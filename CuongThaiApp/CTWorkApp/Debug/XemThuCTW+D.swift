#if DEBUG
import Foundation

// MARK: - Dữ liệu mẫu cho các tuyến backend 18/10/2026 (app iOS CT Work) — CHỈ bản DEBUG
//
// Hình dạng đối chiếu `api-backend`:
//   · `src/services/work/meAgenda.service.ts` — `GET /work/me/agenda`, `GET /work/me/timesheet`
//   · `src/services/work/contentReport.service.ts` — `POST /work/report` ⇒ `{reported, duplicate}`
//   · `src/routes/work.ios.routes.ts` — `/chat/dm`, `/dashboards/:id`, `/swr/requirements/:num`, `/meetings/:n/report`
// Cũng là đầu vào của kiểm thử giải mã (`CTWorkTests/MangDTests.swift`).
// ⚠️ Cả tệp trong `#if DEBUG` (CLAUDE.md A6).

extension XemThuCTW {
    /// Cho phép `CTWChiaSeNhom` ghi vùng App Group khi chạy máy chủ giả (để widget có dữ liệu khi chụp).
    static var choGhiNhom: Bool { true }
}

enum DuLieuGiaD {
    typealias G = DuLieuGia
    private static let pr = "/work/projects/7"
    private static let duAn: [String: Any] = ["id": 7, "key": "NW", "name": "Mobile App Launch", "workspaceSlug": "northwind"]
    private static let duAnWeb: [String: Any] = ["id": 8, "key": "WEB", "name": "Marketing Website", "workspaceSlug": "northwind"]

    static func route(_ m: String, _ p: String, _ b: [String: Any]) -> Any? {
        switch (m, p) {
        case ("GET", "/work/me/agenda"): return agenda
        case ("GET", "/work/me/timesheet"): return bangGio
        case ("POST", "/work/report"): return ["reported": true, "duplicate": false]
        case ("POST", pr + "/chat/dm"):
            return ["id": 7, "kind": "DM", "channelKind": "PRIVATE", "name": "dm-1-\(b["userId"] ?? 2)",
                    "with": ["id": b["userId"] ?? 2, "username": "linh"], "created": false]
        default: break
        }
        if m == "GET", p.hasPrefix(pr + "/dashboards/"), let id = Int(p.split(separator: "/").last ?? "") {
            var d = DuLieuGiaB1.dashboard
            d["id"] = id
            d["canEdit"] = true
            return d
        }
        if m == "GET", p.hasPrefix(pr + "/swr/requirements/"), p.split(separator: "/").count == 6,
           let so = Int(p.split(separator: "/").last ?? "") {
            return DuLieuGiaRequirements.dsYeuCau.first { ($0["number"] as? Int) == so } ?? DuLieuGiaRequirements.dsYeuCau[0]
        }
        if m == "POST", p.hasPrefix(pr + "/chat/channels/"), p.hasSuffix("/report") { return ["reported": true, "duplicate": false] }
        return nil
    }

    // MARK: /me/agenda

    static var agenda: [String: Any] {
        let hn = G.ngay(0)
        func due(_ id: Int, _ so: Int, _ t: String, ngay: Double, pri: String = "HIGH", st: String = "In Progress", cat: String = "IN_PROGRESS",
                 p: [String: Any] = duAn) -> [String: Any] {
            let k = p["key"] as? String ?? "NW"
            return ["type": "due", "date": G.ngay(ngay), "id": id, "key": "\(k)-\(so)", "number": so, "title": t, "priority": pri,
                    "status": ["name": st, "category": cat], "project": p, "url": "/work/northwind/\(k)/issue/\(so)"]
        }
        let items: [[String: Any]] = [
            ["type": "meeting", "date": hn, "id": 41, "number": 4, "title": "Daily stand-up", "meetingType": "STANDUP", "status": "SCHEDULED",
             "startsAt": G.iso(0, gio: 1), "endsAt": G.iso(0, gio: 1.25), "timezone": "Asia/Ho_Chi_Minh", "location": NSNull(),
             "meetingUrl": "https://meet.google.com/abc-defg-hij", "rsvp": "YES", "project": duAn, "client": false,
             "url": "/work/northwind/NW/meetings/4"],
            due(1012, 12, "Push notifications open the right issue", ngay: 0),
            due(1018, 18, "Offline queue for chat messages", ngay: 0, pri: "MEDIUM", st: "To Do", cat: "TODO"),
            due(2003, 3, "Hero section copy review", ngay: 0, pri: "LOW", st: "In Review", cat: "IN_PROGRESS", p: duAnWeb),
            ["type": "sprint", "date": G.ngay(-9), "end": hn, "id": 22, "title": "Sprint 7", "goal": "TestFlight build for the team",
             "status": "ACTIVE", "project": duAn, "url": "/work/northwind/NW/board"],
            ["type": "meeting", "date": G.ngay(1), "id": 33, "number": 3, "title": "Sprint 6 review & demo", "meetingType": "REVIEW",
             "status": "SCHEDULED", "startsAt": G.iso(1, gio: 3), "endsAt": G.iso(1, gio: 4), "timezone": "Asia/Ho_Chi_Minh",
             "location": "Room 2 · Floor 5", "meetingUrl": "https://zoom.us/j/123456789", "rsvp": NSNull(), "project": duAn,
             "client": false, "url": "/work/northwind/NW/meetings/3"],
            due(1021, 21, "Crash on iPad split view", ngay: 2, pri: "HIGHEST", st: "To Do", cat: "TODO"),
            ["type": "release", "date": G.ngay(5), "id": 3, "title": "v1.0", "status": "UNRELEASED", "project": duAn, "url": "/work/northwind/NW/releases"],
            ["type": "stage", "date": G.ngay(6), "event": "started", "id": 4, "n": 4, "title": "Testing", "status": "ACTIVE", "project": duAn,
             "url": "/work/northwind/NW/stages"],
            ["type": "sprint", "date": hn, "end": G.ngay(13), "id": 23, "title": "Sprint 8", "goal": NSNull(), "status": "PLANNED",
             "project": duAn, "url": "/work/northwind/NW/board"],
        ]
        return ["from": hn, "to": G.ngay(30), "timezone": "Asia/Ho_Chi_Minh", "items": items,
                "counts": ["due": 4, "sprint": 2, "release": 1, "stage": 1, "meeting": 2]]
    }

    // MARK: /me/timesheet

    static var bangGio: [String: Any] {
        let cal = NgayCTW.lichVN
        let thuHai = NgayCTW.dauTuan(Date())
        let ngay = (0..<7).map { NgayCTW.ymd(cal.date(byAdding: .day, value: $0, to: thuHai) ?? thuHai) }
        let phutNW = [150, 210, 95, 0, 0, 0, 0]
        let phutWEB = [30, 0, 60, 0, 0, 0, 0]
        let homNay = ngay.firstIndex(of: G.ngay(0)) ?? 2
        func theoNgay(_ a: [Int]) -> [String: Int] {
            var d: [String: Int] = [:]
            for (i, v) in a.enumerated() where i <= homNay && v > 0 { d[ngay[i]] = v }
            return d
        }
        let nw = theoNgay(phutNW), web = theoNgay(phutWEB)
        let tongNW = nw.values.reduce(0, +), tongWEB = web.values.reduce(0, +)
        var ca: [String: Int] = Dictionary(uniqueKeysWithValues: ngay.map { ($0, 0) })
        for (k, v) in nw { ca[k, default: 0] += v }
        for (k, v) in web { ca[k, default: 0] += v }
        return [
            "weekStart": ngay[0], "weekEnd": ngay[6], "days": ngay, "timezone": "Asia/Ho_Chi_Minh",
            "totalMin": tongNW + tongWEB, "byDay": ca,
            "projects": [
                ["project": duAn, "totalMin": tongNW, "byDay": nw, "timesheetStatus": "SUBMITTED", "issues": [
                    ["key": "NW-12", "number": 12, "title": "Push notifications open the right issue", "totalMin": Int(Double(tongNW) * 0.6),
                     "byDay": [String: Int](), "url": "/work/northwind/NW/issue/12"],
                    ["key": "NW-18", "number": 18, "title": "Offline queue for chat messages", "totalMin": tongNW - Int(Double(tongNW) * 0.6),
                     "byDay": [String: Int](), "url": "/work/northwind/NW/issue/18"],
                ]],
                ["project": duAnWeb, "totalMin": tongWEB, "byDay": web, "timesheetStatus": NSNull(), "issues": [
                    ["key": "WEB-3", "number": 3, "title": "Hero section copy review", "totalMin": tongWEB, "byDay": web,
                     "url": "/work/northwind/WEB/issue/3"],
                ]],
            ],
            "logs": [
                ["id": 501, "minutes": 95, "startedAt": G.iso(0, gio: -3), "day": G.ngay(0), "note": "Cold-start routing", "source": "MANUAL",
                 "activity": "Coding", "issueKey": "NW-12", "issueNumber": 12, "issueTitle": "Push notifications open the right issue", "project": duAn],
            ],
        ]
    }
}
#endif
