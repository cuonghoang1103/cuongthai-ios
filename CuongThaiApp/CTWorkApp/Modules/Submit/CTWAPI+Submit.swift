import Foundation

// MARK: - CTWAPI — cổng nộp sản phẩm (`work.routes.ts` ~690)

extension CTWAPI {
    static func nopSanPham(pid: Int) -> APIEndpoint { get("/projects/\(pid)/submissions") }
}
