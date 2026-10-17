import SwiftUI

// MARK: - Đăng ký mô-đun Diagrams — `/work/<ws>/<KEY>/diagrams[/<n>]`
// Ẩn với khách cổng (máy chủ trả 403 WORK_INTERNAL_ONLY).

extension CTWModule {
    static let diagrams = CTWModule(
        id: "diagrams", ten: "Diagrams", bieuTuong: "square.on.square.dashed", nhom: .taiLieu,
        moTa: "View, zoom and discuss project diagrams", thuTu: 20, doanWeb: "diagrams",
        hien: { cfg in cfg?.role != "CLIENT" },
        man: { c in AnyView(DiagramsCTW(nguCanh: c)) },
        dichDen: { v in
            AnyView(v.navigationDestination(for: RouteSoDoCTW.self) { r in SoDoChiTietCTW(r: r) })
        })
}
