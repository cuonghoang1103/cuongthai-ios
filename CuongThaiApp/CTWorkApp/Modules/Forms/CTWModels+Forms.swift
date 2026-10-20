import Foundation

// MARK: - CT Work — model Forms (`services/work/forms.service.ts`; kiểu ở `work-ctw7b-api.ts`).
// Mỗi câu trả lời form tự sinh một thẻ. `var` + optional, ngày là chuỗi.

struct CTWTruongForm: Codable, Hashable, Identifiable {
    var id: String
    /// text | longtext | select | multiselect | number | date | file | user
    var kind: String?
    var label: String?
    var help: String?
    var required: Bool?
    var options: [String]?
    var min: Double?
    var max: Double?
}

struct CTWForm: Codable, Hashable, Identifiable {
    var id: Int
    var number: Int?
    var key: String?
    var title: String
    var description: String?
    var fields: [CTWTruongForm]?
    /// PUBLIC | INTERNAL
    var access: String?
    /// DRAFT | OPEN | CLOSED
    var status: String?
    var confirmMessage: String?
    var collectEmail: Bool?
    var maxResponses: Int?
    var closesAt: String?
    /// Link điền form — chỉ có khi người xem sửa được.
    var link: String?
    /// CLOSED | EXPIRED | FULL | null
    var closed: String?
    var responses: Int?
    var createdAt: String?
    var updatedAt: String?
}

struct CTWDsForm: Codable {
    var forms: [CTWForm]?
    var canEdit: Bool?
    var canPublish: Bool?
}

struct CTWTraLoiForm: Codable {
    struct TomTat: Codable, Hashable, Identifiable {
        struct Dem: Codable, Hashable { var option: String?; var n: Int? }
        var id: String
        var label: String?
        var kind: String?
        var answered: Int?
        var counts: [Dem]?
        var average: Double?
        var min: Double?
        var max: Double?
        var earliest: String?
        var latest: String?
        var samples: [String]?
    }
    struct PhanHoi: Codable, Hashable, Identifiable {
        struct The: Codable, Hashable { var number: Int?; var key: String? }
        var id: Int
        var createdAt: String?
        var issue: The?
        var respondent: String?
        var email: String?
        var answers: [String: CTWGiaTri]?
    }
    struct DauForm: Codable { var key: String?; var title: String?; var fields: [CTWTruongForm]? }
    var form: DauForm?
    var total: Int?
    var summary: [TomTat]?
    var responses: [PhanHoi]?
}

enum CTWFormNhan {
    static func bieuTuong(_ kind: String?) -> String {
        switch kind {
        case "longtext": return "text.alignleft"
        case "select": return "list.bullet.circle"
        case "multiselect": return "checklist"
        case "number": return "number"
        case "date": return "calendar"
        case "file": return "paperclip"
        case "user": return "person"
        default: return "character.cursor.ibeam"
        }
    }

    static func lyDoDong(_ s: String?) -> String? {
        switch s {
        case "CLOSED": return String(localized: "Closed")
        case "EXPIRED": return String(localized: "Past closing date")
        case "FULL": return String(localized: "Response limit reached")
        default: return nil
        }
    }
}
