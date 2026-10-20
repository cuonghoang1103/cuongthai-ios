import SwiftUI

// MARK: - Change requests — danh sách + chi tiết + tạo/sửa
//
// Máy chủ (`govCtx`) chặn khách và khách mời không phải giảng viên
// (`WORK_INTERNAL_ONLY`); ghi cần ADMIN/MEMBER. Trạng thái UNDER_REVIEW /
// APPROVED / REJECTED chỉ đến từ phê duyệt — app chỉ cho bước chuyển tay hợp lệ.

@MainActor
final class ThayDoiVM: ObservableObject {
    let pid: Int
    @Published var ds: CTWCrDanhSach?
    @Published var loc: String?
    @Published var loi: String?
    @Published var tatMoDun = false
    init(pid: Int) { self.pid = pid }

    func tai() async {
        do { ds = try await APIClient.shared.request(CTWAPI.dsCr(pid: pid, trangThai: loc)); loi = nil }
        catch {
            if GovLoi.laTatMoDun(error) { tatMoDun = true; return }
            loi = CTW.loi(error)
        }
    }
}

enum TamPhuCr: Identifiable {
    case tao, sua(CTWCr), xinDuyet(CTWCr)
    var id: String {
        switch self {
        case .tao: return "tao"
        case .sua(let c): return "sua-\(c.id)"
        case .xinDuyet(let c): return "duyet-\(c.id)"
        }
    }
}

struct ThayDoiCTW: View {
    let pid: Int
    @StateObject private var vm: ThayDoiVM
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var tamPhu: TamPhuCr?

    init(pid: Int) {
        self.pid = pid
        _vm = StateObject(wrappedValue: ThayDoiVM(pid: pid))
    }

    private var chips: [CTWChipLoc] {
        let dem = vm.ds?.totals?.byStatus ?? [:]
        let dau = CTWChipLoc(id: "ALL", nhan: String(localized: "All"), bat: vm.loc == nil)
        return [dau] + CTWCrLuat.trangThai.map { s in
            CTWChipLoc(id: s, nhan: CTWMauTrangThai.nhan(s) + (dem[s].map { " \($0)" } ?? ""), bat: vm.loc == s)
        }
    }

    var body: some View {
        List {
            if let loi = vm.loi {
                CTWErrorBanner(text: loi) { vm.loi = nil }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            if vm.tatMoDun {
                GovTatMoDun(ten: String(localized: "Change requests")).listRowBackground(Color.clear)
            } else if let ds = vm.ds {
                Section { tongQuan(ds) }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                let items = ds.items ?? []
                if items.isEmpty {
                    CTWOTrong(bieuTuong: "arrow.triangle.branch", tieuDe: vm.loc == nil ? String(localized: "No change requests") : String(localized: "Nothing here"),
                              moTa: String(localized: "Change requests record scope, schedule and cost changes, and who approved them."),
                              nut: ds.canEdit == true && vm.loc == nil ? String(localized: "New change request") : nil,
                              hanhDong: { tamPhu = .tao })
                        .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(items) { c in
                            NavigationLink(value: RouteCrCTW(pid: pid, so: c.number)) { GovHangCr(c: c) }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundPrimary)
        .overlay { if vm.ds == nil && vm.loi == nil && !vm.tatMoDun { CTWKhungTai(soHang: 5, coAvatar: false) } }
        .navigationTitle("Change requests")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if vm.ds?.canEdit == true {
                ToolbarItem(placement: .primaryAction) {
                    Button { tamPhu = .tao } label: { Image(systemName: "plus") }.accessibilityLabel("New change request")
                }
            }
        }
        .refreshable { await vm.tai() }
        .task { if vm.ds == nil { await vm.tai() } }
        .sheet(item: $tamPhu) { t in
            if case .tao = t {
                FormCrCTW(pid: pid, ban: nil) { c in
                    Task { await vm.tai() }
                    nganXep.duong.append(RouteCrCTW(pid: pid, so: c.number))
                }
            }
        }
        .task(id: app.dichCho) {
            guard let d = app.dichCho, d.moDun == "changes" else { return }
            defer { app.dichCho = nil }
            if let so = d.duongDan.phanCon.first.flatMap({ Int($0.replacingOccurrences(of: "CR-", with: "")) }) ?? d.duongDan.tham["cr"].flatMap(Int.init) {
                nganXep.duong.append(RouteCrCTW(pid: pid, so: so))
            }
        }
        #if DEBUG
        .onAppear {
            if XemThuCTW.conCua("changes") == "detail", nganXep.duong.count <= 1 { nganXep.duong.append(RouteCrCTW(pid: pid, so: 5)) }
        }
        #endif
    }

    private func tongQuan(_ ds: CTWCrDanhSach) -> some View {
        let t = ds.totals
        let tien = (t?.approvedCost ?? []).compactMap { c in c.amount.map { CTWCrLuat.tien($0, c.currency) } }.joined(separator: " · ")
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                CTWODem(so: "\(t?.approvedCount ?? 0)", nhan: String(localized: "Approved changes"), bieuTuong: "checkmark.seal.fill", mau: AppColors.success)
                CTWODem(so: "\(t?.pending ?? 0)", nhan: String(localized: "Waiting for a decision"), bieuTuong: "hourglass", mau: AppColors.warning)
            }
            HStack(spacing: 10) {
                CTWODem(so: (t?.approvedDays ?? 0) == 0 ? "0" : String(localized: "\((t?.approvedDays ?? 0) > 0 ? "+" : "")\(t?.approvedDays ?? 0)d"),
                        nhan: String(localized: "Approved schedule impact"), bieuTuong: "calendar.badge.clock", mau: AppColors.info)
                CTWODem(so: tien.isEmpty ? "0" : tien, nhan: String(localized: "Approved cost impact"), bieuTuong: "banknote", mau: AppColors.primary)
            }
            CTWThanhLoc(chip: chips) { c in
                vm.loc = c.id == "ALL" ? nil : c.id
                Task { await vm.tai() }
            }
        }
    }
}

struct GovHangCr: View {
    let c: CTWCr
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(c.nhanKhoa).font(.ctw(size: 12, weight: .semibold).monospaced()).foregroundColor(AppColors.textSecondary)
                CTWChipChu(chu: c.status)
                if let u = c.urgency { CTWNhanNho(chu: CTWMauTrangThai.nhan(u), bieuTuong: "flame", mau: CTWMauTrangThai.mau(u)) }
                Spacer(minLength: 0)
                if c.clientVisible == true { Image(systemName: "person.crop.rectangle").font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary).accessibilityLabel("Shared with client") }
            }
            Text(c.title).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary).lineLimit(2)
            HStack(spacing: 10) {
                if let o = c.owner {
                    HStack(spacing: 4) { CTWAvatar(user: o, size: 18); Text(o.ten).lineLimit(1) }
                }
                if let l = c.nhanLich { Label(l, systemImage: "calendar") }
                if let t = c.nhanChiPhi { Label(t, systemImage: "banknote") }
                if let w = c.waitingDays, c.pendingApprovalId != nil { Label("\(w)d waiting", systemImage: "hourglass") }
            }
            .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
            .labelStyle(.titleAndIcon)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Chi tiết

struct ChiTietCrCTW: View {
    let pid: Int
    let so: Int
    @EnvironmentObject private var app: AppState
    @State private var c: CTWCr?
    @State private var loi: String?
    @State private var khoaSua = false
    @State private var tamPhu: TamPhuCr?
    @State private var dangDoi = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }
                if khoaSua { GovDaiKhoaSua(pid: pid) { khoaSua = false } }
                if let c {
                    dau(c)
                    hanhDong(c)
                    tacDong(c)
                    noiDung(c)
                    lienKet(c)
                } else if loi == nil {
                    CTWKhungTai(soHang: 4, coAvatar: false).padding(-Spacing.md)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(c?.nhanKhoa ?? "CR-\(so)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let c, c.canEdit == true, c.status != "IMPLEMENTED" {
                ToolbarItem(placement: .primaryAction) {
                    Button { tamPhu = .sua(c) } label: { Text("Edit") }
                }
            }
        }
        .refreshable { await tai() }
        .task { if c == nil { await tai() } }
        .sheet(item: $tamPhu) { t in
            switch t {
            case .tao: EmptyView()
            case .sua(let ban):
                FormCrCTW(pid: pid, ban: ban) { moi in c = moi }
            case .xinDuyet(let ban):
                GovYeuCauDuyetView(cfg: app.cauHinhDuAn, tieuDe: String(localized: "Request approval"),
                                   moTa: String(localized: "Approvers sign \(ban.nhanKhoa) “\(ban.title)”. Approval moves it to Approved; one rejection moves it to Rejected.")) { ids, tuanTu, han in
                    do {
                        let _: CTWDuyet = try await APIClient.shared.request(CTWAPI.xinDuyetCr(pid: pid, so: so, nguoiDuyet: ids, tuanTu: tuanTu, han: han))
                        await tai()
                        return nil
                    } catch {
                        return CTW.loi(error)
                    }
                }
            }
        }
    }

    private func dau(_ c: CTWCr) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                CTWChipChu(chu: c.status)
                if let u = c.urgency { CTWNhanNho(chu: String(localized: "\(CTWMauTrangThai.nhan(u)) urgency"), bieuTuong: "flame", mau: CTWMauTrangThai.mau(u)) }
                if c.clientVisible == true { CTWNhanNho(chu: String(localized: "Shared with client"), bieuTuong: "person.crop.rectangle") }
            }
            Text(c.title).font(.ctw(size: 22, weight: .bold)).foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .ctwMenuBaoCaoChan(khoa: "cr-\(pid)-\(c.number)", noiDung: c.title, nguCanh: "Change request \(c.nhanKhoa)",
                                   tacGia: c.createdBy ?? c.requester, laCuaToi: (c.createdBy ?? c.requester)?.id == app.currentUser?.id,
                                   dich: CTWDichBaoCao("change_request", c.id))
        }
    }

    @ViewBuilder
    private func hanhDong(_ c: CTWCr) -> some View {
        let buoc = c.canEdit == true ? CTWCrLuat.buocTay(tu: c.status) : []
        let xin = c.canRequestApproval == true && c.approvalsOn != false && CTWCrLuat.xinDuyetDuoc(c.status) && c.pendingApprovalId == nil
        if let aid = c.pendingApprovalId {
            NavigationLink(value: RouteDuyetCTW(pid: pid, id: aid)) {
                HStack(spacing: 10) {
                    Image(systemName: "hourglass").foregroundColor(AppColors.warning)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Approval in progress").font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                        Text(c.waitingDays.map { $0 == 1 ? String(localized: "Waiting 1 day") : String(localized: "Waiting \($0) days") } ?? String(localized: "Tap to see who still needs to sign"))
                            .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                }
                .padding(12).ctwThe(12)
            }
            .buttonStyle(.plain)
        }
        if !buoc.isEmpty || xin {
            HStack(spacing: 10) {
                ForEach(buoc, id: \.self) { b in
                    Button { Task { await doi(b) } } label: {
                        Text(CTWCrLuat.nhanBuoc(b)).frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                }
                if xin {
                    Button { tamPhu = .xinDuyet(c) } label: {
                        Label("Request approval", systemImage: "signature").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .disabled(dangDoi)
        }
    }

    private func tacDong(_ c: CTWCr) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CTWSectionHeader("gauge.with.dots.needle.33percent", String(localized: "Impact"))
            CTWKhoiTruong {
                CTWHangTruong(String(localized: "Schedule"), c.nhanLich ?? String(localized: "No change"), bieuTuong: "calendar.badge.clock")
                Divider()
                CTWHangTruong(String(localized: "Cost"), c.nhanChiPhi ?? String(localized: "No change"), bieuTuong: "banknote")
                Divider()
                CTWHangTruong(nhan: String(localized: "Owner"), bieuTuong: "person") { nguoi(c.owner) }
                Divider()
                CTWHangTruong(nhan: String(localized: "Requester"), bieuTuong: "person.wave.2") { nguoi(c.requester) }
                if let s = c.sourceIssue {
                    Divider()
                    NavigationLink(value: CTWRoute.the(pid: pid, so: s.number)) {
                        CTWHangTruong(nhan: String(localized: "Raised from"), bieuTuong: "link") { Text(s.title ?? "#\(s.number)").lineLimit(1) }
                    }
                    .buttonStyle(.plain)
                }
                Divider()
                CTWHangTruong(String(localized: "Updated"), CTW.thoiDiem(c.updatedAt), bieuTuong: "clock")
            }
        }
    }

    private func nguoi(_ u: CTWUser?) -> some View {
        HStack(spacing: 6) {
            if let u {
                CTWAvatar(user: u, size: 20)
                Text(u.ten).lineLimit(1)
                if u.laAgent { CTWNhanAI() }
            } else { Text("—") }
        }
    }

    @ViewBuilder
    private func noiDung(_ c: CTWCr) -> some View {
        let tacGia = c.createdBy ?? c.requester
        let cuaToi = tacGia?.id == app.currentUser?.id
        if let d = c.descriptionJson, !d.chuTron.isEmpty {
            CTWSectionHeader("text.alignleft", String(localized: "Description"))
            CTWTipTapView(doc: d, coChu: 15)
                .padding(14).frame(maxWidth: .infinity, alignment: .leading).ctwThe(14)
                .ctwMenuBaoCaoChan(khoa: "cr-desc-\(pid)-\(c.number)", noiDung: d.chuTron, nguCanh: "Change request \(c.nhanKhoa)",
                                   tacGia: tacGia, laCuaToi: cuaToi, dich: CTWDichBaoCao("change_request", c.id))
        }
        ForEach([("Reason", "questionmark.bubble", c.reason, String(localized: "Reason")),
                 ("Impact on scope", "square.dashed", c.impactScope, String(localized: "Impact on scope")),
                 ("Risk", "exclamationmark.shield", c.impactRisk, String(localized: "Risk")),
                 ("Alternatives considered", "arrow.triangle.swap", c.alternatives, String(localized: "Alternatives considered"))],
                id: \.0) { m in
            if let t = m.2?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                CTWSectionHeader(m.1, m.3)
                CTWMarkdownView(markdown: t, coChu: 15)
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading).ctwThe(14)
                    .ctwMenuBaoCaoChan(khoa: "cr-\(m.0.lowercased())-\(pid)-\(c.number)", noiDung: t,
                                       nguCanh: "Change request \(c.nhanKhoa)", tacGia: tacGia, laCuaToi: cuaToi,
                                       dich: CTWDichBaoCao("change_request", c.id))
            }
        }
    }

    @ViewBuilder
    private func lienKet(_ c: CTWCr) -> some View {
        let ds = c.links ?? []
        if !ds.isEmpty {
            CTWSectionHeader("link", String(localized: "Linked work"), count: "\(ds.count)")
            VStack(spacing: 0) {
                ForEach(ds) { l in
                    Group {
                        if let i = l.issue {
                            NavigationLink(value: CTWRoute.the(pid: pid, so: i.number)) {
                                hangLienKet(i.done == true ? "checkmark.circle.fill" : "circle", i.key ?? "#\(i.number)", i.title ?? "", l.role)
                            }
                            .buttonStyle(.plain)
                        } else if let s = l.stage {
                            hangLienKet("flag.checkered", String(localized: "Stage \(s.n.map(String.init) ?? "")"), s.name ?? "", l.role)
                        } else if let v = l.version {
                            hangLienKet("shippingbox", v.name ?? String(localized: "Release"), CTW.ngayNgan(v.releaseDate) ?? "", l.role)
                        }
                    }
                    if l.id != ds.last?.id { Divider() }
                }
            }
            .padding(.horizontal, 14).ctwThe(14)
        }
        if let r = c.risks, !r.isEmpty {
            CTWSectionHeader("exclamationmark.triangle", String(localized: "Related risks"), count: "\(r.count)")
            VStack(spacing: 0) {
                ForEach(r, id: \.number) { x in
                    NavigationLink(value: RouteRaidCTW(pid: pid, so: x.number)) {
                        hangLienKet("exclamationmark.triangle", CTWRaidLuat.khoa(x.type, x.number), x.title ?? "", x.status)
                    }
                    .buttonStyle(.plain)
                    if x.number != r.last?.number { Divider() }
                }
            }
            .padding(.horizontal, 14).ctwThe(14)
        }
    }

    private func hangLienKet(_ icon: String, _ khoa: String, _ ten: String, _ vai: String?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(AppColors.primary).frame(width: 18)
            Text(khoa).font(.ctw(size: 12, weight: .semibold).monospaced()).foregroundColor(AppColors.textSecondary)
            Text(ten).font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary).lineLimit(1)
            Spacer(minLength: 0)
            if let vai { Text(CTWMauTrangThai.nhan(vai)).font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary) }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    // MARK: Mạng

    private func tai() async {
        do { c = try await APIClient.shared.request(CTWAPI.cr(pid: pid, so: so)); loi = nil }
        catch { loi = CTW.loi(error) }
    }

    private func doi(_ s: String) async {
        dangDoi = true
        defer { dangDoi = false }
        do {
            c = try await APIClient.shared.request(CTWAPI.doiTrangThaiCr(pid: pid, so: so, trangThai: s))
            CTWRung.thanhCong()
        } catch {
            CTWRung.loi()
            if GovLoi.laKhoaSua(error) { khoaSua = true } else { loi = CTW.loi(error) }
            if CTW.laXungDot(error) { await tai() }
        }
    }
}

// MARK: - Tạo / sửa

struct FormCrCTW: View {
    let pid: Int
    let ban: CTWCr?
    let xong: (CTWCr) -> Void
    @Environment(\.dismiss) private var dong
    @State private var tieuDe = ""
    @State private var lyDo = ""
    @State private var khan = "MEDIUM"
    @State private var phamVi = ""
    @State private var soNgay = ""
    @State private var chiPhi = ""
    @State private var tienTe = "VND"
    @State private var ruiRo = ""
    @State private var phuongAn = ""
    @State private var loi: String?
    @State private var dangLuu = false
    @State private var khoaSua = false

    var body: some View {
        NavigationStack {
            Form {
                if let loi { Section { CTWErrorBanner(text: loi) { self.loi = nil } }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear) }
                if khoaSua { Section { GovDaiKhoaSua(pid: pid) { khoaSua = false } }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear) }
                Section("Change") {
                    TextField("Title", text: $tieuDe, axis: .vertical).lineLimit(1...3)
                    TextField("Why is this change needed?", text: $lyDo, axis: .vertical).lineLimit(2...6)
                    Picker("Urgency", selection: $khan) {
                        Text("Low").tag("LOW"); Text("Medium").tag("MEDIUM"); Text("High").tag("HIGH")
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    TextField("Impact on scope", text: $phamVi, axis: .vertical).lineLimit(1...5)
                    HStack {
                        Text("Schedule (days)")
                        Spacer()
                        TextField("0", text: $soNgay).keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing).frame(maxWidth: 120)
                    }
                    HStack {
                        Text("Cost")
                        Spacer()
                        TextField("0", text: $chiPhi).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 140)
                        TextField("VND", text: $tienTe).textInputAutocapitalization(.characters).autocorrectionDisabled()
                            .multilineTextAlignment(.trailing).frame(width: 56)
                    }
                    TextField("Risk", text: $ruiRo, axis: .vertical).lineLimit(1...5)
                    TextField("Alternatives considered", text: $phuongAn, axis: .vertical).lineLimit(1...5)
                } header: { Text("Impact") } footer: {
                    Text("Use a negative number of days if the change saves time.")
                }
            }
            .navigationTitle(ban == nil ? "New change request" : "Edit \(ban!.nhanKhoa)")
            .ctwTieuDeNho()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    if dangLuu { ProgressView() } else {
                        Button(ban == nil ? "Create" : "Save") { Task { await luu() } }
                            .bold()
                            .disabled(tieuDe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .onAppear(perform: napBan)
        }
    }

    private func napBan() {
        guard let b = ban, tieuDe.isEmpty else { return }
        tieuDe = b.title
        lyDo = b.reason ?? ""
        khan = b.urgency ?? "MEDIUM"
        phamVi = b.impactScope ?? ""
        soNgay = b.scheduleDays.map(String.init) ?? ""
        chiPhi = b.costAmount.map { $0.rounded() == $0 ? String(Int($0)) : String($0) } ?? ""
        tienTe = b.costCurrency ?? "VND"
        ruiRo = b.impactRisk ?? ""
        phuongAn = b.alternatives ?? ""
    }

    private func chuHoacNull(_ s: String) -> Any {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return govNull(t.isEmpty ? nil : t)
    }

    private func luu() async {
        let ngay = Int(soNgay.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "+", with: ""))
        if !soNgay.trimmingCharacters(in: .whitespaces).isEmpty, ngay == nil || abs(ngay!) > 3650 {
            loi = String(localized: "Schedule impact must be a whole number of days (up to ±3650)."); return
        }
        let tien = Double(chiPhi.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces))
        if !chiPhi.trimmingCharacters(in: .whitespaces).isEmpty, tien == nil { loi = String(localized: "Cost must be a number."); return }
        var t: [String: Any] = [
            "title": String(tieuDe.trimmingCharacters(in: .whitespacesAndNewlines).prefix(255)),
            "reason": chuHoacNull(lyDo), "urgency": khan, "impactScope": chuHoacNull(phamVi),
            "impactRisk": chuHoacNull(ruiRo), "alternatives": chuHoacNull(phuongAn),
            "scheduleDays": govNull(ngay),
            "costAmount": govNull(tien),
            "costCurrency": govNull(tien == nil ? nil : String(tienTe.trimmingCharacters(in: .whitespaces).uppercased().prefix(16))),
        ]
        dangLuu = true
        defer { dangLuu = false }
        do {
            let c: CTWCr
            if let b = ban {
                if let v = b.version { t["version"] = v }
                c = try await APIClient.shared.request(CTWAPI.suaCr(pid: pid, so: b.number, than: t))
            } else {
                c = try await APIClient.shared.request(CTWAPI.taoCr(pid: pid, than: t))
            }
            CTWRung.thanhCong()
            xong(c)
            dong()
        } catch {
            CTWRung.loi()
            if GovLoi.laKhoaSua(error) { khoaSua = true }
            else if CTW.laXungDot(error) { loi = String(localized: "Someone else changed this change request. Close, pull to refresh and try again.") }
            else { loi = CTW.loi(error) }
        }
    }
}
