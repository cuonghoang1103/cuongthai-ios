import Foundation

// MARK: - CT Work — model mô-đun Chat (`services/work/chat.service.ts`, `present()` ~dòng 513;
// `chatFiles.service.ts` cho tệp/voice). Luật: mọi trường `var` + optional, ngày là chuỗi (CLAUDE.md C3/C4).

// MARK: Đếm chưa đọc

struct CTWChatUnread: Codable {
    struct DuAn: Codable, Hashable { var projectId: Int; var unread: Int?; var mentions: Int? }
    var total: Int?
    var projects: [DuAn]?
}

// MARK: Kênh

/// Cuộc gọi đang mở của kênh (≤ 4 giờ) — `listChannels().call`.
struct CTWCallInfo: Codable, Hashable {
    var url: String?
    var startedAt: String?
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
    var mutedUntil: String?
    var mutedForever: Bool?
    /// DEFAULT | ALL | MENTIONS
    var notify: String?
    var member: Bool?
    var canPost: Bool?
    var canManage: Bool?
    var call: CTWCallInfo?

    var laRieng: Bool { kind == "PRIVATE" }
    var laKhach: Bool { kind == "CLIENT" }
    var bieuTuong: String { laRieng ? "lock.fill" : (laKhach ? "person.2.fill" : "number") }
}

struct CTWChatMe: Codable, Hashable {
    var audience: String?
    var canCreate: Bool?
    var canCreateClient: Bool?
    var canModerate: Bool?
}

struct CTWChannelList: Codable {
    var channels: [CTWChannel]?
    var total: Int?
    var me: CTWChatMe?
}

/// Thành viên kênh: `PUBLIC_USER` phẳng + `role` + `online` (null với agent).
struct CTWChannelMember: Codable, Hashable, Identifiable {
    var id: Int
    var username: String?
    var fullName: String?
    var displayName: String?
    var avatarUrl: String?
    var kind: String?
    var role: String?
    var online: Bool?

    var nguoi: CTWUser {
        CTWUser(id: id, username: username, fullName: fullName, displayName: displayName,
                avatarUrl: avatarUrl, role: role, kind: kind)
    }
}

/// `POST /chat/channels` ⇒ `{ id, name, kind }`.
struct CTWKenhMoi: Codable { var id: Int; var name: String?; var kind: String? }

/// `PUT /channels/:cid/notify` ⇒ trạng thái báo của kênh.
struct CTWKenhBao: Codable {
    var channelId: Int?
    var mutedUntil: String?
    var mutedForever: Bool?
    var notify: String?
}

/// `GET|PUT /chat/prefs` — cài đặt chat CHUNG của người dùng.
struct CTWChatPrefs: Codable, Hashable {
    var mutedUntil: String?
    var mutedForever: Bool?
    /// ALL | MENTIONS
    var notify: String?
    var sound: Bool?
    var desktop: Bool?
    var emailDigest: Bool?
    var quietStart: Int?
    var quietEnd: Int?
    var quietNow: Bool?
}

// MARK: Tin

struct CTWVoiceInfo: Codable, Hashable {
    var durationMs: Int?
    /// PENDING | DONE | FAILED | SKIPPED
    var transcriptStatus: String?
    var transcript: String?
    var language: String?
}

struct CTWChatFile: Codable, Hashable, Identifiable {
    var id: Int
    var fileName: String?
    var mime: String?
    var size: Int?
    var createdAt: String?
    var voice: CTWVoiceInfo?

    var laAnh: Bool { (mime ?? "").hasPrefix("image/") }
    var laGiongNoi: Bool { voice != nil }
    var bieuTuong: String {
        let m = mime ?? ""
        if m.hasPrefix("image/") { return "photo" }
        if m.hasPrefix("video/") { return "film" }
        if m.hasPrefix("audio/") { return "waveform" }
        if m.contains("pdf") { return "doc.richtext" }
        if m.contains("zip") || m.contains("compressed") { return "doc.zipper" }
        if m.contains("sheet") || m.contains("excel") || m.contains("csv") { return "tablecells" }
        if m.contains("presentation") || m.contains("powerpoint") { return "rectangle.on.rectangle" }
        return "doc"
    }
    var coChu: String? {
        guard let size else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
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

/// Link web ngoài trong tin.
struct CTWWebLink: Codable, Hashable {
    var url: String?
    var domain: String?
    var title: String?
}

/// `meta` của tin hệ thống: `{type:'call', url}` · `{type:'issue', key, number, title, url}` · `{type:'created'}`…
struct CTWChatMeta: Codable, Hashable {
    var type: String?
    var url: String?
    var key: String?
    var number: Int?
    var title: String?

    private enum CodingKeys: String, CodingKey { case type, url, key, number, title }
    init(type: String? = nil, url: String? = nil) { self.type = type; self.url = url }
    init(from decoder: Decoder) throws {
        guard let c = try? decoder.container(keyedBy: CodingKeys.self) else { return }
        type = try? c.decodeIfPresent(String.self, forKey: .type)
        url = try? c.decodeIfPresent(String.self, forKey: .url)
        key = try? c.decodeIfPresent(String.self, forKey: .key)
        number = try? c.decodeIfPresent(Int.self, forKey: .number)
        title = try? c.decodeIfPresent(String.self, forKey: .title)
    }
}

struct CTWPinInfo: Codable, Hashable {
    var at: String?
    var byId: Int?
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
    var meta: CTWChatMeta?
    var pinned: CTWPinInfo?
    var reactions: [CTWReaction]?
    var files: [CTWChatFile]?
    var links: [CTWWebLink]?
    var previews: [CTWRefPreview]?

    private enum CodingKeys: String, CodingKey {
        case id, channelId, kind, parentId, replyCount, lastReplyAt, createdAt, editedAt, deleted,
             clientKey, body, author, mentions, meta, pinned, reactions, files, links, previews
    }

    init(id: Int, body: String, author: CTWUser?, createdAt: String?) {
        self.id = id; self.body = body; self.author = author; self.createdAt = createdAt
        kind = "USER"
    }

    /// Khoan dung: mảng phụ (reactions/files/previews/links) hay `meta` hỏng thì
    /// thành rỗng, không làm hỏng cả trang tin.
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
        meta = try? c.decodeIfPresent(CTWChatMeta.self, forKey: .meta)
        pinned = try? c.decodeIfPresent(CTWPinInfo.self, forKey: .pinned)
        reactions = try? c.decodeIfPresent([CTWReaction].self, forKey: .reactions)
        files = try? c.decodeIfPresent([CTWChatFile].self, forKey: .files)
        links = try? c.decodeIfPresent([CTWWebLink].self, forKey: .links)
        previews = try? c.decodeIfPresent([CTWRefPreview].self, forKey: .previews)
    }

    var laHeThong: Bool { kind == "SYSTEM" }
    var daXoa: Bool { deleted == true }
    var daGhim: Bool { pinned != nil }
    /// Tin hệ thống "started a call" — có nút Join.
    var laCuocGoi: Bool { laHeThong && meta?.type == "call" }
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

// MARK: Kết quả thao tác

struct CTWReactionKQ: Codable { var messageId: Int?; var reactions: [CTWReaction]? }
struct CTWPinKQ: Codable { var messageId: Int?; var pinned: Bool? }
struct CTWCallKQ: Codable { var url: String?; var reused: Bool?; var messageId: Int? }
struct CTWUrlKQ: Codable { var url: String? }
struct CTWTheTuTinKQ: Codable { var number: Int?; var key: String?; var url: String? }
struct CTWDaDocKQ: Codable { var channelId: Int?; var lastReadId: Int? }

/// "Đang gõ" của một người trong kênh (socket `work:chat:typing`).
struct SuKienGoCTW {
    var projectId: Int
    var channelId: Int
    var threadId: Int?
    var dangGo: Bool
    var user: CTWUser?
}
