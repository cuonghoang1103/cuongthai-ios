import XCTest
@testable import CTWork

/// Bộ giải đường dẫn ảnh (avatar, ảnh trong mô tả) — 20/10/2026: chủ app thấy avatar/ảnh không hiện trên iPhone thật vì
/// máy chủ trả đường dẫn TƯƠNG ĐỐI, khoá R2 trần và SVG.
final class DuongDanAnhTests: XCTestCase {
    private let goc = "https://cuongthai.com"

    func testTuyetDoiGiuNguyen() {
        let s = "https://media.cuongthai.com/images/post/a.webp"
        XCTAssertEqual(DuongDanAnh.url(s, goc: goc)?.absoluteString, s)
        XCTAssertEqual(DuongDanAnh.url("http://x.example/a.png", goc: goc)?.absoluteString, "http://x.example/a.png")
    }

    func testTuongDoiGhepGocTrang() {
        XCTAssertEqual(DuongDanAnh.url("/images/avatars/u1.png", goc: goc)?.absoluteString, "https://cuongthai.com/images/avatars/u1.png")
        XCTAssertEqual(DuongDanAnh.url("/api/v1/work/projects/7/images/3", goc: goc)?.absoluteString,
                       "https://cuongthai.com/api/v1/work/projects/7/images/3")
        XCTAssertEqual(DuongDanAnh.url("//media.cuongthai.com/a.jpg", goc: goc)?.absoluteString, "https://media.cuongthai.com/a.jpg")
    }

    func testKhoaR2TranGhepCDN() {
        XCTAssertEqual(DuongDanAnh.url("avatars/12.webp", goc: goc)?.absoluteString, "https://media.cuongthai.com/avatars/12.webp")
        XCTAssertEqual(DuongDanAnh.url("  avatars/12.webp \n", goc: goc)?.absoluteString, "https://media.cuongthai.com/avatars/12.webp")
    }

    func testBoQuaThuKhongTaiDuoc() {
        XCTAssertNil(DuongDanAnh.url(nil, goc: goc))
        XCTAssertNil(DuongDanAnh.url("", goc: goc))
        XCTAssertNil(DuongDanAnh.url("blob:https://cuongthai.com/1234", goc: goc))
        XCTAssertNil(DuongDanAnh.url("data:image/png;base64,AAAA", goc: goc))
        XCTAssertNil(DuongDanAnh.url("file:///etc/passwd", goc: goc))
    }

    func testSVGKhongPhaiAnhBitmap() {
        // Kingfisher không giải được SVG ⇒ nơi gọi hiện avatar chữ cái thay vì vòng trống.
        XCTAssertNotNil(DuongDanAnh.url("/images/bots/claude-mini.svg", goc: goc))
        XCTAssertNil(DuongDanAnh.urlAnh("/images/bots/claude-mini.svg", goc: goc))
        XCTAssertNil(DuongDanAnh.urlAnh("https://cuongthai.com/images/cuongmini-avatar.SVG?v=2", goc: goc))
        XCTAssertNotNil(DuongDanAnh.urlAnh("/images/a.png", goc: goc))
    }

    func testMauAvatarTheoWeb() {
        // Cùng thuật băm `hashStr` của web ⇒ cùng chỉ số màu (tính tay theo JS: "alex" → 2996766 % 10 = 6).
        XCTAssertEqual(CTWKieuWeb.bam("alex") % CTWKieuWeb.bangMau.count, 6)
        XCTAssertEqual(CTWKieuWeb.chuCau("IN REVIEW"), "In review")
        XCTAssertEqual(CTWKieuWeb.chuCau("Ready for QA"), "Ready for QA")
    }
}
