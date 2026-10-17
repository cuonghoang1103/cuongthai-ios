import Foundation

// MARK: - CTWAPI — Forms (`work.ctw7b.routes.ts`). `:form` nhận `3` hoặc `"F-3"`.

extension CTWAPI {
    static func dsForm(pid: Int) -> APIEndpoint { get("/projects/\(pid)/forms") }
    static func traLoiForm(pid: Int, so: Int) -> APIEndpoint {
        get("/projects/\(pid)/forms/\(so)/responses", ["limit": 200])
    }
}
