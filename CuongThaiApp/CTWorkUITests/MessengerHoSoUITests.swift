import XCTest

/// Hồ sơ + Tin nhắn kiểu Messenger (bản 1.1 — 22/10/2026). Bấm THẬT trên máy mô phỏng với máy chủ giả
/// (`Debug/XemThuCTW+ThanhVien.swift`): avatar trong chat ⇒ hồ sơ; đổi ảnh đại diện (ảnh mẫu ⇒ cắt ⇒ tải lên ⇒ PUT /profile);
/// nhấn giữ ⇒ thả cảm xúc; trả lời có trích dẫn; gửi GIF; lọc "Chưa đọc" ở danh sách hội thoại.
/// `TEST_RUNNER_CTW_CHUP_MSG=<thư mục>` ⇒ lưu ảnh chụp (tiếng Anh) dọc đường.
final class MessengerHoSoUITests: XCTestCase {
    private var thuMuc: String? { ProcessInfo.processInfo.environment["CTW_CHUP_MSG"] }

    override func setUpWithError() throws { continueAfterFailure = false }

    private func mo(_ man: String, _ them: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CT_XEM_MAN"] = man
        for (k, v) in them { app.launchEnvironment[k] = v }
        // Nhãn nút tiếng Anh ổn định. `TEST_RUNNER_CTW_NGON_NGU=vi` ⇒ quay video tiếng Việt (chỉ các test dùng mã nhận dạng).
        app.launchArguments += ["-com.cuongthai.ctwork.ngonNgu", ProcessInfo.processInfo.environment["CTW_NGON_NGU"] ?? "en"]
        app.launch()
        return app
    }

    private func chup(_ app: XCUIApplication, _ ten: String) {
        guard let thuMuc, !thuMuc.isEmpty else { return }
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: thuMuc).appendingPathComponent(ten + ".png"))
    }

    private func phanTu(_ app: XCUIApplication, _ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    func testMoHoSoTuAvatarTrongChat() {
        let app = mo("mod:tin-nhan/chat")
        XCTAssertTrue(phanTu(app, "dm.composer").waitForExistence(timeout: 10))
        let avatar = app.buttons.matching(identifier: "dm.avatar").allElementsBoundByIndex.last { $0.isHittable }
        XCTAssertNotNil(avatar, "avatar người kia ở cuối nhóm tin")
        avatar?.tap()
        XCTAssertTrue(app.buttons["member.message"].waitForExistence(timeout: 6), "hồ sơ có nút Nhắn tin")
        XCTAssertTrue(app.buttons["profile.work"].exists, "hồ sơ có nút Xem việc")
        XCTAssertTrue(phanTu(app, "profile.bio").waitForExistence(timeout: 6), "giới thiệu từ GET /users/:id")
        chup(app, "02-ho-so-nguoi-khac")
        // Menu "…" có Báo cáo + Chặn (1.2).
        app.buttons["profile.more"].tap()
        XCTAssertTrue(app.buttons["Report"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Block"].exists)
        XCTAssertTrue(app.buttons["Copy profile link"].exists)
    }

    func testDoiAnhDaiDien() {
        let app = mo("hoso", ["CT_XEM_ANH_MAU": "1"])
        let avatar = phanTu(app, "profile.avatar")
        XCTAssertTrue(avatar.waitForExistence(timeout: 10))
        XCTAssertEqual(avatar.value as? String ?? "", "", "lúc đầu chưa có ảnh")
        chup(app, "01-ho-so-cua-toi")
        app.buttons["profile.changePhoto"].tap()
        let chon = app.buttons["Choose photo"]
        XCTAssertTrue(chon.waitForExistence(timeout: 4))
        chon.tap()
        let dung = app.buttons["crop.use"]
        XCTAssertTrue(dung.waitForExistence(timeout: 6), "màn cắt ảnh vuông")
        chup(app, "01b-cat-anh")
        dung.tap()
        XCTAssertFalse(dung.waitForExistence(timeout: 2))
        let coAnh = NSPredicate(format: "value != ''")
        expectation(for: coAnh, evaluatedWith: avatar)
        waitForExpectations(timeout: 10)
    }

    func testNhanGiuThaCamXuc() {
        let app = mo("mod:tin-nhan/chat")
        let tin = app.staticTexts["Dạ em merge liền"]
        XCTAssertTrue(tin.waitForExistence(timeout: 10))
        tin.press(forDuration: 0.9)
        let tim = app.buttons["dm.react.0"]
        XCTAssertTrue(tim.waitForExistence(timeout: 4), "thanh cảm xúc nhanh")
        XCTAssertTrue(app.buttons["dm.menu.reply"].exists)
        XCTAssertTrue(app.buttons["dm.menu.unsend"].exists, "tin của tôi, 3 phút trước ⇒ còn thu hồi được (≤ 5 phút)")
        chup(app, "05-nhan-giu")
        tim.tap()
        XCTAssertTrue(phanTu(app, "dm.reactions.1011").waitForExistence(timeout: 4), "viên cảm xúc hiện ngay (lạc quan)")
    }

    func testTraLoiCoTrichDan() {
        let app = mo("mod:tin-nhan/chat")
        let tin = app.staticTexts["Đã xem, ổn rồi. Merge PR #42 đi em 👍"]
        XCTAssertTrue(tin.waitForExistence(timeout: 10))
        let truoc = app.descendants(matching: .any).matching(identifier: "dm.quote").count
        tin.press(forDuration: 0.9)
        XCTAssertTrue(app.buttons["dm.menu.reply"].waitForExistence(timeout: 4))
        app.buttons["dm.menu.reply"].tap()
        XCTAssertTrue(phanTu(app, "dm.replyBar").waitForExistence(timeout: 4), "dải 'Đang trả lời' trên ô soạn")
        phanTu(app, "dm.composer").tap()
        app.typeText("Reply from the test")
        app.buttons["dm.send"].tap()
        XCTAssertTrue(app.staticTexts["Reply from the test"].waitForExistence(timeout: 6))
        XCTAssertFalse(phanTu(app, "dm.replyBar").exists)
        XCTAssertGreaterThan(app.descendants(matching: .any).matching(identifier: "dm.quote").count, truoc, "tin mới có trích dẫn")
        chup(app, "04-tra-loi")
    }

    func testGuiGif() {
        let app = mo("mod:tin-nhan/chat")
        XCTAssertTrue(phanTu(app, "dm.composer").waitForExistence(timeout: 10))
        let truoc = app.descendants(matching: .any).matching(identifier: "dm.gif").count
        app.buttons["dm.gif.open"].tap()
        let gif = app.buttons["gif.item.1"]
        XCTAssertTrue(gif.waitForExistence(timeout: 6), "GIF thịnh hành")
        chup(app, "06-chon-gif")
        // Ô tìm: gõ ⇒ vẫn có kết quả (máy chủ giả).
        app.textFields["gif.search"].tap()
        app.typeText("ok")
        XCTAssertTrue(app.buttons["gif.item.0"].waitForExistence(timeout: 6))
        app.buttons["gif.item.0"].tap()
        let sau = NSPredicate(format: "count > %d", truoc)
        expectation(for: sau, evaluatedWith: app.descendants(matching: .any).matching(identifier: "dm.gif"))
        waitForExpectations(timeout: 8)
        chup(app, "03-chat-gif")
    }

    func testDanhSachLocChuaDoc() {
        let app = mo("mod:tin-nhan")
        XCTAssertTrue(phanTu(app, "dm.101").waitForExistence(timeout: 10))
        chup(app, "07-danh-sach")
        phanTu(app, "dm.filter.unread").tap()
        XCTAssertTrue(phanTu(app, "dm.102").waitForExistence(timeout: 4), "Minh có 2 tin chưa đọc")
        XCTAssertFalse(phanTu(app, "dm.103").exists, "hội thoại đã đọc bị lọc")
    }
}
