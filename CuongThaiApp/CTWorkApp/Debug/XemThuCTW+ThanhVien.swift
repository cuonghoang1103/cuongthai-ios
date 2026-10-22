#if DEBUG
import Foundation
import UIKit
import ImageIO
import UniformTypeIdentifiers

// MARK: - Dữ liệu mẫu mảng Thành viên + Tin nhắn riêng + Hồ sơ (21–22/10/2026)
//
// Đúng HÌNH DẠNG máy chủ: `/work/me/people` (people.service.ts › listPeople), `/messages/*` (messages.service.ts —
// `serializeThreadAsync` có `peer`, `serializeMessage`, `listThreadReads`), `/gifs` (gifs.routes.ts — mảng, `offset`),
// `/stickers/packs*` (sticker.service.ts), `/users/:id` (getEnhancedPublicProfile), `/files/upload`. Màn thử:
//   mod:thanh-vien · mod:thanh-vien/hoso · mod:tin-nhan · mod:tin-nhan/chat · account · hoso (Hồ sơ của tôi)
//   + `CT_XEM_TAT_TT=1` ⇒ người xem đã tắt trạng thái hoạt động (máy chủ ẩn trạng thái của mọi người)
//   + `CT_XEM_DM=giu|traloi|gif|info|camxuc` (mở sẵn trong chat) · `CT_XEM_DM_GO=1` (người kia đang nhập)
//   + `CT_XEM_ANH_MAU=1` (Đổi ảnh ⇒ ảnh mẫu thay bảng chọn ảnh của hệ thống).
// GIF/nhãn dán mẫu do app TỰ VẼ (`/api/v1/__gia/gif|sticker/<n>`) — không dùng GIF của người thật trong ảnh chụp.

enum DuLieuGiaThanhVien {
    nonisolated(unsafe) static var hienTrangThai = ProcessInfo.processInfo.environment["CT_XEM_TAT_TT"] != "1"
    nonisolated(unsafe) static var tinGui: [[String: Any]] = []
    nonisolated(unsafe) static var hoSo: [String: Any] = [
        "id": 1, "username": "alex", "email": "alex@northwind.example", "fullName": "Alex Morgan", "displayName": NSNull(),
        "avatarUrl": NSNull(), "coverPhotoUrl": NSNull(),
        "bio": "Mobile lead at Northwind. iOS + design systems. Coffee first ☕️", "showActiveStatus": true,
    ]

    static func iso(phut: Double) -> String { DuLieuGia.iso(0, gio: -phut / 60) }
    static let goc = "https://cuongthai.com/api/v1/__gia"

    static func nguoi(_ id: Int, _ u: String, _ ten: String, vai: String, ws: [(Int, String, String)], duAn: [String],
                      online: Bool, phut: Double?, an: Bool = false, agent: Bool = false) -> [String: Any] {
        let hien = hienTrangThai && !an && !agent
        return [
            "id": id, "username": u, "fullName": ten, "displayName": NSNull(), "avatarUrl": NSNull(), "kind": agent ? "AGENT" : "HUMAN",
            "workspaces": ws.map { ["id": $0.0, "name": $0.1, "slug": $0.2, "role": vai] },
            "projects": duAn.enumerated().map { ["id": 7 + $0.offset, "key": $0.element, "name": $0.element == "NW" ? "Mobile App Launch" : "Marketing Website", "role": $0.offset == 0 && vai == "ADMIN" ? "ADMIN" : "MEMBER"] },
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
                    traLoi: (Int, Int, String)? = nil, camXuc: [(String, [Int])] = [], thuHoi: Bool = false, thread: Int = 101,
                    media: (String, String)? = nil, thoai: Bool = false) -> [String: Any] {
        var at: [[String: Any]] = []
        if let anh { at.append(["id": id * 10, "fileId": id * 10, "mimeType": "image/jpeg", "fileName": "photo.jpg", "fileSize": 182_000, "url": anh, "thumbnailUrl": NSNull()]) }
        if let tep { at.append(["id": id * 10 + 1, "fileId": id * 10 + 1, "mimeType": "application/pdf", "fileName": tep.0, "fileSize": tep.1, "url": "https://media.cuongthai.com/chat/\(tep.0)", "thumbnailUrl": NSNull()]) }
        if thoai { at.append(["id": id * 10 + 2, "fileId": id * 10 + 2, "mimeType": "audio/mp4", "fileName": "voice.m4a", "fileSize": 96_000, "url": "\(goc)/voice/\(id).m4a", "thumbnailUrl": NSNull()]) }
        return [
            "id": id, "threadId": thread, "senderId": tu, "content": thuHoi ? "" : chu,
            "mediaUrl": thuHoi ? NSNull() : (media?.0 as Any? ?? NSNull()), "mediaKind": thuHoi ? NSNull() : (media?.1 as Any? ?? NSNull()),
            "deleted": false, "recalled": thuHoi, "createdAt": iso(phut: phut), "attachments": thuHoi ? [] : at,
            "parentMessageId": traLoi?.0 ?? NSNull(),
            "parentMessage": traLoi.map { ["id": $0.0, "senderId": $0.1, "senderName": $0.1 == 2 ? "Linh Tran" : "Alex Morgan", "content": $0.2] } as Any? ?? NSNull(),
            "reactions": camXuc.map { ["emoji": $0.0, "count": $0.1.count, "userIds": $0.1] },
        ]
    }

    /// Hội thoại với Linh: hôm qua → hôm nay; có nhóm liên tiếp, ảnh, trả lời + tệp, thu hồi, tin thoại, GIF, link, emoji lớn.
    static var tinNhan: [[String: Any]] {
        [
            tin(1001, 2, "Chào Alex, sprint review chiều nay dời sang 4h nha 🙏", phut: 60 * 26),
            tin(1002, 1, "Ok chị, em cập nhật lại slide demo luôn", phut: 60 * 26 - 1, camXuc: [("❤️", [2])]),
            tin(1003, 2, "", phut: 95, anh: "https://picsum.photos/id/180/800/600"),
            tin(1004, 2, "Đây là màn login mới bên design gửi", phut: 94.6),
            tin(1005, 2, "Em xem giúp chị flow quên mật khẩu với, nhất là bước nhập OTP", phut: 94.2),
            tin(1006, 1, "", phut: 41, thuHoi: true),
            tin(1007, 1, "Bản đặc tả em vừa sửa xong, chị xem phần 3.2 nhé", phut: 40.5, tep: ("SRS-v1.3.pdf", 1_240_000),
                traLoi: (1005, 2, "Em xem giúp chị flow quên mật khẩu với, nhất là bước nhập OTP")),
            tin(1008, 1, "", phut: 40, thoai: true),
            tin(1009, 2, "", phut: 12, media: ("\(goc)/gif/3.gif", "gif")),
            tin(1010, 2, "Đã xem, ổn rồi. Merge PR #42 đi em 👍", phut: 11.6, camXuc: [("👍", [1]), ("😂", [1])]),
            tin(1011, 1, "Dạ em merge liền", phut: 3),
            tin(1012, 1, "Thẻ ở đây nha chị: https://cuongthai.com/work/northwind/NW/issue/42", phut: 2.6),
            tin(1013, 1, "🚀", phut: 2),
        ] + tinGui
    }

    static var hoiThoai: [[String: Any]] {
        [
            ["id": 101, "type": "USER", "peer": peer(2, "linh", "Linh Tran", phut: 0.2), "unreadCount": 0, "createdAt": iso(phut: 6000),
             "updatedAt": iso(phut: 2), "preferences": ["pinnedAt": iso(phut: 600)], "lastMessage": tinNhan.last as Any],
            ["id": 102, "type": "USER", "peer": peer(3, "minh", "Minh Pham", phut: 5), "unreadCount": 2, "createdAt": iso(phut: 9000),
             "updatedAt": iso(phut: 18), "preferences": NSNull(),
             "lastMessage": tin(2002, 3, "Anh ơi API /bookings trả 500 khi thiếu slotId", phut: 18, thread: 102)],
            ["id": 105, "type": "USER", "peer": peer(5, "sara", "Sara Kim", phut: 0.5), "unreadCount": 0, "createdAt": iso(phut: 9000),
             "updatedAt": iso(phut: 50), "preferences": NSNull(),
             "lastMessage": tin(5001, 5, "", phut: 50, thread: 105, media: ("\(goc)/gif/1.gif", "gif"))],
            ["id": 103, "type": "USER", "peer": peer(4, "an", "An Nguyen", phut: 125), "unreadCount": 0, "createdAt": iso(phut: 9000),
             "updatedAt": iso(phut: 60 * 20), "preferences": ["mutedUntil": DuLieuGia.iso(30)],
             "lastMessage": tin(3001, 1, "Mai họp nhóm lúc 9h nhé", phut: 60 * 20, thread: 103)],
            ["id": 104, "type": "USER", "peer": peer(6, "khoa", "Khoa Le", phut: 60 * 26), "unreadCount": 0, "createdAt": iso(phut: 90000),
             "updatedAt": iso(phut: 60 * 50), "preferences": NSNull(),
             "lastMessage": tin(4001, 6, "", phut: 60 * 50, anh: "https://picsum.photos/id/1/400/300", thread: 104)],
            ["id": 106, "type": "USER", "peer": peer(7, "tu", "Anh Tu Vo", phut: nil), "unreadCount": 0, "createdAt": iso(phut: 90000),
             "updatedAt": iso(phut: 60 * 24 * 12), "preferences": NSNull(),
             "lastMessage": tin(6001, 7, "", phut: 60 * 24 * 12, thread: 106, thoai: true)],
        ]
    }

    static let tenGif = ["Ship it!", "LGTM", "On it 🙌", "Done ✅", "Coffee?", "Brb", "Nice!", "Thanks!", "Good morning", "Bug found 🐛",
                         "Deploying…", "Yay!"]

    static func gifs(offset: Int) -> [[String: Any]] {
        let n = offset >= 48 ? 10 : 24   // trang thứ ba ngắn ⇒ client biết đã hết
        return (0..<n).map { i in
            let k = offset + i
            return ["id": "gia\(k)", "url": "\(goc)/gif/\(k).gif", "previewUrl": "\(goc)/gif/\(k).gif"]
        }
    }

    static func route(_ m: String, _ p: String, _ b: [String: Any]) -> Any? {
        switch (m, p) {
        case ("GET", "/work/me/people"): return danhBa
        case ("GET", "/messages/threads"): return hoiThoai
        case ("GET", "/messages/unread-count"): return ["count": 2]
        case ("POST", "/users/status"): return ["ok": true]
        case ("POST", "/messages/upload"):
            return ["fileId": 9001, "url": "https://picsum.photos/id/180/800/600", "fileName": "photo-1.jpg", "fileSize": 120_000, "mimeType": "image/jpeg"]
        case ("POST", "/files/upload"):
            return ["url": "https://picsum.photos/id/64/600/600", "key": "avatars/gia.jpg"]
        case ("GET", "/gifs"):
            return gifs(offset: Int(b["offset"] as? String ?? "") ?? 0)
        case ("GET", "/stickers/packs"):
            return [["id": 1, "slug": "ctwork", "name": "CT Work", "coverUrl": "\(goc)/sticker/0.png", "stickerCount": 8],
                    ["id": 2, "slug": "cam-xuc", "name": "Cảm xúc", "coverUrl": "\(goc)/sticker/4.png", "stickerCount": 8]]
        case ("GET", "/profile"):
            var h = hoSo; h["showActiveStatus"] = hienTrangThai
            return h
        case ("PUT", "/profile"):
            if let v = b["showActiveStatus"] as? Bool { hienTrangThai = v }
            for k in ["avatarUrl", "coverPhotoUrl", "bio", "displayName"] where b.keys.contains(k) { hoSo[k] = b[k] }
            var h = hoSo; h["showActiveStatus"] = hienTrangThai
            return h
        default: break
        }
        if m == "GET", p.hasPrefix("/stickers/packs/"), p.hasSuffix("/stickers") {
            let goi = Int(p.split(separator: "/")[2]) ?? 1
            return (0..<8).map { i in ["id": goi * 100 + i, "packId": goi, "url": "\(goc)/sticker/\((goi - 1) * 4 + i).png", "label": "Sticker \(i + 1)"] }
        }
        if m == "GET", p.hasPrefix("/users/"), let id = Int(p.split(separator: "/").last ?? "") {
            let n = ((danhBa["people"] as? [[String: Any]]) ?? []).first { ($0["id"] as? Int) == id }
            return ["id": id, "username": n?["username"] ?? "user\(id)", "fullName": n?["fullName"] ?? "User", "displayName": NSNull(),
                    "avatarUrl": NSNull(), "coverPhotoUrl": id == 2 ? "https://picsum.photos/id/1018/1200/400" : NSNull(),
                    "bio": id == 2 ? "Product owner · Northwind. Ask me about the roadmap 🗺️" : NSNull(),
                    "jobTitle": id == 2 ? "Product Owner" : NSNull(), "workplace": id == 2 ? "Northwind Studio" : NSNull(),
                    "createdAt": DuLieuGia.iso(-400)]
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
                let media = (b["media"] as? [String: Any]).flatMap { d -> (String, String)? in
                    guard let u = d["url"] as? String, let k = d["kind"] as? String else { return nil }
                    return (u, k)
                }
                let traLoi = (b["parentMessageId"] as? Int).flatMap { pid -> (Int, Int, String)? in
                    guard let g = tinNhan.first(where: { ($0["id"] as? Int) == pid }) else { return nil }
                    return (pid, g["senderId"] as? Int ?? 2, g["content"] as? String ?? "")
                }
                let coTep = !((b["fileIds"] as? [Any]) ?? []).isEmpty
                let moi = tin(5000 + tinGui.count, 1, b["content"] as? String ?? "", phut: 0,
                              anh: coTep ? "https://picsum.photos/id/180/800/600" : nil, traLoi: traLoi, thread: tid, media: media)
                if tid == 101 { tinGui.append(moi) }
                return moi
            case ("GET", "reads"): return [["userId": 2, "lastReadAt": iso(phut: 1)], ["userId": 1, "lastReadAt": iso(phut: 0)]]
            case (_, "preference"), (_, "mute-for"), (_, "mark-unread"), (_, "hard"):
                return ["preferences": [String: Any]()]
            default: return ["ok": true]
            }
        }
        return ["ok": true]   // reactions, recall, report, blocks…
    }
}

// MARK: - GIF / nhãn dán / tin thoại TỰ VẼ cho máy chủ giả (`/api/v1/__gia/…`)

enum MediaGiaCTW {
    nonisolated(unsafe) private static var dem: [String: Data] = [:]

    /// Trả dữ liệu cho đường `/api/v1/__gia/<loai>/<n>.<đuôi>` (nil ⇒ không phải đường media giả).
    static func du(_ path: String) -> (Data, String)? {
        guard path.hasPrefix("/api/v1/__gia/") else { return nil }
        if let d = dem[path] { return (d, kieu(path)) }
        let ten = (path as NSString).lastPathComponent
        let n = Int((ten as NSString).deletingPathExtension) ?? 0
        let d: Data?
        if path.contains("/gif/") { d = gif(n) }
        else if path.contains("/sticker/") { d = nhanDan(n) }
        else { d = Data() }   // tin thoại: rỗng (máy mô phỏng không phát; bong bóng vẫn vẽ)
        guard let d else { return nil }
        dem[path] = d
        return (d, kieu(path))
    }

    private static func kieu(_ p: String) -> String { p.hasSuffix(".gif") ? "image/gif" : p.hasSuffix(".png") ? "image/png" : "audio/mp4" }

    private static let mau: [(UIColor, UIColor)] = [
        (UIColor(red: 0.31, green: 0.36, blue: 0.84, alpha: 1), UIColor(red: 0.45, green: 0.80, blue: 0.95, alpha: 1)),
        (UIColor(red: 0.95, green: 0.45, blue: 0.40, alpha: 1), UIColor(red: 0.99, green: 0.78, blue: 0.36, alpha: 1)),
        (UIColor(red: 0.18, green: 0.65, blue: 0.50, alpha: 1), UIColor(red: 0.62, green: 0.90, blue: 0.55, alpha: 1)),
        (UIColor(red: 0.55, green: 0.33, blue: 0.85, alpha: 1), UIColor(red: 0.98, green: 0.55, blue: 0.80, alpha: 1)),
    ]

    /// GIF 10 khung: nền gradient + chữ nảy + ngôi sao xoay.
    private static func gif(_ n: Int) -> Data? {
        let co = CGSize(width: 240, height: 180)
        let (a, b) = mau[n % mau.count]
        let chu = DuLieuGiaThanhVien.tenGif[n % DuLieuGiaThanhVien.tenGif.count]
        let du = NSMutableData()
        guard let dich = CGImageDestinationCreateWithData(du, UTType.gif.identifier as CFString, 10, nil) else { return nil }
        CGImageDestinationSetProperties(dich, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        for k in 0..<10 {
            let pha = Double(k) / 10 * 2 * .pi
            let anh = UIGraphicsImageRenderer(size: co, format: f).image { c in
                let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [a.cgColor, b.cgColor] as CFArray, locations: [0, 1])!
                c.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: co.width, y: co.height), options: [])
                UIColor.white.withAlphaComponent(0.25).setFill()
                for s in 0..<5 {
                    let x = CGFloat(s) * 52 + 10, y = 20 + CGFloat(sin(pha + Double(s))) * 10
                    c.cgContext.fillEllipse(in: CGRect(x: x, y: y, width: 14, height: 14))
                }
                let dy = CGFloat(abs(sin(pha))) * -14
                let kieu = NSMutableParagraphStyle(); kieu.alignment = .center
                (chu as NSString).draw(in: CGRect(x: 0, y: 72 + dy, width: co.width, height: 50), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 30, weight: .heavy), .foregroundColor: UIColor.white, .paragraphStyle: kieu,
                ])
            }
            if let cg = anh.cgImage {
                CGImageDestinationAddImage(dich, cg, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.09]] as CFDictionary)
            }
        }
        return CGImageDestinationFinalize(dich) ? du as Data : nil
    }

    /// Nhãn dán PNG nền trong: emoji lớn trên vòng tròn màu.
    private static func nhanDan(_ n: Int) -> Data? {
        let e = ["🚀", "✅", "🐛", "☕️", "🎉", "😂", "🙏", "🔥"][n % 8]
        let (a, _) = mau[n % mau.count]
        let co = CGSize(width: 220, height: 220)
        let f = UIGraphicsImageRendererFormat(); f.scale = 1; f.opaque = false
        return UIGraphicsImageRenderer(size: co, format: f).image { c in
            a.withAlphaComponent(0.18).setFill()
            c.cgContext.fillEllipse(in: CGRect(x: 10, y: 10, width: 200, height: 200))
            (e as NSString).draw(at: CGPoint(x: 42, y: 36), withAttributes: [.font: UIFont.systemFont(ofSize: 120)])
        }.pngData()
    }
}
#endif
