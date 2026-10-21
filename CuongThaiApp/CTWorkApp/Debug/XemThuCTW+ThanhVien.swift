#if DEBUG
import Foundation

// MARK: - Dữ liệu mẫu mảng Thành viên + Tin nhắn riêng (21/10/2026)
//
// Đúng HÌNH DẠNG máy chủ: `/work/me/people` (people.service.ts › listPeople), `/messages/*` (messages.service.ts —
// `serializeThreadAsync` có `peer`, `serializeMessage`, `listThreadReads`). Màn thử:
//   mod:thanh-vien · mod:thanh-vien/hoso · mod:tin-nhan · mod:tin-nhan/chat · account (công tắc trạng thái)
//   + `CT_XEM_TAT_TT=1` ⇒ người xem đã tắt trạng thái hoạt động (máy chủ ẩn trạng thái của mọi người).

enum DuLieuGiaThanhVien {
    nonisolated(unsafe) static var hienTrangThai = ProcessInfo.processInfo.environment["CT_XEM_TAT_TT"] != "1"
    nonisolated(unsafe) static var tinGui: [[String: Any]] = []

    static func iso(phut: Double) -> String { DuLieuGia.iso(0, gio: -phut / 60) }

    static func nguoi(_ id: Int, _ u: String, _ ten: String, vai: String, ws: [(Int, String, String)], duAn: [String],
                      online: Bool, phut: Double?, an: Bool = false, agent: Bool = false) -> [String: Any] {
        let hien = hienTrangThai && !an && !agent
        return [
            "id": id, "username": u, "fullName": ten, "displayName": NSNull(), "avatarUrl": NSNull(), "kind": agent ? "AGENT" : "HUMAN",
            "workspaces": ws.map { ["id": $0.0, "name": $0.1, "slug": $0.2, "role": vai] },
            "projects": duAn.enumerated().map { ["id": 7 + $0.offset, "key": $0.element, "name": $0.element == "NW" ? "Mobile App Launch" : "Marketing Website", "role": "MEMBER"] },
            "blocked": false,
            "presence": ["visible": hien, "online": hien && online,
                         "lastActiveAt": hien ? (phut.map { iso(phut: $0) } as Any? ?? NSNull()) : NSNull()],
        ]
    }

    static var danhBa: [String: Any] {
        let nw = (1, "Northwind Studio", "northwind"), swp = (2, "SWP391 · Group 4", "swp391-g4")
        return ["viewerShowsActiveStatus": hienTrangThai, "people": [
            nguoi(2, "linh", "Linh Tran", vai: "ADMIN", ws: [nw, swp], duAn: ["NW", "WEB"], online: true, phut: 0.2),
            nguoi(5, "sara", "Sara Kim", vai: "MEMBER", ws: [nw], duAn: ["NW"], online: true, phut: 0.5),
            nguoi(3, "minh", "Minh Pham", vai: "MEMBER", ws: [nw], duAn: ["NW"], online: false, phut: 5),
            nguoi(4, "an", "An Nguyen", vai: "MEMBER", ws: [nw, swp], duAn: ["NW"], online: false, phut: 125),
            nguoi(6, "khoa", "Khoa Le", vai: "MEMBER", ws: [swp], duAn: [], online: false, phut: 60 * 26),
            nguoi(7, "tu", "Anh Tu Vo", vai: "GUEST", ws: [swp], duAn: [], online: false, phut: 60, an: true),
            nguoi(9, "scout", "Scout", vai: "MEMBER", ws: [nw], duAn: ["NW"], online: false, phut: nil, agent: true),
        ]]
    }

    static func peer(_ id: Int, _ u: String, _ ten: String, phut: Double?) -> [String: Any] {
        ["id": id, "username": u, "displayName": ten, "avatarUrl": NSNull(), "alias": NSNull(),
         "lastActiveAt": hienTrangThai ? (phut.map { iso(phut: $0) } as Any? ?? NSNull()) : NSNull()]
    }

    static func tin(_ id: Int, _ tu: Int, _ chu: String, phut: Double, anh: String? = nil, tep: (String, Int)? = nil,
                    traLoi: (Int, String)? = nil, camXuc: [(String, [Int])] = [], thuHoi: Bool = false, thread: Int = 101) -> [String: Any] {
        var at: [[String: Any]] = []
        if let anh { at.append(["id": id * 10, "fileId": id * 10, "mimeType": "image/jpeg", "fileName": "photo.jpg", "fileSize": 182_000, "url": anh, "thumbnailUrl": NSNull()]) }
        if let tep { at.append(["id": id * 10 + 1, "fileId": id * 10 + 1, "mimeType": "application/pdf", "fileName": tep.0, "fileSize": tep.1, "url": "https://media.cuongthai.com/chat/\(tep.0)", "thumbnailUrl": NSNull()]) }
        return [
            "id": id, "threadId": thread, "senderId": tu, "content": thuHoi ? "" : chu, "mediaUrl": NSNull(), "mediaKind": NSNull(),
            "deleted": false, "recalled": thuHoi, "createdAt": iso(phut: phut), "attachments": at,
            "parentMessageId": traLoi?.0 ?? NSNull(),
            "parentMessage": traLoi.map { ["id": $0.0, "senderId": 2, "senderName": "Linh Tran", "content": $0.1] } as Any? ?? NSNull(),
            "reactions": camXuc.map { ["emoji": $0.0, "count": $0.1.count, "userIds": $0.1] },
        ]
    }

    static var tinNhan: [[String: Any]] {
        [
            tin(1001, 2, "Chào Alex, sprint review chiều nay dời sang 4h nha 🙏", phut: 95),
            tin(1002, 1, "Ok chị, em cập nhật lại slide demo luôn", phut: 93, camXuc: [("❤️", [2])]),
            tin(1003, 2, "Đây là màn login mới bên design gửi", phut: 40, anh: "https://picsum.photos/id/180/800/600"),
            tin(1004, 2, "Em xem giúp chị flow quên mật khẩu với", phut: 39),
            tin(1005, 1, "Bản đặc tả em vừa sửa xong, chị xem phần 3.2 nhé", phut: 12, tep: ("SRS-v1.3.pdf", 1_240_000),
                traLoi: (1004, "Em xem giúp chị flow quên mật khẩu với")),
            tin(1006, 1, "", phut: 11, thuHoi: true),
            tin(1007, 2, "Đã xem, ổn rồi. Merge PR #42 đi em 👍", phut: 3, camXuc: [("👍", [1])]),
            tin(1008, 1, "Dạ em merge liền", phut: 2),
        ] + tinGui
    }

    static var hoiThoai: [[String: Any]] {
        [
            ["id": 101, "type": "USER", "peer": peer(2, "linh", "Linh Tran", phut: 0.2), "unreadCount": 0, "createdAt": iso(phut: 6000),
             "updatedAt": iso(phut: 2), "preferences": NSNull(), "lastMessage": tinNhan.last as Any],
            ["id": 102, "type": "USER", "peer": peer(3, "minh", "Minh Pham", phut: 5), "unreadCount": 2, "createdAt": iso(phut: 9000),
             "updatedAt": iso(phut: 18), "preferences": NSNull(),
             "lastMessage": tin(2002, 3, "Anh ơi API /bookings trả 500 khi thiếu slotId", phut: 18, thread: 102)],
            ["id": 103, "type": "USER", "peer": peer(4, "an", "An Nguyen", phut: 125), "unreadCount": 0, "createdAt": iso(phut: 9000),
             "updatedAt": iso(phut: 60 * 20), "preferences": NSNull(),
             "lastMessage": tin(3001, 1, "Mai họp nhóm lúc 9h nhé", phut: 60 * 20, thread: 103)],
            ["id": 104, "type": "USER", "peer": peer(6, "khoa", "Khoa Le", phut: 60 * 26), "unreadCount": 0, "createdAt": iso(phut: 90000),
             "updatedAt": iso(phut: 60 * 50), "preferences": NSNull(),
             "lastMessage": tin(4001, 6, "", phut: 60 * 50, anh: "https://picsum.photos/id/1/400/300", thread: 104)],
        ]
    }

    static func route(_ m: String, _ p: String, _ b: [String: Any]) -> Any? {
        switch (m, p) {
        case ("GET", "/work/me/people"): return danhBa
        case ("GET", "/messages/threads"): return hoiThoai
        case ("GET", "/messages/unread-count"): return ["count": 2]
        case ("POST", "/users/status"): return ["ok": true]
        case ("POST", "/messages/upload"):
            return ["fileId": 9001, "url": "https://picsum.photos/id/180/800/600", "fileName": "photo-1.jpg", "fileSize": 120_000, "mimeType": "image/jpeg"]
        case ("GET", "/profile"):
            return ["id": 1, "username": "alex", "email": "alex@northwind.example", "fullName": "Alex Morgan", "displayName": NSNull(),
                    "avatarUrl": NSNull(), "showActiveStatus": hienTrangThai]
        case ("PUT", "/profile"):
            if let v = b["showActiveStatus"] as? Bool { hienTrangThai = v }
            return ["id": 1, "username": "alex", "showActiveStatus": hienTrangThai]
        default: break
        }
        guard p.hasPrefix("/messages/"), p != "/messages/blocks" else { return nil }
        let phan = p.split(separator: "/").map(String.init)   // ["messages","threads","101","messages"]
        if phan.count >= 4, phan[1] == "threads", phan[2] == "user", let ai = Int(phan[3]) {
            return hoiThoai.first { (($0["peer"] as? [String: Any])?["id"] as? Int) == ai } ?? hoiThoai[0]
        }
        if phan.count >= 3, phan[1] == "threads", let tid = Int(phan[2]) {
            if phan.count == 3 { return hoiThoai.first { ($0["id"] as? Int) == tid } ?? hoiThoai[0] }
            switch (m, phan[3]) {
            case ("GET", "messages"): return tid == 101 ? tinNhan : [Any]()
            case ("POST", "messages"):
                let moi = tin(5000 + tinGui.count, 1, b["content"] as? String ?? "", phut: 0)
                tinGui.append(moi)
                return moi
            case ("GET", "reads"): return [["userId": 2, "lastReadAt": iso(phut: 1)], ["userId": 1, "lastReadAt": iso(phut: 0)]]
            default: return ["ok": true]
            }
        }
        return ["ok": true]   // reactions, recall, report, blocks…
    }
}
#endif
