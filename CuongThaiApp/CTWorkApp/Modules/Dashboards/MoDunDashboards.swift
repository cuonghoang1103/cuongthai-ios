import SwiftUI

// MARK: - Đăng ký mô-đun Dashboards (+ mẫu báo cáo chỉ xem)
//
// Deep link `/work/<ws>/<KEY>/dashboards?d=<id>`. Route con: một dashboard, một mẫu báo cáo.

extension CTWModule {
    static let dashboards = CTWModule(
        id: "dashboards", ten: "Dashboards", bieuTuong: "rectangle.3.group", nhom: .duAn,
        moTa: "Widgets and report templates", thuTu: 70, doanWeb: "dashboards",
        man: { c in AnyView(DashboardsCTW(pid: c.pid)) },
        dichDen: { v in
            AnyView(v
                .navigationDestination(for: RouteDashboardCTW.self) { r in DashboardCTW(pid: r.pid, dashboard: r.dashboard) }
                .navigationDestination(for: RouteMauBaoCaoCTW.self) { r in XemBaoCaoCTW(pid: r.pid, ref: r.ref, ten: r.ten) })
        })
}
