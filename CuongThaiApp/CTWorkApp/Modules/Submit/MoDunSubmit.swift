import SwiftUI

// MARK: - Đăng ký mô-đun Nộp sản phẩm (deliverables) — xem ai đã nộp tệp cho thẻ nào.

extension CTWModule {
    static let submit = CTWModule(
        id: "submit", ten: "Deliverables", bieuTuong: "tray.and.arrow.up", nhom: .duAn,
        moTa: "Who has submitted files for their issues", thuTu: 70, doanWeb: "submit",
        hien: { cfg in cfg?.role != "CLIENT" },
        man: { c in AnyView(NopSanPhamCTW(pid: c.pid)) })
}
