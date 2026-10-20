#if DEBUG
import Foundation

// MARK: - Dữ liệu mẫu: SỬA THẺ (mảng A, 20/10/2026) — chỉ #if DEBUG (CLAUDE.md A6)
//
// Hình dạng đối chiếu backend: `issues.service.ts → getIssueDetail` (CARD_SELECT + pickDetail: fixVersionId,
// teamId, stageId, componentIds, originalEstimateMin/remainingEstimateMin/timeSpentMin, flagReason),
// `getProject` (versions, components, customFields, settings.estimation), `custom.service.ts` (giá trị theo kiểu),
// `resources.service.ts → listWebLinks`, `pages.service.ts → issuePages`, `ai.service.ts → similarIssues`,
// `issueTemplates`. PATCH/PUT được GHI NHỚ trong lượt chạy để màn hiện kết quả sau khi sửa.
// Nhật ký giờ, bộ phận, giai đoạn, phiên bản: dữ liệu mẫu của B2/B3 (đã có).
//
// Màn thử (mở thẻ NW-12): `the:suamota` (soạn mô tả) · `the:nhan` (chọn nhãn) · `the:tuychinh` (cuộn tới trường
// tuỳ chỉnh) · `the:thecon` (thêm nhanh sub-task) · `the:lienket` (tab Links + tấm Link issue) · `the:ghigio`
// (nút ghi giờ) · `the:nhatky` (tab Work log) · `the:taothe` (hộp tạo thẻ) · `the:chiase` · `the:chuyen`.

enum DuLieuGiaSuaThe {
    private static let pr = "/work/projects/7"
    private static let khoa = NSLock()
    nonisolated(unsafe) private static var daSua: [Int: [String: Any]] = [:]
    nonisolated(unsafe) private static var giaTriTruong: [Int: [String: Any]] = [12: giaTriMau]
    nonisolated(unsafe) private static var lienKetWeb: [[String: Any]] = [
        ["id": 1, "resourceId": NSNull(), "title": "APNs payload reference", "url": "https://developer.apple.com/documentation/usernotifications",
         "kind": "LINK", "faviconUrl": NSNull(), "inResources": false, "createdAt": DuLieuGia.iso(-3), "canDelete": true],
    ]

    static func route(_ m: String, _ p: String, _ b: [String: Any]) -> Any? {
        guard p.hasPrefix(pr) else { return nil }
        if p == pr, m == "GET" { return cauHinh }
        let phan = p.split(separator: "/").map(String.init)   // work, projects, 7, issues, 12, …
        if phan.count >= 5, phan[3] == "issues", let so = Int(phan[4]) {
            let duoi = phan.dropFirst(5).joined(separator: "/")
            switch (m, duoi) {
            case ("GET", ""): return chiTiet(so)
            case ("PATCH", ""):
                if b["title"] as? String == "#409" { return LoiGiaCTW(trangThai: 409, ma: "CONFLICT", thongDiep: "Someone else just changed this issue") }
                khoa.lock()
                var d = daSua[so] ?? [:]
                for (k, v) in b where k != "version" { d[k] = v }
                d["version"] = ((d["version"] as? Int) ?? 3) + 1
                daSua[so] = d
                khoa.unlock()
                return chiTiet(so)
            case ("DELETE", ""): return ["deleted": true]
            case ("POST", "clone"): return DuLieuGia.chiTiet(so: 41, tieuDe: "Copy of " + ((chiTiet(so)["title"] as? String) ?? ""))
            case ("POST", "move-project"):
                return ["issueId": 100 + so, "projectId": b["targetProjectId"] ?? 8, "key": "WEB-31", "number": 31,
                        "subtasks": [Any](), "dropped": ["label ios", "Fix version 1.0"], "canEditTarget": true]
            case ("GET", "custom-values"):
                khoa.lock(); defer { khoa.unlock() }
                return giaTriTruong[so] ?? [String: Any]()
            case ("PUT", "custom-values"):
                khoa.lock(); defer { khoa.unlock() }
                var v = giaTriTruong[so] ?? [:]
                for (k, x) in (b["values"] as? [String: Any]) ?? [:] { if x is NSNull { v.removeValue(forKey: k) } else { v[k] = x } }
                giaTriTruong[so] = v
                return v
            case ("POST", "links"): return ["id": 9, "type": b["type"] ?? "RELATES"]
            case ("PUT", "flag"):
                khoa.lock(); daSua[so, default: [:]]["flaggedAt"] = DuLieuGia.iso(0); daSua[so, default: [:]]["flagReason"] = b["reason"]; khoa.unlock()
                return ["number": so, "flaggedAt": DuLieuGia.iso(0), "flagReason": b["reason"] ?? ""]
            case ("DELETE", "flag"):
                khoa.lock(); daSua[so, default: [:]]["flaggedAt"] = NSNull(); daSua[so, default: [:]]["flagReason"] = NSNull(); khoa.unlock()
                return ["number": so, "flaggedAt": NSNull()]
            case ("GET", "web-links"):
                khoa.lock(); defer { khoa.unlock() }
                return ["items": lienKetWeb, "canEdit": true]
            case ("POST", "web-links"):
                khoa.lock(); defer { khoa.unlock() }
                lienKetWeb.append(["id": lienKetWeb.count + 10, "resourceId": NSNull(), "title": b["title"] ?? NSNull(), "url": b["url"] ?? "",
                                   "kind": "LINK", "faviconUrl": NSNull(), "inResources": false, "createdAt": DuLieuGia.iso(0), "canDelete": true])
                return ["items": lienKetWeb, "canEdit": true]
            case ("GET", "pages"):
                return ["pages": [["linkId": 1, "id": 3, "number": 3, "title": "Release plan — v1.0", "status": "APPROVED",
                                   "visibility": "TEAM", "updatedAt": DuLieuGia.iso(-1)]], "canEdit": true]
            default:
                if m == "DELETE", duoi.hasPrefix("links/") { return ["removed": true] }
                if m == "DELETE", duoi.hasPrefix("web-links/") {
                    let id = Int(duoi.split(separator: "/").last ?? "") ?? 0
                    khoa.lock(); lienKetWeb.removeAll { ($0["id"] as? Int) == id }; let ds = lienKetWeb; khoa.unlock()
                    return ["items": ds, "canEdit": true]
                }
                return nil
            }
        }
        if p == pr + "/issue-templates" { return mauMoTa }
        if p == pr + "/similar" {
            let t = ((b["title"] as? String) ?? "").lowercased()
            return t.contains("notif") ? [["number": 12, "title": "Push notifications open the right issue", "score": 0.71, "resolved": false]] : [Any]()
        }
        if p == pr + "/issues", m == "GET", b["parent"] == nil, b["type"] as? String == "1" {
            return ["items": [epic(5, "Public beta"), epic(6, "App Store launch")], "total": 2, "nextCursor": NSNull()]
        }
        return nil
    }

    private static func epic(_ so: Int, _ t: String) -> [String: Any] {
        DuLieuGia.card(so, t, type: 1, st: 2, pr: 2, ai: 2, sp: nil, han: nil, nhan: [], sprint: nil)
    }

    static func chiTiet(_ so: Int) -> [String: Any] {
        var c = DuLieuGia.chiTiet(so: so, tieuDe: nil)
        c["version"] = 3
        c["startDate"] = so == 12 ? DuLieuGia.ngay(-5) : NSNull()
        c["fixVersionId"] = so == 12 ? 2 : NSNull()
        c["teamId"] = so == 12 ? 1 : NSNull()
        c["stageId"] = so == 12 ? 3 : NSNull()
        c["componentIds"] = so == 12 ? [1] : [Int]()
        c["originalEstimateMin"] = so == 12 ? 480 : NSNull()
        c["remainingEstimateMin"] = so == 12 ? 210 : NSNull()
        c["timeSpentMin"] = so == 12 ? 270 : 0
        c["flagReason"] = NSNull()
        c["canDelete"] = true
        if so == 12 {
            c["parentId"] = 105
            c["parent"] = ["id": 105, "number": 5, "title": "Public beta", "typeId": 1, "statusId": 2]
        }
        khoa.lock()
        let sua = daSua[so] ?? [:]
        khoa.unlock()
        for (k, v) in sua { c[k] = v }
        if let a = sua["assigneeId"] {
            c["assignee"] = (a as? Int).flatMap { id in [DuLieuGia.toi, DuLieuGia.linh, DuLieuGia.minh, DuLieuGia.an, DuLieuGia.sara, DuLieuGia.scout].first { ($0["id"] as? Int) == id } } ?? NSNull()
        }
        if let pid = sua["parentId"] {
            if let id = pid as? Int, id == 106 { c["parent"] = ["id": 106, "number": 6, "title": "App Store launch", "typeId": 1, "statusId": 2] }
            else if pid is NSNull { c["parent"] = NSNull() }
        }
        return c
    }

    static let giaTriMau: [String: Any] = [
        "1": "ios", "2": 420, "3": "https://www.figma.com/file/notification-flow", "4": true,
        "5": ["iphone15", "iphone17"], "6": 4, "8": DuLieuGia.ngay(8),
    ]

    static var cauHinh: [String: Any] {
        var c = DuLieuGia.cauHinh
        c["settings"] = ["estimation": "POINTS"]
        c["editLocked"] = false
        c["modules"] = ["teams": true, "stages": true, "docs": true, "resources": true]
        c["versions"] = [["id": 1, "name": "1.0 Beta", "status": "RELEASED"], ["id": 2, "name": "1.0", "status": "UNRELEASED"],
                         ["id": 3, "name": "1.1", "status": "UNRELEASED"]]
        c["components"] = [["id": 1, "name": "Notifications", "description": NSNull(), "leadId": 1],
                           ["id": 2, "name": "Chat", "description": NSNull(), "leadId": 3],
                           ["id": 3, "name": "Offline", "description": NSNull(), "leadId": NSNull()]]
        c["customFields"] = [
            truong(1, "Platform", "SELECT", 0, tuyChon: [("ios", "iOS", "#2563eb"), ("android", "Android", "#16a34a"), ("web", "Web", "#ea580c")]),
            truong(2, "Customer impact", "NUMBER", 1),
            truong(3, "Spec link", "URL", 2),
            truong(4, "Needs QA sign-off", "CHECKBOX", 3),
            truong(5, "Test devices", "MULTISELECT", 4, tuyChon: [("iphone15", "iPhone 15", "#7c3aed"), ("iphone17", "iPhone 17", "#0891b2"), ("ipad", "iPad Air", "#db2777")]),
            truong(6, "QA owner", "USER", 5),
            truong(7, "Release note", "TEXT", 6, loai: ["STORY", "BUG"]),
            truong(8, "Target date", "DATE", 7),
            truong(9, "Root cause", "TEXT", 8, loai: ["BUG"], batBuoc: true),
        ]
        return c
    }

    private static func truong(_ id: Int, _ ten: String, _ kieu: String, _ vt: Int, tuyChon: [(String, String, String)] = [],
                               loai: [String]? = nil, batBuoc: Bool = false) -> [String: Any] {
        ["id": id, "name": ten, "kind": kieu, "position": vt, "required": batBuoc, "typeKeys": loai ?? NSNull(),
         "options": tuyChon.map { ["id": $0.0, "label": $0.1, "color": $0.2] }]
    }

    static let mauMoTa: [[String: Any]] = [
        ["typeId": 2, "typeKey": "STORY", "typeName": "Story", "name": "User story", "isDefault": true,
         "doc": ["type": "doc", "content": [
            ["type": "paragraph", "content": [["type": "text", "text": "As a "], ["type": "text", "text": "<role>", "marks": [["type": "bold"]]],
                                              ["type": "text", "text": ", I want <goal> so that <benefit>."]]],
            ["type": "heading", "attrs": ["level": 3], "content": [["type": "text", "text": "Acceptance criteria"]]],
            ["type": "taskList", "content": [["type": "taskItem", "attrs": ["checked": false], "content": [["type": "paragraph"]]]]],
         ]]],
        ["typeId": 4, "typeKey": "BUG", "typeName": "Bug", "name": "Bug report", "isDefault": true,
         "doc": ["type": "doc", "content": [
            ["type": "heading", "attrs": ["level": 3], "content": [["type": "text", "text": "Steps to reproduce"]]],
            ["type": "orderedList", "attrs": ["start": 1], "content": [["type": "listItem", "content": [["type": "paragraph"]]]]],
            ["type": "heading", "attrs": ["level": 3], "content": [["type": "text", "text": "Expected"]]],
            ["type": "heading", "attrs": ["level": 3], "content": [["type": "text", "text": "Actual"]]],
         ]]],
        ["typeId": 3, "typeKey": "TASK", "typeName": "Task", "name": "Task", "isDefault": true, "doc": NSNull()],
    ]
}
#endif
