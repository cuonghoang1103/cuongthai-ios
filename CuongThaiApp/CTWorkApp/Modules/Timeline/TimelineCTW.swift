import SwiftUI

// MARK: - Timeline / Roadmap
//
// Hai chế độ:
//   · List  — mặc định trên iPhone: thẻ nhóm theo THÁNG (hạn, không có thì ngày bắt đầu), mỗi hàng
//     có chip ngày + thanh tiến độ. Đọc nhanh khi đang ở ngoài.
//   · Gantt — mặc định trên iPad: cột tên cố định + trục ngày cuộn ngang, thanh theo start/due,
//     mũi tên phụ thuộc BLOCKS, đường Today, hàng mốc (sprint · stage · version).
// Nguồn: `GET /timeline` + `GET /timeline/markers` (+ `cfg.sprints` để sửa ngày sprint lệch UTC).

@MainActor
final class TimelineVM: ObservableObject {
    let pid: Int
    @Published var trangThai: TaiCTW<TLDuLieuCTW> = .dangTai
    @Published var moc = TLMocCTW()
    @Published var cauHinh: CTWProjectConfig?

    init(pid: Int) { self.pid = pid }

    func tai(cfg: CTWProjectConfig?) async {
        if cauHinh == nil { cauHinh = cfg }
        do {
            async let d: TLDuLieuCTW = APIClient.shared.request(CTWAPI.dongThoiGian(pid: pid))
            async let m: TLMocCTW? = try? APIClient.shared.request(CTWAPI.mocThoiGian(pid: pid))
            if cauHinh == nil { cauHinh = try? await APIClient.shared.request(.workDuAn(pid: pid)) }
            let du = try await d
            moc = await m ?? TLMocCTW()
            trangThai = .xong(du)
        } catch {
            if trangThai.giaTri == nil { trangThai = .loi(CTW.loi(error)) }
        }
    }

    /// Khoảng ngày sprint: ưu tiên `cfg.sprints` (ISO thật ⇒ đổi đúng sang ngày VN), sprint đã đóng
    /// (không có trong cfg) lấy từ markers.
    var khoangSprint: TLBoDungCTW.Khoang {
        var k: TLBoDungCTW.Khoang = [:]
        for s in moc.sprints ?? [] {
            if let a = NgayCTW.ngay(s.start), let b = NgayCTW.ngay(s.end) { k[s.id] = (a, max(a, b)) }
        }
        for s in cauHinh?.sprints ?? [] {
            if let a = NgayCTW.ngay(NgayCTW.ngayCua(s.startAt)), let b = NgayCTW.ngay(NgayCTW.ngayCua(s.endAt)) { k[s.id] = (a, max(a, b)) }
        }
        return k
    }

    var khoangVersion: TLBoDungCTW.Khoang {
        var k: TLBoDungCTW.Khoang = [:]
        for v in moc.versions ?? [] {
            guard let r = NgayCTW.ngay(v.release) else { continue }
            let s = NgayCTW.ngay(v.start) ?? NgayCTW.cong(r, ngay: -13)
            k[v.id] = (min(s, r), r)
        }
        return k
    }
}

struct TimelineCTW: View {
    let pid: Int
    @StateObject private var vm: TimelineVM
    @EnvironmentObject private var app: AppState
    @Environment(\.horizontalSizeClass) private var beRong
    @State private var cheDo: CheDo?
    @State private var zoom: TLZoomCTW = .tuan
    /// nil = mọi người · 0 = chưa giao · id người
    @State private var nguoi: Int?
    @State private var phienBan: Int?
    @State private var anKhongLich = false

    enum CheDo: String, CaseIterable, Identifiable {
        case danhSach = "List", gantt = "Gantt"
        var id: String { rawValue }
    }

    init(pid: Int) {
        self.pid = pid
        _vm = StateObject(wrappedValue: TimelineVM(pid: pid))
    }

    private var cheDoHien: CheDo { cheDo ?? (beRong == .regular ? .gantt : .danhSach) }

    var body: some View {
        KhungTaiCTW(trangThai: vm.trangThai, thuLai: { Task { await vm.tai(cfg: app.cauHinhDuAn) } }) { d in
            noiDung(d)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Timeline")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .primaryAction) { menuLoc } }
        .task { await vm.tai(cfg: app.cauHinhDuAn) }
        .refreshable { await vm.tai(cfg: app.cauHinhDuAn) }
        .task(id: app.dichCho) {
            // Deep link `/work/<ws>/<KEY>/timeline` — màn đã mở là đủ; xoá cờ ở CUỐI (KIEN_TRUC mục 6).
            guard app.dichCho?.moDun == "timeline" else { return }
            app.dichCho = nil
        }
        #if DEBUG
        .onAppear {
            if let c = XemThuCTW.conCua("timeline") { cheDo = c == "gantt" ? .gantt : (c == "list" ? .danhSach : cheDo) }
        }
        #endif
    }

    // MARK: Nội dung

    @ViewBuilder
    private func noiDung(_ d: TLDuLieuCTW) -> some View {
        let tatCa = d.items ?? []
        let ds = tatCa.filter(locMuc)
        let thanh = TLBoDungCTW.tatCaThanh(tatCa, sprint: vm.khoangSprint, version: vm.khoangVersion)
        VStack(spacing: 0) {
            thanhDieuKhien(d, ds: ds, thanh: thanh)
            if ds.isEmpty {
                CTWOTrong(bieuTuong: "calendar.day.timeline.left", tieuDe: tatCa.isEmpty ? "Nothing on the roadmap yet" : "No issues match",
                          moTa: tatCa.isEmpty ? "Add start and due dates to epics and issues to see them here." : "Try a different assignee or version filter.")
                    .frame(maxHeight: .infinity)
            } else if cheDoHien == .gantt {
                GanttTLCTW(pid: pid, du: d, ds: ds, thanh: thanh, moc: vm.moc, khoangSprint: vm.khoangSprint,
                           cfg: vm.cauHinh, zoom: zoom, anKhongLich: anKhongLich, rong: beRong == .regular)
            } else {
                danhSach(ds, thanh: thanh)
            }
        }
    }

    private func locMuc(_ m: TLMucCTW) -> Bool {
        if let n = nguoi {
            // Epic giữ lại nếu có con khớp — để cây không mất gốc.
            if m.laEpic {
                let con = (vm.trangThai.giaTri?.items ?? []).filter { $0.parentId == m.id }
                if !(con.contains { ($0.assigneeId ?? 0) == n } || (m.assigneeId ?? 0) == n) { return false }
            } else if (m.assigneeId ?? 0) != n { return false }
        }
        if let v = phienBan, !m.laEpic, m.fixVersionId != v { return false }
        return true
    }

    private func thanhDieuKhien(_ d: TLDuLieuCTW, ds: [TLMucCTW], thanh: [Int: TLThanhCTW]) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Picker("View", selection: Binding(get: { cheDoHien }, set: { cheDo = $0 })) {
                    ForEach(CheDo.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
                if cheDoHien == .gantt {
                    Picker("Zoom", selection: $zoom) {
                        ForEach(TLZoomCTW.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)
                }
                Spacer(minLength: 0)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    let coLich = ds.filter { thanh[$0.id] != nil }.count
                    chip("calendar", "\(coLich) scheduled", AppColors.textSecondary)
                    if ds.count - coLich > 0 { chip("calendar.badge.exclamationmark", "\(ds.count - coLich) unscheduled", AppColors.textSecondary) }
                    let canh = d.dependencies?.count ?? 0
                    if canh > 0 { chip("arrow.triangle.branch", "\(canh) dependencies", AppColors.textSecondary) }
                    let xd = d.conflicts?.count ?? 0
                    if xd > 0 { chip("exclamationmark.triangle.fill", "\(xd) scheduling conflict\(xd == 1 ? "" : "s")", AppColors.error) }
                    if let cd = d.criticalDays, cd > 0, (d.criticalPath?.count ?? 0) >= 2 {
                        chip("bolt.horizontal.fill", "Critical path \(cd)d", AppColors.accent)
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 8)
        .background(AppColors.backgroundPrimary)
    }

    private func chip(_ icon: String, _ chu: String, _ mau: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.ctw(size: 10, weight: .semibold)).foregroundColor(mau)
            Text(chu).font(.ctw(size: 12, weight: .medium)).foregroundColor(AppColors.textSecondary).fixedSize()
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Capsule().fill(AppColors.backgroundCard))
        .overlay(Capsule().strokeBorder(AppColors.border, lineWidth: 0.5))
    }

    private var menuLoc: some View {
        Menu {
            Picker("Assignee", selection: $nguoi) {
                Text("Anyone").tag(Int?.none)
                if let toi = app.currentUser?.id { Text("Me").tag(Int?.some(toi)) }
                Text("Unassigned").tag(Int?.some(0))
                ForEach((vm.cauHinh?.dsThanhVien ?? []).filter { $0.id != app.currentUser?.id }) { u in
                    Text(u.laAgent ? "\(u.ten) · AI agent" : u.ten).tag(Int?.some(u.id))
                }
            }
            .pickerStyle(.menu)
            let pb = vm.moc.versions ?? []
            if !pb.isEmpty {
                Picker("Version", selection: $phienBan) {
                    Text("All versions").tag(Int?.none)
                    ForEach(pb) { v in Text(v.name ?? "Version").tag(Int?.some(v.id)) }
                }
                .pickerStyle(.menu)
            }
            Toggle("Hide unscheduled", isOn: $anKhongLich)
        } label: {
            Image(systemName: (nguoi != nil || phienBan != nil || anKhongLich) ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("Filters")
    }

    // MARK: Danh sách theo tháng

    private func danhSach(_ ds: [TLMucCTW], thanh: [Int: TLThanhCTW]) -> some View {
        let tenEpic = Dictionary(uniqueKeysWithValues: (vm.trangThai.giaTri?.items ?? []).filter(\.laEpic).map { ($0.id, $0.title) })
        let nhom = TLBoDungCTW.theoThang(ds, thanh: thanh).filter { !(anKhongLich && $0.thang == nil) }
        return List {
            ForEach(nhom, id: \.thang) { n in
                Section {
                    ForEach(n.ds) { m in
                        NavigationLink(value: CTWRoute.the(pid: pid, so: m.number)) {
                            HangTLCTW(muc: m, thanh: thanh[m.id], cfg: vm.cauHinh, tenEpic: m.parentId.flatMap { tenEpic[$0] })
                        }
                    }
                } header: {
                    HStack {
                        Text(n.thang.map(NgayCTW.thang) ?? "Unscheduled")
                        Spacer()
                        Text("\(n.ds.count)").foregroundColor(AppColors.textTertiary)
                    }
                    .font(.ctw(size: 13, weight: .semibold))
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}

/// Một hàng ở chế độ danh sách.
struct HangTLCTW: View {
    let muc: TLMucCTW
    let thanh: TLThanhCTW?
    let cfg: CTWProjectConfig?
    let tenEpic: String?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            CTWTypeIcon(type: muc.typeId.flatMap { cfg?.loai($0) }, size: 14).padding(.top, 2)
            VStack(alignment: .leading, spacing: 5) {
                Text(muc.title).font(.ctw(size: 15, weight: muc.laEpic ? .semibold : .regular))
                    .foregroundColor(AppColors.textPrimary).lineLimit(2)
                HStack(spacing: 6) {
                    Text("\(cfg?.key ?? "#")-\(muc.number)").font(.ctw(size: 11, weight: .medium).monospaced())
                        .foregroundColor(AppColors.textSecondary).strikethrough(muc.done == true)
                    if let tenEpic {
                        Text(tenEpic).font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary).lineLimit(1)
                    }
                }
                HStack(spacing: 8) {
                    chipNgay
                    if !(muc.done ?? false) || (muc.progress ?? 0) > 0 {
                        CTWThanhTienDo(doan: [CTWDoanTienDo(ten: "Done", giaTri: muc.progress ?? 0, mau: AppColors.success),
                                              CTWDoanTienDo(ten: "Remaining", giaTri: max(1 - (muc.progress ?? 0), 0), mau: AppColors.backgroundTertiary)],
                                       cao: 5)
                            .frame(maxWidth: 90)
                        Text("\(Int(((muc.progress ?? 0) * 100).rounded()))%").font(.ctw(size: 11).monospacedDigit())
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            Spacer(minLength: 0)
            if let a = muc.assigneeId {
                CTWAvatar(user: cfg?.thanhVien(a) ?? CTWUser(id: a), size: 24)
            }
        }
        .padding(.vertical, 3)
    }

    private var quaHan: Bool {
        guard !(muc.done ?? false), let d = NgayCTW.ngay(muc.due) else { return false }
        return NgayCTW.soNgay(d, Date()) > 0
    }

    @ViewBuilder private var chipNgay: some View {
        let chu: String = {
            guard let t = thanh else { return "No dates" }
            let a = NgayCTW.ngan(t.batDau), b = NgayCTW.ngan(t.ketThuc)
            switch t.kieu {
            case .motNgay: return "Due \(b)"
            case .moDuoi: return "From \(a)"
            case .suyRa: return a == b ? "~ \(a)" : "~ \(a) – \(b)"
            case .day: return a == b ? a : "\(a) – \(b)"
            }
        }()
        HStack(spacing: 3) {
            if quaHan { Image(systemName: "exclamationmark.circle.fill").font(.ctw(size: 9, weight: .bold)) }
            Text(chu).font(.ctw(size: 11, weight: .semibold)).fixedSize()
        }
        .foregroundColor(quaHan ? AppColors.error : (muc.done == true ? AppColors.success : AppColors.textSecondary))
        .padding(.horizontal, 7).padding(.vertical, 2)
        .background(Capsule().fill((quaHan ? AppColors.error : AppColors.textTertiary).opacity(0.12)))
        .accessibilityLabel(quaHan ? "\(chu), overdue" : chu)
    }
}
