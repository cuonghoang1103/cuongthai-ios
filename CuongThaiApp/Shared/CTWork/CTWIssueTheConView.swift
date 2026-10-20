import SwiftUI

// MARK: - CT Work — THẺ CON (sub-task / thẻ trong epic) + LIÊN KẾT thẻ (20/10/2026)
//
// Như web (`IssueDetail.tsx → Subtasks`, `Links`):
//   · Thêm nhanh sub-task ngay tại chỗ (Enter), "Details…" mở hộp tạo đầy đủ có sẵn thẻ cha.
//     Chỉ khi: thẻ không phải epic/sub-task, dự án có loại sub-task, quyền sửa + tạo thẻ.
//   · Mỗi dòng: mở · đổi trạng thái (đúng luồng chuyển của loại thẻ) · gỡ khỏi epic / xoá sub-task (hỏi lại).
//   · Liên kết: thêm (chọn kiểu + tìm thẻ, hoặc gõ mã thẻ của dự án khác) · gỡ.

struct CTWIssueTheConView: View {
    @ObservedObject var vm: CTWIssueVM
    let t: CTWIssueDetail
    let cfg: CTWProjectConfig
    /// "Details…" — mở hộp tạo thẻ đầy đủ (thẻ cha điền sẵn).
    let moTaoChiTiet: () -> Void
    @State private var nhanh = ""
    @State private var dangThem = false
    @State private var hoiXoa: CTWIssueRef?
    @FocusState private var oNhanh: Bool

    private var loai: CTWIssueType? { cfg.loai(t.typeId) }
    private var laEpic: Bool { loai?.level == 1 }
    private var loaiCon: CTWIssueType? { cfg.dsLoai.first { $0.level == -1 } }
    private var themDuoc: Bool { !laEpic && loaiCon != nil && cfg.coTheSua && cfg.coTheTao }

    var body: some View {
        let con = t.children ?? []
        if loai?.level != -1 && (!con.isEmpty || themDuoc) {
            noiDung(con)
        }
    }

    private func noiDung(_ con: [CTWIssueRef]) -> some View {
        let xong = con.filter { $0.statusId.flatMap(cfg.trangThai)?.category == "DONE" }.count
        let phanTram = con.isEmpty ? 0 : Int((Double(xong) / Double(con.count) * 100).rounded())
        return VStack(alignment: .leading, spacing: 8) {
            CTWSectionHeader("checklist", laEpic ? String(localized: "Issues in this epic") : String(localized: "Sub-tasks"),
                             count: con.isEmpty ? nil : "\(xong)/\(con.count)",
                             trailing: themDuoc ? AnyView(
                                Button(action: moTaoChiTiet) {
                                    Label("Details…", systemImage: "plus").font(.ctw(size: 13, weight: .semibold))
                                        .frame(minHeight: 32)
                                }
                                .accessibilityHint(Text("Create a sub-task with all fields"))
                             ) : nil)
            if !con.isEmpty {
                HStack(spacing: 8) {
                    ProgressView(value: Double(xong), total: Double(max(con.count, 1)))
                        .tint(AppColors.success)
                    Text(verbatim: "\(phanTram)%").font(.ctw(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundColor(AppColors.textTertiary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(xong) of \(con.count) done"))
            }
            VStack(spacing: 0) {
                ForEach(con) { c in
                    hang(c)
                    if c.id != con.last?.id || themDuoc { Divider() }
                }
                if themDuoc { oThemNhanh }
            }
            .padding(.horizontal, 14)
            .ctwThe(12)
        }
        .confirmationDialog(
            hoiXoa.map { String(localized: "Delete \(cfg.key)-\($0.number)?") } ?? "",
            isPresented: Binding(get: { hoiXoa != nil }, set: { if !$0 { hoiXoa = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete sub-task", role: .destructive) {
                guard let c = hoiXoa else { return }
                Task { _ = await vm.goi(CTWAPI.xoaThe(pid: vm.pid, so: c.number)) }
            }
        } message: {
            Text("It moves to the project's trash. Admins can restore it from the web.")
        }
    }

    private func hang(_ c: CTWIssueRef) -> some View {
        let st = c.statusId.flatMap(cfg.trangThai)
        let xong = st?.category == "DONE"
        return NavigationLink(value: CTWRoute.the(pid: vm.pid, so: c.number)) {
            HStack(spacing: 8) {
                Image(systemName: xong ? "checkmark.square.fill" : "square")
                    .foregroundColor(xong ? AppColors.success : (st?.category == "IN_PROGRESS" ? AppColors.primary : AppColors.textTertiary))
                Text(verbatim: "\(cfg.key)-\(c.number)").font(.ctw(size: 12, weight: .medium).monospaced())
                    .foregroundColor(AppColors.textSecondary)
                Text(verbatim: c.title).font(.ctw(size: 14))
                    .foregroundColor(xong ? AppColors.textSecondary : AppColors.textPrimary)
                    .strikethrough(xong)
                    .lineLimit(1)
                Spacer(minLength: 0)
                CTWStatusChip(status: st)
                if c.assigneeId != nil { CTWAvatar(user: cfg.thanhVien(c.assigneeId), size: 20) }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu { menuDong(c) }
    }

    @ViewBuilder
    private func menuDong(_ c: CTWIssueRef) -> some View {
        if cfg.coTheChuyen, let tid = c.typeId, let sid = c.statusId {
            Menu {
                ForEach(cfg.trangThaiDich(loai: tid, tu: sid).filter { $0.id != sid }) { s in
                    Button(s.name) {
                        Task { _ = await vm.goi(.workChuyenThe(pid: vm.pid, so: c.number, than: ["statusId": s.id])) }
                    }
                }
            } label: { Label("Change status", systemImage: "arrow.triangle.swap") }
        }
        Button { CTW.chepVaoBoNho("\(cfg.key)-\(c.number)") } label: { Label("Copy key", systemImage: "number") }
        if cfg.coTheSua && laEpic {
            Button(role: .destructive) {
                Task { _ = await vm.goi(CTWAPI.suaThe(pid: vm.pid, so: c.number, ["parentId": NSNull()])) }
            } label: { Label("Remove from epic", systemImage: "minus.circle") }
        }
        if !laEpic && cfg.permissions?.deleteIssues == true {
            Button(role: .destructive) { hoiXoa = c } label: { Label("Delete sub-task", systemImage: "trash") }
        }
    }

    private var oThemNhanh: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus").font(.ctw(size: 13, weight: .semibold)).foregroundColor(AppColors.textTertiary)
            TextField("Add a sub-task…", text: $nhanh)
                .font(.ctw(size: 14))
                .focused($oNhanh)
                .submitLabel(.done)
                .onSubmit { Task { await themNhanh() } }
                .disabled(dangThem)
                .accessibilityIdentifier("ctw.theCon.nhanh")
            if dangThem {
                ProgressView()
            } else if !nhanh.trimmingCharacters(in: .whitespaces).isEmpty {
                Button("Add") { Task { await themNhanh() } }
                    .buttonStyle(.borderedProminent).controlSize(.small)
            }
        }
        .frame(minHeight: 46)
        #if DEBUG
        .task {
            if ProcessInfo.processInfo.environment["CT_XEM_MAN"]?.lowercased() == "the:thecon" {
                try? await Task.sleep(nanoseconds: 900_000_000)
                nhanh = "Handle notification tap while app is locked"
            }
        }
        #endif
    }

    private func themNhanh() async {
        let tieuDe = nhanh.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tieuDe.isEmpty, let loaiCon, !dangThem else { return }
        dangThem = true
        defer { dangThem = false }
        if await vm.goi(CTWAPI.taoThe(pid: vm.pid, ["typeId": loaiCon.id, "title": String(tieuDe.prefix(255)), "parentId": t.id])) {
            nhanh = ""
            oNhanh = true
        }
    }
}

// MARK: - Liên kết thẻ

struct CTWIssueLienKetView: View {
    @ObservedObject var vm: CTWIssueVM
    let t: CTWIssueDetail
    let cfg: CTWProjectConfig
    @State private var dangThem = false

    var body: some View {
        let lk = t.links ?? []
        VStack(alignment: .leading, spacing: 8) {
            CTWSectionHeader("link", String(localized: "Linked issues"), count: lk.isEmpty ? nil : "\(lk.count)",
                             trailing: cfg.coTheSua ? AnyView(
                                Button { dangThem = true } label: {
                                    Label("Link issue", systemImage: "plus").font(.ctw(size: 13, weight: .semibold)).frame(minHeight: 32)
                                }
                                .accessibilityIdentifier("ctw.lienKet.them")
                             ) : nil)
            if lk.isEmpty {
                Text(cfg.coTheSua ? "No linked issues. Tap Link issue to add one." : "No linked issues.")
                    .font(.ctw(size: 13)).foregroundColor(AppColors.textTertiary)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(lk) { l in
                        hang(l)
                        if l.id != lk.last?.id { Divider() }
                    }
                }
                .padding(.horizontal, 14)
                .ctwThe(12)
            }
        }
        .sheet(isPresented: $dangThem) {
            CTWThemLienKetView(pid: vm.pid, cfg: cfg, loaiTru: [t.id]) { kieu, ma in
                await vm.goi(CTWAPI.themLienKet(pid: vm.pid, so: vm.so, kieu: kieu.ma, maDich: ma))
            } themNguoc: { kieu, so in
                // "is blocked by X" = X blocks thẻ này ⇒ thêm từ phía X.
                await vm.goi(CTWAPI.themLienKet(pid: vm.pid, so: so, kieu: kieu.ma, maDich: "\(cfg.key)-\(vm.so)"))
            }
        }
        #if DEBUG
        .task {
            if ProcessInfo.processInfo.environment["CT_XEM_MAN"]?.lowercased() == "the:lienket" {
                try? await Task.sleep(nanoseconds: 900_000_000)
                dangThem = true
            }
        }
        #endif
    }

    private func hang(_ l: CTWIssueLink) -> some View {
        let ma = l.issue?.key ?? ""
        let cungDuAn = ma.hasPrefix(cfg.key + "-")
        let noiDung = HStack(spacing: 8) {
            Text(verbatim: Self.tenKieu(l)).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                .frame(width: 92, alignment: .leading)
            Text(verbatim: ma).font(.ctw(size: 12, weight: .medium).monospaced()).foregroundColor(AppColors.textSecondary)
            Text(verbatim: l.issue?.title ?? "").font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary).lineLimit(1)
            Spacer(minLength: 0)
            if cungDuAn, let s = l.issue?.statusId { CTWStatusChip(status: cfg.trangThai(s)) }
        }
        .padding(.vertical, 9)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        return Group {
            if let i = l.issue, cungDuAn {
                NavigationLink(value: CTWRoute.the(pid: vm.pid, so: i.number)) { noiDung }.buttonStyle(.plain)
            } else {
                noiDung
            }
        }
        .contextMenu {
            Button { CTW.chepVaoBoNho(ma) } label: { Label("Copy key", systemImage: "number") }
            if cfg.coTheSua {
                Button(role: .destructive) {
                    Task { _ = await vm.goi(CTWAPI.xoaLienKet(pid: vm.pid, so: vm.so, lid: l.id)) }
                } label: { Label("Remove link", systemImage: "xmark.circle") }
            }
        }
        .accessibilityAction(named: Text("Remove link")) {
            guard cfg.coTheSua else { return }
            Task { _ = await vm.goi(CTWAPI.xoaLienKet(pid: vm.pid, so: vm.so, lid: l.id)) }
        }
    }

    static func tenKieu(_ l: CTWIssueLink) -> String {
        let ra = l.direction != "inward"
        switch l.type {
        case "BLOCKS": return ra ? String(localized: "blocks") : String(localized: "is blocked by")
        case "DUPLICATES": return ra ? String(localized: "duplicates") : String(localized: "is duplicated by")
        case "CLONES": return ra ? String(localized: "clones") : String(localized: "is cloned by")
        case "TESTS": return ra ? String(localized: "tests") : String(localized: "is tested by")
        default: return String(localized: "relates to")
        }
    }
}

/// Tấm phủ "Link issue": chọn kiểu + tìm thẻ trong dự án (hoặc gõ mã thẻ dự án khác, vd OPS-7).
struct CTWThemLienKetView: View {
    let pid: Int
    let cfg: CTWProjectConfig
    var loaiTru: Set<Int> = []
    let them: (CTWLinkKieu, String) async -> Bool
    let themNguoc: (CTWLinkKieu, Int) async -> Bool
    @Environment(\.dismiss) private var dong
    @State private var kieu: CTWLinkKieu = .relates
    @State private var tim = ""
    @State private var ds: [CTWIssueCard]?
    @State private var dangLuu = false

    /// Gõ đúng một mã thẻ (`ABC-12`) ⇒ cho liên kết thẳng (kể cả dự án khác trong không gian).
    private var maGo: String? {
        let s = tim.trimmingCharacters(in: .whitespaces).uppercased()
        return s.range(of: #"^[A-Z][A-Z0-9]{0,9}-\d{1,7}$"#, options: .regularExpression) != nil ? s : nil
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("This issue", selection: $kieu) {
                        ForEach(CTWLinkKieu.tatCa) { k in Text(verbatim: k.ten).tag(k) }
                    }
                }
                if let ma = maGo, kieu != .blockedBy, !ma.hasPrefix(cfg.key + "-") {
                    Section {
                        Button { Task { await chon(ma: ma, so: Int(ma.split(separator: "-").last ?? "")) } } label: {
                            Label(String(localized: "Link to \(ma)"), systemImage: "link")
                        }
                    }
                }
                Section {
                    if let ds {
                        let loc = ds.filter { !loaiTru.contains($0.id) }
                        if loc.isEmpty { Text("No matches").foregroundColor(AppColors.textSecondary) }
                        ForEach(loc) { c in
                            Button { Task { await chon(ma: "\(cfg.key)-\(c.number)", so: c.number) } } label: {
                                HStack(spacing: 8) {
                                    CTWTypeIcon(type: cfg.loai(c.typeId), size: 12)
                                    Text(verbatim: "\(cfg.key)-\(c.number)").font(.ctw(size: 12, weight: .medium).monospaced())
                                        .foregroundColor(AppColors.textSecondary)
                                    Text(verbatim: c.title).foregroundColor(AppColors.textPrimary).lineLimit(2)
                                    Spacer(minLength: 0)
                                    CTWStatusChip(status: cfg.trangThai(c.statusId))
                                }
                                .frame(minHeight: 36)
                                .contentShape(Rectangle())
                            }
                        }
                    } else {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                } header: {
                    Text("Issues in \(cfg.key)")
                }
            }
            .searchable(text: $tim, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search or type a key, e.g. \(cfg.key)-12"))
            .navigationTitle("Link issue")
            .ctwTieuDeNho()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                if dangLuu { ToolbarItem(placement: .confirmationAction) { ProgressView() } }
            }
            .task(id: tim) {
                if !tim.isEmpty { try? await Task.sleep(nanoseconds: 300_000_000) }
                guard !Task.isCancelled else { return }
                let r: CTWIssueList? = try? await APIClient.shared.request(CTWAPI.dsTheLoc(pid: pid, q: tim, gomXong: true, limit: 50))
                ds = r?.items ?? []
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func chon(ma: String, so: Int?) async {
        dangLuu = true
        defer { dangLuu = false }
        let xong: Bool
        if kieu == .blockedBy {
            // Chỉ thẻ CÙNG dự án mới thêm ngược được (POST trên thẻ kia).
            guard ma.hasPrefix(cfg.key + "-"), let so else { return }
            xong = await themNguoc(kieu, so)
        } else {
            xong = await them(kieu, ma)
        }
        if xong { dong() }
    }
}
