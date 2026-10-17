import SwiftUI

// MARK: - Đăng ký mô-đun Cuộc họp (Meetings)
//
// Ẩn khi dự án tắt mô-đun `meetings` (`cfg.batMoDun("meetings")`). Nhóm Giao tiếp.
// iPhone: một dòng trong trang Projects. Deep link `/work/<ws>/<KEY>/meetings/<n>`.
// Route con: `RouteHopCTW` (chi tiết một cuộc họp).

extension CTWModule {
    static let meetings = CTWModule(
        id: "meetings", ten: "Meetings", bieuTuong: "calendar", nhom: .giaoTiep,
        moTa: "Schedule, join, notes and action items", thuTu: 20, doanWeb: "meetings",
        hien: { cfg in cfg?.batMoDun("meetings") ?? true },
        man: { c in AnyView(CuocHopCTW(nguCanh: c)) },
        dichDen: { v in
            AnyView(v.navigationDestination(for: RouteHopCTW.self) { r in
                ChiTietHopCTW(pid: r.pid, so: r.so)
            })
        })
}
