import SwiftUI

// MARK: - Đăng ký mô-đun Planning Poker
//
// Web: `/work/<ws>/<KEY>/poker` — đội dự án + giảng viên; khách (CLIENT) không thấy (máy chủ trả 404).

extension CTWModule {
    static let poker = CTWModule(
        id: "poker", ten: "Planning poker", bieuTuong: "suit.spade", nhom: .keHoach,
        moTa: "Estimate stories together", thuTu: 60, doanWeb: "poker",
        hien: { cfg in cfg?.role != "CLIENT" },
        man: { c in AnyView(PokerCTW(nguCanh: c)) },
        dichDen: { v in
            AnyView(v.navigationDestination(for: RoutePokerCTW.self) { r in
                PhongPokerCTW(pid: r.pid, sid: r.sid, ten: r.ten)
            })
        })
}
