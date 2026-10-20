#if DEBUG
import Foundation

// MARK: - Dữ liệu mẫu đợt B (21/10/2026) — board có epic, sửa hàng loạt, JQL, bộ lọc đã lưu, tìm toàn cục, ghim navPins
//
// Hình dạng theo backend (work.routes.ts + sprints/search/globalSearch service, user.routes preferences). Hỏi TRƯỚC các
// bộ khác (`DuLieuGiaMoDun.boXuLy` dòng đầu) nhưng CHỈ nhận đúng các tuyến dưới — còn lại trả nil.
// Màn thử: `board` (+ `SIMCTL_CHILD_CT_XEM_NHOM=assignee|epic|priority|subtasks`, `SIMCTL_CHILD_CT_XEM_CHON=1` bật chọn
// nhiều) · `backlog` · `list` · `timkiem` · `mod:…` như cũ.
// ⚠️ Cả tệp trong `#if DEBUG` (CLAUDE.md A6).

enum DuLieuGiaDotB {
    typealias G = DuLieuGia

    /// Epic (level 1) — KHÔNG nằm trên board (như thật), tải bằng `GET /issues?type=1`.
    static let epic: [[String: Any]] = [
        G.card(40, "Notifications & deep links", type: 1, st: 2, pr: 2, ai: 1, sp: nil, han: nil, nhan: [], sprint: nil),
        G.card(41, "Accessibility & polish", type: 1, st: 1, pr: 3, ai: 4, sp: nil, han: nil, nhan: [], sprint: nil),
    ]
    /// Thẻ board → epic.
    static let chaEpic: [Int: Int] = [12: 140, 14: 140, 16: 140, 15: 141, 20: 141, 19: 141]

    static func voiEpic(_ c: [String: Any]) -> [String: Any] {
        var m = c
        if let so = c["number"] as? Int, let p = chaEpic[so] { m["parentId"] = p; m["parentNumber"] = p - 100 }
        return m
    }

    nonisolated(unsafe) static var boLoc: [[String: Any]] = [
        ["id": 1, "name": "My open work", "query": "assignee = currentUser() AND statusCategory != Done ORDER BY priority ASC",
         "shared": false, "ownerId": 1, "updatedAt": G.iso(-2), "owner": ["username": "alex"]],
        ["id": 2, "name": "Release blockers", "query": "labels = release AND priority <= High", "shared": true, "ownerId": 2,
         "updatedAt": G.iso(-5), "owner": ["username": "linh"]],
    ]

    static func route(_ m: String, _ p: String, _ b: [String: Any]) -> Any? {
        let pr = "/work/projects/7"
        switch (m, p) {
        case ("GET", "/users/me/preferences"), ("PATCH", "/users/me/preferences"):
            return ["theme": "light", "preferences": ["work": ["locale": NSNull(), "navPins": ["7": ["pin": ["time", "sprints"], "hide": ["code"]]]]]]
        case ("GET", pr + "/board"):
            return ["mode": "SPRINT", "sprint": G.sprint, "fallback": false, "issues": G.the.map(G.apDoi).map(voiEpic)]
        case ("GET", pr + "/issues") where (b["type"] as? String) == "1":
            return ["items": epic, "total": epic.count, "nextCursor": NSNull()]
        case ("POST", pr + "/issues/bulk"):
            let so = (b["numbers"] as? [Int]) ?? []
            return ["updated": so, "failed": [Any]()]
        case ("GET", pr + "/search"):
            let tat = (G.the + G.tonDong).map(voiEpic)
            let jql = (b["jql"] as? String ?? "").lowercased()
            var ds = jql.contains("statuscategory != done") ? tat.filter { ($0["statusId"] as? Int) != 4 } : tat
            if jql.contains("order by priority") { ds.sort { ($0["priority"] as? Int ?? 3) < ($1["priority"] as? Int ?? 3) } }
            return ["total": ds.count, "items": ds, "offset": 0, "limit": 100]
        case ("GET", pr + "/filters"): return boLoc
        case ("POST", pr + "/filters"):
            let moi: [String: Any] = ["id": 3, "name": b["name"] ?? "Filter", "query": b["query"] ?? "", "shared": b["shared"] ?? false,
                                      "ownerId": 1, "updatedAt": G.iso(0), "owner": ["username": "alex"]]
            boLoc.append(moi)
            return moi
        case ("GET", "/work/search/facets"):
            return ["projects": [["id": 7, "key": "NW", "name": "Mobile App Launch", "archived": false, "workspace": ["slug": "northwind", "name": "Northwind Studio"]],
                                 ["id": 8, "key": "WEB", "name": "Marketing Website", "archived": false, "workspace": ["slug": "northwind", "name": "Northwind Studio"]],
                                 ["id": 11, "key": "SWP", "name": "Clinic Booking System", "archived": false, "workspace": ["slug": "swp391-g4", "name": "SWP391 · Group 4"]]],
                    "statuses": [["name": "To Do", "category": "TODO", "color": "#94a3b8", "projectCount": 3],
                                 ["name": "In Progress", "category": "IN_PROGRESS", "color": "#3b82f6", "projectCount": 3],
                                 ["name": "Done", "category": "DONE", "color": "#22c55e", "projectCount": 3]],
                    "types": [["key": "STORY", "name": "Story", "icon": "story", "color": "#16a34a", "projectCount": 3],
                              ["key": "BUG", "name": "Bug", "icon": "bug", "color": "#dc2626", "projectCount": 3],
                              ["key": "TASK", "name": "Task", "icon": "task", "color": "#2563eb", "projectCount": 3]],
                    "assignees": [G.toi, G.linh, G.minh, G.scout]]
        case ("GET", "/work/search"):
            func hit(_ c: [String: Any], _ ma: String, _ ten: String, slug: String) -> [String: Any] {
                let st = c["statusId"] as? Int ?? 1
                let ts: [Int: (String, String)] = [1: ("To Do", "TODO"), 2: ("In Progress", "IN_PROGRESS"), 3: ("In Review", "IN_PROGRESS"), 4: ("Done", "DONE")]
                let ty: [Int: (String, String, String)] = [2: ("STORY", "Story", "#16a34a"), 3: ("TASK", "Task", "#2563eb"), 4: ("BUG", "Bug", "#dc2626")]
                let t = ty[c["typeId"] as? Int ?? 3] ?? ("TASK", "Task", "#2563eb")
                let ai = c["assigneeId"] as? Int
                return ["id": c["id"]!, "key": "\(ma)-\(c["number"]!)", "number": c["number"]!, "title": c["title"]!, "priority": c["priority"]!,
                        "dueDate": c["dueDate"]!, "updatedAt": c["updatedAt"]!,
                        "status": ["id": st, "name": ts[st]!.0, "category": ts[st]!.1, "color": "#888"],
                        "type": ["id": 1, "key": t.0, "name": t.1, "icon": t.0.lowercased(), "color": t.2],
                        "assignee": ai.flatMap { id in [G.toi, G.linh, G.minh, G.an, G.scout].first { ($0["id"] as? Int) == id } } ?? NSNull(),
                        "project": ["id": 7, "key": ma, "name": ten, "archived": false], "workspace": ["slug": slug, "name": "Northwind Studio"]]
            }
            let ds = (G.the + G.tonDong).prefix(9).map { hit($0, "NW", "Mobile App Launch", slug: "northwind") }
            return ["items": ds, "total": ds.count, "offset": 0, "limit": 30, "hasMore": false, "projectsSearched": 3, "truncated": false, "ranked": true]
        default:
            return nil
        }
    }
}
#endif
