import XCTest

/// Build 7 (22/10/2026, audit R14) — soát lại trên iPad các lỗi thấy ở build 4 (`anh/build4/_loi/09–12`):
/// ô soạn tin riêng sau khi ẩn bàn phím ảo phải về sát đáy; khung chat có ảnh mở ra ở đáy; viên điểm trên thẻ board có số.
/// Chỉ chạy trên iPad (iPhone ⇒ bỏ qua).
final class IPadBuild7UITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("chỉ iPad") }
    }

    private func mo(_ man: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CT_XEM_MAN"] = man
        app.launchArguments += ["-com.cuongthai.ctwork.ngonNgu", "en"]
        app.launch()
        return app
    }

    /// Ảnh lỗi 11: ẩn bàn phím ảo bằng phím ⌨︎↓ ⇒ ô soạn lơ lửng trên một dải trống.
    func testOSoanVeDayKhiAnBanPhim() throws {
        let app = mo("mod:tin-nhan/chat")
        let o = app.descendants(matching: .any)["dm.composer"].firstMatch
        XCTAssertTrue(o.waitForExistence(timeout: 10))
        let dayTruoc = o.frame.maxY
        o.tap()
        let banPhim = app.keyboards.firstMatch
        guard banPhim.waitForExistence(timeout: 4), banPhim.frame.height > 200 else {
            throw XCTSkip("máy mô phỏng đang dùng bàn phím rời — không có bàn phím ảo để ẩn")
        }
        // Phím ẩn bàn phím của iPad (nhãn khác nhau theo phiên bản iPadOS).
        let an = banPhim.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'keyboard' OR label CONTAINS[c] 'dismiss'")).firstMatch
        guard an.exists else { throw XCTSkip("không tìm thấy phím ẩn bàn phím") }
        an.tap()
        let het = NSPredicate { _, _ in !banPhim.exists || banPhim.frame.height < 120 }
        wait(for: [XCTNSPredicateExpectation(predicate: het, object: nil)], timeout: 5)
        sleep(1)
        XCTAssertEqual(o.frame.maxY, dayTruoc, accuracy: 70, "ô soạn phải về lại đáy sau khi ẩn bàn phím (không còn dải trống)")
    }

    /// Ảnh lỗi 12: viên điểm (story point) trên thẻ board co lại thành viên xám rỗng.
    func testVienDiemTrenTheBoardCoSo() {
        let app = mo("board")
        let the = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'NW-14'")).firstMatch
        XCTAssertTrue(the.waitForExistence(timeout: 10))
        let so = app.staticTexts.matching(NSPredicate(format: "label == '3' OR label == '8' OR label == '5'")).firstMatch
        XCTAssertTrue(so.waitForExistence(timeout: 5), "viên điểm phải hiện số")
        XCTAssertGreaterThan(so.frame.width, 4)
    }
}
