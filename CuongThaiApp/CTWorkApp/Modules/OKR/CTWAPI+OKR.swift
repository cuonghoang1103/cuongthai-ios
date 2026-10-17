import Foundation

// MARK: - CTWAPI — OKR (`work.ctw7a.routes.ts:55-74`). `wid` là id SỐ của không gian.

extension CTWAPI {
    static func okrDuAn(pid: Int, chuKy: Int?) -> APIEndpoint { get("/projects/\(pid)/okrs", chuKy.map { ["cycle": $0] }) }
    static func okrKhongGian(wid: Int, chuKy: Int?) -> APIEndpoint { get("/workspaces/\(wid)/okrs", chuKy.map { ["cycle": $0] }) }
    /// Check-in tuần: `value` bắt buộc với KR MANUAL; một tuần một lần (lần sau ghi đè).
    static func checkinKR(kid: Int, giaTri: Double?, tinCay: Int, ghiChu: String?) -> APIEndpoint {
        var t: [String: Any] = ["confidence": min(max(tinCay, 0), 10)]
        if let giaTri { t["value"] = giaTri }
        if let ghiChu, !ghiChu.isEmpty { t["note"] = String(ghiChu.prefix(2000)) }
        return goi("/okrs/key-results/\(kid)/checkins", "POST", t)
    }
}
