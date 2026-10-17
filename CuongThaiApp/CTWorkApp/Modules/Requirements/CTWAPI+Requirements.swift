import Foundation

// MARK: - CTWAPI — Yêu cầu: SRS (`work.ctw4.routes.ts`), Wiegers (`work.ctw4b.routes.ts`,
// `work.ctw6b.routes.ts`). Không có cờ mô-đun — cổng thật là `srsCtx` ở máy chủ
// (khách/khách mời ⇒ 403 WORK_INTERNAL_ONLY).

extension CTWAPI {
    // MARK: SRS
    static func srs(pid: Int) -> APIEndpoint { get("/projects/\(pid)/srs") }
    static func deXuatUC(pid: Int, than: [String: Any]) -> APIEndpoint { goi("/projects/\(pid)/srs/use-cases", "POST", than) }
    static func trangThaiUC(pid: Int, n: Int, trangThai: String) -> APIEndpoint {
        goi("/projects/\(pid)/srs/use-cases/\(n)/status", "POST", ["status": trangThai])
    }
    static func deXuatQuyTac(pid: Int, than: [String: Any]) -> APIEndpoint { goi("/projects/\(pid)/srs/rules", "POST", than) }
    static func trangThaiQuyTac(pid: Int, n: Int, trangThai: String) -> APIEndpoint {
        goi("/projects/\(pid)/srs/rules/\(n)", "PATCH", ["status": trangThai])
    }
    static func rtm(pid: Int) -> APIEndpoint { get("/projects/\(pid)/rtm") }

    // MARK: Wiegers
    static func swrYeuCau(pid: Int) -> APIEndpoint { get("/projects/\(pid)/swr/requirements") }
    static func swrLichSu(pid: Int, so: Int) -> APIEndpoint { get("/projects/\(pid)/swr/requirements/\(so)/history") }
    static func swrVongDoi(pid: Int, so: Int, den: String, ghiChu: String?) -> APIEndpoint {
        goi("/projects/\(pid)/swr/requirements/\(so)/lifecycle", "POST", ["to": den, "note": ghiChu.map { $0 as Any } ?? NSNull()])
    }
    static func swrTinhNang(pid: Int) -> APIEndpoint { get("/projects/\(pid)/swr/features") }
    static func swrBenLienQuan(pid: Int) -> APIEndpoint { get("/projects/\(pid)/swr/stakeholders") }
    static func swrThuatNgu(pid: Int) -> APIEndpoint { get("/projects/\(pid)/swr/glossary") }
    static func swrPhien(pid: Int) -> APIEndpoint { get("/projects/\(pid)/swr/elicitation") }
    static func swrPhien(pid: Int, n: Int) -> APIEndpoint { get("/projects/\(pid)/swr/elicitation/\(n)") }
    static func swrDeXuatYeuCau(pid: Int, n: Int, than: [String: Any]) -> APIEndpoint {
        goi("/projects/\(pid)/swr/elicitation/\(n)/proposals", "POST", than)
    }
    static func swrNfr(pid: Int) -> APIEndpoint { get("/projects/\(pid)/swr/nfr") }
    static func swrMau(pid: Int) -> APIEndpoint { get("/projects/\(pid)/swr/mockups") }
}
