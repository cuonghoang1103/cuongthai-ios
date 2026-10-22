import Foundation

// MARK: - Dịch câu lỗi của máy chủ CT Work (20/10/2026)
//
// Máy chủ CT Work KHÔNG đọc `Accept-Language`: câu lỗi luôn là tiếng Anh, kèm `code` (WORK_*). Web dịch ở phía client
// (`api-backend/frontend/src/components/work/i18n/errors.ts`); tệp này là bản iOS của cùng bảng đó, để người dùng thấy
// CÙNG một câu tiếng Việt trên web lẫn app. Chỉ dùng khi app đang tiếng Việt (`CTWDinhDang.laTiengViet`) — tiếng Anh
// thì giữ nguyên câu máy chủ như web. Không khớp gì ⇒ nil ⇒ giữ câu gốc.
//
// ⚠️ Mỗi câu là `String(localized:)` với khoá = câu tiếng Anh của web (en/errors.ts) ⇒ bản dịch nằm trong catalog.
// Hàm, không phải `static let` (dịch lúc gọi, theo ngôn ngữ đang chọn).

enum CTWLoiDich {
    static func theoMa(_ ma: String) -> String? {
        switch ma {
        case "WORK_EDIT_LOCKED": return String(localized: "Editing is locked for this project. Unlock it to make changes.")
        case "WORK_STALE", "WORK_SPEC_STALE": return String(localized: "Someone else just changed this. Reload to see the latest version.")
        case "WORK_AI_UNAVAILABLE": return String(localized: "AI is unavailable right now. Try again later.")
        case "WORK_AI_TOKEN_CAP": return String(localized: "You’ve reached today’s AI limit. Try again tomorrow.")
        case "WORK_AI_BAD_OUTPUT", "WORK_AI_BAD_REPLY", "WORK_AI_BAD_ANSWER": return String(localized: "The AI returned something we couldn’t use. Try again.")
        case "WORK_AGENT_PAUSED": return String(localized: "This AI agent is paused.")
        case "WORK_AGENT_RETIRED": return String(localized: "This AI agent is retired.")
        case "WORK_INTERNAL_ONLY": return String(localized: "Only your team can see this — it’s hidden from the client.")
        case "WORK_FINANCE_FORBIDDEN": return String(localized: "You need finance access in this project.")
        case "WORK_EXPORT_EXPIRED", "WORK_EXPORT_LINK_EXPIRED": return String(localized: "This export has expired. Create it again.")
        case "WORK_EXPORT_RUNNING", "WORK_EXPORT_BUSY", "WORK_IMPORT_RUNNING", "WORK_IMPORT_BUSY":
            return String(localized: "Another import or export is already running. Wait for it to finish.")
        case "WORK_IMPORT_TOO_LARGE": return String(localized: "The file is too large to import.")
        case "WORK_LEASE_TAKEN": return String(localized: "Someone else is working on this right now.")
        case "WORK_STORAGE_OFF": return String(localized: "File storage is not available right now.")
        case "WORK_URL_BLOCKED": return String(localized: "That link can’t be used.")
        case "WORK_WEB_LINK_DUPLICATE": return String(localized: "This link is already added.")
        case "WORK_APPROVAL_NOT_YOUR_TURN": return String(localized: "It isn’t your turn to approve yet.")
        case "WORK_BASELINED": return String(localized: "This item is frozen in an approved baseline. Raise a change request that lists it and get it approved before editing.")
        case "WORK_REVIEW_NOT_READY": return String(localized: "The review cannot be closed yet — finish the checklist, add a moderator and record the decision.")
        case "WORK_REVIEW_REINSPECT": return String(localized: "The decision is “re-inspect”: move the review to Rework and hold the meeting again.")
        case "WORK_QUIZ_TIME_UP": return String(localized: "Time is up — your saved answers were submitted")
        case "WORK_QUIZ_NOT_OPEN": return String(localized: "This quiz is not open yet")
        case "WORK_QUIZ_CLOSED": return String(localized: "This quiz is closed.")
        case "WORK_QUIZ_NO_ATTEMPTS": return String(localized: "You have used all your attempts.")
        case "WORK_QUIZ_SUBMITTED": return String(localized: "This attempt has already been submitted")
        case "WORK_QUIZ_HAS_ATTEMPTS": return String(localized: "Students have started this quiz — set a close time instead")
        case "PAYLOAD_TOO_LARGE": return String(localized: "The file or image is too large. Send a smaller one.")
        case "UNAUTHORIZED": return String(localized: "Your session has expired. Sign in again.")
        default: return nil
        }
    }

    static func theoCau(_ cau: String) -> String? {
        let m = cau.trimmingCharacters(in: .whitespacesAndNewlines)
        switch m {
        case "Title is required": return String(localized: "Title is required")
        case "Nothing to change": return String(localized: "Nothing to change")
        case "Files must be 25 MB or smaller": return String(localized: "Files must be 25 MB or smaller")
        case "\"From\" must be before \"to\"": return String(localized: "“From” must be before “to”")
        case "The end date must be after the start date": return String(localized: "The end date must be after the start date")
        case "This issue is already done": return String(localized: "This issue is already done")
        case "This invitation has already been used": return String(localized: "This invitation has already been used")
        case "The file is empty": return String(localized: "The file is empty")
        case "Use a PNG, JPEG, WebP or GIF image": return String(localized: "Use a PNG, JPEG, WebP or GIF image")
        case "You can read this page but not edit it": return String(localized: "You can read this page but not edit it")
        case "You cannot edit issues in this project": return String(localized: "You cannot edit issues in this project")
        case "You cannot comment in this project": return String(localized: "You cannot comment in this project")
        case "Already linked": return String(localized: "Already linked")
        case "That workspace URL is taken, try another name": return String(localized: "That workspace URL is taken, try another name")
        case "The board changed while you were dragging. Reload and try again.":
            return String(localized: "The board changed while you were dragging. Reload and try again.")
        case "You do not have permission to do this in this project": return String(localized: "You don’t have permission to do this in this project.")
        case "You do not have permission to do this in this workspace": return String(localized: "You don’t have permission to do this in this workspace.")
        case "Access denied", "Forbidden": return String(localized: "You don’t have permission to do this.")
        case "Internal Server Error": return String(localized: "The server ran into a problem. Try again in a moment.")
        default: break
        }
        // "<thứ> not found" / "Someone else just changed this <thứ>".
        if m.range(of: #"^(.+?) not found(?: in this (?:project|workspace|team queue))?\.?$"#, options: [.regularExpression, .caseInsensitive]) != nil {
            let thu = m.replacingOccurrences(of: #" not found.*$"#, with: "", options: [.regularExpression, .caseInsensitive])
            if let ten = danhTu(thu) { return String(localized: "\(ten) not found") }
            return String(localized: "Not found")
        }
        if m.range(of: #"^Someone else (?:just )?changed this"#, options: [.regularExpression, .caseInsensitive]) != nil {
            let sau = m.replacingOccurrences(of: #"^Someone else (?:just )?changed this\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
            let thu = sau.replacingOccurrences(of: #"\s*[—.\-].*$"#, with: "", options: .regularExpression)
            if let ten = danhTu(thu) { return String(localized: "Someone else just changed this \(ten). Reload to see the latest version.") }
            return String(localized: "Someone else just changed this. Reload to see the latest version.")
        }
        return nil
    }

    /// Danh từ trong câu lỗi — viết thường khi chèn giữa câu tiếng Việt cũng ổn ("Không tìm thấy thẻ").
    static func danhTu(_ s: String) -> String? {
        switch s.lowercased() {
        case "issue": return String(localized: "Issue")
        case "project": return String(localized: "Project")
        case "workspace": return String(localized: "Workspace")
        case "sprint": return String(localized: "Sprint")
        case "version": return String(localized: "Version")
        case "comment": return String(localized: "Comment")
        case "member": return String(localized: "Member")
        case "document": return String(localized: "Document")
        case "meeting": return String(localized: "Meeting")
        case "label": return String(localized: "Label")
        case "link": return String(localized: "Link")
        case "stage": return String(localized: "Stage")
        case "function": return String(localized: "Function")
        case "rule": return String(localized: "Rule")
        case "attachment": return String(localized: "Attachment")
        case "agent": return String(localized: "AI agent")
        case "report": return String(localized: "Report")
        case "token": return String(localized: "Token")
        case "change request": return String(localized: "Change request")
        case "use case": return String(localized: "Use case")
        case "item": return String(localized: "Item")
        case "question": return String(localized: "Question")
        default: return nil
        }
    }

    // MARK: Bộ lọc nội dung (App Store 1.2 — 422 `CONTENT_BLOCKED`, build 7)
    //
    // Máy chủ (api-backend `services/locNoiDung.ts › THONG_BAO_CHAN`) trả MỘT câu SONG NGỮ "<tiếng Việt> · <English>"
    // cho mọi cửa ghi (bài/bình luận Bảng tin, tin nhắn riêng, tin kênh, bình luận thẻ/trang, tên + giới thiệu hồ sơ).
    // App hiện NỬA theo ngôn ngữ đang chọn — vẫn là câu của máy chủ, chỉ không bắt người dùng đọc hai thứ tiếng.
    // Không tách được (máy chủ đổi câu) ⇒ câu catalog cùng nghĩa.

    static let maNoiDungBiChan = "CONTENT_BLOCKED"

    static func noiDungBiChan(_ cau: String) -> String {
        let phan = cau.components(separatedBy: " · ").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if phan.count == 2 {
            // Nửa nào là tiếng Việt: nửa có chữ có dấu (ký tự Latin mở rộng). Không đoán theo vị trí — máy chủ có thể đảo.
            let coDau: (String) -> Bool = { $0.unicodeScalars.contains { (0x00C0...0x1EFF).contains($0.value) } }
            let vi = phan.first(where: coDau) ?? phan[0]
            let en = phan.first(where: { !coDau($0) }) ?? phan[1]
            return CTWDinhDang.laTiengViet ? vi : en
        }
        return String(localized: "This contains words that aren't allowed in CT Work (profanity, slurs, sexual or threatening language). Please edit it.")
    }

    /// Lỗi này là bộ lọc nội dung từ chối (giữ nguyên bản nháp, báo tại chỗ — không "Thử lại" vô ích).
    static func laNoiDungBiChan(_ e: Error) -> Bool {
        if case APIError.coMa(let ma, _) = e { return ma == maNoiDungBiChan }
        return false
    }

    /// Câu máy chủ ⇒ câu theo ngôn ngữ app (chỉ khi tiếng Việt). nil = giữ câu gốc.
    static func dich(ma: String?, cau: String) -> String? {
        guard CTWDinhDang.laTiengViet else { return nil }
        if let ma, let c = theoMa(ma) { return c }
        return theoCau(cau)
    }
}
