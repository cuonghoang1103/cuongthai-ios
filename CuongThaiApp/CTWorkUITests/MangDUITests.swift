import XCTest

/// Giao diện các tính năng 18/10/2026 (tuyến backend mới + mảng D) — bấm thật, máy chủ giả.
final class MangDUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func mo(_ man: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CT_XEM_MAN"] = man
        app.launch()
        return app
    }

    /// My Work → Agenda (`/me/agenda`): họp có nút Join, hạn thẻ của dự án KHÁC cũng hiện.
    func testAgendaXuyenDuAn() throws {
        let app = mo("agenda")
        XCTAssertTrue(app.staticTexts["Daily stand-up"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Join"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Hero section copy review"].exists, "thẻ của dự án WEB")
        app.buttons["Issues"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Project charter + scope statement'")).firstMatch.waitForExistence(timeout: 5))
    }

    /// Hộp thư: nhắc họp có "Join meeting"; cài đặt có công tắc đẩy theo loại + múi giờ.
    func testHopThuJoinVaCaiDatDay() throws {
        let app = mo("caidattb")
        XCTAssertTrue(app.switches.matching(NSPredicate(format: "label CONTAINS %@", "Mentions")).firstMatch.waitForExistence(timeout: 8))
        let nc = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Email & quiet hours")).firstMatch
        for _ in 0..<6 where !(nc.exists && nc.isHittable) { app.swipeUp() }
        nc.tap()
        let muiGio = app.switches.matching(NSPredicate(format: "label CONTAINS %@", "time zone")).firstMatch
        for _ in 0..<6 where !muiGio.exists { app.swipeUp() }
        XCTAssertTrue(muiGio.exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Join meeting"].firstMatch.waitForExistence(timeout: 5))
    }

    /// Account: Face ID lock (mặc định tắt); KHÔNG còn lối "Open CT Work on the web" (3.1.1).
    func testTaiKhoanFaceIdVaKhongLoiWeb() throws {
        let app = mo("account")
        let congTac = app.switches.matching(NSPredicate(format: "label BEGINSWITH %@", "Require")).firstMatch
        XCTAssertTrue(congTac.waitForExistence(timeout: 8) || { app.swipeUp(); return congTac.waitForExistence(timeout: 3) }())
        XCTAssertEqual(congTac.value as? String, "0", "mặc định TẮT")
        XCTAssertFalse(app.buttons["Open CT Work on the web"].exists)
    }

    /// Chat: mục "Direct messages" hiện tên NGƯỜI KIA thay cho `dm-1-2`.
    func testNhanRieng() throws {
        let app = mo("chat2")
        XCTAssertTrue(app.staticTexts["Linh Tran"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["dm-1-2"].exists)
    }

    /// Màn khoá Face ID (máy chủ giả, màn `khoa`).
    func testManKhoa() throws {
        let app = mo("khoa")
        XCTAssertTrue(app.staticTexts["CT Work is locked"].waitForExistence(timeout: 8))
    }
}
