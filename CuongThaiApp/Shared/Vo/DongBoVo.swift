#if os(iOS)
import CryptoKit
import Foundation
import PencilKit
import SwiftData
import UIKit

/// Đồng bộ Vở lên máy chủ.
///
/// Ba nhịp cho mỗi trang, khớp với `vo.routes.ts`:
///   1. `POST /vo/sync`                → gửi cây, nhận id máy chủ
///   2. `POST /vo/trang/:id/duong-day` → xin URL ký sẵn, **PUT THẲNG lên R2**
///   3. `POST /vo/trang/:id/xac-nhan`  → máy chủ HEAD kiểm rồi mới ghi con trỏ
///
/// ⚠️ Nguyên tắc xuyên suốt: **không bao giờ ghi đè khi không chắc.** Máy chủ
/// từ chối lượt đẩy dựa trên phiên bản cũ (409 `INK_CONFLICT`); ở đây ta hợp
/// nhất, và khi không hợp nhất được thì GIỮ CẢ HAI thành hai trang. Mất một
/// buổi ghi chép là thứ không có cách nào lấy lại.
@MainActor
final class DongBoVo: ObservableObject {
    static let shared = DongBoVo()

    enum TrangThai: Equatable {
        case nghi
        case dangDay(xong: Int, tong: Int)
        case loi(String)
        case xong(Date)
    }

    @Published private(set) var trangThai: TrangThai = .nghi
    @Published private(set) var soTrangChoDay = 0

    private var kho: ModelContext?
    private var dangChay = false
    /// Lượt đồng bộ đang chạy, giữ ở ĐÂY chứ không gắn vào view.
    private var viecDangChay: Task<Void, Never>?
    /// Lượt đã hẹn nhưng chưa tới giờ.
    private var viecDaHen: Task<Void, Never>?
    private var lanChayCuoi: Date?
    /// Số lần liên tiếp bị máy chủ từ chối vì gọi quá dày.
    private var soLanBiChan = 0

    private init() {}

    func gan(kho: ModelContext) { self.kho = kho }

    /// Khởi động một lượt đồng bộ KHÔNG gắn vào vòng đời của view.
    ///
    /// ⚠️⚠️ Đây là cách DUY NHẤT được gọi từ view. Viết
    /// `.task { await DongBoVo.shared.dongBo() }` thì lượt đẩy sống theo cái
    /// view đó: đóng màn viết là SwiftUI huỷ task, `URLSession` ném
    /// `CancellationError`, và huy hiệu hiện đúng một chữ **"cancelled"** —
    /// đo thật trên iPad mô phỏng 17/09/2026, lệnh xoá một trang không bao
    /// giờ tới được máy chủ vì lý do này.
    ///
    /// `Task {}` tạo ở đây là task KHÔNG cấu trúc: nó không bị huỷ theo task
    /// cha, nên lượt đẩy chạy tới cùng dù người dùng đã rời màn.
    /// ⚠️⚠️ GOM các lời gọi lại, đừng đẩy ngay mỗi lần.
    ///
    /// Nhập một PDF 3 trang là ba lần thêm trang, cộng lưu nét, cộng ghi âm
    /// — mỗi cái gọi `batDau()` một lần. Đo thật 17/09/2026 trên production:
    /// chuỗi đó ăn **"Too many requests. Please try again later."** và huy
    /// hiệu đỏ suốt, dù chẳng có gì hỏng. Máy chủ chặn đúng; lỗi ở nhịp gọi
    /// của app.
    ///
    /// Nhịp: cách lượt trước ít nhất `nhipToiThieu`; bị chặn thì lùi gấp đôi
    /// mỗi lần, tối đa 5 phút.
    private var nhipToiThieu: TimeInterval {
        soLanBiChan == 0 ? 6 : min(6 * pow(2, Double(soLanBiChan)), 300)
    }

    func batDau(keoVeTruoc: Bool = false) {
        guard viecDangChay == nil else { return }
        // Đã có lượt đang chờ thì thôi — nó sẽ gom cả thay đổi này.
        guard viecDaHen == nil else { return }

        let choThem = lanChayCuoi.map { nhipToiThieu - Date().timeIntervalSince($0) } ?? 0
        guard choThem > 0 else {
            chayNgay(keoVeTruoc: keoVeTruoc)
            return
        }
        viecDaHen = Task { [weak self] in
            try? await Task.sleep(for: .seconds(choThem))
            guard let self, !Task.isCancelled else { return }
            viecDaHen = nil
            chayNgay(keoVeTruoc: keoVeTruoc)
        }
    }

    private func chayNgay(keoVeTruoc: Bool) {
        guard viecDangChay == nil else { return }
        lanChayCuoi = Date()
        viecDangChay = Task { [weak self] in
            await self?.dongBo(keoVeTruoc: keoVeTruoc)
            self?.viecDangChay = nil
        }
    }

    // MARK: - Vòng đồng bộ

    /// Một vòng đầy đủ: đẩy cây → đẩy nét các trang bẩn → kéo về phần thiếu.
    ///
    /// An toàn khi gọi nhiều lần: `dangChay` chặn hai vòng chồng nhau. Hai
    /// vòng cùng lúc sẽ cùng thấy một trang là "cần đẩy" và cùng xin phiên
    /// bản mới — một trong hai chắc chắn ăn 409, và người dùng thấy một cảnh
    /// báo xung đột do chính app tự gây ra.
    func dongBo(keoVeTruoc: Bool = false) async {
        guard !dangChay, let kho else { return }
        guard TaiKhoanDangNhap() else { return }
        dangChay = true
        defer { dangChay = false }

        do {
            // ⚠️ XẢ HÀNG ĐỢI XOÁ TRƯỚC TIÊN, trước cả lượt kéo về. Kéo trước
            // thì máy chủ vẫn còn thứ vừa bị xoá và nó quay lại máy ngay
            // trong chính lượt này — người dùng xoá xong thấy nó hiện lại.
            try await xaHangDoiXoa(kho: kho)
            if keoVeTruoc { try await keoVe(kho: kho) }
            try await daySoCay(kho: kho)
            try await dayCacTrangBan(kho: kho)
            trangThai = .xong(Date())
            soLanBiChan = 0          // thông rồi thì trả nhịp về bình thường
            NhatKy.vo.info("đồng bộ xong")
        } catch let e as APIError where laQuaDay(e) {
            soLanBiChan += 1
            trangThai = .nghi        // KHÔNG hiện đỏ: không có gì hỏng, chỉ là gọi dày quá
            NhatKy.vo.info("máy chủ bảo gọi quá dày — lùi \(Int(nhipToiThieu))s rồi thử lại")
            batDau()                 // tự hẹn lại theo nhịp mới
        } catch is CancellationError {
            // Người dùng đóng app giữa chừng — không phải lỗi, và cũng không
            // mất gì: mọi thứ chưa đẩy vẫn còn cờ `canDay` để lượt sau làm lại.
            trangThai = .nghi
            NhatKy.vo.info("đồng bộ bị cắt giữa chừng, sẽ làm lại ở lượt sau")
        } catch {
            trangThai = .loi(moTaLoi(error))
            NhatKy.vo.error("đồng bộ hỏng: \(error.localizedDescription)")
        }
        capNhatSoCho(kho: kho)
    }

    private func TaiKhoanDangNhap() -> Bool {
        AppState.shared.currentUser != nil
    }

    /// Máy chủ từ chối vì gọi quá dày. Nhận theo MÃ và theo câu chữ, vì
    /// tầng chặn nhịp nằm ngoài `AppError` nên không phải lúc nào cũng có mã.
    private func laQuaDay(_ e: APIError) -> Bool {
        if case .coMa(let ma, _) = e, ma == "TOO_MANY_REQUESTS" || ma == "RATE_LIMITED" {
            return true
        }
        let m = e.localizedDescription.lowercased()
        return m.contains("too many requests") || m.contains("quá nhiều")
    }

    private func moTaLoi(_ e: Error) -> String {
        if let api = e as? APIError { return api.localizedDescription }
        // `URLError.cancelled` không phải `CancellationError` — nó là lượt
        // tải bị cắt, và câu chữ của nó cũng chỉ là "cancelled".
        if let u = e as? URLError, u.code == .cancelled {
            return T("Lượt đồng bộ bị cắt giữa chừng — sẽ thử lại")
        }
        return e.localizedDescription
    }

    private func capNhatSoCho(kho: ModelContext) {
        let d = FetchDescriptor<TrangVo>(predicate: #Predicate { $0.canDay })
        soTrangChoDay = (try? kho.fetchCount(d)) ?? 0
    }

    // MARK: - 0. Xả hàng đợi xoá

    private func xaHangDoiXoa(kho: ModelContext) async throws {
        let ds = try kho.fetch(FetchDescriptor<ViecXoaCho>())
        guard !ds.isEmpty else { return }

        // Gom mọi lệnh xoá TRANG vào MỘT lời gọi: xoá cả cuốn 200 trang mà
        // bắn 200 request thì vừa chậm vừa dễ đứt giữa chừng.
        let trangs = ds.filter { $0.loai == "trang" && $0.soLanHong < 5 }
        if !trangs.isEmpty {
            do {
                let _: KetQuaXoa = try await APIClient.shared.request(
                    .voXoaTrang(clientIds: trangs.map(\.maDoiTuong)))
                for v in trangs { kho.delete(v) }
            } catch {
                for v in trangs { v.soLanHong += 1 }
                NhatKy.vo.error("xoá \(trangs.count) trang trên máy chủ hỏng: \(error.localizedDescription)")
            }
        }

        for v in ds where v.loai == "cuon" && v.soLanHong < 5 {
            do {
                let _: KetQuaXoa = try await APIClient.shared.request(.voXoaCuon(clientId: v.maDoiTuong))
                kho.delete(v)
            } catch {
                v.soLanHong += 1
                NhatKy.vo.error("xoá cuốn vở trên máy chủ hỏng: \(error.localizedDescription)")
            }
        }

        // Thử 5 lần vẫn hỏng thì bỏ — nhiều khả năng thứ đó đã bị xoá ở máy
        // khác rồi. Giữ lại chỉ tổ làm mỗi lượt đồng bộ chậm thêm mãi mãi.
        for v in ds where v.soLanHong >= 5 { kho.delete(v) }
        try kho.save()
    }

    /// Ghi nhận một lệnh xoá để đẩy lên máy chủ sau. Gọi NGAY khi người dùng
    /// bấm xoá, cùng lúc với việc xoá bản cục bộ.
    static func ghiNhanXoa(kho: ModelContext, maDoiTuong: String, loai: String) {
        kho.insert(ViecXoaCho(maDoiTuong: maDoiTuong, loai: loai))
    }

    // MARK: - 0. Đẩy NỀN tài liệu

    /// Đẩy mọi tệp nền chưa từng lên mây.
    ///
    /// Khoá đánh theo sha256 nội dung nên một PDF nhập thành 20 trang chỉ
    /// tốn MỘT lượt tải lên — 19 trang sau nhận `daCo: true` và chỉ ghi con
    /// trỏ. Nhập lại đúng tệp đó lần sau tốn KHÔNG lượt nào.
    private func dayNenChuaLen(mons: [MonVo]) async {
        var daXong: [String: String] = [:]   // tên tệp trên máy → khoá R2

        for mon in mons {
            for cuon in mon.cuonsTheoThuTu {
                for trang in cuon.trangsTheoThuTu {
                    guard trang.nenKhoaR2 == nil else { continue }
                    let ten: String
                    let loai: String
                    if let t = trang.nenPdfTen { ten = t; loai = "pdf" }
                    else if let t = trang.nenAnhTen { ten = t; loai = "img" }
                    else { continue }

                    // Trang cùng một tệp thì dùng lại kết quả, khỏi băm lại.
                    if let khoa = daXong[ten] {
                        trang.nenKhoaR2 = khoa
                        trang.nenLoaiR2 = loai
                        continue
                    }

                    let duong = KhoVo.duongDanNen(ten)
                    guard let du = try? Data(contentsOf: duong) else {
                        NhatKy.vo.info("nền: không đọc được \(ten), bỏ qua")
                        continue
                    }
                    let sha = SHA256.hash(data: du).map { String(format: "%02x", $0) }.joined()
                    let duoi = (ten as NSString).pathExtension.lowercased()
                    let duoiGui = duoi == "pdf" ? "pdf" : (duoi == "png" ? "png" : "jpg")

                    do {
                        let d: DuongNen = try await APIClient.shared.request(
                            .voXinDuongNen(sha256: sha, duoi: duoiGui, soByte: du.count))
                        if !d.daCo, let url = d.url {
                            let kieu = duoiGui == "pdf" ? "application/pdf"
                                     : (duoiGui == "png" ? "image/png" : "image/jpeg")
                            try await putR2(du, toi: url, kieu: kieu)
                        }
                        trang.nenKhoaR2 = d.khoa
                        trang.nenLoaiR2 = loai
                        daXong[ten] = d.khoa
                        NhatKy.vo.info("nền: \(d.daCo ? "đã có sẵn" : "đã đẩy") \(ten)")
                    } catch {
                        // Nền hỏng KHÔNG được chặn cả lượt đồng bộ: nét vẽ
                        // quan trọng hơn, và lượt sau sẽ thử lại.
                        NhatKy.vo.info("nền: đẩy hỏng \(ten) — \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // MARK: - 1. Đẩy cây

    private func daySoCay(kho: ModelContext) async throws {
        let mons = try kho.fetch(FetchDescriptor<MonVo>())
        guard !mons.isEmpty else { return }

        // Nền phải lên TRƯỚC cây: payload cây mang con trỏ `nenKhoa`, mà con
        // trỏ chỉ có sau khi tệp đã nằm trên R2. Làm ngược lại thì máy chủ
        // nhận một khoá trỏ vào hư không.
        await dayNenChuaLen(mons: mons)

        let payload: [[String: Any]] = mons.map { mon in
            [
                "clientId": mon.id.uuidString,
                "ten": mon.ten,
                "emoji": mon.emoji,
                "mauHex": mon.mauHex,
                "thuTu": mon.thuTu,
                "ghim": mon.ghim,
                "cuons": mon.cuonsTheoThuTu.map { cuon in
                    [
                        "clientId": cuon.id.uuidString,
                        "ten": cuon.ten,
                        "mauBiaHex": cuon.mauBiaHex,
                        "giayMacDinh": cuon.giayMacDinh,
                        "thuTu": cuon.thuTu,
                        "ghim": cuon.ghim,
                        "trangs": cuon.trangsTheoThuTu.map { trang in
                            [
                                "clientId": trang.id.uuidString,
                                "thuTu": trang.thuTu,
                                "tenChuong": trang.tenChuong as Any,
                                "giay": trang.loaiGiay,
                                "huong": trang.huongGiay,
                                "phienBanNet": trang.phienBanNet,
                                // Con trỏ nền. Chỉ gửi khi đã đẩy tệp lên —
                                // `nenKhoa` rỗng nghĩa là GỠ nền, còn không
                                // gửi gì cả thì máy chủ giữ nguyên bản cũ.
                                "nenKhoa": trang.nenKhoaR2 as Any,
                                "nenLoai": trang.nenLoaiR2 as Any,
                                "nenTrang": trang.nenPdfTrang,
                            ] as [String: Any]
                        },
                    ] as [String: Any]
                },
            ]
        }

        let ket: KetQuaDongBoCay = try await APIClient.shared.request(.voDongBoCay(mons: payload))

        // Ghi id máy chủ về từng nút, và ghi nhận trang nào máy chủ đang giữ
        // bản mới hơn — những trang đó KHÔNG được đẩy đè ở bước sau.
        var theoId: [UUID: TrangVo] = [:]
        for mon in mons {
            for cuon in mon.cuonsTheoThuTu {
                for trang in cuon.trangsTheoThuTu { theoId[trang.id] = trang }
            }
        }
        var monTheoId: [UUID: MonVo] = Dictionary(uniqueKeysWithValues: mons.map { ($0.id, $0) })
        var cuonTheoId: [UUID: CuonVo] = [:]
        for mon in mons { for c in mon.cuonsTheoThuTu { cuonTheoId[c.id] = c } }

        for m in ket.mons {
            if let uid = UUID(uuidString: m.clientId), let mon = monTheoId[uid] {
                mon.idMayChu = m.id
                mon.canDayCay = false
            }
            for c in m.cuons {
                if let uid = UUID(uuidString: c.clientId), let cuon = cuonTheoId[uid] {
                    cuon.idMayChu = c.id
                    cuon.canDayCay = false
                }
                for t in c.trangs {
                    guard let uid = UUID(uuidString: t.clientId), let trang = theoId[uid] else { continue }
                    trang.idMayChu = t.id
                    if t.xungDot {
                        trang.vuongXungDot = true
                    } else if t.inkVersion > trang.phienBanNet && !trang.canDay {
                        // Máy chủ mới hơn mà máy này không có gì chưa đẩy ⇒
                        // chỉ việc tải về, không phải xung đột.
                        await keoNetVe(trang: trang, tuUrl: t.inkUrl, phienBan: t.inkVersion)
                    }
                }
            }
        }
        try kho.save()
    }

    // MARK: - 2. Đẩy nét vẽ

    private func dayCacTrangBan(kho: ModelContext) async throws {
        let ds = try kho.fetch(FetchDescriptor<TrangVo>(
            predicate: #Predicate { $0.canDay }
        ))
        let canDay = ds.filter { $0.idMayChu != nil }
        guard !canDay.isEmpty else { trangThai = .nghi; return }

        var xong = 0
        for trang in canDay {
            trangThai = .dangDay(xong: xong, tong: canDay.count)
            do {
                try await dayMotTrang(trang)
            } catch let e as APIError {
                if truongHopXungDot(e) {
                    try await hopNhatXungDot(trang: trang, kho: kho)
                } else {
                    throw e
                }
            }
            xong += 1
        }
        try kho.save()
        trangThai = .nghi
    }

    private func truongHopXungDot(_ e: APIError) -> Bool {
        if case .coMa(let ma, _) = e { return ma == "INK_CONFLICT" }
        return false
    }

    private func dayMotTrang(_ trang: TrangVo) async throws {
        guard let idMayChu = trang.idMayChu else { return }

        let net = KhoVo.nap(trang.id)
        let duLieuNet = net.dataRepresentation()
        let anhNho = KhoVo.anhNho(trang.id)?.pngData()

        let duong: DuongDay = try await APIClient.shared.request(
            .voXinDuongDay(trangId: idMayChu, coAnhXemTruoc: anhNho != nil))

        // ⚠️ `Content-Type` PHẢI khớp CHÍNH XÁC chuỗi máy chủ đã ký
        // (`getSignedUploadUrl` ký cả header này). Lệch một ký tự là R2 trả
        // 403, và thông báo của nó không nhắc gì tới content type.
        try await putR2(duLieuNet, toi: duong.inkUrl, kieu: "application/octet-stream")
        if let anhNho, let urlAnh = duong.previewUrl {
            // Ảnh xem trước hỏng thì BỎ QUA, không huỷ cả lượt đẩy: mất hình
            // trên web đổi lấy mất nét vẽ là đánh đổi sai.
            try? await putR2(anhNho, toi: urlAnh, kieu: "image/png")
        }

        let than: [String: Any] = [
            "inkKey": duong.inkKey,
            "previewKey": duong.previewKey as Any,
            "phienBanDuaTren": trang.phienBanNet,
            "soNet": net.strokes.count,
        ]
        let ket: KetQuaXacNhan = try await APIClient.shared.request(
            .voXacNhanNet(trangId: idMayChu, than: than))

        trang.phienBanNet = ket.inkVersion
        trang.soNetDaDay = net.strokes.count
        trang.canDay = false
        trang.vuongXungDot = false
        trang.dayLuc = Date()
    }

    private func putR2(_ data: Data, toi url: String, kieu: String) async throws {
        guard let u = URL(string: url) else { throw APIError.invalidURL }
        var req = URLRequest(url: u)
        req.httpMethod = "PUT"
        req.setValue(kieu, forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 60
        let (_, resp) = try await URLSession.shared.upload(for: req, from: data)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let ma = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError.serverError("Tải nét vẽ lên kho thất bại (HTTP \(ma))")
        }
    }

    // MARK: - 3. Hợp nhất khi xung đột

    /// Máy khác đã ghi trang này trong lúc máy mình viết.
    ///
    /// Hợp nhất theo **TIỀN TỐ NÉT**: `soNetDaDay` nét đầu là phần hai bên
    /// cùng có; từ đó trở đi là phần máy này viết thêm. Ghép phần thêm đó
    /// vào bản máy chủ là ra bản đủ cả hai.
    ///
    /// ⚠️ Chỉ đúng khi máy này CHỈ VẼ THÊM. Nếu người dùng đã tẩy hoặc dùng
    /// lasso di chuyển, tiền tố không còn nguyên và phép ghép sẽ nhân đôi
    /// hoặc làm sống lại nét đã xoá. Trường hợp đó **giữ CẢ HAI thành hai
    /// trang** rồi để người dùng tự quyết — xấu, nhưng không mất gì.
    private func hopNhatXungDot(trang: TrangVo, kho: ModelContext) async throws {
        guard let idMayChu = trang.idMayChu else { return }
        NhatKy.vo.info("xung đột ở trang \(trang.id.uuidString), bắt đầu hợp nhất")

        let cay: CayVoTaiVe = try await APIClient.shared.request(.voLayCay)
        guard let tMayChu = cay.mons
            .flatMap({ $0.cuons }).flatMap({ $0.trangs })
            .first(where: { $0.id == idMayChu }),
              let urlNet = tMayChu.inkUrl,
              let banMayChu = await taiNet(urlNet) else {
            trang.vuongXungDot = true
            return
        }

        let banLocal = KhoVo.nap(trang.id)
        let chiVeThem = banLocal.strokes.count >= trang.soNetDaDay
            && trang.soNetDaDay <= banMayChu.strokes.count

        if chiVeThem {
            let netThem = Array(banLocal.strokes[trang.soNetDaDay...])
            let gop = banMayChu.appending(PKDrawing(strokes: netThem))
            KhoVo.ghi(gop, cho: trang.id)
            trang.phienBanNet = tMayChu.inkVersion
            trang.soNetDaDay = gop.strokes.count
            trang.canDay = true          // đẩy lại bản đã gộp
            trang.vuongXungDot = false
            KhoVo.dungAnhNho(gop, kho: trang.khoTrang, cho: trang.id,
                             nenPdfTen: trang.nenPdfTen, nenPdfTrang: trang.nenPdfTrang,
                             nenAnhTen: trang.nenAnhTen)
            NhatKy.vo.info("gộp được \(netThem.count) nét vào bản máy chủ")
            try await dayMotTrang(trang)
        } else {
            // Không suy ra được ⇒ tách đôi. Bản máy chủ nằm lại đúng chỗ cũ,
            // bản của máy này thành một trang mới ngay sau nó.
            let trangMoi = TrangVo(cuon: trang.cuon, thuTu: trang.thuTu + 1,
                                   giay: trang.giay, huong: trang.huong)
            trangMoi.tenChuong = T("Bản của máy này") + " — " + (trang.tenChuong ?? "")
            kho.insert(trangMoi)
            for khac in trang.cuon?.trangsTheoThuTu ?? []
            where khac.thuTu > trang.thuTu && khac.id != trangMoi.id {
                khac.thuTu += 1
            }
            KhoVo.nhanBan(tu: trang.id, sang: trangMoi.id)
            trangMoi.coNet = true
            trangMoi.canDay = true

            KhoVo.ghi(banMayChu, cho: trang.id)
            KhoVo.dungAnhNho(banMayChu, kho: trang.khoTrang, cho: trang.id,
                             nenPdfTen: trang.nenPdfTen, nenPdfTrang: trang.nenPdfTrang,
                             nenAnhTen: trang.nenAnhTen)
            trang.phienBanNet = tMayChu.inkVersion
            trang.soNetDaDay = banMayChu.strokes.count
            trang.canDay = false
            trang.vuongXungDot = false
            NhatKy.vo.info("không gộp được (có tẩy/sửa) — đã tách thành hai trang")
        }
        try kho.save()
    }

    // MARK: - 4. Kéo về

    private func keoVe(kho: ModelContext) async throws {
        let cay: CayVoTaiVe = try await APIClient.shared.request(.voLayCay)
        let monsCo = try kho.fetch(FetchDescriptor<MonVo>())
        var monTheoId = Dictionary(uniqueKeysWithValues: monsCo.map { ($0.id, $0) })
        var cuonTheoId: [UUID: CuonVo] = [:]
        var trangTheoId: [UUID: TrangVo] = [:]
        for m in monsCo {
            for c in m.cuonsTheoThuTu {
                cuonTheoId[c.id] = c
                for t in c.trangsTheoThuTu { trangTheoId[t.id] = t }
            }
        }

        for m in cay.mons {
            guard let uid = UUID(uuidString: m.clientId) else { continue }
            let mon: MonVo
            if let co = monTheoId[uid] {
                mon = co
            } else {
                mon = MonVo(ten: m.ten, emoji: m.emoji ?? "📘",
                            mauHex: hexSangSo(m.mauHex) ?? 0x7A45E8, thuTu: m.thuTu)
                mon.id = uid
                mon.idMayChu = m.id
                mon.canDayCay = false
                kho.insert(mon)
                monTheoId[uid] = mon
            }

            for c in m.cuons {
                guard let cuid = UUID(uuidString: c.clientId) else { continue }
                let cuon: CuonVo
                if let co = cuonTheoId[cuid] {
                    cuon = co
                } else {
                    cuon = CuonVo(ten: c.ten, mon: mon,
                                  mauBiaHex: hexSangSo(c.mauBiaHex) ?? mon.mauHex,
                                  giay: LoaiGiay(rawValue: c.giayMacDinh ?? "") ?? .keNgang,
                                  huong: .doc, thuTu: c.thuTu)
                    cuon.id = cuid
                    cuon.idMayChu = c.id
                    cuon.canDayCay = false
                    kho.insert(cuon)
                    cuonTheoId[cuid] = cuon
                }

                for t in c.trangs {
                    guard let tuid = UUID(uuidString: t.clientId) else { continue }
                    if let co = trangTheoId[tuid] {
                        // ⚠️ Trang đã có trên máy mà đang BẨN thì KHÔNG đè.
                        // Nó sẽ đi qua đường xung đột ở lượt đẩy, nơi có phép
                        // hợp nhất. Đè ở đây là xoá thẳng thứ vừa viết.
                        if !co.canDay && t.inkVersion > co.phienBanNet {
                            await keoNetVe(trang: co, tuUrl: t.inkUrl, phienBan: t.inkVersion)
                        }
                        await keoNenVe(trang: co, t)
                        continue
                    }
                    let trang = TrangVo(cuon: cuon, thuTu: t.thuTu,
                                        giay: LoaiGiay(rawValue: t.giay ?? "") ?? .keNgang,
                                        huong: HuongGiay(rawValue: t.huong ?? "") ?? .doc)
                    trang.id = tuid
                    trang.idMayChu = t.id
                    trang.tenChuong = t.tenChuong
                    trang.canDay = false
                    kho.insert(trang)
                    trangTheoId[tuid] = trang
                    await keoNetVe(trang: trang, tuUrl: t.inkUrl, phienBan: t.inkVersion)
                    await keoNenVe(trang: trang, t)
                }
            }
        }
        try kho.save()
    }

    /// Tải NỀN tài liệu về máy này nếu chưa có.
    ///
    /// Tệp lưu theo tên = phần cuối của khoá R2 (đã mang sha256), nên hai
    /// trang cùng nguồn dùng chung một tệp và tải một lần. Có tệp rồi thì
    /// chỉ ghi lại con trỏ, không tải lại.
    private func keoNenVe(trang: TrangVo, _ t: TrangTaiVe) async {
        guard let url = t.nenUrl, let loai = t.nenLoai else { return }
        // Tên tệp lấy từ URL: nó chính là `<sha256>.<đuôi>`.
        guard let u = URL(string: url) else { return }
        let ten = u.lastPathComponent
        guard !ten.isEmpty else { return }

        trang.nenPdfTrang = t.nenTrang ?? 0
        trang.nenLoaiR2 = loai
        trang.nenKhoaR2 = trang.nenKhoaR2 ?? "notes/bg/\(ten)"

        let dich = KhoVo.duongDanNen(ten)
        if !FileManager.default.fileExists(atPath: dich.path) {
            do {
                let (du, _) = try await URLSession.shared.data(from: u)
                try du.write(to: dich, options: .atomic)
                NhatKy.vo.info("nền: đã tải về \(ten) (\(du.count) byte)")
            } catch {
                NhatKy.vo.info("nền: tải về hỏng \(ten) — \(error.localizedDescription)")
                return
            }
        }
        if loai == "pdf" { trang.nenPdfTen = ten } else { trang.nenAnhTen = ten }
    }

    /// Nhận URL + phiên bản rời rạc chứ không nhận một struct cụ thể: hai
    /// endpoint (`/vo` và `/vo/sync`) trả về hai hình dạng khác nhau cho
    /// cùng một trang, và buộc chúng chung một kiểu chỉ để gọi được hàm này
    /// là tạo thêm một chỗ nữa phải sửa mỗi lần backend đổi payload.
    private func keoNetVe(trang: TrangVo, tuUrl url: String?, phienBan: Int) async {
        guard let url, let net = await taiNet(url) else { return }
        KhoVo.ghi(net, cho: trang.id)
        KhoVo.dungAnhNho(net, kho: trang.khoTrang, cho: trang.id,
                             nenPdfTen: trang.nenPdfTen, nenPdfTrang: trang.nenPdfTrang,
                             nenAnhTen: trang.nenAnhTen)
        trang.phienBanNet = phienBan
        trang.soNetDaDay = net.strokes.count
        trang.coNet = !net.strokes.isEmpty
        trang.canDay = false
        trang.suaLuc = Date()
    }

    private func taiNet(_ url: String) async -> PKDrawing? {
        guard let u = URL(string: url) else { return nil }
        do {
            let (data, resp) = try await URLSession.shared.data(from: u)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return try PKDrawing(data: data)
        } catch {
            NhatKy.vo.error("tải nét vẽ hỏng: \(error.localizedDescription)")
            return nil
        }
    }

    private func hexSangSo(_ hex: String?) -> Int? {
        guard var s = hex else { return nil }
        if s.hasPrefix("#") { s.removeFirst() }
        return Int(s, radix: 16)
    }

    // MARK: - Đánh dấu bẩn

    /// Gọi mỗi khi một trang được ghi xuống đĩa.
    static func danhDauBan(_ trang: TrangVo) {
        trang.canDay = true
    }
}

// MARK: - Hình dạng payload

private struct KetQuaDongBoCay: Decodable {
    struct Mon: Decodable { let clientId: String; let id: Int; let cuons: [Cuon] }
    struct Cuon: Decodable { let clientId: String; let id: Int; let trangs: [Trang] }
    struct Trang: Decodable {
        let clientId: String
        let id: Int
        let inkVersion: Int
        let inkStrokeCount: Int
        let inkUrl: String?
        let previewUrl: String?
        let xungDot: Bool
        let nenUrl: String?
        let nenLoai: String?
        let nenTrang: Int?
    }
    let mons: [Mon]
}

private struct DuongDay: Decodable {
    let inkKey: String
    let inkUrl: String
    let previewKey: String?
    let previewUrl: String?
    let phienBanMoi: Int
}

private struct DuongNen: Decodable {
    let khoa: String
    let url: String?
    let daCo: Bool
}

private struct KetQuaXoa: Decodable { let daXoa: Int }

private struct KetQuaXacNhan: Decodable {
    let inkVersion: Int
    let inkUrl: String
    let previewUrl: String?
}

struct TrangTaiVe: Decodable {
    let clientId: String
    let id: Int
    let thuTu: Int
    let tenChuong: String?
    let giay: String?
    let huong: String?
    let inkVersion: Int
    let inkStrokeCount: Int
    let inkUrl: String?
    let previewUrl: String?
    let nenUrl: String?
    let nenLoai: String?
    let nenTrang: Int?
}

private struct CayVoTaiVe: Decodable {
    struct Mon: Decodable {
        let clientId: String; let id: Int; let ten: String
        let emoji: String?; let mauHex: String?; let thuTu: Int; let ghim: Bool
        let cuons: [Cuon]
    }
    struct Cuon: Decodable {
        let clientId: String; let id: Int; let ten: String
        let mauBiaHex: String?; let giayMacDinh: String?; let thuTu: Int; let ghim: Bool
        let trangs: [TrangTaiVe]
    }
    let mons: [Mon]
}
#endif
