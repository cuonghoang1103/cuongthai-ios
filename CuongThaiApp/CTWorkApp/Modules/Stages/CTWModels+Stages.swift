import Foundation

// MARK: - Model Giai đoạn dự án (Stages)
//
// Đối chiếu backend `services/work/stages.service.ts`:
//   · `STAGE_SELECT` (:32-35) + phần thêm của `GET /stages` (:43-66): `gateIssueKey`, `issueCount`,
//     `doneCount`, `pendingApprovalId`. Sắp theo `n`.
//   · Vòng đời NOT_STARTED → ACTIVE → GATE_REVIEW → DONE (DONE chỉ khi cổng được DUYỆT).
//   · Mô-đun `stages` tắt ⇒ 403 `MODULE_DISABLED`.

struct GiaiDoanCongCTW: Codable, Hashable {
    var id: Int?
    var number: Int?
    var title: String?
    var resolvedAt: String?
}

struct GiaiDoanCTW: Codable, Hashable, Identifiable {
    var id: Int
    var n: Int?
    var slug: String?
    var name: String
    /// NOT_STARTED | ACTIVE | GATE_REVIEW | DONE
    var status: String?
    var gateIssueId: Int?
    var startedAt: String?
    var completedAt: String?
    var createdAt: String?
    var gateIssue: GiaiDoanCongCTW?
    var gateIssueKey: String?
    var issueCount: Int?
    var doneCount: Int?
    var pendingApprovalId: Int?

    var tiLe: Double {
        guard let t = issueCount, t > 0 else { return status == "DONE" ? 1 : 0 }
        return Double(doneCount ?? 0) / Double(t)
    }
}

/// Tóm tắt cả dãy giai đoạn (đầu màn).
struct TomTatGiaiDoanCTW: Equatable {
    var xong: Int
    var tong: Int
    /// Giai đoạn đang chạy (ACTIVE hoặc GATE_REVIEW đầu tiên).
    var hienTai: String?

    static func tinh(_ ds: [GiaiDoanCTW]) -> TomTatGiaiDoanCTW {
        let ht = ds.first { $0.status == "ACTIVE" || $0.status == "GATE_REVIEW" }
        return TomTatGiaiDoanCTW(xong: ds.filter { $0.status == "DONE" }.count, tong: ds.count, hienTai: ht?.name)
    }
}
