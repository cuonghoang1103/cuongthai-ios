import XCTest
import SwiftData
@testable import CuongThaiApp

/// Vở theo học kỳ · mẫu trang · chữ nhận dạng (23/10/2026).
@MainActor
final class VoHocKyTests: XCTestCase {

    private func buoi(_ id: Int, _ thu: Int, _ gio: String, batDau: String?) -> BuoiHoc {
        BuoiHoc(id: id, subject: "SWT301 - Software Testing", classCode: "SE1912", teacher: nil, room: nil,
                weekday: thu, startTime: gio, endTime: "23:59", color: nil, note: nil, remindMinutes: 0,
                startDate: batDau, endDate: nil, slot: 2, meetUrl: nil, materialsUrl: nil)
    }

    func testMaMonKhongNhamMaLop() {
        XCTAssertEqual(VoHocKy.maMon(trong: "SWT301 - Software Testing"), "SWT301")
        XCTAssertEqual(VoHocKy.maMon(trong: "Môn jpd123 (Tiếng Nhật)"), "JPD123")
        XCTAssertEqual(VoHocKy.maMon(trong: "MAE101c"), "MAE101")
        XCTAssertNil(VoHocKy.maMon(trong: "SE1801"), "mã lớp 4 số không phải mã môn")
        XCTAssertNil(VoHocKy.maMon(trong: "Toán cao cấp"))
    }

    /// Thứ Hai 05/10/2026 bắt đầu; học thứ 2 + thứ 5 ⇒ thứ 2 tuần 3 (19/10) là buổi 5.
    func testSoSlotDemMoiBuoiCuaMon() throws {
        let a = buoi(1, 2, "07:30", batDau: "2026-10-05")
        let b = buoi(2, 5, "12:50", batDau: "2026-10-05")
        let ngay = try XCTUnwrap(PhamViViec.dinhDang.date(from: "2026-10-19"))
        XCTAssertEqual(VoHocKy.soSlot(a, vao: ngay, cacBuoi: [a, b], batDauKy: nil), 5)
        let ngay2 = try XCTUnwrap(PhamViViec.dinhDang.date(from: "2026-10-08"))
        XCTAssertEqual(VoHocKy.soSlot(b, vao: ngay2, cacBuoi: [a, b], batDauKy: nil), 2)
        // Không biết ngày bắt đầu ⇒ không bịa số.
        let c = buoi(3, 2, "07:30", batDau: nil)
        XCTAssertNil(VoHocKy.soSlot(c, vao: ngay, cacBuoi: [c], batDauKy: nil))
    }

    func testTieuDeTrangBuoi() throws {
        let b = buoi(1, 2, "07:30", batDau: "2026-10-05")
        let m = VoHocKy.gopMon(tongQuan: nil, lich: [b])
        XCTAssertEqual(m.first?.maMon, "SWT301")
        XCTAssertEqual(m.first?.tenVo, "SWT301 · Software Testing")
        let ngay = try XCTUnwrap(PhamViViec.dinhDang.date(from: "2026-10-19"))
        let ds = VoHocKy.buoiTrongNgay(m, vao: ngay, batDauKy: nil, tongQuan: nil)
        XCTAssertEqual(ds.count, 1)
        XCTAssertEqual(ds.first?.tieuDeTrang, "Slot 3 · 19/10")
    }

    /// Giấy lạ (máy mới gửi, máy cũ chưa biết) ⇒ đọc ra kẻ ngang, không vỡ.
    func testMauTrangVaGiayLa() {
        XCTAssertEqual(LoaiGiay.mauTrang.count, 5)
        XCTAssertTrue(LoaiGiay.tuVung3Cot.laMauTrang)
        XCTAssertFalse(LoaiGiay.keNgang.laMauTrang)
        XCTAssertEqual(LoaiGiay(rawValue: "soDoTuDuy"), .soDoTuDuy)
        let t = TrangVo(cuon: nil, thuTu: 0, giay: .keNgang, huong: .doc)
        t.loaiGiay = "giayChuaCo"
        XCTAssertEqual(t.giay, .keNgang)
        XCTAssertFalse(GiayNenView.dongChanChu(giay: .tuVung3Cot, khoTrang: HuongGiay.doc.khoA4).isEmpty)
    }

    func testDauChuOnDinh() {
        XCTAssertEqual(DauChuDaGui.dau("đạo hàm"), DauChuDaGui.dau("đạo hàm"))
        XCTAssertNotEqual(DauChuDaGui.dau("đạo hàm"), DauChuDaGui.dau("dao ham"))
    }

    /// Trang của buổi: gọi hai lần ⇒ CÙNG một trang (không nhân đôi), cuốn mới
    /// dùng lại trang trắng sẵn có thay vì để trống trang đầu.
    func testTrangChoBuoiKhongNhanDoi() throws {
        let schema = Schema([MonVo.self, CuonVo.self, TrangVo.self, ViecXoaCho.self, TienDoChu.self, TheHoiAI.self])
        let c = try ModelContainer(for: schema, configurations: [ModelConfiguration("ThuHK", schema: schema, isStoredInMemoryOnly: true)])
        let kho = ModelContext(c)
        let ma = "ZZT9\(Int.random(in: 10...99))"
        let m = MonKyNay(maMon: String(ma.prefix(6)), ten: "Thử", mauHex: 0x6366F1, courseSlug: "thu", buoi: [])
        let bh = buoi(9, 2, "07:30", batDau: "2026-10-05")
        let ngay = try XCTUnwrap(PhamViViec.dinhDang.date(from: "2026-10-19"))
        let bv = BuoiVo(mon: m, buoi: bh, ngay: ngay, soSlot: 3, chuDe: nil)
        let (cuon, t1) = VoHocKy.trangChoBuoi(bv, tenKy: "Fall 2026", kho: kho)
        let (_, t2) = VoHocKy.trangChoBuoi(bv, tenKy: "Fall 2026", kho: kho)
        XCTAssertEqual(t1.id, t2.id)
        XCTAssertEqual(cuon.soTrang, 1)
        XCTAssertEqual(t1.tieuDe, "Slot 3 · 19/10")
        XCTAssertEqual(cuon.ten, "Fall 2026")
    }
}
