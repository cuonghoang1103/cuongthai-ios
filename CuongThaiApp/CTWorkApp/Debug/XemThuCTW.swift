#if DEBUG
import Foundation

/// Cửa XEM MÀN HÌNH bằng MÁY CHỦ GIẢ — CHỈ có trong bản DEBUG (CLAUDE.md A6).
///
/// Vì sao: chụp màn hình để kiểm giao diện mà KHÔNG dùng tài khoản thật, không
/// đụng dữ liệu production. Một `URLProtocol` chặn mọi yêu cầu tới máy chủ và
/// trả dữ liệu mẫu có HÌNH DẠNG ĐÚNG như backend (đối chiếu service — cùng bộ
/// model `Codable` giải mã), nên màn hình hiện y như thật.
///
///     SIMCTL_CHILD_CT_XEM_MAN=board xcrun simctl launch <udid> com.cuongthai.ctwork
///
/// Tên màn: dongy · dangnhap · mywork · duan · board · backlog · list · issue · binhluan ·
/// lichsu · docs · trang · chat · kenh · inbox · account · chonduan
///
/// ⚠️ Toàn bộ tệp nằm trong `#if DEBUG` ⇒ không vào Release. Kiểm bằng
/// `grep -a -c CT_XEM_MAN <Release binary>` phải = 0.
enum XemThuCTW {
    static var man: String? { ProcessInfo.processInfo.environment["CT_XEM_MAN"] }

    /// Mô-đun mở sẵn trong trang dự án (iPhone) cho màn đang chụp.
    static var moDunMoSan: String? {
        if let m = moDunGiaoTiep { return m }
        if let m = moDunXem { return m.id }
        switch man?.lowercased() {
        case "board": return "board"
        case "backlog", "list": return "backlog"
        case "docs", "trang": return "docs"
        default: return nil
        }
    }

    @MainActor
    static func batNeuCan() {
        guard let man = man?.lowercased(), !man.isEmpty else { return }
        URLProtocol.registerClass(MayChuGia.self)
        let app = AppState.shared
        app.cheDoXemThu = true
        // Mỗi lượt xem thử bắt đầu sạch: nội dung đã ẩn ở lượt trước không ẩn tiếp.
        AnNoiDungCTW.shared.xoaHet()
        AnNoiDungChungCTW.shared.xoaHet()
        switch man {
        case "dongy":
            app.daDongYDieuKhoan = false
            app.isAuthenticated = false
            return
        case "dangnhap":
            app.daDongYDieuKhoan = true
            app.isAuthenticated = false
            return
        default: break
        }
        // My Work mở tab Agenda cho màn `agenda` (mảng D), Issues cho mọi màn khác.
        UserDefaults.standard.set(man == "agenda" ? 1 : 0, forKey: "ctw.myWork.che")
        app.daDongYDieuKhoan = true
        app.isAuthenticated = true
        app.luaChon = LuaChonCTW(slug: "northwind", tenKhongGian: "Northwind Studio", pid: 7, maDuAn: "NW", tenDuAn: "Mobile App Launch")
        Task { await app.fetchProfile() }
        // Màn của mảng Giao tiếp (chat/họp/hộp thư) — XemThuCTW+GiaoTiep.swift.
        if batGiaoTiep(app) { return }
        // `mod:<id>[/<màn con>]` — mở thẳng một mô-đun bất kỳ (XemThuCTW+MoDun.swift).
        if let m = moDunXem { app.muc = .moDun(m.id); UserDefaults.standard.set(man, forKey: "ctw.xemThu.man"); return }
        switch man {
        case "duan": app.muc = .duAn
        // iPhone: khung gộp mô-đun `.trangDuAn` vào tab Projects (trang dự án tự mở
        // mô-đun — `moDunMoSan`); iPad: mở thẳng mục thanh bên.
        case "board", "backlog", "list", "docs", "trang": app.muc = .moDun(moDunMoSan ?? "board")
        case "issue", "lichsu", "binhluan": app.muc = .viecCuaToi; app.ctWorkDich = CTWDich(slug: "northwind", maDuAn: "NW", so: 12)
        case "chat": app.muc = .moDun("chat")
        case "kenh":
            app.muc = .moDun("chat")
            app.dichCho = DichMoDunCTW(moDun: "chat", pid: 7, duongDan: DuongDanCTW.tach("/work/northwind/NW/chat?c=1")!)
        case "inbox": app.muc = .hopThu
        case "them": app.muc = .them
        case "account", "chonduan": app.muc = .taiKhoan
        default: app.muc = .viecCuaToi
        }
        UserDefaults.standard.set(man, forKey: "ctw.xemThu.man")
    }
}

/// Máy chủ giả trong tiến trình.
final class MayChuGia: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        guard let u = request.url else { return false }
        return u.path.hasPrefix("/api/v1/")
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let u = request.url!
        // `CT_XEM_LOI_MANG=<đoạn đường>` (vd `/work/projects/7/code`): giả MẤT MẠNG cho mọi đường chứa đoạn đó —
        // kiểm trạng thái lỗi mạng / bản lưu ngoại tuyến của từng mô-đun mà không phải tắt mạng máy.
        if let mat = ProcessInfo.processInfo.environment["CT_XEM_LOI_MANG"], !mat.isEmpty,
           mat == "*" || u.path.contains(mat) {
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.15) {
                self.client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            }
            return
        }
        // GET không có thân ⇒ đưa tham số query vào `body` cho tuyến giả cần (cây thư mục theo `path`, tệp…).
        var than = Self.than(request)
        if than.isEmpty, let q = URLComponents(url: u, resolvingAgainstBaseURL: false)?.queryItems {
            for i in q { than[i.name] = i.value ?? "" }
        }
        let (ma, data) = DuLieuGia.traLoiCoMa(method: request.httpMethod ?? "GET", path: u.path, body: than)
        let res = HTTPURLResponse(url: u, statusCode: ma, httpVersion: "HTTP/1.1",
                                  headerFields: ["Content-Type": "application/json"])!
        // Trợ lý AI "nghĩ" lâu hơn ⇒ thấy được trạng thái chờ khi chụp/kiểm.
        let cho = u.path.hasSuffix("/ai/chat") || u.path.hasSuffix("/retry") ? 1.2 : 0.15
        DispatchQueue.global().asyncAfter(deadline: .now() + cho) {
            self.client?.urlProtocol(self, didReceive: res, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: data)
            self.client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}

    private static func than(_ r: URLRequest) -> [String: Any] {
        var d = r.httpBody
        if d == nil, let s = r.httpBodyStream {
            s.open()
            var buf = Data()
            var b = [UInt8](repeating: 0, count: 4096)
            while s.hasBytesAvailable {
                let n = s.read(&b, maxLength: b.count)
                if n <= 0 { break }
                buf.append(b, count: n)
            }
            s.close()
            d = buf
        }
        guard let d, let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return [:] }
        return o
    }
}

/// Dữ liệu mẫu: không gian "Northwind Studio", dự án NW (Scrum), 6 thành viên
/// trong đó có MỘT AI agent ("Scout"). Người đang dùng = Alex Morgan (id 1).
enum DuLieuGia {
    static func iso(_ ngay: Double, gio: Double = 0) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: Date().addingTimeInterval(ngay * 86400 + gio * 3600))
    }
    static func ngay(_ n: Double) -> String { String(iso(n).prefix(10)) }

    static func nguoi(_ id: Int, _ u: String, _ ten: String, agent: Bool = false) -> [String: Any] {
        ["id": id, "username": u, "fullName": ten, "displayName": NSNull(), "avatarUrl": NSNull(), "kind": agent ? "AGENT" : "HUMAN"]
    }
    static let toi = nguoi(1, "alex", "Alex Morgan")
    static let linh = nguoi(2, "linh", "Linh Tran")
    static let minh = nguoi(3, "minh", "Minh Pham")
    static let an = nguoi(4, "an", "An Nguyen")
    static let sara = nguoi(5, "sara", "Sara Kim")
    static let scout = nguoi(9, "scout", "Scout", agent: true)

    static func traLoi(method: String, path: String, body: [String: Any]) -> Data {
        traLoiCoMa(method: method, path: path, body: body).1
    }

    /// Như `traLoi` nhưng kèm mã HTTP: tuyến trả `LoiGiaCTW` ⇒ phong bì lỗi THẬT của máy chủ
    /// (`{success:false, message, code}`) với mã 4xx/5xx — kiểm nhánh lỗi (502 AI, 409, 429…).
    static func traLoiCoMa(method: String, path: String, body: [String: Any]) -> (Int, Data) {
        let p = path.replacingOccurrences(of: "/api/v1", with: "")
        let data: Any = route(method, p, body)
        if let l = data as? LoiGiaCTW {
            let goi: [String: Any] = ["success": false, "message": l.thongDiep, "code": l.ma]
            return (l.trangThai, (try? JSONSerialization.data(withJSONObject: goi)) ?? Data())
        }
        let goi: [String: Any] = ["success": true, "data": data]
        return (200, (try? JSONSerialization.data(withJSONObject: goi)) ?? Data("{\"success\":true}".utf8))
    }

    // swiftlint:disable:next cyclomatic_complexity
    static func route(_ m: String, _ p: String, _ b: [String: Any]) -> Any {
        if let r = DuLieuGiaGiaoTiep.route(m, p, b) { return r }
        // Dữ liệu mẫu của các mô-đun đặt ở tệp riêng (XemThuCTW+MoDun.swift) — hỏi trước.
        if let r = DuLieuGiaMoDun.route(m, p, b) { return r }
        switch (m, p) {
        case ("GET", "/profile"):
            return ["id": 1, "username": "alex", "email": "alex@northwind.example", "fullName": "Alex Morgan", "displayName": NSNull(), "avatarUrl": NSNull()]
        case ("GET", "/messages/blocks"): return [Any]()
        case ("GET", "/profile/deletion-request"): return ["request": NSNull()]
        case ("GET", "/work/chat/unread"): return ["total": 3, "projects": [["projectId": 7, "unread": 3, "mentions": 1]]]
        case ("GET", "/social/notifications"): return thongBao
        case ("GET", "/work/me/work"): return viecCuaToi
        case ("GET", "/work/workspaces"):
            return [["id": 1, "name": "Northwind Studio", "slug": "northwind", "role": "ADMIN", "projectCount": 2, "memberCount": 6],
                    ["id": 2, "name": "SWP391 · Group 4", "slug": "swp391-g4", "role": "MEMBER", "projectCount": 1, "memberCount": 5]]
        case ("GET", "/work/workspaces/by-slug/northwind"):
            return ["id": 1, "name": "Northwind Studio", "slug": "northwind", "role": "ADMIN", "projects": [
                ["id": 7, "key": "NW", "name": "Mobile App Launch", "type": "SCRUM", "openIssues": 24, "role": "ADMIN"],
                ["id": 8, "key": "WEB", "name": "Marketing Website", "type": "KANBAN", "openIssues": 9, "role": "MEMBER"]]]
        case ("GET", "/work/workspaces/by-slug/swp391-g4"):
            return ["id": 2, "name": "SWP391 · Group 4", "slug": "swp391-g4", "role": "MEMBER", "projects": [
                ["id": 11, "key": "SWP", "name": "Clinic Booking System", "type": "SCRUM", "openIssues": 31, "role": "MEMBER"]]]
        default: break
        }
        if p.hasPrefix("/work/resolve/") { return ["projectId": 7] }
        if p == "/work/search" { return ["items": [], "total": 0] }
        let pr = "/work/projects/7"
        if p == pr { return cauHinh }
        // Chuyển trạng thái được GHI NHỚ trong lượt chạy — để kéo thả/"Move to…" thấy kết quả.
        if p.hasPrefix(pr + "/issues/"), p.hasSuffix("/move"), let st = b["statusId"] as? Int,
           let so = Int(p.split(separator: "/")[4]) {
            khoa.lock(); daDoi[so] = st; khoa.unlock()
            return ["moved": true]
        }
        if p == pr + "/board" { return ["mode": "SPRINT", "sprint": sprint, "fallback": false, "issues": the.map(apDoi)] }
        if p == pr + "/backlog" { return ["unit": "POINTS", "sprints": [sprint, sprintSau], "truncated": false, "total": the.count + tonDong.count, "issues": the + tonDong] }
        if p == pr + "/issues" && m == "GET" { return ["items": the + tonDong, "total": the.count + tonDong.count, "nextCursor": NSNull()] }
        if p == pr + "/issues" && m == "POST" { return chiTiet(so: 40, tieuDe: b["title"] as? String ?? "New issue") }
        if p.hasPrefix(pr + "/issues/"), p.hasSuffix("/comments"), m == "GET" { return binhLuan }
        if p.hasPrefix(pr + "/issues/"), p.hasSuffix("/comments"), m == "POST" {
            return ["id": 99, "bodyJson": b["bodyJson"] ?? NSNull(), "isAi": false, "createdAt": iso(0), "author": toi]
        }
        if p.hasPrefix(pr + "/issues/"), p.hasSuffix("/history") { return lichSu }
        if p.hasPrefix(pr + "/issues/"), p.split(separator: "/").count == 5 {
            let so = Int(p.split(separator: "/").last ?? "") ?? 12
            return chiTiet(so: so, tieuDe: nil)
        }
        if p == pr + "/chat/channels" { return kenh }
        if p.hasPrefix(pr + "/chat/channels/"), p.hasSuffix("/messages"), m == "GET" { return ["messages": tin, "hasMoreBefore": false, "hasMoreAfter": false] }
        if p.hasPrefix(pr + "/chat/channels/"), p.hasSuffix("/messages"), m == "POST" {
            return ["id": 500, "channelId": 1, "kind": "USER", "body": b["body"] ?? "", "createdAt": iso(0), "author": toi, "replyCount": 0]
        }
        if p == pr + "/pages" { return ["pages": trang, "canEdit": true] }
        if p.hasSuffix("/markdown") { return ["filename": "release-plan.md", "markdown": markdown] }
        if p.hasPrefix(pr + "/pages/") {
            return ["id": 3, "number": 3, "title": "Release plan — v1.0", "status": "APPROVED", "updatedAt": iso(-1), "owner": linh,
                    "lastEditedBy": linh, "ancestors": [["id": 1, "number": 1, "title": "Product"]],
                    "children": [["id": 5, "number": 5, "title": "Store listing checklist"]]]
        }
        return [String: Any]()
    }

    private static let khoa = NSLock()
    nonisolated(unsafe) private static var daDoi: [Int: Int] = [:]
    static func apDoi(_ c: [String: Any]) -> [String: Any] {
        khoa.lock(); defer { khoa.unlock() }
        guard let so = c["number"] as? Int, let st = daDoi[so] else { return c }
        var m = c
        m["statusId"] = st
        m["version"] = 4
        return m
    }

    static let sprint: [String: Any] = ["id": 21, "name": "Sprint 6 — Beta polish", "goal": "Ship the public beta", "state": "ACTIVE",
                                        "startAt": iso(-6), "endAt": iso(8)]
    static let sprintSau: [String: Any] = ["id": 22, "name": "Sprint 7 — Launch", "state": "PLANNED", "startAt": iso(8), "endAt": iso(22)]

    static let cauHinh: [String: Any] = [
        "id": 7, "key": "NW", "name": "Mobile App Launch", "type": "SCRUM",
        "workspace": ["id": 1, "name": "Northwind Studio", "slug": "northwind"],
        "role": "ADMIN", "workspaceRole": "ADMIN",
        "permissions": ["editIssues": true, "createIssues": true, "transition": true, "deleteIssues": true, "comment": true,
                        "attach": true, "manageSprints": true, "settings": true, "useAi": true],
        "workflows": [["id": 1, "name": "Default", "isDefault": true, "transitions": [Any](), "statuses": [
            ["id": 1, "name": "To Do", "category": "TODO", "position": 0],
            ["id": 2, "name": "In Progress", "category": "IN_PROGRESS", "position": 1],
            ["id": 3, "name": "In Review", "category": "IN_PROGRESS", "position": 2],
            ["id": 4, "name": "Done", "category": "DONE", "position": 3]]]],
        "boardColumns": [["key": "todo", "name": "To Do", "category": "TODO", "statusIds": [1]],
                         ["key": "doing", "name": "In Progress", "category": "IN_PROGRESS", "statusIds": [2], "wipLimit": 4],
                         ["key": "review", "name": "In Review", "category": "IN_PROGRESS", "statusIds": [3]],
                         ["key": "done", "name": "Done", "category": "DONE", "statusIds": [4]]],
        "issueTypes": [["id": 1, "key": "EPIC", "name": "Epic", "icon": "epic", "color": "#7c3aed", "level": 1],
                       ["id": 2, "key": "STORY", "name": "Story", "icon": "story", "color": "#16a34a", "level": 0],
                       ["id": 3, "key": "TASK", "name": "Task", "icon": "task", "color": "#2563eb", "level": 0],
                       ["id": 4, "key": "BUG", "name": "Bug", "icon": "bug", "color": "#dc2626", "level": 0],
                       ["id": 5, "key": "SUBTASK", "name": "Sub-task", "icon": "subtask", "color": "#0891b2", "level": -1]],
        "labels": [["id": 1, "name": "ios", "color": "#2563eb"], ["id": 2, "name": "backend", "color": "#16a34a"],
                   ["id": 3, "name": "design", "color": "#db2777"], ["id": 4, "name": "release", "color": "#ea580c"]],
        "sprints": [sprint, sprintSau],
        "members": [toi.merging(["role": "ADMIN"]) { $1 }, linh.merging(["role": "ADMIN"]) { $1 },
                    minh.merging(["role": "MEMBER"]) { $1 }, an.merging(["role": "MEMBER"]) { $1 },
                    sara.merging(["role": "VIEWER"]) { $1 }, scout.merging(["role": "MEMBER"]) { $1 }],
    ]

    static func card(_ so: Int, _ t: String, type: Int, st: Int, pr: Int, ai: Int?, sp: Double?, han: Double?, nhan: [Int], sprint: Int? = 21, bl: Int = 0) -> [String: Any] {
        ["id": 100 + so, "number": so, "title": t, "typeId": type, "statusId": st, "priority": pr,
         "assigneeId": ai ?? NSNull(), "storyPoints": sp ?? NSNull(), "dueDate": han.map { iso($0) } ?? NSNull(),
         "rank": "a\(so)", "version": 3, "resolvedAt": st == 4 ? iso(-1) : NSNull(), "sprintId": sprint ?? NSNull(),
         "labelIds": nhan, "commentCount": bl, "attachmentCount": 0, "subtaskCount": 0, "createdAt": iso(-9), "updatedAt": iso(-0.2)]
    }

    static let the: [[String: Any]] = [
        card(12, "Push notifications open the right issue", type: 2, st: 2, pr: 2, ai: 1, sp: 5, han: 2, nhan: [1, 2], bl: 4),
        card(14, "Crash when attaching a HEIC photo on iOS 17", type: 4, st: 1, pr: 1, ai: 3, sp: 3, han: -1, nhan: [1]),
        card(15, "Design empty states for Inbox and Chat", type: 3, st: 3, pr: 3, ai: 4, sp: 2, han: 4, nhan: [3]),
        card(16, "Write release notes draft", type: 3, st: 2, pr: 4, ai: 9, sp: 1, han: 5, nhan: [4]),
        card(17, "Offline cache for My Work", type: 2, st: 1, pr: 3, ai: 1, sp: 8, han: 9, nhan: [1]),
        card(18, "Rate-limit chat uploads per user", type: 3, st: 4, pr: 3, ai: 2, sp: 2, han: nil, nhan: [2]),
        card(19, "iPad split view layout", type: 2, st: 4, pr: 2, ai: 1, sp: 5, han: nil, nhan: [1, 3]),
        card(20, "Accessibility audit (Dynamic Type)", type: 3, st: 1, pr: 2, ai: nil, sp: 3, han: 6, nhan: [3]),
    ]
    static let tonDong: [[String: Any]] = [
        card(23, "Dark mode screenshots for the App Store", type: 3, st: 1, pr: 4, ai: nil, sp: 1, han: nil, nhan: [4], sprint: nil),
        card(24, "Search across workspaces", type: 2, st: 1, pr: 3, ai: nil, sp: 5, han: nil, nhan: [1, 2], sprint: nil),
        card(25, "Widget: today's due issues", type: 2, st: 1, pr: 5, ai: nil, sp: 3, han: nil, nhan: [1], sprint: nil),
    ]

    static func doc(_ ps: [String]) -> [String: Any] {
        ["type": "doc", "content": ps.map { ["type": "paragraph", "content": [["type": "text", "text": $0]]] }]
    }

    static func chiTiet(so: Int, tieuDe: String?) -> [String: Any] {
        var c = (the + tonDong).map(apDoi).first { ($0["number"] as? Int) == so } ?? card(so, tieuDe ?? "New issue", type: 3, st: 1, pr: 3, ai: nil, sp: nil, han: nil, nhan: [])
        if let tieuDe { c["title"] = tieuDe }
        c["assignee"] = (c["assigneeId"] as? Int).flatMap { id in [toi, linh, minh, an, sara, scout].first { ($0["id"] as? Int) == id } } ?? NSNull()
        c["reporter"] = linh
        c["descriptionJson"] = [
            "type": "doc", "content": [
                ["type": "paragraph", "content": [["type": "text", "text": "When a user taps a CT Work notification, the app must open "],
                                                  ["type": "text", "text": "exactly", "marks": [["type": "bold"]]],
                                                  ["type": "text", "text": " the issue or chat channel it refers to — even from a cold start."]]],
                ["type": "heading", "attrs": ["level": 3], "content": [["type": "text", "text": "Acceptance criteria"]]],
                ["type": "taskList", "content": [
                    ["type": "taskItem", "attrs": ["checked": true], "content": [["type": "paragraph", "content": [["type": "text", "text": "Tap on an assignment opens the issue"]]]]],
                    ["type": "taskItem", "attrs": ["checked": true], "content": [["type": "paragraph", "content": [["type": "text", "text": "Mentions in chat open the channel"]]]]],
                    ["type": "taskItem", "attrs": ["checked": false], "content": [["type": "paragraph", "content": [["type": "text", "text": "Works when the app was force-quit"]]]]]]],
                ["type": "codeBlock", "content": [["type": "text", "text": "ctwork://work/northwind/NW/issue/12"]]],
            ]]
        c["children"] = so == 12 ? [["id": 130, "number": 30, "title": "Handle cold-start routing", "typeId": 5, "statusId": 4, "assigneeId": 1],
                                    ["id": 131, "number": 31, "title": "Badge count after reading", "typeId": 5, "statusId": 2, "assigneeId": 9]] : [Any]()
        c["links"] = so == 12 ? [["id": 1, "type": "BLOCKS", "direction": "inward", "issue": ["id": 114, "key": "NW-14", "number": 14, "title": "Crash when attaching a HEIC photo on iOS 17"]]] : [Any]()
        c["attachments"] = so == 12 ? [["id": 51, "fileName": "notification-flow.png", "mime": "image/png", "size": 482_113, "createdAt": iso(-2), "uploader": minh],
                                       ["id": 52, "fileName": "apns-payload.json", "mime": "application/json", "size": 2_210, "createdAt": iso(-1), "uploader": scout]] : [Any]()
        c["watcherCount"] = 3
        c["isWatching"] = true
        return c
    }

    static let binhLuan: [[String: Any]] = [
        ["id": 1, "bodyJson": doc(["Routing works for assignments. Chat deep links still land on the channel list."]), "isAi": false,
         "createdAt": iso(-2, gio: -3), "author": minh],
        ["id": 2, "bodyJson": doc(["I traced it: the chat URL carries ?c=<channel>. Proposed fix attached as apns-payload.json — please review."]),
         "isAi": false, "createdAt": iso(-1, gio: -5), "author": scout],
        ["id": 3, "bodyJson": doc(["Looks right. Let's also cover the cold-start case before moving to review."]), "isAi": false,
         "createdAt": iso(-1, gio: -2), "editedAt": iso(-1, gio: -1), "author": linh],
        ["id": 4, "bodyJson": doc(["On it — will push the fix today."]), "isAi": false, "createdAt": iso(0, gio: -1), "author": toi],
    ]

    static let lichSu: [[String: Any]] = [
        ["id": 5, "field": "statusId", "fromValue": "1", "toValue": "2", "actorKind": "USER", "createdAt": iso(0, gio: -1), "actor": toi],
        ["id": 4, "field": "attachment", "fromValue": NSNull(), "toValue": "apns-payload.json", "actorKind": "AGENT", "createdAt": iso(-1), "actor": scout],
        ["id": 3, "field": "assigneeId", "fromValue": "3", "toValue": "1", "actorKind": "USER", "createdAt": iso(-3), "actor": linh],
        ["id": 2, "field": "priority", "fromValue": "3", "toValue": "2", "actorKind": "AUTOMATION", "createdAt": iso(-4), "actor": NSNull()],
        ["id": 1, "field": "created", "fromValue": NSNull(), "toValue": NSNull(), "actorKind": "USER", "createdAt": iso(-9), "actor": linh],
    ]

    static var viecCuaToi: [String: Any] {
        func it(_ so: Int, _ t: String, _ pr: Int, _ han: Double?, _ b: String, type: String, st: String, cat: String) -> [String: Any] {
            ["key": "NW-\(so)", "number": so, "title": t, "priority": pr, "dueDate": han.map { ngay($0) } ?? NSNull(), "bucket": b,
             "type": ["key": type, "name": type.capitalized, "color": type == "BUG" ? "#dc2626" : (type == "STORY" ? "#16a34a" : "#2563eb")],
             "status": ["name": st, "category": cat], "updatedAt": iso(-0.3),
             "project": ["key": "NW", "name": "Mobile App Launch"], "workspace": ["slug": "northwind", "name": "Northwind Studio"],
             "url": "/work/northwind/NW/issue/\(so)"]
        }
        return ["items": [it(21, "Fix sign-in token refresh loop", 1, -1, "overdue", type: "BUG", st: "In Progress", cat: "IN_PROGRESS"),
                          it(12, "Push notifications open the right issue", 2, 0, "today", type: "STORY", st: "In Progress", cat: "IN_PROGRESS"),
                          it(17, "Offline cache for My Work", 3, 2, "soon", type: "STORY", st: "To Do", cat: "TODO"),
                          it(26, "Review sprint 6 demo script", 3, 3, "soon", type: "TASK", st: "To Do", cat: "TODO"),
                          it(19, "Verify iPad split view on 11-inch", 4, nil, "none", type: "TASK", st: "In Review", cat: "IN_PROGRESS")],
                "counts": ["overdue": 1, "dueToday": 1, "dueSoon": 2, "inProgress": 3, "total": 5]]
    }

    static let kenh: [String: Any] = [
        "channels": [
            ["id": 1, "name": "general", "topic": "Announcements and day-to-day chat", "kind": "PUBLIC", "isGeneral": true, "unread": 2, "mentions": 1, "badge": 2, "canPost": true, "canManage": true],
            ["id": 2, "name": "ios-dev", "topic": "Builds, TestFlight, crashes", "kind": "PUBLIC", "unread": 1, "mentions": 0, "badge": 1, "canPost": true],
            ["id": 3, "name": "design", "topic": "Figma links and reviews", "kind": "PUBLIC", "unread": 0, "badge": 0, "canPost": true],
            ["id": 4, "name": "leads", "topic": "Planning (private)", "kind": "PRIVATE", "unread": 0, "badge": 0, "muted": true, "canPost": true]],
        "total": 3, "me": ["audience": "TEAM", "canCreate": true, "canModerate": true]]

    static let tin: [[String: Any]] = [
        ["id": 401, "channelId": 1, "kind": "SYSTEM", "body": "started a call", "createdAt": iso(-1, gio: -6), "author": linh],
        ["id": 402, "channelId": 1, "kind": "USER", "body": "Morning team! Beta build **1.0 (14)** is on TestFlight 🎉", "createdAt": iso(0, gio: -5), "author": linh, "reactions": [["emoji": "🎉", "count": 4, "mine": true]]],
        ["id": 403, "channelId": 1, "kind": "USER", "body": "Thanks @linh — installing now.", "createdAt": iso(0, gio: -4.9), "author": minh],
        ["id": 404, "channelId": 1, "kind": "USER", "body": "I summarised yesterday's crash reports in NW-14: 3 of 5 come from HEIC attachments on iOS 17.", "createdAt": iso(0, gio: -3), "author": scout,
         "previews": [["t": "issue", "key": "NW-14", "n": 14, "url": "/work/northwind/NW/issue/14", "title": "Crash when attaching a HEIC photo on iOS 17"]], "replyCount": 2],
        ["id": 405, "channelId": 1, "kind": "USER", "body": "Nice catch. @alex can you take a look after standup?", "createdAt": iso(0, gio: -2.5), "author": an],
        ["id": 406, "channelId": 1, "kind": "USER", "body": "Yes — picking it up now.", "createdAt": iso(0, gio: -2.4), "author": toi, "editedAt": iso(0, gio: -2.3)],
    ]

    static let trang: [[String: Any]] = [
        ["id": 1, "number": 1, "parentId": NSNull(), "title": "Product", "status": "APPROVED", "position": 1, "updatedAt": iso(-12), "owner": linh],
        ["id": 3, "number": 3, "parentId": 1, "title": "Release plan — v1.0", "status": "APPROVED", "position": 1, "updatedAt": iso(-1), "owner": linh],
        ["id": 5, "number": 5, "parentId": 3, "title": "Store listing checklist", "status": "IN_REVIEW", "position": 1, "updatedAt": iso(-2), "owner": an],
        ["id": 2, "number": 2, "parentId": NSNull(), "title": "Engineering", "status": "DRAFT", "position": 2, "updatedAt": iso(-5), "owner": minh],
        ["id": 4, "number": 4, "parentId": 2, "title": "Push notification architecture", "status": "DRAFT", "position": 1, "updatedAt": iso(-3), "owner": minh, "aiAssisted": true],
        ["id": 6, "number": 6, "parentId": NSNull(), "title": "Meeting notes — Sprint 6 planning", "status": "DRAFT", "position": 3, "updatedAt": iso(-6), "owner": toi],
    ]

    static let markdown = """
    # Release plan — v1.0

    We ship the **public beta** at the end of Sprint 6 and the App Store release in Sprint 7.

    ## Milestones

    | Milestone | Owner | Date |
    | --- | --- | --- |
    | Feature freeze | Linh | Oct 24 |
    | Beta on TestFlight | Alex | Oct 27 |
    | App Store submission | An | Nov 7 |

    ## Checklist

    - [x] Sign in with Apple
    - [x] Account deletion in Settings
    - [ ] Store screenshots (light + dark)
    - [ ] Review notes and demo account

    > Anything that blocks submission goes into the `release` label on the board.

    1. Freeze features
    2. Fix P1 bugs only
    3. Submit for review
    """

    static var thongBao: [String: Any] {
        func n(_ id: Int, _ t: String, _ s: [String: Any]?, _ p: [String: Any], doc: Bool, _ h: Double) -> [String: Any] {
            ["id": id, "type": t, "entityId": 112, "secondaryEntityId": NSNull(), "isRead": doc, "createdAt": iso(0, gio: h),
             "sender": s ?? NSNull(), "payload": p]
        }
        return ["items": [
            n(9, "WORK_MENTION", an, ["chat": true, "issueKey": "#general", "title": "NW · Mobile App Launch", "excerpt": "@alex can you take a look after standup?",
                                     "url": "/work/northwind/NW/chat?c=1&m=405"], doc: false, -2.5),
            n(8, "WORK_ASSIGN", linh, ["issueKey": "NW-12", "title": "Push notifications open the right issue", "url": "/work/northwind/NW/issue/12"], doc: false, -5),
            n(7, "WORK_COMMENT", scout, ["issueKey": "NW-12", "title": "Push notifications open the right issue", "excerpt": "Proposed fix attached — please review.",
                                        "url": "/work/northwind/NW/issue/12?comment=2"], doc: true, -29),
            n(6, "WORK_ALERT", nil, ["issueKey": "NW-21", "message": "is overdue", "url": "/work/northwind/NW/issue/21"], doc: true, -30),
            n(5, "WORK_INVITE", linh, ["workspaceName": "Northwind Studio", "url": "/work/northwind"], doc: true, -200),
        ], "pagination": ["nextCursor": NSNull(), "hasNextPage": false, "limit": 50], "unreadCount": 2]
    }
}
#endif
