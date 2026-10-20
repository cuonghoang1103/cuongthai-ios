import SwiftUI

// MARK: - CT Work — model mô-đun Kiểm thử (Xray + mẫu FPT)
// Nguồn hình dạng: `services/work/tests.service.ts` (ca kiểm thử, chu kỳ, lượt chạy),
// `services/work/fptTests.service.ts` + `fptTests.ts` (Report 5.1 / 5.2 / 5.3).
// Luật: mọi trường `var` + optional, ngày là chuỗi (CLAUDE.md C3/C4).

// MARK: Ca kiểm thử

struct CTWTestReqRef: Codable, Hashable { var number: Int?; var title: String? }

struct CTWTestLastRun: Codable, Hashable {
    var status: String?
    var executedAt: String?
    var cycleName: String?
}

/// Một dòng `GET /projects/:pid/tests` (tối đa 1000, xếp theo rank).
struct CTWTestCase: Codable, Hashable, Identifiable {
    var id: Int
    var number: Int
    var title: String
    var priority: Int?
    var statusId: Int?
    var assigneeId: Int?
    var updatedAt: String?
    var labelIds: [Int]?
    /// MANUAL | GHERKIN
    var kind: String?
    var stepCount: Int?
    var requirements: [CTWTestReqRef]?
    var lastRun: CTWTestLastRun?
}

struct CTWTestStep: Codable, Hashable, Identifiable {
    var id: Int
    var position: Int?
    var action: String?
    var data: String?
    var expected: String?
}

struct CTWTestDefect: Codable, Hashable, Identifiable {
    var number: Int
    var title: String?
    var statusId: Int?
    var deletedAt: String?
    var id: Int { number }
}

struct CTWTestCycleRef: Codable, Hashable {
    var id: Int
    var name: String?
    var environment: String?
    var build: String?
    var state: String?
}

struct CTWTestRunBrief: Codable, Hashable, Identifiable {
    var id: Int
    var status: String?
    var executedAt: String?
    var comment: String?
    var executedBy: CTWUser?
    var cycle: CTWTestCycleRef?
    var defects: [CTWTestDefect]?
}

struct CTWTestPlanRef: Codable, Hashable, Identifiable { var id: Int; var name: String? }

/// `GET /projects/:pid/tests/:num`.
struct CTWTestDetail: Codable {
    var number: Int
    var title: String
    var testCaseId: Int?
    var kind: String?
    var preconditions: String?
    var gherkin: String?
    var updatedAt: String?
    var steps: [CTWTestStep]?
    /// 30 lượt gần nhất, mới trước.
    var runs: [CTWTestRunBrief]?
    var plans: [CTWTestPlanRef]?
}

// MARK: Chu kỳ kiểm thử

struct CTWTestIssueRef: Codable, Hashable { var number: Int; var title: String?; var priority: Int? }

/// Một lượt chạy trong chu kỳ (`GET /test-cycles/:id` → `runs`).
struct CTWCycleRun: Codable, Hashable, Identifiable {
    var id: Int
    var status: String?
    var executedAt: String?
    var comment: String?
    var assigneeId: Int?
    var executedBy: CTWUser?
    var stepCount: Int?
    var testVersion: Int?
    var currentVersion: Int?
    /// Ca kiểm thử đã sửa sau khi lượt này chụp lại các bước.
    var outdated: Bool?
    var test: CTWTestIssueRef?
    var defects: [CTWTestDefect]?
}

/// `GET /test-cycles` (danh sách, mới trước) và `GET /test-cycles/:id` (thêm `runs`).
struct CTWTestCycle: Codable, Hashable, Identifiable {
    var id: Int
    var name: String
    var environment: String?
    var build: String?
    /// PLANNED | IN_PROGRESS | DONE
    var state: String?
    var startAt: String?
    var endAt: String?
    var createdAt: String?
    var closedReason: String?
    var plan: CTWTestPlanRef?
    /// TODO/IN_PROGRESS/PASS/FAIL/BLOCKED/SKIP/RETEST → số lượt.
    var counts: [String: Int]?
    var total: Int?
    var executed: Int?
    /// `null` khi chưa chạy lượt nào.
    var passRate: Double?
    var progress: Double?
    var runs: [CTWCycleRun]?

    func dem(_ s: String) -> Int { counts?[s] ?? 0 }
}

// MARK: Lượt chạy

struct CTWRunStep: Codable, Hashable, Identifiable {
    /// ⚠️ Id KẾT QUẢ BƯỚC (không phải id bước của ca kiểm thử) — dùng cho PATCH.
    var id: Int
    var position: Int?
    var action: String?
    var data: String?
    var expected: String?
    /// TODO | PASS | FAIL | BLOCKED | SKIP
    var status: String?
    var actual: String?
}

struct CTWRunTestCase: Codable, Hashable {
    var preconditions: String?
    var kind: String?
    var version: Int?
    var issue: CTWTestIssueRef?
}

/// `GET /projects/:pid/test-runs/:runId` — cũng là thân trả về của mọi PATCH lượt/bước.
struct CTWRunDetail: Codable, Hashable {
    var id: Int
    var status: String?
    var comment: String?
    var gherkin: String?
    var executedAt: String?
    var assigneeId: Int?
    var testCaseVersion: Int?
    var executedBy: CTWUser?
    var cycle: CTWTestCycleRef?
    var testCase: CTWRunTestCase?
    var steps: [CTWRunStep]?
    var defects: [CTWTestDefect]?
    /// Bằng chứng gắn vào LƯỢT (không theo bước).
    var evidence: [CTWAttachment]?
}

struct CTWSoMoi: Codable { var number: Int }
struct CTWIdMoi: Codable { var id: Int }

// MARK: Luật trạng thái (bản sao `deriveRunStatus` ở tests.service.ts:505)

enum CTWLuatTest {
    static let trangThaiBuoc = ["PASS", "FAIL", "BLOCKED", "SKIP"]

    /// Cùng luật với máy chủ: không bước ⇒ TODO; có FAIL ⇒ FAIL; có BLOCKED ⇒ BLOCKED;
    /// mọi bước PASS/SKIP ⇒ PASS (nếu có ≥ 1 PASS) hoặc SKIP; có bước khác TODO ⇒ IN_PROGRESS.
    /// Dùng để cập nhật lạc quan; câu trả lời của máy chủ luôn là sự thật cuối cùng.
    static func trangThaiLuot(_ buoc: [String]) -> String {
        if buoc.isEmpty { return "TODO" }
        if buoc.contains("FAIL") { return "FAIL" }
        if buoc.contains("BLOCKED") { return "BLOCKED" }
        if buoc.allSatisfy({ $0 == "PASS" || $0 == "SKIP" }) { return buoc.contains("PASS") ? "PASS" : "SKIP" }
        if buoc.contains(where: { $0 != "TODO" }) { return "IN_PROGRESS" }
        return "TODO"
    }

    /// Cùng công thức `countStatuses`: đã chạy = tổng − TODO − RETEST − IN_PROGRESS.
    static func tienDo(_ counts: [String: Int]) -> (total: Int, executed: Int, passRate: Int?, progress: Int) {
        let total = counts.values.reduce(0, +)
        let executed = total - (counts["TODO"] ?? 0) - (counts["RETEST"] ?? 0) - (counts["IN_PROGRESS"] ?? 0)
        let pass = counts["PASS"] ?? 0
        let rate = executed > 0 ? Int((Double(pass) * 100 / Double(executed)).rounded()) : nil
        let prog = total > 0 ? Int((Double(executed) * 100 / Double(total)).rounded()) : 0
        return (total, executed, rate, prog)
    }

    static func mau(_ s: String?) -> Color {
        switch s {
        case "PASS": return AppColors.success
        case "FAIL": return AppColors.error
        case "BLOCKED": return AppColors.warning
        case "IN_PROGRESS", "RETEST": return AppColors.info
        case "SKIP": return AppColors.textSecondary
        default: return AppColors.textTertiary
        }
    }

    static func nhan(_ s: String?) -> String {
        switch s {
        case "PASS": return String(localized: "Passed")
        case "FAIL": return String(localized: "Failed")
        case "BLOCKED": return String(localized: "Blocked")
        case "SKIP": return String(localized: "Skipped")
        case "IN_PROGRESS": return String(localized: "In progress")
        case "RETEST": return String(localized: "Retest")
        default: return String(localized: "To do")
        }
    }

    static func bieuTuong(_ s: String?) -> String {
        switch s {
        case "PASS": return "checkmark.circle.fill"
        case "FAIL": return "xmark.octagon.fill"
        case "BLOCKED": return "hand.raised.fill"
        case "SKIP": return "forward.fill"
        case "IN_PROGRESS": return "play.circle.fill"
        case "RETEST": return "arrow.clockwise.circle.fill"
        default: return "circle.dashed"
        }
    }
}

// MARK: - Mẫu FPT (Report 5.1 Unit · 5.2 Integration · 5.3 System)

struct CTWFptUnitStats: Codable, Hashable {
    var passed: Int?
    var failed: Int?
    var untested: Int?
    var n: Int?
    var a: Int?
    var b: Int?
    var total: Int?
}

struct CTWFptUnitSummary: Codable, Hashable {
    var passed: Int?
    var failed: Int?
    var untested: Int?
    var n: Int?
    var a: Int?
    var b: Int?
    var total: Int?
    /// Số HÀM (ở `summary` là số, không phải mảng).
    var functions: Int?
    var coverage: Double?
    var successCoverage: Double?
    var normalPct: Double?
    var abnormalPct: Double?
    var boundaryPct: Double?
    var totalLoc: Double?
    var kloc: Double?
    var requiredCases: Int?
    var casesWithLoc: Int?
    var functionsWithoutLoc: Int?
    var belowNorm: Int?
    var meetsNorm: Bool?
}

struct CTWFptRow: Codable, Hashable, Identifiable {
    var id: Int
    /// COND | CONFIRM
    var section: String?
    var groupName: String?
    var label: String?
    var value: String?
}

struct CTWFptCase: Codable, Hashable, Identifiable {
    var id: Int
    /// N | A | B
    var type: String?
    /// P | F | nil (chưa chạy)
    var result: String?
    var executedAt: String?
    var defectId: String?
    var note: String?
    var rowIds: [Int]?
}

struct CTWFptFunction: Codable, Hashable, Identifiable {
    var id: Int
    var moduleName: String?
    var methodName: String?
    var sheetName: String?
    var description: String?
    var preCondition: String?
    var testRequirement: String?
    var codeRef: String?
    var loc: Int?
    /// Tên NGƯỜI dạng chữ (mẫu trường ghi tên tay), không phải PublicUser.
    var createdBy: String?
    var executedBy: String?
    var position: Int?
    var updatedAt: String?
    var rowCount: Int?
    var stats: CTWFptUnitStats?
    var requiredCases: Int?
    var belowNorm: Bool?
    var tcPerKloc: Int?
    // Chỉ có ở chi tiết:
    var rows: [CTWFptRow]?
    var cases: [CTWFptCase]?
}

struct CTWFptUnitList: Codable {
    var tcPerKloc: Int?
    var summary: CTWFptUnitSummary?
    var functions: [CTWFptFunction]?
}

struct CTWFptRound: Codable, Hashable {
    /// Passed | Failed | Pending | N/A | nil
    var status: String?
    var date: String?
    var tester: String?
}

struct CTWFptRoundStats: Codable, Hashable { var passed: Int?; var failed: Int?; var pending: Int?; var na: Int? }

struct CTWFptItStats: Codable, Hashable {
    var passed: Int?
    var failed: Int?
    var pending: Int?
    var na: Int?
    var total: Int?
    var rounds: [CTWFptRoundStats]?
    var lastRound: Int?
}

struct CTWFptItCase: Codable, Hashable, Identifiable {
    var id: Int
    var section: String?
    var description: String?
    var procedure: String?
    var testData: String?
    var expected: String?
    var actual: String?
    var preConditions: String?
    var evidence: String?
    var note: String?
    var rounds: [CTWFptRound]?
}

struct CTWFptModule: Codable, Hashable, Identifiable {
    var id: Int
    var name: String?
    var sheetName: String?
    var idPrefix: String?
    var description: String?
    var preCondition: String?
    var testRequirement: String?
    var position: Int?
    var updatedAt: String?
    /// INT | SYS (chỉ ở chi tiết)
    var kind: String?
    var stats: CTWFptItStats?
    var cases: [CTWFptItCase]?
}

struct CTWFptItSummary: Codable, Hashable {
    var passed: Int?
    var failed: Int?
    var pending: Int?
    var na: Int?
    var total: Int?
    var coverage: Double?
    var successCoverage: Double?
}

struct CTWFptItList: Codable {
    var modules: [CTWFptModule]?
    var summary: CTWFptItSummary?
}

enum CTWLuatFpt {
    /// "UTCID01" — số thứ tự ca (từ 1), đệm 2 chữ số như mẫu trường.
    static func utcid(_ chiSo: Int) -> String { String(format: "UTCID%02d", chiSo + 1) }

    /// Ô ma trận có dấu "O" không.
    static func coDau(_ c: CTWFptCase, hang: CTWFptRow) -> Bool { (c.rowIds ?? []).contains(hang.id) }

    /// Trạng thái hiện tại của một ca integration = vòng gần nhất có kết quả; chưa có ⇒ Pending.
    static func trangThaiIt(_ vong: [CTWFptRound]) -> String {
        for r in vong.reversed() { if let s = r.status, !s.isEmpty { return s } }
        return "Pending"
    }

    /// "AT1" — mã ca integration hiển thị.
    static func maIt(_ prefix: String?, _ chiSo: Int) -> String { "\(prefix ?? "IT")\(chiSo + 1)" }

    static func mauIt(_ s: String?) -> Color {
        switch s {
        case "Passed": return AppColors.success
        case "Failed": return AppColors.error
        case "N/A": return AppColors.textSecondary
        default: return AppColors.warning
        }
    }

    /// Nhóm hàng theo section (COND trước) rồi groupName — giữ thứ tự xuất hiện.
    static func nhomHang(_ rows: [CTWFptRow]) -> [(section: String, nhom: String, hang: [CTWFptRow])] {
        var out: [(section: String, nhom: String, hang: [CTWFptRow])] = []
        for sec in ["COND", "CONFIRM"] {
            for r in rows where (r.section ?? "COND") == sec {
                let g = r.groupName ?? ""
                if let i = out.firstIndex(where: { $0.section == sec && $0.nhom == g }) { out[i].hang.append(r) }
                else { out.append((sec, g, [r])) }
            }
        }
        return out
    }
}
