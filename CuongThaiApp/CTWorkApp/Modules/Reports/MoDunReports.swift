import SwiftUI

// MARK: - Đăng ký mô-đun Reports
//
// Deep link `/work/<ws>/<KEY>/reports?tab=<id>`. Ẩn khi máy chủ báo `viewReports = false`
// (thiếu cờ ⇒ hiện; máy chủ vẫn kiểm từng route).

extension CTWModule {
    static let reports = CTWModule(
        id: "reports", ten: "Reports", bieuTuong: "chart.xyaxis.line", nhom: .duAn,
        moTa: "Burndown, velocity, flow, workload, people vs agents", thuTu: 60, doanWeb: "reports",
        hien: { cfg in cfg?.permissions?.tatCa["viewReports"] != false },
        man: { c in AnyView(BaoCaoCTW(nguCanh: c)) })
}
