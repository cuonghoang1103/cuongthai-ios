import XCTest
@testable import CTWork

/// Mô-đun Kiểm thử: giải mã dữ liệu mẫu (đúng hình dạng `tests.service.ts` /
/// `fptTests.service.ts`) bằng model thật + luật thuần (trạng thái lượt, tiến độ
/// chu kỳ, mã UTCID, dấu "O" của ma trận FPT).
final class TestsCTWTests: XCTestCase {
    private func giai<T: Decodable>(_ kieu: T.Type, _ path: String, method: String = "GET", body: [String: Any] = [:],
                                    file: StaticString = #filePath, line: UInt = #line) throws -> T {
        let d = DuLieuGia.traLoi(method: method, path: "/api/v1" + path, body: body)
        let r = try JSONDecoder().decode(APIResponse<T>.self, from: d)
        XCTAssertTrue(r.success, file: file, line: line)
        return try XCTUnwrap(r.data, file: file, line: line)
    }

    func testGiaiMaCaVaChuKy() throws {
        let ds = try giai([CTWTestCase].self, "/work/projects/7/tests")
        XCTAssertEqual(ds.count, 6)
        XCTAssertEqual(ds.first?.lastRun?.status, "FAIL")
        XCTAssertNil(ds.first { $0.number == 46 }?.lastRun, "lastRun null ⇒ nil, không hỏng cả danh sách")
        let ct = try giai(CTWTestDetail.self, "/work/projects/7/tests/42")
        XCTAssertEqual(ct.steps?.count, 5)
        XCTAssertEqual(ct.runs?.last?.executedBy?.laAgent, true)
        let cks = try giai([CTWTestCycle].self, "/work/projects/7/test-cycles")
        XCTAssertEqual(cks.count, 2)
        XCTAssertNil(cks.first?.runs, "danh sách chu kỳ không kèm runs")
        let ck = try giai(CTWTestCycle.self, "/work/projects/7/test-cycles/9")
        XCTAssertEqual(ck.runs?.count, 10)
        XCTAssertEqual(ck.runs?.first?.outdated, true)
        XCTAssertEqual(ck.passRate, 67)
        XCTAssertEqual(ck.dem("FAIL"), 1)
    }

    func testGiaiMaLuotVaBangChung() throws {
        let r = try giai(CTWRunDetail.self, "/work/projects/7/test-runs/555")
        XCTAssertEqual(r.testCase?.issue?.number, 42)
        XCTAssertEqual(r.steps?.count, 5)
        XCTAssertEqual(r.evidence?.first?.laAnh, true)
        XCTAssertEqual(r.status, CTWLuatTest.trangThaiLuot((r.steps ?? []).map { $0.status ?? "TODO" }),
                       "luật của app phải khớp trạng thái máy chủ trả về")
        let m = try giai(CTWSoMoi.self, "/work/projects/7/test-runs/555/defects", method: "POST")
        XCTAssertEqual(m.number, 41)
        let a = try giai(CTWAttachment.self, "/work/projects/7/issues/42/attachments/complete", method: "POST",
                         body: ["key": "k", "fileName": "x.jpg", "runId": 555])
        XCTAssertEqual(a.fileName, "x.jpg")
    }

    func testLuatTrangThaiLuot() {
        XCTAssertEqual(CTWLuatTest.trangThaiLuot([]), "TODO")
        XCTAssertEqual(CTWLuatTest.trangThaiLuot(["TODO", "TODO"]), "TODO")
        XCTAssertEqual(CTWLuatTest.trangThaiLuot(["PASS", "TODO"]), "IN_PROGRESS")
        XCTAssertEqual(CTWLuatTest.trangThaiLuot(["PASS", "BLOCKED", "FAIL"]), "FAIL", "FAIL thắng BLOCKED")
        XCTAssertEqual(CTWLuatTest.trangThaiLuot(["PASS", "BLOCKED", "TODO"]), "BLOCKED")
        XCTAssertEqual(CTWLuatTest.trangThaiLuot(["PASS", "SKIP"]), "PASS")
        XCTAssertEqual(CTWLuatTest.trangThaiLuot(["SKIP", "SKIP"]), "SKIP")
        XCTAssertEqual(CTWLuatTest.trangThaiLuot(["SKIP", "TODO"]), "IN_PROGRESS")
    }

    func testTienDoChuKy() {
        let t = CTWLuatTest.tienDo(["TODO": 2, "IN_PROGRESS": 1, "PASS": 4, "FAIL": 1, "BLOCKED": 1, "SKIP": 0, "RETEST": 1])
        XCTAssertEqual(t.total, 10)
        XCTAssertEqual(t.executed, 6)
        XCTAssertEqual(t.passRate, 67)
        XCTAssertEqual(t.progress, 60)
        XCTAssertNil(CTWLuatTest.tienDo(["TODO": 3]).passRate, "chưa chạy gì ⇒ không có tỉ lệ đạt")
        XCTAssertEqual(CTWLuatTest.tienDo([:]).progress, 0)
    }

    func testFptUnitVaMaTran() throws {
        let u = try giai(CTWFptUnitList.self, "/work/projects/7/fpt-tests/unit")
        XCTAssertEqual(u.summary?.functions, 2, "`functions` trong summary là SỐ")
        XCTAssertEqual(u.functions?.count, 2)
        XCTAssertEqual(u.summary?.meetsNorm, false)
        let f = try giai(CTWFptFunction.self, "/work/projects/7/fpt-tests/unit/1")
        let rows = try XCTUnwrap(f.rows)
        let cases = try XCTUnwrap(f.cases)
        XCTAssertEqual(CTWLuatFpt.utcid(0), "UTCID01")
        XCTAssertEqual(CTWLuatFpt.utcid(11), "UTCID12")
        XCTAssertTrue(CTWLuatFpt.coDau(cases[2], hang: rows.first { $0.id == 5 }!))
        XCTAssertFalse(CTWLuatFpt.coDau(cases[0], hang: rows.first { $0.id == 5 }!))
        let nhom = CTWLuatFpt.nhomHang(rows)
        XCTAssertEqual(nhom.first?.section, "COND")
        XCTAssertEqual(nhom.last?.section, "CONFIRM")
        XCTAssertEqual(nhom.first { $0.nhom == "username" }?.hang.count, 2)
    }

    func testFptIntegration() throws {
        let l = try giai(CTWFptItList.self, "/work/projects/7/fpt-tests/integration")
        XCTAssertEqual(l.modules?.count, 2)
        XCTAssertEqual(l.modules?.first?.stats?.rounds?.count, 4)
        let m = try giai(CTWFptModule.self, "/work/projects/7/fpt-tests/integration/1")
        XCTAssertEqual(m.cases?.count, 4)
        XCTAssertEqual(CTWLuatFpt.trangThaiIt(m.cases?[1].rounds ?? []), "Failed")
        XCTAssertEqual(CTWLuatFpt.trangThaiIt([CTWFptRound(status: nil), CTWFptRound(status: nil)]), "Pending")
        XCTAssertEqual(CTWLuatFpt.maIt(m.idPrefix, 0), "LS1")
        let sys = try giai(CTWFptItList.self, "/work/projects/7/fpt-tests/system")
        XCTAssertEqual(sys.modules?.count, 0)
    }

    func testMoDunAnKhiKhongCoLoaiTest() throws {
        let khong = try JSONDecoder().decode(CTWProjectConfig.self, from: Data(#"{"id":1,"key":"A","name":"A","role":"MEMBER","issueTypes":[{"id":1,"key":"TASK","name":"Task"}]}"#.utf8))
        let co = try JSONDecoder().decode(CTWProjectConfig.self, from: Data(#"{"id":1,"key":"A","name":"A","role":"MEMBER","issueTypes":[{"id":9,"key":"TEST","name":"Test"}]}"#.utf8))
        let khach = try JSONDecoder().decode(CTWProjectConfig.self, from: Data(#"{"id":1,"key":"A","name":"A","role":"CLIENT","issueTypes":[{"id":9,"key":"TEST","name":"Test"}]}"#.utf8))
        guard XemThuCTW.conCua("tests") == nil else { return }
        let hien = CTWModule.tests.hien
        MainActor.assumeIsolated {
            XCTAssertFalse(hien(khong))
            XCTAssertTrue(hien(co))
            XCTAssertFalse(hien(khach), "khách không thấy kiểm thử nội bộ")
        }
    }
}
