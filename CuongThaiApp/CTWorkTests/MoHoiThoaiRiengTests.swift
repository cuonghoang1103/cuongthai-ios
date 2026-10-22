import XCTest
@testable import CTWork

/// 22/10/2026: `POST /messages/threads/user/:id` trả bản THÔ (userA/userB, không unreadCount/peer) ⇒ trước đây bấm
/// "Nhắn tin" báo "Máy chủ trả về phản hồi không như mong đợi". JSON dưới là phản hồi THẬT của production.
final class MoHoiThoaiRiengTests: XCTestCase {
    private let tho = #"{"id":68,"type":"USER","userId":null,"adminUserId":null,"userAId":191,"userBId":192,"lastMessageAt":"2026-10-21T16:51:52.028Z","createdAt":"2026-10-21T16:51:51.602Z","updatedAt":"2026-10-21T16:51:52.034Z","preferences":{},"user":null,"adminUser":null,"userA":{"id":191,"username":"ctworkdemo","fullName":"CT Work Review","displayName":null,"avatarUrl":null,"lastActiveAt":null,"showActiveStatus":true},"userB":{"id":192,"username":"ctworkminh","fullName":"Minh (Demo)","displayName":null,"avatarUrl":null,"lastActiveAt":null,"showActiveStatus":true},"messages":[{"id":913,"content":"Perfect, thanks.","senderId":192,"createdAt":"2026-10-21T16:51:52.028Z","attachments":[]}]}"#

    func testBanThoGiaiMaDuocVaChonDungNguoiKia() throws {
        let t = try JSONDecoder().decode(MessageThread.self, from: Data(tho.utf8))
        XCTAssertEqual(t.id, 68)
        XCTAssertEqual(t.unreadCount, 0)
        XCTAssertNil(t.peer)
        let m = t.voiNguoiKia(192)
        XCTAssertEqual(m.peer?.id, 192)
        XCTAssertEqual(m.peer?.username, "ctworkminh")
        XCTAssertEqual(m.displayName, "Minh (Demo)")
        XCTAssertTrue(m.laNhanRieng)
    }

    func testBanDungVanNhuCu() throws {
        let dung = #"{"id":68,"type":"USER","peer":{"id":192,"username":"ctworkminh","displayName":"Minh (Demo)","avatarUrl":null,"alias":null,"lastActiveAt":null},"unreadCount":3,"preferences":null}"#
        let t = try JSONDecoder().decode(MessageThread.self, from: Data(dung.utf8))
        XCTAssertEqual(t.unreadCount, 3)
        XCTAssertEqual(t.peer?.id, 192)
        XCTAssertEqual(t.voiNguoiKia(999).peer?.id, 192, "đã có peer thì giữ nguyên")
    }
}
