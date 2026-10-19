import Foundation

// MARK: - Model trang Code (đối chiếu `code.service.ts` + `gitSource.ts` của api-backend, 18/10/2026)
//
// Luật kho (CLAUDE.md C3/C4): mọi trường `var` + optional, ngày là `String`.
// `issues` của máy chủ là `Record<number, IssueRef>` ⇒ JSON object khoá CHUỖI ("12") ⇒ `[String: CTWCodeThe]`.

/// `{ user: PublicUser | null, label }` — người khớp được với thành viên dự án, hoặc chỉ tên git.
struct CTWCodeAi: Codable, Hashable {
    var user: CTWUser?
    var label: String?
    var ten: String { user?.ten ?? label ?? "unknown" }
}

/// Thẻ được nhắc trong commit/nhánh/PR.
struct CTWCodeThe: Codable, Hashable {
    struct TT: Codable, Hashable { var name: String?; var category: String? }
    var number: Int
    var key: String?
    var title: String?
    var status: TT?
    var assigneeId: Int?
}

struct CTWCodeTrangThai: Codable { var connected: Bool?; var providers: [String]? }

struct CTWCodeTongQuan: Codable {
    struct NhaCungCap: Codable, Hashable {
        var provider: String
        var repo: String?
        var webUrl: String?
        var lastEventAt: String?
        var hasReadToken: Bool?
    }
    struct NguoiDongGop: Codable, Hashable { var key: String?; var user: CTWUser?; var label: String? }
    struct Ngay: Codable, Hashable { var day: String; var commits: Int?; var pushes: Int? }
    struct SoLieu: Codable {
        var commits7d: Int?
        var pushes7d: Int?
        var openPrs: Int?
        var contributors30d: [NguoiDongGop]?
        var daily: [Ngay]?
    }
    var connected: Bool?
    var providers: [NhaCungCap]?
    var canManage: Bool?
    var canViewSource: Bool?
    var trackedSince: String?
    var stats: SoLieu?
}

struct CTWCodeCommit: Codable, Hashable {
    var sha: String
    var message: String?
    var url: String?
    var at: String?
    var author: CTWCodeAi?
    var issueNumbers: [Int]?
    var files: Int?
    var dongDau: String { (message ?? "").split(separator: "\n", maxSplits: 1).first.map(String.init) ?? "" }
    var shaNgan: String { String(sha.prefix(7)) }
}

/// Một mục dòng thời gian. `kind`: PUSH · BRANCH_CREATED · BRANCH_DELETED · PR_OPENED · PR_REOPENED · PR_MERGED ·
/// PR_CLOSED · REVIEW_REQUESTED · COMMIT (dữ liệu cũ, `legacy`).
struct CTWCodeSuKien: Codable, Hashable, Identifiable {
    var id: String
    var kind: String
    var provider: String?
    var repo: String?
    var ref: String?
    var actor: CTWCodeAi?
    var title: String?
    var url: String?
    var prNumber: Int?
    var commitCount: Int?
    var commits: [CTWCodeCommit]?
    var issueNumbers: [Int]?
    var occurredAt: String?
    var legacy: Bool?

    /// Mọi số thẻ nhắc tới (sự kiện + từng commit), không trùng, giữ thứ tự.
    var tatCaThe: [Int] {
        var thay = Set<Int>(); var out: [Int] = []
        for n in (issueNumbers ?? []) + (commits ?? []).flatMap({ $0.issueNumbers ?? [] }) where thay.insert(n).inserted { out.append(n) }
        return out
    }
}

struct CTWCodeTrangHoatDong: Codable {
    struct LocNguoi: Codable, Hashable { var value: String; var label: String?; var user: CTWUser? }
    struct LocNhanh: Codable, Hashable { var name: String; var deleted: Bool? }
    struct BoLoc: Codable { var actors: [LocNguoi]?; var branches: [LocNhanh]? }
    var items: [CTWCodeSuKien]
    var nextBefore: String?
    var issues: [String: CTWCodeThe]?
    var filters: BoLoc?
}

struct CTWCodeNhanh: Codable, Hashable, Identifiable {
    struct CommitCuoi: Codable, Hashable { var title: String?; var url: String? }
    struct PRMo: Codable, Hashable { var number: Int; var title: String?; var url: String?; var state: String? }
    var name: String
    var provider: String?
    var headSha: String?
    var lastCommit: CommitCuoi?
    var lastAuthor: CTWCodeAi?
    var lastPushAt: String?
    var commitCount: Int?
    var deleted: Bool?
    var issueNumbers: [Int]?
    var pr: PRMo?
    var id: String { "\(provider ?? "")-\(name)" }
}

struct CTWCodeDSNhanh: Codable { var items: [CTWCodeNhanh]; var issues: [String: CTWCodeThe]? }

struct CTWCodePR: Codable, Hashable, Identifiable {
    var provider: String?
    var number: Int
    var title: String?
    var url: String?
    /// open | draft | merged | closed
    var state: String?
    var author: CTWCodeAi?
    var reviewers: [CTWCodeAi]?
    var headRef: String?
    var baseRef: String?
    var issueNumbers: [Int]?
    var additions: Int?
    var deletions: Int?
    var changedFiles: Int?
    var mergedBy: CTWCodeAi?
    var openedAt: String?
    var mergedAt: String?
    var closedAt: String?
    var id: String { "\(provider ?? "")-\(number)" }
}

struct CTWCodeDSPR: Codable {
    struct Dem: Codable { var open: Int?; var merged: Int?; var closed: Int? }
    var items: [CTWCodePR]
    var counts: Dem?
    var issues: [String: CTWCodeThe]?
}

// MARK: Mã nguồn (proxy)

struct CTWCodeRepo: Codable {
    var provider: String?
    var repo: String?
    var hasToken: Bool?
    var defaultBranch: String?
    var `private`: Bool?
    var description: String?
    var webUrl: String?
}

struct CTWCodeRef: Codable, Hashable { var name: String; var sha: String? }

struct CTWCodeMucCay: Codable, Hashable, Identifiable {
    var name: String
    var path: String
    /// dir | file | symlink | submodule
    var type: String
    var size: Int?
    var id: String { path }
    var laThuMuc: Bool { type == "dir" }
}

struct CTWCodeCay: Codable { var ref: String?; var path: String?; var entries: [CTWCodeMucCay] }

/// Tệp: trần 1 MB (`MAX_FILE_BYTES`) ⇒ `tooLarge`; nhị phân ⇒ `binary`; cả hai ⇒ `content = null`.
struct CTWCodeTep: Codable {
    var ref: String?
    var path: String?
    var size: Int?
    var binary: Bool?
    var tooLarge: Bool?
    var content: String?
    var webUrl: String?
}

struct CTWCodeCommitNguon: Codable, Hashable, Identifiable {
    var sha: String
    var message: String?
    var authorLogin: String?
    var authorName: String?
    var at: String?
    var url: String?
    var author: CTWCodeAi?
    var id: String { sha }
    var dongDau: String { (message ?? "").split(separator: "\n", maxSplits: 1).first.map(String.init) ?? "" }
}

struct CTWCodeDSCommit: Codable { var ref: String?; var items: [CTWCodeCommitNguon] }

struct CTWCodeTepDoi: Codable, Hashable, Identifiable {
    var filename: String
    var previous: String?
    /// added | modified | removed | renamed …
    var status: String?
    var additions: Int?
    var deletions: Int?
    /// `nil` khi quá trần (200 KB/tệp, 800 KB tổng) ⇒ `truncated`.
    var patch: String?
    var truncated: Bool?
    var id: String { filename }
}

struct CTWCodeChiTietCommit: Codable {
    struct Tong: Codable { var additions: Int?; var deletions: Int?; var files: Int? }
    var sha: String
    var message: String?
    var authorLogin: String?
    var authorName: String?
    var at: String?
    var url: String?
    var author: CTWCodeAi?
    var parents: [String]?
    var stats: Tong?
    var files: [CTWCodeTepDoi]?
    var truncated: Bool?
    var issues: [String: CTWCodeThe]?
}

// MARK: Chữ hiện

enum CTWCodeChu {
    static func hanhDong(_ e: CTWCodeSuKien) -> (bieuTuong: String, cau: String) {
        let ai = e.actor?.ten ?? "Someone"
        let nhanh = e.ref ?? "a branch"
        let pr = e.prNumber.map { "#\($0)" } ?? ""
        switch e.kind {
        case "PUSH":
            let n = e.commitCount ?? e.commits?.count ?? 0
            return ("arrow.up.circle", "\(ai) pushed \(n) commit\(n == 1 ? "" : "s") to \(nhanh)")
        case "COMMIT": return ("smallcircle.filled.circle", "\(ai) committed")
        case "BRANCH_CREATED": return ("arrow.triangle.branch", "\(ai) created branch \(nhanh)")
        case "BRANCH_DELETED": return ("trash", "\(ai) deleted branch \(nhanh)")
        case "PR_OPENED": return ("arrow.triangle.pull", "\(ai) opened pull request \(pr)")
        case "PR_REOPENED": return ("arrow.triangle.pull", "\(ai) reopened pull request \(pr)")
        case "PR_MERGED": return ("arrow.triangle.merge", "\(ai) merged pull request \(pr)")
        case "PR_CLOSED": return ("xmark.circle", "\(ai) closed pull request \(pr)")
        case "REVIEW_REQUESTED": return ("eye", "\(ai) requested a review on \(pr)")
        default: return ("circle", "\(ai) · \(e.kind.lowercased())")
        }
    }

    static func trangThaiPR(_ s: String?) -> String {
        switch s {
        case "merged": return "MERGED"
        case "closed": return "CLOSED"
        case "draft": return "DRAFT"
        default: return "OPEN"
        }
    }

    /// "1.2 KB" / "980 B".
    static func coTep(_ b: Int?) -> String {
        guard let b else { return "" }
        if b < 1024 { return "\(b) B" }
        if b < 1024 * 1024 { return String(format: "%.1f KB", Double(b) / 1024) }
        return String(format: "%.1f MB", Double(b) / 1024 / 1024)
    }
}
