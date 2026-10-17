import SwiftUI

// MARK: - Đăng ký mô-đun Cổng khách
//
// Khách (vai trò CLIENT) dùng nó làm "trang chủ" của dự án; đội dự án thấy cùng
// màn đó ở chế độ xem thử chỉ đọc. Hiện khi dự án bật `clientPortal`.

extension CTWModule {
    static let portal = CTWModule(
        id: "portal", ten: "Client portal", bieuTuong: "person.2.badge.gearshape", nhom: .giaoTiep,
        moTa: "What your client sees: requests, approvals, documents", thuTu: 36, doanWeb: "portal",
        hien: { cfg in cfg?.batMoDun("clientPortal") ?? true },
        man: { c in AnyView(PortalCTW(pid: c.pid)) },
        dichDen: { v in
            AnyView(v.navigationDestination(for: RoutePortalCTW.self) { r in r.man })
        })
}
