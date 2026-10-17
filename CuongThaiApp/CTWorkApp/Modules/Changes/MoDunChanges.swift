import SwiftUI

// MARK: - Đăng ký mô-đun Change requests
//
// Hiện khi dự án bật `changeRequests` và vai trò xem được quản trị dự án
// (`viewGovernance` — khách/khách mời không thấy). Deep link
// `/work/<ws>/<KEY>/changes/<n>`.

extension CTWModule {
    static let changes = CTWModule(
        id: "changes", ten: "Change requests", bieuTuong: "arrow.triangle.branch", nhom: .quanLy,
        moTa: "Scope, schedule and cost changes", thuTu: 20, doanWeb: "changes",
        hien: { cfg in
            (cfg?.batMoDun("changeRequests") ?? true) && GovQuyen.co(cfg, "viewGovernance") && !GovQuyen.laKhach(cfg)
        },
        man: { c in AnyView(ThayDoiCTW(pid: c.pid)) },
        dichDen: { v in
            AnyView(v.navigationDestination(for: RouteCrCTW.self) { r in ChiTietCrCTW(pid: r.pid, so: r.so) })
        })
}
