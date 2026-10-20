import SwiftUI

// MARK: - Chi tiết một sprint: mục tiêu · chỉ số · burndown/burnup · tiến độ điểm & số thẻ · báo cáo
//
// Nguồn: `GET /sprints` (sprint đầy đủ), `/reports/burndown`, `/reports/sprint`, và
// `GET /issues?sprint=<id>&includeDone=true` (đếm thẻ theo nhóm trạng thái của quy trình).
// Sprint chưa bắt đầu ⇒ không có burndown (máy chủ trả `points: []`) — chỉ hiện danh sách thẻ.

@MainActor
final class ChiTietSprintVM: ObservableObject {
    let pid: Int
    let sid: Int
    @Published var sprint: CTWSprintDu?
    @Published var dsSprint: [CTWSprintDu] = []
    @Published var burndown: CTWBurndown?
    @Published var baoCao: CTWSprintReport?
    @Published var the: [CTWIssueCard] = []
    @Published var trangThai: TaiCTW<Bool> = .dangTai
    @Published var loi: String?

    init(pid: Int, sid: Int) { self.pid = pid; self.sid = sid }

    func tai() async {
        do {
            let ds: [CTWSprintDu] = try await APIClient.shared.request(CTWAPI.dsSprint(pid: pid))
            dsSprint = ds
            guard let s = ds.first(where: { $0.id == sid }) else {
                trangThai = .loi(String(localized: "This sprint no longer exists."))
                return
            }
            sprint = s
            var loc = CTWAPI.BoLoc()
            loc.sprint = String(sid)
            loc.includeDone = true
            async let dsThe: CTWIssueList = APIClient.shared.request(CTWAPI.dsThe(pid: pid, loc: loc, limit: 200))
            if !s.chuaBatDau {
                async let bd: CTWBurndown = APIClient.shared.request(CTWAPI.burndown(pid: pid, sid: sid))
                async let bc: CTWBaoCaoSprint = APIClient.shared.request(CTWAPI.baoCaoSprint(pid: pid, sid: sid))
                burndown = try? await bd
                baoCao = (try? await bc)?.report
            }
            // Máy chủ đã lọc theo sprint; lọc lại ở máy để chắc (máy chủ giả trả mọi thẻ).
            the = ((try await dsThe).items ?? []).filter { $0.sprintId == sid }
            trangThai = .xong(true)
        } catch {
            if trangThai.giaTri == nil { trangThai = .loi(CTW.loi(error)) } else { loi = CTW.loi(error) }
        }
    }

    func ghi(_ e: APIEndpoint) async -> String? {
        do {
            try await APIClient.shared.send(e)
            CTWRung.thanhCong()
            await tai()
            return nil
        } catch {
            CTWRung.loi()
            return CTW.loi(error)
        }
    }
}

struct ChiTietSprintCTW: View {
    let pid: Int
    let sid: Int
    @StateObject private var vm: ChiTietSprintVM
    @EnvironmentObject private var app: AppState
    @Environment(\.horizontalSizeClass) private var beRong
    @State private var tamPhu: TamPhuSprintCTW?

    init(pid: Int, sid: Int) {
        self.pid = pid
        self.sid = sid
        _vm = StateObject(wrappedValue: ChiTietSprintVM(pid: pid, sid: sid))
    }

    private var cfg: CTWProjectConfig? { app.cauHinhDuAn }
    private var quanLy: Bool { cfg?.permissions?.manageSprints == true }
    private var rong: Bool { beRong == .regular }

    var body: some View {
        KhungTaiCTW(trangThai: vm.trangThai, thuLai: { Task { await vm.tai() } }) { _ in
            if let s = vm.sprint { noiDung(s) }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(vm.sprint?.ten ?? String(localized: "Sprint"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if quanLy, let s = vm.sprint, !s.daDong {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { tamPhu = .sua(s) } label: { Label("Edit", systemImage: "pencil") }
                        if s.chuaBatDau { Button { tamPhu = .batDau(s) } label: { Label("Start sprint", systemImage: "play.fill") } }
                        if s.dangChay { Button { tamPhu = .hoanTat(s) } label: { Label("Complete sprint", systemImage: "checkmark.seal") } }
                    } label: { Image(systemName: "ellipsis.circle") }
                    .accessibilityLabel("Sprint actions")
                }
            }
        }
        .sheet(item: $tamPhu) { t in
            BangSprintCTW(tamPhu: t, pid: pid, dsKhac: vm.dsSprint) { e in await vm.ghi(e) }
        }
        .refreshable { await vm.tai() }
        .task { if vm.trangThai.giaTri == nil { await vm.tai() } }
    }

    // MARK: Nội dung

    private func noiDung(_ s: CTWSprintDu) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let loi = vm.loi { CTWErrorBanner(text: loi) { vm.loi = nil } }
                dau(s)
                chiSo(s)
                tienDo(s)
                if let bd = vm.burndown, !(bd.points ?? []).isEmpty {
                    let diem = TinhSprintCTW.chuoi(bd)
                    if rong {
                        HStack(alignment: .top, spacing: 14) {
                            BieuDoBurndownCTW(diem: diem, unit: bd.unit)
                            BieuDoBurnupCTW(diem: diem, unit: bd.unit, cao: 220)
                        }
                    } else {
                        BieuDoBurndownCTW(diem: diem, unit: bd.unit)
                        BieuDoBurnupCTW(diem: diem, unit: bd.unit)
                    }
                }
                if let bc = vm.baoCao { baoCao(bc, unit: vm.burndown?.unit) }
                dsThe()
            }
            .padding(Spacing.md)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
    }

    private func dau(_ s: CTWSprintDu) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                chipTrangThai(s)
                if let a = NgayCTW.ngayCua(s.startAt).flatMap(NgayCTW.nganTu),
                   let b = NgayCTW.ngayCua(s.endAt).flatMap(NgayCTW.nganTu) {
                    Label("\(a) – \(b)", systemImage: "calendar").font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                }
            }
            if let g = s.goal, !g.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Sprint goal", systemImage: "target").font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.primary)
                    Text(g).font(.ctw(size: 15)).foregroundColor(AppColors.textPrimary).fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppColors.primary.opacity(0.08)))
            }
        }
    }

    private func chipTrangThai(_ s: CTWSprintDu) -> some View {
        let (chu, mau): (String, Color) = s.dangChay ? (String(localized: "ACTIVE"), AppColors.primary) : (s.daDong ? (String(localized: "COMPLETED"), AppColors.success) : (String(localized: "PLANNED"), AppColors.textSecondary))
        return Text(chu).font(.ctw(size: 10, weight: .bold)).foregroundColor(mau)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(mau.opacity(0.12)))
    }

    @ViewBuilder
    private func chiSo(_ s: CTWSprintDu) -> some View {
        let unit = vm.burndown?.unit
        let cs = vm.burndown.map(TinhSprintCTW.chiSo)
        let laTheCon: (Int) -> Bool = { cfg?.loai($0)?.level == -1 }
        let diemThe = TinhSprintCTW.tongDiem(vm.the, laTheCon: laTheCon)
        let cot = Array(repeating: GridItem(.flexible(), spacing: 10), count: rong ? 4 : 2)
        LazyVGrid(columns: cot, spacing: 10) {
            CTWTheChiSo(nhan: String(localized: "Committed"), giaTri: DonViSprintCTW.so(cs?.cam ?? diemThe, unit), phu: s.chuaBatDau ? String(localized: "Current scope") : String(localized: "At sprint start"),
                        bieuTuong: "flag", mau: CTWMauChuoi.mau(0))
            CTWTheChiSo(nhan: String(localized: "Completed"), giaTri: DonViSprintCTW.so(cs?.xong ?? 0, unit),
                        phu: cs.map { String(localized: "\(Int(($0.tiLe * 100).rounded()))% of committed") }, bieuTuong: "checkmark.circle", mau: AppColors.success)
            CTWTheChiSo(nhan: String(localized: "Remaining"), giaTri: DonViSprintCTW.so(cs?.con ?? diemThe, unit), bieuTuong: "hourglass", mau: CTWMauChuoi.mau(1))
            o4(s)
        }
    }

    private func o4(_ s: CTWSprintDu) -> CTWTheChiSo {
        if s.daDong {
            let d = NgayCTW.thoiDiem(s.completedAt).map(NgayCTW.ngan) ?? "—"
            return CTWTheChiSo(nhan: String(localized: "Completed on"), giaTri: d, bieuTuong: "checkmark.seal", mau: AppColors.success)
        }
        guard let con = TinhSprintCTW.ngayConLai(endAt: s.endAt) else {
            return CTWTheChiSo(nhan: String(localized: "Days left"), giaTri: "—", phu: String(localized: "No dates yet"), bieuTuong: "calendar")
        }
        let duBao = vm.burndown.flatMap(TinhSprintCTW.duBaoXong).map { String(localized: "Forecast: done \(NgayCTW.ngan($0))") }
        if con < 0 {
            return CTWTheChiSo(nhan: String(localized: "Overdue by"), giaTri: con == -1 ? String(localized: "1 day") : String(localized: "\(-con) days"), phu: duBao, bieuTuong: "exclamationmark.triangle", mau: AppColors.error)
        }
        return CTWTheChiSo(nhan: String(localized: "Days left"), giaTri: "\(con)", phu: duBao ?? NgayCTW.thoiDiem(s.endAt).map { String(localized: "Ends \(NgayCTW.ngan($0))") },
                           bieuTuong: "calendar", mau: AppColors.primary)
    }

    private func tienDo(_ s: CTWSprintDu) -> some View {
        let laTheCon: (Int) -> Bool = { cfg?.loai($0)?.level == -1 }
        let dem = TinhSprintCTW.demThe(vm.the, nhom: { cfg?.trangThai($0)?.category }, laTheCon: laTheCon)
        let cs = vm.burndown.map(TinhSprintCTW.chiSo)
        return VStack(alignment: .leading, spacing: 14) {
            CTWSectionHeader("chart.bar.fill", String(localized: "Progress"))
            if let cs, cs.cam > 0 {
                dongTienDo(tieuDe: String(localized: "By \(DonViSprintCTW.tenDai(vm.burndown?.unit))"),
                           phai: "\(CTWSo.gon(cs.xong)) / \(CTWSo.gon(cs.cam))",
                           doan: [CTWDoanTienDo(ten: String(localized: "Done"), giaTri: cs.xong, mau: AppColors.success),
                                  CTWDoanTienDo(ten: String(localized: "Remaining"), giaTri: max(cs.con, 0), mau: CTWMauChuoi.khac)])
            }
            dongTienDo(tieuDe: String(localized: "By issues"), phai: "\(dem.xong) / \(dem.tong)",
                       doan: [CTWDoanTienDo(ten: String(localized: "Done"), giaTri: Double(dem.xong), mau: AppColors.success),
                              CTWDoanTienDo(ten: String(localized: "In progress"), giaTri: Double(dem.dangLam), mau: CTWMauChuoi.mau(0)),
                              CTWDoanTienDo(ten: String(localized: "To do"), giaTri: Double(dem.chuaLam), mau: CTWMauChuoi.khac)])
            CTWChuGiai(muc: [CTWMucChuGiai(ten: String(localized: "Done \(dem.xong)"), mau: AppColors.success),
                             CTWMucChuGiai(ten: String(localized: "In progress \(dem.dangLam)"), mau: CTWMauChuoi.mau(0)),
                             CTWMucChuGiai(ten: String(localized: "To do \(dem.chuaLam)"), mau: CTWMauChuoi.khac)])
        }
        .padding(14)
        .ctwThe(14)
    }

    private func dongTienDo(tieuDe: String, phai: String, doan: [CTWDoanTienDo]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(tieuDe).font(.ctw(size: 13, weight: .medium)).foregroundColor(AppColors.textSecondary)
                Spacer()
                Text(phai).font(.ctw(size: 13, weight: .semibold).monospacedDigit()).foregroundColor(AppColors.textPrimary)
            }
            CTWThanhTienDo(doan: doan, cao: 10)
        }
    }

    // MARK: Báo cáo sprint

    private func baoCao(_ bc: CTWSprintReport, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            CTWSectionHeader("doc.text.magnifyingglass", String(localized: "Sprint report"))
            HStack(spacing: 10) {
                o(String(localized: "Completed"), "\(bc.soXong)", AppColors.success)
                o(String(localized: "Not done"), "\(bc.soChuaXong)", CTWMauChuoi.mau(1))
                o(String(localized: "Added"), "+\(bc.added?.count ?? 0)", CTWMauChuoi.mau(0))
                o(String(localized: "Removed"), "−\(bc.removed?.count ?? 0)", CTWMauChuoi.khac)
            }
            if !(bc.added ?? []).isEmpty || !(bc.removed ?? []).isEmpty {
                Text(thayDoiPhamVi(bc)).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !(bc.incomplete ?? []).isEmpty {
                Text("Not done").font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary).padding(.top, 4)
                ForEach(bc.incomplete ?? []) { i in hangBaoCao(i, unit) }
            }
        }
        .padding(14)
        .ctwThe(14)
    }

    private func thayDoiPhamVi(_ bc: CTWSprintReport) -> String {
        let ma = cfg?.key ?? ""
        var p: [String] = []
        if let a = bc.added, !a.isEmpty { p.append(String(localized: "Added after start: \(a.prefix(8).map { "\(ma)-\($0)" }.joined(separator: ", "))")) }
        if let r = bc.removed, !r.isEmpty { p.append(String(localized: "Removed: \(r.prefix(8).map { "\(ma)-\($0)" }.joined(separator: ", "))")) }
        return p.joined(separator: "\n")
    }

    private func o(_ nhan: String, _ v: String, _ mau: Color) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.ctw(size: 18, weight: .bold).monospacedDigit()).foregroundColor(AppColors.textPrimary)
            HStack(spacing: 4) {
                Circle().fill(mau).frame(width: 6, height: 6)
                Text(nhan).font(.ctw(size: 11)).foregroundColor(AppColors.textSecondary).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColors.backgroundTertiary.opacity(0.6)))
        .accessibilityElement(children: .combine)
    }

    private func hangBaoCao(_ i: CTWSprintReportItem, _ unit: String?) -> some View {
        Group {
            if let so = i.number {
                NavigationLink(value: CTWRoute.the(pid: pid, so: so)) {
                    HStack {
                        Text("\(cfg?.key ?? "")-\(so)").font(.ctw(size: 12, weight: .medium).monospaced()).foregroundColor(AppColors.textSecondary)
                        Text(i.title ?? "").font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                        Spacer(minLength: 0)
                        if let p = i.points, p > 0 { Text(DonViSprintCTW.so(p, unit)).font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary) }
                        Image(systemName: "chevron.right").font(.ctw(size: 11, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                    }
                    .frame(minHeight: 36)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Thẻ trong sprint

    private func dsThe() -> some View {
        let nhom: [(String, String, [CTWIssueCard])] = [
            (String(localized: "In progress"), "IN_PROGRESS", vm.the.filter { cfg?.trangThai($0.statusId)?.category == "IN_PROGRESS" }),
            (String(localized: "To do"), "TODO", vm.the.filter { let c = cfg?.trangThai($0.statusId)?.category; return c != "IN_PROGRESS" && c != "DONE" }),
            (String(localized: "Done"), "DONE", vm.the.filter { cfg?.trangThai($0.statusId)?.category == "DONE" }),
        ]
        return VStack(alignment: .leading, spacing: 10) {
            CTWSectionHeader("list.bullet.rectangle", String(localized: "Issues"), count: "\(vm.the.count)")
            if vm.the.isEmpty {
                Text("No issues in this sprint yet.").font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
            }
            ForEach(nhom, id: \.1) { n in
                if !n.2.isEmpty {
                    HStack(spacing: 6) {
                        Circle().fill(CTWMauChuoi.nhom(n.1)).frame(width: 7, height: 7)
                        Text(n.0).font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                        Text("\(n.2.count)").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                    }
                    .padding(.top, 4)
                    ForEach(n.2) { t in hangThe(t) }
                }
            }
        }
        .padding(14)
        .ctwThe(14)
    }

    private func hangThe(_ t: CTWIssueCard) -> some View {
        NavigationLink(value: CTWRoute.the(pid: pid, so: t.number)) {
            HStack(spacing: 10) {
                CTWTypeIcon(type: cfg?.loai(t.typeId), size: 14)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.title).font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                        .strikethrough(t.resolvedAt != nil, color: AppColors.textTertiary)
                    Text("\(cfg?.key ?? "")-\(t.number)").font(.ctw(size: 11, weight: .medium).monospaced()).foregroundColor(AppColors.textTertiary)
                }
                Spacer(minLength: 0)
                if let sp = t.storyPoints {
                    Text(CTWSo.gon(sp)).font(.ctw(size: 11, weight: .bold)).foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(AppColors.backgroundTertiary))
                }
                if t.assigneeId != nil {
                    CTWAvatar(user: cfg?.thanhVien(t.assigneeId) ?? CTWUser(id: t.assigneeId ?? 0), size: 24)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
