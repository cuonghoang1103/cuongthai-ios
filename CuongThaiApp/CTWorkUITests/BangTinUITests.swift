import XCTest

/// Bảng tin (Team Feed, 21/10/2026) — bấm THẬT trên máy mô phỏng với máy chủ giả (`Debug/XemThuCTW+BangTin.swift`):
/// My Work › Bảng tin → cuộn (tải trang sau) → thả cảm xúc (chạm + giữ ⇒ bảng 6 cảm xúc) → bình luận → ô soạn đăng bài có ảnh →
/// báo cáo một bài; máy chủ CŨ (404) ⇒ phân đoạn Bảng tin biến mất.
/// `TEST_RUNNER_CTW_CHUP_FEED=<thư mục>` ⇒ lưu ảnh chụp TIẾNG VIỆT các màn (testChupManHinh).
final class BangTinUITests: XCTestCase {
    private var thuMuc: String? { ProcessInfo.processInfo.environment["CTW_CHUP_FEED"] }

    override func setUpWithError() throws { continueAfterFailure = false }

    private func mo(_ man: String = "bangtin", env: [String: String] = [:], vi: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CT_XEM_MAN"] = man
        for (k, v) in env { app.launchEnvironment[k] = v }
        app.launchArguments += ["-com.cuongthai.ctwork.ngonNgu", vi ? "vi" : "en"]
        app.launch()
        return app
    }

    private func phanTu(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func chup(_ app: XCUIApplication, _ ten: String) {
        guard let thuMuc, !thuMuc.isEmpty else { return }
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: thuMuc).appendingPathComponent(ten + ".png"))
    }

    // MARK: Bảng tin gộp: cuộn · cảm xúc · bình luận

    func testCuonThaCamXucVaBinhLuan() {
        let app = mo()
        let bai = phanTu(app, "feed.post.2")
        XCTAssertTrue(bai.waitForExistence(timeout: 15), "My Work › Bảng tin hiện bài mẫu")
        // Cuộn xuống cuối ⇒ tải trang sau (con trỏ) ⇒ thấy bài số 9 (trang 2).
        var lan = 0
        while !phanTu(app, "feed.post.9").exists && lan < 14 { app.swipeUp(); lan += 1 }
        XCTAssertTrue(phanTu(app, "feed.post.9").exists, "trang sau đã nối")
        for _ in 0..<16 { app.swipeDown(velocity: .fast) }

        // Chạm Thích.
        let thich = bai.descendants(matching: .any).matching(identifier: "feed.post.like").firstMatch
        XCTAssertTrue(thich.waitForExistence(timeout: 5))
        thich.tap()
        XCTAssertTrue(app.descendants(matching: .any)["Reaction: Like"].waitForExistence(timeout: 5))
        // Giữ ⇒ bảng 6 cảm xúc ⇒ chọn "Love".
        thich.press(forDuration: 0.8)
        let yeu = phanTu(app, "feed.reaction.love")
        XCTAssertTrue(yeu.waitForExistence(timeout: 5), "bảng cảm xúc mở khi giữ")
        XCTAssertTrue(phanTu(app, "feed.reaction.celebrate").exists, "đủ 6 cảm xúc như web")
        yeu.tap()
        XCTAssertTrue(app.descendants(matching: .any)["Reaction: Love"].waitForExistence(timeout: 5))

        // Bình luận.
        bai.descendants(matching: .any).matching(identifier: "feed.post.comment").firstMatch.tap()
        let o = phanTu(app, "feed.comment.field")
        XCTAssertTrue(o.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Ổn rồi, merge PR #42 đi em. Nhớ cập nhật NW-12 sang Review."].waitForExistence(timeout: 8))
        o.tap()
        app.typeText("Đã test trên iPhone, ổn 👍")
        phanTu(app, "feed.comment.send").tap()
        XCTAssertTrue(app.staticTexts["Đã test trên iPhone, ổn 👍"].waitForExistence(timeout: 8))
    }

    // MARK: Ô soạn: đăng bài có ảnh (lạc quan)

    func testDangBaiCoAnh() {
        let app = mo(env: ["CT_XEM_FEED_ANH": "1"])
        let soan = phanTu(app, "feed.compose")
        XCTAssertTrue(soan.waitForExistence(timeout: 15))
        soan.tap()
        let dang = app.buttons["feed.composer.post"]
        XCTAssertTrue(dang.waitForExistence(timeout: 8))
        XCTAssertFalse(dang.isEnabled, "chưa có nội dung ⇒ nút Đăng tắt")
        let chu = phanTu(app, "feed.composer.text")
        chu.tap()
        app.typeText("Ảnh demo từ UI test")
        phanTu(app, "feed.composer.photos").tap()
        let bat = NSPredicate(format: "isEnabled == true")
        expectation(for: bat, evaluatedWith: dang)
        waitForExpectations(timeout: 15)
        dang.tap()
        XCTAssertTrue(app.staticTexts["Ảnh demo từ UI test"].waitForExistence(timeout: 10), "bài mới hiện đầu bảng tin")
        XCTAssertFalse(dang.exists, "ô soạn đã đóng")
    }

    // MARK: Báo cáo (App Store 1.2)

    func testBaoCaoBai() {
        let app = mo()
        let bai = phanTu(app, "feed.post.2")
        XCTAssertTrue(bai.waitForExistence(timeout: 15))
        bai.descendants(matching: .any).matching(identifier: "feed.post.menu").firstMatch.tap()
        XCTAssertTrue(app.buttons["Hide post"].waitForExistence(timeout: 5), "1.2: Ẩn bài")
        XCTAssertTrue(app.buttons["Block Minh Pham"].exists, "1.2: Chặn tác giả")
        app.buttons["Report post"].tap()
        let gui = app.buttons["feed.report.send"]
        XCTAssertTrue(gui.waitForExistence(timeout: 5))
        app.buttons["Harassment or bullying"].firstMatch.tap()
        gui.tap()
        XCTAssertTrue(app.staticTexts["Thanks — our moderators will review it within 24 hours. It's hidden for you now."].waitForExistence(timeout: 8))
        XCTAssertFalse(phanTu(app, "feed.post.2").exists, "bài đã báo cáo biến khỏi bảng tin")
    }

    // MARK: Máy chủ cũ ⇒ ẩn

    func testMayChuCuAnBangTin() {
        let app = mo("mywork", env: ["CT_XEM_FEED": "0"])
        let issues = app.buttons["Issues"]
        XCTAssertTrue(issues.waitForExistence(timeout: 15))
        sleep(2)
        XCTAssertFalse(app.buttons["Feed"].exists, "máy chủ chưa có /feed ⇒ không có phân đoạn Bảng tin")
    }

    // MARK: Ảnh chụp tiếng Việt (chỉ khi có thư mục)

    func testChupManHinh() throws {
        guard thuMuc != nil else { throw XCTSkip("Không có CTW_CHUP_FEED") }
        var app = mo(vi: true)
        XCTAssertTrue(phanTu(app, "feed.post.2").waitForExistence(timeout: 15))
        sleep(4)
        chup(app, "01-my-work-bang-tin")
        app.swipeUp(); sleep(2)
        chup(app, "02-luoi-anh")
        // Giữ nút Thích ⇒ bảng cảm xúc.
        let thich = phanTu(app, "feed.post.2").descendants(matching: .any).matching(identifier: "feed.post.like").firstMatch
        if thich.exists { thich.press(forDuration: 0.8); sleep(1); chup(app, "05-bang-cam-xuc"); app.tap() }
        app.terminate()

        app = mo(env: ["CT_XEM_FEED_MO": "binhluan"], vi: true)
        XCTAssertTrue(phanTu(app, "feed.comment.field").waitForExistence(timeout: 15))
        sleep(3)
        chup(app, "04-binh-luan")
        app.terminate()

        app = mo(env: ["CT_XEM_FEED_MO": "soan"], vi: true)
        XCTAssertTrue(app.buttons["feed.composer.post"].waitForExistence(timeout: 15))
        sleep(4)
        chup(app, "06-soan-bai-co-anh")
        app.terminate()

        app = mo(env: ["CT_XEM_FEED_MO": "xemanh"], vi: true)
        XCTAssertTrue(phanTu(app, "feed.viewer.close").waitForExistence(timeout: 15))
        sleep(3)
        chup(app, "03b-xem-anh-toan-man")
        app.terminate()

        app = mo(vi: true)
        var lan = 0
        while !phanTu(app, "feed.post.3").exists && lan < 6 { app.swipeUp(); lan += 1 }
        sleep(2)
        chup(app, "03-bai-video")
        app.terminate()

        app = mo("mod:feed", vi: true)
        XCTAssertTrue(phanTu(app, "feed.post.2").waitForExistence(timeout: 15))
        sleep(3)
        chup(app, "07-bang-tin-du-an")
        app.terminate()

        app = mo("mod:feed/bai", vi: true)
        XCTAssertTrue(phanTu(app, "feed.comment.field").waitForExistence(timeout: 15))
        sleep(3)
        chup(app, "08-chi-tiet-bai")
        app.terminate()

        app = mo(env: ["CT_XEM_FEED_TRONG": "1"], vi: true)
        XCTAssertTrue(phanTu(app, "feed.empty.compose").waitForExistence(timeout: 15))
        sleep(2)
        chup(app, "09-bang-tin-trong")
        app.terminate()

        app = mo(env: ["CT_XEM_FEED_MOI": "3"], vi: true)
        XCTAssertTrue(phanTu(app, "feed.newPosts").waitForExistence(timeout: 15))
        chup(app, "10-vien-bai-moi")
    }
}
