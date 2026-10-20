import SwiftUI

// MARK: - CT Work — Bảng (board)
//
// Cột = `config.boardColumns` (mỗi cột gom nhiều trạng thái). Thẻ vào cột có
// `statusIds` chứa `statusId` của nó. Đổi cột bằng menu "Move to…" (giữ thẻ)
// hoặc kéo thả (iPhone lẫn iPad: cột đích sáng lên + rung nhẹ khi thẻ lơ lửng trên nó). Quy trình có thể CẤM một số bước chuyển — menu
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
            CTWRung.thanhCong()
            await napBang()   // lấy `version`/`rank` mới
        } catch {
            bang?.issues = cu
            loi = CTW.loi(error)
            CTWRung.loi()
            if CTW.laXungDot(error) { await napBang() }
        }
    }

    /// Kéo thả vào cột: chọn trạng thái hợp lệ ĐẦU TIÊN của cột đó.
    func tha(soThe: Int, vaoCot c: CTWBoardColumn) async -> Bool {
        guard let cfg = cauHinh, cfg.coTheChuyen,
              let the = bang?.issues?.first(where: { $0.number == soThe }) else { return false }
        if (c.statusIds ?? []).contains(the.statusId) { return false }
        guard let st = cfg.trangThaiTrongCot(c, loai: the.typeId, tu: the.statusId) else {
            loi = String(localized: "\(cfg.key)-\(the.number) can't move to \(c.name) — the workflow doesn't allow it.")
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
    @EnvironmentObject private var appState: AppState
    @State private var moTao = false
    /// Lọc nhanh trên bảng (chỉ phía máy — bảng đã nạp đủ thẻ của sprint). Cùng bộ với web (đợt 8D: gom vào MỘT
    /// nút "Filters"): chỉ của tôi · cập nhật gần đây (2 ngày) · hạn trong tuần · chưa giao · nhãn.
    @State private var loc = BoLocBang()
    @State private var timChu = ""
    /// Cột đang được kéo thẻ lơ lửng phía trên — tô sáng làm đích thả.
    @State private var cotDich: String?
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var beRong
    #endif

    struct BoLocBang: Equatable {
        var chiCuaToi = false
        var ganDay = false
        var tuanNay = false
        var chuaGiao = false
        var nhan: Set<Int> = []
        var soBat: Int { [chiCuaToi, ganDay, tuanNay, chuaGiao].filter { $0 }.count + nhan.count }
    }

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
                    .padding(.bottom, Spacing.sm)
            }
            if let b = vm.bang, vm.cauHinh != nil {
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
        .searchable(text: $timChu, placement: .toolbar, prompt: "Filter issues")
        .navigationTitle(vm.cauHinh?.name ?? ten)
        .ctwTieuDeNho()
        .toolbar {
            // "Hiện dần" (19/10/2026): MỘT hành động chính nổi bật (+ tạo thẻ); mọi bộ lọc + chọn sprint trong MỘT
            // menu "Filters" (như web đợt 8D) — biểu tượng đặc khi đang lọc để người dùng biết bảng đang bị lọc.
            ToolbarItemGroup(placement: .primaryAction) {
                menuLoc
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

    // MARK: Menu lọc

    private var dangLoc: Bool { loc.soBat > 0 || vm.sprintId != nil }

    private var menuLoc: some View {
        Menu {
            Section("Quick filters") {
                Toggle(isOn: $loc.chiCuaToi) { Label("Only my issues", systemImage: "person.crop.circle") }
                Toggle(isOn: $loc.ganDay) { Label("Recently updated", systemImage: "clock.arrow.circlepath") }
                Toggle(isOn: $loc.tuanNay) { Label("Due this week", systemImage: "calendar") }
                Toggle(isOn: $loc.chuaGiao) { Label("Unassigned", systemImage: "person.crop.circle.badge.questionmark") }
            }
            if let cfg = vm.cauHinh, !(cfg.labels ?? []).isEmpty {
                Menu {
                    ForEach(cfg.labels ?? []) { l in
                        Toggle(isOn: Binding(get: { loc.nhan.contains(l.id) },
                                             set: { if $0 { loc.nhan.insert(l.id) } else { loc.nhan.remove(l.id) } })) {
                            Text(verbatim: l.name)
                        }
                    }
                } label: {
                    Label("Labels", systemImage: "tag")
                }
            }
            if let cfg = vm.cauHinh, cfg.type != "KANBAN" {
                menuSprint(cfg)
            }
            if dangLoc {
                Divider()
                Button(role: .destructive) { xoaLoc() } label: { Label("Clear all filters", systemImage: "xmark.circle") }
            }
        } label: {
            Image(systemName: dangLoc ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel(dangLoc ? Text("Filters, \(loc.soBat + (vm.sprintId != nil ? 1 : 0)) active") : Text("Filters"))
    }

    private func xoaLoc() {
        loc = BoLocBang()
        timChu = ""
        if vm.sprintId != nil {
            vm.sprintId = nil
            Task { await vm.napBang() }
        }
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
                    if s.state == "ACTIVE" {
                        Label { Text("\(s.name) (active)") } icon: { Image(systemName: vm.sprintId == s.id ? "checkmark" : "calendar") }
                    } else {
                        Label { Text(verbatim: s.name) } icon: { Image(systemName: vm.sprintId == s.id ? "checkmark" : "calendar") }
                    }
                }
            }
        } label: {
            Label("Sprint", systemImage: "flag")
        }
        .accessibilityLabel("Choose sprint")
        .disabled(ds.isEmpty)
    }

    // MARK: Đầu bảng: sprint · số thẻ · bộ lọc đang bật

    private func dauBang(_ b: CTWBoardData) -> some View {
        let tong = b.issues?.count ?? 0
        let hien = (b.issues ?? []).filter(khop).count
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let s = b.sprint {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.fill").font(.ctw(size: 11)).foregroundColor(AppColors.primary)
                        Text(s.name).font(.ctw(size: 13, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(AppColors.primary.opacity(0.12)))
                    .layoutPriority(1)
                    if let e = CTWKieuWeb.ngay(s.endAt) {
                        Text("ends \(e)")
                            .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                    }
                } else if b.fallback == true {
                    Image(systemName: "info.circle").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                    Text("No active sprint — showing all open issues")
                        .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(2)
                }
                Spacer(minLength: 4)
                Group {
                    if hien == tong { Text("\(tong) issues") } else { Text("\(hien) of \(tong)") }
                }
                .font(.ctw(size: 12).monospacedDigit())
                .foregroundColor(AppColors.textTertiary)
                .lineLimit(1)
                .fixedSize()
            }
            if loc.soBat > 0 || !timChu.trimmingCharacters(in: .whitespaces).isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        if loc.chiCuaToi { chipLoc("Only my issues") { loc.chiCuaToi = false } }
                        if loc.ganDay { chipLoc("Recently updated") { loc.ganDay = false } }
                        if loc.tuanNay { chipLoc("Due this week") { loc.tuanNay = false } }
                        if loc.chuaGiao { chipLoc("Unassigned") { loc.chuaGiao = false } }
                        ForEach((vm.cauHinh?.labels ?? []).filter { loc.nhan.contains($0.id) }) { l in
                            chipLoc(verbatim: l.name) { loc.nhan.remove(l.id) }
                        }
                        Button { xoaLoc() } label: {
                            Text("Clear all").font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.primary).fixedSize()
                                .padding(.horizontal, 8).frame(minHeight: 30)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, 8)
    }

    private func chipLoc(_ ten: LocalizedStringKey, bo: @escaping () -> Void) -> some View {
        chipLocNoiDung(Text(ten), bo: bo)
    }

    private func chipLoc(verbatim ten: String, bo: @escaping () -> Void) -> some View {
        chipLocNoiDung(Text(verbatim: ten), bo: bo)
    }

    private func chipLocNoiDung(_ chu: Text, bo: @escaping () -> Void) -> some View {
        Button { CTWRung.chon(); bo() } label: {
            HStack(spacing: 4) {
                chu.font(.ctw(size: 12, weight: .medium)).fixedSize()
                Image(systemName: "xmark").font(.ctw(size: 9, weight: .bold))
            }
            .foregroundColor(AppColors.primary)
            .padding(.horizontal, 9).frame(minHeight: 30)
            .background(Capsule().fill(AppColors.primary.opacity(0.10)))
            .overlay(Capsule().strokeBorder(AppColors.primary.opacity(0.35), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Removes this filter"))
    }

    // MARK: Cột

    private var cacCot: some View {
        GeometryReader { geo in
            let so = max(vm.cot.count, 1)
            let le = Spacing.md
            let khoang: CGFloat = 10
            // iPad/Mac: chia đều bề ngang khi đủ chỗ (≥ 240pt mỗi cột), không thì cuộn ngang. iPhone: cột gần bằng
            // màn (thấy mép cột sau) và cuộn BẬT TỪNG CỘT (viewAligned) — vuốt một cái là sang đúng cột kế.
            let deu = (geo.size.width - le * 2 - khoang * CGFloat(so - 1)) / CGFloat(so)
            let rongCot: CGFloat = rong ? max(250, deu) : min(340, geo.size.width - le * 2 - 34)
            ScrollView(.horizontal, showsIndicators: rong) {
                HStack(alignment: .top, spacing: khoang) {
                    ForEach(vm.cot) { c in
                        cot(c, rongCot: rongCot, cao: geo.size.height - 4)
                    }
                }
                .scrollTargetLayout()
                .padding(.bottom, 4)
            }
            .contentMargins(.horizontal, le, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .overlay {
                if vm.cot.isEmpty {
                    Text("This project has no board columns.")
                        .font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func khop(_ t: CTWIssueCard) -> Bool {
        if loc.chiCuaToi && t.assigneeId != appState.currentUser?.id { return false }
        if loc.chuaGiao && t.assigneeId != nil { return false }
        if loc.ganDay {
            guard let s = t.updatedAt,
                  let d = Self.iso.date(from: s) ?? ISO8601DateFormatter().date(from: s),
                  Date().timeIntervalSince(d) <= 2 * 86_400 else { return false }
        }
        if loc.tuanNay {
            // Như web: còn mở, có hạn, hạn ≤ cuối tuần này (Chủ nhật).
            guard t.resolvedAt == nil, vm.cauHinh?.trangThai(t.statusId)?.category != "DONE",
                  let han = CTW.ngay(t.dueDate) else { return false }
            if han > Self.cuoiTuan() { return false }
        }
        if !loc.nhan.isEmpty && Set(t.labelIds ?? []).isDisjoint(with: loc.nhan) { return false }
        let q = timChu.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return true }
        let ma = "\(vm.cauHinh?.key ?? "")-\(t.number)"
        return t.title.localizedCaseInsensitiveContains(q) || ma.localizedCaseInsensitiveContains(q)
    }

    /// Ngày Chủ nhật cuối tuần này theo lịch máy (`YYYY-MM-DD`).
    private static func cuoiTuan() -> String {
        var lich = Calendar(identifier: .gregorian)
        lich.timeZone = .current
        let hn = Date()
        let thu = lich.component(.weekday, from: hn)   // 1 = CN
        let them = thu == 1 ? 0 : 8 - thu
        return CTW.chuoiNgay(lich.date(byAdding: .day, value: them, to: hn) ?? hn)
    }

    private func cot(_ c: CTWBoardColumn, rongCot: CGFloat, cao: CGFloat) -> some View {
        let ds = vm.the(trongCot: c).filter(khop)
        let vuot = c.wipLimit.map { ds.count > $0 } ?? false
        let laDich = cotDich == c.key
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                CTWStatusGlyph(category: c.category, co: CTWCoChu.co(12))
                Text(verbatim: CTWKieuWeb.chuCau(c.name))
                    .font(.ctw(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                Text(c.wipLimit.map { "\(ds.count)/\($0)" } ?? "\(ds.count)")
                    .font(.ctw(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundColor(vuot ? .white : AppColors.textSecondary)
                    .padding(.horizontal, 7).padding(.vertical, 1.5)
                    .background(Capsule().fill(vuot ? AppColors.error : AppColors.backgroundCard))
                    .accessibilityLabel(vuot ? Text("\(ds.count) issues, over the limit of \(c.wipLimit ?? 0)") : Text("\(ds.count) issues"))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.top, 11).padding(.bottom, 9)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            // Dải màu nhóm dưới tiêu đề — như web, nhận ra cột "đang làm"/"xong" ngay cả khi lướt nhanh.
            Capsule().fill(CTWKieuWeb.mauNhom(c.category).opacity(0.55)).frame(height: 2)
                .padding(.horizontal, 12).padding(.bottom, 8)
                .accessibilityHidden(true)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(ds) { t in
                        theBang(t, rong: rongCot - 16)
                    }
                    if ds.isEmpty {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                            .foregroundColor(laDich ? AppColors.primary : AppColors.border)
                            .frame(height: 72)
                            .overlay {
                                if laDich { Text("Drop here").font(.ctw(size: 13, weight: .medium)).foregroundColor(AppColors.primary) }
                                else { Text("No issues").font(.ctw(size: 13)).foregroundColor(AppColors.textTertiary) }
                            }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
            .refreshable { await vm.tai() }
        }
        .frame(width: rongCot)
        .frame(maxHeight: max(cao, 200), alignment: .top)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(laDich ? AppColors.primary.opacity(0.10) : AppColors.backgroundTertiary))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(laDich ? AppColors.primary : Color.clear, lineWidth: 1.5))
        .animation(.easeOut(duration: 0.15), value: laDich)
        .dropDestination(for: String.self) { items, _ in
            cotDich = nil
            guard let s = items.first, let so = Int(s) else { return false }
            Task { _ = await vm.tha(soThe: so, vaoCot: c) }
            return true
        } isTargeted: { dang in
            if dang {
                if cotDich != c.key { CTWRung.chon() }
                cotDich = c.key
            } else if cotDich == c.key {
                cotDich = nil
            }
        }
    }

    @ViewBuilder
    private func theBang(_ t: CTWIssueCard, rong: CGFloat) -> some View {
        if let cfg = vm.cauHinh {
            NavigationLink(value: CTWRoute.the(pid: pid, so: t.number)) {
                CTWCardView(the: t, cauHinh: cfg)
            }
            .buttonStyle(.plain)
            .contextMenu { menuThe(t, cfg) }
            .modifier(KeoThe(so: t.number, bat: cfg.coTheChuyen) {
                // Ảnh kéo: chính tấm thẻ, nghiêng nhẹ như web (`rotate-[1.5deg]`).
                CTWCardView(the: t, cauHinh: cfg)
                    .frame(width: rong)
                    .rotationEffect(.degrees(1.5))
            })
        }
    }

    @ViewBuilder
    private func menuThe(_ t: CTWIssueCard, _ cfg: CTWProjectConfig) -> some View {
        if cfg.coTheChuyen {
            let dich = cfg.trangThaiDich(loai: t.typeId, tu: t.statusId).filter { $0.id != t.statusId }
            if dich.isEmpty {
                Text("No transitions available")
            } else {
                // "Move to…" — đường thay cho kéo thả (VoiceOver, một tay). Chỉ bước quy trình cho phép.
                Section("Move to…") {
                    ForEach(dich) { s in
                        Button { Task { await vm.chuyen(t, sang: s.id) } } label: {
                            Label { Text(verbatim: CTWKieuWeb.chuCau(s.name)) } icon: { Image(systemName: Self.bieuTuongNhom(s.category)) }
                        }
                    }
                }
            }
        } else {
            Text("You can view this project but not move issues")
        }
        Button { CTW.chepVaoBoNho("\(cfg.key)-\(t.number)") } label: { Label("Copy key", systemImage: "number") }
    }

    static func bieuTuongNhom(_ c: String?) -> String {
        switch c {
        case "DONE": return "checkmark.circle.fill"
        case "IN_PROGRESS": return "circle.lefthalf.filled"
        default: return "circle"
        }
    }
}

/// Kéo thẻ — chỉ bật khi có quyền chuyển trạng thái.
private struct KeoThe<AnhKeo: View>: ViewModifier {
    let so: Int
    let bat: Bool
    @ViewBuilder let anhKeo: () -> AnhKeo

    func body(content: Content) -> some View {
        if bat {
            content.draggable(String(so)) { anhKeo() }
        } else {
            content
        }
    }
}

// MARK: - Thẻ (kiểu web `BoardCard`)
//
// Thứ bậc như web: tiêu đề (14, ≤ 3 dòng) → nhãn (≤ 3, +N) → hàng dưới: loại + mã · bình luận … hạn · điểm · ưu tiên · người.

struct CTWCardView: View {
    let the: CTWIssueCard
    let cauHinh: CTWProjectConfig

    var body: some View {
        let xong = the.resolvedAt != nil || cauHinh.trangThai(the.statusId)?.category == "DONE"
        VStack(alignment: .leading, spacing: 8) {
            Text(the.title)
                .font(.ctw(size: 14, weight: xong ? .regular : .medium))
                .foregroundColor(xong ? AppColors.textTertiary : AppColors.textPrimary)
                .strikethrough(xong, color: AppColors.textTertiary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let nhan = nhanCuaThe, !nhan.isEmpty {
                HStack(spacing: 4) {
                    ForEach(nhan.prefix(3)) { l in CTWLabelChip(label: l) }
                    if nhan.count > 3 {
                        Text("+\(nhan.count - 3)").font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                    }
                }
            }

            HStack(spacing: 6) {
                CTWTypeIcon(type: cauHinh.loai(the.typeId), size: 12)
                Text(verbatim: "\(cauHinh.key)-\(the.number)")
                    .font(.ctw(size: 12, weight: .medium).monospaced())
                    .foregroundColor(xong ? AppColors.textTertiary : AppColors.textSecondary)
                    .strikethrough(xong)
                    .lineLimit(1)
                    .fixedSize()
                if let n = the.commentCount, n > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "bubble.left").font(.ctw(size: 10))
                        Text("\(n)").font(.ctw(size: 11).monospacedDigit())
                    }
                    .foregroundColor(AppColors.textTertiary)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("\(n) comments"))
                }
                Spacer(minLength: 0)
                CTWDueChip(dueDate: the.dueDate, xong: xong)
                if let sp = the.storyPoints { CTWPointsBadge(diem: sp) }
                CTWPriorityIcon(priority: the.priority)
                if the.assigneeId != nil {
                    CTWAvatar(user: cauHinh.thanhVien(the.assigneeId) ?? CTWUser(id: the.assigneeId ?? 0, username: "?"), size: 22)
                } else {
                    Circle().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [2.5, 2]))
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: 20, height: 20)
                        .accessibilityLabel(Text("Unassigned"))
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 11)
        .ctwThe(10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var nhanCuaThe: [CTWLabel]? {
        guard let ids = the.labelIds, !ids.isEmpty else { return nil }
        return (cauHinh.labels ?? []).filter { ids.contains($0.id) }
    }
}
