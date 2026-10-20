import SwiftUI

// MARK: - Backlog / Danh sách có lọc
//
// Hai chế độ:
//   · Backlog — `GET /projects/:pid/backlog`: sprint đang mở (ACTIVE trước) +
//     các thẻ chưa vào sprint. Máy chủ trả MỘT danh sách phẳng, app nhóm theo
//     `sprintId` (nil = backlog).
//   · All issues — `GET /projects/:pid/issues` với bộ lọc của máy chủ
//     (người làm, trạng thái, loại, nhãn, sprint, chữ). Độ ưu tiên máy chủ
//     KHÔNG lọc được ⇒ lọc ở máy trên kết quả trả về.

@MainActor
final class BacklogVM: ObservableObject {
    let pid: Int
    @Published var cauHinh: CTWProjectConfig?
    @Published var backlog: CTWBacklog?
    @Published var ds: [CTWIssueCard] = []
    @Published var tong = 0
    @Published var conTiep: String?
    @Published var loi: String?
    @Published var dangTai = false
    @Published var loc = CTWAPI.BoLoc()
    @Published var uuTien: Set<Int> = []

    init(pid: Int) { self.pid = pid }

    func taiCauHinh() async {
        if cauHinh != nil { return }
        do { cauHinh = try await APIClient.shared.request(.workDuAn(pid: pid)) } catch { loi = CTW.loi(error) }
    }

    func taiBacklog() async {
        await taiCauHinh()
        dangTai = true
        defer { dangTai = false }
        do {
            backlog = try await APIClient.shared.request(CTWAPI.backlog(pid: pid))
            loi = nil
        } catch { loi = CTW.loi(error) }
    }

    func taiDanhSach() async {
        await taiCauHinh()
        dangTai = true
        defer { dangTai = false }
        do {
            let r: CTWIssueList = try await APIClient.shared.request(CTWAPI.dsThe(pid: pid, loc: loc, limit: 100))
            ds = r.items ?? []
            tong = r.total ?? ds.count
            conTiep = r.nextCursor
            loi = nil
        } catch { loi = CTW.loi(error) }
    }

    func taiThem() async {
        guard let c = conTiep, !dangTai else { return }
        dangTai = true
        defer { dangTai = false }
        do {
            let r: CTWIssueList = try await APIClient.shared.request(CTWAPI.dsThe(pid: pid, loc: loc, cursor: c, limit: 100))
            let co = Set(ds.map(\.id))
            ds += (r.items ?? []).filter { !co.contains($0.id) }
            conTiep = r.nextCursor
        } catch { loi = CTW.loi(error) }
    }

    var dsDaLoc: [CTWIssueCard] {
        uuTien.isEmpty ? ds : ds.filter { uuTien.contains($0.priority ?? 3) }
    }

    var soBoLoc: Int {
        [loc.assignee.isEmpty, loc.status.isEmpty, loc.type.isEmpty, loc.label.isEmpty, loc.sprint == nil, uuTien.isEmpty, !loc.includeDone]
            .filter { !$0 }.count
    }
}

struct BacklogCTW: View {
    let pid: Int
    @StateObject private var vm: BacklogVM
    @EnvironmentObject private var app: AppState
    @State private var cheDo: CheDo = .backlog
    @State private var moLoc = false
    @State private var moTao = false
    @State private var tim = ""

    enum CheDo: String, CaseIterable, Identifiable {
        case backlog = "Sprints", tatCa = "All issues"
        var id: String { rawValue }
    }

    /// Nhúng trong trang dự án (công tắc Board · Backlog · List ở trên đã chọn chế độ) ⇒ ẩn công tắc Sprints/All riêng.
    private let nhung: Bool

    init(pid: Int, cheDoDau: CheDo = .backlog, nhung: Bool = false) {
        self.pid = pid
        self.nhung = nhung
        _vm = StateObject(wrappedValue: BacklogVM(pid: pid))
        _cheDo = State(initialValue: cheDoDau)
    }

    var body: some View {
        List {
            Section {
                if !nhung {
                    Picker("Mode", selection: $cheDo) {
                        ForEach(CheDo.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
                }
                if let loi = vm.loi {
                    CTWErrorBanner(text: loi) { vm.loi = nil }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
            }
            if let cfg = vm.cauHinh {
                switch cheDo {
                case .backlog: phanBacklog(cfg)
                case .tatCa: phanTatCa(cfg)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundPrimary)
        .overlay { if vm.dangTai && vm.cauHinh == nil { CTWKhungTai(soHang: 6) } }
        .searchable(text: $tim, placement: .toolbar, prompt: "Search title or key")
        .onSubmit(of: .search) { apDungTim() }
        .onChange(of: tim) { _, moi in if moi.isEmpty { apDungTim() } }
        .navigationTitle(vm.cauHinh?.name ?? "Backlog")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if cheDo == .tatCa {
                    Button { moLoc = true } label: {
                        Image(systemName: vm.soBoLoc > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel(vm.soBoLoc > 0 ? "Filters, \(vm.soBoLoc) active" : "Filters")
                }
                if vm.cauHinh?.coTheTao == true {
                    Button { moTao = true } label: { Image(systemName: "plus") }.accessibilityLabel("Create issue")
                }
            }
        }
        .sheet(isPresented: $moLoc) {
            if let cfg = vm.cauHinh {
                BoLocCTW(cauHinh: cfg, loc: vm.loc, uuTien: vm.uuTien, toi: app.currentUser?.id) { l, u in
                    vm.loc = l
                    vm.uuTien = u
                    Task { await vm.taiDanhSach() }
                }
            }
        }
        // Tấm phủ thứ hai gắn trên thanh chọn (không cùng chỗ với `moLoc`) — bẫy C5.
        .background(EmptyView().sheet(isPresented: $moTao) {
            if let cfg = vm.cauHinh {
                CTWCreateIssueView(cauHinh: cfg, sprintId: nil) { _ in
                    Task { cheDo == .backlog ? await vm.taiBacklog() : await vm.taiDanhSach() }
                }
            }
        })
        .refreshable { cheDo == .backlog ? await vm.taiBacklog() : await vm.taiDanhSach() }
        #if DEBUG
        .onAppear { if XemThuCTW.man?.lowercased() == "list" { cheDo = .tatCa } }
        #endif
        .task(id: cheDo) {
            switch cheDo {
            case .backlog: if vm.backlog == nil { await vm.taiBacklog() }
            case .tatCa: if vm.ds.isEmpty { await vm.taiDanhSach() }
            }
        }
    }

    private func apDungTim() {
        vm.loc.q = tim
        if cheDo == .backlog && !nhung { cheDo = .tatCa }
        Task { await vm.taiDanhSach() }
    }

    // MARK: Backlog

    @ViewBuilder
    private func phanBacklog(_ cfg: CTWProjectConfig) -> some View {
        // Nhúng trong trang dự án: ô tìm lọc NGAY trên backlog (không nhảy sang List).
        let q = nhung ? tim.trimmingCharacters(in: .whitespaces) : ""
        let the = (vm.backlog?.issues ?? []).filter {
            q.isEmpty || $0.title.localizedCaseInsensitiveContains(q) || "\(cfg.key)-\($0.number)".localizedCaseInsensitiveContains(q)
        }
        let sprints = vm.backlog?.sprints ?? []
        ForEach(sprints) { s in
            let ds = the.filter { $0.sprintId == s.id }
            Section {
                if ds.isEmpty { Text("No issues in this sprint").foregroundColor(AppColors.textTertiary).font(.ctw(size: 13)) }
                ForEach(ds) { t in hang(t, cfg) }
            } header: {
                dauSprint(s, ds: ds, cfg: cfg)
            }
        }
        let tonDong = the.filter { $0.sprintId == nil }
        Section {
            if tonDong.isEmpty && vm.backlog != nil {
                Text("The backlog is empty").foregroundColor(AppColors.textTertiary).font(.ctw(size: 13))
            }
            ForEach(tonDong) { t in hang(t, cfg) }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "tray.full")
                Text("Backlog")
                Text("\(tonDong.count)").foregroundColor(AppColors.textTertiary)
            }
            .font(.ctw(size: 13, weight: .semibold))
        } footer: {
            if vm.backlog?.truncated == true {
                Text("Showing the first \(the.count) of \(vm.backlog?.total ?? the.count) issues.")
            }
        }
    }

    private func dauSprint(_ s: CTWSprint, ds: [CTWIssueCard], cfg: CTWProjectConfig) -> some View {
        let xong = ds.filter { cfg.trangThai($0.statusId)?.category == "DONE" }.count
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: s.state == "ACTIVE" ? "flag.fill" : "flag")
                    .foregroundColor(s.state == "ACTIVE" ? AppColors.primary : AppColors.textSecondary)
                Text(s.name)
                if s.state == "ACTIVE" {
                    Text("ACTIVE").font(.ctw(size: 10, weight: .bold)).foregroundColor(AppColors.primary)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule().fill(AppColors.primary.opacity(0.12)))
                }
                Spacer()
                Text("\(xong)/\(ds.count) done").foregroundColor(AppColors.textTertiary)
            }
            .font(.ctw(size: 13, weight: .semibold))
            if let a = CTW.ngayNgan(s.startAt), let b = CTW.ngayNgan(s.endAt) {
                Text("\(a) – \(b)").font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary).textCase(nil)
            }
            if ds.count > 0 {
                ProgressView(value: Double(xong), total: Double(ds.count)).tint(AppColors.success)
            }
        }
    }

    // MARK: Tất cả

    @ViewBuilder
    private func phanTatCa(_ cfg: CTWProjectConfig) -> some View {
        let ds = vm.dsDaLoc
        Section {
            if !vm.dangTai && ds.isEmpty {
                Text(vm.soBoLoc > 0 || !vm.loc.q.isEmpty ? "No issues match these filters." : "No open issues.")
                    .foregroundColor(AppColors.textSecondary)
            }
            ForEach(ds) { t in hang(t, cfg) }
            if vm.conTiep != nil {
                Button("Load more") { Task { await vm.taiThem() } }
                    .frame(maxWidth: .infinity)
            }
        } header: {
            HStack {
                Text(vm.loc.includeDone ? "All issues" : "Open issues")
                Spacer()
                Text("\(vm.tong)").foregroundColor(AppColors.textTertiary)
            }
            .font(.ctw(size: 13, weight: .semibold))
        }
    }

    // MARK: Hàng

    private func hang(_ t: CTWIssueCard, _ cfg: CTWProjectConfig) -> some View {
        NavigationLink(value: CTWRoute.the(pid: pid, so: t.number)) {
            HStack(spacing: 10) {
                CTWTypeIcon(type: cfg.loai(t.typeId), size: 14)
                VStack(alignment: .leading, spacing: 4) {
                    Text(t.title).font(.ctw(size: 15)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                    // Chật (máy nhỏ / chữ lớn) ⇒ hạn xuống dòng thay vì bị cắt.
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 7) {
                            siHang(t, cfg)
                            CTWDueChip(dueDate: t.dueDate, xong: t.resolvedAt != nil)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 7) { siHang(t, cfg) }
                            CTWDueChip(dueDate: t.dueDate, xong: t.resolvedAt != nil)
                        }
                    }
                }
                Spacer(minLength: 0)
                if let sp = t.storyPoints { CTWPointsBadge(diem: sp) }
                if t.assigneeId != nil {
                    CTWAvatar(user: cfg.thanhVien(t.assigneeId) ?? CTWUser(id: t.assigneeId ?? 0), size: 24)
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder private func siHang(_ t: CTWIssueCard, _ cfg: CTWProjectConfig) -> some View {
        Text("\(cfg.key)-\(t.number)").font(.ctw(size: 12, weight: .medium).monospaced())
            .foregroundColor(t.resolvedAt != nil ? AppColors.textTertiary : AppColors.primary)
            .strikethrough(t.resolvedAt != nil)
            .fixedSize()
        CTWPriorityIcon(priority: t.priority)
        if let s = cfg.trangThai(t.statusId) {
            CTWStatusChip(status: s).fixedSize()
        }
    }
}

// MARK: - Bảng lọc

struct BoLocCTW: View {
    let cauHinh: CTWProjectConfig
    @State var loc: CTWAPI.BoLoc
    @State var uuTien: Set<Int>
    let toi: Int?
    let apDung: (CTWAPI.BoLoc, Set<Int>) -> Void
    @Environment(\.dismiss) private var dong

    var body: some View {
        NavigationStack {
            Form {
                Section("Assignee") {
                    if let toi {
                        chon("Me", loc.assignee.contains(toi)) { doi(&loc.assignee, toi) }
                    }
                    chon("Unassigned", loc.assignee.contains(0)) { doi(&loc.assignee, 0) }
                    ForEach(cauHinh.dsThanhVien.filter { $0.id != toi }) { u in
                        chon(u.laAgent ? "\(u.ten) · AI agent" : u.ten, loc.assignee.contains(u.id)) { doi(&loc.assignee, u.id) }
                    }
                }
                Section("Status") {
                    ForEach(trangThai) { s in
                        chon(s.name, loc.status.contains(s.id)) { doi(&loc.status, s.id) }
                    }
                    Toggle("Include done issues", isOn: $loc.includeDone)
                }
                Section("Priority") {
                    ForEach(CTW.doUuTien, id: \.so) { p in
                        Button {
                            if uuTien.contains(p.so) { uuTien.remove(p.so) } else { uuTien.insert(p.so) }
                        } label: {
                            HStack {
                                Label(p.ten, systemImage: p.bieuTuong).foregroundColor(AppColors.textPrimary)
                                Spacer()
                                if uuTien.contains(p.so) { Image(systemName: "checkmark").foregroundColor(AppColors.primary) }
                            }
                        }
                    }
                }
                Section("Type") {
                    ForEach(cauHinh.dsLoai) { t in
                        chon(t.name, loc.type.contains(t.id)) { doi(&loc.type, t.id) }
                    }
                }
                if !(cauHinh.labels ?? []).isEmpty {
                    Section("Labels") {
                        ForEach(cauHinh.labels ?? []) { l in
                            chon(l.name, loc.label.contains(l.id)) { doi(&loc.label, l.id) }
                        }
                    }
                }
                if !(cauHinh.sprints ?? []).isEmpty {
                    Section("Sprint") {
                        chon("Any", loc.sprint == nil) { loc.sprint = nil }
                        chon("Backlog (no sprint)", loc.sprint == "backlog") { loc.sprint = "backlog" }
                        ForEach(cauHinh.sprints ?? []) { s in
                            chon(s.name + (s.state == "ACTIVE" ? " (active)" : ""), loc.sprint == String(s.id)) { loc.sprint = String(s.id) }
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        let q = loc.q
                        loc = CTWAPI.BoLoc()
                        loc.q = q
                        uuTien = []
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { apDung(loc, uuTien); dong() }.bold()
                }
            }
        }
    }

    private var trangThai: [CTWStatus] {
        var thay = Set<Int>()
        return cauHinh.tatCaTrangThai.filter { thay.insert($0.id).inserted }
    }

    private func doi(_ a: inout [Int], _ v: Int) {
        if let i = a.firstIndex(of: v) { a.remove(at: i) } else { a.append(v) }
    }

    private func chon(_ ten: String, _ bat: Bool, _ lam: @escaping () -> Void) -> some View {
        Button(action: lam) {
            HStack {
                Text(ten).foregroundColor(AppColors.textPrimary)
                Spacer()
                if bat { Image(systemName: "checkmark").foregroundColor(AppColors.primary) }
            }
        }
    }
}
