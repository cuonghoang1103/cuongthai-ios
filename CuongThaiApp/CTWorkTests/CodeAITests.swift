import XCTest
@testable import CTWork

/// Trang Code + trợ lý AI (19/10/2026). Dữ liệu mẫu `Debug/XemThuCTW+Code.swift` viết theo hình dạng
/// `code.service.ts` / `gitSource.ts` / `aiThreads.service.ts` — giải mã bằng chính model của app.
final class CodeAITests: XCTestCase {
    private func giai<T: Decodable>(_ kieu: T.Type, _ path: String, method: String = "GET", body: [String: Any] = [:],
                                    file: StaticString = #filePath, line: UInt = #line) throws -> T {
        let d = DuLieuGia.traLoi(method: method, path: "/api/v1" + path, body: body)
        let r = try JSONDecoder().decode(APIResponse<T>.self, from: d)
        XCTAssertTrue(r.success, file: file, line: line)
        return try XCTUnwrap(r.data, file: file, line: line)
    }

    func testTongQuanVaHoatDong() throws {
        let t = try giai(CTWCodeTongQuan.self, "/work/projects/7/code/overview")
        XCTAssertEqual(t.stats?.daily?.count, 30)
        XCTAssertEqual(t.providers?.first?.repo, "northwind/mobile-app")
        XCTAssertEqual(t.canViewSource, true)
        let h = try giai(CTWCodeTrangHoatDong.self, "/work/projects/7/code/activity")
        XCTAssertEqual(h.items.first?.kind, "PUSH")
        XCTAssertEqual(h.items.first?.tatCaThe, [12])
        XCTAssertEqual(h.issues?["12"]?.key, "NW-12", "issues là object khoá chuỗi số")
        XCTAssertNotNil(h.nextBefore)
        XCTAssertEqual(CTWCodeChu.hanhDong(h.items[0]).cau, "Alex Morgan pushed 3 commits to feature/NW-12-push-routing")
        let ci = try XCTUnwrap(h.items.first { $0.actor?.user == nil })
        XCTAssertEqual(ci.actor?.ten, "ci-bot", "người git không khớp thành viên ⇒ dùng label")
    }

    func testNhanhVaPR() throws {
        let n = try giai(CTWCodeDSNhanh.self, "/work/projects/7/code/branches")
        XCTAssertEqual(n.items.filter { $0.deleted == true }.count, 1)
        XCTAssertEqual(n.items.first?.pr?.number, 48)
        let p = try giai(CTWCodeDSPR.self, "/work/projects/7/code/pulls")
        XCTAssertEqual(p.counts?.open, 2)
        XCTAssertEqual(Set(p.items.compactMap(\.state)), ["open", "draft", "merged", "closed"])
        XCTAssertEqual(CTWCodeChu.trangThaiPR("draft"), "DRAFT")
    }

    func testNguonTepVaDiff() throws {
        let c = try giai(CTWCodeCay.self, "/work/projects/7/code/source/tree", body: ["path": "Sources/App"])
        XCTAssertTrue(c.entries.allSatisfy { $0.path.hasPrefix("Sources/App/") })
        let lon = try giai(CTWCodeTep.self, "/work/projects/7/code/source/blob", body: ["path": "Sources/App/AppState.swift"])
        XCTAssertEqual(lon.tooLarge, true); XCTAssertNil(lon.content)
        let nhiPhan = try giai(CTWCodeTep.self, "/work/projects/7/code/source/blob", body: ["path": "AppIcon.png"])
        XCTAssertEqual(nhiPhan.binary, true)
        let d = try giai(CTWCodeChiTietCommit.self, "/work/projects/7/code/source/commit/9f8e7d6")
        XCTAssertEqual(d.files?.count, 3)
        XCTAssertNil(d.files?.last?.patch, "tệp nhị phân không có patch")
        XCTAssertEqual(d.issues?["12"]?.number, 12)
    }

    func testToMauMa() {
        let nn = ToMauMaCTW.ngonNgu("A.swift")
        let a = ToMauMaCTW.dong(#"let x = "hi" // note"#, nn)
        XCTAssertEqual(String(a.characters), #"let x = "hi" // note"#, "tô màu không được đổi chữ")
        XCTAssertTrue(ToMauMaCTW.ngonNgu("q.sql").khongPhanBietHoa)
        // URL trong chuỗi không bị coi là chú thích.
        let u = ToMauMaCTW.dong(#"x = "https://a.b" + 1"#, nn)
        XCTAssertEqual(String(u.characters), #"x = "https://a.b" + 1"#)
        // Dòng dài (mã nén) không tô — không treo.
        XCTAssertEqual(ToMauMaCTW.dong(String(repeating: "a", count: 5000), nn).characters.count, 5000)
    }

    func testThongBaoGit() throws {
        let r = try giai(CTWTrangThongBao.self, "/social/notifications")
        let g = try XCTUnwrap(r.items.first { $0.laGit })
        XCTAssertEqual(g.loai, "code")
        XCTAssertEqual(g.payload?.gitKind, "REVIEW_REQUESTED")
        let d = try XCTUnwrap(DuongDanCTW.tach(g.payload?.url ?? ""))
        XCTAssertEqual(d.doan, "code"); XCTAssertEqual(d.tham["tab"], "pulls"); XCTAssertEqual(d.tham["pr"], "48")
        XCTAssertEqual(CTWDangKyMoDun.moDun(choDoan: "code")?.id, "code", "thông báo Git ⇒ mô-đun Code")
        let caiDat = try JSONDecoder().decode(CTWCaiDatBao.self, from: Data(#"{"push":{"git":false}}"#.utf8))
        XCTAssertEqual(caiDat.push?.git, false)
    }

    func testAIHoiThoaiVaDeXuat() throws {
        let ds = try giai([CTWAIHoiThoai].self, "/work/projects/7/ai/threads")
        XCTAssertFalse(ds.isEmpty)
        let t = try giai(CTWAIHoiThoai.self, "/work/projects/7/ai/threads/801")
        let tl = try XCTUnwrap(t.messages?.first { $0.laAI })
        XCTAssertTrue(tl.content.contains("](/work/northwind/NW/issue/12)"), "câu trả lời có link thẻ /work/...")
        let dx = try XCTUnwrap(tl.actions?.first)
        XCTAssertEqual(dx.moTa(ma: "NW"), "Update NW-17: status → In Progress")
        // Đề xuất có trường lạ / sai kiểu không làm hỏng cả tin.
        let lech = #"{"index":0,"status":"pending","action":{"type":"command","command":"raid_create","args":{"x":1},"number":"abc"}}"#
        let d = try JSONDecoder().decode(CTWAIDeXuat.self, from: Data(lech.utf8))
        XCTAssertEqual(d.action?.command, "raid_create"); XCTAssertNil(d.action?.number)
        let hong = try giai(CTWAIHoiThoai.self, "/work/projects/7/ai/threads/802")
        XCTAssertNotNil(hong.messages?.first?.error, "câu hỏi chưa trả lời mang `error` ⇒ nút Ask again")
    }

    func testAILoiKhongMoiMua() {
        // 3.1.1: hết hạn mức ⇒ không lọt "Upgrade to Pro" của máy chủ.
        let e = APIError.coMa(ma: "WORK_AI_QUOTA_EXCEEDED", thongDiep: "You have used all 20 free AI requests for today. Upgrade to Pro to keep using the AI assistant.")
        XCTAssertFalse(TroLyAICTW.loi(e).localizedCaseInsensitiveContains("pro"))
        XCTAssertTrue(TroLyAICTW.loi(APIError.coMa(ma: "WORK_AI_BAD_OUTPUT", thongDiep: "x")).contains("Ask again"))
    }

    @MainActor
    func testMoDunCodeChiHienKhiNoiRepo() throws {
        let cfg = try JSONDecoder().decode(CTWProjectConfig.self, from: Data(#"{"id":7,"key":"NW","name":"N","role":"MEMBER","permissions":{"useAi":true}}"#.utf8))
        AppState.shared.codeDaNoi = false
        XCTAssertFalse(CTWDangKyMoDun.hienDuoc(cfg).contains { $0.id == "code" })
        AppState.shared.codeDaNoi = true
        XCTAssertTrue(CTWDangKyMoDun.hienDuoc(cfg).contains { $0.id == "code" })
        XCTAssertTrue(CTWDangKyMoDun.hienDuoc(cfg).contains { $0.id == "ai" })
        let khach = try JSONDecoder().decode(CTWProjectConfig.self, from: Data(#"{"id":7,"key":"NW","name":"N","role":"CLIENT","permissions":{"useAi":false}}"#.utf8))
        XCTAssertFalse(CTWDangKyMoDun.hienDuoc(khach).contains { $0.id == "code" }, "khách cổng không thấy Code")
        XCTAssertFalse(CTWDangKyMoDun.hienDuoc(khach).contains { $0.id == "ai" }, "khách cổng không thấy AI")
        AppState.shared.codeDaNoi = nil
    }
}
