import XCTest

/// Khởi động nguội ⇒ màn khởi động động ⇒ đăng nhập (máy chủ giả `CT_XEM_MAN=dangnhap`) ⇒ My Work (21/10/2026).
/// `CT_XEM_KHOIDONG=1` bật màn khởi động trong chế độ xem thử (mặc định màn thử bỏ qua nó để không làm chậm test khác).
/// Mật khẩu "wrong" ⇒ máy chủ giả trả lỗi sai mật khẩu.
///
///     xcodebuild test -scheme CTWorkApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
///       -only-testing:CTWorkAppUITests/KhoiDongDangNhapUITests
final class KhoiDongDangNhapUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func mo(khoiDong: Bool = true, giu: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CT_XEM_MAN"] = "dangnhap"
        if khoiDong { app.launchEnvironment["CT_XEM_KHOIDONG"] = giu ? "giu" : "1" }
        app.launchArguments += ["-com.cuongthai.ctwork.ngonNgu", "en"]
        // Lần trước có thể đã nhớ tên đăng nhập ⇒ tắt để ô trống, kiểm cho chắc.
        app.launchArguments += ["-ctw.dangNhap.tenDaNho", ""]
        // Máy chủ giả trả /auth/login sau 3 s ⇒ lớp "Signing you in…" đứng đủ lâu để kiểm.
        app.launchEnvironment["CT_XEM_CHO_DANGNHAP"] = "3"
        app.launch()
        return app
    }

    private func cho(_ e: XCUIElement, bienMat: Bool, _ giay: TimeInterval) -> Bool {
        let p = NSPredicate(format: "exists == %@", NSNumber(value: !bienMat))
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: p, object: e)], timeout: giay) == .completed
    }

    func testKhoiDongRoiDangNhapVaoMyWork() throws {
        let app = mo()
        let khoiDong = app.descendants(matching: .any)["khoiDong"].firstMatch
        let ten = app.textFields["dangNhap.ten"]
        // Màn khởi động có mặt rồi tự biến mất (không cần chạm) — tối đa vài giây.
        XCTAssertTrue(khoiDong.waitForExistence(timeout: 8) || ten.exists, "màn khởi động phải hiện lúc mở nguội")
        XCTAssertTrue(cho(khoiDong, bienMat: true, 6), "màn khởi động phải tự thoát")
        XCTAssertTrue(ten.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Welcome back"].exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Apple'")).firstMatch.exists, "4.8: Sign in with Apple")

        // Sai mật khẩu ⇒ lớp chờ ⇒ băng lỗi, vẫn ở màn đăng nhập.
        ten.tap()
        ten.typeText("alex")
        let mk = app.secureTextFields["dangNhap.matKhau"]
        mk.tap()
        // Gửi bằng phím Go của bàn phím (nút dưới có thể đang bị bàn phím che trên máy nhỏ).
        mk.typeText("wrong\n")
        let lopCho = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'dangNhap.dangCho' OR label == 'Signing you in…'")).firstMatch
        XCTAssertTrue(lopCho.waitForExistence(timeout: 2.5), "lớp Đang đăng nhập…")
        XCTAssertTrue(app.staticTexts["Incorrect username or password."].waitForExistence(timeout: 10))

        // Đúng ⇒ vào My Work (dữ liệu mẫu).
        let mk2 = app.secureTextFields["dangNhap.matKhau"]
        mk2.tap()
        mk2.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "secret-pass\n")
        let theMau = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS 'Project charter + scope statement'")).firstMatch
        XCTAssertTrue(theMau.waitForExistence(timeout: 15), "đăng nhập xong phải vào My Work")
    }

    func testChamDeBoQuaManKhoiDong() throws {
        // `giu` ⇒ màn khởi động đứng chờ (không tự thoát) ⇒ biến mất CHỈ vì cú chạm.
        let app = mo(giu: true)
        let khoiDong = app.descendants(matching: .any)["khoiDong"].firstMatch
        XCTAssertTrue(khoiDong.waitForExistence(timeout: 8))
        XCTAssertFalse(cho(khoiDong, bienMat: true, 3), "chưa chạm ⇒ còn đó")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(cho(khoiDong, bienMat: true, 1.5), "chạm ⇒ thoát ngay")
        XCTAssertTrue(app.textFields["dangNhap.ten"].waitForExistence(timeout: 3))
    }

    func testDoiSangDangKyVaLai() throws {
        let app = mo(khoiDong: false)
        XCTAssertTrue(app.textFields["dangNhap.ten"].waitForExistence(timeout: 8))
        app.buttons["dangNhap.doiCheDo"].tap()
        XCTAssertTrue(app.textFields["dangNhap.email"].waitForExistence(timeout: 3), "chế độ đăng ký có ô Email")
        XCTAssertTrue(app.staticTexts["Create your account"].exists)
        app.buttons["dangNhap.doiCheDo"].tap()
        XCTAssertTrue(app.staticTexts["Welcome back"].waitForExistence(timeout: 3))
    }
}
