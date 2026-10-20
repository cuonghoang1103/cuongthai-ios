import SwiftUI

// MARK: - "Create with CuongMini" — điểm vào (tấm phủ riêng, có NavigationStack của nó)
//
// Web: `/work/<ws>/setup` (commit ee507275). Màn đầu: hai lựa chọn (Một dự án / Cả không gian), 3 bước, bản nháp của tôi.
// Chọn ⇒ tạo bản nháp (`POST /workspaces/:ws/setup-drafts`) ⇒ đẩy màn bản nháp (`BanNhapCuongMiniCTW`).
// Quyền: chỉ vai được tạo dự án (OWNER/ADMIN/MEMBER) mới thấy lối vào — máy chủ kiểm lại (`workspace.createProject`).
// App Store: 5.1.2(i) — đề bài/tệp/danh sách được GỬI cho nhà cung cấp AI ⇒ dùng chung đồng ý của trợ lý AI
// (`com.cuongthai.ctwork.ai.dongY`), hỏi trước lần gửi đầu; 4.7 — nội dung CuongMini viết có nhãn "AI-generated";
// 3.1.1 — không có chọn/mở khoá model, không lời mời mua.

struct TaoCuongMiniCTW: View {
    let ws: CTWWorkspace
    /// Mang sang từ hộp "New project" (tên, mã, mẫu…) ⇒ tạo bản nháp ngay.
    var mangSang: CTWDauVaoCM?
    let xong: (CTWKetQuaCM.DuAn) -> Void
    @Environment(\.dismiss) private var dong
    @AppStorage("com.cuongthai.ctwork.ai.dongY") private var daDongY = false
    @State private var duong: [Int] = []
    @State private var ds: [CTWTomTatBanNhapCM] = []
    @State private var dangTao = false
    @State private var loi: String?
    @State private var hoiDongY: String?
    @State private var daMangSang = false

    var body: some View {
        NavigationStack(path: $duong) {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles").font(.ctw(size: 18, weight: .bold)).foregroundColor(AppColors.primary)
                                .frame(width: 40, height: 40)
                                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColors.primary.opacity(0.12)))
                                .accessibilityHidden(true)
                            CTWNhanAI(chu: "CuongMini")
                        }
                        Text("Let CuongMini set up the work for your team").font(.ctw(size: 20, weight: .bold))
                            .foregroundColor(AppColors.textPrimary).fixedSize(horizontal: false, vertical: true)
                        Text("Give it the brief, code, member list and deadline. CuongMini tells you what it understood first; once you accept, it builds epics, stories, sprints, assignments, docs, risks and meetings.")
                            .font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.clear)
                }
                Section {
                    the(cheDo: "PROJECT", bieuTuong: "folder", tieuDe: String(localized: "One project"),
                        moTa: String(localized: "A team project, capstone or client job — one board with everything planned."))
                    the(cheDo: "WORKSPACE", bieuTuong: "building.2", tieuDe: String(localized: "A whole workspace"),
                        moTa: String(localized: "Several teams or products at once — e.g. a lecturer's class of 8 groups, one project and one leader each."))
                }
                Section {
                    ForEach(Array([String(localized: "Fill in what you have and upload files — everything is optional except a name or a brief."),
                                   String(localized: "Read CuongMini's summary, answer its questions, fix what it got wrong, then accept."),
                                   String(localized: "Review the plan — modules, epics, stories, sprints and people — then create.")].enumerated()), id: \.offset) { i, t in
                        HStack(alignment: .top, spacing: 10) {
                            Text(verbatim: "\(i + 1)").font(.ctw(size: 13, weight: .bold)).foregroundColor(AppColors.primary).monospacedDigit()
                            Text(t).font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } header: { Text("How it works").textCase(nil) }
                if !ds.isEmpty {
                    Section {
                        ForEach(ds) { d in
                            NavigationLink(value: d.id) {
                                VStack(alignment: .leading, spacing: 3) {
                                    if let t = d.title, !t.isEmpty { Text(verbatim: t).font(.ctw(size: 15, weight: .medium)).lineLimit(2) }
                                    else { Text("Untitled draft").font(.ctw(size: 15, weight: .medium)) }
                                    Text(verbatim: dongPhu(d))
                                        .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                                }
                            }
                            .swipeActions {
                                if d.status != "APPLIED" {
                                    Button(role: .destructive) { Task { await xoa(d) } } label: { Label("Delete draft", systemImage: "trash") }
                                }
                            }
                        }
                    } header: { Text("Your drafts").textCase(nil) }
                }
            }
            .listStyle(.insetGrouped)
            .overlay { if dangTao { ProgressView().controlSize(.large) } }
            .navigationTitle(Text("Create with CuongMini"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dong() } } }
            .navigationDestination(for: Int.self) { id in
                BanNhapCuongMiniCTW(id: id, ws: ws, xong: xong)
            }
            .task { await taiDs(); await mangSangNeuCo() }
            .refreshable { await taiDs() }
            .alert(loi ?? "", isPresented: Binding(get: { loi != nil }, set: { if !$0 { loi = nil } })) { Button("OK", role: .cancel) {} }
            .sheet(item: Binding(get: { hoiDongY.map { DongYCMItem(cheDo: $0) } }, set: { hoiDongY = $0?.cheDo })) { m in
                DongYAICTW {
                    daDongY = true
                    hoiDongY = nil
                    Task { await batDau(m.cheDo) }
                } huy: { hoiDongY = nil }
            }
            #if DEBUG
            .task {
                if let id = DuLieuGiaTaoCM.idXem { daDongY = true; duong = [id] }
            }
            #endif
        }
    }

    private func dongPhu(_ d: CTWTomTatBanNhapCM) -> String {
        let cheDo = d.mode == "WORKSPACE" ? String(localized: "Workspace") : String(localized: "Project")
        let phan: [String?] = [NhanCM.trangThai(d.status), cheDo, CTW.thoiDiem(d.updatedAt)]
        return phan.compactMap { $0 }.joined(separator: " · ")
    }

    private func the(cheDo: String, bieuTuong: String, tieuDe: String, moTa: String) -> some View {
        Button { thu(cheDo) } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: bieuTuong).font(.ctw(size: 16, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(AppColors.backgroundTertiary))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tieuDe).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    Text(moTa).font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(dangTao)
        .accessibilityIdentifier("cm.start.\(cheDo)")
    }

    private func thu(_ cheDo: String) {
        guard daDongY else { hoiDongY = cheDo; return }
        Task { await batDau(cheDo) }
    }

    private func batDau(_ cheDo: String, dauVao: CTWDauVaoCM? = nil) async {
        dangTao = true
        defer { dangTao = false }
        var dv = dauVao ?? CTWDauVaoCM()
        dv.reviewFirst = true   // iOS: luôn dừng ở kế hoạch để xem/sửa trước khi tạo
        do {
            let d: CTWBanNhapCM = try await APIClient.shared.request(CTWAPI.cmTaoBanNhap(ws: ws.id, cheDo: cheDo, dauVao: dv))
            duong = [d.id]
            await taiDs()
        } catch { loi = BanNhapCMVM.cauLoi(error) }
    }

    private func mangSangNeuCo() async {
        guard let m = mangSang, !daMangSang else { return }
        daMangSang = true
        guard daDongY else { return }   // chưa đồng ý ⇒ người dùng bấm thẻ (hộp đồng ý) — tên/mã vẫn điền được sau
        await batDau("PROJECT", dauVao: m)
    }

    private func taiDs() async {
        if let d: [CTWTomTatBanNhapCM] = try? await APIClient.shared.request(CTWAPI.cmDsBanNhap(ws: ws.id)) { ds = d }
    }

    private func xoa(_ d: CTWTomTatBanNhapCM) async {
        do {
            try await APIClient.shared.send(CTWAPI.cmXoa(id: d.id))
            ds.removeAll { $0.id == d.id }
        } catch { loi = BanNhapCMVM.cauLoi(error) }
    }
}

private struct DongYCMItem: Identifiable { var cheDo: String; var id: String { cheDo } }

// MARK: - Nhãn dùng chung

enum NhanCM {
    static func trangThai(_ s: String?) -> String? {
        switch s {
        case "DRAFT": return String(localized: "Draft")
        case "READING": return String(localized: "Reading")
        case "UNDERSTOOD": return String(localized: "Summary ready")
        case "PLANNING": return String(localized: "Planning")
        case "READY": return String(localized: "Plan ready")
        case "APPLYING": return String(localized: "Creating")
        case "APPLIED": return String(localized: "Created")
        case "FAILED": return String(localized: "Stopped")
        case "CANCELLED": return String(localized: "Cancelled")
        default: return nil
        }
    }

    /// Nhãn bước tiến độ — khoá máy chủ dạng `head[:x[:sub]]` (như `stepLabel` của web).
    static func buoc(_ k: String) -> String {
        let p = k.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        switch p.first ?? "" {
        case "read": return String(localized: "Read files, links and repo")
        case "understand": return String(localized: "Write a summary of what it understood")
        case "prepare": return String(localized: "Projects, members and sprints")
        case "outline": return String(localized: "Plan epics, modules, risks and sprint goals")
        case "epics": return String(localized: "Write stories and subtasks for each epic")
        case "tests": return String(localized: "Write the key test cases")
        case "pages": return String(localized: "Write Docs pages")
        case "assemble": return String(localized: "Assign, schedule and check the load")
        case "revise": return String(localized: "Revise the plan")
        case "create": return String(localized: "Create in CT Work")
        case "project": return String(localized: "Project")
        case "invites": return String(localized: "Send invitations")
        default: return p.count > 2 ? "\(p[0]) \(p[2])" : k
        }
    }

    static func canhBao(_ k: String?) -> String {
        switch k {
        case "MISSING_INFO": return String(localized: "Missing info")
        case "OVERLOAD": return String(localized: "Overloaded")
        case "DEADLINE": return String(localized: "Deadline")
        case "UNASSIGNED": return String(localized: "Unassigned")
        case "BEGINNER_HARD": return String(localized: "Beginner on hard work")
        case "CAP": return String(localized: "Limit")
        case "NO_EMAIL": return String(localized: "No email")
        case "SOURCE": return String(localized: "While creating content")
        default: return k ?? ""
        }
    }

    static func cachGhep(_ m: String?) -> String {
        switch m {
        case "USER": return String(localized: "In the workspace")
        case "INVITE": return String(localized: "Invite by email")
        default: return String(localized: "Planned owner only")
        }
    }

    static func loaiViec(_ k: String?) -> String {
        switch k {
        case "EPIC": return "Epic"
        case "STORY": return "Story"
        case "TASK": return String(localized: "Task")
        case "BUG": return "Bug"
        case "SUBTASK": return String(localized: "Subtask")
        default: return k ?? ""
        }
    }

    static func diem(_ d: Double?) -> String? {
        guard let d else { return nil }
        return d.rounded() == d ? String(Int(d)) : String(format: "%.1f", d)
    }
}
