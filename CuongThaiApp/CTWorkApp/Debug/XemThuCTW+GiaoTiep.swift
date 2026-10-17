#if DEBUG
import Foundation

// MARK: - Xem thử mảng GIAO TIẾP (Chat · Họp · Hộp thư) bằng máy chủ giả — CHỈ bản DEBUG
//
// Tên màn (`CT_XEM_MAN`):
//   chat2 (danh sách kênh) · kenhday (kênh đủ loại tin) · chuoi (chuỗi trả lời) · ttkenh (thông tin kênh)
//   taokenh (tạo nhóm riêng) · hop (lịch họp) · chitiethop (chi tiết họp) · taohop (tạo cuộc họp)
//   hopthu (hộp thư có phê duyệt) · hopthunhom (gộp theo thẻ/kênh) · caidattb (cài đặt thông báo)
//   traloinhanh (trả lời nhanh từ hộp thư)
// Dữ liệu viết THEO hình dạng backend (`chat.service.present`, `meetings.service.getMeeting`,
// `meetingRec.getRoom`, `notifications.routes`) — cũng là đầu vào kiểm thử giải mã.
// ⚠️ Cả tệp trong `#if DEBUG` (CLAUDE.md A6).

extension XemThuCTW {
    static let manGiaoTiep: Set<String> = ["chat2", "kenhday", "chuoi", "ttkenh", "taokenh", "hop", "chitiethop", "taohop",
                                           "hopthu", "hopthunhom", "caidattb", "traloinhanh"]

    /// Mô-đun mở sẵn trong trang dự án (iPhone) cho màn họp.
    static var moDunGiaoTiep: String? {
        guard let m = manGT, ["hop", "chitiethop", "taohop"].contains(m) else { return nil }
        return "meetings"
    }

    /// Màn đang xem thử thuộc mảng Giao tiếp (nil nếu không).
    static var manGT: String? {
        guard let m = man?.lowercased(), manGiaoTiep.contains(m) else { return nil }
        return m
    }

    /// Mở đúng chỗ cho màn của mảng Giao tiếp. Trả `true` nếu đã xử lý.
    @MainActor
    static func batGiaoTiep(_ app: AppState) -> Bool {
        guard let m = manGT else { return false }
        switch m {
        case "chat2", "taokenh": app.muc = .moDun("chat")
        case "kenhday", "chuoi", "ttkenh":
            app.muc = .moDun("chat")
            let t = m == "chuoi" ? "&t=404" : ""
            app.dichCho = DichMoDunCTW(moDun: "chat", pid: 7, duongDan: DuongDanCTW.tach("/work/northwind/NW/chat?c=1\(t)")!)
        case "hop", "taohop": app.muc = .moDun("meetings")
        case "chitiethop":
            app.muc = .moDun("meetings")
            app.dichCho = DichMoDunCTW(moDun: "meetings", pid: 7, duongDan: DuongDanCTW.tach("/work/northwind/NW/meetings/3")!)
        case "hopthunhom": UserDefaults.standard.set(true, forKey: "ctw.hopThu.gop"); app.muc = .hopThu
        default:
            UserDefaults.standard.set(false, forKey: "ctw.hopThu.gop")
            app.muc = .hopThu
        }
        UserDefaults.standard.set(m, forKey: "ctw.xemThu.man")
        return true
    }
}

enum DuLieuGiaGiaoTiep {
    typealias D = DuLieuGia

    private static func phanTu(_ a: [String], _ i: Int) -> String? { a.indices.contains(i) ? a[i] : nil }

    // swiftlint:disable:next cyclomatic_complexity
    static func route(_ m: String, _ p: String, _ b: [String: Any]) -> Any? {
        let pr = "/work/projects/7"
        switch (m, p) {
        case ("GET", "/social/notifications"): return thongBao
        case ("PATCH", "/social/notifications"): return ["updated": 1]
        case ("GET", "/work/chat/prefs"), ("PUT", "/work/chat/prefs"):
            return ["mutedUntil": NSNull(), "mutedForever": false, "notify": b["notify"] ?? "ALL", "sound": true, "desktop": true,
                    "emailDigest": b["emailDigest"] ?? false, "quietStart": 22, "quietEnd": 7, "quietNow": false]
        case ("GET", "/work/me/notify-settings"), ("PUT", "/work/me/notify-settings"):
            return ["emailMode": b["emailMode"] ?? "DIGEST", "quietStart": 22, "quietEnd": 7]
        default: break
        }
        guard p.hasPrefix(pr + "/") else { return nil }
        let c = String(p.dropFirst(pr.count))
        // ─ Chat ─
        if c == "/chat/channels" && m == "GET" { return kenh }
        if c == "/chat/channels" && m == "POST" { return ["id": 6, "name": b["name"] ?? "new-group", "kind": b["kind"] ?? "PRIVATE"] }
        if c.hasPrefix("/chat/channels/") {
            let phan = c.split(separator: "/").map(String.init)   // chat, channels, <cid>, …
            let cid = Int(phanTu(phan, 2) ?? "") ?? 1
            let duoi = Array(phan.dropFirst(3))
            switch (m, duoi.first ?? "") {
            case ("GET", "messages") where duoi.count == 1: return ["messages": tin(cid), "hasMoreBefore": cid == 1, "hasMoreAfter": false]
            case ("POST", "messages") where duoi.count == 1:
                return ["id": 900 + Int.random(in: 1...99), "channelId": cid, "kind": "USER", "body": b["body"] ?? "", "createdAt": D.iso(0),
                        "author": D.toi, "replyCount": 0, "parentId": b["parentId"] ?? NSNull(), "reactions": [Any](), "files": [Any]()]
            case ("GET", "messages") where duoi.count == 3 && duoi[2] == "thread":
                return ["root": tin(1).first { ($0["id"] as? Int) == 404 } ?? [:], "replies": traLoi]
            case ("GET", "messages") where duoi.count == 2:
                let mid = Int(duoi[1]) ?? 0
                return tin(cid).first { ($0["id"] as? Int) == mid } ?? tin(cid).last ?? [:]
            case ("PUT", "messages") where duoi.count >= 3 && duoi[2] == "reactions":
                return ["messageId": Int(duoi[1]) ?? 0, "reactions": [["emoji": "🎉", "count": 5, "mine": true], ["emoji": "👍", "count": 1, "mine": true]]]
            case ("PUT", "messages") where duoi.count == 3 && duoi[2] == "pin":
                return ["messageId": Int(duoi[1]) ?? 0, "pinned": b["pinned"] ?? true]
            case ("GET", "members"): return thanhVien
            case ("GET", "pinned"): return tin(1).filter { $0["pinned"] != nil }
            case ("GET", "search"): return tin(1).filter { (($0["body"] as? String) ?? "").localizedCaseInsensitiveContains("build") }
            case ("PUT", "notify"): return ["channelId": cid, "mutedUntil": NSNull(), "mutedForever": b["mute"] as? String == "forever", "notify": b["notify"] ?? "DEFAULT"]
            case ("POST", "read"): return ["channelId": cid, "lastReadId": 410]
            case ("POST", "call"): return ["url": "https://meet.jit.si/ctwork-demo4k2p9x", "reused": false, "messageId": 950]
            default: return nil
            }
        }
        if c.hasPrefix("/chat/files/"), c.hasSuffix("/url") { return ["url": "https://cuongthai.com/demo/file"] }
        // ─ Họp ─
        if c == "/meetings" && m == "GET" { return ["items": dsHop, "canEdit": true, "portalOn": false, "now": D.iso(0)] }
        if c == "/meetings" && m == "POST" { return chiTietHop(so: 9, tieuDe: b["title"] as? String) }
        if c.hasPrefix("/meetings/") {
            let phan = c.split(separator: "/").map(String.init)   // meetings, <n>, …
            let so = Int(phanTu(phan, 1) ?? "") ?? 3
            switch (m, phanTu(phan, 2) ?? "") {
            case ("GET", ""), ("PATCH", ""), ("PUT", "actions"), ("PUT", "attendees"): return chiTietHop(so: so, tieuDe: nil)
            case ("GET", "room"), ("POST", "rsvp"): return phongHop(rsvp: b["rsvp"] as? String)
            case ("GET", "transcript"): return banGhiLoi
            case ("POST", "join"): return ["url": "https://meet.google.com/abc-defg-hij", "attendance": "PRESENT"]
            case ("POST", "actions"): return ["created": [["actionId": 2, "number": 41, "key": "NW-41", "title": "Draft App Store review notes"]], "meeting": chiTietHop(so: so, tieuDe: nil)]
            default: return [String: Any]()
            }
        }
        if c.hasPrefix("/approvals/"), c.hasSuffix("/decide") { return ["id": 31, "status": "APPROVED"] }
        return nil
    }

    // MARK: Chat

    static let kenh: [String: Any] = [
        "channels": [
            ["id": 1, "name": "general", "topic": "Announcements and day-to-day chat", "kind": "PUBLIC", "isGeneral": true, "unread": 3, "mentions": 1, "badge": 3,
             "lastReadId": 405, "lastMessageAt": D.iso(0, gio: -0.2), "canPost": true, "canManage": true, "notify": "DEFAULT"],
            ["id": 2, "name": "ios-dev", "topic": "Builds, TestFlight, crashes", "kind": "PUBLIC", "unread": 1, "mentions": 0, "badge": 1,
             "lastMessageAt": D.iso(0, gio: -1), "canPost": true, "call": ["url": "https://meet.jit.si/ctwork-demo4k2p9x", "startedAt": D.iso(0, gio: -0.3)]],
            ["id": 3, "name": "design", "topic": "Figma links and reviews", "kind": "PUBLIC", "unread": 0, "badge": 0, "lastMessageAt": D.iso(-1), "canPost": true],
            ["id": 5, "name": "client-acme", "topic": "Shared with Acme Corp", "kind": "CLIENT", "unread": 0, "badge": 0, "lastMessageAt": D.iso(-3), "canPost": true],
            ["id": 4, "name": "leads", "topic": "Planning (private)", "kind": "PRIVATE", "unread": 0, "badge": 0, "muted": true, "mutedForever": true,
             "lastMessageAt": D.iso(-2), "canPost": true, "canManage": true],
            ["id": 6, "name": "alex-linh", "topic": NSNull(), "kind": "PRIVATE", "unread": 2, "mentions": 0, "badge": 2, "lastMessageAt": D.iso(0, gio: -0.5), "canPost": true]],
        "total": 6, "me": ["audience": "TEAM", "canCreate": true, "canCreateClient": true, "canModerate": true]]

    static var thanhVien: [[String: Any]] {
        [D.toi.merging(["role": "ADMIN", "online": true]) { $1 }, D.linh.merging(["role": "ADMIN", "online": true]) { $1 },
         D.minh.merging(["role": "MEMBER", "online": true]) { $1 }, D.an.merging(["role": "MEMBER", "online": false]) { $1 },
         D.sara.merging(["role": "VIEWER", "online": false]) { $1 }, D.scout.merging(["role": "MEMBER", "online": NSNull()]) { $1 }]
    }

    static func tin(_ cid: Int) -> [[String: Any]] {
        guard cid == 1 else {
            return [["id": 801, "channelId": cid, "kind": "USER", "body": "Can someone check the TestFlight crash on iPad?", "createdAt": D.iso(0, gio: -1), "author": D.minh, "reactions": [Any]()]]
        }
        return [
            ["id": 398, "channelId": 1, "kind": "USER", "body": "Sprint 6 demo deck is in **Docs → Release plan**. Comments welcome before Friday.",
             "createdAt": D.iso(-1, gio: -4), "author": D.linh, "reactions": [["emoji": "👀", "count": 3, "mine": false]],
             "previews": [["t": "doc", "key": "DOC-3", "n": 3, "url": "/work/northwind/NW/docs/3", "title": "Release plan — v1.0"]]],
            ["id": 399, "channelId": 1, "kind": "USER", "body": "Here's the new onboarding flow 👇", "createdAt": D.iso(-1, gio: -3.9), "author": D.an,
             "files": [["id": 71, "fileName": "onboarding-1.jpg", "mime": "image/jpeg", "size": 412_000, "createdAt": D.iso(-1)],
                       ["id": 72, "fileName": "onboarding-2.jpg", "mime": "image/jpeg", "size": 398_000, "createdAt": D.iso(-1)]],
             "reactions": [["emoji": "😍", "count": 2, "mine": true], ["emoji": "🔥", "count": 1, "mine": false]]],
            ["id": 401, "channelId": 1, "kind": "SYSTEM", "body": "started a call", "createdAt": D.iso(0, gio: -6), "author": D.linh,
             "meta": ["type": "call", "url": "https://meet.jit.si/ctwork-demo4k2p9x"]],
            ["id": 402, "channelId": 1, "kind": "USER", "body": "Morning team! Beta build **1.0 (14)** is on TestFlight 🎉", "createdAt": D.iso(0, gio: -5), "author": D.linh,
             "reactions": [["emoji": "🎉", "count": 4, "mine": true], ["emoji": "🚀", "count": 2, "mine": false]],
             "pinned": ["at": D.iso(0, gio: -4.8), "byId": 2]],
            ["id": 403, "channelId": 1, "kind": "USER", "body": "Thanks @linh — installing now. Release notes attached.", "createdAt": D.iso(0, gio: -4.9), "author": D.minh,
             "mentions": [2], "files": [["id": 73, "fileName": "release-notes-1.0.pdf", "mime": "application/pdf", "size": 182_400, "createdAt": D.iso(0)]]],
            ["id": 404, "channelId": 1, "kind": "USER", "body": "I summarised yesterday's crash reports in NW-14: 3 of 5 come from HEIC attachments on iOS 17.", "createdAt": D.iso(0, gio: -3), "author": D.scout,
             "previews": [["t": "issue", "key": "NW-14", "n": 14, "url": "/work/northwind/NW/issue/14", "title": "Crash when attaching a HEIC photo on iOS 17"]],
             "replyCount": 2, "lastReplyAt": D.iso(0, gio: -2.7)],
            ["id": 405, "channelId": 1, "kind": "USER", "body": "", "createdAt": D.iso(0, gio: -2.8), "author": D.an,
             "files": [["id": 74, "fileName": "voice-note-20261018.m4a", "mime": "audio/mp4", "size": 96_000, "createdAt": D.iso(0),
                        "voice": ["durationMs": 23_000, "transcriptStatus": "DONE", "language": "en",
                                  "transcript": "Quick update from the client call: they're happy with the beta, and they'd like the iPad layout in the next build."]]]],
            ["id": 406, "channelId": 1, "kind": "USER", "body": "Nice catch. @alex can you take a look after standup?", "createdAt": D.iso(0, gio: -2.5), "author": D.an, "mentions": [1]],
            ["id": 407, "channelId": 1, "kind": "USER", "body": "Yes — picking it up now. Design ref: https://www.figma.com/file/northwind", "createdAt": D.iso(0, gio: -2.4), "author": D.toi,
             "editedAt": D.iso(0, gio: -2.3), "links": [["url": "https://www.figma.com/file/northwind", "domain": "figma.com", "title": "Northwind — App screens"]]],
        ]
    }

    static var traLoi: [[String: Any]] {
        [["id": 420, "channelId": 1, "parentId": 404, "kind": "USER", "body": "Repro steps added to the issue. Happens only with Live Photos.", "createdAt": D.iso(0, gio: -2.9), "author": D.minh],
         ["id": 421, "channelId": 1, "parentId": 404, "kind": "USER", "body": "Converting to JPEG before upload fixes it in my test build.", "createdAt": D.iso(0, gio: -2.7), "author": D.scout,
          "reactions": [["emoji": "✅", "count": 2, "mine": true]]]]
    }

    // MARK: Họp

    static func hop(_ so: Int, _ t: String, type: String, nhan: String, ngay: Double, gio: Double, phut: Double, url: String?, ng: [[String: Any]], mo: Int = 0, st: String = "SCHEDULED") -> [String: Any] {
        ["id": 300 + so, "number": so, "key": "M-\(so)", "title": t, "type": type, "typeLabel": nhan, "status": st,
         "startsAt": D.iso(ngay, gio: gio), "endsAt": D.iso(ngay, gio: gio + phut / 60), "timezone": "Asia/Ho_Chi_Minh",
         "location": url == nil ? "Room 4.02" : NSNull(), "meetingUrl": url ?? NSNull(),
         "provider": url.map { $0.contains("google") ? "MEET" : ($0.contains("zoom") ? "ZOOM" : "JITSI") } ?? NSNull(),
         "organizer": D.linh, "attendees": ng, "actionCount": mo + 1, "actionsOpen": mo, "minutesShared": false]
    }

    static var dsHop: [[String: Any]] {
        // Giờ tương đối: cuộc đầu đang diễn ra (−5 phút) ⇒ nút Join nổi.
        let bay = Calendar.current.component(.hour, from: Date())
        let lech = -Double(bay) - Double(Calendar.current.component(.minute, from: Date())) / 60
        return [
            hop(3, "Sprint 6 review & demo", type: "DEMO", nhan: "Demo", ngay: 0, gio: -0.08, phut: 45, url: "https://meet.google.com/abc-defg-hij", ng: [D.toi, D.linh, D.minh, D.an, D.sara], mo: 2),
            hop(4, "Daily stand-up", type: "DAILY", nhan: "Daily stand-up", ngay: 1, gio: lech + 9, phut: 15, url: "https://meet.jit.si/ctwork-demo4k2p9x", ng: [D.toi, D.linh, D.minh, D.an]),
            hop(5, "Client check-in — Acme", type: "CLIENT", nhan: "Client meeting", ngay: 2, gio: lech + 14, phut: 30, url: "https://acme.zoom.us/j/123456789", ng: [D.toi, D.linh, D.sara]),
            hop(6, "Sprint 7 planning", type: "PLANNING", nhan: "Sprint planning", ngay: 4, gio: lech + 10, phut: 90, url: nil, ng: [D.toi, D.linh, D.minh, D.an, D.sara, D.scout], mo: 0),
            hop(7, "Retro", type: "RETRO", nhan: "Retrospective", ngay: 4, gio: lech + 15, phut: 45, url: "https://meet.jit.si/ctwork-retro", ng: [D.toi, D.linh, D.minh], st: "CANCELLED"),
        ]
    }

    static func chiTietHop(so: Int, tieuDe: String?) -> [String: Any] {
        var h = dsHop.first { ($0["number"] as? Int) == so } ?? dsHop[0]
        if let tieuDe { h["title"] = tieuDe }
        h["attendees"] = [D.toi, D.linh, D.minh, D.an.merging(["isClient": false]) { $1 }, D.sara.merging(["isClient": true]) { $1 }]
        h["agendaJson"] = D.doc(["Demo: push notifications deep links", "Demo: iPad split view", "Release blockers"])
        h["minutesJson"] = ["type": "doc", "content": [
            ["type": "heading", "attrs": ["level": 3], "content": [["type": "text", "text": "Summary"]]],
            ["type": "paragraph", "content": [["type": "text", "text": "Beta 1.0 (14) is stable. Deep links from notifications work, including cold start. "],
                                              ["type": "text", "text": "iPad split view", "marks": [["type": "bold"]]],
                                              ["type": "text", "text": " needs one more pass on the sidebar."]]],
            ["type": "bulletList", "content": [
                ["type": "listItem", "content": [["type": "paragraph", "content": [["type": "text", "text": "Crash on HEIC attachments: fixed in 1.0 (15)"]]]]],
                ["type": "listItem", "content": [["type": "paragraph", "content": [["type": "text", "text": "Store screenshots: light + dark, iPhone and iPad"]]]]]]]]]
        h["decisions"] = ["Ship the public beta on Monday", "Freeze features after Sprint 7 planning"]
        h["version"] = 5
        h["actions"] = [
            ["id": 1, "position": 0, "text": "Fix sidebar collapse on iPad mini", "dueDate": D.ngay(2), "assignee": D.toi,
             "issue": ["number": 19, "key": "NW-19", "title": "iPad split view layout", "done": false, "status": ["name": "In Progress", "category": "IN_PROGRESS"]]],
            ["id": 2, "position": 1, "text": "Draft App Store review notes", "dueDate": D.ngay(3), "assignee": D.an, "issue": NSNull()],
            ["id": 3, "position": 2, "text": "Collect beta feedback from Acme", "dueDate": NSNull(), "assignee": D.sara, "issue": NSNull()]]
        h["previous"] = ["number": 1, "title": "Sprint 5 review", "startsAt": D.iso(-14)]
        h["next"] = [Any]()
        h["canEdit"] = true
        h["canDelete"] = true
        h["canCreateIssues"] = true
        h["hasClients"] = true
        return h
    }

    static func phongHop(rsvp: String?) -> [String: Any] {
        func a(_ u: [String: Any], _ r: String?, _ at: String?, coMat: Bool = false) -> [String: Any] {
            ["userId": u["id"] ?? 0, "invited": true, "rsvp": r ?? NSNull(), "attendance": at ?? NSNull(), "present": coMat, "user": u]
        }
        return [
            "number": 3, "meId": 1, "agendaMinutes": 40, "recordingUrl": NSNull(), "tracked": true,
            "agenda": [["id": "a1", "title": "Demo: push notification deep links", "presenterId": 1, "minutes": 15],
                       ["id": "a2", "title": "Demo: iPad split view", "presenterId": 3, "minutes": 15],
                       ["id": "a3", "title": "Release blockers & go/no-go", "presenterId": 2, "minutes": 10]],
            "attendees": [a(D.toi, rsvp ?? "YES", "PRESENT", coMat: true), a(D.linh, "YES", "PRESENT", coMat: true), a(D.minh, "MAYBE", nil),
                          a(D.an, "YES", "LATE"), a(D.sara, "NO", nil)],
            "me": ["rsvp": rsvp ?? "YES", "invited": true, "present": true, "attendance": "PRESENT"],
            "recordings": [["id": 1, "source": "LIVE", "status": "DONE", "durationMs": 1_800_000, "startedAt": D.iso(-1)]],
            "drafts": [["id": 8, "status": "PROPOSED", "language": "en", "createdAt": D.iso(0, gio: -0.5),
                        "content": ["summary": "The team reviewed beta 1.0 (14) and agreed to ship the public beta once the iPad sidebar fix lands.",
                                    "decisions": [["text": "Public beta ships Monday", "unsupported": false]],
                                    "actions": [["text": "Fix iPad sidebar collapse", "ownerId": 1, "ownerName": "Alex Morgan", "due": D.ngay(2), "unsupported": false],
                                                ["text": "Prepare store screenshots", "ownerId": NSNull(), "ownerName": NSNull(), "due": NSNull(), "unsupported": true]],
                                    "openIssues": [["text": "Do we need a separate iPad onboarding?", "unsupported": false]],
                                    "unsupportedCount": 1, "lineCount": 214, "truncated": false]]],
            "can": ["edit": true, "chair": true, "record": true, "ai": true],
        ]
    }

    static var banGhiLoi: [String: Any] {
        ["recordings": [["id": 1, "source": "LIVE", "fileName": NSNull(), "startedAt": D.iso(-1), "lines": [
            ["id": "0.0", "n": 1, "startMs": 0, "endMs": 4000, "text": "Okay, let's start with the notification deep links.", "speakerId": 2, "seq": 0, "at": "00:00"],
            ["id": "0.1", "n": 2, "startMs": 4000, "endMs": 11000, "text": "Tapping a mention now opens the exact chat thread, even from a cold start.", "speakerId": 1, "seq": 0, "at": "00:04"],
            ["id": "0.2", "n": 3, "startMs": 11000, "endMs": 16000, "text": "Great. What's left for the iPad layout?", "speakerId": 2, "seq": 0, "at": "00:11"]]]],
         "speakers": [D.toi, D.linh]]
    }

    // MARK: Hộp thư

    static var thongBao: [String: Any] {
        func n(_ id: Int, _ t: String, _ s: [String: Any]?, _ p: [String: Any], doc: Bool, _ h: Double) -> [String: Any] {
            ["id": id, "type": t, "entityId": 112, "secondaryEntityId": NSNull(), "isRead": doc, "createdAt": D.iso(0, gio: h),
             "sender": s ?? NSNull(), "payload": p.merging(["surface": "work"]) { $1 }]
        }
        return ["items": [
            n(12, "WORK_ALERT", D.linh, ["issueKey": "NW · DOC-3", "title": "Release plan — v1.0", "message": "Your approval is requested: Release plan — v1.0",
                                         "url": "/work/northwind/NW/docs/3", "approvalId": 31], doc: false, -0.3),
            n(11, "WORK_MENTION", D.an, ["chat": true, "issueKey": "#general", "title": "NW · Mobile App Launch", "excerpt": "@alex can you take a look after standup?",
                                         "url": "/work/northwind/NW/chat?c=1&m=406"], doc: false, -2.5),
            n(10, "WORK_COMMENT", D.scout, ["chat": true, "reply": true, "issueKey": "#general", "title": "NW · Mobile App Launch",
                                            "excerpt": "Converting to JPEG before upload fixes it in my test build.", "url": "/work/northwind/NW/chat?c=1&m=421&t=404"], doc: false, -2.7),
            n(8, "WORK_ASSIGN", D.linh, ["issueKey": "NW-12", "title": "Push notifications open the right issue", "url": "/work/northwind/NW/issue/12"], doc: false, -5),
            n(7, "WORK_COMMENT", D.minh, ["issueKey": "NW-12", "title": "Push notifications open the right issue", "excerpt": "Cold start works on my device too.",
                                          "url": "/work/northwind/NW/issue/12?comment=3"], doc: true, -29),
            n(6, "WORK_ALERT", nil, ["issueKey": "NW-21", "message": "is overdue", "url": "/work/northwind/NW/issue/21"], doc: true, -30),
            n(5, "WORK_ALERT", D.minh, ["issueKey": "NW · M-3", "title": "Sprint 6 review & demo", "message": "Minh Pham replied Maybe", "url": "/work/northwind/NW/meetings/3"], doc: true, -40),
            n(4, "WORK_INVITE", D.linh, ["workspaceName": "Northwind Studio", "url": "/work/northwind"], doc: true, -200),
        ], "pagination": ["nextCursor": NSNull(), "hasNextPage": false, "limit": 50], "unreadCount": 4]
    }
}
#endif
