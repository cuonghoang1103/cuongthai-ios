import XCTest
@testable import CTWork

/// Bảng tin — giải mã JSON THẬT của production (cuongthai.com, 22/10/2026, tài khoản demo trong không gian "CT Work Demo";
/// bài thử đã xoá ngay sau khi lấy mẫu; URL ký thay bằng r2.example). Bắt lệch kiểu mà ví dụ trong hợp đồng không bắt được.
final class BangTinThatTests: XCTestCase {
    private func giai<T: Decodable>(_ k: T.Type, _ s: String) throws -> T { try JSONDecoder().decode(T.self, from: Data(s.utf8)) }

    func testBangTinThat() throws {
        let t = try giai(CTWFeedTrang.self, #"{"posts":[{"id":1,"workspace":{"id":15,"slug":"ct-work-demo","name":"CT Work Demo","logoUrl":null},"project":{"id":32,"key":"DEMO","name":"Demo Shop App"},"author":{"id":191,"username":"ctworkdemo","fullName":"CT Work Review","displayName":null,"avatarUrl":null,"kind":"HUMAN"},"authorRole":"ADMIN","body":"iOS test — sẽ xoá ngay #ios @ctworkdemo","mentions":[{"id":191,"username":"ctworkdemo","name":"CT Work Review"}],"hashtags":["ios"],"attachments":[{"id":1,"kind":"IMAGE","status":"READY","fileName":"test.jpg","mime":"image/jpeg","size":3140,"width":1200,"height":800,"durationMs":null,"alt":null,"position":0,"url":"https://r2.example/signed","thumbUrl":"https://r2.example/signed","posterUrl":null,"urlExpiresAt":"2026-10-22T01:20:54.819Z"},{"id":2,"kind":"FILE","status":"READY","fileName":"ghi-chu.txt","mime":"text/plain","size":12,"width":null,"height":null,"durationMs":null,"alt":null,"position":1,"url":"https://r2.example/signed","thumbUrl":null,"posterUrl":null,"urlExpiresAt":"2026-10-22T01:20:56.308Z"}],"linkPreview":null,"refs":[],"poll":null,"reactionCount":1,"reactions":[{"kind":"celebrate","count":1}],"myReaction":"celebrate","commentCount":1,"comments":[{"id":1,"postId":1,"parentId":null,"author":{"id":191,"username":"ctworkdemo","fullName":"CT Work Review","displayName":null,"avatarUrl":null,"kind":"HUMAN"},"body":"Bình luận thử","mentions":[],"reactionCount":0,"reactions":[],"myReaction":null,"replyCount":0,"replies":[],"hidden":false,"hiddenForMe":false,"authorBlocked":false,"reportedByMe":false,"editedAt":null,"createdAt":"2026-10-22T01:10:56.581Z","can":{"edit":true,"delete":true,"moderate":true,"report":false,"reply":true}}],"commentsOff":false,"pinned":false,"pinnedAt":null,"saved":false,"hiddenForMe":false,"hidden":false,"editedAt":null,"createdAt":"2026-10-22T01:10:56.405Z","url":"/work/ct-work-demo/feed?post=1","can":{"edit":true,"delete":true,"pin":true,"moderate":true,"comment":true,"react":true,"report":false}}],"pinned":[],"nextCursor":null}"#)
        let p = try XCTUnwrap(t.posts?.first)
        XCTAssertEqual(p.project?.key, "DEMO")
        XCTAssertEqual(p.anhVaVideo.count, 1)
        XCTAssertEqual(p.tep.first?.fileName, "ghi-chu.txt", "tệp tải qua URL ký (đường B) đã gắn bài")
        XCTAssertEqual(p.camXucCuaToi, .celebrate)
        XCTAssertEqual(p.hiddenForMe, false)
        XCTAssertEqual(p.comments?.first?.body, "Bình luận thử")
        XCTAssertEqual(DichBangTin.tach(p.url ?? "")?.post, p.id)
        XCTAssertEqual(ChuBangTin.manh(p.body ?? "", nhac: p.mentions ?? []).count, 2, "@nhắc + #tag")
    }

    func testBinhLuanVaCamXucThat() throws {
        let c = try giai(CTWFeedTrangBinhLuan.self, #"{"comments":[{"id":1,"postId":1,"parentId":null,"author":{"id":191,"username":"ctworkdemo","fullName":"CT Work Review","displayName":null,"avatarUrl":null,"kind":"HUMAN"},"body":"Bình luận thử","mentions":[],"reactionCount":0,"reactions":[],"myReaction":null,"replyCount":0,"replies":[],"hidden":false,"hiddenForMe":false,"authorBlocked":false,"reportedByMe":false,"editedAt":null,"createdAt":"2026-10-22T01:10:56.581Z","can":{"edit":true,"delete":true,"moderate":true,"report":false,"reply":true}}],"nextCursor":null}"#)
        XCTAssertEqual(c.comments?.count, 1)
        XCTAssertEqual(c.comments?.first?.can?.reply, true)
        let r = try giai(CTWFeedNguoiThaCamXuc.self, #"{"items":[{"user":{"id":191,"username":"ctworkdemo","fullName":"CT Work Review","displayName":null,"avatarUrl":null,"kind":"HUMAN"},"kind":"celebrate","createdAt":"2026-10-22T01:10:56.735Z"}],"reactions":[{"kind":"celebrate","count":1}],"nextCursor":null}"#)
        XCTAssertEqual(r.items?.first?.kind, "celebrate")
    }
}
