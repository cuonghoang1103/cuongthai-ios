import XCTest

/// Màn "Tìm mọi thứ" (⌘K, 21/10/2026) — BẤM THẬT trên máy mô phỏng với máy chủ giả.
/// `test01…` luôn chạy (hồi quy: mở bằng kính lúp, gõ không dấu, chọn ⇒ tới đúng màn).
/// `test02…`/`test03…` chỉ chạy khi chụp màn: `TEST_RUNNER_CTW_CHUP_TIM=<thư mục>` (tiếng Việt).
final class TimKiemUITests: XCTestCase {
    private var thuMuc: String? { ProcessInfo.processInfo.environment["CTW_CHUP_TIM"] }

    override func setUpWithError() throws { continueAfterFailure = false }

    private func mo(_ man: String = "mywork", vi: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CT_XEM_MAN"] = man
        if vi { app.launchArguments += ["-com.cuongthai.ctwork.ngonNgu", "vi"] }
        app.launch()
        return app
    }

    private func chup(_ app: XCUIApplication, _ ten: String) {
        let s = app.screenshot()
        add(XCTAttachment(screenshot: s))
        if let thuMuc, !thuMuc.isEmpty {
            try? s.pngRepresentation.write(to: URL(fileURLWithPath: thuMuc).appendingPathComponent(ten + ".png"))
        }
    }

    private func moTim(_ app: XCUIApplication) -> XCUIElement {
        let nut = app.buttons["search.open"].firstMatch
        XCTAssertTrue(nut.waitForExistence(timeout: 10), "thiếu kính lúp ở thanh trên")
        nut.tap()
        let o = app.textFields["search.field"]
        XCTAssertTrue(o.waitForExistence(timeout: 5))
        return o
    }

    func test01GoKhongDauRoiMoChucNang() {
        let app = mo()
        let o = moTim(app)
        sleep(1)
        o.typeText("lich hop")
        let hop = app.buttons["search.row.mod:meetings"]
        XCTAssertTrue(hop.waitForExistence(timeout: 5), "“lich hop” phải ra Cuộc họp")
        o.clearAndType(app, "bao cao")
        let bc = app.buttons["search.row.mod:reports"]
        XCTAssertTrue(bc.waitForExistence(timeout: 5), "“bao cao” (không dấu) phải ra Báo cáo")
        bc.tap()
        XCTAssertFalse(app.textFields["search.field"].waitForExistence(timeout: 2) && app.textFields["search.field"].isHittable,
                       "chọn xong phải đóng màn tìm")
        XCTAssertTrue(app.navigationBars["Báo cáo"].waitForExistence(timeout: 8), "phải tới màn Báo cáo")
    }

    /// Gõ "thanh vien" / "tin nhan" ⇒ phân đoạn Thành viên / Tin nhắn của tab Chat (không phải Team / kênh Chat);
    /// gõ tên người ⇒ nút nhắn tin mở thẳng chat 1-1; "cuongmini" ⇒ trợ lý CuongMini.
    func test04ThanhVienTinNhanNguoiCuongMini() {
        let app = mo()
        var o = moTim(app)
        sleep(1)
        o.typeText("thanh vien")
        let tv = app.buttons["search.row.mod:thanh-vien"]
        XCTAssertTrue(tv.waitForExistence(timeout: 5), "“thanh vien” phải ra Thành viên")
        tv.tap()
        XCTAssertTrue(app.descendants(matching: .any)["chat.hub"].waitForExistence(timeout: 8), "phải tới tab Chat (Kênh · Tin nhắn · Thành viên)")
        XCTAssertTrue(app.buttons["member.2"].waitForExistence(timeout: 8), "phải đứng ở phân đoạn Thành viên")

        o = moTim(app)
        sleep(1)
        o.typeText("nhan tin")
        let tn = app.buttons["search.row.mod:tin-nhan"]
        XCTAssertTrue(tn.waitForExistence(timeout: 5), "“nhan tin” phải ra Tin nhắn")
        tn.tap()
        XCTAssertTrue(app.descendants(matching: .any)["dm.101"].waitForExistence(timeout: 8), "phải đứng ở phân đoạn Tin nhắn")

        o = moTim(app)
        sleep(1)
        o.typeText("Linh")
        let dm = app.buttons["search.dm.2"]
        XCTAssertTrue(dm.waitForExistence(timeout: 8), "gõ tên người ⇒ có nút nhắn tin")
        XCTAssertTrue(app.buttons["search.person.2"].exists)
        dm.tap()
        XCTAssertTrue(app.descendants(matching: .any)["dm.composer"].waitForExistence(timeout: 8), "phải mở chat 1-1")
        // Kính lúp chỉ ở màn GỐC ⇒ quay lại danh sách hội thoại.
        app.navigationBars.buttons.element(boundBy: 0).tap()

        o = moTim(app)
        sleep(1)
        o.typeText("cuongmini")
        let cm = app.buttons["search.row.mod:ai"]
        XCTAssertTrue(cm.waitForExistence(timeout: 5), "“cuongmini” phải ra CuongMini")
        cm.tap()
        XCTAssertTrue(app.navigationBars["CuongMini"].waitForExistence(timeout: 8), "phải tới màn CuongMini")
    }

    func test02ChupIPhone() throws {
        try XCTSkipIf((thuMuc ?? "").isEmpty, "chỉ chạy khi chụp màn")
        let app = mo()
        let o = moTim(app)
        sleep(2)
        chup(app, "01-trong")
        o.typeText("bao cao")
        sleep(3)
        chup(app, "02-go-chuc-nang-bao-cao")
        o.clearAndType(app, "push")
        sleep(3)
        chup(app, "03-go-noi-dung-the")
        o.clearAndType(app, "NW-12")
        sleep(3)
        chup(app, "04-go-ma-the")
    }

    func test03ChupIPadCmdK() throws {
        try XCTSkipIf((thuMuc ?? "").isEmpty, "chỉ chạy khi chụp màn")
        let app = mo()
        sleep(4)
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("chỉ iPad") }
        chup(app, "05-ipad-truoc-cmdk")
        app.typeKey("k", modifierFlags: .command)
        let o = app.textFields["search.field"]
        XCTAssertTrue(o.waitForExistence(timeout: 5), "⌘K phải mở màn tìm")
        sleep(2)
        chup(app, "06-ipad-cmdk")
        o.typeText("lich")
        sleep(3)
        chup(app, "07-ipad-go-lich")
    }
}

private extension XCUIElement {
    func clearAndType(_ app: XCUIApplication, _ chu: String) {
        let xoa = app.buttons["Xoá"].firstMatch
        if xoa.exists && xoa.isHittable { xoa.tap() } else if let v = value as? String, !v.isEmpty {
            typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: v.count))
        }
        if !hasFocus { tap() }
        typeText(chu)
    }
}
