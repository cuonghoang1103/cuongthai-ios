import Foundation

// MARK: - CT Work — model mảng Yêu cầu (SRS · RTM · Wiegers/SWR302)
//
// Nguồn hình dạng: `srs.service.ts`, `rtm.ts`, `swr.service.ts`, `swrElic.service.ts`,
// `srsDeep.service.ts` (kiểu TS đối chiếu: frontend/src/lib/work-ctw4-api.ts,
// work-swr-api.ts, work-swr6b-api.ts).
// Luật: mọi trường `var` + optional, ngày là CHUỖI (CLAUDE.md C3/C4) — một trường
// lệch là cả màn hỏng câm, nên kể cả mảng cũng để optional.

// MARK: SRS — `GET /projects/:pid/srs`

struct CTWSrsActor: Codable, Hashable, Identifiable {
    var id: Int
    var name: String?
    var description: String?
    /// PERSON | SYSTEM
    var kind: String?
    var position: Int?
}

struct CTWSrsIssueRef: Codable, Hashable {
    struct Loai: Codable, Hashable { var key: String? }
    struct TrangThai: Codable, Hashable { var name: String?; var category: String? }
    var number: Int
    var key: String?
    var title: String?
    var type: Loai?
    var status: TrangThai?
}

struct CTWSrsUseCase: Codable, Hashable, Identifiable {
    var id: Int
    var number: Int
    var key: String?
    var name: String?
    var feature: String?
    var description: String?
    var trigger: String?
    var preconditions: String?
    var postconditions: String?
    var normalFlow: String?
    var alternativeFlows: String?
    var exceptionFlows: String?
    /// HIGH | MEDIUM | LOW
    var priority: String?
    /// PROPOSED | DRAFT | APPROVED
    var status: String?
    var primaryActorId: Int?
    var secondaryActorIds: [Int]?
    var ruleNumbers: [Int]?
    var issueKey: String?
    var section: String?
    /// "primary actor", "description"… — trường còn thiếu cho đặc tả UC.
    var missing: [String]?
    var version: Int?
    var aiModel: String?
    var updatedAt: String?
    var issue: CTWSrsIssueRef?

    var ma: String { key ?? String(format: "UC-%02d", number) }
}

struct CTWSrsRule: Codable, Hashable, Identifiable {
    var id: Int
    var number: Int
    var key: String?
    var name: String?
    var definition: String?
    var category: String?
    var status: String?
    var usedIn: [String]?
    var aiModel: String?

    var ma: String { key ?? String(format: "BR-%02d", number) }
}

struct CTWSrsScreen: Codable, Hashable, Identifiable {
    var id: Int
    var name: String?
    var feature: String?
    var description: String?
    var position: Int?
}

struct CTWSrsLink: Codable, Hashable {
    var fromId: Int
    var toId: Int
    var label: String?
}

struct CTWSrsFunction: Codable, Hashable, Identifiable {
    var id: Int
    var feature: String?
    var name: String?
    var description: String?
    var position: Int?
}

struct CTWSrsCounts: Codable, Hashable {
    var useCases: Int?
    var proposed: Int?
    var approved: Int?
    var rules: Int?
    var screens: Int?
}

struct CTWSrsData: Codable {
    struct TrangR3: Codable, Hashable { var number: Int; var title: String? }
    var key: String?
    var actors: [CTWSrsActor]?
    var useCases: [CTWSrsUseCase]?
    var rules: [CTWSrsRule]?
    var screens: [CTWSrsScreen]?
    var links: [CTWSrsLink]?
    /// Ô "X" của ma trận phân quyền: `[screenId, actorId]`.
    var auth: [[Int]]?
    var functions: [CTWSrsFunction]?
    var report3Page: TrangR3?
    var canEdit: Bool?
    var canApprove: Bool?
    var counts: CTWSrsCounts?

    // MARK: Tra cứu (logic thuần — có kiểm thử)

    func actor(_ id: Int?) -> CTWSrsActor? {
        guard let id else { return nil }
        return (actors ?? []).first { $0.id == id }
    }
    func rule(_ n: Int) -> CTWSrsRule? { (rules ?? []).first { $0.number == n } }
    func screen(_ id: Int) -> CTWSrsScreen? { (screens ?? []).first { $0.id == id } }

    /// Diễn viên được vào màn `screenId` (theo ma trận `auth`).
    func actorsCho(screen screenId: Int) -> [CTWSrsActor] {
        let ids = Set((auth ?? []).compactMap { $0.count == 2 && $0[0] == screenId ? $0[1] : nil })
        return (actors ?? []).filter { ids.contains($0.id) }.sorted { ($0.position ?? 0) < ($1.position ?? 0) }
    }
    func duocVao(screen: Int, actor: Int) -> Bool {
        (auth ?? []).contains { $0.count == 2 && $0[0] == screen && $0[1] == actor }
    }
    /// Màn đi tới được từ `screenId` (cạnh `links`).
    func diToi(tu screenId: Int) -> [(screen: CTWSrsScreen, nhan: String?)] {
        (links ?? []).filter { $0.fromId == screenId }.compactMap { l in screen(l.toId).map { ($0, l.label) } }
    }
    func diTu(den screenId: Int) -> [CTWSrsScreen] {
        (links ?? []).filter { $0.toId == screenId }.compactMap { screen($0.fromId) }
    }

    /// UC gom theo tính năng (giữ thứ tự xuất hiện; không tính năng ⇒ "Other").
    var ucTheoTinhNang: [(tinhNang: String, ds: [CTWSrsUseCase])] {
        var thuTu: [String] = []
        var nhom: [String: [CTWSrsUseCase]] = [:]
        let khac = String(localized: "Other")
        for u in (useCases ?? []).sorted(by: { $0.number < $1.number }) {
            let f = (u.feature?.trimmingCharacters(in: .whitespaces)).flatMap { $0.isEmpty ? nil : $0 } ?? khac
            if nhom[f] == nil { thuTu.append(f) }
            nhom[f, default: []].append(u)
        }
        if let i = thuTu.firstIndex(of: khac) { thuTu.append(thuTu.remove(at: i)) }
        return thuTu.map { ($0, nhom[$0] ?? []) }
    }
}

// MARK: Luồng UC — chữ nhiều dòng ⇒ các bước có nhãn

/// Một bước của luồng: "1. Open assignment" ⇒ (nhan "1", chu "Open assignment");
/// "2A. File too large" ⇒ ("2A", …); dòng không đánh số ⇒ nhan nil (dòng tiếp nối).
struct CTWBuocLuong: Hashable {
    var nhan: String?
    var chu: String
    /// Bước nhánh (2A, 3B.1…) — thụt vào trong.
    var laNhanh: Bool
}

enum CTWLuongUC {
    static func tach(_ s: String?) -> [CTWBuocLuong] {
        guard let s else { return [] }
        return s.components(separatedBy: .newlines).compactMap { dongGoc in
            var d = dongGoc.trimmingCharacters(in: .whitespaces)
            guard !d.isEmpty else { return nil }
            // Gạch đầu dòng markdown đi trước số ("- 1. …") — bỏ.
            for t in ["- ", "* ", "• "] where d.hasPrefix(t) { d = String(d.dropFirst(t.count)) }
            // Nhãn: chữ số + chữ cái/chấm, kết thúc bằng "." / ")" / ":" rồi khoảng trắng.
            var i = d.startIndex
            while i < d.endIndex, d[i].isNumber || d[i].isLetter || d[i] == "." { i = d.index(after: i) }
            let nhanTho = String(d[d.startIndex..<i])
            let coSo = nhanTho.first?.isNumber == true
            var sau = i
            if sau < d.endIndex, d[sau] == ")" || d[sau] == ":" { sau = d.index(after: sau) }
            let hopLe = coSo && nhanTho.count <= 8 && (sau == d.endIndex || d[sau] == " ")
                && (nhanTho.hasSuffix(".") || sau != i)
            guard hopLe else { return CTWBuocLuong(nhan: nil, chu: d, laNhanh: false) }
            let nhan = nhanTho.hasSuffix(".") ? String(nhanTho.dropLast()) : nhanTho
            let chu = String(d[sau...]).trimmingCharacters(in: .whitespaces)
            let nhanh = nhan.contains { $0.isLetter } || nhan.contains(".")
            return CTWBuocLuong(nhan: nhan, chu: chu, laNhanh: nhanh)
        }
    }
}

// MARK: RTM — `GET /projects/:pid/rtm`

struct CTWRtmTestSet: Codable, Hashable {
    var name: String?
    var ref: String?
    var cases: Int?
    var passed: Int?
    var failed: Int?
    var notRun: Int?
}

struct CTWRtmRow: Codable, Hashable, Identifiable {
    struct Code: Codable, Hashable {
        struct Moi: Codable, Hashable { var title: String?; var url: String? }
        var commits: Int?
        var prs: Int?
        var branches: Int?
        var latest: Moi?
    }
    struct Xray: Codable, Hashable { var key: String?; var title: String?; var last: String? }
    struct Loi: Codable, Hashable { var key: String?; var title: String?; var open: Bool?; var severity: String? }

    var reqId: String
    var kind: String?
    var ucNumber: Int?
    var issueNumber: Int?
    var issueKey: String?
    var requirement: String?
    var feature: String?
    var rules: [String]?
    var srs: [String]?
    var screens: [String]?
    var sds: [String]?
    var code: Code?
    var unit: [CTWRtmTestSet]?
    var integration: [CTWRtmTestSet]?
    var system: [CTWRtmTestSet]?
    var xray: [Xray]?
    var bugs: [Loi]?
    var iteration: String?
    var issueDone: Bool?
    var ucMissing: [String]?
    /// Planned | Analyzed | Designed | Coded | Tested
    var status: String?
    var gaps: [String]?

    var id: String { reqId }
    var soCaKiem: Int {
        ([unit, integration, system].compactMap { $0 }.flatMap { $0 }.reduce(0) { $0 + ($1.cases ?? 0) }) + (xray?.count ?? 0)
    }
}

struct CTWRtmData: Codable {
    struct TomTat: Codable, Hashable {
        var rows: Int?
        var useCases: Int?
        var requirements: Int?
        var withTests: Int?
        var testedPct: Double?
        var passing: Int?
        var withGaps: Int?
        var gaps: [String: Int]?
    }
    var rows: [CTWRtmRow]?
    var summary: TomTat?
    var gapLabels: [String: String]?
}

// MARK: Wiegers — yêu cầu `GET /swr/requirements`

struct CTWSwrRequirement: Codable, Hashable, Identifiable {
    struct TrangThai: Codable, Hashable { var name: String?; var category: String? }
    var issueId: Int
    var number: Int
    var key: String?
    var title: String?
    var text: String?
    var parentId: Int?
    var status: TrangThai?
    var classified: Bool?
    var reqType: String?
    var subtype: String?
    var priority: String?
    var lifecycle: String?
    var source: String?
    var ownerId: Int?
    var rationale: String?
    var stability: String?
    var reqVersion: Int?
    var updatedAt: String?
    var next: [String]?

    var id: Int { issueId }
}

struct CTWSwrRequirementList: Codable {
    struct Dem: Codable, Hashable {
        var total: Int?
        var unclassified: Int?
        var byType: [String: Int]?
        var byLifecycle: [String: Int]?
    }
    struct ChuSoHuu: Codable, Hashable { var id: Int; var name: String? }
    var key: String?
    var canEdit: Bool?
    var canApprove: Bool?
    var requirements: [CTWSwrRequirement]?
    var counts: Dem?
    var owners: [ChuSoHuu]?
}

struct CTWSwrHistoryRow: Codable, Hashable, Identifiable {
    var id: Int
    var field: String?
    var from: String?
    var to: String?
    var at: String?
    var actor: String?
    var actorKind: String?
}

/// Vòng đời yêu cầu (Wiegers Figure 27-2) — CHÉP từ `swr.ts LIFECYCLE_NEXT` để app
/// tự ẩn nút không hợp lệ khi máy chủ chưa trả `next` (bản cũ / lỗi). Máy chủ vẫn là nơi phán.
enum CTWVongDoiYeuCau {
    static let tatCa = ["PROPOSED", "APPROVED", "IMPLEMENTED", "VERIFIED", "DELETED", "REJECTED"]
    static let tiep: [String: [String]] = [
        "PROPOSED": ["APPROVED", "REJECTED", "DELETED"],
        "APPROVED": ["IMPLEMENTED", "DELETED"],
        "IMPLEMENTED": ["VERIFIED", "APPROVED", "DELETED"],
        "VERIFIED": ["IMPLEMENTED", "DELETED"],
        "DELETED": ["PROPOSED"],
        "REJECTED": ["PROPOSED"],
    ]
    static func diDuoc(_ tu: String?, _ den: String) -> Bool { (tiep[tu ?? "PROPOSED"] ?? []).contains(den) }
    /// Đích này cần NGƯỜI DUYỆT (canApprove); chỉ IMPLEMENTED/PROPOSED là người sửa được (canEdit).
    static func canDuyet(_ den: String) -> Bool { den != "IMPLEMENTED" && den != "PROPOSED" }
    /// Nút được hiện cho người này.
    static func nutHien(_ r: CTWSwrRequirement, canEdit: Bool, canApprove: Bool) -> [String] {
        let ds = r.next ?? tiep[r.lifecycle ?? "PROPOSED"] ?? []
        return ds.filter { canDuyet($0) ? canApprove : canEdit }
    }
    static func nhanHanhDong(_ den: String) -> String {
        switch den {
        case "APPROVED": return String(localized: "Approve")
        case "IMPLEMENTED": return String(localized: "Mark implemented")
        case "VERIFIED": return String(localized: "Mark verified")
        case "DELETED": return String(localized: "Delete")
        case "REJECTED": return String(localized: "Reject")
        case "PROPOSED": return String(localized: "Reopen as proposed")
        default: return CTWMauTrangThai.nhan(den)
        }
    }
    static func tenLoai(_ t: String?) -> String {
        switch t {
        case "BUSINESS": return String(localized: "Business")
        case "USER": return String(localized: "User")
        case "FUNCTIONAL": return String(localized: "Functional")
        case "QUALITY": return String(localized: "Quality")
        case "CONSTRAINT": return String(localized: "Constraint")
        case "EXTERNAL_INTERFACE": return String(localized: "External interface")
        case "DATA": return String(localized: "Data")
        case nil: return String(localized: "Unclassified")
        default: return CTWMauTrangThai.nhan(t)
        }
    }
}

// MARK: Wiegers — tính năng, stakeholder, thuật ngữ, elicitation, NFR, prototype

struct CTWSwrFeature: Codable, Hashable, Identifiable {
    struct Epic: Codable, Hashable { var number: Int?; var key: String?; var title: String? }
    struct UC: Codable, Hashable { var number: Int; var key: String?; var name: String?; var status: String? }
    struct The: Codable, Hashable { var number: Int; var key: String?; var title: String?; var type: String? }
    var id: Int
    var number: Int?
    var key: String?
    var name: String?
    var description: String?
    /// IN | OUT (phạm vi)
    var scope: String?
    var priority: String?
    var release: String?
    var epic: Epic?
    var useCases: [UC]?
    var issues: [The]?
    var realized: Bool?
}

struct CTWSwrFeatureList: Codable {
    var key: String?
    var canEdit: Bool?
    var features: [CTWSwrFeature]?
}

struct CTWSwrStakeholder: Codable, Hashable, Identifiable {
    var id: Int
    var number: Int?
    var key: String?
    var name: String?
    var role: String?
    var organization: String?
    var kind: String?
    var userClass: String?
    var influence: Int?
    var interest: Int?
    var attitude: String?
    var isChampion: Bool?
    var decisionRights: String?
    var majorValue: String?
    var interests: String?
    var constraints: String?
    var contact: String?
    var notes: String?
    /// MANAGE_CLOSELY | KEEP_SATISFIED | KEEP_INFORMED | MONITOR
    var quadrant: String?
    var sessions: [String]?
    var requirements: Int?
}

struct CTWSwrStakeholderList: Codable {
    var stakeholders: [CTWSwrStakeholder]?
    var grid: [String: [String]]?
    var canEdit: Bool?
}

struct CTWSwrTerm: Codable, Hashable, Identifiable {
    var id: Int
    var term: String?
    var definition: String?
    var aliases: [String]?
    var source: String?
}

struct CTWSwrGlossary: Codable {
    struct VaCham: Codable, Hashable { var word: String?; var terms: [String]? }
    var terms: [CTWSwrTerm]?
    var clashes: [VaCham]?
    var canEdit: Bool?
}

struct CTWSwrSessionPerson: Codable, Hashable {
    var key: String?
    var name: String?
    var role: String?
    var rolePlayed: String?
}

struct CTWSwrSessionRow: Codable, Hashable, Identifiable {
    var number: Int
    var key: String?
    var title: String?
    var technique: String?
    var status: String?
    var scheduledAt: String?
    var durationMin: Int?
    var aiSimulated: Bool?
    var participants: [CTWSwrSessionPerson]?
    var questions: Int?
    var answered: Int?
    var requirements: Int?
    var pending: Int?

    var id: Int { number }
}

struct CTWSwrSessions: Codable {
    var sessions: [CTWSwrSessionRow]?
    var canEdit: Bool?
    var canApprove: Bool?
}

struct CTWSwrSessionDetail: Codable {
    struct CauHoi: Codable, Hashable { var id: String?; var text: String?; var answer: String? }
    struct DeXuat: Codable, Hashable, Identifiable {
        struct NguoiLQ: Codable, Hashable { var key: String?; var name: String? }
        struct ChungCu: Codable, Hashable { var line: Int?; var quote: String? }
        var id: Int
        var title: String?
        var text: String?
        var reqType: String?
        var priority: String?
        /// PENDING | ACCEPTED | DISMISSED
        var status: String?
        var model: String?
        var stakeholder: NguoiLQ?
        var evidence: [ChungCu]?
        var issue: String?
    }
    struct YeuCau: Codable, Hashable {
        var originId: Int?
        var key: String?
        var number: Int?
        var title: String?
        var lifecycle: String?
    }
    struct NguoiThamGia: Codable, Hashable {
        var stakeholderId: Int?
        var key: String?
        var name: String?
        var role: String?
        var rolePlayed: String?
    }
    var number: Int
    var key: String?
    var title: String?
    var technique: String?
    var status: String?
    var scheduledAt: String?
    var durationMin: Int?
    var location: String?
    var objective: String?
    var plan: String?
    var questions: [CauHoi]?
    var notes: String?
    var outcome: String?
    var aiSimulated: Bool?
    var participants: [NguoiThamGia]?
    var proposals: [DeXuat]?
    var requirements: [YeuCau]?
    var canEdit: Bool?
    var canApprove: Bool?
}

struct CTWSwrNfr: Codable {
    struct Spec: Codable, Hashable {
        var characteristic: String?
        var subCharacteristic: String?
        var scale: String?
        var meter: String?
        var unit: String?
        var comparator: String?
        var mustValue: Double?
        var planValue: Double?
        var wishValue: Double?
        var conditions: String?
        var verification: String?
    }
    struct Muc: Codable, Hashable, Identifiable {
        var number: Int
        var key: String?
        var title: String?
        var text: String?
        var subtype: String?
        var priority: String?
        var lifecycle: String?
        var spec: Spec?
        var statement: String?
        var id: Int { number }
    }
    struct DacTinh: Codable, Hashable { var key: String; var label: String? }
    var requirements: [Muc]?
    var characteristics: [DacTinh]?
    var measured: Int?
    var canEdit: Bool?
}

struct CTWSwrMockup: Codable, Hashable, Identifiable {
    var id: Int
    var screenId: Int?
    var screen: String?
    /// IMAGE | LINK
    var kind: String?
    var url: String?
    var provider: String?
    var title: String?
    /// Ảnh tương đối `/api/v1/work/projects/:pid/images/:id` (cần token).
    var image: String?
    /// DRAFT | SUBMITTED | APPROVED | CHANGES
    var status: String?
    var reviewerName: String?
    var reviewerRole: String?
    var reviewNote: String?
    var reviewedAt: String?
    var updatedAt: String?
}

struct CTWSwrMockups: Codable {
    struct Man: Codable, Hashable, Identifiable {
        var id: Int
        var name: String?
        var feature: String?
        var mockups: [CTWSwrMockup]?
        var approved: Bool?
    }
    struct Dem: Codable, Hashable { var screens: Int?; var withPrototype: Int?; var approved: Int? }
    var screens: [Man]?
    var counts: Dem?
}

struct CTWSrsTaoKetQua: Codable { var id: Int?; var number: Int?; var key: String? }
