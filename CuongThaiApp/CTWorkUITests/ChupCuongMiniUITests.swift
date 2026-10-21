import XCTest

/// CuongMini (21/10/2026): CHỤP màn các lối vào + câu trả lời dài bằng máy chủ giả, đồng thời BẤM THẬT luồng
/// (nút trong thẻ ⇒ bảng ⇒ việc một chạm ⇒ đồng ý ⇒ câu trả lời; My Work ⇒ "Hôm nay tôi nên làm gì?").
/// Chụp chỉ khi có `TEST_RUNNER_CTW_CHUP_CM=<thư mục>`; không có ⇒ vẫn chạy như kiểm thử luồng (không ghi ảnh).
/// App chạy tiếng Việt (`-com.cuongthai.ctwork.ngonNgu vi`).
final class ChupCuongMiniUITests: XCTestCase {
    private var thuMuc: String? { ProcessInfo.processInfo.environment["CTW_CHUP_CM"] }

    override func setUp() { continueAfterFailure = false }

    private func mo(_ man: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CT_XEM_MAN"] = man
        app.launchArguments += ["-com.cuongthai.ctwork.ngonNgu", "vi"]
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

    private func dongYNeuHoi(_ app: XCUIApplication) {
        let b = app.buttons["ai.consent.allow"]
        if b.waitForExistence(timeout: 4) { b.tap() }
    }

    private func chua(_ app: XCUIApplication, _ chu: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", chu)).firstMatch
    }

    func test01TrangDuAnCoNutVaThe() {
        let app = mo("board")
        let nut = app.descendants(matching: .any)["cuongmini.toolbar"]
        if !nut.waitForExistence(timeout: 10) { print("CAY_GIAO_DIEN\n" + app.debugDescription) }
        XCTAssertTrue(nut.exists, "nút ✦ cạnh công tắc Board")
        sleep(2)
        chup(app, "01-board-nut-cuongmini")
        let app2 = mo("duan")
        XCTAssertTrue(app2.buttons["cuongmini.card"].waitForExistence(timeout: 10), "thẻ Hỏi CuongMini ở đầu More")
        sleep(1)
        chup(app2, "02-trang-du-an-the-cuongmini")
        app2.buttons["cuongmini.card"].tap()
        XCTAssertTrue(app2.buttons["ai.sample.0"].waitForExistence(timeout: 8))
        XCTAssertTrue(chua(app2, "Hôm nay tôi nên làm gì?").exists, "câu mẫu đầu tiên là 'Hôm nay tôi nên làm gì?'")
        chup(app2, "07-cuongmini-man-trong")
    }

    func test02TheCoMenuCuongMiniVaViecNhanh() {
        let app = mo("issue")
        let nut = app.buttons["cuongmini.issue"]
        XCTAssertTrue(nut.waitForExistence(timeout: 10), "nút CuongMini trong chi tiết thẻ")
        sleep(1)
        chup(app, "03a-the-nut-cuongmini")
        nut.tap()
        let tomTat = app.buttons["cuongmini.quick.summarize"]
        XCTAssertTrue(tomTat.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["cuongmini.quick.generate_tests"].exists, "Story có Sinh test case")
        sleep(1)
        chup(app, "03b-the-bang-cuongmini")
        tomTat.tap()
        dongYNeuHoi(app)
        XCTAssertTrue(chua(app, "Tóm tắt NW-12").waitForExistence(timeout: 10), "kết quả việc một chạm hiện trong hội thoại")
        sleep(1)
        chup(app, "03c-ket-qua-tom-tat")
    }

    func test03HoiVeTheGoiY() {
        let app = mo("issue")
        let nut = app.buttons["cuongmini.issue"]
        XCTAssertTrue(nut.waitForExistence(timeout: 10))
        nut.tap()
        XCTAssertTrue(app.buttons["cuongmini.quick.summarize"].waitForExistence(timeout: 5))
        let khac = app.buttons["cuongmini.ask.other"]
        for _ in 0..<4 where !(khac.exists && khac.isHittable) { app.swipeUp() }
        XCTAssertTrue(khac.exists, "'Hỏi câu khác…' trong bảng CuongMini của thẻ")
        chup(app, "03d-the-bang-hoi-ve-the")
        khac.tap()
        XCTAssertTrue(app.descendants(matching: .any)["ai.issueContext"].waitForExistence(timeout: 8), "chip 'Về NW-12'")
        sleep(1)
        chup(app, "08-hoi-ve-the")
    }

    func test04MyWorkHomNay() {
        let app = mo("mywork")
        let the = app.buttons["cuongmini.today"]
        XCTAssertTrue(the.waitForExistence(timeout: 10), "thẻ 'Hôm nay tôi nên làm gì?' trong My Work")
        sleep(2)
        chup(app, "05-mywork-homnay")
        the.tap()
        dongYNeuHoi(app)
        XCTAssertTrue(chua(app, "Kiến thức chung").waitForExistence(timeout: 30), "câu trả lời dài chạy xong")
        sleep(2)
        chup(app, "06c-tra-loi-dai-cuoi")
        for _ in 0..<6 { app.swipeDown() }
        sleep(1)
        chup(app, "06a-tra-loi-dai-dau")
        app.swipeUp()
        sleep(1)
        chup(app, "06b-tra-loi-dai-giua")
    }
}
