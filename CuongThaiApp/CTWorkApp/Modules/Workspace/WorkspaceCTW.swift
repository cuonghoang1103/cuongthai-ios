import SwiftUI
import Charts

// MARK: - Portfolio & workload (cấp không gian): Portfolio · Workload · Teams · AI agents
//
// Phạm vi dữ liệu do MÁY CHỦ quyết: workload của admin = mọi người; trưởng nhóm = nhóm mình;
// thành viên = chỉ mình (app nói rõ). Khách (GUEST) không có Teams/AI agents ⇒ ẩn tab.

struct RouteDoiCTW: Hashable { var ws: Int; var doi: Int; var ten: String }

struct WorkspaceCTW: View {
    let nguCanh: CTWNguCanh
    @EnvironmentObject private var app: AppState
    @State private var tab: Tab = .portfolio
    @State private var ws: Int?
    @State private var khongCoWs = false

    enum Tab: String, Hashable { case portfolio, workload, teams, agents }

    private var laKhach: Bool { app.cauHinhDuAn?.workspaceRole == "GUEST" }
    private var dsTab: [(id: Tab, ten: String, bieuTuong: String?)] {
        var t: [(id: Tab, ten: String, bieuTuong: String?)] = [(.portfolio, String(localized: "Portfolio"), "square.grid.2x2"), (.workload, String(localized: "Workload"), "gauge.with.needle")]
        if !laKhach { t += [(.teams, String(localized: "Teams"), "person.3"), (.agents, String(localized: "AI agents"), "sparkles")] }
        return t
    }

    var body: some View {
        VStack(spacing: 0) {
            ThanhTabCTW(tab: dsTab, chon: $tab).padding(.vertical, 6)
            Group {
                if let ws {
                    switch tab {
                    case .portfolio: PortfolioCTW(ws: ws)
                    case .workload: WorkloadCTW(ws: ws)
                    case .teams: DsDoiCTW(ws: ws)
                    case .agents: AgentKhongGianCTW(ws: ws)
                    }
                } else if khongCoWs {
                    CTWOLoi(loi: String(localized: "Couldn't find this workspace.")) { Task { await timWs() } }
                } else {
                    CTWKhungTai(soHang: 4, coAvatar: false)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(app.luaChon?.tenKhongGian ?? String(localized: "Workspace"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await timWs() }
        #if DEBUG
        .onAppear {
            if let con = XemThuCTW.conCua("workspace"), let t = Tab(rawValue: con) { tab = t }
        }
        #endif
    }

    private func timWs() async {
        khongCoWs = false
        ws = await app.idKhongGian()
        khongCoWs = ws == nil
    }
}

// MARK: - Portfolio

struct PortfolioCTW: View {
    let ws: Int
    @Environment(\.horizontalSizeClass) private var beRong
    @State private var dl: TaiCTW<CTWPortfolio> = .dangTai

    var body: some View {
        KhungTaiCTW(trangThai: dl, thuLai: { Task { await tai() } }) { p in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    let ds = p.projects ?? []
                    tomTat(ds)
                    if ds.isEmpty {
                        CTWOTrong(bieuTuong: "square.grid.2x2", tieuDe: String(localized: "No projects to show"), moTa: String(localized: "Projects you can see in this workspace appear here."))
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: beRong == .regular ? 320 : 300), spacing: 12)], spacing: 12) {
                        ForEach(ds) { theDuAn($0) }
                    }
                    let moc = p.milestones ?? []
                    if !moc.isEmpty { mocSapToi(moc) }
                    let chan = p.blockers ?? []
                    if !chan.isEmpty { chanCheo(chan) }
                }
                .padding(Spacing.md)
                .frame(maxWidth: 1200)
                .frame(maxWidth: .infinity)
            }
            .refreshable { await tai() }
        }
        .task { await tai() }
    }

    private func tomTat(_ ds: [CTWDuAnPortfolio]) -> some View {
        let dem = { (r: String) in ds.filter { ($0.health?.rag ?? "GREEN") == r }.count }
        return CTWLuoiChiSo {
            CTWTheChiSo(nhan: String(localized: "Projects"), giaTri: "\(ds.count)", bieuTuong: "square.grid.2x2")
            CTWTheChiSo(nhan: String(localized: "On track"), giaTri: "\(dem("GREEN"))", bieuTuong: "checkmark.circle.fill", mau: AppColors.success)
            CTWTheChiSo(nhan: String(localized: "Needs attention"), giaTri: "\(dem("AMBER"))", bieuTuong: "exclamationmark.triangle.fill", mau: AppColors.warning)
            CTWTheChiSo(nhan: String(localized: "Off track"), giaTri: "\(dem("RED"))", bieuTuong: "xmark.octagon.fill", mau: AppColors.error)
        }
    }

    private func mauRag(_ r: String?) -> Color {
        switch r { case "RED": return AppColors.error; case "AMBER": return AppColors.warning; default: return AppColors.success }
    }

    private func theDuAn(_ p: CTWDuAnPortfolio) -> some View {
        let rag = p.health?.rag ?? "GREEN"
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(p.key ?? "").font(.ctw(size: 12, weight: .heavy).monospaced()).foregroundColor(AppColors.onPrimary)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(CTW.mau(p.color, macDinh: AppColors.primary)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.name ?? "").font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                    Text([p.type.map { CTWMauTrangThai.nhan($0) }, p.lead.map { String(localized: "Lead \($0.ten)") }].compactMap { $0 }.joined(separator: " · "))
                        .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                }
                Spacer(minLength: 4)
                Label(WorkspaceTinh.tenRag(rag), systemImage: WorkspaceTinh.bieuTuongRag(rag))
                    .font(.ctw(size: 11, weight: .bold)).foregroundColor(mauRag(rag))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(mauRag(rag).opacity(0.12)))
                    .fixedSize()
            }
            if let ly = p.health?.reasons?.filter({ $0.level != "GREEN" }).prefix(2), !ly.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(ly.enumerated()), id: \.offset) { _, r in
                        Label(r.text ?? "", systemImage: r.level == "RED" ? "exclamationmark.octagon" : "exclamationmark.triangle")
                            .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(2)
                    }
                }
            }
            HStack(spacing: 14) {
                so("Open", p.counts?.open, AppColors.textPrimary)
                so("Overdue", p.counts?.overdue, (p.counts?.overdue ?? 0) > 0 ? AppColors.error : AppColors.textPrimary)
                so("Done (14d)", p.counts?.done14, AppColors.success)
                if let a = p.approvals?.pending, a > 0 { so("Approvals", a, AppColors.warning) }
            }
            if let s = p.sprint {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label(s.name ?? String(localized: "Sprint"), systemImage: "flag").font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                        Spacer()
                        Text(s.daysLeft.map { $0 >= 0 ? String(localized: "\($0)d left") : String(localized: "ended") } ?? "").font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                    }
                    CTWThanhTienDo(doan: [
                        CTWDoanTienDo(ten: String(localized: "Done"), giaTri: s.done ?? 0, mau: AppColors.success),
                        CTWDoanTienDo(ten: String(localized: "Remaining"), giaTri: s.remaining ?? 0, mau: s.status == "AT_RISK" ? AppColors.warning : CTWMauChuoi.khac),
                    ], cao: 6)
                    if let sum = s.summary { Text(sum).font(.ctw(size: 11)).foregroundColor(s.status == "AT_RISK" ? AppColors.warning : AppColors.textTertiary).lineLimit(2) }
                }
            }
            if let st = p.stage, let c = st.current {
                Label("Stage \(c.n ?? 0): \(c.name ?? "") · \(st.done ?? 0)/\(st.total ?? 0)", systemImage: "flag.2.crossed")
                    .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
            }
            if let m = p.nextMilestone {
                Label("\(m.name ?? "") · \(chuMoc(m))", systemImage: "diamond")
                    .font(.ctw(size: 12)).foregroundColor((m.daysUntil ?? 0) < 0 ? AppColors.error : AppColors.textSecondary)
            }
            if let d = p.dependencies, (d.blockedBy ?? 0) + (d.blocking ?? 0) > 0 {
                Label("Blocked by \(d.blockedBy ?? 0) · blocking \(d.blocking ?? 0) in other projects", systemImage: "link")
                    .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(14)
        .ctwThe(14)
        .accessibilityElement(children: .combine)
    }

    private func so(_ nhan: LocalizedStringKey, _ v: Int?, _ mau: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(v ?? 0)").font(.ctw(size: 17, weight: .bold).monospacedDigit()).foregroundColor(mau)
            Text(nhan).font(.ctw(size: 10, weight: .medium)).foregroundColor(AppColors.textTertiary)
        }
    }

    private func chuMoc(_ m: CTWMocDuAn) -> String {
        let n = m.daysUntil ?? 0
        let ngay = NgayCTW.nganTu(m.date) ?? ""
        if n < 0 { return String(localized: "\(ngay) · \(-n)d late") }
        if n == 0 { return String(localized: "today") }
        return String(localized: "\(ngay) · in \(n)d")
    }

    private func mocSapToi(_ ds: [CTWMocDuAn]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            CTWSectionHeader("diamond", String(localized: "Milestones"), count: "\(ds.count)").padding(.bottom, 8)
            ForEach(Array(ds.prefix(12).enumerated()), id: \.offset) { i, m in
                HStack(spacing: 10) {
                    Text(m.projectKey ?? "").font(.ctw(size: 11, weight: .bold).monospaced()).foregroundColor(AppColors.primary)
                        .frame(width: 44, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.name ?? "").font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                        Text("\(m.done ?? 0)/\(m.total ?? 0) done").font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                    }
                    Spacer()
                    Text(chuMoc(m)).font(.ctw(size: 12, weight: .medium)).foregroundColor((m.daysUntil ?? 0) < 0 ? AppColors.error : AppColors.textSecondary)
                }
                .frame(minHeight: 44)
                if i < min(ds.count, 12) - 1 { Divider() }
            }
        }
        .padding(14)
        .ctwThe(14)
    }

    private func chanCheo(_ ds: [CTWPortfolio.Chan]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            CTWSectionHeader("link", String(localized: "Cross-project blockers"), count: "\(ds.count)").padding(.bottom, 8)
            ForEach(Array(ds.prefix(15).enumerated()), id: \.element.id) { i, c in
                VStack(alignment: .leading, spacing: 3) {
                    phia(c.blocker, String(localized: "blocks"))
                    phia(c.blocked, nil)
                }
                .padding(.vertical, 6)
                if i < min(ds.count, 15) - 1 { Divider() }
            }
        }
        .padding(14)
        .ctwThe(14)
    }

    private func phia(_ p: CTWPhiaChan?, _ dongTu: String?) -> some View {
        HStack(spacing: 6) {
            if p?.hidden == true {
                Text("A private issue").font(.ctw(size: 13)).italic().foregroundColor(AppColors.textTertiary)
            } else {
                Text(p?.key ?? "").font(.ctw(size: 12, weight: .semibold).monospaced()).foregroundColor(AppColors.textSecondary)
                Text(p?.title ?? "").font(.ctw(size: 13)).foregroundColor(AppColors.textPrimary).lineLimit(1)
            }
            if let dongTu { Text(dongTu).font(.ctw(size: 11, weight: .semibold)).foregroundColor(AppColors.error) }
        }
    }

    private func tai() async {
        do { dl = .xong(try await APIClient.shared.request(CTWAPI.portfolio(ws: ws))) }
        catch { if dl.giaTri == nil { dl = .loi(CTW.loi(error)) } }
    }
}

// MARK: - Workload

struct WorkloadCTW: View {
    let ws: Int
    @State private var dl: TaiCTW<CTWWorkload> = .dangTai
    @State private var doi: Int?
    @State private var mo: Set<Int> = []

    var body: some View {
        KhungTaiCTW(trangThai: dl, thuLai: { Task { await tai() } }) { w in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(phamVi(w)).font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        if let t = w.teamOptions, !t.isEmpty {
                            Menu {
                                Button("All people") { doi = nil }
                                ForEach(t) { d in Button(d.name ?? d.key ?? String(localized: "Team")) { doi = d.id } }
                            } label: {
                                Label(t.first { $0.id == doi }?.name ?? String(localized: "All people"), systemImage: "line.3.horizontal.decrease.circle")
                                    .font(.ctw(size: 13, weight: .semibold))
                            }
                        }
                    }
                    chuGiaiMuc
                    let ds = w.people ?? []
                    if ds.isEmpty {
                        CTWOTrong(bieuTuong: "gauge.with.needle", tieuDe: String(localized: "No workload to show"), moTa: String(localized: "Assigned, estimated work appears here."))
                    }
                    ForEach(ds) { n in theNguoi(n, tuan: w.weeks ?? []) }
                    if w.truncated == true {
                        Text("Showing the first 5,000 issues.").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                    }
                }
                .padding(Spacing.md)
                .frame(maxWidth: 1100)
                .frame(maxWidth: .infinity)
            }
            .refreshable { await tai() }
        }
        .task(id: doi) { await tai() }
    }

    private func phamVi(_ w: CTWWorkload) -> String {
        let khoang = "\(NgayCTW.nganTu(w.from) ?? "") – \(NgayCTW.nganTu(w.to) ?? "")"
        switch w.scope {
        case "SELF": return String(localized: "Only your own workload is visible. \(khoang)")
        case "TEAMS": return String(localized: "People in the teams you lead. \(khoang)")
        default: return String(localized: "Everyone in this workspace. \(khoang)")
        }
    }

    static func mau(_ level: String?) -> Color {
        switch level {
        case "over": return AppColors.error
        case "high": return AppColors.warning
        case "ok": return AppColors.success
        case "low": return CTWMauChuoi.mau(0)
        default: return CTWMauChuoi.khac
        }
    }

    private var chuGiaiMuc: some View {
        CTWChuGiai(muc: ["low", "ok", "high", "over"].map { CTWMucChuGiai(ten: WorkspaceTinh.tenMuc($0), mau: Self.mau($0)) })
    }

    private func theNguoi(_ n: CTWNguoiTai, tuan: [CTWWorkload.Tuan]) -> some View {
        let dangMo = mo.contains(n.id)
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { if dangMo { mo.remove(n.id) } else { mo.insert(n.id) } }
            } label: {
                HStack(spacing: 10) {
                    CTWAvatar(user: n.user, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(n.user.ten).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                            if n.user.laAgent { CTWNhanAI() }
                        }
                        Text((n.unestimated ?? 0) > 0
                             ? String(localized: "\(CTWSo.gon(n.totalHours ?? 0))h of \(CTWSo.gon(n.totalCapacity ?? 0))h · \(n.unestimated ?? 0) unestimated")
                             : String(localized: "\(CTWSo.gon(n.totalHours ?? 0))h of \(CTWSo.gon(n.totalCapacity ?? 0))h"))
                            .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(n.pct.map { "\(Int($0.rounded()))%" } ?? "—").font(.ctw(size: 17, weight: .bold).monospacedDigit())
                            .foregroundColor(Self.mau(n.level))
                        Text(WorkspaceTinh.tenMuc(n.level)).font(.ctw(size: 10, weight: .semibold)).foregroundColor(Self.mau(n.level))
                    }
                    Image(systemName: dangMo ? "chevron.up" : "chevron.down").font(.ctw(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            HStack(spacing: 4) {
                ForEach(n.weeks ?? [], id: \.start) { t in
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Self.mau(t.level).opacity(t.level == "none" ? 0.35 : 0.85))
                            .frame(height: 26)
                            .overlay(Text(t.pct.map { "\(Int($0.rounded()))" } ?? "–")
                                .font(.ctw(size: 10, weight: .bold).monospacedDigit()).foregroundColor(.white))
                        Text(NgayCTW.nganTu(t.start) ?? "").font(.ctw(size: 9)).foregroundColor(AppColors.textTertiary).lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Week of \(NgayCTW.nganTu(t.start) ?? ""): \(t.pct.map { String(localized: "\(Int($0)) percent") } ?? String(localized: "no capacity")), \(WorkspaceTinh.tenMuc(t.level))")
                }
            }
            if dangMo {
                let viec = n.issues ?? []
                if viec.isEmpty { Text("No scheduled issues.").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary) }
                ForEach(viec.prefix(20)) { v in
                    HStack(spacing: 8) {
                        Text(v.key ?? "").font(.ctw(size: 11, weight: .semibold).monospaced()).foregroundColor(AppColors.textSecondary)
                        Text(v.title ?? "").font(.ctw(size: 13)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                        Spacer()
                        if let d = NgayCTW.nganTu(v.due) {
                            Text(d).font(.ctw(size: 11)).foregroundColor(v.overdue == true ? AppColors.error : AppColors.textTertiary)
                        }
                        Text("\(CTWSo.gon(v.hours ?? 0))h").font(.ctw(size: 12, weight: .semibold).monospacedDigit())
                    }
                    .frame(minHeight: 30)
                }
            }
        }
        .padding(14)
        .ctwThe(14)
    }

    private func tai() async {
        do { dl = .xong(try await APIClient.shared.request(CTWAPI.workload(ws: ws, tu: nil, doi: doi))) }
        catch { dl = .loi(CTW.loi(error)) }
    }
}

// MARK: - Teams

struct DsDoiCTW: View {
    let ws: Int
    @State private var dl: TaiCTW<[CTWDoi]> = .dangTai

    var body: some View {
        KhungTaiCTW(trangThai: dl, thuLai: { Task { await tai() } }) { ds in
            List {
                if ds.isEmpty {
                    CTWOTrong(bieuTuong: "person.3", tieuDe: String(localized: "No teams yet"), moTa: String(localized: "Workspace admins create teams on the web."))
                        .listRowBackground(Color.clear)
                }
                ForEach(ds) { d in
                    NavigationLink(value: RouteDoiCTW(ws: ws, doi: d.id, ten: d.name ?? String(localized: "Team"))) {
                        HStack(spacing: 12) {
                            Text(d.key ?? "").font(.ctw(size: 11, weight: .heavy).monospaced()).foregroundColor(.white)
                                .lineLimit(1).minimumScaleFactor(0.6)
                                .frame(width: 40, height: 40)
                                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(CTW.mau(d.color, macDinh: AppColors.primary)))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(d.name ?? "").font(.ctw(size: 15, weight: .semibold))
                                HStack(spacing: -6) {
                                    ForEach((d.members ?? []).prefix(6)) { m in
                                        CTWAvatar(user: m.nguoi, size: 22).overlay(Circle().strokeBorder(AppColors.backgroundCard, lineWidth: 1.5))
                                    }
                                    if (d.members?.count ?? 0) > 6 {
                                        Text("+\((d.members?.count ?? 0) - 6)").font(.ctw(size: 10, weight: .bold)).foregroundColor(AppColors.textSecondary)
                                            .padding(.leading, 10)
                                    }
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("\(d.openIssues ?? 0)").font(.ctw(size: 16, weight: .bold).monospacedDigit())
                                Text("open").font(.ctw(size: 10)).foregroundColor(AppColors.textTertiary)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable { await tai() }
        }
        .task { await tai() }
    }

    private func tai() async {
        do { dl = .xong(try await APIClient.shared.request(CTWAPI.dsDoi(ws: ws))) }
        catch { dl = .loi(CTW.loi(error)) }
    }
}

struct HangDoiCTW: View {
    let ws: Int
    let doi: Int
    let ten: String
    @State private var dl: TaiCTW<CTWHangDoi> = .dangTai

    var body: some View {
        KhungTaiCTW(trangThai: dl, thuLai: { Task { await tai() } }) { q in
            List {
                if let m = q.team?.members, !m.isEmpty {
                    Section("Members") {
                        ForEach(m) { u in
                            HStack(spacing: 10) {
                                CTWAvatar(user: u.nguoi, size: 28)
                                Text(u.nguoi.ten)
                                if u.nguoi.laAgent { CTWNhanAI() }
                                Spacer()
                                if u.teamRole == "LEAD" { Text("Lead").font(.ctw(size: 11, weight: .bold)).foregroundColor(AppColors.primary) }
                            }
                        }
                    }
                }
                Section {
                    if (q.items ?? []).isEmpty { Text("The queue is empty.").foregroundColor(AppColors.textSecondary) }
                    ForEach(q.items ?? []) { t in
                        HStack(spacing: 10) {
                            CTWPriorityIcon(priority: t.priority)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(t.title ?? "").font(.ctw(size: 14)).lineLimit(2)
                                HStack(spacing: 6) {
                                    Text(t.key ?? "").font(.ctw(size: 11, weight: .semibold).monospaced()).foregroundColor(AppColors.textSecondary)
                                    if let d = NgayCTW.nganTu(t.dueDate) {
                                        Text(d).font(.ctw(size: 11)).foregroundColor(CTW.quaHan(t.dueDate) ? AppColors.error : AppColors.textTertiary)
                                    }
                                }
                            }
                            Spacer()
                            if let a = t.assignee { CTWAvatar(user: a, size: 24) } else {
                                Text("Unassigned").font(.ctw(size: 10)).foregroundColor(AppColors.textTertiary)
                            }
                        }
                    }
                } header: { Text("Open queue · \(q.total ?? 0)") }
            }
            .listStyle(.insetGrouped)
            .refreshable { await tai() }
        }
        .navigationTitle(ten)
        .navigationBarTitleDisplayMode(.inline)
        .task { await tai() }
    }

    private func tai() async {
        do { dl = .xong(try await APIClient.shared.request(CTWAPI.hangDoi(ws: ws, doi: doi))) }
        catch { dl = .loi(CTW.loi(error)) }
    }
}

// MARK: - AI agents (People vs Agents cấp không gian)

struct AgentKhongGianCTW: View {
    let ws: Int
    @State private var ngay = 30
    @State private var dl: TaiCTW<CTWAgentDashboard> = .dangTai

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Period", selection: $ngay) {
                    Text("14 days").tag(14); Text("30 days").tag(30); Text("90 days").tag(90)
                }
                .pickerStyle(.segmented)
                switch dl {
                case .dangTai: CTWKhungTai(soHang: 4, coAvatar: true).padding(-Spacing.md)
                case .loi(let l): CTWOLoi(loi: l) { Task { await tai() } }
                case .xong(let d): noiDung(d)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .refreshable { await tai() }
        .task(id: ngay) { await tai() }
    }

    @ViewBuilder private func noiDung(_ d: CTWAgentDashboard) -> some View {
        let t = d.totals
        if d.scope == "OWN" {
            Label("Showing only the AI agents you own. Workspace admins see everyone.", systemImage: "info.circle")
                .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
        }
        CTWLuoiChiSo {
            if let h = t?.humanResolved {
                CTWTheChiSo(nhan: String(localized: "Resolved by people"), giaTri: "\(h)", phu: t?.humanHours.map { String(localized: "\(CTWSo.gon($0))h logged") }, bieuTuong: "person.2", mau: CTWMauChuoi.mau(0))
            }
            CTWTheChiSo(nhan: String(localized: "Resolved by AI agents"), giaTri: "\(t?.agentResolved ?? 0)",
                        phu: String(localized: "\(Int(((t?.agentReturnRate ?? 0) * 100).rounded()))% sent back"), bieuTuong: "sparkles", mau: CTWMauChuoi.mau(1))
            VStack(alignment: .leading, spacing: 4) {
                CTWTheChiSo(nhan: String(localized: "AI agent cost (est.)"), giaTri: CTWSo.usd(t?.agentCostUsd ?? 0),
                            phu: String(localized: "Self-reported \(CTWSo.usd(t?.costSource?.reported ?? 0)) · measured \(CTWSo.usd(t?.costSource?.gateway ?? 0))"),
                            bieuTuong: "dollarsign.circle", mau: CTWMauChuoi.mau(3))
                    .overlay(alignment: .topTrailing) { NhanTuKhaiCTW().padding(8) }
            }
        }
        let tuan = d.weeks ?? []
        if !tuan.isEmpty {
            let tenNguoi = String(localized: "People"), tenAgent = String(localized: "AI agents")
            let cot = tuan.flatMap { w -> [(String, String, Int)] in
                let x = NgayCTW.nganTu(w.weekStart) ?? w.weekStart
                return (w.humanResolved.map { [(x, tenNguoi, $0)] } ?? []) + [(x, tenAgent, w.agentResolved ?? 0)]
            }
            CTWKhungBieuDo(tieuDe: String(localized: "Resolved per week"), phu: String(localized: "People vs AI agents"),
                           chuGiai: [CTWMucChuGiai(ten: tenNguoi, mau: CTWMauChuoi.mau(0)), CTWMucChuGiai(ten: tenAgent, mau: CTWMauChuoi.mau(1))],
                           cot: [String(localized: "Week"), tenNguoi, tenAgent],
                           hang: tuan.map { CTWHangBang(nhan: NgayCTW.nganTu($0.weekStart) ?? $0.weekStart,
                                                        giaTri: [$0.humanResolved.map(String.init) ?? "—", "\($0.agentResolved ?? 0)"]) },
                           cao: 200) {
                Chart(Array(cot.enumerated()), id: \.offset) { _, c in
                    BarMark(x: .value("Week", c.0), y: .value("Resolved", c.2), width: .ratio(0.8))
                        .foregroundStyle(by: .value("Who", c.1))
                        .position(by: .value("Who", c.1))
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 3, topTrailingRadius: 3))
                }
                .chartForegroundStyleScale([tenNguoi: CTWMauChuoi.mau(0), tenAgent: CTWMauChuoi.mau(1)])
                .chartLegend(.hidden)
            }
        }
        VStack(alignment: .leading, spacing: 0) {
            CTWSectionHeader("sparkles", String(localized: "AI agents"), count: "\(d.agents?.count ?? 0)").padding(.bottom, 8)
            if (d.agents ?? []).isEmpty {
                Text("No AI agent activity in this period.").font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
            }
            ForEach(Array((d.agents ?? []).enumerated()), id: \.element.id) { i, a in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        CTWAvatar(user: a.nguoi, size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 5) {
                                Text(a.agent.displayName ?? a.agent.username ?? String(localized: "Agent")).font(.ctw(size: 15, weight: .semibold))
                                CTWNhanAI()
                                if a.agent.status != "ACTIVE" {
                                    Text(a.agent.status.map { CTWMauTrangThai.nhan($0) } ?? "").font(.ctw(size: 10, weight: .bold)).foregroundColor(AppColors.textTertiary)
                                }
                            }
                            Text([a.agent.model, a.agent.owner.map { String(localized: "Owner \($0.ten)") }].compactMap { $0 }.joined(separator: " · "))
                                .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(CTWSo.usd(a.costUsd ?? 0)).font(.ctw(size: 14, weight: .bold).monospacedDigit())
                            Text(WorkspaceTinh.tiLeTuKhai(a.costSource) >= 0.5 ? "self-reported" : "measured")
                                .font(.ctw(size: 10)).foregroundColor(AppColors.textTertiary)
                        }
                    }
                    HStack(spacing: 14) {
                        chiSo("Resolved", "\(a.issuesResolved ?? 0)")
                        chiSo("Points", CTWSo.gon(a.pointsResolved ?? 0))
                        chiSo("Sent back", "\(Int(((a.returnRate ?? 0) * 100).rounded()))%")
                        chiSo("Cost / pt", a.costPerPoint.map(CTWSo.usd) ?? "—")
                    }
                }
                .padding(.vertical, 8)
                if i < (d.agents?.count ?? 0) - 1 { Divider() }
            }
            Text("Agent costs are estimates. Most are self-reported by the agent, not measured by CT Work.")
                .font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary).padding(.top, 8)
        }
        .padding(14)
        .ctwThe(14)
    }

    private func chiSo(_ nhan: LocalizedStringKey, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(v).font(.ctw(size: 13, weight: .semibold).monospacedDigit()).foregroundColor(AppColors.textPrimary)
            Text(nhan).font(.ctw(size: 10)).foregroundColor(AppColors.textTertiary)
        }
    }

    private func tai() async {
        if dl.giaTri == nil { dl = .dangTai }
        do { dl = .xong(try await APIClient.shared.request(CTWAPI.agentDashboard(ws: ws, ngay: ngay))) }
        catch { dl = .loi(CTW.loi(error)) }
    }
}
