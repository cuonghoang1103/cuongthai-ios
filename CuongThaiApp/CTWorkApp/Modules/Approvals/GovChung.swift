import SwiftUI

// MARK: - Mảng Governance (Approvals · Change requests · RAID · Stages · Reviews) — phần DÙNG CHUNG
//
// Năm mô-đun cùng một nhịp: quyền đọc từ `permissions` của dự án, khoá chỉnh sửa
// cá nhân (423) giống nhau, và cùng cần "chọn người duyệt". Gom ở đây để mỗi
// mô-đun không tự viết lại một kiểu.

enum GovQuyen {
    /// Cờ quyền của dự án. THIẾU khoá ⇒ coi là có (máy chủ vẫn chặn thật) — để
    /// dự án cũ/máy chủ cũ chưa trả cờ mới không làm mất mục khỏi app.
    @MainActor
    static func co(_ cfg: CTWProjectConfig?, _ ten: String) -> Bool {
        cfg?.permissions?.tatCa[ten] ?? true
    }

    @MainActor
    static func laKhach(_ cfg: CTWProjectConfig?) -> Bool { cfg?.role == "CLIENT" }
}

/// Giá trị JSON: `nil` ⇒ `null` (gửi `null` để XOÁ trường — bỏ khoá là "không đổi").
func govNull(_ v: Any?) -> Any { v ?? NSNull() }

enum GovLoi {
    /// 423 khoá chỉnh sửa cá nhân (`editLock.service.ts`) — mã có lúc là
    /// `WORK_EDIT_LOCKED`, có lúc `EDIT_LOCKED` ⇒ so phần đuôi.
    static func laKhoaSua(_ e: Error) -> Bool {
        if case APIError.coMa(let ma, _) = e { return ma.hasSuffix("EDIT_LOCKED") }
        if case APIError.serverError(let m) = e { return m.contains("Editing is locked") }
        return false
    }

    static func laTatMoDun(_ e: Error) -> Bool {
        if case APIError.coMa(let ma, _) = e { return ma == "MODULE_DISABLED" || ma == "WORK_INTERNAL_ONLY" }
        return false
    }

    static func ma(_ e: Error) -> String? {
        if case APIError.coMa(let ma, _) = e { return ma }
        return nil
    }
}

extension CTWAPI {
    /// Tắt khoá chỉnh sửa cá nhân của dự án (`PUT /projects/:pid/edit-lock`).
    static func govMoKhoaSua(pid: Int) -> APIEndpoint { goi("/projects/\(pid)/edit-lock", "PUT", ["locked": false]) }
}

/// Dải "Editing is locked" + nút Unlock. Hiện khi một thao tác ghi bị 423.
struct GovDaiKhoaSua: View {
    let pid: Int
    var moXong: () -> Void
    @State private var dangMo = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill").foregroundColor(AppColors.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text("Editing is locked").font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                Text("You turned on read-only mode for this project.").font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
            }
            Spacer(minLength: 0)
            Button {
                dangMo = true
                Task {
                    defer { dangMo = false }
                    if (try? await APIClient.shared.send(CTWAPI.govMoKhoaSua(pid: pid))) != nil { CTWRung.thanhCong(); moXong() }
                }
            } label: {
                if dangMo { ProgressView() } else { Text("Unlock").font(.ctw(size: 14, weight: .semibold)) }
            }
            .buttonStyle(.bordered)
            .frame(minHeight: 44)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppColors.warning.opacity(0.12)))
    }
}

/// Chồng avatar (tối đa 4 + "+n").
struct GovChongAvatar: View {
    let users: [CTWUser]
    var size: CGFloat = 22
    var body: some View {
        HStack(spacing: -size * 0.3) {
            ForEach(Array(users.prefix(4).enumerated()), id: \.offset) { _, u in
                CTWAvatar(user: u, size: size)
                    .overlay(Circle().strokeBorder(AppColors.backgroundCard, lineWidth: 1.5))
            }
            if users.count > 4 {
                Text("+\(users.count - 4)").font(.ctw(size: size * 0.42, weight: .bold))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: size, height: size)
                    .background(Circle().fill(AppColors.backgroundTertiary))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(users.map { $0.laAgent ? "\($0.ten), AI agent" : $0.ten }.joined(separator: ", "))
    }
}

enum GovNgay {
    /// Date → ISO đầy đủ (dueAt của phê duyệt nhận ISO).
    static func iso(_ d: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: d)
    }

    /// Hạn ISO đã qua chưa (so cả giờ).
    static func daQua(_ s: String?) -> Bool {
        guard let s else { return false }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let d = f.date(from: s) ?? { f.formatOptions = [.withInternetDateTime]; return f.date(from: s) }()
        guard let d else { return CTW.quaHan(s) }
        return d < Date()
    }

    /// "2 days ago" / "in 3 days".
    static func tuongDoi(_ s: String?) -> String? {
        guard let s else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let d = f.date(from: s) ?? { f.formatOptions = [.withInternetDateTime]; return f.date(from: s) }() else { return nil }
        let r = RelativeDateTimeFormatter()
        r.locale = Locale(identifier: "en_US")
        r.unitsStyle = .full
        return r.localizedString(for: d, relativeTo: Date())
    }
}

/// Giá trị JSON "chữ hoặc số" (vd `line` của mục review) — giải mã khoan dung.
struct GovChuHoacSo: Codable, Hashable {
    var chu: String
    init(_ chu: String) { self.chu = chu }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { chu = s }
        else if let i = try? c.decode(Int.self) { chu = String(i) }
        else if let d = try? c.decode(Double.self) { chu = String(d) }
        else { chu = "" }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(chu)
    }
}

/// Màn trạng thái "mô-đun tắt / không có quyền xem".
struct GovTatMoDun: View {
    let ten: String
    var body: some View {
        CTWOTrong(bieuTuong: "lock.shield", tieuDe: "\(ten) isn't available",
                  moTa: "It's turned off for this project, or your role can't see it. A project admin can change this in project settings.")
    }
}

// MARK: - Chọn người duyệt + gửi yêu cầu phê duyệt (dùng cho Change request, có thể cho Docs)

/// Tấm "Request approval": chọn 1–10 người duyệt (người thật, vai được duyệt), kiểu
/// tuần tự/song song, hạn. `gui` trả `true` khi máy chủ nhận.
struct GovYeuCauDuyetView: View {
    let cfg: CTWProjectConfig?
    var tieuDe = "Request approval"
    var moTa: String?
    let gui: (_ ids: [Int], _ tuanTu: Bool, _ han: Date?) async -> String?

    @Environment(\.dismiss) private var dong
    @EnvironmentObject private var app: AppState
    @State private var chon: [Int] = []
    @State private var tuanTu = true
    @State private var coHan = false
    @State private var han = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var dangGui = false
    @State private var loi: String?

    /// Người duyệt: người thật có vai ADMIN/MEMBER/TEACHER/CLIENT (`approval.decide`).
    /// Agent bị máy chủ từ chối (`WORK_BAD_APPROVER`) ⇒ không liệt kê.
    private var ungVien: [CTWUser] {
        (cfg?.dsThanhVien ?? []).filter { !$0.laAgent && ["ADMIN", "MEMBER", "TEACHER", "CLIENT"].contains($0.role ?? "MEMBER") }
            .sorted { $0.ten.localizedCaseInsensitiveCompare($1.ten) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let loi { Section { CTWErrorBanner(text: loi) { self.loi = nil } }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear) }
                if let moTa { Section { Text(moTa).font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary) } }
                Section {
                    ForEach(ungVien) { u in
                        Button {
                            CTWRung.chon()
                            if let i = chon.firstIndex(of: u.id) { chon.remove(at: i) } else if chon.count < 10 { chon.append(u.id) }
                        } label: {
                            HStack(spacing: 12) {
                                CTWAvatar(user: u, size: 30)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(u.id == app.currentUser?.id ? "\(u.ten) (me)" : u.ten).foregroundColor(AppColors.textPrimary)
                                    if let r = u.role { Text(r.capitalized).font(.caption).foregroundColor(AppColors.textSecondary) }
                                }
                                Spacer()
                                if let i = chon.firstIndex(of: u.id) {
                                    Text(tuanTu ? "\(i + 1)" : "✓").font(.ctw(size: 13, weight: .bold))
                                        .foregroundColor(AppColors.onPrimary)
                                        .frame(width: 26, height: 26).background(Circle().fill(AppColors.primary))
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: { Text("Approvers") } footer: {
                    Text(tuanTu ? "Approvers sign in the order you pick them." : "Everyone can sign at the same time. One rejection ends the request.")
                }
                Section {
                    Picker("Order", selection: $tuanTu) {
                        Text("Sequential").tag(true)
                        Text("Parallel").tag(false)
                    }
                    .pickerStyle(.segmented)
                    Toggle("Due date", isOn: $coHan)
                    if coHan { DatePicker("Due", selection: $han, in: Date()..., displayedComponents: .date) }
                }
            }
            .navigationTitle(tieuDe)
            .ctwTieuDeNho()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    if dangGui { ProgressView() } else {
                        Button("Send") {
                            dangGui = true
                            Task {
                                defer { dangGui = false }
                                if let l = await gui(chon, tuanTu, coHan ? han : nil) { loi = l; CTWRung.loi() }
                                else { CTWRung.thanhCong(); dong() }
                            }
                        }
                        .bold()
                        .disabled(chon.isEmpty)
                    }
                }
            }
        }
    }
}
