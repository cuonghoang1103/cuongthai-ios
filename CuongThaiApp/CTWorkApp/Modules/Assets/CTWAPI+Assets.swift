import Foundation

// MARK: - CTWAPI — tài sản & giấy phép (work.ctw7c.routes.ts:95-126) — CHỈ ĐỌC trên điện thoại

extension CTWAPI {
    static func dsTaiSan(pid: Int, sapHet: Bool = false) -> APIEndpoint {
        get("/projects/\(pid)/assets", sapHet ? ["expiring": 1] : nil)
    }
    static func taiSan(pid: Int, so: Int) -> APIEndpoint { get("/projects/\(pid)/assets/\(so)") }
}
