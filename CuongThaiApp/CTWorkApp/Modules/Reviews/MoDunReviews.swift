import SwiftUI

// MARK: - Đăng ký mô-đun Reviews (rà soát IEEE-1028)
//
// Không có cờ mô-đun riêng (web cũng không chặn) — chỉ ẩn với khách (máy chủ
// trả `WORK_INTERNAL_ONLY`). Deep link `/work/<ws>/<KEY>/reviews/<n>`.

extension CTWModule {
    static let reviews = CTWModule(
        id: "reviews", ten: "Reviews", bieuTuong: "text.magnifyingglass", nhom: .quanLy,
        moTa: "Inspections with a checklist and defect log", thuTu: 50, doanWeb: "reviews",
        hien: { cfg in !GovQuyen.laKhach(cfg) },
        man: { c in AnyView(RaSoatCTW(pid: c.pid)) },
        dichDen: { v in
            AnyView(v.navigationDestination(for: RouteReviewCTW.self) { r in ChiTietRaSoatCTW(pid: r.pid, so: r.so) })
        })
}
