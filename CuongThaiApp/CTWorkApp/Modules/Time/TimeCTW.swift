import SwiftUI
import Charts

// MARK: - Màn Time tracking: đồng hồ đang chạy + ghi giờ + "My week" (bảng giờ của TÔI theo tuần)
//
// Bảng giờ lấy từ `GET /projects/:pid/reports/time?userId=<tôi>` (chỉ cần quyền xem dự án).
// Backend KHÔNG có bảng giờ cá nhân xuyên dự án ⇒ tuần hiện theo dự án đang chọn.
// Module Finance bật ⇒ thêm trạng thái phiếu giờ tuần (SUBMITTED/APPROVED…); 403 ⇒ bỏ qua.

/// Hoạt động chuẩn của worklog (`TL_ACTIVITIES`, `fptReports.ts:277`).
let hoatDongCTW = ["Training", "Analyzing", "Designing", "Coding", "Testing", "Deploying"]

/// Route con của mô-đun Time.
struct RouteWorklogCTW: Hashable { var pid: Int; var so: Int; var tieuDe: String }

@MainActor
final class TuanGioVM: ObservableObject {
    let pid: Int
    @Published var thuHai: String = NgayCTW.ymd(NgayCTW.dauTuan(Date()))
    @Published var baoCao: TaiCTW<CTWBaoCaoGio> = .dangTai
    @Published var phieu: CTWBangGioTuan?

    init(pid: Int) { self.pid = pid }

    var ngay: [TinhGioCTW.Ngay] { TinhGioCTW.theoNgay(baoCao.giaTri?.people ?? [], tuThuHai: thuHai) }
    var tong: Int { TinhGioCTW.tongTuan(ngay) }
    var the: [CTWBaoCaoGio.The] { TinhGioCTW.theoThe(baoCao.giaTri?.people ?? []) }
    var laTuanNay: Bool { thuHai == NgayCTW.ymd(NgayCTW.dauTuan(Date())) }

    func doiTuan(_ n: Int) {
        guard let d = NgayCTW.ngay(thuHai) else { return }
        thuHai = NgayCTW.ymd(NgayCTW.cong(d, ngay: 7 * n))
    }

    func tai(toi: Int?) async {
        let cn = TinhGioCTW.bayNgay(tuThuHai: thuHai).last ?? thuHai
        if baoCao.giaTri == nil { baoCao = .dangTai }
        do {
            let r: CTWBaoCaoGio = try await APIClient.shared.request(CTWAPI.baoCaoGio(pid: pid, tu: thuHai, den: cn, userId: toi))
            // Máy chủ lọc theo userId; phòng khi bản cũ bỏ qua tham số ⇒ tự lọc lại.
            var r2 = r
            if let toi { r2.people = (r.people ?? []).filter { $0.user?.id == nil || $0.user?.id == toi } }
            baoCao = .xong(r2)
        } catch { baoCao = .loi(CTW.loi(error)) }
        // Phiếu giờ tuần: chỉ có khi module Finance bật + có quyền — lỗi thì không hiện gì.
        phieu = try? await APIClient.shared.request(CTWAPI.bangGioTuan(pid: pid, tuan: thuHai))
    }
}

struct TimeCTW: View {
    let nguCanh: CTWNguCanh
    @EnvironmentObject private var app: AppState
    @ObservedObject private var dongHo = DongHoCTW.shared
    @StateObject private var vm: TuanGioVM
    @Environment(\.horizontalSizeClass) private var beRong
    @State private var tamPhu: TamPhuTimeCTW?

    init(nguCanh: CTWNguCanh) {
        self.nguCanh = nguCanh
        _vm = StateObject(wrappedValue: TuanGioVM(pid: nguCanh.pid))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if beRong == .regular {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(spacing: 16) { TheDongHoCTW(tamPhu: $tamPhu); nutHanhDong }
                            .frame(maxWidth: 380)
                        khoiTuan
                    }
                } else {
                    TheDongHoCTW(tamPhu: $tamPhu)
                    nutHanhDong
                    khoiTuan
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Time tracking")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await dongHo.taiLai()
            await vm.tai(toi: app.currentUser?.id)
        }
        .onAppear { dongHo.nghe() }
        .onDisappear { dongHo.boNghe() }
        .task { await dongHo.taiLai() }
        .task(id: vm.thuHai) { await vm.tai(toi: app.currentUser?.id) }
        .sheet(item: $tamPhu) { t in
            TamPhuTimeView(tamPhu: t, nguCanh: nguCanh) {
                Task { await vm.tai(toi: app.currentUser?.id) }
            }
        }
    }

    private var nutHanhDong: some View {
        HStack(spacing: 10) {
            Button { tamPhu = .chonThe(.batDau) } label: {
                Label("Start timer", systemImage: "play.fill").frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            Button { tamPhu = .chonThe(.ghi) } label: {
                Label("Log time", systemImage: "plus.circle").frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
        }
        .font(.system(size: 15, weight: .semibold))
    }

    // MARK: Tuần

    private var khoiTuan: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                CTWSectionHeader("calendar", "My week")
                Button { vm.doiTuan(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    .accessibilityLabel("Previous week")
                Button { vm.doiTuan(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                    .disabled(vm.laTuanNay)
                    .accessibilityLabel("Next week")
            }
            Text(nhanTuan).font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
            switch vm.baoCao {
            case .dangTai: CTWKhungTai(soHang: 3, coAvatar: false)
            case .loi(let l): CTWErrorBanner(text: l)
            case .xong: noiDungTuan
            }
        }
    }

    private var nhanTuan: String {
        let ds = TinhGioCTW.bayNgay(tuThuHai: vm.thuHai)
        guard let a = NgayCTW.nganTu(ds.first), let b = NgayCTW.nganTu(ds.last) else { return "" }
        return "\(a) – \(b)" + (vm.laTuanNay ? " · This week" : "") + " · \(nguCanh.maDuAn)"
    }

    @ViewBuilder private var noiDungTuan: some View {
        CTWLuoiChiSo {
            CTWTheChiSo(nhan: "Logged this week", giaTri: TinhGioCTW.chuPhut(vm.tong), bieuTuong: "clock")
            let homNay = vm.ngay.first { $0.ngay == NgayCTW.ymd(Date()) }?.phut
            CTWTheChiSo(nhan: vm.laTuanNay ? "Today" : "Daily average",
                        giaTri: TinhGioCTW.chuPhut(vm.laTuanNay ? (homNay ?? 0) : vm.tong / 7),
                        bieuTuong: "sun.max", mau: CTWMauChuoi.mau(1))
            if let p = vm.phieu?.timesheet?.status {
                CTWTheChiSo(nhan: "Timesheet", giaTri: p.capitalized, phu: vm.phieu?.locked == true ? "Week is locked" : nil,
                            bieuTuong: p == "APPROVED" ? "checkmark.seal" : "doc.text", mau: p == "APPROVED" ? AppColors.success : AppColors.warning)
            }
        }
        CTWKhungBieuDo(tieuDe: "Hours per day", phu: "Your worklogs in \(nguCanh.maDuAn)",
                       cot: ["Day", "Logged"],
                       hang: vm.ngay.map { CTWHangBang(nhan: NgayCTW.ngay($0.ngay).map(NgayCTW.thuNgay) ?? $0.ngay, giaTri: [TinhGioCTW.chuPhut($0.phut)]) },
                       cao: 180) {
            Chart(vm.ngay) { n in
                BarMark(x: .value("Day", NgayCTW.ngay(n.ngay).map(NgayCTW.thuNgay) ?? n.ngay),
                        y: .value("Hours", Double(n.phut) / 60), width: .ratio(0.55))
                    .foregroundStyle(n.ngay == NgayCTW.ymd(Date()) ? AppColors.primary : CTWMauChuoi.mau(0))
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4))
                    .annotation(position: .top) {
                        if n.phut > 0 {
                            Text(CTWSo.gioThapPhan(giay: n.phut * 60)).font(.system(size: 10, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
            }
            .chartYAxis { AxisMarks(position: .leading) { v in
                AxisGridLine().foregroundStyle(AppColors.divider)
                AxisValueLabel { if let d = v.as(Double.self) { Text("\(CTWSo.gon(d))h") } }
            } }
        }
        VStack(alignment: .leading, spacing: 0) {
            Text("Issues").font(.system(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                .padding(.bottom, 8)
            if vm.the.isEmpty {
                Text("No time logged this week. Start a timer or log time on an issue.")
                    .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
            }
            ForEach(Array(vm.the.enumerated()), id: \.offset) { i, t in
                if let so = t.number {
                    NavigationLink(value: RouteWorklogCTW(pid: nguCanh.pid, so: so, tieuDe: t.title ?? "")) {
                        HStack(spacing: 10) {
                            Text("\(nguCanh.maDuAn)-\(so)").font(.system(size: 12, weight: .semibold).monospaced())
                                .foregroundColor(AppColors.textSecondary)
                            Text(t.title ?? "").font(.system(size: 14)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                            Spacer(minLength: 6)
                            Text(TinhGioCTW.chuPhut(t.minutes ?? 0)).font(.system(size: 13, weight: .semibold).monospacedDigit())
                                .foregroundColor(AppColors.textPrimary)
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    if i < vm.the.count - 1 { Divider() }
                }
            }
        }
        .padding(14)
        .ctwThe(14)
    }
}

// MARK: - Thẻ đồng hồ đang chạy

struct TheDongHoCTW: View {
    @Binding var tamPhu: TamPhuTimeCTW?
    @ObservedObject private var dongHo = DongHoCTW.shared
    @State private var loi: String?
    @State private var dangLam = false
    @State private var hoiHuy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let d = dongHo.dongHo {
                HStack(spacing: 8) {
                    Circle().fill(d.dangChay ? AppColors.success : AppColors.warning).frame(width: 8, height: 8)
                    Text(d.dangChay ? "RUNNING" : "PAUSED").font(.system(size: 11, weight: .bold))
                        .foregroundColor(d.dangChay ? AppColors.success : AppColors.warning)
                    if d.overdue == true {
                        Label("Running for a long time", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .semibold)).foregroundColor(AppColors.warning)
                    }
                    Spacer()
                    if let a = d.activity {
                        Text(a).font(.system(size: 11, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(AppColors.backgroundTertiary))
                    }
                }
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text(CTWSo.dongHo(giay: dongHo.giay(ctx.date)))
                        .font(.system(size: 52, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundColor(AppColors.textPrimary)
                        .minimumScaleFactor(0.6).lineLimit(1)
                        .accessibilityLabel("Elapsed \(CTWSo.gio(giay: dongHo.giay(ctx.date)))")
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(d.issueKey ?? "").font(.system(size: 12, weight: .semibold).monospaced()).foregroundColor(AppColors.primary)
                    Text(d.issueTitle ?? "").font(.system(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                    if let n = d.note, !n.isEmpty {
                        Text(n).font(.system(size: 13)).foregroundColor(AppColors.textSecondary).lineLimit(2)
                    }
                    if let p = d.projectName { Text(p).font(.system(size: 12)).foregroundColor(AppColors.textTertiary) }
                }
                HStack(spacing: 8) {
                    Button { Task { await lam { d.dangChay ? try await dongHo.tamDung() : try await dongHo.tiepTuc() } } } label: {
                        Label(d.dangChay ? "Pause" : "Resume", systemImage: d.dangChay ? "pause.fill" : "play.fill")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    Button { tamPhu = .dung } label: {
                        Label("Stop & log", systemImage: "stop.fill").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    Menu {
                        Button { tamPhu = .suaDongHo } label: { Label("Edit note & activity", systemImage: "pencil") }
                        Button(role: .destructive) { hoiHuy = true } label: { Label("Discard timer", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis").frame(width: 44, height: 44)
                            .background(Circle().fill(AppColors.backgroundTertiary))
                    }
                    .accessibilityLabel("More timer actions")
                }
                .font(.system(size: 15, weight: .semibold))
                .disabled(dangLam)
            } else if dongHo.daTai {
                HStack(spacing: 12) {
                    Image(systemName: "stopwatch").font(.system(size: 26, weight: .semibold)).foregroundColor(AppColors.primary)
                        .frame(width: 54, height: 54).background(Circle().fill(AppColors.primary.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("No timer running").font(.system(size: 16, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                        Text("Start a timer on an issue — it keeps running on the web and desktop too.")
                            .font(.system(size: 13)).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                CTWKhungTai(soHang: 2, coAvatar: true).padding(-Spacing.md)
            }
            if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }
        }
        .padding(16)
        .ctwThe(16)
        .confirmationDialog("Discard this timer?", isPresented: $hoiHuy, titleVisibility: .visible) {
            Button("Discard without logging", role: .destructive) { Task { await lam { try await dongHo.huy() } } }
        } message: { Text("The elapsed time will not be logged.") }
    }

    private func lam(_ f: @escaping () async throws -> Void) async {
        dangLam = true
        defer { dangLam = false }
        do { try await f(); loi = nil } catch { loi = CTW.loi(error); CTWRung.loi() }
    }
}

// MARK: - Tấm phủ (một `.sheet(item:)` cho cả màn — bẫy C5)

enum TamPhuTimeCTW: Identifiable, Hashable {
    enum Muc: String, Hashable { case batDau, ghi }
    case chonThe(Muc)
    case ghiGio(pid: Int, so: Int, tieuDe: String)
    case dung
    case suaDongHo

    var id: String {
        switch self {
        case .chonThe(let m): return "chon-\(m.rawValue)"
        case .ghiGio(let p, let s, _): return "ghi-\(p)-\(s)"
        case .dung: return "dung"
        case .suaDongHo: return "sua"
        }
    }
}

/// Nội dung tấm phủ — chọn thẻ ⇒ (bắt đầu đồng hồ | mở form ghi giờ) trong cùng một NavigationStack.
struct TamPhuTimeView: View {
    let tamPhu: TamPhuTimeCTW
    let nguCanh: CTWNguCanh
    let xong: () -> Void
    @Environment(\.dismiss) private var dong

    var body: some View {
        NavigationStack {
            switch tamPhu {
            case .chonThe(let muc):
                ChonTheB3CTW(pid: nguCanh.pid, maDuAn: nguCanh.maDuAn,
                             tieuDe: muc == .batDau ? "Start timer on…" : "Log time on…") { so, ten in
                    BatDauHoacGhiCTW(muc: muc, pid: nguCanh.pid, so: so, tieuDe: ten, maDuAn: nguCanh.maDuAn) { dong(); xong() }
                }
            case .ghiGio(let pid, let so, let ten):
                GhiGioCTW(pid: pid, so: so, tieuDe: ten, maDuAn: nguCanh.maDuAn) { dong(); xong() }
            case .dung:
                DungDongHoCTW { dong(); xong() }
            case .suaDongHo:
                SuaDongHoCTW { dong() }
            }
        }
    }
}

// MARK: - Chọn thẻ (tìm trong dự án)

struct ChonTheB3CTW<Dich: View>: View {
    let pid: Int
    let maDuAn: String
    let tieuDe: String
    @ViewBuilder let dich: (Int, String) -> Dich
    @State private var tim = ""
    @State private var ds: [CTWIssueCard] = []
    @State private var loi: String?
    @State private var dangTai = true
    @Environment(\.dismiss) private var dong

    var body: some View {
        List {
            if let loi { CTWErrorBanner(text: loi).listRowBackground(Color.clear) }
            if !dangTai && ds.isEmpty {
                Text(tim.isEmpty ? "No open issues in this project." : "No issues match “\(tim)”.")
                    .foregroundColor(AppColors.textSecondary)
            }
            ForEach(ds) { t in
                NavigationLink { dich(t.number, t.title) } label: {
                    HStack(spacing: 10) {
                        Text("\(maDuAn)-\(t.number)").font(.system(size: 12, weight: .semibold).monospaced())
                            .foregroundColor(AppColors.textSecondary)
                        Text(t.title).font(.system(size: 15)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                    }
                    .frame(minHeight: 36)
                }
            }
        }
        .overlay { if dangTai && ds.isEmpty { ProgressView() } }
        .searchable(text: $tim, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search title or key")
        .navigationTitle(tieuDe)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } } }
        .task(id: tim) {
            if !tim.isEmpty { try? await Task.sleep(nanoseconds: 300_000_000) }
            await tai()
        }
    }

    private func tai() async {
        dangTai = true
        defer { dangTai = false }
        var loc = CTWAPI.BoLoc()
        loc.q = tim
        do {
            let r: CTWIssueList = try await APIClient.shared.request(CTWAPI.dsThe(pid: pid, loc: loc, limit: 50))
            ds = r.items ?? []
            loi = nil
        } catch is CancellationError {
        } catch { loi = CTW.loi(error) }
    }
}

/// Sau khi chọn thẻ: bắt đầu đồng hồ (có hỏi chuyển nếu đang chạy thẻ khác) hoặc mở form ghi giờ.
struct BatDauHoacGhiCTW: View {
    let muc: TamPhuTimeCTW.Muc
    let pid: Int
    let so: Int
    let tieuDe: String
    let maDuAn: String
    let xong: () -> Void

    var body: some View {
        switch muc {
        case .ghi: GhiGioCTW(pid: pid, so: so, tieuDe: tieuDe, maDuAn: maDuAn, xong: xong)
        case .batDau: BatDauDongHoCTW(pid: pid, so: so, tieuDe: tieuDe, maDuAn: maDuAn, xong: xong)
        }
    }
}

struct BatDauDongHoCTW: View {
    let pid: Int
    let so: Int
    let tieuDe: String
    let maDuAn: String
    let xong: () -> Void
    @State private var hoatDong: String?
    @State private var ghiChu = ""
    @State private var loi: String?
    @State private var hoiChuyen: String?
    @State private var dangLam = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(maDuAn)-\(so)").font(.system(size: 12, weight: .semibold).monospaced()).foregroundColor(AppColors.primary)
                    Text(tieuDe).font(.system(size: 15, weight: .medium))
                }
            }
            Section("Activity") {
                Picker("Activity", selection: $hoatDong) {
                    Text("Guess from the issue").tag(String?.none)
                    ForEach(hoatDongCTW, id: \.self) { Text($0).tag(String?.some($0)) }
                }
            }
            Section("Note") { TextField("What are you working on? (optional)", text: $ghiChu, axis: .vertical).lineLimit(1...4) }
            if let loi { Section { Text(loi).foregroundColor(AppColors.error) } }
        }
        .navigationTitle("Start timer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { Task { await batDau(chuyen: false) } } label: { if dangLam { ProgressView() } else { Text("Start").bold() } }
                    .disabled(dangLam)
            }
        }
        .confirmationDialog(hoiChuyen ?? "", isPresented: Binding(get: { hoiChuyen != nil }, set: { if !$0 { hoiChuyen = nil } }),
                            titleVisibility: .visible) {
            Button("Stop it, log the time and switch") { Task { await batDau(chuyen: true) } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func batDau(chuyen: Bool) async {
        dangLam = true
        defer { dangLam = false }
        do {
            try await DongHoCTW.shared.batDau(pid: pid, so: so, activity: hoatDong, note: ghiChu, chuyen: chuyen)
            xong()
        } catch {
            if DongHoCTW.maLoi(error) == "WORK_TIMER_RUNNING" {
                let k = DongHoCTW.shared.dongHo?.issueKey
                hoiChuyen = "A timer is already running" + (k.map { " on \($0)" } ?? "") + "."
            } else {
                loi = CTW.loi(error)
                CTWRung.loi()
            }
        }
    }
}

// MARK: - Form ghi giờ

struct GhiGioCTW: View {
    let pid: Int
    let so: Int
    let tieuDe: String
    let maDuAn: String
    let xong: () -> Void
    @State private var phut = 30
    @State private var chuPhut = "30m"
    @State private var ngay = Date()
    @State private var ghiChu = ""
    @State private var hoatDong: String?
    @State private var dsHoatDong: [String] = hoatDongCTW
    @State private var loi: String?
    @State private var dangLam = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(maDuAn)-\(so)").font(.system(size: 12, weight: .semibold).monospaced()).foregroundColor(AppColors.primary)
                    Text(tieuDe).font(.system(size: 15, weight: .medium))
                }
            }
            Section {
                HStack {
                    Text("Time spent")
                    Spacer()
                    TextField("1h 30m", text: $chuPhut)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numbersAndPunctuation)
                        .onSubmit { if let p = TinhGioCTW.docPhut(chuPhut) { phut = p } ; chuPhut = TinhGioCTW.chuPhut(phut) }
                        .frame(maxWidth: 140)
                }
                Stepper(value: Binding(get: { phut }, set: { phut = min(max($0, 1), 1440); chuPhut = TinhGioCTW.chuPhut(phut) }),
                        in: 1...1440, step: 15) {
                    Text(TinhGioCTW.chuPhut(phut)).font(.system(size: 15, weight: .semibold).monospacedDigit())
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach([15, 30, 60, 90, 120, 240], id: \.self) { p in
                            Button { phut = p; chuPhut = TinhGioCTW.chuPhut(p) } label: {
                                Text(TinhGioCTW.chuPhut(p)).font(.system(size: 13, weight: .semibold)).fixedSize()
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(Capsule().fill(p == phut ? AppColors.primary : AppColors.backgroundTertiary))
                                    .foregroundColor(p == phut ? AppColors.onPrimary : AppColors.textPrimary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                DatePicker("Started", selection: $ngay, in: ...Date().addingTimeInterval(3600), displayedComponents: [.date, .hourAndMinute])
            } footer: { Text("Type “1h 30m”, “1.5h”, “90m” or “1:30”. Up to 24 hours per entry.") }
            Section("Activity") {
                Picker("Activity", selection: $hoatDong) {
                    Text("None").tag(String?.none)
                    ForEach(dsHoatDong, id: \.self) { Text($0).tag(String?.some($0)) }
                }
            }
            Section("Note") { TextField("What did you do? (optional)", text: $ghiChu, axis: .vertical).lineLimit(1...5) }
            if let loi { Section { Text(loi).foregroundColor(AppColors.error) } }
        }
        .navigationTitle("Log time")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { Task { await luu() } } label: { if dangLam { ProgressView() } else { Text("Log").bold() } }
                    .disabled(dangLam)
            }
        }
        .task {
            if let m: CTWWorklogMacDinh = try? await APIClient.shared.request(CTWAPI.worklogMacDinh(pid: pid, so: so)) {
                if let a = m.activities, !a.isEmpty { dsHoatDong = a }
                if hoatDong == nil { hoatDong = m.activity }
            }
        }
    }

    private func luu() async {
        if let p = TinhGioCTW.docPhut(chuPhut) { phut = p }
        dangLam = true
        defer { dangLam = false }
        do {
            let _: CTWWorklog = try await APIClient.shared.request(
                CTWAPI.ghiGio(pid: pid, so: so, phut: phut, batDau: ngay, note: ghiChu, activity: hoatDong))
            CTWRung.thanhCong()
            xong()
        } catch {
            loi = DongHoCTW.maLoi(error) == "WORK_TIMESHEET_LOCKED"
                ? "That week's timesheet is submitted or approved, so it's locked. Ask a project admin to reopen it."
                : CTW.loi(error)
            CTWRung.loi()
        }
    }
}

// MARK: - Dừng & ghi

struct DungDongHoCTW: View {
    let xong: () -> Void
    @ObservedObject private var dongHo = DongHoCTW.shared
    @State private var suaPhut = false
    @State private var phut = 1
    @State private var ghiChu = ""
    @State private var hoatDong: String?
    @State private var loi: String?
    @State private var ketQua: CTWKetQuaDung?
    @State private var dangLam = false

    var body: some View {
        Form {
            if let k = ketQua {
                Section {
                    Label(k.worklog != nil ? "Logged \(TinhGioCTW.chuPhut(k.minutes ?? 0)) on \(k.issueKey ?? "the issue")"
                                           : "Under 30 seconds — nothing was logged.",
                          systemImage: k.worklog != nil ? "checkmark.circle.fill" : "info.circle")
                        .foregroundColor(k.worklog != nil ? AppColors.success : AppColors.textSecondary)
                    if k.capped == true { Text("Capped at 24 hours.").font(.system(size: 13)).foregroundColor(AppColors.warning) }
                }
            } else if let d = dongHo.dongHo {
                Section {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(d.issueKey ?? "").font(.system(size: 12, weight: .semibold).monospaced()).foregroundColor(AppColors.primary)
                        Text(d.issueTitle ?? "").font(.system(size: 15, weight: .medium))
                    }
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        LabeledContent("Elapsed", value: CTWSo.dongHo(giay: dongHo.giay(ctx.date)))
                            .monospacedDigit()
                    }
                }
                Section {
                    Toggle("Change logged time", isOn: $suaPhut)
                    if suaPhut {
                        Stepper(value: $phut, in: 1...1440, step: 5) {
                            Text(TinhGioCTW.chuPhut(phut)).font(.system(size: 15, weight: .semibold).monospacedDigit())
                        }
                    }
                } footer: {
                    Text(suaPhut ? "This amount is logged instead of the measured time."
                                 : "Logs \(TinhGioCTW.chuPhut(TinhGioCTW.phutSeGhi(giay: dongHo.giay()))). Under 30 seconds logs nothing.")
                }
                Section("Activity") {
                    Picker("Activity", selection: $hoatDong) {
                        Text("Keep (\(d.activity ?? "guess"))").tag(String?.none)
                        ForEach(hoatDongCTW, id: \.self) { Text($0).tag(String?.some($0)) }
                    }
                }
                Section("Note") { TextField(d.note ?? "Logged with the timer", text: $ghiChu, axis: .vertical).lineLimit(1...4) }
            }
            if let loi { Section { Text(loi).foregroundColor(AppColors.error) } }
        }
        .navigationTitle("Stop & log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if ketQua != nil {
                    Button("Done") { xong() }.bold()
                } else {
                    Button { Task { await dung() } } label: { if dangLam { ProgressView() } else { Text("Stop").bold() } }
                        .disabled(dangLam || dongHo.dongHo == nil)
                }
            }
        }
        .onAppear { phut = max(TinhGioCTW.phutSeGhi(giay: dongHo.giay()), 1) }
    }

    private func dung() async {
        dangLam = true
        defer { dangLam = false }
        do {
            ketQua = try await dongHo.dung(phut: suaPhut ? phut : nil, note: ghiChu.isEmpty ? nil : ghiChu, activity: hoatDong)
        } catch {
            loi = DongHoCTW.maLoi(error) == "WORK_TIMESHEET_LOCKED"
                ? "That week's timesheet is locked, so the time can't be logged. The timer keeps running — ask a project admin to reopen the week."
                : CTW.loi(error)
            CTWRung.loi()
        }
    }
}

struct SuaDongHoCTW: View {
    let xong: () -> Void
    @ObservedObject private var dongHo = DongHoCTW.shared
    @State private var ghiChu = ""
    @State private var hoatDong: String?
    @State private var loi: String?

    var body: some View {
        Form {
            Section("Activity") {
                Picker("Activity", selection: $hoatDong) {
                    Text("None").tag(String?.none)
                    ForEach(hoatDongCTW, id: \.self) { Text($0).tag(String?.some($0)) }
                }
            }
            Section("Note") { TextField("Note", text: $ghiChu, axis: .vertical).lineLimit(1...5) }
            if let loi { Section { Text(loi).foregroundColor(AppColors.error) } }
        }
        .navigationTitle("Edit timer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { xong() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        do { try await dongHo.sua(activity: hoatDong, note: ghiChu.isEmpty ? nil : ghiChu); xong() }
                        catch { loi = CTW.loi(error) }
                    }
                }.bold()
            }
        }
        .onAppear { ghiChu = dongHo.dongHo?.note ?? ""; hoatDong = dongHo.dongHo?.activity }
    }
}

// MARK: - Worklog của một thẻ

struct DsWorklogTheCTW: View {
    let pid: Int
    let so: Int
    let tieuDe: String
    @EnvironmentObject private var app: AppState
    @State private var ds: TaiCTW<[CTWWorklog]> = .dangTai
    @State private var loi: String?
    @State private var ghi = false

    var body: some View {
        List {
            Section {
                NutGhiGioTheCTW(pid: pid, so: so, tieuDe: tieuDe) { Task { await tai() } }
            }
            if let loi { CTWErrorBanner(text: loi) { self.loi = nil }.listRowBackground(Color.clear) }
            switch ds {
            case .dangTai: Section { ProgressView().frame(maxWidth: .infinity) }
            case .loi(let l): Section { Text(l).foregroundColor(AppColors.error) }
            case .xong(let a):
                Section {
                    if a.isEmpty { Text("No time logged on this issue yet.").foregroundColor(AppColors.textSecondary) }
                    ForEach(a) { w in
                        hang(w)
                            .swipeActions {
                                if coTheXoa(w) {
                                    Button(role: .destructive) { Task { await xoa(w) } } label: { Label("Delete", systemImage: "trash") }
                                }
                            }
                    }
                } header: {
                    HStack {
                        Text("Worklogs")
                        Spacer()
                        Text(TinhGioCTW.chuPhut(a.reduce(0) { $0 + ($1.minutes ?? 0) })).monospacedDigit()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(tieuDe.isEmpty ? "Worklogs" : tieuDe)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: CTWRoute.the(pid: pid, so: so)) { Image(systemName: "arrow.up.forward.square") }
                    .accessibilityLabel("Open issue")
            }
        }
        .refreshable { await tai() }
        .task { await tai() }
    }

    private func coTheXoa(_ w: CTWWorklog) -> Bool {
        (w.userId ?? w.user?.id) == app.currentUser?.id || app.cauHinhDuAn?.role == "ADMIN"
    }

    private func hang(_ w: CTWWorklog) -> some View {
        HStack(alignment: .top, spacing: 10) {
            CTWAvatar(user: w.user, size: 30)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(w.user?.ten ?? "Someone").font(.system(size: 14, weight: .semibold))
                    if w.user?.laAgent == true { CTWNhanAI() }
                    if w.source == "AGENT_AUTO" { Text("auto").font(.system(size: 10, weight: .semibold)).foregroundColor(AppColors.textTertiary) }
                    Spacer()
                    Text(TinhGioCTW.chuPhut(w.minutes ?? 0)).font(.system(size: 14, weight: .semibold).monospacedDigit())
                }
                HStack(spacing: 6) {
                    Text(CTW.thoiDiem(w.startedAt)).font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
                    if let a = w.activity { Text("· \(a)").font(.system(size: 12)).foregroundColor(AppColors.textSecondary) }
                }
                if let n = w.note, !n.isEmpty { Text(n).font(.system(size: 13)).foregroundColor(AppColors.textSecondary) }
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            if coTheXoa(w) {
                Button(role: .destructive) { Task { await xoa(w) } } label: { Label("Delete worklog", systemImage: "trash") }
            }
        }
    }

    private func tai() async {
        do { ds = .xong(try await APIClient.shared.request(CTWAPI.dsWorklog(pid: pid, so: so))) }
        catch { if ds.giaTri == nil { ds = .loi(CTW.loi(error)) } else { loi = CTW.loi(error) } }
    }

    private func xoa(_ w: CTWWorklog) async {
        do {
            try await APIClient.shared.send(CTWAPI.xoaWorklog(pid: pid, so: so, id: w.id))
            if case .xong(let a) = ds { ds = .xong(a.filter { $0.id != w.id }) }
            CTWRung.thanhCong()
        } catch {
            loi = DongHoCTW.maLoi(error) == "WORK_TIMESHEET_LOCKED" ? "That week's timesheet is locked." : CTW.loi(error)
        }
    }
}

// MARK: - Nút chấm công cho MỘT thẻ (dùng lại ở chi tiết thẻ sau này)

/// Start/Stop timer + Log time cho đúng một thẻ. Tự biết đồng hồ có đang chạy trên thẻ này không.
struct NutGhiGioTheCTW: View {
    let pid: Int
    let so: Int
    var tieuDe: String = ""
    var daGhi: (() -> Void)?
    @EnvironmentObject private var app: AppState
    @ObservedObject private var dongHo = DongHoCTW.shared
    @State private var tamPhu: TamPhuTimeCTW?
    @State private var loi: String?
    @State private var hoiChuyen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                if dongHo.laThe(pid: pid, so: so), let d = dongHo.dongHo {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        Label(CTWSo.dongHo(giay: dongHo.giay(ctx.date)), systemImage: d.dangChay ? "record.circle" : "pause.circle")
                            .font(.system(size: 15, weight: .semibold).monospacedDigit())
                            .foregroundColor(d.dangChay ? AppColors.success : AppColors.warning)
                    }
                    Spacer()
                    Button { tamPhu = .dung } label: { Label("Stop", systemImage: "stop.fill").frame(minHeight: 36) }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button { Task { await batDau(chuyen: false) } } label: {
                        Label("Start timer", systemImage: "play.fill").frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.bordered)
                }
                Button { tamPhu = .ghiGio(pid: pid, so: so, tieuDe: tieuDe) } label: {
                    Label("Log time", systemImage: "plus").frame(maxWidth: dongHo.laThe(pid: pid, so: so) ? nil : .infinity, minHeight: 36)
                }
                .buttonStyle(.bordered)
            }
            .font(.system(size: 14, weight: .semibold))
            if let loi { Text(loi).font(.system(size: 12)).foregroundColor(AppColors.error) }
        }
        .task { if !dongHo.daTai { await dongHo.taiLai() } }
        .confirmationDialog("A timer is already running on \(dongHo.dongHo?.issueKey ?? "another issue").",
                            isPresented: $hoiChuyen, titleVisibility: .visible) {
            Button("Stop it, log the time and switch") { Task { await batDau(chuyen: true) } }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $tamPhu) { t in
            TamPhuTimeView(tamPhu: t, nguCanh: CTWNguCanh(pid: pid, slug: app.luaChon?.slug ?? "", maDuAn: app.luaChon?.maDuAn ?? "",
                                                          tenDuAn: app.luaChon?.tenDuAn ?? "")) { daGhi?() }
        }
    }

    private func batDau(chuyen: Bool) async {
        do { try await dongHo.batDau(pid: pid, so: so, chuyen: chuyen); loi = nil; daGhi?() }
        catch {
            if DongHoCTW.maLoi(error) == "WORK_TIMER_RUNNING" { hoiChuyen = true } else { loi = CTW.loi(error) }
        }
    }
}
