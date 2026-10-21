import XCTest
@testable import CTWork

/// Màn "Tìm mọi thứ" (⌘K, 21/10/2026) — phần THUẦN: bỏ dấu, xếp hạng (đầu chuỗi > đầu từ > chứa), nhận mã thẻ,
/// mọi mô-đun tìm được bằng tên vi + en, từ khoá hay gõ dẫn đúng chỗ.
@MainActor
final class TimKiemCTWTests: XCTestCase {
    private var moDun: [MucTimCTW] { CTWDangKyMoDun.dangKyMoDun.map(CTWXepHangTim.muc) }
    private var tatCa: [MucTimCTW] { CTWXepHangTim.manApp + moDun }

    private func ids(_ q: String, _ ds: [MucTimCTW]? = nil) -> [String] { CTWXepHangTim.xep(q, ds ?? tatCa).map(\.id) }

    // MARK: Bỏ dấu

    func testBoDauTiengViet() {
        XCTAssertEqual(CTWBoDau.chuan("Báo cáo"), "bao cao")
        XCTAssertEqual(CTWBoDau.chuan("ĐỔI DỰ ÁN"), "doi du an")
        XCTAssertEqual(CTWBoDau.chuan("Thời gian"), "thoi gian")
        XCTAssertEqual(CTWBoDau.chuan("  Docs & knowledge "), "docs knowledge", "dấu câu thành một khoảng trắng")
        XCTAssertEqual(CTWBoDau.chuan("ai-usage"), "ai usage")
        XCTAssertEqual(CTWBoDau.chuan("Lịch   họp"), "lich hop")
        XCTAssertEqual(CTWBoDau.chuan(""), "")
    }

    // MARK: Xếp hạng

    func testDiemTheoThuBac() throws {
        let q = "bao"
        let dau = try XCTUnwrap(CTWKhopTim.diem(q, "bao cao tuan"))
        let dauTu = try XCTUnwrap(CTWKhopTim.diem(q, "xem bao cao"))
        let chua = try XCTUnwrap(CTWKhopTim.diem(q, "thongbao moi"))
        XCTAssertGreaterThan(CTWKhopTim.diem("bao cao", "bao cao")!, dau, "trùng hẳn đứng đầu")
        XCTAssertGreaterThan(dau, dauTu, "đầu chuỗi > đầu một từ")
        XCTAssertGreaterThan(dauTu, chua, "đầu một từ > chứa")
        XCTAssertNil(CTWKhopTim.diem(q, "board"))
        XCTAssertNotNil(CTWKhopTim.diem("lich hop", "hop lich"), "nhiều từ, khác thứ tự vẫn khớp")
        XCTAssertNil(CTWKhopTim.diem("lich xyz", "hop lich"))
    }

    func testXepHangMucDauChuoiTruoc() {
        let ds = [
            MucTimCTW(id: "c", nhom: .chucNang, tenNguon: "Thongbao moi", bieuTuong: "x", dich: .hopThu),
            MucTimCTW(id: "b", nhom: .chucNang, tenNguon: "Xem báo cáo", bieuTuong: "x", dich: .hopThu),
            MucTimCTW(id: "a", nhom: .chucNang, tenNguon: "Báo cáo tuần", bieuTuong: "x", dich: .hopThu),
            MucTimCTW(id: "z", nhom: .chucNang, tenNguon: "Board", bieuTuong: "x", dich: .hopThu),
        ]
        XCTAssertEqual(CTWXepHangTim.xep("bao", ds).map(\.id), ["a", "b", "c"])
        XCTAssertEqual(CTWXepHangTim.xep("BÁO", ds).map(\.id), ["a", "b", "c"], "không phân biệt hoa thường/dấu")
        // Đếm "hay dùng" chỉ phân định khi ngang điểm — không đè thứ bậc khớp.
        XCTAssertEqual(CTWXepHangTim.xep("bao", ds, dem: ["c": 99]).map(\.id), ["a", "b", "c"])
        let ngang = [MucTimCTW(id: "p", nhom: .chucNang, tenNguon: "Báo cáo A", bieuTuong: "x", dich: .hopThu),
                     MucTimCTW(id: "q", nhom: .chucNang, tenNguon: "Báo cáo B", bieuTuong: "x", dich: .hopThu)]
        XCTAssertEqual(CTWXepHangTim.xep("bao", ngang, dem: ["q": 3]).map(\.id), ["q", "p"])
    }

    // MARK: Mã thẻ

    func testNhanMaThe() {
        XCTAssertEqual(CTWMaTheGo.tach("ABC-12"), CTWMaTheGo(maDuAn: "ABC", so: 12))
        XCTAssertEqual(CTWMaTheGo.tach(" nw-7 "), CTWMaTheGo(maDuAn: "NW", so: 7), "chữ thường + khoảng trắng")
        XCTAssertEqual(CTWMaTheGo.tach("SWP391-4"), CTWMaTheGo(maDuAn: "SWP391", so: 4))
        XCTAssertEqual(CTWMaTheGo.tach("12"), CTWMaTheGo(maDuAn: nil, so: 12))
        XCTAssertEqual(CTWMaTheGo.tach("#12"), CTWMaTheGo(maDuAn: nil, so: 12))
        XCTAssertNil(CTWMaTheGo.tach("ABC-"))
        XCTAssertNil(CTWMaTheGo.tach("ABC-12x"))
        XCTAssertNil(CTWMaTheGo.tach("1AB-3"), "mã dự án bắt đầu bằng chữ")
        XCTAssertNil(CTWMaTheGo.tach("0"))
        XCTAssertNil(CTWMaTheGo.tach("báo cáo"))
        XCTAssertNil(CTWMaTheGo.tach("１２"), "chữ số toàn khổ không phải mã")
        XCTAssertEqual(CTWMaTheGo.tach("12")?.ma("NW"), "NW-12")
        XCTAssertNil(CTWMaTheGo.tach("12")?.ma(nil), "chưa chọn dự án ⇒ số trần không thành mã")
        XCTAssertEqual(CTWMaTheGo.tach("abc-3")?.ma("NW"), "ABC-3", "mã gõ thắng dự án đang chọn")
    }

    // MARK: Mọi mô-đun tìm được bằng tên vi + en

    func testMoiMoDunTimDuocBangTenViVaEn() throws {
        XCTAssertEqual(CTWHaiNgu.cacTen(khoa: "Reports"), ["Reports", "Báo cáo"], "đọc thẳng vi.lproj, không theo ngôn ngữ đang chọn")
        var thieuVi: [String] = []
        for m in CTWDangKyMoDun.dangKyMoDun {
            let ten = CTWHaiNgu.cacTen(m.tenNguon)
            XCTAssertEqual(ten.first, m.tenNguon.key)
            if ten.count < 2 { thieuVi.append(m.id) }
            for q in ten {
                let kq = ids(q, moDun)
                let i = kq.firstIndex(of: "mod:\(m.id)")
                XCTAssertNotNil(i, "“\(q)” không tìm ra mô-đun \(m.id)")
                XCTAssertLessThan(i ?? 99, 3, "“\(q)” xếp mô-đun \(m.id) quá thấp: \(kq.prefix(4))")
            }
            // Gõ không dấu tên tiếng Việt cũng ra.
            if let vi = ten.dropFirst().first {
                XCTAssertTrue(ids(CTWBoDau.chuan(vi), moDun).contains("mod:\(m.id)"), "không dấu “\(vi)”")
            }
        }
        // Tên giữ nguyên tiếng Anh theo GLOSSARY (Board, Backlog…) thì không có bản vi riêng — số này phải nhỏ.
        XCTAssertLessThan(thieuVi.count, 12, "thiếu bản vi: \(thieuVi)")
    }

    func testTuKhoaHayGoDanDungCho() {
        let mong: [(String, String)] = [
            ("sprint", "mod:sprints"), ("bảng", "mod:board"), ("kanban", "mod:board"), ("lịch", "mod:calendar"),
            ("họp", "mod:meetings"), ("tài liệu", "mod:docs"), ("chat", "mod:chat"), ("tin nhắn", "mod:tin-nhan"),
            ("ai", "mod:ai"), ("cuongmini", "mod:ai"), ("báo cáo", "mod:reports"), ("bao cao", "mod:reports"),
            ("thời gian", "mod:time"), ("thanh vien", "mod:thanh-vien"), ("team", "mod:team"), ("github", "mod:code"), ("rủi ro", "mod:raid"),
            ("thông báo", "app:inbox"), ("việc của tôi", "app:mywork"), ("cài đặt", "app:account"), ("face id", "app:account"),
        ]
        for (q, id) in mong {
            let kq = ids(q)
            XCTAssertTrue(kq.prefix(3).contains(id), "“\(q)” ⇒ \(id) phải trong 3 đầu, được \(kq.prefix(4))")
        }
    }

    /// Thành viên / Tin nhắn riêng (mô-đun CẤP ỨNG DỤNG của ctw-msg) và CuongMini phải đứng ĐẦU với những chữ người
    /// dùng hay gõ — trước đây "Thành viên" ra Team, "Tin nhắn" ra Chat (từ khoá đặt dưới id đoán `members`/`messages`).
    func testThanhVienTinNhanCuongMiniDungDau() {
        let mong: [(String, String)] = [
            ("thanh vien", "mod:thanh-vien"), ("Thành viên", "mod:thanh-vien"), ("members", "mod:thanh-vien"),
            ("online", "mod:thanh-vien"), ("đang hoạt động", "mod:thanh-vien"), ("đồng nghiệp", "mod:thanh-vien"),
            ("tin nhan", "mod:tin-nhan"), ("Tin nhắn", "mod:tin-nhan"), ("nhắn tin", "mod:tin-nhan"),
            ("chat riêng", "mod:tin-nhan"), ("messages", "mod:tin-nhan"), ("dm", "mod:tin-nhan"),
            ("kênh", "mod:chat"), ("channel", "mod:chat"),
            ("cuongmini", "mod:ai"), ("CuongMini", "mod:ai"), ("hỏi ai", "mod:ai"), ("hom nay lam gi", "mod:ai"),
            ("Hôm nay tôi nên làm gì?", "mod:ai"),
        ]
        for (q, id) in mong {
            XCTAssertEqual(ids(q).first, id, "“\(q)” ⇒ \(id) phải đứng đầu, được \(ids(q).prefix(4))")
        }
    }

    /// Từ khoá chỉ có tác dụng khi khoá trùng id một mô-đun đã đăng ký — khoá đoán sai (vd `members`) là chết câm.
    func testKhoaTuKhoaLaIdMoDunThat() {
        let co = Set(CTWDangKyMoDun.dangKyMoDun.map(\.id))
        for id in CTWTuKhoaMoDun.bang.keys { XCTAssertTrue(co.contains(id), "từ khoá khai dưới id “\(id)” không có mô-đun") }
        XCTAssertTrue(CTWDangKyMoDun.moDun("tin-nhan")?.capUngDung == true)
        XCTAssertTrue(CTWDangKyMoDun.moDun("thanh-vien")?.capUngDung == true)
    }

    /// Mở Thành viên / Tin nhắn từ màn tìm ⇒ đúng mục (iPad) + đúng phân đoạn tab Chat (iPhone), kể cả khi `muc` đã là
    /// mô-đun đó và người dùng tự đổi phân đoạn sau (onChange không chạy ⇒ phải đặt `phan` trực tiếp).
    func testMoThanhVienTinNhanTuTimKiem() {
        let app = AppState.shared, kho = KhoTinNhanCTW.shared
        let mucCu = app.muc, phanCu = kho.phan
        defer { app.muc = mucCu; kho.phan = phanCu; kho.hoSoCanMo = nil }

        DieuHuongTimCTW.shared.moMoDun("thanh-vien")
        XCTAssertEqual(app.muc, .moDun("thanh-vien"))
        XCTAssertEqual(kho.phan, "thanhVien")
        XCTAssertNotEqual(app.dichCho?.moDun, "thanh-vien", "mô-đun cấp ứng dụng không đặt dichCho")

        kho.phan = "kenh"   // người dùng tự đổi sang Kênh
        DieuHuongTimCTW.shared.moMoDun("thanh-vien")
        XCTAssertEqual(kho.phan, "thanhVien")

        DieuHuongTimCTW.shared.moMoDun("tin-nhan")
        XCTAssertEqual(app.muc, .moDun("tin-nhan"))
        XCTAssertEqual(kho.phan, "tinNhan")

        kho.moHoSo(5)
        XCTAssertEqual(app.muc, .moDun("thanh-vien"))
        XCTAssertEqual(kho.phan, "thanhVien")
        XCTAssertEqual(kho.hoSoCanMo, 5)
    }

    func testMoiKhoaTuKhoaKhongDau() {
        for (id, ds) in CTWTuKhoaMoDun.bang {
            for k in ds { XCTAssertEqual(CTWBoDau.chuan(k), k, "từ khoá \(id) “\(k)” phải viết không dấu, chữ thường") }
        }
    }

    // MARK: Lệnh

    func testLenhTheoQuyen() {
        let co = CTWXepHangTim.lenh(taoThe: true, taoDuAn: true, coDuAn: true, ngonNguHienTai: .vi)
        XCTAssertEqual(ids("tạo thẻ", co).first, "act:create")
        XCTAssertTrue(ids("cuongmini", co).contains("act:cuongmini"))
        XCTAssertEqual(Set(ids("đổi ngôn ngữ", co).filter { $0.hasPrefix("act:lang-") }), ["act:lang-system", "act:lang-en"],
                       "bỏ lựa chọn đang dùng")
        XCTAssertTrue(ids("english", co).contains("act:lang-en"))
        XCTAssertEqual(ids("đổi dự án", co).first, "act:switch")

        let khong = CTWXepHangTim.lenh(taoThe: false, taoDuAn: false, coDuAn: false, ngonNguHienTai: .en)
        XCTAssertFalse(ids("tao the", khong).contains("act:create"), "không có quyền tạo thẻ ⇒ không có lệnh")
        XCTAssertFalse(ids("cuongmini", khong).contains("act:cuongmini"))
    }
}
