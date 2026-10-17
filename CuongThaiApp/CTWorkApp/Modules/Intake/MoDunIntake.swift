import SwiftUI

// MARK: - Đăng ký mô-đun Intake (chỉ đội dự án — khách không thấy)

extension CTWModule {
    static let intake = CTWModule(
        id: "intake", ten: "Intake", bieuTuong: "tray.and.arrow.down", nhom: .giaoTiep,
        moTa: "Requests from email, Discord, Zalo, Slack", thuTu: 32, doanWeb: "intake",
        hien: { cfg in cfg?.role != "CLIENT" },
        man: { c in AnyView(IntakeCTW(pid: c.pid)) },
        dichDen: { v in
            AnyView(v.navigationDestination(for: RouteDeXuatCTW.self) { r in DeXuatCTW(pid: r.pid, dx: r.dx) })
        })
}
