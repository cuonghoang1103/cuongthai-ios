import Foundation

// MARK: - "Create with CuongMini" — model (web commit ee507275, 20/10/2026)
//
// Đối chiếu api-backend: `src/services/work/taoCuongMini/kieu.ts` (zod: setupInput, understanding, planMember/planItem…),
// `banNhap.service.ts → present()` (hình dạng bản nháp), `frontend/src/lib/work-setup-api.ts` (kiểu web).
// Luật kho: mọi trường `var` + optional, ngày là `String` (CLAUDE.md C3/C4).
//   · `input` (đầu vào) khai ĐỦ trường của zod `setupInput` ⇒ gửi lại không mất gì; trường thiếu máy chủ tự điền mặc định.
//   · `understanding` + `plan` giữ dạng JSON thô (`CTWJSON`) để sửa vài trường rồi gửi lại nguyên vẹn; hiển thị bằng
//     `CTWHieuCM` / `CTWKeHoachCM` (chỉ đọc).

/// Một dòng danh sách thành viên.
struct CTWThanhVienCM: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String = ""
    var studentId: String? = ""
    var email: String? = ""
    var role: String? = ""
    var skills: String? = ""
    /// 1 = mới bắt đầu … 5 = rất mạnh.
    var level: Int? = 3
    var hoursPerWeek: Double? = 8
    var prefs: String? = ""
    var group: String? = ""

    private enum CodingKeys: String, CodingKey { case name, studentId, email, role, skills, level, hoursPerWeek, prefs, group }
}

struct CTWNhomCM: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String = ""
    var key: String? = ""
    var topic: String? = ""
    var leader: String? = ""
    private enum CodingKeys: String, CodingKey { case name, key, topic, leader }
}

struct CTWMocCM: Codable, Hashable { var name: String; var date: String }
struct CTWTranhCM: Codable, Hashable { var name: String; var from: String; var to: String }
struct CTWHopCM: Codable, Hashable { var weekday: Int; var time: String; var durationMin: Int? }

/// Đầu vào trình hướng dẫn — đủ trường của zod `setupInput`.
struct CTWDauVaoCM: Codable, Equatable {
    struct TongQuan: Codable, Equatable {
        var name: String? = ""
        var key: String? = ""
        var template: String? = "SWP391"
        var type: String? = "SCRUM"
        var kind: String? = "SCHOOL"
        var courseCode: String? = ""
        var className: String? = ""
        var semester: String? = ""
        var stakeholders: String? = ""
        /// vi | en | both
        var language: String? = "vi"
        var goal: String? = ""
    }
    struct DeBai: Codable, Equatable {
        var text: String? = ""
        var functional: String? = ""
        var nonFunctional: String? = ""
        var rubric: String? = ""
        var deliverables: [String]? = []
    }
    struct Nhom: Codable, Equatable {
        var members: [CTWThanhVienCM]? = []
        var rules: [String]? = ["BY_LEVEL", "LEADER_REVIEWS"]
        var rulesText: String? = ""
        var sendInvites: Bool? = false
    }
    struct Lich: Codable, Equatable {
        var startDate: String? = ""
        var endDate: String? = ""
        var milestones: [CTWMocCM]? = []
        var sprintWeeks: Int? = 2
        var workingDays: [Int]? = [1, 2, 3, 4, 5]
        var avoid: [CTWTranhCM]? = []
        var meeting: CTWHopCM?
    }
    struct Ma: Codable, Equatable {
        var repoUrl: String? = ""
        var branch: String? = ""
        var stack: String? = ""
        var conventions: String? = ""
    }
    struct ChiaViec: Codable, Equatable {
        var prompt: String? = ""
        /// EPICS | STORIES | SUBTASKS
        var detail: String? = "SUBTASKS"
        var criteria: Bool? = true
        var points: Bool? = true
        var tests: Bool? = true
        var risks: Bool? = true
        var meetings: Bool? = true
        var pages: Bool? = true
        var assign: Bool? = true
        var onboarding: Bool? = true
    }
    var overview: TongQuan? = TongQuan()
    var brief: DeBai? = DeBai()
    var team: Nhom? = Nhom()
    var timeline: Lich? = Lich()
    var code: Ma? = Ma()
    var split: ChiaViec? = ChiaViec()
    var groups: [CTWNhomCM]? = []
    var reviewFirst: Bool? = false

    /// Bản gửi đi: bỏ dòng dở (máy chủ kiểm chặt — như `cleanInput` của web).
    func sach() -> CTWDauVaoCM {
        var x = self
        let ngay = { (s: String?) -> Bool in (s ?? "").range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil }
        x.brief?.deliverables = (brief?.deliverables ?? []).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        x.team?.members = (team?.members ?? []).filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }.map { m in
            var m = m
            let e = (m.email ?? "").trimmingCharacters(in: .whitespaces)
            m.email = e.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil ? e : ""
            return m
        }
        if !ngay(timeline?.startDate) { x.timeline?.startDate = "" }
        if !ngay(timeline?.endDate) { x.timeline?.endDate = "" }
        x.timeline?.milestones = (timeline?.milestones ?? []).filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty && ngay($0.date) }
        x.timeline?.avoid = (timeline?.avoid ?? []).filter { !$0.name.isEmpty && ngay($0.from) && ngay($0.to) }
        x.groups = (groups ?? []).filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        x.overview?.key = String((overview?.key ?? "").uppercased().filter { $0.isLetter || $0.isNumber }.prefix(10))
        return x
    }

    /// Đủ để CuongMini đọc: tên, mục tiêu, đề bài hoặc một nguồn đã đọc được.
    func docDuoc(coNguon: Bool) -> Bool {
        let co = { (s: String?) in !(s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return co(overview?.name) || co(overview?.goal) || co(brief?.text) || coNguon
    }
}

struct CTWNguonCM: Codable, Hashable, Identifiable {
    var id: String
    /// FILE | LINK | REPO
    var kind: String?
    /// BRIEF | TEMPLATE | CODE | SAMPLE | ROSTER | OTHER
    var category: String?
    var name: String?
    var note: String?
    var mime: String?
    var size: Int?
    var url: String?
    /// OK | EMPTY | ERROR | PRIVATE
    var status: String?
    var error: String?
    var chars: Int?
    var addedAt: String?
}

struct CTWBuocCM: Codable, Hashable {
    var key: String
    /// pending | running | done | skipped | error
    var status: String?
    var detail: String?
    var at: String?
}

struct CTWKetQuaCM: Codable, Hashable {
    struct DuAn: Codable, Hashable, Identifiable {
        var id: Int
        var key: String
        var name: String
        var url: String?
        var issues: Int?
        var pages: Int?
        var sprints: Int?
        var tests: Int?
        var risks: Int?
        var meetings: Int?
        var resources: Int?
        var files: Int?
        var invited: Int?
        var added: Int?
        var planned: Int?
    }
    struct LoiMoi: Codable, Hashable { var sent: Int?; var added: Int?; var skipped: Int?; var reason: String? }
    var projects: [DuAn]?
    var invites: LoiMoi?
}

struct CTWDungCM: Codable, Hashable { var calls: Int?; var usd: Double?; var fallback: Int? }

/// Bản nháp (`GET /setup-drafts/:id`).
struct CTWBanNhapCM: Codable {
    var id: Int
    var workspaceId: Int?
    /// PROJECT | WORKSPACE
    var mode: String?
    /// DRAFT | READING | UNDERSTOOD | PLANNING | READY | APPLYING | APPLIED | FAILED | CANCELLED
    var status: String?
    var title: String?
    var model: String?
    var input: CTWDauVaoCM?
    var understanding: CTWJSON?
    var plan: CTWJSON?
    var progress: [CTWBuocCM]?
    var result: CTWKetQuaCM?
    var error: String?
    /// READING | PLANNING | APPLYING
    var failedPhase: String?
    var busy: Bool?
    var sources: [CTWNguonCM]?
    var usage: CTWDungCM?
    var createdAt: String?
    var updatedAt: String?
    var appliedAt: String?

    var dangChay: Bool { busy == true }
    var laKhongGian: Bool { mode == "WORKSPACE" }
    /// Hiểu (bản tóm tắt) đã giải mã để hiển thị — nil khi chưa có / `null`.
    var hieu: CTWHieuCM? { understanding.flatMap { $0 == .null ? nil : $0.giai(CTWHieuCM.self) } }
    var keHoach: CTWKeHoachCM? { plan.flatMap { $0 == .null ? nil : $0.giai(CTWKeHoachCM.self) } }
}

struct CTWTomTatBanNhapCM: Codable, Hashable, Identifiable {
    var id: Int
    var mode: String?
    var status: String?
    var title: String?
    var updatedAt: String?
}

/// `POST /setup-drafts/:id/files` · `/links` ⇒ `{draft, source, roster?}`.
struct CTWThemNguonCM: Codable {
    var draft: CTWBanNhapCM?
    var source: CTWNguonCM?
    var roster: CTWDanhSachCM?
}

/// `POST /workspaces/:wsId/setup/roster` ⇒ danh sách đọc được.
struct CTWDanhSachCM: Codable {
    var rows: [CTWThanhVienCM]?
    var headerFound: Bool?
    var warnings: [String]?
}

// MARK: Bản tóm tắt "CuongMini đã hiểu gì" (chỉ đọc; câu trả lời + ghi chú sửa trên cây JSON)

struct CTWHieuCM: Codable {
    struct SanPham: Codable, Hashable { var name: String?; var due: String?; var criteria: String? }
    struct CongNghe: Codable, Hashable { var stack: [String]?; var repoFindings: [String]? }
    struct NguoiCM: Codable, Hashable { var name: String?; var studentId: String?; var group: String?; var proposedRole: String?; var why: String? }
    struct CauHoi: Codable, Hashable { var q: String?; var answer: String? }
    var goal: String?
    var scopeIn: [String]?
    var scopeOut: [String]?
    var deliverables: [SanPham]?
    var grading: [String]?
    var tech: CongNghe?
    var team: [NguoiCM]?
    var timeline: [String]?
    var strategy: [String]?
    var assumptions: [String]?
    var risks: [String]?
    var questions: [CauHoi]?
    var notes: String?
}

// MARK: Kế hoạch (chỉ đọc — sửa trên cây JSON `plan`)

struct CTWKeHoachCM: Codable {
    struct ThanhVien: Codable, Hashable, Identifiable {
        var ref: String
        var name: String?
        var email: String?
        var role: String?
        var level: Int?
        var hoursPerWeek: Double?
        var projectRef: String?
        var leader: Bool?
        /// USER | INVITE | PLACEHOLDER
        var mapping: String?
        var why: String?
        var id: String { ref }
    }
    struct Sprint: Codable, Hashable, Identifiable {
        var ref: String
        var name: String?
        var goal: String?
        var start: String?
        var end: String?
        var id: String { ref }
    }
    struct MoDun: Codable, Hashable { var name: String?; var description: String?; var ownerRef: String? }
    struct Moc: Codable, Hashable { var ref: String?; var name: String?; var date: String? }
    struct Viec: Codable, Hashable, Identifiable {
        var ref: String
        /// EPIC | STORY | TASK | BUG | SUBTASK
        var kind: String?
        var parentRef: String?
        var title: String?
        var description: String?
        var criteria: [String]?
        var points: Double?
        var priority: Int?
        var difficulty: Int?
        var component: String?
        var assigneeRef: String?
        var pairRef: String?
        var sprintRef: String?
        var due: String?
        var locked: Bool?
        var id: String { ref }
        var laEpic: Bool { kind == "EPIC" }
    }
    struct Trang: Codable, Hashable { var ref: String?; var kind: String?; var title: String? }
    struct TestCM: Codable, Hashable { var ref: String?; var title: String? }
    struct RuiRo: Codable, Hashable { var ref: String?; var title: String?; var probability: Int?; var impact: Int? }
    struct DuAn: Codable, Identifiable {
        var ref: String
        var name: String?
        var key: String?
        var template: String?
        var type: String?
        var description: String?
        var sprints: [Sprint]?
        var milestones: [Moc]?
        var components: [MoDun]?
        var items: [Viec]?
        var pages: [Trang]?
        var tests: [TestCM]?
        var risks: [RuiRo]?
        var id: String { ref }

        var epic: [Viec] { (items ?? []).filter(\.laEpic) }
        func con(_ ref: String) -> [Viec] { (items ?? []).filter { $0.parentRef == ref } }
        /// Việc không thuộc epic nào (và không phải epic).
        var leLe: [Viec] {
            let ds = items ?? []
            let refs = Set(ds.map(\.ref))
            return ds.filter { v in !v.laEpic && (v.parentRef.map { !refs.contains($0) } ?? true) }
        }
        var tongDiem: Double { (items ?? []).filter { $0.kind != "EPIC" && $0.kind != "SUBTASK" }.compactMap(\.points).reduce(0, +) }
    }
    struct CanhBao: Codable, Hashable {
        /// MISSING_INFO | OVERLOAD | DEADLINE | UNASSIGNED | BEGINNER_HARD | CAP | NO_EMAIL | SOURCE
        var kind: String?
        var projectRef: String?
        var ref: String?
        var message: String?
    }
    var projects: [DuAn]?
    var members: [ThanhVien]?
    var warnings: [CanhBao]?
}

/// Mẫu dự án (khớp `PROJECT_TEMPLATES`) — tên theo web `create.tpl_*`.
enum MauDuAnCTW: String, CaseIterable, Identifiable {
    case CAPSTONE, SWP391, SWR302, SWT301, FREELANCE, COMPANY, BLANK
    var id: String { rawValue }
    var ten: String {
        switch self {
        case .CAPSTONE: return String(localized: "FPT Capstone")
        case .SWP391: return String(localized: "Software project")
        case .SWR302: return String(localized: "Requirements")
        case .SWT301: return String(localized: "Software testing")
        case .FREELANCE: return String(localized: "Client project")
        case .COMPANY: return String(localized: "Team project")
        case .BLANK: return String(localized: "Blank project")
        }
    }
    var moTa: String {
        switch self {
        case .CAPSTONE: return String(localized: "Stages for Reports 1–7, Iterations 1–3, FPT report templates in Docs, RAID, meetings and approvals.")
        case .SWP391: return String(localized: "Scrum with epics, stories, Sprint 1 ready and a bug lifecycle with retest.")
        case .SWR302: return String(localized: "Requirement issues with a MoSCoW field and Sprint 1 ready.")
        case .SWT301: return String(localized: "Test cases with steps, a test plan, test cycles and a full bug lifecycle.")
        case .FREELANCE: return String(localized: "Weekly sprints and hour estimates to report to the client.")
        case .COMPANY: return String(localized: "Code review and QA columns before Done.")
        case .BLANK: return String(localized: "To Do, In Progress, Done. Configure the rest yourself.")
        }
    }
    var bieuTuong: String {
        switch self {
        case .CAPSTONE: return "rosette"
        case .SWP391: return "graduationcap"
        case .SWR302: return "checklist"
        case .SWT301: return "flask"
        case .FREELANCE: return "briefcase"
        case .COMPANY: return "building.2"
        case .BLANK: return "square"
        }
    }
    /// Mẫu ⇒ loại (khớp `kindFromTemplate` của backend / TEMPLATE_KIND của web).
    var loai: LoaiDuAnCTW {
        switch self {
        case .CAPSTONE, .SWR302, .SWT301, .SWP391: return .SCHOOL
        case .FREELANCE: return .CLIENT
        case .BLANK, .COMPANY: return .SOFTWARE
        }
    }
}

/// Loại dự án (lớp studio) — mô-đun mặc định do MÁY CHỦ đặt theo loại.
enum LoaiDuAnCTW: String, CaseIterable, Identifiable {
    case PERSONAL, SCHOOL, SOFTWARE, CLIENT
    var id: String { rawValue }
    var ten: String {
        switch self {
        case .PERSONAL: return String(localized: "Personal")
        case .SCHOOL: return String(localized: "School / coursework")
        case .SOFTWARE: return String(localized: "Software team")
        case .CLIENT: return String(localized: "Client project (studio)")
        }
    }
    var moTa: String {
        switch self {
        case .PERSONAL: return String(localized: "Your own tasks and side projects. Just a board — nothing to set up.")
        case .SCHOOL: return String(localized: "Group assignments and capstones (SWP391, SWR302, SWT301). Sprints, tests and reports for your lecturer.")
        case .SOFTWARE: return String(localized: "A product team shipping software: sprints, code review, releases and GitHub.")
        case .CLIENT: return String(localized: "Work delivered for a client through departments: stages with gate reviews, approvals and handoffs.")
        }
    }
    var bieuTuong: String {
        switch self {
        case .PERSONAL: return "person"
        case .SCHOOL: return "graduationcap"
        case .SOFTWARE: return "chevron.left.forwardslash.chevron.right"
        case .CLIENT: return "briefcase"
        }
    }
    /// Mẫu gợi ý (KIND_TEMPLATE của web).
    var mauGoiY: MauDuAnCTW {
        switch self {
        case .PERSONAL: return .BLANK
        case .SCHOOL: return .SWP391
        case .SOFTWARE: return .COMPANY
        case .CLIENT: return .FREELANCE
        }
    }
}

enum MaDuAnCTW {
    /// Mã hợp lệ: 2–10 chữ/số, bắt đầu bằng chữ (PROJECT_KEY_RE).
    static func hopLe(_ k: String) -> Bool { k.range(of: #"^[A-Z][A-Z0-9]{1,9}$"#, options: .regularExpression) != nil }

    /// "SWP391 Group 3" ⇒ "SG3"; "Website" ⇒ "WEB" (bỏ dấu tiếng Việt) — như `deriveKey` của web.
    static func tuTen(_ ten: String) -> String {
        let bo = ten.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "đ", with: "d").replacingOccurrences(of: "Đ", with: "D").uppercased()
        let tu = bo.split { !($0.isASCII && ($0.isLetter || $0.isNumber)) }.map(String.init).filter { !$0.isEmpty }
        guard !tu.isEmpty else { return "" }
        var k = tu.count > 1 ? tu.map { String($0.prefix(1)) }.joined() : String(tu[0].prefix(3))
        while let c = k.first, c.isNumber { k.removeFirst() }
        if k.count < 2 {
            let chu = tu.first { $0.first?.isLetter == true } ?? ""
            k = String((k + chu.dropFirst(k.isEmpty ? 0 : 1)).prefix(3))
        }
        return String(k.prefix(10))
    }
}
