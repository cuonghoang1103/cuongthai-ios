import SwiftUI
import Charts

// MARK: - Biểu đồ báo cáo (Swift Charts) — dùng ở tab Reports và widget Dashboards
//
// Quy ước: một trục y, đường 2pt, cột bo 4pt; ≥ 2 chuỗi thì có chú giải; mọi khung có
// "xem dạng bảng" (`CTWKhungBieuDo`). Phân bố một chuỗi ⇒ MỘT màu (độ dài mã hoá độ lớn);
// riêng phân bố theo trạng thái dùng màu nhóm trạng thái (kèm chữ).

// MARK: Velocity

struct BieuDoVelocityCTW: View {
    let v: CTWVelocity
    var cao: CGFloat = 220

    var body: some View {
        let ds = v.sprints ?? []
        let dv = DonViSprintCTW.ten(v.unit)
        CTWKhungBieuDo(
            tieuDe: "Velocity",
            phu: v.average.map { "Average of the last 3 sprints: \(CTWSo.gon($0)) \(dv)" } ?? "Committed vs completed per sprint",
            chuGiai: [CTWMucChuGiai(ten: "Committed", mau: CTWMauChuoi.khac),
                      CTWMucChuGiai(ten: "Completed", mau: CTWMauChuoi.mau(0)),
                      CTWMucChuGiai(ten: "3-sprint average", mau: CTWMauChuoi.mau(1), netDut: true)],
            cot: ["Sprint", "Committed", "Completed"],
            hang: ds.map { CTWHangBang(nhan: $0.name ?? "#\($0.id)", giaTri: [CTWSo.gon($0.committedPoints ?? 0), CTWSo.gon($0.completedPoints ?? 0)]) },
            cao: cao
        ) {
            if ds.isEmpty {
                Text("Complete a sprint to see velocity.").font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart {
                    ForEach(ds) { s in
                        BarMark(x: .value("Sprint", s.name ?? "#\(s.id)"), y: .value(dv, s.committedPoints ?? 0))
                            .foregroundStyle(by: .value("Series", "Committed"))
                            .position(by: .value("Series", "Committed"))
                            .cornerRadius(4)
                        BarMark(x: .value("Sprint", s.name ?? "#\(s.id)"), y: .value(dv, s.completedPoints ?? 0))
                            .foregroundStyle(by: .value("Series", "Completed"))
                            .position(by: .value("Series", "Completed"))
                            .cornerRadius(4)
                    }
                    ForEach(ds) { s in
                        if let r = s.rollingAverage {
                            LineMark(x: .value("Sprint", s.name ?? "#\(s.id)"), y: .value(dv, r), series: .value("Series", "Average"))
                                .foregroundStyle(CTWMauChuoi.mau(1))
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                                .symbol(Circle().strokeBorder(lineWidth: 2))
                                .symbolSize(30)
                        }
                    }
                }
                .chartForegroundStyleScale(["Committed": CTWMauChuoi.khac, "Completed": CTWMauChuoi.mau(0)])
                .chartLegend(.hidden)
                .chartXAxis { AxisMarks { _ in AxisValueLabel().font(.ctw(size: 9)) } }
                .chartYAxis { AxisMarks(position: .leading) { _ in AxisGridLine().foregroundStyle(AppColors.divider); AxisValueLabel() } }
            }
        }
    }
}

// MARK: CFD

struct BieuDoCfdCTW: View {
    let c: CTWCfd
    var cao: CGFloat = 240

    var body: some View {
        let diem = TinhBaoCaoCTW.cfd(c)
        let dai = Array((c.bands ?? []).reversed())
        let mau = mauDai(dai)
        CTWKhungBieuDo(
            tieuDe: "Cumulative flow",
            phu: "Issues per status at the end of each day · last \(c.days ?? 30) days",
            chuGiai: dai.reversed().map { CTWMucChuGiai(ten: $0.name ?? $0.key, mau: mau[$0.key] ?? CTWMauChuoi.khac) },
            cot: ["Day"] + dai.reversed().map { $0.name ?? $0.key },
            hang: (c.points ?? []).map { p in
                CTWHangBang(nhan: NgayCTW.nganTu(p.day) ?? p.day, giaTri: dai.reversed().map { CTWSo.gon(p.giaTri[$0.key] ?? 0) })
            },
            cao: cao
        ) {
            Chart(diem) { d in
                AreaMark(x: .value("Day", d.ngay, unit: .day), y: .value("Issues", d.giaTri), stacking: .standard)
                    .foregroundStyle(by: .value("Status", d.tenDai))
                    .interpolationMethod(.monotone)
            }
            .chartForegroundStyleScale(domain: dai.map { $0.name ?? $0.key }, range: dai.map { mau[$0.key] ?? CTWMauChuoi.khac })
            .chartLegend(.hidden)
            .modifier(TrucNgayCTW())
        }
    }

    /// Màu dải: DONE = xanh thành công; các dải còn lại theo thứ tự cố định của bảng màu
    /// (TODO dùng xám nhạt dần không đủ tách ⇒ dùng màu phân loại, theo THỨ TỰ dải của quy trình).
    private func mauDai(_ dai: [CTWCfdDai]) -> [String: Color] {
        var m: [String: Color] = [:]
        var i = 0
        for d in dai.reversed() {
            if d.category == "DONE" { m[d.key] = AppColors.success } else { m[d.key] = CTWMauChuoi.mau(i == 5 ? 6 : i); i += 1 }
        }
        return m
    }
}

struct TrucNgayCTW: ViewModifier {
    func body(content: Content) -> some View {
        content
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine().foregroundStyle(AppColors.divider)
                AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: false)
            } }
            .chartYAxis { AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(AppColors.divider)
                AxisValueLabel()
            } }
    }
}

// MARK: Throughput

struct BieuDoThroughputCTW: View {
    let t: CTWThroughput
    var cao: CGFloat = 200

    var body: some View {
        let ds = (t.weeks ?? []).compactMap { w in NgayCTW.ngay(w.week).map { (w, $0) } }
        CTWKhungBieuDo(
            tieuDe: "Throughput",
            phu: t.average.map { "Issues finished per week · average \(CTWSo.gon($0))" } ?? "Issues finished per week",
            cot: ["Week of", "Issues", DonViSprintCTW.tenDai(t.unit).capitalized],
            hang: ds.map { CTWHangBang(nhan: NgayCTW.ngan($0.1), giaTri: ["\($0.0.count ?? 0)", CTWSo.gon($0.0.points ?? 0)]) },
            cao: cao
        ) {
            Chart {
                ForEach(ds, id: \.0.week) { w, d in
                    BarMark(x: .value("Week", d, unit: .weekOfYear), y: .value("Issues", w.count ?? 0))
                        .foregroundStyle(CTWMauChuoi.mau(0))
                        .cornerRadius(4)
                }
                if let a = t.average {
                    RuleMark(y: .value("Average", a))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("avg \(CTWSo.gon(a))").font(.ctw(size: 9, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                        }
                }
            }
            .modifier(TrucNgayCTW())
        }
    }
}

// MARK: Cycle time

struct TheCycleTimeCTW: View {
    let c: CTWCycleTime

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cycle & lead time").font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
            Text("Days from start (cycle) or creation (lead) to done · last \(c.days ?? 90) days · \(c.cycle?.n ?? 0) issues")
                .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
            HStack(spacing: 10) {
                CTWTheChiSo(nhan: "Cycle P50", giaTri: ngay(c.cycle?.p50), phu: "half finish faster", bieuTuong: "timer", mau: CTWMauChuoi.mau(0))
                CTWTheChiSo(nhan: "Cycle P85", giaTri: ngay(c.cycle?.p85), phu: "85% finish within", bieuTuong: "timer", mau: CTWMauChuoi.mau(0))
            }
            HStack(spacing: 10) {
                CTWTheChiSo(nhan: "Lead P50", giaTri: ngay(c.lead?.p50), bieuTuong: "clock.arrow.circlepath", mau: CTWMauChuoi.mau(1))
                CTWTheChiSo(nhan: "Lead P85", giaTri: ngay(c.lead?.p85), bieuTuong: "clock.arrow.circlepath", mau: CTWMauChuoi.mau(1))
            }
        }
        .padding(14)
        .ctwThe(14)
    }

    private func ngay(_ v: Double?) -> String { v.map { "\(CTWSo.gon($0))d" } ?? "—" }
}

// MARK: Created vs resolved

struct BieuDoTaoXongCTW: View {
    let ds: [CTWTaoXongNgay]
    var cao: CGFloat = 220

    var body: some View {
        let diem = ds.compactMap { d in NgayCTW.ngay(d.day).map { (d, $0) } }
        let tong = TinhBaoCaoCTW.taoXong(ds)
        CTWKhungBieuDo(
            tieuDe: "Created vs resolved",
            phu: "\(tong.tao) created · \(tong.xong) resolved · " + (tong.chenh > 0 ? "backlog grew by \(tong.chenh)" : (tong.chenh < 0 ? "backlog shrank by \(-tong.chenh)" : "backlog steady")),
            chuGiai: [CTWMucChuGiai(ten: "Created", mau: CTWMauChuoi.mau(1)), CTWMucChuGiai(ten: "Resolved", mau: CTWMauChuoi.mau(0))],
            cot: ["Day", "Created", "Resolved"],
            hang: diem.map { CTWHangBang(nhan: NgayCTW.ngan($0.1), giaTri: ["\($0.0.created ?? 0)", "\($0.0.resolved ?? 0)"]) },
            cao: cao
        ) {
            Chart {
                ForEach(diem, id: \.0.day) { d, n in
                    LineMark(x: .value("Day", n, unit: .day), y: .value("Issues", d.created ?? 0), series: .value("Series", "Created"))
                        .foregroundStyle(CTWMauChuoi.mau(1)).lineStyle(StrokeStyle(lineWidth: 2)).interpolationMethod(.monotone)
                    LineMark(x: .value("Day", n, unit: .day), y: .value("Issues", d.resolved ?? 0), series: .value("Series", "Resolved"))
                        .foregroundStyle(CTWMauChuoi.mau(0)).lineStyle(StrokeStyle(lineWidth: 2)).interpolationMethod(.monotone)
                }
            }
            .modifier(TrucNgayCTW())
        }
    }
}

// MARK: Phân bố (cột ngang)

struct BieuDoPhanBoCTW: View {
    let tieuDe: String
    var phu: String?
    let thanh: [ThanhPhanBoCTW]
    var tong: Double
    var donVi: String = "issues"
    /// Màu theo nhóm trạng thái (groupBy=status/statusCategory).
    var mauTrangThai = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tieuDe).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    Text(phu ?? "\(CTWSo.gon(tong)) \(donVi) in total").font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                }
                Spacer()
            }
            if thanh.isEmpty {
                Text("No data yet.").font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
            }
            ForEach(thanh) { t in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if mauTrangThai { Circle().fill(mau(t)).frame(width: 7, height: 7) }
                        Text(t.nhan).font(.ctw(size: 13)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                        Spacer(minLength: 8)
                        Text(CTWSo.gon(t.giaTri)).font(.ctw(size: 13, weight: .semibold).monospacedDigit()).foregroundColor(AppColors.textPrimary)
                        Text("\(Int((t.tiLe * 100).rounded()))%").font(.ctw(size: 12).monospacedDigit())
                            .foregroundColor(AppColors.textTertiary).frame(width: 38, alignment: .trailing)
                    }
                    GeometryReader { g in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(mau(t))
                            .frame(width: max(g.size.width * CGFloat(t.tiLe / (thanh.map(\.tiLe).max() ?? 1)), 4))
                    }
                    .frame(height: 8)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(t.nhan): \(CTWSo.gon(t.giaTri)) \(donVi), \(Int((t.tiLe * 100).rounded())) percent")
            }
        }
        .padding(14)
        .ctwThe(14)
    }

    private func mau(_ t: ThanhPhanBoCTW) -> Color {
        if t.viTriMau == 8 { return CTWMauChuoi.khac }
        if mauTrangThai { return CTWMauChuoi.nhom(t.category ?? (t.id.hasPrefix("DONE") ? "DONE" : (t.id == "IN_PROGRESS" ? "IN_PROGRESS" : nil))) }
        return CTWMauChuoi.mau(0)
    }
}

// MARK: KPI

struct HangKpiCTW: View {
    let k: CTWKpis
    var soCot: Int = 2

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: soCot), spacing: 10) {
            CTWTheChiSo(nhan: "Open issues", giaTri: so(k.open?.value), phu: xu(k.open), bieuTuong: "tray.full", mau: CTWMauChuoi.mau(0))
            CTWTheChiSo(nhan: "Overdue", giaTri: so(k.overdue?.value), phu: xu(k.overdue), bieuTuong: "exclamationmark.circle",
                        mau: (k.overdue?.value ?? 0) > 0 ? AppColors.error : AppColors.success)
            CTWTheChiSo(nhan: "Blocked", giaTri: so(k.blocked?.value), bieuTuong: "hand.raised", mau: AppColors.warning)
            if let s = k.sprint {
                CTWTheChiSo(nhan: s.name ?? "Sprint", giaTri: s.pctDone.map { "\(Int($0.rounded()))%" } ?? "—",
                            phu: nhanNhip(s.status) + (s.daysLeft.map { " · \($0)d left" } ?? ""), bieuTuong: "flag.checkered",
                            mau: s.status == "AT_RISK" ? AppColors.warning : AppColors.primary)
            } else if let r = k.highRisks {
                CTWTheChiSo(nhan: "High risks", giaTri: "\(r)", bieuTuong: "shield.lefthalf.filled", mau: r > 0 ? AppColors.error : AppColors.success)
            }
        }
    }

    private func so(_ v: Double?) -> String { v.map(CTWSo.gon) ?? "—" }
    private func xu(_ k: CTWKpiSo?) -> String? {
        guard let v = k?.value, let p = k?.previous else { return nil }
        let d = v - p
        if d == 0 { return "Same as 7 days ago" }
        return "\(d > 0 ? "▲" : "▼") \(CTWSo.gon(abs(d))) vs 7 days ago"
    }

    static func nhanNhipTinh(_ s: String?) -> String {
        switch s {
        case "ON_TRACK": return "On track"
        case "AT_RISK": return "At risk"
        case "DONE": return "Done"
        case "TOO_EARLY": return "Too early to tell"
        case "NO_ESTIMATES": return "No estimates"
        default: return "—"
        }
    }
    private func nhanNhip(_ s: String?) -> String { Self.nhanNhipTinh(s) }
}

// MARK: Tải theo người

struct BieuDoTaiNguoiCTW: View {
    let t: CTWTaiTheoNguoi

    var body: some View {
        let ds = t.people ?? []
        let maxTong = max(ds.map { $0.total ?? 0 }.max() ?? 1, 1)
        VStack(alignment: .leading, spacing: 10) {
            Text("Workload").font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
            CTWChuGiai(muc: [CTWMucChuGiai(ten: "In progress", mau: CTWMauChuoi.mau(0)), CTWMucChuGiai(ten: "To do", mau: CTWMauChuoi.khac)])
            ForEach(Array(ds.enumerated()), id: \.offset) { _, p in
                HStack(spacing: 10) {
                    if let u = p.user { CTWAvatar(user: u, size: 26) } else {
                        Image(systemName: "person.crop.circle.badge.questionmark").font(.ctw(size: 20)).foregroundColor(AppColors.textTertiary).frame(width: 26)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(p.user?.ten ?? "Unassigned").font(.ctw(size: 13, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                            if p.user?.laAgent == true { CTWNhanAI() }
                            Spacer(minLength: 4)
                            if (p.overdue ?? 0) > 0 {
                                Text("\(p.overdue ?? 0) overdue").font(.ctw(size: 11, weight: .semibold)).foregroundColor(AppColors.error)
                            }
                            Text("\(p.total ?? 0)").font(.ctw(size: 13, weight: .semibold).monospacedDigit()).foregroundColor(AppColors.textPrimary)
                        }
                        GeometryReader { g in
                            CTWThanhTienDo(doan: [CTWDoanTienDo(ten: "In progress", giaTri: Double(p.inProgress ?? 0), mau: CTWMauChuoi.mau(0)),
                                                 CTWDoanTienDo(ten: "To do", giaTri: Double(p.todo ?? 0), mau: CTWMauChuoi.khac)], cao: 7)
                                .frame(width: max(g.size.width * CGFloat(Double(p.total ?? 0) / Double(maxTong)), 8))
                        }
                        .frame(height: 7)
                    }
                }
                .frame(minHeight: 40)
            }
        }
        .padding(14)
        .ctwThe(14)
    }
}
