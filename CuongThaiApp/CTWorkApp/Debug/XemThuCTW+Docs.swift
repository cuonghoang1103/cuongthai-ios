#if DEBUG
import Foundation

// MARK: - Dữ liệu mẫu mô-đun Docs (sửa trang, lịch sử, bình luận, thùng rác, KB) —
// hình dạng theo `pages.service.ts` / `pageTrash.service.ts` / `kb.service.ts`.
// Nối vào `DuLieuGiaMoDun.boXuLy`. Trang 3 sửa được; trang 5 có @nhắc tên ⇒ app
// phải từ chối sửa (kiểm thử `DocsCTWTests`).

enum DuLieuGiaDocs {
    typealias G = DuLieuGia
    static let pr = "/work/projects/7"

    static func route(_ m: String, _ p: String, _ b: [String: Any]) -> Any? {
        guard p.hasPrefix(pr + "/pages") || p.hasPrefix(pr + "/trash/pages") || p == pr + "/kb"
                || p == pr + "/edit-lock" || p == pr + "/images" else { return nil }
        let doan = p.dropFirst(pr.count).split(separator: "/").map(String.init)   // ["pages","3","versions",…]
        switch (m, doan.count) {
        case (_, _) where p == pr + "/edit-lock": return ["locked": false, "since": NSNull()]
        case ("POST", _) where p == pr + "/images":
            return ["id": 88, "url": "/api/v1/work/projects/7/images/88", "width": 1280, "height": 720]
        case (_, _) where p == pr + "/kb": return kb
        case ("GET", _) where p == pr + "/trash/pages": return thungRac
        case ("POST", _) where p.hasPrefix(pr + "/trash/pages/"): return ["restored": 1, "number": 9, "toTopLevel": false]
        case ("GET", 1): return ["pages": dsTrang, "canEdit": true, "canManage": true, "approvalsOn": true, "stagesOn": false]
        case ("POST", 1):
            return chiTiet(so: 12, tieuDe: b["title"] as? String ?? "Untitled", noiDung: G.doc([]), trangThai: "DRAFT", phienBan: 1)
        default: break
        }
        guard doan.count >= 2, let so = Int(doan[1]) else { return nil }
        let con = doan.count > 2 ? doan[2] : ""
        switch (m, con) {
        case ("GET", ""): return so == 5 ? trangCoNhacTen : chiTiet(so: so, tieuDe: nil, noiDung: noiDung3, trangThai: "APPROVED", phienBan: 14)
        case ("PATCH", ""): return chiTiet(so: so, tieuDe: b["title"] as? String, noiDung: noiDung3, trangThai: b["status"] as? String ?? "APPROVED", phienBan: 15)
        case ("DELETE", ""): return ["deleted": 1]
        case ("GET", "markdown"):
            return ["filename": "NW-DOC-\(so).md", "markdown": so == 3 ? G.markdown : "# Page \(so)\n\nNotes."]
        case ("POST", "collab"): return ["flushed": true]
        case ("POST", "move"): return ["pages": dsTrang, "canEdit": true, "canManage": true]
        case ("GET", "comments"): return binhLuan
        case ("POST", "comments"):
            return ["id": 77, "bodyJson": b["bodyJson"] ?? NSNull(), "bodyText": "", "createdAt": G.iso(0), "editedAt": NSNull(),
                    "authorId": 1, "author": G.toi, "parentId": NSNull(), "anchor": NSNull(), "canDelete": true]
        case ("POST", "issues"), ("DELETE", "issues"): return theLienKet
        case ("POST", "request-approval"): return ["id": 41, "status": "PENDING"]
        case ("GET", "versions"):
            if doan.count > 3, doan[3] == "compare" { return soSanh }
            if doan.count > 3, let n = Int(doan[3]) {
                return ["id": 200 + n, "n": n, "kind": "EDIT", "title": "Release plan — v1.0", "note": NSNull(),
                        "createdAt": G.iso(-Double(9 - n)), "updatedAt": G.iso(-Double(9 - n)), "author": G.linh,
                        "contentJson": G.doc(["We ship the public beta at the end of Sprint 6.", "Draft milestones below — dates TBC."]),
                        "contentText": "We ship…"]
            }
            return phienBan
        case ("POST", "versions"): return chiTiet(so: so, tieuDe: nil, noiDung: noiDung3, trangThai: "DRAFT", phienBan: 16)
        default: return nil
        }
    }

    static var dsTrang: [[String: Any]] {
        G.trang.map { t in
            var t = t
            t["ownerId"] = (t["owner"] as? [String: Any])?["id"] ?? NSNull()
            t["visibility"] = (t["number"] as? Int) == 3 ? "CLIENT" : "INTERNAL"
            return t
        } + [["id": 9, "number": 9, "parentId": NSNull(), "title": "Old onboarding notes", "status": "ARCHIVED", "position": 9,
              "updatedAt": G.iso(-40), "owner": G.minh, "ownerId": 3, "visibility": "INTERNAL"]]
    }

    /// Thân trang 3 — chỉ những nút vòng Markdown giữ được.
    static let noiDung3: [String: Any] = [
        "type": "doc", "content": [
            ["type": "paragraph", "content": [["type": "text", "text": "We ship the "],
                                              ["type": "text", "text": "public beta", "marks": [["type": "bold"]]],
                                              ["type": "text", "text": " at the end of Sprint 6."]]],
            ["type": "heading", "attrs": ["level": 2], "content": [["type": "text", "text": "Milestones"]]],
            ["type": "table", "content": [
                ["type": "tableRow", "content": [
                    ["type": "tableHeader", "attrs": ["colspan": 1, "rowspan": 1, "colwidth": NSNull()],
                     "content": [["type": "paragraph", "content": [["type": "text", "text": "Milestone"]]]]]]]]],
            ["type": "taskList", "content": [
                ["type": "taskItem", "attrs": ["checked": true], "content": [["type": "paragraph", "content": [["type": "text", "text": "Sign in with Apple"]]]]]]],
        ],
    ]

    static func chiTiet(so: Int, tieuDe: String?, noiDung: [String: Any], trangThai: String, phienBan: Int) -> [String: Any] {
        [
            "id": so, "number": so, "parentId": 1, "title": tieuDe ?? "Release plan — v1.0", "status": trangThai, "visibility": "CLIENT",
            "stageId": NSNull(), "position": 1, "ownerId": 2, "templateKey": NSNull(), "createdAt": G.iso(-20), "updatedAt": G.iso(-1),
            "aiAssisted": false, "aiModel": NSNull(), "aiAssistedAt": NSNull(), "owner": G.linh, "lastEditedBy": G.linh,
            "contentJson": noiDung, "contentText": "We ship…", "version": phienBan, "lastEditedById": 2, "stage": NSNull(),
            "projectKey": "NW", "currentVersion": 9, "versionCount": 9, "issues": theLienKet,
            "ancestors": [["id": 1, "number": 1, "title": "Product"]],
            "children": [["id": 5, "number": 5, "title": "Store listing checklist", "status": "IN_REVIEW", "visibility": "INTERNAL"]],
            "approval": ["id": 41, "status": "APPROVED", "decidedAt": G.iso(-2), "createdAt": G.iso(-3), "contentChanged": false, "changedSinceRequest": false],
            "approvalsOn": true, "canEdit": true, "canManage": true, "canComment": true, "canRequestApproval": true,
        ]
    }

    static var trangCoNhacTen: [String: Any] {
        var t = chiTiet(so: 5, tieuDe: "Store listing checklist", noiDung: [
            "type": "doc", "content": [["type": "paragraph", "content": [
                ["type": "text", "text": "Ask "], ["type": "mention", "attrs": ["id": "2", "label": "Linh Tran"]],
                ["type": "text", "text": " for the final copy."]]]],
        ], trangThai: "IN_REVIEW", phienBan: 3)
        t["approval"] = NSNull()
        return t
    }

    static let theLienKet: [[String: Any]] = [
        ["linkId": 5, "linkedAt": G.iso(-4), "id": 112, "number": 12, "title": "Push notifications open the right issue", "resolvedAt": NSNull(),
         "status": ["name": "In Progress", "category": "IN_PROGRESS"], "type": ["key": "STORY", "name": "Story", "icon": "story", "color": "#16a34a"], "key": "NW-12"],
        ["linkId": 6, "linkedAt": G.iso(-3), "id": 119, "number": 19, "title": "iPad split view layout", "resolvedAt": G.iso(-1),
         "status": ["name": "Done", "category": "DONE"], "type": ["key": "STORY", "name": "Story", "icon": "story", "color": "#16a34a"], "key": "NW-19"],
    ]

    static let binhLuan: [[String: Any]] = [
        ["id": 31, "bodyJson": G.doc(["Can we move the beta date one day earlier? QA is done."]), "bodyText": "Can we move the beta date one day earlier? QA is done.",
         "createdAt": G.iso(-1, gio: -3), "editedAt": NSNull(), "authorId": 3, "author": G.minh, "parentId": NSNull(), "anchor": NSNull(), "canDelete": false],
        ["id": 32, "bodyJson": G.doc(["Summary of open risks: screenshots and review notes are still pending."]), "bodyText": "Summary of open risks…",
         "createdAt": G.iso(-1, gio: -1), "editedAt": NSNull(), "authorId": 9, "author": G.scout, "parentId": NSNull(), "anchor": NSNull(), "canDelete": false],
    ]

    static var phienBan: [[String: Any]] {
        func v(_ n: Int, _ k: String, _ a: [String: Any], _ note: String?) -> [String: Any] {
            let t = G.iso(-Double(10 - n))
            return ["id": 200 + n, "n": n, "kind": k, "title": "Release plan — v1.0", "note": note ?? NSNull(),
                    "createdAt": t, "updatedAt": t, "author": a, "chars": 1200 + n * 37]
        }
        return [v(9, "EDIT", G.linh, nil), v(8, "MANUAL", G.toi, "Before store review"), v(7, "EDIT", G.scout, nil),
                v(6, "RESTORE", G.linh, nil), v(2, "CREATE", G.linh, nil)]
    }

    static let soSanh: [String: Any] = [
        "from": ["n": 7, "title": "Release plan — v1.0", "createdAt": G.iso(-3)],
        "to": ["title": "Release plan — v1.0", "current": true],
        "lines": [["op": "eq", "text": "# Release plan — v1.0"], ["op": "eq", "text": ""],
                  ["op": "del", "text": "We ship the beta at the end of Sprint 7."],
                  ["op": "add", "text": "We ship the **public beta** at the end of Sprint 6."],
                  ["op": "eq", "text": "## Milestones"], ["op": "add", "text": "| App Store submission | An | Nov 7 |"]],
        "added": 2, "removed": 1,
    ]

    static let thungRac: [String: Any] = [
        "canPurge": true,
        "items": [["id": 11, "number": 11, "title": "Draft: pricing FAQ", "visibility": "INTERNAL", "deletedAt": G.iso(-2), "childCount": 1,
                   "deletedBy": ["id": 2, "name": "Linh Tran"], "owner": G.linh, "restoresTo": ["number": 1, "title": "Product"], "canRestore": true]],
    ]

    static let kb: [String: Any] = [
        "canEdit": true,
        "categories": [["id": 1, "name": "Getting started", "description": NSNull(), "position": 0, "articles": 2],
                       ["id": 2, "name": "Billing", "description": NSNull(), "position": 1, "articles": 1]],
        "articles": [
            ["id": 4, "title": "Reset your password", "pageNumber": 3, "category": ["id": 1, "name": "Getting started"], "excerpt": "Use “Forgot password” on the sign-in screen…",
             "updatedAt": G.iso(-2), "audience": "CLIENT", "published": true, "keywords": NSNull(), "pageVisibility": "CLIENT", "pageStatus": "APPROVED",
             "views": 128, "helpful": 30, "notHelpful": 4, "deflected": 12, "helpfulPercent": 88, "hiddenFromClients": false],
            ["id": 5, "title": "Invite your team", "pageNumber": 6, "category": ["id": 1, "name": "Getting started"], "excerpt": "Workspace admins can share an invite link…",
             "updatedAt": G.iso(-6), "audience": "INTERNAL", "published": false, "keywords": NSNull(), "pageVisibility": "INTERNAL", "pageStatus": "DRAFT",
             "views": 9, "helpful": 1, "notHelpful": 0, "deflected": 0, "helpfulPercent": NSNull(), "hiddenFromClients": true],
        ],
        "pages": [["number": 4, "title": "Push notification architecture", "visibility": "INTERNAL"]],
        "totals": ["articles": 2, "forClients": 1, "views": 137, "deflected": 12, "helpful": 31, "notHelpful": 4],
    ]
}
#endif
