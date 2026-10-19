import SwiftUI

// MARK: - Kiểm thử — màn chính: Chu kỳ · Ca kiểm thử · Báo cáo FPT
//
// Chu kỳ là chỗ tester LÀM VIỆC (chạy từng lượt trên điện thoại) nên là mặc
// định. Mục FPT chỉ hiện khi dự án đã có dữ liệu Report 5.1/5.2/5.3 — không
// hiện một trang rỗng (2.1).

@MainActor
final class KiemThuVM: ObservableObject {
    let pid: Int
    @Published var chuKy: [CTWTestCycle]?
    @Published var ca: [CTWTestCase]?
    @Published var fptUnit: CTWFptUnitList?
    @Published var fptInt: CTWFptItList?
    @Published var fptSys: CTWFptItList?
    @Published var loi: String?

    init(pid: Int) { self.pid = pid }

    var coFpt: Bool {
        !(fptUnit?.functions ?? []).isEmpty || !(fptInt?.modules ?? []).isEmpty || !(fptSys?.modules ?? []).isEmpty
    }

    func taiChuKy() async {
        do { chuKy = try await APIClient.shared.request(CTWAPI.dsChuKy(pid: pid)); loi = nil }
        catch { loi = CTW.loi(error) }
    }

    func taiCa(_ q: String = "") async {
        do { ca = try await APIClient.shared.request(CTWAPI.dsTest(pid: pid, q: q)); loi = nil }
        catch { if !Task.isCancelled { loi = CTW.loi(error) } }
    }

    /// FPT: lỗi (vd khách bị chặn 403) ⇒ coi như không có — mục tự ẩn.
    func taiFpt() async {
        async let u: CTWFptUnitList? = try? APIClient.shared.request(CTWAPI.fptUnit(pid: pid))
        async let i: CTWFptItList? = try? APIClient.shared.request(CTWAPI.fptIt(pid: pid, kieu: "integration"))
        async let s: CTWFptItList? = try? APIClient.shared.request(CTWAPI.fptIt(pid: pid, kieu: "system"))
        (fptUnit, fptInt, fptSys) = await (u, i, s)
    }
}

struct KiemThuCTW: View {
    let pid: Int
    let maDuAn: String
    @StateObject private var vm: KiemThuVM
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var muc: Muc = .chuKy
    @State private var tim = ""

    enum Muc: String, CaseIterable, Identifiable {
        case chuKy = "Cycles", ca = "Test cases", fpt = "FPT reports"
        var id: String { rawValue }
    }

    init(pid: Int, maDuAn: String) {
        self.pid = pid
        self.maDuAn = maDuAn
        _vm = StateObject(wrappedValue: KiemThuVM(pid: pid))
    }

    var body: some View {
        List {
            Section {
                Picker("View", selection: $muc) {
                    ForEach(Muc.allCases.filter { $0 != .fpt || vm.coFpt }) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }
            if let loi = vm.loi {
                CTWErrorBanner(text: loi) { vm.loi = nil }
                    .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            switch muc {
            case .chuKy: dsChuKy
            case .ca: dsCa
            case .fpt: FptTongQuanCTW(pid: pid, vm: vm)
            }
        }
        .ctwKieuDanhSach()
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Tests")
        .ctwTieuDeNho()
        .modifier(TimNeuCan(bat: muc == .ca, tim: $tim))
        .task(id: tim) {
            guard muc == .ca, vm.ca != nil else { return }
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await vm.taiCa(tim)
        }
        .onChange(of: muc) { _, m in
            if m == .ca && vm.ca == nil { Task { await vm.taiCa() } }
        }
        .refreshable {
            switch muc {
            case .chuKy: await vm.taiChuKy()
            case .ca: await vm.taiCa(tim)
            case .fpt: await vm.taiFpt()
            }
        }
        .task {
            if vm.chuKy == nil {
                async let a: Void = vm.taiChuKy()
                async let b: Void = vm.taiFpt()
                _ = await (a, b)
            }
        }
        // Đích `/work/<ws>/<KEY>/tests?run=<id>` | `?cycle=<id>` ⇒ mở thẳng.
        .task(id: app.dichCho) {
            guard let d = app.dichCho, d.moDun == "tests" else { return }
            defer { app.dichCho = nil }
            if let r = d.duongDan.tham["run"].flatMap(Int.init) {
                nganXep.duong.append(RouteLuotChayCTW(pid: pid, id: r))
            } else if let c = d.duongDan.tham["cycle"].flatMap(Int.init) {
                nganXep.duong.append(RouteChuKyCTW(pid: pid, id: c, ten: "Test cycle"))
            }
        }
        #if DEBUG
        .onAppear {
            guard let con = XemThuCTW.conCua("tests"), nganXep.duong.count <= 1 else { return }
            switch con {
            case "run": nganXep.duong.append(RouteLuotChayCTW(pid: pid, id: 555))
            case "cycle": nganXep.duong.append(RouteChuKyCTW(pid: pid, id: 9, ten: "Sprint 6 — iOS regression"))
            case "case": nganXep.duong.append(RouteTestCTW(pid: pid, so: 42, ten: "Sign in with Apple"))
            case "fpt": muc = .fpt
            case "matrix": nganXep.duong.append(RouteFptHamCTW(pid: pid, id: 1, ten: "AuthService.login"))
            case "it": nganXep.duong.append(RouteFptModuleCTW(pid: pid, kieu: "integration", id: 1, ten: "Login & session"))
            case "cases": muc = .ca
            default: break
            }
        }
        #endif
    }

    // MARK: Chu kỳ

    @ViewBuilder private var dsChuKy: some View {
        if let ds = vm.chuKy {
            if ds.isEmpty {
                CTWOTrong(bieuTuong: "checkmark.seal", tieuDe: "No test cycles yet",
                          moTa: "Create a cycle on the web to group test runs for a sprint, build or environment. Runs then show up here to execute on your phone.")
                    .listRowBackground(Color.clear)
            } else {
                let dangChay = ds.filter { $0.state != "DONE" }
                let xong = ds.filter { $0.state == "DONE" }
                if !dangChay.isEmpty {
                    Section("Active") { ForEach(dangChay) { hangChuKy($0) } }
                }
                if !xong.isEmpty {
                    Section("Completed") { ForEach(xong) { hangChuKy($0) } }
                }
            }
        } else if vm.loi == nil {
            CTWKhungTai(soHang: 4, coAvatar: false).listRowBackground(Color.clear).listRowInsets(EdgeInsets())
        }
    }

    private func hangChuKy(_ c: CTWTestCycle) -> some View {
        NavigationLink(value: RouteChuKyCTW(pid: pid, id: c.id, ten: c.name)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(c.name).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    CTWChipChu(chu: c.state)
                }
                HStack(spacing: 6) {
                    if let e = c.environment, !e.isEmpty { CTWNhanNho(chu: e, bieuTuong: "desktopcomputer") }
                    if let b = c.build, !b.isEmpty { CTWNhanNho(chu: b, bieuTuong: "shippingbox") }
                    if let p = c.plan?.name { CTWNhanNho(chu: p, bieuTuong: "list.bullet.rectangle") }
                }
                CTWThanhTienDoTest(counts: c.counts ?? [:])
                Text(moTaTienDo(c)).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
            }
            .padding(.vertical, 4)
        }
    }

    private func moTaTienDo(_ c: CTWTestCycle) -> String {
        var p = ["\(c.executed ?? 0)/\(c.total ?? 0) executed"]
        if let r = c.passRate { p.append("\(Int(r))% passed") }
        if c.dem("FAIL") > 0 { p.append("\(c.dem("FAIL")) failed") }
        if c.dem("BLOCKED") > 0 { p.append("\(c.dem("BLOCKED")) blocked") }
        return p.joined(separator: " · ")
    }

    // MARK: Ca kiểm thử

    @ViewBuilder private var dsCa: some View {
        if let ds = vm.ca {
            if ds.isEmpty {
                CTWOTrong(bieuTuong: "doc.text.magnifyingglass",
                          tieuDe: tim.isEmpty ? "No test cases yet" : "No test cases match “\(tim)”",
                          moTa: tim.isEmpty ? "Test cases are issues of type Test. Your team writes their steps on the web." : "")
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(ds) { t in
                        NavigationLink(value: RouteTestCTW(pid: pid, so: t.number, ten: t.title)) { hangCa(t) }
                    }
                } header: { Text("\(ds.count) test case\(ds.count == 1 ? "" : "s")") }
            }
        } else if vm.loi == nil {
            CTWKhungTai(soHang: 6, coAvatar: false).listRowBackground(Color.clear).listRowInsets(EdgeInsets())
        }
    }

    private func hangCa(_ t: CTWTestCase) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: CTWLuatTest.bieuTuong(t.lastRun?.status))
                .font(.ctw(size: 18)).foregroundColor(CTWLuatTest.mau(t.lastRun?.status))
                .frame(width: 24)
                .accessibilityLabel("Last run: \(CTWLuatTest.nhan(t.lastRun?.status))")
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(maDuAn)-\(t.number)").font(.ctw(size: 12, weight: .medium).monospaced())
                        .foregroundColor(AppColors.textSecondary)
                    CTWPriorityIcon(priority: t.priority)
                    if t.kind == "GHERKIN" { CTWNhanNho(chu: "Gherkin") }
                }
                Text(t.title).font(.ctw(size: 15)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                HStack(spacing: 8) {
                    Label("\(t.stepCount ?? 0) steps", systemImage: "list.number")
                    if let r = t.requirements, !r.isEmpty { Label("\(r.count) req", systemImage: "link") }
                    if let lr = t.lastRun, lr.status != nil {
                        Text([CTWLuatTest.nhan(lr.status), lr.cycleName].compactMap { $0 }.joined(separator: " · "))
                            .lineLimit(1)
                    } else {
                        Text("Never run")
                    }
                }
                .font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                .labelStyle(.titleAndIcon)
            }
        }
        .padding(.vertical, 2)
    }
}

/// `.searchable` chỉ ở mục Ca kiểm thử (ô tìm ở mục Chu kỳ thì vô nghĩa).
private struct TimNeuCan: ViewModifier {
    let bat: Bool
    @Binding var tim: String
    func body(content: Content) -> some View {
        if bat { content.searchable(text: $tim, prompt: "Search tests or keys") } else { content }
    }
}

/// Thanh tiến độ chu kỳ: Passed · Failed · Blocked · Skipped · còn lại.
struct CTWThanhTienDoTest: View {
    let counts: [String: Int]
    var cao: CGFloat = 8
    var body: some View {
        CTWThanhPhanDoan(doan: [
            (counts["PASS"] ?? 0, CTWLuatTest.mau("PASS")),
            (counts["FAIL"] ?? 0, CTWLuatTest.mau("FAIL")),
            (counts["BLOCKED"] ?? 0, CTWLuatTest.mau("BLOCKED")),
            (counts["SKIP"] ?? 0, CTWLuatTest.mau("SKIP")),
            ((counts["IN_PROGRESS"] ?? 0) + (counts["RETEST"] ?? 0), CTWLuatTest.mau("IN_PROGRESS")),
            (counts["TODO"] ?? 0, Color.clear),
        ], cao: cao)
    }
}

// MARK: - Chi tiết chu kỳ

struct ChuKyCTW: View {
    let pid: Int
    let id: Int
    let ten: String
    @EnvironmentObject private var app: AppState
    @State private var ck: CTWTestCycle?
    @State private var loi: String?
    @State private var loc = "ALL"

    private let boLoc: [(ma: String, nhan: String)] = [
        ("ALL", "All"), ("TODO", "To do"), ("FAIL", "Failed"), ("BLOCKED", "Blocked"), ("PASS", "Passed"),
    ]

    var body: some View {
        List {
            if let loi {
                CTWErrorBanner(text: loi) { self.loi = nil }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            if let c = ck {
                Section { dau(c) }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                Section {
                    CTWThanhLoc(chip: boLoc.map { l in
                        CTWChipLoc(id: l.ma, nhan: l.ma == "ALL" ? "All \(c.total ?? 0)" : "\(l.nhan) \(demLoc(c, l.ma))", bat: loc == l.ma)
                    }) { loc = $0.id }
                    .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                }
                let ds = (c.runs ?? []).filter(khop)
                Section {
                    if ds.isEmpty {
                        Text("No runs in this filter.").font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
                    }
                    ForEach(ds) { r in
                        NavigationLink(value: RouteLuotChayCTW(pid: pid, id: r.id)) { hang(r) }
                    }
                } header: { Text("Runs") }
            } else if loi == nil {
                CTWKhungTai(soHang: 6).listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
        }
        .ctwKieuDanhSach()
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundPrimary)
        .navigationTitle(ck?.name ?? ten)
        .ctwTieuDeNho()
        .refreshable { await tai() }
        .task { await tai() }
    }

    private func tai() async {
        do { ck = try await APIClient.shared.request(CTWAPI.chuKy(pid: pid, id: id)); loi = nil }
        catch { loi = CTW.loi(error) }
    }

    /// "To do" gồm cả lượt đang làm dở và lượt cần chạy lại — đều là việc còn phải làm.
    private func khop(_ r: CTWCycleRun) -> Bool {
        switch loc {
        case "ALL": return true
        case "TODO": return ["TODO", "IN_PROGRESS", "RETEST", nil].contains(r.status)
        default: return r.status == loc
        }
    }

    private func demLoc(_ c: CTWTestCycle, _ ma: String) -> Int {
        ma == "TODO" ? c.dem("TODO") + c.dem("IN_PROGRESS") + c.dem("RETEST") : c.dem(ma)
    }

    private func dau(_ c: CTWTestCycle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                CTWChipChu(chu: c.state)
                if let e = c.environment, !e.isEmpty { CTWNhanNho(chu: e, bieuTuong: "desktopcomputer") }
                if let b = c.build, !b.isEmpty { CTWNhanNho(chu: b, bieuTuong: "shippingbox") }
                Spacer(minLength: 0)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                CTWODem(so: c.passRate.map { "\(Int($0))%" } ?? "—", nhan: "Pass rate", bieuTuong: "percent", mau: AppColors.success)
                CTWODem(so: "\(c.executed ?? 0)/\(c.total ?? 0)", nhan: "Executed", bieuTuong: "play.circle", mau: AppColors.primary)
                CTWODem(so: "\(c.dem("FAIL"))", nhan: "Failed", bieuTuong: "xmark.octagon", mau: AppColors.error)
                CTWODem(so: "\(c.dem("BLOCKED"))", nhan: "Blocked", bieuTuong: "hand.raised", mau: AppColors.warning)
            }
            CTWThanhTienDoTest(counts: c.counts ?? [:], cao: 10)
        }
        .padding(.vertical, 6)
    }

    private func hang(_ r: CTWCycleRun) -> some View {
        let key = app.cauHinhDuAn?.key ?? app.luaChon?.maDuAn ?? ""
        return HStack(alignment: .top, spacing: 11) {
            Image(systemName: CTWLuatTest.bieuTuong(r.status))
                .font(.ctw(size: 19)).foregroundColor(CTWLuatTest.mau(r.status)).frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(key)-\(r.test?.number ?? 0)").font(.ctw(size: 12, weight: .medium).monospaced())
                        .foregroundColor(AppColors.textSecondary)
                    CTWPriorityIcon(priority: r.test?.priority)
                    if r.outdated == true {
                        CTWNhanNho(chu: "Outdated", bieuTuong: "exclamationmark.arrow.circlepath", mau: AppColors.warning)
                    }
                }
                Text(r.test?.title ?? "Test").font(.ctw(size: 15)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                HStack(spacing: 6) {
                    Text(CTWLuatTest.nhan(r.status)).foregroundColor(CTWLuatTest.mau(r.status))
                    Text("· \(r.stepCount ?? 0) steps")
                    if let d = r.defects?.filter({ $0.deletedAt == nil }), !d.isEmpty {
                        Label("\(d.count)", systemImage: "ladybug.fill").foregroundColor(AppColors.error)
                    }
                    Spacer(minLength: 0)
                    if let u = r.executedBy {
                        CTWAvatar(user: u, size: 18)
                        if u.laAgent { CTWNhanAI() }
                    }
                }
                .font(.ctw(size: 11, weight: .medium)).foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Chi tiết ca kiểm thử (chỉ đọc) + "Chạy trong chu kỳ…"

struct TestChiTietCTW: View {
    let pid: Int
    let so: Int
    let ten: String
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var t: CTWTestDetail?
    @State private var chuKy: [CTWTestCycle] = []
    @State private var loi: String?
    @State private var dangThem = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }
                if let t {
                    noiDung(t)
                } else if loi == nil {
                    CTWKhungTai(soHang: 4, coAvatar: false)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("\(app.cauHinhDuAn?.key ?? app.luaChon?.maDuAn ?? "")-\(so)")
        .ctwTieuDeNho()
        .toolbar {
            if app.cauHinhDuAn?.coTheSua == true, !chuKy.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Section("Run in cycle") {
                            ForEach(chuKy.filter { $0.state != "DONE" }) { c in
                                Button(c.name) { Task { await chayTrong(c) } }
                            }
                        }
                    } label: {
                        if dangThem { ProgressView() } else { Label("Run", systemImage: "play.circle") }
                    }
                    .disabled(dangThem)
                }
            }
        }
        .refreshable { await tai() }
        .task { await tai() }
    }

    private func tai() async {
        do {
            async let a: CTWTestDetail = APIClient.shared.request(CTWAPI.test(pid: pid, so: so))
            async let b: [CTWTestCycle]? = try? APIClient.shared.request(CTWAPI.dsChuKy(pid: pid))
            let (x, y) = try await (a, b)
            t = x
            chuKy = (y ?? []).filter { $0.state != "DONE" }
            loi = nil
        } catch { loi = CTW.loi(error) }
    }

    /// Không có lượt chạy lẻ ⇒ thêm ca vào chu kỳ rồi đọc lại chu kỳ để tìm id lượt.
    /// Ca đã có trong chu kỳ thì máy chủ giữ lượt cũ — vẫn tìm được và mở.
    private func chayTrong(_ c: CTWTestCycle) async {
        dangThem = true
        defer { dangThem = false }
        do {
            try await APIClient.shared.send(CTWAPI.themVaoChuKy(pid: pid, id: c.id, so: [so]))
            let ck: CTWTestCycle = try await APIClient.shared.request(CTWAPI.chuKy(pid: pid, id: c.id))
            if let r = ck.runs?.first(where: { $0.test?.number == so }) {
                CTWRung.thanhCong()
                nganXep.duong.append(RouteLuotChayCTW(pid: pid, id: r.id))
            } else {
                loi = "The test was added, but its run isn't ready yet. Pull to refresh the cycle."
            }
        } catch { CTWRung.loi(); loi = CTW.loi(error) }
    }

    @ViewBuilder private func noiDung(_ t: CTWTestDetail) -> some View {
        Text(t.title).font(.ctw(size: 24, weight: .bold)).foregroundColor(AppColors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
        HStack(spacing: 6) {
            CTWNhanNho(chu: t.kind == "GHERKIN" ? "Gherkin" : "Manual", bieuTuong: "checkmark.seal")
            ForEach(t.plans ?? []) { p in CTWNhanNho(chu: p.name ?? "Plan", bieuTuong: "list.bullet.rectangle") }
        }
        if let p = t.preconditions, !p.isEmpty {
            CTWSectionHeader("flag", "Preconditions")
            Text(p).font(.ctw(size: 15)).foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading).padding(12).ctwThe(12)
        }
        if let g = t.gherkin, !g.isEmpty {
            CTWSectionHeader("text.alignleft", "Scenario")
            CTWKhoiView(khoi: [.ma(g)])
        }
        let buoc = (t.steps ?? []).sorted { ($0.position ?? 0) < ($1.position ?? 0) }
        if !buoc.isEmpty {
            CTWSectionHeader("list.number", "Steps", count: "\(buoc.count)")
            VStack(spacing: 10) {
                ForEach(Array(buoc.enumerated()), id: \.element.id) { i, s in
                    CTWBuocTestView(so: i + 1, action: s.action, data: s.data, expected: s.expected)
                }
            }
        }
        let luot = t.runs ?? []
        CTWSectionHeader("clock.arrow.circlepath", "Recent runs", count: luot.isEmpty ? nil : "\(luot.count)")
        if luot.isEmpty {
            Text("This test hasn't been run yet.").font(.ctw(size: 13)).foregroundColor(AppColors.textTertiary)
        } else {
            VStack(spacing: 0) {
                ForEach(luot) { r in
                    NavigationLink(value: RouteLuotChayCTW(pid: pid, id: r.id)) {
                        HStack(spacing: 10) {
                            Image(systemName: CTWLuatTest.bieuTuong(r.status)).foregroundColor(CTWLuatTest.mau(r.status))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.cycle?.name ?? "Cycle").font(.ctw(size: 14, weight: .medium))
                                    .foregroundColor(AppColors.textPrimary).lineLimit(1)
                                Text([CTWLuatTest.nhan(r.status), r.cycle?.environment, r.executedAt.map { CTW.thoiDiem($0) }]
                                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.ctw(size: 11)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            if let u = r.executedBy { CTWAvatar(user: u, size: 22) }
                            Image(systemName: "chevron.right").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if r.id != luot.last?.id { Divider() }
                }
            }
            .padding(.horizontal, 14)
            .ctwThe(12)
        }
    }
}

/// Thẻ một bước (dùng chung cho ca kiểm thử và lượt chạy): số · thao tác · dữ liệu · kết quả mong đợi.
struct CTWBuocTestView<Duoi: View>: View {
    let so: Int
    let action: String?
    let data: String?
    let expected: String?
    var trangThai: String?
    @ViewBuilder var duoi: () -> Duoi

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(so)")
                .font(.ctw(size: 13, weight: .bold).monospacedDigit())
                .foregroundColor(trangThai == nil || trangThai == "TODO" ? AppColors.primary : .white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(nenSo))
                .accessibilityLabel("Step \(so)")
            VStack(alignment: .leading, spacing: 8) {
                Text(action ?? "—").font(.ctw(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let d = data, !d.isEmpty {
                    nhan("Data", d, mono: true)
                }
                if let e = expected, !e.isEmpty {
                    nhan("Expected", e, mono: false)
                }
                duoi()
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .ctwThe(14)
    }

    private var nenSo: Color {
        guard let t = trangThai, t != "TODO" else { return AppColors.primary.opacity(0.12) }
        return CTWLuatTest.mau(t)
    }

    private func nhan(_ ten: String, _ gt: String, mono: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(ten.uppercased()).font(.ctw(size: 10, weight: .bold)).foregroundColor(AppColors.textTertiary)
            Text(gt).font(mono ? .ctw(size: 13, design: .monospaced) : .ctw(size: 14))
                .foregroundColor(AppColors.textSecondary).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension CTWBuocTestView where Duoi == EmptyView {
    init(so: Int, action: String?, data: String?, expected: String?) {
        self.init(so: so, action: action, data: data, expected: expected, trangThai: nil) { EmptyView() }
    }
}
