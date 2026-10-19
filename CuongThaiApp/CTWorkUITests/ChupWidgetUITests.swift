import XCTest

/// Đưa app vào trạng thái để CHỤP widget + Live Activity cho App Store (không phải kiểm thử hồi quy):
/// bấm Pause → Resume trên đồng hồ (Live Activity bật), về Màn hình chính, thêm widget "My work today".
/// Chỉ chạy khi `TEST_RUNNER_CTW_CHUP=1` (xcodebuild chuyển thành biến môi trường `CTW_CHUP` của bộ chạy test).
final class ChupWidgetUITests: XCTestCase {
    func testDuaWidgetVaLiveActivityLenManHinh() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CTW_CHUP"] == "1")
        let app = XCUIApplication()
        app.launchEnvironment["CT_XEM_MAN"] = "mod:time"
        app.launch()
        let dung = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Pause'")).firstMatch
        XCTAssertTrue(dung.waitForExistence(timeout: 10))
        dung.tap()
        let chay = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Resume'")).firstMatch
        if chay.waitForExistence(timeout: 5) { chay.tap() }
        sleep(2)
        XCUIDevice.shared.press(.home)
        sleep(2)

        let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        // Nhấn giữ khoảng trống ⇒ chế độ sửa Màn hình chính.
        sb.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62)).press(forDuration: 1.6)
        let sua = sb.buttons["Edit"]
        if sua.waitForExistence(timeout: 3) { sua.tap() }
        let them = sb.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Add Widget'")).firstMatch
        if them.waitForExistence(timeout: 4) { them.tap() }
        add(XCTAttachment(screenshot: sb.screenshot()))
        let tim = sb.searchFields.firstMatch
        if tim.waitForExistence(timeout: 5) {
            tim.tap()
            tim.typeText("CT Work")
        }
        let ketQua = sb.descendants(matching: .any).matching(NSPredicate(format: "label == 'CT Work'")).element(boundBy: 0)
        if ketQua.waitForExistence(timeout: 5) { ketQua.tap() }
        add(XCTAttachment(screenshot: sb.screenshot()))
        // Kéo sang cỡ vừa (medium) nếu có.
        sleep(1)
        sb.swipeLeft()
        sleep(1)
        let nutThem = sb.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Add Widget'")).firstMatch
        if nutThem.waitForExistence(timeout: 5) { nutThem.tap() }
        sleep(2)
        let xong = sb.buttons["Done"]
        if xong.waitForExistence(timeout: 3) { xong.tap() } else {
            sb.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).tap()
        }
        sleep(3)
        add(XCTAttachment(screenshot: sb.screenshot()))
    }

    /// Màn hình khoá có Live Activity của đồng hồ. Khoá máy bằng selector riêng của bộ mô phỏng (chỉ dùng để CHỤP).
    func testManHinhKhoaLiveActivity() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CTW_CHUP"] == "1")
        let app = XCUIApplication()
        app.launchEnvironment["CT_XEM_MAN"] = "mod:time"
        app.launch()
        let dung = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Pause'")).firstMatch
        XCTAssertTrue(dung.waitForExistence(timeout: 10))
        dung.tap()
        let chay = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Resume'")).firstMatch
        if chay.waitForExistence(timeout: 5) { chay.tap() }
        sleep(3)
        XCUIDevice.shared.press(.home)
        sleep(2)
        let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let a1 = XCTAttachment(screenshot: sb.screenshot()); a1.name = "home-la"; a1.lifetime = .keepAlways; add(a1)
        XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        sleep(2)
        XCUIDevice.shared.press(.home)   // đánh thức màn khoá (không mở khoá)
        sleep(3)
        // Lần đầu iOS hỏi "Allow Live Activities from CT Work?" ngay dưới Live Activity — chấp nhận rồi chụp lại.
        let choPhep = sb.buttons["Allow"]
        if choPhep.waitForExistence(timeout: 2) { choPhep.tap(); sleep(2) }
        let a2 = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a2.name = "lock-la"; a2.lifetime = .keepAlways; add(a2)
    }
}
