import SwiftUI

// MARK: - Đăng ký mô-đun Sprints
//
// Web không có trang `/sprints` riêng (sprint nằm trong Backlog) ⇒ `doanWeb = nil`.
// Ẩn với dự án Kanban (không có sprint). Route con: `RouteSprintCTW` (chi tiết sprint).

extension CTWModule {
    static let sprints = CTWModule(
        id: "sprints", ten: "Sprints", bieuTuong: "flag.checkered", nhom: .keHoach,
        moTa: "Plan, start and complete sprints · burndown", thuTu: 10, doanWeb: nil,
        hien: { cfg in cfg?.type != "KANBAN" },
        man: { c in AnyView(SprintsCTW(pid: c.pid)) },
        dichDen: { v in
            AnyView(v.navigationDestination(for: RouteSprintCTW.self) { r in
                ChiTietSprintCTW(pid: r.pid, sid: r.sid)
            })
        })
}
