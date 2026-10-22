#if DEBUG
import Foundation
import UIKit

// MARK: - Dữ liệu mẫu Bảng tin (Team Feed) — đúng HÌNH DẠNG hợp đồng `api-backend/docs/ctw-feed-hop-dong-api.md`
//
// Màn thử:
//   bangtin                       My Work › Bảng tin (gộp)
//   mod:feed                      bảng tin dự án NW · mod:feed/bai ⇒ màn một bài (cuộn tới bình luận)
//   + CT_XEM_FEED_MO=binhluan | soan | xemanh | video | camxuc   mở sẵn tấm phủ để chụp
//   + CT_XEM_FEED_MOI=3           giả 3 sự kiện socket `post.created` ⇒ viên "3 bài mới"
//   + CT_XEM_FEED=0               giả MÁY CHỦ CŨ (mọi /work/feed/* ⇒ 404 "Route … not found") ⇒ bảng tin biến mất
//   + CT_XEM_FEED_TRONG=1         bảng tin trống (ô trống + "Tạo bài viết đầu tiên")
//   + CT_XEM_FEED_ANH=1           nút Ảnh của ô soạn thêm thẳng một ảnh mẫu (UI test không phải lái bảng chọn ảnh hệ thống)
// Ảnh: picsum.photos (như các mảng khác). Video: mẫu công khai của Google (phát thật khi có mạng).

enum XemThuBangTin {
    static var env: [String: String] { ProcessInfo.processInfo.environment }
    static var mo: String? { env["CT_XEM_FEED_MO"] }
    static var anhMau: Bool { env["CT_XEM_FEED_ANH"] == "1" }

    /// Ảnh mẫu (gradient + chữ) cho ô soạn khi `CT_XEM_FEED_ANH=1`.
    static func taoAnhMau() -> Data {
        let s = CGSize(width: 1600, height: 1200)
        let anh = UIGraphicsImageRenderer(size: s).image { c in
            let mau = [UIColor(red: 0.31, green: 0.36, blue: 0.84, alpha: 1).cgColor, UIColor(red: 0.45, green: 0.78, blue: 0.86, alpha: 1).cgColor]
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: mau as CFArray, locations: [0, 1]) {
                c.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: s.width, y: s.height), options: [])
            }
            let chu = NSAttributedString(string: "Sprint 6 ✓", attributes: [.font: UIFont.boldSystemFont(ofSize: 160), .foregroundColor: UIColor.white])
            chu.draw(at: CGPoint(x: 180, y: 480))
        }
        return anh.jpegData(compressionQuality: 0.85) ?? Data()
    }

    /// Gọi khi một bảng tin vừa mở (BangTinCTW) — mở sẵn tấm phủ cho ảnh chụp.
    @MainActor
    static func khiMo(dp: DieuPhoiBaiCTW, vm: BangTinVM) async {
        guard XemThuCTW.man != nil else { return }
        try? await Task.sleep(nanoseconds: 1_400_000_000)
        if let n = Int(env["CT_XEM_FEED_MOI"] ?? ""), n > 0 {
            for i in 0..<n {
                RealtimeCTW.shared.suKienBangTin.send(SuKienBangTinCTW(type: "post.created", postId: 990 + i, workspaceId: 1, projectId: 7, actorId: 2))
            }
        }
        switch mo {
        case "binhluan": if let p = vm.bai.first(where: { ($0.commentCount ?? 0) > 2 }) { dp.tamPhu = .binhLuan(p) }
        case "soan": dp.tamPhu = .soan(KhoBangTinCTW.shared.noiDang.first { $0.duAn?.id == 7 })
        case "xemanh": if let p = vm.bai.first(where: { $0.anhVaVideo.count >= 4 }) { dp.xem = XemPhuongTienMo(ds: p.anhVaVideo, batDau: 1) }
        case "video": if let p = vm.bai.first(where: { $0.anhVaVideo.first?.laVideo == true }) { dp.xem = XemPhuongTienMo(ds: p.anhVaVideo, batDau: 0) }
        default: break
        }
    }

    /// Ô soạn mở sẵn có chữ + 3 ảnh (2 xong, 1 đang tải 62%).
    @MainActor
    static func mauSoan(_ vm: SoanBaiVM) {
        guard mo == "soan" else { return }
        vm.chu = "Bản build 1.1 (5) đã lên TestFlight 🚀 Cảm ơn @linh đã test flow đăng nhập. Ai rảnh thử giúp mình màn Bảng tin mới nhé #release"
        vm.datMau([
            MucDinhKemCTW(loai: .anh, ten: "a.jpg", tep: DuLieuGiaBangTin.tepAnh(7001, 0, 1600, 1067)),
            MucDinhKemCTW(loai: .anh, ten: "b.jpg", tep: DuLieuGiaBangTin.tepAnh(7002, 180, 1600, 1067)),
            MucDinhKemCTW(loai: .anh, ten: "c.jpg", tienDo: 0.62, tep: nil),
        ])
    }
}

enum DuLieuGiaBangTin {
    typealias G = DuLieuGia
    nonisolated(unsafe) static var baiMoi: [[String: Any]] = []
    nonisolated(unsafe) static var binhLuanMoi: [Int: [[String: Any]]] = [:]
    nonisolated(unsafe) static var camXuc: [Int: (Int, [[String: Any]], String?)] = [:]
    nonisolated(unsafe) static var daLuu: Set<Int> = [2, 6]
    nonisolated(unsafe) static var daAn: Set<Int> = []
    nonisolated(unsafe) static var soTai = 0
    private static let khoa = NSLock()

    static let northwind: [String: Any] = ["id": 1, "slug": "northwind", "name": "Northwind Studio", "logoUrl": NSNull()]
    static let swp: [String: Any] = ["id": 2, "slug": "swp391-g4", "name": "SWP391 · Group 4", "logoUrl": NSNull()]
    static let nw: [String: Any] = ["id": 7, "key": "NW", "name": "Mobile App Launch"]
    static let web: [String: Any] = ["id": 8, "key": "WEB", "name": "Marketing Website"]
    static let swpP: [String: Any] = ["id": 11, "key": "SWP", "name": "Clinic Booking System"]
    static let khoaLe = G.nguoi(6, "khoa", "Khoa Le")

    static func phut(_ p: Double) -> String { G.iso(0, gio: -p / 60) }
    static func het() -> String { G.iso(0, gio: 0.16) }

    static func tepAnh(_ id: Int, _ anh: Int, _ w: Int, _ h: Int, alt: String? = nil) -> CTWFeedAttachment {
        CTWFeedAttachment(id: id, kind: "IMAGE", status: "READY", fileName: "photo-\(id).jpg", mime: "image/jpeg", size: 380_000,
                          width: w, height: h, alt: alt, position: 0,
                          url: "https://picsum.photos/id/\(anh)/\(w)/\(h)", thumbUrl: "https://picsum.photos/id/\(anh)/\(min(w, 1280))/\(min(w, 1280) * h / w)",
                          urlExpiresAt: het())
    }

    static func anh(_ id: Int, _ anh: Int, _ w: Int, _ h: Int, vt: Int = 0, alt: String? = nil) -> [String: Any] {
        ["id": id, "kind": "IMAGE", "status": "READY", "fileName": "IMG_\(4000 + id).jpg", "mime": "image/jpeg", "size": 420_000 + id * 13,
         "width": w, "height": h, "durationMs": NSNull(), "alt": alt ?? NSNull(), "position": vt,
         "url": "https://picsum.photos/id/\(anh)/\(w)/\(h)", "thumbUrl": "https://picsum.photos/id/\(anh)/\(min(w, 1280))/\(min(w, 1280) * h / w)",
         "posterUrl": NSNull(), "urlExpiresAt": het()]
    }

    static func tep(_ id: Int, _ ten: String, _ mime: String, _ co: Int) -> [String: Any] {
        ["id": id, "kind": "FILE", "status": "READY", "fileName": ten, "mime": mime, "size": co, "width": NSNull(), "height": NSNull(),
         "durationMs": NSNull(), "alt": NSNull(), "position": 0, "url": "https://media.cuongthai.com/feed/\(ten)", "thumbUrl": NSNull(),
         "posterUrl": NSNull(), "urlExpiresAt": het()]
    }

    static func cx(_ ds: [(String, Int)]) -> [[String: Any]] { ds.map { ["kind": $0.0, "count": $0.1] } }

    static func quyen(_ cuaToi: Bool, quanTri: Bool = true) -> [String: Any] {
        ["edit": cuaToi, "delete": cuaToi || quanTri, "pin": quanTri, "moderate": quanTri, "comment": true, "react": true, "report": !cuaToi]
    }

    static func binhLuan(_ id: Int, _ post: Int, _ tac: [String: Any], _ chu: String, phut p: Double, cha: Int? = nil,
                         nhac: [[String: Any]] = [], cxs: [(String, Int)] = [], cua: String? = nil, tl: [[String: Any]] = [], soTl: Int? = nil,
                         chan: Bool = false) -> [String: Any] {
        let cuaToi = (tac["id"] as? Int) == 1
        return ["id": id, "postId": post, "parentId": cha ?? NSNull(), "author": tac, "body": chu, "mentions": nhac,
                "reactionCount": cxs.reduce(0) { $0 + $1.1 }, "reactions": cx(cxs), "myReaction": cua ?? NSNull(),
                "replyCount": soTl ?? tl.count, "replies": tl, "hidden": false, "hiddenForMe": chan, "authorBlocked": chan, "reportedByMe": false,
                "editedAt": NSNull(), "createdAt": phut(p),
                "can": ["edit": cuaToi, "delete": true, "moderate": !cuaToi, "report": !cuaToi, "reply": true]]
    }

    static func nhac(_ id: Int, _ u: String, _ ten: String) -> [String: Any] { ["id": id, "username": u, "name": ten] }

    static func bai(_ id: Int, ws: [String: Any], duAn: [String: Any]?, tac: [String: Any], vai: String, chu: String, phut p: Double,
                    nhac: [[String: Any]] = [], tags: [String] = [], tep: [[String: Any]] = [], link: [String: Any]? = nil,
                    refs: [[String: Any]] = [], poll: [String: Any]? = nil, cxs: [(String, Int)] = [], cua: String? = nil,
                    soBl: Int = 0, bl: [[String: Any]] = [], ghim: Bool = false, sua: Bool = false, an: Bool = false) -> [String: Any] {
        let cuaToi = (tac["id"] as? Int) == 1
        return ["id": id, "workspace": ws, "project": duAn ?? NSNull(), "author": tac, "authorRole": vai, "body": chu,
                "mentions": nhac, "hashtags": tags, "attachments": tep, "linkPreview": link ?? NSNull(), "refs": refs, "poll": poll ?? NSNull(),
                "reactionCount": cxs.reduce(0) { $0 + $1.1 }, "reactions": cx(cxs), "myReaction": cua ?? NSNull(),
                "commentCount": soBl, "comments": bl, "commentsOff": false, "pinned": ghim, "pinnedAt": ghim ? phut(60 * 30) : NSNull(),
                "saved": daLuu.contains(id), "hidden": an, "editedAt": sua ? phut(p - 5) : NSNull(), "createdAt": phut(p),
                "url": "/work/\(ws["slug"] as? String ?? "")/feed?post=\(id)", "can": quyen(cuaToi, quanTri: (ws["id"] as? Int) == 1)]
    }

    /// 10 bài mẫu, mới nhất trước.
    static var tatCa: [[String: Any]] {
        let linh = G.linh, minh = G.minh, an = G.an, sara = G.sara, toi = G.toi
        var ds: [[String: Any]] = baiMoi
        ds += [
            bai(1, ws: northwind, duAn: nil, tac: linh, vai: "ADMIN",
                chu: "📣 Lịch demo **Sprint 6**: thứ Sáu 14:00 tại phòng họp lớn. Mỗi nhóm 10 phút, nhớ chuẩn bị bản build TestFlight. @alex @minh nhớ mang iPad để demo bản iPad nhé! #demo #sprint6",
                phut: 60 * 26, nhac: [nhac(1, "alex", "Alex Morgan"), nhac(3, "minh", "Minh Pham")], tags: ["demo", "sprint6"],
                cxs: [("like", 8), ("celebrate", 3), ("love", 1)], cua: "like", soBl: 5,
                bl: [binhLuan(101, 1, minh, "Ok chị, em mang cả iPad mini nữa 👍", phut: 60 * 25),
                     binhLuan(102, 1, sara, "Phòng họp lớn có máy chiếu chưa ạ?", phut: 60 * 24)],
                ghim: true),
            bai(2, ws: northwind, duAn: nw, tac: minh, vai: "MEMBER",
                chu: "Màn đăng nhập mới đã lên bản build 1.1 (4) 🎉 Mọi người thử giúp mình flow quên mật khẩu, có bug thì gắn vào NW-12 nhé. Cảm ơn @sara đã thiết kế lại phần hero!",
                phut: 42, nhac: [nhac(5, "sara", "Sara Kim")],
                tep: [anh(201, 0, 1600, 1067, vt: 0, alt: "Màn đăng nhập trên iPhone"), anh(202, 180, 1600, 1067, vt: 1), anh(203, 48, 1600, 1067, vt: 2),
                      anh(204, 2, 1600, 1067, vt: 3), anh(205, 6, 1600, 1067, vt: 4)],
                refs: [["t": "issue", "key": "NW-12", "n": 12, "url": "/work/northwind/NW/issue/12", "title": "Quên mật khẩu: gửi lại mã OTP sau 60 giây",
                        "status": ["name": "In Progress", "category": "IN_PROGRESS"], "type": ["key": "story", "name": "Story", "color": "#4BADE8"],
                        "assignee": ["id": 3, "name": "Minh Pham", "avatarUrl": NSNull()], "project": "Mobile App Launch", "when": NSNull()]],
                cxs: [("love", 4), ("like", 6), ("wow", 1)], soBl: 4,
                bl: [binhLuan(111, 2, an, "Đẹp quá anh ơi 😍 Nút đăng nhập bằng Apple nằm đúng chỗ rồi", phut: 30),
                     binhLuan(112, 2, linh, "Ổn rồi, merge PR #42 đi em", phut: 12)]),
            bai(3, ws: northwind, duAn: web, tac: sara, vai: "MEMBER",
                chu: "Bản quay màn hình animation hero mới cho trang chủ — 45 giây. Góp ý trước thứ Năm nha! 🎬",
                phut: 60 * 3,
                tep: [["id": 301, "kind": "VIDEO", "status": "READY", "fileName": "hero-animation.mp4", "mime": "video/mp4", "size": 18_400_000,
                       "width": 1280, "height": 720, "durationMs": 45_000, "alt": "Animation hero trang chủ", "position": 0,
                       "url": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4",
                       "thumbUrl": "https://picsum.photos/id/96/1280/720", "posterUrl": "https://picsum.photos/id/96/1280/720", "urlExpiresAt": het()]],
                cxs: [("like", 5), ("wow", 2)], soBl: 1,
                bl: [binhLuan(121, 3, minh, "Mượt ghê, nhưng đoạn cuối hơi nhanh", phut: 60 * 2)]),
            bai(4, ws: swp, duAn: swpP, tac: an, vai: "MEMBER",
                chu: "Họp nhóm tuần này chốt ngày nào mọi người? Cần đủ 5 người để review use case UC-07 → UC-12.",
                phut: 60 * 5,
                poll: ["options": [["id": "a", "text": "Thứ Năm 20:00 (online)", "votes": 2], ["id": "b", "text": "Thứ Sáu 19:30 (thư viện)", "votes": 3],
                                   ["id": "c", "text": "Chủ nhật 9:00", "votes": 0]],
                       "multi": false, "closesAt": G.iso(2), "closed": false, "totalVotes": 5, "voters": 5, "myVotes": ["b"]],
                cxs: [("like", 2)], soBl: 0),
            bai(5, ws: northwind, duAn: nil, tac: khoaLe, vai: "MEMBER",
                chu: "Bài này viết hay về cách React 19 xử lý form và Actions 👇 nhóm WEB tham khảo trước khi nâng cấp nhé https://react.dev/blog/2024/12/05/react-19",
                phut: 60 * 9,
                link: ["url": "https://react.dev/blog/2024/12/05/react-19", "domain": "react.dev", "title": "React v19",
                       "description": "React 19 is now available on npm! Actions, useActionState, useOptimistic and more.", "siteName": "React",
                       "imageUrl": "https://picsum.photos/id/1/1200/630"],
                cxs: [("like", 3)], soBl: 0),
            bai(6, ws: northwind, duAn: nw, tac: linh, vai: "ADMIN",
                chu: "Đặc tả SRS v1.3 đã cập nhật phần 3.2 thanh toán + báo cáo kiểm thử Sprint 6. Ai review xong thì thả 👍 giúp mình nhé.",
                phut: 60 * 20,
                tep: [tep(601, "SRS-v1.3.pdf", "application/pdf", 1_240_000), tep(602, "Bao-cao-kiem-thu-Sprint6.xlsx",
                      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", 86_000)],
                cxs: [("like", 4)], soBl: 0, sua: true),
            bai(7, ws: northwind, duAn: nil, tac: toi, vai: "ADMIN",
                chu: "Team building cuối tuần ở Đà Lạt 🌲 Cảm ơn cả nhà đã đi đủ 100%! Album đầy đủ mình để trong Drive chung.",
                phut: 60 * 30,
                tep: [anh(701, 10, 1600, 1067, vt: 0, alt: "Rừng thông Đà Lạt"), anh(702, 29, 1600, 1067, vt: 1)],
                cxs: [("love", 9), ("celebrate", 4), ("like", 3)], soBl: 6,
                bl: [binhLuan(171, 7, linh, "Chuyến đi vui nhất năm 🥰", phut: 60 * 28)]),
            bai(8, ws: northwind, duAn: nw, tac: minh, vai: "MEMBER",
                chu: "Sơ đồ luồng thanh toán mới sau buổi whiteboard sáng nay. Phần retry khi mất mạng mình tách thành NW-31.",
                phut: 60 * 34, tep: [anh(801, 20, 1600, 1200, alt: "Ảnh chụp bảng trắng luồng thanh toán")], cxs: [("like", 2)], soBl: 0),
            bai(9, ws: swp, duAn: nil, tac: an, vai: "MEMBER",
                chu: """
                Tổng kết buổi mentor tối qua với anh Cường, ghi lại cho ai vắng:

                1. Use case phải có actor rõ ràng, không viết "hệ thống tự động" chung chung.
                2. Mỗi màn hình trong SRS cần mockup + bảng mô tả trường dữ liệu.
                3. Test case viết theo mẫu của trường (UTCID), mỗi chức năng tối thiểu 5 case.
                4. ERD chốt trước thứ Hai để nhóm BE bắt đầu viết migration.
                5. Tuần sau demo luồng đặt lịch khám end-to-end.

                Ai còn thắc mắc thì comment dưới đây nha, mình tổng hợp gửi anh ấy một lần. #mentor #swp391
                """,
                phut: 60 * 48, tags: ["mentor", "swp391"], cxs: [("like", 6), ("love", 1)], soBl: 2),
            bai(10, ws: northwind, duAn: web, tac: sara, vai: "MEMBER",
                chu: "Ảnh banner chưa đúng brand guideline, tạm gỡ để sửa.", phut: 60 * 70, cxs: [], soBl: 0, an: true),
        ]
        khoa.lock(); defer { khoa.unlock() }
        return ds.filter { !daAn.contains($0["id"] as? Int ?? 0) }.map(apCamXuc)
    }

    private static func apCamXuc(_ p: [String: Any]) -> [String: Any] {
        guard let id = p["id"] as? Int, let c = camXuc[id] else { return p }
        var m = p
        m["reactionCount"] = c.0; m["reactions"] = c.1; m["myReaction"] = c.2 ?? NSNull()
        m["saved"] = daLuu.contains(id)
        return m
    }

    static func binhLuanCua(_ post: Int) -> [[String: Any]] {
        let linh = G.linh, minh = G.minh, an = G.an, sara = G.sara, toi = G.toi
        var ds: [[String: Any]]
        switch post {
        case 1:
            ds = [
                binhLuan(101, 1, minh, "Ok chị, em mang cả iPad mini nữa 👍", phut: 60 * 25, cxs: [("like", 2)],
                         tl: [binhLuan(103, 1, linh, "Tuyệt, nhớ sạc đầy pin nha", phut: 60 * 25 - 3, cha: 101)]),
                binhLuan(102, 1, sara, "Phòng họp lớn có máy chiếu chưa ạ? @linh", phut: 60 * 24, nhac: [nhac(2, "linh", "Linh Tran")],
                         tl: [binhLuan(104, 1, linh, "Có rồi em, thêm cả màn 65 inch", phut: 60 * 23, cha: 102, cxs: [("love", 1)]),
                              binhLuan(105, 1, toi, "Mình mang thêm adapter USB-C sang HDMI", phut: 60 * 22, cha: 102)], soTl: 3),
                binhLuan(106, 1, khoaLe, "Nhóm em xin slot cuối được không ạ, build đang chạy CI 🙏", phut: 60 * 5, cxs: [("haha", 1)]),
                binhLuan(107, 1, G.nguoi(12, "spam_bot", "Người đã chặn"), "", phut: 60 * 2, chan: true),
            ]
        case 2:
            ds = [
                binhLuan(111, 2, an, "Đẹp quá anh ơi 😍 Nút đăng nhập bằng Apple nằm đúng chỗ rồi", phut: 30, cxs: [("love", 2)], cua: "love",
                         tl: [binhLuan(113, 2, minh, "Cảm ơn em, nhờ @sara cả đấy", phut: 28, cha: 111, nhac: [nhac(5, "sara", "Sara Kim")])]),
                binhLuan(112, 2, linh, "Ổn rồi, merge PR #42 đi em. Nhớ cập nhật NW-12 sang Review.", phut: 12, cxs: [("like", 3)]),
                binhLuan(114, 2, sara, "Mình sẽ làm thêm bản tối cho màn này trong tuần sau", phut: 4),
            ]
        case 7:
            ds = [binhLuan(171, 7, linh, "Chuyến đi vui nhất năm 🥰", phut: 60 * 28, cxs: [("love", 4)])]
        default:
            ds = [binhLuan(post * 100 + 1, post, minh, "Đã xem 👍", phut: 50)]
        }
        return ds + (binhLuanMoi[post] ?? [])
    }

    static var phamVi: [String: Any] {
        ["scopes": [
            ["workspace": northwind, "role": "ADMIN", "canPost": true, "canModerate": true, "follow": "ALL",
             "projects": [["id": 7, "key": "NW", "name": "Mobile App Launch", "role": "ADMIN", "canPost": true, "canModerate": true, "follow": "ALL"],
                          ["id": 8, "key": "WEB", "name": "Marketing Website", "role": "MEMBER", "canPost": true, "canModerate": true, "follow": "MENTIONS"]]],
            ["workspace": swp, "role": "MEMBER", "canPost": true, "canModerate": false, "follow": "ALL",
             "projects": [["id": 11, "key": "SWP", "name": "Clinic Booking System", "role": "MEMBER", "canPost": true, "canModerate": false, "follow": "ALL"]]],
        ], "openReports": 2]
    }

    static func route(_ m: String, _ p: String, _ b: [String: Any]) -> Any? {
        guard p.hasPrefix("/work/feed") || p.hasPrefix("/work/__xem-thu/feed") else { return nil }
        if XemThuBangTin.env["CT_XEM_FEED"] == "0" {
            return LoiGiaCTW(trangThai: 404, ma: "", thongDiep: "Route \(m) /api/v1\(p) not found")
        }
        let phan = p.split(separator: "/").map(String.init)   // ["work","feed","posts","2","comments"]
        switch (m, p) {
        case ("GET", "/work/feed/scopes"): return phamVi
        case ("PUT", "/work/feed/follow"): return ["workspaceId": b["workspaceId"] ?? 1, "projectId": b["projectId"] ?? NSNull(), "level": b["level"] ?? "ALL"]
        case ("GET", "/work/feed/mentionable"):
            let q = (b["q"] as? String ?? "").lowercased()
            let ds = [G.toi, G.linh, G.minh, G.an, G.sara, khoaLe].filter { q.isEmpty || ($0["username"] as? String ?? "").hasPrefix(q) || ($0["fullName"] as? String ?? "").lowercased().contains(q) }
            return ["users": ds]
        case ("GET", "/work/feed/new-count"): return ["count": 0]
        case ("GET", "/work/feed"): return trang(b)
        case ("POST", "/work/feed/posts"): return taoBai(b)
        case ("POST", "/work/feed/uploads"):
            khoa.lock(); soTai += 1; let n = soTai; khoa.unlock()
            return anh(8000 + n, [0, 180, 48][n % 3], 1600, 1067)
        case ("POST", "/work/feed/uploads/presign"):
            khoa.lock(); soTai += 1; let n = soTai; khoa.unlock()
            return ["attachment": ["id": 8500 + n, "kind": b["kind"] ?? "FILE", "status": "PENDING", "fileName": b["fileName"] ?? "file"],
                    "uploadUrl": "https://cuongthai.com/api/v1/work/__xem-thu/feed-r2", "method": "PUT",
                    "headers": ["Content-Type": b["mime"] ?? "application/octet-stream"], "expiresAt": G.iso(0, gio: 1)]
        case ("PUT", "/work/__xem-thu/feed-r2"): return ["ok": true]
        case ("POST", "/work/feed/link-preview"):
            return ["url": b["url"] ?? "", "domain": URL(string: b["url"] as? String ?? "")?.host ?? "", "title": "Bài viết được chia sẻ",
                    "description": "Xem trước liên kết do máy chủ tải.", "siteName": NSNull(), "imageUrl": NSNull()]
        case ("GET", "/work/feed/reports"):
            return ["reports": [
                ["id": 5, "status": "OPEN", "reason": "spam", "detail": "Quảng cáo khoá học ngoài", "createdAt": phut(80), "reporter": G.minh, "reportCount": 2,
                 "target": ["type": "post", "postId": 10, "commentId": NSNull(), "excerpt": "Ảnh banner chưa đúng brand guideline, tạm gỡ để sửa.",
                            "author": G.sara, "hidden": false, "deleted": false],
                 "workspace": ["id": 1, "slug": "northwind", "name": "Northwind Studio"], "project": web,
                 "resolvedBy": NSNull(), "resolvedAt": NSNull(), "action": NSNull(), "url": "/work/northwind/feed?post=10"],
            ], "nextCursor": NSNull(), "openCount": 2]
        default: break
        }
        if phan.count >= 4, phan[2] == "posts", let id = Int(phan[3]) { return baiRoute(m, id, phan.count > 4 ? phan[4] : nil, b) }
        if phan.count >= 4, phan[2] == "comments", let cid = Int(phan[3]) {
            if phan.count > 4, phan[4] == "reaction" { return ["reactionCount": m == "PUT" ? 1 : 0, "reactions": m == "PUT" ? cx([(b["kind"] as? String ?? "like", 1)]) : [], "myReaction": m == "PUT" ? (b["kind"] ?? "like") : NSNull()] }
            if phan.count > 4, phan[4] == "report" { return ["reported": true, "duplicate": false] }
            if m == "DELETE" { return ["deleted": true] }
            if m == "PATCH" { return binhLuan(cid, 0, G.toi, b["body"] as? String ?? "", phut: 1) }
            return ["deleted": true]
        }
        if phan.count >= 4, phan[2] == "attachments", let id = Int(phan[3]) {
            let a = tatCa.flatMap { $0["attachments"] as? [[String: Any]] ?? [] }.first { ($0["id"] as? Int) == id }
            return ["url": a?["url"] ?? "https://picsum.photos/id/0/800/600", "expiresAt": het()]
        }
        if phan.count >= 5, phan[2] == "uploads", let id = Int(phan[3]) {
            if phan[4] == "complete" || phan[4] == "poster" {
                return ["id": id, "kind": "VIDEO", "status": "READY", "fileName": "video.mov", "mime": "video/quicktime", "size": 9_000_000,
                        "width": b["width"] ?? 1280, "height": b["height"] ?? 720, "durationMs": b["durationMs"] ?? 12_000, "position": 0,
                        "url": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4",
                        "thumbUrl": "https://picsum.photos/id/96/1280/720", "posterUrl": "https://picsum.photos/id/96/1280/720", "urlExpiresAt": het()]
            }
        }
        if phan.count >= 4, phan[2] == "uploads" { return ["deleted": true] }
        if phan.count >= 4, phan[2] == "reports" { return ["id": Int(phan[3]) ?? 5, "status": "RESOLVED", "action": b["action"] ?? "dismiss"] }
        return ["ok": true]
    }

    private static func trang(_ b: [String: Any]) -> [String: Any] {
        if XemThuBangTin.env["CT_XEM_FEED_TRONG"] == "1" { return ["posts": [], "pinned": [], "nextCursor": NSNull()] }
        // Máy chủ xếp `createdAt desc, id desc` (hợp đồng §3).
        var ds = tatCa.sorted { ($0["createdAt"] as? String ?? "") > ($1["createdAt"] as? String ?? "") }
        let ws = Int("\(b["workspaceId"] ?? "")"), pid = Int("\(b["projectId"] ?? "")")
        if let pid { ds = ds.filter { (($0["project"] as? [String: Any])?["id"] as? Int) == pid } }
        else if let ws { ds = ds.filter { (($0["workspace"] as? [String: Any])?["id"] as? Int) == ws } }
        switch b["filter"] as? String {
        case "mine": ds = ds.filter { (($0["author"] as? [String: Any])?["id"] as? Int) == 1 }
        case "media": ds = ds.filter { ($0["attachments"] as? [[String: Any]] ?? []).contains { ($0["kind"] as? String) != "FILE" } }
        case "files": ds = ds.filter { ($0["attachments"] as? [[String: Any]] ?? []).contains { ($0["kind"] as? String) == "FILE" } }
        case "saved": ds = ds.filter { daLuu.contains($0["id"] as? Int ?? 0) }
        default: break
        }
        if let q = (b["q"] as? String)?.lowercased(), !q.isEmpty {
            ds = ds.filter { ($0["body"] as? String ?? "").lowercased().contains(q) }
        }
        var ghim: [[String: Any]] = []
        let motPhamVi = (ws != nil || pid != nil) && (b["filter"] == nil || b["filter"] as? String == "all") && b["q"] == nil
        if motPhamVi {
            ghim = ds.filter { $0["pinned"] as? Bool == true }
            ds = ds.filter { $0["pinned"] as? Bool != true }
        }
        let dau = b["cursor"] as? String == "p2" ? 6 : 0
        let trang = Array(ds.dropFirst(dau).prefix(6))
        return ["posts": trang, "pinned": dau == 0 ? ghim : [], "nextCursor": dau == 0 && ds.count > 6 ? "p2" : NSNull()]
    }

    private static func taoBai(_ b: [String: Any]) -> [String: Any] {
        khoa.lock(); let id = 900 + baiMoi.count; khoa.unlock()
        let pid = b["projectId"] as? Int
        let duAn: [String: Any]? = pid == 7 ? nw : pid == 8 ? web : pid == 11 ? swpP : nil
        let ws = (b["workspaceId"] as? Int) == 2 ? swp : northwind
        let ids = b["attachmentIds"] as? [Int] ?? []
        var p = bai(id, ws: ws, duAn: duAn, tac: G.toi, vai: "ADMIN", chu: b["body"] as? String ?? "", phut: 0,
                    tep: ids.enumerated().map { anh($0.element, [0, 180, 48][$0.offset % 3], 1600, 1067, vt: $0.offset) })
        if let poll = b["poll"] as? [String: Any], let o = poll["options"] as? [String] {
            p["poll"] = ["options": o.enumerated().map { ["id": "\($0.offset)", "text": $0.element, "votes": 0] }, "multi": poll["multi"] ?? false,
                         "closesAt": NSNull(), "closed": false, "totalVotes": 0, "voters": 0, "myVotes": []]
        }
        khoa.lock(); baiMoi.insert(p, at: 0); khoa.unlock()
        return p
    }

    private static func baiRoute(_ m: String, _ id: Int, _ con: String?, _ b: [String: Any]) -> Any {
        let p = tatCa.first { ($0["id"] as? Int) == id }
        switch (m, con) {
        case ("GET", nil): return p ?? LoiGiaCTW(trangThai: 404, ma: "NOT_FOUND", thongDiep: "Post not found")
        case ("DELETE", nil): khoa.lock(); daAn.insert(id); khoa.unlock(); return ["deleted": true]
        case ("PATCH", nil):
            var q = p ?? [:]
            if let chu = b["body"] as? String { q["body"] = chu; q["editedAt"] = phut(0) }
            return q
        case (_, "reaction"):
            let cu = CTWFeedPost(id: id, reactionCount: p?["reactionCount"] as? Int,
                                 reactions: (p?["reactions"] as? [[String: Any]] ?? []).map { CTWFeedDemCamXuc(kind: $0["kind"] as? String ?? "", count: $0["count"] as? Int) },
                                 myReaction: p?["myReaction"] as? String)
            let k: CamXucBangTin? = m == "PUT" ? CamXucBangTin(rawValue: b["kind"] as? String ?? "") : nil
            var s = TrangThaiCamXuc(cu)
            if s.cuaToi != k?.rawValue { s = CamXucLogic.ap(s, chon: k) }
            let ds = s.ds.map { ["kind": $0.kind, "count": $0.count ?? 0] as [String: Any] }
            khoa.lock(); camXuc[id] = (s.tong, ds, s.cuaToi); khoa.unlock()
            return ["reactionCount": s.tong, "reactions": ds, "myReaction": s.cuaToi ?? NSNull()]
        case ("GET", "reactions"):
            let nguoi = [G.linh, G.minh, G.an, G.sara, khoaLe, G.toi]
            let kinds = (p?["reactions"] as? [[String: Any]] ?? []).flatMap { r in Array(repeating: r["kind"] as? String ?? "like", count: r["count"] as? Int ?? 0) }
            let loc = b["kind"] as? String
            let items = kinds.enumerated().filter { loc == nil || $0.element == loc }.map { ["user": nguoi[$0.offset % nguoi.count], "kind": $0.element, "createdAt": phut(Double($0.offset * 7))] }
            return ["items": items, "reactions": p?["reactions"] ?? [], "nextCursor": NSNull()]
        case ("PUT", "save"):
            let luu = b["saved"] as? Bool ?? true
            khoa.lock(); if luu { daLuu.insert(id) } else { daLuu.remove(id) }; khoa.unlock()
            return ["saved": luu]
        case ("PUT", "hide"):
            let an = b["hidden"] as? Bool ?? true
            khoa.lock(); if an { daAn.insert(id) } else { daAn.remove(id) }; khoa.unlock()
            return ["hidden": an]
        case ("POST", "report"): khoa.lock(); daAn.insert(id); khoa.unlock(); return ["reported": true, "duplicate": false]
        case ("PUT", "pin"):
            var q = p ?? [:]; q["pinned"] = b["pinned"] ?? false; return q
        case ("PUT", "moderation"):
            var q = p ?? [:]; q["hidden"] = b["hidden"] ?? false; return q
        case ("PUT", "vote"):
            var poll = p?["poll"] as? [String: Any] ?? [:]
            let chon = b["optionIds"] as? [String] ?? []
            let cu = Set(poll["myVotes"] as? [String] ?? [])
            var opts = poll["options"] as? [[String: Any]] ?? []
            for i in opts.indices {
                let oid = opts[i]["id"] as? String ?? ""
                var v = opts[i]["votes"] as? Int ?? 0
                if cu.contains(oid) { v -= 1 }
                if chon.contains(oid) { v += 1 }
                opts[i]["votes"] = max(0, v)
            }
            poll["options"] = opts
            poll["myVotes"] = chon
            let tong = opts.reduce(0) { $0 + ($1["votes"] as? Int ?? 0) }
            poll["totalVotes"] = tong; poll["voters"] = tong
            return poll
        case ("GET", "comments"):
            if let cha = Int("\(b["parentId"] ?? "")") {
                let goc = binhLuanCua(id).first { ($0["id"] as? Int) == cha }
                var tl = goc?["replies"] as? [[String: Any]] ?? []
                if cha == 102 { tl.append(binhLuan(108, 1, G.an, "Em đặt phòng rồi nha", phut: 60 * 21, cha: 102)) }
                return ["comments": tl, "nextCursor": NSNull()]
            }
            return ["comments": binhLuanCua(id), "nextCursor": NSNull()]
        case ("POST", "comments"):
            khoa.lock()
            let cid = 5000 + (binhLuanMoi[id]?.count ?? 0) + id * 10
            let c = binhLuan(cid, id, G.toi, b["body"] as? String ?? "", phut: 0, cha: b["parentId"] as? Int)
            if b["parentId"] == nil { binhLuanMoi[id, default: []].append(c) }
            khoa.unlock()
            return c
        default:
            return ["ok": true]
        }
    }
}
#endif
