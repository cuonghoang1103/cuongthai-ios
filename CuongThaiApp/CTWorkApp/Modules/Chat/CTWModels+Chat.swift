import Foundation

// MARK: - CT Work — model mô-đun Chat (`services/work/chat.service.ts`, `present()` ~dòng 513)
// Luật: mọi trường `var` + optional, ngày là chuỗi (CLAUDE.md C3/C4).

// MARK: Chat

struct CTWChatUnread: Codable {
    struct DuAn: Codable, Hashable { var projectId: Int; var unread: Int?; var mentions: Int? }
    var total: Int?
    var projects: [DuAn]?
}

struct CTWChannel: Codable, Hashable, Identifiable {
    var id: Int
    var name: String
    var topic: String?
    /// PUBLIC | PRIVATE | CLIENT
    var kind: String?
    var isGeneral: Bool?
    var archived: Bool?
    var lastMessageAt: String?
    var unread: Int?
    var mentions: Int?
    var badge: Int?
    var lastReadId: Int?
    var muted: Bool?
    var member: Bool?
    var canPost: Bool?
    var canManage: Bool?
}

struct CTWChatMe: Codable, Hashable {
    var audience: String?
    var canCreate: Bool?
    var canModerate: Bool?
}

struct CTWChannelList: Codable {
    var channels: [CTWChannel]?
    var total: Int?
    var me: CTWChatMe?
}

struct CTWChatFile: Codable, Hashable, Identifiable {
    var id: Int
    var fileName: String?
    var mime: String?
    var size: Int?
    var createdAt: String?
}

struct CTWReaction: Codable, Hashable {
    var emoji: String
    var count: Int?
    var mine: Bool?
}

/// Thẻ/tài liệu được nhắc trong tin (`KEY-12`, link `/work/...`).
struct CTWRefPreview: Codable, Hashable {
    var t: String?
    var key: String?
    var n: Int?
    var url: String?
    var title: String?
}

struct CTWChatMessage: Codable, Hashable, Identifiable {
    var id: Int
    var channelId: Int?
    /// USER | SYSTEM
    var kind: String?
    var parentId: Int?
    var replyCount: Int?
    var lastReplyAt: String?
    var createdAt: String?
    var editedAt: String?
    var deleted: Bool?
    var clientKey: String?
    /// Markdown thô.
    var body: String?
    var author: CTWUser?
    var mentions: [Int]?
    var reactions: [CTWReaction]?
    var files: [CTWChatFile]?
    var previews: [CTWRefPreview]?

    private enum CodingKeys: String, CodingKey {
        case id, channelId, kind, parentId, replyCount, lastReplyAt, createdAt, editedAt, deleted,
             clientKey, body, author, mentions, reactions, files, previews
    }

    init(id: Int, body: String, author: CTWUser?, createdAt: String?) {
        self.id = id; self.body = body; self.author = author; self.createdAt = createdAt
        kind = "USER"
    }

    /// Khoan dung: mảng phụ (reactions/files/previews) hỏng thì thành rỗng,
    /// không làm hỏng cả trang tin.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        channelId = try? c.decodeIfPresent(Int.self, forKey: .channelId)
        kind = try? c.decodeIfPresent(String.self, forKey: .kind)
        parentId = try? c.decodeIfPresent(Int.self, forKey: .parentId)
        replyCount = try? c.decodeIfPresent(Int.self, forKey: .replyCount)
        lastReplyAt = try? c.decodeIfPresent(String.self, forKey: .lastReplyAt)
        createdAt = try? c.decodeIfPresent(String.self, forKey: .createdAt)
        editedAt = try? c.decodeIfPresent(String.self, forKey: .editedAt)
        deleted = try? c.decodeIfPresent(Bool.self, forKey: .deleted)
        clientKey = try? c.decodeIfPresent(String.self, forKey: .clientKey)
        body = try? c.decodeIfPresent(String.self, forKey: .body)
        author = try? c.decodeIfPresent(CTWUser.self, forKey: .author)
        mentions = try? c.decodeIfPresent([Int].self, forKey: .mentions)
        reactions = try? c.decodeIfPresent([CTWReaction].self, forKey: .reactions)
        files = try? c.decodeIfPresent([CTWChatFile].self, forKey: .files)
        previews = try? c.decodeIfPresent([CTWRefPreview].self, forKey: .previews)
    }

    var laHeThong: Bool { kind == "SYSTEM" }
    var daXoa: Bool { deleted == true }
}

struct CTWChatPage: Codable {
    var messages: [CTWChatMessage]?
    var hasMoreBefore: Bool?
    var hasMoreAfter: Bool?
}

struct CTWChatThread: Codable {
    var root: CTWChatMessage?
    var replies: [CTWChatMessage]?
}

