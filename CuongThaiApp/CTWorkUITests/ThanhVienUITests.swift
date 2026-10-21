import XCTest

/// Thành viên + Tin nhắn riêng (21/10/2026) — bấm THẬT trên máy mô phỏng với máy chủ giả (`XemThuCTW+ThanhVien.swift`):
/// danh bạ có chấm xanh → hồ sơ → Nhắn tin → gửi một tin; Account › công tắc "Hiển thị trạng thái hoạt động".
/// `TEST_RUNNER_CTW_CHUP_TV=<thư mục>` ⇒ lưu thêm ảnh chụp (tiếng Việt).
final class ThanhVienUITests: XCTestCase {
    private var thuMuc: String? { ProcessInfo.processInfo.environment["CTW_CHUP_TV"] }

    override func setUpWithError() throws { continueAfterFailure = false }

    private func mo(_ man: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CT_XEM_MAN"] = man
        app.launchArguments += ["-com.cuongthai.ctwork.ngonNgu", thuMuc == nil ? "en" : "vi"]
        app.launch()
        return app
    }

    private func chup(_ app: XCUIApplication, _ ten: String) {
        guard let thuMuc, !thuMuc.isEmpty else { return }
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: thuMuc).appendingPathComponent(ten + ".png"))
    }

    func testThanhVienDenNhanTin() {
        let app = mo("mod:thanh-vien")
        let linh = app.buttons["member.2"]
        XCTAssertTrue(linh.waitForExistence(timeout: 10))
        linh.tap()
        let nhan = app.buttons["member.message"]
        XCTAssertTrue(nhan.waitForExistence(timeout: 5))
        nhan.tap()
        XCTAssertTrue(app.descendants(matching: .any)["dm.composer"].waitForExistence(timeout: 8))
        app.descendants(matching: .any)["dm.composer"].tap()
        app.typeText("Hello from the test")
        app.buttons["dm.send"].tap()
        XCTAssertTrue(app.staticTexts["Hello from the test"].waitForExistence(timeout: 5))
    }

    func testCongTacTrangThaiHoatDong() {
        let app = mo("account")
        let ct = app.switches["account.activeStatus"]
        var lan = 0
        while !ct.isHittable && lan < 6 { app.swipeUp(); lan += 1 }
        XCTAssertTrue(ct.waitForExistence(timeout: 5))
        chup(app, "05-cai-dat-trang-thai")
        XCTAssertEqual(ct.value as? String, "1")
        // Bấm vào CÔNG TẮC (mép phải), không vào giữa nhãn hai dòng.
        ct.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let tat = NSPredicate(format: "value == '0'")
        expectation(for: tat, evaluatedWith: ct)
        waitForExpectations(timeout: 5)
        chup(app, "06-cai-dat-trang-thai-tat")
    }
}
