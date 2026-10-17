import XCTest
@testable import CTWork

/// Kiểm thử phần dùng chung của mảng B: ngày theo giờ VN, định dạng số/giờ.
final class KeHoachChungTests: XCTestCase {
    func testNgayTheoGioVN() throws {
        // Sprint lưu 00:00 giờ VN = 17:00Z hôm trước — cắt 10 ký tự là SAI một ngày, `ngayCua` phải đúng.
        XCTAssertEqual(NgayCTW.ngayCua("2026-10-12T17:00:00.000Z"), "2026-10-13")
        XCTAssertEqual(NgayCTW.ngayCua("2026-10-13"), "2026-10-13")
        XCTAssertNil(NgayCTW.ngayCua(nil))
        let d = try XCTUnwrap(NgayCTW.ngay("2026-10-18"))
        XCTAssertEqual(NgayCTW.ymd(d), "2026-10-18")
        XCTAssertNil(NgayCTW.ngay("bad"))
    }

    func testDauTuanVaSoNgay() throws {
        // 18/10/2026 là Chủ nhật ⇒ thứ Hai đầu tuần là 12/10.
        let cn = try XCTUnwrap(NgayCTW.ngay("2026-10-18"))
        XCTAssertEqual(NgayCTW.ymd(NgayCTW.dauTuan(cn)), "2026-10-12")
        let t2 = try XCTUnwrap(NgayCTW.ngay("2026-10-12"))
        XCTAssertEqual(NgayCTW.ymd(NgayCTW.dauTuan(t2)), "2026-10-12")
        XCTAssertEqual(NgayCTW.soNgay(t2, cn), 6)
        XCTAssertEqual(NgayCTW.ymd(NgayCTW.cong(t2, ngay: 7)), "2026-10-19")
    }

    func testDinhDangSo() {
        XCTAssertEqual(CTWSo.gon(3), "3")
        XCTAssertEqual(CTWSo.gon(2.5), "2.5")
        XCTAssertEqual(CTWSo.gio(giay: 0), "0m")
        XCTAssertEqual(CTWSo.gio(giay: 45 * 60), "45m")
        XCTAssertEqual(CTWSo.gio(giay: 2 * 3600), "2h")
        XCTAssertEqual(CTWSo.gio(giay: 2 * 3600 + 5 * 60), "2h 05m")
        XCTAssertEqual(CTWSo.dongHo(giay: 125), "02:05")
        XCTAssertEqual(CTWSo.dongHo(giay: 3725), "1:02:05")
        XCTAssertEqual(CTWSo.usd(0.004), "<$0.01")
        XCTAssertEqual(CTWSo.usd(1.5), "$1.50")
    }
}
