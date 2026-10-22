import XCTest
@testable import CTWork

/// Bảng tin (Team Feed, 21/10/2026) — hợp đồng `api-backend/docs/ctw-feed-hop-dong-api.md`.
/// Giải mã ĐÚNG ví dụ JSON trong hợp đồng + dữ liệu mẫu (`Debug/XemThuCTW+BangTin.swift`) bằng model thật; logic thuần:
/// @nhắc/#tag/link, bố cục lưới ảnh, gộp trang + chống trùng, chèn lạc quan, đường dẫn sâu, cảm xúc, đo máy chủ cũ.
@MainActor
final class BangTinCTWTests: XCTestCase {

    private func giai<T: Decodable>(_ kieu: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    private func giaiGia<T: Decodable>(_ kieu: T.Type, _ path: String, method: String = "GET", body: [String: Any] = [:]) throws -> T {
        let d = DuLieuGia.traLoi(method: method, path: "/api/v1" + path, body: body)
        let r = try JSONDecoder().decode(APIResponse<T>.self, from: d)
        XCTAssertTrue(r.success)
        return try XCTUnwrap(r.data)
    }

    // MARK: Ví dụ JSON của hợp đồng (§1, §2, §7)

    static let viDuBai = """
    {
      "id": 12,
      "workspace": { "id": 1, "slug": "acme", "name": "Acme Studio", "logoUrl": null },
      "project": { "id": 3, "key": "FP", "name": "Flying Pencil" },
      "author": { "id": 7, "username": "an", "fullName": "An Nguyen", "displayName": null, "avatarUrl": null, "kind": "HUMAN" },
      "authorRole": "ADMIN",
      "body": "Sprint 4 demo is **Friday** — @an please bring the build. See /work/acme/FP/issue/12 #demo",
      "mentions": [ { "id": 7, "username": "an", "name": "An Nguyen" } ],
      "hashtags": ["demo"],
      "attachments": [ {
        "id": 41, "kind": "IMAGE", "status": "READY",
        "fileName": "sprint-demo.png", "mime": "image/png", "size": 482113,
        "width": 1920, "height": 1080, "durationMs": null, "alt": "Burndown chart, sprint 4",
        "position": 0, "url": "https://r2.example/signed", "thumbUrl": "https://r2.example/thumb", "posterUrl": null,
        "urlExpiresAt": "2026-10-21T10:10:00.000Z"
      } ],
      "linkPreview": { "url": "https://react.dev/blog", "domain": "react.dev", "title": "React Blog", "description": "…", "siteName": "React",
                       "imageUrl": "https://r2.example/og" },
      "refs": [ { "t": "issue", "key": "FP-12", "n": 12, "url": "/work/acme/FP/issue/12", "title": "Login page",
                  "status": { "name": "In Progress", "category": "IN_PROGRESS" }, "type": { "key": "story", "name": "Story", "color": "#4BADE8" },
                  "assignee": { "id": 7, "name": "An Nguyen", "avatarUrl": null }, "project": "Flying Pencil", "when": null } ],
      "poll": { "options": [ { "id": "a", "text": "Thứ 5", "votes": 3 }, { "id": "b", "text": "Thứ 6", "votes": 1 } ],
                "multi": false, "closesAt": null, "closed": false, "totalVotes": 4, "voters": 4, "myVotes": ["a"] },
      "reactionCount": 5,
      "reactions": [ { "kind": "like", "count": 3 }, { "kind": "celebrate", "count": 2 } ],
      "myReaction": "like",
      "commentCount": 4,
      "comments": [ {
        "id": 88, "postId": 12, "parentId": null,
        "author": { "id": 9, "username": "minh", "fullName": "Minh", "displayName": null, "avatarUrl": null, "kind": "HUMAN" },
        "body": "On it @minh", "mentions": [ { "id": 9, "username": "minh", "name": "Minh" } ],
        "reactionCount": 1, "reactions": [ { "kind": "like", "count": 1 } ], "myReaction": null,
        "replyCount": 2, "replies": [],
        "hidden": false, "hiddenForMe": false, "authorBlocked": false, "reportedByMe": false,
        "editedAt": null, "createdAt": "2026-10-21T09:00:00.000Z",
        "can": { "edit": true, "delete": true, "moderate": false, "report": false, "reply": true }
      } ],
      "commentsOff": false,
      "pinned": true, "pinnedAt": "2026-10-21T08:00:00.000Z",
      "saved": false,
      "hidden": false,
      "editedAt": null, "createdAt": "2026-10-21T08:00:00.000Z",
      "url": "/work/acme/feed?post=12",
      "can": { "edit": true, "delete": true, "pin": true, "moderate": true, "comment": true, "react": true, "report": false }
    }
    """

    func testGiaiMaBaiTheoHopDong() throws {
        let p = try giai(CTWFeedPost.self, Self.viDuBai)
        XCTAssertEqual(p.id, 12)
        XCTAssertEqual(p.workspace?.slug, "acme")
        XCTAssertEqual(p.project?.key, "FP")
        XCTAssertEqual(p.author?.ten, "An Nguyen")
        XCTAssertEqual(p.anhVaVideo.first?.alt, "Burndown chart, sprint 4")
        XCTAssertEqual(p.anhVaVideo.first?.tiLe ?? 0, 1920.0 / 1080, accuracy: 0.001)
        XCTAssertEqual(p.refs?.first?.status?.category, "IN_PROGRESS")
        XCTAssertEqual(p.poll?.myVotes, ["a"])
        XCTAssertEqual(p.camXucCuaToi, .like)
        XCTAssertEqual(p.comments?.first?.replyCount, 2)
        XCTAssertEqual(p.can?.pin, true)
        XCTAssertEqual(p.linkPreview?.domain, "react.dev")
        XCTAssertFalse(p.laTam, "bài từ máy chủ không phải bài tạm")
    }

    func testGiaiMaPhamViVaBaoCao() throws {
        let pv = try giai(CTWFeedPhamVi.self, """
        { "scopes": [ { "workspace": { "id": 1, "slug": "acme", "name": "Acme Studio", "logoUrl": null },
          "role": "ADMIN", "canPost": true, "canModerate": true, "follow": "ALL",
          "projects": [ { "id": 3, "key": "FP", "name": "Flying Pencil", "role": "MEMBER", "canPost": true, "canModerate": false, "follow": "ALL" } ]
        } ], "openReports": 2 }
        """)
        XCTAssertEqual(pv.scopes?.first?.projects?.first?.key, "FP")
        XCTAssertEqual(pv.openReports, 2)
        let r = try giai(CTWFeedTrangBaoCao.self, """
        { "reports": [ { "id": 5, "status": "OPEN", "reason": "spam", "detail": null, "createdAt": "2026-10-21T08:00:00.000Z",
          "reporter": { "id": 2, "username": "b", "fullName": "B", "displayName": null, "avatarUrl": null, "kind": "HUMAN" }, "reportCount": 2,
          "target": { "type": "post", "postId": 12, "commentId": null, "excerpt": "…",
                      "author": { "id": 7, "username": "an", "fullName": "An", "displayName": null, "avatarUrl": null, "kind": "HUMAN" },
                      "hidden": false, "deleted": false },
          "workspace": { "id": 1, "slug": "acme", "name": "Acme Studio" }, "project": { "id": 3, "key": "FP", "name": "Flying Pencil" },
          "resolvedBy": null, "resolvedAt": null, "action": null, "url": "/work/acme/feed?post=12" } ], "nextCursor": null, "openCount": 2 }
        """)
        XCTAssertEqual(r.reports?.first?.target?.postId, 12)
        XCTAssertEqual(LyDoBaoCaoBangTin(rawValue: r.reports?.first?.reason ?? "")?.rawValue, "spam")
        let x = try giai(CTWFeedXinTaiLen.self, """
        { "attachment": { "id": 50, "kind": "VIDEO", "status": "PENDING", "url": null }, "uploadUrl": "https://r2/put", "method": "PUT",
          "headers": { "Content-Type": "video/mp4" }, "expiresAt": "2026-10-21T11:00:00.000Z" }
        """)
        XCTAssertEqual(x.headers?["Content-Type"], "video/mp4")
        XCTAssertFalse(x.attachment.sanSang)
    }

    func testGiaiMaDuLieuMau() throws {
        let t = try giaiGia(CTWFeedTrang.self, "/work/feed")
        XCTAssertEqual(t.posts?.count, 6)
        XCTAssertEqual(t.nextCursor, "p2", "bảng tin gộp có trang sau")
        XCTAssertTrue(t.pinned?.isEmpty ?? true, "bảng tin gộp không có mục ghim riêng")
        let t2 = try giaiGia(CTWFeedTrang.self, "/work/feed", body: ["cursor": "p2"])
        XCTAssertNil(t2.nextCursor)
        let duAn = try giaiGia(CTWFeedTrang.self, "/work/feed", body: ["workspaceId": 1])
        XCTAssertEqual(duAn.pinned?.map(\.id), [1], "lọc một phạm vi ⇒ bài ghim tách riêng")
        XCTAssertFalse(duAn.posts?.contains { $0.id == 1 } ?? true, "bài ghim không lặp trong posts")
        let bl = try giaiGia(CTWFeedTrangBinhLuan.self, "/work/feed/posts/1/comments")
        XCTAssertEqual(bl.comments?.first(where: { $0.id == 102 })?.replyCount, 3)
        XCTAssertEqual(bl.comments?.first(where: { $0.id == 107 })?.hiddenForMe, true)
        _ = try giaiGia(CTWFeedPhamVi.self, "/work/feed/scopes")
        _ = try giaiGia(CTWFeedNguoiThaCamXuc.self, "/work/feed/posts/1/reactions")
        _ = try giaiGia(CTWFeedTrangBaoCao.self, "/work/feed/reports")
        let video = try XCTUnwrap(t.posts?.first { $0.anhVaVideo.first?.laVideo == true }?.anhVaVideo.first)
        XCTAssertEqual(video.durationMs, 45_000)
        XCTAssertEqual(LuoiPhuongTienCTW.thoiLuong(45_000), "0:45")
    }

    // MARK: Chữ: @nhắc · #tag · link · mã thẻ

    func testNhacChiToNguoiTrongMentions() {
        let chu = "Cảm ơn @an và @la_ai_do, email a@b.com, xem #demo #sprint_6 và /work/acme/FP/issue/12 hoặc FP-7 https://react.dev/x#y"
        let m = ChuBangTin.manh(chu, nhac: [CTWFeedNhac(id: 7, username: "an", name: "An")], maDuAn: "FP")
        let loai = m.map(\.1)
        XCTAssertTrue(loai.contains(.nhac(id: 7, username: "an")))
        XCTAssertFalse(loai.contains { if case .nhac(_, let u) = $0 { return u == "la_ai_do" }; return false }, "người ngoài mentions không tô")
        XCTAssertFalse(loai.contains { if case .nhac(_, let u) = $0 { return u == "b.com" }; return false }, "@ trong email không phải @nhắc")
        XCTAssertTrue(loai.contains(.hashtag("demo")))
        XCTAssertTrue(loai.contains(.hashtag("sprint_6")))
        XCTAssertFalse(loai.contains(.hashtag("y")), "#anchor trong URL không phải hashtag")
        XCTAssertTrue(loai.contains(.url(URL(string: "https://cuongthai.com/work/acme/FP/issue/12")!)))
        XCTAssertTrue(loai.contains(.maThe(key: "FP", so: 7)))
        XCTAssertTrue(loai.contains { if case .url(let u) = $0 { return u.host == "react.dev" }; return false })
        // Không chồng nhau, theo thứ tự.
        for i in 1..<m.count { XCTAssertLessThanOrEqual(m[i - 1].0.upperBound, m[i].0.lowerBound) }
    }

    func testHashtagTiengVietVaMaTheChiTrongDuAn() {
        let m = ChuBangTin.manh("Chúc mừng #ra_mắt #ĐàLạt NW-3 X-1", nhac: [], maDuAn: "NW")
        XCTAssertTrue(m.map(\.1).contains(.hashtag("ra_mắt")))
        XCTAssertTrue(m.map(\.1).contains(.hashtag("ĐàLạt")))
        XCTAssertTrue(m.map(\.1).contains(.maThe(key: "NW", so: 3)))
        XCTAssertFalse(m.map(\.1).contains(.maThe(key: "X", so: 1)), "mã của dự án khác không tự thành link")
        XCTAssertTrue(ChuBangTin.manh("NW-3", nhac: [], maDuAn: nil).isEmpty, "bài cấp không gian: không đoán mã thẻ")
        XCTAssertTrue(ChuBangTin.manh("#a", nhac: []).isEmpty, "hashtag ít nhất 2 ký tự")
    }

    func testDungChuGanLinkVaGiuMarkdown() {
        let a = ChuBangTin.dung("**Thứ Sáu** @an xem #demo", nhac: [CTWFeedNhac(id: 7, username: "an", name: "An")], maDuAn: nil, slug: "acme")
        XCTAssertEqual(String(a.characters), "Thứ Sáu @an xem #demo", "markdown đã dựng, không còn **")
        let links = a.runs.compactMap(\.link).map(\.absoluteString)
        XCTAssertEqual(links, ["ctwfeed://nguoi/7", "ctwfeed://tag/demo"])
        XCTAssertEqual(ChuBangTin.thuan("**a** _b_"), "a b")
        XCTAssertTrue(ChuBangTin.canThuGon(String(repeating: "x", count: 300)))
        XCTAssertTrue(ChuBangTin.canThuGon("1\n2\n3\n4\n5\n6\n7"))
        XCTAssertFalse(ChuBangTin.canThuGon("ngắn"))
    }

    func testNhacDangGo() {
        XCTAssertEqual(NhacDangGo.dangGo("Cảm ơn @mi"), "mi")
        XCTAssertEqual(NhacDangGo.dangGo("@"), "")
        XCTAssertNil(NhacDangGo.dangGo("email a@b"), "dính chữ trước ⇒ không phải @nhắc")
        XCTAssertNil(NhacDangGo.dangGo("@an "), "đã gõ xong")
        XCTAssertNil(NhacDangGo.dangGo("không có"))
        XCTAssertEqual(NhacDangGo.chen("Cảm ơn @mi", username: "minh"), "Cảm ơn @minh ")
        XCTAssertEqual(NhacDangGo.chen("Xin chào", username: "an"), "Xin chào@an ")
    }

    // MARK: Bố cục lưới ảnh

    private func a(_ id: Int, _ w: Int? = nil, _ h: Int? = nil, video: Bool = false) -> CTWFeedAttachment {
        CTWFeedAttachment(id: id, kind: video ? "VIDEO" : "IMAGE", width: w, height: h)
    }

    func testBoCucAnh() {
        XCTAssertNil(BoCucAnh.chon([]))
        XCTAssertEqual(BoCucAnh.chon([a(1, 1920, 1080)]), .mot(tiLe: 1920.0 / 1080))
        XCTAssertEqual(BoCucAnh.chon([a(1, 1000, 3000)]), .mot(tiLe: 0.8), "ảnh dọc kẹp 4:5")
        XCTAssertEqual(BoCucAnh.chon([a(1, 4000, 1000)]), .mot(tiLe: 1.91), "ảnh toàn cảnh kẹp 1,91:1")
        XCTAssertEqual(BoCucAnh.chon([a(1, video: true)]), .mot(tiLe: 16.0 / 9), "video chưa đo ⇒ 16:9")
        XCTAssertEqual(BoCucAnh.chon([a(1), a(2)]), .hai)
        XCTAssertEqual(BoCucAnh.chon([a(1), a(2), a(3)]), .ba)
        XCTAssertEqual(BoCucAnh.chon((1...4).map { a($0) }), .bon(thua: 0))
        XCTAssertEqual(BoCucAnh.chon((1...10).map { a($0) }), .bon(thua: 6))
        XCTAssertEqual(BoCucAnh.bon(thua: 6).soO, 4)
    }

    func testThuNhoAnh() {
        XCTAssertEqual(AnhBangTin.kichThuoc(rong: 4032, cao: 3024), CGSize(width: 2048, height: 1536))
        XCTAssertEqual(AnhBangTin.kichThuoc(rong: 3024, cao: 4032), CGSize(width: 1536, height: 2048))
        XCTAssertEqual(AnhBangTin.kichThuoc(rong: 800, cao: 600), CGSize(width: 800, height: 600), "ảnh nhỏ giữ nguyên")
        let du = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 1000)).pngData { c in UIColor.red.setFill(); c.fill(CGRect(x: 0, y: 0, width: 3000, height: 1000)) }
        let (j, s) = try! XCTUnwrap(AnhBangTin.nen(du))
        XCTAssertEqual(s.width, 2048)
        XCTAssertEqual(UIImage(data: j)?.size.width, 2048, "đã đổi sang JPEG thu nhỏ")
    }

    // MARK: Trang + lạc quan

    private func p(_ id: Int, _ gio: String = "2026-10-21T08:00:00.000Z", body: String? = nil) -> CTWFeedPost {
        var x = CTWFeedPost(id: id); x.createdAt = gio; x.body = body; return x
    }

    func testNoiTrangChongTrung() {
        let cu = [p(5), p(4), p(3)]
        let moi = [p(3, body: "đã sửa"), p(2), p(1)]
        let kq = TrangBangTin.noi(cu, moi)
        XCTAssertEqual(kq.map(\.id), [5, 4, 3, 2, 1], "bài lặp ở mép trang không nhân đôi")
        XCTAssertEqual(kq[2].body, "đã sửa", "bản mới thay tại chỗ")
    }

    func testLamMoiGiuBaiTam() {
        let tam = TrangBangTin.baiTam(khoa: "ios-k1", toi: nil, chu: "x", ws: nil, duAn: nil, dinhKem: [])
        let ds = TrangBangTin.lamMoi([tam, p(3)], dau: [p(9), p(3)])
        XCTAssertEqual(ds.first?.khoaTam, "ios-k1", "bài đang đăng không mất khi kéo làm mới")
        XCTAssertEqual(ds.dropFirst().map(\.id), [9, 3])
    }

    func testChenVaThayBaiTam() {
        let tam = TrangBangTin.baiTam(khoa: "ios-k1", toi: CTWUser(id: 1, username: "alex"), chu: "Xin chào", ws: nil, duAn: nil, dinhKem: [])
        XCTAssertTrue(tam.laTam)
        XCTAssertLessThan(tam.id, 0, "id tạm âm — không đụng id thật")
        var ds = TrangBangTin.chenTam([p(5), p(4)], tam)
        XCTAssertEqual(ds.first?.khoaTam, "ios-k1")
        ds = TrangBangTin.danhDauHong(ds, khoa: "ios-k1")
        XCTAssertEqual(ds.first?.dangHong, true)
        // Socket đã kéo bài thật vào trước khi POST trả lời ⇒ không nhân đôi.
        ds.insert(p(42), at: 1)
        let that = p(42, body: "Xin chào")
        ds = TrangBangTin.thayTam(ds, khoa: "ios-k1", bang: that)
        XCTAssertEqual(ds.map(\.id), [42, 5, 4])
        XCTAssertFalse(ds.contains { $0.laTam })
        // Bài tạm đã bị bỏ (kéo làm mới…) ⇒ bài thật chèn đầu, một lần.
        XCTAssertEqual(TrangBangTin.thayTam([p(5)], khoa: "khac", bang: p(43)).map(\.id), [43, 5])
        XCTAssertEqual(TrangBangTin.boTam([tam, p(5)], khoa: "ios-k1").map(\.id), [5])
        XCTAssertLessThanOrEqual(TrangBangTin.khoaMoi().count, 40, "clientKey ≤ 40 ký tự (hợp đồng §4)")
    }

    func testLocBaiNguoiDaChan() {
        var a1 = p(1); a1.author = CTWUser(id: 9)
        var a2 = p(2); a2.author = CTWUser(id: 3)
        XCTAssertEqual(TrangBangTin.loc([a1, a2], daChan: [9], daAn: []).map(\.id), [2])
        XCTAssertEqual(TrangBangTin.loc([a1, a2], daChan: [], daAn: [2]).map(\.id), [1])
    }

    func testBinhLuanGopTraLoiVaXoa() {
        var g = CTWFeedComment(id: 1, replyCount: 1, replies: [CTWFeedComment(id: 2, parentId: 1)])
        g.postId = 9
        var ds = BinhLuanLogic.noi([], [g, CTWFeedComment(id: 3)])
        ds = BinhLuanLogic.themTraLoi(ds, CTWFeedComment(id: 4, parentId: 1))
        XCTAssertEqual(ds.first?.replies?.map(\.id), [2, 4])
        XCTAssertEqual(ds.first?.replyCount, 2)
        let (sauXoaTl, bot1) = BinhLuanLogic.xoa(ds, id: 4)
        XCTAssertEqual(bot1, 1)
        XCTAssertEqual(sauXoaTl.first?.replies?.map(\.id), [2])
        let (sauXoaGoc, bot2) = BinhLuanLogic.xoa(ds, id: 1)
        XCTAssertEqual(bot2, 3, "xoá gốc ⇒ trừ cả trả lời")
        XCTAssertEqual(sauXoaGoc.map(\.id), [3])
        XCTAssertEqual(BinhLuanLogic.thay(ds, CTWFeedComment(id: 2, body: "sửa")).first?.replies?.first?.body, "sửa")
    }

    // MARK: Cảm xúc

    func testCamXuc() {
        let goc = TrangThaiCamXuc(tong: 5, ds: [CTWFeedDemCamXuc(kind: "like", count: 3), CTWFeedDemCamXuc(kind: "celebrate", count: 2)], cuaToi: nil)
        XCTAssertEqual(CamXucLogic.khiCham(goc), .like)
        let thich = CamXucLogic.ap(goc, chon: .like)
        XCTAssertEqual(thich.tong, 6); XCTAssertEqual(thich.cuaToi, "like"); XCTAssertEqual(thich.ds.first?.count, 4)
        XCTAssertNil(CamXucLogic.khiCham(thich), "đã thả ⇒ chạm là bỏ")
        let doi = CamXucLogic.ap(thich, chon: .love)
        XCTAssertEqual(doi.tong, 6, "đổi loại không tăng tổng (một người một cảm xúc)")
        XCTAssertEqual(doi.cuaToi, "love")
        XCTAssertEqual(doi.ds.map(\.kind), ["like", "celebrate", "love"], "giảm dần theo số")
        let bo = CamXucLogic.ap(doi, chon: nil)
        XCTAssertEqual(bo.tong, 5); XCTAssertNil(bo.cuaToi)
        XCTAssertFalse(bo.ds.contains { $0.kind == "love" }, "về 0 ⇒ rơi khỏi danh sách")
        XCTAssertNil(CamXucLogic.ap(doi, chon: .love).cuaToi, "chọn đúng loại đang có ⇒ bỏ")
        XCTAssertEqual(CamXucLogic.baDau(goc), [.like, .celebrate])
        XCTAssertEqual(CamXucBangTin.allCases.map(\.emoji), ["👍", "❤️", "😂", "😮", "😢", "🎉"], "cùng bộ với web")
    }

    // MARK: Đường dẫn sâu

    func testDuongDanSau() {
        XCTAssertEqual(DichBangTin.tach("/work/acme/feed?post=12&comment=88"), DichBangTin(slug: "acme", post: 12, comment: 88))
        XCTAssertEqual(DichBangTin.tach("https://cuongthai.com/work/acme/feed?post=12"), DichBangTin(slug: "acme", post: 12, comment: nil))
        XCTAssertEqual(DichBangTin.tach("ctwork://x/work/acme/feed?comment=3&post=5")?.post, 5)
        XCTAssertNil(DichBangTin.tach("/work/acme/FP/issue/12"))
        XCTAssertNil(DichBangTin.tach("/work/acme/feed"), "thiếu post")
        XCTAssertNil(DichBangTin.tach("/work/acme/FP/feed?post=1"), "chỉ đường cấp không gian (hợp đồng §9)")
        XCTAssertEqual(DichBangTin.urlWeb("/work/acme/feed?post=12")?.absoluteString, "https://cuongthai.com/work/acme/feed?post=12")
    }

    func testDinhTuyenMoBai() {
        let app = AppState.shared, kho = KhoBangTinCTW.shared
        let cu = (app.isAuthenticated, app.muc)
        defer { app.isAuthenticated = cu.0; app.muc = cu.1; kho.canMo = nil }
        app.isAuthenticated = true
        app.muc = .hopThu
        DinhTuyenCTW.mo(duongDan: "/work/acme/feed?post=12&comment=88")
        XCTAssertEqual(app.muc, .viecCuaToi)
        XCTAssertEqual(kho.canMo, .bai(id: 12, binhLuan: 88))
    }

    // MARK: Bộ lọc + socket + máy chủ cũ

    func testThamSoBoLoc() {
        XCTAssertTrue(LocBangTin.gop.thamSo.isEmpty, "bảng tin gộp: không tham số")
        var l = LocBangTin.khongGian(1)
        l.chiKhongGian = true
        l.kieu = .media
        XCTAssertEqual(l.thamSo["workspaceId"] as? Int, 1)
        XCTAssertEqual(l.thamSo["level"] as? String, "workspace")
        XCTAssertEqual(l.thamSo["filter"] as? String, "media")
        XCTAssertFalse(l.coMucGhim)
        XCTAssertTrue(LocBangTin.duAn(3).coMucGhim)
        XCTAssertFalse(LocBangTin.gop.coMucGhim)
        XCTAssertTrue(LocBangTin.duAn(3).thuoc(ws: 1, pid: 3))
        XCTAssertFalse(LocBangTin.duAn(3).thuoc(ws: 1, pid: nil))
        XCTAssertTrue(LocBangTin.gop.thuoc(ws: 9, pid: nil))
    }

    func testSuKienSocket() {
        let e = SuKienBangTinCTW.tu(["type": "comment.created", "postId": 12, "workspaceId": 1, "projectId": 3, "actorId": 7,
                                    "commentId": 88, "parentId": NSNull(), "commentCount": 5, "at": "2026-10-21T09:00:00Z"])
        XCTAssertEqual(e?.commentCount, 5)
        XCTAssertNil(e?.parentId)
        XCTAssertNil(SuKienBangTinCTW.tu(["type": "post.created"]), "thiếu postId ⇒ bỏ")
    }

    func testMayChuCuAnBangTin() {
        let kho = KhoBangTinCTW.shared
        let tim404 = Data(#"{"success":false,"message":"Route GET /api/v1/work/feed/scopes not found"}"#.utf8)
        kho.apKetQuaDo(maHTTP: 404, du: tim404)
        XCTAssertEqual(kho.hoTro, false)
        XCTAssertFalse(kho.hien, "máy chủ cũ ⇒ ẩn mọi lối vào")
        XCTAssertFalse(CTWModule.feed.hien(nil))
        let co = DuLieuGia.traLoi(method: "GET", path: "/api/v1/work/feed/scopes", body: [:])
        kho.apKetQuaDo(maHTTP: 200, du: co)
        XCTAssertEqual(kho.hoTro, true)
        XCTAssertTrue(kho.hien)
        XCTAssertEqual(kho.noiDang.count, 5, "2 không gian + 3 dự án đăng được")
        var cfg = try! giaiGia(CTWProjectConfig.self, "/work/projects/7")
        XCTAssertTrue(CTWModule.feed.hien(cfg))
        cfg.role = "CLIENT"
        XCTAssertFalse(CTWModule.feed.hien(cfg), "khách cổng không bao giờ thấy bảng tin")
        kho.apKetQuaDo(maHTTP: 500, du: Data())
        XCTAssertEqual(kho.hoTro, true, "lỗi 5xx tạm thời ⇒ giữ kết luận cũ")
        kho.apKetQuaDo(maHTTP: 200, du: Data(#"{"success":true,"data":{"scopes":[],"openReports":0}}"#.utf8))
        XCTAssertFalse(kho.hien, "không đọc được phạm vi nào (vai CLIENT) ⇒ ẩn")
    }

    func testTuKhoaTimKiem() {
        XCTAssertNotNil(CTWDangKyMoDun.moDun("feed"))
        XCTAssertTrue(CTWTuKhoaMoDun.cua("feed").contains("bang tin"))
        XCTAssertTrue(CTWTuKhoaMoDun.cua("feed").contains("dang bai"))
        let feed = CTWXepHangTim.manApp.first { $0.id == "app:feed" }
        XCTAssertNotNil(feed)
        XCTAssertEqual(CTWXepHangTim.xep("bai viet", CTWXepHangTim.manApp).first?.id, "app:feed")
    }
}
