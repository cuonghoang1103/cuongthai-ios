import XCTest
@testable import CTWork

/// CuongMini (21/10/2026): việc một chạm theo loại thẻ (port `AiIssueMenu.tsx`), thân `/ai/quick`, `issueNumber` đi kèm
/// câu hỏi/hội thoại, cổng quyền, thời gian chờ và bộ dựng Markdown của câu trả lời dài.
final class CuongMiniTests: XCTestCase {
    private func ids(_ loai: String?) -> [String] { CuongMini.mucNhanh(loai: loai).map(\.id) }

    func testViecNhanhTheoLoaiTheGiongWeb() {
        XCTAssertEqual(ids("EPIC"), ["summarize", "split-epic"])
        XCTAssertEqual(ids("STORY"), ["summarize", "split", "generate_tests", "review_story"])
        XCTAssertEqual(ids("TASK"), ["summarize", "split"])
        XCTAssertEqual(ids("BUG"), ["summarize", "split", "improve_bug"])
        XCTAssertEqual(ids("REQUIREMENT"), ["summarize", "generate_tests", "review_story"])
        XCTAssertEqual(ids("SUBTASK"), ["summarize"], "sub-task chỉ có Tóm tắt")
        XCTAssertEqual(ids(nil), ["summarize"])
        XCTAssertEqual(ids("story"), ids("STORY"), "khoá loại không phân biệt hoa thường")
    }

    func testEpicGoiLaChiaThanhStoryNhungVanLaTaskSplit() {
        let epic = CuongMini.mucNhanh(loai: "EPIC")[1]
        let story = CuongMini.mucNhanh(loai: "STORY")[1]
        XCTAssertEqual(epic.viec, .split)
        XCTAssertEqual(story.viec, .split)
        XCTAssertNotEqual(epic.nhan, story.nhan, "Epic: 'Break into stories', còn lại 'Split into sub-tasks'")
        XCTAssertNotEqual(epic.id, story.id)
    }

    func testThanViecNhanhDungZodCuaMayChu() {
        let t = CuongMini.thanViecNhanh(viec: .generate_tests, so: 12, threadId: 901, nhan: "Sinh test case")
        XCTAssertEqual(t["task"] as? String, "generate_tests")
        XCTAssertEqual(t["issueNumber"] as? Int, 12)
        XCTAssertEqual(t["threadId"] as? Int, 901)
        XCTAssertEqual(t["label"] as? String, "Sinh test case")
        XCTAssertEqual(Set(t.keys), ["task", "issueNumber", "threadId", "label"])
        // `label` tối đa 120 ký tự (z.string().max(120)).
        let dai = CuongMini.thanViecNhanh(viec: .summarize, so: 1, threadId: 1, nhan: String(repeating: "á", count: 300))
        XCTAssertEqual((dai["label"] as? String)?.count, 120)
        // Mọi task iOS gửi đều nằm trong enum của máy chủ.
        let mayChu: Set<String> = ["write_story", "split", "generate_tests", "improve_bug", "summarize", "review_story", "meeting_notes",
                                   "req_review", "team_health", "draft_srs", "summarize_page"]
        XCTAssertTrue(Set(ViecNhanhCuongMini.allCases.map(\.rawValue)).isSubset(of: mayChu))
    }

    func testDuongVaThoiGianChoViecNhanh() {
        let e = CTWAPI.aiViecNhanh(pid: 7, viec: .split, so: 12, threadId: 3, nhan: "Chia thành việc con")
        guard case .workGoi(let d, let m, let than, _) = e else { return XCTFail("phải là workGoi") }
        XCTAssertEqual(m, "POST")
        XCTAssertTrue(d.hasSuffix("/projects/7/ai/quick"), d)
        XCTAssertEqual(than?["task"] as? String, "split")
        XCTAssertEqual(e.thoiGianCho, 180, "/ai/quick chạy một lượt model dài như /ai/chat")
    }

    func testHoiThoaiVaCauHoiGanThe() {
        guard case .workGoi(_, _, let co, _) = CTWAPI.aiTaoHoiThoai(pid: 7, tieuDe: "Tóm tắt · NW-12", rieng: false, so: 12),
              case .workGoi(_, _, let khong, _) = CTWAPI.aiTaoHoiThoai(pid: 7, tieuDe: "x", rieng: true) else { return XCTFail() }
        XCTAssertEqual(co?["issueNumber"] as? Int, 12)
        XCTAssertEqual(co?["visibility"] as? String, "PROJECT")
        XCTAssertNil(khong?["issueNumber"])
        XCTAssertEqual(khong?["visibility"] as? String, "PRIVATE")
        XCTAssertEqual(LuongAICTW.than(cauHoi: "Tôi cần đọc gì trước?", threadId: 5, so: 12)["issueNumber"] as? Int, 12)
        guard case .workGoi(_, _, let chat, _) = CTWAPI.aiHoi(pid: 7, cauHoi: "?", threadId: 5, so: 12) else { return XCTFail() }
        XCTAssertEqual(chat?["issueNumber"] as? Int, 12)
    }

    func testCongQuyenCuongMini() throws {
        func cfg(_ json: String) throws -> CTWProjectConfig { try JSONDecoder().decode(CTWProjectConfig.self, from: Data(json.utf8)) }
        XCTAssertTrue(CuongMini.coTheDung(try cfg(#"{"id":7,"key":"NW","name":"N","role":"MEMBER","permissions":{"useAi":true}}"#)))
        XCTAssertFalse(CuongMini.coTheDung(try cfg(#"{"id":7,"key":"NW","name":"N","role":"VIEWER","permissions":{"useAi":false}}"#)))
        XCTAssertFalse(CuongMini.coTheDung(try cfg(#"{"id":7,"key":"NW","name":"N","role":"CLIENT","permissions":{"useAi":true}}"#)),
                       "khách cổng không bao giờ thấy CuongMini")
        XCTAssertFalse(CuongMini.coTheDung(nil))
    }

    func testRouteMoCuongMiniPhanBietViecMoSan() {
        let a = RouteCuongMiniCTW(pid: 7, maDuAn: "NW", the: TheCuongMini(so: 12, loai: "STORY"), khoiDau: .nhanh(MucNhanhCuongMini(viec: .summarize)))
        let b = RouteCuongMiniCTW(pid: 7, maDuAn: "NW", the: TheCuongMini(so: 12, loai: "STORY"), khoiDau: .hoi("x"))
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(a, RouteCuongMiniCTW(pid: 7, maDuAn: "NW", the: TheCuongMini(so: 12, loai: "STORY"), khoiDau: .nhanh(MucNhanhCuongMini(viec: .summarize))))
    }

    @MainActor
    func testMoDunTenCuongMiniGiuIdAi() {
        XCTAssertEqual(CTWModule.ai.id, "ai", "giữ id để ghim đồng bộ navPins của web")
        XCTAssertEqual(CTWModule.ai.ten, "CuongMini")
    }

    // MARK: Câu trả lời dài (Markdown)

    func testDanhSachSoKieuNgoacVaKhoangCach() {
        let k = CTWMarkdown.khoi("""
        ## Ưu tiên
        1) **NW-12** — hạn hôm nay
           - Đọc Docs #3 trước
        2) NW-14 — quá hạn 1 ngày

        Còn lại: NW-17.
        """)
        let nhan = k.compactMap { x -> String? in if case .muc(_, let n, _) = x { return n }; return nil }
        XCTAssertEqual(nhan, ["1.", "•", "2."], "'1)' đọc như '1.'")
        // Mục liền nhau sát hơn đoạn ↔ mục; tiêu đề thoáng nhất.
        let muc = k[1], muc2 = k[2], doan = k.last!
        let giuaMuc = CTWKhoiView.khoangTruoc(muc2, sau: muc, coChu: 15)
        let truocDoan = CTWKhoiView.khoangTruoc(doan, sau: k[3], coChu: 15)
        let truocTieuDe = CTWKhoiView.khoangTruoc(k[0], sau: doan, coChu: 15)
        XCTAssertLessThan(giuaMuc, truocDoan)
        XCTAssertLessThan(truocDoan, truocTieuDe)
    }
}
