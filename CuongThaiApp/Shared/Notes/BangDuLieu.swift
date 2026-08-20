import Foundation

// ════════════════════════════════════════════════════════════════
// TRANG CƠ SỞ DỮ LIỆU (Notion-style database)
//
// `GET /notes-databases/:id` trả `{...bảng, properties, views, rows,
// relationLabels, total, truncated}`. Mỗi dòng có `values` là bản đồ
// `propertyId (dạng CHUỖI) → giá trị` — máy chủ làm phẳng sẵn để client không
// phải quét mảng ô cho từng dòng.
//
// ⚠️ Khoá của `values` là chuỗi vì JSON không có khoá số. Tra bằng
// `String(property.id)`, tra bằng Int là luôn trượt và mọi ô hiện rỗng.
// ════════════════════════════════════════════════════════════════

struct BangDuLieu: Codable, Identifiable {
    let id: Int
    let title: String?
    let icon: String?
    let subjectId: Int?
    let properties: [CotBang]
    let views: [KieuXemBang]?
    let rows: [DongBang]
    let total: Int?
    /// Máy chủ ngừng quét ở một trần nào đó — phải nói cho người dùng biết,
    /// không thì họ tưởng bảng chỉ có bấy nhiêu dòng.
    let truncated: Bool?
    /// `propertyId` → (`rowId` → nhãn) cho cột quan hệ.
    let relationLabels: [String: AnyCodable]?

    var ten: String { (title?.isEmpty == false ? title! : nil) ?? "Bảng chưa đặt tên" }
    var cotTieuDe: CotBang? { properties.first { $0.isTitle == true } ?? properties.first }
}

struct CotBang: Codable, Identifiable, Hashable {
    // `AnyCodable` không Hashable/Equatable được (nó bọc `Any`), nên so sánh
    // và băm theo `id` — đủ, vì id là duy nhất trong một bảng.
    static func == (a: CotBang, b: CotBang) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    let id: Int
    let name: String
    let type: String
    let isTitle: Bool?
    let sortOrder: Int?
    let config: [String: AnyCodable]?

    var kieu: KieuCot { KieuCot(rawValue: type) ?? .khac }

    /// Lựa chọn cho cột SELECT / MULTI_SELECT / STATUS, đọc từ `config.options`.
    var luaChon: [String] {
        guard let ds = config?["options"]?.value as? [Any] else { return [] }
        return ds.compactMap { m in
            if let s = m as? String { return s }
            if let d = m as? [String: Any] { return d["name"] as? String ?? d["label"] as? String }
            if let a = m as? AnyCodable, let d = a.value as? [String: Any] {
                return d["name"] as? String ?? d["label"] as? String
            }
            return nil
        }
    }
}

/// 17 kiểu cột của máy chủ. Ba kiểu cuối máy chủ TÍNH lúc đọc, không lưu.
enum KieuCot: String {
    case title = "TITLE", text = "TEXT", number = "NUMBER"
    case select = "SELECT", multiSelect = "MULTI_SELECT", status = "STATUS"
    case date = "DATE", checkbox = "CHECKBOX", url = "URL", email = "EMAIL"
    case person = "PERSON", file = "FILE"
    case createdTime = "CREATED_TIME", lastEditedTime = "LAST_EDITED_TIME"
    case relation = "RELATION", rollup = "ROLLUP", formula = "FORMULA"
    case khac

    /// Cột app này SỬA được. Ba kiểu tính-lúc-đọc và quan hệ/rollup/công thức
    /// thì máy chủ BỎ QUA khi ghi — hiện chúng ở dạng chỉ-đọc thay vì cho gõ
    /// rồi lặng lẽ mất.
    var suaDuoc: Bool {
        switch self {
        case .title, .text, .number, .select, .multiSelect, .status,
             .date, .checkbox, .url, .email: return true
        default: return false
        }
    }

    var bieuTuong: String {
        switch self {
        case .title: return "textformat"
        case .text: return "text.alignleft"
        case .number: return "number"
        case .select, .status: return "chevron.down.circle"
        case .multiSelect: return "tag"
        case .date, .createdTime, .lastEditedTime: return "calendar"
        case .checkbox: return "checkmark.square"
        case .url: return "link"
        case .email: return "envelope"
        case .person: return "person"
        case .file: return "paperclip"
        case .relation: return "arrow.triangle.branch"
        case .rollup: return "sum"
        case .formula: return "function"
        case .khac: return "questionmark"
        }
    }
}

struct KieuXemBang: Codable, Identifiable, Hashable {
    let id: Int
    let name: String?
    let type: String?
    let sortOrder: Int?
}

struct DongBang: Codable, Identifiable {
    let id: Int
    let sortOrder: Int?
    let createdAt: String?
    let updatedAt: String?
    let values: [String: AnyCodable]?

    /// ⚠️ Khoá là CHUỖI — xem chú thích đầu tệp.
    func giaTri(_ cot: CotBang) -> Any? { values?[String(cot.id)]?.value }

    /// Chữ hiện trong ô, đã theo đúng kiểu cột.
    func chu(_ cot: CotBang) -> String {
        guard let v = giaTri(cot) else { return "" }
        switch cot.kieu {
        case .checkbox:
            return (v as? Bool ?? false) ? "✓" : ""
        case .multiSelect:
            if let ds = v as? [Any] { return ds.compactMap { $0 as? String }.joined(separator: ", ") }
            return moTa(v)
        case .date, .createdTime, .lastEditedTime:
            guard let s = v as? String, let d = Date.tuChuoiISO(s) else { return moTa(v) }
            let f = DateFormatter()
            f.locale = Locale(identifier: "vi_VN")
            f.dateFormat = "d/M/yyyy"
            return f.string(from: d)
        case .number:
            if let n = v as? Double { return n == n.rounded() ? String(Int(n)) : String(n) }
            return moTa(v)
        default:
            return moTa(v)
        }
    }

    private func moTa(_ v: Any) -> String {
        if let s = v as? String { return s }
        if let b = v as? Bool { return b ? "✓" : "" }
        if let i = v as? Int { return String(i) }
        if let d = v as? Double { return d == d.rounded() ? String(Int(d)) : String(d) }
        if let ds = v as? [Any] { return ds.map { moTa($0) }.joined(separator: ", ") }
        if v is NSNull { return "" }
        return ""
    }
}

/// Một bảng trong danh sách của môn — `GET /notes-databases/subject/:id`.
struct BangTomTat: Codable, Identifiable {
    let id: Int
    let title: String?
    let icon: String?
    let properties: [CotBang]?
    let _count: SoDong?

    var ten: String { (title?.isEmpty == false ? title! : nil) ?? "Bảng chưa đặt tên" }
    var soDong: Int { _count?.rows ?? 0 }

    struct SoDong: Codable { let rows: Int? }
}
