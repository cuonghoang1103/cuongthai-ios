import SwiftUI

// MARK: - Đăng ký mô-đun OKRs (dự án + không gian, một màn có công tắc phạm vi)
//
// Web: `/work/<ws>/<KEY>/okrs` (dự án) và `/work/<ws>/okrs` (không gian). Khách (CLIENT) ⇒ 404 ⇒ ẩn.

extension CTWModule {
    static let okrs = CTWModule(
        id: "okrs", ten: "OKRs", bieuTuong: "scope", nhom: .keHoach,
        moTa: "Objectives, key results and check-ins", thuTu: 90, doanWeb: "okrs",
        hien: { cfg in cfg?.role != "CLIENT" },
        man: { c in AnyView(OkrCTW(nguCanh: c)) })
}
