import XCTest

/// Kiểm thử GIAO DIỆN mảng Giao tiếp — bấm thật trên máy mô phỏng với máy chủ giả
/// (`CT_XEM_MAN`, chỉ bản DEBUG).
///
///     xcodebuild test -scheme CTWorkApp -destination '…' -only-testing:CTWorkAppUITests/GiaoTiepUITests
final class GiaoTiepUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func mo(_ man: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CT_XEM_MAN"] = man
        app.launch()
        return app
    }

    private func nut(_ app: XCUIApplication, _ chu: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", chu)).firstMatch
    }

    /// Kênh: tin hệ thống cuộc gọi (Join), voice note có bản phiên âm, gửi tin mới, menu tin có Pin + Report.
    func testKenhGuiTinVaMenu() throws {
        let app = mo("kenhday")
        XCTAssertTrue(app.staticTexts["Nice catch. @alex can you take a look after standup?"].waitForExistence(timeout: 10))
        XCTAssertTrue(nut(app, "Join call").exists || app.buttons["Call in progress. Join"].exists || app.buttons["Join call"].exists)
        XCTAssertTrue(app.staticTexts["Auto transcript"].exists, "voice note hiện bản phiên âm có nhãn")
        let o = app.textFields["Message #general"]
        XCTAssertTrue(o.waitForExistence(timeout: 5))
        o.tap()
        o.typeText("See you at the demo")
        app.buttons["Send message"].tap()
        XCTAssertTrue(app.staticTexts["See you at the demo"].waitForExistence(timeout: 6))
        let tin = app.staticTexts["Nice catch. @alex can you take a look after standup?"]
        tin.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Pin to channel"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Report message"].exists)
        XCTAssertTrue(app.buttons["Forward…"].exists)
    }

    /// Deep link `t=` mở thẳng chuỗi trả lời.
    func testChuoiTraLoi() throws {
        let app = mo("chuoi")
        XCTAssertTrue(app.staticTexts["Converting to JPEG before upload fixes it in my test build."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["2 replies"].exists)
    }

    /// Danh sách kênh: mục "Live now" cho cuộc gọi đang mở + nhóm riêng.
    func testDanhSachKenh() throws {
        let app = mo("chat2")
        XCTAssertTrue(app.staticTexts["Live now"].waitForExistence(timeout: 10) || app.staticTexts["LIVE NOW"].exists)
        XCTAssertTrue(app.staticTexts["alex-linh"].exists || app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "alex-linh")).firstMatch.exists)
    }

    /// Chi tiết họp: Join, RSVP, việc ⇒ tạo thẻ.
    func testChiTietHopTaoThe() throws {
        let app = mo("chitiethop")
        XCTAssertTrue(app.staticTexts["Sprint 6 review & demo"].waitForExistence(timeout: 10))
        XCTAssertTrue(nut(app, "Join with Google Meet").exists)
        XCTAssertTrue(app.staticTexts["AI-generated"].exists || app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "AI-generated")).firstMatch.exists,
                      "bản nháp biên bản AI phải có nhãn (4.7)")
        let tao = nut(app, "Create issues for 2 open items")
        for _ in 0..<8 where !tao.isHittable { app.swipeUp() }
        tao.tap()
        XCTAssertTrue(app.staticTexts["Created NW-41."].waitForExistence(timeout: 6))
    }

    /// Hộp thư: Duyệt yêu cầu phê duyệt ngay trong hộp thư.
    func testHopThuPheDuyet() throws {
        let app = mo("hopthu")
        let duyet = app.buttons["Approve"].firstMatch
        XCTAssertTrue(duyet.waitForExistence(timeout: 10))
        duyet.tap()
        let xacNhan = app.sheets.buttons["Approve"].firstMatch.exists ? app.sheets.buttons["Approve"].firstMatch : app.buttons.matching(NSPredicate(format: "label == %@", "Approve")).element(boundBy: 1)
        XCTAssertTrue(xacNhan.waitForExistence(timeout: 4))
        xacNhan.tap()
        XCTAssertTrue(app.staticTexts["You approved"].waitForExistence(timeout: 6))
    }

    /// Hộp thư: trả lời nhanh một lần @nhắc trong chat.
    func testTraLoiNhanh() throws {
        let app = mo("traloinhanh")
        let o = app.textFields["Write a reply…"]
        XCTAssertTrue(o.waitForExistence(timeout: 10))
        o.typeText("On it!")
        app.buttons["Send"].tap()
        XCTAssertFalse(o.waitForExistence(timeout: 3) && o.isHittable, "gửi xong thì đóng tấm trả lời")
    }

    /// Cài đặt thông báo đọc được từ máy chủ.
    func testCaiDatThongBao() throws {
        let app = mo("caidattb")
        XCTAssertTrue(app.staticTexts["Quiet hours"].waitForExistence(timeout: 10) || app.switches["Quiet hours"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Notify me about"].exists || app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Notify me about")).firstMatch.exists)
    }
}
