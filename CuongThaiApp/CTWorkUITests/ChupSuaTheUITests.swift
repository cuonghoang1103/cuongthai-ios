import XCTest

/// Mảng A (sửa thẻ, 20/10/2026): CHỤP màn hình bằng máy chủ giả (không phải kiểm thử hồi quy).
/// Chỉ chạy khi có `TEST_RUNNER_CTW_CHUP_A=<thư mục>` (xcodebuild chuyển thành `CTW_CHUP_A` của bộ chạy test);
/// `TEST_RUNNER_CTW_CHUP_HAU_TO=-dark` ⇒ thêm hậu tố tên tệp (chạy lại sau `simctl ui … appearance dark`).
/// App chạy tiếng Việt (`-com.cuongthai.ctwork.ngonNgu vi`).
final class ChupSuaTheUITests: XCTestCase {
    private var thuMuc: String? { ProcessInfo.processInfo.environment["CTW_CHUP_A"] }
    private var hauTo: String { ProcessInfo.processInfo.environment["CTW_CHUP_HAU_TO"] ?? "" }

    override func setUpWithError() throws {
        continueAfterFailure = true
        try XCTSkipIf((thuMuc ?? "").isEmpty, "chỉ chạy khi chụp màn")
    }

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
        if let thuMuc { try? s.pngRepresentation.write(to: URL(fileURLWithPath: thuMuc).appendingPathComponent(ten + hauTo + ".png")) }
    }

    private func cho(_ giay: UInt32) { sleep(giay) }

    func test01SoanMoTa() {
        let app = mo("the:suamota")
        cho(5)
        chup(app, "01-soan-mo-ta")
    }

    func test02TickOViec() {
        let app = mo("the:tick")
        cho(6)
        chup(app, "02-tick-o-viec")
    }

    func test03Truong() {
        let app = mo("issue")
        cho(5)
        chup(app, "03a-truong-chi-tiet")
        let app2 = mo("the:tuychinh")
        cho(5)
        chup(app2, "03b-truong-tuy-chinh")
    }

    func test04TheConThemNhanh() {
        let app = mo("the:thecon")
        cho(6)
        chup(app, "04-viec-con-them-nhanh")
    }

    func test05LienKetThe() {
        let app = mo("the:lienket")
        cho(6)
        chup(app, "05-lien-ket-the")
    }

    func test06GhiGio() {
        let app = mo("the:ghigio")
        cho(5)
        chup(app, "06a-ghi-gio-trong-the")
        let nut = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Ghi giờ' OR label CONTAINS[c] 'Log time'")).firstMatch
        if nut.waitForExistence(timeout: 5) {
            nut.tap()
            cho(3)
            chup(app, "06b-ghi-gio-tam-phu")
        }
    }

    func test07TaoThe() {
        let app = mo("the:taothe")
        cho(5)
        let o = app.textFields["ctw.tao.tieuDe"].exists ? app.textFields["ctw.tao.tieuDe"] : app.textViews["ctw.tao.tieuDe"]
        if o.waitForExistence(timeout: 5) {
            o.tap()
            o.typeText("Notification badge stays after reading")
            cho(3)
        }
        chup(app, "07-tao-the")
    }

    func test08MenuThe() {
        let app = mo("issue")
        cho(5)
        let m = app.buttons["ctw.the.menu"]
        if m.waitForExistence(timeout: 8) {
            m.tap()
            cho(2)
        }
        chup(app, "08-menu-nhan-ban-chuyen-xoa")
        let xoa = app.buttons.matching(NSPredicate(format: "label == 'Xoá thẻ' OR label == 'Delete issue'")).firstMatch
        if xoa.waitForExistence(timeout: 3) {
            xoa.tap()
            cho(2)
            chup(app, "09-hoi-xoa-the")
        }
    }
}
