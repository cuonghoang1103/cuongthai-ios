import SwiftUI

// MARK: - Model Review (rà soát/inspection kiểu IEEE-1028 — `quality.service.ts` :84–122, `reviewRules.ts`)
// Danh sách và chi tiết là HAI hình dạng (`participants` là SỐ ở danh sách, MẢNG ở chi tiết).

struct CTWReviewHang: Codable, Hashable, Identifiable {
    var number: Int
    var key: String?
    var projectKey: String?
    var title: String
    /// DOC | CODE
    var kind: String?
    var method: String?
    var checklistKey: String?
    var status: String?
    var decision: String?
    var workProduct: String?
    var meetingAt: String?
    var createdAt: String?
    var closedAt: String?
    var participants: Int?
    var defects: Int?
    var progress: Int?
    var rate: Double?
    var density: Double?
    var efficiency: Double?
    var id: Int { number }
    var nhanKhoa: String { key ?? "REV-\(number)" }
}

struct CTWReviewNguoi: Codable, Hashable, Identifiable {
    var id: Int
    var userId: Int?
    /// MODERATOR | AUTHOR | REVIEWER | SCRIBE | READER
    var role: String?
    var prepMinutes: Int?
    var user: CTWUser?
}

struct CTWReviewMuc: Codable, Hashable, Identifiable {
    struct Loi: Codable, Hashable { var number: Int; var key: String?; var title: String?; var done: Bool? }
    var id: Int
    var position: Int?
    var section: String?
    var question: String?
    /// OK | NG | NA | nil
    var result: String?
    var line: GovChuHoacSo?
    var note: String?
    /// CRITICAL | MAJOR | MINOR | TRIVIAL
    var severity: String?
    var defect: Loi?
}

struct CTWReviewSoDo: Codable, Hashable {
    var size: Double?
    var sizeUnit: String?
    var participants: Int?
    var prepHours: Double?
    var meetingHours: Double?
    var effortHours: Double?
    var reworkHours: Double?
    var defects: Int?
    var majorDefects: Int?
    var checklistProgress: Double?
    var rate: Double?
    var rateTooFast: Bool?
    var density: Double?
    var efficiency: Double?
}

struct CTWReview: Codable, Hashable {
    struct Trang: Codable, Hashable { var number: Int; var title: String? }
    var number: Int
    var key: String?
    var projectKey: String?
    var title: String
    var kind: String?
    var method: String?
    var checklistKey: String?
    var checklistName: String?
    var checklistSource: String?
    var page: Trang?
    var workProduct: String?
    var prUrl: String?
    var size: Double?
    var sizeUnit: String?
    var status: String?
    var decision: String?
    var meetingAt: String?
    var meetingMinutes: Double?
    var reworkMinutes: Double?
    var entryCriteria: String?
    var exitCriteria: String?
    var notes: String?
    var createdAt: String?
    var updatedAt: String?
    var closedAt: String?
    var participants: [CTWReviewNguoi]?
    var items: [CTWReviewMuc]?
    var metrics: CTWReviewSoDo?
    var next: [String]?
    var closeBlockers: [String]?
    var canEdit: Bool?

    var nhanKhoa: String { key ?? "REV-\(number)" }
    var suaDuoc: Bool { canEdit == true && status != "CLOSED" }

    /// Mục theo phần, giữ thứ tự `position`.
    var theoPhan: [(phan: String, muc: [CTWReviewMuc])] {
        var thuTu: [String] = []
        var nhom: [String: [CTWReviewMuc]] = [:]
        for m in (items ?? []).sorted(by: { ($0.position ?? 0, $0.id) < ($1.position ?? 0, $1.id) }) {
            let p = m.section ?? String(localized: "Checklist")
            if nhom[p] == nil { thuTu.append(p) }
            nhom[p, default: []].append(m)
        }
        return thuTu.map { ($0, nhom[$0] ?? []) }
    }
}

struct CTWReviewTaoLoi: Codable { var created: Bool?; var number: Int?; var key: String?; var title: String? }

enum CTWReviewLuat {
    /// Bước chuyển hợp lệ (`reviewRules.ts`) — dùng khi máy chủ chưa gửi `next`.
    static func ke(tu s: String?) -> [String] {
        switch s {
        case "PLANNING": return ["PREPARATION"]
        case "PREPARATION": return ["MEETING", "PLANNING"]
        case "MEETING": return ["REWORK", "CLOSED"]
        case "REWORK": return ["FOLLOW_UP", "MEETING"]
        case "FOLLOW_UP": return ["CLOSED", "REWORK"]
        default: return []
        }
    }

    static let quyetDinh = ["ACCEPT", "ACCEPT_WITH_CHANGES", "REINSPECT"]
    static let mucDo = ["CRITICAL", "MAJOR", "MINOR", "TRIVIAL"]

    static func nhanBuoc(_ s: String) -> String {
        switch s {
        case "PREPARATION": return String(localized: "Start preparation")
        case "MEETING": return String(localized: "Start meeting")
        case "REWORK": return String(localized: "Send to rework")
        case "FOLLOW_UP": return String(localized: "Follow up")
        case "CLOSED": return String(localized: "Close review")
        case "PLANNING": return String(localized: "Back to planning")
        default: return CTWMauTrangThai.nhan(s)
        }
    }

    static func nhanQuyetDinh(_ s: String?) -> String {
        switch s {
        case "ACCEPT": return String(localized: "Accept")
        case "ACCEPT_WITH_CHANGES": return String(localized: "Accept with changes")
        case "REINSPECT": return String(localized: "Re-inspect")
        default: return String(localized: "No decision")
        }
    }

    static func lyDoChan(_ s: String) -> String {
        switch s {
        case "NO_MODERATOR": return String(localized: "Add a moderator before closing.")
        case "CHECKLIST_INCOMPLETE": return String(localized: "Answer every checklist item (OK, NG or N/A).")
        case "NO_DECISION": return String(localized: "Record the review decision.")
        default: return CTWMauTrangThai.nhan(s)
        }
    }
}

struct RouteReviewCTW: Hashable {
    var pid: Int
    var so: Int
}

extension CTWAPI {
    static func dsReview(pid: Int) -> APIEndpoint { get("/projects/\(pid)/reviews") }
    static func review(pid: Int, so: Int) -> APIEndpoint { get("/projects/\(pid)/reviews/\(so)") }
    static func suaReview(pid: Int, so: Int, than: [String: Any]) -> APIEndpoint { goi("/projects/\(pid)/reviews/\(so)", "PATCH", than) }
    static func chuyenReview(pid: Int, so: Int, den: String) -> APIEndpoint { goi("/projects/\(pid)/reviews/\(so)/transition", "POST", ["to": den]) }

    /// Ghi kết quả từng mục checklist (`PUT /reviews/:num/items`).
    static func ghiMucReview(pid: Int, so: Int, muc: [[String: Any]]) -> APIEndpoint {
        goi("/projects/\(pid)/reviews/\(so)/items", "PUT", ["items": muc])
    }

    static func taoLoiTuMuc(pid: Int, so: Int, mucId: Int, mucDo: String?) -> APIEndpoint {
        goi("/projects/\(pid)/reviews/\(so)/items/\(mucId)/defect", "POST", mucDo.map { ["severity": $0] } ?? [:])
    }
}
