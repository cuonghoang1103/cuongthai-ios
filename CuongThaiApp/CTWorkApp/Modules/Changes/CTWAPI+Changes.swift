import Foundation

// MARK: - CTWAPI — Change request (`work.governance.routes.ts` :84–135)

extension CTWAPI {
    static func dsCr(pid: Int, trangThai: String?) -> APIEndpoint {
        get("/projects/\(pid)/changes", trangThai.map { ["status": $0] })
    }

    static func cr(pid: Int, so: Int) -> APIEndpoint { get("/projects/\(pid)/changes/\(so)") }

    static func taoCr(pid: Int, than: [String: Any]) -> APIEndpoint { goi("/projects/\(pid)/changes", "POST", than) }

    /// Sửa có khoá lạc quan `version` (lệch ⇒ 409).
    static func suaCr(pid: Int, so: Int, than: [String: Any]) -> APIEndpoint { goi("/projects/\(pid)/changes/\(so)", "PATCH", than) }

    static func doiTrangThaiCr(pid: Int, so: Int, trangThai: String) -> APIEndpoint {
        goi("/projects/\(pid)/changes/\(so)/status", "POST", ["status": trangThai])
    }

    static func xinDuyetCr(pid: Int, so: Int, nguoiDuyet: [Int], tuanTu: Bool, han: Date?) -> APIEndpoint {
        var t: [String: Any] = ["approverIds": nguoiDuyet, "mode": tuanTu ? "SEQUENTIAL" : "PARALLEL"]
        t["dueAt"] = govNull(han.map { GovNgay.iso($0) })
        return goi("/projects/\(pid)/changes/\(so)/approval", "POST", t)
    }
}
