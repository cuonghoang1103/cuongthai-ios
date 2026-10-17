#if DEBUG
import Foundation

// MARK: - Dữ liệu mẫu mảng B1 — Sprints · Reports · Dashboards (xem `XemThuCTW+KeHoach.swift`)
//
// Hình dạng đối chiếu service backend:
//   sprints.service.ts (SPRINT_SELECT) · reports.service.ts (burndown/velocity/sprint/epics) ·
//   planning.service.ts (reports/time) · flowReports.service.ts (cfd/throughput/cycle-time/kpis/load-by-person) ·
//   search.service.ts (search/stats/created-resolved/dashboards) · ai.service.ts (insights) ·
//   agentReports.service.ts (reports/agents) · reportBuilder.service.ts (templates/preview).
// Dự án mẫu NW (pid 7): sprint 21 ACTIVE "Sprint 6 — Beta polish", 22 PLANNED, 16–20 CLOSED.
// ⚠️ Không chặn đường LÕI (`/work/projects/7`, `/board`, `/backlog`, `/issues`…) và không chặn
//    `/work/me/timer` (của mô-đun Time — B3).

enum DuLieuGiaB1 {
    private typealias G = DuLieuGia

    static func route(_ m: String, _ p: String, _ b: [String: Any]) -> Any? {
        let pr = "/work/projects/7"
        guard p.hasPrefix(pr + "/") else { return nil }
        let r = String(p.dropFirst(pr.count))
        switch (m, r) {
        // MARK: Sprints
        case ("GET", "/sprints"): return dsSprint
        case ("POST", "/sprints"):
            return sprint(23, b["name"] as? String ?? "Sprint 8", "PLANNED", goal: b["goal"] as? String, a: nil, e: nil)
        case ("GET", "/reports/burndown"): return burndown
        case ("GET", "/reports/sprint"): return ["sprint": sprintBaoCao, "report": baoCaoSprint]
        // MARK: Reports
        case ("GET", "/reports/velocity"): return velocity
        case ("GET", "/reports/epics"): return epics
        case ("GET", "/reports/kpis"): return kpis
        case ("GET", "/insights"): return insights
        case ("GET", "/reports/cfd"): return cfd
        case ("GET", "/reports/throughput"): return throughput
        case ("GET", "/reports/cycle-time"): return cycleTime
        case ("GET", "/reports/load-by-person"): return taiTheoNguoi
        case ("GET", "/stats"): return thongKe()
        case ("GET", "/stats/created-resolved"): return taoXong
        case ("GET", "/search"): return timKiem
        case ("GET", "/reports/time"): return thoiGian
        case ("GET", "/reports/agents"): return nguoiVsAgent
        // MARK: Dashboards
        case ("GET", "/dashboards"): return [dashboard]
        case ("POST", "/dashboards/overview"): return dashboard
        case ("GET", "/report-builder/templates"): return mauBaoCao
        case ("POST", "/report-builder/preview"): return xemTruoc
        default: break
        }
        // Ghi sprint: PATCH/DELETE /sprints/:sid, POST /sprints/:sid/start|complete
        if r.hasPrefix("/sprints/") {
            let phan = r.split(separator: "/")
            let sid = Int(phan.count > 1 ? phan[1] : "") ?? 21
            if m == "DELETE" { return ["deleted": true] }
            if r.hasSuffix("/complete") { return ["report": baoCaoSprint, "movedTo": NSNull()] }
            if r.hasSuffix("/start") { return sprint(sid, "Sprint 7 — Launch", "ACTIVE", goal: nil, a: 0, e: 14) }
            return sprint(sid, b["name"] as? String ?? "Sprint", "PLANNED", goal: b["goal"] as? String, a: nil, e: nil)
        }
        return nil
    }

    // MARK: Sprint

    static func sprint(_ id: Int, _ ten: String, _ st: String, goal: String?, a: Double?, e: Double?,
                       xongLuc: Double? = nil, cam: Double? = nil, xong: Double? = nil, pos: Int = 0) -> [String: Any] {
        ["id": id, "name": ten, "goal": goal ?? NSNull(), "state": st,
         "startAt": a.map { G.iso($0) } ?? NSNull(), "endAt": e.map { G.iso($0) } ?? NSNull(),
         "completedAt": xongLuc.map { G.iso($0) } ?? NSNull(),
         "committedPoints": cam ?? NSNull(), "completedPoints": xong ?? NSNull(), "position": pos]
    }

    static var dsSprint: [[String: Any]] {
        [sprint(21, "Sprint 6 — Beta polish", "ACTIVE", goal: "Ship the public beta to TestFlight with push notifications and offline My Work.",
                a: -6, e: 8, cam: 29, pos: 6),
         sprint(22, "Sprint 7 — Launch", "PLANNED", goal: "App Store submission", a: nil, e: nil, pos: 7),
         sprint(20, "Sprint 5 — Chat", "CLOSED", goal: "Team chat in the app", a: -20, e: -6, xongLuc: -6, cam: 26, xong: 23, pos: 5),
         sprint(19, "Sprint 4 — Board", "CLOSED", goal: nil, a: -34, e: -20, xongLuc: -20, cam: 24, xong: 24, pos: 4),
         sprint(18, "Sprint 3 — Issues", "CLOSED", goal: nil, a: -48, e: -34, xongLuc: -34, cam: 30, xong: 21, pos: 3),
         sprint(17, "Sprint 2 — Sign-in", "CLOSED", goal: nil, a: -62, e: -48, xongLuc: -48, cam: 18, xong: 17, pos: 2),
         sprint(16, "Sprint 1 — Foundations", "CLOSED", goal: nil, a: -76, e: -62, xongLuc: -62, cam: 15, xong: 12, pos: 1)]
    }

    static var sprintBaoCao: [String: Any] {
        var s = sprint(21, "Sprint 6 — Beta polish", "ACTIVE", goal: "Ship the public beta to TestFlight with push notifications and offline My Work.",
                       a: -6, e: 8, cam: 29)
        s["report"] = ["committedIssueIds": [112, 114, 115, 116, 117, 118, 119]]
        s.removeValue(forKey: "position")
        return s
    }

    /// 15 ngày: 7 ngày đã qua có số liệu (có một lần thêm phạm vi ở ngày 3), 8 ngày tới = null.
    static var burndown: [String: Any] {
        let con: [Double] = [29, 29, 26, 27, 22, 19, 16]
        let tong: [Double] = [29, 29, 29, 32, 32, 32, 32]
        var diem: [[String: Any]] = []
        for i in 0..<15 {
            let d = G.ngay(Double(i - 6))
            let ideal = max(29 - 29.0 * Double(i) / 14.0, 0)
            if i < con.count {
                diem.append(["day": d, "remaining": con[i], "total": tong[i], "done": tong[i] - con[i], "ideal": (ideal * 100).rounded() / 100])
            } else {
                diem.append(["day": d, "remaining": NSNull(), "total": NSNull(), "done": NSNull(), "ideal": (ideal * 100).rounded() / 100])
            }
        }
        return ["sprint": sprintBaoCao, "unit": "POINTS", "points": diem]
    }

    static var baoCaoSprint: [String: Any] {
        ["completed": [["id": 118, "number": 18, "title": "Rate-limit chat uploads per user", "points": 2],
                       ["id": 119, "number": 19, "title": "iPad split view layout", "points": 5]],
         "incomplete": [["id": 112, "number": 12, "title": "Push notifications open the right issue", "points": 5],
                        ["id": 114, "number": 14, "title": "Crash when attaching a HEIC photo on iOS 17", "points": 3],
                        ["id": 115, "number": 15, "title": "Design empty states for Inbox and Chat", "points": 2],
                        ["id": 116, "number": 16, "title": "Write release notes draft", "points": 1],
                        ["id": 117, "number": 17, "title": "Offline cache for My Work", "points": 8]],
         "added": [20], "removed": [24], "committedPoints": 29, "completedPoints": 7, "unit": "POINTS"]
    }

    // MARK: Reports

    static var velocity: [String: Any] {
        let ds: [(Int, String, Double, Double, Double, Double)] = [
            (16, "Sprint 1", 15, 12, -62, 12), (17, "Sprint 2", 18, 17, -48, 14.5), (18, "Sprint 3", 30, 21, -34, 16.7),
            (19, "Sprint 4", 24, 24, -20, 20.7), (20, "Sprint 5", 26, 23, -6, 22.7)]
        return ["unit": "POINTS", "average": 22.7,
                "sprints": ds.map { ["id": $0.0, "name": $0.1, "committedPoints": $0.2, "completedPoints": $0.3, "completedAt": G.iso($0.4), "rollingAverage": $0.5] }]
    }

    static var epics: [String: Any] {
        ["unit": "POINTS", "epics": [
            ["id": 101, "number": 1, "title": "Mobile app — public beta", "statusId": 2, "dueDate": G.iso(8), "resolved": false,
             "total": 14, "completed": 9, "points": 52, "pointsDone": 33, "percent": 64],
            ["id": 102, "number": 2, "title": "Notifications & deep links", "statusId": 2, "dueDate": G.iso(4), "resolved": false,
             "total": 6, "completed": 3, "points": 18, "pointsDone": 8, "percent": 50],
            ["id": 103, "number": 3, "title": "Sign in with Apple", "statusId": 4, "dueDate": NSNull(), "resolved": true,
             "total": 4, "completed": 4, "points": 11, "pointsDone": 11, "percent": 100]]]
    }

    static var kpis: [String: Any] {
        ["asOf": G.iso(0), "open": ["value": 24, "previous": 27], "overdue": ["value": 2, "previous": 1],
         "blocked": ["value": 1, "previous": NSNull()],
         "sprint": ["name": "Sprint 6 — Beta polish", "status": "AT_RISK", "daysLeft": 8, "total": 32, "done": 16, "pctDone": 50],
         "highRisks": 1]
    }

    static var insights: [String: Any] {
        func br(_ so: Int, _ t: String, _ ai: String?, _ st: String, _ han: Double?) -> [String: Any] {
            ["key": "NW-\(so)", "number": so, "title": t, "assignee": ai ?? NSNull(), "status": st, "dueDate": han.map { G.ngay($0) } ?? NSNull()]
        }
        var stale = br(20, "Accessibility audit (Dynamic Type)", nil, "To Do", 6)
        stale["idleDays"] = 9
        return [
            "overdue": [br(14, "Crash when attaching a HEIC photo on iOS 17", "minh", "To Do", -1),
                        br(21, "Fix sign-in token refresh loop", "alex", "In Progress", -1)],
            "dueSoon": [br(12, "Push notifications open the right issue", "alex", "In Progress", 2),
                        br(15, "Design empty states for Inbox and Chat", "an", "In Review", 4)],
            "stale": [stale], "unassignedUrgent": [Any](),
            "overloaded": [["username": "alex", "points": 21, "issues": 5, "unit": "points", "capacity": 16, "overloaded": true, "basis": "capacity"]],
            "loads": [Any](),
            "sprintRisk": ["sprint": "Sprint 6 — Beta polish", "committed": 29, "total": 32, "remaining": 16, "done": 16, "daysLeft": 8,
                           "elapsedDays": 6, "neededPerDay": 2.7, "recentPerDay": 2.2, "estimated": true, "atRisk": true, "status": "AT_RISK",
                           "summary": "At the recent pace (2.2 pts/day) about 3 points will be left when the sprint ends."],
            "unit": "POINTS"]
    }

    static var cfd: [String: Any] {
        var diem: [[String: Any]] = []
        for i in 0..<30 {
            let t = Double(i)
            diem.append(["day": G.ngay(t - 29), "s1": max(18 - t * 0.25, 9).rounded(), "s2": (4 + (t.truncatingRemainder(dividingBy: 5))).rounded(),
                         "s3": (2 + (t / 10).rounded(.down)), "s4": (6 + t * 0.6).rounded()])
        }
        return ["scope": "Top-level issues (no epics, sub-tasks or test cases).", "days": 30, "from": G.ngay(-29), "to": G.ngay(0),
                "bands": [["key": "s1", "name": "To Do", "category": "TODO", "color": NSNull()],
                          ["key": "s2", "name": "In Progress", "category": "IN_PROGRESS", "color": NSNull()],
                          ["key": "s3", "name": "In Review", "category": "IN_PROGRESS", "color": NSNull()],
                          ["key": "s4", "name": "Done", "category": "DONE", "color": NSNull()]],
                "points": diem]
    }

    static var throughput: [String: Any] {
        let dem = [3, 5, 4, 6, 2, 5, 7, 6, 4, 8, 6, 5]
        let dau = NgayCTW.dauTuan(Date())
        let tuan: [[String: Any]] = dem.enumerated().map { i, c in
            let d = NgayCTW.cong(dau, ngay: (i - 11) * 7)
            return ["week": NgayCTW.ymd(d), "end": NgayCTW.ymd(NgayCTW.cong(d, ngay: 6)), "count": c, "points": c * 3]
        }
        return ["scope": "Top-level issues.", "unit": "POINTS", "weeks": tuan, "average": 5.1, "averagePoints": 15.4]
    }

    static var cycleTime: [String: Any] {
        ["scope": "Top-level issues.", "days": 90, "from": G.ngay(-89), "to": G.ngay(0), "items": [Any](),
         "cycle": ["n": 41, "p50": 2.5, "p85": 6, "p95": 9, "mean": 3.4],
         "lead": ["n": 41, "p50": 7, "p85": 15, "p95": 22, "mean": 8.9]]
    }

    static var taiTheoNguoi: [String: Any] {
        ["unit": "POINTS", "people": [
            ["user": G.toi, "todo": 2, "inProgress": 3, "overdue": 1, "blocked": 0, "estimate": 21, "total": 5],
            ["user": G.minh, "todo": 3, "inProgress": 1, "overdue": 1, "blocked": 1, "estimate": 11, "total": 4],
            ["user": G.an, "todo": 1, "inProgress": 2, "overdue": 0, "blocked": 0, "estimate": 7, "total": 3],
            ["user": G.scout, "todo": 1, "inProgress": 1, "overdue": 0, "blocked": 0, "estimate": 2, "total": 2],
            ["user": G.linh, "todo": 1, "inProgress": 0, "overdue": 0, "blocked": 0, "estimate": 3, "total": 1],
            ["user": NSNull(), "todo": 4, "inProgress": 0, "overdue": 0, "blocked": 0, "estimate": 9, "total": 4]]]
    }

    /// `/stats` — máy chủ giả không thấy `?groupBy=` (chỉ đường dẫn) ⇒ xoay vòng bốn kiểu nhóm theo
    /// thứ tự màn Distribution hỏi (status → assignee → type → priority). Chỉ để chụp màn hình.
    private static let khoa = NSLock()
    nonisolated(unsafe) private static var luot = 0
    static func thongKe() -> [String: Any] {
        khoa.lock(); let i = luot % 4; luot += 1; khoa.unlock()
        let nhom: [[String: Any]]
        switch i {
        case 0: nhom = [["key": "sTo Do", "label": "To Do", "category": "TODO", "count": 11, "points": 29],
                        ["key": "sIn Progress", "label": "In Progress", "category": "IN_PROGRESS", "count": 6, "points": 21],
                        ["key": "sIn Review", "label": "In Review", "category": "IN_PROGRESS", "count": 3, "points": 7],
                        ["key": "sDone", "label": "Done", "category": "DONE", "count": 4, "points": 12]]
        case 1: nhom = [["key": "u1", "label": "Alex Morgan", "count": 5, "points": 21], ["key": "u3", "label": "Minh Pham", "count": 4, "points": 11],
                        ["key": "none", "label": "Unassigned", "count": 4, "points": 9], ["key": "u4", "label": "An Nguyen", "count": 3, "points": 7],
                        ["key": "u9", "label": "Scout", "count": 2, "points": 2], ["key": "u2", "label": "Linh Tran", "count": 1, "points": 3]]
        case 2: nhom = [["key": "tStory", "label": "Story", "color": "#16a34a", "count": 9, "points": 38],
                        ["key": "tTask", "label": "Task", "color": "#2563eb", "count": 10, "points": 18],
                        ["key": "tBug", "label": "Bug", "color": "#dc2626", "count": 5, "points": 13]]
        default: nhom = [["key": "p1", "label": "Highest", "count": 2, "points": 6], ["key": "p2", "label": "High", "count": 6, "points": 22],
                         ["key": "p3", "label": "Medium", "count": 11, "points": 30], ["key": "p4", "label": "Low", "count": 4, "points": 8],
                         ["key": "p5", "label": "Lowest", "count": 1, "points": 3]]
        }
        let tong = nhom.compactMap { $0["count"] as? Int }.reduce(0, +)
        return ["unit": "POINTS", "total": tong, "groups": nhom]
    }

    static var taoXong: [[String: Any]] {
        let tao = [2, 1, 3, 0, 2, 4, 1, 1, 2, 3, 0, 0, 2, 1, 3, 2, 1, 4, 2, 0, 1, 2, 3, 1, 2, 0, 1, 3, 2, 1, 2]
        let xong = [1, 2, 1, 1, 3, 2, 0, 0, 2, 2, 1, 1, 3, 2, 1, 2, 2, 3, 1, 0, 0, 3, 2, 2, 1, 1, 0, 2, 3, 2, 1]
        return (0...30).map { i in ["day": G.ngay(Double(i - 30)), "created": tao[i], "resolved": xong[i]] }
    }

    static var timKiem: [String: Any] {
        let ds = Array(G.the.filter { ($0["statusId"] as? Int) != 4 }.prefix(5))
        return ["total": ds.count, "items": ds, "offset": 0, "limit": 10]
    }

    static var thoiGian: [String: Any] {
        let dau = NgayCTW.dauTuan(Date())
        let soNgay = max(NgayCTW.soNgay(dau, Date()) + 1, 1)
        func ngayPhut(_ ds: [Int]) -> [String: Int] {
            var r: [String: Int] = [:]
            for (i, v) in ds.prefix(soNgay).enumerated() { r[NgayCTW.ymd(NgayCTW.cong(dau, ngay: i))] = v }
            return r
        }
        func ng(_ u: [String: Any], _ ten: String, _ ds: [Int], kind: String = "HUMAN", auto: Int = 0, the: [(Int, String, Int)]) -> [String: Any] {
            let d = ngayPhut(ds)
            return ["user": u, "userKind": kind, "name": ten, "totalMin": d.values.reduce(0, +), "autoMin": auto, "byDay": d,
                    "issues": the.map { ["number": $0.0, "title": $0.1, "minutes": $0.2] }]
        }
        let ds = [ng(G.toi, "Alex Morgan", [420, 390, 450, 300, 360, 0, 0], the: [(12, "Push notifications open the right issue", 900), (21, "Fix sign-in token refresh loop", 600)]),
                  ng(G.minh, "Minh Pham", [360, 420, 300, 400, 330, 0, 0], the: [(14, "Crash when attaching a HEIC photo on iOS 17", 720)]),
                  ng(G.an, "An Nguyen", [240, 300, 360, 270, 180, 60, 0], the: [(15, "Design empty states for Inbox and Chat", 540)]),
                  ng(G.scout, "Scout", [90, 120, 60, 150, 45, 0, 0], kind: "AGENT", auto: 240, the: [(16, "Write release notes draft", 300)])]
        let tong = ds.compactMap { $0["totalMin"] as? Int }.reduce(0, +)
        let agent = (ds.last?["totalMin"] as? Int) ?? 0
        return ["from": NgayCTW.ymd(dau), "to": NgayCTW.ymd(Date()), "principal": "ALL", "totalMin": tong,
                "byPrincipal": ["HUMAN": tong - agent, "AGENT": agent], "people": ds]
    }

    static var nguoiVsAgent: [String: Any] {
        let agent: [String: Any] = [
            "agent": ["id": 3, "userId": 9, "username": "scout", "displayName": "Scout", "model": "claude-sonnet-5", "status": "ACTIVE", "owner": G.linh],
            "issuesTouched": 9, "issuesResolved": 6, "pointsResolved": 11, "returnedCount": 1, "returnRate": 0.1667,
            "leaseMinutes": 610, "worklogMinutes": 465, "autoWorklogMinutes": 240,
            "tokens": ["in": 1_284_000, "out": 96_400, "cacheRead": 2_010_000],
            "costUsd": 7.4210, "costSource": ["reported": 6.1180, "gateway": 1.3030], "costPerPoint": 0.6746, "costPerResolved": 1.2368]
        func h(_ u: [String: Any], _ m: Int, _ r: Int) -> [String: Any] {
            ["user": u, "worklogMinutes": m, "hours": (Double(m) / 60 * 10).rounded() / 10, "cost": NSNull(), "issuesResolved": r]
        }
        return ["from": G.ngay(-29), "to": G.ngay(0), "sprintId": NSNull(), "agents": [agent],
                "humans": [h(G.toi, 4_320, 9), h(G.minh, 3_960, 7), h(G.an, 3_120, 5), h(G.linh, 1_800, 4)],
                "totals": ["agents": ["issuesResolved": 6, "returnedCount": 1, "returnRate": 0.1667, "pointsResolved": 11, "costUsd": 7.4210,
                                      "costSource": ["reported": 6.1180, "gateway": 1.3030], "tokens": ["in": 1_284_000, "out": 96_400, "cacheRead": 2_010_000],
                                      "leaseMinutes": 610, "worklogMinutes": 465, "costPerPoint": 0.6746, "costPerResolved": 1.2368],
                           "humans": ["hours": 220.0, "worklogMinutes": 13_200, "cost": NSNull(), "issuesResolved": 25]],
                "currency": NSNull()]
    }

    // MARK: Dashboards

    static var dashboard: [String: Any] {
        func w(_ id: String, _ k: String, _ t: String = "", size: String = "half", extra: [String: Any] = [:]) -> [String: Any] {
            ["id": id, "kind": k, "title": t, "size": size].merging(extra) { $1 }
        }
        return ["id": 4, "name": "Project overview", "shared": true, "ownerId": 2, "updatedAt": G.iso(-1),
                "widgets": [w("kp000001", "kpis", size: "full"),
                            w("br000002", "burndown"),
                            w("pi000003", "pie", "Open issues by status", extra: ["groupBy": "status", "query": "statusCategory != Done"]),
                            w("mi000004", "my_issues"),
                            w("cr000005", "created_resolved", extra: ["days": 30]),
                            w("wl000006", "workload"),
                            w("vl000007", "velocity"),
                            w("cf000008", "cfd", size: "full", extra: ["days": 30]),
                            w("tx000009", "text", "Team notes", extra: ["text": "**Beta freeze** on Friday. Only P1 fixes after that — tag them with `release`."]),
                            w("rk000010", "top_risks")]]
    }

    static var mauBaoCao: [String: Any] {
        ["language": "en", "canEdit": true, "canManage": true, "templates": [Any](),
         "builtins": [["ref": "builtin:weekly", "key": "weekly", "builtin": true, "name": "Weekly status", "description": "KPIs, burnup and what changed this week", "layout": [String: Any]()],
                      ["ref": "builtin:sprint", "key": "sprint", "builtin": true, "name": "Sprint review", "description": "Velocity, burndown and the sprint's issues", "layout": [String: Any]()]]]
    }

    static var xemTruoc: [String: Any] {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 720 300"><rect width="720" height="300" fill="#fff"/>\
        <polyline fill="none" stroke="#9a9aa3" stroke-width="2" stroke-dasharray="6 6" points="40,40 680,260"/>\
        <polyline fill="none" stroke="#2a78d6" stroke-width="4" points="40,40 130,40 220,80 310,70 400,130 490,160 580,190"/></svg>
        """
        return ["title": "Weekly status — Mobile App Launch", "subtitle": "Northwind Studio", "lang": "en",
                "period": ["from": G.ngay(-6), "to": G.ngay(0), "kind": "week", "sprint": NSNull()],
                "project": ["name": "Mobile App Launch", "key": "NW"], "workspace": ["name": "Northwind Studio"],
                "accent": "#7a45e8", "generatedAt": G.iso(0), "options": ["cover": false, "toc": false, "logo": false, "coverImage": false],
                "brand": ["logoUrl": NSNull(), "coverUrl": NSNull()],
                "blocks": [
                    ["id": "h1", "type": "heading", "text": "This week at a glance", "level": 1],
                    ["id": "k1", "type": "kpis", "title": NSNull(), "items": [
                        ["key": "open", "label": "Open issues", "value": "24", "hint": "▼ 3 vs last week"],
                        ["key": "doneInPeriod", "label": "Done this week", "value": "7", "hint": NSNull()],
                        ["key": "overdue", "label": "Overdue", "value": "2", "hint": NSNull()],
                        ["key": "sprintProgress", "label": "Sprint progress", "value": "50%", "hint": "8 days left"]]],
                    ["id": "c1", "type": "chart", "title": "Sprint burndown", "svg": svg],
                    ["id": "i1", "type": "issues", "title": "Due in the next 7 days", "columns": ["Key", "Title", "Status", "Assignee", "Due"],
                     "colKeys": ["key", "title", "status", "assignee", "due"],
                     "rows": [["NW-12", "Push notifications open the right issue", "In Progress", "Alex Morgan", "Oct 20"],
                              ["NW-15", "Design empty states for Inbox and Chat", "In Review", "An Nguyen", "Oct 22"]], "total": 2],
                    ["id": "r1", "type": "risks", "title": "Top risks", "note": NSNull(), "items": [
                        ["key": "R-3", "title": "App Review may reject the demo account", "level": "HIGH", "score": 16, "owner": "Linh Tran",
                         "mitigation": "Turn on Pro for the demo account and write review notes."]]],
                    ["id": "a1", "type": "ai", "title": "Summary", "text": "The team closed 7 issues. Push routing is nearly done; HEIC crash is the main blocker for the beta.",
                     "generatedAt": G.iso(-0.1), "note": "Drafted by AI from project data — check before sending."]]]
    }
}
#endif
