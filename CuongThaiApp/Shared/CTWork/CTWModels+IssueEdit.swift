import Foundation

// MARK: - CT Work — model SỬA THẺ (trường đầy đủ, trường tuỳ chỉnh, nhật ký giờ, liên kết…) — 20/10/2026
//
// Hình dạng đối chiếu backend (đọc service, không đoán):
//   · thẻ `getIssueDetail` (issues.service.ts — CARD_SELECT + pickDetail) · cấu hình `getProject`
//   · trường tuỳ chỉnh `custom.service.ts` (giá trị theo kiểu: TEXT/URL/DATE/SELECT = chuỗi, NUMBER/USER = số,
//     CHECKBOX = bool, MULTISELECT = mảng chuỗi)
//   · nhật ký giờ `planning.service.ts` (WORKLOG_SELECT) · bộ phận `teams.service.ts` · giai đoạn `stages.service.ts`
//   · liên kết web `resources.service.ts` · tài liệu liên kết `pages.service.ts → issuePages`
// Tệp RIÊNG (không sửa `CTWorkModels.swift`) — model lõi giữ nguyên cho các mảng khác.
// Luật kho (CLAUDE.md C3/C4): mọi trường `var` + optional, ngày là CHUỖI.

/// Phần thẻ mà `CTWIssueDetail` (model lõi, dùng chung) không khai — giải mã từ CÙNG một phản hồi.
struct CTWIssueThem: Codable {
    var version: Int?
    var fixVersionId: Int?
    var teamId: Int?
    var stageId: Int?
    var componentIds: [Int]?
    var originalEstimateMin: Int?
    var remainingEstimateMin: Int?
    var timeSpentMin: Int?
    var flagReason: String?
    var clientVisible: Bool?
    var aiAssisted: Bool?
    /// Mô tả THÔ (giữ mọi attrs/marks) — chỉ đường này được dùng để GHI lại.
    var descriptionJson: CTWJSON?
}

struct CTWVersionRef: Codable, Hashable, Identifiable {
    var id: Int
    var name: String
    /// UNRELEASED | RELEASED | ARCHIVED
    var status: String?
}

struct CTWComponent: Codable, Hashable, Identifiable {
    var id: Int
    var name: String
    var description: String?
}

struct CTWCustomOption: Codable, Hashable, Identifiable {
    var id: String
    var label: String
    var color: String?
}

struct CTWCustomField: Codable, Hashable, Identifiable {
    var id: Int
    var name: String
    /// TEXT | NUMBER | DATE | SELECT | MULTISELECT | USER | URL | CHECKBOX
    var kind: String
    var options: [CTWCustomOption]?
    var typeKeys: [String]?
    var required: Bool?
    var position: Int?

    func apCho(loai key: String?) -> Bool {
        guard let ks = typeKeys, !ks.isEmpty else { return true }
        guard let key else { return false }
        return ks.contains(key)
    }
}

/// Phần cấu hình dự án mà `CTWProjectConfig` (lõi) không khai.
struct CTWCauHinhThem: Codable {
    struct CaiDat: Codable { var estimation: String? }
    var versions: [CTWVersionRef]?
    var components: [CTWComponent]?
    var customFields: [CTWCustomField]?
    var settings: CaiDat?
    var editLocked: Bool?
    var clientView: Bool?

    /// Ước lượng theo GIỜ (`settings.estimation == "HOURS"`) thay vì story point.
    var theoGio: Bool { settings?.estimation == "HOURS" }
}

/// Giá trị một trường tuỳ chỉnh.
enum CTWGiaTriTruong: Hashable {
    case chu(String)
    case so(Double)
    case co(Bool)
    case nhieu([String])

    init?(_ j: CTWJSON?) {
        switch j {
        case .chuoi(let s)?: self = .chu(s)
        case .so(let n)?: self = .so(n)
        case .bool(let b)?: self = .co(b)
        case .mang(let a)?: self = .nhieu(a.compactMap(\.chuoi))
        default: return nil
        }
    }

    var any: Any {
        switch self {
        case .chu(let s): return s
        case .so(let n): return n == n.rounded() && abs(n) < 1e15 ? Int(n) : n
        case .co(let b): return b
        case .nhieu(let a): return a
        }
    }

    var chu: String? { if case .chu(let s) = self { return s }; return nil }
    var so: Double? { if case .so(let n) = self { return n }; return nil }
    var co: Bool? { if case .co(let b) = self { return b }; return nil }
    var nhieu: [String] {
        if case .nhieu(let a) = self { return a }
        if case .chu(let s) = self { return [s] }
        return []
    }

    /// Thân PUT custom-values cho MỘT trường (`nil` = xoá giá trị ⇒ `null`).
    static func than(truong: Int, _ v: CTWGiaTriTruong?) -> [String: Any] {
        ["values": [String(truong): v?.any ?? NSNull()]]
    }
}

/// `{ "<fieldId>": giá trị }` của GET/PUT custom-values.
struct CTWGiaTriTruongThe: Codable {
    var tatCa: [Int: CTWGiaTriTruong] = [:]

    init(_ d: [Int: CTWGiaTriTruong] = [:]) { tatCa = d }
    init(from decoder: Decoder) throws {
        let raw = (try? [String: CTWJSON](from: decoder)) ?? [:]
        for (k, v) in raw { if let id = Int(k), let g = CTWGiaTriTruong(v) { tatCa[id] = g } }
    }
    func encode(to encoder: Encoder) throws {
        var d: [String: CTWJSON] = [:]
        for (k, v) in tatCa { d[String(k)] = CTWJSON(v.any) }
        try d.encode(to: encoder)
    }
}

struct CTWWorklogThe: Codable, Hashable, Identifiable {
    var id: Int
    var minutes: Int?
    var startedAt: String?
    var note: String?
    var createdAt: String?
    var userId: Int?
    var user: CTWUser?
    var activity: String?
    var workProduct: String?
    var source: String?
}

struct CTWTeamRef: Codable, Hashable, Identifiable {
    var id: Int
    var key: String?
    var name: String
    var color: String?
    var archivedAt: String?
}

struct CTWStageRef: Codable, Hashable, Identifiable {
    var id: Int
    var n: Int?
    var name: String
    var status: String?
}

struct CTWLienKetWeb: Codable, Hashable, Identifiable {
    var id: Int
    var title: String?
    var url: String
    var kind: String?
    var canDelete: Bool?
}

struct CTWDsLienKetWeb: Codable {
    var items: [CTWLienKetWeb]?
    var canEdit: Bool?
}

struct CTWTrangLienKet: Codable, Hashable, Identifiable {
    var linkId: Int?
    var id: Int
    var number: Int
    var title: String
    var status: String?
    var updatedAt: String?
}

struct CTWTrangCuaThe: Codable {
    var pages: [CTWTrangLienKet]?
    var canEdit: Bool?
}

/// Một trang trong danh sách `/pages` (chọn tài liệu để liên kết).
struct CTWTrangNgan: Codable, Hashable, Identifiable {
    var id: Int
    var number: Int
    var title: String
}

struct CTWDsTrang: Codable {
    var pages: [CTWTrangNgan]?
    var canEdit: Bool?
}

/// Mẫu mô tả theo loại thẻ (`GET /issue-templates`).
struct CTWMauMoTa: Codable, Hashable {
    var typeId: Int
    var typeKey: String?
    var name: String?
    var doc: CTWJSON?
    var isDefault: Bool?
}

/// Thẻ có thể trùng (`GET /similar?title=` — so chuỗi pg_trgm, KHÔNG dùng AI).
struct CTWTheTuongTu: Codable, Hashable, Identifiable {
    var number: Int
    var title: String
    var score: Double?
    var resolved: Bool?
    var id: Int { number }
}

struct CTWKetQuaChuyenDuAn: Codable {
    var projectId: Int?
    var key: String?
    var number: Int?
    var dropped: [String]?
    var canEditTarget: Bool?
}

/// Kênh chat (chỉ phần cần để "Share to channel") — `GET /chat/channels` trả `{channels: [...]}`.
struct CTWKenhNgan: Codable, Hashable, Identifiable {
    var id: Int
    var name: String
    /// PUBLIC | PRIVATE | CLIENT
    var kind: String?
    var archived: Bool?
    var member: Bool?
    var canPost: Bool?
}

struct CTWDsKenhNgan: Codable {
    var channels: [CTWKenhNgan]?
}

/// Dự án trong không gian (đích "Move to another project").
struct CTWDuAnDich: Codable, Hashable, Identifiable {
    var id: Int
    var key: String
    var name: String
    var role: String?
    var archivedAt: String?
}

struct CTWKhongGianDuAn: Codable {
    var id: Int?
    var projects: [CTWDuAnDich]?
}

// MARK: Tiện ích

extension CTWLinkKieu {
    static var tatCa: [CTWLinkKieu] { [.blocks, .blockedBy, .relates, .duplicates, .clones, .tests] }
}

/// Loại liên kết khi THÊM (`POST /links {type, targetKey}`) — chiều "is blocked by" = thêm ngược từ thẻ kia.
enum CTWLinkKieu: String, Hashable, Identifiable {
    case blocks, blockedBy, relates, duplicates, clones, tests
    var id: String { rawValue }

    var ma: String {
        switch self {
        case .blocks, .blockedBy: return "BLOCKS"
        case .relates: return "RELATES"
        case .duplicates: return "DUPLICATES"
        case .clones: return "CLONES"
        case .tests: return "TESTS"
        }
    }

    var ten: String {
        switch self {
        case .blocks: return String(localized: "blocks")
        case .blockedBy: return String(localized: "is blocked by")
        case .relates: return String(localized: "relates to")
        case .duplicates: return String(localized: "duplicates")
        case .clones: return String(localized: "clones")
        case .tests: return String(localized: "tests")
        }
    }
}

enum CTWThoiLuong {
    /// "1h 30m" / "45m" / "2h". Chữ đơn vị theo Jira (web cũng vậy) — không dịch.
    static func chu(_ phut: Int?) -> String {
        guard let p = phut, p > 0 else { return "0m" }
        let g = p / 60, ph = p % 60
        if g == 0 { return "\(ph)m" }
        return ph == 0 ? "\(g)h" : "\(g)h \(ph)m"
    }

    /// "1h 30m", "1.5h", "90m", "90" (phút) ⇒ phút. Sai cú pháp ⇒ nil.
    static func doc(_ s: String) -> Int? {
        let t = s.lowercased().replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        if let n = Double(t) { return n >= 0 ? Int(n.rounded()) : nil }
        var tong = 0.0
        var so = ""
        var coDonVi = false
        for c in t {
            if c.isNumber || c == "." { so.append(c); continue }
            if c == " " { continue }
            guard let n = Double(so) else { return nil }
            switch c {
            case "w": tong += n * 5 * 8 * 60
            case "d": tong += n * 8 * 60
            case "h": tong += n * 60
            case "m": tong += n
            default: return nil
            }
            so = ""; coDonVi = true
        }
        if !so.isEmpty { return nil }
        return coDonVi ? Int(tong.rounded()) : nil
    }
}
