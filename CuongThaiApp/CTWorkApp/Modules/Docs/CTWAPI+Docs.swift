import Foundation

// MARK: - CTWAPI — tài liệu dự án (`work.routes.ts` /pages, `pages.service.ts`)

extension CTWAPI {
    // MARK: Tài liệu

    static func dsTrang(pid: Int) -> APIEndpoint { get("/projects/\(pid)/pages") }
    static func trang(pid: Int, so: Int) -> APIEndpoint { get("/projects/\(pid)/pages/\(so)") }
    static func trangMarkdown(pid: Int, so: Int) -> APIEndpoint { get("/projects/\(pid)/pages/\(so)/markdown") }
    static func timTrang(pid: Int, q: String) -> APIEndpoint {
        get("/projects/\(pid)/pages/search", ["q": String(q.prefix(200)), "limit": 30])
    }
}
