import Foundation

// MARK: - CTWAPI — Resources (work.resources.routes.ts:70-125)

extension CTWAPI {
    static func dsNguonLuc(pid: Int) -> APIEndpoint { get("/projects/\(pid)/resources") }
    /// Ghi một lượt mở (đếm + "mở gần đây") rồi trả url chuẩn để mở.
    static func moNguonLuc(pid: Int, id: Int) -> APIEndpoint { goi("/projects/\(pid)/resources/\(id)/open", "POST", [:]) }
}
