import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// ════════════════════════════════════════════════════════════════
// ĐỒNG Ý CHIA SẺ DỮ LIỆU VỚI AI BÊN THỨ BA — App Store 5.1.2(i)
//
// > "You must clearly disclose where personal data will be shared with
// > third parties, including with third-party AI, and obtain explicit
// > permission before doing so."
//
// Sự đồng ý này TÁCH RIÊNG khỏi màn "Tôi đồng ý" điều khoản: gộp vào một nút
// với quy tắc cộng đồng thì không phải "explicit permission" cho việc chia sẻ
// với AI. Nên: lần ĐẦU người dùng dùng một tính năng AI, hỏi riêng một câu
// có Đồng ý / Không. Chọn "Không" ⇒ yêu cầu KHÔNG được gửi đi.
//
// ── Chốt ở đâu ─────────────────────────────────────────────────────
// Không có MỘT chỗ duy nhất: phần lớn lời gọi AI đi qua `APIClient.perform`,
// còn luồng chữ (SSE) và các lượt tải âm thanh/ảnh tự dựng `URLRequest`.
// Nên chốt ở ĐỦ các đường ra, không ở từng màn:
//   1. `APIClient.chotAI` — móc gắn lúc app khởi động (`iOSApp.init`),
//      lọc theo `laDuongAI(method:path:)` bên dưới.
//   2. `LuongChat.gui` (AI Chat) và `LuongHoiDap.doc` (gia sư bài học,
//      CuongMini phòng thi, hỏi về video).
//   3. Bốn lượt tải tự dựng: `/ielts/ai/cham-noi` (âm thanh → Groq Whisper),
//      `/ai/stt` (giọng nói → Groq Whisper), `/video-hoc/nhai` (âm thanh →
//      Groq Whisper), `/class-schedule/doc-anh` (ảnh lịch → model thị giác).
//
// ⚠️ Thêm một đường AI mới tự dựng `URLRequest` thì PHẢI gọi
// `try await DongYChiaSeAI.batBuoc()` trước khi gửi. Đi qua `APIClient` thì
// kiểm `laDuongAI` có bắt được đường đó chưa.
//
// "Không" KHÔNG được ghi nhớ: lần sau người dùng tự bấm một tính năng AI thì
// hỏi lại — họ vừa chủ động muốn dùng AI, hỏi lại là đúng, còn khoá chết vĩnh
// viễn thì không có đường nào mở lại ngoài trang Chính sách bảo mật.
// ════════════════════════════════════════════════════════════════

enum DongYChiaSeAI {
    /// Khoá `@AppStorage` / `UserDefaults`. Đổi hậu tố `.v1` khi nội dung
    /// công bố thay đổi đáng kể (thêm nhà cung cấp mới) để hỏi lại mọi người.
    static let khoa = "ai.dongYChiaSeDuLieu.v1"

    static var daDongY: Bool { UserDefaults.standard.bool(forKey: khoa) }

    static let tieuDe = "Cho phép gửi dữ liệu tới AI?"

    /// Tóm tắt công bố — phải khớp mục "Tính năng AI và bên thứ ba" trong
    /// `PrivacyPolicyView` (LegalViews.swift).
    static let tomTat = """
    Để trả lời, tính năng AI gửi nội dung bạn đưa vào qua máy chủ CuongThai tới nhà cung cấp AI bên thứ ba:

    • Câu hỏi, ảnh/tệp đính kèm và lịch sử trò chuyện
    • Ghi chú liên quan (Trợ lý ghi chú), số liệu thu chi (AI Tiền), CV, bài làm, mã nguồn
    • Bản ghi âm khi luyện nói IELTS / nói với AI

    Nhà cung cấp: Anthropic (Claude) và OpenAI (GPT) qua cổng rambo.ai.vn, modelapi.vn; Groq (Whisper — chuyển giọng nói thành chữ).

    Dữ liệu chỉ dùng để tạo câu trả lời. Chọn "Không" thì tính năng AI không gửi gì. Đổi lại bất cứ lúc nào trong Chính sách bảo mật.
    """

    static let loiTuChoi = "Bạn chưa đồng ý chia sẻ dữ liệu với AI nên yêu cầu không được gửi đi. Bật lại trong Cài đặt → Chính sách bảo mật, hoặc thử lại và chọn Đồng ý."

    /// Ném lỗi (có câu giải thích) nếu người dùng không đồng ý.
    static func batBuoc() async throws {
        if daDongY { return }
        if await xinPhep() { return }
        throw APIError.serverError(T(loiTuChoi))
    }

    /// `true` = được gửi. Hỏi nếu chưa đồng ý. Nhiều lời gọi cùng lúc chỉ
    /// hiện MỘT hộp thoại và cùng chờ một câu trả lời.
    static func xinPhep() async -> Bool {
        if daDongY { return true }
        return await BoHoi.chung.hoi()
    }

    /// Móc chốt vào `APIClient` (gọi một lần lúc khởi động app).
    static func ganVaoAPIClient() {
        APIClient.chotAI = { method, path in
            guard laDuongAI(method: method, path: path) else { return }
            try await batBuoc()
        }
    }

    /// Đường nào qua `APIClient` là gửi dữ liệu người dùng tới AI.
    ///
    /// ⚠️ KHÔNG lọc theo method một cách mù quáng: `GET /finance/ai/tom-tat`
    /// là GET mà vẫn gửi số liệu thu chi tới AI.
    static func laDuongAI(method: String, path: String) -> Bool {
        if method == "DELETE" { return false }
        // Quản lý phiên/thư mục chat, xem lịch sử, báo cáo câu trả lời, danh
        // sách hành động/câu hỏi đã lưu: không gửi gì tới nhà cung cấp AI.
        let boQuaDau = ["/api/v1/ai/feedback", "/api/v1/ai/chat/sessions",
                        "/api/v1/ai/chat/folders", "/api/v1/ai/chat/history"]
        if boQuaDau.contains(where: { path.hasPrefix($0) }) { return false }
        if path.hasSuffix("/ai/actions") || path.hasSuffix("/ai/asks") { return false }
        // `/notes/ai/*`, `/finance/ai/*`, `/ielts/ai/*`, `/my-language/ai/*`,
        // `/courses/lessons/:id/ai/*`, `/exams/attempts/:id/ai/*`, `/ai/*`
        if path.contains("/ai/") { return true }
        // Tư vấn ngành (Academy): câu hỏi đi tới AI.
        if path == "/api/v1/academy/advisor" && method == "POST" { return true }
        guard method != "GET" else { return false }
        // Phỏng vấn thử: câu trả lời được AI chấm (trừ nút báo lỗi câu hỏi).
        if path.hasPrefix("/api/v1/interview/") && !path.hasSuffix("/flag") { return true }
        // CV: chấm, viết lại gạch đầu dòng, gợi ý theo việc, thư xin việc.
        if path.hasPrefix("/api/v1/cv/") {
            let ai = ["/critique", "/rewrite", "/tailor", "/cover-letter"]
            if ai.contains(where: { path.hasSuffix($0) }) { return true }
        }
        // Code Lab: huấn luyện viên AI chấm mã.
        if path.contains("/coach/") { return true }
        return false
    }
}

// MARK: - Hộp thoại hỏi

/// Giữ MỘT lượt hỏi đang mở, để năm lời gọi song song không bật năm hộp thoại.
@MainActor
private final class BoHoi {
    static let chung = BoHoi()
    private var dangHoi: Task<Bool, Never>?

    nonisolated func hoi() async -> Bool {
        await hoiTrenMain()
    }

    private func hoiTrenMain() async -> Bool {
        if DongYChiaSeAI.daDongY { return true }
        if let t = dangHoi { return await t.value }
        let t = Task { @MainActor in await Self.hienHop() }
        dangHoi = t
        let kq = await t.value
        dangHoi = nil
        if kq { UserDefaults.standard.set(true, forKey: DongYChiaSeAI.khoa) }
        return kq
    }

    #if os(iOS)
    /// Dùng `UIAlertController` trình bày trên view controller TRÊN CÙNG,
    /// không dùng `.sheet` của SwiftUI: AI Chat, gia sư, luyện nói… thường
    /// đã nằm trong một sheet/fullScreenCover, và một `.sheet` gắn ở gốc sẽ
    /// không hiện được lên trên đó ("already presenting") — tức là hộp thoại
    /// không bao giờ hiện và lời gọi chờ mãi.
    private static func hienHop() async -> Bool {
        guard let vc = vcTrenCung() else { return false }   // không hỏi được ⇒ không gửi
        return await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            var daTra = false
            func tra(_ v: Bool) {
                guard !daTra else { return }
                daTra = true
                c.resume(returning: v)
            }
            let a = UIAlertController(title: T(DongYChiaSeAI.tieuDe),
                                      message: T(DongYChiaSeAI.tomTat),
                                      preferredStyle: .alert)
            a.addAction(UIAlertAction(title: T("Không"), style: .cancel) { _ in tra(false) })
            let dongY = UIAlertAction(title: T("Đồng ý"), style: .default) { _ in tra(true) }
            a.addAction(dongY)
            a.preferredAction = dongY
            vc.present(a, animated: true)
            // Lưới an toàn: nếu hệ thống từ chối trình bày (đang có màn khác
            // đóng/mở dở) thì hộp thoại không bao giờ hiện và continuation sẽ
            // treo vĩnh viễn. Kiểm sau 1,5s — không hiện được thì coi như "Không".
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if a.presentingViewController == nil { tra(false) }
            }
        }
    }

    private static func vcTrenCung() -> UIViewController? {
        let canh = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .sorted { ($0.activationState == .foregroundActive ? 0 : 1) < ($1.activationState == .foregroundActive ? 0 : 1) }
        guard let cuaSo = canh.flatMap(\.windows).first(where: \.isKeyWindow) ?? canh.first?.windows.first,
              var vc = cuaSo.rootViewController else { return nil }
        while let tiep = vc.presentedViewController, !tiep.isBeingDismissed { vc = tiep }
        return vc
    }
    #else
    private static func hienHop() async -> Bool {
        let a = NSAlert()
        a.messageText = T(DongYChiaSeAI.tieuDe)
        a.informativeText = T(DongYChiaSeAI.tomTat)
        a.addButton(withTitle: T("Đồng ý"))
        a.addButton(withTitle: T("Không"))
        return a.runModal() == .alertFirstButtonReturn
    }
    #endif
}
