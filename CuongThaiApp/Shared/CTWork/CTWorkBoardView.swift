import SwiftUI

// MARK: - CT Work — Bảng (board)
//
// Cột = `config.boardColumns` (mỗi cột gom nhiều trạng thái). Thẻ vào cột có
// `statusIds` chứa `statusId` của nó. Đổi cột bằng menu "Move to…" (giữ thẻ)
// hoặc kéo thả (iPad/Mac). Quy trình có thể CẤM một số bước chuyển — menu
// chỉ liệt kê bước hợp lệ, và câu từ chối của máy chủ vẫn hiện nguyên văn.

@MainActor
final class CTWBoardVM: ObservableObject {
    let pid: Int
    @Published var cauHinh: CTWProjectConfig?
    @Published var bang: CTWBoardData?
    @Published var loi: String?
    @Published var dangTai = false
    /// Sprint đang xem; nil = sprint đang chạy (mặc định của máy chủ).
    @Published var sprintId: Int?

    init(pid: Int) { self.pid = pid }

    func tai() async {
        dangTai = true
        defer { dangTai = false }
        do {
            async let c: CTWProjectConfig = APIClient.shared.request(.workDuAn(pid: pid))
            async let b: CTWBoardData = APIClient.shared.request(.workBang(pid: pid, sprintId: sprintId))
            let (cc, bb) = try await (c, b)
            cauHinh = cc
            bang = bb
            loi = nil
        } catch {
            loi = CTW.loi(error)
        }
    }

    func napBang() async {
        do {
            bang = try await APIClient.shared.request(.workBang(pid: pid, sprintId: sprintId))
            loi = nil
        } catch {
            loi = CTW.loi(error)
        }
    }

    var cot: [CTWBoardColumn] { cauHinh?.boardColumns ?? [] }

    func the(trongCot c: CTWBoardColumn) -> [CTWIssueCard] {
        let ids = Set(c.statusIds ?? [])
        return (bang?.issues ?? []).filter { ids.contains($0.statusId) }
    }

    /// Chuyển thẻ sang trạng thái mới — đổi trên máy TRƯỚC rồi gọi mạng,
    /// hỏng thì trả lại chỗ cũ.
    func chuyen(_ the: CTWIssueCard, sang statusId: Int) async {
        guard the.statusId != statusId, var ds = bang?.issues,
              let i = ds.firstIndex(where: { $0.id == the.id }) else { return }
        let cu = ds
        ds[i].statusId = statusId
        bang?.issues = ds
        var than: [String: Any] = ["statusId": statusId]
        if let v = the.version { than["version"] = v }
        do {
            try await APIClient.shared.send(.workChuyenThe(pid: pid, so: the.number, than: than))
            await napBang()   // lấy `version`/`rank` mới
        } catch {
            bang?.issues = cu
            loi = CTW.loi(error)
            if CTW.laXungDot(error) { await napBang() }
        }
    }

    /// Kéo thả vào cột: chọn trạng thái hợp lệ ĐẦU TIÊN của cột đó.
    func tha(soThe: Int, vaoCot c: CTWBoardColumn) async -> Bool {
        guard let cfg = cauHinh, cfg.coTheChuyen,
              let the = bang?.issues?.first(where: { $0.number == soThe }) else { return false }
        if (c.statusIds ?? []).contains(the.statusId) { return false }
        guard let st = cfg.trangThaiTrongCot(c, loai: the.typeId, tu: the.statusId) else {
            loi = "\(cfg.key)-\(the.number) can't move to \(c.name) — the workflow doesn't allow it."
            return false
        }
        await chuyen(the, sang: st.id)
        return true
    }
}

struct CTWBoardView: View {
    let pid: Int
    let ten: String

    @StateObject private var vm: CTWBoardVM
    @State private var moTao = false
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var beRong
    #endif

    init(pid: Int, ten: String) {
        self.pid = pid
        self.ten = ten
        _vm = StateObject(wrappedValue: CTWBoardVM(pid: pid))
    }

    private var rong: Bool {
        #if os(iOS)
        return beRong == .regular
        #else
        return true
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            if let loi = vm.loi {
                CTWErrorBanner(text: loi) { vm.loi = nil }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.sm)
            }
            if let b = vm.bang {
                dauBang(b)
            }
            if vm.cauHinh != nil {
                cacCot
            } else if vm.loi == nil {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Spacer()
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(vm.cauHinh?.name ?? ten)
        .ctwTieuDeNho()
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if let cfg = vm.cauHinh, cfg.type != "KANBAN" {
                    menuSprint(cfg)
                }
                if vm.cauHinh?.coTheTao == true {
                    Button { moTao = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Create issue")
                }
            }
        }
        .sheet(isPresented: $moTao) {
            if let cfg = vm.cauHinh {
                CTWCreateIssueView(cauHinh: cfg, sprintId: vm.bang?.sprint?.id) { so in
                    Task { await vm.napBang() }
                    _ = so
                }
            }
        }
        .task { if vm.cauHinh == nil { await vm.tai() } }
    }

    private func dauBang(_ b: CTWBoardData) -> some View {
        HStack(spacing: 6) {
            if let s = b.sprint {
                Image(systemName: "flag.fill").foregroundColor(AppColors.primary)
                Text(s.name).font(.system(size: 13, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                if let e = CTW.ngayNgan(s.endAt) {
                    Text("· ends \(e)").font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                }
            } else if b.fallback == true {
                Image(systemName: "info.circle").foregroundColor(AppColors.textTertiary)
                Text("No active sprint — showing all open issues")
                    .font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 6)
    }

    private func menuSprint(_ cfg: CTWProjectConfig) -> some View {
        let ds = (cfg.sprints ?? []).filter { $0.state != "CLOSED" }
        return Menu {
            Button {
                vm.sprintId = nil
                Task { await vm.napBang() }
            } label: {
                Label("Active sprint", systemImage: vm.sprintId == nil ? "checkmark" : "flag")
            }
            ForEach(ds) { s in
                Button {
                    vm.sprintId = s.id
                    Task { await vm.napBang() }
                } label: {
                    Label("\(s.name)\(s.state == "ACTIVE" ? " (active)" : "")",
                          systemImage: vm.sprintId == s.id ? "checkmark" : "calendar")
                }
            }
        } label: {
            Image(systemName: "flag")
        }
        .accessibilityLabel("Choose sprint")
        .disabled(ds.isEmpty)
    }

    // MARK: Cột

    private var cacCot: some View {
        GeometryReader { geo in
            let so = max(vm.cot.count, 1)
            let khoang: CGFloat = 12
            // iPad/Mac: chia đều bề ngang khi đủ chỗ (≥ 240pt mỗi cột), không
            // thì cuộn ngang. iPhone: cột gần bằng màn để thấy mép cột sau.
            let deu = (geo.size.width - khoang * CGFloat(so + 1)) / CGFloat(so)
            let rongCot: CGFloat = rong ? max(240, deu) : min(300, geo.size.width * 0.82)
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: khoang) {
                    ForEach(vm.cot) { c in
                        cot(c, rongCot: rongCot, cao: geo.size.height - 8)
                    }
                }
                .padding(.horizontal, khoang)
                .padding(.bottom, 8)
            }
            .overlay {
                if vm.cot.isEmpty {
                    Text("This project has no board columns.")
                        .font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    private func cot(_ c: CTWBoardColumn, rongCot: CGFloat, cao: CGFloat) -> some View {
        let ds = vm.the(trongCot: c)
        let vuot = c.wipLimit.map { ds.count > $0 } ?? false
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(c.name.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
                Text(c.wipLimit.map { "\(ds.count)/\($0)" } ?? "\(ds.count)")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundColor(vuot ? AppColors.error : AppColors.textTertiary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(ds) { t in
                        theBang(t)
                    }
                    if ds.isEmpty {
                        Text("No issues")
                            .font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
                            .frame(maxWidth: .infinity, minHeight: 60)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
            .refreshable { await vm.tai() }
        }
        .frame(width: rongCot)
        .frame(maxHeight: max(cao, 200), alignment: .top)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppColors.backgroundTertiary))
        .dropDestination(for: String.self) { items, _ in
            guard let s = items.first, let so = Int(s) else { return false }
            Task { _ = await vm.tha(soThe: so, vaoCot: c) }
            return true
        }
    }

    @ViewBuilder
    private func theBang(_ t: CTWIssueCard) -> some View {
        if let cfg = vm.cauHinh {
            NavigationLink(value: CTWRoute.the(pid: pid, so: t.number)) {
                CTWCardView(the: t, cauHinh: cfg)
            }
            .buttonStyle(.plain)
            .contextMenu { menuChuyen(t, cfg) }
            .modifier(KeoThe(so: t.number, bat: cfg.coTheChuyen))
        }
    }

    @ViewBuilder
    private func menuChuyen(_ t: CTWIssueCard, _ cfg: CTWProjectConfig) -> some View {
        if cfg.coTheChuyen {
            let dich = cfg.trangThaiDich(loai: t.typeId, tu: t.statusId).filter { $0.id != t.statusId }
            if dich.isEmpty {
                Text("No transitions available")
            } else {
                Menu("Move to…") {
                    ForEach(dich) { s in
                        Button(s.name) { Task { await vm.chuyen(t, sang: s.id) } }
                    }
                }
            }
        } else {
            Text("You can view this project but not move issues")
        }
    }
}

/// Kéo thẻ — chỉ bật khi có quyền chuyển trạng thái.
private struct KeoThe: ViewModifier {
    let so: Int
    let bat: Bool
    func body(content: Content) -> some View {
        if bat {
            content.draggable(String(so))
        } else {
            content
        }
    }
}

// MARK: - Thẻ

struct CTWCardView: View {
    let the: CTWIssueCard
    let cauHinh: CTWProjectConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(the.title)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let nhan = nhanCuaThe, !nhan.isEmpty {
                HStack(spacing: 4) {
                    ForEach(nhan.prefix(3)) { l in
                        Text(l.name)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(CTW.mau(l.color, macDinh: AppColors.textSecondary))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Capsule().fill(CTW.mau(l.color, macDinh: AppColors.textSecondary).opacity(0.14)))
                            .lineLimit(1)
                    }
                }
            }

            HStack(spacing: 6) {
                CTWTypeIcon(type: cauHinh.loai(the.typeId), size: 12)
                Text("\(cauHinh.key)-\(the.number)")
                    .font(.system(size: 11, weight: .medium).monospaced())
                    .foregroundColor(the.resolvedAt != nil ? AppColors.textTertiary : AppColors.textSecondary)
                    .strikethrough(the.resolvedAt != nil)
                CTWPriorityIcon(priority: the.priority)
                if let d = CTW.ngayNgan(the.dueDate) {
                    Text(d)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(the.resolvedAt == nil && CTW.quaHan(the.dueDate) ? AppColors.error : AppColors.textTertiary)
                }
                Spacer(minLength: 0)
                if let sp = the.storyPoints {
                    Text(sp == sp.rounded() ? String(Int(sp)) : String(format: "%.1f", sp))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(AppColors.backgroundTertiary))
                }
                if the.assigneeId != nil {
                    CTWAvatar(user: cauHinh.thanhVien(the.assigneeId)
                                ?? CTWUser(id: the.assigneeId ?? 0, username: "?"),
                              size: 22)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppColors.backgroundCard)
                .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var nhanCuaThe: [CTWLabel]? {
        guard let ids = the.labelIds, !ids.isEmpty else { return nil }
        return (cauHinh.labels ?? []).filter { ids.contains($0.id) }
    }
}
