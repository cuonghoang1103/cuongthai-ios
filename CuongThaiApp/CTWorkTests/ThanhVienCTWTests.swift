import XCTest
@testable import CTWork

/// Thành viên + Tin nhắn riêng (21/10/2026): chữ trạng thái hoạt động, luật riêng tư, thân yêu cầu, giải mã dữ liệu mẫu.
@MainActor
final class ThanhVienCTWTests: XCTestCase {
    private let bayGio = ISO8601DateFormatter().date(from: "2026-10-21T15:00:00Z")!
    private func truoc(_ giay: TimeInterval) -> Date { bayGio.addingTimeInterval(-giay) }
    private var lich: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!; return c }

    override func tearDown() {
        KhoTinNhanCTW.shared.xoaHet()
        super.tearDown()
    }

    // MARK: Chữ "Hoạt động … trước"

    func testPhanLoaiMoc() {
        typealias T = TrangThaiHoatDongCTW
        XCTAssertEqual(T.phanLoai(hien: true, online: true, moc: nil, bayGio: bayGio, lich: lich), .dangHoatDong)
        XCTAssertEqual(T.phanLoai(hien: true, online: false, moc: truoc(30), bayGio: bayGio, lich: lich), .dangHoatDong, "trong ngưỡng 60 s")
        XCTAssertEqual(T.phanLoai(hien: true, online: false, moc: bayGio.addingTimeInterval(120), bayGio: bayGio, lich: lich), .dangHoatDong, "đồng hồ lệch")
        XCTAssertEqual(T.phanLoai(hien: true, online: false, moc: truoc(5 * 60 + 10), bayGio: bayGio, lich: lich), .phut(5))
        XCTAssertEqual(T.phanLoai(hien: true, online: false, moc: truoc(61), bayGio: bayGio, lich: lich), .phut(1))
        XCTAssertEqual(T.phanLoai(hien: true, online: false, moc: truoc(2 * 3600 + 100), bayGio: bayGio, lich: lich), .gio(2))
        XCTAssertEqual(T.phanLoai(hien: true, online: false, moc: truoc(23 * 3600), bayGio: bayGio, lich: lich), .gio(23))
        XCTAssertEqual(T.phanLoai(hien: true, online: false, moc: truoc(26 * 3600), bayGio: bayGio, lich: lich), .homQua)
        XCTAssertEqual(T.phanLoai(hien: true, online: false, moc: truoc(3 * 86400), bayGio: bayGio, lich: lich), .ngay(3))
        XCTAssertEqual(T.phanLoai(hien: true, online: false, moc: truoc(15 * 86400), bayGio: bayGio, lich: lich), .tuan(2))
        XCTAssertEqual(T.phanLoai(hien: true, online: false, moc: truoc(60 * 86400), bayGio: bayGio, lich: lich), .an, "quá lâu ⇒ im như Messenger")
        XCTAssertEqual(T.phanLoai(hien: true, online: false, moc: nil, bayGio: bayGio, lich: lich), .an, "không có mốc ⇒ không đoán")
        XCTAssertEqual(T.phanLoai(hien: false, online: true, moc: truoc(10), bayGio: bayGio, lich: lich), .an)
    }

    func testChuTiengVietVaTiengAnh() {
        let cu = NgonNguCTW.cheDo
        defer { NgonNguCTW.dat(cu) }
        typealias T = TrangThaiHoatDongCTW
        NgonNguCTW.dat(.vi)
        XCTAssertEqual(T.chu(.dangHoatDong), "Đang hoạt động")
        XCTAssertEqual(T.chu(.phut(5)), "Hoạt động 5 phút trước")
        XCTAssertEqual(T.chu(.gio(2)), "Hoạt động 2 giờ trước")
        XCTAssertEqual(T.chu(.homQua), "Hoạt động hôm qua")
        XCTAssertEqual(T.chu(.ngay(3)), "Hoạt động 3 ngày trước")
        XCTAssertEqual(T.chu(.an), "")
        NgonNguCTW.dat(.en)
        XCTAssertEqual(T.chu(.dangHoatDong), "Active now")
        XCTAssertEqual(T.chu(.phut(5)), "Active 5m ago")
        XCTAssertEqual(T.chu(.homQua), "Active yesterday")
    }

    // MARK: Luật riêng tư

    func testLuatRiengTuDoiUng() {
        typealias T = TrangThaiHoatDongCTW
        XCTAssertTrue(T.duocHien(toiBat: true, hoBat: true))
        XCTAssertFalse(T.duocHien(toiBat: true, hoBat: false), "người kia tắt ⇒ ẩn")
        XCTAssertFalse(T.duocHien(toiBat: false, hoBat: true), "TÔI tắt ⇒ cũng không thấy của họ (Messenger)")
        XCTAssertFalse(T.duocHien(toiBat: true, hoBat: true, laAgent: true))
        XCTAssertFalse(T.duocHien(toiBat: true, hoBat: true, daChan: true))
    }

    func testKhoApLuatChoDanhBaVaSocket() throws {
        let kho = KhoTinNhanCTW.shared
        let d = try JSONDecoder().decode(CTWDanhBa.self, from: JSONSerialization.data(withJSONObject: DuLieuGiaThanhVien.danhBa))
        kho.datDanhBa(d)
        let bay = Date()
        XCTAssertEqual(kho.moc(2, bayGio: bay), .dangHoatDong, "máy chủ nói online")
        XCTAssertEqual(kho.moc(3, bayGio: bay), .phut(5))
        XCTAssertEqual(kho.moc(7, bayGio: bay), .an, "người tắt trạng thái (máy chủ đã che)")
        XCTAssertEqual(kho.moc(9, bayGio: bay), .an, "agent không có trạng thái")
        // Socket: vừa rời ⇒ không còn chấm, hiện "1 phút trước" theo mốc rời.
        kho.datSocket(2, online: false, luc: bay.addingTimeInterval(-90))
        XCTAssertEqual(kho.moc(2, bayGio: bay), .phut(1))
        kho.datSocket(3, online: true)
        XCTAssertEqual(kho.moc(3, bayGio: bay), .dangHoatDong)
        // Đang hoạt động lên đầu danh sách.
        XCTAssertEqual(kho.danhBaDaSap(tim: "", bayGio: bay).first?.id, 3)
        XCTAssertEqual(kho.danhBaDaSap(tim: "nguyen").map(\.id), [4], "tìm không dấu, theo tên")
        // TÔI tắt ⇒ không thấy của ai, kể cả từ socket.
        kho.toiHienTrangThai = false
        XCTAssertEqual(kho.moc(3, bayGio: bay), .an)
        XCTAssertEqual(kho.moc(50, mocHoiThoai: DuLieuGia.iso(0), bayGio: bay), .an, "người ngoài danh bạ cũng ẩn")
        kho.toiHienTrangThai = true
        XCTAssertNotEqual(kho.moc(50, mocHoiThoai: DuLieuGia.iso(0, gio: -0.5), bayGio: bay), .an, "ngoài danh bạ: dùng peer.lastActiveAt")
        XCTAssertEqual(kho.moc(51, mocHoiThoai: nil, bayGio: bay), .an, "peer.lastActiveAt null (họ tắt) ⇒ im")
    }

    // MARK: Thân yêu cầu

    func testThanYeuCau() throws {
        let g = TinNhanAPI.thanGui(noiDung: "Chào", tepIds: [], traLoi: nil)
        XCTAssertEqual(g as NSDictionary, ["content": "Chào"] as NSDictionary, "không gửi khoá rỗng")
        let g2 = TinNhanAPI.thanGui(noiDung: "", tepIds: [11, 12], traLoi: 99)
        XCTAssertEqual(g2 as NSDictionary, ["content": "", "fileIds": [11, 12], "parentMessageId": 99] as NSDictionary,
                       "tin chỉ có ảnh vẫn gửi content rỗng")
        let e = TinNhanAPI.gui(threadId: 5, noiDung: "x", tepIds: [], traLoi: nil)
        XCTAssertEqual(e.path, "/api/v1/messages/threads/5/messages")
        XCTAssertEqual(e.method, "POST")

        let b = TinNhanAPI.thanBaoCao(lyDo: "  Spam: bán hàng  ", loai: "spam")
        XCTAssertEqual(b as NSDictionary, ["reason": "Spam: bán hàng", "category": "spam"] as NSDictionary)
        XCTAssertEqual(TinNhanAPI.thanBaoCao(lyDo: "x", loai: "lạ")["category"] as? String, "other", "loại lạ ⇒ other (máy chủ chỉ nhận 5 loại)")
        XCTAssertEqual(TinNhanAPI.baoCao(threadId: 3, lyDo: "x", loai: "hate").path, "/api/v1/messages/threads/3/report")

        XCTAssertEqual(TinNhanAPI.thanTrangThaiHoatDong(false) as NSDictionary, ["showActiveStatus": false] as NSDictionary,
                       "chỉ MỘT trường — không đè hồ sơ")
        let p = TinNhanAPI.datTrangThaiHoatDong(true)
        XCTAssertEqual(p.path, "/api/v1/profile")
        XCTAssertEqual(p.method, "PUT")
        XCTAssertEqual(CTWAPI.thanhVien().path, "/api/v1/work/me/people")
    }

    // MARK: Thu hồi + "Đã xem"

    func testThuHoiVaDaXem() throws {
        let ds = try JSONDecoder().decode([Message].self, from: JSONSerialization.data(withJSONObject: DuLieuGiaThanhVien.tinNhan))
        let cuoi = try XCTUnwrap(ds.last)
        XCTAssertTrue(ChatRiengVM.thuHoiDuoc(cuoi, toi: 1), "tin của tôi, 2 phút trước")
        XCTAssertFalse(ChatRiengVM.thuHoiDuoc(cuoi, toi: 2), "không phải tin của tôi")
        XCTAssertFalse(ChatRiengVM.thuHoiDuoc(ds[1], toi: 1), "quá 5 phút")
        XCTAssertEqual(ChatRiengVM.tinDaXem(ds, toi: 1, hoDocLuc: Date()), cuoi.id)
        XCTAssertEqual(ChatRiengVM.tinDaXem(ds, toi: 1, hoDocLuc: nil), nil)
        let thuHoi = try XCTUnwrap(ds.first { $0.id == 1006 })
        XCTAssertEqual(ChatRiengCTW.tomTat(thuHoi).isEmpty, false)
        let doi = cuoi.doi(camXuc: [MessageReaction(emoji: "❤️", count: 1, userIds: [2])], thuHoi: nil, daXoa: nil)
        XCTAssertEqual(doi.reactions?.first?.emoji, "❤️")
        XCTAssertEqual(doi.content, cuoi.content, "đổi cảm xúc không đụng nội dung")
        XCTAssertEqual(cuoi.doi(camXuc: nil, thuHoi: true, daXoa: nil).content, "")
    }

    // MARK: Giải mã dữ liệu mẫu bằng model thật

    func testGiaiMaDuLieuMau() throws {
        func giai<T: Decodable>(_ k: T.Type, _ p: String) throws -> T {
            let d = DuLieuGia.traLoi(method: "GET", path: "/api/v1" + p, body: [:])
            return try XCTUnwrap(try JSONDecoder().decode(APIResponse<T>.self, from: d).data)
        }
        let db = try giai(CTWDanhBa.self, "/work/me/people")
        XCTAssertEqual(db.people?.count, 7)
        XCTAssertEqual(db.people?.first { $0.id == 9 }?.laAgent, true)
        let t = try giai([MessageThread].self, "/messages/threads")
        XCTAssertEqual(t.count, 6, "1.1: thêm hội thoại GIF (Sara) + tin thoại (Anh Tu) cho ảnh chụp Messenger")
        XCTAssertEqual(t.first { $0.id == 102 }?.unreadCount, 2)
        XCTAssertNotNil(t.first?.peer?.lastActiveAt)
        let m = try giai([Message].self, "/messages/threads/101/messages")
        XCTAssertTrue(m.contains { !$0.anh.isEmpty }, "có tin ảnh")
        XCTAssertTrue(m.contains { !$0.tepKhongPhaiAnh.isEmpty }, "có tin tệp")
        XCTAssertTrue(m.contains { $0.parentMessage != nil }, "có tin trả lời")
        _ = try giai([MocDoc].self, "/messages/threads/101/reads")
        _ = try giai(CTWSoTinNhanChuaDoc.self, "/messages/unread-count")
    }

    // MARK: Đăng ký mô-đun

    func testMoDunCapUngDung() {
        let ids = CTWDangKyMoDun.capUngDung.map(\.id)
        XCTAssertEqual(ids, ["tin-nhan", "thanh-vien"])
        XCTAssertFalse(CTWDangKyMoDun.hienDuoc(nil).contains { $0.capUngDung }, "không lọt vào trang dự án / More tools")
        XCTAssertEqual(CTWDangKyMoDun.moDun("tin-nhan")?.tabIPhone, "chat")
        XCTAssertNotNil(CTWDangKyMoDun.moDun("chat")?.manTabIPhone, "tab Chat iPhone = Kênh · Tin nhắn · Thành viên")
    }
}
