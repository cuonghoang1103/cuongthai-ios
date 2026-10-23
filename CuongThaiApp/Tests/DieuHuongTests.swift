import XCTest
@testable import CuongThaiApp

/// Đợt rút gọn điều hướng (22/10/2026): bảng đăng ký tính năng, ghim, link
/// `cuongthai://`, định tuyến thông báo đẩy, giá trị cửa sổ phụ cũ.
@MainActor
final class DieuHuongTests: XCTestCase {

    // MARK: Bảng đăng ký

    func testMoiTinhNangCoIdDuyNhat() {
        let ids = TinhNang.allCases.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "rawValue trùng ⇒ ghim/cửa sổ phụ đọc nhầm")
    }

    func testMoiTinhNangCoTenBieuTuongMoTa() {
        for f in TinhNang.allCases {
            XCTAssertFalse(f.ten.isEmpty, "\(f) thiếu tên")
            XCTAssertFalse(f.moTa.isEmpty, "\(f) thiếu mô tả")
            XCTAssertFalse(f.bieuTuong.isEmpty, "\(f) thiếu biểu tượng")
        }
    }

    /// Danh mục phải phủ ĐỦ mọi tính năng từng có lối vào trong app (đợt rút
    /// gọn hứa "mọi thứ vẫn tới được") — kể cả Xưởng 3D (trước đây không có
    /// lối chạm trên iPhone) và CT Work (giờ là app riêng).
    func testDanhMucPhuDuTinhNang() {
        let canCo: [String] = ["vo", "thoi-khoa-bieu", "hoc-ky", "tien-nong", "ielts", "ngoai-ngu", "dekiru", "ielts-nen-tang",
                               "academy", "chuong-trinh", "phong-thi", "code-lab", "thu-vien-sach", "lo-trinh", "du-an",
                               "phong-van", "thuat-toan", "mo-phong", "cv", "snippets", "video-hoc",
                               "xuong-ve", "xuong-3d", "ai-chat", "notes", "khoa-hoc-cua-toi",
                               "thong-bao", "ct-work", "cai-dat"]
        for ma in canCo { XCTAssertNotNil(TinhNang(rawValue: ma), "thiếu \(ma)") }
        XCTAssertEqual(TinhNang.allCases.count, canCo.count, "thêm tính năng mới ⇒ thêm vào danh sách kiểm")
    }

    func testMoiNhomDeuCoMuc() {
        for n in TinhNang.Nhom.allCases {
            XCTAssertFalse(TinhNang.allCases.filter { $0.nhom == n }.isEmpty, "nhóm \(n) rỗng")
        }
    }

    func testCachMo() {
        XCTAssertEqual(TinhNang.ctWork.cachMo, .ngoai)
        XCTAssertEqual(TinhNang.aiChat.cachMo, .trinhBay)
        XCTAssertEqual(TinhNang.caiDat.cachMo, .trinhBay)
        XCTAssertEqual(TinhNang.tienNong.cachMo, .day)
        XCTAssertEqual(TinhNang.xuongBa.cachMo, .day)
    }

    func testGhimMacDinhHopLe() {
        XCTAssertEqual(TinhNang.ghimMacDinh, [.hocKy, .thoiKhoaBieu, .vo, .aiChat, .phongThi, .codeLab])
        XCTAssertEqual(Set(TinhNang.ghimMacDinh).count, TinhNang.ghimMacDinh.count)
    }

    // MARK: Tìm

    func testTimKhongDauVaTuKhoaPhu() {
        XCTAssertEqual(TinhNang.tim("tien").first, .tienNong)
        XCTAssertTrue(TinhNang.tim("money").contains(.tienNong))
        XCTAssertEqual(TinhNang.tim("vở").first, .vo)
        XCTAssertTrue(TinhNang.tim("thoi khoa").contains(.thoiKhoaBieu))
        XCTAssertTrue(TinhNang.tim("Đề thi").contains(.phongThi))
        XCTAssertTrue(TinhNang.tim("3d").contains(.xuongBa))
        XCTAssertTrue(TinhNang.tim("   ").isEmpty)
        XCTAssertTrue(TinhNang.tim("zzzqqq").isEmpty)
    }

    // MARK: Ghim

    private func khoMoi() -> (KhoGhim, UserDefaults) {
        let ten = "test.ghim.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: ten)!
        d.removePersistentDomain(forName: ten)
        return (KhoGhim(kho: d), d)
    }

    func testGhimMacDinhKhiChuaTungChinh() {
        let (kho, _) = khoMoi()
        XCTAssertEqual(kho.ds, TinhNang.ghimMacDinh)
    }

    func testGhimLuuVaDocLai() {
        let (kho, d) = khoMoi()
        kho.boGhim(.vo)
        kho.ghim(.xuongBa)
        kho.ghim(.xuongBa)   // trùng ⇒ bỏ qua
        kho.diChuyen(tu: IndexSet(integer: kho.ds.count - 1), toi: 0)
        let docLai = KhoGhim(kho: d)
        XCTAssertEqual(docLai.ds, kho.ds)
        XCTAssertEqual(docLai.ds.first, .xuongBa)
        XCTAssertFalse(docLai.coGhim(.vo))
    }

    /// Bỏ ghim HẾT rồi mở lại app ⇒ vẫn rỗng (không được mọc lại mặc định).
    func testBoGhimHetVanRong() {
        let (kho, d) = khoMoi()
        for f in kho.ds { kho.boGhim(f) }
        XCTAssertEqual(KhoGhim(kho: d).ds, [])
    }

    func testGhimBoQuaMaLaVaTrung() {
        let (_, d) = khoMoi()
        d.set("vo,khong-ton-tai,ielts,vo", forKey: KhoGhim.khoa)
        XCTAssertEqual(KhoGhim.doc(d), [.vo, .ielts])
    }

    func testVeMacDinh() {
        let (kho, d) = khoMoi()
        kho.boGhim(.vo)
        kho.veMacDinh()
        XCTAssertEqual(kho.ds, TinhNang.ghimMacDinh)
        XCTAssertNil(d.string(forKey: KhoGhim.khoa))
    }

    // MARK: Link cuongthai://

    func testLinkCu() {
        XCTAssertEqual(HanhDongURL.doc(URL(string: "cuongthai://tien")!), .tinhNang(.tienNong))
        XCTAssertEqual(HanhDongURL.doc(URL(string: "cuongthai://them-video")!), .nhatVideo)
    }

    func testLinkMoi() {
        XCTAssertEqual(HanhDongURL.doc(URL(string: "cuongthai://tinh-nang/xuong-3d")!), .tinhNang(.xuongBa))
        XCTAssertEqual(HanhDongURL.doc(URL(string: "cuongthai://tab/tin-nhan")!), .tab(.tinNhan))
        XCTAssertEqual(HanhDongURL.doc(URL(string: "cuongthai://tim")!), .timKiem)
        XCTAssertNil(HanhDongURL.doc(URL(string: "cuongthai://tinh-nang/khong-co")!))
        XCTAssertNil(HanhDongURL.doc(URL(string: "https://cuongthai.com/tien")!))
    }

    // MARK: Thông báo đẩy

    func testPhanLoaiThongBao() {
        XCTAssertEqual(DinhTuyenDay.phanLoai(["loai": "xa-hoi"]), .chuong)
        XCTAssertEqual(DinhTuyenDay.phanLoai(["loai": "tin-nhan", "threadId": 42]), .tinNhan(threadId: 42))
        XCTAssertEqual(DinhTuyenDay.phanLoai(["threadId": "7"]), .tinNhan(threadId: 7))
        XCTAssertEqual(DinhTuyenDay.phanLoai(["man": "finance/no", "hoiChiTieu": true]), .tienNong(ghiChiNgay: true))
        XCTAssertEqual(DinhTuyenDay.phanLoai(["man": "finance"]), .tienNong(ghiChiNgay: false))
        // CT Work cũng mang `loai: xa-hoi` — phải ra CT Work, không phải chuông.
        XCTAssertEqual(DinhTuyenDay.phanLoai(["kieu": "WORK_ASSIGNED", "loai": "xa-hoi",
                                              "duongDan": "/work/fpt/LF/issue/12"]),
                       .ctWork(duongDan: "/work/fpt/LF/issue/12"))
        XCTAssertNil(DinhTuyenDay.phanLoai([:]))
    }

    /// Lỗi (a): chạm thông báo xã hội phải về BẢNG TIN và bật cờ mở chuông
    /// (chỉ Bảng tin đọc cờ đó) — bản cũ về Hôm nay nên chuông không bao giờ mở.
    func testApDungChuongMoBangTin() {
        let a = AppState.shared
        a.selectedTab = .homNay
        a.moChuongThongBao = false
        a.apDung(.chuong)
        XCTAssertEqual(a.selectedTab, .bangTin)
        XCTAssertTrue(a.moChuongThongBao)
        a.moChuongThongBao = false
    }

    func testApDungTienNongVaTinNhan() {
        let a = AppState.shared
        a.dichCanMo = nil
        a.apDung(.tienNong(ghiChiNgay: true))
        XCTAssertEqual(a.dichCanMo, .tinhNang(.tienNong))
        XCTAssertTrue(a.ghiChiNgaySauKhiMoTien)
        a.dichCanMo = nil
        a.ghiChiNgaySauKhiMoTien = false

        a.apDung(.tinNhan(threadId: 9))
        XCTAssertEqual(a.selectedTab, .tinNhan)
        XCTAssertEqual(a.hoiThoaiCanMo, 9)
        a.hoiThoaiCanMo = nil
    }

    func testDatTabXoaMucRiengIPad() {
        let a = AppState.shared
        a.mucBenRieng = .tinhNang(.tienNong)
        a.selectedTab = .tinNhan
        XCTAssertNil(a.mucBenRieng, "thông báo đặt tab ⇒ cột chi tiết iPad phải rời tính năng")
    }

    func testMoTinhNangTrinhBay() {
        let a = AppState.shared
        a.bangGoc = nil
        a.moTinhNang(.caiDat)
        XCTAssertEqual(a.bangGoc, .caiDat)
        a.bangGoc = nil
        a.moTinhNang(.aiChat)
        XCTAssertTrue(a.moAIChatGoc)
        a.moAIChatGoc = false
    }

    // MARK: CT Work là app riêng

    func testURLAppCTWork() {
        XCTAssertEqual(MoCTWorkApp.urlApp(duongDan: "/work/fpt/LF/issue/12").absoluteString,
                       "ctwork://work/fpt/LF/issue/12")
        XCTAssertEqual(MoCTWorkApp.urlApp(duongDan: "https://cuongthai.com/work/fpt/LF").absoluteString,
                       "ctwork://work/fpt/LF")
        XCTAssertEqual(MoCTWorkApp.urlApp(duongDan: nil).absoluteString, "ctwork://")
        XCTAssertEqual(MoCTWorkApp.urlAppStore.absoluteString, "https://apps.apple.com/app/id6824877696")
    }

    func testInfoPlistKhaiLuocDoCTWork() {
        let ds = Bundle.main.object(forInfoDictionaryKey: "LSApplicationQueriesSchemes") as? [String]
        XCTAssertTrue(ds?.contains("ctwork") == true, "thiếu ⇒ canOpenURL(ctwork://) luôn sai")
    }

    // MARK: Giá trị cửa sổ phụ / tab cũ

    func testGiaiMaSoTabCu() throws {
        let dec = JSONDecoder()
        func doc(_ so: Int) throws -> MucBen { try dec.decode(MucBen.self, from: Data("\(so)".utf8)) }
        XCTAssertEqual(try doc(0), .tab(.homNay))
        XCTAssertEqual(try doc(1), .tab(.hoc))
        XCTAssertEqual(try doc(2), .tab(.bangTin))
        XCTAssertEqual(try doc(3), .tab(.tinNhan))
        XCTAssertEqual(try doc(4), .tab(.toi))
        XCTAssertEqual(try doc(5), .tinhNang(.vo))
        XCTAssertEqual(try doc(6), .tinhNang(.tienNong))
        XCTAssertEqual(try doc(9), .tinhNang(.xuongBa))
        XCTAssertEqual(try doc(10), .tinhNang(.ctWork))
        XCTAssertEqual(try doc(99), .tab(.homNay))
    }

    func testMucBenKhuHoi() throws {
        for m in [MucBen.tab(.bangTin), .tinhNang(.xuongVe), .tatCa] {
            let d = try JSONEncoder().encode(m)
            XCTAssertEqual(try JSONDecoder().decode(MucBen.self, from: d), m)
        }
    }

    /// AppTab mới KHÔNG được giải mã nhầm từ số cũ (1 cũ = Học, mới thì không có số).
    func testAppTabKhongNhanSo() {
        XCTAssertNil(try? JSONDecoder().decode(AppState.AppTab.self, from: Data("1".utf8)))
        XCTAssertEqual(AppState.AppTab.allCases.count, 5)
    }

    func testNhanTabTrungTieuDe() {
        XCTAssertEqual(AppState.AppTab.allCases.map(\.title), ["Hôm nay", "Bảng tin", "Học", "Tin nhắn", "Tôi"]
                        .map { T($0) })
    }
}
