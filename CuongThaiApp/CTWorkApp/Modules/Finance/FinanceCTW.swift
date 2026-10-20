import SwiftUI

// MARK: - Tài chính dự án — CHỈ XEM
//
// ⛔ App Store 3.1.1: KHÔNG nút thanh toán, KHÔNG link trả tiền, KHÔNG câu mời mua.
// Mốc thanh toán chỉ hiện TRẠNG THÁI (Planned/Due/Invoiced/Paid) như một báo cáo.
// Người quản lý tài chính (ADMIN — `manageFinance`) thấy ngân sách/chi phí/EVM;
// thành viên khác thấy cài đặt chung + bảng công của chính mình.

@MainActor
final class FinanceVM: ObservableObject {
    let pid: Int
    @Published var caiDat: CTWTaiChinhCaiDat?
    @Published var tongQuan: CTWTaiChinhTongQuan?
    @Published var moc: CTWDsMocThanhToan?
    @Published var chiPhi: [CTWChiPhi]?
    @Published var bangCong: [CTWBangCong]?
    @Published var loi: String?
    @Published var tatMoDun = false
    @Published var daTai = false

    init(pid: Int) { self.pid = pid }

    var quanLy: Bool { caiDat?.access?.manage == true }

    func tai() async {
        do {
            let c: CTWTaiChinhCaiDat = try await APIClient.shared.request(CTWAPI.caiDatTaiChinh(pid: pid))
            caiDat = c
            loi = nil
            if c.access?.manage == true {
                async let a: CTWTaiChinhTongQuan? = try? APIClient.shared.request(CTWAPI.tongQuanTaiChinh(pid: pid))
                async let b: CTWDsMocThanhToan? = try? APIClient.shared.request(CTWAPI.mocThanhToan(pid: pid))
                async let d: [CTWChiPhi]? = try? APIClient.shared.request(CTWAPI.chiPhi(pid: pid))
                async let e: CTWDsBangCong? = try? APIClient.shared.request(CTWAPI.bangCong(pid: pid))
                let (x, y, z, w) = await (a, b, d, e)
                tongQuan = x; moc = y; chiPhi = z; bangCong = w?.items
            } else {
                let e: CTWDsBangCong? = try? await APIClient.shared.request(CTWAPI.bangCong(pid: pid))
                bangCong = e?.items
            }
        } catch {
            if case APIError.coMa(let ma, _) = error {
                if ma == "MODULE_DISABLED" { tatMoDun = true; daTai = true; return }
                if ma == "WORK_FINANCE_FORBIDDEN" || ma == "FORBIDDEN" { loi = String(localized: "You don't have access to this project's finances.") }
                else { loi = CTW.loi(error) }
            } else { loi = CTW.loi(error) }
        }
        daTai = true
    }
}

struct FinanceCTW: View {
    let nguCanh: CTWNguCanh
    @StateObject private var vm: FinanceVM
    @State private var tab: Tab = .tongQuan

    enum Tab: String, CaseIterable, Identifiable {
        case tongQuan = "Overview", moc = "Milestones", chiPhi = "Expenses", cong = "Timesheets"
        var id: String { rawValue }
        var ten: String {
            switch self {
            case .tongQuan: return String(localized: "Overview")
            case .moc: return String(localized: "Milestones")
            case .chiPhi: return String(localized: "Expenses")
            case .cong: return String(localized: "Timesheets")
            }
        }
    }

    init(nguCanh: CTWNguCanh) {
        self.nguCanh = nguCanh
        _vm = StateObject(wrappedValue: FinanceVM(pid: nguCanh.pid))
    }

    private var tien: String? { vm.tongQuan?.currency ?? vm.caiDat?.currency }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let loi = vm.loi {
                    if vm.caiDat == nil { CTWOLoi(loi: loi) { Task { await vm.tai() } } }
                    else { CTWErrorBanner(text: loi) { vm.loi = nil } }
                }
                if vm.tatMoDun {
                    CTWOTrong(bieuTuong: "chart.pie", tieuDe: String(localized: "Finance is turned off"),
                              moTa: String(localized: "A project admin can turn Finance on in project settings."))
                } else if vm.caiDat != nil {
                    if vm.quanLy {
                        Picker("Section", selection: $tab) { ForEach(Tab.allCases) { Text($0.ten).tag($0) } }
                            .pickerStyle(.segmented)
                        switch tab {
                        case .tongQuan: tongQuan
                        case .moc: mocView
                        case .chiPhi: chiPhiView
                        case .cong: bangCongView
                        }
                    } else {
                        caiDatChung
                        bangCongView
                    }
                    if let n = vm.tongQuan?.notice ?? vm.caiDat?.notice, !n.isEmpty {
                        Text(n).font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if vm.loi == nil {
                    CTWKhungTai(soHang: 4, coAvatar: false)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Finance")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await vm.tai() }
        .task { if !vm.daTai { await vm.tai() } }
    }

    // MARK: Tổng quan (quản lý)

    @ViewBuilder
    private var tongQuan: some View {
        if let t = vm.tongQuan, let s = t.summary {
            let canh = s.alerts ?? []
            if !canh.isEmpty {
                HStack(spacing: 6) {
                    ForEach(canh, id: \.self) { a in
                        CTWNhanNho(chu: CTWTien.nhanCanhBao(a), bieuTuong: "exclamationmark.triangle.fill",
                                   mau: a == "WARN" ? AppColors.warning : AppColors.error)
                    }
                }
            }
            nganSach(s)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                CTWODem(so: CTWTien.gon(s.bac ?? t.budgetTotal, tien), nhan: String(localized: "Budget (BAC)"), bieuTuong: "banknote", mau: AppColors.primary)
                CTWODem(so: CTWTien.gon(s.actual, tien), nhan: String(localized: "Actual cost"), bieuTuong: "sum", mau: AppColors.info)
                CTWODem(so: CTWTien.gon(s.remaining, tien), nhan: String(localized: "Remaining"), bieuTuong: "tray",
                        mau: (s.remaining ?? 0) < 0 ? AppColors.error : AppColors.success)
                CTWODem(so: CTWTien.gon(s.burnRatePerWeek, tien), nhan: String(localized: "Burn per week"), bieuTuong: "flame", mau: AppColors.warning)
                CTWODem(so: CTWTien.cpi(s.cpi), nhan: String(localized: "CPI (≥ 1 is on budget)"), bieuTuong: "gauge.with.dots.needle.50percent",
                        mau: (s.cpi ?? 1) < 1 ? AppColors.error : AppColors.success)
                CTWODem(so: CTWTien.gon(s.eac, tien), nhan: s.eacMethod == "BURN_RATE" ? String(localized: "Forecast at completion (burn rate)") : String(localized: "Forecast at completion"),
                        bieuTuong: "chart.line.uptrend.xyaxis", mau: AppColors.primary)
                CTWODem(so: CTWTien.gon(s.vac, tien), nhan: String(localized: "Variance at completion"), bieuTuong: "plusminus",
                        mau: (s.vac ?? 0) < 0 ? AppColors.error : AppColors.success)
                CTWODem(so: CTWTien.phanTram(s.percentComplete.map { $0 * 100 }), nhan: String(localized: "Work complete"), bieuTuong: "checkmark.circle",
                        mau: AppColors.success)
            }
            if let ds = t.byStage, !ds.isEmpty { khoiDong(String(localized: "Budget by stage"), "flag", ds) }
            if let ds = t.byCategory, !ds.isEmpty { khoiDong(String(localized: "Budget by category"), "square.grid.2x2", ds) }
            if let ng = t.byPerson, !ng.isEmpty {
                CTWSectionHeader("person.2", String(localized: "Labor by person"), count: "\(ng.count)")
                CTWKhoiTruong {
                    ForEach(Array(ng.enumerated()), id: \.offset) { i, p in
                        if i > 0 { Divider() }
                        CTWHangTruong(p.name ?? "—", "\(CTWTien.gio(p.minutes)) · \(CTWTien.dinhDang(p.cost, tien))")
                    }
                }
            }
            if let p = t.payments {
                CTWSectionHeader("calendar.badge.clock", String(localized: "Milestone status"))
                CTWKhoiTruong {
                    CTWHangTruong(String(localized: "Planned"), CTWTien.dinhDang(p.planned, tien))
                    Divider(); CTWHangTruong(String(localized: "Due"), CTWTien.dinhDang(p.due, tien))
                    Divider(); CTWHangTruong(String(localized: "Invoiced"), CTWTien.dinhDang(p.invoiced, tien))
                    Divider(); CTWHangTruong(String(localized: "Received"), CTWTien.dinhDang(p.paid, tien))
                }
            }
            if (t.pendingTimesheets ?? 0) > 0 {
                Label(t.pendingTimesheets == 1 ? String(localized: "1 timesheet waiting for review (\(CTWTien.gio(t.pendingMinutes))) — not counted yet.")
                      : String(localized: "\(t.pendingTimesheets!) timesheets waiting for review (\(CTWTien.gio(t.pendingMinutes))) — not counted yet."),
                      systemImage: "hourglass")
                    .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
            }
        } else {
            CTWOTrong(bieuTuong: "chart.pie", tieuDe: String(localized: "No budget yet"), moTa: String(localized: "Once a budget is set for this project, spending and forecasts appear here."))
        }
    }

    private func nganSach(_ s: CTWTaiChinhTongQuan.TomTat) -> some View {
        let dung = s.percentUsed ?? 0
        let qua = dung > 100
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Budget used").font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                Spacer()
                Text(CTWTien.phanTram(s.percentUsed)).font(.ctw(size: 14, weight: .bold).monospacedDigit())
                    .foregroundColor(qua ? AppColors.error : dung >= Double(s.alertLevel ?? 80) ? AppColors.warning : AppColors.textPrimary)
            }
            CTWThanhPhanDoan(doan: [(Int(min(dung, 100) * 10), qua ? AppColors.error : AppColors.primary),
                                   (Int(max(0, 100 - dung) * 10), AppColors.backgroundTertiary)], cao: 10)
            Text("\(CTWTien.dinhDang(s.actual, tien)) of \(CTWTien.dinhDang(s.bac, tien))")
                .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
        }
        .padding(14)
        .ctwThe(14)
        .accessibilityElement(children: .combine)
    }

    private func khoiDong(_ ten: String, _ icon: String, _ ds: [CTWTaiChinhTongQuan.Dong]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            CTWSectionHeader(icon, ten, count: "\(ds.count)")
            VStack(spacing: 12) {
                ForEach(Array(ds.enumerated()), id: \.offset) { _, d in
                    let ns = d.budget ?? 0, tt = d.actual ?? 0
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(d.label ?? CTWMauTrangThai.nhan(d.category)).font(.ctw(size: 14, weight: .medium))
                                .foregroundColor(AppColors.textPrimary).lineLimit(1)
                            if let st = d.status { CTWChipChu(chu: st) }
                            Spacer()
                            Text("\(CTWTien.gon(tt, tien)) / \(CTWTien.gon(ns, tien))").font(.ctw(size: 12).monospacedDigit())
                                .foregroundColor(tt > ns && ns > 0 ? AppColors.error : AppColors.textSecondary)
                        }
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(AppColors.backgroundTertiary)
                                Capsule().fill(tt > ns && ns > 0 ? AppColors.error : AppColors.primary)
                                    .frame(width: ns > 0 ? g.size.width * min(1, tt / ns) : (tt > 0 ? g.size.width : 0))
                            }
                        }
                        .frame(height: 6)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(14)
            .ctwThe(14)
        }
    }

    // MARK: Mốc thanh toán — chỉ trạng thái

    @ViewBuilder
    private var mocView: some View {
        let ds = vm.moc?.items ?? []
        if ds.isEmpty {
            CTWOTrong(bieuTuong: "calendar.badge.clock", tieuDe: String(localized: "No milestones"), moTa: String(localized: "Payment milestones agreed with the client appear here with their status."))
        } else {
            if let v = vm.moc?.contractValue {
                Text("Contract value: \(CTWTien.dinhDang(v, vm.moc?.currency ?? tien))")
                    .font(.ctw(size: 13, weight: .medium)).foregroundColor(AppColors.textSecondary)
            }
            VStack(spacing: 8) {
                ForEach(ds) { m in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(m.number ?? 0)").font(.ctw(size: 13, weight: .bold).monospacedDigit()).foregroundColor(AppColors.primary)
                            .frame(width: 28, height: 28).background(Circle().fill(AppColors.primary.opacity(0.12)))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(m.name).font(.ctw(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary)
                            Text([CTWTien.dinhDang(m.computedAmount ?? m.amount, vm.moc?.currency ?? tien),
                                  m.percent.map { CTWTien.phanTram($0) },
                                  m.stage?.name.map { String(localized: "Stage: \($0)") } ?? m.version?.name.map { String(localized: "Release: \($0)") },
                                  CTW.ngayNgan(m.dueDate).map { String(localized: "Due \($0)") }].compactMap { $0 }.joined(separator: " · "))
                                .font(.ctw(size: 12)).foregroundColor(m.overdue == true ? AppColors.error : AppColors.textSecondary)
                        }
                        Spacer(minLength: 4)
                        CTWChipChu(chu: m.status == "PAID" ? "RECEIVED" : m.status,
                                   mau: m.status == "PAID" ? AppColors.success : (m.overdue == true ? AppColors.error : nil))
                    }
                    .padding(12)
                    .ctwThe(12)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    // MARK: Chi phí

    @ViewBuilder
    private var chiPhiView: some View {
        let ds = vm.chiPhi ?? []
        if ds.isEmpty {
            CTWOTrong(bieuTuong: "cart", tieuDe: String(localized: "No expenses"), moTa: String(localized: "Equipment, services and licenses bought for the project appear here."))
        } else {
            let tong = ds.reduce(0) { $0 + ($1.amount ?? 0) }
            Text("Total: \(CTWTien.dinhDang(tong, tien))").font(.ctw(size: 13, weight: .semibold)).foregroundColor(AppColors.textSecondary)
            CTWKhoiTruong {
                ForEach(Array(ds.enumerated()), id: \.element.id) { i, e in
                    if i > 0 { Divider() }
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(e.description ?? String(localized: "Expense")).font(.ctw(size: 14, weight: .medium)).foregroundColor(AppColors.textPrimary)
                            Text([CTWMauTrangThai.nhan(e.category), e.vendor, CTW.ngayNgan(e.spentOn), e.budgetLine?.name].compactMap { $0 }.joined(separator: " · "))
                                .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                        }
                        Spacer(minLength: 8)
                        Text(CTWTien.dinhDang(e.amount, tien)).font(.ctw(size: 14, weight: .semibold).monospacedDigit())
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .padding(.vertical, 9)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    // MARK: Bảng công

    @ViewBuilder
    private var bangCongView: some View {
        let ds = vm.bangCong ?? []
        CTWSectionHeader("clock", vm.quanLy ? String(localized: "Timesheets") : String(localized: "My timesheets"), count: "\(ds.count)")
        if ds.isEmpty {
            Text("No submitted timesheets yet.").font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
        } else {
            CTWKhoiTruong {
                ForEach(Array(ds.enumerated()), id: \.element.id) { i, t in
                    if i > 0 { Divider() }
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(vm.quanLy ? (t.userName ?? "—") : String(localized: "Week of \(CTW.ngayNgan(t.weekStart) ?? "—")"))
                                .font(.ctw(size: 14, weight: .medium)).foregroundColor(AppColors.textPrimary)
                            Text([vm.quanLy ? String(localized: "Week of \(CTW.ngayNgan(t.weekStart) ?? "—")") : nil, CTWTien.gio(t.totalMinutes),
                                  t.approvedCost.map { CTWTien.dinhDang($0, tien) }].compactMap { $0 }.joined(separator: " · "))
                                .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                            if t.status == "RETURNED", let r = t.returnReason, !r.isEmpty {
                                Text("Returned: \(r)").font(.ctw(size: 12)).foregroundColor(AppColors.warning)
                            }
                        }
                        Spacer(minLength: 6)
                        CTWChipChu(chu: t.status)
                    }
                    .padding(.vertical, 9)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var caiDatChung: some View {
        CTWKhoiTruong {
            CTWHangTruong(String(localized: "Currency"), vm.caiDat?.currency, bieuTuong: "dollarsign.circle")
            Divider()
            CTWHangTruong(String(localized: "Budget alert at"), vm.caiDat?.alertLevel.map { String(localized: "\($0)% used") }, bieuTuong: "bell")
            Divider()
            CTWHangTruong(String(localized: "Your access"), vm.caiDat?.access?.review != nil ? String(localized: "Review timesheets") : String(localized: "Own timesheets"), bieuTuong: "person.badge.key")
        }
    }
}
