import SwiftUI

// MARK: - Đăng ký mô-đun Retrospectives
//
// Web: `/work/<ws>/<KEY>/retros` — đội dự án + giảng viên; khách (CLIENT) không thấy.

extension CTWModule {
    static let retros = CTWModule(
        id: "retros", ten: "Retrospectives", bieuTuong: "bubble.left.and.text.bubble.right", nhom: .keHoach,
        moTa: "What went well, what to improve", thuTu: 70, doanWeb: "retros",
        hien: { cfg in cfg?.role != "CLIENT" },
        man: { c in AnyView(RetroCTW(nguCanh: c)) },
        dichDen: { v in
            AnyView(v.navigationDestination(for: RouteRetroCTW.self) { r in
                BangRetroCTW(pid: r.pid, rid: r.rid, ten: r.ten)
            })
        })
}
