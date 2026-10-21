#if DEBUG
import Foundation

// MARK: - Dữ liệu mẫu cho màn "Tìm mọi thứ" (⌘K) — `CT_XEM_MAN=tim` (+ `CT_XEM_TIM=<chữ>`)
//
// Hình dạng theo backend: `globalSearch.service.ts` (`/work/search` — items có `key`, `status`, `type`, `assignee`,
// `project`, `workspace`) và `pages.service.ts › searchDocsGlobal` (`/work/search/docs`). Hỏi TRƯỚC mảng B: tuyến
// `/work/search` của mảng B trả cùng 9 thẻ với MỌI chữ — ở đây lọc theo chữ (bỏ dấu, như máy chủ `foldVi`) và theo
// `project = KEY` để thấy đúng hai nhóm "trong dự án" / "dự án khác".
enum DuLieuGiaTimKiem {
    static func route(_ m: String, _ p: String, _ b: [String: Any]) -> Any? {
        guard m == "GET" else { return nil }
        switch p {
        case "/work/search":
            let q = CTWBoDau.chuan((b["q"] as? String) ?? "")
            guard !q.isEmpty else { return nil }   // không chữ (trang Search của My Work với bộ lọc) ⇒ để mảng B trả
            let goc = (DuLieuGiaDotB.route("GET", "/work/search", [:]) as? [String: Any])?["items"] as? [[String: Any]] ?? []
            var ds = goc + khac
            let jql = ((b["jql"] as? String) ?? "").lowercased()
            if let r = jql.range(of: "project = ") {
                let ma = jql[r.upperBound...].split(separator: " ").first.map { $0.replacingOccurrences(of: "\"", with: "").uppercased() } ?? ""
                ds = ds.filter { (($0["project"] as? [String: Any])?["key"] as? String)?.uppercased() == ma }
            }
            let maGo = CTWMaTheGo.tach((b["q"] as? String) ?? "")
            ds = ds.filter { t in
                let key = (t["key"] as? String ?? "").uppercased()
                if let g = maGo, let n = t["number"] as? Int, n == g.so, g.maDuAn == nil || key.hasPrefix(g.maDuAn! + "-") { return true }
                return CTWBoDau.chuan(t["title"] as? String ?? "").contains(q) || CTWBoDau.chuan(key).contains(q)
            }
            let lim = Int("\(b["limit"] ?? 10)") ?? 10
            return ["items": Array(ds.prefix(lim)), "total": ds.count, "offset": 0, "limit": lim, "hasMore": ds.count > lim,
                    "projectsSearched": 3, "truncated": false, "ranked": true]
        case "/work/search/docs":
            let q = CTWBoDau.chuan((b["q"] as? String) ?? "")
            return trang.filter { CTWBoDau.chuan(($0["title"] as? String ?? "") + " " + ($0["snippet"] as? String ?? "")).contains(q) }
        default:
            return nil
        }
    }

    /// Thẻ ở dự án KHÁC (WEB, SWP) — để thấy nhóm "dự án khác" trong kết quả.
    private static let khac: [[String: Any]] = [
        the(301, "WEB", 18, "Báo cáo lượt truy cập trang chủ theo tuần", "In Progress", "IN_PROGRESS", "Task", "#2563eb",
            ["id": 3, "username": "minh", "displayName": "Minh Tran"], slug: "northwind", tenDA: "Marketing Website"),
        the(302, "SWP", 7, "Đặt lịch khám — chọn bác sĩ và khung giờ", "To Do", "TODO", "Story", "#16a34a",
            ["id": 2, "username": "linh", "displayName": "Linh Pham"], slug: "swp391-g4", tenDA: "Clinic Booking System"),
        the(303, "SWP", 12, "Lỗi đăng nhập bằng Google trên Safari", "In Review", "IN_PROGRESS", "Bug", "#dc2626",
            nil, slug: "swp391-g4", tenDA: "Clinic Booking System"),
        the(304, "WEB", 4, "Push notification opt-in banner", "Done", "DONE", "Story", "#16a34a",
            ["id": 1, "username": "alex", "displayName": "Alex Nguyen"], slug: "northwind", tenDA: "Marketing Website"),
    ]

    private static func the(_ id: Int, _ ma: String, _ so: Int, _ tieuDe: String, _ st: String, _ nhom: String, _ loai: String,
                            _ mau: String, _ nguoi: [String: Any]?, slug: String, tenDA: String) -> [String: Any] {
        ["id": id, "key": "\(ma)-\(so)", "number": so, "title": tieuDe, "priority": 3, "dueDate": NSNull(), "updatedAt": "2026-10-20T08:00:00.000Z",
         "status": ["id": 1, "name": st, "category": nhom, "color": "#888"],
         "type": ["id": 1, "key": loai.uppercased(), "name": loai, "icon": loai.lowercased(), "color": mau],
         "assignee": nguoi ?? NSNull(),
         "project": ["id": ma == "WEB" ? 8 : 11, "key": ma, "name": tenDA, "archived": false],
         "workspace": ["slug": slug, "name": slug == "northwind" ? "Northwind Studio" : "SWP391 · Group 4"],
         "url": "/work/\(slug)/\(ma)/issue/\(so)", "match": "title"]
    }

    private static let trang: [[String: Any]] = [
        ["id": 1, "projectId": 7, "number": 3, "title": "Release plan — v1.0", "status": "APPROVED", "updatedAt": "2026-10-19T08:00:00.000Z",
         "snippet": "Push notifications ship in sprint 3; App Store review notes…",
         "project": ["id": 7, "key": "NW", "name": "Mobile App Launch", "workspaceSlug": "northwind"]],
        ["id": 2, "projectId": 7, "number": 5, "title": "Báo cáo tuần 6 — nhóm Mobile", "status": "DRAFT", "updatedAt": "2026-10-18T08:00:00.000Z",
         "snippet": "Tiến độ: 14/20 thẻ xong, rủi ro push notification trên iOS 26…",
         "project": ["id": 7, "key": "NW", "name": "Mobile App Launch", "workspaceSlug": "northwind"]],
        ["id": 3, "projectId": 11, "number": 2, "title": "SRS — Clinic Booking", "status": "IN_REVIEW", "updatedAt": "2026-10-17T08:00:00.000Z",
         "snippet": "Use case UC-04 Đặt lịch khám, business rule BR-12 push nhắc lịch…",
         "project": ["id": 11, "key": "SWP", "name": "Clinic Booking System", "workspaceSlug": "swp391-g4"]],
    ]

    /// "Thẻ xem gần đây" của màn thử (bản DEBUG không ghi vùng chung App Group).
    static var theGanDay: [TheGanDayCTW] {
        [
            TheGanDayCTW(pid: 7, slug: "northwind", maDuAn: "NW", so: 12, tieuDe: "Push notifications for comments and mentions", xemLuc: Date()),
            TheGanDayCTW(pid: 7, slug: "northwind", maDuAn: "NW", so: 24, tieuDe: "Global search across workspaces", xemLuc: Date()),
            TheGanDayCTW(pid: 11, slug: "swp391-g4", maDuAn: "SWP", so: 7, tieuDe: "Đặt lịch khám — chọn bác sĩ và khung giờ", xemLuc: Date()),
        ]
    }
}
#endif
