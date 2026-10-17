import Foundation

// MARK: - CT Work — model cổng NỘP SẢN PHẨM (`services/work/submitGate.ts`, route `GET /projects/:pid/submissions`).
// Sản phẩm nộp = tệp đính kèm của thẻ; ở chế độ `hard`, chuyển thẻ sang Done mà thiếu tệp ⇒ 400
// `WORK_SUBMIT_INCOMPLETE`. `var` + optional, ngày là chuỗi.

struct CTWNopSanPham: Codable {
    struct Cong: Codable, Hashable { var enabled: Bool?; var mode: String?; var minAttachments: Int?; var typeKeys: [String]? }
    struct Tong: Codable, Hashable { var members: Int?; var issues: Int?; var submitted: Int?; var files: Int?; var overdue: Int? }
    struct Tep: Codable, Hashable, Identifiable { var id: Int; var fileName: String?; var mime: String?; var size: Int? }
    struct Muc: Codable, Hashable, Identifiable {
        var key: String?
        var number: Int
        var title: String
        var type: String?
        var status: String?
        var statusCategory: String?
        var done: Bool?
        var dueDate: String?
        var resolvedAt: String?
        var onTime: Bool?
        var overdue: Bool?
        var attachmentCount: Int?
        var submitted: Bool?
        var attachments: [Tep]?
        var id: Int { number }
    }
    struct ThanhVien: Codable, Hashable, Identifiable {
        var username: String?
        var name: String?
        var kind: String?
        var total: Int?
        var submitted: Int?
        var doneCount: Int?
        var onTime: Int?
        var onTimeOf: Int?
        var overdue: Int?
        var files: Int?
        var items: [Muc]?
        var id: String { username ?? name ?? "?" }
    }
    struct DA: Codable, Hashable { var key: String?; var name: String? }
    var project: DA?
    var gate: Cong?
    var canConfig: Bool?
    var totals: Tong?
    var members: [ThanhVien]?
}
