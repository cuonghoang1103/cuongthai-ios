import XCTest
import Combine
@testable import CTWork

/// Build 1.0.0 (7) — phần thêm 22/10/2026:
///   · Đăng nhập Google trong CT Work (client iOS riêng, chuyển hướng không lấn deep link, nút đúng thương hiệu);
///   · R4 — báo cáo MỘT tin nhắn riêng (`messageId`) + ẩn tin đó ngay tại máy;
///   · 422 `CONTENT_BLOCKED` (bộ lọc nội dung của máy chủ) — câu song ngữ theo ngôn ngữ app, bản nháp giữ nguyên.
@MainActor
final class Build7GoogleKiemDuyetTests: XCTestCase {

    private let clientId = "20442169272-u34g5m8cu3icggucjmmdmcb6cakc20u5.apps.googleusercontent.com"
    private let schemeDao = "com.googleusercontent.apps.20442169272-u34g5m8cu3icggucjmmdmcb6cakc20u5"
    private let cauMayChu = DuLieuGia.cauBiChan

    override func tearDown() {
        URLProtocol.unregisterClass(MayChuGia.self)
        AnNoiDungChungCTW.shared.xoaHet()
        DuLieuGia.tinDaBaoCao = []
        super.tearDown()
    }

    // MARK: Google — cấu hình

    func testInfoPlistCoClientIdVaSchemeGoogle() throws {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String, clientId)
        XCTAssertEqual(GoogleSignInService.clientID, clientId)
        XCTAssertTrue(GoogleSignInService.duocCauHinh, "có client ID ⇒ nút Google hiện")
        let loai = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]])
        let scheme = loai.flatMap { ($0["CFBundleURLSchemes"] as? [String]) ?? [] }
        XCTAssertTrue(scheme.contains("ctwork"), "deep link cũ giữ nguyên")
        XCTAssertTrue(scheme.contains(schemeDao), "Google chuyển hướng về app qua client ID đảo ngược")
    }

    func testChuyenHuongGoogleKhongLanDeepLink() {
        XCTAssertTrue(GoogleSignInService.laURLChuyenHuong(URL(string: "\(schemeDao):/oauth2redirect/google?state=x&code=y")!))
        XCTAssertTrue(GoogleSignInService.laURLChuyenHuong(URL(string: "COM.GOOGLEUSERCONTENT.APPS.20442169272-U34G5M8CU3ICGGUCJMMDMCB6CAKC20U5:/x")!),
                      "scheme không phân biệt hoa thường")
        for s in ["ctwork://issue/NW-12", "ctwork://dm/101", "ctwork://work/northwind/NW/issue/12",
                  "https://cuongthai.com/work/northwind/NW/issue/12", "https://accounts.google.com/o/oauth2"] {
            XCTAssertFalse(GoogleSignInService.laURLChuyenHuong(URL(string: s)!), s)
        }
    }

    func testChuGCuaSdkCoTrongGoiApp() {
        // Nút tự dựng dùng ĐÚNG ảnh chữ G của SDK — mất ảnh (đổi tên gói tài nguyên) thì nút chỉ còn chữ.
        XCTAssertNotNil(GoogleSignInService.logoG)
    }

    func testDangNhapOAuthGiaTraToken() throws {
        let d = DuLieuGia.traLoi(method: "POST", path: "/api/v1/auth/oauth/token",
                                 body: ["provider": "google", "email": "a@b.c", "providerId": "1", "idToken": "t"])
        let r = try XCTUnwrap(JSONDecoder().decode(APIResponse<AuthResponse>.self, from: d).data)
        XCTAssertEqual(r.token, "xem-thu-token")
    }

    func testCauLoiGoogle() {
        XCTAssertEqual(DangNhapCTW.cauLoiGoogle(GoogleSignInError.khongCoEmail),
                       "Your Google account didn't share an email address, so we couldn't sign you in.")
        XCTAssertEqual(DangNhapCTW.cauLoiGoogle(GoogleSignInError.that("GIDSignIn keychain error -34018")),
                       "Sign in with Google didn't complete. Please try again.", "lỗi kỹ thuật của SDK không hiện nguyên văn")
        XCTAssertEqual(DangNhapCTW.cauLoiGoogle(URLError(.timedOut)), "Sign in with Google didn't complete. Please try again.")
    }

    // MARK: R4 — báo cáo một tin nhắn riêng

    func testThanBaoCaoMotTin() {
        let b = TinNhanAPI.thanBaoCao(lyDo: "Harassment or bullying", loai: "harassment", tinId: 1004)
        XCTAssertEqual(b as NSDictionary, ["reason": "Harassment or bullying", "category": "harassment", "messageId": 1004] as NSDictionary)
        XCTAssertNil(TinNhanAPI.thanBaoCao(lyDo: "x", loai: "spam")["messageId"], "báo cáo cả hội thoại ⇒ không có messageId")
        XCTAssertNil(TinNhanAPI.thanBaoCao(lyDo: "x", loai: "spam", tinId: 0)["messageId"], "id không hợp lệ ⇒ bỏ")
        let e = TinNhanAPI.baoCao(threadId: 101, lyDo: "Spam", loai: "spam", tinId: 1004)
        XCTAssertEqual(e.path, "/api/v1/messages/threads/101/report")
        XCTAssertEqual(e.method, "POST")
    }

    func testTinDaBaoCaoAnTaiMayVaMayChuGiaKhongTraLai() throws {
        let ds = try JSONDecoder().decode([Message].self, from: JSONSerialization.data(withJSONObject: DuLieuGiaThanhVien.tinNhan))
        let cua2 = try XCTUnwrap(ds.first { $0.senderId == 2 && !$0.daXoaHoacThuHoi })
        XCTAssertEqual(TinNhanAPI.locDaAn(ds).count, ds.count)
        AnNoiDungChungCTW.shared.an(TinNhanAPI.khoaAnTin(cua2.id))
        let con = TinNhanAPI.locDaAn(ds)
        XCTAssertEqual(con.count, ds.count - 1)
        XCTAssertFalse(con.contains { $0.id == cua2.id }, "máy chủ cũ còn trả tin ⇒ app vẫn ẩn")

        // Máy chủ giả (như 48d4d79a): báo cáo kèm messageId ⇒ GET messages bỏ tin đó.
        _ = DuLieuGia.traLoi(method: "POST", path: "/api/v1/messages/threads/101/report",
                             body: TinNhanAPI.thanBaoCao(lyDo: "Spam", loai: "spam", tinId: cua2.id))
        let d = DuLieuGia.traLoi(method: "GET", path: "/api/v1/messages/threads/101/messages", body: [:])
        let sau = try XCTUnwrap(JSONDecoder().decode(APIResponse<[Message]>.self, from: d).data)
        XCTAssertFalse(sau.contains { $0.id == cua2.id })
    }

    func testVMAnTinVaKhongNhanLaiQuaSocket() throws {
        let ds = try JSONDecoder().decode([Message].self, from: JSONSerialization.data(withJSONObject: DuLieuGiaThanhVien.tinNhan))
        let vm = ChatRiengVM(threadId: 101)
        vm.tin = ds
        let m = try XCTUnwrap(ds.first { $0.senderId == 2 })
        AnNoiDungChungCTW.shared.an(TinNhanAPI.khoaAnTin(m.id))
        vm.anTin(m.id)
        XCTAssertFalse(vm.tin.contains { $0.id == m.id })
        vm.them(m)
        XCTAssertFalse(vm.tin.contains { $0.id == m.id }, "tin đã báo cáo dội lại (socket) không hiện lại")
    }

    // MARK: 422 CONTENT_BLOCKED

    func testCauBiChanTheoNgonNgu() {
        let cu = NgonNguCTW.cheDo
        defer { NgonNguCTW.dat(cu); CTWDinhDang.locale = Locale(identifier: "en_US") }
        let e = APIError.coMa(ma: "CONTENT_BLOCKED", thongDiep: cauMayChu)
        XCTAssertTrue(CTWLoiDich.laNoiDungBiChan(e))
        XCTAssertFalse(CTWLoiDich.laNoiDungBiChan(APIError.coMa(ma: "WORK_RATE", thongDiep: "x")))

        NgonNguCTW.dat(.en); CTWDinhDang.locale = NgonNguCTW.locale
        XCTAssertEqual(CTW.loi(e), "This contains words that aren't allowed in CT Work (profanity, slurs, sexual or threatening language). Please edit it.")
        XCTAssertEqual(TroLyAICTW.loi(e), CTW.loi(e))
        XCTAssertEqual(DangNhapCTW.cauLoi(e), CTW.loi(e), "đăng ký với tên hiển thị bị chặn ⇒ câu bộ lọc, không phải 'Couldn't sign in'")
        NgonNguCTW.dat(.vi); CTWDinhDang.locale = NgonNguCTW.locale
        XCTAssertEqual(CTW.loi(e), "Nội dung có từ ngữ không được phép trong CT Work (tục tĩu, xúc phạm, tình dục hoặc đe doạ). Vui lòng sửa lại.")
        // Máy chủ đảo thứ tự hai nửa ⇒ vẫn chọn đúng nửa tiếng Việt.
        let dao = cauMayChu.components(separatedBy: " · ").reversed().joined(separator: " · ")
        XCTAssertTrue(CTWLoiDich.noiDungBiChan(dao).hasPrefix("Nội dung"))
        // Câu không tách được ⇒ câu catalog cùng nghĩa.
        XCTAssertTrue(CTWLoiDich.noiDungBiChan("Blocked").hasPrefix("Nội dung"))
    }

    func testMayChuGiaChanMoiCuaGhi() {
        for (p, b) in [("/api/v1/feed/posts", ["body": "a badword here"]),
                       ("/api/v1/messages/threads/101/messages", ["content": "BadWord"]),
                       ("/api/v1/work/projects/7/issues/12/comments", ["bodyJson": ["type": "doc", "content": [["type": "text", "text": "badword"]]]]),
                       ("/api/v1/profile", ["bio": "badword"])] as [(String, [String: Any])] {
            let (ma, d) = DuLieuGia.traLoiCoMa(method: p == "/api/v1/profile" ? "PUT" : "POST", path: p, body: b)
            XCTAssertEqual(ma, 422, p)
            XCTAssertEqual((try? JSONSerialization.jsonObject(with: d) as? [String: Any])?["code"] as? String, "CONTENT_BLOCKED", p)
        }
        XCTAssertEqual(DuLieuGia.traLoiCoMa(method: "POST", path: "/api/v1/messages/threads/101/messages", body: ["content": "hello"]).0, 200)
    }

    /// Tin nhắn riêng bị chặn: bong bóng chờ biến mất (không "Thử lại" vô ích), chữ về ô soạn, câu lỗi tại chỗ.
    func testTinNhanRiengBiChanGiuBanNhap() async throws {
        URLProtocol.registerClass(MayChuGia.self)
        let vm = ChatRiengVM(threadId: 101)
        vm.gui(.chu("you badword"), traLoi: 1004)
        for _ in 0..<60 where vm.loiChan == nil { try await Task.sleep(nanoseconds: 50_000_000) }
        XCTAssertNotNil(vm.loiChan)
        XCTAssertTrue(vm.dangCho.isEmpty)
        XCTAssertEqual(vm.nhapTraLai?.chu, "you badword")
        XCTAssertEqual(vm.nhapTraLai?.traLoi, 1004)
    }

    /// Tin kênh (qua hàng chờ ngoại tuyến): bị chặn ⇒ rời hàng chờ, nơi gọi nhận `.biChan` ⇒ ô soạn giữ chữ.
    func testTinKenhBiChanRoiHangCho() async throws {
        URLProtocol.registerClass(MayChuGia.self)
        let kq = await HangChoGuiCTW.shared.themKQ(pid: 7, cid: 1, parentId: nil, body: "badword")
        guard case .biChan(let l) = kq else { return XCTFail("phải bị chặn") }
        XCTAssertFalse(l.isEmpty)
        XCTAssertTrue(HangChoGuiCTW.shared.cua(pid: 7, cid: 1).allSatisfy { $0.body != "badword" }, "không nằm lại hàng chờ")
    }

    /// Bài Bảng tin (đăng lạc quan, ô soạn đã đóng): bị chặn ⇒ sự kiện `.biChan` + nháp được ghi lại cho nút "Sửa".
    func testBaiBangTinBiChanGhiLaiNhap() async throws {
        URLProtocol.registerClass(MayChuGia.self)
        NhapBaiCTW.ghi(nil)
        defer { NhapBaiCTW.ghi(nil) }
        let ws = CTWFeedWorkspace(id: 1, slug: "northwind", name: "Northwind Studio", logoUrl: nil)
        let khoa = TrangBangTin.khoaMoi()
        let tam = TrangBangTin.baiTam(khoa: khoa, toi: nil, chu: "badword", ws: ws, duAn: nil, dinhKem: [])
        let nhap = NhapBaiCTW(chu: "badword", noi: NoiDangBangTin(ws: ws, duAn: nil))
        var suKien: [SuKienDangBaiCTW] = []
        let huy = KhoBangTinCTW.shared.dangBai.sink { suKien.append($0) }
        defer { huy.cancel() }
        KhoBangTinCTW.shared.dang(than: ["workspaceId": 1, "body": "badword"], tam: tam, nhap: nhap)
        for _ in 0..<60 where suKien.count < 2 { try await Task.sleep(nanoseconds: 50_000_000) }
        guard suKien.count >= 2, case .biChan(let k, let l) = suKien[1] else { return XCTFail("phải bị chặn: \(suKien)") }
        XCTAssertEqual(k, khoa)
        XCTAssertFalse(l.isEmpty)
        XCTAssertEqual(NhapBaiCTW.doc()?.chu, "badword", "nháp giữ lại cho nút Sửa")
        let ds = TrangBangTin.danhDauBiChan([tam], khoa: khoa, loi: l)
        XCTAssertEqual(ds.first?.dangHong, true)
        XCTAssertEqual(ds.first?.loiChan, l)
    }
}
