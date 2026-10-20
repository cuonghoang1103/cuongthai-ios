import XCTest
@testable import CTWork

/// Mảng A (20/10/2026) — sửa thẻ: mô tả TipTap ⇄ Markdown, tick ô việc giữ nguyên JSON, model trường/giá trị tuỳ chỉnh,
/// thời lượng, và giải mã dữ liệu mẫu (`Debug/XemThuCTW+SuaThe.swift`, hình dạng theo `issues.service.ts`,
/// `custom.service.ts`, `getProject`) bằng chính model của app.
final class SuaTheCTWTests: XCTestCase {
    private func du(_ path: String, method: String = "GET", body: [String: Any] = [:]) -> Data {
        DuLieuGia.traLoi(method: method, path: "/api/v1" + path, body: body)
    }

    private func giai<T: Decodable>(_ kieu: T.Type, _ path: String, method: String = "GET", body: [String: Any] = [:]) throws -> T {
        try CTWAPI.giaiMa(T.self, du(path, method: method, body: body))
    }

    private var moTaMau: CTWJSON { CTWJSON(DuLieuGia.chiTiet(so: 12, tieuDe: nil)["descriptionJson"]) }

    // MARK: Giải mã

    func testChiTietTheHaiModelCungMotPhanHoi() throws {
        let d = du("/work/projects/7/issues/12")
        let t = try CTWAPI.giaiMa(CTWIssueDetail.self, d)
        let x = try CTWAPI.giaiMa(CTWIssueThem.self, d)
        XCTAssertEqual(t.number, 12)
        XCTAssertEqual(x.fixVersionId, 2)
        XCTAssertEqual(x.componentIds, [1])
        XCTAssertEqual(x.originalEstimateMin, 480)
        XCTAssertEqual(x.timeSpentMin, 270)
        XCTAssertEqual(x.teamId, 1)
        XCTAssertEqual(x.version, 3)
        XCTAssertNotNil(x.descriptionJson?["content"]?.mang, "mô tả THÔ phải còn nguyên để ghi lại")
        XCTAssertEqual(t.parent?.number, 5)
    }

    func testCauHinhThem() throws {
        let c = try giai(CTWCauHinhThem.self, "/work/projects/7")
        XCTAssertFalse(c.theoGio)
        XCTAssertEqual(c.versions?.count, 3)
        XCTAssertEqual(c.components?.map(\.name), ["Notifications", "Chat", "Offline"])
        let f = try XCTUnwrap(c.customFields)
        XCTAssertEqual(f.count, 9)
        XCTAssertEqual(Set(f.map(\.kind)), ["TEXT", "NUMBER", "DATE", "SELECT", "MULTISELECT", "USER", "URL", "CHECKBOX"])
        let rootCause = try XCTUnwrap(f.first { $0.id == 9 })
        XCTAssertTrue(rootCause.apCho(loai: "BUG"))
        XCTAssertFalse(rootCause.apCho(loai: "STORY"), "typeKeys giới hạn loại thẻ")
        XCTAssertTrue(f[0].apCho(loai: "TASK"), "typeKeys null = mọi loại")
        // Cấu hình lõi vẫn giải mã được khi có thêm trường.
        XCTAssertEqual(try giai(CTWProjectConfig.self, "/work/projects/7").key, "NW")
    }

    func testGiaTriTruongTuyChinhTheoKieu() throws {
        let v = try giai(CTWGiaTriTruongThe.self, "/work/projects/7/issues/12/custom-values")
        XCTAssertEqual(v.tatCa[1], .chu("ios"))
        XCTAssertEqual(v.tatCa[2], .so(420))
        XCTAssertEqual(v.tatCa[4], .co(true))
        XCTAssertEqual(v.tatCa[5], .nhieu(["iphone15", "iphone17"]))
        XCTAssertEqual(v.tatCa[6]?.so, 4)
        XCTAssertNil(v.tatCa[7])
        // Thân PUT: một trường; xoá = null; số nguyên giữ Int.
        let xoa = CTWGiaTriTruong.than(truong: 3, nil)
        XCTAssertTrue((xoa["values"] as? [String: Any])?["3"] is NSNull)
        let so = CTWGiaTriTruong.than(truong: 2, .so(5))
        XCTAssertEqual((so["values"] as? [String: Any])?["2"] as? Int, 5)
        let json = try JSONSerialization.data(withJSONObject: CTWGiaTriTruong.than(truong: 5, .nhieu(["a", "b"])))
        XCTAssertEqual(String(data: json, encoding: .utf8), #"{"values":{"5":["a","b"]}}"#)
    }

    func testPatchGhiNhoVaTangPhienBan() throws {
        let t = try giai(CTWIssueThem.self, "/work/projects/7/issues/17", method: "PATCH", body: ["storyPoints": 13, "version": 3])
        XCTAssertEqual(t.version, 4)
        let lai = try giai(CTWIssueDetail.self, "/work/projects/7/issues/17")
        XCTAssertEqual(lai.storyPoints, 13)
    }

    // MARK: Mô tả: TipTap → Markdown

    func testTipTapRaMarkdown() {
        let md = CTWMoTaThe.markdown(moTaMau)
        XCTAssertTrue(md.contains("must open **exactly** the issue"), md)
        XCTAssertTrue(md.contains("### Acceptance criteria"), md)
        XCTAssertTrue(md.contains("- [x] Tap on an assignment opens the issue"), md)
        XCTAssertTrue(md.contains("- [ ] Works when the app was force-quit"), md)
        XCTAssertTrue(md.contains("```\nctwork://work/northwind/NW/issue/12\n```"), md)
    }

    func testVongTronMarkdownOnDinh() {
        let md1 = CTWMoTaThe.markdown(moTaMau)
        let md2 = CTWMoTaThe.markdown(CTWMoTaThe.doc(md1))
        XCTAssertEqual(md1, md2, "markdown ⇒ TipTap ⇒ markdown phải không đổi")
        let phucTap = """
        # Title

        Intro with **bold**, _italic_, ~~gone~~, `code` and [a link](https://cuongthai.com/work).
        Second line of the same section\\
        after a hard break.

        1. First
        2. Second
           - nested bullet
           - [x] nested done

        > Quoted **text**

        ---

        ![diagram](/api/v1/work/projects/7/images/3)
        """
        let a = CTWMoTaThe.markdown(CTWMoTaThe.doc(phucTap))
        XCTAssertEqual(CTWMoTaThe.markdown(CTWMoTaThe.doc(a)), a)
        XCTAssertTrue(a.contains("[a link](https://cuongthai.com/work)"), a)
        XCTAssertTrue(a.contains("   - [x] nested done"), a)
        XCTAssertTrue(a.contains("> Quoted **text**"), a)
        XCTAssertTrue(a.contains("![diagram](/api/v1/work/projects/7/images/3)"), a)
    }

    // MARK: Mô tả: Markdown → TipTap

    func testMarkdownRaDauChu() {
        let n = CTWMoTaThe.chuNoi("a **b** _c_ ~~d~~ `e` [f](https://x.y)")
        func dau(_ chu: String) -> [String] {
            (n.first { $0["text"]?.chuoi == chu }?["marks"]?.mang ?? []).compactMap { $0["type"]?.chuoi }
        }
        XCTAssertEqual(dau("b"), ["bold"])
        XCTAssertEqual(dau("c"), ["italic"])
        XCTAssertEqual(dau("d"), ["strike"])
        XCTAssertEqual(dau("e"), ["code"])
        XCTAssertEqual(dau("f"), ["link"])
        let link = n.first { $0["text"]?.chuoi == "f" }?["marks"]?.mang?.first
        XCTAssertEqual(link?["attrs"]?["href"]?.chuoi, "https://x.y")
    }

    func testGachDuoiTrongTuKhongThanhNghieng() {
        let n = CTWMoTaThe.chuNoi("set user_id and order_id, 5 * 3 = 15")
        XCTAssertEqual(n.count, 1)
        XCTAssertEqual(n.first?["text"]?.chuoi, "set user_id and order_id, 5 * 3 = 15")
        XCTAssertNil(n.first?["marks"])
        // Dấu đã thoát giữ nguyên chữ.
        XCTAssertEqual(CTWMoTaThe.chuNoi(#"a \*not bold\* b"#).first?["text"]?.chuoi, "a *not bold* b")
        let md = CTWMoTaThe.markdown(CTWMoTaThe.doc("price *5"))
        XCTAssertEqual(CTWMoTaThe.chuNoi(md).first?["text"]?.chuoi, "price *5", "dấu * trơn thoát khi xuất")
    }

    func testDanhSachViecVaDanhSachSo() throws {
        let d = CTWMoTaThe.doc("- [ ] one\n- [x] two\n\n3. three\n4. four")
        let khoi = try XCTUnwrap(d["content"]?.mang)
        XCTAssertEqual(khoi.map { $0["type"]?.chuoi }, ["taskList", "orderedList"])
        XCTAssertEqual(khoi[0]["content"]?.mang?.map { $0["attrs"]?["checked"]?.bool }, [false, true])
        XCTAssertEqual(khoi[1]["attrs"]?["start"]?.so, 3)
        XCTAssertEqual((d.any as? [String: Any]).flatMap { (($0["content"] as? [[String: Any]])?[1]["attrs"] as? [String: Any])?["start"] as? Int }, 3,
                       "số nguyên gửi đi là Int, không phải 3.0")
    }

    func testMoTaTrong() {
        XCTAssertTrue(CTWMoTaThe.trong(nil))
        XCTAssertTrue(CTWMoTaThe.trong(CTWMoTaThe.doc("")))
        XCTAssertFalse(CTWMoTaThe.trong(CTWMoTaThe.doc("x")))
        XCTAssertFalse(CTWMoTaThe.trong(CTWMoTaThe.doc("- [ ] ")), "ô việc trống của mẫu vẫn là nội dung")
    }

    // MARK: Tick ô việc

    func testDoiViecGiuNguyenPhanKhac() throws {
        let goc = moTaMau
        XCTAssertEqual(CTWMoTaThe.soViec(goc), 3)
        let moi = try XCTUnwrap(CTWMoTaThe.doiViec(goc, chiSo: 2))
        let viec = try XCTUnwrap(moi["content"]?.mang?[2]["content"]?.mang)
        XCTAssertEqual(viec.map { $0["attrs"]?["checked"]?.bool }, [true, true, true])
        // Dấu đậm, khối mã, tiêu đề còn nguyên.
        XCTAssertEqual(moi["content"]?.mang?[0], goc["content"]?.mang?[0])
        XCTAssertEqual(moi["content"]?.mang?[3], goc["content"]?.mang?[3])
        XCTAssertEqual(CTWMoTaThe.doiViec(moi, chiSo: 2).flatMap { CTWMoTaThe.doiViec($0, chiSo: 2) }, moi)
        XCTAssertNil(CTWMoTaThe.doiViec(goc, chiSo: 9), "chỉ số ngoài khoảng ⇒ không đổi gì")
    }

    func testChiSoViecKhopBoDung() {
        let khoi = CTWTipTap.khoi(moTaMau.nut)
        let soHien = khoi.filter { if case .viec = $0 { return true }; return false }.count
        XCTAssertEqual(soHien, CTWMoTaThe.soViec(moTaMau), "ô việc hiển thị và ô việc trong JSON phải cùng thứ tự")
        XCTAssertEqual(CTWIssueMoTaView.chiSoViec(khoi).values.sorted(), [0, 1, 2])
        // Ô việc trong trích dẫn không tick được ⇒ không đếm.
        let q = CTWMoTaThe.doc("> - [ ] quoted\n\n- [ ] real")
        XCTAssertEqual(CTWMoTaThe.soViec(q), 1)
    }

    func testKhongChoSuaKhiMatNoiDung() {
        let nhac = CTWJSON(["type": "doc", "content": [["type": "paragraph", "content": [["type": "mention", "attrs": ["id": 2, "label": "linh"]]]]]])
        XCTAssertNotNil(CTWMoTaThe.lyDoKhongSua(nhac))
        let bang = CTWJSON(["type": "doc", "content": [["type": "table", "content": [Any]()]]])
        XCTAssertNotNil(CTWMoTaThe.lyDoKhongSua(bang))
        let mau = CTWJSON(["type": "doc", "content": [["type": "paragraph", "content": [["type": "text", "text": "x", "marks": [["type": "highlight"]]]]]]])
        XCTAssertNotNil(CTWMoTaThe.lyDoKhongSua(mau))
        XCTAssertNil(CTWMoTaThe.lyDoKhongSua(moTaMau))
        XCTAssertNil(CTWMoTaThe.lyDoKhongSua(nil))
    }

    // MARK: Khác

    func testThoiLuong() {
        XCTAssertEqual(CTWThoiLuong.doc("1h 30m"), 90)
        XCTAssertEqual(CTWThoiLuong.doc("1.5h"), 90)
        XCTAssertEqual(CTWThoiLuong.doc("1d"), 480)
        XCTAssertEqual(CTWThoiLuong.doc("45"), 45)
        XCTAssertNil(CTWThoiLuong.doc("abc"))
        XCTAssertNil(CTWThoiLuong.doc("2x"))
        XCTAssertEqual(CTWThoiLuong.chu(90), "1h 30m")
        XCTAssertEqual(CTWThoiLuong.chu(120), "2h")
        XCTAssertEqual(CTWThoiLuong.chu(nil), "0m")
    }

    func testJSONKhongMatKieu() throws {
        let j = CTWJSON(["a": true, "b": 3, "c": 2.5, "d": NSNull(), "e": ["x"]])
        XCTAssertEqual(j["a"], .bool(true))
        XCTAssertEqual(j["b"], .so(3))
        let lai = try JSONDecoder().decode(CTWJSON.self, from: JSONEncoder().encode(j))
        XCTAssertEqual(lai, j)
        let any = try XCTUnwrap(j.any as? [String: Any])
        XCTAssertEqual(any["b"] as? Int, 3)
        XCTAssertEqual(any["a"] as? Bool, true)
        XCTAssertTrue(any["d"] is NSNull)
    }

    func testMauMoTaVaTheTuongTu() throws {
        let m = try giai([CTWMauMoTa].self, "/work/projects/7/issue-templates")
        XCTAssertEqual(m.count, 3)
        let story = try XCTUnwrap(m.first { $0.typeKey == "STORY" })
        XCTAssertTrue(CTWMoTaThe.markdown(story.doc).contains("### Acceptance criteria"))
        XCTAssertTrue(CTWMoTaThe.trong(m.first { $0.typeKey == "TASK" }?.doc))
        let s = try giai([CTWTheTuongTu].self, "/work/projects/7/similar", body: ["title": "notifications open issue"])
        XCTAssertEqual(s.first?.number, 12)
    }

    func testLienKetWebTaiLieuNhatKy() throws {
        XCTAssertEqual(try giai(CTWDsLienKetWeb.self, "/work/projects/7/issues/12/web-links").items?.first?.id, 1)
        XCTAssertEqual(try giai(CTWTrangCuaThe.self, "/work/projects/7/issues/12/pages").pages?.first?.number, 3)
        let w = try giai([CTWWorklogThe].self, "/work/projects/7/issues/12/worklogs")
        XCTAssertFalse(w.isEmpty)
        XCTAssertNotNil(w.first?.minutes)
        XCTAssertFalse(try giai([CTWTeamRef].self, "/work/workspaces/1/teams").isEmpty)
        XCTAssertFalse(try giai([CTWStageRef].self, "/work/projects/7/stages").isEmpty)
        let ws = try giai(CTWKhongGianDuAn.self, "/work/workspaces/by-slug/northwind")
        XCTAssertEqual(ws.projects?.map(\.key), ["NW", "WEB"])
    }
}
