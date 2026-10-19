import SwiftUI
import Charts

// MARK: - Một dashboard: lưới widget dựng GỐC bằng SwiftUI/Swift Charts
//
// iPhone: một cột. iPad: hai cột; widget `size: "full"` chiếm cả hàng (như web).
// Mỗi widget tự nạp dữ liệu của nó (`NapBaoCaoCTW`) ⇒ một widget hỏng không che cái khác.

struct DashboardCTW: View {
    let pid: Int
    let dashboard: CTWDashboardDb
    @Environment(\.horizontalSizeClass) private var beRong
    @State private var lamMoi = 0
    /// Bản mới nhất từ `GET /dashboards/:id` (widget có thể vừa được sửa trên web).
    @State private var moi: CTWDashboardDb?

    private var db: CTWDashboardDb { moi ?? dashboard }

    var body: some View {
        let ws = db.widgets ?? []
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if ws.isEmpty {
                    CTWOTrong(bieuTuong: "square.grid.2x2", tieuDe: "This dashboard is empty", moTa: "Add widgets on the web — they show up here.")
                }
                ForEach(Array(hang(ws).enumerated()), id: \.offset) { _, h in
                    if h.count == 2 {
                        HStack(alignment: .top, spacing: 14) {
                            WidgetDbCTW(pid: pid, w: h[0], lamMoi: lamMoi, rong: false)
                            WidgetDbCTW(pid: pid, w: h[1], lamMoi: lamMoi, rong: false)
                        }
                    } else if let w = h.first {
                        WidgetDbCTW(pid: pid, w: w, lamMoi: lamMoi, rong: beRong == .regular)
                    }
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .refreshable { await napMoi(); lamMoi += 1 }
        .task { await napMoi() }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(db.name ?? "Dashboard")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func napMoi() async {
        if let d: CTWDashboardDb = try? await APIClient.shared.request(CTWAPI.motDashboard(pid: pid, id: dashboard.id)), d != moi {
            moi = d
        }
    }

    /// Chia widget thành hàng: iPad ghép hai widget "half" liền nhau; iPhone mỗi hàng một widget.
    private func hang(_ ws: [CTWWidgetDb]) -> [[CTWWidgetDb]] {
        guard beRong == .regular else { return ws.map { [$0] } }
        var kq: [[CTWWidgetDb]] = []
        var cho: CTWWidgetDb?
        for w in ws {
            if w.size == "full" {
                if let c = cho { kq.append([c]); cho = nil }
                kq.append([w])
            } else if let c = cho {
                kq.append([c, w]); cho = nil
            } else {
                cho = w
            }
        }
        if let c = cho { kq.append([c]) }
        return kq
    }
}

// MARK: - Widget

struct WidgetDbCTW: View {
    let pid: Int
    let w: CTWWidgetDb
    let lamMoi: Int
    let rong: Bool
    @EnvironmentObject private var app: AppState
    @State private var moWeb = false

    static let tenMacDinh: [String: String] = [
        "filter": "Filter results", "my_issues": "Assigned to me", "overdue": "Overdue", "counter": "Count",
        "pie": "Breakdown", "bar": "Breakdown", "created_resolved": "Created vs resolved", "burndown": "Sprint burndown",
        "health": "Project health", "text": "Notes", "top_risks": "Top risks", "kpis": "Key numbers",
        "cfd": "Cumulative flow", "throughput": "Throughput", "cycle_time": "Cycle time", "aging_wip": "Aging work in progress",
        "velocity": "Velocity", "release_burnup": "Release burnup", "workload": "Workload",
        "test_pass_rate": "Test pass rate", "defects_by_severity": "Defects by severity", "license_expiring": "Expiring licenses",
        "my_timer": "My timer", "okr": "OKRs",
    ]

    private var tieuDe: String {
        if let t = w.title, !t.isEmpty { return t }
        return Self.tenMacDinh[w.kind] ?? w.kind.replacingOccurrences(of: "_", with: " ").capitalized
    }
    private var k: String { "\(w.id)-\(lamMoi)" }

    var body: some View {
        Group {
            switch w.kind {
            case "counter": demJql
            case "filter", "my_issues", "overdue": dsJql
            case "pie", "bar": phanBo
            case "created_resolved":
                NapBaoCaoCTW(khoa: k, diemCuoi: { CTWAPI.taoVsXong(pid: pid, ngay: w.days ?? 30, jql: w.query ?? "") }) { (ds: [CTWTaoXongNgay]) in
                    BieuDoTaoXongCTW(ds: ds)
                }
            case "burndown": burndown
            case "kpis":
                NapBaoCaoCTW(khoa: k, diemCuoi: { CTWAPI.kpis(pid: pid) }, soHang: 2) { (kp: CTWKpis) in
                    VStack(alignment: .leading, spacing: 10) { khung(tieuDe); HangKpiCTW(k: kp, soCot: rong ? 4 : 2) }
                }
            case "cfd":
                NapBaoCaoCTW(khoa: k, diemCuoi: { CTWAPI.cfd(pid: pid, ngay: w.days ?? 30) }) { (c: CTWCfd) in BieuDoCfdCTW(c: c) }
            case "throughput":
                NapBaoCaoCTW(khoa: k, diemCuoi: { CTWAPI.throughput(pid: pid) }) { (t: CTWThroughput) in BieuDoThroughputCTW(t: t) }
            case "cycle_time":
                NapBaoCaoCTW(khoa: k, diemCuoi: { CTWAPI.cycleTime(pid: pid) }) { (c: CTWCycleTime) in TheCycleTimeCTW(c: c) }
            case "velocity":
                NapBaoCaoCTW(khoa: k, diemCuoi: { CTWAPI.velocity(pid: pid) }) { (v: CTWVelocity) in BieuDoVelocityCTW(v: v) }
            case "workload":
                NapBaoCaoCTW(khoa: k, diemCuoi: { CTWAPI.taiTheoNguoi(pid: pid) }) { (t: CTWTaiTheoNguoi) in BieuDoTaiNguoiCTW(t: t) }
            case "health":
                NapBaoCaoCTW(khoa: k, diemCuoi: { CTWAPI.insights(pid: pid) }) { (i: CTWInsights) in
                    VStack(alignment: .leading, spacing: 10) {
                        khung(tieuDe)
                        SucKhoeDuAnCTW(i: i, pid: pid, maDuAn: app.cauHinhDuAn?.key ?? "", rong: rong)
                    }
                }
            case "text": vanBan
            case "my_timer": dongHo
            default: chiCoTrenWeb
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .sheet(isPresented: $moWeb) {
            if let l = app.luaChon, let u = URL(string: "\(APIClient.diaChiGoc)/work/\(CTWAPI.doan(l.slug))/\(CTWAPI.doan(l.maDuAn))/dashboards") {
                SafariCTW(url: u).ignoresSafeArea()
            }
        }
    }

    private func khung(_ t: String) -> some View {
        Text(t).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
    }

    // MARK: JQL

    private var jql: String {
        switch w.kind {
        case "my_issues": return "assignee = currentUser() AND statusCategory != Done ORDER BY priority"
        case "overdue": return "due < now() AND statusCategory != Done AND type != \"Sub-task\" ORDER BY due"
        default: return w.query ?? ""
        }
    }

    private var demJql: some View {
        NapBaoCaoCTW(khoa: k, diemCuoi: { CTWAPI.timJql(pid: pid, jql: jql, limit: 1) }, soHang: 1) { (r: CTWKetQuaJql) in
            VStack(alignment: .leading, spacing: 4) {
                Text(tieuDe).font(.ctw(size: 13, weight: .medium)).foregroundColor(AppColors.textSecondary)
                Text("\(r.total ?? 0)").font(.ctw(size: 34, weight: .bold).monospacedDigit()).foregroundColor(AppColors.textPrimary)
                if !jql.isEmpty {
                    Text(jql).font(.ctw(size: 11).monospaced()).foregroundColor(AppColors.textTertiary).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14).ctwThe(14)
        }
    }

    private var dsJql: some View {
        NapBaoCaoCTW(khoa: k, diemCuoi: { CTWAPI.timJql(pid: pid, jql: jql, limit: 10) }) { (r: CTWKetQuaJql) in
            let cfg = app.cauHinhDuAn
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    khung(tieuDe)
                    Text("\(r.total ?? 0)").font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                        .padding(.horizontal, 6).padding(.vertical, 1).background(Capsule().fill(AppColors.backgroundTertiary))
                }
                if (r.items ?? []).isEmpty {
                    Text(w.kind == "overdue" ? "Nothing overdue. 🎉" : "No issues.").font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                }
                ForEach(r.items ?? []) { t in
                    NavigationLink(value: CTWRoute.the(pid: pid, so: t.number)) {
                        HStack(spacing: 8) {
                            CTWTypeIcon(type: cfg?.loai(t.typeId), size: 12)
                            Text("\(cfg?.key ?? "")-\(t.number)").font(.ctw(size: 11, weight: .medium).monospaced()).foregroundColor(AppColors.textSecondary)
                            Text(t.title).font(.ctw(size: 13)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                            Spacer(minLength: 0)
                            if let d = CTW.ngayNgan(t.dueDate) {
                                Text(d).font(.ctw(size: 11)).foregroundColor(CTW.quaHan(t.dueDate) ? AppColors.error : AppColors.textTertiary)
                            }
                            if t.assigneeId != nil { CTWAvatar(user: cfg?.thanhVien(t.assigneeId) ?? CTWUser(id: t.assigneeId ?? 0), size: 20) }
                        }
                        .frame(minHeight: 34)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if (r.total ?? 0) > (r.items ?? []).count {
                    Text("+\((r.total ?? 0) - (r.items ?? []).count) more").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading).ctwThe(14)
        }
    }

    // MARK: Phân bố

    private var phanBo: some View {
        let g = w.groupBy ?? "status"
        return NapBaoCaoCTW(khoa: k, diemCuoi: { CTWAPI.thongKe(pid: pid, nhomTheo: g, jql: w.query ?? "") }) { (s: CTWThongKe) in
            let thanh = TinhBaoCaoCTW.phanBo(s.groups ?? [], giuThuTu: g == "priority")
            if w.kind == "pie" {
                BieuDoTronDbCTW(tieuDe: tieuDe, thanh: thanh, tong: s.total ?? 0)
            } else {
                BieuDoPhanBoCTW(tieuDe: tieuDe, thanh: thanh, tong: thanh.map(\.giaTri).reduce(0, +),
                                mauTrangThai: g == "status" || g == "statusCategory")
            }
        }
    }

    // MARK: Burndown

    @ViewBuilder private var burndown: some View {
        let sid = w.sprintId ?? app.cauHinhDuAn?.sprints?.first(where: { $0.state == "ACTIVE" })?.id
        if let sid {
            NapBaoCaoCTW(khoa: "\(k)-\(sid)", diemCuoi: { CTWAPI.burndown(pid: pid, sid: sid) }) { (bd: CTWBurndown) in
                VStack(alignment: .leading, spacing: 8) {
                    if let n = bd.sprint?.name { Text(n).font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textSecondary) }
                    NoiDungBurndownCTW(bd: bd, gon: true)
                }
            }
        } else {
            thongDiep(tieuDe, "No active sprint right now.", "flag.checkered")
        }
    }

    // MARK: Text / timer

    private var vanBan: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let t = w.title, !t.isEmpty { khung(t) }
            CTWMarkdownView(markdown: w.text ?? "", coChu: 14)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).ctwThe(14)
    }

    private var dongHo: some View {
        NapBaoCaoCTW(khoa: k, diemCuoi: { CTWAPI.dongHoCuaToiDb() }, soHang: 1) { (g: CTWDongHoGoiDb) in
            VStack(alignment: .leading, spacing: 10) {
                khung(tieuDe)
                if let t = g.timer {
                    HStack(spacing: 10) {
                        Image(systemName: t.running == true ? "timer" : "pause.circle")
                            .font(.ctw(size: 20, weight: .semibold)).foregroundColor(t.running == true ? AppColors.success : AppColors.warning)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.issueKey ?? "").font(.ctw(size: 12, weight: .semibold).monospaced()).foregroundColor(AppColors.textSecondary)
                            Text(t.issueTitle ?? "").font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                        }
                        Spacer()
                        Text(CTWSo.dongHo(giay: t.elapsedSec ?? 0)).font(.ctw(size: 18, weight: .bold).monospacedDigit()).foregroundColor(AppColors.textPrimary)
                    }
                } else {
                    Text("No timer running.").font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                }
                NapBaoCaoCTW(khoa: "\(k)-mt", diemCuoi: { CTWAPI.gioCuaToiDb(pid: pid) }, soHang: 1) { (m: CTWGioCuaToiDb) in
                    HStack(spacing: 10) {
                        CTWTheChiSo(nhan: "Today", giaTri: CTWSo.gio(giay: (m.todayMinutes ?? 0) * 60), bieuTuong: "sun.max", mau: CTWMauChuoi.mau(0))
                        CTWTheChiSo(nhan: "This week", giaTri: CTWSo.gio(giay: (m.weekMinutes ?? 0) * 60), bieuTuong: "calendar", mau: CTWMauChuoi.mau(0))
                    }
                }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading).ctwThe(14)
        }
    }

    // MARK: Widget chỉ có trên web

    private var chiCoTrenWeb: some View {
        HStack(spacing: 12) {
            Image(systemName: bieuTuongWeb).font(.ctw(size: 16, weight: .semibold)).foregroundColor(AppColors.primary)
                .frame(width: 36, height: 36).background(Circle().fill(AppColors.primary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(tieuDe).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                Text("Shown in full on the web dashboard.").font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
            }
            Spacer(minLength: 0)
            Button("Open") { moWeb = true }.buttonStyle(.bordered).font(.ctw(size: 13, weight: .semibold))
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).ctwThe(14)
    }

    private var bieuTuongWeb: String {
        switch w.kind {
        case "top_risks": return "shield.lefthalf.filled"
        case "aging_wip": return "hourglass"
        case "release_burnup": return "shippingbox"
        case "test_pass_rate", "defects_by_severity": return "checkmark.shield"
        case "license_expiring": return "key"
        case "okr": return "scope"
        default: return "square.grid.2x2"
        }
    }

    private func thongDiep(_ t: String, _ m: String, _ b: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            khung(t)
            Label(m, systemImage: b).font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).ctwThe(14)
    }
}

// MARK: - Biểu đồ tròn (widget pie)

struct BieuDoTronDbCTW: View {
    let tieuDe: String
    let thanh: [ThanhPhanBoCTW]
    let tong: Int

    var body: some View {
        CTWKhungBieuDo(tieuDe: tieuDe, phu: "\(tong) issues",
                       chuGiai: thanh.map { CTWMucChuGiai(ten: $0.nhan, mau: mau($0)) },
                       cot: ["Group", "Issues", "%"],
                       hang: thanh.map { CTWHangBang(nhan: $0.nhan, giaTri: [CTWSo.gon($0.giaTri), "\(Int(($0.tiLe * 100).rounded()))%"]) },
                       cao: 200) {
            Chart(thanh) { t in
                SectorMark(angle: .value("Issues", t.giaTri), innerRadius: .ratio(0.6), angularInset: 1.5)
                    .foregroundStyle(mau(t))
                    .cornerRadius(3)
            }
            .chartBackground { _ in
                VStack(spacing: 0) {
                    Text("\(tong)").font(.ctw(size: 22, weight: .bold).monospacedDigit()).foregroundColor(AppColors.textPrimary)
                    Text("issues").font(.ctw(size: 11)).foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    /// Tròn nhiều nhóm ⇒ cần màu PHÂN BIỆT theo thứ tự cố định (không dùng màu nhóm trạng thái:
    /// hai trạng thái cùng nhóm sẽ trùng màu). Có chú giải + bảng nên không chỉ dựa vào màu.
    private func mau(_ t: ThanhPhanBoCTW) -> Color { CTWMauChuoi.mau(t.viTriMau) }
}
