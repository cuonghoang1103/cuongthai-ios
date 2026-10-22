import XCTest
@testable import CuongThaiApp

/// Chương trình đào tạo (22/10/2026): giải mã khoan dung đúng hình dạng backend
/// (`dongGoiMonChuongTrinh` / `xepChuongTrinh` / `nhomSapRaMat`), nhóm theo chuyên ngành,
/// tìm không dấu, luật App Store 3.1.1, đường lùi khi endpoint 404.
@MainActor
final class ChuongTrinhTests: XCTestCase {

    // MARK: Dữ liệu mẫu — đúng hình dạng `GET /courses/chuong-trinh`

    /// Kỳ 1 có MỘT khoá hỏng (thiếu slug) và một khoá có `id` là object ⇒ phải bị bỏ, phần còn lại giữ.
    /// Thêm: số dạng chuỗi (Decimal), trường lạ, `progress` null, kỳ có `mon` không phải mảng.
    static let mau = #"""
    {"success":true,"data":{
      "nam":[
        {"so":2,"ten":"Cốt lõi","tenEn":"Core","moTa":"Viết backend.","moTaEn":"Build backends.","ky":[
          {"so":4,"nam":2,"ten":"Backend căn bản","tenEn":"Backend fundamentals","moTa":"REST API.","moTaEn":"REST APIs.","mon":"hỏng"}
        ]},
        {"so":1,"ten":"Nền tảng","tenEn":"Foundations","moTa":"Làm quen công cụ.","moTaEn":"Tools.","truongLa":42,"ky":[
          {"so":1,"nam":1,"ten":"Nhập môn & công cụ","tenEn":"Introduction & toolkit","moTa":"Git, Linux.","moTaEn":"Git, Linux.","mon":[
            {"id":11,"slug":"web-foundations","title":"Web Foundations|||Nền tảng Lập trình Web","courseCode":null,
             "shortDescription":"Build pages.|||Dựng trang.","thumbnailUrl":"https://x/a.png","price":"0","discountPrice":null,
             "isFree":true,"level":"BEGINNER","language":"Vietnamese","totalLessons":"42","totalDurationSeconds":7200,
             "totalStudents":3,"avgRating":"4.5","totalReviews":0,"categoryName":"Frontend","categorySlug":"frontend",
             "loTrinhKy":1,"loTrinhThuTu":1,"isEnrolled":true,"progress":100,"sapRaMat":false,"moiThem":"bỏ qua"},
            {"id":12,"title":"Không có slug","loTrinhKy":1},
            {"id":{"x":1},"slug":"id-hong"},
            {"id":13,"slug":"linux-bash","title":"Linux & Bash","isFree":true,"level":"BEGINNER","totalLessons":30,
             "totalDurationSeconds":0,"categoryName":"DevOps & Vận hành","categorySlug":"devops",
             "loTrinhKy":1,"loTrinhThuTu":2,"isEnrolled":true,"progress":35,"sapRaMat":false},
            {"id":14,"slug":"git","title":"Git & GitHub","isFree":true,"level":"BEGINNER","totalLessons":20,
             "totalDurationSeconds":1800,"categoryName":"DevOps & Vận hành","categorySlug":"devops",
             "loTrinhKy":1,"loTrinhThuTu":3,"isEnrolled":false,"progress":null},
            {"id":15,"slug":"khoa-tra-phi","title":"Khoá trả phí","isFree":false,"price":499000,"level":"ADVANCED",
             "loTrinhKy":1,"loTrinhThuTu":4,"isEnrolled":false}
          ]},
          {"so":2,"nam":1,"ten":"Ngôn ngữ","tenEn":"Languages","mon":[
            {"id":21,"slug":"typescript","title":"TypeScript","isFree":true,"level":"INTERMEDIATE","totalLessons":50,
             "categoryName":"Ngôn ngữ lập trình","categorySlug":"languages","loTrinhKy":2,"loTrinhThuTu":1}
          ]}
        ]}
      ],
      "chuaXep":[
        {"id":31,"slug":"huong-dan-ct-work","title":"CT Work Tutorial","isFree":true,"level":"BEGINNER",
         "totalLessons":12,"totalDurationSeconds":1979,"categoryName":"Nghề nghiệp","categorySlug":"career",
         "loTrinhKy":null,"loTrinhThuTu":null}
      ],
      "sapRaMat":[
        {"ma":"mobile","ten":"Mobile","tenEn":"Mobile","mon":[
          {"id":41,"slug":"ios-swift-swiftui","title":"iOS & iPadOS|||iOS & iPadOS với SwiftUI","isFree":true,
           "level":"BEGINNER","totalLessons":0,"categoryName":"Frontend","categorySlug":"frontend",
           "sapRaMat":true,"soChuongDuKien":17,"soBaiDuKien":"117"},
          {"slug":"thieu-id"}
        ]},
        {"ten":"Nhóm thiếu mã","mon":[{"id":42,"slug":"golang","title":"Go","categorySlug":"backend","categoryName":"Backend"}]}
      ],
      "tong":{"khoa":7,"bai":166,"gio":3,"sapRaMat":2}
    }}
    """#

    private func mauDaGiai() throws -> ChuongTrinhDaoTao {
        try ChuongTrinhDaoTao.giai(Data(Self.mau.utf8))
    }

    // MARK: Giải mã

    func testGiaiDungHinhDangVaBoPhanTuHong() throws {
        let ct = try mauDaGiai()
        XCTAssertEqual(ct.nguon, .chuongTrinh)
        XCTAssertTrue(ct.coLoTrinh)
        XCTAssertEqual(ct.nam.map(\.so), [1, 2], "năm phải xếp theo số, kể cả khi máy chủ gửi lệch")
        let ky1 = try XCTUnwrap(ct.nam.first?.ky.first)
        XCTAssertEqual(ky1.mon.map(\.slug), ["web-foundations", "linux-bash", "git", "khoa-tra-phi"],
                       "khoá thiếu slug / id hỏng bị bỏ, khoá còn lại giữ nguyên thứ tự")
        let web = ky1.mon[0]
        XCTAssertEqual(web.totalLessons, 42, "số dạng chuỗi (Decimal) vẫn đọc được")
        XCTAssertEqual(web.price, 0)
        XCTAssertEqual(web.progress, 100)
        XCTAssertEqual(web.ten(false), "Nền tảng Lập trình Web")
        XCTAssertEqual(web.ten(true), "Web Foundations")
        XCTAssertNil(ky1.mon[2].progress)
        // Kỳ có `mon` không phải mảng: kỳ vẫn còn (khung chương trình không mất), chỉ rỗng.
        let ky4 = try XCTUnwrap(ct.nam.last?.ky.first)
        XCTAssertEqual(ky4.so, 4)
        XCTAssertTrue(ky4.mon.isEmpty)
        XCTAssertEqual(ky4.tenHien(true), "Backend fundamentals")
        XCTAssertEqual(ct.nam[0].tenHien(false), "Nền tảng")
    }

    func testSapRaMatNhomVaCo() throws {
        let ct = try mauDaGiai()
        XCTAssertEqual(ct.sapRaMat.map(\.ma), ["mobile", "Nhóm thiếu mã"], "thiếu `ma` ⇒ lấy tên làm khoá")
        XCTAssertEqual(ct.sapRaMat[0].mon.map(\.slug), ["ios-swift-swiftui"], "phần tử thiếu id bị bỏ")
        let ios = ct.sapRaMat[0].mon[0]
        XCTAssertTrue(ios.laSapRaMat)
        XCTAssertEqual(ios.soBaiDuKien, 117)
        XCTAssertTrue(ct.sapRaMat[1].mon[0].laSapRaMat, "trong nhóm Sắp ra mắt ⇒ luôn là Sắp ra mắt, kể cả thiếu cờ")
    }

    func testKhongCoGiDungDuocThiNem() {
        XCTAssertThrowsError(try ChuongTrinhDaoTao.giai(Data(#"{"success":false,"message":"Course not found"}"#.utf8)))
        XCTAssertThrowsError(try ChuongTrinhDaoTao.giai(Data(#"{"success":true,"data":{"nam":[],"chuaXep":[]}}"#.utf8)))
        XCTAssertThrowsError(try ChuongTrinhDaoTao.giai(Data("không phải json".utf8)))
    }

    // MARK: Luật App Store 3.1.1

    func testAnKhoaTraPhiChuaSoHuu() throws {
        let ct = try mauDaGiai().locHienDuoc()
        XCTAssertFalse(ct.monHocDuoc.contains { $0.slug == "khoa-tra-phi" })
        XCTAssertEqual(ct.chuaXep.count, 1, "Khoá mới không bao giờ bị giấu (miễn phí)")
        var traPhiDaMua = MonChuongTrinh(id: 1, slug: "a", isFree: false, isEnrolled: true)
        XCTAssertTrue(traPhiDaMua.hienDuoc)
        traPhiDaMua.isEnrolled = false
        XCTAssertFalse(traPhiDaMua.hienDuoc)
        XCTAssertTrue(MonChuongTrinh(id: 2, slug: "b", isFree: nil).hienDuoc, "thiếu isFree ⇒ coi như miễn phí")
        XCTAssertTrue(MonChuongTrinh(id: 3, slug: "c", isFree: false, sapRaMat: true).hienDuoc)
    }

    func testTongTinhTuKhoaDangHien() throws {
        let t = try mauDaGiai().locHienDuoc().tong
        XCTAssertEqual(t.khoa, 5)           // web, linux, git, typescript, ct-work
        XCTAssertEqual(t.ky, 3)
        XCTAssertEqual(t.bai, 42 + 30 + 20 + 50 + 12)
        XCTAssertEqual(t.gio, 3)            // 7200 + 1800 + 1979 giây ≈ 3,0 giờ
        XCTAssertEqual(t.sapRaMat, 2)
    }

    // MARK: Kỳ hiện tại

    func testKyHienTai() throws {
        let ct = try mauDaGiai().locHienDuoc()
        XCTAssertEqual(ct.kyHienTai?.ky.so, 1)
        XCTAssertEqual(ct.kyHienTai?.dangHoc, true, "linux-bash 35% ⇒ đang học kỳ 1")
        XCTAssertEqual(ct.dangHoc.map(\.slug), ["linux-bash"])

        // Chưa đăng nhập ⇒ Kỳ 1, không phải "đang học".
        let k1 = KyHocCT(so: 1, mon: [MonChuongTrinh(id: 1, slug: "a")])
        let k2 = KyHocCT(so: 2, mon: [MonChuongTrinh(id: 2, slug: "b")])
        let moi = ChuongTrinhDaoTao(nam: [NamHocCT(so: 1, ky: [k1, k2])], chuaXep: [], sapRaMat: [], nguon: .chuongTrinh)
        XCTAssertEqual(moi.kyHienTai?.ky.so, 1)
        XCTAssertEqual(moi.kyHienTai?.dangHoc, false)

        // Học xong trọn kỳ 1 ⇒ kỳ tiếp theo là 2.
        let xong = KyHocCT(so: 1, mon: [MonChuongTrinh(id: 1, slug: "a", isEnrolled: true, progress: 100)])
        let tiep = ChuongTrinhDaoTao(nam: [NamHocCT(so: 1, ky: [xong, k2])], chuaXep: [], sapRaMat: [], nguon: .chuongTrinh)
        XCTAssertEqual(tiep.kyHienTai?.ky.so, 2)
        XCTAssertEqual(tiep.kyHienTai?.dangHoc, false)
    }

    // MARK: Chuyên ngành

    func testNhomTheoChuyenNganh() throws {
        let ct = try mauDaGiai().locHienDuoc()
        let nhom = ct.nhomTheoNganh(ct.tatCaMon)
        // devops 2, frontend 2 (web + ios sắp ra mắt) ⇒ hoà số ⇒ theo tên.
        XCTAssertEqual(nhom.map(\.nganh.slug).prefix(2), ["devops", "frontend"])
        let fe = try XCTUnwrap(nhom.first { $0.nganh.slug == "frontend" })
        XCTAssertEqual(fe.mon.map(\.slug), ["web-foundations", "ios-swift-swiftui"], "khoá trong kỳ trước, Sắp ra mắt cuối")
        let devops = try XCTUnwrap(nhom.first { $0.nganh.slug == "devops" })
        XCTAssertEqual(devops.mon.map(\.slug), ["linux-bash", "git"], "theo thứ tự trong kỳ")
        XCTAssertEqual(Set(nhom.flatMap { $0.mon.map(\.id) }).count, ct.tatCaMon.count, "không khoá nào rơi mất")

        // Khoá không danh mục ⇒ nhóm "Khác" (slug rỗng).
        let le = ChuongTrinhDaoTao.tuDanhSach([MonChuongTrinh(id: 9, slug: "le")])
        XCTAssertEqual(le.cacNganh().first?.slug, "")
        XCTAssertFalse(le.cacNganh().first?.tenHien.isEmpty ?? true)
    }

    // MARK: Tìm + lọc

    func testTimKhongDauTiengViet() throws {
        let ct = try mauDaGiai()
        let tim = { (q: String) in ct.tatCaMon.filter { BoLocCT.khopTuKhoa($0, q) }.map(\.slug) }
        XCTAssertEqual(tim("nen tang lap trinh"), ["web-foundations"], "không dấu khớp có dấu")
        XCTAssertEqual(tim("NỀN TẢNG"), ["web-foundations"])
        XCTAssertEqual(tim("web foundations"), ["web-foundations"], "khớp cả nửa tiếng Anh")
        XCTAssertEqual(tim("van hanh git"), ["git"], "MỌI từ phải có mặt; 'đ'/dấu được bỏ")
        XCTAssertTrue(tim("dung trang").contains("web-foundations"), "tìm cả trong mô tả")
        XCTAssertEqual(tim("swiftui"), ["ios-swift-swiftui"])
        XCTAssertEqual(tim("huong dan ct"), ["huong-dan-ct-work"], "slug có gạch ngang vẫn khớp từng từ")
        XCTAssertEqual(tim("   ").count, ct.tatCaMon.count)
        XCTAssertTrue(tim("zzzqqq").isEmpty)
        XCTAssertTrue(BoLocCT.khopTuKhoa(MonChuongTrinh(id: 1, slug: "x", title: "Đóng gói Docker"), "dong goi"))
    }

    func testLocCapDoVaChuyenNganh() throws {
        let ct = try mauDaGiai()
        var loc = BoLocCT(capDo: .trungCap)
        XCTAssertEqual(ct.tatCaMon.filter { loc.khop($0) }.map(\.slug), ["typescript"])
        loc = BoLocCT(nganh: "devops")
        XCTAssertEqual(ct.tatCaMon.filter { loc.khop($0) }.map(\.slug), ["linux-bash", "git"])
        XCTAssertEqual(ct.tatCaMon.filter { loc.khop($0, boQuaNganh: true) }.count, ct.tatCaMon.count,
                       "chế độ Lộ trình bỏ qua lọc chuyên ngành")
        XCTAssertTrue(loc.coLoc)
        XCTAssertFalse(BoLocCT().coLoc)
    }

    // MARK: Đường lùi khi endpoint chưa có (404)

    static let danhSachProd = #"""
    {"success":true,"data":[
      {"id":649,"slug":"huong-dan-ct-work","title":"CT Work Tutorial","courseCode":null,"price":0,"isFree":true,
       "level":"BEGINNER","status":"PUBLISHED","totalLessons":12,"totalDurationSeconds":1979,"categoryName":"Nghề nghiệp",
       "categorySlug":"career","totalStudents":0,"isEnrolled":null,"createdAt":"2026-10-17T12:28:55.852Z"},
      {"id":650,"slug":"react","title":"React","price":"0","isFree":true,"level":"INTERMEDIATE","totalLessons":"80",
       "categoryName":"Frontend","categorySlug":"frontend"},
      {"id":"hỏng"},
      {"id":651,"slug":"khoa-tra-phi","title":"Pro","price":199000,"isFree":false,"categorySlug":"backend"},
      {"id":650,"slug":"react","title":"React (trùng)"}
    ],"pagination":{"page":1,"limit":100,"total":4,"totalPages":1}}
    """#

    func testDuPhongTuDanhSach() throws {
        let trang = try ChuongTrinhDaoTao.giaiTrangDanhSach(Data(Self.danhSachProd.utf8))
        XCTAssertEqual(trang.soTrang, 1)
        XCTAssertEqual(trang.mon.count, 4, "phần tử hỏng bị bỏ")
        let ct = ChuongTrinhDaoTao.tuDanhSach(trang.mon).locHienDuoc()
        XCTAssertEqual(ct.nguon, .danhSach)
        XCTAssertFalse(ct.coLoTrinh)
        XCTAssertTrue(ct.nam.isEmpty)
        XCTAssertEqual(ct.chuaXep.map(\.slug), ["huong-dan-ct-work", "react"], "trùng id bị gộp, trả phí bị ẩn")
        XCTAssertEqual(ct.tong.bai, 92)
        XCTAssertEqual(ct.cacNganh().map(\.slug).sorted(), ["career", "frontend"])
        XCTAssertNil(ct.kyHienTai)
    }

    func testVMLuiVeDanhSachKhi404() async throws {
        var soLanGoiDanhSach = 0
        let vm = ChuongTrinhDaoTaoVM(nguon: NguonChuongTrinh(
            // Đúng thứ prod trả hôm nay: 404 rơi vào `/:slug`.
            chuongTrinh: { throw APIError.serverError("Course not found") },
            trangDanhSach: { trang in
                soLanGoiDanhSach += 1
                XCTAssertEqual(trang, 1)
                return Data(Self.danhSachProd.utf8)
            },
        ))
        await vm.tai()
        XCTAssertNil(vm.loi, "đường lùi chạy được ⇒ KHÔNG có màn lỗi")
        XCTAssertEqual(vm.duLieu?.nguon, .danhSach)
        XCTAssertEqual(vm.duLieu?.chuaXep.count, 2)
        XCTAssertEqual(soLanGoiDanhSach, 1)
    }

    func testVMDungChuongTrinhKhiCo() async {
        let vm = ChuongTrinhDaoTaoVM(nguon: NguonChuongTrinh(
            chuongTrinh: { Data(Self.mau.utf8) },
            trangDanhSach: { _ in XCTFail("có chương trình thì không gọi đường lùi"); return Data() },
        ))
        await vm.tai()
        XCTAssertEqual(vm.duLieu?.nguon, .chuongTrinh)
        XCTAssertEqual(vm.duLieu?.tatCaKy.count, 3)
        XCTAssertFalse(vm.duLieu?.monHocDuoc.contains { $0.slug == "khoa-tra-phi" } ?? true)
    }

    func testVMCaHaiHongThiBaoLoi() async {
        let vm = ChuongTrinhDaoTaoVM(nguon: NguonChuongTrinh(
            chuongTrinh: { throw URLError(.notConnectedToInternet) },
            trangDanhSach: { _ in throw URLError(.notConnectedToInternet) },
        ))
        await vm.tai()
        XCTAssertNil(vm.duLieu)
        XCTAssertNotNil(vm.loi)
    }

    func testVMHuyKhongLuiVaKhongBaoLoi() async {
        let vm = ChuongTrinhDaoTaoVM(nguon: NguonChuongTrinh(
            chuongTrinh: { throw URLError(.cancelled) },
            trangDanhSach: { _ in XCTFail("huỷ (kéo làm mới bị cắt) không được chạy đường lùi"); return Data() },
        ))
        await vm.tai()
        XCTAssertNil(vm.loi)
        XCTAssertNil(vm.duLieu)
    }

    // MARK: Chữ

    func testDinhGioVaSo() {
        XCTAssertEqual(ChuCT.gio(0, false), "")
        XCTAssertEqual(ChuCT.gio(59, false), "")
        XCTAssertEqual(ChuCT.gio(45 * 60, false), "45 phút")
        XCTAssertEqual(ChuCT.gio(11_520, false), "3,2 giờ")
        XCTAssertEqual(ChuCT.gio(11_520, true), "3.2 h")
        XCTAssertEqual(ChuCT.gio(7200, false), "2 giờ")
        XCTAssertEqual(ChuCT.so(4782, false), "4.782")
        XCTAssertEqual(ChuCT.so(4782, true), "4,782")
        XCTAssertEqual(ChuCT.khoa(1, true), "1 course")
        XCTAssertEqual(ChuCT.khoa(5, false), "5 khoá")
        XCTAssertEqual(ChuCT.nam(4, false), "Năm thứ tư")
        XCTAssertEqual(ChuCT.nam(1, true), "Year one")
        XCTAssertEqual(CapDoCT.nhan("ADVANCED"), CapDoCT.nangCao.ten)
    }

    func testKhungSapRaMatKhoanDung() throws {
        let json = #"""
        {"success":true,"data":{"id":41,"slug":"ios-swift-swiftui","title":"iOS|||iOS với SwiftUI","comingSoon":true,
         "isEnrolled":false,"level":42,"soChuongDuKien":2,"soBaiDuKien":"3","sections":[
          {"id":1,"title":"Section 0|||Mục 0","lessonCount":2,"lessons":[{"id":10,"title":"A|||Á"},{"id":11,"title":"B"}]},
          {"id":"hỏng"},
          {"id":2,"title":"Section 1","lessons":[{"id":12,"title":"C"}]}
         ]}}
        """#
        let v = try JSONDecoder().decode(APIResponse<KhungKhoaSapRaMat>.self, from: Data(json.utf8))
        let k = try XCTUnwrap(v.data)
        XCTAssertNil(k.level, "trường sai kiểu ⇒ nil, không làm hỏng cả trang")
        XCTAssertEqual(k.dsChuong.map(\.id), [1, 2])
        XCTAssertEqual(k.dsChuong[0].soBai, 2)
        XCTAssertEqual(k.dsChuong[1].soBai, 1)
        XCTAssertEqual(k.soBaiDuKien?.int, 3)
        XCTAssertFalse(k.daMo)
    }
}
