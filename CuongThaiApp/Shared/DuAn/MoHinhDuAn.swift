import SwiftUI

// ════════════════════════════════════════════════════════════════
// DỰ ÁN (web: /projects)
//
// Đo thật 28/08/2026 trên production: **41 dự án**, công khai, không cần đăng
// nhập. Danh mục: Web 18 · Backend 11 · AI 6 · Mobile 5 · DevOps 1.
//
// ⚠️ Máy chủ CHỐT `limit` ở **12** — gửi `limit=100` vẫn trả 12. Và nó trả
// NGUYÊN cả `bodyHtml` ngay trong danh sách (TB 24,6 KB, lớn nhất 165,8 KB),
// nên mỗi trang nặng ~839 KB. Không rút xuống được từ phía app.
//
// Đổi lại: trang chi tiết KHÔNG cần gọi thêm lần nào — mọi thứ đã nằm trong
// đối tượng của danh sách. Vì thế `DuAnChiTietView` nhận thẳng `DuAn` chứ
// không nhận `slug` rồi tải lại.
//
// ⚠️ SONG NGỮ nằm ở các trường `…En` SONG SONG (`titleEn`, `bodyHtmlEn`,
// `schemaCodeEn`…), không phải một khối `i18n` riêng. Trường tiếng Anh có thể
// TRỐNG ở dự án cũ ⇒ luôn lùi về bản tiếng Việt, đừng để trang trắng.
// ════════════════════════════════════════════════════════════════

struct DuAn: Codable, Identifiable, Hashable {
    let id: Int
    let slug: String
    let title: String
    let description: String?
    let thumbnailUrl: String?
    let projectUrl: String?
    let videoUrl: String?
    let githubUrl: String?
    let techStack: String?
    let role: String?
    let duration: String?
    let status: String?
    let category: String?
    let difficulty: String?
    let bodyHtml: String?
    let schemaCode: String?
    let schemaLang: String?
    let viewCount: Int?
    let likeCount: Int?
    let isFeatured: Bool?
    let titleEn: String?
    let descriptionEn: String?
    let roleEn: String?
    let durationEn: String?
    let bodyHtmlEn: String?
    let schemaCodeEn: String?
    let technologies: [String]?
    let milestones: [MocDuAn]?
    let features: [TinhNangDuAn]?
    let resources: [TaiNguyenDuAn]?
    let listItems: [MucDuAn]?

    var cacCongNghe: [String] {
        if let t = technologies, !t.isEmpty { return t }
        return (techStack ?? "").split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
    var cacMoc: [MocDuAn] { milestones ?? [] }
    var cacTinhNang: [TinhNangDuAn] { features ?? [] }
    var cacTaiNguyen: [TaiNguyenDuAn] { resources ?? [] }
    /// Đo thật trên 41 dự án: CORE_KNOWLEDGE 360 · PORTFOLIO_BONUS 220 ·
    /// COMPLETION_OUTCOME 206. Ba nhóm này là phần "học được gì" của dự án,
    /// bỏ đi là mất gần 800 mục nội dung.
    func muc(_ loai: String) -> [MucDuAn] { (listItems ?? []).filter { $0.kind == loai } }

    /// Lấy trường theo ngôn ngữ, LUÔN lùi về bản tiếng Việt khi bản Anh trống.
    private func theo(_ vi: String?, _ en: String?, _ anh: Bool) -> String? {
        guard anh, let e = en, !e.trimmingCharacters(in: .whitespaces).isEmpty else { return vi }
        return e
    }
    func tua(_ anh: Bool) -> String { theo(title, titleEn, anh) ?? title }
    func moTa(_ anh: Bool) -> String? { theo(description, descriptionEn, anh) }
    func vaiTro(_ anh: Bool) -> String? { theo(role, roleEn, anh) }
    func thoiLuong(_ anh: Bool) -> String? { theo(duration, durationEn, anh) }
    func than(_ anh: Bool) -> String? { theo(bodyHtml, bodyHtmlEn, anh) }
    func schema(_ anh: Bool) -> String? { theo(schemaCode, schemaCodeEn, anh) }

    var mauDanhMuc: Color {
        switch (category ?? "").lowercased() {
        case "web": return Color(hex: 0x3B82F6)
        case "backend": return Color(hex: 0x10B981)
        case "ai": return Color(hex: 0xA855F7)
        case "mobile": return Color(hex: 0xF59E0B)
        case "devops": return Color(hex: 0xEF4444)
        default: return Color(hex: 0x64748B)
        }
    }
    var bieuTuongDanhMuc: String {
        switch (category ?? "").lowercased() {
        case "web": return "globe"
        case "backend": return "server.rack"
        case "ai": return "brain.head.profile"
        case "mobile": return "iphone"
        case "devops": return "gearshape.2"
        default: return "folder"
        }
    }
    /// Đo thật: INTERMEDIATE 19 · EXPERT 10 · ADVANCED 7 · BEGINNER 5.
    var nhanDoKho: String? {
        switch (difficulty ?? "").uppercased() {
        case "BEGINNER": return T("Cơ bản")
        case "INTERMEDIATE": return T("Trung cấp")
        case "ADVANCED": return T("Nâng cao")
        case "EXPERT": return T("Chuyên sâu")
        default: return nil
        }
    }
    var mauDoKho: Color {
        switch (difficulty ?? "").uppercased() {
        case "BEGINNER": return Color(hex: 0x22C55E)
        case "INTERMEDIATE": return Color(hex: 0x3B82F6)
        case "ADVANCED": return Color(hex: 0xF59E0B)
        case "EXPERT": return Color(hex: 0xEF4444)
        default: return Color(hex: 0x64748B)
        }
    }
}

struct MocDuAn: Codable, Identifiable, Hashable {
    let id: Int
    let phase: String?
    let title: String?
    let description: String?
    let titleEn: String?
    let descriptionEn: String?
    /// 87/320 mốc có kèm mã. Bỏ đi là mất phần cụ thể nhất của dự án.
    let codeBlock: String?
    let codeLang: String?
    func tua(_ anh: Bool) -> String {
        if anh, let e = titleEn, !e.isEmpty { return e }
        return title ?? ""
    }
    func moTa(_ anh: Bool) -> String? {
        if anh, let e = descriptionEn, !e.isEmpty { return e }
        return description
    }
}

struct TinhNangDuAn: Codable, Identifiable, Hashable {
    let id: Int
    let title: String?
    let description: String?
    let titleEn: String?
    let descriptionEn: String?
    func tua(_ anh: Bool) -> String {
        if anh, let e = titleEn, !e.isEmpty { return e }
        return title ?? ""
    }
    func moTa(_ anh: Bool) -> String? {
        if anh, let e = descriptionEn, !e.isEmpty { return e }
        return description
    }
}

struct TaiNguyenDuAn: Codable, Identifiable, Hashable {
    let id: Int
    let title: String?
    let titleEn: String?
    let url: String?
    let type: String?
    func tua(_ anh: Bool) -> String {
        if anh, let e = titleEn, !e.isEmpty { return e }
        return title ?? url ?? ""
    }
    /// Đo thật: LINK 158 · DOC 31 · REPO 13 · PDF 12.
    var bieuTuong: String {
        switch (type ?? "").uppercased() {
        case "REPO": return "chevron.left.forwardslash.chevron.right"
        case "PDF": return "doc.richtext"
        case "DOC": return "doc.text"
        default: return "link"
        }
    }
}

struct MucDuAn: Codable, Identifiable, Hashable {
    let id: Int
    let kind: String?
    let content: String?
    let contentEn: String?
    func chu(_ anh: Bool) -> String {
        if anh, let e = contentEn, !e.isEmpty { return e }
        return content ?? ""
    }
}
