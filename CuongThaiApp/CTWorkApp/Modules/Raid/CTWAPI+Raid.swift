import Foundation

// MARK: - CTWAPI — RAID (`work.governance.routes.ts` :149–201)

extension CTWAPI {
    static func dsRaid(pid: Int, loai: String?) -> APIEndpoint {
        get("/projects/\(pid)/raid", loai.map { ["type": $0] })
    }

    static func raid(pid: Int, so: Int) -> APIEndpoint { get("/projects/\(pid)/raid/\(so)") }

    static func taoRaid(pid: Int, than: [String: Any]) -> APIEndpoint { goi("/projects/\(pid)/raid", "POST", than) }

    /// Sửa có `version` (lệch ⇒ 409).
    static func suaRaid(pid: Int, so: Int, than: [String: Any]) -> APIEndpoint { goi("/projects/\(pid)/raid/\(so)", "PATCH", than) }
}
