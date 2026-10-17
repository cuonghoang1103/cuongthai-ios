import Foundation

// MARK: - Model Planning Poker (đối chiếu `services/work/poker.service.ts:95-214`, `agileRules.ts:110-182`)

struct CTWPokerDs: Codable {
    struct Phien: Codable, Hashable, Identifiable {
        struct SprintRef: Codable, Hashable { var id: Int?; var name: String? }
        var id: Int
        var title: String?
        /// FIBONACCI | TSHIRT
        var deck: String?
        /// OPEN | CLOSED
        var status: String?
        var sprint: SprintRef?
        var createdBy: CTWUser?
        var createdAt: String?
        var closedAt: String?
        var items: Int?
        var estimated: Int?
        var points: Double?
    }
    var canCreate: Bool?
    var sessions: [Phien]?
}

struct CTWPokerPhanBo: Codable, Hashable {
    struct Dem: Codable, Hashable { var value: String; var count: Int }
    var counts: [Dem]?
    var voters: Int?
    var numeric: Int?
    var average: Double?
    var median: Double?
    var consensus: Bool?
    var mode: String?
    var low: String?
    var high: String?
    var suggested: String?
}

struct CTWPokerPhieu: Codable, Hashable { var user: CTWUser?; var value: String }

struct CTWPokerMuc: Codable, Hashable, Identifiable {
    struct The: Codable, Hashable {
        struct Loai: Codable, Hashable { var key: String?; var name: String?; var color: String? }
        struct TrangThai: Codable, Hashable { var name: String?; var category: String? }
        var number: Int
        var title: String?
        var storyPoints: Double?
        var type: Loai?
        var status: TrangThai?
        var description: String?
    }
    struct Vong: Codable, Hashable { var round: Int?; var votes: [CTWPokerPhieu]?; var distribution: CTWPokerPhanBo? }
    var id: Int
    var position: Int?
    /// PENDING | VOTING | REVEALED | ESTIMATED | SKIPPED
    var state: String?
    var round: Int?
    var issue: The?
    var finalValue: String?
    var finalPoints: Double?
    var previousPoints: Double?
    var estimatedBy: CTWUser?
    var estimatedAt: String?
    var revealedAt: String?
    /// userId đã bỏ phiếu ở vòng này (luôn thấy — giá trị thì KHÔNG khi chưa lật).
    var voted: [Int]?
    var myVote: String?
    /// nil khi PENDING/VOTING (bài úp).
    var votes: [CTWPokerPhieu]?
    var distribution: CTWPokerPhanBo?
    var rounds: [Vong]?

    var daLat: Bool { state == "REVEALED" || state == "ESTIMATED" }
}

struct CTWPokerPhong: Codable {
    struct La: Codable, Hashable { var value: String; var points: Double? }
    struct Toi: Codable, Hashable { var canVote: Bool?; var canFacilitate: Bool? }
    var id: Int
    var projectId: Int?
    var title: String?
    var deck: String?
    var cards: [La]?
    var status: String?
    var sprint: CTWPokerDs.Phien.SprintRef?
    var currentItemId: Int?
    var timerEndsAt: String?
    var serverNow: String?
    var createdAt: String?
    var closedAt: String?
    var facilitator: CTWUser?
    var me: Toi?
    var voters: [CTWUser]?
    var items: [CTWPokerMuc]?

    var mucHienTai: CTWPokerMuc? { items?.first { $0.id == currentItemId } }
    var daDong: Bool { status == "CLOSED" }
}

struct CTWPokerTao: Codable { var id: Int?; var items: Int? }
