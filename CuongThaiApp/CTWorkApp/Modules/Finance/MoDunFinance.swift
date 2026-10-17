import SwiftUI

// MARK: - Đăng ký mô-đun Finance (CHỈ XEM) — `/work/<ws>/<KEY>/finance`
// Hiện khi dự án bật `finance` VÀ người dùng có `viewFinance` (như web, finance/page.tsx:24).
// ⛔ 3.1.1: mô-đun này không có thao tác tiền bạc nào.

extension CTWModule {
    static let finance = CTWModule(
        id: "finance", ten: "Finance", bieuTuong: "chart.pie", nhom: .quanLy,
        moTa: "Budget, spending and milestones (read-only)", thuTu: 60, doanWeb: "finance",
        hien: { cfg in
            guard let cfg else { return false }
            #if DEBUG
            // Máy chủ giả: cấu hình mẫu chưa có khoá `viewFinance` ⇒ coi là có (máy chủ thật luôn trả đủ).
            if XemThuCTW.man != nil { return cfg.permissions?.tatCa["viewFinance"] ?? true }
            #endif
            return cfg.batMoDun("finance") && cfg.coQuyen("viewFinance")
        },
        man: { c in AnyView(FinanceCTW(nguCanh: c)) })
}
