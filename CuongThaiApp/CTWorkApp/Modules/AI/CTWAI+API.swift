import Foundation

// MARK: - Trợ lý AI của dự án (kiểu MENTOR, web 18/10/2026) — API + model
//
// Đối chiếu api-backend: `work.routes.ts` 996–1066, `ai.service.ts → chat` (đọc thẻ/tệp/Docs/link rồi trả Markdown có
// link `/work/<ws>/<KEY>/issue/<n>`), `aiThreads.service.ts` (hội thoại lưu ở máy chủ, PROJECT = cả nhóm đọc được,
// PRIVATE = chỉ người tạo). Câu hỏi được LƯU TRƯỚC khi gọi AI: AI hỏng (502 `WORK_AI_BAD_OUTPUT`, 503
// `WORK_AI_UNAVAILABLE`…) ⇒ câu hỏi còn trong hội thoại với `error` ⇒ nút "Ask again" = `POST /ai/messages/:mid/retry`.
// Quyền hỏi: `permissions.useAi` (ADMIN/MEMBER); khách cổng bị chặn ở máy chủ (`CLIENT_PORTAL_ONLY`).
// Hạn mức: 402 `WORK_AI_QUOTA_EXCEEDED` có câu "Upgrade to Pro" ⇒ app KHÔNG hiện câu đó (3.1.1) — xem `TroLyAICTW.loi`.

extension CTWAPI {
    static func aiHanMuc() -> APIEndpoint { get("/ai/quota") }
    static func aiDsHoiThoai(pid: Int, chiCuaToi: Bool = false) -> APIEndpoint {
        get("/projects/\(pid)/ai/threads", chiCuaToi ? ["scope": "mine"] : nil)
    }
    static func aiHoiThoai(pid: Int, id: Int) -> APIEndpoint { get("/projects/\(pid)/ai/threads/\(id)") }
    /// Tạo hội thoại TRƯỚC câu hỏi đầu (câu đầu hỏng thì vẫn biết hội thoại nào có nút "Ask again").
    static func aiTaoHoiThoai(pid: Int, tieuDe: String, rieng: Bool) -> APIEndpoint {
        goi("/projects/\(pid)/ai/threads", "POST", ["title": String(tieuDe.prefix(2000)), "visibility": rieng ? "PRIVATE" : "PROJECT"])
    }
    static func aiXoaHoiThoai(pid: Int, id: Int) -> APIEndpoint { goi("/projects/\(pid)/ai/threads/\(id)", "DELETE", nil) }
    /// Chạy lâu (đọc thẻ/Docs/tệp rồi mới trả lời; tới vài lượt gọi model) — `APIEndpoint.thoiGianCho` = 180 s.
    static func aiHoi(pid: Int, cauHoi: String, threadId: Int, so: Int? = nil) -> APIEndpoint {
        var t: [String: Any] = ["message": String(cauHoi.prefix(8000)), "threadId": threadId]
        if let so { t["issueNumber"] = so }
        return goi("/projects/\(pid)/ai/chat", "POST", t)
    }
    static func aiHoiLai(pid: Int, mid: Int) -> APIEndpoint { goi("/projects/\(pid)/ai/messages/\(mid)/retry", "POST") }
    static func aiApDung(pid: Int, mid: Int, idx: Int) -> APIEndpoint { goi("/projects/\(pid)/ai/messages/\(mid)/actions/\(idx)/apply", "POST") }
    static func aiBoQua(pid: Int, mid: Int, idx: Int) -> APIEndpoint {
        goi("/projects/\(pid)/ai/messages/\(mid)/actions/\(idx)", "PATCH", ["status": "dismissed"])
    }
}

struct CTWAIHanMuc: Codable { var pro: Bool?; var used: Int?; var limit: Int?; var remaining: Int?; var available: Bool? }

/// Một đề xuất thay đổi của AI (chỉ chạy khi có người bấm Apply). `action` là JSON tự do theo `actionSchema`
/// ⇒ giải mã KHOAN DUNG từng trường (một trường sai kiểu không được làm hỏng cả câu trả lời).
struct CTWAIDeXuat: Codable, Hashable {
    struct ThanDeXuat: Codable, Hashable {
        var type: String?
        var title: String?
        var issueType: String?
        var number: Int?
        var numbers: [Int]?
        var text: String?
        var status: String?
        var sprint: String?
        var assignee: String?
        var dueDate: String?
        var heading: String?
        var command: String?
        var summary: String?
        private enum K: String, CodingKey { case type, title, issueType, number, numbers, text, status, sprint, assignee, dueDate, heading, command, summary }
        init(from d: Decoder) throws {
            guard let c = try? d.container(keyedBy: K.self) else { return }
            type = try? c.decodeIfPresent(String.self, forKey: .type)
            title = try? c.decodeIfPresent(String.self, forKey: .title)
            issueType = try? c.decodeIfPresent(String.self, forKey: .issueType)
            number = try? c.decodeIfPresent(Int.self, forKey: .number)
            numbers = try? c.decodeIfPresent([Int].self, forKey: .numbers)
            text = try? c.decodeIfPresent(String.self, forKey: .text)
            status = try? c.decodeIfPresent(String.self, forKey: .status)
            sprint = try? c.decodeIfPresent(String.self, forKey: .sprint)
            assignee = try? c.decodeIfPresent(String.self, forKey: .assignee)
            dueDate = try? c.decodeIfPresent(String.self, forKey: .dueDate)
            heading = try? c.decodeIfPresent(String.self, forKey: .heading)
            command = try? c.decodeIfPresent(String.self, forKey: .command)
            summary = try? c.decodeIfPresent(String.self, forKey: .summary)
        }
        func encode(to e: Encoder) throws {
            var c = e.container(keyedBy: K.self)
            try c.encodeIfPresent(type, forKey: .type); try c.encodeIfPresent(title, forKey: .title)
            try c.encodeIfPresent(number, forKey: .number)
        }
    }
    var index: Int
    /// pending | applying | done | error | dismissed
    var status: String?
    var summary: String?
    var number: Int?
    var error: String?
    var byName: String?
    var action: ThanDeXuat?

    /// Câu mô tả đề xuất cho người dùng (tiếng Anh).
    func moTa(ma: String) -> String {
        let a = action
        let the = a?.number.map { "\(ma)-\($0)" } ?? String(localized: "an issue")
        switch a?.type {
        case "create_issue": return String(localized: "Create \((a?.issueType ?? String(localized: "issue")).lowercased()) “\(a?.title ?? "")”")
        case "update_issue":
            var phan: [String] = []
            if let s = a?.status { phan.append(String(localized: "status → \(s)")) }
            if let s = a?.assignee { phan.append(String(localized: "assignee → @\(s)")) }
            if let s = a?.dueDate { phan.append(String(localized: "due → \(s)")) }
            if let s = a?.sprint { phan.append(String(localized: "sprint → \(s)")) }
            if a?.title != nil { phan.append(String(localized: "title")) }
            return phan.isEmpty ? String(localized: "Update \(the)") : String(localized: "Update \(the): \(phan.joined(separator: ", "))")
        case "add_comment": return String(localized: "Comment on \(the)")
        case "move_to_sprint": return String(localized: "Move \(a?.numbers?.count ?? 0) issue(s) to \(a?.sprint ?? String(localized: "a sprint"))")
        case "create_test": return String(localized: "Create test case “\(a?.title ?? "")”")
        case "draft_page": return String(localized: "Draft Docs page “\(a?.title ?? "")”")
        case "update_page_section": return String(localized: "Update section “\(a?.heading ?? "")” of Docs #\(a?.number ?? 0)")
        case "command": return a?.summary ?? (a?.command ?? String(localized: "Run a project command"))
        default: return a?.summary ?? String(localized: "Suggested change")
        }
    }
}

struct CTWAITinNhan: Codable, Hashable, Identifiable {
    var id: Int
    var threadId: Int?
    /// user | assistant
    var role: String
    var content: String
    var title: String?
    var issueNumber: Int?
    /// Câu hỏi chưa được trả lời (AI hỏng) — có nút "Ask again".
    var error: String?
    var createdAt: String?
    var author: CTWUser?
    var actions: [CTWAIDeXuat]?

    var laAI: Bool { role == "assistant" }
}

struct CTWAIHoiThoai: Codable, Hashable, Identifiable {
    var id: Int
    var title: String
    /// PROJECT | PRIVATE
    var visibility: String?
    /// CHAT | DEFENSE
    var mode: String?
    var issueNumber: Int?
    var messageCount: Int?
    var lastMessageAt: String?
    var createdAt: String?
    var createdById: Int?
    var createdBy: CTWUser?
    var participants: [CTWUser]?
    var mine: Bool?
    var canManage: Bool?
    var messages: [CTWAITinNhan]?

    var rieng: Bool { visibility == "PRIVATE" }
}

/// `POST /ai/chat` ⇒ `{reply, actions, quota, threadId, question, answer}`.
struct CTWAIKetQua: Codable {
    var reply: String?
    var threadId: Int?
    var question: CTWAITinNhan?
    var answer: CTWAITinNhan?
    var quota: CTWAIHanMuc?
}
