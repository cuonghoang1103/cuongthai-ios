import SwiftUI

// MARK: - Báo cáo kiểm thử theo mẫu FPT (CHỈ XEM)
//
// Report 5.1 Unit Test (ma trận UTCID × điều kiện/xác nhận, dấu "O", loại N/A/B),
// 5.2 Integration và 5.3 System (ca theo module, tối đa 4/3 vòng). Sửa và xuất
// Excel nộp trường làm trên web — màn này để nhóm/giảng viên XEM nhanh trên máy.

/// Các mục FPT nhúng vào List của màn Kiểm thử.
struct FptTongQuanCTW: View {
    let pid: Int
    @ObservedObject var vm: KiemThuVM

    var body: some View {
        if let u = vm.fptUnit, let fns = u.functions, !fns.isEmpty {
            Section {
                tomTatUnit(u.summary, tcPerKloc: u.tcPerKloc)
                    .listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                ForEach(fns) { f in
                    NavigationLink(value: RouteFptHamCTW(pid: pid, id: f.id, ten: tenHam(f))) { hangHam(f) }
                }
            } header: { Text("Report 5.1 · Unit test") }
        }
        if let i = vm.fptInt, let m = i.modules, !m.isEmpty {
            Section {
                tomTatIt(i.summary)
                    .listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                ForEach(m) { x in
                    NavigationLink(value: RouteFptModuleCTW(pid: pid, kieu: "integration", id: x.id, ten: x.name ?? "Module")) { hangModule(x) }
                }
            } header: { Text("Report 5.2 · Integration test") }
        }
        if let s = vm.fptSys, let m = s.modules, !m.isEmpty {
            Section {
                tomTatIt(s.summary)
                    .listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                ForEach(m) { x in
                    NavigationLink(value: RouteFptModuleCTW(pid: pid, kieu: "system", id: x.id, ten: x.name ?? "Workflow")) { hangModule(x) }
                }
            } header: { Text("Report 5.3 · System test") }
        }
        if !vm.coFpt {
            CTWOTrong(bieuTuong: "tablecells", tieuDe: "No FPT test reports",
                      moTa: "Unit and integration test reports in the FPT template appear here once your team adds them.")
                .listRowBackground(Color.clear)
        }
    }

    private func tenHam(_ f: CTWFptFunction) -> String {
        [f.moduleName, f.methodName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ".")
    }

    private func tomTatUnit(_ s: CTWFptUnitSummary?, tcPerKloc: Int?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                CTWODem(so: "\(s?.total ?? 0)", nhan: "Test cases", bieuTuong: "number", mau: AppColors.primary)
                CTWODem(so: pct(s?.coverage), nhan: "Coverage", bieuTuong: "chart.pie", mau: AppColors.info)
                CTWODem(so: pct(s?.successCoverage), nhan: "Passed", bieuTuong: "checkmark.circle", mau: AppColors.success)
                CTWODem(so: "\(s?.failed ?? 0)", nhan: "Failed", bieuTuong: "xmark.octagon", mau: AppColors.error)
            }
            CTWThanhPhanDoan(doan: [(s?.passed ?? 0, AppColors.success), (s?.failed ?? 0, AppColors.error), (s?.untested ?? 0, Color.clear)])
            HStack(spacing: 6) {
                CTWNhanNho(chu: "N \(pct(s?.normalPct))")
                CTWNhanNho(chu: "A \(pct(s?.abnormalPct))")
                CTWNhanNho(chu: "B \(pct(s?.boundaryPct))")
                if let k = s?.kloc, k > 0 { CTWNhanNho(chu: String(format: "%.2f KLOC", k), bieuTuong: "chevron.left.forwardslash.chevron.right") }
                Spacer(minLength: 0)
            }
            if let m = s?.meetsNorm {
                Label(m ? "Meets the norm (\(tcPerKloc ?? 0) cases per KLOC)"
                        : "Below the norm in \(s?.belowNorm ?? 0) function(s) — need \(s?.requiredCases ?? 0) cases for the declared LOC",
                      systemImage: m ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.ctw(size: 12, weight: .medium))
                    .foregroundColor(m ? AppColors.success : AppColors.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func tomTatIt(_ s: CTWFptItSummary?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                CTWODem(so: "\(s?.total ?? 0)", nhan: "Test cases", bieuTuong: "number", mau: AppColors.primary)
                CTWODem(so: pct(s?.coverage), nhan: "Coverage", bieuTuong: "chart.pie", mau: AppColors.info)
                CTWODem(so: "\(s?.passed ?? 0)", nhan: "Passed", bieuTuong: "checkmark.circle", mau: AppColors.success)
                CTWODem(so: "\(s?.failed ?? 0)", nhan: "Failed", bieuTuong: "xmark.octagon", mau: AppColors.error)
            }
            CTWThanhPhanDoan(doan: [(s?.passed ?? 0, AppColors.success), (s?.failed ?? 0, AppColors.error),
                                     (s?.na ?? 0, AppColors.textSecondary), (s?.pending ?? 0, Color.clear)])
        }
    }

    private func hangHam(_ f: CTWFptFunction) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(f.methodName ?? "Function").font(.ctw(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(AppColors.textPrimary).lineLimit(1)
                if f.belowNorm == true {
                    CTWNhanNho(chu: "Below norm", bieuTuong: "exclamationmark.triangle", mau: AppColors.warning)
                }
                Spacer(minLength: 0)
            }
            Text([f.moduleName, f.loc.map { "\($0) LOC" }].compactMap { $0 }.joined(separator: " · "))
                .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
            CTWThanhPhanDoan(doan: [(f.stats?.passed ?? 0, AppColors.success), (f.stats?.failed ?? 0, AppColors.error),
                                     (f.stats?.untested ?? 0, Color.clear)], cao: 6)
            Text("\(f.stats?.total ?? 0) cases · \(f.stats?.passed ?? 0) P · \(f.stats?.failed ?? 0) F · \(f.stats?.untested ?? 0) untested")
                .font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
        }
        .padding(.vertical, 3)
    }

    private func hangModule(_ m: CTWFptModule) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(m.name ?? "Module").font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                if let p = m.idPrefix { CTWNhanNho(chu: p) }
                Spacer(minLength: 0)
                if let r = m.stats?.lastRound, r > 0 { Text("Round \(r)").font(.ctw(size: 11, weight: .semibold)).foregroundColor(AppColors.textSecondary) }
            }
            CTWThanhPhanDoan(doan: [(m.stats?.passed ?? 0, AppColors.success), (m.stats?.failed ?? 0, AppColors.error),
                                     (m.stats?.na ?? 0, AppColors.textSecondary), (m.stats?.pending ?? 0, Color.clear)], cao: 6)
            Text("\(m.stats?.total ?? 0) cases · \(m.stats?.passed ?? 0) passed · \(m.stats?.failed ?? 0) failed · \(m.stats?.pending ?? 0) pending")
                .font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
        }
        .padding(.vertical, 3)
    }
}

private func pct(_ d: Double?) -> String {
    guard let d else { return "—" }
    return d == d.rounded() ? "\(Int(d))%" : String(format: "%.1f%%", d)
}

// MARK: - Ma trận một hàm (Report 5.1)

struct FptHamCTW: View {
    let pid: Int
    let id: Int
    let ten: String
    @State private var f: CTWFptFunction?
    @State private var loi: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }
                if let f {
                    dau(f)
                    CTWSectionHeader("tablecells", "Test matrix", count: "\((f.cases ?? []).count) cases")
                    maTran(f)
                    chuThich
                } else if loi == nil {
                    CTWKhungTai(soHang: 5, coAvatar: false)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(ten)
        .ctwTieuDeNho()
        .refreshable { await tai() }
        .task { if f == nil { await tai() } }
    }

    private func tai() async {
        do { f = try await APIClient.shared.request(CTWAPI.fptHam(pid: pid, id: id)); loi = nil }
        catch { loi = CTW.loi(error) }
    }

    private func dau(_ f: CTWFptFunction) -> some View {
        CTWKhoiTruong {
            CTWHangTruong("Module", f.moduleName, bieuTuong: "shippingbox")
            Divider()
            CTWHangTruong("Function", f.methodName, bieuTuong: "function")
            if let s = f.sheetName, !s.isEmpty { Divider(); CTWHangTruong("Sheet", s, bieuTuong: "tablecells") }
            if let d = f.description, !d.isEmpty { Divider(); CTWHangTruong("Description", d, bieuTuong: "text.alignleft") }
            if let p = f.preCondition, !p.isEmpty { Divider(); CTWHangTruong("Pre-condition", p, bieuTuong: "flag") }
            if let r = f.testRequirement, !r.isEmpty { Divider(); CTWHangTruong("Requirement", r, bieuTuong: "checklist") }
            if let c = f.codeRef, !c.isEmpty { Divider(); CTWHangTruong("Code", c, bieuTuong: "chevron.left.forwardslash.chevron.right") }
            Divider()
            CTWHangTruong("Lines of code", f.loc.map { "\($0)" }, bieuTuong: "number")
            if let r = f.requiredCases {
                Divider()
                CTWHangTruong(nhan: "Norm", bieuTuong: "gauge") {
                    Text("\(f.stats?.total ?? 0) / \(r) cases")
                        .foregroundColor(f.belowNorm == true ? AppColors.warning : AppColors.success)
                }
            }
            Divider()
            CTWHangTruong("Created by", f.createdBy, bieuTuong: "person")
            Divider()
            CTWHangTruong("Executed by", f.executedBy, bieuTuong: "person.badge.clock")
        }
    }

    /// Lưới cuộn ngang: cột trái là nhóm + giá trị điều kiện/xác nhận, mỗi cột
    /// một UTCID; ô có "O" khi ca đánh dấu hàng đó. Cuối lưới: loại N/A/B, kết
    /// quả P/F, ngày chạy, mã lỗi — đúng thứ tự sheet của mẫu trường.
    private func maTran(_ f: CTWFptFunction) -> some View {
        let ca = f.cases ?? []
        let nhom = CTWLuatFpt.nhomHang(f.rows ?? [])
        return ScrollView(.horizontal, showsIndicators: true) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    o("", rong: 220, dam: true, nen: AppColors.backgroundTertiary)
                    ForEach(Array(ca.enumerated()), id: \.element.id) { i, _ in
                        o(CTWLuatFpt.utcid(i), rong: 74, dam: true, nen: AppColors.backgroundTertiary, giua: true)
                    }
                }
                ForEach(Array(nhom.enumerated()), id: \.offset) { _, g in
                    GridRow {
                        o("\(g.section == "COND" ? "Condition" : "Confirm") · \(g.nhom)", rong: 220, dam: true,
                          nen: AppColors.primary.opacity(0.08), mau: AppColors.primary)
                        ForEach(ca) { _ in o("", rong: 74, nen: AppColors.primary.opacity(0.08)) }
                    }
                    ForEach(g.hang) { h in
                        GridRow {
                            o([h.label, h.value].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ": "), rong: 220)
                            ForEach(ca) { c in
                                o(CTWLuatFpt.coDau(c, hang: h) ? "O" : "", rong: 74, dam: true, giua: true, mau: AppColors.primary)
                            }
                        }
                    }
                }
                GridRow {
                    o("Type (N/A/B)", rong: 220, dam: true, nen: AppColors.backgroundTertiary)
                    ForEach(ca) { c in o(c.type ?? "", rong: 74, dam: true, nen: AppColors.backgroundTertiary, giua: true) }
                }
                GridRow {
                    o("Passed / Failed", rong: 220, dam: true)
                    ForEach(ca) { c in
                        o(c.result ?? "–", rong: 74, dam: true, giua: true,
                          mau: c.result == "P" ? AppColors.success : (c.result == "F" ? AppColors.error : AppColors.textTertiary))
                    }
                }
                GridRow {
                    o("Executed date", rong: 220, dam: true)
                    ForEach(ca) { c in o(c.executedAt.flatMap { CTW.ngayNgan($0) } ?? "", rong: 74, giua: true, co: 11) }
                }
                GridRow {
                    o("Defect ID", rong: 220, dam: true)
                    ForEach(ca) { c in o(c.defectId ?? "", rong: 74, giua: true, co: 11, mau: AppColors.error) }
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(AppColors.border))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(1)
        }
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColors.backgroundCard))
    }

    private func o(_ chu: String, rong: CGFloat, dam: Bool = false, nen: Color = .clear, giua: Bool = false,
                   co: CGFloat = 13, mau: Color = AppColors.textPrimary) -> some View {
        Text(chu)
            .font(.ctw(size: co, weight: dam ? .semibold : .regular))
            .foregroundColor(mau)
            .lineLimit(3)
            .multilineTextAlignment(giua ? .center : .leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: rong - 16, alignment: giua ? .center : .leading)
            .padding(.horizontal, 8).padding(.vertical, 7)
            .frame(maxHeight: .infinity)
            .background(nen)
            .overlay(Rectangle().strokeBorder(AppColors.border, lineWidth: 0.5))
    }

    private var chuThich: some View {
        Text("N = Normal · A = Abnormal · B = Boundary. “O” marks the conditions and confirmations a test case covers. Edit and export the Excel report on the web.")
            .font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Một module integration / system (Report 5.2 / 5.3)

struct FptModuleCTW: View {
    let pid: Int
    let kieu: String
    let id: Int
    let ten: String
    @State private var m: CTWFptModule?
    @State private var loi: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }
                if let m {
                    if let d = m.description, !d.isEmpty {
                        Text(d).font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                    if (m.preCondition ?? "").isEmpty == false || (m.testRequirement ?? "").isEmpty == false {
                        CTWKhoiTruong {
                            if let p = m.preCondition, !p.isEmpty { CTWHangTruong("Pre-condition", p, bieuTuong: "flag") }
                            if let r = m.testRequirement, !r.isEmpty {
                                if !(m.preCondition ?? "").isEmpty { Divider() }
                                CTWHangTruong("Requirement", r, bieuTuong: "checklist")
                            }
                        }
                    }
                    let ca = m.cases ?? []
                    CTWSectionHeader("list.bullet.rectangle", "Test cases", count: "\(ca.count)")
                    if ca.isEmpty {
                        Text("No test cases in this module yet.").font(.ctw(size: 13)).foregroundColor(AppColors.textTertiary)
                    }
                    ForEach(Array(ca.enumerated()), id: \.element.id) { i, c in theCa(c, ma: CTWLuatFpt.maIt(m.idPrefix, i)) }
                } else if loi == nil {
                    CTWKhungTai(soHang: 4, coAvatar: false)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(m?.name ?? ten)
        .ctwTieuDeNho()
        .refreshable { await tai() }
        .task { if m == nil { await tai() } }
    }

    private func tai() async {
        do { m = try await APIClient.shared.request(CTWAPI.fptModule(pid: pid, kieu: kieu, id: id)); loi = nil }
        catch { loi = CTW.loi(error) }
    }

    private func theCa(_ c: CTWFptItCase, ma: String) -> some View {
        let vong = c.rounds ?? []
        let hienTai = CTWLuatFpt.trangThaiIt(vong)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(ma).font(.ctw(size: 12, weight: .bold).monospaced()).foregroundColor(AppColors.primary)
                if let s = c.section, !s.isEmpty { CTWNhanNho(chu: s) }
                Spacer(minLength: 0)
                CTWChipChu(chu: hienTai, mau: CTWLuatFpt.mauIt(hienTai))
            }
            Text(c.description ?? "—").font(.ctw(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            truong("Procedure", c.procedure)
            truong("Test data", c.testData, mono: true)
            truong("Expected", c.expected)
            truong("Actual", c.actual)
            if !vong.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(vong.enumerated()), id: \.offset) { i, r in
                        VStack(spacing: 2) {
                            Text("R\(i + 1)").font(.ctw(size: 10, weight: .bold)).foregroundColor(AppColors.textTertiary)
                            Text(r.status ?? "—").font(.ctw(size: 11, weight: .semibold))
                                .foregroundColor(r.status == nil ? AppColors.textTertiary : CTWLuatFpt.mauIt(r.status))
                                .lineLimit(1).fixedSize()
                            if let d = r.date { Text(CTW.ngayNgan(d) ?? d).font(.ctw(size: 9)).foregroundColor(AppColors.textTertiary) }
                        }
                        .frame(minWidth: 58)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(AppColors.backgroundTertiary))
                        .accessibilityElement(children: .combine)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(14)
        .ctwThe(14)
    }

    @ViewBuilder private func truong(_ ten: String, _ gt: String?, mono: Bool = false) -> some View {
        if let gt, !gt.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(ten.uppercased()).font(.ctw(size: 10, weight: .bold)).foregroundColor(AppColors.textTertiary)
                Text(gt).font(mono ? .ctw(size: 13, design: .monospaced) : .ctw(size: 14))
                    .foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
    }
}
