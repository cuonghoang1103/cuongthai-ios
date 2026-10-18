import Foundation

// MARK: - CT Work — model Hộp thư (thông báo WORK_*)
//
// Cùng đường `GET /api/v1/social/notifications` với app chính, nhưng giải mã ĐỦ khoá
// payload CT Work cần (`chat`, `reply`, `approvalId`) — model chung `TaiTrongThongBao`
// của app chính chỉ đọc vài khoá và không được phình vì app CT Work.
// Payload do `services/work/notify.ts`, `chat.service.ts → fanOut`, `approvals.service.ts`
// dựng: `{issueKey, title, url, excerpt?, message?, chat?, reply?, approvalId?, surface:'work'}`.

struct CTWTaiTrong: Codable, Hashable {
    var url: String?
    var issueKey: String?
    var title: String?
    var excerpt: String?
    var message: String?
    var workspaceName: String?
    var chat: Bool?
    var reply: Bool?
    var approvalId: Int?
    /// Nhắc họp (`reminder: true`) có link vào họp ⇒ nút "Join" (cùng khoá với gói đẩy `CTW_MEETING`).
    var meetingUrl: String?
    var reminder: Bool?

    private enum CodingKeys: String, CodingKey { case url, issueKey, title, excerpt, message, workspaceName, chat, reply, approvalId, meetingUrl, reminder }
    init() {}
    /// Không bao giờ ném: payload là JSON tự do — một khoá sai kiểu không được làm hỏng cả hộp thư.
    init(from decoder: Decoder) throws {
        guard let c = try? decoder.container(keyedBy: CodingKeys.self) else { return }
        url = try? c.decodeIfPresent(String.self, forKey: .url)
        issueKey = try? c.decodeIfPresent(String.self, forKey: .issueKey)
        title = try? c.decodeIfPresent(String.self, forKey: .title)
        excerpt = try? c.decodeIfPresent(String.self, forKey: .excerpt)
        message = try? c.decodeIfPresent(String.self, forKey: .message)
        workspaceName = try? c.decodeIfPresent(String.self, forKey: .workspaceName)
        chat = try? c.decodeIfPresent(Bool.self, forKey: .chat)
        reply = try? c.decodeIfPresent(Bool.self, forKey: .reply)
        approvalId = try? c.decodeIfPresent(Int.self, forKey: .approvalId)
        meetingUrl = try? c.decodeIfPresent(String.self, forKey: .meetingUrl)
        reminder = try? c.decodeIfPresent(Bool.self, forKey: .reminder)
    }
}

struct CTWNguoiGui: Codable, Hashable {
    var id: Int
    var username: String?
    var fullName: String?
    var displayName: String?
    var avatarUrl: String?
    var kind: String?
    var nguoi: CTWUser { CTWUser(id: id, username: username, fullName: fullName, displayName: displayName, avatarUrl: avatarUrl, kind: kind) }
}

struct CTWThongBao: Codable, Hashable, Identifiable {
    var id: Int
    var type: String
    var entityId: Int?
    var secondaryEntityId: Int?
    var isRead: Bool
    var createdAt: String?
    var sender: CTWNguoiGui?
    var payload: CTWTaiTrong?

    private enum CodingKeys: String, CodingKey { case id, type, entityId, secondaryEntityId, isRead, createdAt, sender, payload }
    init(id: Int, type: String, isRead: Bool, payload: CTWTaiTrong?) {
        self.id = id; self.type = type; self.isRead = isRead; self.payload = payload
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        type = (try? c.decode(String.self, forKey: .type)) ?? ""
        entityId = try? c.decodeIfPresent(Int.self, forKey: .entityId)
        secondaryEntityId = try? c.decodeIfPresent(Int.self, forKey: .secondaryEntityId)
        isRead = (try? c.decode(Bool.self, forKey: .isRead)) ?? false
        createdAt = try? c.decodeIfPresent(String.self, forKey: .createdAt)
        sender = try? c.decodeIfPresent(CTWNguoiGui.self, forKey: .sender)
        payload = try? c.decodeIfPresent(CTWTaiTrong.self, forKey: .payload)
    }

    var laCTW: Bool { type.hasPrefix("WORK_") }
    var laChat: Bool { payload?.chat == true }
    var laPheDuyet: Bool { payload?.approvalId != nil && type == "WORK_ALERT" && (payload?.message ?? "").localizedCaseInsensitiveContains("approval is requested") }
    /// Nhắc họp có link vào họp (http/https) ⇒ nút Join.
    var linkVaoHop: URL? {
        guard type == "WORK_ALERT", let s = payload?.meetingUrl, let u = URL(string: s),
              let sc = u.scheme?.lowercased(), sc == "https" || sc == "http" else { return nil }
        return u
    }
    /// Trả lời được ngay (bình luận / nhắc / trả lời trong chat hoặc thẻ).
    var traLoiDuoc: Bool { (type == "WORK_COMMENT" || type == "WORK_MENTION") && payload?.url != nil }

    /// Khoá nhóm: một thẻ (`NW-12`) hoặc một kênh (`#general` của dự án).
    var khoaNhom: String {
        let k = payload?.issueKey ?? "CT Work"
        if laChat { return "\(payload?.title ?? "") \(k)" }
        return k
    }

    /// Bộ lọc chip.
    var loai: String {
        if laPheDuyet { return "approvals" }
        switch type {
        case "WORK_MENTION": return "mentions"
        case "WORK_ASSIGN": return "assigned"
        case "WORK_COMMENT": return "comments"
        case "WORK_ALERT": return "alerts"
        default: return "other"
        }
    }

    var bieuTuong: String {
        if laPheDuyet { return "checkmark.seal.fill" }
        switch type {
        case "WORK_ASSIGN": return "person.fill.checkmark"
        case "WORK_COMMENT": return laChat ? "bubble.left.fill" : "text.bubble.fill"
        case "WORK_MENTION": return "at"
        case "WORK_ALERT": return "exclamationmark.circle.fill"
        case "WORK_INVITE": return "rectangle.3.group.fill"
        default: return "bell.fill"
        }
    }

    /// Câu hiện (tiếng Anh — quyết định sản phẩm CT Work).
    var cau: String {
        let p = payload
        switch type {
        case "WORK_ASSIGN": return "assigned you \(p?.issueKey ?? "an issue")" + (p?.title.map { ": \($0)" } ?? "")
        case "WORK_COMMENT":
            if laChat { return "replied in \(p?.issueKey ?? "a thread")" + (p?.excerpt.map { ": \($0)" } ?? "") }
            return (p?.reply == true ? "replied on " : "commented on ") + (p?.issueKey ?? "an issue") + (p?.excerpt.map { ": \($0)" } ?? "")
        case "WORK_MENTION": return "mentioned you in \(p?.issueKey ?? "an issue")" + (p?.excerpt.map { ": \($0)" } ?? "")
        case "WORK_ALERT": return "\(p?.issueKey ?? "CT Work"): \(p?.message ?? "needs your attention")"
        case "WORK_INVITE": return "added you to \(p?.workspaceName ?? "a CT Work workspace")"
        default: return "has an update"
        }
    }
}

struct CTWTrangThongBao: Codable {
    struct PhanTrang: Codable { var nextCursor: Int?; var hasNextPage: Bool? }
    var items: [CTWThongBao]
    var pagination: PhanTrang?
    var unreadCount: Int?
}

/// `GET|PUT /api/v1/work/me/notify-settings` — email theo thông báo + giờ im lặng + đẩy theo loại + múi giờ.
struct CTWCaiDatBao: Codable, Hashable {
    /// Công tắc đẩy theo loại (`goiDayCtw.ts → PUSH_KEYS`). Thiếu khoá = BẬT (máy chủ cũng hiểu vậy).
    struct Day: Codable, Hashable {
        var assign: Bool?
        var comment: Bool?
        var mention: Bool?
        var alert: Bool?
        var approval: Bool?
        var chatAll: Bool?
    }
    /// INSTANT | DIGEST | OFF
    var emailMode: String?
    var quietStart: Int?
    var quietEnd: Int?
    var push: Day?
    /// Tên IANA; `nil` = máy chủ dùng Asia/Ho_Chi_Minh.
    var timezone: String?
}

/// `GET /social/notifications/unread-count?surface=work`.
struct CTWSoChuaDoc: Codable { var unreadCount: Int? }
