import XCTest
@testable import CTWork

/// Mô-đun Docs (mảng C): giải mã dữ liệu mẫu đúng hình dạng `pages.service.ts`
/// + logic sửa trang an toàn (giao thức chống ghi đè, soát nội dung giữ được).
final class DocsCTWTests: XCTestCase {
    private func du(_ path: String, method: String = "GET") throws -> Data {
        DuLieuGia.traLoi(method: method, path: "/api/v1" + path, body: [:])
    }
    private func giai<T: Decodable>(_ kieu: T.Type, _ path: String, method: String = "GET") throws -> T {
        let r = try JSONDecoder().decode(APIResponse<T>.self, from: try du(path, method: method))
        XCTAssertTrue(r.success)
        return try XCTUnwrap(r.data)
    }
    private func contentJsonTho(_ so: Int) throws -> Any? {
        let o = try JSONSerialization.jsonObject(with: try du("/work/projects/7/pages/\(so)")) as? [String: Any]
        return (o?["data"] as? [String: Any])?["contentJson"]
    }

    // MARK: Giải mã

    func testGiaiMaDanhSachVaChiTiet() throws {
        let ds = try giai(CTWPagesList.self, "/work/projects/7/pages")
        XCTAssertEqual(ds.canManage, true)
        XCTAssertEqual(ds.pages?.first { $0.number == 3 }?.visibility, "CLIENT")
        let t = try giai(CTWPageDetail.self, "/work/projects/7/pages/3")
        XCTAssertEqual(t.version, 14)
        XCTAssertEqual(t.issues?.map(\.key), ["NW-12", "NW-19"])
        XCTAssertEqual(t.approval?.status, "APPROVED")
        XCTAssertEqual(t.canComment, true)
        XCTAssertNotNil(t.contentJson)
    }

    func testGiaiMaPhienBanBinhLuanKbThungRac() throws {
        let v = try giai([CTWPageVersion].self, "/work/projects/7/pages/3/versions")
        XCTAssertEqual(v.first?.n, 9)
        XCTAssertEqual(v.first(where: { $0.kind == "MANUAL" })?.note, "Before store review")
        let mot = try giai(CTWPageVersion.self, "/work/projects/7/pages/3/versions/7")
        XCTAssertFalse(CTWTipTap.khoi(mot.contentJson).isEmpty)
        let ss = try giai(CTWPageCompare.self, "/work/projects/7/pages/3/versions/compare")
        XCTAssertEqual(ss.added, 2)
        XCTAssertEqual(ss.lines?.filter { $0.op == "del" }.count, 1)
        let bl = try giai([CTWPageComment].self, "/work/projects/7/pages/3/comments")
        XCTAssertEqual(bl.last?.author?.laAgent, true, "bình luận của agent phải nhận ra để gắn nhãn AI")
        let kb = try giai(CTWKb.self, "/work/projects/7/kb")
        XCTAssertEqual(kb.articles?.count, 2)
        XCTAssertNil(kb.articles?.last?.helpfulPercent)
        let rac = try giai(CTWTrashPages.self, "/work/projects/7/trash/pages")
        XCTAssertEqual(rac.items?.first?.canRestore, true)
        let anh = try giai(CTWAnhTaiLieu.self, "/work/projects/7/images", method: "POST")
        XCTAssertTrue(anh.url.hasPrefix("/api/v1/work/projects/7/images/"))
    }

    // MARK: Soát nội dung giữ được qua Markdown

    func testTrangThuongSuaDuocTrangCoNhacTenThiKhong() throws {
        XCTAssertNil(CTWSuaTrang.lyDoKhongSuaDuoc(try contentJsonTho(3)))
        XCTAssertNotNil(CTWSuaTrang.lyDoKhongSuaDuoc(try contentJsonTho(5)))
        XCTAssertNil(CTWSuaTrang.lyDoKhongSuaDuoc(nil), "trang trống sửa được")
    }

    func testNhungThuMarkdownLamMat() {
        func doc(_ c: [Any]) -> [String: Any] { ["type": "doc", "content": c] }
        let neo: [String: Any] = ["type": "paragraph", "content": [["type": "text", "text": "x", "marks": [["type": "commentAnchor", "attrs": ["id": "abc123"]]]]]]
        XCTAssertNotNil(CTWSuaTrang.lyDoKhongSuaDuoc(doc([neo])))
        let gach: [String: Any] = ["type": "paragraph", "content": [["type": "text", "text": "x", "marks": [["type": "underline"]]]]]
        XCTAssertNotNil(CTWSuaTrang.lyDoKhongSuaDuoc(doc([gach])))
        let oGop: [String: Any] = ["type": "table", "content": [["type": "tableRow", "content": [
            ["type": "tableCell", "attrs": ["colspan": 2], "content": [["type": "paragraph"]]]]]]]
        XCTAssertNotNil(CTWSuaTrang.lyDoKhongSuaDuoc(doc([oGop])))
        let oNhieuDong: [String: Any] = ["type": "table", "content": [["type": "tableRow", "content": [
            ["type": "tableCell", "content": [["type": "paragraph"], ["type": "bulletList"]]]]]]]
        XCTAssertNotNil(CTWSuaTrang.lyDoKhongSuaDuoc(doc([oNhieuDong])))
        let la: [String: Any] = ["type": "youtube"]
        XCTAssertNotNil(CTWSuaTrang.lyDoKhongSuaDuoc(doc([la])))
        let duoc: [String: Any] = ["type": "codeBlock", "attrs": ["language": "mermaid"], "content": [["type": "text", "text": "graph TD"]]]
        XCTAssertNil(CTWSuaTrang.lyDoKhongSuaDuoc(doc([duoc, ["type": "horizontalRule"], ["type": "image", "attrs": ["src": "/api/v1/work/projects/7/images/1"]]])))
    }

    // MARK: Giao thức lưu (bước 2)

    func testKiemTruocKhiGhi() async throws {
        var goi = 0
        let cung = try await CTWSuaTrang.kiemTruocKhiGhi(v0: 14, vNay: 14, md0: "a") { goi += 1; return "b" }
        XCTAssertEqual(cung, .ghiDuoc)
        XCTAssertEqual(goi, 0, "cùng phiên bản ⇒ không cần tải markdown")
        let chiNhich = try await CTWSuaTrang.kiemTruocKhiGhi(v0: 14, vNay: 15, md0: "# T\n\nabc  \n") { "# T\n\nabc\n" }
        XCTAssertEqual(chiNhich, .ghiDuoc, "bộ đếm nhích nhưng nội dung y nguyên (lần lưu trước của chính mình) ⇒ không phải xung đột")
        let khac = try await CTWSuaTrang.kiemTruocKhiGhi(v0: 14, vNay: 15, md0: "abc") { "abc\nthêm dòng của người khác" }
        XCTAssertEqual(khac, .xungDot)
    }

    func testBoTieuDeVaLienKetThe() {
        XCTAssertEqual(CTWSuaTrang.boTieuDe("# Plan\n\nBody", tieuDe: "Plan"), "Body")
        XCTAssertEqual(CTWSuaTrang.boTieuDe("# Other\n\nBody", tieuDe: "Plan"), "# Other\n\nBody", "H1 khác tiêu đề thì giữ")
        XCTAssertEqual(CTWSuaTrang.lienKetThe(slug: "northwind", maDuAn: "NW", so: 12, tieuDe: "Fix [iOS]"),
                       "[NW-12 Fix (iOS)](/work/northwind/NW/issue/12)")
        // Liên kết đó đi đúng bộ tách đường dẫn ⇒ app mở thẻ ngay trong app.
        let d = DuongDanCTW.tach("/work/northwind/NW/issue/12")
        XCTAssertEqual(d?.doan, "issue")
        XCTAssertEqual(d?.phanCon.first, "12")
    }

    func testTrangThaiChuyenDuoc() {
        XCTAssertEqual(CTWDocStatus.dich(tu: "ARCHIVED", duyetBat: false, quanLy: true), ["DRAFT"])
        XCTAssertEqual(CTWDocStatus.dich(tu: "DRAFT", duyetBat: true, quanLy: true), ["ARCHIVED"], "bật phê duyệt ⇒ không đặt tay IN_REVIEW/APPROVED")
        XCTAssertEqual(CTWDocStatus.dich(tu: "DRAFT", duyetBat: false, quanLy: false), ["IN_REVIEW", "ARCHIVED"])
        XCTAssertEqual(CTWDocStatus.dich(tu: "IN_REVIEW", duyetBat: false, quanLy: true), ["DRAFT", "APPROVED", "ARCHIVED"])
    }

    // MARK: Cây trang + trình soạn

    func testCayVaHauDue() throws {
        let ds = try giai(CTWPagesList.self, "/work/projects/7/pages").pages ?? []
        let cay = TaiLieuVM.dungCay(ds)
        XCTAssertFalse(cay.contains { $0.trang.status == "ARCHIVED" })
        XCTAssertEqual(cay.first { $0.trang.number == 5 }?.sau, 2)
        let cam = TaiLieuVM.hauDue(1, trong: ds)
        XCTAssertEqual(cam, [1, 3, 5], "không được chuyển 'Product' vào trang con/cháu của nó")
    }

    func testBoTienToKhoi() {
        XCTAssertEqual(CTWBoSoan.boTienToKhoi("## Title"), "Title")
        XCTAssertEqual(CTWBoSoan.boTienToKhoi("- [ ] task"), "task")
        XCTAssertEqual(CTWBoSoan.boTienToKhoi("12. item"), "item")
        XCTAssertEqual(CTWBoSoan.boTienToKhoi("plain 1. text"), "plain 1. text")
    }
}
