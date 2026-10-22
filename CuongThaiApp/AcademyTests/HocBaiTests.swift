import XCTest
@testable import CuongThaiApp

/// Kiểm logic màn học Academy bằng dữ liệu THẬT của production (cắt gọn, đã bỏ
/// chữ ký URL R2): FER202 bài 649 (video R2 riêng + YouTube), mục lục FER202 khi
/// chưa đăng nhập (R2 bị giấu), gói `?gon=1`, bài DBI202 14171 (slide ⭐ CS1).
final class HocBaiTests: XCTestCase {

    private func doc<T: Decodable>(_ ten: String, _ kieu: T.Type) throws -> T {
        let url = try XCTUnwrap(Bundle(for: HocBaiTests.self).url(forResource: ten, withExtension: "json"),
                                "thiếu tệp mẫu \(ten).json")
        return try JSONDecoder().decode(kieu, from: Data(contentsOf: url))
    }

    // MARK: Giải mã

    func testGiaiMaBaiDayDu649() throws {
        let r = try doc("bai-649", APIResponse<CourseLesson>.self)
        let bai = try XCTUnwrap(r.data)
        XCTAssertEqual(bai.id, 649)
        XCTAssertEqual(bai.sectionId, 258)
        XCTAssertEqual(bai.loai, .video)
        XCTAssertEqual(bai.defaultVideoTrack, "VI")
        XCTAssertEqual(bai.videoTracks?.count, 2)
        XCTAssertEqual(bai.documents?.count, 0)
        XCTAssertEqual(bai.assignments?.count, 0)
        XCTAssertNotNil(bai.content)
    }

    func testGiaiMaMucLucAnDanh() throws {
        let r = try doc("muc-luc-22", DanhSachEnvelope<CourseSection>.self)
        let ds = try XCTUnwrap(r.data)
        XCTAssertEqual(ds.count, 20)
        let vi = try XCTUnwrap(ds[0].lessons?.first?.videoTracks?.first { $0.track == "VI" })
        XCTAssertNil(vi.url, "mục lục phải GIẤU URL R2")
        XCTAssertEqual(vi.locked, true)
    }

    func testGiaiMaKhoaGon() throws {
        let r = try doc("khoa-gon-fer202", APIResponse<CourseDetail>.self)
        let c = try XCTUnwrap(r.data)
        XCTAssertEqual(c.courseCode, "FER202")
        XCTAssertEqual(c.semesterName, "Kỳ 5")
        XCTAssertEqual(c.accessType, "FREE")
        XCTAssertEqual(c.hasPaidAccess, false)
        XCTAssertNotNil(c.sections?.first?.lessons?.first?.documents)
        XCTAssertNil(c.sections?.first?.lessons?.first?.content, "gon=1 không kèm content")
        // `Course(from:)` từng ghi cứng courseCode = nil.
        XCTAssertEqual(Course(from: c).courseCode, "FER202")
        XCTAssertEqual(Course(from: c).semesterName, "Kỳ 5")
    }

    // MARK: Chọn luồng video

    func testUuTienTrackCuaBaiDayDu() throws {
        let day = try XCTUnwrap(try doc("bai-649", APIResponse<CourseLesson>.self).data)
        let muc = try XCTUnwrap(try doc("muc-luc-22", DanhSachEnvelope<CourseSection>.self).data?[0].lessons?[0])
        let ds = ChonLuong.dsO(dayDu: day.videoTracks, mucLuc: muc.videoTracks)
        XCTAssertEqual(ds.map(\.track), ["VI", "EN", "YT"])
        XCTAssertEqual(ds[0].trangThai, .phatDuoc)
        XCTAssertTrue(ds[0].laFileRieng, "VI là file R2 ⇒ AVPlayer")
        XCTAssertEqual(ds[1].trangThai, .khongCo, "EN chưa thu ⇒ ô 'Sắp có'")
        XCTAssertTrue(ds[2].laYouTube)
        XCTAssertEqual(ChonLuong.chon(ds, dangChon: nil, uaThich: nil, macDinh: day.defaultVideoTrack)?.track, "VI")
    }

    func testMucLucBiKhoaThiChoTaiChuKhongBaoKhongCoVideo() throws {
        let muc = try XCTUnwrap(try doc("muc-luc-22", DanhSachEnvelope<CourseSection>.self).data?[0].lessons?[0])
        let ds = ChonLuong.dsO(dayDu: nil, mucLuc: muc.videoTracks)
        XCTAssertEqual(ds[0].trangThai, .dangTai)
        XCTAssertTrue(ds[0].coVideo)
        XCTAssertFalse(ds[0].laFileRieng)
        // Mặc định VI nhưng URL chưa về ⇒ vẫn chọn VI (hiện "Đang tải video…"), không nhảy sang YT.
        XCTAssertEqual(ChonLuong.chon(ds, dangChon: nil, uaThich: nil, macDinh: "VI")?.track, "VI")
    }

    func testThuTuChonLuong() {
        let t = [VideoTrack(track: "VI", url: "https://x.r2.dev/a.mp4", platform: "DIRECT", credit: nil, locked: nil),
                 VideoTrack(track: "YT", url: "https://youtu.be/abcdefg", platform: "EMBED", credit: "Mosh", locked: nil)]
        let ds = ChonLuong.dsO(dayDu: t, mucLuc: nil)
        XCTAssertEqual(ChonLuong.chon(ds, dangChon: "YT", uaThich: "VI", macDinh: "VI")?.track, "YT", "chọn tay thắng")
        XCTAssertEqual(ChonLuong.chon(ds, dangChon: nil, uaThich: "YT", macDinh: "VI")?.track, "YT", "ưa thích dính thắng mặc định")
        XCTAssertEqual(ChonLuong.chon(ds, dangChon: "EN", uaThich: "EN", macDinh: "VI")?.track, "VI", "luồng không có ⇒ bỏ qua")
        XCTAssertEqual(ChonLuong.chon(ds, dangChon: nil, uaThich: nil, macDinh: nil)?.track, "VI")
        XCTAssertNil(ChonLuong.chon(ChonLuong.dsO(dayDu: [], mucLuc: nil), dangChon: nil, uaThich: nil, macDinh: nil))
    }

    func testBaiCuChiCoVideoUrl() {
        let ds = ChonLuong.dsO(dayDu: nil, mucLuc: nil, videoUrlCu: "https://www.youtube.com/watch?v=SqcY0GlETPk")
        XCTAssertEqual(ds.first { $0.coVideo }?.track, "YT")
        XCTAssertEqual(maVideoYouTube("https://youtu.be/SqcY0GlETPk"), "SqcY0GlETPk")
        XCTAssertEqual(maVideoYouTube("https://www.youtube.com/embed/abc123"), "abc123")
        XCTAssertNil(maVideoYouTube("https://media.cuongthai.com/v/a.mp4"))
    }

    // MARK: Slide

    func testRutSlideTuNoiDung() throws {
        let bai = try XCTUnwrap(try doc("bai-14171-slide", APIResponse<CourseLesson>.self).data)
        let ds = DocSlide.tu(bai.content)
        XCTAssertEqual(ds.count, 3)
        XCTAssertEqual(ds[0].bo, "⭐ CS1")
        XCTAssertEqual(ds[0].so, 1)
        XCTAssertEqual(ds[0].tong, 25)
        XCTAssertEqual(ds[0].ten, "Lịch sử và hệ sinh thái CSDL")
        XCTAssertTrue(ds[0].anh.hasSuffix("/DBI202/v1/cs1/001.webp"))
        XCTAssertEqual(ds.map(\.viTri), [0, 1, 2])
        XCTAssertEqual(ds[0].khoaCache, "slide:⭐ CS1:1")
        XCTAssertTrue(ds[0].cauHoi.hasPrefix("Giảng kỹ slide 1/25 của bộ ⭐ CS1"))
    }

    func testSlideDuongLuiAltVaBaiKhongSlide() {
        let html = #"<div class="anh-slide"><img src="https://m/x/002.webp" alt="SWT0 slide 2: ISTQB &amp; you" /></div>"#
        let ds = DocSlide.tu(html)
        XCTAssertEqual(ds.count, 1)
        XCTAssertEqual(ds[0].bo, "SWT0")
        XCTAssertEqual(ds[0].so, 2)
        XCTAssertEqual(ds[0].ten, "ISTQB & you")
        XCTAssertTrue(DocSlide.tu("<p>không có slide</p>").isEmpty)
        XCTAssertTrue(DocSlide.tu(nil).isEmpty)
    }

    // MARK: Tiêu đề song ngữ + loại chương

    func testTachTieuDeSongNgu() {
        let s = "Chapter 3 — JSX & Rendering|||Chương 3 — JSX & Render"
        XCTAssertEqual(SongNgu.tach(s, tiengViet: true).chinh, "Chương 3 — JSX & Render")
        XCTAssertEqual(SongNgu.tach(s, tiengViet: true).phu, "Chapter 3 — JSX & Rendering")
        XCTAssertEqual(SongNgu.tach(s, tiengViet: false).chinh, "Chapter 3 — JSX & Rendering")
        XCTAssertEqual(SongNgu.tach("Final Exam", tiengViet: true).chinh, "Final Exam")
        XCTAssertNil(SongNgu.tach("Final Exam", tiengViet: true).phu)
        XCTAssertEqual(SongNgu.tach("English only|||", tiengViet: true).chinh, "English only", "vế Việt rỗng ⇒ lùi về Anh")
    }

    func testLoaiChuongTuDuLieuThat() throws {
        struct G: Decodable { let titles: [String] }
        let ds = try doc("tieu-de-chuong-swd392", G.self).titles
        let loai = ds.map(LoaiChuong.cua)
        XCTAssertEqual(loai.filter { $0 == .chuyenSau }.count, 1, "chỉ chương ⭐ là Chuyên sâu")
        XCTAssertEqual(loai.last, .thi)
        XCTAssertEqual(loai.first, .thuong)
        XCTAssertEqual(LoaiChuong.cua("📝 PE review — real exams|||📝 Ôn thi PE"), .onThi)
        XCTAssertEqual(LoaiChuong.cua("Progress Test 1 — CLO1–CLO6|||Bài kiểm tra tiến độ 1"), .thi)
    }

    // MARK: Nhịp lưu tiến độ

    func testNhipLuuTienDo() {
        var n = NhipLuuTienDo(chuKy: 15)
        XCTAssertFalse(n.nenLuu(giay: 0.4, bayGio: 0), "chưa tới 1 giây thì không lưu")
        XCTAssertTrue(n.nenLuu(giay: 3, bayGio: 100))
        XCTAssertFalse(n.nenLuu(giay: 10, bayGio: 107), "chưa đủ 15 giây")
        XCTAssertTrue(n.nenLuu(giay: 20, bayGio: 116))
        XCTAssertTrue(n.nenLuu(giay: 25, bayGio: 117, ep: true), "dừng/rời bài ⇒ lưu ngay")
        XCTAssertFalse(n.nenLuu(giay: 25.6, bayGio: 200, ep: true), "mốc không đổi ⇒ khỏi gửi")
        n.datLai()
        XCTAssertTrue(n.nenLuu(giay: 25, bayGio: 201))
    }

    func testMocMoLaiVaNguongXong() {
        let dang = LessonProgress(id: 1, lessonId: 9, isCompleted: false, watchTimeSeconds: 300, lastPositionSeconds: 300)
        XCTAssertEqual(TienDoXem.mocMoLai(dang, thoiLuong: 1000), 300)
        XCTAssertEqual(TienDoXem.mocMoLai(dang, thoiLuong: 305), 0, "sát cuối ⇒ từ đầu")
        let xong = LessonProgress(id: 1, lessonId: 9, isCompleted: true, watchTimeSeconds: 900, lastPositionSeconds: 500)
        XCTAssertEqual(TienDoXem.mocMoLai(xong, thoiLuong: 1000), 0, "bài đã xong xem lại từ đầu")
        XCTAssertEqual(TienDoXem.mocMoLai(nil, thoiLuong: 1000), 0)
        XCTAssertTrue(TienDoXem.duXong(giay: 900, thoiLuong: 1000))
        XCTAssertFalse(TienDoXem.duXong(giay: 899, thoiLuong: 1000))
        XCTAssertFalse(TienDoXem.duXong(giay: 20, thoiLuong: 20), "video quá ngắn/thời lượng chưa biết không tự xong")
        XCTAssertEqual(TienDoXem.dongHo(3725), "1:02:05")
        XCTAssertEqual(TienDoXem.dongHo(65), "1:05")
    }

    // MARK: Bài kế tiếp

    func testBaiTiepTheo() throws {
        let c = try XCTUnwrap(try doc("khoa-gon-fer202", APIResponse<CourseDetail>.self).data)
        let ds = c.sections ?? []
        let tatCa = CayBai.phang(ds)
        // Chưa có quyền: chỉ bài học thử mở được.
        let moThu: (CourseLesson) -> Bool = { $0.isFreePreview == true }
        XCTAssertEqual(CayBai.baiTiep(ds, daXong: [], moDuoc: moThu)?.isFreePreview, true)
        // Có quyền + đã xong 2 bài đầu ⇒ bài thứ 3.
        let xong: Set<Int> = [tatCa[0].id, tatCa[1].id]
        XCTAssertEqual(CayBai.baiTiep(ds, daXong: xong, moDuoc: { _ in true })?.id, tatCa[2].id)
        // Nhảy cóc: đã xong bài 5 ⇒ đưa về sau bài 5, không về bài 1.
        XCTAssertEqual(CayBai.baiTiep(ds, daXong: [tatCa[4].id], moDuoc: { _ in true })?.id, tatCa[5].id)
    }

    // MARK: Tài liệu + API

    func testKieuTaiLieu() {
        func d(_ t: String, _ f: String?) -> TaiLieuBai { TaiLieuBai(id: 1, title: t, fileType: f) }
        XCTAssertEqual(d("De bai.pdf", "application/pdf").kieu, .pdf)
        XCTAssertEqual(d("Slide.pptx", nil).kieu, .office)
        XCTAssertEqual(d("Drive", "link").kieu, .lienKet)
        XCTAssertEqual(d("anh.PNG", nil).kieu, .anh)
        XCTAssertEqual(TaiLieuBai.duoi("x.docx?sig=1"), "docx")
    }

    func testDuongDanHocBaiAPI() {
        XCTAssertEqual(APIEndpoint.hocBai(.khoaGon(slug: "front-end-web-development-with-react")).path,
                       "/api/v1/courses/front-end-web-development-with-react?gon=1")
        XCTAssertEqual(APIEndpoint.hocBai(.cauHoiThuongGap(lessonId: 5, truoc: 77)).path, "/api/v1/courses/lessons/5/ai/asks?truoc=77")
        XCTAssertEqual(APIEndpoint.hocBai(.nopBaiTap(assignmentId: 3, duongDan: "https://g.co", ghiChu: " ")).method, "POST")
        XCTAssertNil(APIEndpoint.hocBai(.nopBaiTap(assignmentId: 3, duongDan: "https://g.co", ghiChu: " ")).body?["notes"])
        XCTAssertEqual(APIEndpoint.hocBai(.baoThoiLuong(lessonId: 1, giay: 61)).body?["seconds"] as? Int, 61)
        XCTAssertEqual(APIEndpoint.getCourses(page: 1, size: 20, keyword: nil).queryParams?["gon"] as? Int, 1)
    }

    func testThanCauHoiGiaSuKemVideoVaAnh() {
        let t = LuongGiaSuBai.than(cauHoi: "q", lichSu: [], tiengAnh: false, khoaCache: nil, lamMoi: false,
                                   quizContext: [], anh: ["a", "b", "c", "d"],
                                   video: BoiCanhVideoHoi(track: "VI", giay: 125))
        XCTAssertEqual(t["phongVideo"] as? Bool, true)
        XCTAssertEqual(t["videoTrack"] as? String, "VI")
        XCTAssertEqual(t["phuDeGiay"] as? Int, 125)
        XCTAssertEqual((t["images"] as? [String])?.count, 3, "tối đa 3 ảnh")
        let k = LuongGiaSuBai.than(cauHoi: "q", lichSu: [], tiengAnh: false, khoaCache: "start", lamMoi: false,
                                   quizContext: [], anh: [], video: nil)
        XCTAssertNil(k["phongVideo"])
        XCTAssertNil(k["images"])
        XCTAssertEqual(k["cacheKey"] as? String, "start")
    }
}
