import Foundation

// MARK: - CT Work — model Lớp học + Giảng dạy (`work.ctw5/9a/9b.routes.ts`; kiểu chuẩn ở
// `components/work/teaching/teachingApi.ts`, `classroom/classroomApi.ts`, `classroom/classworkApi.ts`).
// `var` + optional, ngày là chuỗi.

struct CTWLop: Codable, Hashable, Identifiable {
    struct NhomCuaToi: Codable, Hashable { var id: Int?; var name: String?; var href: String? }
    var id: Int
    var name: String
    /// SWP391 | SWT301 | SWR302 | SEP490 | ISP490 | OTHER
    var subject: String?
    var classCode: String?
    var term: String?
    /// OWNER | TEACHER | STUDENT
    var role: String?
    var archivedAt: String?
    var groups: Int?
    var students: Int?
    var group: NhomCuaToi?

    var laSinhVien: Bool { role == "STUDENT" }
}

struct CTWDsLop: Codable { var teaching: [CTWLop]?; var enrolled: [CTWLop]? }

struct CTWLopChiTiet: Codable {
    struct Nhom: Codable, Hashable, Identifiable {
        struct DA: Codable, Hashable { var id: Int?; var key: String?; var name: String?; var href: String? }
        var id: Int; var number: Int?; var name: String; var leaderId: Int?; var members: Int?; var project: DA?
    }
    struct Toi: Codable, Hashable { var id: Int?; var groupId: Int?; var studentCode: String? }
    var id: Int
    var name: String
    var subject: String?
    var classCode: String?
    var term: String?
    var role: String?
    var owner: CTWUser?
    var teacher: CTWUser?
    var maxGroupSize: Int?
    var archivedAt: String?
    var joinState: String?
    var groups: [Nhom]?
    var me: Toi?
    var manage: Bool?
    var joinCodeDisplay: String?
}

// MARK: Bài tập

struct CTWDiem: Codable, Hashable { var points: Double?; var rawPoints: Double?; var penaltyPct: Double?; var returnedAt: String? }

struct CTWBaiTap: Codable, Hashable, Identifiable {
    struct Cua: Codable, Hashable { var state: String?; var late: Bool?; var submittedAt: String?; var grade: CTWDiem? }
    struct Dem: Codable, Hashable { var assigned: Int?; var turnedIn: Int?; var late: Int?; var missing: Int?; var returned: Int?; var graded: Int? }
    var id: Int
    var classId: Int?
    var title: String
    var descriptionText: String?
    /// INDIVIDUAL | GROUP
    var kind: String?
    var category: String?
    var topic: String?
    var maxPoints: Double?
    var dueAt: String?
    var allowLate: Bool?
    var latePenaltyPct: Double?
    var state: String?
    var files: Int?
    var counts: Dem?
    var my: Cua?
}

struct CTWDsBaiTap: Codable { var manage: Bool?; var assignments: [CTWBaiTap]? }

struct CTWTepLop: Codable, Hashable, Identifiable {
    var id: Int; var fileName: String?; var mime: String?; var size: Int?; var createdAt: String?
}

struct CTWLienKetNop: Codable, Hashable { var url: String; var label: String? }

struct CTWBaiNop: Codable, Hashable {
    struct BinhLuan: Codable, Hashable, Identifiable { var id: Int; var body: String?; var createdAt: String?; var author: CTWUser?; var mine: Bool? }
    var needsGroup: Bool?
    var canTurnIn: Bool?
    var lateIfNow: Bool?
    var penaltyIfNow: Double?
    var id: Int?
    /// ASSIGNED | TURNED_IN | LATE | MISSING | RETURNED
    var state: String?
    var status: String?
    var text: String?
    var links: [CTWLienKetNop]?
    var files: [CTWTepLop]?
    var late: Bool?
    var submittedAt: String?
    var version: Int?
    var comments: [BinhLuan]?
    var grade: CTWDiem?
}

struct CTWBaiTapChiTiet: Codable {
    var id: Int
    var classId: Int?
    var title: String
    var description: CTWNode?
    var descriptionText: String?
    var kind: String?
    var category: String?
    var topic: String?
    var maxPoints: Double?
    var dueAt: String?
    var allowLate: Bool?
    var latePenaltyPct: Double?
    var latePenaltyMaxPct: Double?
    var manage: Bool?
    var files: [CTWTepLop]?
    var author: CTWUser?
    var submission: CTWBaiNop?
}

struct CTWDsBaiNop: Codable {
    struct Hang: Codable, Hashable, Identifiable {
        struct Nhom: Codable, Hashable { var id: Int?; var number: Int?; var name: String? }
        struct TV: Codable, Hashable { var userId: Int?; var studentCode: String?; var name: String? }
        var ownerKey: String
        var group: Nhom?
        var members: [TV]?
        var state: String?
        var late: Bool?
        var submittedAt: String?
        var points: Double?
        var returnedPoints: Double?
        var graded: Bool?
        var comments: Int?
        var files: Int?
        var id: String { ownerKey }
    }
    var rows: [Hang]?
}

struct CTWUrlTep: Codable { var url: String; var fileName: String? }

// MARK: Bảng tin lớp

struct CTWBaiDangLop: Codable, Hashable, Identifiable {
    struct BinhLuan: Codable, Hashable, Identifiable {
        var id: Int; var postId: Int?; var body: String?; var hidden: Bool?; var createdAt: String?
        var author: CTWUser?; var mine: Bool?; var canDelete: Bool?
    }
    struct LienKet: Codable, Hashable { var url: String; var title: String?; var kind: String? }
    var id: Int
    /// ANNOUNCEMENT | ASSIGNMENT | QUIZ | MATERIAL
    var kind: String?
    var title: String?
    var bodyJson: CTWNode?
    var links: [LienKet]?
    var refType: String?
    var refId: Int?
    var author: CTWUser?
    var files: [CTWTepLop]?
    var pinned: Bool?
    var commentsOff: Bool?
    var publishAt: String?
    var createdAt: String?
    var canComment: Bool?
    var comments: [BinhLuan]?
    var commentCount: Int?
}

struct CTWBangTinLop: Codable {
    var posts: [CTWBaiDangLop]?
    var nextBefore: String?
    var manage: Bool?
}

// MARK: Giảng dạy — tổng quan nhóm

struct CTWNhomGiangDay: Codable, Hashable, Identifiable {
    struct TV: Codable, Hashable, Identifiable { var id: Int; var name: String?; var username: String?; var role: String?; var status: String?; var signals: [String]? }
    struct The: Codable, Hashable { var open: Int?; var overdue: Int?; var done14: Int? }
    struct Sprint: Codable, Hashable { var name: String?; var status: String?; var done: Int?; var total: Int?; var daysLeft: Int?; var atRisk: Bool? }
    struct GD: Codable, Hashable { var n: Int?; var name: String?; var total: Int?; var completed: Int? }
    struct DongGop: Codable, Hashable { var completed: Int?; var actions: Int?; var attention: Int?; var lastActiveDay: String?; var silentDays: Int? }
    struct HoiDap: Codable, Hashable { var open: Int?; var oldestDays: Int? }
    struct RuiRo: Codable, Hashable { var open: Int?; var high: Int? }
    struct Diem: Codable, Hashable { var total: Int?; var published: Int?; var latestMilestone: String? }
    struct LyDo: Codable, Hashable { var code: String?; var level: String?; var n: Int? }
    struct SucKhoe: Codable, Hashable { var status: String?; var reasons: [LyDo]? }
    var projectId: Int
    var key: String?
    var name: String?
    var href: String?
    var workspace: String?
    var archived: Bool?
    var subject: String?
    var classCode: String?
    var term: String?
    var groupCode: String?
    var className: String?
    var members: [TV]?
    var issues: The?
    var sprint: Sprint?
    var stage: GD?
    var contrib: DongGop?
    var docs: [String: String]?
    var docsExpected: Int?
    var docsSubmitted: Int?
    var docsMissing: Int?
    var qna: HoiDap?
    var risks: RuiRo?
    var grades: Diem?
    var health: SucKhoe?
    var id: Int { projectId }
}

struct CTWTongQuanGiangDay: Codable {
    struct Tong: Codable, Hashable {
        var groups: Int?; var red: Int?; var amber: Int?; var green: Int?; var students: Int?; var overdue: Int?; var qnaOpen: Int?; var docsMissing: Int?
    }
    var totals: Tong?
    var groups: [CTWNhomGiangDay]?
}

struct CTWQuyenGiangDay: Codable { var teaching: Bool?; var projects: Int?; var classes: Int? }

// MARK: Nhãn + luật thuần (có kiểm thử)

enum CTWLopNhan {
    static func trangThaiNop(_ s: String?) -> String {
        switch s {
        case "TURNED_IN": return String(localized: "Turned in")
        case "LATE": return String(localized: "Turned in late")
        case "MISSING": return String(localized: "Missing")
        case "RETURNED": return String(localized: "Returned")
        default: return String(localized: "Assigned")
        }
    }

    static func mauNop(_ s: String?) -> String {
        // Trả về mã trạng thái chung để `CTWMauTrangThai.mau` tô màu.
        switch s {
        case "TURNED_IN", "RETURNED": return "DONE"
        case "LATE": return "LATE"
        case "MISSING": return "MISSING"
        default: return "OPEN"
        }
    }

    /// Có được bấm "Turn in" không (luật máy chủ `classwork.service.ts`): cần ít nhất một
    /// tệp, liên kết hoặc chữ; bài nhóm mà chưa vào nhóm thì không; đã nộp thì phải rút lại trước.
    static func nopDuoc(_ s: CTWBaiNop?) -> Bool {
        guard let s else { return false }
        if s.needsGroup == true { return false }
        if s.canTurnIn == false { return false }
        if s.status == "TURNED_IN" { return false }
        let coChu = !(s.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return coChu || !(s.links ?? []).isEmpty || !(s.files ?? []).isEmpty
    }

    static func mauSucKhoe(_ s: String?) -> String {
        switch s {
        case "red": return "RED"
        case "amber": return "AMBER"
        default: return "GREEN"
        }
    }

    static func diem(_ d: Double?) -> String {
        guard let d else { return "—" }
        return d == d.rounded() ? String(Int(d)) : String(format: "%.1f", d)
    }
}
