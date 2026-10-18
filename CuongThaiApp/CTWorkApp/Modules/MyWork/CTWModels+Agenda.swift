import Foundation

// MARK: - Lịch của tôi + giờ của tôi — XUYÊN DỰ ÁN (18/10/2026)
//
// Đối chiếu `api-backend/src/services/work/meAgenda.service.ts`:
//   · `GET /work/me/agenda?from=YYYY-MM-DD&to=YYYY-MM-DD` (mặc định hôm nay → +30 ngày, TỐI ĐA 120 ngày —
//     vượt ⇒ 400). `date` là ngày theo giờ VN. Cùng phạm vi với lịch .ics.
//   · `GET /work/me/timesheet?week=YYYY-MM-DD` (ngày bất kỳ ⇒ tuần bắt đầu thứ Hai).
// Agent gọi ⇒ 403 (tuyến ngoài /projects/:pid). Mọi trường `var` + optional, ngày là chuỗi (C3/C4).

struct CTWDuAnGon: Codable, Hashable {
    var id: Int
    var key: String?
    var name: String?
    var workspaceSlug: String?
}

struct CTWAgendaItem: Codable, Hashable, Identifiable {
    struct TrangThai: Codable, Hashable { var name: String?; var category: String? }
    /// due | sprint | release | stage | meeting
    var type: String
    var date: String
    var id: Int
    var title: String?
    var project: CTWDuAnGon?
    var url: String?
    // due
    var key: String?
    var number: Int?
    var priority: String?
    /// due: `{name, category}`; sprint/release/stage/meeting: chuỗi (ACTIVE, RELEASED…). Giải mã mềm.
    var status: TrangThai?
    var statusText: String?
    // sprint
    var end: String?
    var goal: String?
    // stage
    var event: String?
    var n: Int?
    // meeting
    var meetingType: String?
    var startsAt: String?
    var endsAt: String?
    var timezone: String?
    var location: String?
    var meetingUrl: String?
    var rsvp: String?
    var client: Bool?

    /// Khoá ổn định (id trùng giữa các loại).
    var khoa: String { "\(type)-\(id)-\(date)" }

    private enum CodingKeys: String, CodingKey {
        case type, date, id, title, project, url, key, number, priority, status, end, goal, event, n
        case meetingType, startsAt, endsAt, timezone, location, meetingUrl, rsvp, client
    }

    init(type: String, date: String, id: Int, title: String?) {
        self.type = type; self.date = date; self.id = id; self.title = title
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        type = try c.decode(String.self, forKey: .type)
        date = try c.decode(String.self, forKey: .date)
        id = try c.decode(Int.self, forKey: .id)
        title = try? c.decodeIfPresent(String.self, forKey: .title)
        project = try? c.decodeIfPresent(CTWDuAnGon.self, forKey: .project)
        url = try? c.decodeIfPresent(String.self, forKey: .url)
        key = try? c.decodeIfPresent(String.self, forKey: .key)
        number = try? c.decodeIfPresent(Int.self, forKey: .number)
        priority = try? c.decodeIfPresent(String.self, forKey: .priority)
        if let s = try? c.decodeIfPresent(TrangThai.self, forKey: .status) { status = s }
        else { statusText = try? c.decodeIfPresent(String.self, forKey: .status) }
        end = try? c.decodeIfPresent(String.self, forKey: .end)
        goal = try? c.decodeIfPresent(String.self, forKey: .goal)
        event = try? c.decodeIfPresent(String.self, forKey: .event)
        n = try? c.decodeIfPresent(Int.self, forKey: .n)
        meetingType = try? c.decodeIfPresent(String.self, forKey: .meetingType)
        startsAt = try? c.decodeIfPresent(String.self, forKey: .startsAt)
        endsAt = try? c.decodeIfPresent(String.self, forKey: .endsAt)
        timezone = try? c.decodeIfPresent(String.self, forKey: .timezone)
        location = try? c.decodeIfPresent(String.self, forKey: .location)
        meetingUrl = try? c.decodeIfPresent(String.self, forKey: .meetingUrl)
        rsvp = try? c.decodeIfPresent(String.self, forKey: .rsvp)
        client = try? c.decodeIfPresent(Bool.self, forKey: .client)
    }

    func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type); try c.encode(date, forKey: .date); try c.encode(id, forKey: .id)
        try c.encodeIfPresent(title, forKey: .title); try c.encodeIfPresent(project, forKey: .project)
        try c.encodeIfPresent(url, forKey: .url); try c.encodeIfPresent(key, forKey: .key)
        try c.encodeIfPresent(number, forKey: .number); try c.encodeIfPresent(priority, forKey: .priority)
        if let status { try c.encode(status, forKey: .status) } else { try c.encodeIfPresent(statusText, forKey: .status) }
        try c.encodeIfPresent(end, forKey: .end); try c.encodeIfPresent(goal, forKey: .goal)
        try c.encodeIfPresent(event, forKey: .event); try c.encodeIfPresent(n, forKey: .n)
        try c.encodeIfPresent(meetingType, forKey: .meetingType); try c.encodeIfPresent(startsAt, forKey: .startsAt)
        try c.encodeIfPresent(endsAt, forKey: .endsAt); try c.encodeIfPresent(timezone, forKey: .timezone)
        try c.encodeIfPresent(location, forKey: .location); try c.encodeIfPresent(meetingUrl, forKey: .meetingUrl)
        try c.encodeIfPresent(rsvp, forKey: .rsvp); try c.encodeIfPresent(client, forKey: .client)
    }
}

struct CTWAgenda: Codable {
    struct Dem: Codable, Hashable { var due: Int?; var sprint: Int?; var release: Int?; var stage: Int?; var meeting: Int? }
    var from: String?
    var to: String?
    var timezone: String?
    var items: [CTWAgendaItem]?
    var counts: Dem?
}

struct CTWBangGioCuaToi: Codable {
    struct The: Codable, Hashable {
        var key: String?
        var number: Int?
        var title: String?
        var totalMin: Int?
        var byDay: [String: Int]?
        var url: String?
    }
    struct DuAn: Codable, Hashable {
        var project: CTWDuAnGon?
        var totalMin: Int?
        var byDay: [String: Int]?
        /// SUBMITTED | APPROVED | RETURNED | REOPENED | nil (chưa nộp / không dùng Finance)
        var timesheetStatus: String?
        var issues: [The]?
    }
    struct Ghi: Codable, Hashable, Identifiable {
        var id: Int
        var minutes: Int?
        var startedAt: String?
        var day: String?
        var note: String?
        var source: String?
        var activity: String?
        var issueKey: String?
        var issueNumber: Int?
        var issueTitle: String?
        var project: CTWDuAnGon?
    }
    var weekStart: String?
    var weekEnd: String?
    var days: [String]?
    var timezone: String?
    var totalMin: Int?
    var byDay: [String: Int]?
    var projects: [DuAn]?
    var logs: [Ghi]?
}

extension CTWAPI {
    /// Lịch của tôi xuyên dự án. Khoảng > 120 ngày ⇒ 400 (bên gọi tự cắt — `CTWAgendaKhoang`).
    static func lichCuaToi(tu: String? = nil, den: String? = nil) -> APIEndpoint {
        var q: [String: Any] = [:]
        if let tu { q["from"] = tu }
        if let den { q["to"] = den }
        return get("/me/agenda", q.isEmpty ? nil : q)
    }
    /// Giờ của tôi trong tuần chứa `tuan`, mọi dự án.
    static func gioCuaToi(tuan: String? = nil) -> APIEndpoint { get("/me/timesheet", tuan.map { ["week": $0] }) }
}

enum CTWAgendaKhoang {
    static let toiDa = 120

    /// Cắt khoảng [tu, den] cho vừa trần của máy chủ (giữ `tu`).
    static func cat(tu: String, den: String) -> (String, String) {
        guard let a = NgayCTW.ngay(tu), let b = NgayCTW.ngay(den) else { return (tu, den) }
        let soNgay = Calendar(identifier: .gregorian).dateComponents([.day], from: a, to: b).day ?? 0
        if soNgay <= toiDa { return (tu, den) }
        return (tu, NgayCTW.ymd(NgayCTW.cong(a, ngay: toiDa)))
    }

    /// Việc của HÔM NAY (theo `homNay` YMD): hạn hôm nay + họp hôm nay + sprint kết thúc hôm nay.
    static func homNay(_ ds: [CTWAgendaItem], homNay: String) -> [CTWAgendaItem] {
        ds.filter { $0.date == homNay || ($0.type == "sprint" && $0.end == homNay) }
    }
}
