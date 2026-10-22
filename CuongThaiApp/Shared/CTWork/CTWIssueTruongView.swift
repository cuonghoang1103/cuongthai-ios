import SwiftUI

// MARK: - CT Work — TRƯỜNG của thẻ, sửa được hết như web (20/10/2026)
//
// Đối chiếu `IssueDetail.tsx → properties` (nhóm Details / Planning / More), `fields.tsx`, `CustomFields.tsx`,
// `TimeTracking.tsx`. Luật hiện trường y như web:
//   · Epic/Parent: loại không phải epic; cha = loại cấp trên (`level + 1`)
//   · Sprint: dự án không phải KANBAN và thẻ cấp 0 · Ước lượng: không phải epic
//   · Team/Stage: chỉ khi mô-đun `teams`/`stages` BẬT (`modules[x] == true`) · Components: dự án có component
//   · Cờ "Blocked": không hiện với khách cổng · Trường tuỳ chỉnh: theo `typeKeys`
// Quyền: `permissions.editIssues` (máy chủ đã tắt sẵn khi người xem bật khoá chỉnh sửa — `editLocked`).
// Mỗi lần sửa gửi đúng trường đó + `version` (CTWIssueVM.sua); trường tuỳ chỉnh gửi PUT custom-values một trường.

private enum TamPhuTruong: Identifiable {
    case nhan, thanhPhan, cha
    case ngay(String, String, String?)                 // (khoá, tiêu đề, giá trị)
    case nhap(String, String, String, CTWNhapGiaTriView.KieuBanPhim)   // (khoá, tiêu đề, giá trị, bàn phím)
    case coChan
    case nhieu(CTWCustomField)
    var id: String {
        switch self {
        case .nhan: return "nhan"
        case .thanhPhan: return "tp"
        case .cha: return "cha"
        case .ngay(let k, _, _): return "ngay-\(k)"
        case .nhap(let k, _, _, _): return "nhap-\(k)"
        case .coChan: return "co"
        case .nhieu(let f): return "nhieu-\(f.id)"
        }
    }
}

struct CTWIssueTruongView: View {
    @ObservedObject var vm: CTWIssueVM
    let t: CTWIssueDetail
    let cfg: CTWProjectConfig
    var moRong: CTWIssueMoRong?
    @EnvironmentObject private var appState: AppState
    @State private var tamPhu: TamPhuTruong?
    @State private var giaTri: CTWGiaTriTruongThe?
    @State private var loiTruong: String?
    @State private var boPhan: [CTWTeamRef]?
    @State private var giaiDoan: [CTWStageRef]?
    @AppStorage("ctw.the.nhom.details") private var moDetails = true
    @AppStorage("ctw.the.nhom.planning") private var moPlanning = true
    @AppStorage("ctw.the.nhom.more") private var moMore = true

    private var them: CTWIssueThem? { vm.them }
    private var cfgThem: CTWCauHinhThem? { vm.cauHinhThem }
    private var sua: Bool { cfg.coTheSua }
    private var loai: CTWIssueType? { cfg.loai(t.typeId) }
    private var cap: Int { loai?.level ?? 0 }
    private var laKhach: Bool { cfg.role == "CLIENT" || cfgThem?.clientView == true }
    private func batMoDun(_ m: String) -> Bool { cfg.modules?[m] == true }

    private var truongTuyChinh: [CTWCustomField] {
        (cfgThem?.customFields ?? []).filter { $0.apCho(loai: loai?.key) }.sorted { ($0.position ?? 0) < ($1.position ?? 0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if cfgThem?.editLocked == true {
                Label("Edit lock is on — you're viewing this project read-only.", systemImage: "lock.fill")
                    .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
            }
            nhom(String(localized: "Details"), mo: $moDetails) { chiTiet }
            nhom(String(localized: "Planning"), mo: $moPlanning) { keHoach }
            nhom(String(localized: "More"), mo: $moMore) { themNua }
            chanTrang
        }
        .sheet(item: $tamPhu) { tp in tamPhuView(tp) }
        .task(id: t.id) { await taiPhu() }
        #if DEBUG
        .task {
            let man = ProcessInfo.processInfo.environment["CT_XEM_MAN"]?.lowercased()
            if man == "the:nhan" { try? await Task.sleep(nanoseconds: 800_000_000); tamPhu = .nhan }
        }
        #endif
    }

    // MARK: Nhóm

    private func nhom<V: View>(_ ten: String, mo: Binding<Bool>, @ViewBuilder _ noiDung: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { mo.wrappedValue.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: mo.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.ctw(size: 11, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                        .frame(width: 14)
                    Text(ten).font(.ctw(size: 13, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                    Spacer()
                }
                .frame(minHeight: 40)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityValue(mo.wrappedValue ? Text("Expanded") : Text("Collapsed"))
            if mo.wrappedValue {
                VStack(spacing: 0) { noiDung() }
            }
        }
        .padding(.horizontal, 14)
        .ctwThe(14)
    }

    private func hang<V: View>(_ ten: String, batBuoc: Bool = false, @ViewBuilder _ gt: () -> V) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                (Text(verbatim: ten) + (batBuoc ? Text(verbatim: " *").foregroundColor(AppColors.error) : Text(verbatim: "")))
                    .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                    .frame(width: 112, alignment: .leading)
                    .lineLimit(2)
                Spacer(minLength: 0)
                gt()
            }
            .frame(minHeight: 46)
        }
    }

    /// Ô giá trị bấm được (mở tấm phủ) — chữ phụ khi trống.
    private func oBam(_ chu: String?, trong: String = String(localized: "None"), _ hanhDong: @escaping () -> Void) -> some View {
        Button(action: hanhDong) {
            HStack(spacing: 4) {
                Text(verbatim: chu ?? trong)
                    .font(.ctw(size: 14))
                    .foregroundColor(chu == nil ? AppColors.textTertiary : AppColors.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                if sua { Image(systemName: "chevron.right").font(.ctw(size: 11, weight: .semibold)).foregroundColor(AppColors.textTertiary) }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!sua)
    }

    private func nhanMenu(_ chu: String?, trong: String = String(localized: "None")) -> some View {
        HStack(spacing: 4) {
            Text(verbatim: chu ?? trong)
                .font(.ctw(size: 14))
                .foregroundColor(chu == nil ? AppColors.textTertiary : AppColors.textPrimary)
                .lineLimit(1)
            if sua { Image(systemName: "chevron.up.chevron.down").font(.ctw(size: 10, weight: .semibold)).foregroundColor(AppColors.textTertiary) }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    // MARK: Details

    @ViewBuilder
    private var chiTiet: some View {
        hang(String(localized: "Assignee")) { menuNguoi }
        hang(String(localized: "Reporter")) {
            HStack(spacing: 6) {
                CTWAvatar(user: t.reporter, size: 22).ctwChamMoHoSo(t.reporter?.laAgent == true ? nil : t.reporter?.id)
                Text(verbatim: t.reporter?.ten ?? "—").font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary)
                if t.reporter?.laAgent == true { CTWNhanAI() }
            }
        }
        hang(String(localized: "Priority")) { menuUuTien }
        hang(String(localized: "Labels")) {
            let ds = (cfg.labels ?? []).filter { (t.labelIds ?? []).contains($0.id) }
            Button { tamPhu = .nhan } label: {
                HStack(spacing: 4) {
                    if ds.isEmpty {
                        Text("None").font(.ctw(size: 14)).foregroundColor(AppColors.textTertiary)
                    } else {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 4) { ForEach(ds) { CTWLabelChip(label: $0) } }
                            Text(verbatim: ds.map(\.name).joined(separator: ", ")).font(.ctw(size: 13))
                                .foregroundColor(AppColors.textPrimary).lineLimit(2).multilineTextAlignment(.trailing)
                        }
                    }
                    if sua { Image(systemName: "chevron.right").font(.ctw(size: 11, weight: .semibold)).foregroundColor(AppColors.textTertiary) }
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!sua || (cfg.labels ?? []).isEmpty)
        }
        if !laKhach {
            hang(String(localized: "Blocked")) { oCo }
        }
    }

    @ViewBuilder
    private var menuNguoi: some View {
        let nhan = HStack(spacing: 6) {
            CTWAvatar(user: t.assignee, size: 22)
            Text(verbatim: t.assignee?.ten ?? String(localized: "Unassigned"))
                .font(.ctw(size: 14))
                .foregroundColor(t.assignee == nil ? AppColors.textSecondary : AppColors.textPrimary)
                .lineLimit(1)
            if t.assignee?.laAgent == true { CTWNhanAI() }
        }
        .frame(minHeight: 44)
        if sua {
            Menu {
                if let toi = appState.currentUser?.id, cfg.nguoiGiaoDuoc.contains(where: { $0.id == toi }), t.assigneeId != toi {
                    Button { Task { await vm.sua(["assigneeId": toi]) } } label: { Label("Assign to me", systemImage: "person.fill.checkmark") }
                }
                Button { Task { await vm.sua(["assigneeId": NSNull()]) } } label: {
                    if t.assigneeId == nil { Label("Unassigned", systemImage: "checkmark") } else { Text("Unassigned") }
                }
                Divider()
                ForEach(cfg.nguoiGiaoDuoc) { u in
                    Button { Task { await vm.sua(["assigneeId": u.id]) } } label: {
                        let ten = u.laAgent ? String(localized: "\(u.ten) · AI agent") : u.ten
                        if u.id == t.assigneeId { Label(ten, systemImage: "checkmark") }
                        else if u.laAgent { Label(ten, systemImage: "sparkles") }
                        else { Text(verbatim: ten) }
                    }
                }
            } label: { nhan }
            .accessibilityLabel(Text("Assignee: \(t.assignee?.ten ?? String(localized: "Unassigned"))"))
        } else {
            nhan
        }
    }

    @ViewBuilder
    private var menuUuTien: some View {
        let p = CTW.uuTien(t.priority)
        let nhan = HStack(spacing: 6) {
            CTWPriorityIcon(priority: t.priority)
            Text(verbatim: p.ten).font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary)
        }
        .frame(minHeight: 44)
        if sua {
            Menu {
                ForEach(CTW.doUuTien, id: \.so) { m in
                    Button { Task { await vm.sua(["priority": m.so]) } } label: {
                        Label(m.ten, systemImage: m.so == p.so ? "checkmark" : m.bieuTuong)
                    }
                }
            } label: { nhan }
        } else {
            nhan
        }
    }

    @ViewBuilder
    private var oCo: some View {
        if t.flaggedAt != nil {
            let nhan = HStack(spacing: 5) {
                Image(systemName: "flag.fill").foregroundColor(AppColors.error)
                Text(verbatim: them?.flagReason ?? String(localized: "Blocked"))
                    .font(.ctw(size: 13)).foregroundColor(AppColors.textPrimary).lineLimit(2).multilineTextAlignment(.trailing)
            }
            .frame(minHeight: 44)
            if sua {
                Menu {
                    Button { tamPhu = .coChan } label: { Label("Change reason", systemImage: "pencil") }
                    Button(role: .destructive) {
                        Task { _ = await vm.goi(CTWAPI.goCo(pid: vm.pid, so: vm.so)) }
                    } label: { Label("Remove flag", systemImage: "flag.slash") }
                } label: { nhan }
            } else {
                nhan
            }
        } else if sua {
            Button { tamPhu = .coChan } label: {
                Label("Flag as blocked", systemImage: "flag").font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                    .frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            Text("No").font(.ctw(size: 14)).foregroundColor(AppColors.textTertiary)
        }
    }

    // MARK: Planning

    private var loaiCha: [Int] { cfg.dsLoai.filter { ($0.level ?? 0) == cap + 1 }.map(\.id) }

    @ViewBuilder
    private var keHoach: some View {
        if cap != 1, !loaiCha.isEmpty {
            hang(cap == -1 ? String(localized: "Parent") : String(localized: "Epic")) {
                oBam(t.parent.map { "\(cfg.key)-\($0.number) \($0.title)" },
                     trong: cap == -1 ? String(localized: "Choose a parent") : String(localized: "No epic")) { tamPhu = .cha }
            }
        }
        if cfg.type != "KANBAN" && cap == 0 {
            hang(String(localized: "Sprint")) { menuSprint }
        }
        let phienBan = (cfgThem?.versions ?? []).filter { $0.status != "ARCHIVED" || $0.id == them?.fixVersionId }
        if !phienBan.isEmpty || them?.fixVersionId != nil {
            hang(String(localized: "Fix version")) { menuPhienBan(phienBan) }
        }
        if cap != 1 {
            if cfgThem?.theoGio == true {
                hang(String(localized: "Estimate (hours)")) {
                    let gio = them?.originalEstimateMin.map { Double($0) / 60 }
                    oBam(gio.map(Self.so)) {
                        tamPhu = .nhap("est", String(localized: "Estimate (hours)"), gio.map(Self.so) ?? "", .so)
                    }
                }
            } else {
                hang(String(localized: "Story points")) {
                    oBam(t.storyPoints.map(Self.so)) {
                        tamPhu = .nhap("sp", String(localized: "Story points"), t.storyPoints.map(Self.so) ?? "", .so)
                    }
                }
            }
        }
        hang(String(localized: "Start date")) {
            oBam(CTWKieuWeb.ngay(t.startDate)) { tamPhu = .ngay("start", String(localized: "Start date"), t.startDate) }
        }
        hang(String(localized: "Due date")) {
            let tre = t.resolvedAt == nil && CTW.quaHan(t.dueDate)
            Button { tamPhu = .ngay("due", String(localized: "Due date"), t.dueDate) } label: {
                HStack(spacing: 4) {
                    if t.dueDate != nil { CTWDueChip(dueDate: t.dueDate, xong: t.resolvedAt != nil, co: 13) }
                    else { Text("None").font(.ctw(size: 14)).foregroundColor(AppColors.textTertiary) }
                    if sua { Image(systemName: "chevron.right").font(.ctw(size: 11, weight: .semibold)).foregroundColor(AppColors.textTertiary) }
                }
                .frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!sua)
            .accessibilityValue(tre ? Text("Overdue") : Text(""))
        }
        if batMoDun("teams") && !laKhach {
            hang(String(localized: "Team")) { menuBoPhan }
        }
        if batMoDun("stages") && !laKhach {
            hang(String(localized: "Stage")) { menuGiaiDoan }
        }
        if !(cfgThem?.components ?? []).isEmpty {
            hang(String(localized: "Components")) {
                let ds = (cfgThem?.components ?? []).filter { (them?.componentIds ?? []).contains($0.id) }
                oBam(ds.isEmpty ? nil : ds.map(\.name).joined(separator: ", ")) { tamPhu = .thanhPhan }
            }
        }
    }

    @ViewBuilder
    private var menuSprint: some View {
        let ds = (cfg.sprints ?? []).filter { $0.state != "CLOSED" || $0.id == t.sprintId }
        let hienTai = ds.first { $0.id == t.sprintId }
        if sua {
            Menu {
                Button { Task { await vm.sua(["sprintId": NSNull()]) } } label: {
                    if t.sprintId == nil { Label("Backlog", systemImage: "checkmark") } else { Text("Backlog") }
                }
                Divider()
                ForEach(ds) { s in
                    Button { Task { await vm.sua(["sprintId": s.id]) } } label: {
                        let ten = s.state == "ACTIVE" ? String(localized: "\(s.name) · Active") : s.name
                        if s.id == t.sprintId { Label(ten, systemImage: "checkmark") } else { Text(verbatim: ten) }
                    }
                }
            } label: { nhanMenu(hienTai?.name, trong: String(localized: "Backlog")) }
        } else {
            nhanMenu(hienTai?.name, trong: String(localized: "Backlog"))
        }
    }

    @ViewBuilder
    private func menuPhienBan(_ ds: [CTWVersionRef]) -> some View {
        let hienTai = (cfgThem?.versions ?? []).first { $0.id == them?.fixVersionId }
        if sua {
            Menu {
                Button { Task { await vm.sua(["fixVersionId": NSNull()]) } } label: {
                    if them?.fixVersionId == nil { Label("None", systemImage: "checkmark") } else { Text("None") }
                }
                Divider()
                ForEach(ds) { v in
                    Button { Task { await vm.sua(["fixVersionId": v.id]) } } label: {
                        let ten = v.status == "RELEASED" ? String(localized: "\(v.name) · Released") : v.name
                        if v.id == them?.fixVersionId { Label(ten, systemImage: "checkmark") } else { Text(verbatim: ten) }
                    }
                }
            } label: { nhanMenu(hienTai?.name) }
        } else {
            nhanMenu(hienTai?.name)
        }
    }

    @ViewBuilder
    private var menuBoPhan: some View {
        let ds = (boPhan ?? []).filter { $0.archivedAt == nil }
        let hienTai = (boPhan ?? []).first { $0.id == them?.teamId }
        let trong = them?.teamId != nil && hienTai == nil ? String(localized: "Archived team") : String(localized: "No team")
        if sua {
            Menu {
                Button { Task { await vm.sua(["teamId": NSNull()]) } } label: {
                    if them?.teamId == nil { Label("No team", systemImage: "checkmark") } else { Text("No team") }
                }
                Divider()
                ForEach(ds) { b in
                    Button { Task { await vm.sua(["teamId": b.id]) } } label: {
                        if b.id == them?.teamId { Label(b.name, systemImage: "checkmark") } else { Text(verbatim: b.name) }
                    }
                }
            } label: { nhanMenu(hienTai?.name, trong: trong) }
        } else {
            nhanMenu(hienTai?.name, trong: trong)
        }
    }

    @ViewBuilder
    private var menuGiaiDoan: some View {
        let ds = giaiDoan ?? []
        let hienTai = ds.first { $0.id == them?.stageId }
        let ten: (CTWStageRef) -> String = { s in s.n.map { "\($0). \(s.name)" } ?? s.name }
        if sua {
            Menu {
                Button { Task { await vm.sua(["stageId": NSNull()]) } } label: {
                    if them?.stageId == nil { Label("No stage", systemImage: "checkmark") } else { Text("No stage") }
                }
                Divider()
                ForEach(ds) { s in
                    Button { Task { await vm.sua(["stageId": s.id]) } } label: {
                        if s.id == them?.stageId { Label(ten(s), systemImage: "checkmark") } else { Text(verbatim: ten(s)) }
                    }
                }
            } label: { nhanMenu(hienTai.map(ten), trong: String(localized: "No stage")) }
        } else {
            nhanMenu(hienTai.map(ten), trong: String(localized: "No stage"))
        }
    }

    // MARK: More — trường tuỳ chỉnh + thời gian

    @ViewBuilder
    private var themNua: some View {
        if !truongTuyChinh.isEmpty {
            Color.clear.frame(height: 0).id("tuyChinh")
            if let loiTruong {
                Divider()
                Text(verbatim: loiTruong).font(.ctw(size: 12)).foregroundColor(AppColors.error).padding(.vertical, 8)
            }
            ForEach(truongTuyChinh) { f in
                hang(f.name, batBuoc: f.required == true) { oTuyChinh(f) }
            }
        }
        if !laKhach {
            hang(String(localized: "Original estimate")) {
                oBam(them?.originalEstimateMin.map { CTWThoiLuong.chu($0) }) {
                    tamPhu = .nhap("goc", String(localized: "Original estimate"), them?.originalEstimateMin.map { CTWThoiLuong.chu($0) } ?? "", .chu)
                }
            }
            hang(String(localized: "Remaining")) {
                oBam(them?.remainingEstimateMin.map { CTWThoiLuong.chu($0) }) {
                    tamPhu = .nhap("con", String(localized: "Remaining"), them?.remainingEstimateMin.map { CTWThoiLuong.chu($0) } ?? "", .chu)
                }
            }
            hang(String(localized: "Time spent")) {
                Text(verbatim: CTWThoiLuong.chu(them?.timeSpentMin)).font(.ctw(size: 14).monospacedDigit())
                    .foregroundColor(AppColors.textPrimary)
            }
            if let g = moRong?.nutGhiGio, sua {
                Divider()
                g(vm.pid, vm.so, t.title, { Task { await vm.napLaiThe(); vm.nhatKyGio = nil; vm.lichSu = nil } })
                    .padding(.vertical, 10)
                    .id("ghiGio")
            }
        }
    }

    @ViewBuilder
    private func oTuyChinh(_ f: CTWCustomField) -> some View {
        let v = giaTri?.tatCa[f.id]
        switch f.kind {
        case "TEXT":
            oBam(v?.chu) { tamPhu = .nhap("cf-\(f.id)", f.name, v?.chu ?? "", .chu) }
        case "URL":
            HStack(spacing: 6) {
                if let s = v?.chu, let u = URL(string: s) {
                    Link(destination: u) { Image(systemName: "arrow.up.right.square").frame(width: 32, height: 44) }
                        .accessibilityLabel(Text("Open link"))
                }
                oBam(v?.chu) { tamPhu = .nhap("cf-\(f.id)", f.name, v?.chu ?? "", .url) }
            }
        case "NUMBER":
            oBam(v?.so.map(Self.so)) { tamPhu = .nhap("cf-\(f.id)", f.name, v?.so.map(Self.so) ?? "", .so) }
        case "DATE":
            oBam(CTWKieuWeb.ngay(v?.chu)) { tamPhu = .ngay("cf-\(f.id)", f.name, v?.chu) }
        case "CHECKBOX":
            Toggle(isOn: Binding(get: { v?.co == true }, set: { b in Task { await luuTuyChinh(f, b ? .co(true) : nil) } })) {
                EmptyView()
            }
            .labelsHidden()
            .disabled(!sua || giaTri == nil)
            .frame(minHeight: 44)
        case "SELECT":
            let hienTai = (f.options ?? []).first { $0.id == v?.chu }
            if sua {
                Menu {
                    Button { Task { await luuTuyChinh(f, nil) } } label: {
                        if hienTai == nil { Label("None", systemImage: "checkmark") } else { Text("None") }
                    }
                    Divider()
                    ForEach(f.options ?? []) { o in
                        Button { Task { await luuTuyChinh(f, .chu(o.id)) } } label: {
                            if o.id == hienTai?.id { Label(o.label, systemImage: "checkmark") } else { Text(verbatim: o.label) }
                        }
                    }
                } label: { chipLuaChon(hienTai.map { [$0] } ?? []) }
            } else {
                chipLuaChon(hienTai.map { [$0] } ?? [])
            }
        case "MULTISELECT":
            let chon = Set(v?.nhieu ?? [])
            Button { tamPhu = .nhieu(f) } label: { chipLuaChon((f.options ?? []).filter { chon.contains($0.id) }) }
                .buttonStyle(.plain).disabled(!sua)
        case "USER":
            let nguoi = v?.so.flatMap { cfg.thanhVien(Int($0)) }
            let nhan = HStack(spacing: 6) {
                if let nguoi { CTWAvatar(user: nguoi, size: 20) }
                Text(verbatim: nguoi?.ten ?? (v?.so != nil ? String(localized: "Former member") : String(localized: "None")))
                    .font(.ctw(size: 14)).foregroundColor(nguoi == nil ? AppColors.textTertiary : AppColors.textPrimary)
                    .lineLimit(1)
            }
            .frame(minHeight: 44)
            if sua {
                Menu {
                    Button { Task { await luuTuyChinh(f, nil) } } label: { Text("None") }
                    Divider()
                    ForEach(cfg.dsThanhVien) { u in
                        Button { Task { await luuTuyChinh(f, .so(Double(u.id))) } } label: {
                            if u.id == nguoi?.id { Label(u.ten, systemImage: "checkmark") } else { Text(verbatim: u.ten) }
                        }
                    }
                } label: { nhan }
            } else {
                nhan
            }
        default:
            Text("None").font(.ctw(size: 14)).foregroundColor(AppColors.textTertiary)
        }
    }

    private func chipLuaChon(_ ds: [CTWCustomOption]) -> some View {
        HStack(spacing: 4) {
            if ds.isEmpty {
                Text("None").font(.ctw(size: 14)).foregroundColor(AppColors.textTertiary)
            } else {
                ForEach(ds.prefix(3)) { o in
                    HStack(spacing: 4) {
                        Circle().fill(CTW.mau(o.color, macDinh: AppColors.textTertiary)).frame(width: 7, height: 7)
                        Text(verbatim: o.label).lineLimit(1)
                    }
                    .font(.ctw(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .overlay(Capsule().strokeBorder(AppColors.border))
                }
                if ds.count > 3 { Text(verbatim: "+\(ds.count - 3)").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary) }
            }
            if sua { Image(systemName: "chevron.up.chevron.down").font(.ctw(size: 10, weight: .semibold)).foregroundColor(AppColors.textTertiary) }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private var chanTrang: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Created \(CTW.thoiDiem(t.createdAt))")
            Text("Updated \(CTW.thoiDiem(t.updatedAt))")
            if t.resolvedAt != nil { Text("Resolved \(CTW.thoiDiem(t.resolvedAt))") }
        }
        .font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
        .padding(.horizontal, 4)
    }

    // MARK: Tấm phủ

    @ViewBuilder
    private func tamPhuView(_ tp: TamPhuTruong) -> some View {
        switch tp {
        case .nhan:
            CTWChonNhieuView(
                tieuDe: String(localized: "Labels"),
                muc: (cfg.labels ?? []).map { .init(id: String($0.id), ten: $0.name, mau: $0.color) },
                banDau: Set((t.labelIds ?? []).map(String.init))
            ) { s in await vm.sua(["labelIds": s.compactMap(Int.init).sorted()]) }
        case .thanhPhan:
            CTWChonNhieuView(
                tieuDe: String(localized: "Components"),
                muc: (cfgThem?.components ?? []).map { .init(id: String($0.id), ten: $0.name) },
                banDau: Set((them?.componentIds ?? []).map(String.init))
            ) { s in await vm.sua(["componentIds": s.compactMap(Int.init).sorted()]) }
        case .nhieu(let f):
            CTWChonNhieuView(
                tieuDe: f.name,
                muc: (f.options ?? []).map { .init(id: $0.id, ten: $0.label, mau: $0.color) },
                banDau: Set(giaTri?.tatCa[f.id]?.nhieu ?? [])
            ) { s in
                let thuTu = (f.options ?? []).map(\.id).filter { s.contains($0) }
                return await luuTuyChinh(f, thuTu.isEmpty ? nil : .nhieu(thuTu))
            }
        case .cha:
            CTWChonTheView(
                tieuDe: cap == -1 ? String(localized: "Choose a parent") : String(localized: "Choose an epic"),
                pid: vm.pid, cfg: cfg, loai: loaiCha, loaiTru: [t.id],
                choBoChon: cap != -1 && t.parentId != nil, nhanBoChon: String(localized: "Remove from epic")
            ) { c in await vm.sua(["parentId": Self.hoacNull(c?.id)]) }
        case .ngay(let k, let tieuDe, let gt):
            CTWChonNgayView(tieuDe: tieuDe, banDau: gt) { v in
                switch k {
                case "start": return await vm.sua(["startDate": Self.hoacNull(v)])
                case "due": return await vm.sua(["dueDate": Self.hoacNull(v)])
                default:
                    guard let f = truongTuyChinh.first(where: { "cf-\($0.id)" == k }) else { return true }
                    return await luuTuyChinh(f, v.map { .chu($0) })
                }
            }
        case .nhap(let k, let tieuDe, let gt, let ban):
            nhapView(k, tieuDe, gt, ban)
        case .coChan:
            CTWNhapGiaTriView(
                tieuDe: String(localized: "Flag as blocked"), nhan: String(localized: "Reason"),
                goiY: String(localized: "What is this issue waiting for?"),
                chuThich: String(localized: "The team sees a red flag on the board until someone removes it. Clients never see it."),
                banDau: them?.flagReason ?? "", banPhim: .nhieuDong, choTrong: false
            ) { s in await vm.goi(CTWAPI.camCo(pid: vm.pid, so: vm.so, lyDo: s)) }
        }
    }

    @ViewBuilder
    private func nhapView(_ k: String, _ tieuDe: String, _ gt: String, _ ban: CTWNhapGiaTriView.KieuBanPhim) -> some View {
        switch k {
        case "sp":
            CTWNhapGiaTriView(tieuDe: tieuDe, goiY: "0", banDau: gt, banPhim: .so, kiemTra: Self.kiemSo(toiDa: 1000)) { s in
                await vm.sua(["storyPoints": Self.hoacNull(s.isEmpty ? nil : Self.docSo(s))])
            }
        case "est":
            CTWNhapGiaTriView(tieuDe: tieuDe, goiY: "0", banDau: gt, banPhim: .so, kiemTra: Self.kiemSo(toiDa: 1666)) { s in
                await vm.sua(["originalEstimateMin": Self.hoacNull(s.isEmpty ? nil : Int(((Self.docSo(s) ?? 0) * 60).rounded()))])
            }
        case "goc", "con":
            CTWNhapGiaTriView(
                tieuDe: tieuDe, goiY: "2h 30m", chuThich: String(localized: "Use w, d, h, m — e.g. 1d 4h, 90m, 1.5h. 1d = 8h."),
                banDau: gt, banPhim: .chu,
                kiemTra: { s in
                    guard let p = CTWThoiLuong.doc(s) else { return String(localized: "Enter a duration like 2h 30m.") }
                    return p > 100_000 ? String(localized: "That's too long.") : nil
                }
            ) { s in
                let khoa = k == "goc" ? "originalEstimateMin" : "remainingEstimateMin"
                return await vm.sua([khoa: Self.hoacNull(s.isEmpty ? nil : CTWThoiLuong.doc(s))])
            }
        default:
            if let f = truongTuyChinh.first(where: { "cf-\($0.id)" == k }) {
                CTWNhapGiaTriView(
                    tieuDe: tieuDe, goiY: f.kind == "URL" ? "https://…" : "", banDau: gt, banPhim: ban,
                    kiemTra: f.kind == "NUMBER" ? Self.kiemSo(toiDa: nil)
                        : (f.kind == "URL" ? { s in s.range(of: #"^https?://\S+$"#, options: [.regularExpression, .caseInsensitive]) == nil ? String(localized: "Enter a full link starting with https://") : nil } : nil)
                ) { s in
                    if s.isEmpty { return await luuTuyChinh(f, nil) }
                    if f.kind == "NUMBER" { return await luuTuyChinh(f, .so(Self.docSo(s) ?? 0)) }
                    return await luuTuyChinh(f, .chu(String(s.prefix(1000))))
                }
            }
        }
    }

    // MARK: Dữ liệu phụ

    private func taiPhu() async {
        if !truongTuyChinh.isEmpty {
            do { giaTri = try await APIClient.shared.request(CTWAPI.giaTriTruong(pid: vm.pid, so: vm.so)); loiTruong = nil }
            catch { loiTruong = CTW.loi(error) }
        }
        if batMoDun("teams"), boPhan == nil, let ws = cfg.workspace?.id {
            boPhan = (try? await APIClient.shared.request(CTWAPI.boPhan(wsId: ws)) as [CTWTeamRef]) ?? []
        }
        if batMoDun("stages"), giaiDoan == nil {
            giaiDoan = (try? await APIClient.shared.request(CTWAPI.giaiDoan(pid: vm.pid)) as [CTWStageRef]) ?? []
        }
    }

    @discardableResult
    private func luuTuyChinh(_ f: CTWCustomField, _ v: CTWGiaTriTruong?) async -> Bool {
        let cu = giaTri
        var moi = giaTri ?? CTWGiaTriTruongThe()
        moi.tatCa[f.id] = v
        giaTri = moi                         // lạc quan: công tắc/menu đổi ngay khi bấm
        do {
            giaTri = try await APIClient.shared.request(CTWAPI.luuGiaTriTruong(pid: vm.pid, so: vm.so, truong: f.id, v))
            loiTruong = nil
            vm.lichSu = nil
            return true
        } catch {
            giaTri = cu
            loiTruong = CTW.loi(error)
            CTWRung.loi()
            return false
        }
    }

    // MARK: Số

    static func hoacNull(_ v: Any?) -> Any { v ?? NSNull() }

    static func so(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(format: "%g", d)
    }

    static func docSo(_ s: String) -> Double? {
        Double(s.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
    }

    static func kiemSo(toiDa: Double?) -> (String) -> String? {
        { s in
            guard let n = docSo(s), n.isFinite else { return String(localized: "Enter a number.") }
            if n < 0 { return String(localized: "Enter a number of 0 or more.") }
            if let toiDa, n > toiDa { return String(localized: "That's too large.") }
            return nil
        }
    }
}
