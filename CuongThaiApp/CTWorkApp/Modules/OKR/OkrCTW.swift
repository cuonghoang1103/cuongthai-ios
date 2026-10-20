import SwiftUI
import Charts
import Combine

// MARK: - OKRs: mục tiêu + kết quả then chốt (dự án / không gian), check-in hằng tuần
//
// Máy chủ tự chọn chu kỳ đang chạy khi không truyền `cycle`. Không gian: GUEST ⇒ 404 (app báo
// "not available"). Agent chỉ đọc. Quyền sửa/check-in theo `canEdit`/`canCheckin` máy chủ trả.

@MainActor
final class OkrVM: ObservableObject {
    enum PhamVi: String, CaseIterable, Identifiable {
        case duAn = "Project", khongGian = "Workspace"
        var id: String { rawValue }
        var ten: String { self == .duAn ? String(localized: "Project") : String(localized: "Workspace") }
    }
    let pid: Int
    @Published var phamVi: PhamVi = .duAn
    @Published var chuKy: Int?
    @Published var view: TaiCTW<CTWOkrView> = .dangTai
    @Published var loi: String?

    init(pid: Int) { self.pid = pid }

    func tai(app: AppState) async {
        if view.giaTri == nil { view = .dangTai }
        do {
            switch phamVi {
            case .duAn:
                view = .xong(try await APIClient.shared.request(CTWAPI.okrDuAn(pid: pid, chuKy: chuKy)))
            case .khongGian:
                guard let w = await app.idKhongGian() else { view = .loi(String(localized: "Couldn't find this workspace.")); return }
                view = .xong(try await APIClient.shared.request(CTWAPI.okrKhongGian(wid: w, chuKy: chuKy)))
            }
        } catch {
            view = .loi(phamVi == .khongGian && CTW.loi(error).lowercased().contains("not found")
                        ? String(localized: "Workspace OKRs aren't available to guests.") : CTW.loi(error))
        }
    }
}

struct OkrCTW: View {
    let nguCanh: CTWNguCanh
    @EnvironmentObject private var app: AppState
    @StateObject private var vm: OkrVM
    @Environment(\.horizontalSizeClass) private var beRong
    @State private var checkin: CTWOkrKR?
    @State private var xemKR: CTWOkrKR?
    @State private var huyNghe: AnyCancellable?

    init(nguCanh: CTWNguCanh) {
        self.nguCanh = nguCanh
        _vm = StateObject(wrappedValue: OkrVM(pid: nguCanh.pid))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Scope", selection: $vm.phamVi) {
                    ForEach(OkrVM.PhamVi.allCases) { Text($0.ten).tag($0) }
                }
                .pickerStyle(.segmented)
                switch vm.view {
                case .dangTai: CTWKhungTai(soHang: 4, coAvatar: false).padding(-Spacing.md)
                case .loi(let l): CTWOLoi(loi: l) { Task { await vm.tai(app: app) } }
                case .xong(let v): noiDung(v)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("OKRs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let ck = vm.view.giaTri?.cycles, !ck.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ForEach(ck) { c in
                            Button { vm.chuKy = c.id } label: {
                                if c.id == vm.view.giaTri?.cycle?.id { Label(c.name ?? String(localized: "Cycle"), systemImage: "checkmark") }
                                else { Text(c.status == "CLOSED" ? String(localized: "\(c.name ?? String(localized: "Cycle")) (closed)") : (c.name ?? String(localized: "Cycle"))) }
                            }
                        }
                    } label: { Label(vm.view.giaTri?.cycle?.name ?? String(localized: "Cycle"), systemImage: "calendar") }
                    .accessibilityLabel("Choose OKR cycle")
                }
            }
        }
        .refreshable { await vm.tai(app: app) }
        .task(id: "\(vm.phamVi.rawValue)-\(vm.chuKy ?? 0)") { await vm.tai(app: app) }
        .onAppear {
            RealtimeKeHoachCTW.shared.nghe(pid: nguCanh.pid)
            huyNghe = RealtimeKeHoachCTW.shared.suKienAgile
                .filter { [pid = nguCanh.pid] in $0.projectId == pid && $0.kind == "okr" }
                .sink { _ in Task { await vm.tai(app: app) } }
        }
        .onDisappear { huyNghe = nil; RealtimeKeHoachCTW.shared.boNghe(pid: nguCanh.pid) }
        .sheet(item: $checkin) { k in
            CheckinKRCTW(kr: k) { Task { await vm.tai(app: app) } }
        }
        .background(EmptyView().sheet(item: $xemKR) { k in ChiTietKRCTW(kr: k) { checkin = k } })
    }

    @ViewBuilder private func noiDung(_ v: CTWOkrView) -> some View {
        if let c = v.cycle {
            Text(dongChuKy(c))
                .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
        }
        if let d = v.dashboard { bangTong(d) }
        let cay = OkrTinh.cay(v.objectives ?? [])
        if cay.isEmpty {
            CTWOTrong(bieuTuong: "scope", tieuDe: String(localized: "No objectives in this cycle"),
                      moTa: vm.phamVi == .duAn ? String(localized: "Objectives for this project appear here once they're added on the web.")
                                              : String(localized: "Workspace objectives appear here once an admin adds them."))
                .ctwThe(14)
        } else {
            let cot = beRong == .regular ? [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)] : [GridItem(.flexible())]
            LazyVGrid(columns: cot, alignment: .leading, spacing: 14) {
                ForEach(cay, id: \.goc.id) { n in
                    VStack(alignment: .leading, spacing: 10) {
                        theMucTieu(n.goc, laCon: false)
                        ForEach(n.con) { c in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "arrow.turn.down.right").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                                    .padding(.top, 14)
                                theMucTieu(c, laCon: true)
                            }
                        }
                    }
                }
            }
        }
    }

    private func dongChuKy(_ c: CTWOkrChuKy) -> String {
        let s = "\(c.name ?? String(localized: "Cycle")) · \(NgayCTW.nganTu(c.startDate) ?? "") – \(NgayCTW.nganTu(c.endDate) ?? "")"
        return c.status == "CLOSED" ? String(localized: "\(s) · Closed") : s
    }

    // MARK: Bảng tổng

    private func bangTong(_ d: CTWOkrBang) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            CTWLuoiChiSo {
                CTWTheChiSo(nhan: String(localized: "Average progress"), giaTri: "\(Int((d.avgProgress ?? 0).rounded()))%",
                            phu: String(localized: "\(d.objectives ?? 0) objectives · \(d.keyResults ?? 0) key results"), bieuTuong: "scope")
                CTWTheChiSo(nhan: String(localized: "Confidence"), giaTri: d.avgConfidence.map { "\(CTWSo.gon($0))/10" } ?? "—",
                            phu: String(localized: "Average of the latest check-ins"), bieuTuong: "gauge.with.dots.needle.50percent", mau: CTWMauChuoi.mau(2))
                CTWTheChiSo(nhan: String(localized: "On track"), giaTri: "\(d.statusCounts?["ON_TRACK"] ?? 0)",
                            phu: String(localized: "At risk \(d.statusCounts?["AT_RISK"] ?? 0) · Off track \(d.statusCounts?["OFF_TRACK"] ?? 0)"),
                            bieuTuong: "checkmark.circle", mau: AppColors.success)
                if let s = d.avgScore {
                    CTWTheChiSo(nhan: String(localized: "Average score"), giaTri: String(format: "%.1f", s), bieuTuong: "star", mau: CTWMauChuoi.mau(3))
                }
            }
            let tuan = d.weeks ?? []
            if tuan.count >= 2 {
                CTWKhungBieuDo(tieuDe: String(localized: "Progress vs expected"), phu: String(localized: "Weekly, across all objectives"),
                               chuGiai: [CTWMucChuGiai(ten: String(localized: "Actual"), mau: AppColors.primary),
                                         CTWMucChuGiai(ten: String(localized: "Expected"), mau: AppColors.textTertiary, netDut: true)],
                               cot: [String(localized: "Week"), String(localized: "Actual"), String(localized: "Expected")],
                               hang: tuan.map { CTWHangBang(nhan: NgayCTW.nganTu($0.week) ?? $0.week,
                                                            giaTri: [$0.actual.map { "\(Int($0))%" } ?? "—", "\(Int($0.expected ?? 0))%"]) },
                               cao: 180) {
                    Chart {
                        ForEach(tuan, id: \.week) { t in
                            if let x = NgayCTW.ngay(t.week) {
                                LineMark(x: .value("Week", x), y: .value("Expected", t.expected ?? 0), series: .value("S", "Expected"))
                                    .foregroundStyle(AppColors.textTertiary)
                                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                                if let a = t.actual {
                                    LineMark(x: .value("Week", x), y: .value("Actual", a), series: .value("S", "Actual"))
                                        .foregroundStyle(AppColors.primary)
                                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                                        .symbol(.circle).symbolSize(28)
                                }
                            }
                        }
                    }
                    .chartYScale(domain: 0...100)
                    .chartYAxis { AxisMarks(position: .leading, values: [0, 50, 100]) { v in
                        AxisGridLine().foregroundStyle(AppColors.divider)
                        AxisValueLabel { if let d = v.as(Double.self) { Text("\(Int(d))%") } }
                    } }
                }
            }
        }
    }

    // MARK: Mục tiêu

    private func theMucTieu(_ o: CTWOkrMucTieu, laCon: Bool) -> some View {
        let mau = mauTrangThai(o.status)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if let k = o.project?.key {
                            Text(k).font(.ctw(size: 10, weight: .bold).monospaced()).foregroundColor(AppColors.primary)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(AppColors.primary.opacity(0.12)))
                        } else {
                            Text("WORKSPACE").font(.ctw(size: 10, weight: .bold)).foregroundColor(AppColors.textSecondary)
                        }
                        Label(OkrTinh.tenTrangThai(o.status), systemImage: OkrTinh.bieuTuong(o.status))
                            .font(.ctw(size: 11, weight: .semibold)).foregroundColor(mau)
                    }
                    Text(o.title ?? "").font(.ctw(size: laCon ? 15 : 17, weight: .bold)).foregroundColor(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                CTWVongTienDo(tiLe: o.progress ?? 0, co: laCon ? 42 : 50, net: 5, mau: mau)
            }
            if let owner = o.owner {
                HStack(spacing: 5) {
                    CTWAvatar(user: owner, size: 18)
                    Text(owner.ten).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                    if owner.laAgent { CTWNhanAI() }
                    Spacer()
                    if let s = o.score {
                        Text("Score \(String(format: "%.1f", s))").font(.ctw(size: 11, weight: .bold))
                            .foregroundColor(o.scoreBand == "GREEN" ? AppColors.success : (o.scoreBand == "RED" ? AppColors.error : AppColors.warning))
                    }
                }
            }
            thanhTienDoKyVong(tienDo: o.progress ?? 0, kyVong: o.expected ?? 0, mau: mau)
            ForEach(o.keyResults ?? []) { k in hangKR(k) }
        }
        .padding(14)
        .ctwThe(14)
    }

    /// Thanh tiến độ + vạch "kỳ vọng" (phần chu kỳ đã trôi).
    private func thanhTienDoKyVong(tienDo: Double, kyVong: Double, mau: Color) -> some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(AppColors.backgroundTertiary)
                Capsule().fill(mau).frame(width: g.size.width * min(max(tienDo, 0), 1))
                Rectangle().fill(AppColors.textPrimary.opacity(0.55)).frame(width: 2, height: 12)
                    .offset(x: g.size.width * min(max(kyVong, 0), 1) - 1)
            }
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityLabel("\(Int((tienDo * 100).rounded())) percent done, \(Int((kyVong * 100).rounded())) percent expected by now")
    }

    private func hangKR(_ k: CTWOkrKR) -> some View {
        Button { xemKR = k } label: {
            HStack(spacing: 10) {
                CTWVongTienDo(tiLe: k.progress ?? 0, co: 34, net: 4, mau: CTWMauChuoi.mau(0))
                VStack(alignment: .leading, spacing: 3) {
                    Text(k.title ?? "").font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        Text(OkrTinh.giaTri(k)).font(.ctw(size: 11, weight: .semibold).monospacedDigit()).foregroundColor(AppColors.textSecondary)
                        if k.tuDong {
                            Label(k.source == "POINTS" ? "from points" : "from issues", systemImage: "link")
                                .font(.ctw(size: 10)).foregroundColor(AppColors.textTertiary)
                        }
                        if let c = k.confidence {
                            Label("\(CTWSo.gon(c))/10", systemImage: "gauge.with.dots.needle.50percent")
                                .font(.ctw(size: 10, weight: .medium)).foregroundColor(c <= 4 ? AppColors.warning : AppColors.textTertiary)
                        }
                    }
                }
                Spacer(minLength: 4)
                if k.canCheckin == true {
                    Button { checkin = k } label: {
                        Text("Check in").font(.ctw(size: 12, weight: .semibold)).padding(.horizontal, 10).frame(minHeight: 32)
                            .background(Capsule().fill(AppColors.primary.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(AppColors.primary)
                }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func mauTrangThai(_ s: String?) -> Color {
        switch s {
        case "ON_TRACK", "DONE", "SCORED": return AppColors.success
        case "AT_RISK": return AppColors.warning
        case "OFF_TRACK": return AppColors.error
        default: return AppColors.textTertiary
        }
    }
}

// MARK: - Chi tiết KR + lịch sử check-in

struct ChiTietKRCTW: View {
    let kr: CTWOkrKR
    let moCheckin: () -> Void
    @Environment(\.dismiss) private var dong

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(kr.title ?? "").font(.ctw(size: 17, weight: .semibold))
                        HStack {
                            CTWVongTienDo(tiLe: kr.progress ?? 0, co: 56)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(OkrTinh.giaTri(kr)).font(.ctw(size: 15, weight: .semibold).monospacedDigit())
                                Text("Started at \(CTWSo.gon(kr.startValue ?? 0))\(kr.unit.map { $0 == "%" ? "%" : " \($0)" } ?? "")")
                                    .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                                if let l = kr.linkSummary {
                                    Text("\(CTWSo.gon(l.done ?? 0)) of \(CTWSo.gon(l.total ?? 0)) \(l.unit ?? "") done (linked work)")
                                        .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                                }
                            }
                        }
                    }
                    if let o = kr.owner {
                        HStack { CTWAvatar(user: o, size: 22); Text(o.ten); if o.laAgent { CTWNhanAI() } }
                    }
                }
                let ds = kr.checkins ?? []
                if ds.count >= 2 {
                    Section("Trend") {
                        Chart(ds.reversed()) { c in
                            if let x = NgayCTW.ngay(c.weekStart) {
                                LineMark(x: .value("Week", x), y: .value("Progress", (c.progress ?? 0) * 100))
                                    .foregroundStyle(AppColors.primary).symbol(.circle)
                            }
                        }
                        .chartYScale(domain: 0...100)
                        .frame(height: 140)
                    }
                }
                Section("Check-ins") {
                    if ds.isEmpty { Text("No check-ins yet.").foregroundColor(AppColors.textSecondary) }
                    ForEach(ds) { c in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Week of \(NgayCTW.nganTu(c.weekStart) ?? "")").font(.ctw(size: 13, weight: .semibold))
                                Spacer()
                                Text("\(CTWSo.gon(c.value ?? 0)) · \(Int(((c.progress ?? 0) * 100).rounded()))%")
                                    .font(.ctw(size: 13).monospacedDigit())
                            }
                            HStack(spacing: 6) {
                                if let u = c.user { CTWAvatar(user: u, size: 16); Text(u.ten).font(.ctw(size: 11)).foregroundColor(AppColors.textSecondary) }
                                Text("Confidence \(CTWSo.gon(c.confidence ?? 0))/10").font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                            }
                            if let n = c.note, !n.isEmpty { Text(n).font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary) }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Key result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dong() } }
                if kr.canCheckin == true {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Check in") { dong(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { moCheckin() } }.bold()
                    }
                }
            }
        }
    }
}

// MARK: - Check-in

struct CheckinKRCTW: View {
    let kr: CTWOkrKR
    let xong: () -> Void
    @Environment(\.dismiss) private var dong
    @State private var giaTri = ""
    @State private var xong01 = false
    @State private var tinCay: Double = 7
    @State private var ghiChu = ""
    @State private var loi: String?
    @State private var dangGui = false

    var body: some View {
        NavigationStack {
            Form {
                Section { Text(kr.title ?? "").font(.ctw(size: 15, weight: .semibold)) }
                if !kr.tuDong {
                    Section {
                        if kr.metric == "BOOLEAN" {
                            Toggle("Achieved", isOn: $xong01)
                        } else {
                            HStack {
                                TextField("Current value", text: $giaTri).keyboardType(.decimalPad)
                                if let u = kr.unit { Text(u).foregroundColor(AppColors.textSecondary) }
                            }
                        }
                    } header: { Text("Current value") } footer: {
                        Text("Target \(CTWSo.gon(kr.targetValue ?? 0))\(kr.unit.map { $0 == "%" ? "%" : " \($0)" } ?? ""). One check-in per week — a second one replaces it.")
                    }
                } else {
                    Section { Text("This key result updates itself from linked issues. Just record how confident you are.")
                        .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary) }
                }
                Section {
                    VStack(alignment: .leading) {
                        HStack { Text("Confidence"); Spacer(); Text("\(Int(tinCay))/10").monospacedDigit().bold() }
                        Slider(value: $tinCay, in: 0...10, step: 1)
                    }
                } footer: { Text("How likely is the team to hit this by the end of the cycle?") }
                Section("Note") { TextField("What changed this week? (optional)", text: $ghiChu, axis: .vertical).lineLimit(2...6) }
                if let loi { Section { Text(loi).foregroundColor(AppColors.error) } }
            }
            .navigationTitle("Check in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await gui() } } label: { if dangGui { ProgressView() } else { Text("Save").bold() } }
                        .disabled(dangGui || (!kr.tuDong && kr.metric != "BOOLEAN" && Double(giaTri.replacingOccurrences(of: ",", with: ".")) == nil))
                }
            }
            .onAppear {
                giaTri = CTWSo.gon(kr.currentValue ?? 0)
                xong01 = (kr.currentValue ?? 0) >= 1
                tinCay = kr.confidence ?? 7
            }
        }
    }

    private func gui() async {
        dangGui = true
        defer { dangGui = false }
        let v: Double? = kr.tuDong ? nil : (kr.metric == "BOOLEAN" ? (xong01 ? 1 : 0) : Double(giaTri.replacingOccurrences(of: ",", with: ".")))
        do {
            let _: CTWOkrCheckinKQ = try await APIClient.shared.request(CTWAPI.checkinKR(kid: kr.id, giaTri: v, tinCay: Int(tinCay), ghiChu: ghiChu))
            CTWRung.thanhCong()
            dong()
            xong()
        } catch {
            loi = DongHoCTW.maLoi(error) == "WORK_OKR_CYCLE_CLOSED" ? String(localized: "This cycle is closed — check-ins are no longer accepted.") : CTW.loi(error)
            CTWRung.loi()
        }
    }
}
