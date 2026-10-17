import Foundation

// MARK: - Model Retrospective (đối chiếu `services/work/retro.service.ts:86-186`, `agileRules.ts:225-258`)
// Không có "phase" — chỉ có khoá (`locked`: khoá tay hoặc quá `lockAt`).

struct CTWRetroDs: Codable {
    struct Retro: Codable, Hashable, Identifiable {
        struct SprintRef: Codable, Hashable { var id: Int?; var name: String?; var state: String? }
        var id: Int
        var title: String?
        /// SSC | MSG | FOUR_L
        var template: String?
        var anonymous: Bool?
        var sprint: SprintRef?
        var locked: Bool?
        var lockAt: String?
        var cards: Int?
        var actions: Int?
        var hasSummary: Bool?
        var createdBy: CTWUser?
        var createdAt: String?
    }
    var canCreate: Bool?
    var retros: [Retro]?
}

struct CTWRetroThe: Codable, Hashable, Identifiable {
    var id: Int
    var column: String
    var body: String?
    var groupId: Int?
    var position: Int?
    var votes: Int?
    var myVotes: Int?
    var mine: Bool?
    /// LUÔN nil khi retro ẩn danh (kể cả với ADMIN).
    var author: CTWUser?
    var createdAt: String?
}

struct CTWRetroViec: Codable, Hashable, Identifiable {
    struct The: Codable, Hashable {
        struct TrangThai: Codable, Hashable { var name: String?; var category: String? }
        var id: Int?
        var number: Int?
        var title: String?
        var status: TrangThai?
    }
    var id: Int
    var cardId: Int?
    var title: String?
    var assignee: CTWUser?
    var issue: The?
    var createdAt: String?
}

struct CTWRetro: Codable {
    struct Toi: Codable, Hashable {
        var canWrite: Bool?
        var canFacilitate: Bool?
        var canUseAi: Bool?
        var votesLeft: Int?
        var votesUsed: Int?
    }
    var id: Int
    var projectId: Int?
    var title: String?
    var template: String?
    var columns: [String]?
    var sprint: CTWRetroDs.Retro.SprintRef?
    var anonymous: Bool?
    var votesPerPerson: Int?
    var lockAt: String?
    var locked: Bool?
    var lockedManually: Bool?
    var summary: String?
    var summaryAt: String?
    var createdAt: String?
    var facilitator: CTWUser?
    var me: Toi?
    var cards: [CTWRetroThe]?
    var actions: [CTWRetroViec]?
}

struct CTWRetroTao: Codable { var id: Int? }
struct CTWRetroPhieu: Codable { var votesLeft: Int?; var mine: Int? }

/// Tên cột hiển thị + biểu tượng + màu theo khoá cột của template.
enum RetroCot {
    static func cot(template: String?) -> [String] {
        switch template {
        case "MSG": return ["MAD", "SAD", "GLAD"]
        case "FOUR_L": return ["LIKED", "LEARNED", "LACKED", "LONGED_FOR"]
        default: return ["START", "STOP", "CONTINUE"]
        }
    }
    static func ten(_ k: String) -> String {
        switch k {
        case "START": return "Start"
        case "STOP": return "Stop"
        case "CONTINUE": return "Continue"
        case "MAD": return "Mad"
        case "SAD": return "Sad"
        case "GLAD": return "Glad"
        case "LIKED": return "Liked"
        case "LEARNED": return "Learned"
        case "LACKED": return "Lacked"
        case "LONGED_FOR": return "Longed for"
        default: return k.capitalized
        }
    }
    static func bieuTuong(_ k: String) -> String {
        switch k {
        case "START": return "play.circle"
        case "STOP": return "stop.circle"
        case "CONTINUE": return "arrow.forward.circle"
        case "MAD": return "flame"
        case "SAD": return "cloud.rain"
        case "GLAD": return "sun.max"
        case "LIKED": return "hand.thumbsup"
        case "LEARNED": return "lightbulb"
        case "LACKED": return "exclamationmark.circle"
        case "LONGED_FOR": return "sparkles"
        default: return "square.stack"
        }
    }
    static func tenTemplate(_ t: String?) -> String {
        switch t {
        case "MSG": return "Mad · Sad · Glad"
        case "FOUR_L": return "4Ls"
        default: return "Start · Stop · Continue"
        }
    }
}
