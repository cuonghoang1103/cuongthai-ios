import XCTest
@testable import CTWork

/// Kiểm thử ĐƠN VỊ của app CT Work.
///
/// Dữ liệu mẫu (`Debug/XemThuCTW.swift → DuLieuGia`) viết THEO hình dạng thật
/// của backend (đọc service). Giải mã nó bằng CHÍNH các model `Codable` của app
/// ⇒ bắt được kiểu lệch (CLAUDE.md C3/C4: một trường sai là hỏng cả màn, câm).
final class GiaiMaTests: XCTestCase {
    private func giai<T: Decodable>(_ kieu: T.Type, _ path: String, method: String = "GET",
                                    file: StaticString = #filePath, line: UInt = #line) throws -> T {
        let d = DuLieuGia.traLoi(method: method, path: "/api/v1" + path, body: [:])
        let r = try JSONDecoder().decode(APIResponse<T>.self, from: d)
        XCTAssertTrue(r.success, file: file, line: line)
        return try XCTUnwrap(r.data, file: file, line: line)
    }

    func testCauHinhDuAn() throws {
        let c = try giai(CTWProjectConfig.self, "/work/projects/7")
        XCTAssertEqual(c.key, "NW")
        XCTAssertEqual(c.boardColumns?.count, 4)
        XCTAssertTrue(c.coTheSua)
        XCTAssertTrue(c.coQuyen("attach"))
        XCTAssertFalse(c.coQuyen("viewFinance"))
        XCTAssertTrue(c.batMoDun("docs"), "thiếu khoá modules ⇒ coi là bật")
        XCTAssertEqual(c.dsThanhVien.filter(\.laAgent).map(\.ten), ["Scout"])
    }

    func testCoQuyenVaMoDunKhoanDung() throws {
        let json = #"{"id":1,"key":"A","name":"A","permissions":{"editIssues":true,"viewFinance":false,"weird":"x"},"modules":{"docs":false,"finance":true,"bad":3}}"#
        let c = try JSONDecoder().decode(CTWProjectConfig.self, from: Data(json.utf8))
        XCTAssertTrue(c.coTheSua)
        XCTAssertFalse(c.coQuyen("viewFinance"))
        XCTAssertFalse(c.batMoDun("docs"))
        XCTAssertTrue(c.batMoDun("finance"))
        XCTAssertNil(c.modules?["bad"], "giá trị không phải bool bị bỏ qua, không làm hỏng cả cấu hình")
    }

    func testBangBacklogDanhSach() throws {
        let b = try giai(CTWBoardData.self, "/work/projects/7/board")
        XCTAssertEqual(b.sprint?.state, "ACTIVE")
        XCTAssertFalse((b.issues ?? []).isEmpty)
        let bl = try giai(CTWBacklog.self, "/work/projects/7/backlog")
        XCTAssertEqual(bl.sprints?.count, 2)
        XCTAssertTrue((bl.issues ?? []).contains { $0.sprintId == nil })
        let ds = try giai(CTWIssueList.self, "/work/projects/7/issues")
        XCTAssertEqual(ds.items?.count, ds.total)
    }

    func testChiTietThe() throws {
        let t = try giai(CTWIssueDetail.self, "/work/projects/7/issues/12")
        XCTAssertEqual(t.number, 12)
        XCTAssertEqual(t.attachments?.count, 2)
        XCTAssertEqual(t.attachments?.last?.uploader?.laAgent, true)
        let khoi = CTWTipTap.khoi(t.descriptionJson)
        XCTAssertTrue(khoi.contains { if case .tieuDe = $0 { return true }; return false })
        XCTAssertTrue(khoi.contains { if case .viec(_, let xong, _) = $0 { return xong }; return false })
        XCTAssertTrue(khoi.contains { if case .ma = $0 { return true }; return false })
        let bl = try giai([CTWComment].self, "/work/projects/7/issues/12/comments")
        XCTAssertEqual(bl.count, 4)
        XCTAssertTrue(bl.contains { $0.author?.laAgent == true })
        let ls = try giai([CTWHistory].self, "/work/projects/7/issues/12/history")
        let cfg = try giai(CTWProjectConfig.self, "/work/projects/7")
        XCTAssertEqual(CTWLichSu.moTa(ls[0], cfg: cfg), "moved from To Do to In Progress")
    }

    func testChatTaiLieuThongBao() throws {
        let k = try giai(CTWChannelList.self, "/work/projects/7/chat/channels")
        XCTAssertEqual(k.channels?.first?.name, "general")
        let p = try giai(CTWChatPage.self, "/work/projects/7/chat/channels/1/messages")
        XCTAssertEqual(p.messages?.first?.laHeThong, true)
        XCTAssertTrue((p.messages ?? []).contains { $0.author?.laAgent == true })
        let tr = try giai(CTWPagesList.self, "/work/projects/7/pages")
        XCTAssertEqual(tr.pages?.count, 6)
        let md = try giai(CTWPageMarkdown.self, "/work/projects/7/pages/3/markdown")
        XCTAssertTrue(md.markdown?.hasPrefix("# Release plan") == true)
        let tb = try giai(NotificationsResponse.self, "/social/notifications")
        XCTAssertTrue(tb.items.allSatisfy { $0.type.hasPrefix("WORK_") })
        XCTAssertNotNil(tb.items.first?.payload?.url)
    }

    func testViecCuaToi() throws {
        let m = try giai(CTWMyWork.self, "/work/me/work")
        XCTAssertEqual(m.counts?.overdue, 1)
        XCTAssertEqual(m.items?.first?.bucket, "overdue")
    }

    /// Tin chat: mảng phụ hỏng KHÔNG làm hỏng cả tin.
    func testTinChatKhoanDung() throws {
        let json = #"{"id":5,"kind":"USER","body":"hi","reactions":"oops","files":[{"bad":1}],"author":{"id":2,"username":"a","kind":"AGENT"}}"#
        let m = try JSONDecoder().decode(CTWChatMessage.self, from: Data(json.utf8))
        XCTAssertEqual(m.body, "hi")
        XCTAssertNil(m.reactions)
        XCTAssertEqual(m.author?.laAgent, true)
    }
}

final class DuongDanTests: XCTestCase {
    func testTachDuongDan() throws {
        let a = try XCTUnwrap(DuongDanCTW.tach("/work/northwind/NW/issue/12?comment=3"))
        XCTAssertEqual(a.slug, "northwind"); XCTAssertEqual(a.maDuAn, "NW")
        XCTAssertEqual(a.doan, "issue"); XCTAssertEqual(a.phanCon, ["12"]); XCTAssertEqual(a.tham["comment"], "3")
        let b = try XCTUnwrap(DuongDanCTW.tach("https://cuongthai.com/work/ws/KEY/chat?c=4&m=99#x"))
        XCTAssertEqual(b.doan, "chat"); XCTAssertEqual(b.tham["c"], "4"); XCTAssertEqual(b.tham["m"], "99")
        let c = try XCTUnwrap(DuongDanCTW.tach("/work/my%20ws"))
        XCTAssertEqual(c.slug, "my ws"); XCTAssertNil(c.maDuAn)
        XCTAssertNil(DuongDanCTW.tach("/blog/abc"))
        XCTAssertNil(DuongDanCTW.tach("/work/"))
    }

    func testDichCu() {
        let d = CTWDich.tuDuongDan("/work/northwind/NW/issue/12?comment=2")
        XCTAssertEqual(d?.so, 12)
        XCTAssertEqual(d?.maDuAn, "NW")
    }
}

final class MarkdownTests: XCTestCase {
    func testKhoi() {
        let k = CTWMarkdown.khoi("""
        # Title
        Para **bold**
        - item
          - nested
        - [x] done
        1. one
        | A | B |
        | --- | --- |
        | 1 | 2 |
        > quote
        ```
        code
        ```
        ---
        ![alt](/api/v1/work/projects/1/images/2)
        """)
        func co(_ f: (CTWKhoi) -> Bool) -> Bool { k.contains(where: f) }
        XCTAssertTrue(co { if case .tieuDe(_, 1) = $0 { return true }; return false })
        XCTAssertTrue(co { if case .muc(_, "•", 1) = $0 { return true }; return false })
        XCTAssertTrue(co { if case .viec(_, true, _) = $0 { return true }; return false })
        XCTAssertTrue(co { if case .muc(_, "1.", _) = $0 { return true }; return false })
        XCTAssertTrue(co { if case .bang(let h) = $0 { return h.count == 2 }; return false }, "dòng kẻ | --- | bị bỏ")
        XCTAssertTrue(co { if case .trichDan = $0 { return true }; return false })
        XCTAssertTrue(co { if case .ma("code") = $0 { return true }; return false })
        XCTAssertTrue(co { if case .ke = $0 { return true }; return false })
        XCTAssertTrue(co { if case .anh(let s, "alt") = $0 { return s.hasPrefix("/api/") }; return false })
    }
}

@MainActor
final class DangKyMoDunTests: XCTestCase {
    func testIdVaDoanWebKhongTrung() {
        let ds = CTWDangKyMoDun.dangKyMoDun
        XCTAssertEqual(Set(ds.map(\.id)).count, ds.count, "id mô-đun trùng")
        let doan = ds.compactMap(\.doanWeb)
        XCTAssertEqual(Set(doan).count, doan.count, "hai mô-đun nhận cùng một đoạn đường dẫn")
        XCTAssertFalse(doan.contains("issue"), "`issue` là của lõi")
    }

    func testAnMoDunTheoDuAn() throws {
        let json = #"{"id":1,"key":"A","name":"A","modules":{"docs":false}}"#
        let c = try JSONDecoder().decode(CTWProjectConfig.self, from: Data(json.utf8))
        XCTAssertFalse(CTWDangKyMoDun.hienDuoc(c).contains { $0.id == "docs" })
        XCTAssertTrue(CTWDangKyMoDun.hienDuoc(nil).contains { $0.id == "docs" })
        XCTAssertEqual(CTWDangKyMoDun.moDun(choDoan: "chat")?.id, "chat")
    }

    func testChiMotTabRieng() {
        // iPhone tối đa 5 tab: My Work · Projects · [tab riêng] · Inbox · Account.
        XCTAssertLessThanOrEqual(CTWDangKyMoDun.dangKyMoDun.filter { $0.viTriIPhone == .tabRieng }.count, 1)
    }
}
