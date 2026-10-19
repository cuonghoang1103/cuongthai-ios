#if DEBUG
import Foundation

// MARK: - Dữ liệu mẫu: trang Code + trợ lý AI (19/10/2026) — CHỈ bản DEBUG
//
// Hình dạng đối chiếu api-backend:
//   · `src/services/work/code.service.ts` (status/overview/activity/branches/pulls) + `gitSource.ts` (tree/blob/commits/commit)
//   · `src/services/work/aiThreads.service.ts` (serializeMessage, listThreads, getThread) + `ai.service.ts → chat`
// Màn thử: `mod:code` · `mod:code/branches` · `mod:code/pulls` · `mod:code/source` · `mod:ai` · `mod:ai/thread` · `mod:ai/loi`
// · `mod:ai/dongy`. Câu hỏi AI chứa "#fail" ⇒ máy chủ giả LƯU câu hỏi kèm lỗi rồi trả 502 `WORK_AI_BAD_OUTPUT`
// (đúng như `ai.service.ts`: markFailed rồi ném) ⇒ kiểm nút "Ask again".
// ⚠️ Cả tệp trong `#if DEBUG` (CLAUDE.md A6).

/// Tuyến giả trả lỗi có mã (MayChuGia gửi phong bì `{success:false, message, code}` với mã HTTP này).
struct LoiGiaCTW {
    var trangThai: Int
    var ma: String
    var thongDiep: String
}

enum DuLieuGiaCode {
    typealias G = DuLieuGia
    private static let pr = "/work/projects/7"

    static func route(_ m: String, _ p: String, _ b: [String: Any]) -> Any? {
        guard p.hasPrefix(pr + "/code") || p.hasPrefix(pr + "/ai") || p == "/work/ai/quota" else { return nil }
        switch (m, p) {
        case ("GET", pr + "/code/status"): return ["connected": true, "providers": ["GITHUB"]]
        case ("GET", pr + "/code/overview"): return tongQuan
        case ("GET", pr + "/code/activity"): return hoatDong
        case ("GET", pr + "/code/branches"): return ["items": nhanh, "issues": the]
        case ("GET", pr + "/code/pulls"): return ["items": dsPR, "counts": ["open": 2, "merged": 2, "closed": 1], "issues": the]
        case ("GET", pr + "/code/source/meta"):
            return ["provider": "GITHUB", "repo": "northwind/mobile-app", "hasToken": true, "defaultBranch": "main", "private": true,
                    "description": "Northwind mobile app — SwiftUI client for iPhone and iPad", "webUrl": "https://github.com/northwind/mobile-app"]
        case ("GET", pr + "/code/source/refs"):
            return [["name": "main", "sha": "a1b2c3d"], ["name": "feature/NW-12-push-routing", "sha": "9f8e7d6"], ["name": "fix/NW-14-heic", "sha": "1a2b3c4"]]
        case ("GET", pr + "/code/source/tree"): return cay(b)
        case ("GET", pr + "/code/source/blob"): return tep(b)
        case ("GET", pr + "/code/source/commits"): return ["ref": "main", "items": lichSu]
        case ("GET", "/work/ai/quota"): return ["pro": false, "used": 3, "limit": NSNull(), "remaining": NSNull(), "available": true]
        case ("GET", pr + "/ai/threads"): return AIGia.ds()
        case ("POST", pr + "/ai/threads"): return AIGia.tao(b)
        case ("POST", pr + "/ai/chat"): return AIGia.hoi(b)
        default: break
        }
        if m == "GET", p.hasPrefix(pr + "/code/source/commit/") { return chiTietCommit }
        if m == "GET", p.hasPrefix(pr + "/code/issues/") { return ["connected": true, "codeHref": "/work/northwind/NW/code", "counts": ["prs": 1, "branches": 1, "commits": 3], "groups": [Any]()] }
        if p.hasPrefix(pr + "/ai/threads/"), let id = Int(p.split(separator: "/").last ?? "") {
            if m == "DELETE" { AIGia.xoa(id); return ["ok": true] }
            return AIGia.mot(id) ?? LoiGiaCTW(trangThai: 404, ma: "NOT_FOUND", thongDiep: "Conversation not found")
        }
        if m == "POST", p.hasPrefix(pr + "/ai/messages/"), p.hasSuffix("/retry") {
            let id = Int(p.split(separator: "/").dropLast().last ?? "") ?? 0
            return AIGia.hoiLai(id)
        }
        if p.hasPrefix(pr + "/ai/messages/"), p.contains("/actions/") {
            let phan = p.split(separator: "/")
            let mid = Int(phan[phan.count - (m == "POST" ? 4 : 3)]) ?? 0
            let idx = Int(phan[phan.count - (m == "POST" ? 2 : 1)]) ?? 0
            return AIGia.datDeXuat(mid, idx, trangThai: m == "POST" ? "done" : "dismissed")
        }
        return nil
    }

    // MARK: Code

    static let the: [String: Any] = [
        "12": ["number": 12, "key": "NW-12", "title": "Push notifications open the right issue", "status": ["name": "In Progress", "category": "IN_PROGRESS"], "assigneeId": 1],
        "14": ["number": 14, "key": "NW-14", "title": "Crash when attaching a HEIC photo on iOS 17", "status": ["name": "To Do", "category": "TODO"], "assigneeId": 3],
        "19": ["number": 19, "key": "NW-19", "title": "iPad split view layout", "status": ["name": "Done", "category": "DONE"], "assigneeId": 1],
        "17": ["number": 17, "key": "NW-17", "title": "Offline cache for My Work", "status": ["name": "To Do", "category": "TODO"], "assigneeId": 1],
    ]

    private static func ai(_ u: [String: Any]?, _ label: String) -> [String: Any] { ["user": u ?? NSNull(), "label": label] }

    static var tongQuan: [String: Any] {
        let dem = [2, 0, 1, 3, 5, 2, 0, 0, 4, 6, 3, 2, 1, 0, 0, 3, 7, 5, 4, 2, 0, 1, 6, 8, 5, 3, 0, 2, 4, 6]
        let ngay: [[String: Any]] = dem.enumerated().map { i, c in ["day": G.ngay(Double(i - 29)), "commits": c, "pushes": max(0, c / 2)] }
        return [
            "connected": true,
            "providers": [["provider": "GITHUB", "repo": "northwind/mobile-app", "webUrl": "https://github.com/northwind/mobile-app",
                           "lastEventAt": G.iso(-0.05), "hasReadToken": true]],
            "canManage": true, "canViewSource": true, "trackedSince": G.iso(-60),
            "stats": ["commits7d": 28, "pushes7d": 11, "openPrs": 2,
                      "contributors30d": [["key": "u:1", "user": G.toi, "label": "alex"], ["key": "u:3", "user": G.minh, "label": "minhp"],
                                          ["key": "u:2", "user": G.linh, "label": "linhtran"], ["key": "g:ci-bot", "user": NSNull(), "label": "ci-bot"]],
                      "daily": ngay],
        ]
    }

    private static func cm(_ sha: String, _ msg: String, _ u: [String: Any], _ login: String, _ so: [Int], gio: Double) -> [String: Any] {
        ["sha": sha, "message": msg, "url": "https://github.com/northwind/mobile-app/commit/\(sha)", "at": G.iso(-gio / 24),
         "author": ai(u, login), "issueNumbers": so, "files": 3]
    }

    static var hoatDong: [String: Any] {
        let items: [[String: Any]] = [
            ["id": "e91", "kind": "PUSH", "provider": "GITHUB", "repo": "northwind/mobile-app", "ref": "feature/NW-12-push-routing",
             "actor": ai(G.toi, "alex"), "title": NSNull(), "url": "https://github.com/northwind/mobile-app/compare/a1...9f", "prNumber": NSNull(),
             "commitCount": 3, "commits": [
                cm("9f8e7d6c5b4a", "NW-12 Route cold-start taps through DinhTuyen", G.toi, "alex", [12], gio: 1.2),
                cm("8e7d6c5b4a39", "NW-12 Handle chat deep links with ?c= and ?m=", G.toi, "alex", [12], gio: 1.4),
                cm("7d6c5b4a3928", "Add unit tests for path parsing", G.toi, "alex", [], gio: 1.5)],
             "data": [String: Any](), "issueNumbers": [12], "occurredAt": G.iso(-0.05)],
            ["id": "e90", "kind": "PR_OPENED", "provider": "GITHUB", "repo": "northwind/mobile-app", "ref": "feature/NW-12-push-routing",
             "actor": ai(G.toi, "alex"), "title": "NW-12: open the right issue from a notification", "url": "https://github.com/northwind/mobile-app/pull/48",
             "prNumber": 48, "commitCount": 0, "commits": [Any](), "data": [String: Any](), "issueNumbers": [12], "occurredAt": G.iso(-0.08)],
            ["id": "e89", "kind": "REVIEW_REQUESTED", "provider": "GITHUB", "repo": "northwind/mobile-app", "ref": "feature/NW-12-push-routing",
             "actor": ai(G.toi, "alex"), "title": "NW-12: open the right issue from a notification", "url": "https://github.com/northwind/mobile-app/pull/48",
             "prNumber": 48, "commitCount": 0, "commits": [Any](), "data": ["reviewer": "linhtran"], "issueNumbers": [12], "occurredAt": G.iso(-0.09)],
            ["id": "e88", "kind": "PR_MERGED", "provider": "GITHUB", "repo": "northwind/mobile-app", "ref": "feature/NW-19-ipad-split",
             "actor": ai(G.linh, "linhtran"), "title": "NW-19: iPad split view with grouped sidebar", "url": "https://github.com/northwind/mobile-app/pull/46",
             "prNumber": 46, "commitCount": 0, "commits": [Any](), "data": [String: Any](), "issueNumbers": [19], "occurredAt": G.iso(-0.4)],
            ["id": "e87", "kind": "BRANCH_CREATED", "provider": "GITHUB", "repo": "northwind/mobile-app", "ref": "fix/NW-14-heic",
             "actor": ai(G.minh, "minhp"), "title": "fix/NW-14-heic", "url": "https://github.com/northwind/mobile-app/tree/fix/NW-14-heic",
             "prNumber": NSNull(), "commitCount": 0, "commits": [Any](), "data": [String: Any](), "issueNumbers": [14], "occurredAt": G.iso(-0.7)],
            ["id": "e86", "kind": "PUSH", "provider": "GITHUB", "repo": "northwind/mobile-app", "ref": "main",
             "actor": ai(nil, "ci-bot"), "title": NSNull(), "url": NSNull(), "prNumber": NSNull(), "commitCount": 1,
             "commits": [cm("6c5b4a392817", "chore: bump build number to 2", G.linh, "ci-bot", [], gio: 26)],
             "data": [String: Any](), "issueNumbers": [Int](), "occurredAt": G.iso(-1.1)],
        ]
        return ["items": items, "nextBefore": G.iso(-1.2), "issues": the,
                "filters": ["actors": [["value": "u:1", "label": "Alex Morgan", "user": G.toi]], "branches": [["name": "main", "deleted": false]]]]
    }

    static var nhanh: [[String: Any]] {
        [
            ["name": "feature/NW-12-push-routing", "provider": "GITHUB", "headSha": "9f8e7d6", "lastCommit": ["title": "NW-12 Route cold-start taps through DinhTuyen", "url": NSNull()],
             "lastAuthor": ai(G.toi, "alex"), "lastPushAt": G.iso(-0.05), "commitCount": 7, "deleted": false, "deletedAt": NSNull(), "issueNumbers": [12],
             "pr": ["number": 48, "title": "NW-12: open the right issue from a notification", "url": "https://github.com/northwind/mobile-app/pull/48", "state": "open"], "legacy": false],
            ["name": "fix/NW-14-heic", "provider": "GITHUB", "headSha": "1a2b3c4", "lastCommit": ["title": "Convert HEIC to JPEG before upload", "url": NSNull()],
             "lastAuthor": ai(G.minh, "minhp"), "lastPushAt": G.iso(-0.7), "commitCount": 2, "deleted": false, "deletedAt": NSNull(), "issueNumbers": [14],
             "pr": NSNull(), "legacy": false],
            ["name": "main", "provider": "GITHUB", "headSha": "a1b2c3d", "lastCommit": ["title": "Merge pull request #46 from feature/NW-19-ipad-split", "url": NSNull()],
             "lastAuthor": ai(G.linh, "linhtran"), "lastPushAt": G.iso(-0.4), "commitCount": 214, "deleted": false, "deletedAt": NSNull(), "issueNumbers": [Int](),
             "pr": NSNull(), "legacy": false],
            ["name": "feature/NW-19-ipad-split", "provider": "GITHUB", "headSha": NSNull(), "lastCommit": ["title": "Sidebar groups", "url": NSNull()],
             "lastAuthor": ai(G.linh, "linhtran"), "lastPushAt": G.iso(-0.5), "commitCount": 9, "deleted": true, "deletedAt": G.iso(-0.4), "issueNumbers": [19],
             "pr": NSNull(), "legacy": false],
        ]
    }

    static var dsPR: [[String: Any]] {
        func p(_ n: Int, _ t: String, _ st: String, _ u: [String: Any], _ login: String, _ head: String, _ so: [Int], _ add: Int, _ del: Int, _ f: Int, ngay: Double) -> [String: Any] {
            ["provider": "GITHUB", "number": n, "title": t, "url": "https://github.com/northwind/mobile-app/pull/\(n)", "state": st, "author": ai(u, login),
             "reviewers": [ai(G.linh, "linhtran")], "headRef": head, "baseRef": "main", "issueNumbers": so, "additions": add, "deletions": del, "changedFiles": f,
             "mergedBy": st == "merged" ? ai(G.linh, "linhtran") : NSNull(), "openedAt": G.iso(ngay), "mergedAt": st == "merged" ? G.iso(ngay + 0.3) : NSNull(),
             "closedAt": st == "closed" ? G.iso(ngay + 1) : NSNull(), "legacy": false]
        }
        return [
            p(48, "NW-12: open the right issue from a notification", "open", G.toi, "alex", "feature/NW-12-push-routing", [12], 214, 37, 6, ngay: -0.08),
            p(47, "NW-17: offline cache for My Work (draft)", "draft", G.toi, "alex", "feature/NW-17-offline", [17], 88, 4, 3, ngay: -1.5),
            p(46, "NW-19: iPad split view with grouped sidebar", "merged", G.linh, "linhtran", "feature/NW-19-ipad-split", [19], 512, 140, 14, ngay: -2),
            p(44, "Upgrade Kingfisher to 8.1", "merged", G.minh, "minhp", "deps/kingfisher", [], 12, 12, 2, ngay: -5),
            p(43, "Experiment: custom tab bar", "closed", G.an, "anng", "spike/tab-bar", [], 160, 2, 4, ngay: -7),
        ]
    }

    static func cay(_ b: [String: Any]) -> [String: Any] {
        let path = b["path"] as? String ?? ""
        func f(_ ten: String, _ co: Int) -> [String: Any] { ["name": ten, "path": "\(path)/\(ten)", "type": "file", "size": co] }
        func d(_ ten: String) -> [String: Any] { ["name": ten, "path": "\(path)/\(ten)", "type": "dir", "size": NSNull()] }
        switch path {
        case "Sources": return ["ref": "main", "path": path, "entries": [d("App"), d("Views"), d("Models")]]
        case "Sources/App": return ["ref": "main", "path": path, "entries": [f("NotificationRouter.swift", 742), f("Route.swift", 318), f("AppState.swift", 2140)]]
        case "": break
        default: return ["ref": "main", "path": path, "entries": [Any]()]
        }
        return ["ref": "main", "path": "", "entries": [
            ["name": ".github", "path": ".github", "type": "dir", "size": NSNull()],
            ["name": "Sources", "path": "Sources", "type": "dir", "size": NSNull()],
            ["name": "Tests", "path": "Tests", "type": "dir", "size": NSNull()],
            ["name": "Package.swift", "path": "Package.swift", "type": "file", "size": 1180],
            ["name": "README.md", "path": "README.md", "type": "file", "size": 4210],
            ["name": "AppIcon.png", "path": "AppIcon.png", "type": "file", "size": 182_340],
        ]]
    }

    static func tep(_ b: [String: Any]) -> Any {
        let path = b["path"] as? String ?? ""
        if path.hasSuffix(".png") {
            return ["ref": "main", "path": path, "size": 182_340, "binary": true, "tooLarge": false, "content": NSNull(),
                    "webUrl": "https://github.com/northwind/mobile-app/blob/main/\(path)"]
        }
        if path == "README.md" {
            return ["ref": "main", "path": path, "size": 4210, "binary": false, "tooLarge": false,
                    "content": "# Northwind mobile app\n\nSwiftUI client for iPhone and iPad.\n\n## Build\n\n```\nxcodebuild -scheme App\n```\n",
                    "webUrl": "https://github.com/northwind/mobile-app/blob/main/README.md"]
        }
        if path.hasSuffix("AppState.swift") {
            return ["ref": "main", "path": path, "size": 1_400_000, "binary": false, "tooLarge": true, "content": NSNull(),
                    "webUrl": "https://github.com/northwind/mobile-app/blob/main/\(path)"]
        }
        return tep
    }

    static var tep: [String: Any] {
        let ma = """
        import SwiftUI

        /// Opens the right screen for a notification tap (NW-12).
        enum NotificationRouter {
            static func open(_ path: String, in app: AppState) {
                // Issue links: /work/<ws>/<KEY>/issue/<n>
                guard let route = Route.parse(path) else { return }
                switch route {
                case .issue(let key, let number):
                    app.tab = .myWork
                    app.pendingIssue = IssueRef(key: key, number: number)
                case .chat(let channel, let message):
                    app.tab = .chat
                    app.pendingChannel = channel
                    app.highlight = message
                }
            }

            static let maxRetries = 3
            static let greeting = "Welcome back"
        }
        """
        return ["ref": "main", "path": "Sources/App/NotificationRouter.swift", "size": ma.utf8.count, "binary": false, "tooLarge": false,
                "content": ma, "webUrl": "https://github.com/northwind/mobile-app/blob/main/Sources/App/NotificationRouter.swift"]
    }

    static var lichSu: [[String: Any]] {
        [
            ["sha": "9f8e7d6c5b4a", "message": "NW-12 Route cold-start taps through DinhTuyen", "authorLogin": "alex", "authorName": "Alex Morgan", "at": G.iso(-0.05),
             "url": "https://github.com/northwind/mobile-app/commit/9f8e7d6c5b4a", "author": ai(G.toi, "alex")],
            ["sha": "a1b2c3d4e5f6", "message": "Merge pull request #46 from feature/NW-19-ipad-split", "authorLogin": "linhtran", "authorName": "Linh Tran", "at": G.iso(-0.4),
             "url": "https://github.com/northwind/mobile-app/commit/a1b2c3d4e5f6", "author": ai(G.linh, "linhtran")],
            ["sha": "6c5b4a392817", "message": "chore: bump build number to 2", "authorLogin": NSNull(), "authorName": "ci-bot", "at": G.iso(-1.1),
             "url": "https://github.com/northwind/mobile-app/commit/6c5b4a392817", "author": ai(nil, "ci-bot")],
        ]
    }

    static var chiTietCommit: [String: Any] {
        let patch = """
        @@ -12,9 +12,14 @@ enum NotificationRouter {
             static func open(_ path: String, in app: AppState) {
        -        guard let issue = Int(path.split(separator: "/").last ?? "") else { return }
        -        app.pendingIssue = issue
        +        // Issue links: /work/<ws>/<KEY>/issue/<n>
        +        guard let route = Route.parse(path) else { return }
        +        switch route {
        +        case .issue(let key, let number):
        +            app.tab = .myWork
        +            app.pendingIssue = IssueRef(key: key, number: number)
        +        case .chat(let channel, let message):
        +            app.tab = .chat
        +            app.pendingChannel = channel
        +        }
             }
        """
        return ["sha": "9f8e7d6c5b4a3928", "message": "NW-12 Route cold-start taps through DinhTuyen\n\nCold start delivers the tap before SwiftUI builds the view tree.",
                "authorLogin": "alex", "authorName": "Alex Morgan", "at": G.iso(-0.05), "url": "https://github.com/northwind/mobile-app/commit/9f8e7d6c5b4a3928",
                "author": ai(G.toi, "alex"), "parents": ["8e7d6c5b4a39"], "stats": ["additions": 42, "deletions": 9, "files": 3],
                "files": [
                    ["filename": "Sources/App/NotificationRouter.swift", "previous": NSNull(), "status": "modified", "additions": 30, "deletions": 7, "patch": patch, "truncated": false],
                    ["filename": "Sources/App/Route.swift", "previous": NSNull(), "status": "added", "additions": 12, "deletions": 0,
                     "patch": "@@ -0,0 +1,12 @@\n+enum Route {\n+    case issue(String, Int)\n+    case chat(Int, Int?)\n+}", "truncated": false],
                    ["filename": "Resources/Splash.png", "previous": NSNull(), "status": "modified", "additions": 0, "deletions": 0, "patch": NSNull(), "truncated": false],
                ],
                "truncated": false, "issues": ["12": the["12"]!]]
    }
}

// MARK: - Trợ lý AI: hội thoại giả có trạng thái (tạo, hỏi, hỏng, hỏi lại, áp dụng đề xuất)

enum AIGia {
    typealias G = DuLieuGia
    nonisolated(unsafe) private static var hoiThoai: [[String: Any]] = mau
    nonisolated(unsafe) private static var idKe = 900

    private static func tin(_ id: Int, _ tid: Int, _ role: String, _ content: String, author: [String: Any]?, loi: String? = nil,
                            actions: [[String: Any]] = [], gio: Double) -> [String: Any] {
        ["id": id, "threadId": tid, "role": role, "content": content, "title": NSNull(), "issueNumber": NSNull(), "error": loi ?? NSNull(),
         "createdAt": G.iso(-gio / 24), "author": author ?? NSNull(), "actions": actions]
    }

    static let traLoiMau = """
    You have **3 open issues** in this sprint. Start with the one that's due first.

    ### 1. [NW-12 — Push notifications open the right issue](/work/northwind/NW/issue/12)
    **Due in 2 days** · In Progress · 5 points

    **Read first**
    - [Docs #3 — Notification payloads](/work/northwind/NW/docs/3)
    - The comment by @linh on NW-12 about cold starts

    **Steps**
    1. Parse the `duongDan` path from the push payload.
    2. Route `/issue/<n>` to My Work and `/chat?c=` to the channel.
    3. Test a tap while the app is closed (cold start).

    **Done when** the acceptance criteria on [NW-12](/work/northwind/NW/issue/12) pass on iPhone and iPad.

    ### 2. [NW-17 — Offline cache for My Work](/work/northwind/NW/issue/17)
    To Do · due next week. Ask @linh which screens must work offline.

    _General knowledge:_ keep the router a pure function so you can unit-test it without a device.
    """

    private static var mau: [[String: Any]] {
        let t1 = 801, t2 = 802
        return [
            ["id": t1, "title": "What should I work on next, and what do I need to read first?", "visibility": "PROJECT", "mode": "CHAT", "issueNumber": NSNull(),
             "messageCount": 2, "lastMessageAt": G.iso(-0.02), "createdAt": G.iso(-0.03), "createdById": 1, "createdBy": G.toi, "participants": [G.toi], "mine": true,
             "canManage": true, "messages": [
                tin(811, t1, "user", "What should I work on next, and what do I need to read first?", author: G.toi, gio: 0.7),
                tin(812, t1, "assistant", traLoiMau, author: nil, actions: [
                    ["index": 0, "status": "pending", "action": ["type": "update_issue", "number": 17, "status": "In Progress"]],
                ], gio: 0.68),
             ]],
            ["id": t2, "title": "Why did our velocity drop in Sprint 5?", "visibility": "PROJECT", "mode": "CHAT", "issueNumber": NSNull(),
             "messageCount": 1, "lastMessageAt": G.iso(-1), "createdAt": G.iso(-1), "createdById": 2, "createdBy": G.linh, "participants": [G.linh], "mine": false,
             "canManage": true, "messages": [
                tin(821, t2, "user", "Why did our velocity drop in Sprint 5?", author: G.linh, loi: "The AI returned an answer we could not read. Please try again.", gio: 24),
             ]],
        ]
    }

    private static func gon(_ t: [String: Any]) -> [String: Any] {
        var g = t
        g["messages"] = nil
        return g
    }

    static func ds() -> [[String: Any]] { hoiThoai.filter { ($0["messageCount"] as? Int ?? 0) > 0 }.map(gon) }
    static func mot(_ id: Int) -> [String: Any]? { hoiThoai.first { ($0["id"] as? Int) == id } }
    static func xoa(_ id: Int) { hoiThoai.removeAll { ($0["id"] as? Int) == id } }

    static func tao(_ b: [String: Any]) -> [String: Any] {
        idKe += 1
        let t: [String: Any] = ["id": idKe, "title": (b["title"] as? String) ?? "New conversation", "visibility": b["visibility"] ?? "PROJECT", "mode": "CHAT",
                                "issueNumber": NSNull(), "messageCount": 0, "lastMessageAt": G.iso(0), "createdAt": G.iso(0), "createdById": 1, "createdBy": G.toi,
                                "participants": [Any](), "mine": true, "canManage": true, "messages": [Any]()]
        hoiThoai.insert(t, at: 0)
        return t
    }

    private static func them(_ tid: Int, _ tinMoi: [String: Any]) {
        guard let i = hoiThoai.firstIndex(where: { ($0["id"] as? Int) == tid }) else { return }
        var ms = hoiThoai[i]["messages"] as? [[String: Any]] ?? []
        ms.append(tinMoi)
        hoiThoai[i]["messages"] = ms
        hoiThoai[i]["messageCount"] = ms.count
        hoiThoai[i]["lastMessageAt"] = G.iso(0)
    }

    static func hoi(_ b: [String: Any]) -> Any {
        let tid = b["threadId"] as? Int ?? 0
        let cau = b["message"] as? String ?? ""
        idKe += 1
        let q = tin(idKe, tid, "user", cau, author: G.toi, loi: cau.contains("#fail") ? "The AI returned an answer we could not read. Please try again." : nil, gio: 0)
        them(tid, q)
        if cau.contains("#fail") {
            return LoiGiaCTW(trangThai: 502, ma: "WORK_AI_BAD_OUTPUT", thongDiep: "The AI returned an answer we could not read. Please try again.")
        }
        idKe += 1
        let a = tin(idKe, tid, "assistant", traLoiMau, author: nil, gio: 0)
        them(tid, a)
        return ["reply": traLoiMau, "actions": [Any](), "threadId": tid, "question": q, "answer": a,
                "quota": ["pro": false, "used": 4, "limit": NSNull(), "remaining": NSNull(), "available": true]]
    }

    static func hoiLai(_ mid: Int) -> Any {
        for i in hoiThoai.indices {
            guard var ms = hoiThoai[i]["messages"] as? [[String: Any]], let k = ms.firstIndex(where: { ($0["id"] as? Int) == mid }) else { continue }
            ms[k]["error"] = NSNull()
            hoiThoai[i]["messages"] = ms
            let tid = hoiThoai[i]["id"] as? Int ?? 0
            idKe += 1
            let tl = """
            Velocity dropped from **21** to **13 points** in Sprint 5 for two reasons found in CT Work:

            1. [NW-14](/work/northwind/NW/issue/14) (3 points) was blocked for 4 days waiting on a design decision.
            2. Two team members logged 40% of their time on the public beta release ([Releases](/work/northwind/NW/releases)).

            _General knowledge:_ one sprint is not a trend — compare the next two sprints before changing the plan.
            """
            let a = tin(idKe, tid, "assistant", tl, author: nil, gio: 0)
            them(tid, a)
            return ["reply": tl, "actions": [Any](), "threadId": tid, "question": NSNull(), "answer": a]
        }
        return LoiGiaCTW(trangThai: 404, ma: "NOT_FOUND", thongDiep: "Message not found")
    }

    static func datDeXuat(_ mid: Int, _ idx: Int, trangThai: String) -> Any {
        for i in hoiThoai.indices {
            guard var ms = hoiThoai[i]["messages"] as? [[String: Any]], let k = ms.firstIndex(where: { ($0["id"] as? Int) == mid }),
                  var acts = ms[k]["actions"] as? [[String: Any]], idx < acts.count else { continue }
            acts[idx]["status"] = trangThai
            if trangThai == "done" { acts[idx]["summary"] = "NW-17 moved to In Progress"; acts[idx]["byName"] = "alex" }
            ms[k]["actions"] = acts
            hoiThoai[i]["messages"] = ms
            return acts[idx]
        }
        return LoiGiaCTW(trangThai: 404, ma: "NOT_FOUND", thongDiep: "Suggestion not found")
    }
}
#endif
