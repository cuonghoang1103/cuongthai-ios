import SwiftUI

// MARK: - ĐĂNG KÝ MÔ-ĐUN — chỗ DUY NHẤT liệt kê các mô-đun của app
//
// Thêm mô-đun: tạo `Modules/<Ten>/MoDun<Ten>.swift` khai `static let <ten>`,
// rồi thêm MỘT dòng vào mảng dưới (mỗi người một dòng ⇒ hợp nhất git không đụng nhau).
// Thứ tự mảng không quan trọng — khung sắp theo `nhom` rồi `thuTu`.

enum CTWDangKyMoDun {
    static let dangKyMoDun: [CTWModule] = [
        .desk, .intake, .forms, .portal, .classes, .submit,
        .ai,
        .aiUsage,
        .board,
        .backlog,
        .code,
        .docs,
        .kb,
        .chat,
        .meetings,
        .tests,
        .requirements,
        .wiegers,
        .team, .agents, .assets, .resources, .diagrams, .finance,
        .approvals, .changes, .raid, .reviews,
        .sprints, .reports, .dashboards,
        .time, .poker, .retros, .okrs, .workspace,
        .timeline, .releases, .stages, .calendar,
        .tinNhan, .thanhVien,
        .feed,
    ]

    static func moDun(_ id: String) -> CTWModule? { dangKyMoDun.first { $0.id == id } }

    /// Mô-đun hiện được với dự án đang chọn, đã sắp.
    @MainActor
    static func hienDuoc(_ cfg: CTWProjectConfig?) -> [CTWModule] {
        dangKyMoDun.filter { !$0.capUngDung && $0.hien(cfg) }.sorted { ($0.nhom.rawValue, $0.thuTu) < ($1.nhom.rawValue, $1.thuTu) }
    }

    @MainActor
    static func theoNhom(_ cfg: CTWProjectConfig?) -> [(nhom: CTWNhomMoDun, ds: [CTWModule])] {
        let ds = hienDuoc(cfg)
        return CTWNhomMoDun.allCases.compactMap { n in
            let m = ds.filter { $0.nhom == n }
            return m.isEmpty ? nil : (nhom: n, ds: m)
        }
    }

    /// Mô-đun cấp ứng dụng (không cần dự án) — iPad: khối đầu thanh bên.
    static var capUngDung: [CTWModule] { dangKyMoDun.filter(\.capUngDung).sorted { $0.thuTu < $1.thuTu } }

    /// Mô-đun nhận đoạn đường dẫn web này (deep link / thông báo).
    static func moDun(choDoan doan: String) -> CTWModule? {
        dangKyMoDun.first { ($0.doanWeb ?? $0.id) == doan }
    }
}

extension View {
    /// Đăng ký đích điều hướng của LÕI (thẻ, bảng, mở mô-đun) + của MỌI mô-đun
    /// đã đăng ký. Mọi NavigationStack trong app gắn đúng một lần.
    @MainActor
    func ctwDichDen() -> some View {
        let goc = AnyView(
            self
                .navigationDestination(for: CTWRoute.self) { r in
                    switch r {
                    case .khongGian(let slug, let ten): CTWWorkspaceView(slug: slug, ten: ten)
                    case .bang(let pid, let ten): CTWBoardView(pid: pid, ten: ten)
                    case .bangTheoMa(let slug, let ma):
                        CTWResolver(slug: slug, ma: ma) { pid in CTWBoardView(pid: pid, ten: ma) }
                    case .the(let pid, let so): CTWIssueView(pid: pid, so: so, khiMo: CTWChiaSeNhom.khiMoThe, moRong: .ctwApp)
                    case .theTheoMa(let slug, let ma, let so):
                        CTWResolver(slug: slug, ma: ma) { pid in CTWIssueView(pid: pid, so: so, khiMo: CTWChiaSeNhom.khiMoThe, moRong: .ctwApp) }
                    }
                }
                .navigationDestination(for: RouteMoDunCTW.self) { r in ManMoDunCTW(id: r.id) }
                .navigationDestination(for: RouteThemCTW.self) { _ in ManThemCTW() }
        )
        return CTWDangKyMoDun.dangKyMoDun.reduce(goc) { v, m in m.dichDen?(v) ?? v }
    }
}

/// Màn một mô-đun cấp dự án (cần dự án đang chọn).
struct ManMoDunCTW: View {
    let id: String
    @EnvironmentObject private var app: AppState

    var body: some View {
        if let m = CTWDangKyMoDun.moDun(id), m.capUngDung {
            m.man(CTWNguCanh(pid: 0, slug: "", maDuAn: "", tenDuAn: ""))
        } else if let m = CTWDangKyMoDun.moDun(id), let l = app.luaChon {
            m.man(CTWNguCanh(pid: l.pid, slug: l.slug, maDuAn: l.maDuAn, tenDuAn: l.tenDuAn))
                .id("\(id)-\(l.pid)")
                // Board/Backlog mở như một màn riêng (iPad thanh bên, More tools) ⇒ nút ✦ CuongMini như trang dự án iPhone.
                .toolbar {
                    if (id == "board" || id == "backlog") && CuongMini.coTheDung(app.cauHinhDuAn) {
                        ToolbarItem(placement: .topBarLeading) { NutCuongMiniCTW(pid: l.pid, maDuAn: l.maDuAn) }
                    }
                }
                .onAppear { DungNhieuCTW.dem("mod:\(id)") }   // "hay dùng" của màn Tìm mọi thứ
        } else {
            ChuaChonDuAnCTW(lyDo: String(localized: "Pick a project to continue."))
        }
    }
}
