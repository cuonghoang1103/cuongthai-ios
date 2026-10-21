import SwiftUI

// MARK: - MÔ-ĐUN của app CT Work — kiểu dữ liệu
//
// Mỗi tính năng cấp dự án (Board, Backlog, Docs, Chat, Sprint, Timeline…) là MỘT
// `CTWModule`, khai trong thư mục riêng `Modules/<TenMoDun>/` bằng
//
//     extension CTWModule { static let board = CTWModule(id: "board", …) }
//
// rồi THÊM MỘT DÒNG vào `CTWDangKyMoDun.dangKyMoDun` (Core/CTWDangKyMoDun.swift).
// Khung app (thanh tab iPhone, thanh bên iPad, trang dự án, deep link) đọc
// bảng đó — không ai phải sửa khung. Hướng dẫn đầy đủ: `KIEN_TRUC.md`.
//
// Luật App Store 2.1: mô-đun CHƯA làm xong thì KHÔNG đăng ký (không placeholder).

/// Nhóm trên thanh bên iPad / trang dự án iPhone. Thứ tự case = thứ tự hiện.
enum CTWNhomMoDun: Int, CaseIterable, Identifiable {
    case duAn, giaoTiep, keHoach, taiLieu, chatLuong, quanLy, quanTri
    var id: Int { rawValue }
    var ten: String {
        switch self {
        case .duAn: return String(localized: "Project")
        case .giaoTiep: return String(localized: "Communication")
        case .keHoach: return String(localized: "Planning")
        case .taiLieu: return String(localized: "Docs & knowledge")
        case .chatLuong: return String(localized: "Requirements & testing")
        case .quanLy: return String(localized: "Governance")
        case .quanTri: return String(localized: "Admin")
        }
    }
}

/// Bối cảnh một mô-đun cấp dự án nhận khi dựng màn.
struct CTWNguCanh: Hashable {
    var pid: Int
    var slug: String
    var maDuAn: String
    var tenDuAn: String
}

/// Đường dẫn web/thông báo đã tách: `/work/<slug>/<KEY>/<doan>/<phanCon…>?<tham>`.
struct DuongDanCTW: Equatable, Hashable {
    var slug: String
    var maDuAn: String?
    /// Đoạn thứ 3 — trùng `CTWModule.doanWeb` (vd `chat`, `docs`, `issue`).
    var doan: String?
    var phanCon: [String] = []
    var tham: [String: String] = [:]

    static func tach(_ s: String) -> DuongDanCTW? {
        var chu = s
        if let r = chu.range(of: "://"), let sau = chu[r.upperBound...].firstIndex(of: "/") { chu = String(chu[sau...]) }
        if let h = chu.firstIndex(of: "#") { chu = String(chu[..<h]) }
        let hai = chu.split(separator: "?", maxSplits: 1).map(String.init)
        let p = (hai.first ?? "").split(separator: "/").map { String($0).removingPercentEncoding ?? String($0) }
        guard p.count >= 2, p[0] == "work", !p[1].isEmpty else { return nil }
        var d = DuongDanCTW(slug: p[1])
        if p.count >= 3 { d.maDuAn = p[2] }
        if p.count >= 4 { d.doan = p[3] }
        if p.count >= 5 { d.phanCon = Array(p[4...]) }
        if hai.count > 1 {
            for cap in hai[1].split(separator: "&") {
                let kv = cap.split(separator: "=", maxSplits: 1).map { String($0).removingPercentEncoding ?? String($0) }
                if kv.count == 2 { d.tham[kv[0]] = kv[1] }
            }
        }
        return d
    }
}

/// Đích đang chờ một mô-đun nhận (từ thông báo / deep link). Khung app chuyển
/// tới đúng chỗ của mô-đun; mô-đun đọc `AppState.dichCho`, mở phần con của
/// mình rồi XOÁ cờ (ở cuối — xoá sớm làm `.task(id:)` tự huỷ).
struct DichMoDunCTW: Equatable {
    var moDun: String
    var pid: Int?
    var duongDan: DuongDanCTW
}

/// Ngăn xếp điều hướng của một cột/tab — mô-đun đẩy màn bằng
/// `@EnvironmentObject var nganXep: NganXepCTW` → `nganXep.duong.append(...)`.
@MainActor
final class NganXepCTW: ObservableObject {
    @Published var duong = NavigationPath()
    func veDau() { duong = NavigationPath() }
}

/// Mở một mô-đun cấp dự án từ trang dự án (iPhone).
struct RouteMoDunCTW: Hashable { var id: String }

struct CTWModule: Identifiable {
    enum ViTriIPhone { case trangDuAn, tabRieng }

    /// Định danh — NÊN trùng đoạn đường dẫn web (`/work/<ws>/<KEY>/<id>`).
    let id: String
    /// Tên + mô tả là `LocalizedStringResource` (trình biên dịch tự trích vào Localizable.xcstrings) và DỊCH LÚC
    /// HIỆN (`ten`/`moTa` tính mỗi lần đọc) — `static let` của mô-đun tạo một lần, nên dịch sẵn lúc tạo là
    /// đóng băng ngôn ngữ cũ khi người dùng đổi ngôn ngữ trong app.
    let tenNguon: LocalizedStringResource
    let bieuTuong: String
    let nhom: CTWNhomMoDun
    /// Dòng phụ trên trang dự án (iPhone).
    var moTaNguon: LocalizedStringResource = ""
    var ten: String { CTWModule.dich(tenNguon) }
    var moTa: String { CTWModule.dich(moTaNguon) }
    /// Thứ tự trong nhóm (nhỏ trước).
    var thuTu: Int = 100
    /// iPhone: một dòng trong trang dự án, hay một TAB riêng (chỉ Chat).
    var viTriIPhone: ViTriIPhone = .trangDuAn
    /// Đoạn đường dẫn web để nhận deep link (`nil` = không nhận).
    var doanWeb: String?
    /// Hiện hay không theo cấu hình dự án đang chọn (mô-đun bật/tắt, quyền).
    /// Mặc định: luôn hiện. Dùng `cfg.batMoDun("docs")`, `cfg.coQuyen("viewFinance")`.
    var hien: @MainActor (CTWProjectConfig?) -> Bool = { _ in true }
    /// Màn chính — CHỈ nội dung, KHÔNG bọc NavigationStack (khung bọc sẵn).
    let man: @MainActor (CTWNguCanh) -> AnyView
    /// Đăng ký `navigationDestination` cho các route con của mô-đun.
    var dichDen: (@MainActor (AnyView) -> AnyView)?
    /// Mô-đun CẤP ỨNG DỤNG (không cần dự án — vd Thành viên, Tin nhắn riêng): không nằm trong trang dự án / More tools,
    /// iPad hiện ở khối đầu thanh bên (cạnh My Work, Inbox), `man` nhận bối cảnh rỗng (pid 0).
    var capUngDung: Bool = false
    /// iPhone: mô-đun này sống TRONG tab của mô-đun khác (vd `tin-nhan`/`thanh-vien` nằm trong tab `chat`) — chọn nó
    /// (deep link, thông báo) ⇒ khung chuyển sang tab đó.
    var tabIPhone: String?
    /// iPhone: gốc riêng cho TAB của mô-đun `.tabRieng` (vd tab Chat = Kênh · Tin nhắn · Thành viên). nil ⇒ `man`.
    var manTabIPhone: (@MainActor () -> AnyView)?

    init(id: String, ten: LocalizedStringResource, bieuTuong: String, nhom: CTWNhomMoDun,
         moTa: LocalizedStringResource = "", thuTu: Int = 100, viTriIPhone: ViTriIPhone = .trangDuAn,
         doanWeb: String? = nil,
         hien: @escaping @MainActor (CTWProjectConfig?) -> Bool = { _ in true },
         capUngDung: Bool = false, tabIPhone: String? = nil,
         manTabIPhone: (@MainActor () -> AnyView)? = nil,
         man: @escaping @MainActor (CTWNguCanh) -> AnyView,
         dichDen: (@MainActor (AnyView) -> AnyView)? = nil) {
        self.id = id; self.tenNguon = ten; self.bieuTuong = bieuTuong; self.nhom = nhom
        self.moTaNguon = moTa; self.thuTu = thuTu; self.viTriIPhone = viTriIPhone; self.doanWeb = doanWeb
        self.hien = hien; self.man = man; self.dichDen = dichDen
        self.capUngDung = capUngDung; self.tabIPhone = tabIPhone; self.manTabIPhone = manTabIPhone
    }

    /// Dịch theo ngôn ngữ app đang chọn (không theo `Locale.current` của máy).
    static func dich(_ r: LocalizedStringResource) -> String {
        var r = r
        r.locale = CTWDinhDang.locale
        return String(localized: r)
    }
}

extension CTWProjectConfig {
    /// Mô-đun dự án bật chưa (`modules` của `GET /projects/:pid`). Thiếu khoá ⇒ coi là bật.
    func batMoDun(_ ten: String) -> Bool { modules?[ten] ?? true }
    /// Cờ quyền bất kỳ trong `permissions` (kể cả cờ app chưa khai trường).
    func coQuyen(_ ten: String) -> Bool { permissions?.tatCa[ten] == true }
}
