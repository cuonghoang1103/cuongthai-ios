import SwiftUI

// MARK: - CT Work — model khớp JSON của `/api/v1/work`
//
// Nguồn hình dạng: `frontend/src/lib/work-api.ts` của backend.
// ⚠️ Mọi trường là `var` + optional (C4 trong CLAUDE.md): `let` có mặc định
// thì Codable bỏ qua im lặng, và một trường thiếu là cả lượt giải mã hỏng.
// ⚠️ Ngày giữ dạng CHUỖI (C3): JSONDecoder của APIClient dùng chiến lược
// ngày mặc định, khai `Date` là hỏng hết.
// ⚠️ Chữ hiện cho người dùng trong module này là TIẾNG ANH (quyết định sản
// phẩm: CT Work chỉ có tiếng Anh).

struct CTWUser: Codable, Hashable, Identifiable {
    var id: Int
    var username: String?
    var fullName: String?
    var displayName: String?
    var avatarUrl: String?
    /// Vai trò trong dự án — chỉ có ở `members` của cấu hình dự án.
    var role: String?

    var ten: String {
        for s in [displayName, fullName, username] {
            if let s, !s.trimmingCharacters(in: .whitespaces).isEmpty { return s }
        }
        return "User #\(id)"
    }

    /// Hai chữ cái đầu cho vòng tròn khi không có ảnh.
    var kyTuDau: String {
        let tu = ten.split(separator: " ").prefix(2).compactMap(\.first)
        return tu.isEmpty ? "?" : String(tu).uppercased()
    }

    /// Người được GIAO thẻ phải có quyền sửa thẻ (ADMIN/MEMBER) — máy chủ
    /// từ chối người khác bằng `WORK_BAD_ASSIGNEE` (`assertAssignable`).
    var giaoDuoc: Bool { role == nil || role == "ADMIN" || role == "MEMBER" }
}

struct CTWWorkspace: Codable, Hashable, Identifiable {
    var id: Int
    var name: String
    var slug: String
    var description: String?
    var role: String?
    var projectCount: Int?
    var memberCount: Int?
}

struct CTWProjectSummary: Codable, Hashable, Identifiable {
    var id: Int
    var key: String
    var name: String
    var description: String?
    var type: String?
    var template: String?
    var visibility: String?
    var archivedAt: String?
    var lead: CTWUser?
    var role: String?
    var openIssues: Int?
}

struct CTWWorkspaceDetail: Codable {
    var id: Int
    var name: String
    var slug: String
    var description: String?
    var role: String?
    var projects: [CTWProjectSummary]?
}

struct CTWStatus: Codable, Hashable, Identifiable {
    var id: Int
    var name: String
    var category: String?
    var color: String?
    var position: Int?
    var wipLimit: Int?
}

struct CTWTransition: Codable, Hashable {
    var id: Int
    var fromStatusId: Int?
    var toStatusId: Int
    var name: String?
}

struct CTWWorkflow: Codable, Hashable, Identifiable {
    var id: Int
    var name: String?
    var isDefault: Bool?
    var statuses: [CTWStatus]?
    var transitions: [CTWTransition]?
}

struct CTWIssueType: Codable, Hashable, Identifiable {
    var id: Int
    var key: String?
    var name: String
    var icon: String?
    var color: String?
    /// 1 = epic, 0 = thường, -1 = sub-task.
    var level: Int?
    var workflowId: Int?
}

struct CTWLabel: Codable, Hashable, Identifiable {
    var id: Int
    var name: String
    var color: String?
}

struct CTWSprint: Codable, Hashable, Identifiable {
    var id: Int
    var name: String
    var goal: String?
    var state: String?
    var startAt: String?
    var endAt: String?
}

struct CTWBoardColumn: Codable, Hashable, Identifiable {
    var key: String
    var name: String
    var category: String?
    var statusIds: [Int]?
    var wipLimit: Int?
    var id: String { key }
}

/// Cờ quyền máy chủ gửi để ẨN/HIỆN nút. Chỉ để hiển thị — API vẫn kiểm lại.
struct CTWPermissions: Codable, Hashable {
    var editIssues: Bool?
    var createIssues: Bool?
    var transition: Bool?
    var deleteIssues: Bool?
    var comment: Bool?
    var attach: Bool?
    var manageSprints: Bool?
    var settings: Bool?
    var manageMembers: Bool?
    var useAi: Bool?
}

struct CTWWorkspaceRef: Codable, Hashable {
    var id: Int?
    var name: String?
    var slug: String?
}

struct CTWProjectConfig: Codable {
    var id: Int
    var key: String
    var name: String
    var description: String?
    var type: String?
    var archivedAt: String?
    var workspace: CTWWorkspaceRef?
    var workflows: [CTWWorkflow]?
    var issueTypes: [CTWIssueType]?
    var labels: [CTWLabel]?
    var sprints: [CTWSprint]?
    var role: String?
    var workspaceRole: String?
    var permissions: CTWPermissions?
    var boardColumns: [CTWBoardColumn]?
    var members: [CTWUser]?

    // MARK: Tra cứu

    var dsLoai: [CTWIssueType] { issueTypes ?? [] }
    var dsThanhVien: [CTWUser] { members ?? [] }
    var coTheSua: Bool { permissions?.editIssues == true }
    var coTheChuyen: Bool { permissions?.transition == true }
    var coTheTao: Bool { permissions?.createIssues == true }
    var coTheBinhLuan: Bool { permissions?.comment == true }

    func loai(_ id: Int) -> CTWIssueType? { dsLoai.first { $0.id == id } }
    func thanhVien(_ id: Int?) -> CTWUser? {
        guard let id else { return nil }
        return dsThanhVien.first { $0.id == id }
    }

    var tatCaTrangThai: [CTWStatus] { (workflows ?? []).flatMap { $0.statuses ?? [] } }
    func trangThai(_ id: Int) -> CTWStatus? { tatCaTrangThai.first { $0.id == id } }

    /// Quy trình của một loại thẻ: loại có `workflowId` riêng thì dùng nó,
    /// không thì quy trình mặc định (đúng như `workflowIdForType` ở máy chủ).
    func quyTrinh(choLoai typeId: Int) -> CTWWorkflow? {
        let wfs = workflows ?? []
        if let wid = loai(typeId)?.workflowId, let wf = wfs.first(where: { $0.id == wid }) { return wf }
        return wfs.first { $0.isDefault == true } ?? wfs.first
    }

    /// Trạng thái chuyển tới được từ `tu`. Quy trình KHÔNG có luồng chuyển
    /// nào = chuyển tự do (`assertTransitionAllowed`). Có thì phải khớp một
    /// dòng `from = tu` hoặc `from = null` (mọi nơi).
    func trangThaiDich(loai typeId: Int, tu: Int) -> [CTWStatus] {
        guard let wf = quyTrinh(choLoai: typeId) else { return [] }
        let tatCa = (wf.statuses ?? []).sorted { ($0.position ?? 0) < ($1.position ?? 0) }
        let luong = wf.transitions ?? []
        if luong.isEmpty { return tatCa }
        let den = Set(luong.filter { $0.fromStatusId == nil || $0.fromStatusId == tu }.map(\.toStatusId))
        return tatCa.filter { $0.id == tu || den.contains($0.id) }
    }

    /// Trạng thái ban đầu hợp lệ của một cột cho một loại thẻ (kéo thả vào cột).
    func trangThaiTrongCot(_ cot: CTWBoardColumn, loai typeId: Int, tu: Int) -> CTWStatus? {
        let dich = trangThaiDich(loai: typeId, tu: tu)
        let ids = cot.statusIds ?? []
        return dich.first { ids.contains($0.id) }
    }

    /// Người giao được: vai trò ADMIN/MEMBER.
    var nguoiGiaoDuoc: [CTWUser] {
        dsThanhVien.filter(\.giaoDuoc).sorted { $0.ten.localizedCaseInsensitiveCompare($1.ten) == .orderedAscending }
    }
}

/// Một thẻ trên bảng.
struct CTWIssueCard: Codable, Hashable, Identifiable {
    var id: Int
    var number: Int
    var title: String
    var typeId: Int
    var statusId: Int
    var parentId: Int?
    var parentNumber: Int?
    var sprintId: Int?
    var priority: Int?
    var assigneeId: Int?
    var reporterId: Int?
    var storyPoints: Double?
    var dueDate: String?
    var rank: String?
    var version: Int?
    var resolvedAt: String?
    var createdAt: String?
    var updatedAt: String?
    var labelIds: [Int]?
    var subtaskCount: Int?
    var commentCount: Int?
    var attachmentCount: Int?
}

struct CTWBoardData: Codable {
    var mode: String?
    var sprint: CTWSprint?
    var fallback: Bool?
    var issues: [CTWIssueCard]?
}

struct CTWIssueRef: Codable, Hashable, Identifiable {
    var id: Int
    var number: Int
    var title: String
    var typeId: Int?
    var statusId: Int?
    var assigneeId: Int?
    var priority: Int?
    var key: String?
}

struct CTWIssueLink: Codable, Hashable, Identifiable {
    var id: Int
    var type: String?
    var direction: String?
    var issue: CTWIssueRef?
}

struct CTWIssueDetail: Codable, Identifiable {
    var id: Int
    var number: Int
    var title: String
    var typeId: Int
    var statusId: Int
    var parentId: Int?
    var sprintId: Int?
    var priority: Int?
    var assigneeId: Int?
    var reporterId: Int?
    var storyPoints: Double?
    var dueDate: String?
    var startDate: String?
    var version: Int?
    var resolvedAt: String?
    var resolution: String?
    var createdAt: String?
    var updatedAt: String?
    var labelIds: [Int]?
    var commentCount: Int?
    var descriptionJson: CTWNode?
    var assignee: CTWUser?
    var reporter: CTWUser?
    var parent: CTWIssueRef?
    var children: [CTWIssueRef]?
    var links: [CTWIssueLink]?
    var watcherCount: Int?
    var isWatching: Bool?
    var canDelete: Bool?
}

struct CTWComment: Codable, Identifiable, Hashable {
    var id: Int
    var bodyJson: CTWNode?
    var isAi: Bool?
    var createdAt: String?
    var editedAt: String?
    var author: CTWUser?
}

// MARK: My work

struct CTWMyWorkType: Codable, Hashable { var key: String?; var name: String?; var color: String? }
struct CTWMyWorkStatus: Codable, Hashable { var name: String?; var category: String? }
struct CTWMyWorkProject: Codable, Hashable { var key: String?; var name: String? }
struct CTWMyWorkSpace: Codable, Hashable { var slug: String?; var name: String? }

struct CTWMyWorkItem: Codable, Hashable, Identifiable {
    var key: String
    var number: Int
    var title: String
    var priority: Int?
    var dueDate: String?
    /// overdue | today | soon | later | none
    var bucket: String?
    var type: CTWMyWorkType?
    var status: CTWMyWorkStatus?
    var updatedAt: String?
    var project: CTWMyWorkProject?
    var workspace: CTWMyWorkSpace?
    var url: String?
    var id: String { key }
}

struct CTWMyWorkCounts: Codable, Hashable {
    var overdue: Int?
    var dueToday: Int?
    var dueSoon: Int?
    var inProgress: Int?
    var total: Int?
}

struct CTWMyWork: Codable {
    var items: [CTWMyWorkItem]?
    var counts: CTWMyWorkCounts?
}

struct CTWResolve: Codable { var projectId: Int }

// MARK: - TipTap (mô tả + bình luận)

/// Nút JSON của TipTap. Giải mã KHOAN DUNG: hỏng một nhánh thì bỏ nhánh đó,
/// không làm hỏng cả thẻ — `attrs` là JSON tự do (số, chuỗi, null lẫn lộn).
struct CTWNode: Codable, Hashable {
    var type: String?
    var text: String?
    var nhan: String?
    var content: [CTWNode]?

    private enum CodingKeys: String, CodingKey { case type, text, attrs, content }
    private struct KhoaDong: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    init(type: String?, text: String? = nil, content: [CTWNode]? = nil) {
        self.type = type; self.text = text; self.content = content
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try? c.decodeIfPresent(String.self, forKey: .type)
        text = try? c.decodeIfPresent(String.self, forKey: .text)
        content = (try? c.decodeIfPresent([CTWNode].self, forKey: .content)) ?? nil
        // @nhắc tên: lấy `label`, không có thì `id`.
        if let a = try? c.nestedContainer(keyedBy: KhoaDong.self, forKey: .attrs) {
            for ten in ["label", "id"] {
                guard let k = KhoaDong(stringValue: ten) else { continue }
                if let s = try? a.decode(String.self, forKey: k) { nhan = s; break }
                if let n = try? a.decode(Int.self, forKey: k) { nhan = String(n); break }
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(type, forKey: .type)
        try c.encodeIfPresent(text, forKey: .text)
        try c.encodeIfPresent(content, forKey: .content)
    }

    private static let khoi: Set<String> = [
        "paragraph", "heading", "blockquote", "codeBlock", "listItem", "taskItem", "tableRow", "horizontalRule",
    ]

    /// Chữ trơn — cùng luật với `tiptapToText` ở máy chủ.
    var chuTron: String {
        var out = ""
        func di(_ n: CTWNode) {
            if let t = n.text { out += t }
            else if n.type == "mention" { out += "@" + (n.nhan ?? "") }
            else if n.type == "hardBreak" { out += "\n" }
            n.content?.forEach(di)
            if let t = n.type, Self.khoi.contains(t) { out += "\n" }
        }
        di(self)
        while out.contains("\n\n\n") { out = out.replacingOccurrences(of: "\n\n\n", with: "\n\n") }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Dựng doc TipTap từ chữ trơn: mỗi dòng một đoạn. Trả về dạng
    /// `[String: Any]` để nhét thẳng vào thân yêu cầu.
    static func docTuChu(_ chu: String) -> [String: Any] {
        let doan: [[String: Any]] = chu
            .components(separatedBy: "\n")
            .map { dong in
                dong.isEmpty
                    ? ["type": "paragraph"]
                    : ["type": "paragraph", "content": [["type": "text", "text": dong]]]
            }
        return ["type": "doc", "content": doan]
    }
}

// MARK: - Tiện ích hiển thị

enum CTW {
    /// 1 = Highest … 5 = Lowest (cùng thứ tự với Jira và với web).
    static let doUuTien: [(so: Int, ten: String, bieuTuong: String, mau: Color)] = [
        (1, "Highest", "chevron.up.2", Color(hex: 0xDC2626)),
        (2, "High", "chevron.up", Color(hex: 0xEA580C)),
        (3, "Medium", "equal", Color(hex: 0xCA8A04)),
        (4, "Low", "chevron.down", Color(hex: 0x2563EB)),
        (5, "Lowest", "chevron.down.2", Color(hex: 0x64748B)),
    ]

    static func uuTien(_ p: Int?) -> (so: Int, ten: String, bieuTuong: String, mau: Color) {
        doUuTien.first { $0.so == (p ?? 3) } ?? doUuTien[2]
    }

    /// Biểu tượng SF theo `icon`/`key` của loại thẻ.
    static func bieuTuongLoai(_ t: CTWIssueType?) -> String {
        bieuTuongLoai(key: t?.icon ?? t?.key)
    }

    static func bieuTuongLoai(key: String?) -> String {
        switch (key ?? "").lowercased() {
        case "epic": return "bolt.fill"
        case "story": return "bookmark.fill"
        case "bug": return "ladybug.fill"
        case "subtask", "sub-task": return "arrow.turn.down.right"
        case "test": return "checkmark.seal.fill"
        case "requirement": return "doc.text.fill"
        default: return "checkmark.square.fill"
        }
    }

    /// `#7c3aed` → Color. Chuỗi hỏng thì về màu phụ.
    static func mau(_ hex: String?, macDinh: Color = AppColors.textTertiary) -> Color {
        guard var s = hex?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return macDinh }
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return macDinh }
        return Color(red: Double((v >> 16) & 0xFF) / 255,
                     green: Double((v >> 8) & 0xFF) / 255,
                     blue: Double(v & 0xFF) / 255)
    }

    static func mauNhom(_ category: String?) -> Color {
        switch category {
        case "DONE": return AppColors.success
        case "IN_PROGRESS": return Color(hex: 0x2563EB)
        default: return AppColors.textTertiary
        }
    }

    /// "2026-09-25" hoặc ISO đầy đủ → phần ngày `YYYY-MM-DD`.
    static func ngay(_ s: String?) -> String? {
        guard let s, s.count >= 10 else { return nil }
        return String(s.prefix(10))
    }

    private static let docNgay: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func ngayDate(_ s: String?) -> Date? {
        guard let d = ngay(s) else { return nil }
        return docNgay.date(from: d)
    }

    static func chuoiNgay(_ d: Date) -> String {
        // Ngày người dùng chọn theo giờ MÁY — đổi sang chuỗi theo lịch máy.
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    /// "Sep 25" / "Sep 25, 2027".
    static func ngayNgan(_ s: String?) -> String? {
        guard let d = ngayDate(s) else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.timeZone = TimeZone(identifier: "UTC")
        let namNay = Calendar.current.component(.year, from: Date())
        var lich = Calendar(identifier: .gregorian)
        lich.timeZone = TimeZone(identifier: "UTC")!
        f.dateFormat = lich.component(.year, from: d) == namNay ? "MMM d" : "MMM d, yyyy"
        return f.string(from: d)
    }

    /// Hạn đã qua (so theo ngày máy, không so giờ).
    static func quaHan(_ s: String?) -> Bool {
        guard let d = ngay(s) else { return false }
        return d < chuoiNgay(Date())
    }

    /// Thời điểm ISO → "Sep 25, 14:05".
    static func thoiDiem(_ s: String?) -> String {
        guard let s else { return "" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let d = iso.date(from: s) ?? {
            iso.formatOptions = [.withInternetDateTime]
            return iso.date(from: s)
        }()
        guard let d else { return s }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "MMM d, HH:mm"
        return f.string(from: d)
    }

    /// Câu lỗi bằng TIẾNG ANH. Lỗi của máy chủ CT Work vốn đã là tiếng Anh
    /// (`WORK_TRANSITION_DENIED`, 409 xung đột…) nên giữ nguyên; chỉ thay
    /// những câu tiếng Việt mà `APIError` tự dựng ở client.
    static func loi(_ e: Error) -> String {
        if let a = e as? APIError {
            switch a {
            case .unauthorized: return "Your session has expired. Please sign in again."
            case .networkError: return "Can't reach the server. Check your connection and try again."
            case .decodingError: return "The server sent an unexpected response. Please update the app or try again later."
            case .invalidURL, .noData, .unknown: return "Something went wrong. Please try again."
            case .coMa(let ma, let m):
                if ma == "WORK_QUOTA" || ma.hasSuffix("QUOTA_EXCEEDED") { return m.isEmpty ? "You've reached your plan limit." : m }
                return m
            case .serverError(let m):
                // Không có câu nào từ máy chủ ⇒ APIClient tự dựng "Máy chủ trả lỗi N."
                if m.hasPrefix("Máy chủ trả lỗi") {
                    let so = m.filter(\.isNumber)
                    switch so {
                    case "403": return "You don't have access to this."
                    case "404": return "Not found. It may have been deleted, or CT Work isn't available yet."
                    case "409": return "Someone else just changed this. Pull to refresh and try again."
                    case "429": return "Too many requests. Please wait a moment."
                    default: return "Server error (\(so)). Please try again."
                    }
                }
                // 404 của tuyến chưa mở trên máy chủ ("Route GET … not found").
                if m.hasPrefix("Route ") && m.hasSuffix("not found") {
                    return "CT Work isn't available on the server yet."
                }
                return m
            }
        }
        if e is URLError { return "Can't reach the server. Check your connection and try again." }
        return e.localizedDescription
    }

    /// Lỗi 409 (có người vừa sửa thẻ) — nơi gọi nạp lại thay vì chỉ báo.
    static func laXungDot(_ e: Error) -> Bool {
        guard let a = e as? APIError else { return false }
        switch a {
        case .coMa(let ma, _): return ma == "CONFLICT" || ma.hasSuffix("_CONFLICT")
        case .serverError(let m): return m.contains("Someone else just changed") || m.contains("board changed")
        default: return false
        }
    }
}

// MARK: - Vòng tròn người

struct CTWAvatar: View {
    let user: CTWUser?
    var size: CGFloat = 24

    var body: some View {
        Group {
            if let u = user {
                if let url = u.avatarUrl, !url.isEmpty {
                    UserAvatarView(url: url, size: size)
                } else {
                    Text(u.kyTuDau)
                        .font(.system(size: size * 0.4, weight: .semibold))
                        .foregroundColor(AppColors.onPrimary)
                        .frame(width: size, height: size)
                        .background(Circle().fill(AppColors.primary.opacity(0.85)))
                }
            } else {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: size * 0.75))
                    .foregroundColor(AppColors.textTertiary)
                    .frame(width: size, height: size)
            }
        }
        .accessibilityLabel(user?.ten ?? "Unassigned")
    }
}

struct CTWTypeIcon: View {
    let type: CTWIssueType?
    var size: CGFloat = 14

    var body: some View {
        Image(systemName: CTW.bieuTuongLoai(type))
            .font(.system(size: size * 0.7, weight: .bold))
            .foregroundColor(.white)
            .frame(width: size + 4, height: size + 4)
            .background(RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(CTW.mau(type?.color, macDinh: Color(hex: 0x2563EB))))
            .accessibilityLabel(type?.name ?? "Issue")
    }
}

struct CTWPriorityIcon: View {
    let priority: Int?
    var body: some View {
        let p = CTW.uuTien(priority)
        Image(systemName: p.bieuTuong)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(p.mau)
            .accessibilityLabel("\(p.ten) priority")
    }
}

struct CTWStatusChip: View {
    let status: CTWStatus?
    var body: some View {
        Text((status?.name ?? "—").uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(CTW.mauNhom(status?.category))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(CTW.mauNhom(status?.category).opacity(0.14)))
    }
}

/// Dải lỗi nhỏ đặt trên đầu màn — lỗi nói tại chỗ, không bật hộp thoại.
struct CTWErrorBanner: View {
    let text: String
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(AppColors.error)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppColors.error.opacity(0.10)))
    }
}

extension View {
    /// `insetGrouped` chỉ có trên iOS — macOS dùng `inset`.
    @ViewBuilder
    func ctwKieuDanhSach() -> some View {
        #if os(iOS)
        self.listStyle(.insetGrouped)
        #else
        self.listStyle(.inset)
        #endif
    }

    /// Tiêu đề nhỏ (inline) — chỉ iOS có khái niệm này.
    @ViewBuilder
    func ctwTieuDeNho() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
