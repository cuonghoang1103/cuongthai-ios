import SwiftUI

// MARK: - AI Agents — danh sách agent của không gian + "đang làm gì" trong dự án
//
// App Store 4.7: agent là thành viên AI ⇒ MỌI chỗ hiện agent đều có nhãn "AI agent"
// + ✦ trên avatar. Tạm dừng/chạy lại cho chủ agent hoặc admin không gian
// (`canManage` của chi tiết — máy chủ kiểm lại). Không có "Retire" trên điện thoại
// vì thao tác đó không đảo ngược được.

/// Route con của mô-đun Agents.
struct RouteAgentCTW: Hashable { var wsId: Int; var id: Int; var ten: String }

@MainActor
final class AgentsVM: ObservableObject {
    let pid: Int
    let wsId: Int?
    @Published var ds: [CTWAgentHoSo]?
    @Published var chip: [CTWAgentChip] = []
    /// issueId nội bộ → (mã thẻ, tiêu đề) — rút từ lịch sử lease của từng agent đang làm.
    @Published var theTheoId: [Int: CTWAgentLeaseLichSu.The] = [:]
    @Published var loi: String?

    init(pid: Int, wsId: Int?) { self.pid = pid; self.wsId = wsId }

    func tai() async {
        guard let wsId else { loi = String(localized: "This project isn't in a workspace you can see."); return }
        do {
            async let a: [CTWAgentHoSo] = APIClient.shared.request(CTWAPI.dsAgent(wsId: wsId))
            async let b: [CTWAgentChip]? = try? APIClient.shared.request(CTWAPI.chipAgent(pid: pid))
            let (x, y) = try await (a, b)
            ds = x
            chip = y ?? []
            loi = nil
            // Chip chỉ có issueId nội bộ ⇒ hỏi lịch sử lease của agent đang làm để có mã thẻ.
            let canHoi = x.filter { !($0.activeLeases ?? []).isEmpty }.prefix(8)
            var map: [Int: CTWAgentLeaseLichSu.The] = [:]
            for ag in canHoi {
                if let ls: [CTWAgentLeaseLichSu] = try? await APIClient.shared.request(CTWAPI.agentLease(wsId: wsId, id: ag.id)) {
                    for l in ls { if let i = l.issueId, let t = l.issue { map[i] = t } }
                }
            }
            theTheoId = map
        } catch {
            if case APIError.coMa(let ma, _) = error, ma == "WORK_AGENT_FORBIDDEN" {
                loi = String(localized: "AI agents can't view other agents.")
            } else { loi = CTW.loi(error) }
        }
    }
}

struct AgentsCTW: View {
    let nguCanh: CTWNguCanh
    @StateObject private var vm: AgentsVM
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW

    init(nguCanh: CTWNguCanh, wsId: Int?) {
        self.nguCanh = nguCanh
        _vm = StateObject(wrappedValue: AgentsVM(pid: nguCanh.pid, wsId: wsId))
    }

    var body: some View {
        List {
            if let loi = vm.loi {
                if vm.ds == nil {
                    CTWOLoi(loi: loi) { Task { await vm.tai() } }.listRowBackground(Color.clear)
                } else {
                    CTWErrorBanner(text: loi) { vm.loi = nil }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                }
            }
            if !vm.chip.isEmpty {
                Section {
                    ForEach(vm.chip, id: \.issueId) { c in hangDangLam(c) }
                } header: {
                    Text("Working now in \(nguCanh.maDuAn)")
                } footer: {
                    Text("Progress is reported by the agent itself.")
                }
            }
            if let ds = vm.ds {
                if ds.isEmpty {
                    CTWOTrong(bieuTuong: "sparkles", tieuDe: String(localized: "No AI agents yet"),
                              moTa: String(localized: "Workspace admins can add AI agents as team members. They show up here with their status and current work."))
                        .listRowBackground(Color.clear)
                } else {
                    Section("Agents in this workspace · \(ds.count)") {
                        ForEach(ds) { a in
                            NavigationLink(value: RouteAgentCTW(wsId: vm.wsId ?? 0, id: a.id, ten: a.ten)) { hang(a) }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundPrimary)
        .overlay { if vm.ds == nil && vm.loi == nil { CTWKhungTai(soHang: 4) } }
        .navigationTitle("AI agents")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await vm.tai() }
        .task { if vm.ds == nil { await vm.tai() } }
        #if DEBUG
        .onAppear {
            if XemThuCTW.conCua("agents") == "detail", nganXep.duong.count <= 1 {
                nganXep.duong.append(RouteAgentCTW(wsId: 1, id: 4, ten: "Scout"))
            }
        }
        #endif
    }

    private func hang(_ a: CTWAgentHoSo) -> some View {
        HStack(spacing: 12) {
            CTWAvatar(user: a.user, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(a.ten).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                    CTWNhanAI()
                }
                Text([a.roleText, a.model].compactMap { $0 }.joined(separator: " · "))
                    .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                HStack(spacing: 8) {
                    CTWChipChu(chu: a.status, mau: CTWAgentHienThi.mauTrangThai(a.status))
                    let n = (a.activeLeases ?? []).count
                    if n > 0 {
                        Text("\(n) active").font(.ctw(size: 11, weight: .semibold)).foregroundColor(AppColors.primary)
                    }
                    if let t = CTWAgentHienThi.truoc(a.lastSeenAt) {
                        Text("Seen \(t)").font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary).lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func hangDangLam(_ c: CTWAgentChip) -> some View {
        let u = app.cauHinhDuAn?.thanhVien(c.agentUserId)
            ?? vm.ds?.first { $0.userId == c.agentUserId }?.user
        let ch = CTWAgentHienThi.chip(status: c.status, expiresAt: c.expiresAt, pct: c.progressPct)
        let the = vm.theTheoId[c.issueId]
        let noiDung = VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                CTWAvatar(user: u, size: 26)
                Text(u?.ten ?? String(localized: "Agent")).font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                CTWNhanAI()
                Spacer(minLength: 4)
                CTWNhanNho(chu: ch.chu, bieuTuong: ch.ket ? "exclamationmark.triangle.fill" : "bolt.fill",
                           mau: ch.ket ? AppColors.error : AppColors.primary)
            }
            if let the {
                Text([the.key, the.title].compactMap { $0 }.joined(separator: "  "))
                    .font(.ctw(size: 13, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(2)
            }
            if let p = c.progress, !p.isEmpty {
                Text(p).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(2)
            }
            if let pct = c.progressPct, !ch.ket {
                ProgressView(value: min(max(pct, 0), 100), total: 100).tint(AppColors.primary)
            }
        }
        .padding(.vertical, 3)
        if let k = the?.key, let t = Self.tachMa(k) {
            NavigationLink(value: CTWRoute.theTheoMa(slug: nguCanh.slug, ma: t.0, so: t.1)) { noiDung }
        } else {
            noiDung
        }
    }

    /// "NW-12" → ("NW", 12). Mã dự án có thể chứa "-" ⇒ tách ở gạch CUỐI.
    static func tachMa(_ k: String) -> (String, Int)? {
        guard let g = k.lastIndex(of: "-"), let so = Int(k[k.index(after: g)...]) else { return nil }
        let ma = String(k[..<g])
        return ma.isEmpty ? nil : (ma, so)
    }
}

// MARK: - Chi tiết agent

struct AgentChiTietCTW: View {
    let r: RouteAgentCTW
    @EnvironmentObject private var app: AppState
    @State private var a: CTWAgentHoSo?
    @State private var lease: [CTWAgentLeaseLichSu] = []
    @State private var loi: String?
    @State private var hoiDung: Bool?
    @State private var dangLam = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }
                if let a {
                    dau(a)
                    if a.canManage == true && a.status != "RETIRED" { nutDieuKhien(a) }
                    CTWKhoiTruong {
                        CTWHangTruong(String(localized: "Model"), a.model, bieuTuong: "cpu")
                        Divider()
                        CTWHangTruong(String(localized: "Runs"), a.tenRuntime, bieuTuong: "server.rack")
                        Divider()
                        CTWHangTruong(nhan: String(localized: "Owner"), bieuTuong: "person.crop.circle") {
                            HStack(spacing: 6) {
                                CTWAvatar(user: a.owner, size: 20)
                                Text(a.owner?.ten ?? "—")
                            }
                        }
                        Divider()
                        CTWHangTruong(String(localized: "Parallel tasks"), a.parallelSlots.map(String.init), bieuTuong: "square.stack.3d.up")
                        if let cap = a.dailyCostCapUsd {
                            Divider()
                            CTWHangTruong(String(localized: "Daily cost cap"), String(localized: "\(String(format: "$%.2f", cap)) (estimate)"), bieuTuong: "gauge.with.dots.needle.33percent")
                        }
                        Divider()
                        CTWHangTruong(String(localized: "Last seen"), CTWAgentHienThi.truoc(a.lastSeenAt) ?? String(localized: "Never"), bieuTuong: "clock")
                        Divider()
                        CTWHangTruong(String(localized: "Added"), CTW.ngayNgan(a.createdAt), bieuTuong: "calendar")
                    }
                    let dangLamDs = lease.filter { $0.status == "ACTIVE" }
                    CTWSectionHeader("bolt.fill", String(localized: "Current work"), count: "\(dangLamDs.count)")
                    if dangLamDs.isEmpty {
                        Text("Not working on anything right now.").font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
                    } else {
                        VStack(spacing: 8) { ForEach(dangLamDs) { hangLease($0) } }
                    }
                    let cu = lease.filter { $0.status != "ACTIVE" }.prefix(20)
                    if !cu.isEmpty {
                        CTWSectionHeader("clock.arrow.circlepath", String(localized: "Recent work"), count: "\(cu.count)")
                        VStack(spacing: 8) { ForEach(Array(cu)) { hangLease($0) } }
                    }
                    if let ps = a.projects, !ps.isEmpty {
                        CTWSectionHeader("rectangle.3.group", String(localized: "Projects"), count: "\(ps.count)")
                        CTWKhoiTruong {
                            ForEach(Array(ps.enumerated()), id: \.element.id) { i, p in
                                if i > 0 { Divider() }
                                CTWHangTruong(nhan: [p.key, p.name].compactMap { $0 }.joined(separator: " · ")) {
                                    CTWNhanNho(chu: CTWVaiTroDuAn(rawValue: p.role ?? "")?.ten ?? (p.role ?? "—"))
                                }
                            }
                        }
                    }
                } else if loi == nil {
                    CTWKhungTai(soHang: 4)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(r.ten)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await tai() }
        .task { if a == nil { await tai() } }
        .confirmationDialog(
            hoiDung == true ? "Pause \(a?.ten ?? "this agent")?" : "Resume \(a?.ten ?? "this agent")?",
            isPresented: Binding(get: { hoiDung != nil }, set: { if !$0 { hoiDung = nil } }),
            titleVisibility: .visible
        ) {
            Button(hoiDung == true ? "Pause agent" : "Resume agent", role: hoiDung == true ? .destructive : nil) {
                guard let d = hoiDung else { return }
                Task { await doi(dung: d) }
            }
        } message: {
            Text(hoiDung == true
                 ? "While paused the agent can still read the project, but every change it tries is refused."
                 : "The agent can pick up and change work again.")
        }
    }

    private func dau(_ a: CTWAgentHoSo) -> some View {
        HStack(spacing: 14) {
            CTWAvatar(user: a.user, size: 56)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(a.ten).font(.ctw(size: 20, weight: .bold)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                    CTWNhanAI()
                }
                if let rt = a.roleText, !rt.isEmpty {
                    Text(rt).font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary).lineLimit(2)
                }
                CTWChipChu(chu: a.status, mau: CTWAgentHienThi.mauTrangThai(a.status))
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .ctwThe(16)
    }

    private func nutDieuKhien(_ a: CTWAgentHoSo) -> some View {
        let dung = a.status == "ACTIVE"
        return Button { hoiDung = dung } label: {
            HStack {
                if dangLam { ProgressView() } else { Image(systemName: dung ? "pause.fill" : "play.fill") }
                Text(dung ? "Pause agent" : "Resume agent").fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(dung ? AppColors.warning : AppColors.success)
        .disabled(dangLam)
    }

    @ViewBuilder
    private func hangLease(_ l: CTWAgentLeaseLichSu) -> some View {
        let ch = CTWAgentHienThi.chip(status: l.status, expiresAt: l.expiresAt, pct: l.progressPct)
        let noiDung = VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let k = l.issue?.key {
                    Text(k).font(.ctw(size: 12, weight: .bold).monospaced()).foregroundColor(AppColors.primary)
                }
                Text(l.issue?.title ?? String(localized: "Issue")).font(.ctw(size: 14, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                Spacer(minLength: 4)
                CTWNhanNho(chu: ch.chu, mau: ch.ket ? AppColors.error : (l.status == "ACTIVE" ? AppColors.primary : AppColors.textSecondary))
            }
            if let p = l.progress, !p.isEmpty {
                Text(p).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(3)
            }
            Text(l.status == "ACTIVE"
                 ? String(localized: "Claimed \(CTWAgentHienThi.truoc(l.claimedAt) ?? "—") · heartbeat \(CTWAgentHienThi.truoc(l.heartbeatAt) ?? "—")")
                 : (l.releasedAt.map { String(localized: "Claimed \(CTW.thoiDiem(l.claimedAt)) · released \(CTW.thoiDiem($0))") }
                    ?? String(localized: "Claimed \(CTW.thoiDiem(l.claimedAt))")))
                .font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ctwThe(12)
        if let k = l.issue?.key, let t = AgentsCTW.tachMa(k), let slug = app.luaChon?.slug {
            NavigationLink(value: CTWRoute.theTheoMa(slug: slug, ma: t.0, so: t.1)) { noiDung }.buttonStyle(.plain)
        } else {
            noiDung
        }
    }

    private func tai() async {
        do {
            async let x: CTWAgentHoSo = APIClient.shared.request(CTWAPI.agent(wsId: r.wsId, id: r.id))
            async let y: [CTWAgentLeaseLichSu]? = try? APIClient.shared.request(CTWAPI.agentLease(wsId: r.wsId, id: r.id))
            let (m, n) = try await (x, y)
            a = m
            lease = n ?? []
            loi = nil
        } catch { loi = CTW.loi(error) }
    }

    private func doi(dung: Bool) async {
        dangLam = true
        defer { dangLam = false }
        do {
            var m: CTWAgentHoSo = try await APIClient.shared.request(CTWAPI.dungAgent(wsId: r.wsId, id: r.id, dung: dung))
            // Giữ trường chỉ có ở lần đọc chi tiết nếu phản hồi thiếu.
            if m.canManage == nil { m.canManage = a?.canManage }
            if m.projects == nil { m.projects = a?.projects }
            a = m
            CTWRung.thanhCong()
        } catch { loi = CTW.loi(error); CTWRung.loi() }
    }
}
