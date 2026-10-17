import SwiftUI
import Charts

// MARK: - Chi tiết một phiên bản
//
// Đầu: trạng thái + ngày + vòng tiến độ + thanh Done/In progress/To do (tính từ thẻ — endpoint chi
// tiết KHÔNG trả tiến độ). Giữa: burnup (`/reports/release-burnup`, theo số thẻ hoặc ước lượng) có
// dự báo. Dưới: ghi chú phát hành (markdown) + thẻ theo nhóm trạng thái.
// Ghi (quyền `manageSprints`): sửa ghi chú, Release (chuyển thẻ chưa xong), bỏ phát hành, lưu trữ.
// KHÔNG có "AI draft notes" của web — app không gửi dữ liệu cho AI bên thứ ba (5.1.2).

@MainActor
final class ChiTietPhienBanVM: ObservableObject {
    let pid: Int
    let id: Int
    @Published var trangThai: TaiCTW<PhienBanChiTietCTW> = .dangTai
    @Published var burnup: BurnupPhatHanhCTW?
    @Published var theoSoThe = true
    @Published var dsPhienBan: [PhienBanCTW] = []
    @Published var cauHinh: CTWProjectConfig?
    @Published var loi: String?
    @Published var dangGui = false

    init(pid: Int, id: Int) { self.pid = pid; self.id = id }

    func tai(cfg: CTWProjectConfig?) async {
        if cauHinh == nil { cauHinh = cfg }
        do {
            async let ct: PhienBanChiTietCTW = APIClient.shared.request(CTWAPI.phienBan(pid: pid, id: id))
            async let ds: [PhienBanCTW]? = try? APIClient.shared.request(CTWAPI.dsPhienBan(pid: pid))
            if cauHinh == nil { cauHinh = try? await APIClient.shared.request(.workDuAn(pid: pid)) }
            trangThai = .xong(try await ct)
            dsPhienBan = await ds ?? dsPhienBan
            await taiBurnup()
        } catch {
            if trangThai.giaTri == nil { trangThai = .loi(CTW.loi(error)) } else { loi = CTW.loi(error) }
        }
    }

    func taiBurnup() async {
        burnup = try? await APIClient.shared.request(CTWAPI.burnupPhatHanh(pid: pid, id: id, theoSoThe: theoSoThe))
    }

    func sua(_ than: [String: Any]) async -> Bool {
        dangGui = true
        defer { dangGui = false }
        do {
            let v: PhienBanCTW = try await APIClient.shared.request(CTWAPI.suaPhienBan(pid: pid, id: id, than: than))
            if var c = trangThai.giaTri { c.version = v; trangThai = .xong(c) }
            CTWRung.thanhCong()
            return true
        } catch {
            CTWRung.loi()
            loi = CTW.loi(error)
            return false
        }
    }

    func phatHanh(chuyenSang: Int?, ngay: Date) async -> Bool {
        dangGui = true
        defer { dangGui = false }
        do {
            let _: KetQuaPhatHanhCTW = try await APIClient.shared.request(CTWAPI.phatHanh(pid: pid, id: id, chuyenSang: chuyenSang, ngay: CTW.chuoiNgay(ngay)))
            CTWRung.thanhCong()
            await tai(cfg: cauHinh)
            return true
        } catch {
            CTWRung.loi()
            loi = CTW.loi(error)
            return false
        }
    }

    func nhom(_ statusId: Int) -> String? { cauHinh?.trangThai(statusId)?.category }
}

struct ChiTietPhienBanCTW: View {
    let route: RoutePhienBanCTW
    @StateObject private var vm: ChiTietPhienBanVM
    @EnvironmentObject private var app: AppState
    @Environment(\.horizontalSizeClass) private var beRong
    @State private var tamPhu: TamPhu?

    private enum TamPhu: String, Identifiable { case ghiChu, phatHanh; var id: String { rawValue } }

    init(route: RoutePhienBanCTW) {
        self.route = route
        _vm = StateObject(wrappedValue: ChiTietPhienBanVM(pid: route.pid, id: route.id))
    }

    private var quanLy: Bool { (vm.cauHinh ?? app.cauHinhDuAn)?.permissions?.manageSprints == true }

    var body: some View {
        KhungTaiCTW(trangThai: vm.trangThai, thuLai: { Task { await vm.tai(cfg: app.cauHinhDuAn) } }) { ct in
            ScrollView {
                VStack(spacing: 14) {
                    if let loi = vm.loi { CTWErrorBanner(text: loi) { vm.loi = nil } }
                    if let v = ct.version {
                        if beRong == .regular {
                            HStack(alignment: .top, spacing: 14) {
                                VStack(spacing: 14) { dau(v, ct.issues ?? []); ghiChu(v) }
                                VStack(spacing: 14) { bieuDo; dsThe(ct.issues ?? []) }
                            }
                        } else {
                            dau(v, ct.issues ?? [])
                            bieuDo
                            ghiChu(v)
                            dsThe(ct.issues ?? [])
                        }
                    }
                }
                .padding(Spacing.md)
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(vm.trangThai.giaTri?.version?.name ?? route.ten)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if quanLy, let v = vm.trangThai.giaTri?.version {
                ToolbarItem(placement: .primaryAction) { menu(v) }
            }
        }
        .sheet(item: $tamPhu) { t in
            switch t {
            case .ghiChu:
                SuaGhiChuPBCTW(ban: vm.trangThai.giaTri?.version?.releaseNotes ?? "") { chu in
                    await vm.sua(["releaseNotes": chu.isEmpty ? NSNull() : chu])
                }
            case .phatHanh:
                if let ct = vm.trangThai.giaTri, let v = ct.version {
                    PhatHanhPBCTW(v: v, chuaXong: (ct.issues ?? []).filter { $0.resolvedAt == nil && vm.nhom($0.statusId) != "DONE" }.count,
                                  dich: vm.dsPhienBan.filter { $0.status == "UNRELEASED" && $0.id != v.id }) { dich, ngay in
                        await vm.phatHanh(chuyenSang: dich, ngay: ngay)
                    }
                }
            }
        }
        .task { await vm.tai(cfg: app.cauHinhDuAn) }
        .refreshable { await vm.tai(cfg: app.cauHinhDuAn) }
    }

    private func menu(_ v: PhienBanCTW) -> some View {
        Menu {
            if v.status == "UNRELEASED" || v.status == nil {
                Button { tamPhu = .phatHanh } label: { Label("Release…", systemImage: "paperplane") }
            }
            Button { tamPhu = .ghiChu } label: { Label("Edit release notes", systemImage: "square.and.pencil") }
            if v.daPhatHanh {
                Button { Task { _ = await vm.sua(["status": "UNRELEASED"]); await vm.tai(cfg: nil) } } label: {
                    Label("Mark as unreleased", systemImage: "arrow.uturn.backward")
                }
            }
            if v.daLuuTru {
                Button { Task { _ = await vm.sua(["status": "UNRELEASED"]) } } label: { Label("Restore", systemImage: "tray.and.arrow.up") }
            } else {
                Button { Task { _ = await vm.sua(["status": "ARCHIVED"]) } } label: { Label("Archive", systemImage: "archivebox") }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .disabled(vm.dangGui)
        .accessibilityLabel("Version actions")
    }

    // MARK: Đầu

    private func dau(_ v: PhienBanCTW, _ the: [CTWIssueCard]) -> some View {
        let tt = PhienBanChuCTW.trangThai(v.status)
        let td = TienDoPhienBanCTW.tinh(the, nhom: vm.nhom)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                CTWVongTienDo(tiLe: td.tiLe, co: 64, mau: v.overdue == true ? AppColors.error : AppColors.success)
                VStack(alignment: .leading, spacing: 5) {
                    Label(tt.ten, systemImage: tt.bieuTuong).font(.system(size: 12, weight: .semibold)).foregroundColor(tt.mau)
                    Text(v.name).font(.system(size: 20, weight: .bold)).foregroundColor(AppColors.textPrimary)
                    HStack(spacing: 4) {
                        if v.overdue == true { Image(systemName: "exclamationmark.circle.fill") }
                        Text(PhienBanChuCTW.dongNgay(v))
                    }
                    .font(.system(size: 13)).foregroundColor(v.overdue == true ? AppColors.error : AppColors.textSecondary)
                    if let s = NgayCTW.ngay(v.startDate) {
                        Text("Started \(NgayCTW.day(s))").font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
                    }
                }
                Spacer(minLength: 0)
            }
            if let m = v.description, !m.isEmpty {
                Text(m).font(.system(size: 14)).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            CTWThanhTienDo(doan: [CTWDoanTienDo(ten: "Done", giaTri: Double(td.xong), mau: AppColors.success),
                                  CTWDoanTienDo(ten: "In progress", giaTri: Double(td.dangLam), mau: CTWMauChuoi.mau(0)),
                                  CTWDoanTienDo(ten: "To do", giaTri: Double(td.chuaLam), mau: CTWMauChuoi.khac)], cao: 10)
            HStack(spacing: 14) {
                demNhom("Done", td.xong, AppColors.success)
                demNhom("In progress", td.dangLam, CTWMauChuoi.mau(0))
                demNhom("To do", td.chuaLam, CTWMauChuoi.khac)
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .ctwThe(16)
    }

    private func demNhom(_ t: String, _ n: Int, _ m: Color) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(m).frame(width: 9, height: 9)
            Text("\(n)").font(.system(size: 13, weight: .bold).monospacedDigit()).foregroundColor(AppColors.textPrimary)
            Text(t).font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Burnup

    private var bieuDo: some View {
        let b = vm.burnup
        let diem = (b?.points ?? []).compactMap { p in NgayCTW.ngay(p.day).map { (d: $0, p: p) } }
        let donVi = vm.theoSoThe ? "issues" : ((b?.unit == "HOURS") ? "hours" : "points")
        let phu: String = {
            if let f = NgayCTW.ngay(b?.forecast) { return "Forecast to finish \(NgayCTW.day(f)) at the recent pace" }
            return "Scope vs. completed \(donVi) over time"
        }()
        return CTWKhungBieuDo(
            tieuDe: "Release burnup", phu: phu,
            chuGiai: [CTWMucChuGiai(ten: "Scope", mau: CTWMauChuoi.mau(0)),
                      CTWMucChuGiai(ten: "Done", mau: CTWMauChuoi.mau(2)),
                      CTWMucChuGiai(ten: "Ideal", mau: AppColors.textTertiary, netDut: true)],
            cot: ["Day", "Scope", "Done"],
            hang: diem.map { CTWHangBang(nhan: NgayCTW.ngan($0.d), giaTri: [CTWSo.gon($0.p.scope ?? 0), CTWSo.gon($0.p.done ?? 0)]) }
        ) {
            VStack(spacing: 8) {
                Picker("Measure", selection: $vm.theoSoThe) {
                    Text("Issue count").tag(true)
                    Text("Estimate").tag(false)
                }
                .pickerStyle(.segmented)
                .onChange(of: vm.theoSoThe) { _, _ in Task { await vm.taiBurnup() } }
                if diem.isEmpty {
                    Text(b == nil ? "Loading…" : "No burnup data yet. It appears once the version has issues and a start date.")
                        .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Chart {
                        ForEach(diem, id: \.d) { x in
                            if let s = x.p.scope {
                                LineMark(x: .value("Day", x.d), y: .value("Value", s), series: .value("Series", "Scope"))
                                    .foregroundStyle(CTWMauChuoi.mau(0)).lineStyle(StrokeStyle(lineWidth: 2))
                                    .interpolationMethod(.stepEnd)
                            }
                            if let d = x.p.done {
                                AreaMark(x: .value("Day", x.d), y: .value("Value", d), series: .value("Series", "Done"))
                                    .foregroundStyle(CTWMauChuoi.mau(2).opacity(0.18))
                                LineMark(x: .value("Day", x.d), y: .value("Value", d), series: .value("Series", "Done"))
                                    .foregroundStyle(CTWMauChuoi.mau(2)).lineStyle(StrokeStyle(lineWidth: 2))
                            }
                            if let i = x.p.ideal {
                                LineMark(x: .value("Day", x.d), y: .value("Value", i), series: .value("Series", "Ideal"))
                                    .foregroundStyle(AppColors.textTertiary).lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            }
                        }
                        RuleMark(x: .value("Today", NgayCTW.lichVN.startOfDay(for: Date())))
                            .foregroundStyle(AppColors.error.opacity(0.5)).lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    }
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisGridLine(); AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
                    .chartYAxis { AxisMarks(position: .leading) }
                }
            }
        }
    }

    // MARK: Ghi chú

    private func ghiChu(_ v: PhienBanCTW) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            CTWSectionHeader("doc.richtext", "Release notes", trailing: quanLy ? AnyView(
                Button("Edit") { tamPhu = .ghiChu }.font(.system(size: 14, weight: .semibold))
            ) : nil)
            if let n = v.releaseNotes, !n.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                CTWMarkdownView(markdown: n, coChu: 14)
            } else {
                Text(quanLy ? "No release notes yet. Tap Edit to write what's new in this version."
                            : "No release notes have been written for this version.")
                    .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .ctwThe(16)
    }

    // MARK: Thẻ

    private func dsThe(_ the: [CTWIssueCard]) -> some View {
        let nhom: [(String, String, [CTWIssueCard])] = [
            ("In progress", "circle.lefthalf.filled", the.filter { $0.resolvedAt == nil && vm.nhom($0.statusId) == "IN_PROGRESS" }),
            ("To do", "circle", the.filter { $0.resolvedAt == nil && vm.nhom($0.statusId) != "IN_PROGRESS" && vm.nhom($0.statusId) != "DONE" }),
            ("Done", "checkmark.circle.fill", the.filter { $0.resolvedAt != nil || vm.nhom($0.statusId) == "DONE" }),
        ]
        let cfg = vm.cauHinh
        return VStack(alignment: .leading, spacing: 12) {
            CTWSectionHeader("list.bullet.rectangle", "Issues", count: "\(the.count)")
            if the.isEmpty {
                Text("No issues are assigned to this version.").font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
            }
            ForEach(nhom.filter { !$0.2.isEmpty }, id: \.0) { n in
                VStack(alignment: .leading, spacing: 0) {
                    Label("\(n.0) · \(n.2.count)", systemImage: n.1).font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary).padding(.bottom, 4)
                    ForEach(n.2) { t in
                        NavigationLink(value: CTWRoute.the(pid: route.pid, so: t.number)) {
                            HStack(spacing: 9) {
                                CTWTypeIcon(type: cfg?.loai(t.typeId), size: 13)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.title).font(.system(size: 14)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                                    Text("\(cfg?.key ?? "#")-\(t.number)").font(.system(size: 11).monospaced())
                                        .foregroundColor(AppColors.textTertiary).strikethrough(t.resolvedAt != nil)
                                }
                                Spacer(minLength: 0)
                                if let a = t.assigneeId { CTWAvatar(user: cfg?.thanhVien(a) ?? CTWUser(id: a), size: 22) }
                                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                            }
                            .padding(.vertical, 7)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .ctwThe(16)
    }
}

// MARK: - Sửa ghi chú phát hành

struct SuaGhiChuPBCTW: View {
    @State var ban: String
    let luu: (String) async -> Bool
    @Environment(\.dismiss) private var dong
    @State private var dangLuu = false

    var body: some View {
        NavigationStack {
            ScrollView {
                CTWSoanMarkdown(chu: $ban, goiY: "What's new, fixed and changed in this version…", dongToiThieu: 12)
                    .padding(Spacing.md)
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Release notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            dangLuu = true
                            if await luu(String(ban.trimmingCharacters(in: .whitespacesAndNewlines).prefix(50_000))) { dong() }
                            dangLuu = false
                        }
                    }
                    .bold().disabled(dangLuu)
                }
            }
        }
    }
}

// MARK: - Phát hành

struct PhatHanhPBCTW: View {
    let v: PhienBanCTW
    let chuaXong: Int
    let dich: [PhienBanCTW]
    let lam: (Int?, Date) async -> Bool
    @Environment(\.dismiss) private var dong
    @State private var chuyenSang: Int?
    @State private var ngay = Date()
    @State private var dangGui = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(chuaXong == 0 ? "All issues in this version are done." : "\(chuaXong) issue\(chuaXong == 1 ? " is" : "s are") not done yet.",
                          systemImage: chuaXong == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(chuaXong == 0 ? AppColors.success : AppColors.warning)
                }
                if chuaXong > 0 {
                    Section {
                        Picker("Move unfinished issues to", selection: $chuyenSang) {
                            Text("Remove from version").tag(Int?.none)
                            ForEach(dich) { d in Text(d.name).tag(Int?.some(d.id)) }
                        }
                    } footer: {
                        Text("Unfinished issues can't stay in a released version.")
                    }
                }
                Section {
                    DatePicker("Release date", selection: $ngay, displayedComponents: .date)
                }
            }
            .navigationTitle("Release \(v.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Release") {
                        Task {
                            dangGui = true
                            if await lam(chuyenSang, ngay) { dong() }
                            dangGui = false
                        }
                    }
                    .bold().disabled(dangGui)
                }
            }
            .onAppear {
                if let r = NgayCTW.ngay(v.releaseDate), r <= Date() { ngay = r }
            }
        }
    }
}
