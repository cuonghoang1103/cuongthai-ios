import SwiftUI

// MARK: - Đăng ký mô-đun Approvals (phê duyệt nhiều bước có ký số nội dung)
//
// Ẩn khi dự án tắt mô-đun `approvals`. Tuyến `RouteDuyetCTW` đăng ký ở đây nên
// mô-đun khác (Docs, Stages, Change requests) đẩy được chi tiết phê duyệt.
// Deep link `/work/<ws>/<KEY>/approvals?id=<id>`.

extension CTWModule {
    static let approvals = CTWModule(
        id: "approvals", ten: "Approvals", bieuTuong: "checkmark.seal", nhom: .quanLy,
        moTa: "Sign off issues, documents, changes and gates", thuTu: 10, doanWeb: "approvals",
        hien: { cfg in cfg?.batMoDun("approvals") ?? true },
        man: { c in AnyView(DuyetCTW(pid: c.pid)) },
        dichDen: { v in
            AnyView(v.navigationDestination(for: RouteDuyetCTW.self) { r in ChiTietDuyetCTW(pid: r.pid, id: r.id) })
        })
}
