import Foundation

// MARK: - CT Work — model mô-đun Cuộc họp
// Nguồn: `services/work/meetings.service.ts` (listRow / getMeeting), `meetingRec.service.ts`
// (getRoom / getTranscript / rsvp / join), `meetingRules.ts` (AgendaItem, MinutesContent).
// Luật: mọi trường `var` + optional, ngày là chuỗi (CLAUDE.md C3/C4).

/// Người dự họp: `PUBLIC_USER` phẳng + `isClient` (chỉ có ở chi tiết).
struct CTWNguoiHop: Codable, Hashable, Identifiable {
    var id: Int
    var username: String?
    var fullName: String?
    var displayName: String?
    var avatarUrl: String?
    var kind: String?
    var isClient: Bool?

    var nguoi: CTWUser {
        CTWUser(id: id, username: username, fullName: fullName, displayName: displayName, avatarUrl: avatarUrl, kind: kind)
    }
}

struct CTWHopTrangThaiThe: Codable, Hashable { var name: String?; var category: String? }

/// Thẻ sinh từ một việc của cuộc họp.
struct CTWHopTheRef: Codable, Hashable {
    var number: Int?
    var key: String?
    var title: String?
    var done: Bool?
    var status: CTWHopTrangThaiThe?
}

/// Việc cần làm (action item).
struct CTWHopViec: Codable, Hashable, Identifiable {
    var id: Int
    var position: Int?
    var text: String
    /// `YYYY-MM-DD`
    var dueDate: String?
    var assignee: CTWUser?
    var issue: CTWHopTheRef?
}

struct CTWHopLienKet: Codable, Hashable { var number: Int; var title: String?; var startsAt: String? }

struct CTWHopChuoi: Codable, Hashable {
    var id: Int?
    var title: String?
    var summary: String?
    var ended: Bool?
    var detached: Bool?
}

struct CTWMeeting: Codable, Hashable, Identifiable {
    var id: Int
    var number: Int
    var key: String?
    var title: String
    /// KICKOFF | DAILY | WEEKLY | DEMO | RETRO | STEERING | CLIENT | ELICITATION | PLANNING | MENTOR | OTHER
    var type: String?
    var typeLabel: String?
    /// SCHEDULED | DONE | CANCELLED
    var status: String?
    var startsAt: String?
    var endsAt: String?
    var timezone: String?
    var location: String?
    var meetingUrl: String?
    /// MEET | ZOOM | TEAMS | JITSI | OTHER | null
    var provider: String?
    var minutesShared: Bool?
    var organizer: CTWUser?
    var attendees: [CTWNguoiHop]?
    var actionCount: Int?
    var actionsOpen: Int?
    var seriesId: Int?
    var templateKey: String?
    var createdAt: String?
    var updatedAt: String?
    // — chỉ ở chi tiết —
    var agendaJson: CTWNode?
    var minutesJson: CTWNode?
    var decisions: [String]?
    var version: Int?
    var actions: [CTWHopViec]?
    var previous: CTWHopLienKet?
    var next: [CTWHopLienKet]?
    var series: CTWHopChuoi?
    var hasClients: Bool?
    var canEdit: Bool?
    var canDelete: Bool?
    var canCreateIssues: Bool?

    private enum CodingKeys: String, CodingKey {
        case id, number, key, title, type, typeLabel, status, startsAt, endsAt, timezone, location, meetingUrl, provider,
             minutesShared, organizer, attendees, actionCount, actionsOpen, seriesId, templateKey, createdAt, updatedAt,
             agendaJson, minutesJson, decisions, version, actions, previous, next, series, hasClients, canEdit, canDelete, canCreateIssues
    }

    init(id: Int, number: Int, title: String) { self.id = id; self.number = number; self.title = title }

    /// Khoan dung: nội dung giàu (agenda/minutes TipTap) hay mảng phụ hỏng ⇒ bỏ phần đó, không hỏng cả cuộc họp.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        number = try c.decode(Int.self, forKey: .number)
        title = (try? c.decode(String.self, forKey: .title)) ?? "Meeting"
        key = try? c.decodeIfPresent(String.self, forKey: .key)
        type = try? c.decodeIfPresent(String.self, forKey: .type)
        typeLabel = try? c.decodeIfPresent(String.self, forKey: .typeLabel)
        status = try? c.decodeIfPresent(String.self, forKey: .status)
        startsAt = try? c.decodeIfPresent(String.self, forKey: .startsAt)
        endsAt = try? c.decodeIfPresent(String.self, forKey: .endsAt)
        timezone = try? c.decodeIfPresent(String.self, forKey: .timezone)
        location = try? c.decodeIfPresent(String.self, forKey: .location)
        meetingUrl = try? c.decodeIfPresent(String.self, forKey: .meetingUrl)
        provider = try? c.decodeIfPresent(String.self, forKey: .provider)
        minutesShared = try? c.decodeIfPresent(Bool.self, forKey: .minutesShared)
        organizer = try? c.decodeIfPresent(CTWUser.self, forKey: .organizer)
        attendees = try? c.decodeIfPresent([CTWNguoiHop].self, forKey: .attendees)
        actionCount = try? c.decodeIfPresent(Int.self, forKey: .actionCount)
        actionsOpen = try? c.decodeIfPresent(Int.self, forKey: .actionsOpen)
        seriesId = try? c.decodeIfPresent(Int.self, forKey: .seriesId)
        templateKey = try? c.decodeIfPresent(String.self, forKey: .templateKey)
        createdAt = try? c.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try? c.decodeIfPresent(String.self, forKey: .updatedAt)
        agendaJson = try? c.decodeIfPresent(CTWNode.self, forKey: .agendaJson)
        minutesJson = try? c.decodeIfPresent(CTWNode.self, forKey: .minutesJson)
        decisions = try? c.decodeIfPresent([String].self, forKey: .decisions)
        version = try? c.decodeIfPresent(Int.self, forKey: .version)
        actions = try? c.decodeIfPresent([CTWHopViec].self, forKey: .actions)
        previous = try? c.decodeIfPresent(CTWHopLienKet.self, forKey: .previous)
        next = try? c.decodeIfPresent([CTWHopLienKet].self, forKey: .next)
        series = try? c.decodeIfPresent(CTWHopChuoi.self, forKey: .series)
        hasClients = try? c.decodeIfPresent(Bool.self, forKey: .hasClients)
        canEdit = try? c.decodeIfPresent(Bool.self, forKey: .canEdit)
        canDelete = try? c.decodeIfPresent(Bool.self, forKey: .canDelete)
        canCreateIssues = try? c.decodeIfPresent(Bool.self, forKey: .canCreateIssues)
    }

    var batDau: Date? { CTWChatThoiGian.date(startsAt) }
    var ketThuc: Date? { CTWChatThoiGian.date(endsAt) }
    var daHuy: Bool { status == "CANCELLED" }
    var daXong: Bool { status == "DONE" }
    /// Đang diễn ra hoặc sắp bắt đầu trong 10 phút ⇒ nút "Join" nổi bật.
    var sapHoacDangHop: Bool {
        guard !daHuy, let b = batDau, let k = ketThuc else { return false }
        let bay = Date()
        return bay >= b.addingTimeInterval(-600) && bay <= k
    }
    var urlHop: URL? {
        guard let s = meetingUrl?.trimmingCharacters(in: .whitespaces), let u = URL(string: s),
              u.scheme == "https" || u.scheme == "http" else { return nil }
        return u
    }
    var tenNhaCungCap: String {
        switch provider {
        case "MEET": return "Google Meet"
        case "ZOOM": return "Zoom"
        case "TEAMS": return "Microsoft Teams"
        case "JITSI": return "Jitsi Meet"
        default: return urlHop?.host ?? "Video call"
        }
    }
}

struct CTWMeetingList: Codable {
    var items: [CTWMeeting]?
    var canEdit: Bool?
    var portalOn: Bool?
    var now: String?
}

// MARK: Phòng họp (RSVP, điểm danh, chương trình có cấu trúc, ghi âm, bản nháp AI)

struct CTWHopMucChuongTrinh: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var presenterId: Int?
    var minutes: Int?
    var ref: String?
}

struct CTWHopNguoiPhong: Codable, Hashable, Identifiable {
    var userId: Int
    var invited: Bool?
    /// YES | NO | MAYBE
    var rsvp: String?
    var rsvpNote: String?
    /// PRESENT | LATE | EXCUSED | ABSENT
    var attendance: String?
    var joinedAt: String?
    var leftAt: String?
    var present: Bool?
    var user: CTWUser?
    var id: Int { userId }
}

struct CTWHopToi: Codable, Hashable {
    var rsvp: String?
    var rsvpNote: String?
    var attendance: String?
    var joinedAt: String?
    var invited: Bool?
    var present: Bool?
}

struct CTWHopDeXuat: Codable, Hashable {
    var text: String?
    var unsupported: Bool?
    var ownerId: Int?
    var ownerName: String?
    var due: String?
}

/// Biên bản do AI đề xuất (`minutes-ai`) — LUÔN gắn nhãn AI khi hiện (4.7).
struct CTWHopNoiDungAI: Codable, Hashable {
    var summary: String?
    var decisions: [CTWHopDeXuat]?
    var actions: [CTWHopDeXuat]?
    var openIssues: [CTWHopDeXuat]?
    var unsupportedCount: Int?
    var truncated: Bool?
}

struct CTWHopBanNhapAI: Codable, Hashable, Identifiable {
    var id: Int
    /// PROPOSED | APPLIED | DISMISSED
    var status: String?
    var language: String?
    var content: CTWHopNoiDungAI?
    var createdAt: String?
}

struct CTWHopQuyen: Codable, Hashable {
    var edit: Bool?
    var chair: Bool?
    var record: Bool?
    var ai: Bool?
}

struct CTWHopGhiAm: Codable, Hashable, Identifiable {
    var id: Int
    var source: String?
    var status: String?
    var durationMs: Int?
    var startedAt: String?
}

struct CTWMeetingRoom: Codable {
    var number: Int?
    var agenda: [CTWHopMucChuongTrinh]?
    var agendaMinutes: Int?
    var recordingUrl: String?
    var attendees: [CTWHopNguoiPhong]?
    var tracked: Bool?
    var me: CTWHopToi?
    var recordings: [CTWHopGhiAm]?
    var drafts: [CTWHopBanNhapAI]?
    var can: CTWHopQuyen?

    private enum CodingKeys: String, CodingKey { case number, agenda, agendaMinutes, recordingUrl, attendees, tracked, me, recordings, drafts, can }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        number = try? c.decodeIfPresent(Int.self, forKey: .number)
        agenda = try? c.decodeIfPresent([CTWHopMucChuongTrinh].self, forKey: .agenda)
        agendaMinutes = try? c.decodeIfPresent(Int.self, forKey: .agendaMinutes)
        recordingUrl = try? c.decodeIfPresent(String.self, forKey: .recordingUrl)
        attendees = try? c.decodeIfPresent([CTWHopNguoiPhong].self, forKey: .attendees)
        tracked = try? c.decodeIfPresent(Bool.self, forKey: .tracked)
        me = try? c.decodeIfPresent(CTWHopToi.self, forKey: .me)
        recordings = try? c.decodeIfPresent([CTWHopGhiAm].self, forKey: .recordings)
        drafts = try? c.decodeIfPresent([CTWHopBanNhapAI].self, forKey: .drafts)
        can = try? c.decodeIfPresent(CTWHopQuyen.self, forKey: .can)
    }
}

// MARK: Bản ghi lời (transcript)

struct CTWHopDongLoi: Codable, Hashable, Identifiable {
    var id: String
    var n: Int?
    var startMs: Int?
    var text: String?
    var speakerId: Int?
    /// "mm:ss"
    var at: String?
}

struct CTWHopBanGhiLoi: Codable, Hashable, Identifiable {
    var id: Int
    var source: String?
    var fileName: String?
    var startedAt: String?
    var lines: [CTWHopDongLoi]?
}

struct CTWHopTranscript: Codable {
    var recordings: [CTWHopBanGhiLoi]?
    var speakers: [CTWUser]?
}

// MARK: Kết quả thao tác

struct CTWHopVaoKQ: Codable { var url: String?; var attendance: String? }
struct CTWHopTaoTheKQ: Codable {
    struct Moi: Codable, Hashable { var actionId: Int?; var number: Int?; var key: String?; var title: String? }
    var created: [Moi]?
    var meeting: CTWMeeting?
}
