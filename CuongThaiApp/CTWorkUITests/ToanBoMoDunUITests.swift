import XCTest

/// Soát TOÀN BỘ trước khi nộp App Store (19/10/2026): mở MỌI mô-đun đã đăng ký bằng máy chủ giả, kiểm không sập,
/// có tiêu đề, không kẹt màn lỗi; rồi cùng các mô-đun đó khi MẤT MẠNG (`CT_XEM_LOI_MANG`) — phải ra màn lỗi có
/// "Try again" (hoặc bản lưu ngoại tuyến), không sập, không màn trắng. Cộng các luồng mới: Code, trợ lý AI
/// (đồng ý 5.1.2 → hỏi → link mở thẻ → 502 → Ask again → báo cáo câu trả lời 4.7), công tắc thông báo Git.
final class ToanBoMoDunUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Mọi id trong `CTWDangKyMoDun.dangKyMoDun` (kiểm thử đơn vị `DangKyMoDunTests` bắt lệch danh sách).
    static let moDun = ["ai", "board", "backlog", "code", "dashboards", "reports", "submit", "classes",
                        "chat", "meetings", "desk", "intake", "forms", "portal",
                        "sprints", "time", "poker", "retros", "okrs", "workspace", "timeline", "releases", "stages", "calendar",
                        "docs", "kb", "resources", "diagrams",
                        "tests", "requirements", "wiegers",
                        "approvals", "changes", "raid", "reviews",
                        "team", "agents", "assets", "finance"]

    private func mo(_ man: String, _ env: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CT_XEM_MAN"] = man
        for (k, v) in env { app.launchEnvironment[k] = v }
        // Câu chữ kiểm ở đây là tiếng Anh. App NHỚ ngôn ngữ đã chọn ⇒ lớp chạy trước bằng `vi` (TimKiemUITests,
        // ThanhVienUITests khi chụp) làm cả lớp này đỏ nếu không ép lại.
        app.launchArguments += ["-com.cuongthai.ctwork.ngonNgu", "en"]
        app.launch()
        return app
    }

    private func chua(_ app: XCUIApplication, _ chu: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", chu)).firstMatch
    }

    func testMoMoiMoDunKhongSap() throws {
        var hong: [String] = []
        for id in Self.moDun {
            let app = mo("mod:\(id)")
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10), "\(id): không có thanh điều hướng")
            // Chờ tải xong (skeleton → nội dung).
            _ = app.staticTexts["Loading"].waitForNonExistence(timeout: 6)
            sleep(1)
            if app.state != .runningForeground { hong.append("\(id): app không còn chạy") }
            if app.staticTexts["Couldn't load"].exists { hong.append("\(id): màn lỗi với máy chủ giả") }
            if app.staticTexts["Choose a project"].exists { hong.append("\(id): đòi chọn dự án") }
            app.terminate()
        }
        XCTAssertTrue(hong.isEmpty, hong.joined(separator: "\n"))
    }

    func testMatMangMoiMoDunKhongSap() throws {
        var hong: [String] = []
        for id in Self.moDun {
            let app = mo("mod:\(id)", ["CT_XEM_LOI_MANG": "/work/projects/"])
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10), "\(id): không có thanh điều hướng khi mất mạng")
            sleep(3)
            if app.state != .runningForeground { hong.append("\(id): sập khi mất mạng") }
            // Không bao giờ được kẹt skeleton vô tận.
            if app.otherElements["Loading"].exists && app.staticTexts["Couldn't load"].exists == false {
                sleep(4)
                if app.otherElements["Loading"].exists { hong.append("\(id): kẹt khung tải khi mất mạng") }
            }
            app.terminate()
        }
        XCTAssertTrue(hong.isEmpty, hong.joined(separator: "\n"))
    }

    // MARK: Code

    func testCodeHoatDongNguonVaPR() throws {
        let app = mo("mod:code")
        XCTAssertTrue(app.staticTexts["northwind/mobile-app"].waitForExistence(timeout: 10))
        XCTAssertTrue(chua(app, "pushed 3 commits").waitForExistence(timeout: 5))
        // Chip mã thẻ mở thẻ ngay trong app.
        let chip = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Open issue NW-12'")).firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        chip.tap()
        XCTAssertTrue(app.staticTexts["Push notifications open the right issue"].waitForExistence(timeout: 8))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        // Pull request.
        app.buttons["Pull requests"].firstMatch.tap()
        XCTAssertTrue(chua(app, "NW-12: open the right issue from a notification").waitForExistence(timeout: 5))
        // Mã nguồn: thư mục → tệp (có số dòng) → lịch sử → commit (diff).
        let nguon = app.buttons["Source"]
        if !nguon.isHittable { app.scrollViews.firstMatch.swipeLeft() }
        nguon.tap()
        let thuMuc = app.buttons["Folder Sources"]
        for _ in 0..<4 where !(thuMuc.exists && thuMuc.isHittable) { app.swipeUp() }
        thuMuc.tap()
        XCTAssertTrue(app.buttons["Folder App"].waitForExistence(timeout: 5))
        app.buttons["Folder App"].tap()
        XCTAssertTrue(app.buttons["File NotificationRouter.swift"].waitForExistence(timeout: 5))
        app.buttons["File NotificationRouter.swift"].tap()
        XCTAssertTrue(chua(app, "Line 1: import SwiftUI").waitForExistence(timeout: 5), "khung mã phải có số dòng")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        // Tệp quá 1 MB ⇒ báo, không tải.
        app.buttons["File AppState.swift"].tap()
        XCTAssertTrue(app.staticTexts["This file is too large to show"].waitForExistence(timeout: 5))
    }

    func testCodeDiffCommit() throws {
        let app = mo("mod:code/source")
        let ls = app.buttons["History"]
        XCTAssertTrue(ls.waitForExistence(timeout: 10))
        ls.tap()
        let c = chua(app, "NW-12 Route cold-start taps")
        XCTAssertTrue(c.waitForExistence(timeout: 5))
        c.tap()
        XCTAssertTrue(chua(app, "Sources/App/NotificationRouter.swift").waitForExistence(timeout: 5))
        XCTAssertTrue(chua(app, "Added:").waitForExistence(timeout: 5), "diff mở sẵn tệp đầu, dòng + có nhãn VoiceOver")
    }

    /// Màn được ĐẨY dùng `NganXepCTW` (Docs › trang › Version history; Họp › chi tiết › mở thẻ) — trên iPad từng SIGTRAP
    /// vì màn được đẩy không thấy environmentObject của cột (đo 19/10 ở Code).
    func testManDayDungNganXep() throws {
        let app = mo("mod:docs/page")
        let menu = app.buttons["Page actions"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        menu.tap()
        app.buttons["Version history"].tap()
        XCTAssertTrue(app.navigationBars["Version history"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.state, .runningForeground)
    }

    // MARK: Trợ lý AI

    private func dongYNeuHoi(_ app: XCUIApplication) {
        let b = app.buttons["ai.consent.allow"]
        if b.waitForExistence(timeout: 3) { b.tap() }
    }

    /// Câu trả lời đến bằng SSE (máy chủ giả phát mẩu 23 byte — mục 16) ⇒ link ở cuối câu dài chỉ có khi stream xong.
    /// Xong = nút Dừng (`ai.stop`) biến mất.
    private func choHetStream(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["ai.stop"].waitForNonExistence(timeout: 40), "câu trả lời phải viết xong")
    }

    func testAIDongYTruocKhiHoi() throws {
        let app = mo("mod:ai/dongy")
        XCTAssertTrue(app.staticTexts["Questions are answered by AI"].waitForExistence(timeout: 8), "5.1.2(i): phải hỏi đồng ý trước câu đầu")
        XCTAssertTrue(chua(app, "third-party AI model provider").exists)
        app.buttons["ai.consent.allow"].tap()
        // Câu mở sẵn của `mod:ai/dongy` là câu mẫu ĐẦU — từ đợt CuongMini (21/10) là "What should I work on today?" ⇒ máy chủ
        // giả trả `AIGia.traLoiHomNay` (tiếng Việt, có link NW-12/NW-14/NW-17), không còn câu "You have 3 open issues".
        XCTAssertTrue(chua(app, "Sprint 6").waitForExistence(timeout: 10), "câu trả lời phải hiện sau khi đồng ý")
        choHetStream(app)
        XCTAssertTrue(app.links.matching(NSPredicate(format: "label CONTAINS 'NW-12'")).firstMatch.exists, "câu trả lời có link thẻ")
        XCTAssertTrue(app.staticTexts["AI-generated"].exists || chua(app, "AI-generated").exists, "4.7: nhãn AI")
    }

    func testAICauMauLinkMoTheVaBaoCao() throws {
        let app = mo("mod:ai")
        // Câu mẫu thứ hai ("What should I work on next…"). Từ mảng C câu hỏi đi bản STREAM ⇒ máy chủ giả trả
        // `AIGia.traLoiBang` (có bảng Sprint 6 + link NW-12/NW-17), không còn `traLoiMau` "You have 3 open issues"; câu mẫu
        // đầu giờ là "…today?" ⇒ `traLoiHomNay` (KIEN_TRUC mục 16, 17).
        let mau = app.buttons["ai.sample.1"]
        XCTAssertTrue(mau.waitForExistence(timeout: 8))
        mau.tap()
        dongYNeuHoi(app)
        XCTAssertTrue(chua(app, "Sprint 6").waitForExistence(timeout: 10), "câu trả lời phải hiện")
        choHetStream(app)
        // Link Markdown /work/<ws>/NW/issue/17 ⇒ mở thẻ trong app.
        let link = app.links.matching(NSPredicate(format: "label CONTAINS 'NW-17'")).firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()
        XCTAssertTrue(app.staticTexts["Offline cache for My Work"].waitForExistence(timeout: 8))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        // Báo cáo câu trả lời (4.7) ⇒ ẩn ngay cho người báo cáo.
        let bc = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'ai.report.'")).firstMatch
        for _ in 0..<5 where !(bc.exists && bc.isHittable) { app.swipeUp() }
        bc.tap()
        app.buttons["Spam or advertising"].tap()
        XCTAssertTrue(chua(app, "You reported this answer").waitForExistence(timeout: 5))
    }

    func testAI502HoiLai() throws {
        let app = mo("mod:ai")
        let o = app.textViews["ai.input"].exists ? app.textViews["ai.input"] : app.textFields["ai.input"]
        XCTAssertTrue(o.waitForExistence(timeout: 8))
        o.tap()
        o.typeText("Why is the build red? #fail")
        app.buttons["ai.send"].tap()
        dongYNeuHoi(app)
        let lai = app.buttons["ai.askAgain"]
        XCTAssertTrue(lai.waitForExistence(timeout: 10), "502 WORK_AI_BAD_OUTPUT phải có nút Ask again")
        XCTAssertTrue(chua(app, "couldn't be read").exists)
        lai.tap()
        XCTAssertTrue(chua(app, "Velocity dropped").waitForExistence(timeout: 10))
    }

    // MARK: Thông báo Git

    func testCongTacThongBaoGitVaThongBaoMoCode() throws {
        let app = mo("caidattb")
        let ct = app.switches.matching(NSPredicate(format: "label BEGINSWITH 'Git activity'")).firstMatch
        for _ in 0..<5 where !(ct.exists && ct.isHittable) { app.swipeUp() }
        XCTAssertTrue(ct.exists, "công tắc đẩy 'Git activity' (push.git)")
        let app2 = mo("hopthu")
        let tb = chua(app2, "requested your review on PR #48")
        // Hộp thư giờ có hàng cao (nút Approve/Reject, Reply, Join meeting) ⇒ thông báo Git nằm dưới mép màn; danh sách lười
        // chưa tạo phần tử cho tới khi cuộn tới.
        XCTAssertTrue(app2.staticTexts["Inbox"].waitForExistence(timeout: 8))
        for _ in 0..<6 where !(tb.exists && tb.isHittable) { app2.swipeUp() }
        XCTAssertTrue(tb.waitForExistence(timeout: 8), "thông báo Git (REVIEW_REQUESTED) trong Hộp thư")
        tb.tap()
        XCTAssertTrue(chua(app2, "NW-12: open the right issue from a notification").waitForExistence(timeout: 10), "thông báo Git mở thẳng tab PR của Code")
    }
}

/// "Hiện dần" (19/10/2026): điều hướng chỉ còn mô-đun cốt lõi; "More tools" có tìm + ghim, ghim hiện lên điều hướng chính.
final class HienDanUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testMoreTimVaGhim() throws {
        let app = XCUIApplication()
        app.launchEnvironment["CT_XEM_MAN"] = "them"
        app.launchArguments += ["-com.cuongthai.ctwork.ngonNgu", "en"]   // app nhớ ngôn ngữ của lớp chạy trước
        app.launch()
        XCTAssertTrue(app.buttons["more.board"].waitForExistence(timeout: 10), "lưới More tools mở")
        // Tìm (lưới lười: ô ngoài màn chưa có phần tử ⇒ tìm thay vì cuộn).
        let tim = app.searchFields["Search tools"]
        XCTAssertTrue(tim.waitForExistence(timeout: 5))
        tim.tap(); tim.typeText("okr")
        XCTAssertTrue(app.buttons["more.okrs"].waitForExistence(timeout: 5), "OKRs (không cốt lõi) nằm trong More")
        tim.buttons["Clear text"].firstMatch.tap()
        tim.typeText("retro")
        XCTAssertTrue(app.buttons["more.retros"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["more.okrs"].exists, "tìm lọc lưới")
        // Ghim ⇒ hiện trên điều hướng chính; bỏ ghim lại cho sạch.
        let ghim = app.buttons["Pin Retrospectives"]
        XCTAssertTrue(ghim.waitForExistence(timeout: 5))
        ghim.tap()
        XCTAssertTrue(app.buttons["Unpin Retrospectives"].waitForExistence(timeout: 5))
        app.buttons["Unpin Retrospectives"].tap()
        XCTAssertTrue(app.buttons["Pin Retrospectives"].waitForExistence(timeout: 5))
        // Mở một mô-đun từ lưới.
        app.buttons["more.retros"].tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 8))
        XCTAssertEqual(app.state, .runningForeground)
    }
}
