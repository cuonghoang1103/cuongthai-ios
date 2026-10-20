import SwiftUI
import Charts

// MARK: - Nội dung từng tab Reports
//
// Mỗi tab là một view nhỏ tự nạp dữ liệu (`NapBaoCaoCTW`) — chuyển tab không tải lại tab khác,
// kéo làm mới (`lamMoi`) tải lại tab đang xem.

// MARK: Overview (KPIs + sức khoẻ)

struct TabTongQuanBaoCaoCTW: View {
    let pid: Int
    let lamMoi: Int
    let rong: Bool
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NapBaoCaoCTW(khoa: "kpi-\(lamMoi)", diemCuoi: { CTWAPI.kpis(pid: pid) }, soHang: 2) { (k: CTWKpis) in
                HangKpiCTW(k: k, soCot: rong ? 4 : 2)
            }
            NapBaoCaoCTW(khoa: "ins-\(lamMoi)", diemCuoi: { CTWAPI.insights(pid: pid) }) { (i: CTWInsights) in
                SucKhoeDuAnCTW(i: i, pid: pid, maDuAn: app.cauHinhDuAn?.key ?? "", rong: rong)
            }
            NapBaoCaoCTW(khoa: "load-\(lamMoi)", diemCuoi: { CTWAPI.taiTheoNguoi(pid: pid) }) { (t: CTWTaiTheoNguoi) in
                BieuDoTaiNguoiCTW(t: t)
            }
        }
    }
}

/// Thẻ sức khoẻ dự án (từ `/insights`): nhịp sprint, quá hạn, sắp hạn, đứng yên, người quá tải.
struct SucKhoeDuAnCTW: View {
    let i: CTWInsights
    let pid: Int
    let maDuAn: String
    var rong = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let r = i.sprintRisk { nhipSprint(r) }
            let khoi: [(String, String, Color, [CTWInsightThe])] = [
                (String(localized: "Overdue"), "exclamationmark.circle.fill", AppColors.error, i.overdue ?? []),
                (String(localized: "Due in the next days"), "calendar.badge.clock", AppColors.warning, i.dueSoon ?? []),
                (String(localized: "No activity for a while"), "zzz", CTWMauChuoi.khac, i.stale ?? []),
                (String(localized: "Urgent and unassigned"), "person.crop.circle.badge.exclamationmark", AppColors.error, i.unassignedUrgent ?? []),
            ]
            let coKhoi = khoi.filter { !$0.3.isEmpty }
            if coKhoi.isEmpty && (i.overloaded ?? []).isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill").foregroundColor(AppColors.success).font(.ctw(size: 22))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Looking healthy").font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                        Text("Nothing overdue, stale or overloaded right now.").font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading).ctwThe(14)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14, alignment: .top), count: rong ? 2 : 1), spacing: 14) {
                ForEach(coKhoi, id: \.0) { k in danhSach(k.0, k.1, k.2, k.3) }
                if !(i.overloaded ?? []).isEmpty { quaTai(i.overloaded ?? []) }
            }
        }
    }

    private func nhipSprint(_ r: CTWSprintNhip) -> some View {
        let mau: Color = r.atRisk == true ? AppColors.warning : (r.status == "DONE" ? AppColors.success : AppColors.primary)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: r.atRisk == true ? "exclamationmark.triangle.fill" : "speedometer").foregroundColor(mau)
                Text(r.sprint ?? String(localized: "Sprint")).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                Spacer()
                Text(HangKpiCTW.nhanNhipTinh(r.status).uppercased()).font(.ctw(size: 10, weight: .bold)).foregroundColor(mau)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(mau.opacity(0.12)))
            }
            if let s = r.summary, !s.isEmpty {
                Text(s).font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            if let need = r.neededPerDay, let recent = r.recentPerDay {
                HStack(spacing: 16) {
                    nhan(String(localized: "Needed / day"), CTWSo.gon(need))
                    nhan(String(localized: "Recent / day"), CTWSo.gon(recent))
                    nhan(String(localized: "Days left"), r.daysLeft.map(String.init) ?? "—")
                }
            }
        }
        .padding(14).ctwThe(14)
    }

    private func nhan(_ a: String, _ b: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(b).font(.ctw(size: 16, weight: .bold).monospacedDigit()).foregroundColor(AppColors.textPrimary)
            Text(a).font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
        }
        .accessibilityElement(children: .combine)
    }

    private func danhSach(_ tieuDe: String, _ bt: String, _ mau: Color, _ ds: [CTWInsightThe]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: bt).foregroundColor(mau).font(.ctw(size: 13, weight: .semibold))
                Text(tieuDe).font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                Text("\(ds.count)").font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary)
            }
            ForEach(Array(ds.prefix(6).enumerated()), id: \.offset) { _, t in
                if let so = t.number {
                    NavigationLink(value: CTWRoute.the(pid: pid, so: so)) {
                        HStack(spacing: 8) {
                            Text(t.key ?? "\(maDuAn)-\(so)").font(.ctw(size: 11, weight: .medium).monospaced()).foregroundColor(AppColors.textSecondary)
                            Text(t.title ?? "").font(.ctw(size: 13)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                            Spacer(minLength: 0)
                            if let d = t.idleDays { Text("\(d)d idle").font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary) }
                            else if let d = NgayCTW.nganTu(t.dueDate) { Text(d).font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary) }
                        }
                        .frame(minHeight: 32)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            if ds.count > 6 { Text("+\(ds.count - 6) more").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary) }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).ctwThe(14)
    }

    private func quaTai(_ ds: [CTWInsightTai]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "person.fill.badge.plus").foregroundColor(AppColors.warning).font(.ctw(size: 13, weight: .semibold))
                Text("Overloaded").font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
            }
            ForEach(Array(ds.enumerated()), id: \.offset) { _, l in
                HStack {
                    Text("@\(l.username ?? "")").font(.ctw(size: 13)).foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Text("\(CTWSo.gon(l.points ?? 0)) \(l.unit ?? String(localized: "points"))" + (l.capacity.map { " / \(CTWSo.gon($0))" } ?? ""))
                        .font(.ctw(size: 12).monospacedDigit()).foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).ctwThe(14)
    }
}

// MARK: Burndown

struct TabBurndownBaoCaoCTW: View {
    let pid: Int
    let sprints: [CTWSprintDu]
    let lamMoi: Int
    let rong: Bool
    @State private var chon: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if sprints.isEmpty {
                CTWOTrong(bieuTuong: "chart.line.downtrend.xyaxis", tieuDe: String(localized: "No started sprints"), moTa: String(localized: "Start a sprint to see its burndown."))
            } else {
                ChonSprintBaoCaoCTW(ds: sprints, chon: $chon)
                if let sid = chon ?? sprints.first?.id {
                    NapBaoCaoCTW(khoa: "bd-\(sid)-\(lamMoi)", diemCuoi: { CTWAPI.burndown(pid: pid, sid: sid) }) { (bd: CTWBurndown) in
                        NoiDungBurndownCTW(bd: bd, rong: rong)
                    }
                }
            }
        }
        .onAppear { if chon == nil { chon = sprints.first?.id } }
    }
}

/// Chỉ số + mục tiêu + burndown/burnup của một sprint (tab Burndown, widget burndown).
struct NoiDungBurndownCTW: View {
    let bd: CTWBurndown
    var rong = false
    var gon = false

    var body: some View {
        let cs = TinhSprintCTW.chiSo(bd)
        let diem = TinhSprintCTW.chuoi(bd)
        VStack(alignment: .leading, spacing: 12) {
            if !gon {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: rong ? 4 : 2), spacing: 10) {
                    CTWTheChiSo(nhan: String(localized: "Committed"), giaTri: DonViSprintCTW.so(cs.cam, bd.unit), phu: String(localized: "At start"), bieuTuong: "flag", mau: CTWMauChuoi.mau(0))
                    CTWTheChiSo(nhan: String(localized: "Completed"), giaTri: DonViSprintCTW.so(cs.xong, bd.unit), phu: "\(Int((cs.tiLe * 100).rounded()))%",
                                bieuTuong: "checkmark.circle", mau: AppColors.success)
                    CTWTheChiSo(nhan: String(localized: "Remaining"), giaTri: DonViSprintCTW.so(cs.con, bd.unit), bieuTuong: "hourglass", mau: CTWMauChuoi.mau(1))
                    if bd.sprint?.state == "CLOSED" {
                        CTWTheChiSo(nhan: String(localized: "Completed on"), giaTri: NgayCTW.thoiDiem(bd.sprint?.completedAt).map(NgayCTW.ngan) ?? "—", bieuTuong: "checkmark.seal")
                    } else if let con = TinhSprintCTW.ngayConLai(endAt: bd.sprint?.endAt) {
                        CTWTheChiSo(nhan: con < 0 ? String(localized: "Overdue by") : String(localized: "Days left"), giaTri: "\(abs(con))", bieuTuong: "calendar",
                                    mau: con < 0 ? AppColors.error : AppColors.primary)
                    }
                }
                if let g = bd.sprint?.goal, !g.isEmpty {
                    Label { Text(g).fixedSize(horizontal: false, vertical: true) } icon: { Image(systemName: "target").foregroundColor(AppColors.primary) }
                        .font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary)
                }
            }
            if diem.isEmpty {
                Text("This sprint hasn't started yet.").font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
            } else if rong && !gon {
                HStack(alignment: .top, spacing: 14) {
                    BieuDoBurndownCTW(diem: diem, unit: bd.unit)
                    BieuDoBurnupCTW(diem: diem, unit: bd.unit, cao: 220)
                }
            } else {
                BieuDoBurndownCTW(diem: diem, unit: bd.unit, cao: gon ? 180 : 220)
                if !gon { BieuDoBurnupCTW(diem: diem, unit: bd.unit) }
            }
        }
    }
}

// MARK: Velocity

struct TabVelocityBaoCaoCTW: View {
    let pid: Int
    let lamMoi: Int

    var body: some View {
        NapBaoCaoCTW(khoa: "vel-\(lamMoi)", diemCuoi: { CTWAPI.velocity(pid: pid) }) { (v: CTWVelocity) in
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    CTWTheChiSo(nhan: String(localized: "Average (last 3)"), giaTri: v.average.map { DonViSprintCTW.so($0, v.unit) } ?? "—",
                                bieuTuong: "speedometer", mau: CTWMauChuoi.mau(0))
                    let ds = v.sprints ?? []
                    let cam = ds.compactMap(\.committedPoints).reduce(0, +)
                    let xong = ds.compactMap(\.completedPoints).reduce(0, +)
                    CTWTheChiSo(nhan: String(localized: "Say / do ratio"), giaTri: cam > 0 ? "\(Int((xong / cam * 100).rounded()))%" : "—",
                                phu: String(localized: "Completed ÷ committed"), bieuTuong: "scalemass", mau: CTWMauChuoi.mau(1))
                }
                BieuDoVelocityCTW(v: v, cao: 240)
            }
        }
    }
}

// MARK: Flow

struct TabFlowBaoCaoCTW: View {
    let pid: Int
    let lamMoi: Int
    let rong: Bool
    @State private var ngay = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ChonKhoangNgayCTW(ngay: $ngay)
            NapBaoCaoCTW(khoa: "cfd-\(ngay)-\(lamMoi)", diemCuoi: { CTWAPI.cfd(pid: pid, ngay: ngay) }) { (c: CTWCfd) in
                BieuDoCfdCTW(c: c, cao: rong ? 300 : 240)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14, alignment: .top), count: rong ? 2 : 1), spacing: 14) {
                NapBaoCaoCTW(khoa: "thr-\(lamMoi)", diemCuoi: { CTWAPI.throughput(pid: pid) }) { (t: CTWThroughput) in
                    BieuDoThroughputCTW(t: t)
                }
                NapBaoCaoCTW(khoa: "cyc-\(lamMoi)", diemCuoi: { CTWAPI.cycleTime(pid: pid) }) { (c: CTWCycleTime) in
                    TheCycleTimeCTW(c: c)
                }
            }
            Text("Flow reports count top-level issues only (no epics, sub-tasks or test cases).")
                .font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
        }
    }
}

// MARK: Created vs resolved

struct TabTaoXongBaoCaoCTW: View {
    let pid: Int
    let lamMoi: Int
    @State private var ngay = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ChonKhoangNgayCTW(ngay: $ngay, lua: [14, 30, 90])
            NapBaoCaoCTW(khoa: "cr-\(ngay)-\(lamMoi)", diemCuoi: { CTWAPI.taoVsXong(pid: pid, ngay: ngay) }) { (ds: [CTWTaoXongNgay]) in
                let t = TinhBaoCaoCTW.taoXong(ds)
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        CTWTheChiSo(nhan: String(localized: "Created"), giaTri: "\(t.tao)", bieuTuong: "plus.circle", mau: CTWMauChuoi.mau(1))
                        CTWTheChiSo(nhan: String(localized: "Resolved"), giaTri: "\(t.xong)", bieuTuong: "checkmark.circle", mau: CTWMauChuoi.mau(0))
                        CTWTheChiSo(nhan: String(localized: "Net"), giaTri: (t.chenh > 0 ? "+" : "") + "\(t.chenh)", phu: t.chenh > 0 ? String(localized: "Backlog growing") : String(localized: "Keeping up"),
                                    bieuTuong: t.chenh > 0 ? "arrow.up.right" : "arrow.down.right", mau: t.chenh > 0 ? AppColors.warning : AppColors.success)
                    }
                    BieuDoTaoXongCTW(ds: ds, cao: 240)
                }
            }
        }
    }
}

// MARK: Distribution

struct TabPhanBoBaoCaoCTW: View {
    let pid: Int
    let lamMoi: Int
    let rong: Bool
    @State private var theoDiem = false
    @State private var chiMo = true

    private var nhom: [(String, String)] { [("status", String(localized: "By status")), ("assignee", String(localized: "By assignee")), ("type", String(localized: "By type")), ("priority", String(localized: "By priority"))] }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Picker("Measure", selection: $theoDiem) {
                    Text("Issues").tag(false)
                    Text("Points").tag(true)
                }
                .pickerStyle(.segmented).frame(maxWidth: 200)
                Toggle("Open only", isOn: $chiMo).toggleStyle(.button).font(.ctw(size: 13, weight: .semibold))
            }
            let jql = chiMo ? "statusCategory != Done" : ""
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14, alignment: .top), count: rong ? 2 : 1), spacing: 14) {
                ForEach(nhom, id: \.0) { g in
                    NapBaoCaoCTW(khoa: "st-\(g.0)-\(chiMo)-\(lamMoi)", diemCuoi: { CTWAPI.thongKe(pid: pid, nhomTheo: g.0, jql: jql) }) { (s: CTWThongKe) in
                        let thanh = TinhBaoCaoCTW.phanBo(s.groups ?? [], theoDiem: theoDiem, giuThuTu: g.0 == "priority")
                        BieuDoPhanBoCTW(tieuDe: g.1, thanh: thanh, tong: thanh.map(\.giaTri).reduce(0, +),
                                        donVi: theoDiem ? DonViSprintCTW.tenDai(s.unit) : String(localized: "issues"), mauTrangThai: g.0 == "status")
                    }
                }
            }
        }
    }
}

// MARK: Epics

struct TabEpicsBaoCaoCTW: View {
    let pid: Int
    let lamMoi: Int
    @EnvironmentObject private var app: AppState

    var body: some View {
        NapBaoCaoCTW(khoa: "ep-\(lamMoi)", diemCuoi: { CTWAPI.epicsBaoCao(pid: pid) }) { (e: CTWEpicsBaoCao) in
            let ds = e.epics ?? []
            VStack(alignment: .leading, spacing: 10) {
                if ds.isEmpty {
                    CTWOTrong(bieuTuong: "bolt.horizontal", tieuDe: String(localized: "No epics"), moTa: String(localized: "Epics group related stories so you can track bigger goals."))
                }
                ForEach(ds) { ep in
                    NavigationLink(value: CTWRoute.the(pid: pid, so: ep.number ?? 0)) { hang(ep, unit: e.unit) }
                        .buttonStyle(.plain)
                        .disabled(ep.number == nil)
                }
            }
        }
    }

    private func hang(_ ep: CTWEpicBaoCao, unit: String?) -> some View {
        let tong = ep.total ?? 0, xong = ep.completed ?? 0
        let ma = "\(app.cauHinhDuAn?.key ?? "")-\(ep.number ?? 0)"
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill").font(.ctw(size: 11, weight: .bold)).foregroundColor(.white)
                    .frame(width: 22, height: 22).background(RoundedRectangle(cornerRadius: 5).fill(CTWMauChuoi.mau(6)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(ep.title ?? "").font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                    Text(NgayCTW.nganTu(ep.dueDate).map { String(localized: "\(ma) · due \($0)") } ?? ma)
                        .font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                }
                Spacer()
                Text("\(Int((ep.percent ?? 0).rounded()))%").font(.ctw(size: 16, weight: .bold).monospacedDigit())
                    .foregroundColor(ep.resolved == true ? AppColors.success : AppColors.textPrimary)
            }
            CTWThanhTienDo(doan: [CTWDoanTienDo(ten: String(localized: "Done"), giaTri: Double(xong), mau: AppColors.success),
                                 CTWDoanTienDo(ten: String(localized: "Open"), giaTri: Double(max(tong - xong, 0)), mau: CTWMauChuoi.khac)])
            Text("\(xong) of \(tong) issues · \(CTWSo.gon(ep.pointsDone ?? 0)) / \(CTWSo.gon(ep.points ?? 0)) \(DonViSprintCTW.ten(unit))")
                .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
        }
        .padding(14).ctwThe(14)
    }
}

// MARK: Time

struct TabThoiGianBaoCaoCTW: View {
    let pid: Int
    let lamMoi: Int
    @State private var khoang = 0 // 0 = tuần này, 1 = 30 ngày

    var body: some View {
        let k = khoang == 0 ? TinhBaoCaoCTW.tuanNay() : TinhBaoCaoCTW.khoang(30)
        VStack(alignment: .leading, spacing: 14) {
            Picker("Range", selection: $khoang) {
                Text("This week").tag(0)
                Text("Last 30 days").tag(1)
            }
            .pickerStyle(.segmented).frame(maxWidth: 300)
            NapBaoCaoCTW(khoa: "tm-\(k.tu)-\(k.den)-\(lamMoi)", diemCuoi: { CTWAPI.baoCaoThoiGian(pid: pid, tu: k.tu, den: k.den) }) { (r: CTWBaoCaoThoiGian) in
                NoiDungThoiGianCTW(r: r)
            }
        }
    }
}

struct NoiDungThoiGianCTW: View {
    let r: CTWBaoCaoThoiGian

    var body: some View {
        let ngay = TinhBaoCaoCTW.phutTheoNgay(r)
        let ds = (r.people ?? []).sorted { ($0.totalMin ?? 0) > ($1.totalMin ?? 0) }
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                CTWTheChiSo(nhan: String(localized: "Logged"), giaTri: CTWSo.gio(giay: (r.totalMin ?? 0) * 60), bieuTuong: "clock", mau: CTWMauChuoi.mau(0))
                CTWTheChiSo(nhan: String(localized: "People"), giaTri: CTWSo.gio(giay: (r.byPrincipal?["HUMAN"] ?? 0) * 60), bieuTuong: "person.2", mau: CTWMauChuoi.mau(0))
                if (r.byPrincipal?["AGENT"] ?? 0) > 0 {
                    CTWTheChiSo(nhan: String(localized: "AI agents"), giaTri: CTWSo.gio(giay: (r.byPrincipal?["AGENT"] ?? 0) * 60), bieuTuong: "sparkles", mau: CTWMauChuoi.mau(6))
                }
            }
            CTWKhungBieuDo(tieuDe: String(localized: "Hours per day"), phu: "\(NgayCTW.nganTu(r.from) ?? "") – \(NgayCTW.nganTu(r.to) ?? "")",
                           cot: [String(localized: "Day"), String(localized: "Logged")], hang: ngay.map { CTWHangBang(nhan: NgayCTW.thuNgay($0.ngay), giaTri: [CTWSo.gio(giay: $0.phut * 60)]) },
                           cao: 180) {
                Chart(ngay, id: \.ymd) { d in
                    BarMark(x: .value("Day", d.ngay, unit: .day), y: .value("Hours", Double(d.phut) / 60))
                        .foregroundStyle(CTWMauChuoi.mau(0)).cornerRadius(4)
                }
                .modifier(TrucNgayCTW())
            }
            VStack(alignment: .leading, spacing: 10) {
                CTWSectionHeader("person.2", String(localized: "By person"), count: "\(ds.count)")
                if ds.isEmpty { Text("No time logged in this range.").font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary) }
                ForEach(Array(ds.enumerated()), id: \.offset) { _, p in
                    HStack(spacing: 10) {
                        CTWAvatar(user: p.user, size: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(p.user?.ten ?? p.name ?? "—").font(.ctw(size: 14, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                                if p.userKind == "AGENT" || p.user?.laAgent == true { CTWNhanAI() }
                            }
                            Text(Self.dongNguoi(soThe: (p.issues ?? []).count, phutTuDong: p.autoMin ?? 0))
                                .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                        }
                        Spacer()
                        Text(CTWSo.gio(giay: (p.totalMin ?? 0) * 60)).font(.ctw(size: 14, weight: .semibold).monospacedDigit()).foregroundColor(AppColors.textPrimary)
                    }
                    .frame(minHeight: 40)
                }
            }
            .padding(14).ctwThe(14)
        }
    }
}

// MARK: People vs Agents

extension NoiDungThoiGianCTW {
    static func dongNguoi(soThe n: Int, phutTuDong: Int) -> String {
        let the = n == 1 ? String(localized: "1 issue") : String(localized: "\(n) issues")
        guard phutTuDong > 0 else { return the }
        return String(localized: "\(the) · \(CTWSo.gio(giay: phutTuDong * 60)) auto-logged")
    }
}

struct TabAgentsBaoCaoCTW: View {
    let pid: Int
    let sprints: [CTWSprintDu]
    let lamMoi: Int
    let rong: Bool
    @State private var ngay = 30
    @State private var sprint: Int?

    var body: some View {
        let k = TinhBaoCaoCTW.khoang(ngay)
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if sprint == nil { ChonKhoangNgayCTW(ngay: $ngay) }
                    if !sprints.isEmpty { ChonSprintBaoCaoCTW(ds: sprints, chon: $sprint, choPhepTatCa: true) }
                }
            }
            NapBaoCaoCTW(khoa: "ag-\(ngay)-\(sprint ?? 0)-\(lamMoi)",
                         diemCuoi: { CTWAPI.nguoiVsAgent(pid: pid, tu: sprint == nil ? k.tu : nil, den: sprint == nil ? k.den : nil, sprint: sprint) }) { (r: CTWNguoiVsAgent) in
                NoiDungNguoiVsAgentCTW(r: r, rong: rong)
            }
        }
    }
}

struct NoiDungNguoiVsAgentCTW: View {
    let r: CTWNguoiVsAgent
    let rong: Bool

    var body: some View {
        let ta = r.totals?.agents, th = r.totals?.humans
        VStack(alignment: .leading, spacing: 14) {
            // So sánh tổng: người vs agent (một thước đo — số thẻ đã xong).
            CTWKhungBieuDo(tieuDe: String(localized: "Issues resolved"), phu: "\(NgayCTW.nganTu(r.from) ?? "") – \(NgayCTW.nganTu(r.to) ?? "")",
                           chuGiai: [CTWMucChuGiai(ten: String(localized: "People"), mau: CTWMauChuoi.mau(0)), CTWMucChuGiai(ten: String(localized: "AI agents"), mau: CTWMauChuoi.mau(6))],
                           cot: ["", String(localized: "Resolved")], hang: [CTWHangBang(nhan: String(localized: "People"), giaTri: ["\(th?.issuesResolved ?? 0)"]),
                                                         CTWHangBang(nhan: String(localized: "AI agents"), giaTri: ["\(ta?.issuesResolved ?? 0)"])],
                           cao: 90) {
                Chart {
                    BarMark(x: .value("Resolved", th?.issuesResolved ?? 0), y: .value("Who", String(localized: "People")))
                        .foregroundStyle(CTWMauChuoi.mau(0)).cornerRadius(4)
                        .annotation(position: .trailing) { Text("\(th?.issuesResolved ?? 0)").font(.ctw(size: 11, weight: .semibold)).foregroundColor(AppColors.textPrimary) }
                    BarMark(x: .value("Resolved", ta?.issuesResolved ?? 0), y: .value("Who", String(localized: "AI agents")))
                        .foregroundStyle(CTWMauChuoi.mau(6)).cornerRadius(4)
                        .annotation(position: .trailing) { Text("\(ta?.issuesResolved ?? 0)").font(.ctw(size: 11, weight: .semibold)).foregroundColor(AppColors.textPrimary) }
                }
                .chartXAxis(.hidden)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: rong ? 4 : 2), spacing: 10) {
                CTWTheChiSo(nhan: String(localized: "People · hours"), giaTri: String(localized: "\(CTWSo.gon(th?.hours ?? 0))h"), bieuTuong: "person.2", mau: CTWMauChuoi.mau(0))
                CTWTheChiSo(nhan: String(localized: "Agents · returned"), giaTri: "\(Int(((ta?.returnRate ?? 0) * 100).rounded()))%",
                            phu: String(localized: "\(ta?.returnedCount ?? 0) sent back from review"), bieuTuong: "arrow.uturn.backward", mau: CTWMauChuoi.mau(6))
                CTWTheChiSo(nhan: String(localized: "Agent cost (est.)"), giaTri: CTWSo.usd(ta?.costUsd ?? 0), phu: String(localized: "Mostly self-reported"), bieuTuong: "sparkles", mau: CTWMauChuoi.mau(6))
                CTWTheChiSo(nhan: String(localized: "Agent cost / point"), giaTri: (ta?.costPerPoint).map(CTWSo.usd) ?? "—", bieuTuong: "divide", mau: CTWMauChuoi.mau(6))
            }
            ghiChuChiPhi(ta?.costSource)
            VStack(alignment: .leading, spacing: 10) {
                CTWSectionHeader("sparkles", String(localized: "AI agents"), count: "\((r.agents ?? []).count)")
                if (r.agents ?? []).isEmpty { Text("No agent activity in this range.").font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary) }
                ForEach(Array((r.agents ?? []).enumerated()), id: \.offset) { _, a in hangAgent(a) }
            }
            .padding(14).ctwThe(14)
            VStack(alignment: .leading, spacing: 10) {
                CTWSectionHeader("person.2", String(localized: "People"), count: "\((r.humans ?? []).count)")
                ForEach(Array((r.humans ?? []).enumerated()), id: \.offset) { _, h in
                    HStack(spacing: 10) {
                        CTWAvatar(user: h.user, size: 28)
                        Text(h.user?.ten ?? "—").font(.ctw(size: 14, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(h.issuesResolved ?? 0) resolved · \(CTWSo.gon(h.hours ?? 0))h").font(.ctw(size: 12).monospacedDigit()).foregroundColor(AppColors.textSecondary)
                            if let c = h.cost { Text("\(CTWSo.gon(c)) \(r.currency ?? "")").font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary) }
                        }
                    }
                    .frame(minHeight: 40)
                }
            }
            .padding(14).ctwThe(14)
        }
    }

    /// 4.7 + quy ước web: chi phí agent là USD ƯỚC LƯỢNG, phần lớn do agent TỰ KHAI.
    private func ghiChuChiPhi(_ n: CTWNguonChiPhi?) -> some View {
        HStack(alignment: .top, spacing: 8) {
            NhanTuKhaiCTW()
            Text("Agent cost is an estimate in USD. \(CTWSo.usd(n?.reported ?? 0)) was self-reported by the agents; \(CTWSo.usd(n?.gateway ?? 0)) was measured by CT Work. Treat it as a guide, not a bill.")
                .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppColors.backgroundTertiary.opacity(0.6)))
    }

    private func hangAgent(_ a: CTWAgentBaoCao) -> some View {
        let u = CTWUser(id: a.agent?.userId ?? 0, username: a.agent?.username, fullName: nil, displayName: a.agent?.displayName, avatarUrl: nil, kind: "AGENT")
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                CTWAvatar(user: u, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(a.agent?.displayName ?? a.agent?.username ?? String(localized: "Agent")).font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                        CTWNhanAI()
                    }
                    Text([a.agent?.model, a.agent?.owner.map { String(localized: "owner \($0.ten)") }, a.agent?.status?.capitalized].compactMap { $0 }.joined(separator: " · "))
                        .font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary).lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(CTWSo.usd(a.costUsd ?? 0)).font(.ctw(size: 14, weight: .semibold).monospacedDigit()).foregroundColor(AppColors.textPrimary)
                    Text("est.").font(.ctw(size: 10)).foregroundColor(AppColors.textTertiary)
                }
            }
            HStack(spacing: 14) {
                so(String(localized: "Resolved"), "\(a.issuesResolved ?? 0)")
                so(String(localized: "Points"), CTWSo.gon(a.pointsResolved ?? 0))
                so(String(localized: "Returned"), "\(Int(((a.returnRate ?? 0) * 100).rounded()))%")
                so(String(localized: "Worked"), CTWSo.gio(giay: (a.leaseMinutes ?? 0) * 60))
            }
        }
        .padding(.vertical, 4)
    }

    private func so(_ a: String, _ b: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(b).font(.ctw(size: 13, weight: .semibold).monospacedDigit()).foregroundColor(AppColors.textPrimary)
            Text(a).font(.ctw(size: 10)).foregroundColor(AppColors.textTertiary)
        }
        .accessibilityElement(children: .combine)
    }
}
