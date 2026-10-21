import XCTest
@testable import CTWork

/// Màn khởi động + lớp chuyển động (21/10/2026): lịch thoát (khôi phục phiên trước/sau hoạt hình, bỏ qua, trần),
/// bộ điều phối chạy thật, điều kiện dựng màn khởi động, âm thanh có trong gói, pháo "Xong!".
@MainActor
final class KhoiDongCTWTests: XCTestCase {
    private let lich = KhoiDongCTW.lich   // toiThieu 1,5 · tuNhien 1,8 · tran 2,3 · thoat 0,4

    // MARK: Lịch thoát (thuần)

    func testKhoiPhucXongTruocHoatHinhThiThoatNgayKhiLogoHienDu() {
        // Khôi phục xong ở 0,3 s ⇒ không đợi đoạn "đứng ngắm" tới 1,8 s — thoát ở mốc logo hiện đủ.
        XCTAssertEqual(lich.batDauThoat(khoiPhuc: 0.3, boQua: nil, bayGio: 0.3), lich.toiThieu)
        XCTAssertEqual(lich.batDauThoat(khoiPhuc: 0.0, boQua: nil, bayGio: 0.0), lich.toiThieu)
    }

    func testKhoiPhucXongGiuaDoanDungNgamThiThoatNgayLucDo() {
        XCTAssertEqual(lich.batDauThoat(khoiPhuc: 1.6, boQua: nil, bayGio: 1.6)!, 1.6, accuracy: 1e-9)
        XCTAssertEqual(lich.batDauThoat(khoiPhuc: lich.tuNhien, boQua: nil, bayGio: lich.tuNhien)!, lich.tuNhien, accuracy: 1e-9)
    }

    func testKhoiPhucChamThiDoiNhungKhongQuaTran() {
        // Chưa xong, chưa tới trần ⇒ còn chờ.
        XCTAssertNil(lich.batDauThoat(khoiPhuc: nil, boQua: nil, bayGio: 1.0))
        XCTAssertNil(lich.batDauThoat(khoiPhuc: nil, boQua: nil, bayGio: 2.0))
        // Xong sau khi hoạt hình hết nhưng trước trần ⇒ thoát lúc xong.
        XCTAssertEqual(lich.batDauThoat(khoiPhuc: 2.0, boQua: nil, bayGio: 2.0)!, 2.0, accuracy: 1e-9)
        // Tới trần mà chưa xong ⇒ thoát ở trần (màn khởi động không bao giờ chặn đường vào app).
        XCTAssertEqual(lich.batDauThoat(khoiPhuc: nil, boQua: nil, bayGio: lich.tran), lich.tran)
        XCTAssertEqual(lich.batDauThoat(khoiPhuc: 5, boQua: nil, bayGio: 5), lich.tran)
    }

    func testBoQuaThoatNgayVaThangMocKhac() {
        XCTAssertEqual(lich.batDauThoat(khoiPhuc: nil, boQua: 0.4, bayGio: 0.4), 0.4)
        XCTAssertEqual(lich.batDauThoat(khoiPhuc: 0.2, boQua: 0.6, bayGio: 0.6), 0.6, "bỏ qua sớm hơn mốc logo-hiện-đủ ⇒ thắng")
        XCTAssertEqual(lich.batDauThoat(khoiPhuc: 0.2, boQua: 1.7, bayGio: 1.7), lich.toiThieu, "mốc sớm hơn thắng")
    }

    func testTienDoThoatVaXong() {
        XCTAssertEqual(lich.tienDoThoat(batDau: nil, t: 3), 0)
        XCTAssertEqual(lich.tienDoThoat(batDau: 1.5, t: 1.4), 0)
        XCTAssertEqual(lich.tienDoThoat(batDau: 1.5, t: 1.7), 0.5, accuracy: 1e-9)
        XCTAssertEqual(lich.tienDoThoat(batDau: 1.5, t: 9), 1)
        XCTAssertFalse(lich.daXong(batDau: nil, t: 99))
        XCTAssertFalse(lich.daXong(batDau: 1.5, t: 1.8))
        XCTAssertTrue(lich.daXong(batDau: 1.5, t: 1.9))
    }

    func testTongThoiGianTrongKhoang() {
        // Khôi phục sớm: tổng = toiThieu + thoat; khôi phục chậm: tối đa tran + thoat.
        XCTAssertEqual(lich.toiThieu + lich.thoat, 1.9, accuracy: 0.001)
        XCTAssertLessThanOrEqual(lich.tran + lich.thoat, 2.8)
        XCTAssertLessThan(KhoiDongCTW.lichGiam.tran, lich.tran, "Giảm chuyển động ⇒ ngắn hơn")
        XCTAssertLessThan(KhoiDongCTW.mocTich, lich.toiThieu, "dấu tích (âm thanh) phải trước lúc thoát")
    }

    // MARK: Bộ điều phối (chạy thật, lịch rút ngắn)

    private let lichNgan = LichKhoiDong(toiThieu: 0.15, tuNhien: 0.25, tran: 0.6, thoat: 0.05)

    func testDieuPhoiKhoiPhucSomXongNhanh() async {
        let d = DieuPhoiKhoiDong(lich: lichNgan)
        let xong = expectation(description: "xong")
        d.chay { xong.fulfill() }
        d.baoKhoiPhucXong()
        await fulfillment(of: [xong], timeout: 2)
        XCTAssertTrue(d.xong)
        XCTAssertEqual(d.mocThoat ?? -1, lichNgan.toiThieu, accuracy: 1e-9)
    }

    func testDieuPhoiKhongKhoiPhucThiThoatOTran() async {
        let d = DieuPhoiKhoiDong(lich: lichNgan)
        let xong = expectation(description: "xong")
        d.chay { xong.fulfill() }
        await fulfillment(of: [xong], timeout: 3)
        XCTAssertEqual(d.mocThoat ?? -1, lichNgan.tran, accuracy: 1e-9)
    }

    func testDieuPhoiBoQua() async {
        let d = DieuPhoiKhoiDong(lich: LichKhoiDong(toiThieu: 5, tuNhien: 6, tran: 7, thoat: 0.05))
        KhoiDongChung.shared.dangChieu = true
        let xong = expectation(description: "xong")
        d.chay { xong.fulfill() }
        try? await Task.sleep(nanoseconds: 60_000_000)
        d.boQua()
        await fulfillment(of: [xong], timeout: 2)
        XCTAssertLessThan(d.mocThoat ?? 99, 1, "bỏ qua ⇒ thoát ngay, không đợi 5 s")
        XCTAssertFalse(KhoiDongChung.shared.dangChieu, "thoát ⇒ báo màn bên dưới được chạy hoạt hình")
    }

    // MARK: Khi nào dựng màn khởi động

    func testNenHien() {
        XCTAssertTrue(KhoiDongCTW.nenHien([:]))
        XCTAssertFalse(KhoiDongCTW.nenHien(["XCTestConfigurationFilePath": "/x"]), "app chủ của unit test")
        XCTAssertFalse(KhoiDongCTW.nenHien(["CT_KHONG_KHOIDONG": "1"]))
        XCTAssertFalse(KhoiDongCTW.nenHien(["CT_XEM_MAN": "board"]), "màn thử ⇒ không chen màn khởi động")
        XCTAssertTrue(KhoiDongCTW.nenHien(["CT_XEM_MAN": "dangnhap", "CT_XEM_KHOIDONG": "1"]))
    }

    // MARK: Âm thanh

    func testBayTepAmThanhNamOGocGoiApp() {
        // Âm thông báo đẩy phải ở GỐC gói (hoặc Library/Sounds) — iOS không tìm trong thư mục con.
        for ten in ["ctwork", "tin-nhan", "giao-the", "nhac-ten", "han-chot", "xong", "cuongmini"] {
            let u = Bundle.main.url(forResource: ten, withExtension: "caf")
            XCTAssertNotNil(u, "\(ten).caf thiếu trong gói app")
            XCTAssertEqual(u?.deletingLastPathComponent().standardizedFileURL, Bundle.main.bundleURL.standardizedFileURL,
                           "\(ten).caf phải ở gốc gói")
        }
    }

    func testCongTacAmThanhMacDinhBat() {
        let d = UserDefaults.standard
        let cu = (d.object(forKey: AmThanhCTW.khoaKhoiDong), d.object(forKey: AmThanhCTW.khoaHieuUng))
        d.removeObject(forKey: AmThanhCTW.khoaKhoiDong)
        d.removeObject(forKey: AmThanhCTW.khoaHieuUng)
        AmThanhCTW.dangKyMacDinh()
        XCTAssertTrue(AmThanhCTW.batKhoiDong)
        XCTAssertTrue(AmThanhCTW.batHieuUng)
        d.set(false, forKey: AmThanhCTW.khoaKhoiDong)
        XCTAssertFalse(AmThanhCTW.batKhoiDong)
        if let a = cu.0 { d.set(a, forKey: AmThanhCTW.khoaKhoiDong) } else { d.removeObject(forKey: AmThanhCTW.khoaKhoiDong) }
        if let b = cu.1 { d.set(b, forKey: AmThanhCTW.khoaHieuUng) } else { d.removeObject(forKey: AmThanhCTW.khoaHieuUng) }
    }

    // MARK: Pháo "Xong!"

    func testPhaoXongGoiMocAmThanh() {
        let no = CTWNoXong.shared
        let cuMoc = no.amThanh
        defer { no.amThanh = cuMoc }
        var soLanAm = 0
        no.amThanh = { soLanAm += 1 }
        let truoc = no.lan
        no.phat()
        XCTAssertEqual(no.lan, truoc + 1)
        XCTAssertEqual(soLanAm, 1)
        XCTAssertFalse(CTWNoXong.laXong(1, cfg: nil), "không có cấu hình ⇒ không nổ")
    }
}
