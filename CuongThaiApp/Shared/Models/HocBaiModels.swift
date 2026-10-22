import Foundation

// ════════════════════════════════════════════════════════════════
// MÔ HÌNH PHỤ CỦA MÀN HỌC ACADEMY (22/10/2026)
//
// Tệp RIÊNG trong `Shared/Models` (không chèn vào `Models.swift`) để nhiều
// nhánh cùng sửa app không giẫm nhau. Chỉ `import Foundation` vì thư mục này
// còn được dựng vào app Quản trị và app CT Work (xem `project.yml`).
//
// ⚠️ Mọi trường đều `var` + optional (CLAUDE.md C3/C4): một khoá thiếu không
// được phép làm hỏng cả lượt giải mã một khoá học 108 bài. Ngày tháng để
// `String?` — `APIClient` dùng `JSONDecoder()` trần.
// ════════════════════════════════════════════════════════════════

/// Tài liệu đính kèm — của MỘT bài (`lesson.documents`) hoặc của CẢ khoá
/// (`GET /courses/:id/documents`, mục "Tài liệu" cố định ở đầu nội dung khoá).
///
/// `fileUrl` là địa chỉ R2 RIÊNG TƯ: không mở thẳng được. Muốn mở phải xin
/// `GET /courses/documents/:id/download?resolve=1` ⇒ URL ký 5 phút.
/// Riêng `fileType == "link"` là liên kết ngoài (Google Drive, OneDrive…).
struct TaiLieuBai: Codable, Identifiable, Hashable {
    var id: Int
    var title: String
    var fileUrl: String?
    var fileSizeBytes: Double?
    var fileType: String?
    var downloadCount: Int?
    var createdAt: String?
    var lessonId: Int?
    var courseId: Int?

    /// Kiểu để chọn trình mở: PDF (PDFKit) · ảnh/Office (QuickLook) · liên kết (Safari).
    enum Kieu: String { case pdf, anh, office, lienKet, khac }

    var kieu: Kieu {
        let loai = (fileType ?? "").lowercased()
        let duoi = (TaiLieuBai.duoi(title) ?? TaiLieuBai.duoi(fileUrl ?? "") ?? "").lowercased()
        if loai == "link" || loai == "url" { return .lienKet }
        if loai.contains("pdf") || duoi == "pdf" { return .pdf }
        if loai.hasPrefix("image") || ["png", "jpg", "jpeg", "webp", "gif", "heic"].contains(duoi) { return .anh }
        if ["doc", "docx", "ppt", "pptx", "xls", "xlsx", "csv", "txt", "md", "rtf", "key", "pages", "numbers"].contains(duoi)
            || loai.contains("word") || loai.contains("presentation") || loai.contains("sheet") || loai.contains("officedocument") {
            return .office
        }
        return .khac
    }

    /// "2,4 MB" — cỡ tệp đọc được bằng mắt. Liên kết ngoài thì không có cỡ.
    var nhanCo: String? {
        guard let b = fileSizeBytes, b > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(b), countStyle: .file)
    }

    var bieuTuong: String {
        switch kieu {
        case .pdf: return "doc.richtext"
        case .anh: return "photo"
        case .office: return "doc.text"
        case .lienKet: return "link"
        case .khac: return "doc"
        }
    }

    /// Đuôi tệp của một tên/đường dẫn (bỏ query). `nil` khi không có.
    static func duoi(_ s: String) -> String? {
        let goc = s.components(separatedBy: "?").first ?? s
        guard let cham = goc.lastIndex(of: "."), cham < goc.index(before: goc.endIndex) else { return nil }
        let d = String(goc[goc.index(after: cham)...])
        return (d.count <= 5 && !d.contains("/")) ? d : nil
    }
}

/// `GET /courses/documents/:id/download?resolve=1`
struct LinkTaiLieu: Codable {
    var url: String
    var fileType: String?
    var title: String?
}

/// Bài tập nộp link của một bài (`lesson.assignments`).
struct BaiTapNop: Codable, Identifiable, Hashable {
    var id: Int
    var lessonId: Int?
    var title: String
    var instructions: String?
    var deadline: String?
    var sortOrder: Int?
    var isPublished: Bool?
    var maxScore: Double?
    var mySubmission: NopBai?

    func hash(into h: inout Hasher) { h.combine(id) }
    static func == (a: BaiTapNop, b: BaiTapNop) -> Bool { a.id == b.id && a.mySubmission == b.mySubmission }
}

/// Bài nộp của chính mình — `POST /courses/assignments/submit` trả đúng hình này.
struct NopBai: Codable, Hashable {
    var id: Int?
    var submissionUrl: String?
    var notes: String?
    /// SUBMITTED | GRADED | …
    var status: String?
    var grade: Double?
    var feedback: String?
    var submittedAt: String?
}

/// Bộ luyện Code Lab gắn với bài học — `GET /code-lab/practice/:khoa/:bai`.
/// Bản chép `BoLuyenTap` của web (`lib/codelabPractice.ts`), chỉ giữ trường app đọc.
struct BoLuyenCodeLab: Codable {
    var coBoLuyen: Bool?
    var trackSlug: String?
    var trackName: String?
    /// lesson | chapter | none
    var scope: String?
    var items: [BaiLuyenCodeLab]?
    var total: Int?
    var estimatedMinutes: Int?
    var solvedCount: Int?
    var dangSoan: Bool?
    var goiY: GoiYLuyen?

    struct GoiYLuyen: Codable {
        var trackSlug: String?
        var trackName: String?
        var moduleSlug: String?
        var items: [BaiLuyenCodeLab]?
    }

    var dsBai: [BaiLuyenCodeLab] { items ?? [] }
}

struct BaiLuyenCodeLab: Codable, Identifiable, Hashable {
    var id: Int?
    var slug: String
    var title: String
    /// EASY | MEDIUM | HARD | EXPERT
    var difficulty: String?
    var estimatedMinutes: Int?
    var moduleSlug: String?
    var solved: Bool?

    var khoa: String { slug }
    var nhanDoKho: String {
        switch difficulty {
        case "EASY": return "Dễ"
        case "MEDIUM": return "Vừa"
        case "HARD": return "Khó"
        case "EXPERT": return "Chuyên gia"
        default: return difficulty ?? ""
        }
    }
}

/// Đoạn đã lưu vào Sổ tay từ một bài học — `GET /notes/ghi-nhanh/khoa/:slug/bai/:id`.
struct DoanSoTay: Codable, Hashable {
    var text: String
    var laCode: Bool?
}

struct GoiDoanSoTay: Codable {
    var noteId: Int?
    var title: String?
    var doan: [DoanSoTay]?
}

/// `POST /notes/ghi-nhanh/khoa/luu`
struct KetQuaLuuSoTay: Codable {
    var noteId: Int?
    var subjectId: Int?
    var subjectName: String?
}

/// Chứng chỉ khoá — `GET /certificates/course/:id` (404 khi chưa đủ 100%).
struct ChungChiKhoa: Codable {
    var id: Int
    var certificateNumber: String?
}

/// Một trang "Câu hỏi thường gặp" của gia sư bài — `GET …/ai/asks?truoc=<id>`.
/// Phần tử dùng `CauHoiLuu` (khai ở `GiaSuBaiHocView.swift`) nên chỉ giữ cờ trang ở đây.
struct CoTrangTiep: Codable {
    var conNua: Bool?
}
