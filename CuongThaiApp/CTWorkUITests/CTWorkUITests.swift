import XCTest

/// Kiểm thử GIAO DIỆN — BẤM THẬT trên máy mô phỏng, dữ liệu từ máy chủ giả
/// (`CT_XEM_MAN`, chỉ bản DEBUG). Không tài khoản thật, không mạng thật.
///
///     xcodebuild test -scheme CTWorkApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0.1'
///     xcodebuild test -scheme CTWorkApp -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' \
///       -only-testing:CTWorkAppUITests/CTWorkUITests/testThanhBenIPad
final class CTWorkUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func mo(_ man: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CT_XEM_MAN"] = man
        app.launch()
        return app
    }

    /// Nút có nhãn BẮT ĐẦU bằng `chu` (hàng có dòng phụ gộp nhãn: "Board, Drag issues…").
    private func nut(_ app: XCUIApplication, _ chu: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", chu)).firstMatch
    }

    /// Mục thanh bên iPad. Thanh bên giờ có hàng chục mô-đun (mọi mảng đăng ký) ⇒ mục cần tìm có thể nằm
    /// ngoài màn — danh sách lười không tạo phần tử cho tới khi cuộn tới. Cuộn xuống rồi cuộn lên tìm.
    private func mucBen(_ app: XCUIApplication, _ chu: String) -> XCUIElement {
        let b = nut(app, chu)
        // Kéo trong VÙNG thanh bên (mép trái) — `collectionViews.firstMatch` có thể là danh sách ở cột nội dung.
        func keo(_ tu: CGFloat, _ den: CGFloat) {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: tu))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: den)))
        }
        for _ in 0..<8 where !(b.exists && b.isHittable) { keo(0.85, 0.35) }
        for _ in 0..<10 where !(b.exists && b.isHittable) { keo(0.3, 0.8) }
        return b
    }

    private var laIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    func testTabVaTrangDuAn() throws {
        try XCTSkipIf(laIPad)
        let app = mo("mywork")
        XCTAssertTrue(app.staticTexts["Fix sign-in token refresh loop"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Projects"].tap()
        XCTAssertTrue(app.staticTexts["Mobile App Launch"].waitForExistence(timeout: 5))
        nut(app, "Board").tap()
        XCTAssertTrue(app.staticTexts["TO DO"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        nut(app, "Backlog & issues").tap()
        XCTAssertTrue(app.staticTexts["Sprint 6 — Beta polish"].waitForExistence(timeout: 5))
        app.buttons["All issues"].tap()
        XCTAssertTrue(app.staticTexts["Open issues"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Inbox"].tap()
        XCTAssertTrue(app.buttons["Read all"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Account"].tap()
        XCTAssertTrue(app.staticTexts["Alex Morgan"].waitForExistence(timeout: 5))
    }

    func testMoTheVaBinhLuan() throws {
        let app = mo("issue")
        XCTAssertTrue(app.staticTexts["Push notifications open the right issue"].waitForExistence(timeout: 8))
        let o = app.textFields["Add a comment…"]
        for _ in 0..<6 where !o.isHittable { app.swipeUp() }
        o.tap()
        o.typeText("Shipping the fix now")
        app.buttons["Send comment"].tap()
        XCTAssertTrue(app.staticTexts["Shipping the fix now"].waitForExistence(timeout: 5))
    }

    func testBaoCaoTinChat() throws {
        let app = mo("kenh")
        let tin = app.staticTexts["Nice catch. @alex can you take a look after standup?"]
        XCTAssertTrue(tin.waitForExistence(timeout: 8))
        // Dữ liệu kênh #general của mảng Giao tiếp dài hơn bản lõi ⇒ tin có thể nằm DƯỚI mép màn. Nhấn giữ
        // phần tử ngoài màn = nhấn trúng tin khác (đã dính 18/10). Cuộn cho tới khi chạm được.
        let day = app.windows.firstMatch.frame.maxY - 140   // trên ô soạn tin
        for _ in 0..<6 {
            if tin.frame.maxY > day { app.swipeUp() } else if tin.frame.minY < 120 { app.swipeDown() } else { break }
        }
        tin.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Report message"].waitForExistence(timeout: 5))
        app.buttons["Report message"].tap()
        XCTAssertTrue(app.buttons["Spam or advertising"].waitForExistence(timeout: 5))
        app.buttons["Spam or advertising"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        app.alerts.buttons["OK"].tap()
        XCTAssertFalse(tin.exists, "tin đã báo cáo phải ẩn ngay cho người báo cáo (1.2)")
    }

    func testGuiTinChat() throws {
        let app = mo("kenh")
        let o = app.textFields["Message #general"]
        XCTAssertTrue(o.waitForExistence(timeout: 8))
        o.tap()
        o.typeText("Standup in 5")
        app.buttons["Send message"].tap()
        XCTAssertTrue(app.staticTexts["Standup in 5"].waitForExistence(timeout: 5))
    }

    func testDangNhapCoAppleVaXoaTaiKhoan() throws {
        let app = mo("dangnhap")
        XCTAssertTrue(app.buttons["Continue with Apple"].waitForExistence(timeout: 8) ||
                      app.buttons.matching(NSPredicate(format: "label CONTAINS 'Apple'")).firstMatch.exists)
        let app2 = mo("account")
        let xoa = app2.buttons["Delete account"]
        for _ in 0..<4 where !xoa.isHittable { app2.swipeUp() }
        xoa.tap()
        XCTAssertTrue(app2.buttons["Delete my account"].waitForExistence(timeout: 5))
    }

    /// Đổi cột thẻ trên bảng — iPhone qua menu "Move to…", iPad bằng KÉO THẢ thật.
    func testDoiCotTheTrenBang() throws {
        let app = mo("board")
        let the = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Crash when attaching a HEIC'")).firstMatch
        XCTAssertTrue(the.waitForExistence(timeout: 8))
        let cotDich = app.staticTexts["IN REVIEW"]
        if laIPad {
            XCTAssertTrue(cotDich.waitForExistence(timeout: 3))
            the.press(forDuration: 1.0, thenDragTo: cotDich)
        } else {
            the.press(forDuration: 1.2)
            XCTAssertTrue(app.buttons["Move to…"].waitForExistence(timeout: 5))
            app.buttons["Move to…"].tap()
            XCTAssertTrue(app.buttons["In Review"].waitForExistence(timeout: 5))
            app.buttons["In Review"].tap()
        }
        // Thẻ phải nằm dưới cột đích: toạ độ x của thẻ ≈ cột "IN REVIEW" (iPad), hoặc
        // trên iPhone cột To Do còn 2 thẻ.
        if laIPad {
            let moi = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Crash when attaching a HEIC'")).firstMatch
            XCTAssertTrue(moi.waitForExistence(timeout: 5))
            XCTAssertEqual(moi.frame.midX, cotDich.frame.midX, accuracy: max(cotDich.frame.width, 160))
        } else {
            XCTAssertTrue(app.staticTexts["2"].waitForExistence(timeout: 5), "cột To Do còn 2 thẻ")
        }
    }

    /// iPad: mục thanh bên phải BẤM ĐƯỢC (bài học `.tag()` chết câm trên iOS).
    func testThanhBenIPad() throws {
        try XCTSkipUnless(laIPad)
        let app = mo("mywork")
        XCTAssertTrue(app.staticTexts["Fix sign-in token refresh loop"].waitForExistence(timeout: 8))
        mucBen(app, "Docs").tap()
        XCTAssertTrue(app.staticTexts["Release plan — v1.0"].waitForExistence(timeout: 5))
        mucBen(app, "Inbox").tap()
        XCTAssertTrue(app.buttons["Read all"].waitForExistence(timeout: 5))
        mucBen(app, "Board").tap()
        XCTAssertTrue(app.staticTexts["TO DO"].waitForExistence(timeout: 5))
        mucBen(app, "Chat").tap()
        XCTAssertTrue(app.staticTexts["general"].waitForExistence(timeout: 5))
    }
}
