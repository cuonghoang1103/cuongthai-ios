#if DEBUG
import Foundation

// MARK: - Dữ liệu mẫu mảng B2 — Timeline · Releases · Stages · Calendar (xem `XemThuCTW+KeHoach.swift`)
//
// Hình dạng đối chiếu: `planning.service.ts` (timeline 178-214, versions 29-169), `uxc.service.ts`
// (markers 190-210), `flowReports.service.ts` (release-burnup 160-202), `stages.service.ts` (43-66),
// `meetings.service.ts` (44-84), `calendar.service.ts` (32-50). Dự án NW (pid 7), thẻ khớp `DuLieuGia`.
//
//     SIMCTL_CHILD_CT_XEM_MAN=mod:timeline        (list) · mod:timeline/gantt
//     SIMCTL_CHILD_CT_XEM_MAN=mod:releases        · mod:releases/2 (chi tiết phiên bản 2)
//     SIMCTL_CHILD_CT_XEM_MAN=mod:stages          · mod:calendar

enum DuLieuGiaB2 {
    static func route(_ m: String, _ p: String, _ b: [String: Any]) -> Any? {
        let pr = "/work/projects/7"
        switch (m, p) {
        case ("GET", pr + "/timeline"): return timeline
        case ("GET", pr + "/timeline/markers"): return markers
        case ("GET", pr + "/versions"): return versions
        case ("POST", pr + "/versions"):
            return version(9, b["name"] as? String ?? "New version", "UNRELEASED", start: nil, release: 30, total: 0, done: 0)
        case ("GET", pr + "/reports/release-burnup"): return burnup(theoSoThe: true)
        case ("GET", pr + "/stages"): return stages
        case ("GET", pr + "/meetings"): return meetings
        case ("GET", "/work/me/calendar-link"): return ["active": false, "createdAt": NSNull(), "lastUsedAt": NSNull(), "prefix": NSNull()]
        case ("POST", "/work/me/calendar-link"): return ["token": "ctc_demo0000_secret", "path": "/work/calendar/ctc_demo0000_secret.ics"]
        default: break
        }
        if p.hasPrefix(pr + "/versions/") {
            let phan = p.split(separator: "/")
            guard phan.count >= 5, let id = Int(phan[4]) else { return nil }
            let v = versions.first { ($0["id"] as? Int) == id } ?? versions[1]
            if phan.count == 6 && phan[5] == "release" { return ["version": v.merging(["status": "RELEASED", "releasedAt": DuLieuGia.iso(0)]) { $1 }, "moved": 2] }
            if m == "PATCH" { return v.merging(b) { $1 } }
            return ["version": v, "issues": issuesCua(id)]
        }
        if m == "PUT", p.hasPrefix(pr + "/issues/"), p.hasSuffix("/schedule") {
            return ["number": Int(p.split(separator: "/")[4]) ?? 0, "version": 4]
        }
        return nil
    }

    /// 10 ký tự đầu của chuỗi ngày (giống `toISOString().slice(0,10)` của máy chủ), không có ⇒ null.
    static func cat10(_ x: Any?) -> Any {
        guard let s = x as? String else { return NSNull() }
        return String(s.prefix(10))
    }
    static func ymd(_ n: Double?) -> Any { n.map { DuLieuGia.ngay($0) } ?? NSNull() }
    /// Cột `@db.Date` ⇒ ISO nửa đêm Z.
    static func dbDate(_ n: Double?) -> Any { n.map { DuLieuGia.ngay($0) + "T00:00:00.000Z" } ?? NSNull() }

    // MARK: Timeline

    static func muc(_ so: Int, _ t: String, type: Int, st: Int, epic: Int? = nil, ai: Int? = nil, sprint: Int? = 21, version: Int? = 2,
                    start: Double?, due: Double?, done: Bool = false, progress: Double = 0) -> [String: Any] {
        ["id": 100 + so, "number": so, "title": t, "typeId": type, "statusId": st, "parentId": epic.map { 100 + $0 } ?? NSNull(),
         "assigneeId": ai ?? NSNull(), "sprintId": sprint ?? NSNull(), "fixVersionId": version ?? NSNull(),
         "level": type == 1 ? 1 : 0, "start": ymd(start), "due": ymd(due), "done": done, "progress": progress]
    }

    static let timeline: [String: Any] = [
        "items": [
            muc(10, "Public beta readiness", type: 1, st: 2, ai: 2, sprint: nil, start: -14, due: 8, progress: 0.4),
            muc(19, "iPad split view layout", type: 2, st: 4, epic: 10, ai: 1, start: -13, due: -6, done: true, progress: 1),
            muc(12, "Push notifications open the right issue", type: 2, st: 2, epic: 10, ai: 1, start: -4, due: 2),
            muc(14, "Crash when attaching a HEIC photo on iOS 17", type: 4, st: 1, epic: 10, ai: 3, start: -3, due: -1),
            muc(15, "Design empty states for Inbox and Chat", type: 3, st: 3, epic: 10, ai: 4, start: 0, due: 4),
            muc(20, "Accessibility audit (Dynamic Type)", type: 3, st: 1, epic: 10, start: nil, due: 6),
            muc(11, "Launch & store listing", type: 1, st: 1, ai: 5, sprint: nil, start: nil, due: nil),
            muc(16, "Write release notes draft", type: 3, st: 2, epic: 11, ai: 9, start: 3, due: 5),
            muc(17, "Offline cache for My Work", type: 2, st: 1, epic: 11, ai: 1, start: 6, due: 13),
            muc(23, "Dark mode screenshots for the App Store", type: 3, st: 1, epic: 11, sprint: nil, version: 3, start: nil, due: nil),
            muc(18, "Rate-limit chat uploads per user", type: 3, st: 4, ai: 2, start: -9, due: -7, done: true, progress: 1),
            muc(24, "Search across workspaces", type: 2, st: 1, sprint: 22, version: 3, start: nil, due: nil),
            muc(25, "Widget: today's due issues", type: 2, st: 1, sprint: nil, version: nil, start: nil, due: nil),
        ],
        "dependencies": [["from": 114, "to": 112], ["from": 112, "to": 116], ["from": 115, "to": 117]],
        "criticalPath": [114, 112, 116, 117],
        "criticalDays": 17,
        "conflicts": [["from": 114, "to": 112]],
    ]

    static var markers: [String: Any] {
        ["sprints": [["id": 20, "name": "Sprint 5", "status": "CLOSED", "start": DuLieuGia.ngay(-20), "end": DuLieuGia.ngay(-7)],
                     ["id": 21, "name": "Sprint 6 — Beta polish", "status": "ACTIVE", "start": DuLieuGia.ngay(-7), "end": DuLieuGia.ngay(7)],
                     ["id": 22, "name": "Sprint 7 — Launch", "status": "PLANNED", "start": DuLieuGia.ngay(7), "end": DuLieuGia.ngay(21)]],
         "versions": versions.filter { ($0["status"] as? String) != "ARCHIVED" }.map { v in
             ["id": v["id"]!, "name": v["name"]!, "status": v["status"]!,
              "start": cat10(v["startDate"]), "release": cat10(v["releaseDate"])] as [String: Any]
         },
         "stages": stages.compactMap { s -> [String: Any]? in
             ["id": s["id"]!, "n": s["n"]!, "name": s["name"]!, "status": s["status"]!,
              "start": cat10(s["startedAt"]), "end": cat10(s["completedAt"])]
         }]
    }

    // MARK: Versions

    static func version(_ id: Int, _ ten: String, _ st: String, start: Double?, release: Double?, total: Int, done: Int,
                        notes: String? = nil, moTa: String? = nil) -> [String: Any] {
        let quaHan = st == "UNRELEASED" && (release ?? 1) < 0
        return ["id": id, "name": ten, "description": moTa ?? NSNull(), "startDate": dbDate(start), "releaseDate": dbDate(release),
                "status": st, "releasedAt": st == "RELEASED" ? DuLieuGia.iso(release ?? 0) : NSNull(), "releaseNotes": notes ?? NSNull(),
                "position": id, "createdAt": DuLieuGia.iso(-40), "total": total, "done": done, "overdue": quaHan]
    }

    static let notes = """
    ## What's new
    - **Push notifications** open exactly the issue or chat they refer to.
    - iPad split view with a sidebar for every project module.

    ## Fixed
    - Rate limits on chat uploads per user.
    - Dynamic Type clipping on the board.
    """

    static let versions: [[String: Any]] = [
        version(1, "1.0 Beta", "RELEASED", start: -30, release: -6, total: 8, done: 8, notes: notes, moTa: "First TestFlight beta for the pilot teams."),
        version(2, "1.0", "UNRELEASED", start: -14, release: 12, total: 14, done: 6, moTa: "Public App Store release."),
        version(3, "1.1", "UNRELEASED", start: 12, release: 40, total: 5, done: 0),
        version(5, "Hotfix 0.9.2", "UNRELEASED", start: -10, release: -2, total: 3, done: 2),
        version(4, "0.9 Alpha", "ARCHIVED", start: -60, release: -35, total: 6, done: 6),
    ]

    static func issuesCua(_ id: Int) -> [[String: Any]] {
        let ds = DuLieuGia.the
        switch id {
        case 2: return ds
        case 3: return DuLieuGia.tonDong
        default: return Array(ds.prefix(3))
        }
    }

    static func burnup(theoSoThe: Bool) -> [String: Any] {
        var diem: [[String: Any]] = []
        for i in -14...0 {
            let d = Double(i)
            let scope = 10.0 + (i >= -8 ? 2 : 0) + (i >= -3 ? 2 : 0)
            let done = max(0, Double(i + 14) * 0.45).rounded(.down)
            let ideal = max(0, 10 - (d + 14) * (10.0 / 26))
            diem.append(["day": DuLieuGia.ngay(d), "scope": scope, "done": done, "remaining": scope - done, "ideal": ideal])
        }
        return ["version": ["id": 2, "name": "1.0", "status": "UNRELEASED", "startDate": dbDate(-14), "releaseDate": dbDate(12),
                            "releasedAt": NSNull(), "createdAt": DuLieuGia.iso(-40)],
                "unit": "POINTS", "byCount": theoSoThe, "points": diem,
                "scope": "Top-level issues (no epics, sub-tasks or test cases).", "forecast": DuLieuGia.ngay(15)]
    }

    // MARK: Stages

    static let stages: [[String: Any]] = [
        stage(1, 1, "Initiation", "DONE", bd: -45, xong: -38, so: 6, xongSo: 6),
        stage(2, 2, "Requirements & design", "DONE", bd: -38, xong: -20, so: 14, xongSo: 14, cong: (31, "Sign-off: SRS v1.2", -21)),
        stage(3, 3, "Build", "GATE_REVIEW", bd: -20, xong: nil, so: 24, xongSo: 19, cong: (20, "Accessibility audit (Dynamic Type)", nil), duyet: 41),
        stage(4, 4, "Acceptance testing", "NOT_STARTED", bd: nil, xong: nil, so: 9, xongSo: 0),
        stage(5, 5, "Launch", "NOT_STARTED", bd: nil, xong: nil, so: 0, xongSo: 0),
    ]

    static func stage(_ id: Int, _ n: Int, _ ten: String, _ st: String, bd: Double?, xong: Double?, so: Int, xongSo: Int,
                      cong: (Int, String, Double?)? = nil, duyet: Int? = nil) -> [String: Any] {
        ["id": id, "n": n, "slug": ten.lowercased().replacingOccurrences(of: " ", with: "-"), "name": ten, "status": st,
         "gateIssueId": cong.map { 100 + $0.0 } ?? NSNull(),
         "startedAt": bd.map { DuLieuGia.iso($0) } ?? NSNull(), "completedAt": xong.map { DuLieuGia.iso($0) } ?? NSNull(),
         "createdAt": DuLieuGia.iso(-50),
         "gateIssue": cong.map { ["id": 100 + $0.0, "number": $0.0, "title": $0.1, "resolvedAt": $0.2.map { DuLieuGia.iso($0) } ?? NSNull()] as [String: Any] } ?? NSNull(),
         "gateIssueKey": cong.map { "NW-\($0.0)" } ?? NSNull(),
         "issueCount": so, "doneCount": xongSo, "pendingApprovalId": duyet ?? NSNull()]
    }

    // MARK: Meetings

    static var meetings: [String: Any] {
        func hop(_ id: Int, _ t: String, _ type: String, _ nhan: String, ngay: Double, gio: Double, phut: Double, url: String?, noi: String?) -> [String: Any] {
            let bd = DuLieuGia.iso(ngay, gio: gio)
            let kt = DuLieuGia.iso(ngay, gio: gio + phut / 60)
            return ["id": id, "number": id, "title": t, "type": type, "status": "SCHEDULED", "startsAt": bd, "endsAt": kt,
                    "timezone": "Asia/Ho_Chi_Minh", "location": noi ?? NSNull(), "meetingUrl": url ?? NSNull(), "minutesShared": false,
                    "createdAt": DuLieuGia.iso(-5), "updatedAt": DuLieuGia.iso(-1), "seriesId": NSNull(), "seriesDetached": false,
                    "templateKey": NSNull(), "organizer": DuLieuGia.linh, "key": "M-\(id)", "typeLabel": nhan,
                    "provider": url == nil ? NSNull() : "MEET",
                    "attendees": [DuLieuGia.toi, DuLieuGia.linh, DuLieuGia.minh, DuLieuGia.an], "actionCount": 2, "actionsOpen": 1]
        }
        return ["items": [hop(31, "Daily stand-up", "DAILY", "Daily", ngay: 1, gio: 2, phut: 15, url: "https://meet.google.com/abc-defg-hij", noi: nil),
                          hop(32, "Client demo — beta walkthrough", "CLIENT", "Client", ngay: 3, gio: 5, phut: 60, url: "https://meet.google.com/xyz-uvwx-rst", noi: "Room 4.2"),
                          hop(33, "Sprint 6 review & retro", "DEMO", "Demo", ngay: 7, gio: 6, phut: 90, url: nil, noi: "Studio A")],
                "canEdit": true, "portalOn": false, "now": DuLieuGia.iso(0)]
    }
}
#endif
