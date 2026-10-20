import XCTest
@testable import CTWork

/// Trợ lý AI bản stream — bộ đọc SSE + giải nghĩa sự kiện + quyết định lùi về `/ai/chat` (hợp đồng `docs/ctw-ai-stream.md`).
final class LuongAITests: XCTestCase {
    private func doc(_ manh: [String]) -> [KhungSSE] {
        var bo = BoDocSSE()
        var ra: [KhungSSE] = []
        for m in manh { ra += bo.nap(Data(m.utf8)) }
        return ra + bo.ketThuc()
    }

    func testKhungDonVaTenSuKien() {
        let k = doc(["event: progress\ndata: {\"type\":\"progress\",\"phase\":\"thinking\",\"round\":1}\n\n"])
        XCTAssertEqual(k, [KhungSSE(suKien: "progress", duLieu: "{\"type\":\"progress\",\"phase\":\"thinking\",\"round\":1}")])
        XCTAssertEqual(SuKienAICTW.tu(k[0]), .nghi(vong: 1))
    }

    func testCatGiuaChungKeCaGiuaKyTuUTF8() {
        let toan = Data("event: delta\ndata: {\"type\":\"delta\",\"text\":\"Việc gấp — LFD-75\"}\n\n".utf8)
        // Cắt từng 3 byte: rơi giữa "ệ"/"ấ" (3 byte UTF-8) và giữa "data:" với JSON.
        var bo = BoDocSSE()
        var ra: [KhungSSE] = []
        var i = toan.startIndex
        while i < toan.endIndex {
            let j = toan.index(i, offsetBy: 3, limitedBy: toan.endIndex) ?? toan.endIndex
            ra += bo.nap(toan[i..<j])
            i = j
        }
        XCTAssertEqual(ra.count, 1)
        XCTAssertEqual(SuKienAICTW.tu(ra[0]), .manh("Việc gấp — LFD-75"))
    }

    func testNhieuDongDataVaCRLF() {
        let k = doc(["data: {\"type\":\"delta\",\r\n", "data: \"text\":\"a\"}\r\n\r\n"])
        XCTAssertEqual(k.count, 1)
        XCTAssertEqual(k[0].duLieu, "{\"type\":\"delta\",\n\"text\":\"a\"}")
        XCTAssertEqual(SuKienAICTW.tu(k[0]), .manh("a"))
    }

    func testPingRetryVaDongTrongThuaBiBoQua() {
        let k = doc([": ping\n\n", "retry: 5000\n\n\n", ":\n", "data: {\"type\":\"reset\"}\n\n"])
        XCTAssertEqual(k.count, 1)
        XCTAssertEqual(SuKienAICTW.tu(k[0]), .xoaNhap)
    }

    func testKhungCuoiKhongCoDongTrongVanDuocNha() {
        let k = doc(["data: {\"type\":\"error\",\"code\":\"WORK_AI_BAD_OUTPUT\",\"message\":\"x\",\"status\":502}"])
        XCTAssertEqual(k.count, 1)
        XCTAssertEqual(SuKienAICTW.tu(k[0]), .loi(ma: "WORK_AI_BAD_OUTPUT", thongDiep: "x", trangThai: 502))
    }

    func testGiaiNghiaProgress() {
        let chuanBi = KhungSSE(suKien: nil, duLieu: "{\"type\":\"progress\",\"phase\":\"preparing\",\"threadId\":34,\"questionId\":901}")
        XCTAssertEqual(SuKienAICTW.tu(chuanBi), .chuanBi(threadId: 34, questionId: 901))
        let doc = KhungSSE(suKien: "progress", duLieu: "{\"type\":\"progress\",\"phase\":\"reading\",\"round\":0,\"items\":[\"LFD-75\",\"Docs #3 — How to run LFD\"],\"prefetched\":true}")
        XCTAssertEqual(SuKienAICTW.tu(doc), .doc(vong: 0, muc: ["LFD-75", "Docs #3 — How to run LFD"]))
        XCTAssertEqual(SuKienAICTW.tu(KhungSSE(suKien: nil, duLieu: "{\"type\":\"progress\",\"phase\":\"checking\"}")), .kiemTra)
        // Thiếu `type` trong data ⇒ dùng tên `event:`.
        XCTAssertEqual(SuKienAICTW.tu(KhungSSE(suKien: "delta", duLieu: "{\"text\":\"b\"}")), .manh("b"))
        XCTAssertNil(SuKienAICTW.tu(KhungSSE(suKien: nil, duLieu: "not json")))
        XCTAssertNil(SuKienAICTW.tu(KhungSSE(suKien: nil, duLieu: "{\"type\":\"delta\",\"text\":\"\"}")))
    }

    func testDoneGiaiBangCungModelVoiAiChat() throws {
        let json = """
        {"type":"done","reply":"| A | B |\\n| - | - |\\n| 1 | 2 |","actions":[],"threadId":34,
         "question":{"id":901,"threadId":34,"role":"user","content":"Hi","error":null},
         "answer":{"id":902,"threadId":34,"role":"assistant","content":"| A | B |","actions":[{"index":0,"status":"pending","action":{"type":"add_comment","number":3}}]},
         "quota":{"pro":false,"used":4,"limit":null,"remaining":null,"available":true}}
        """
        guard case .xong(let d)? = SuKienAICTW.tu(KhungSSE(suKien: "done", duLieu: json)) else { return XCTFail("không phải done") }
        let kq = try JSONDecoder().decode(CTWAIKetQua.self, from: d)
        XCTAssertEqual(kq.threadId, 34)
        XCTAssertEqual(kq.question?.id, 901)
        XCTAssertEqual(kq.answer?.actions?.first?.action?.type, "add_comment")
        XCTAssertEqual(kq.quota?.used, 4)
    }

    func testLuiVeAiChatKhiTuyenChuaCo() {
        XCTAssertEqual(LuongAICTW.phanLoai(trangThai: 200, contentType: "text/event-stream; charset=utf-8"), .luong)
        XCTAssertEqual(LuongAICTW.phanLoai(trangThai: 404, contentType: "application/json"), .khongHoTro)
        XCTAssertEqual(LuongAICTW.phanLoai(trangThai: 405, contentType: "text/html"), .khongHoTro)
        XCTAssertEqual(LuongAICTW.phanLoai(trangThai: 200, contentType: "text/html"), .khongHoTro, "trang SPA/HTML 200 ⇒ không phải SSE")
        XCTAssertEqual(LuongAICTW.phanLoai(trangThai: 200, contentType: nil), .khongHoTro)
        XCTAssertEqual(LuongAICTW.phanLoai(trangThai: 402, contentType: "application/json"), .loiJSON)
        XCTAssertEqual(LuongAICTW.phanLoai(trangThai: 503, contentType: "application/json"), .loiJSON)
        XCTAssertEqual(LuongAICTW.phanLoai(trangThai: 401, contentType: "application/json"), .phienHetHan)
    }

    func testLoiJSONTruocKhiMoLuongGiuMa() {
        let e = LuongAICTW.loiTuThan(Data("{\"success\":false,\"message\":\"Upgrade to Pro\",\"code\":\"WORK_AI_QUOTA_EXCEEDED\"}".utf8), trangThai: 402)
        guard case .coMa(let ma, _) = e else { return XCTFail() }
        XCTAssertEqual(ma, "WORK_AI_QUOTA_EXCEEDED")
        // 3.1.1: câu mời mua của máy chủ không lọt ra.
        XCTAssertFalse(TroLyAICTW.loi(e).localizedCaseInsensitiveContains("pro"))
    }

    func testThanCoRetryMessageId() {
        let t = LuongAICTW.than(cauHoi: "Q", threadId: 34, hoiLai: 901)
        XCTAssertEqual(t["retryMessageId"] as? Int, 901)
        XCTAssertEqual(t["threadId"] as? Int, 34)
        XCTAssertNil(LuongAICTW.than(cauHoi: "Q", threadId: nil)["threadId"])
    }

    func testNhanTienDo() {
        XCTAssertEqual(LuongAICTW.nhan(.doc(vong: 1, muc: [])), String(localized: "Reading the project…"))
        let n = LuongAICTW.nhan(.doc(vong: 1, muc: ["A-1", "A-2", "Docs #3", "A-4", "A-5"])) ?? ""
        XCTAssertTrue(n.contains("A-1") && n.contains("Docs #3") && !n.contains("A-4"), n)
        XCTAssertNil(LuongAICTW.nhan(.manh("x")))
    }

    // MARK: Markdown: bảng không viền + mục danh sách nhiều dòng

    func testBangKhongVienVaMucNhieuDong() {
        let k = CTWMarkdown.khoi("""
        Thẻ | Người
        ---|---
        LFD-1 | An
        LFD-2 | Bình

        - Mục một
          tiếp dòng hai
          - con
        Sau đó
        """)
        guard case .bang(let h)? = k.first(where: { if case .bang = $0 { return true }; return false }) else { return XCTFail("không có bảng") }
        XCTAssertEqual(h.count, 3)
        XCTAssertEqual(h[2], ["LFD-2", "Bình"])
        let muc = k.compactMap { k -> (String, Int)? in if case .muc(let a, _, let c) = k { return (String(a.characters), c) }; return nil }
        XCTAssertEqual(muc.count, 2)
        XCTAssertEqual(muc[0].0, "Mục một tiếp dòng hai")
        XCTAssertEqual(muc[1].1, 1)
    }

    func testRongOBang() {
        XCTAssertNil(CTWBangView.rongO("LFD-12", coChu: 15))
        let w = CTWBangView.rongO(String(repeating: "x", count: 200), coChu: 15) ?? 0
        XCTAssertEqual(w, 240)
    }
}
