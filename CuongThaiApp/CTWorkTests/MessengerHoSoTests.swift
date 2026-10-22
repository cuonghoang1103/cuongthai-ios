import XCTest
@testable import CTWork

/// Hồ sơ + Tin nhắn kiểu Messenger (bản 1.1 — 22/10/2026). Logic THUẦN ở `Modules/ThanhVien/TinNhanLogicCTW.swift`:
/// gom nhóm + mốc thời gian, giờ ngắn, cảm xúc, trích dẫn trả lời, emoji lớn/link, trang GIF, thân yêu cầu hồ sơ,
/// chuyển tiếp, sắp hội thoại, cắt ảnh; giải mã dữ liệu mẫu (đúng hình dạng máy chủ).
final class MessengerHoSoTests: XCTestCase {
    private let goc = Date(timeIntervalSince1970: 1_792_000_000)   // một thời điểm cố định
    private var lich: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!; return c }

    private func muc(_ nguoi: Int, _ phut: Double, rieng: Bool = false) -> NhomTinCTW.Muc {
        NhomTinCTW.Muc(nguoi: nguoi, luc: goc.addingTimeInterval(phut * 60), dungRieng: rieng)
    }

    // MARK: Gom nhóm + mốc

    func testGomNhomTheoNguoiVaThoiGian() {
        let ds = [muc(2, 0), muc(2, 1), muc(2, 2.5), muc(1, 3), muc(1, 10), muc(2, 11)]
        let b = NhomTinCTW.boCuc(ds, lich: lich)
        XCTAssertEqual(b.map(\.viTri), [.dau, .giua, .cuoi, .don, .don, .don],
                       "3 tin liền của 2 (≤ 3 phút) thành nhóm; tin của 1 cách 7 phút ⇒ hai nhóm đơn")
        XCTAssertEqual(b.map(\.mocThoiGian), [true, false, false, false, false, false], "mốc CHỈ ở tin đầu (không cách > 1 giờ)")
        XCTAssertTrue(NhomTinCTW.hienAvatar(b[2], cuaToi: false), "avatar ở tin CUỐI nhóm")
        XCTAssertFalse(NhomTinCTW.hienAvatar(b[0], cuaToi: false))
        XCTAssertFalse(NhomTinCTW.hienAvatar(b[3], cuaToi: true), "tin của tôi không có avatar")
    }

    func testMocKhiCachHonMotGioHoacKhacNgay() {
        let ds = [muc(2, 0), muc(2, 59), muc(2, 59 + 61)]
        let b = NhomTinCTW.boCuc(ds, lich: lich)
        XCTAssertEqual(b.map(\.mocThoiGian), [true, false, true], "cách 61 phút ⇒ mốc mới")
        XCTAssertEqual(b[2].viTri, .don, "có mốc ⇒ không nối nhóm qua mốc")
        // Khác ngày dù chỉ cách vài phút.
        var c = lich
        c.timeZone = TimeZone(identifier: "UTC")!
        let dem = c.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 23, minute: 59))!
        let b2 = NhomTinCTW.boCuc([NhomTinCTW.Muc(nguoi: 1, luc: dem), NhomTinCTW.Muc(nguoi: 1, luc: dem.addingTimeInterval(120))], lich: c)
        XCTAssertEqual(b2.map(\.mocThoiGian), [true, true])
    }

    func testTinDungRiengKhongNoiNhom() {
        let b = NhomTinCTW.boCuc([muc(1, 0), muc(1, 0.5, rieng: true), muc(1, 1)], lich: lich)
        XCTAssertEqual(b.map(\.viTri), [.don, .don, .don], "nhãn dán / emoji lớn / thu hồi đứng riêng")
    }

    func testGocBongTheoViTri() {
        let dau = GocBongCTW.cho(.dau, cuaToi: true)
        XCTAssertEqual(dau.trenPhai, GocBongCTW.lon)
        XCTAssertEqual(dau.duoiPhai, GocBongCTW.nho, "tin đầu nhóm của tôi: góc dưới-phải nối tin sau")
        XCTAssertEqual(dau.trenTrai, GocBongCTW.lon)
        let giua = GocBongCTW.cho(.giua, cuaToi: false)
        XCTAssertEqual([giua.trenTrai, giua.duoiTrai], [GocBongCTW.nho, GocBongCTW.nho], "người kia: góc TRÁI nối")
        XCTAssertEqual([giua.trenPhai, giua.duoiPhai], [GocBongCTW.lon, GocBongCTW.lon])
        let don = GocBongCTW.cho(.don, cuaToi: false)
        XCTAssertEqual(Set([don.trenTrai, don.trenPhai, don.duoiTrai, don.duoiPhai]), [GocBongCTW.lon])
    }

    // MARK: Giờ ngắn

    func testThoiGianNganPhanLoai() {
        let bay = goc
        XCTAssertEqual(ThoiGianNganCTW.phanLoai(bay.addingTimeInterval(-20), bayGio: bay, lich: lich), .vuaXong)
        XCTAssertEqual(ThoiGianNganCTW.phanLoai(bay.addingTimeInterval(-2 * 60), bayGio: bay, lich: lich), .phut(2))
        XCTAssertEqual(ThoiGianNganCTW.phanLoai(bay.addingTimeInterval(-3 * 3600 - 10), bayGio: bay, lich: lich), .gio(3))
        let haiNgay = bay.addingTimeInterval(-2 * 86400)
        XCTAssertEqual(ThoiGianNganCTW.phanLoai(haiNgay, bayGio: bay, lich: lich), .thu(lich.component(.weekday, from: haiNgay)))
        let muoiNgay = bay.addingTimeInterval(-10 * 86400)
        if lich.component(.year, from: muoiNgay) == lich.component(.year, from: bay) {
            XCTAssertEqual(ThoiGianNganCTW.phanLoai(muoiNgay, bayGio: bay, lich: lich), .ngay(muoiNgay))
        }
        let namTruoc = bay.addingTimeInterval(-400 * 86400)
        XCTAssertEqual(ThoiGianNganCTW.phanLoai(namTruoc, bayGio: bay, lich: lich), .ngayNam(namTruoc))
    }

    func testThoiGianNganChuTiengViet() {
        XCTAssertEqual(ThoiGianNganCTW.thu(4).chu(viet: true), "Thứ 4")
        XCTAssertEqual(ThoiGianNganCTW.thu(1).chu(viet: true), "CN")
        XCTAssertEqual(ThoiGianNganCTW.thu(4).chu(viet: false), "Wed")
        XCTAssertFalse(ThoiGianNganCTW.phut(2).chu().isEmpty)
    }

    func testNhanMoc() {
        let bay = Date()
        let h = NhanMocCTW.chuoi(bay.addingTimeInterval(-60), bayGio: bay)
        XCTAssertEqual(h, CTWDinhDang.gio(bay.addingTimeInterval(-60)), "hôm nay ⇒ chỉ giờ")
        let hq = Calendar.current.date(byAdding: .day, value: -1, to: bay)!
        XCTAssertTrue(NhanMocCTW.chuoi(hq, bayGio: bay).contains(CTWDinhDang.gio(hq)))
        XCTAssertNotEqual(NhanMocCTW.chuoi(hq, bayGio: bay), CTWDinhDang.gio(hq), "hôm qua có chữ 'Hôm qua'")
    }

    // MARK: Cảm xúc

    func testDaoCamXuc() {
        var ds: [MessageReaction] = []
        ds = CamXucCTW.dao(ds, emoji: "❤️", toi: 1)
        XCTAssertEqual(ds.first?.userIds, [1])
        ds = CamXucCTW.dao(ds, emoji: "❤️", toi: 2)
        XCTAssertEqual(ds.first?.count, 2)
        XCTAssertEqual(CamXucCTW.cuaToi(ds, toi: 1), ["❤️"])
        ds = CamXucCTW.dao(ds, emoji: "❤️", toi: 1)
        XCTAssertEqual(ds.first?.userIds, [2], "chạm lần hai ⇒ gỡ cảm xúc của tôi")
        ds = CamXucCTW.dao(ds, emoji: "❤️", toi: 2)
        XCTAssertTrue(ds.isEmpty, "không còn ai ⇒ bỏ hẳn loại đó")
        ds = CamXucCTW.dao(CamXucCTW.dao(CamXucCTW.dao([], emoji: "😂", toi: 1), emoji: "👍", toi: 1), emoji: "👍", toi: 3)
        let v = CamXucCTW.vien(ds)
        XCTAssertEqual(v.emoji.first, "👍", "viên xếp theo số nhiều nhất")
        XCTAssertEqual(v.tong, 3)
        XCTAssertEqual(CamXucCTW.nhanh.count, 6)
    }

    // MARK: Trả lời / tóm tắt / emoji lớn / link

    private func tin(_ id: Int, _ tu: Int, _ chu: String = "", media: (String, String)? = nil, at: [MessageAttachment] = [],
                     thuHoi: Bool = false, cha: MessageParent? = nil, phut: Double = 1) -> Message {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return Message(id: id, threadId: 101, senderId: tu, sender: nil, content: chu, mediaUrl: media?.0, mediaKind: media?.1,
                       deleted: false, recalled: thuHoi, createdAt: f.string(from: Date().addingTimeInterval(-phut * 60)),
                       attachments: at, parentMessageId: cha?.id, parentMessage: cha, hasAttachment: nil, reactions: nil)
    }

    func testTrichDanTraLoi() {
        let cha = MessageParent(id: 9, senderId: 2, senderName: "Linh Tran", content: "Xem flow OTP giúp chị")
        let t = TrichDanCTW.tu(cha, toi: 1, tenKia: "Linh")
        XCTAssertEqual(t.ten, "Linh Tran")
        XCTAssertFalse(t.cuaToi)
        XCTAssertEqual(t.chu, "Xem flow OTP giúp chị")
        let cuaToi = TrichDanCTW.tu(MessageParent(id: 9, senderId: 1, senderName: "Alex", content: ""), toi: 1, tenKia: "Linh")
        XCTAssertTrue(cuaToi.cuaToi)
        XCTAssertEqual(cuaToi.chu, String(localized: "Attachment"), "tin gốc không chữ ⇒ 'Tệp đính kèm'")
        let soan = TrichDanCTW.tuTin(tin(3, 2, "", media: ("https://x/a.gif", "gif")), toi: 1, tenKia: "Linh")
        XCTAssertEqual(soan.chu, String(localized: "🎬 GIF"))
        XCTAssertNotEqual(t.nhanTraLoi(nguoiTraLoiLaToi: true, tenKia: "Linh"), t.nhanTraLoi(nguoiTraLoiLaToi: false, tenKia: "Linh"))
    }

    func testTomTatTheoLoai() {
        let thoai = MessageAttachment(id: 1, fileId: 1, mimeType: "audio/mp4", fileName: "v.m4a", fileSize: 1, url: "https://x/v.m4a", thumbnailUrl: nil)
        let pdf = MessageAttachment(id: 2, fileId: 2, mimeType: "application/pdf", fileName: "a.pdf", fileSize: 1, url: "https://x/a.pdf", thumbnailUrl: nil)
        XCTAssertEqual(TomTatTinCTW.chu(tin(1, 1, at: [thoai])), String(localized: "🎤 Voice message"))
        XCTAssertEqual(TomTatTinCTW.chu(tin(1, 1, at: [pdf])), String(localized: "📎 File"))
        XCTAssertEqual(TomTatTinCTW.chu(tin(1, 1, media: ("https://x/s.png", "sticker"))), String(localized: "🪄 Sticker"))
        XCTAssertEqual(TomTatTinCTW.chu(tin(1, 1, "chào", thuHoi: true)), String(localized: "Message unsent"))
        XCTAssertEqual(TomTatTinCTW.amThanh(tin(1, 1, at: [thoai, pdf])).count, 1)
        XCTAssertEqual(TomTatTinCTW.tepKhac(tin(1, 1, at: [thoai, pdf])).map(\.id), [2], "tệp thoại không hiện thành thẻ tệp")
    }

    func testEmojiLon() {
        XCTAssertTrue(EmojiLonCTW.la("👍"))
        XCTAssertTrue(EmojiLonCTW.la("❤️🔥 🚀"))
        XCTAssertTrue(EmojiLonCTW.la("👩‍💻"), "chuỗi ZWJ là MỘT emoji")
        XCTAssertFalse(EmojiLonCTW.la("👍👍👍👍"), "quá 3")
        XCTAssertFalse(EmojiLonCTW.la("ok 👍"))
        XCTAssertFalse(EmojiLonCTW.la("1"), "chữ số không phải emoji")
        XCTAssertFalse(EmojiLonCTW.la(""))
        XCTAssertFalse(EmojiLonCTW.la(nil))
    }

    func testLinkTrongChu() {
        let s = "Thẻ: https://cuongthai.com/work/nw/NW/issue/42 và mailto:a@b.co"
        XCTAssertEqual(LienKetCTW.urls(s).map(\.absoluteString), ["https://cuongthai.com/work/nw/NW/issue/42"])
        let a = LienKetCTW.coLink(s)
        XCTAssertEqual(String(a.characters), s, "không đổi ký tự nào (không đọc markdown)")
        XCTAssertTrue(a.runs.contains { $0.link?.absoluteString == "https://cuongthai.com/work/nw/NW/issue/42" })
        XCTAssertEqual(String(LienKetCTW.coLink("**không đậm**").characters), "**không đậm**")
    }

    // MARK: GIF

    func testTrangGifPhanTrangVaLocTrung() {
        func trang(_ tu: Int, _ n: Int) -> [CTWGif] { (tu..<(tu + n)).map { CTWGif(id: "g\($0)", url: "u\($0)", previewUrl: "p\($0)") } }
        var t = TrangGifCTW()
        t.ghep(trang(0, 24))
        XCTAssertEqual(t.ds.count, 24); XCTAssertEqual(t.offset, 24); XCTAssertFalse(t.het)
        t.ghep(trang(24, 24))
        XCTAssertEqual(t.ds.count, 48); XCTAssertEqual(t.offset, 48); XCTAssertFalse(t.het)
        t.ghep(trang(48, 10))
        XCTAssertTrue(t.het, "trang ngắn hơn 24 ⇒ hết")
        XCTAssertEqual(t.ds.count, 58)
        // Máy chủ CŨ bỏ qua offset ⇒ trả lại trang đầu ⇒ không có mục mới ⇒ dừng, không lặp vô hạn.
        var cu = TrangGifCTW()
        cu.ghep(trang(0, 24)); cu.ghep(trang(0, 24))
        XCTAssertTrue(cu.het)
        XCTAssertEqual(cu.ds.count, 24)
    }

    func testDuongGif() {
        XCTAssertEqual(TrangGifCTW.duong(q: "", offset: 0), "/api/v1/gifs")
        XCTAssertEqual(TrangGifCTW.duong(q: "  ", offset: 24), "/api/v1/gifs?offset=24")
        XCTAssertEqual(TrangGifCTW.duong(q: "chào bạn", offset: 48), "/api/v1/gifs?q=ch%C3%A0o%20b%E1%BA%A1n&offset=48")
        let e = TinNhanAPI.gif(q: "ok", offset: 0)
        XCTAssertEqual(e.path, "/api/v1/gifs?q=ok"); XCTAssertEqual(e.method, "GET")
        let gui = TinNhanAPI.guiMedia(threadId: 7, url: "https://g/x.gif", kieu: "gif", traLoi: 5)
        XCTAssertEqual(gui.path, "/api/v1/messages/threads/7/messages")
        XCTAssertEqual(gui.body?["parentMessageId"] as? Int, 5)
        XCTAssertEqual((gui.body?["media"] as? [String: String]) ?? [:], ["url": "https://g/x.gif", "kind": "gif"], "giống web MessageInput")
    }

    func testGiaiMaGifVaNhanDanMau() throws {
        let gif = try JSONDecoder().decode([CTWGif].self, from: JSONSerialization.data(withJSONObject: DuLieuGiaThanhVien.gifs(offset: 0)))
        XCTAssertEqual(gif.count, TrangGifCTW.kichTrang)
        let cuoi = try JSONDecoder().decode([CTWGif].self, from: JSONSerialization.data(withJSONObject: DuLieuGiaThanhVien.gifs(offset: 48)))
        XCTAssertLessThan(cuoi.count, TrangGifCTW.kichTrang)
        let goi = try JSONDecoder().decode([CTWGoiNhanDan].self, from: JSONSerialization.data(
            withJSONObject: try XCTUnwrap(DuLieuGiaThanhVien.route("GET", "/stickers/packs", [:]))))
        XCTAssertEqual(goi.first?.name, "CT Work")
        let nd = try JSONDecoder().decode([CTWNhanDan].self, from: JSONSerialization.data(
            withJSONObject: try XCTUnwrap(DuLieuGiaThanhVien.route("GET", "/stickers/packs/1/stickers", [:]))))
        XCTAssertEqual(nd.count, 8)
    }

    // MARK: Hồ sơ (đổi ảnh đại diện — cùng đường web/app chính)

    func testYeuCauDoiAnhDaiDien() {
        XCTAssertEqual(HoSoAPICTW.thanAnhDaiDien("https://media.cuongthai.com/avatars/a.jpg") as NSDictionary,
                       ["avatarUrl": "https://media.cuongthai.com/avatars/a.jpg"] as NSDictionary, "CHỈ một trường — không đè hồ sơ")
        XCTAssertTrue(HoSoAPICTW.thanAnhBia(nil)["coverPhotoUrl"] is NSNull, "xoá ảnh bìa = null")
        let p = APIEndpoint.updateProfile(HoSoAPICTW.thanAnhDaiDien("x"))
        XCTAssertEqual(p.path, "/api/v1/profile"); XCTAssertEqual(p.method, "PUT")
        XCTAssertEqual(HoSoAPICTW.thuMucAnhDaiDien, "avatars", "upload.routes.ts › resolveCategory: avatars ⇒ images/avatar")
        XCTAssertEqual(HoSoAPICTW.thuMucAnhBia, "covers")
        let sua = HoSoAPICTW.thanSua(ten: "  Alex  ", gioiThieu: "   ")
        XCTAssertEqual(sua["displayName"] as? String, "Alex")
        XCTAssertTrue(sua["bio"] is NSNull, "rỗng ⇒ xoá (null), không gửi chuỗi trắng")
        XCTAssertEqual(HoSoAPICTW.linkHoSo(2).absoluteString, "https://cuongthai.com/profile/2")
    }

    func testCatAnhVuong() {
        let anh = CGSize(width: 1200, height: 800)
        let khung = CGSize(width: 300, height: 300)
        let tl = CatAnhCTW.tiLePhu(anh: anh, khung: khung)
        XCTAssertEqual(tl, 300.0 / 800.0, accuracy: 0.0001, "phủ kín theo cạnh ngắn")
        let giua = CatAnhCTW.vungCat(anh: anh, tiLe: tl, lech: .zero, khung: khung)
        XCTAssertEqual(giua, CGRect(x: 200, y: 0, width: 800, height: 800), "không kéo ⇒ vuông giữa ảnh")
        let lech = CatAnhCTW.gioiHan(lech: CGSize(width: 999, height: 50), anh: anh, tiLe: tl, khung: khung)
        XCTAssertEqual(lech.width, 75, accuracy: 0.001, "không kéo lộ nền: (450-300)/2")
        XCTAssertEqual(lech.height, 0, accuracy: 0.001)
        let trai = CatAnhCTW.vungCat(anh: anh, tiLe: tl, lech: lech, khung: khung)
        XCTAssertEqual(trai.origin.x, 0, "kéo hết sang phải ⇒ cắt mép trái ảnh")
        XCTAssertEqual(CatAnhCTW.coXuat(tiLeKhung: 1), CGSize(width: 1024, height: 1024))
        XCTAssertEqual(CatAnhCTW.coXuat(tiLeKhung: 3).width, 1600)
    }

    func testGiaiMaHoSoCongKhai() throws {
        let r = try XCTUnwrap(DuLieuGiaThanhVien.route("GET", "/users/2", [:]))
        let h = try JSONDecoder().decode(CTWHoSoCongKhai.self, from: JSONSerialization.data(withJSONObject: r))
        XCTAssertEqual(h.ten, "Linh Tran")
        XCTAssertEqual(h.dongNghe, "Product Owner · Northwind Studio")
        XCTAssertNotNil(h.bio)
        // Máy chủ trả THÊM nhiều trường (followerCount, socialLinks…) — model chỉ đọc phần cần, không vỡ.
        let du: [String: Any] = ["id": 3, "username": "minh", "followerCount": 4, "socialLinks": ["github": "x"], "isPro": true]
        XCTAssertEqual(try JSONDecoder().decode(CTWHoSoCongKhai.self, from: JSONSerialization.data(withJSONObject: du)).ten, "minh")
    }

    // MARK: Chuyển tiếp / tắt thông báo / sắp hội thoại

    func testThanChuyenTiep() {
        let a = MessageAttachment(id: 1, fileId: 77, mimeType: "image/jpeg", fileName: "a.jpg", fileSize: 1, url: "https://x/a.jpg", thumbnailUrl: nil)
        let b = ChuyenTiepCTW.than(tin(1, 2, "xem nè", at: [a]))
        XCTAssertEqual(b["content"] as? String, "xem nè")
        XCTAssertEqual(b["fileIds"] as? [Int], [77], "tệp đã có trên kho — không tải lên lại")
        let g = ChuyenTiepCTW.than(tin(2, 2, media: ("https://g/x.gif", "gif")))
        XCTAssertEqual((g["media"] as? [String: String])?["kind"], "gif")
        XCTAssertNil(g["fileIds"])
        XCTAssertFalse(ChuyenTiepCTW.duocChuyen(tin(3, 2, "x", thuHoi: true)), "tin đã thu hồi không chuyển tiếp")
    }

    func testTatThongBaoDungMucMayChu() {
        XCTAssertEqual(TatThongBaoCTW.allCases.compactMap(\.phut), [15, 60, 480, 1440], "đúng các mức mute-for nhận")
        XCTAssertTrue(TatThongBaoCTW.than(nil)["durationMinutes"] is NSNull, "null = tới khi bật lại")
        XCTAssertEqual(TinNhanAPI.tatThongBao(threadId: 3, phut: 60).path, "/api/v1/messages/threads/3/mute-for")
        XCTAssertEqual(TinNhanAPI.xoaPhiaToi(threadId: 3).method, "DELETE")
        XCTAssertEqual(TinNhanAPI.xoaPhiaToi(threadId: 3).path, "/api/v1/messages/threads/3/hard")
        let ghim = TinNhanAPI.tuyChon(threadId: 3, o: "pinnedAt", giaTri: nil)
        XCTAssertEqual(ghim.method, "PATCH")
        XCTAssertTrue(ghim.body?["value"] is NSNull)
    }

    func testSapHoiThoaiGhimLenDau() throws {
        let ds = try JSONDecoder().decode([MessageThread].self, from: JSONSerialization.data(withJSONObject: DuLieuGiaThanhVien.hoiThoai))
        let sap = SapHoiThoaiCTW.sap(ds.reversed())
        XCTAssertEqual(sap.first?.id, 101, "hội thoại đã ghim lên đầu")
        XCTAssertTrue(sap.first?.daGhim ?? false)
        let conLai = sap.dropFirst().compactMap { $0.lastMessage?.createdAt }
        XCTAssertEqual(conLai, conLai.sorted(by: >), "còn lại theo tin mới nhất")
        XCTAssertTrue(ds.first { $0.id == 103 }?.daTatThongBao ?? false, "mẫu có một hội thoại đang tắt thông báo")
    }

    func testGiaiMaTinMauDuLoai() throws {
        let ds = try JSONDecoder().decode([Message].self, from: JSONSerialization.data(withJSONObject: DuLieuGiaThanhVien.tinNhan))
        XCTAssertTrue(ds.contains { TomTatTinCTW.laGif($0) }, "có GIF")
        XCTAssertTrue(ds.contains { !TomTatTinCTW.amThanh($0).isEmpty }, "có tin thoại")
        XCTAssertTrue(ds.contains { $0.parentMessage != nil }, "có trả lời")
        XCTAssertTrue(ds.contains { EmojiLonCTW.la($0.content) }, "có emoji lớn")
        let b = NhomTinCTW.boCuc(ds.map(ChatRiengCTW.muc))
        XCTAssertLessThanOrEqual(b.filter(\.mocThoiGian).count, 5, "mốc thời gian KHÔNG trên mọi tin (ảnh chủ app 22/10)")
        XCTAssertTrue(b.contains { $0.viTri == .giua }, "có nhóm ≥ 3 tin liền")
    }
}
