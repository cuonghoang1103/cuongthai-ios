import SwiftUI

// MARK: - Backlog: lên kế hoạch sprint (21/10/2026 — ngang web `Backlog.tsx`)
//
//   · Kéo thả thẻ giữa sprint ⇄ backlog ⇄ sprint khác, và kéo để XẾP HẠNG trong cùng khung. Rank là thứ tự TOÀN DỰ ÁN ⇒
//     chỉ gửi hai hàng xóm trong khung đích (`POST /issues/:n/move {sprintId?, beforeIssueId, afterIssueId, version}`,
//     logic thuần `CTWXepHang`). Vẽ lạc quan trước, hỏng (409 board đổi) ⇒ nạp lại + báo.
//   · Đường thay cho kéo (VoiceOver, một tay): menu nhấn giữ "Move to sprint…", "Move up/down", "Move to top/bottom".
//   · Chọn nhiều + thanh sửa hàng loạt (`CTWThanhHangLoat`, chung với Board/List): sprint, trạng thái, giao, ưu tiên…
//   · Tạo / bắt đầu / hoàn thành sprint: mô-đun Sprints (nút "Sprints" ở đầu và trên mỗi khung).
// ⚠️ Danh sách là ScrollView + LazyVStack (không `List`): `dropDestination` trên từng hàng mới cho chèn đúng chỗ; `.onMove`
// của List không đi xuyên Section.

@MainActor
final class KeHoachSprintVM: ObservableObject {
    let pid: Int
    @Published var cauHinh: CTWProjectConfig?
    @Published var backlog: CTWBacklog?
    /// Thẻ theo thứ tự rank toàn dự án (vẽ lạc quan khi kéo).
    @Published var ds: [CTWIssueCard] = []
    @Published var loi: String?
    @Published var bao: String?
    @Published var dangTai = false
    @Published var dangGui = false

    init(pid: Int) { self.pid = pid }

    func tai() async {
        dangTai = true
        defer { dangTai = false }
        do {
            if cauHinh == nil { cauHinh = try await APIClient.shared.request(.workDuAn(pid: pid)) }
            let b: CTWBacklog = try await APIClient.shared.request(CTWAPI.backlog(pid: pid))
            backlog = b
            ds = b.issues ?? []
            loi = nil
        } catch { loi = CTW.loi(error) }
    }

    /// Sprint đang mở: ACTIVE trước, rồi PLANNED (như máy chủ trả).
    var sprints: [CTWSprint] { (backlog?.sprints ?? []).filter { $0.state != "CLOSED" } }

    func trongKhung(_ sid: Int?) -> [CTWIssueCard] { ds.filter { $0.sprintId == sid } }

    /// Di chuyển: `khung` = sprint đích (nil = backlog), `ketQua` = vị trí trong khung đích.
    func diChuyen(_ t: CTWIssueCard, khung: Int?, _ kq: CTWXepHang.KetQua) async {
        let cu = ds
        // Lạc quan: bỏ thẻ ra, đổi sprint, chèn trước hàng xóm dưới (hoặc sau hàng xóm trên) trong mảng toàn cục.
        var moi = ds.filter { $0.id != t.id }
        var m = t
        m.sprintId = khung
        if let sau = kq.sau, let i = moi.firstIndex(where: { $0.id == sau }) { moi.insert(m, at: i) }
        else if let truoc = kq.truoc, let i = moi.firstIndex(where: { $0.id == truoc }) { moi.insert(m, at: i + 1) }
        else { moi.append(m) }
        ds = moi
        CTWRung.chon()
        do {
            try await APIClient.shared.send(CTWAPI.diChuyen(pid: pid, so: t.number, sprint: khung == t.sprintId ? nil : .some(khung),
                                                            truoc: kq.truoc, sau: kq.sau, version: t.version))
            CTWRung.thanhCong()
        } catch {
            ds = cu
            loi = CTW.laXungDot(error) ? String(localized: "The backlog changed while you were dragging. It has been refreshed — try again.") : CTW.loi(error)
            CTWRung.loi()
        }
        await taiLaiIm()
    }

    /// Nạp lại không hiện khung tải (lấy version/rank mới).
    func taiLaiIm() async {
        if let b: CTWBacklog = try? await APIClient.shared.request(CTWAPI.backlog(pid: pid)) {
            backlog = b
            ds = b.issues ?? []
        }
    }

    /// Thả thẻ số `so` vào khung `khung`, ngay trên thẻ `chenTruoc` (nil = cuối khung).
    func tha(so: Int, khung: Int?, chenTruoc: Int?) async -> Bool {
        guard let t = ds.first(where: { $0.number == so }) else { return false }
        let dich = trongKhung(khung).map(\.id)
        guard let kq = CTWXepHang.viTriTha(dich: dich, dangKeo: t.id, chenTruoc: chenTruoc) else { return false }
        await diChuyen(t, khung: khung, kq)
        return true
    }

    func hangLoat(_ chon: [CTWIssueCard], patch: [String: Any]?, tenTrangThai: String?, nhan: String) async -> Set<Int> {
        guard let cfg = cauHinh, !chon.isEmpty else { return [] }
        dangGui = true
        defer { dangGui = false }
        do {
            let kq = try await CTWHangLoat.apDung(pid: pid, cfg: cfg, the: chon, patch: patch, tenTrangThai: tenTrangThai)
            let cau = CTWBaoHangLoat.cau(kq, nhan: nhan, ma: cfg.key)
            bao = cau.thanhCong
            loi = cau.loi
            await taiLaiIm()
            let hong = Set((kq.failed ?? []).map(\.number))
            return Set(chon.filter { hong.contains($0.number) }.map(\.id))
        } catch {
            loi = CTW.loi(error)
            return Set(chon.map(\.id))
        }
    }
}

struct KeHoachSprintCTW: View {
    let pid: Int
    @StateObject private var vm: KeHoachSprintVM
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var tim = ""
    @State private var moTao = false
    @State private var dangChon = false
    @State private var chon: Set<Int> = []
    @State private var hoiXoa = false
    /// Đích thả đang lơ lửng: "<khung>|<id thẻ>" hoặc "<khung>|end".
    @State private var dich: String?
    @State private var gap: Set<String> = []

    init(pid: Int) {
        self.pid = pid
        _vm = StateObject(wrappedValue: KeHoachSprintVM(pid: pid))
    }

    private var q: String { tim.trimmingCharacters(in: .whitespaces) }

    private func hien(_ ds: [CTWIssueCard]) -> [CTWIssueCard] {
        guard !q.isEmpty, let k = vm.cauHinh?.key else { return ds }
        return ds.filter { $0.title.localizedCaseInsensitiveContains(q) || "\(k)-\($0.number)".localizedCaseInsensitiveContains(q) }
    }

    private var quyenSua: Bool { vm.cauHinh?.coTheSua == true }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if let loi = vm.loi { CTWErrorBanner(text: loi) { vm.loi = nil } }
                if let cfg = vm.cauHinh {
                    ForEach(vm.sprints) { s in khung(cfg, sprint: s) }
                    khung(cfg, sprint: nil)
                    if vm.backlog?.truncated == true {
                        Text("Showing the first \(vm.ds.count) of \(vm.backlog?.total ?? vm.ds.count) issues.")
                            .font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                    }
                    if cfg.type != "KANBAN" && cfg.permissions?.manageSprints == true {
                        Button { moSprints() } label: {
                            Label("Create, start or complete sprints", systemImage: "flag.checkered")
                                .font(.ctw(size: 14, weight: .medium)).frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, 20)
        }
        .background(AppColors.backgroundPrimary)
        .overlay { if vm.dangTai && vm.cauHinh == nil { CTWKhungTai(soHang: 6) } }
        .overlay(alignment: .top) {
            if let b = vm.bao {
                CTWDaiBao(chu: b).padding(.top, 6)
                    .task(id: b) { try? await Task.sleep(nanoseconds: 2_800_000_000); vm.bao = nil }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if dangChon, let cfg = vm.cauHinh {
                CTWThanhHangLoat(cauHinh: cfg, soChon: chon.count, dangGui: vm.dangGui, epics: nil,
                                 doiTrangThai: { ten in gui(nil, ten, String(localized: "moved to \(CTWTen.trangThai(ten))")) },
                                 sua: { p, n in gui(p, nil, n) },
                                 xoa: { hoiXoa = true },
                                 boChon: { dangChon = false; chon = [] })
            }
        }
        .confirmationDialog(chon.count == 1 ? Text("Delete 1 issue?") : Text("Delete \(chon.count) issues?"), isPresented: $hoiXoa, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { gui(["delete": true], nil, String(localized: "deleted")) }
        } message: { Text("Deleted issues go to the project trash.") }
        .searchable(text: $tim, placement: .toolbar, prompt: "Search title or key")
        .refreshable { await vm.tai() }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    if quyenSua {
                        Button { dangChon.toggle(); if !dangChon { chon = [] } } label: {
                            Label(dangChon ? "Done selecting" : "Select issues", systemImage: "checkmark.circle")
                        }
                    }
                    if vm.cauHinh?.type != "KANBAN" {
                        Button { moSprints() } label: { Label("Sprints", systemImage: "flag.checkered") }
                    }
                    if !gap.isEmpty { Button { gap = [] } label: { Label("Expand all", systemImage: "rectangle.expand.vertical") } }
                } label: { Image(systemName: dangChon ? "checkmark.circle.fill" : "ellipsis.circle") }
                .accessibilityLabel("Backlog options")
                if vm.cauHinh?.coTheTao == true && !dangChon {
                    Button { moTao = true } label: { Image(systemName: "plus") }.accessibilityLabel("Create issue")
                }
            }
        }
        .sheet(isPresented: $moTao) {
            if let cfg = vm.cauHinh {
                CTWCreateIssueView(cauHinh: cfg, sprintId: nil) { _ in Task { await vm.taiLaiIm() } }
            }
        }
        .task { if vm.backlog == nil { await vm.tai() } }
        #if DEBUG
        .onAppear { if ProcessInfo.processInfo.environment["CT_XEM_CHON"] != nil { dangChon = true; chon = [117, 120] } }
        #endif
    }

    private func moSprints() {
        nganXep.duong.append(RouteMoDunCTW(id: "sprints"))
    }

    private func gui(_ patch: [String: Any]?, _ ten: String?, _ nhan: String) {
        let ds = vm.ds.filter { chon.contains($0.id) }
        Task {
            let hong = await vm.hangLoat(ds, patch: patch, tenTrangThai: ten, nhan: nhan)
            chon = hong
            if hong.isEmpty && patch?["delete"] != nil { dangChon = false }
        }
    }

    // MARK: Khung (sprint / backlog)

    private func khoa(_ s: CTWSprint?) -> String { s.map { "s\($0.id)" } ?? "backlog" }

    @ViewBuilder
    private func khung(_ cfg: CTWProjectConfig, sprint s: CTWSprint?) -> some View {
        let tatCa = vm.trongKhung(s?.id)
        let ds = hien(tatCa)
        let k = khoa(s)
        let daGap = gap.contains(k)
        VStack(alignment: .leading, spacing: 0) {
            dauKhung(cfg, s, tatCa: tatCa, daGap: daGap) {
                CTWRung.chon()
                if daGap { gap.remove(k) } else { gap.insert(k) }
            }
            if !daGap {
                Divider()
                if ds.isEmpty {
                    oTrongKhung(s, k: k)
                }
                ForEach(ds) { t in hang(t, cfg, khung: s?.id, k: k) }
                if !ds.isEmpty { vungCuoi(s?.id, k: k) }
            }
        }
        .ctwThe(12)
        .dropDestination(for: String.self) { items, _ in thaCuoi(items, s?.id) } isTargeted: { doiDich($0, "\(k)|end") }
    }

    private func dauKhung(_ cfg: CTWProjectConfig, _ s: CTWSprint?, tatCa: [CTWIssueCard], daGap: Bool, doi: @escaping () -> Void) -> some View {
        let xong = tatCa.filter { cfg.trangThai($0.statusId)?.category == "DONE" }.count
        let diem = tatCa.compactMap(\.storyPoints).reduce(0, +)
        return Button(action: doi) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Image(systemName: daGap ? "chevron.right" : "chevron.down")
                        .font(.ctw(size: 11, weight: .semibold)).foregroundColor(AppColors.textTertiary).frame(width: 12)
                    if let s {
                        Image(systemName: s.state == "ACTIVE" ? "flag.fill" : "flag")
                            .foregroundColor(s.state == "ACTIVE" ? AppColors.primary : AppColors.textSecondary)
                        Text(verbatim: s.name).lineLimit(1)
                        if s.state == "ACTIVE" {
                            Text("ACTIVE").font(.ctw(size: 10, weight: .bold)).foregroundColor(AppColors.primary)
                                .padding(.horizontal, 6).padding(.vertical, 1)
                                .background(Capsule().fill(AppColors.primary.opacity(0.12))).fixedSize()
                        }
                    } else {
                        Image(systemName: "tray.full").foregroundColor(AppColors.textSecondary)
                        Text("Backlog")
                    }
                    Spacer(minLength: 4)
                    (tatCa.count == 1 ? Text("1 issue") : Text("\(tatCa.count) issues"))
                        .font(.ctw(size: 12).monospacedDigit()).foregroundColor(AppColors.textTertiary).fixedSize()
                }
                .font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                HStack(spacing: 8) {
                    if let s, let a = CTW.ngayNgan(s.startAt), let b = CTW.ngayNgan(s.endAt) {
                        Text(verbatim: "\(a) – \(b)")
                    }
                    if diem > 0 { Text("\(CTWDinhDang.so(Int(diem.rounded()))) pts") }
                    if s != nil && !tatCa.isEmpty { Text("\(xong)/\(tatCa.count) done") }
                }
                .font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                .padding(.leading, 19)
                if s != nil && !tatCa.isEmpty {
                    ProgressView(value: Double(xong), total: Double(tatCa.count)).tint(AppColors.success).padding(.leading, 19)
                }
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isHeader)
        .accessibilityValue(daGap ? Text("Collapsed") : Text("Expanded"))
        .contextMenu {
            if cfg.type != "KANBAN" { Button { moSprints() } label: { Label("Sprints", systemImage: "flag.checkered") } }
        }
    }

    private func oTrongKhung(_ s: CTWSprint?, k: String) -> some View {
        let laDich = dich == "\(k)|end"
        return (laDich ? Text("Drop here") : (s == nil ? Text("The backlog is empty") : Text("Drag issues here to plan this sprint")))
            .font(.ctw(size: 13)).foregroundColor(laDich ? AppColors.primary : AppColors.textTertiary)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .foregroundColor(laDich ? AppColors.primary : AppColors.border))
            .padding(10)
    }

    /// Dải cuối khung — thả vào đây = xuống cuối.
    private func vungCuoi(_ sid: Int?, k: String) -> some View {
        Rectangle().fill(dich == "\(k)|end" ? AppColors.primary : Color.clear).frame(height: 3)
            .padding(.horizontal, 12).padding(.bottom, 6)
            .accessibilityHidden(true)
    }

    private func doiDich(_ dang: Bool, _ k: String) {
        if dang { if dich != k { CTWRung.chon() }; dich = k } else if dich == k { dich = nil }
    }

    private func thaCuoi(_ items: [String], _ sid: Int?) -> Bool {
        dich = nil
        guard quyenSua, let s = items.first, let so = Int(s) else { return false }
        Task { _ = await vm.tha(so: so, khung: sid, chenTruoc: nil) }
        return true
    }

    // MARK: Hàng

    @ViewBuilder
    private func hang(_ t: CTWIssueCard, _ cfg: CTWProjectConfig, khung sid: Int?, k: String) -> some View {
        let khoaDich = "\(k)|\(t.id)"
        VStack(spacing: 0) {
            // Vạch chèn: thẻ đang kéo sẽ đứng NGAY TRÊN hàng này.
            Rectangle().fill(dich == khoaDich ? AppColors.primary : Color.clear).frame(height: 3)
                .padding(.horizontal, 12)
            noiDungHang(t, cfg)
                .padding(.horizontal, 12).padding(.vertical, 7)
            Divider().padding(.leading, 44)
        }
        .contextMenu { menuHang(t, cfg, khung: sid) }
        .modifier(KeoHangCTW(so: t.number, bat: quyenSua && !dangChon))
        .dropDestination(for: String.self) { items, _ in
            dich = nil
            guard quyenSua, let s = items.first, let so = Int(s) else { return false }
            Task { _ = await vm.tha(so: so, khung: sid, chenTruoc: t.id) }
            return true
        } isTargeted: { doiDich($0, khoaDich) }
    }

    @ViewBuilder
    private func noiDungHang(_ t: CTWIssueCard, _ cfg: CTWProjectConfig) -> some View {
        if dangChon {
            let da = chon.contains(t.id)
            Button {
                CTWRung.chon()
                if da { chon.remove(t.id) } else { chon.insert(t.id) }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: da ? "checkmark.circle.fill" : "circle")
                        .font(.ctw(size: 20)).foregroundColor(da ? AppColors.primary : AppColors.textTertiary)
                    HangTheCTW(the: t, cfg: cfg)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(da ? .isSelected : [])
        } else {
            NavigationLink(value: CTWRoute.the(pid: pid, so: t.number)) {
                HangTheCTW(the: t, cfg: cfg).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func menuHang(_ t: CTWIssueCard, _ cfg: CTWProjectConfig, khung sid: Int?) -> some View {
        if quyenSua {
            if cfg.type != "KANBAN" {
                Menu {
                    ForEach(vm.sprints.filter { $0.id != sid }) { s in
                        Button { Task { _ = await vm.tha(so: t.number, khung: s.id, chenTruoc: nil) } } label: {
                            if s.state == "ACTIVE" { Text("\(s.name) (active)") } else { Text(verbatim: s.name) }
                        }
                    }
                    if sid != nil {
                        Button { Task { _ = await vm.tha(so: t.number, khung: nil, chenTruoc: nil) } } label: { Label("Backlog", systemImage: "tray.full") }
                    }
                } label: { Label("Move to sprint…", systemImage: "arrow.left.arrow.right") }
            }
            let ids = vm.trongKhung(sid).map(\.id)
            if let kq = CTWXepHang.dichMotBac(dich: ids, the: t.id, len: true) {
                Button { Task { await vm.diChuyen(t, khung: sid, kq) } } label: { Label("Move up", systemImage: "arrow.up") }
            }
            if let kq = CTWXepHang.dichMotBac(dich: ids, the: t.id, len: false) {
                Button { Task { await vm.diChuyen(t, khung: sid, kq) } } label: { Label("Move down", systemImage: "arrow.down") }
            }
            if ids.first != t.id, let kq = CTWXepHang.viTriTha(dich: ids, dangKeo: t.id, chenTruoc: ids.first) {
                Button { Task { await vm.diChuyen(t, khung: sid, kq) } } label: { Label("Move to top", systemImage: "arrow.up.to.line") }
            }
            if ids.last != t.id, let kq = CTWXepHang.viTriTha(dich: ids, dangKeo: t.id, chenTruoc: nil) {
                Button { Task { await vm.diChuyen(t, khung: sid, kq) } } label: { Label("Move to bottom", systemImage: "arrow.down.to.line") }
            }
            Button { dangChon = true; chon = [t.id] } label: { Label("Select", systemImage: "checkmark.circle") }
        }
        Button { CTW.chepVaoBoNho("\(cfg.key)-\(t.number)") } label: { Label("Copy key", systemImage: "number") }
    }
}

/// Kéo hàng — chỉ khi sửa được thẻ.
private struct KeoHangCTW: ViewModifier {
    let so: Int
    let bat: Bool
    func body(content: Content) -> some View {
        if bat { content.draggable(String(so)) } else { content }
    }
}

/// Một hàng thẻ gọn (Backlog / List): loại · tiêu đề · mã · ưu tiên · trạng thái · hạn · điểm · người.
struct HangTheCTW: View {
    let the: CTWIssueCard
    let cfg: CTWProjectConfig

    var body: some View {
        let t = the
        HStack(spacing: 10) {
            CTWTypeIcon(type: cfg.loai(t.typeId), size: 14)
            VStack(alignment: .leading, spacing: 4) {
                Text(t.title).font(.ctw(size: 15)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                    .multilineTextAlignment(.leading)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 7) { siHang; CTWDueChip(dueDate: t.dueDate, xong: t.resolvedAt != nil) }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 7) { siHang }
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
    }

    @ViewBuilder private var siHang: some View {
        Text(verbatim: "\(cfg.key)-\(the.number)").font(.ctw(size: 12, weight: .medium).monospaced())
            .foregroundColor(the.resolvedAt != nil ? AppColors.textTertiary : AppColors.primary)
            .strikethrough(the.resolvedAt != nil)
            .fixedSize()
        CTWPriorityIcon(priority: the.priority)
        if let s = cfg.trangThai(the.statusId) { CTWStatusChip(status: s).fixedSize() }
    }
}
