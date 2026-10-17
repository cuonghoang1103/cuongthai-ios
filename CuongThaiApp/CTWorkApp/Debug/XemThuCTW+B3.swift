#if DEBUG
import Foundation

// MARK: - Dữ liệu mẫu mảng B3 — Time · Poker · Retro · OKR · Workspace (xem `XemThuCTW+KeHoach.swift`)
//
// Hình dạng đối chiếu service: `timer.service.ts`, `planning.service.ts` (worklog, reports/time),
// `poker.service.ts`, `retro.service.ts`, `okr.service.ts`, `portfolio.service.ts`, `teams.service.ts`,
// `agentReports.service.ts`. Dự án NW (pid 7), không gian 1. Tôi = Alex (id 1). Agent = Scout (id 9).
// Đồng hồ đang chạy trên NW-12 (1h 23m).

enum DuLieuGiaB3 {
    typealias G = DuLieuGia
    private static let pr = "/work/projects/7"

    static func route(_ m: String, _ p: String, _ b: [String: Any]) -> Any? {
        // ── Đồng hồ
        if p == "/work/me/timer" {
            if m == "GET" || m == "PATCH" { return ["timer": dongHo(chay: true)] }
        }
        if p == "/work/me/timer/pause" { return ["timer": dongHo(chay: false)] }
        if p == "/work/me/timer/resume" { return ["timer": dongHo(chay: true), "switched": NSNull()] }
        if p == "/work/me/timer/stop" {
            return ["stopped": true, "issueKey": "NW-12", "elapsedSec": 4980, "minutes": 83, "capped": false, "worklog": ["id": 77, "minutes": 83]]
        }
        if p == "/work/me/timer/discard" { return ["discarded": true] }
        if p.hasPrefix(pr + "/issues/"), p.hasSuffix("/timer") {
            if m == "POST" { return ["timer": dongHo(chay: true), "switched": NSNull()] }
            return ["timer": dongHo(chay: true), "onThisIssue": p.contains("/issues/12/")]
        }
        // ── Worklog
        if p.hasPrefix(pr + "/issues/"), p.hasSuffix("/worklogs") {
            if m == "POST" {
                return wl(90, b["minutes"] as? Int ?? 30, G.toi, ngay: 0, note: b["note"] as? String, act: b["activity"] as? String)
            }
            return worklog
        }
        if p.hasPrefix(pr + "/issues/"), p.contains("/worklogs/"), m == "DELETE" { return ["deleted": true] }
        if p.hasPrefix(pr + "/issues/"), p.hasSuffix("/worklog-defaults") {
            return ["activity": "Coding", "workProduct": "Software Package",
                    "activities": ["Training", "Analyzing", "Designing", "Coding", "Testing", "Deploying"],
                    "products": ["Software Package", "Report1 (Intro)", "Report2 (Plan)"]]
        }
        if p == pr + "/reports/time" { return baoCaoGio }
        if p == pr + "/finance/timesheet" { return phieuGio }
        // ── Poker
        if p == pr + "/poker" && m == "GET" { return dsPoker }
        if p == pr + "/poker" && m == "POST" { return ["id": 3, "items": 4] }
        if p.hasPrefix(pr + "/poker/") {
            let phan = p.split(separator: "/")
            if m == "GET", phan.count == 5, let sid = Int(phan[4]) { return phongPoker(sid) }
            return ["ok": true, "storyPoints": 5, "round": 2, "timerEndsAt": NSNull(), "added": 1]
        }
        // ── Retro
        if p == pr + "/retros" && m == "GET" { return dsRetro }
        if p == pr + "/retros" && m == "POST" { return ["id": 2] }
        if p.hasPrefix(pr + "/retros/") {
            let phan = p.split(separator: "/")
            if m == "GET", phan.count == 5 { return retro }
            if p.hasSuffix("/vote") { return ["votesLeft": 2, "mine": 1] }
            return ["ok": true, "id": 99]
        }
        // ── OKR
        if p == pr + "/okrs" { return okr(phamVi: "project") }
        if p == "/work/workspaces/1/okrs" { return okr(phamVi: "workspace") }
        if p.hasPrefix("/work/okrs/key-results/"), p.hasSuffix("/checkins") {
            return ["ok": true, "value": b["value"] ?? 0, "progress": 0.6, "weekStart": NgayCTW.ymd(NgayCTW.dauTuan(Date()))]
        }
        // ── Không gian
        if p == "/work/workspaces/1/portfolio" { return portfolio }
        if p == "/work/workspaces/1/workload" { return workload }
        if p == "/work/workspaces/1/teams" { return [doi(1, "MOB", "Mobile", "#7c3aed", [G.toi, G.minh, G.scout], lead: 1, mo: 14),
                                                    doi(2, "WEB", "Web", "#0891b2", [G.linh, G.an], lead: 2, mo: 9),
                                                    doi(3, "QA", "Quality", "#16a34a", [G.sara, G.an], lead: 5, mo: 4)] }
        if p.hasPrefix("/work/workspaces/1/teams/"), p.hasSuffix("/queue") { return hangDoi }
        if p == "/work/workspaces/1/agents/dashboard" { return agentDashboard }
        return nil
    }

    // MARK: Đồng hồ + giờ

    static func dongHo(chay: Bool) -> [String: Any] {
        ["id": 5, "projectId": 7, "issueNumber": 12, "issueKey": "NW-12", "issueTitle": "Push notifications open the right issue",
         "projectKey": "NW", "projectName": "Mobile App Launch", "workspaceSlug": "northwind", "url": "/work/northwind/NW/issue/12",
         "startedAt": G.iso(0, gio: -1.4), "running": chay, "runningSince": chay ? G.iso(0, gio: -0.9) as Any : NSNull(),
         "elapsedSec": 4980, "activity": "Coding", "note": "Cold-start routing", "remindAfterMin": 240, "overdue": false,
         "serverNow": G.iso(0)]
    }

    static func wl(_ id: Int, _ phut: Int, _ u: [String: Any], ngay: Double, note: String?, act: String?, auto: Bool = false) -> [String: Any] {
        ["id": id, "minutes": phut, "startedAt": G.iso(ngay, gio: -3), "note": note ?? NSNull(), "source": auto ? "AGENT_AUTO" : "MANUAL",
         "createdAt": G.iso(ngay), "userId": u["id"] ?? 0, "user": u, "activity": act ?? NSNull(), "workProduct": NSNull()]
    }

    static var worklog: [[String: Any]] {
        [wl(81, 95, G.toi, ngay: 0, note: "Routing for chat deep links", act: "Coding"),
         wl(80, 40, G.scout, ngay: -1, note: "Traced APNs payload", act: "Analyzing", auto: true),
         wl(79, 120, G.toi, ngay: -2, note: nil, act: "Coding"),
         wl(78, 30, G.minh, ngay: -3, note: "Review", act: "Testing")]
    }

    /// Bảng giờ tuần này của Alex: phân bổ theo các ngày ĐÃ QUA của tuần (VN).
    static var baoCaoGio: [String: Any] {
        let thuHai = NgayCTW.dauTuan(Date())
        let homNay = NgayCTW.soNgay(thuHai, Date())
        let mau = [210, 345, 180, 420, 300, 60, 0]
        var theoNgay: [String: Int] = [:]
        for i in 0...max(min(homNay, 6), 0) { theoNgay[NgayCTW.ymd(NgayCTW.cong(thuHai, ngay: i))] = mau[i] }
        let tong = theoNgay.values.reduce(0, +)
        return ["from": NgayCTW.ymd(thuHai), "to": NgayCTW.ymd(NgayCTW.cong(thuHai, ngay: 6)), "principal": "ALL",
                "totalMin": tong, "byPrincipal": ["HUMAN": tong, "AGENT": 0],
                "people": [["user": G.toi, "userKind": "HUMAN", "name": "Alex Morgan", "totalMin": tong, "autoMin": 0, "byDay": theoNgay,
                            "issues": [["number": 12, "title": "Push notifications open the right issue", "minutes": tong * 45 / 100],
                                       ["number": 19, "title": "iPad split view layout", "minutes": tong * 30 / 100],
                                       ["number": 17, "title": "Offline cache for My Work", "minutes": tong * 15 / 100],
                                       ["number": 26, "title": "Review sprint 6 demo script", "minutes": tong - tong * 90 / 100]]]]]
    }

    static var phieuGio: [String: Any] {
        ["weekStart": NgayCTW.ymd(NgayCTW.dauTuan(Date())), "totalMin": 0, "timesheet": NSNull(), "locked": false]
    }

    // MARK: Poker

    static var dsPoker: [String: Any] {
        ["canCreate": true, "sessions": [
            ["id": 3, "title": "Sprint 7 refinement", "deck": "FIBONACCI", "status": "OPEN", "sprint": ["id": 22, "name": "Sprint 7 — Launch"],
             "createdBy": G.linh, "createdAt": G.iso(-1), "closedAt": NSNull(), "items": 4, "estimated": 1, "points": 5],
            ["id": 4, "title": "Bug triage sizing", "deck": "TSHIRT", "status": "OPEN", "sprint": NSNull(),
             "createdBy": G.toi, "createdAt": G.iso(0, gio: -2), "closedAt": NSNull(), "items": 3, "estimated": 0, "points": 0],
            ["id": 1, "title": "Sprint 6 planning", "deck": "FIBONACCI", "status": "CLOSED", "sprint": ["id": 21, "name": "Sprint 6 — Beta polish"],
             "createdBy": G.linh, "createdAt": G.iso(-9), "closedAt": G.iso(-8), "items": 8, "estimated": 8, "points": 29]]]
    }

    static func mucPoker(_ id: Int, _ pos: Int, _ so: Int, _ ten: String, trangThai: String, phieu: [Any]?, bau: [Int], cuaToi: String?,
                         chot: String? = nil, phanBo: Any? = nil, loai: String = "STORY") -> [String: Any] {
        ["id": id, "position": pos, "state": trangThai, "round": 1,
         "issue": ["number": so, "title": ten, "storyPoints": NSNull(),
                   "type": ["key": loai, "name": loai.capitalized, "color": loai == "BUG" ? "#dc2626" : "#16a34a"],
                   "status": ["name": "To Do", "category": "TODO"],
                   "description": so == 24 ? "Search issues by key or title across every workspace the user belongs to, with recent searches." as Any : NSNull()],
         "finalValue": chot ?? NSNull(), "finalPoints": chot.flatMap { Double($0) } ?? NSNull(), "previousPoints": NSNull(),
         "estimatedBy": chot != nil ? G.linh as Any : NSNull(), "estimatedAt": chot != nil ? G.iso(-1) as Any : NSNull(),
         "revealedAt": phieu != nil ? G.iso(0, gio: -0.1) as Any : NSNull(),
         "voted": bau, "myVote": cuaToi ?? NSNull(), "votes": phieu ?? NSNull(), "distribution": phanBo ?? NSNull(), "rounds": [Any]()]
    }

    static func phongPoker(_ sid: Int) -> [String: Any] {
        let laBai = sid == 4 ? ["XS", "S", "M", "L", "XL", "XXL", "?", "☕"] : ["0", "1", "2", "3", "5", "8", "13", "21", "?", "☕"]
        let diem: [String: Double] = ["XS": 1, "S": 2, "M": 3, "L": 5, "XL": 8, "XXL": 13]
        let cards: [[String: Any]] = laBai.map { v in ["value": v, "points": (sid == 4 ? diem[v] : Double(v)) ?? NSNull()] }
        let voters = [G.toi, G.linh, G.minh, G.an]
        var items: [[String: Any]]
        var hienTai: Int
        if sid == 4 {
            items = [mucPoker(41, 0, 14, "Crash when attaching a HEIC photo on iOS 17", trangThai: "VOTING", phieu: nil, bau: [2, 3], cuaToi: nil, loai: "BUG"),
                     mucPoker(42, 1, 25, "Widget: today's due issues", trangThai: "PENDING", phieu: nil, bau: [], cuaToi: nil)]
            hienTai = 41
        } else {
            let phanBo: [String: Any] = ["counts": [["value": "3", "count": 1], ["value": "5", "count": 2], ["value": "8", "count": 1]],
                                         "voters": 4, "numeric": 4, "average": 5.25, "median": 5, "consensus": false,
                                         "mode": "5", "low": "3", "high": "8", "suggested": "5"]
            items = [mucPoker(31, 0, 24, "Search across workspaces", trangThai: "REVEALED",
                              phieu: [["user": G.toi, "value": "5"], ["user": G.linh, "value": "5"], ["user": G.minh, "value": "8"], ["user": G.an, "value": "3"]],
                              bau: [1, 2, 3, 4], cuaToi: "5", phanBo: phanBo),
                     mucPoker(32, 1, 17, "Offline cache for My Work", trangThai: "ESTIMATED", phieu: nil, bau: [], cuaToi: nil, chot: "8"),
                     mucPoker(33, 2, 25, "Widget: today's due issues", trangThai: "PENDING", phieu: nil, bau: [], cuaToi: nil),
                     mucPoker(34, 3, 20, "Accessibility audit (Dynamic Type)", trangThai: "PENDING", phieu: nil, bau: [], cuaToi: nil)]
            hienTai = 31
        }
        return ["id": sid, "projectId": 7, "title": sid == 4 ? "Bug triage sizing" : "Sprint 7 refinement",
                "deck": sid == 4 ? "TSHIRT" : "FIBONACCI", "cards": cards, "status": "OPEN",
                "sprint": sid == 4 ? NSNull() as Any : ["id": 22, "name": "Sprint 7 — Launch"] as Any,
                "currentItemId": hienTai, "timerEndsAt": sid == 4 ? G.iso(0, gio: 0.02) as Any : NSNull(), "serverNow": G.iso(0),
                "createdAt": G.iso(-1), "closedAt": NSNull(), "facilitator": G.toi,
                "me": ["canVote": true, "canFacilitate": true], "voters": voters, "items": items]
    }

    // MARK: Retro

    static var dsRetro: [String: Any] {
        ["canCreate": true, "retros": [
            ["id": 2, "title": "Sprint 6 retro", "template": "SSC", "anonymous": false, "sprint": ["id": 21, "name": "Sprint 6 — Beta polish"],
             "locked": false, "lockAt": NSNull(), "cards": 9, "actions": 2, "hasSummary": false, "createdBy": G.linh, "createdAt": G.iso(-1)],
            ["id": 1, "title": "Sprint 5 retro", "template": "MSG", "anonymous": true, "sprint": ["id": 20, "name": "Sprint 5"],
             "locked": true, "lockAt": G.iso(-12), "cards": 14, "actions": 4, "hasSummary": true, "createdBy": G.linh, "createdAt": G.iso(-14)]]]
    }

    static func the(_ id: Int, _ cot: String, _ chu: String, _ u: [String: Any]?, phieu: Int, cuaToi: Int = 0, nhom: Int? = nil) -> [String: Any] {
        ["id": id, "column": cot, "body": chu, "groupId": nhom ?? NSNull(), "position": id, "votes": phieu, "myVotes": cuaToi,
         "mine": (u?["id"] as? Int) == 1, "author": u ?? NSNull(), "createdAt": G.iso(-0.5)]
    }

    static var retro: [String: Any] {
        ["id": 2, "projectId": 7, "title": "Sprint 6 retro", "template": "SSC", "columns": ["START", "STOP", "CONTINUE"],
         "sprint": ["id": 21, "name": "Sprint 6 — Beta polish", "state": "ACTIVE"], "anonymous": false, "votesPerPerson": 5,
         "lockAt": NSNull(), "locked": false, "lockedManually": false, "summary": NSNull(), "summaryAt": NSNull(), "createdAt": G.iso(-1),
         "facilitator": G.linh, "me": ["canWrite": true, "canFacilitate": false, "canUseAi": false, "votesLeft": 3, "votesUsed": 2],
         "cards": [
            the(1, "START", "Pair on push-notification routing — it touches three modules.", G.minh, phieu: 4, cuaToi: 1),
            the(2, "START", "Write the TestFlight notes before the build, not after.", G.toi, phieu: 2),
            the(3, "START", "Ask Scout to draft release notes from merged issues.", G.an, phieu: 1),
            the(4, "STOP", "Merging on Friday evening without a smoke test.", G.linh, phieu: 5, cuaToi: 1),
            the(5, "STOP", "Late review requests in the last two days of the sprint.", G.sara, phieu: 2),
            the(6, "STOP", "Reviews requested at 11pm.", G.minh, phieu: 0, nhom: 5),
            the(7, "CONTINUE", "Daily 10-minute standup on #general.", G.an, phieu: 3),
            the(8, "CONTINUE", "Crash triage summary every morning — it saved us on NW-14.", G.scout, phieu: 3),
            the(9, "CONTINUE", "Dark-mode screenshots in every PR.", G.toi, phieu: 1)],
         "actions": [
            ["id": 1, "cardId": 4, "title": "Add a release smoke-test checklist", "assignee": G.linh,
             "issue": ["id": 140, "number": 40, "title": "Add a release smoke-test checklist", "status": ["name": "In Progress", "category": "IN_PROGRESS"]],
             "createdAt": G.iso(-0.2)],
            ["id": 2, "cardId": 1, "title": "Schedule pairing on routing", "assignee": G.minh, "issue": NSNull(), "createdAt": G.iso(-0.1)]]]
    }

    // MARK: OKR

    static func kr(_ id: Int, _ ten: String, metric: String = "NUMBER", unit: String?, dau: Double, dich: Double, ht: Double,
                   nguon: String = "MANUAL", tinCay: Double?, chu: [String: Any]?) -> [String: Any] {
        let tienDo = OkrTinh.tienDo(metric: metric, dau: dau, dich: dich, hienTai: ht)
        let thuHai = NgayCTW.dauTuan(Date())
        let ci: [[String: Any]] = (0..<4).map { i in
            let p = max(tienDo - Double(i) * 0.12, 0)
            return ["id": id * 10 + i, "weekStart": NgayCTW.ymd(NgayCTW.cong(thuHai, ngay: -7 * i)), "value": dau + (dich - dau) * p,
                    "progress": p, "confidence": max((tinCay ?? 7) - Double(i % 2), 0),
                    "note": i == 0 ? "Beta feedback is in; crash rate dropped." as Any : NSNull(), "at": G.iso(Double(-7 * i)), "user": chu ?? G.toi]
        }
        return ["id": id, "title": ten, "metric": metric, "unit": unit ?? NSNull(), "startValue": dau, "targetValue": dich, "currentValue": ht,
                "source": nguon, "owner": chu ?? NSNull(), "position": id, "progress": tienDo, "score": NSNull(),
                "suggestedScore": (tienDo * 10).rounded() / 10,
                "linkSummary": nguon == "MANUAL" ? NSNull() as Any : ["done": 9, "total": 14, "unit": nguon == "POINTS" ? "points" : "issues"],
                "confidence": tinCay ?? NSNull(), "canCheckin": nguon == "MANUAL", "checkins": nguon == "MANUAL" ? ci : [], "links": [Any]()]
    }

    static func okr(phamVi: String) -> [String: Any] {
        let thuHai = NgayCTW.dauTuan(Date())
        let batDau = NgayCTW.cong(thuHai, ngay: -42)
        let ketThuc = NgayCTW.cong(batDau, ngay: 90)
        let cycle: [String: Any] = ["id": 3, "name": "Q4 2026", "startDate": NgayCTW.ymd(batDau), "endDate": NgayCTW.ymd(ketThuc), "status": "ACTIVE", "createdById": 2]
        let wsObj: [String: Any] = ["id": 10, "cycleId": 3, "projectId": NSNull(), "project": NSNull(), "parent": NSNull(),
                                    "title": "Become the team tool our customers use every day", "description": NSNull(), "owner": G.linh,
                                    "position": 0, "progress": 0.52, "expected": 0.47, "status": "ON_TRACK", "confidence": 7,
                                    "score": NSNull(), "scoreBand": NSNull(), "scoreNote": NSNull(), "canEdit": true,
                                    "keyResults": [kr(101, "Weekly active teams", unit: "teams", dau: 20, dich: 60, ht: 41, tinCay: 7, chu: G.linh)]]
        let duAn: [[String: Any]] = [
            ["id": 11, "cycleId": 3, "projectId": 7, "project": ["key": "NW", "name": "Mobile App Launch"], "parent": ["id": 10, "title": "Become the team tool our customers use every day"],
             "title": "Ship a 5-star mobile app", "description": NSNull(), "owner": G.toi, "position": 0, "progress": 0.58, "expected": 0.47,
             "status": "ON_TRACK", "confidence": 8, "score": NSNull(), "scoreBand": NSNull(), "scoreNote": NSNull(), "canEdit": true,
             "keyResults": [kr(111, "App Store rating", unit: "★", dau: 0, dich: 4.8, ht: 4.5, tinCay: 8, chu: G.toi),
                            kr(112, "Crash-free sessions", metric: "PERCENT", unit: "%", dau: 97, dich: 99.8, ht: 99.1, tinCay: 6, chu: G.minh),
                            kr(113, "Launch scope delivered", metric: "PERCENT", unit: "%", dau: 0, dich: 100, ht: 64, nguon: "ISSUES", tinCay: 7, chu: nil)]],
            ["id": 12, "cycleId": 3, "projectId": 7, "project": ["key": "NW", "name": "Mobile App Launch"], "parent": ["id": 10, "title": "Become the team tool our customers use every day"],
             "title": "Make onboarding effortless", "description": NSNull(), "owner": G.an, "position": 1, "progress": 0.31, "expected": 0.47,
             "status": "AT_RISK", "confidence": 4, "score": NSNull(), "scoreBand": NSNull(), "scoreNote": NSNull(), "canEdit": true,
             "keyResults": [kr(121, "New teams finishing setup", metric: "PERCENT", unit: "%", dau: 40, dich: 80, ht: 52, tinCay: 4, chu: G.an),
                            kr(122, "Sample project on first launch", metric: "BOOLEAN", unit: nil, dau: 0, dich: 1, ht: 0, tinCay: 5, chu: G.scout)]],
        ]
        var ds = duAn
        if phamVi == "workspace" { ds.insert(wsObj, at: 0) } else { ds = duAn.map { var o = $0; o["parent"] = ["id": 10, "title": "Become the team tool our customers use every day"]; return o } }
        let tuan: [[String: Any]] = (0..<7).map { i in
            let d = NgayCTW.cong(batDau, ngay: 7 * i)
            return ["week": NgayCTW.ymd(d), "actual": Double(i) * 8.5 + 2, "expected": Double(i) * 7.8, "confidence": 7 - Double(i % 3) * 0.5]
        }
        return ["scope": phamVi, "workspaceId": 1, "projectId": phamVi == "project" ? 7 as Any : NSNull(),
                "cycles": [cycle, ["id": 2, "name": "Q3 2026", "startDate": "2026-07-01", "endDate": "2026-09-30", "status": "CLOSED", "createdById": 2]],
                "cycle": cycle, "canEdit": true, "canCreateCycle": true, "canManageCycle": true, "objectives": ds,
                "dashboard": ["objectives": ds.count, "keyResults": 6, "statusCounts": ["NOT_STARTED": 0, "ON_TRACK": phamVi == "workspace" ? 2 : 1, "AT_RISK": 1, "OFF_TRACK": 0, "DONE": 0, "SCORED": 0],
                              "avgProgress": 48.6, "avgScore": NSNull(), "avgConfidence": 6.3, "weeks": tuan]]
    }

    // MARK: Không gian

    static var portfolio: [String: Any] {
        func moc(_ id: Int, _ ten: String, _ n: Int, _ pid: Int, _ key: String, xong: Int, tong: Int) -> [String: Any] {
            ["id": id, "name": ten, "date": NgayCTW.ymd(NgayCTW.cong(Date(), ngay: n)), "daysUntil": n, "total": tong, "done": xong,
             "projectId": pid, "projectKey": key, "projectName": key, "url": "/work/northwind/\(key)/releases"]
        }
        func duAn(_ id: Int, _ key: String, _ ten: String, _ loai: String, mau: String, rag: String, lyDo: [[String: Any]], mo: Int, tre: Int, xong: Int,
                  sprint: [String: Any]?, moc m: [String: Any]?, lead: [String: Any]) -> [String: Any] {
            ["id": id, "key": key, "name": ten, "type": loai, "role": "ADMIN", "archivedAt": NSNull(), "avatarUrl": NSNull(), "iconEmoji": NSNull(),
             "color": mau, "kind": "SOFTWARE", "lead": lead, "url": "/work/northwind/\(key)/board",
             "modules": ["stages": false, "approvals": false, "teams": true], "counts": ["open": mo, "overdue": tre, "done14": xong],
             "sprint": sprint ?? NSNull(), "stage": NSNull(), "approvals": ["pending": key == "WEB" ? 2 : 0, "oldestDays": key == "WEB" ? 4 as Any : NSNull() as Any],
             "milestones": [Any](), "nextMilestone": m ?? NSNull(), "dependencies": ["blockedBy": key == "WEB" ? 1 : 0, "blocking": key == "NW" ? 1 : 0],
             "health": ["rag": rag, "reasons": lyDo]]
        }
        let m1 = moc(1, "v1.0 App Store", 9, 7, "NW", xong: 18, tong: 26)
        let m2 = moc(2, "Marketing site launch", -2, 8, "WEB", xong: 11, tong: 15)
        let m3 = moc(3, "Clinic MVP demo", 21, 11, "SWP", xong: 6, tong: 20)
        return ["today": NgayCTW.ymd(Date()), "rules": [Any](), "thresholds": [String: Any](),
                "projects": [
                    duAn(7, "NW", "Mobile App Launch", "SCRUM", mau: "#7c3aed", rag: "GREEN",
                         lyDo: [["level": "GREEN", "code": "ALL_CLEAR", "text": "All clear"]], mo: 24, tre: 1, xong: 11,
                         sprint: ["name": "Sprint 6 — Beta polish", "status": "ON_TRACK", "summary": "On pace: 2.1 pts/day needed, 2.6 recent.",
                                  "daysLeft": 8, "remaining": 17, "total": 29, "done": 12, "neededPerDay": 2.1, "recentPerDay": 2.6, "unit": "POINTS"],
                         moc: m1, lead: G.linh),
                    duAn(8, "WEB", "Marketing Website", "KANBAN", mau: "#0891b2", rag: "RED",
                         lyDo: [["level": "RED", "code": "MILESTONE_LATE", "text": "Milestone “Marketing site launch” is 2 days late"],
                                ["level": "AMBER", "code": "APPROVAL_WAITING", "text": "2 approvals waiting for 4 days"]], mo: 9, tre: 4, xong: 6,
                         sprint: nil, moc: m2, lead: G.an),
                    duAn(11, "SWP", "Clinic Booking System", "SCRUM", mau: "#ea580c", rag: "AMBER",
                         lyDo: [["level": "AMBER", "code": "SPRINT_AT_RISK", "text": "Sprint 3 at risk: needs 3.4 pts/day, recent 1.9"]], mo: 31, tre: 2, xong: 7,
                         sprint: ["name": "Sprint 3", "status": "AT_RISK", "summary": "Needs 3.4 pts/day, recent pace 1.9.",
                                  "daysLeft": 5, "remaining": 17, "total": 30, "done": 13, "neededPerDay": 3.4, "recentPerDay": 1.9, "unit": "POINTS"],
                         moc: m3, lead: G.sara)],
                "milestones": [m2, m1, m3],
                "blockers": [["id": 1, "since": G.iso(-3),
                              "blocker": ["hidden": false, "projectId": 7, "key": "NW-19", "projectKey": "NW", "projectName": "Mobile App Launch", "number": 19, "title": "iPad split view layout", "dueDate": NSNull()],
                              "blocked": ["hidden": false, "projectId": 8, "key": "WEB-31", "projectKey": "WEB", "projectName": "Marketing Website", "number": 31, "title": "App screenshots on the landing page", "dueDate": NgayCTW.ymd(Date())]]],
                "canSeeWorkload": true, "workloadScope": "ALL"]
    }

    static var workload: [String: Any] {
        let thuHai = NgayCTW.dauTuan(Date())
        let tuan: [[String: Any]] = (0..<4).map { i in
            ["start": NgayCTW.ymd(NgayCTW.cong(thuHai, ngay: 7 * i)), "end": NgayCTW.ymd(NgayCTW.cong(thuHai, ngay: 7 * i + 6))]
        }
        func muc(_ pct: Double) -> String { pct > 100 ? "over" : (pct >= 85 ? "high" : (pct >= 40 ? "ok" : (pct > 0 ? "low" : "none"))) }
        func nguoi(_ u: [String: Any], _ pcts: [Double], doi: [Int]) -> [String: Any] {
            let w = pcts.enumerated().map { i, p -> [String: Any] in
                ["start": tuan[i]["start"]!, "end": tuan[i]["end"]!, "workingDays": 5, "capacity": 40, "hours": p * 0.4, "issueIds": [Int](),
                 "pct": p, "overloaded": p > 100, "level": muc(p)]
            }
            let tong = pcts.reduce(0, +) * 0.4
            let pct = pcts.reduce(0, +) / Double(pcts.count)
            return ["user": u, "teamIds": doi, "hoursPerDay": 8, "capacitySource": "projects", "timeOff": [Any](), "weeks": w,
                    "totalHours": tong, "totalCapacity": 160, "pct": pct, "overloaded": pct > 100, "level": muc(pct),
                    "overloadedWeeks": [String](), "unscheduled": 0, "scheduledBySprint": 2, "unestimated": (u["id"] as? Int) == 3 ? 2 : 0,
                    "issues": [["id": 112, "key": "NW-12", "number": 12, "title": "Push notifications open the right issue", "priority": 2,
                                "project": ["id": 7, "key": "NW", "name": "Mobile App Launch"], "teamId": 1, "start": NSNull(),
                                "due": NgayCTW.ymd(Date()), "overdue": false, "planDue": NSNull(), "planSource": "due", "planLabel": NSNull(),
                                "hours": 12, "source": "points", "status": ["name": "In Progress", "category": "IN_PROGRESS"],
                                "type": ["key": "STORY", "name": "Story", "color": "#16a34a"], "url": "/work/northwind/NW/issue/12"]]]
        }
        return ["from": tuan[0]["start"]!, "to": tuan[3]["end"]!, "today": NgayCTW.ymd(Date()), "weeks": tuan, "scope": "ALL", "hoursPerPoint": 4,
                "rules": ["defaultHoursPerDay": 8, "overloadPct": 100, "highPct": 85, "conversion": [String]()],
                "teams": [Any](), "teamOptions": [["id": 1, "key": "MOB", "name": "Mobile", "color": "#7c3aed"], ["id": 2, "key": "WEB", "name": "Web", "color": "#0891b2"]],
                "projectOptions": [["id": 7, "key": "NW", "name": "Mobile App Launch"]],
                "people": [nguoi(G.minh, [135, 118, 96, 70], doi: [1]), nguoi(G.toi, [96, 88, 70, 45], doi: [1]),
                           nguoi(G.linh, [72, 80, 66, 50], doi: [2]), nguoi(G.scout, [55, 40, 30, 0], doi: [1]),
                           nguoi(G.an, [35, 52, 48, 20], doi: [2, 3])],
                "truncated": false]
    }

    static func doi(_ id: Int, _ key: String, _ ten: String, _ mau: String, _ tv: [[String: Any]], lead: Int, mo: Int) -> [String: Any] {
        ["id": id, "workspaceId": 1, "key": key, "name": ten, "color": mau, "description": NSNull(), "archivedAt": NSNull(), "createdAt": G.iso(-60),
         "members": tv.map { u in u.merging(["teamRole": (u["id"] as? Int) == lead ? "LEAD" : "MEMBER"]) { $1 } },
         "leadIds": [lead], "openIssues": mo]
    }

    static var hangDoi: [String: Any] {
        func t(_ so: Int, _ ten: String, _ pr: Int, _ ai: [String: Any]?, han: Double?) -> [String: Any] {
            ["id": 100 + so, "number": so, "title": ten, "priority": pr, "dueDate": han.map { G.ngay($0) + "T00:00:00.000Z" } ?? NSNull(),
             "projectId": 7, "projectKey": "NW", "projectName": "Mobile App Launch", "key": "NW-\(so)", "assignee": ai ?? NSNull(), "resolvedAt": NSNull()]
        }
        return ["team": doi(1, "MOB", "Mobile", "#7c3aed", [G.toi, G.minh, G.scout], lead: 1, mo: 14), "isLead": true, "total": 4, "limit": 100, "offset": 0,
                "items": [t(14, "Crash when attaching a HEIC photo on iOS 17", 1, G.minh, han: -1), t(12, "Push notifications open the right issue", 2, G.toi, han: 0),
                          t(20, "Accessibility audit (Dynamic Type)", 2, nil, han: 6), t(16, "Write release notes draft", 4, G.scout, han: 5)]]
    }

    static var agentDashboard: [String: Any] {
        let thuHai = NgayCTW.dauTuan(Date())
        let tuan: [[String: Any]] = (0..<5).map { i in
            ["weekStart": NgayCTW.ymd(NgayCTW.cong(thuHai, ngay: -7 * (4 - i))), "humanResolved": [9, 11, 8, 12, 6][i],
             "agentResolved": [2, 3, 5, 4, 3][i], "agentReturned": [0, 1, 1, 0, 0][i], "agentCostUsd": [0.8, 1.4, 2.1, 1.7, 0.9][i],
             "humanHours": [62, 71, 58, 75, 40][i]]
        }
        return ["days": 30, "from": NgayCTW.ymd(NgayCTW.cong(Date(), ngay: -30)), "to": NgayCTW.ymd(Date()), "scope": "ALL", "weeks": tuan,
                "agents": [["agent": ["id": 1, "userId": 9, "username": "scout", "displayName": "Scout", "model": "claude-sonnet-5", "status": "ACTIVE",
                                      "owner": G.linh, "lastSeenAt": G.iso(0, gio: -1)],
                            "issuesResolved": 17, "pointsResolved": 31, "returnedCount": 2, "returnRate": 0.1176, "costUsd": 6.9,
                            "costSource": ["reported": 6.1, "gateway": 0.8], "costPerPoint": 0.2226,
                            "tokens": ["in": 1_204_000, "out": 210_400, "cacheRead": 880_000], "leaseMinutes": 1440, "activeLeases": 1]],
                "totals": ["humanResolved": 46, "agentResolved": 17, "agentReturned": 2, "agentReturnRate": 0.1176, "agentCostUsd": 6.9,
                           "humanHours": 306, "costSource": ["reported": 6.1, "gateway": 0.8]]]
    }
}
#endif
