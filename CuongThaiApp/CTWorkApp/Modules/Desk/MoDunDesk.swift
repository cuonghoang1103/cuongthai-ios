import SwiftUI

// MARK: - Đăng ký mô-đun Service desk
//
// Hiện khi dự án bật mô-đun `serviceDesk` và người xem không phải khách (khách
// gửi yêu cầu qua Cổng khách). Deep link `/work/<ws>/<KEY>/desk/<số>`.

extension CTWModule {
    static let desk = CTWModule(
        id: "desk", ten: "Service desk", bieuTuong: "lifepreserver", nhom: .giaoTiep,
        moTa: "Tickets, SLAs and client replies", thuTu: 30, doanWeb: "desk",
        hien: { cfg in (cfg?.batMoDun("serviceDesk") ?? true) && cfg?.role != "CLIENT" },
        man: { c in AnyView(HangChoCTW(pid: c.pid)) },
        dichDen: { v in
            AnyView(v.navigationDestination(for: RouteTicketCTW.self) { r in TicketCTW(pid: r.pid, so: r.so) })
        })
}
