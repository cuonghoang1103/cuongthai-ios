import Foundation

// MARK: - CTWAPI — kiểm thử (`work.routes.ts` :891–989 · `work.fpt.routes.ts`)
//
// ⚠️ Không có lượt chạy "lẻ": mọi lượt thuộc MỘT chu kỳ, mỗi ca tối đa một lượt
// mỗi chu kỳ. Muốn chạy một ca ⇒ thêm ca vào chu kỳ (`addNumbers`) rồi đọc lại
// chu kỳ để lấy id lượt (PATCH không trả id).

extension CTWAPI {
    // MARK: Ca kiểm thử

    static func dsTest(pid: Int, q: String = "") -> APIEndpoint {
        let t = q.trimmingCharacters(in: .whitespacesAndNewlines)
        return get("/projects/\(pid)/tests", t.isEmpty ? nil : ["q": String(t.prefix(200))])
    }
    static func test(pid: Int, so: Int) -> APIEndpoint { get("/projects/\(pid)/tests/\(so)") }

    // MARK: Chu kỳ

    static func dsChuKy(pid: Int) -> APIEndpoint { get("/projects/\(pid)/test-cycles") }
    static func chuKy(pid: Int, id: Int) -> APIEndpoint { get("/projects/\(pid)/test-cycles/\(id)") }
    static func themVaoChuKy(pid: Int, id: Int, so: [Int]) -> APIEndpoint {
        goi("/projects/\(pid)/test-cycles/\(id)", "PATCH", ["addNumbers": so])
    }

    // MARK: Lượt chạy

    static func luotChay(pid: Int, id: Int) -> APIEndpoint { get("/projects/\(pid)/test-runs/\(id)") }
    /// `status` / `actual` — gửi khoá nào thì đổi khoá đó (`NSNull()` = xoá chữ).
    static func suaBuoc(pid: Int, run: Int, buoc: Int, than: [String: Any]) -> APIEndpoint {
        goi("/projects/\(pid)/test-runs/\(run)/steps/\(buoc)", "PATCH", than)
    }
    static func suaLuot(pid: Int, run: Int, than: [String: Any]) -> APIEndpoint {
        goi("/projects/\(pid)/test-runs/\(run)", "PATCH", than)
    }
    static func taoLoiTuLuot(pid: Int, run: Int, buoc: Int?, tieuDe: String, uuTien: Int) -> APIEndpoint {
        var t: [String: Any] = ["title": String(tieuDe.prefix(255)), "priority": uuTien]
        if let buoc { t["stepResultId"] = buoc }
        return goi("/projects/\(pid)/test-runs/\(run)/defects", "POST", t)
    }
    /// Hoàn tất tải bằng chứng — như đính kèm thẻ nhưng kèm `runId` (thẻ = số của CA kiểm thử).
    static func xongTaiBangChung(pid: Int, soTest: Int, key: String, ten: String, run: Int) -> APIEndpoint {
        goi("/projects/\(pid)/issues/\(soTest)/attachments/complete", "POST",
            ["key": key, "fileName": String(ten.prefix(255)), "runId": run])
    }

    // MARK: Mẫu FPT (chỉ đọc)

    static func fptUnit(pid: Int) -> APIEndpoint { get("/projects/\(pid)/fpt-tests/unit") }
    static func fptHam(pid: Int, id: Int) -> APIEndpoint { get("/projects/\(pid)/fpt-tests/unit/\(id)") }
    /// `kieu`: "integration" (5.2) | "system" (5.3).
    static func fptIt(pid: Int, kieu: String) -> APIEndpoint { get("/projects/\(pid)/fpt-tests/\(kieu)") }
    static func fptModule(pid: Int, kieu: String, id: Int) -> APIEndpoint { get("/projects/\(pid)/fpt-tests/\(kieu)/\(id)") }
}
