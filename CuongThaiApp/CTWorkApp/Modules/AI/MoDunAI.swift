import SwiftUI

// MARK: - Đăng ký mô-đun "AI assistant" (trợ lý mentor của dự án — web 18/10/2026)
//
// Hiện khi người dùng được hỏi AI trong dự án (`permissions.useAi` = vai ADMIN/MEMBER; khách cổng, người xem và
// agent không có). Web mở trợ lý bằng bảng trượt (không có đường riêng) ⇒ `doanWeb: nil`.
// App Store 5.1.2(i)/4.7: đồng ý trước câu hỏi đầu + nhãn AI + báo cáo câu trả lời — xem `TroLyAICTW.swift`.

extension CTWModule {
    static let ai = CTWModule(
        id: "ai", ten: "AI assistant", bieuTuong: "sparkles", nhom: .duAn,
        moTa: "Ask about issues, docs and the sprint — answers link to the issues", thuTu: 5, doanWeb: nil,
        hien: { cfg in cfg?.permissions?.useAi == true && cfg?.role != "CLIENT" },
        man: { c in AnyView(TroLyAICTW(pid: c.pid)) })
}
