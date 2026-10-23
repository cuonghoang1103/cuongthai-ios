#if os(iOS)
import Combine
import PencilKit
import SwiftUI
import UIKit

// MARK: - "Viết lên bài" bằng Apple Pencil (24/10/2026)
//
// Một lớp mực trong suốt ĐÈ lên bài đang đọc. Yêu cầu khó: nét phải đi theo nội dung khi cuộn, và không lệch khi
// đổi cỡ chữ / xoay máy / mở cột Vở bên cạnh. Cách làm:
//
// • KHÔNG một canvas cho cả trang. Mỗi KHỐI nội dung (mỗi phần tử của LazyVStack: một nhóm khối, một hàng bảng,
//   một câu trắc nghiệm…) có canvas RIÊNG đặt bằng `.overlay` ⇒ canvas là con của chính khối đó, cuộn theo nó,
//   LazyVStack dựng/bỏ nó cùng khối. Khoá nét = <bài>/<id khối> (`.vietDe("n3")`, `.vietDeCon("r2")`).
// • Lưu kèm BỀ NGANG + CỠ CHỮ lúc vẽ. Hiện ở bề ngang khác ⇒ `CoGianVietDe` co giãn từng nét theo tỉ lệ (hình nét
//   giữ dáng, vị trí theo tỉ lệ), nên khối hẹp lại thì nét co lại đúng chỗ trong khối.
// • Chỉ dựng canvas khi đang bật "Viết lên bài", hoặc khi khối đó ĐÃ có nét (và lớp đang hiện). Bài chưa từng viết
//   ⇒ overlay rỗng, cuộn không chậm đi (bài Chữ Hán đã tối ưu ở ecb368e/4132d9c).
// • Pencil vẽ, ngón tay cuộn: `drawingPolicy = .pencilOnly`; ScrollView cha thôi nhận Pencil (`allowedTouchTypes`)
//   để bút không kéo trang đi giữa nét; chạm NGÓN TAY lên canvas đi xuyên xuống nội dung (`hitTest`) nên nút trong
//   bài vẫn bấm được. Máy chưa từng thấy Pencil (iPhone, máy ảo) ⇒ `.pencilOnly` là canvas CHẾT (bẫy đã gặp
//   17/09) — có công tắc "✋ Vẽ bằng ngón tay" nói rõ trên thanh công cụ (bật thì cuộn bằng HAI ngón).
//
// Lưu CỤC BỘ: `Documents/GhiKhiHoc/vietde/<bài>.json` (mỗi khối: nét PKDrawing + bề ngang + cỡ chữ). Chưa đồng bộ
// lên máy chủ — máy chủ không có bảng cho lớp này; đi qua Vở thì phải bịa ra trang giả.

// MARK: Lưu

/// Nét của MỘT khối + kích thước lúc vẽ.
struct NetKhoiVietDe: Codable, Equatable {
    var net: Data
    /// Bề ngang khối (pt) lúc vẽ.
    var rong: Double
    /// Hệ số cỡ chữ lúc vẽ (cỡ chữ đọc × Dynamic Type).
    var coChu: Double
    var luc: Date

    init(net: Data, rong: Double, coChu: Double, luc: Date = Date()) {
        self.net = net; self.rong = rong; self.coChu = coChu; self.luc = luc
    }

    // ⚠️ Viết tay, mọi khoá `decodeIfPresent` — thêm trường sau này không làm mất tệp cũ.
    private enum K: String, CodingKey { case net, rong, coChu, luc }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        net = (try? c.decodeIfPresent(Data.self, forKey: .net)) ?? Data()
        rong = (try? c.decodeIfPresent(Double.self, forKey: .rong)) ?? 0
        coChu = (try? c.decodeIfPresent(Double.self, forKey: .coChu)) ?? 1
        luc = (try? c.decodeIfPresent(Date.self, forKey: .luc)) ?? Date()
    }
}

/// Tệp của một bài.
struct TepVietDe: Codable {
    var phienBan: Int = 1
    var khoi: [String: NetKhoiVietDe] = [:]

    init(khoi: [String: NetKhoiVietDe] = [:]) { self.khoi = khoi }
    private enum K: String, CodingKey { case phienBan, khoi }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        phienBan = (try? c.decodeIfPresent(Int.self, forKey: .phienBan)) ?? 1
        khoi = (try? c.decodeIfPresent([String: NetKhoiVietDe].self, forKey: .khoi)) ?? [:]
    }
}

enum KhoVietDe {
    static var thuMuc: URL {
        let doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let u = doc.appendingPathComponent("GhiKhiHoc/vietde", isDirectory: true)
        if !FileManager.default.fileExists(atPath: u.path) {
            try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        }
        return u
    }

    /// Tên tệp an toàn cho một khoá bài ("dekiru/b0-hiragana" ⇒ "dekiru_b0-hiragana"). Khoá dài/lạ thì thêm băm
    /// ổn định (FNV-1a, không dùng `hashValue` — nó đổi mỗi lần chạy app).
    static func tenTep(_ khoaBai: String) -> String {
        let cho = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
        let sach = String(khoaBai.map { cho.contains($0) ? $0 : "_" }.prefix(80))
        var h: UInt64 = 0xcbf29ce484222325
        for b in khoaBai.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        return "\(sach)-\(String(h, radix: 36)).json"
    }

    static func duongDan(_ khoaBai: String) -> URL { thuMuc.appendingPathComponent(tenTep(khoaBai)) }

    static func doc(_ khoaBai: String) -> [String: NetKhoiVietDe] {
        let u = duongDan(khoaBai)
        guard let d = try? Data(contentsOf: u), !d.isEmpty else { return [:] }
        do {
            let dec = JSONDecoder(); dec.dateDecodingStrategy = .secondsSince1970
            return try dec.decode(TepVietDe.self, from: d).khoi
        } catch {
            NhatKy.vo.error("viết lên bài: đọc \(u.lastPathComponent) hỏng — \(error.localizedDescription); giữ bản .hong")
            try? FileManager.default.moveItem(at: u, to: u.appendingPathExtension("hong"))
            return [:]
        }
    }

    static func ghi(_ khoaBai: String, _ khoi: [String: NetKhoiVietDe]) {
        let u = duongDan(khoaBai)
        if khoi.isEmpty { try? FileManager.default.removeItem(at: u); return }
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .secondsSince1970
        guard let d = try? enc.encode(TepVietDe(khoi: khoi)) else { return }
        do { try d.write(to: u, options: .atomic) } catch {
            NhatKy.vo.error("viết lên bài: ghi hỏng — \(error.localizedDescription)")
        }
    }
}

// MARK: Co giãn theo bề ngang / cỡ chữ (thuần — có kiểm thử)

enum CoGianVietDe {
    /// Tỉ lệ (x, y) để đưa nét vẽ ở (rongGoc, coGoc) sang (rong, co). x theo bề ngang; y theo bề ngang × cỡ chữ
    /// (chữ to hơn ⇒ khối cao hơn theo đúng tỉ lệ cỡ chữ khi số dòng giữ nguyên).
    static func tiLe(tuRong rongGoc: CGFloat, tuCo coGoc: CGFloat, sangRong rong: CGFloat, sangCo co: CGFloat) -> (x: CGFloat, y: CGFloat) {
        guard rongGoc > 1, rong > 1 else { return (1, 1) }
        let sx = rong / rongGoc
        let sc = (coGoc > 0 && co > 0) ? co / coGoc : 1
        return (sx, sx * sc)
    }

    /// Co giãn từng nét: TÂM nét đi theo (sx, sy), HÌNH nét co đều theo sx — chữ viết tay không bị kéo méo.
    static func bienDoi(_ d: PKDrawing, tuRong rongGoc: CGFloat, tuCo coGoc: CGFloat,
                        sangRong rong: CGFloat, sangCo co: CGFloat) -> PKDrawing {
        let (sx, sy) = tiLe(tuRong: rongGoc, tuCo: coGoc, sangRong: rong, sangCo: co)
        guard abs(sx - 1) > 0.002 || abs(sy - 1) > 0.002 else { return d }
        var ds = d.strokes
        for i in ds.indices {
            let b = ds[i].renderBounds
            guard !b.isNull, !b.isInfinite else { continue }
            let c = CGPoint(x: b.midX, y: b.midY)
            let t = CGAffineTransform(translationX: -c.x, y: -c.y)
                .concatenating(CGAffineTransform(scaleX: sx, y: sx))
                .concatenating(CGAffineTransform(translationX: c.x * sx, y: c.y * sy))
            ds[i].transform = ds[i].transform.concatenating(t)
        }
        return PKDrawing(strokes: ds)
    }
}

// MARK: Công cụ

enum CongCuVietDe: Equatable {
    case but(Int)      // chỉ số trong `CongCuVietDe.mauBut`
    case toSang
    case tay

    static let mauBut: [UIColor] = [.black, .systemBlue, .systemRed]
    static let tenMau = ["Đen", "Xanh", "Đỏ"]

    var pk: PKTool {
        switch self {
        case .but(let i):
            return PKInkingTool(.pen, color: Self.mauBut[min(max(0, i), Self.mauBut.count - 1)], width: 2.6)
        case .toSang:
            return PKInkingTool(.marker, color: UIColor.systemYellow.withAlphaComponent(0.85), width: 18)
        case .tay:
            return PKEraserTool(.vector)
        }
    }
}

// MARK: Phiên viết của một bài

/// Trạng thái "Viết lên bài" của MỘT màn bài. Màn bài giữ nó bằng `@State` (KHÔNG `@StateObject`): màn bài không
/// được dựng lại mỗi lần đổi bút — chỉ thanh công cụ và lớp phủ các khối quan sát nó.
@MainActor
final class PhienVietDe: ObservableObject {
    @Published private(set) var khoaBai: String?
    /// Đang bật chế độ viết (canvas nhận bút).
    @Published var dangViet = false { didSet { if dangViet != oldValue { doiCheDoCuon() } } }
    /// Lớp nét đang HIỆN (ẩn/hiện mà không mất).
    @Published var hienLop = true
    @Published var congCu: CongCuVietDe = .but(0)
    /// Máy chưa có Pencil: ngón tay vẽ, HAI ngón cuộn.
    @Published var ngonTayVe: Bool { didSet { UserDefaults.standard.set(ngonTayVe, forKey: Self.khoaNgonTay); doiCheDoCuon() } }
    /// Các khối đang có nét (để biết khối nào cần dựng canvas khi chưa bật chế độ viết).
    @Published private(set) var khoiCoNet: Set<String> = []
    @Published private(set) var coThe: Bool = false

    /// Khối có dữ liệu đổi từ NGOÀI canvas (hoàn tác, xoá hết) ⇒ canvas đang sống của khối đó nạp lại.
    let napLaiKhoi = PassthroughSubject<String, Never>()

    private var du: [String: NetKhoiVietDe] = [:]
    private var lichSu: [(khoi: String, cu: NetKhoiVietDe?)] = []
    private var henGhi: Task<Void, Never>?
    private var daBan = false

    static let khoaNgonTay = "ghikhihoc.vietde.ngontay"
    /// Phiên rỗng cho màn KHÔNG có lớp viết đè (để view quan sát không phải nhận optional).
    static let khong = PhienVietDe()

    init() {
        let d = UserDefaults.standard
        // iPhone không có Pencil ⇒ mặc định ngón tay vẽ. iPad mặc định CHỈ Pencil (ngón tay để cuộn bài).
        ngonTayVe = d.object(forKey: Self.khoaNgonTay) as? Bool ?? (UIDevice.current.userInterfaceIdiom == .phone)
    }

    /// Màn bài giữ phiên bằng `@State` ⇒ SwiftUI dựng (rồi bỏ) một phiên mới mỗi lần khởi tạo struct màn. Chỉ phiên
    /// THẬT SỰ được dùng (`doiBai`) mới đăng ký nghe app xuống nền — và gỡ token khi bị huỷ.
    private var tokenNen: NSObjectProtocol?
    deinit { if let t = tokenNen { NotificationCenter.default.removeObserver(t) } }

    var coNet: Bool { !khoiCoNet.isEmpty }
    var coHoanTac: Bool { !lichSu.isEmpty }

    /// Mở (hoặc đổi sang) bài `khoa`. Bài cũ ghi xuống đĩa trước.
    func doiBai(_ khoa: String?) {
        if tokenNen == nil {
            tokenNen = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                                              object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.ghiNgay() }
            }
        }
        guard khoa != khoaBai else { return }
        ghiNgay()
        khoaBai = khoa
        du = khoa.map { KhoVietDe.doc($0) } ?? [:]
        lichSu = []
        #if DEBUG
        // Màn soi: `CT_GHI_MAU=1` ⇒ bài chưa có nét thì điền nét MẪU (vẽ ở bề ngang 688 — cột đọc iPad 11" dọc) vào
        // vài khối đầu, để soi nét đi theo khối khi cuộn / đổi bề ngang / đổi cỡ chữ (máy ảo không có Pencil).
        if du.isEmpty, ProcessInfo.processInfo.environment["CT_GHI_MAU"] == "1" {
            for (i, k) in (ProcessInfo.processInfo.environment["CT_GHI_MAU_KHOI"] ?? "dau,n1,n2,n3,n4").split(separator: ",").enumerated() {
                du[String(k)] = NetKhoiVietDe(net: Self.netMau(i).dataRepresentation(), rong: 688, coChu: 1)
            }
            daBan = true   // ghi xuống đĩa như nét thật ⇒ lượt mở sau (không cờ) kiểm được "mở lại vẫn còn"
            henGhiXuong()
        }
        #endif
        khoiCoNet = Set(du.filter { !$0.value.net.isEmpty }.keys)
        coThe = khoa != nil
    }

    #if DEBUG
    /// Nét mẫu: vòng khoanh đỏ + gạch chân xanh + vệt tô sáng. Cỡ điểm 3pt (điểm < 2,4pt VÔ HÌNH trên iPad thật).
    static func netMau(_ i: Int) -> PKDrawing {
        func diem(_ p: CGPoint, _ t: Double, co: CGFloat = 3) -> PKStrokePoint {
            PKStrokePoint(location: p, timeOffset: t, size: CGSize(width: co, height: co), opacity: 1, force: 1,
                          azimuth: 0, altitude: .pi / 2)
        }
        var ds: [PKStroke] = []
        let cx: CGFloat = 90 + CGFloat(i % 3) * 170, cy: CGFloat = 26
        let vong = (0...40).map { k -> PKStrokePoint in
            let a = Double(k) / 40 * 2 * .pi
            return diem(CGPoint(x: cx + 70 * cos(a), y: cy + 22 * sin(a)), Double(k) * 0.01)
        }
        ds.append(PKStroke(ink: PKInk(.pen, color: .systemRed), path: PKStrokePath(controlPoints: vong, creationDate: Date())))
        let gach = (0...20).map { k in diem(CGPoint(x: 20 + CGFloat(k) * 16, y: 52 + CGFloat(k % 2) * 2), Double(k) * 0.01) }
        ds.append(PKStroke(ink: PKInk(.pen, color: .systemBlue), path: PKStrokePath(controlPoints: gach, creationDate: Date())))
        let sang = (0...12).map { k in diem(CGPoint(x: 360 + CGFloat(k) * 22, y: 14), Double(k) * 0.01, co: 16) }
        ds.append(PKStroke(ink: PKInk(.marker, color: UIColor.systemYellow.withAlphaComponent(0.85)),
                           path: PKStrokePath(controlPoints: sang, creationDate: Date())))
        return PKDrawing(strokes: ds)
    }
    #endif

    func coNet(_ khoi: String) -> Bool { khoiCoNet.contains(khoi) }

    /// Nét để HIỆN ở khối `khoi` với bề ngang/cỡ chữ hiện tại.
    func netHien(_ khoi: String, rong: CGFloat, coChu: CGFloat) -> PKDrawing {
        guard let n = du[khoi], !n.net.isEmpty, let d = try? PKDrawing(data: n.net) else { return PKDrawing() }
        return CoGianVietDe.bienDoi(d, tuRong: CGFloat(n.rong), tuCo: CGFloat(n.coChu), sangRong: rong, sangCo: coChu)
    }

    /// Canvas báo nét đổi (người dùng vẽ/tẩy).
    func capNhat(_ khoi: String, _ d: PKDrawing, rong: CGFloat, coChu: CGFloat) {
        lichSu.append((khoi, du[khoi]))
        if lichSu.count > 200 { lichSu.removeFirst(lichSu.count - 200) }
        if d.strokes.isEmpty {
            du[khoi] = nil
        } else {
            du[khoi] = NetKhoiVietDe(net: d.dataRepresentation(), rong: Double(rong), coChu: Double(coChu))
        }
        let co = !d.strokes.isEmpty
        if co != khoiCoNet.contains(khoi) {
            if co { khoiCoNet.insert(khoi) } else { khoiCoNet.remove(khoi) }
        }
        objectWillChange.send()   // nút Hoàn tác sáng lên
        henGhiXuong()
    }

    func hoanTac() {
        guard let (khoi, cu) = lichSu.popLast() else { return }
        du[khoi] = cu
        if cu == nil { khoiCoNet.remove(khoi) } else { khoiCoNet.insert(khoi) }
        objectWillChange.send()
        napLaiKhoi.send(khoi)
        henGhiXuong()
    }

    /// Xoá HẾT lớp ghi của bài này (đã hỏi xác nhận ở thanh công cụ). Hoàn tác được từng khối.
    func xoaHet() {
        for (k, v) in du { lichSu.append((k, v)) }
        let ds = Array(du.keys)
        du = [:]
        khoiCoNet = []
        for k in ds { napLaiKhoi.send(k) }
        henGhiXuong()
    }

    private func henGhiXuong() {
        daBan = true
        henGhi?.cancel()
        henGhi = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            self?.ghiNgay()
        }
    }

    func ghiNgay() {
        henGhi?.cancel()
        guard daBan, let k = khoaBai else { return }
        daBan = false
        KhoVietDe.ghi(k, du)
    }

    // MARK: Cử chỉ cuộn của ScrollView cha

    private struct GocCuon { weak var sv: UIScrollView?; let loai: [NSNumber]; let soNgon: Int }
    private var cuonDaDoi: [ObjectIdentifier: GocCuon] = [:]

    /// Canvas đã vào cửa sổ: áp chế độ cuộn cho mọi ScrollView tổ tiên của nó (ghi lại giá trị gốc để trả về).
    func ganCuon(tu v: UIView) {
        var p = v.superview
        while let s = p {
            if let sv = s as? UIScrollView, !(sv is PKCanvasView) {
                let id = ObjectIdentifier(sv)
                if cuonDaDoi[id] == nil {
                    cuonDaDoi[id] = GocCuon(sv: sv, loai: sv.panGestureRecognizer.allowedTouchTypes,
                                            soNgon: sv.panGestureRecognizer.minimumNumberOfTouches)
                }
                apCuon(sv)
            }
            p = s.superview
        }
    }

    private func apCuon(_ sv: UIScrollView) {
        guard let goc = cuonDaDoi[ObjectIdentifier(sv)] else { return }
        if dangViet {
            // Pencil KHÔNG cuộn bài (không thì vừa viết vừa kéo trang); ngón tay + bàn di chuột vẫn cuộn.
            sv.panGestureRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue),
                                                        NSNumber(value: UITouch.TouchType.indirectPointer.rawValue)]
            sv.panGestureRecognizer.minimumNumberOfTouches = ngonTayVe ? 2 : goc.soNgon
        } else {
            sv.panGestureRecognizer.allowedTouchTypes = goc.loai
            sv.panGestureRecognizer.minimumNumberOfTouches = goc.soNgon
        }
    }

    private func doiCheDoCuon() {
        for (id, g) in cuonDaDoi {
            guard let sv = g.sv else { cuonDaDoi[id] = nil; continue }
            apCuon(sv)
        }
        if !dangViet { cuonDaDoi.removeAll() }
    }
}

// MARK: Môi trường

/// Ngữ cảnh "viết lên bài" truyền xuống các khối (màn bài đặt ở gốc danh sách khối).
struct NguCanhVietDe: Equatable {
    let phien: PhienVietDe
    /// Hệ số cỡ chữ hiện tại (cỡ chữ đọc của màn × Dynamic Type).
    var coChu: CGFloat

    static func == (a: Self, b: Self) -> Bool { a.phien === b.phien && a.coChu == b.coChu }

    /// Hệ số theo Dynamic Type (≈ cỡ chữ body so với mặc định 17pt).
    static func heSo(_ d: DynamicTypeSize) -> CGFloat {
        switch d {
        case .xSmall: 0.82; case .small: 0.88; case .medium: 0.94; case .large: 1
        case .xLarge: 1.12; case .xxLarge: 1.24; case .xxxLarge: 1.35
        case .accessibility1: 1.65; case .accessibility2: 1.94; case .accessibility3: 2.35
        case .accessibility4: 2.76; case .accessibility5: 3.12
        @unknown default: 1
        }
    }
}

private struct VietDeKey: EnvironmentKey { static let defaultValue: NguCanhVietDe? = nil }
private struct PhanNhomVietDeKey: EnvironmentKey { static let defaultValue: String? = nil }
extension EnvironmentValues {
    var vietDe: NguCanhVietDe? {
        get { self[VietDeKey.self] }
        set { self[VietDeKey.self] = newValue }
    }
    /// Khối lớn đã cắt lát (bảng, trắc nghiệm) ở mức cao nhất của màn bài: tiền tố khoá cho từng lát của nó.
    var phanNhomVietDe: String? {
        get { self[PhanNhomVietDeKey.self] }
        set { self[PhanNhomVietDeKey.self] = newValue }
    }
}

extension View {
    /// Lớp "viết lên bài" cho MỘT khối (khoá `phan`, duy nhất trong bài). Không có ngữ cảnh ⇒ không làm gì.
    func vietDe(_ phan: String) -> some View { modifier(VietDeModifier(phan: phan, con: false)) }
    /// Lớp cho một LÁT của khối lớn (hàng bảng, câu trắc nghiệm) — chỉ khi khối đang ở mức cao nhất của màn bài
    /// (`phanNhomVietDe` có giá trị); nằm trong khung ngữ pháp thì khung đã có lớp chung.
    func vietDeCon(_ con: String) -> some View { modifier(VietDeModifier(phan: con, con: true)) }
}

private struct VietDeModifier: ViewModifier {
    let phan: String
    let con: Bool
    @Environment(\.vietDe) private var ngc
    @Environment(\.phanNhomVietDe) private var nhom

    func body(content: Content) -> some View {
        // ⚠️ LUÔN `.overlay` (nội dung rỗng khi không cần) — rẽ nhánh if/else quanh `content` là đổi DANH TÍNH
        // của khối mỗi lần bật/tắt chế độ viết ⇒ mất trạng thái của khối (đáp án trắc nghiệm đã chọn…).
        content.overlay {
            if let ngc, let khoa = khoa {
                LopVietDeKhoi(phien: ngc.phien, khoi: khoa, coChu: ngc.coChu)
            }
        }
    }

    private var khoa: String? {
        if con { return nhom.map { "\($0)/\(phan)" } }
        return phan
    }
}

/// Quyết định có dựng canvas cho khối không — quan sát phiên (chỉ những khối đang trên màn).
private struct LopVietDeKhoi: View {
    @ObservedObject var phien: PhienVietDe
    let khoi: String
    let coChu: CGFloat

    var body: some View {
        if phien.dangViet || (phien.hienLop && phien.coNet(khoi)) {
            CanvasVietDeView(phien: phien, khoi: khoi, coChu: coChu,
                             dangViet: phien.dangViet, hien: phien.hienLop || phien.dangViet,
                             congCu: phien.congCu, ngonTayVe: phien.ngonTayVe)
                .accessibilityHidden(true)
        }
    }
}

// MARK: Canvas của một khối

/// Canvas trong suốt. Chạm NGÓN TAY (khi chỉ Pencil vẽ) đi xuyên xuống nội dung bên dưới.
final class CanvasVietDe: PKCanvasView {
    var khiDoiBeNgang: ((CGFloat) -> Void)?
    var khiVaoCuaSo: ((UIView) -> Void)?
    var choNgonTayXuyen = true
    private var rongCu: CGFloat = 0

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        if abs(w - rongCu) > 0.5, w > 1 {
            rongCu = w
            khiDoiBeNgang?(w)
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { khiVaoCuaSo?(self) }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, self.point(inside: point, with: event) else { return nil }
        if choNgonTayXuyen, let ts = event?.allTouches, !ts.isEmpty, !ts.contains(where: { $0.type == .pencil }) {
            // Chỉ ngón tay ⇒ để nội dung (nút, chọn chữ) và ScrollView cha nhận. Không đọc được loại chạm (tập
            // rỗng) ⇒ giữ lại cho canvas: thà nút bên dưới tạm không bấm được còn hơn Pencil không viết được.
            return nil
        }
        return super.hitTest(point, with: event)
    }
}

private struct CanvasVietDeView: UIViewRepresentable {
    let phien: PhienVietDe
    let khoi: String
    let coChu: CGFloat
    let dangViet: Bool
    let hien: Bool
    let congCu: CongCuVietDe
    let ngonTayVe: Bool

    func makeCoordinator() -> DieuPhoi { DieuPhoi(phien: phien, khoi: khoi, coChu: coChu) }

    // ⚠️ KHÔNG dùng lại canvas qua một "kho" tĩnh: `dismantleUIView` chạy TRƯỚC khi SwiftUI gỡ view khỏi chỗ cũ ⇒
    // canvas lấy lại cho khối mới bị gỡ mất ngay sau đó (đo 24/10: nét của câu trắc nghiệm biến mất khi bật viết).
    func makeUIView(context: Context) -> CanvasVietDe {
        let c = CanvasVietDe()
        c.backgroundColor = .clear
        c.isOpaque = false
        c.isScrollEnabled = false
        c.bounces = false
        c.showsVerticalScrollIndicator = false
        c.showsHorizontalScrollIndicator = false
        c.contentInsetAdjustmentBehavior = .never
        // Nét khoanh chờm sang khối bên cạnh (vòng tròn quanh chữ ở mép hàng) vẫn hiện trọn, không bị cắt ở mép khối.
        c.clipsToBounds = false
        c.delegate = context.coordinator
        context.coordinator.canvas = c
        c.khiDoiBeNgang = { [weak co = context.coordinator] w in co?.napLai(rong: w) }
        c.khiVaoCuaSo = { [weak phien] v in
            guard let phien, phien.dangViet else { return }
            phien.ganCuon(tu: v)
        }
        context.coordinator.theoDoi()
        apDung(c, context.coordinator)
        return c
    }

    func updateUIView(_ c: CanvasVietDe, context: Context) {
        let co = context.coordinator
        if co.coChu != coChu || (co.rongDaNap == 0 && c.bounds.width > 1) {
            co.coChu = coChu
            co.napLai(rong: c.bounds.width)
        }
        apDung(c, co)
        if dangViet, c.window != nil { phien.ganCuon(tu: c) }
    }

    static func dismantleUIView(_ c: CanvasVietDe, coordinator: DieuPhoi) {
        coordinator.huy?.cancel()
    }

    private func apDung(_ c: CanvasVietDe, _ co: DieuPhoi) {
        c.isUserInteractionEnabled = dangViet
        c.isHidden = !hien
        c.drawingPolicy = ngonTayVe ? .anyInput : .pencilOnly
        c.choNgonTayXuyen = !ngonTayVe
        if co.congCuDat != congCu {
            co.congCuDat = congCu
            c.tool = congCu.pk
        }
    }

    final class DieuPhoi: NSObject, PKCanvasViewDelegate {
        let phien: PhienVietDe
        let khoi: String
        var coChu: CGFloat
        weak var canvas: CanvasVietDe?
        var congCuDat: CongCuVietDe?
        var huy: AnyCancellable?
        private var dangNap = false
        var rongDaNap: CGFloat = 0

        init(phien: PhienVietDe, khoi: String, coChu: CGFloat) {
            self.phien = phien; self.khoi = khoi; self.coChu = coChu
        }

        func theoDoi() {
            huy = phien.napLaiKhoi.sink { [weak self] k in
                guard let self, k == self.khoi, let c = self.canvas else { return }
                self.napLai(rong: c.bounds.width)
            }
        }

        @MainActor func napLai(rong: CGFloat) {
            guard let c = canvas, rong > 1 else { return }
            rongDaNap = rong
            dangNap = true
            c.drawing = phien.netHien(khoi, rong: rong, coChu: coChu)
            dangNap = false
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !dangNap else { return }
            let w = canvasView.bounds.width
            guard w > 1 else { return }
            MainActor.assumeIsolated {
                phien.capNhat(khoi, canvasView.drawing, rong: w, coChu: coChu)
            }
        }
    }
}

// MARK: Thanh công cụ

/// Thanh công cụ nhỏ của chế độ viết: bút (3 màu), tô sáng, tẩy, hoàn tác, ngón tay vẽ, ẩn/hiện lớp, xoá hết, xong.
struct ThanhVietDe: View {
    @ObservedObject var phien: PhienVietDe
    @State private var hoiXoa = false
    @ScaledMetric(relativeTo: .body) private var coNut: CGFloat = 36

    private var nut: CGFloat { min(max(coNut, 34), 52) }

    var body: some View {
        VStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(0..<CongCuVietDe.mauBut.count, id: \.self) { i in
                        nutCongCu(.but(i), "pencil.tip", mau: Color(CongCuVietDe.mauBut[i]),
                                  nhan: "\(T("Bút")) \(T(CongCuVietDe.tenMau[i]))")
                    }
                    nutCongCu(.toSang, "highlighter", mau: .yellow, nhan: T("Tô sáng"))
                    nutCongCu(.tay, "eraser", mau: AppColors.textPrimary, nhan: T("Tẩy"))
                    Divider().frame(height: nut * 0.6)
                    nutLenh("arrow.uturn.backward", T("Hoàn tác"), tat: !phien.coHoanTac) { phien.hoanTac() }
                    nutLenh(phien.ngonTayVe ? "hand.draw.fill" : "hand.draw", phien.ngonTayVe ? T("Ngón tay đang vẽ") : T("Vẽ bằng ngón tay"),
                            bat: phien.ngonTayVe) { phien.ngonTayVe.toggle(); Haptics.cham() }
                    nutLenh(phien.hienLop ? "eye" : "eye.slash", phien.hienLop ? T("Ẩn lớp ghi") : T("Hiện lớp ghi")) {
                        phien.hienLop.toggle()
                    }
                    nutLenh("trash", T("Xoá hết lớp ghi của bài"), tat: !phien.coNet) { hoiXoa = true }
                    Button {
                        phien.dangViet = false
                        phien.ghiNgay()
                    } label: {
                        Text(T("Xong")).font(.body.weight(.semibold))
                            .padding(.horizontal, 12).frame(minHeight: nut)
                            .background(Capsule().fill(AppColors.primary))
                            .foregroundStyle(AppColors.onPrimary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(T("Tắt viết lên bài"))
                }
                .padding(.horizontal, 8).padding(.vertical, 6)
                .fixedSize(horizontal: true, vertical: false)
            }
            .background(Capsule().fill(.regularMaterial))
            .overlay(Capsule().strokeBorder(AppColors.border, lineWidth: 0.5))
            .fixedSize(horizontal: false, vertical: true)
            Text(phien.ngonTayVe ? T("Ngón tay đang VẼ — cuộn bài bằng hai ngón")
                                 : T("Viết bằng Apple Pencil · ngón tay vẫn cuộn bài"))
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(Capsule().fill(.thinMaterial))
        }
        .padding(.horizontal, 12)
        .confirmationDialog(T("Xoá hết nét đã viết lên bài này?"), isPresented: $hoiXoa, titleVisibility: .visible) {
            Button(T("Xoá hết"), role: .destructive) { phien.xoaHet(); Haptics.cham() }
            Button(T("Huỷ"), role: .cancel) {}
        } message: {
            Text(T("Chỉ xoá lớp ghi của bài đang mở. Bấm Hoàn tác để lấy lại từng khối."))
        }
    }

    private func nutCongCu(_ cc: CongCuVietDe, _ hinh: String, mau: Color, nhan: String) -> some View {
        let chon = phien.congCu == cc
        return Button { phien.congCu = cc; Haptics.cham() } label: {
            Image(systemName: hinh)
                .font(.system(size: nut * 0.46, weight: .semibold))
                .foregroundStyle(mau)
                .frame(width: nut, height: nut)
                .background(Circle().fill(chon ? AppColors.primary.opacity(0.18) : Color.clear))
                .overlay(Circle().strokeBorder(chon ? AppColors.primary : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(nhan)
        .accessibilityAddTraits(chon ? .isSelected : [])
    }

    private func nutLenh(_ hinh: String, _ nhan: String, tat: Bool = false, bat: Bool = false,
                         _ lam: @escaping () -> Void) -> some View {
        Button(action: lam) {
            Image(systemName: hinh)
                .font(.system(size: nut * 0.44, weight: .medium))
                .foregroundStyle(bat ? AppColors.primary : AppColors.textPrimary)
                .frame(width: nut, height: nut)
        }
        .buttonStyle(.plain)
        .disabled(tat)
        .opacity(tat ? 0.35 : 1)
        .accessibilityLabel(nhan)
    }
}
#else
import SwiftUI
extension View {
    func vietDe(_ phan: String) -> some View { self }
    func vietDeCon(_ con: String) -> some View { self }
}
#endif
