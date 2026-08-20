import SwiftUI
import UniformTypeIdentifiers

/// Một thứ người dùng đính vào câu hỏi.
///
/// Backend nhận **data URL** (`data:<mime>;base64,<...>`) chứ không nhận byte
/// thô — xem `parseChatImages` / `parseChatDocuments` trong `ai.routes.ts`.
struct DinhKemAI: Identifiable, Equatable {
    let id = UUID()
    let ten: String
    let mime: String
    let duLieu: Data

    var laAnh: Bool { mime.hasPrefix("image/") }

    /// Chuỗi gửi lên. Cả ảnh lẫn tệp đều cùng một dạng.
    var dataURL: String { "data:\(mime);base64," + duLieu.base64EncodedString() }

    var bieuTuong: String {
        if laAnh { return "photo" }
        if mime == "application/pdf" { return "doc.richtext" }
        if mime.contains("wordprocessingml") { return "doc.text" }
        return "doc.plaintext"
    }
}

enum HanMucDinhKem {
    /// Khớp `MAX_CHAT_IMAGES` / `MAX_CHAT_DOCS` / `MAX_DOC_BYTES` của backend.
    /// Chặn ở đây để người dùng biết NGAY, thay vì gửi đi rồi ăn 400.
    static let soAnh = 4
    static let soTep = 3
    static let byteMoiTep = 6 * 1024 * 1024

    /// Đúng `ALLOWED_DOC_TYPES`. `.doc` đời cũ KHÔNG có trong danh sách —
    /// backend trả lời hẳn một câu riêng bảo lưu lại thành .docx.
    static let loaiTep: [UTType] = [
        .pdf, .plainText, .commaSeparatedText,
        UTType(filenameExtension: "docx") ?? .data,
        UTType(filenameExtension: "md") ?? .plainText,
    ]

    /// Suy ra mime từ đuôi tệp.
    ///
    /// ⚠️ `UTType.preferredMIMEType` trả `nil` cho .docx và .md trên vài máy,
    /// mà gửi mime sai là backend từ chối thẳng. Nên tra tay trước.
    static func mime(cho url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf":  return "application/pdf"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "md", "markdown": return "text/markdown"
        case "csv":  return "text/csv"
        case "txt":  return "text/plain"
        default:
            return UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "text/plain"
        }
    }
}
