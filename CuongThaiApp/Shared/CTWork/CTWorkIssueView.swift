import SwiftUI

// MARK: - CT Work — Chi tiết thẻ
//
// Sửa trường nào thì PATCH đúng trường đó kèm `version` — máy chủ trả 409 khi
// có người sửa chen giữa; lúc đó nạp lại và báo, không ghi đè.
// Đổi trạng thái đi qua `/move` (quyền `issue.transition`), còn lại qua PATCH
// (quyền `issue.edit`). Người xem/giảng viên/khách hàng chỉ đọc.

@MainActor
final class CTWIssueVM: ObservableObject {
    let pid: Int
    let so: Int
    @Published var cauHinh: CTWProjectConfig?
    @Published var the: CTWIssueDetail?
    @Published var binhLuan: [CTWComment] = []
    @Published var loi: String?
    @Published var dangGui = false

    init(pid: Int, so: Int) { self.pid = pid; self.so = so }

    func tai() async {
        do {
            async let c: CTWProjectConfig = APIClient.shared.request(.workDuAn(pid: pid))
            async let t: CTWIssueDetail = APIClient.shared.request(.workThe(pid: pid, so: so))
            let (cc, tt) = try await (c, t)
            cauHinh = cc
            the = tt
            loi = nil
        } catch {
            loi = CTW.loi(error)
        }
        await taiBinhLuan()
    }

    func taiBinhLuan() async {
        do {
            binhLuan = try await APIClient.shared.request(.workDsBinhLuan(pid: pid, so: so))
        } catch {
            if loi == nil { loi = CTW.loi(error) }
        }
    }

    /// PATCH một nhóm trường. `null` gửi bằng `NSNull()`.
    func sua(_ truong: [String: Any]) async {
        guard let t = the else { return }
        var than = truong
        if let v = t.version { than["version"] = v }
        dangGui = true
        defer { dangGui = false }
        do {
            the = try await APIClient.shared.request(.workSuaThe(pid: pid, so: so, than: than))
            loi = nil
        } catch {
            loi = CTW.loi(error)
            if CTW.laXungDot(error) {
                if let moi: CTWIssueDetail = try? await APIClient.shared.request(.workThe(pid: pid, so: so)) {
                    the = moi
                }
            }
        }
    }

    func chuyenTrangThai(_ statusId: Int) async {
        guard let t = the, t.statusId != statusId else { return }
        var than: [String: Any] = ["statusId": statusId]
        if let v = t.version { than["version"] = v }
        dangGui = true
        defer { dangGui = false }
        do {
            try await APIClient.shared.send(.workChuyenThe(pid: pid, so: so, than: than))
            the = try await APIClient.shared.request(.workThe(pid: pid, so: so))
            loi = nil
        } catch {
            loi = CTW.loi(error)
            if CTW.laXungDot(error),
               let moi: CTWIssueDetail = try? await APIClient.shared.request(.workThe(pid: pid, so: so)) {
                the = moi
            }
        }
    }

    func guiBinhLuan(_ chu: String) async -> Bool {
        let s = chu.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return false }
        dangGui = true
        defer { dangGui = false }
        do {
            let c: CTWComment = try await APIClient.shared.request(
                .workThemBinhLuan(pid: pid, so: so, than: ["bodyJson": CTWNode.docTuChu(s)]))
            binhLuan.append(c)
            loi = nil
            return true
        } catch {
            loi = CTW.loi(error)
            return false
        }
    }
}

struct CTWIssueView: View {
    @StateObject private var vm: CTWIssueVM
    @ObservedObject private var kiemDuyet = ModerationStore.shared
    @EnvironmentObject private var appState: AppState

    @State private var dangSuaTieuDe = false
    @State private var tieuDeNhap = ""
    @State private var binhLuanNhap = ""
    @State private var chonNgay = false
    @State private var ngayNhap = Date()
    @State private var hoiChan: CTWUser?

    init(pid: Int, so: Int) {
        _vm = StateObject(wrappedValue: CTWIssueVM(pid: pid, so: so))
    }

    var body: some View {
        Group {
            if let t = vm.the, let cfg = vm.cauHinh {
                noiDung(t, cfg)
            } else if let loi = vm.loi {
                VStack(spacing: Spacing.md) {
                    CTWErrorBanner(text: loi)
                    Button("Try again") { Task { await vm.tai() } }.buttonStyle(.bordered)
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(vm.cauHinh.map { "\($0.key)-\(vm.so)" } ?? "Issue")
        .ctwTieuDeNho()
        .task { if vm.the == nil { await vm.tai() } }
        .confirmationDialog(
            "Block \(hoiChan?.ten ?? "this user")?",
            isPresented: Binding(get: { hoiChan != nil }, set: { if !$0 { hoiChan = nil } }),
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                guard let u = hoiChan else { return }
                Task {
                    do { try await kiemDuyet.block(userId: u.id) } catch { vm.loi = CTW.loi(error) }
                }
            }
        } message: {
            Text("You won't see their comments anywhere in the app.")
        }
    }

    // MARK: Nội dung

    private func noiDung(_ t: CTWIssueDetail, _ cfg: CTWProjectConfig) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let loi = vm.loi {
                    CTWErrorBanner(text: loi) { vm.loi = nil }
                }
                dau(t, cfg)
                truong(t, cfg)
                moTa(t)
                if let con = t.children, !con.isEmpty { theCon(con, cfg) }
                if let lk = t.links, !lk.isEmpty { lienKet(lk, cfg) }
                khoiBinhLuan(cfg)
            }
            .padding(Spacing.md)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .refreshable { await vm.tai() }
        .disabled(vm.dangGui)
        .overlay(alignment: .top) {
            if vm.dangGui { ProgressView().padding(8) }
        }
    }

    private func dau(_ t: CTWIssueDetail, _ cfg: CTWProjectConfig) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let p = t.parent {
                    NavigationLink(value: CTWRoute.the(pid: vm.pid, so: p.number)) {
                        HStack(spacing: 4) {
                            CTWTypeIcon(type: p.typeId.flatMap(cfg.loai), size: 11)
                            Text("\(cfg.key)-\(p.number)").font(.system(size: 12, weight: .medium).monospaced())
                        }
                    }
                    Text("/").foregroundColor(AppColors.textTertiary)
                }
                CTWTypeIcon(type: cfg.loai(t.typeId), size: 13)
                Text("\(cfg.key)-\(t.number)")
                    .font(.system(size: 13, weight: .semibold).monospaced())
                    .foregroundColor(AppColors.textSecondary)
                    .textSelection(.enabled)
                Text(cfg.loai(t.typeId)?.name ?? "")
                    .font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
                Spacer(minLength: 0)
            }

            if dangSuaTieuDe {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Title", text: $tieuDeNhap, axis: .vertical)
                        .font(.system(size: 20, weight: .semibold))
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Cancel") { dangSuaTieuDe = false }
                        Spacer()
                        Button("Save") {
                            let moi = tieuDeNhap.trimmingCharacters(in: .whitespacesAndNewlines)
                            dangSuaTieuDe = false
                            guard !moi.isEmpty, moi != t.title else { return }
                            Task { await vm.sua(["title": String(moi.prefix(255))]) }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(tieuDeNhap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            } else {
                HStack(alignment: .top) {
                    Text(t.title)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if cfg.coTheSua {
                        Button {
                            tieuDeNhap = t.title
                            dangSuaTieuDe = true
                        } label: {
                            Image(systemName: "pencil").frame(width: 32, height: 32)
                        }
                        .accessibilityLabel("Edit title")
                    }
                }
            }
        }
    }

    // MARK: Trường

    private func truong(_ t: CTWIssueDetail, _ cfg: CTWProjectConfig) -> some View {
        VStack(spacing: 0) {
            hangTruong("Status") { menuTrangThai(t, cfg) }
            Divider()
            hangTruong("Assignee") { menuNguoi(t, cfg) }
            Divider()
            hangTruong("Priority") { menuUuTien(t, cfg) }
            Divider()
            hangTruong("Due date") { oNgay(t, cfg) }
            Divider()
            hangTruong("Reporter") {
                HStack(spacing: 6) {
                    CTWAvatar(user: t.reporter, size: 22)
                    Text(t.reporter?.ten ?? "—").font(.system(size: 14)).foregroundColor(AppColors.textPrimary)
                }
            }
            if let sp = t.storyPoints {
                Divider()
                hangTruong("Story points") {
                    Text(sp == sp.rounded() ? String(Int(sp)) : String(format: "%.1f", sp))
                        .font(.system(size: 14)).foregroundColor(AppColors.textPrimary)
                }
            }
            if let nhan = t.labelIds, !nhan.isEmpty {
                Divider()
                hangTruong("Labels") {
                    Text((cfg.labels ?? []).filter { nhan.contains($0.id) }.map(\.name).joined(separator: ", "))
                        .font(.system(size: 14)).foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.trailing)
                }
            }
            Divider()
            hangTruong("Updated") {
                Text(CTW.thoiDiem(t.updatedAt)).font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppColors.backgroundCard))
    }

    private func hangTruong<V: View>(_ ten: String, @ViewBuilder _ gt: () -> V) -> some View {
        HStack(spacing: 12) {
            Text(ten).font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                .frame(width: 96, alignment: .leading)
            Spacer(minLength: 0)
            gt()
        }
        .frame(minHeight: 46)
    }

    @ViewBuilder
    private func menuTrangThai(_ t: CTWIssueDetail, _ cfg: CTWProjectConfig) -> some View {
        let hienTai = cfg.trangThai(t.statusId)
        if cfg.coTheChuyen {
            let dich = cfg.trangThaiDich(loai: t.typeId, tu: t.statusId)
            Menu {
                ForEach(dich) { s in
                    Button {
                        Task { await vm.chuyenTrangThai(s.id) }
                    } label: {
                        if s.id == t.statusId { Label(s.name, systemImage: "checkmark") } else { Text(s.name) }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    CTWStatusChip(status: hienTai)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 10))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .accessibilityLabel("Status: \(hienTai?.name ?? "")")
        } else {
            CTWStatusChip(status: hienTai)
        }
    }

    @ViewBuilder
    private func menuNguoi(_ t: CTWIssueDetail, _ cfg: CTWProjectConfig) -> some View {
        let nhan = HStack(spacing: 6) {
            CTWAvatar(user: t.assignee, size: 22)
            Text(t.assignee?.ten ?? "Unassigned")
                .font(.system(size: 14))
                .foregroundColor(t.assignee == nil ? AppColors.textSecondary : AppColors.textPrimary)
                .lineLimit(1)
        }
        if cfg.coTheSua {
            Menu {
                if let toi = appState.currentUser?.id, cfg.nguoiGiaoDuoc.contains(where: { $0.id == toi }),
                   t.assigneeId != toi {
                    Button { Task { await vm.sua(["assigneeId": toi]) } } label: {
                        Label("Assign to me", systemImage: "person.fill.checkmark")
                    }
                }
                Button { Task { await vm.sua(["assigneeId": NSNull()]) } } label: {
                    if t.assigneeId == nil { Label("Unassigned", systemImage: "checkmark") } else { Text("Unassigned") }
                }
                Divider()
                ForEach(cfg.nguoiGiaoDuoc) { u in
                    Button { Task { await vm.sua(["assigneeId": u.id]) } } label: {
                        if u.id == t.assigneeId { Label(u.ten, systemImage: "checkmark") } else { Text(u.ten) }
                    }
                }
            } label: { nhan }
        } else {
            nhan
        }
    }

    @ViewBuilder
    private func menuUuTien(_ t: CTWIssueDetail, _ cfg: CTWProjectConfig) -> some View {
        let p = CTW.uuTien(t.priority)
        let nhan = HStack(spacing: 6) {
            CTWPriorityIcon(priority: t.priority)
            Text(p.ten).font(.system(size: 14)).foregroundColor(AppColors.textPrimary)
        }
        if cfg.coTheSua {
            Menu {
                ForEach(CTW.doUuTien, id: \.so) { m in
                    Button { Task { await vm.sua(["priority": m.so]) } } label: {
                        Label(m.ten, systemImage: m.so == p.so ? "checkmark" : m.bieuTuong)
                    }
                }
            } label: { nhan }
        } else {
            nhan
        }
    }

    @ViewBuilder
    private func oNgay(_ t: CTWIssueDetail, _ cfg: CTWProjectConfig) -> some View {
        let chu = CTW.ngayNgan(t.dueDate)
        let tre = t.resolvedAt == nil && CTW.quaHan(t.dueDate)
        if cfg.coTheSua {
            if chonNgay {
                HStack(spacing: 8) {
                    DatePicker("", selection: $ngayNhap, displayedComponents: .date)
                        .labelsHidden()
                    Button("Save") {
                        chonNgay = false
                        Task { await vm.sua(["dueDate": CTW.chuoiNgay(ngayNhap)]) }
                    }
                    .buttonStyle(.borderedProminent)
                    Button { chonNgay = false } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Cancel")
                }
            } else {
                Menu {
                    Button { batChonNgay(t) } label: { Label(chu == nil ? "Set due date" : "Change due date", systemImage: "calendar") }
                    if chu != nil {
                        Button(role: .destructive) { Task { await vm.sua(["dueDate": NSNull()]) } } label: {
                            Label("Remove due date", systemImage: "calendar.badge.minus")
                        }
                    }
                } label: {
                    Text(chu ?? "None")
                        .font(.system(size: 14, weight: tre ? .semibold : .regular))
                        .foregroundColor(chu == nil ? AppColors.textSecondary : (tre ? AppColors.error : AppColors.textPrimary))
                }
            }
        } else {
            Text(chu ?? "None")
                .font(.system(size: 14))
                .foregroundColor(tre ? AppColors.error : AppColors.textPrimary)
        }
    }

    private func batChonNgay(_ t: CTWIssueDetail) {
        // Ngày lưu dạng YYYY-MM-DD không múi giờ — dựng lại theo lịch MÁY
        // để DatePicker không lệch một ngày ở UTC+7.
        if let d = CTW.ngay(t.dueDate) {
            let p = d.split(separator: "-").compactMap { Int($0) }
            if p.count == 3, let n = Calendar.current.date(from: DateComponents(year: p[0], month: p[1], day: p[2])) {
                ngayNhap = n
            }
        } else {
            ngayNhap = Date()
        }
        chonNgay = true
    }

    // MARK: Mô tả, thẻ con, liên kết

    private func tieuDeKhoi(_ s: String) -> some View {
        Text(s).font(.system(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
    }

    private func moTa(_ t: CTWIssueDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            tieuDeKhoi("Description")
            let chu = t.descriptionJson?.chuTron ?? ""
            Text(chu.isEmpty ? "No description." : chu)
                .font(.system(size: 14))
                .foregroundColor(chu.isEmpty ? AppColors.textTertiary : AppColors.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppColors.backgroundCard))
        }
    }

    private func theCon(_ con: [CTWIssueRef], _ cfg: CTWProjectConfig) -> some View {
        let xong = con.filter { $0.statusId.flatMap(cfg.trangThai)?.category == "DONE" }.count
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                tieuDeKhoi("Sub-tasks")
                Text("\(xong)/\(con.count) done").font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
            }
            VStack(spacing: 0) {
                ForEach(con) { c in
                    NavigationLink(value: CTWRoute.the(pid: vm.pid, so: c.number)) {
                        HStack(spacing: 8) {
                            CTWTypeIcon(type: c.typeId.flatMap(cfg.loai), size: 12)
                            Text("\(cfg.key)-\(c.number)").font(.system(size: 12, weight: .medium).monospaced())
                                .foregroundColor(AppColors.textSecondary)
                            Text(c.title).font(.system(size: 14)).foregroundColor(AppColors.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            CTWStatusChip(status: c.statusId.flatMap(cfg.trangThai))
                            if c.assigneeId != nil { CTWAvatar(user: cfg.thanhVien(c.assigneeId), size: 20) }
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if c.id != con.last?.id { Divider() }
                }
            }
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppColors.backgroundCard))
        }
    }

    private func lienKet(_ lk: [CTWIssueLink], _ cfg: CTWProjectConfig) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            tieuDeKhoi("Linked issues")
            VStack(alignment: .leading, spacing: 8) {
                ForEach(lk) { l in
                    HStack(spacing: 8) {
                        Text(tenLienKet(l)).font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                            .frame(width: 110, alignment: .leading)
                        Text(l.issue?.key ?? "").font(.system(size: 12, weight: .medium).monospaced())
                            .foregroundColor(AppColors.textSecondary)
                        Text(l.issue?.title ?? "").font(.system(size: 14)).foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppColors.backgroundCard))
        }
    }

    private func tenLienKet(_ l: CTWIssueLink) -> String {
        let ra = l.direction != "inward"
        switch l.type {
        case "BLOCKS": return ra ? "blocks" : "is blocked by"
        case "DUPLICATES": return ra ? "duplicates" : "is duplicated by"
        case "CLONES": return ra ? "clones" : "is cloned by"
        case "TESTS": return ra ? "tests" : "is tested by"
        default: return "relates to"
        }
    }

    // MARK: Bình luận

    private func khoiBinhLuan(_ cfg: CTWProjectConfig) -> some View {
        // Bình luận của người đã chặn thì ẩn (Guideline 1.2 — chặn phải có tác dụng ngay).
        let ds = vm.binhLuan.filter { c in
            guard let a = c.author?.id else { return true }
            return !kiemDuyet.blockedUserIds.contains(a)
        }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                tieuDeKhoi("Comments")
                Text("\(ds.count)").font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
            }
            if ds.isEmpty {
                Text("No comments yet.").font(.system(size: 13)).foregroundColor(AppColors.textTertiary)
            }
            ForEach(ds) { c in hangBinhLuan(c) }

            if cfg.coTheBinhLuan {
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Add a comment…", text: $binhLuanNhap, axis: .vertical)
                        .lineLimit(1...6)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        let s = binhLuanNhap
                        Task { if await vm.guiBinhLuan(s) { binhLuanNhap = "" } }
                    } label: {
                        Image(systemName: "paperplane.fill").frame(width: 36, height: 36)
                    }
                    .disabled(binhLuanNhap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.dangGui)
                    .accessibilityLabel("Send comment")
                }
                .padding(.top, 4)
            } else {
                Text("You can view this issue but not comment on it.")
                    .font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
            }
        }
    }

    private func hangBinhLuan(_ c: CTWComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if c.isAi == true {
                Image(systemName: "sparkles").font(.system(size: 13)).foregroundColor(.white)
                    .frame(width: 28, height: 28).background(Circle().fill(AppColors.primary))
            } else {
                CTWAvatar(user: c.author, size: 28)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(c.isAi == true ? "CT Work AI" : (c.author?.ten ?? "Someone"))
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    Text(CTW.thoiDiem(c.createdAt)).font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                    if c.editedAt != nil {
                        Text("(edited)").font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                    }
                }
                Text(c.bodyJson?.chuTron ?? "")
                    .font(.system(size: 14)).foregroundColor(AppColors.textPrimary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppColors.backgroundCard))
        .contextMenu {
            if let a = c.author, c.isAi != true, a.id != appState.currentUser?.id {
                Button(role: .destructive) { hoiChan = a } label: {
                    Label("Block \(a.ten)", systemImage: "hand.raised")
                }
            }
        }
    }
}
