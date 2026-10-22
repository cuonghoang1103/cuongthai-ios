import XCTest
import CoreGraphics
@testable import CTWork

/// Lỗi thấy lúc chụp ảnh nộp App Store build 4 (22/10/2026, `~/Documents/ctwork-appstore/anh/build4/_loi/`):
/// chữ tắt avatar "M(", tên ngắn "(Demo)", danh sách tin nhắn đứng yên sau khi gửi, khung ảnh chat, dính đáy, cột bảng iPad.
@MainActor
final class SuaLoiBuild5Tests: XCTestCase {

    // MARK: Chữ tắt avatar (ảnh lỗi 05)

    func testChuTatChiLayChuCai() {
        XCTAssertEqual(TenNguoi.chuCaiDau("Minh (Demo)"), "M", "bỏ phần trong ngoặc — không còn \"M(\"")
        XCTAssertEqual(TenNguoi.chuCaiDau("Hoàng Nghĩa Cường"), "HC", "từ đầu + từ cuối, như web initialsOf")
        XCTAssertEqual(TenNguoi.chuCaiDau("đặng ước"), "ĐƯ", "chữ có dấu tiếng Việt viết hoa đúng")
        XCTAssertEqual(TenNguoi.chuCaiDau("Linh Tran"), "LT")
        XCTAssertEqual(TenNguoi.chuCaiDau("CT Work Review"), "CR")
        XCTAssertEqual(TenNguoi.chuCaiDau("Release Bot"), "RB")
        XCTAssertEqual(TenNguoi.chuCaiDau("cuong"), "C")
        XCTAssertEqual(TenNguoi.chuCaiDau("🚀 Minh"), "M", "emoji không phải chữ")
        XCTAssertEqual(TenNguoi.chuCaiDau("Minh 🚀"), "M")
        XCTAssertEqual(TenNguoi.chuCaiDau("\"Cường\" - Hoàng!"), "CH", "dấu câu hai đầu bị bỏ")
        XCTAssertEqual(TenNguoi.chuCaiDau("[Bot] Deploy Helper"), "DH")
        XCTAssertEqual(TenNguoi.chuCaiDau("(Demo)"), "D", "cả tên trong ngoặc ⇒ vẫn lấy chữ bên trong")
        XCTAssertEqual(TenNguoi.chuCaiDau("Anne-Marie O'Brien"), "AO")
        XCTAssertEqual(TenNguoi.chuCaiDau("李 小龍"), "李小", "chữ CJK là chữ cái")
        XCTAssertEqual(TenNguoi.chuCaiDau(""), "?")
        XCTAssertEqual(TenNguoi.chuCaiDau("   "), "?")
        XCTAssertEqual(TenNguoi.chuCaiDau("🚀🔥"), "?")
        XCTAssertEqual(TenNguoi.chuCaiDau("🚀", duPhong: "ctworkminh"), "C", "không có chữ ⇒ lùi về username")
        XCTAssertEqual(TenNguoi.chuCaiDau(nil), "?")
        XCTAssertLessThanOrEqual(TenNguoi.chuCaiDau("A B C D E").count, 2, "tối đa 2 chữ")
    }

    func testCTWUserKyTuDauDungHelperChung() {
        XCTAssertEqual(CTWUser(id: 7, username: "ctworkminh", displayName: "Minh (Demo)").kyTuDau, "M")
        XCTAssertEqual(CTWUser(id: 7, username: "ctworkminh", displayName: "😀").kyTuDau, "C")
        XCTAssertEqual(CTWUser(id: 7, username: "ctworkminh", displayName: "Minh (Demo)").tenNgan, "Minh")
    }

    // MARK: Tên ngắn (ảnh lỗi 07 — hàng "Đang hoạt động")

    func testTenNgan() {
        XCTAssertEqual(TenNguoi.tenNgan("Minh (Demo)"), "Minh")
        XCTAssertEqual(TenNguoi.tenNgan("Hoàng Nghĩa Cường"), "Cường", "tên gọi người Việt là từ CUỐI")
        XCTAssertEqual(TenNguoi.tenNgan("Linh Tran"), "Tran", "tên kiểu Tây: giữ luật từ cuối")
        XCTAssertEqual(TenNguoi.tenNgan("Cường"), "Cường")
        XCTAssertEqual(TenNguoi.tenNgan("Minh 🚀"), "Minh", "emoji cuối không thành tên")
        XCTAssertEqual(TenNguoi.tenNgan("Nguyễn Văn An [QA]"), "An")
        XCTAssertEqual(TenNguoi.tenNgan("Trần Bình, "), "Bình", "dấu câu cuối bị bỏ")
        XCTAssertEqual(TenNguoi.tenNgan("(Demo)"), "Demo")
        XCTAssertEqual(TenNguoi.tenNgan(""), "")
        XCTAssertEqual(TenNguoi.tenNgan("🚀"), "🚀", "không có chữ nào ⇒ giữ nguyên")
    }

    // MARK: Hàng hội thoại cập nhật khi gửi / nhận (ảnh lỗi 08)

    private func tin(_ id: Int, _ chu: String, nguoiGui: Int = 1, luc: String) throws -> Message {
        let json = #"{"id":\#(id),"threadId":5,"senderId":\#(nguoiGui),"content":"\#(chu)","createdAt":"\#(luc)"}"#
        return try JSONDecoder().decode(Message.self, from: Data(json.utf8))
    }

    private func hoiThoai(_ id: Int, tinCuoi: Message?, capNhat: String, chuaDoc: Int = 0) -> MessageThread {
        MessageThread(id: id, type: "USER", peer: ThreadPeer(id: 100 + id, username: "u\(id)", displayName: nil, avatarUrl: nil, alias: nil),
                      lastMessage: tinCuoi, unreadCount: chuaDoc, createdAt: capNhat, updatedAt: capNhat, preferences: nil)
    }

    func testGuiTinDuaHangLenDauVaDoiDongXemTruoc() throws {
        let cu = try tin(10, "old", luc: "2026-10-20T08:00:00.000Z")
        let ds = [hoiThoai(1, tinCuoi: nil, capNhat: "2026-10-21T08:00:00.000Z"),
                  hoiThoai(5, tinCuoi: cu, capNhat: "2026-10-20T08:00:00.000Z")]
        let moi = try tin(11, "Hi Minh", luc: "2026-10-22T09:00:00.000Z")
        let kq = try XCTUnwrap(KhoTinNhanCTW.voiTin(ds, threadId: 5, tin: moi, tangChuaDoc: false))
        XCTAssertEqual(kq.map(\.id), [5, 1], "hội thoại vừa có tin lên đầu")
        XCTAssertEqual(kq[0].lastMessage?.content, "Hi Minh")
        XCTAssertEqual(kq[0].updatedAt, "2026-10-22T09:00:00.000Z", "giờ theo tin mới (không còn \"Wed\")")
        XCTAssertEqual(kq[0].unreadCount, 0)
    }

    func testHoiThoaiChuaCoTinNaoNhanTinDauTien() throws {
        let ds = [hoiThoai(5, tinCuoi: nil, capNhat: "2026-10-15T08:00:00.000Z")]
        let moi = try tin(1, "Hello", luc: "2026-10-22T09:00:00.000Z")
        let kq = try XCTUnwrap(KhoTinNhanCTW.voiTin(ds, threadId: 5, tin: moi, tangChuaDoc: false))
        XCTAssertEqual(kq[0].lastMessage?.id, 1, "không còn \"Say hi 👋\"")
    }

    func testTinCuNguoiKhacTangChuaDocMotLan() throws {
        let ds = [hoiThoai(5, tinCuoi: nil, capNhat: "2026-10-15T08:00:00.000Z", chuaDoc: 2)]
        let moi = try tin(3, "ping", nguoiGui: 105, luc: "2026-10-22T09:00:00.000Z")
        let mot = try XCTUnwrap(KhoTinNhanCTW.voiTin(ds, threadId: 5, tin: moi, tangChuaDoc: true))
        XCTAssertEqual(mot[0].unreadCount, 3)
        let hai = try XCTUnwrap(KhoTinNhanCTW.voiTin(mot, threadId: 5, tin: moi, tangChuaDoc: true))
        XCTAssertEqual(hai[0].unreadCount, 3, "cùng một tin về hai lần (gửi + socket dội) không đếm hai lần")
    }

    func testTinVeTreKhongLuiDongXemTruoc() throws {
        let moiNhat = try tin(20, "newest", luc: "2026-10-22T09:00:00.000Z")
        let ds = [hoiThoai(1, tinCuoi: nil, capNhat: "2026-10-22T10:00:00.000Z"),
                  hoiThoai(5, tinCuoi: moiNhat, capNhat: "2026-10-22T09:00:00.000Z")]
        let tre = try tin(19, "older", luc: "2026-10-22T08:59:00.000Z")
        let kq = try XCTUnwrap(KhoTinNhanCTW.voiTin(ds, threadId: 5, tin: tre, tangChuaDoc: false))
        XCTAssertEqual(kq.map(\.id), [1, 5], "tin cũ hơn không đổi thứ tự")
        XCTAssertEqual(kq[1].lastMessage?.content, "newest")
    }

    func testHoiThoaiKhongCoTrongDanhSachTraNil() throws {
        XCTAssertNil(KhoTinNhanCTW.voiTin([], threadId: 5, tin: try tin(1, "x", luc: "2026-10-22T09:00:00.000Z"), tangChuaDoc: false),
                     "nil ⇒ kho tải lại danh sách từ máy chủ")
    }

    func testHangHoiThoaiDocTinMoi() throws {
        // Hàng giữ GIÁ TRỊ rút từ hội thoại (không giữ MessageThread — `==` chỉ so id ⇒ SwiftUI không vẽ lại).
        let t = hoiThoai(5, tinCuoi: nil, capNhat: "2026-10-15T08:00:00.000Z")
        XCTAssertEqual(HangHoiThoaiCTW.xemTruoc(t.lastMessage, toi: 1), String(localized: "Say hi 👋"))
        let moi = try tin(7, "Hi", nguoiGui: 1, luc: "2026-10-22T09:00:00.000Z")
        let sau = try XCTUnwrap(KhoTinNhanCTW.voiTin([t], threadId: 5, tin: moi, tangChuaDoc: false))[0]
        let tom = ChatRiengCTW.tomTat(moi)
        XCTAssertEqual(HangHoiThoaiCTW.xemTruoc(sau.lastMessage, toi: 1), String(localized: "You: \(tom)"))
        XCTAssertEqual(HangHoiThoaiCTW.xemTruoc(sau.lastMessage, toi: 2), tom)
    }

    // MARK: Khung ảnh chat (ảnh lỗi 06)

    func testKhungAnhGiuTiLe() {
        let hop = CGSize(width: 280, height: 320)
        XCTAssertEqual(TiLeAnhChatCTW.khung(tiLe: 2, toiDa: hop), CGSize(width: 280, height: 140), "ảnh ngang: đủ rộng, cao theo tỉ lệ")
        XCTAssertEqual(TiLeAnhChatCTW.khung(tiLe: 0.5, toiDa: hop), CGSize(width: 160, height: 320), "ảnh dọc: đủ cao, rộng theo tỉ lệ")
        XCTAssertEqual(TiLeAnhChatCTW.khung(tiLe: 1, toiDa: hop), CGSize(width: 280, height: 280))
        XCTAssertEqual(TiLeAnhChatCTW.khung(tiLe: 20, toiDa: hop).height, 72, "ảnh rất dẹt vẫn có cạnh tối thiểu")
        XCTAssertEqual(TiLeAnhChatCTW.khung(tiLe: nil, toiDa: hop), CGSize(width: 280, height: 210), "chưa biết ⇒ tạm 4:3")
        XCTAssertEqual(TiLeAnhChatCTW.khung(tiLe: .nan, toiDa: hop), CGSize(width: 280, height: 210))
    }

    // MARK: Dính đáy khung chat (ảnh lỗi 10/10b)

    func testLuatDinhDay() {
        typealias G = GhimDayChatCTW
        var kq = G.luat(dinh: true, doiCao: true, cachDay: 240, nguoiDangCuon: false)
        XCTAssertTrue(kq.dinh); XCTAssertTrue(kq.cuon, "ảnh tải xong khi đang ở đáy ⇒ cuộn lại xuống đáy")
        kq = G.luat(dinh: false, doiCao: true, cachDay: 240, nguoiDangCuon: false)
        XCTAssertFalse(kq.cuon, "đang đọc tin cũ ⇒ không giật xuống")
        kq = G.luat(dinh: true, doiCao: true, cachDay: 240, nguoiDangCuon: true)
        XCTAssertFalse(kq.cuon, "người dùng đang kéo ⇒ không giành cuộn")
        kq = G.luat(dinh: true, doiCao: false, cachDay: 400, nguoiDangCuon: true)
        XCTAssertFalse(kq.dinh, "cuộn lên quá ngưỡng ⇒ thôi dính")
        kq = G.luat(dinh: false, doiCao: false, cachDay: 30, nguoiDangCuon: false)
        XCTAssertTrue(kq.dinh, "cuộn về gần đáy ⇒ dính lại")
    }

    func testGhimDayTheoKhungThat() {
        let g = GhimDayChatCTW()
        _ = g.doKhung(800)
        g.batDauNap()
        XCTAssertFalse(g.doNoiDung(CGRect(x: 0, y: -1200, width: 700, height: 2000)), "lần đo đầu chỉ ghi nhận")
        XCTAssertFalse(g.doNoiDung(CGRect(x: 0, y: -1200, width: 700, height: 2000)))
        XCTAssertTrue(g.dinh, "đáy nội dung = đáy khung")
        XCTAssertTrue(g.doNoiDung(CGRect(x: 0, y: -1200, width: 700, height: 2300)), "ảnh tải xong cao thêm 300pt ⇒ cuộn")
        // Người dùng cuộn lên xa (vị trí đổi, cao không đổi) ⇒ thôi dính, lần đổi cao sau không cuộn.
        XCTAssertFalse(g.doNoiDung(CGRect(x: 0, y: -500, width: 700, height: 2300)))
        XCTAssertFalse(g.dinh)
        XCTAssertFalse(g.doNoiDung(CGRect(x: 0, y: -500, width: 700, height: 2500)))
    }

    // MARK: Ô soạn iPad sau khi ẩn bàn phím (ảnh lỗi 11)

    func testBoFocusKhiBanPhimAoThuNho() {
        typealias B = BoFocusKhiAnBanPhimCTW
        let man = CGRect(x: 0, y: 0, width: 1032, height: 1376)
        XCTAssertEqual(B.caoHien(khung: CGRect(x: 0, y: 973, width: 1032, height: 403), man: man), 403)
        XCTAssertEqual(B.caoHien(khung: CGRect(x: 0, y: 1376, width: 1032, height: 403), man: man), 0, "bàn phím đã trượt khỏi màn")
        XCTAssertEqual(B.caoHien(khung: CGRect(x: 0, y: 1306, width: 1032, height: 70), man: man), 70, "thanh phím tắt thu nhỏ")
        XCTAssertEqual(B.caoHien(khung: .null, man: man), 0)
        XCTAssertTrue(B.nenBoFocus(caoTruoc: 403, caoMoi: 70, dangFocus: true), "ẩn bàn phím ảo mà còn con trỏ ⇒ bỏ focus")
        XCTAssertFalse(B.nenBoFocus(caoTruoc: 0, caoMoi: 70, dangFocus: true), "gõ bằng bàn phím rời từ đầu ⇒ giữ focus")
        XCTAssertFalse(B.nenBoFocus(caoTruoc: 70, caoMoi: 70, dangFocus: true))
        XCTAssertFalse(B.nenBoFocus(caoTruoc: 403, caoMoi: 70, dangFocus: false))
        XCTAssertFalse(B.nenBoFocus(caoTruoc: 403, caoMoi: 380, dangFocus: true), "đổi kiểu bàn phím (gợi ý chữ) ⇒ không đụng")
    }

    // MARK: Cột bảng iPad (ảnh lỗi 09)

    func testRongCotIPad() {
        // Cột chi tiết iPad 13" có thanh bên: ~720pt, 4 cột ⇒ 2 cột trọn + mép cột kế, không cắt giữa cột.
        let w = CTWBangCot.rongIPad(beNgang: 720, soCot: 4, khoang: 10)
        XCTAssertGreaterThanOrEqual(w, CTWBangCot.san)
        XCTAssertEqual(2 * w + 2 * 10 + CTWBangCot.hoMep, 720, accuracy: 0.5)
        // Đủ chỗ ⇒ chia đều (tối đa trần).
        XCTAssertEqual(CTWBangCot.rongIPad(beNgang: 1300, soCot: 4, khoang: 10), 317.5, accuracy: 0.01)
        XCTAssertEqual(CTWBangCot.rongIPad(beNgang: 1300, soCot: 1, khoang: 10), CTWBangCot.tran)
        // Rất hẹp ⇒ không nhỏ hơn sàn.
        XCTAssertEqual(CTWBangCot.rongIPad(beNgang: 300, soCot: 3, khoang: 10), CTWBangCot.san)
    }
}
