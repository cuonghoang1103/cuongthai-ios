import Foundation

// MARK: - Model Timeline / Roadmap
//
// Đối chiếu backend:
//   · `GET /projects/:pid/timeline` — `planning.service.ts:178-214`. Epic (level 1) + story/task/bug
//     (level 0); sub-task bị loại. `start`/`due` là chuỗi YMD. Thẻ có hạn mà không có ngày bắt đầu ⇒
//     máy chủ ĐOÁN `start` = ngày tạo. `dependencies`/`criticalPath`/`conflicts` dùng ISSUE ID (không
//     phải số thẻ) — tra qua `items`.
//   · `GET /projects/:pid/timeline/markers` — `uxc.service.ts:190-210`. Ngày cắt từ ISO UTC ⇒ sprint
//     (lưu 00:00 giờ VN = 17:00Z hôm trước) có thể SỚM một ngày; màn sửa lại bằng `cfg.sprints`.
// Mọi trường `var` + optional (CLAUDE.md C3/C4).

struct TLMucCTW: Codable, Hashable, Identifiable {
    var id: Int
    var number: Int
    var title: String
    var typeId: Int?
    var statusId: Int?
    var parentId: Int?
    var assigneeId: Int?
    var sprintId: Int?
    var fixVersionId: Int?
    /// 1 = epic, 0 = story/task/bug.
    var level: Int?
    /// YMD
    var start: String?
    /// YMD
    var due: String?
    var done: Bool?
    /// 0…1
    var progress: Double?

    var laEpic: Bool { (level ?? 0) >= 1 }
    var coLich: Bool { start != nil || due != nil }
}

/// Cạnh phụ thuộc "from BLOCKS to" (id thẻ).
struct TLCanhCTW: Codable, Hashable {
    var from: Int
    var to: Int
}

struct TLDuLieuCTW: Codable {
    var items: [TLMucCTW]?
    var dependencies: [TLCanhCTW]?
    var criticalPath: [Int]?
    var criticalDays: Int?
    var conflicts: [TLCanhCTW]?
}

struct TLMocSprintCTW: Codable, Hashable, Identifiable {
    var id: Int
    var name: String?
    /// PLANNED | ACTIVE | CLOSED
    var status: String?
    var start: String?
    var end: String?
}

struct TLMocVersionCTW: Codable, Hashable, Identifiable {
    var id: Int
    var name: String?
    /// UNRELEASED | RELEASED
    var status: String?
    var start: String?
    var release: String?
}

struct TLMocStageCTW: Codable, Hashable, Identifiable {
    var id: Int
    var n: Int?
    var name: String?
    /// NOT_STARTED | ACTIVE | GATE_REVIEW | DONE
    var status: String?
    var start: String?
    var end: String?
}

struct TLMocCTW: Codable {
    var sprints: [TLMocSprintCTW]?
    var versions: [TLMocVersionCTW]?
    var stages: [TLMocStageCTW]?
}

/// Kết quả `PUT /issues/:num/schedule`.
struct TLLichMoiCTW: Codable {
    var number: Int?
    var version: Int?
}
