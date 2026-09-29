#if os(iOS)
import SwiftUI

// ════════════════════════════════════════════════════════════════
// VẼ GIÚP — AI vẽ bằng NÉT BÚT cho vở
//
// Máy chủ (`POST /api/v1/vo/ve`) nhờ model viết một SVG nét đơn rồi tự đổi ra
// danh sách điểm, co về khung cạnh dài = 1000. App chỉ việc:
//   · xem trước bằng `Path` (đúng thứ tự vẽ của model),
//   · đưa `HinhVeAI` cho màn viết đặt lên trang thành `PKStroke` thật —
//     người học tẩy/sửa/tô tiếp được như nét của chính mình.
//
// Vì sao là NÉT chứ không phải ẢNH: ảnh dán lên trang thì chết cứng, không
// sửa được một nét nào, và trông lạc loài giữa chữ viết tay.
//
// ⚠️ Chạy 30–90 giây (gpt-6-sol). `APIEndpoint.voVe` có `thoiGianCho` riêng;
// để mặc định 60 giây là app bỏ cuộc trong khi máy chủ vẫn vẽ và vẫn trừ hạn
// mức. Trạng thái sống ở `MayVe` do `TroLyTrang` giữ, nên đóng khung giữa
// chừng KHÔNG huỷ lượt vẽ — mở lại là thấy tiếp.
// ════════════════════════════════════════════════════════════════

/// Một hình AI vẽ, toạ độ trong khung `rong × cao` (cạnh dài = 1000).
struct HinhVeAI {
    let net: [[CGPoint]]
    let rong: CGFloat
    let cao: CGFloat
    /// Nhãn gợi ý (chỉ sơ đồ) — người học TỰ viết vào, AI không viết chữ hộ.
    let nhan: [String]
    /// Chỗ viết từng nhãn, cùng hệ toạ độ với `net`. App vẽ số ①②③ ở đó để
    /// người học biết viết nhãn nào vào đâu (người dùng hỏi 28/09: "không đánh
    /// dấu chỗ thì sao tôi viết được"). Rỗng với máy chủ cũ.
    var nhanViTri: [NhanVe] = []
    /// Vai trò từng nét, song song với `net` (rỗng = mọi nét là `.chinh`).
    /// Chữ Hán / sơ đồ khối dùng: chữ luôn mảnh, ô 田 mờ, số thứ tự đỏ.
    var loai: [VaiTroNet] = []
    /// `true` = toạ độ đã là pt THẬT (chữ trong sơ đồ cỡ ~9pt, ô chữ Hán
    /// 64/96/140pt) ⇒ đặt đúng cỡ, không phóng theo bề rộng trang. Chỉ co
    /// nhỏ khi vùng đang nhìn không chứa nổi.
    var coTuNhien = false
    /// Cỡ ĐIỂM tối thiểu của nét `.chinh` (xem `BanVeNet.coNetChinh`).
    var coNetChinh: CGFloat?
    /// Cỡ ĐIỂM cố định của nét `.chinh` (xem `BanVeNet.coNetCoDinh`).
    var coNetCoDinh: CGFloat?
}

extension HinhVeAI {
    init(_ b: BanVeNet, nhan: [String] = []) {
        self.init(net: b.net, rong: max(b.rong, 1), cao: max(b.cao, 1), nhan: nhan)
        loai = b.loai
        coTuNhien = true
        coNetChinh = b.coNetChinh
        coNetCoDinh = b.coNetCoDinh
    }

    func loaiCua(_ i: Int) -> VaiTroNet { i < loai.count ? loai[i] : .chinh }
}

struct NhanVe: Hashable {
    let so: Int
    let ten: String
    let diem: CGPoint
}

enum KieuVe: String, CaseIterable, Identifiable {
    case hinh, sodo, chuHan, soDoKhoi
    var id: String { rawValue }

    var ten: String {
        switch self {
        case .hinh: return T("Tranh")
        case .sodo: return T("Sơ đồ học tập")
        case .chuHan: return T("Chữ Hán")
        case .soDoKhoi: return T("Sơ đồ khối")
        }
    }
    var bieuTuong: String {
        switch self {
        case .hinh: return "paintpalette"
        case .sodo: return "point.3.connected.trianglepath.dotted"
        case .chuHan: return "character.book.closed.ja"
        case .soDoKhoi: return "flowchart"
        }
    }
    var moTa: String {
        switch self {
        case .hinh: return T("Nét phác tự do")
        case .sodo: return T("Rõ khối, có nhãn")
        case .chuHan: return T("Đúng thứ tự nét")
        case .soDoKhoi: return T("Luồng, MVC, có chữ")
        }
    }
    /// Hai kiểu đầu: AI vẽ SVG (`/vo/ve`). Hai kiểu sau có đường riêng.
    var laVeTuDo: Bool { self == .hinh || self == .sodo }
}

// MARK: - Gọi máy chủ

enum VeBangNet {
    /// Hình dạng câu trả lời. Mọi trường `var` + optional — xem C4 trong
    /// CLAUDE.md của kho: `let` có mặc định thì `Codable` bỏ qua im lặng.
    private struct KetQua: Decodable {
        var net: [[[Double]]]?
        var rong: Double?
        var cao: Double?
        var nhan: [String]?
        var nhanViTri: [NhanViTri]?
        var model: String?
        var xong: Bool?
        var giay: Int?
    }
    private struct NhanViTri: Decodable {
        var so: Int?
        var ten: String?
        var x: Double?
        var y: Double?
    }
    private struct Viec: Decodable { var viec: String? }

    static func ve(de: String, kieu: KieuVe, chiTiet: Bool = false) async throws -> (HinhVeAI, String?) {
        // Chốt đồng ý chia sẻ với AI chạy trong `APIClient` (`laDuongAI` bắt
        // `POST /vo/ve/viec`). Đừng gọi thêm `batBuoc()` ở đây — hai chốt là
        // người dùng chưa đồng ý bị hỏi HAI lần liền.
        //
        // ⚠️ Gửi việc rồi HỎI LẠI, không chờ một cục: Cloudflare cắt yêu cầu
        // quá 100 giây (524) mà bản "Chi tiết" mất 100–150 giây.
        let kq: KetQua = try await ViecNen.cho(han: chiTiet ? 330 : 200, gui: {
            let v: Viec = try await APIClient.shared.request(.voVeViec(de: de, kieu: kieu.rawValue, chiTiet: chiTiet))
            guard let id = v.viec else {
                throw APIError.coMa(ma: "VE_RONG", thongDiep: T("Máy chủ chưa nhận lượt vẽ — thử lại."))
            }
            return id
        }, xem: { id in
            let k: KetQua = try await APIClient.shared.request(.voVeXem(viec: id))
            return k.xong == true ? k : nil
        })
        let net: [[CGPoint]] = (kq.net ?? []).compactMap { n in
            let d = n.compactMap { p in p.count >= 2 ? CGPoint(x: p[0], y: p[1]) : nil }
            return d.isEmpty ? nil : d
        }
        guard !net.isEmpty else {
            throw APIError.coMa(ma: "VE_RONG", thongDiep: T("AI chưa vẽ được hình này — thử mô tả khác một chút."))
        }
        let viTri: [NhanVe] = (kq.nhanViTri ?? []).compactMap { n in
            guard let so = n.so, let ten = n.ten, let x = n.x, let y = n.y else { return nil }
            return NhanVe(so: so, ten: ten, diem: CGPoint(x: x, y: y))
        }
        let hinh = HinhVeAI(net: net, rong: CGFloat(max(kq.rong ?? 1000, 1)),
                            cao: CGFloat(max(kq.cao ?? 1000, 1)),
                            nhan: viTri.isEmpty ? (kq.nhan ?? []) : viTri.map(\.ten),
                            nhanViTri: viTri)
        return (hinh, kq.model)
    }

    /// Câu người dùng đọc. Máy chủ đã viết sẵn tiếng Việt cho các mã lỗi của
    /// nó; chỉ phải dịch hai chỗ nó không nói được: mất kết nối và 404 (bản
    /// app đi trước bản máy chủ — tuyến chưa lên production).
    static func cauLoi(_ e: Error) -> String {
        if let u = e as? URLError, u.code == .timedOut {
            return T("Chờ quá lâu mà chưa có hình. Thử lại, hoặc mô tả ngắn gọn hơn.")
        }
        if case APIError.serverError(let m) = e, m.contains("404") || m.contains("not found") {
            return T("Máy chủ chưa có tính năng vẽ — sắp có.")
        }
        return (e as? LocalizedError)?.errorDescription ?? e.localizedDescription
    }
}

// MARK: - Việc chạy nền: gửi, hỏi lại, tự gửi lại khi máy chủ khởi động lại

/// Việc AI chạy nền (vẽ, viết lại trang) sống trong BỘ NHỚ máy chủ. Máy chủ
/// khởi động lại (deploy) là việc đang chạy MẤT: lượt hỏi kế tiếp nhận 502
/// (container đang tráo) rồi 404 "không tìm thấy lượt". Đo thật 29/09/2026:
/// người dùng bấm "AI viết lại trang" đúng lúc một phiên khác deploy ⇒ màn báo
/// "Máy chủ trả lỗi 502". Nên: lỗi kiểu "máy chủ vừa đi vắng" thì đợi rồi GỬI
/// LẠI việc (tối đa 2 lần), không báo lỗi ngay.
enum ViecNen {
    static func cho<T>(han giay: TimeInterval, gui: () async throws -> String,
                       xem: (String) async throws -> T?) async throws -> T {
        let han = Date().addingTimeInterval(giay)
        var id = try await gui()
        var soLanGuiLai = 0
        while true {
            try await Task.sleep(for: .seconds(3))
            do {
                if let kq = try await xem(id) { return kq }
            } catch {
                guard laMayChuVang(error), soLanGuiLai < 2, Date() < han else { throw error }
                soLanGuiLai += 1
                NhatKy.vo.info("việc nền: máy chủ vắng (\(error.localizedDescription)) — gửi lại lần \(soLanGuiLai)")
                try await Task.sleep(for: .seconds(6))
                id = try await gui()
                continue
            }
            if Date() > han { throw URLError(.timedOut) }
        }
    }

    /// 502/503/504, mất kết nối, hay "không tìm thấy lượt" (máy chủ mới không
    /// biết việc của máy chủ cũ) — đều là máy chủ vừa khởi động lại.
    static func laMayChuVang(_ e: Error) -> Bool {
        if e is URLError { return true }
        switch e as? APIError {
        case .networkError?: return true
        case .serverError(let m)?: return m.contains("502") || m.contains("503") || m.contains("504")
        case .coMa(let ma, _)?: return ma.hasSuffix("KHONG_CO")
        default: return false
        }
    }
}

// MARK: - Trạng thái

@MainActor
final class MayVe: ObservableObject {
    enum TrangThai {
        case rong
        case dangVe(batDau: Date)
        case xong(HinhVeAI, model: String?)
        /// Chữ Hán: tra ra nhiều chữ, chờ người dùng chọn.
        case chonChu([UngVienHan])
        case loi(String)
    }

    @Published var de = ""
    @Published var kieu: KieuVe = .hinh
    /// Bản "Chi tiết": ~100 nét, có bóng + chi tiết, mất 1–3 phút.
    /// (`@Published` + UserDefaults chứ không `@AppStorage`: `@AppStorage` trong
    /// ObservableObject không phát thay đổi ⇒ công tắc bấm không đổi hình.)
    @Published var chiTiet = UserDefaults.standard.bool(forKey: "vo.ve.chitiet") {
        didSet { UserDefaults.standard.set(chiTiet, forKey: "vo.ve.chitiet") }
    }
    @Published private(set) var trangThai: TrangThai = .rong
    private var viec: Task<Void, Never>?

    // ── Chữ Hán ──
    @Published var coHan: VeChuHan.Co = VeChuHan.Co(rawValue: UserDefaults.standard.string(forKey: "vo.ve.han.co") ?? "") ?? .vua {
        didSet { UserDefaults.standard.set(coHan.rawValue, forKey: "vo.ve.han.co"); dungLaiHan() }
    }
    @Published var soThuTuNet = UserDefaults.standard.object(forKey: "vo.ve.han.so") as? Bool ?? true {
        didSet { UserDefaults.standard.set(soThuTuNet, forKey: "vo.ve.han.so"); dungLaiHan() }
    }
    @Published var oDien = UserDefaults.standard.object(forKey: "vo.ve.han.o") as? Bool ?? true {
        didSet { UserDefaults.standard.set(oDien, forKey: "vo.ve.han.o"); dungLaiHan() }
    }
    /// Thông tin chữ đang vẽ (On/Kun/Hán Việt) — có thể tới SAU hình.
    @Published private(set) var thongTinHan: UngVienHan?
    /// Chữ kana mà dữ liệu thứ tự nét không đáng tin ⇒ không đánh số.
    @Published private(set) var canhBaoHan: String?
    @Published private(set) var soNetHan: [String: Int] = [:]
    private var chuDangVe = ""
    private var netHan: [String: NetChu] = [:]
    /// Mô tả gốc của sơ đồ khối vừa dựng (tiêu đề hiển thị).
    @Published private(set) var tieuDeSoDo: String?

    var dangVe: Bool { if case .dangVe = trangThai { return true } else { return false } }
    var hinh: HinhVeAI? { if case .xong(let h, _) = trangThai { return h } else { return nil } }

    func ve() {
        let d = de.trimmingCharacters(in: .whitespacesAndNewlines)
        guard d.count >= (kieu == .chuHan ? 1 : 2), !dangVe else { return }
        if kieu == .chuHan { veChuHan(d); return }
        if kieu == .soDoKhoi { veSoDoKhoi(d); return }
        trangThai = .dangVe(batDau: Date())
        Haptics.cham()
        let kieu = self.kieu
        let chiTiet = self.chiTiet
        viec = Task { [weak self] in
            do {
                let (h, m) = try await VeBangNet.ve(de: d, kieu: kieu, chiTiet: chiTiet)
                guard let self, !Task.isCancelled else { return }
                self.trangThai = .xong(h, model: m)
                Haptics.xong()
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.trangThai = .loi(VeBangNet.cauLoi(error))
                Haptics.hong()
            }
        }
    }

    /// Huỷ phía app. Máy chủ vẫn chạy nốt lượt đó — không có cách gọi nó dừng.
    func huy() {
        viec?.cancel()
        viec = nil
        trangThai = .rong
    }

    func veLai() { trangThai = .rong; ve() }
    func xoaKetQua() { trangThai = .rong; thongTinHan = nil; canhBaoHan = nil }

    // MARK: Chữ Hán

    private func veChuHan(_ d: String) {
        trangThai = .dangVe(batDau: Date())
        thongTinHan = nil
        canhBaoHan = nil
        Haptics.cham()
        viec = Task { [weak self] in
            do {
                if TraHan.laChuVeDuoc(d) {
                    // Gõ thẳng chữ: vẽ ngay bằng nét chuẩn; thông tin tra SONG SONG, tới sau.
                    let chu = String(d.filter { !$0.isWhitespace }.prefix(8))
                    async let tt = try? TraHan.tra(chu)
                    try await self?.taiNetVaVe(chu)
                    let ds = await tt
                    guard let self, !Task.isCancelled, self.chuDangVe == chu else { return }
                    self.thongTinHan = ds?.first
                    return
                }
                let ds = try await TraHan.tra(d)
                guard let self, !Task.isCancelled else { return }
                if ds.count == 1, let u = ds.first {
                    self.thongTinHan = u
                    try await self.taiNetVaVe(u.chu ?? "")
                } else if ds.isEmpty {
                    self.trangThai = .loi(T("Chưa tìm ra chữ Hán khớp — thử âm Hán Việt khác hoặc dán thẳng chữ."))
                } else {
                    self.trangThai = .chonChu(ds)
                    Haptics.xong()
                }
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.trangThai = .loi(VeBangNet.cauLoi(error))
                Haptics.hong()
            }
        }
    }

    func chonUngVien(_ u: UngVienHan) {
        guard let chu = u.chu, !chu.isEmpty else { return }
        thongTinHan = u
        trangThai = .dangVe(batDau: Date())
        viec = Task { [weak self] in
            do { try await self?.taiNetVaVe(chu) } catch {
                guard let self, !Task.isCancelled else { return }
                self.trangThai = .loi(VeBangNet.cauLoi(error))
            }
        }
    }

    /// Tải nét chuẩn cho từng chữ (song song) rồi dựng hình.
    private func taiNetVaVe(_ chu: String) async throws {
        let cacChu = chu.map(String.init)
        var thieu: [String] = []
        // Tải lần lượt: 1–8 chữ, mỗi chữ một yêu cầu nhỏ có đệm — gọn hơn nhóm
        // việc song song mà vẫn nhanh.
        for c in cacChu where netHan[c] == nil && !thieu.contains(c) {
            if let n = await KhoNetChu.shared.lay(c, lang: "ja") { netHan[c] = n }
            else if let n = await KhoNetChu.shared.lay(c, lang: "zh") { netHan[c] = n }
            else { thieu.append(c) }
        }
        guard !Task.isCancelled else { return }
        if !thieu.isEmpty {
            throw APIError.coMa(ma: "HAN_THIEU_NET",
                                thongDiep: T("Chưa có dữ liệu nét chuẩn cho chữ") + " " + thieu.joined(separator: " ")
                                    + T(" — mình không để AI tự vẽ nét chữ Hán vì hay sai thứ tự."))
        }
        chuDangVe = chu
        dungLaiHan(batBuoc: true)
        Haptics.xong()
    }

    /// Dựng lại hình từ nét đã tải (đổi cỡ / bật tắt số / ô 田 không gọi mạng).
    private func dungLaiHan(batBuoc: Bool = false) {
        guard kieu == .chuHan, !chuDangVe.isEmpty else { return }
        if !batBuoc { guard case .xong = trangThai else { return } }
        var kanaSai: [String] = []
        let ds: [VeChuHan.Chu] = chuDangVe.compactMap { ch in
            let c = String(ch)
            guard let n = netHan[c] else { return nil }
            let tin = SoNetChuan.chamTungNetDuoc(chu: c, soNetMayChu: n.strokes.count)
            if !tin { kanaSai.append(c) }
            return VeChuHan.Chu(chu: c, medians: n.medians, danhSo: tin)
        }
        guard !ds.isEmpty else { return }
        soNetHan = Dictionary(ds.map { ($0.chu, $0.medians.count) }, uniquingKeysWith: { a, _ in a })
        canhBaoHan = kanaSai.isEmpty ? nil
            : T("Kho nét của kana") + " " + kanaSai.joined(separator: " ")
                + " " + T("chưa chắc đúng thứ tự nét nên không đánh số. Kanji thì nét chuẩn.")
        let ban = VeChuHan.dung(ds, canh: coHan.canh, soThuTu: soThuTuNet, oDien: oDien)
        trangThai = .xong(HinhVeAI(ban), model: nil)
    }

    // MARK: Sơ đồ khối

    private func veSoDoKhoi(_ d: String) {
        trangThai = .dangVe(batDau: Date())
        tieuDeSoDo = nil
        Haptics.cham()
        viec = Task { [weak self] in
            do {
                let (h, g) = try await TaiSoDo.dung(d)
                guard let self, !Task.isCancelled else { return }
                self.tieuDeSoDo = g.tieuDe
                self.trangThai = .xong(h, model: g.model)
                Haptics.xong()
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.trangThai = .loi(VeBangNet.cauLoi(error))
                Haptics.hong()
            }
        }
    }

    #if DEBUG
    /// Chỉ cho bàn thử `CT_TROLY` — dựng trạng thái mà không gọi mạng.
    func gia(_ t: TrangThai) { trangThai = t }

    /// Bàn thử chữ Hán: nạp nét mẫu (không mạng) rồi dựng như thật.
    func giaHan(_ chu: String, thongTin: UngVienHan?) {
        kieu = .chuHan
        de = chu
        for c in chu.map(String.init) { if let n = MauVeMoi.netChu(c) { netHan[c] = n } }
        thongTinHan = thongTin
        chuDangVe = chu
        dungLaiHan(batBuoc: true)
    }

    func giaSoDo(_ g: DoThiKhoi, de: String) {
        kieu = .soDoKhoi
        self.de = de
        tieuDeSoDo = g.tieuDe
        if let b = SoDoKhoi.dung(g) { trangThai = .xong(HinhVeAI(b), model: "gpt-6-sol") }
    }
    #endif
}

// MARK: - Xem trước hình

/// Vẽ `HinhVeAI` bằng `Path`, co vừa khung, giữ tỉ lệ.
///
/// Nối điểm bằng đường cong bậc hai qua TRUNG ĐIỂM: nối thẳng từng điểm thì
/// nét tròn ra góc cạnh như đa giác, khác hẳn nét sẽ đặt lên trang.
struct HinhVeXemTruoc: View {
    let hinh: HinhVeAI
    var mau: Color = AppColors.textPrimary
    /// Vẽ dần theo đúng thứ tự nét lúc xuất hiện.
    var veDan = true

    @Environment(\.accessibilityReduceMotion) private var giamChuyenDong
    @State private var tien: CGFloat = 0

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .topLeading) {
                let tyXem = min(g.size.width / max(hinh.rong, 1), g.size.height / max(hinh.cao, 1))
                if hinh.loai.isEmpty {
                    duong(trong: g.size)
                        .trim(from: 0, to: (veDan && !giamChuyenDong) ? tien : 1)
                        .stroke(mau, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                } else {
                    // Vẽ theo vai trò, cùng tỉ lệ bề dày như trên trang (cỡ điểm
                    // PencilKit ≈ 2,2 × bề rộng nét hiện ra).
                    ForEach([VaiTroNet.mo, .phu, .chinh, .chu, .so], id: \.rawValue) { l in
                        let day: CGFloat = {
                            switch l {
                            case .chinh: return max(1.2, (hinh.coNetCoDinh ?? hinh.coNetChinh ?? 3.6) * 0.5 * tyXem)
                            case .chu: return max(0.7, 1.15 * tyXem)
                            default: return max(0.5, 1.0 * tyXem)
                            }
                        }()
                        let mauNay: Color = l == .so ? Color(red: 0.86, green: 0.16, blue: 0.2)
                            : l == .mo ? Color(red: 0.62, green: 0.63, blue: 0.68)
                            : l == .phu ? mau.opacity(0.6) : mau
                        duong(trong: g.size, chi: l)
                            .trim(from: 0, to: (veDan && !giamChuyenDong && l != .mo) ? tien : 1)
                            .stroke(mauNay, style: StrokeStyle(lineWidth: day, lineCap: .round, lineJoin: .round))
                    }
                }
                // Số nhãn đúng chỗ AI chỉ — khớp số trong danh sách nhãn bên dưới.
                let ty = min(g.size.width / max(hinh.rong, 1), g.size.height / max(hinh.cao, 1))
                let leX = (g.size.width - hinh.rong * ty) / 2
                let leY = (g.size.height - hinh.cao * ty) / 2
                ForEach(hinh.nhanViTri, id: \.self) { n in
                    Text("\(n.so)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 17, height: 17)
                        .background(Circle().fill(Color(red: 0.86, green: 0.16, blue: 0.2)))
                        .position(x: leX + n.diem.x * ty, y: leY + n.diem.y * ty)
                        .opacity((veDan && !giamChuyenDong) ? Double(tien) : 1)
                }
            }
        }
        .aspectRatio(hinh.rong / max(hinh.cao, 1), contentMode: .fit)
        .onAppear {
            guard veDan, !giamChuyenDong else { return }
            tien = 0
            let tg = min(2.4, 0.6 + Double(hinh.net.count) * 0.04)
            withAnimation(.easeInOut(duration: tg)) { tien = 1 }
        }
        .accessibilityLabel(T("Hình xem trước"))
    }

    private func duong(trong kho: CGSize, chi: VaiTroNet? = nil) -> Path {
        let ty = min(kho.width / max(hinh.rong, 1), kho.height / max(hinh.cao, 1))
        let leX = (kho.width - hinh.rong * ty) / 2
        let leY = (kho.height - hinh.cao * ty) / 2
        var p = Path()
        for (i, net) in hinh.net.enumerated() {
            if let chi, hinh.loaiCua(i) != chi { continue }
            let d = net.map { CGPoint(x: leX + $0.x * ty, y: leY + $0.y * ty) }
            guard let dau = d.first else { continue }
            if chi != nil && chi != .chinh {
                // Chữ / số / khung: nối thẳng — làm tròn qua trung điểm làm méo chữ nhỏ.
                p.move(to: dau)
                if d.count == 1 { p.addLine(to: CGPoint(x: dau.x + 0.4, y: dau.y)) }
                for q in d.dropFirst() { p.addLine(to: q) }
                continue
            }
            p.move(to: dau)
            if d.count == 1 {
                // Một chấm (mắt, dấu chấm) — vẽ thành vòng nhỏ cho thấy được.
                p.addEllipse(in: CGRect(x: dau.x - 1, y: dau.y - 1, width: 2, height: 2))
                continue
            }
            for i in 1..<d.count {
                let giua = CGPoint(x: (d[i - 1].x + d[i].x) / 2, y: (d[i - 1].y + d[i].y) / 2)
                if i == 1 { p.addLine(to: giua) } else { p.addQuadCurve(to: giua, control: d[i - 1]) }
            }
            p.addLine(to: d[d.count - 1])
        }
        return p
    }
}

// MARK: - Khung Vẽ giúp (trong khung hỏi)

struct KhungVeGiup: View {
    @ObservedObject var may: MayVe
    /// `nil` = màn viết chưa nối việc đặt hình lên trang.
    let chen: ((HinhVeAI) -> Void)?
    let dong: () -> Void

    @FocusState private var dangGo: Bool
    @State private var baoSapCo = false

    /// Chip ví dụ RIÊNG cho từng kiểu: (chữ trên chip, mô tả điền vào ô).
    private static func viDu(_ k: KieuVe) -> [(String, String)] {
        switch k {
        case .hinh: return [("Con mèo ngồi", "Con mèo ngồi"), ("Cây xương rồng", "Cây xương rồng"),
                            ("Chiếc xe đạp", "Chiếc xe đạp"), ("Ngôi nhà nhỏ", "Ngôi nhà nhỏ")]
        case .sodo: return [("Chu trình nước", "Chu trình nước"), ("Tế bào thực vật", "Tế bào thực vật"),
                            ("Trục toạ độ Oxy", "Trục toạ độ Oxy"), ("Mạch điện nối tiếp", "Mạch điện nối tiếp")]
        case .chuHan: return [("学", "学"), ("日本", "日本"), ("愛", "愛"), ("日本語", "日本語"),
                              ("học", "học"), ("gaku", "gaku"), ("nhật bản ngữ", "nhật bản ngữ")]
        case .soDoKhoi: return [
            ("MVC", "Mô hình MVC: người dùng, View, Controller, Model, cơ sở dữ liệu"),
            ("Luồng đăng nhập JWT", "Luồng đăng nhập JWT: client → API → DB, lưu refresh token vào Redis"),
            ("Vòng đời request Express", "Vòng đời một request trong Express: middleware → router → controller → response"),
            ("Kiến trúc 3 tầng", "Kiến trúc 3 tầng: giao diện, nghiệp vụ, dữ liệu"),
            ("Flowchart chẵn lẻ", "Flowchart kiểm tra một số là chẵn hay lẻ"),
            ("Git → CI/CD → VPS", "Luồng CI/CD: git push → GitHub Actions chạy test, build Docker → deploy lên VPS"),
        ]
        }
    }

    private var goiYO: String {
        switch may.kieu {
        case .hinh: return T("Ví dụ: con mèo ngồi trên ghế…")
        case .sodo: return T("Ví dụ: sơ đồ quang hợp có mũi tên…")
        case .chuHan: return T("Gõ chữ Hán, âm Hán Việt, nghĩa hoặc romaji — 学, học, gaku…")
        case .soDoKhoi: return T("Mô tả sơ đồ — vd: luồng đăng nhập JWT: client → API → DB…")
        }
    }

    private var tieuDeNhap: (String, String) {
        switch may.kieu {
        case .chuHan: return (T("Vẽ chữ Hán nào?"), T("Nét lấy từ dữ liệu nét chuẩn, vẽ đúng thứ tự — AI chỉ tra chữ và cách đọc."))
        case .soDoKhoi: return (T("Sơ đồ gì?"), T("AI dựng khung sơ đồ, app tự căn thẳng hàng và viết chữ bằng nét bút — tẩy, sửa được."))
        default: return (T("Bạn muốn vẽ gì?"), T("AI vẽ bằng nét bút — đặt lên trang rồi bạn tẩy, sửa, tô tiếp như nét của mình."))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                switch may.trangThai {
                case .rong:              manNhap
                case .dangVe(let luc):   ManChoVe(batDau: luc, de: may.de, kieu: may.kieu, huy: may.huy)
                case .xong(let h, let m): manKetQua(h, model: m)
                case .chonChu(let ds):
                    DanhSachUngVienHan(ds: ds) { may.chonUngVien($0) }
                    nutPhu(T("Sửa chữ cần tra"), "text.cursor") { may.xoaKetQua() }
                case .loi(let e):        manLoi(e)
                }
            }
            .padding(Spacing.md)
            .animation(.snappy(duration: 0.25), value: khoaTrangThai)
        }
        .scrollDismissesKeyboard(.interactively)
        .alert(T("Sắp có"), isPresented: $baoSapCo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(T("Đặt hình lên trang đang được hoàn thiện. Tạm thời bạn nhìn hình mẫu và vẽ theo nhé."))
        }
    }

    /// Chuỗi ổn định để khoá hoạt ảnh — xem C6 trong CLAUDE.md của kho.
    private var khoaTrangThai: String {
        switch may.trangThai {
        case .rong: return "rong"
        case .dangVe: return "ve"
        case .xong: return "xong"
        case .chonChu: return "chon"
        case .loi: return "loi"
        }
    }

    // ── Nhập mô tả ──────────────────────────────────────────────
    @ViewBuilder
    private var manNhap: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tieuDeNhap.0)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
            Text(tieuDeNhap.1)
                .font(.footnote)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.sm), GridItem(.flexible(), spacing: Spacing.sm)],
                  spacing: Spacing.sm) {
            ForEach(KieuVe.allCases) { k in theKieu(k) }
        }

        TextField(goiYO, text: $may.de, axis: .vertical)
            .font(.body)
            .lineLimit(2...5)
            .focused($dangGo)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.backgroundCard.opacity(0.85)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(dangGo ? AppColors.primary.opacity(0.6) : AppColors.border,
                              lineWidth: dangGo ? 1.5 : 1))

        VStack(alignment: .leading, spacing: 6) {
            Text(T("Gợi ý"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textTertiary)
                .textCase(.uppercase)
            LuoiChip(khoangCach: 6) {
                ForEach(Self.viDu(may.kieu), id: \.0) { chu, moTa in
                    Button {
                        may.de = may.kieu == .chuHan ? moTa : T(moTa)
                        Haptics.cham()
                    } label: {
                        Text(may.kieu == .chuHan ? chu : T(chu))
                            .font(may.kieu == .chuHan && TraHan.laChuVeDuoc(chu) ? .body : nil)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(AppColors.primary.opacity(0.09)))
                            .overlay(Capsule().strokeBorder(AppColors.primary.opacity(0.18), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        Button {
            dangGo = false
            may.ve()
        } label: {
            Label(may.kieu == .chuHan ? T("Vẽ chữ") : may.kieu == .soDoKhoi ? T("Dựng sơ đồ") : T("Vẽ giúp mình"),
                  systemImage: may.kieu == .soDoKhoi ? "flowchart.fill" : "paintbrush.pointed.fill")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .foregroundStyle(AppColors.onPrimary)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [AppColors.primary, AppColors.brandPink],
                                         startPoint: .leading, endPoint: .trailing)))
                .opacity(coTheVe ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!coTheVe)

        if may.kieu == .chuHan { TuyChonVeHan(may: may) }

        if may.kieu.laVeTuDo {
        Toggle(isOn: $may.chiTiet) {
            VStack(alignment: .leading, spacing: 2) {
                Text(T("Vẽ chi tiết hơn"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(T("Nhiều nét, có bóng và chi tiết nhỏ — đẹp hơn nhưng mất 1–3 phút"))
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .tint(AppColors.primary)

        }

        Label(may.kieu == .chuHan ? T("Gõ thẳng chữ thì vẽ ngay; tra từ âm/nghĩa mất 5–20 giây.")
              : may.kieu == .soDoKhoi ? T("Thường mất 15–40 giây. Đóng khung vẫn dựng tiếp.")
              : may.chiTiet ? T("Thường mất 1–3 phút. Đóng khung vẫn vẽ tiếp.")
                          : T("Thường mất 30–90 giây. Đóng khung vẫn vẽ tiếp."), systemImage: "clock")
            .font(.caption)
            .foregroundStyle(AppColors.textTertiary)
    }

    private var coTheVe: Bool {
        may.de.trimmingCharacters(in: .whitespacesAndNewlines).count >= (may.kieu == .chuHan ? 1 : 2)
    }

    private func theKieu(_ k: KieuVe) -> some View {
        let chon = may.kieu == k
        return Button {
            may.kieu = k
            Haptics.cham()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: k.bieuTuong)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(chon ? AppColors.onPrimary : AppColors.primary)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(chon ? AnyShapeStyle(AppColors.primary) : AnyShapeStyle(AppColors.primary.opacity(0.12))))
                VStack(alignment: .leading, spacing: 1) {
                    Text(k.ten)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(k.moTa)
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.backgroundCard.opacity(chon ? 0.95 : 0.6)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(chon ? AppColors.primary : AppColors.border, lineWidth: chon ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(chon ? .isSelected : [])
    }

    // ── Kết quả ─────────────────────────────────────────────────
    @ViewBuilder
    private func manKetQua(_ h: HinhVeAI, model: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(may.kieu == .chuHan ? T("Chữ đã sẵn sàng") : T("Xong rồi!"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(dongPhu(h))
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }

        // Nền GIẤY trắng ở cả hai chế độ: hình sẽ nằm trên trang giấy, xem
        // trước trên nền tối là xem sai thứ sẽ thấy.
        HinhVeXemTruoc(hinh: h, mau: Color(hex: 0x1C1C24))
            .id(may.kieu == .chuHan ? "\(h.net.count)-\(h.rong)" : "h")   // đổi tuỳ chọn ⇒ vẽ dần lại
            .padding(Spacing.md)
            .frame(maxWidth: .infinity)
            .frame(maxHeight: may.kieu == .soDoKhoi ? 420 : 300)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1))
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)

        if may.kieu == .chuHan {
            if let c = may.canhBaoHan {
                Label(c, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let u = may.thongTinHan, !(u.chiTiet ?? []).isEmpty || u.nghia != nil {
                TheThongTinHan(u: u, soNet: may.soNetHan)
            } else {
                Label(T("Đang tra cách đọc, nghĩa…"), systemImage: "hourglass")
                    .font(.caption).foregroundStyle(AppColors.textTertiary)
            }
            TuyChonVeHan(may: may)
        }

        if !h.nhan.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Label(T("Nhãn gợi ý — bạn tự viết vào hình"), systemImage: "pencil.and.list.clipboard")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
                LuoiChip(khoangCach: 6) {
                    ForEach(Array(h.nhan.enumerated()), id: \.offset) { i, n in
                        HStack(spacing: 5) {
                            Text("\(i + 1)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(AppColors.onPrimary)
                                .frame(width: 17, height: 17)
                                .background(Circle().fill(AppColors.secondary))
                            Text(n)
                                .font(.footnote)
                                .foregroundStyle(AppColors.textPrimary)
                        }
                        .padding(.leading, 4).padding(.trailing, 10).padding(.vertical, 4)
                        .background(Capsule().fill(AppColors.secondary.opacity(0.12)))
                    }
                }
            }
        }

        Button {
            if let chen {
                // Đóng khung TRƯỚC rồi mới vẽ: hình vẽ dần lên trang, khung
                // hỏi còn mở là che mất đúng chỗ đang vẽ.
                dong()
                Haptics.xong()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { chen(h) }
            } else { baoSapCo = true }
        } label: {
            Label(T("Vẽ lên trang"), systemImage: "square.and.pencil")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .foregroundStyle(AppColors.onPrimary)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.primary))
        }
        .buttonStyle(.plain)

        HStack(spacing: Spacing.sm) {
            if may.kieu == .chuHan {
                nutPhu(T("Chữ khác"), "character.cursor.ibeam") { may.xoaKetQua() }
            } else {
                nutPhu(may.kieu == .soDoKhoi ? T("Dựng lại") : T("Vẽ lại"), "arrow.clockwise") { may.veLai() }
                nutPhu(T("Sửa mô tả"), "text.cursor") { may.xoaKetQua() }
            }
        }

        if let model {
            Text(model)
                .font(.caption2)
                .foregroundStyle(AppColors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func dongPhu(_ h: HinhVeAI) -> String {
        switch may.kieu {
        case .chuHan:
            let so = may.soNetHan.values.reduce(0, +)
            return "\(may.thongTinHan?.chu ?? may.de) · \(so) \(T("nét")) · \(T("vẽ đúng thứ tự nét"))"
        case .soDoKhoi:
            return "“\(may.tieuDeSoDo ?? may.de)” · \(T("khung, mũi tên và chữ đều là nét bút"))"
        default:
            return "“\(may.de)” · \(h.net.count) \(T("nét"))"
        }
    }

    private func manLoi(_ e: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "scribble.variable")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(AppColors.textTertiary)
                .padding(.top, Spacing.lg)
            Text(e)
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Spacing.sm) {
                nutPhu(T("Thử lại"), "arrow.clockwise") { may.veLai() }
                nutPhu(T("Sửa mô tả"), "text.cursor") { may.xoaKetQua() }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func nutPhu(_ chu: String, _ icon: String, _ lam: @escaping () -> Void) -> some View {
        Button(action: lam) {
            Label(chu, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(AppColors.textPrimary)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColors.textPrimary.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Màn chờ

/// Màn chờ 30–90 giây. Phải cho thấy ba thứ: MÁY ĐANG LÀM (không treo), ĐÃ
/// BAO LÂU và CÒN KHOẢNG BAO LÂU — thiếu cái cuối thì người ta bấm huỷ ở
/// giây 40 vì tưởng hỏng, đúng lúc hình sắp về.
private struct ManChoVe: View {
    let batDau: Date
    let de: String
    var kieu: KieuVe = .hinh
    let huy: () -> Void

    @Environment(\.accessibilityReduceMotion) private var giamChuyenDong
    /// Mốc để thanh tiến độ tới ~95%. Không phải số đo — chỉ để thanh không
    /// đứng im; tới 95% là dừng, không bao giờ báo "xong" giả.
    private var moc: Double { kieu == .chuHan ? 12 : kieu == .soDoKhoi ? 30 : 75 }

    var body: some View {
        VStack(spacing: Spacing.md) {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: giamChuyenDong)) { tl in
                ButVeCho(t: tl.date.timeIntervalSince(batDau), tinh: giamChuyenDong)
            }
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1))

            VStack(spacing: 4) {
                Text(kieu == .chuHan ? T("Đang tra chữ và tải nét chuẩn…") : kieu == .soDoKhoi ? T("Đang dựng sơ đồ…") : T("Đang vẽ…"))
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Text("“\(de)”")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            TimelineView(.periodic(from: batDau, by: 1)) { tl in
                let da = max(0, tl.date.timeIntervalSince(batDau))
                VStack(spacing: 6) {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppColors.textPrimary.opacity(0.08))
                            Capsule()
                                .fill(LinearGradient(colors: [AppColors.primary, AppColors.brandPink],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: g.size.width * min(0.95, max(0.04, da / moc)))
                                .animation(.linear(duration: 1), value: Int(da))
                        }
                    }
                    .frame(height: 6)
                    HStack {
                        Text(dongHo(da))
                            .monospacedDigit()
                        Spacer()
                        Text(kieu == .chuHan ? T("thường 5–20 giây")
                             : kieu == .soDoKhoi ? (da < 40 ? T("thường 15–40 giây") : T("sơ đồ lớn, chờ thêm chút"))
                             : da < 90 ? T("thường 30–90 giây") : da < 180 ? T("hình khó / chi tiết, chờ thêm chút") : T("sắp xong rồi…"))
                    }
                    .font(.caption)
                    .foregroundStyle(AppColors.textTertiary)
                }
            }

            Button(role: .cancel, action: huy) {
                Text(T("Huỷ"))
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 8)
                    .foregroundStyle(AppColors.textPrimary)
                    .background(Capsule().fill(AppColors.textPrimary.opacity(0.07)))
            }
            .buttonStyle(.plain)
        }
        .accessibilityElement(children: .combine)
    }

    private func dongHo(_ s: TimeInterval) -> String {
        let n = Int(s)
        return String(format: "%d:%02d", n / 60, n % 60)
    }
}

/// Ngòi bút vẽ đi vẽ lại một đường lượn — gợi "đang vẽ", không giả làm hình thật.
private struct ButVeCho: View {
    let t: TimeInterval
    let tinh: Bool

    var body: some View {
        GeometryReader { g in
            let chu = tinh ? 0.7 : (t.truncatingRemainder(dividingBy: 2.6)) / 2.6
            let dau = max(0, chu - 0.45)
            let p = duong(g.size)
            ZStack {
                p.stroke(Color.black.opacity(0.06), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 6]))
                p.trim(from: dau, to: chu)
                    .stroke(LinearGradient(colors: [AppColors.primary.opacity(0.2), AppColors.primary],
                                           startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                Image(systemName: "pencil.tip")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
                    .rotationEffect(.degrees(-35))
                    .position(diem(chu, g.size))
                    .offset(x: 6, y: -9)
            }
        }
        .padding(.horizontal, 24)
    }

    /// Đường lượn hình số 8 nằm ngang — đọc ra ngay là "nét bút", và khép
    /// kín nên vòng lặp không có chỗ giật.
    private func diem(_ u: Double, _ k: CGSize) -> CGPoint {
        let a = u * 2 * .pi
        return CGPoint(x: k.width / 2 + sin(a) * k.width * 0.42,
                       y: k.height / 2 + sin(2 * a) * k.height * 0.28)
    }

    private func duong(_ k: CGSize) -> Path {
        var p = Path()
        let n = 120
        for i in 0...n {
            let d = diem(Double(i) / Double(n), k)
            if i == 0 { p.move(to: d) } else { p.addLine(to: d) }
        }
        return p
    }
}

// `LuoiChip` (xếp chip tự xuống dòng) dùng chung bản ở `Academy/SoDoMonHocView.swift`.

// MARK: - Hình mẫu (DEBUG)

#if DEBUG
/// Hình giả cho bàn thử — dựng bằng hình học, không gọi mạng.
enum HinhVeMau {
    private static func tron(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat,
                             tu: CGFloat = 0, den: CGFloat = 2 * .pi, n: Int = 40) -> [CGPoint] {
        (0...n).map { i in
            let a = tu + (den - tu) * CGFloat(i) / CGFloat(n)
            return CGPoint(x: cx + cos(a) * rx, y: cy + sin(a) * ry)
        }
    }

    static let meo = HinhVeAI(net: [
        tron(500, 330, 230, 200),                                            // đầu
        [CGPoint(x: 320, y: 220), CGPoint(x: 300, y: 40), CGPoint(x: 440, y: 150)],   // tai trái
        [CGPoint(x: 560, y: 150), CGPoint(x: 700, y: 40), CGPoint(x: 680, y: 220)],   // tai phải
        tron(420, 300, 28, 38), tron(580, 300, 28, 38),                      // mắt
        [CGPoint(x: 480, y: 380), CGPoint(x: 520, y: 380), CGPoint(x: 500, y: 405)],  // mũi
        tron(470, 420, 30, 25, tu: 0.2, den: 2.9, n: 12),                    // miệng
        tron(530, 420, 30, 25, tu: 0.2, den: 2.9, n: 12),
        [CGPoint(x: 360, y: 390), CGPoint(x: 180, y: 360)], [CGPoint(x: 360, y: 420), CGPoint(x: 190, y: 440)],
        [CGPoint(x: 640, y: 390), CGPoint(x: 820, y: 360)], [CGPoint(x: 640, y: 420), CGPoint(x: 810, y: 440)],
        tron(500, 720, 260, 230, tu: -2.6, den: -0.55 + 2 * .pi, n: 50),      // thân
        [CGPoint(x: 740, y: 820), CGPoint(x: 900, y: 760), CGPoint(x: 960, y: 600),
         CGPoint(x: 900, y: 520), CGPoint(x: 860, y: 580)],                   // đuôi
    ], rong: 1000, cao: 960, nhan: [])

    static let oxy: HinhVeAI = {
        var net: [[CGPoint]] = [
            [CGPoint(x: 40, y: 700), CGPoint(x: 1000, y: 700)],              // Ox
            [CGPoint(x: 960, y: 680), CGPoint(x: 1000, y: 700), CGPoint(x: 960, y: 720)],
            [CGPoint(x: 300, y: 980), CGPoint(x: 300, y: 20)],               // Oy
            [CGPoint(x: 280, y: 60), CGPoint(x: 300, y: 20), CGPoint(x: 320, y: 60)],
        ]
        net.append(tron(700, 300, 12, 12, n: 16))                             // điểm A
        for i in 0..<10 { net.append([CGPoint(x: 700, y: 330 + CGFloat(i) * 37), CGPoint(x: 700, y: 348 + CGFloat(i) * 37)]) }
        for i in 0..<10 { net.append([CGPoint(x: 330 + CGFloat(i) * 37, y: 300), CGPoint(x: 348 + CGFloat(i) * 37, y: 300)]) }
        return HinhVeAI(net: net, rong: 1000, cao: 1000,
                        nhan: ["O (gốc toạ độ)", "trục hoành Ox", "trục tung Oy", "A(2; 3)"],
                        nhanViTri: [NhanVe(so: 1, ten: "O (gốc toạ độ)", diem: CGPoint(x: 260, y: 740)),
                                    NhanVe(so: 2, ten: "trục hoành Ox", diem: CGPoint(x: 960, y: 760)),
                                    NhanVe(so: 3, ten: "trục tung Oy", diem: CGPoint(x: 350, y: 40)),
                                    NhanVe(so: 4, ten: "A(2; 3)", diem: CGPoint(x: 750, y: 260))])
    }()
}
#endif
#endif
