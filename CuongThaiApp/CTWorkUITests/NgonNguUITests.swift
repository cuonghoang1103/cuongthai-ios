import XCTest

/// Đổi ngôn ngữ NGAY trong app (Account › Language) — bấm thật trên máy mô phỏng.
///
/// Chạy được ở MỌI ngôn ngữ đang chọn: bấm "English" ⇒ tiêu đề tab Account phải là "Account";
/// bấm "Tiếng Việt" ⇒ "Tài khoản" — không khởi động lại app. Kết thúc ở "Tiếng Việt".
/// `CTW_CHUP_NN=<thư mục>` (xcodebuild: `TEST_RUNNER_CTW_CHUP_NN`) ⇒ lưu ảnh chụp từng bước vào thư mục đó.
final class NgonNguUITests: XCTestCase {
    private func chup(_ app: XCUIApplication, _ ten: String) {
        let s = app.screenshot()
        add(XCTAttachment(screenshot: s))
        if let thuMuc = ProcessInfo.processInfo.environment["CTW_CHUP_NN"], !thuMuc.isEmpty {
            try? s.pngRepresentation.write(to: URL(fileURLWithPath: thuMuc).appendingPathComponent(ten + ".png"))
        }
    }

    private func chon(_ app: XCUIApplication, _ nhan: String) {
        let o = app.buttons["account.language"].exists ? app.buttons["account.language"] : app.otherElements["account.language"]
        XCTAssertTrue(o.waitForExistence(timeout: 10))
        o.tap()
        let muc = app.buttons[nhan].firstMatch
        XCTAssertTrue(muc.waitForExistence(timeout: 5), "không thấy mục \(nhan) trong menu")
        muc.tap()
        sleep(1)
    }

    func testDoiNgonNguNgayKhongKhoiDongLai() throws {
        let app = XCUIApplication()
        app.launchEnvironment["CT_XEM_MAN"] = "account"
        app.launch()

        chon(app, "Tiếng Việt")
        XCTAssertTrue(app.navigationBars["Tài khoản"].waitForExistence(timeout: 5), "chưa đổi sang tiếng Việt")
        XCTAssertTrue(app.tabBars.buttons["Việc của tôi"].exists)
        chup(app, "13-doi-ngay-1-tieng-viet")

        chon(app, "English")
        XCTAssertTrue(app.navigationBars["Account"].waitForExistence(timeout: 5), "chưa đổi sang tiếng Anh")
        XCTAssertTrue(app.tabBars.buttons["My Work"].exists)
        chup(app, "14-doi-ngay-2-english")

        // Sang tab khác: vẫn là tiếng Anh, không cần mở lại app.
        app.tabBars.buttons["My Work"].tap()
        sleep(2)
        chup(app, "15-doi-ngay-3-english-my-work")

        app.tabBars.buttons["Account"].tap()
        chon(app, "Tiếng Việt")
        XCTAssertTrue(app.navigationBars["Tài khoản"].waitForExistence(timeout: 5))
        chup(app, "16-doi-ngay-4-tieng-viet-lai")
    }
}
