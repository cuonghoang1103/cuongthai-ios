import XCTest
import PencilKit
import SwiftData
@testable import CuongThaiApp

/// "Ghi khi học" (24/10/2026): khoá lưu, co giãn nét theo bề ngang / cỡ chữ, đặt ảnh dán, trang Vở của bài.
@MainActor
final class GhiKhiHocTests: XCTestCase {

    // MARK: Co giãn nét

    private func netVuong(_ r: CGRect) -> PKDrawing {
        let ds = [r.origin, CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY)]
        let pts = ds.enumerated().map { i, p in
            PKStrokePoint(location: p, timeOffset: Double(i) * 0.01, size: CGSize(width: 3, height: 3),
                          opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .black),
                                            path: PKStrokePath(controlPoints: pts, creationDate: Date()))])
    }

    func testTiLeTheoBeNgangVaCoChu() {
        let a = CoGianVietDe.tiLe(tuRong: 688, tuCo: 1, sangRong: 344, sangCo: 1)
        XCTAssertEqual(a.x, 0.5, accuracy: 1e-6)
        XCTAssertEqual(a.y, 0.5, accuracy: 1e-6)
        let b = CoGianVietDe.tiLe(tuRong: 500, tuCo: 1, sangRong: 500, sangCo: 1.3)
        XCTAssertEqual(b.x, 1, accuracy: 1e-6)
        XCTAssertEqual(b.y, 1.3, accuracy: 1e-6, "chữ to 1,3× ⇒ vị trí dọc giãn theo")
        // Chưa biết bề ngang (0) ⇒ không biến đổi bừa.
        let c = CoGianVietDe.tiLe(tuRong: 0, tuCo: 1, sangRong: 400, sangCo: 1)
        XCTAssertEqual(c.x, 1); XCTAssertEqual(c.y, 1)
    }

    /// Khối hẹp đi một nửa ⇒ tâm nét về đúng nửa toạ độ, hình nét co đều (vuông vẫn vuông).
    func testBienDoiGiuTamVaDangNet() {
        let goc = netVuong(CGRect(x: 100, y: 40, width: 60, height: 60))
        let moi = CoGianVietDe.bienDoi(goc, tuRong: 600, tuCo: 1, sangRong: 300, sangCo: 1)
        let b0 = goc.strokes[0].renderBounds, b1 = moi.strokes[0].renderBounds
        XCTAssertEqual(b1.midX, b0.midX * 0.5, accuracy: 0.5)
        XCTAssertEqual(b1.midY, b0.midY * 0.5, accuracy: 0.5)
        XCTAssertEqual(b1.width, b0.width * 0.5, accuracy: 1.0)
        XCTAssertEqual(b1.width / b1.height, b0.width / b0.height, accuracy: 0.05)
        // Đổi cỡ chữ: chỉ vị trí dọc theo cỡ chữ, hình nét giữ nguyên.
        let co = CoGianVietDe.bienDoi(goc, tuRong: 600, tuCo: 1, sangRong: 600, sangCo: 1.5)
        let b2 = co.strokes[0].renderBounds
        XCTAssertEqual(b2.midY, b0.midY * 1.5, accuracy: 0.5)
        XCTAssertEqual(b2.midX, b0.midX, accuracy: 0.5)
        XCTAssertEqual(b2.width, b0.width, accuracy: 0.5)
        // Cùng kích thước ⇒ trả nguyên (không tích sai số mỗi lần mở).
        XCTAssertEqual(CoGianVietDe.bienDoi(goc, tuRong: 600, tuCo: 1, sangRong: 600, sangCo: 1).dataRepresentation(),
                       goc.dataRepresentation())
    }

    /// Đi rồi về (xoay máy rồi xoay lại) ⇒ về đúng chỗ cũ.
    func testCoGianDiVeKhongLech() {
        let goc = netVuong(CGRect(x: 220, y: 18, width: 40, height: 22))
        let di = CoGianVietDe.bienDoi(goc, tuRong: 688, tuCo: 1, sangRong: 472, sangCo: 1)
        let ve = CoGianVietDe.bienDoi(di, tuRong: 472, tuCo: 1, sangRong: 688, sangCo: 1)
        let a = goc.strokes[0].renderBounds, b = ve.strokes[0].renderBounds
        XCTAssertEqual(a.midX, b.midX, accuracy: 0.5)
        XCTAssertEqual(a.midY, b.midY, accuracy: 0.5)
        XCTAssertEqual(a.width, b.width, accuracy: 0.5)
    }

    // MARK: Khoá lưu

    func testTenTepOnDinhVaKhacNhau() {
        let a = KhoVietDe.tenTep("dekiru/b3-kanji")
        XCTAssertEqual(a, KhoVietDe.tenTep("dekiru/b3-kanji"), "băm ổn định giữa các lần chạy (không dùng hashValue)")
        XCTAssertNotEqual(a, KhoVietDe.tenTep("dekiru/b3_kanji"), "hai khoá khác nhau sau khi làm sạch vẫn khác tệp")
        XCTAssertTrue(a.hasPrefix("dekiru_b3-kanji-"))
        XCTAssertFalse(KhoVietDe.tenTep("a/../../b").contains("/"))
    }

    func testKhoaVietDeTheoNguonVaBai() {
        let s = NguCanhGhi.sachHoc(khoa: "dekiru", tenKhoa: nil, baiId: "b5-kanji", soBai: 5, tieuDe: "Chữ Hán")
        XCTAssertEqual(s.khoaVietDe, "dekiru/b5-kanji")
        XCTAssertEqual(s.maMon, "JPD123")
        XCTAssertEqual(s.tieuDeBai, "Bài 5 · Chữ Hán")
        XCTAssertEqual(NguCanhGhi.sachHoc(khoa: "dekiru", tenKhoa: nil, baiId: "b2-x", soBai: 2, tieuDe: "x").maMon, "JPD113")
        XCTAssertEqual(NguCanhGhi.sachHoc(khoa: "dekiru", tenKhoa: nil, baiId: "b12-x", soBai: 12, tieuDe: "x").maMon, "DEKIRU")
        XCTAssertEqual(NguCanhGhi.sachHoc(khoa: "ielts", tenKhoa: nil, baiId: "d1", soBai: nil, tieuDe: "x").maMon, "IELTS")
        let a = NguCanhGhi.academy(slug: "front-end-web-development-with-react", courseCode: "FER202",
                                   tenKhoa: "Front-End", lessonId: 649, tieuDe: "0.1")
        XCTAssertEqual(a.maMon, "FER202")
        XCTAssertEqual(a.khoaVietDe, "front-end-web-development-with-react/649")
    }

    /// Tệp định dạng cũ / thiếu trường (bản sau thêm trường) vẫn đọc được — không mất nét.
    func testGiaiMaKhoanDung() throws {
        let json = #"{"khoi":{"n1":{"net":"","rong":688},"n2":{"rong":400,"coChu":1.15,"net":""}}}"#
        let t = try JSONDecoder().decode(TepVietDe.self, from: Data(json.utf8))
        XCTAssertEqual(t.khoi.count, 2)
        XCTAssertEqual(t.khoi["n1"]?.coChu, 1, "thiếu cỡ chữ ⇒ mặc định 1")
        XCTAssertEqual(t.khoi["n2"]?.rong, 400)
        let a = try JSONDecoder().decode([AnhDanTrang].self, from: Data(#"[{"ten":"a.png","x":10,"y":20,"rong":100,"cao":50}]"#.utf8))
        XCTAssertEqual(a.first?.khung, CGRect(x: 10, y: 20, width: 100, height: 50))
    }

    func testGhiDocVietDe() {
        let khoa = "thu/\(UUID().uuidString)"
        let d = netVuong(CGRect(x: 1, y: 2, width: 30, height: 30))
        KhoVietDe.ghi(khoa, ["n0": NetKhoiVietDe(net: d.dataRepresentation(), rong: 500, coChu: 1)])
        let doc = KhoVietDe.doc(khoa)
        XCTAssertEqual(doc["n0"]?.rong, 500)
        XCTAssertEqual(doc["n0"]?.net, d.dataRepresentation())
        KhoVietDe.ghi(khoa, [:])
        XCTAssertTrue(KhoVietDe.doc(khoa).isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: KhoVietDe.duongDan(khoa).path))
    }

    // MARK: Ảnh dán

    func testDatAnhVaoCotGhiChepCornell() {
        let kho = KhoGiay.a4.kho(.doc)
        let vung = KhoAnhDan.vungGhi(giay: .cornell, khoTrang: kho, khoGoc: kho)
        XCTAssertGreaterThan(vung.minX, kho.width * 0.3, "Cornell: ảnh vào cột Ghi chép, không vào cột gợi ý")
        // Ảnh rộng hơn cột ⇒ co lại vừa cột, giữ tỉ lệ.
        let (k, noi) = KhoAnhDan.viTriMoi(anh: CGSize(width: 800, height: 200), giay: .cornell,
                                          khoTrang: kho, khoGoc: kho, dayNoiDung: 0)
        XCTAssertEqual(k.width, vung.width, accuracy: 0.5)
        XCTAssertEqual(k.width / k.height, 4, accuracy: 0.01)
        XCTAssertEqual(k.minY, vung.minY, accuracy: 0.5)
        XCTAssertEqual(noi, 0)
        // Ảnh nhỏ ⇒ giữ đúng cỡ, đặt DƯỚI nội dung đã có.
        let (k2, _) = KhoAnhDan.viTriMoi(anh: CGSize(width: 120, height: 60), giay: .keNgang,
                                         khoTrang: kho, khoGoc: kho, dayNoiDung: 300)
        XCTAssertEqual(k2.width, 120); XCTAssertEqual(k2.minY, 312)
        // Không đủ chỗ ⇒ báo số pt cần nối dài, ảnh không bị cắt.
        let (k3, noi3) = KhoAnhDan.viTriMoi(anh: CGSize(width: 200, height: 300), giay: .cornell,
                                            khoTrang: kho, khoGoc: kho, dayNoiDung: 500)
        XCTAssertGreaterThan(noi3, 0)
        XCTAssertEqual(k3.maxY - noi3, vung.maxY, accuracy: 1.5)
    }

    func testDayNoiDung() {
        let net = netVuong(CGRect(x: 10, y: 100, width: 50, height: 40))
        let a = AnhDanTrang(ten: "x.png", khung: CGRect(x: 0, y: 300, width: 10, height: 20), nguon: nil)
        XCTAssertEqual(KhoAnhDan.dayNoiDung(net: PKDrawing(), anh: []), 0)
        XCTAssertGreaterThan(KhoAnhDan.dayNoiDung(net: net, anh: []), 139)
        XCTAssertEqual(KhoAnhDan.dayNoiDung(net: net, anh: [a]), 320)
    }

    // MARK: Trang Vở của bài

    private func khoThu() throws -> ModelContext {
        let schema = Schema([MonVo.self, CuonVo.self, TrangVo.self, ViecXoaCho.self, TienDoChu.self, TheHoiAI.self])
        let c = try ModelContainer(for: schema, configurations: [ModelConfiguration("ThuGhi", schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(c)
    }

    /// Bài kiểu sách: gọi lại ⇒ CÙNG trang; trang nằm trong cuốn "Ghi khi học" (Cornell); môn mới KHÔNG kèm cuốn
    /// "Kỳ này" trắng; trang nhớ được bài để mở lại.
    func testTrangCuaBaiSachHoc() throws {
        let kho = try khoThu()
        let ma = "ZQG\(Int.random(in: 100...999))"
        let bai = "b4-thu-\(UUID().uuidString.prefix(6))"
        let ngc = NguCanhGhi(maMon: ma, tenMon: "Thử", nguon: "dekiru", khoaBai: bai, tieuDeBai: "Bài 4 · Thử", sachHoc: true)
        let (c1, t1) = ngc.layTrang(kho: kho)
        let (c2, t2) = ngc.layTrang(kho: kho)
        XCTAssertEqual(t1.id, t2.id)
        XCTAssertEqual(c1.id, c2.id)
        XCTAssertEqual(c1.ten, "Ghi khi học")
        XCTAssertEqual(c1.giayMacDinh, LoaiGiay.cornell.rawValue)
        XCTAssertEqual(t1.tieuDe, "Bài 4 · Thử")
        XCTAssertEqual(c1.mon?.cuonsTheoThuTu.count, 1, "không để lại cuốn 'Kỳ này' trắng")
        XCTAssertEqual(VoHocKy.baiSachCuaTrang(t1)?.khoa, "dekiru")
        XCTAssertEqual(VoHocKy.baiSachCuaTrang(t1)?.baiId, bai)
        XCTAssertNil(VoHocKy.courseSlug(cho: c1), "khoá sách không được ghi thành khoá Academy")
        XCTAssertEqual(VoHocKy.trangDaCoChoBai(nguon: "dekiru", maMon: ma, khoaBai: bai, kho: kho)?.id, t1.id)
        // Bài khác ⇒ trang khác, cùng cuốn.
        var ngc2 = ngc; ngc2.khoaBai = bai + "-2"; ngc2.tieuDeBai = "Bài 4 · Thử 2"
        let (c3, t3) = ngc2.layTrang(kho: kho)
        XCTAssertNotEqual(t3.id, t1.id)
        XCTAssertEqual(c3.id, c1.id)
    }

    /// Bài Academy qua đường chuỗi = CÙNG khoá với đường số nguyên cũ (`trangChoBaiHoc(lessonId:)`).
    func testAcademyHaiDuongCungTrang() throws {
        let kho = try khoThu()
        let ma = "ZQA\(Int.random(in: 100...999))"
        let id = Int.random(in: 100_000...999_999)
        let (_, t1) = VoHocKy.trangChoBaiHoc(maMon: ma, tenMon: "Thử", courseSlug: "thu-acad", lessonId: id,
                                             tieuDeBai: "Bài thử", kho: kho)
        let (_, t2) = VoHocKy.trangChoBaiHoc(maMon: ma, tenMon: "Thử", nguon: "thu-acad", khoaBai: String(id),
                                             tieuDeBai: "Bài thử", kho: kho)
        XCTAssertEqual(t1.id, t2.id)
        XCTAssertEqual(VoHocKy.baiCuaTrang(t1)?.lessonId, id)
    }
}
