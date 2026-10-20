import SwiftUI

// MARK: - Bước 3: Kế hoạch — xem & sửa trước khi tạo (web `PlanPreview.tsx`)
//
// Sửa được: thành viên (trưởng nhóm), sprint (tên, mục tiêu), mô-đun (tên, mô tả), epic/story (tiêu đề, mô tả, điểm,
// người làm, sprint, tiêu chí), thêm epic/story, bỏ việc. Mục đã sửa tay được KHOÁ (`locked`) để "Cân lại" và
// "Nhờ CuongMini" không đè (như web). Sửa ghi thẳng vào cây JSON gốc (`CTWJSON`) ⇒ trường app không hiển thị không mất.

extension CTWJSON {
    /// Sửa dự án thứ `i` trong `projects`.
    mutating func suaDuAn(_ i: Int, _ f: (inout CTWJSON) -> Void) {
        guard var ps = self["projects"]?.mang, ps.indices.contains(i) else { return }
        f(&ps[i])
        self["projects"] = .mang(ps)
    }
}

struct KeHoachCMView: View {
    @ObservedObject var vm: BanNhapCMVM
    @State private var duAn = 0
    @State private var loiDan = ""
    @State private var sua: ViecSuaCM?
    @State private var moCanhBao = false

    var body: some View {
        let kh = vm.keHoach?.giai(CTWKeHoachCM.self)
        let ps = kh?.projects ?? []
        let p = ps[cm: min(duAn, max(0, ps.count - 1))]
        ScrollViewReader { cuon in
        Form {
            Section {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles").foregroundColor(AppColors.primary).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Plan — review before creating").font(.ctw(size: 16, weight: .semibold))
                            CTWNhanAI(chu: String(localized: "AI-generated"))
                        }
                        Text("Edit anything. What you change is locked so Rebalance and Ask CuongMini don't overwrite it.")
                            .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .listRowBackground(Color.clear)
                if ps.count > 1 {
                    Picker("Project", selection: $duAn) {
                        ForEach(Array(ps.enumerated()), id: \.offset) { i, x in Text(verbatim: "\(x.key ?? "") · \(x.name ?? "")").tag(i) }
                    }
                }
            }
            if let p {
                Section {
                    HStack(spacing: 10) {
                        CTWProjectMark(ma: p.key ?? "", co: 34, caMa: true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: p.name ?? "").font(.ctw(size: 16, weight: .semibold))
                            Text(thongKe(p)).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                canhBao(kh?.warnings ?? [], p)
                thanhVien(kh?.members?.filter { $0.projectRef == p.ref } ?? [])
                sprint(p)
                moDun(p)
                viec(p, thanhVien: kh?.members?.filter { $0.projectRef == p.ref } ?? [])
            }
        }
        .scrollDismissesKeyboard(.interactively)
        #if DEBUG
        // Chụp màn: `CT_XEM_CUON=viec` cuộn tới phần mô-đun/epic.
        .task {
            guard ProcessInfo.processInfo.environment["CT_XEM_CUON"] == "viec" else { return }
            try? await Task.sleep(nanoseconds: 600_000_000)
            cuon.scrollTo("modun", anchor: .top)
        }
        #endif
        }
        .disabled(!vm.suaDuoc)
        .safeAreaInset(edge: .bottom) { if vm.suaDuoc { thanhNut(ps.count) } }
        .sheet(item: $sua) { s in
            SuaViecCMView(vm: vm, sua: s)
        }
    }

    private func thongKe(_ p: CTWKeHoachCM.DuAn) -> String {
        let ds = p.items ?? []
        let epic = ds.filter { $0.kind == "EPIC" }.count, con = ds.filter { $0.kind == "SUBTASK" }.count
        let viec = ds.count - epic - con
        return String(localized: "\(epic) epics · \(viec) stories/tasks · \(con) subtasks · \(NhanCM.diem(p.tongDiem) ?? "0") points · \((p.sprints ?? []).count) sprints · \((p.pages ?? []).count) pages")
    }

    @ViewBuilder
    private func canhBao(_ ds: [CTWKeHoachCM.CanhBao], _ p: CTWKeHoachCM.DuAn) -> some View {
        let cua = ds.filter { $0.projectRef == nil || $0.projectRef == p.ref }
        if !cua.isEmpty {
            Section {
                ForEach(Array(cua.prefix(moCanhBao ? 60 : 3).enumerated()), id: \.offset) { _, w in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.ctw(size: 12)).foregroundColor(AppColors.warning)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NhanCM.canhBao(w.kind)).font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                            Text(verbatim: w.message ?? "").font(.ctw(size: 13)).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if cua.count > 3 {
                    Button(moCanhBao ? String(localized: "Show less") : String(localized: "Show all \(cua.count)")) { moCanhBao.toggle() }
                        .font(.ctw(size: 13))
                }
            } header: { Text("Check before creating").textCase(nil) }
        }
    }

    @ViewBuilder
    private func thanhVien(_ ds: [CTWKeHoachCM.ThanhVien]) -> some View {
        Section {
            if ds.isEmpty {
                Text("No members yet — work stays unassigned.").font(.ctw(size: 13)).foregroundColor(AppColors.textTertiary)
            }
            ForEach(ds) { m in
                HStack(spacing: 10) {
                    CTWAvatar(user: CTWUser(id: abs(m.ref.hashValue % 10_000), username: m.name ?? "", fullName: m.name, displayName: nil, avatarUrl: nil, role: nil, kind: nil), size: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(verbatim: m.name ?? "").font(.ctw(size: 14, weight: .medium))
                            if m.leader == true {
                                Text("Leader").font(.ctw(size: 10, weight: .bold)).foregroundColor(AppColors.primary)
                                    .padding(.horizontal, 5).padding(.vertical, 1).background(Capsule().fill(AppColors.primary.opacity(0.12)))
                            }
                        }
                        Text(verbatim: [m.role, NhanCM.cachGhep(m.mapping)].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " · "))
                            .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Menu {
                        Button(m.leader == true ? String(localized: "Remove leader") : String(localized: "Make leader")) {
                            vm.suaKeHoach { $0.suaTrongMang("members", ref: m.ref) { $0["leader"] = .bool(!(m.leader ?? false)) } }
                        }
                    } label: { Image(systemName: "ellipsis.circle").foregroundColor(AppColors.textTertiary).frame(width: 36, height: 36) }
                    .accessibilityLabel(Text("Options for \(m.name ?? "")"))
                }
            }
        } header: { Text("Members").textCase(nil) } footer: {
            Text("No accounts are created for anyone. People without an account are invited (if they have an email) or keep the “Planned owner” name on their work — they get it as soon as they join.")
        }
    }

    @ViewBuilder
    private func sprint(_ p: CTWKeHoachCM.DuAn) -> some View {
        if let ds = p.sprints, !ds.isEmpty {
            Section {
                ForEach(ds) { s in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            TextField("Sprint", text: chuoiSprint(s.ref, "name", s.name)).font(.ctw(size: 14, weight: .semibold))
                            Spacer()
                            Text(verbatim: [CTW.ngayNgan(s.start), CTW.ngayNgan(s.end)].compactMap { $0 }.joined(separator: " – "))
                                .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                            let n = (p.items ?? []).filter { $0.sprintRef == s.ref }.count
                            Text(n == 1 ? String(localized: "1 item") : String(localized: "\(n) items")).font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                        }
                        TextField("Sprint goal", text: chuoiSprint(s.ref, "goal", s.goal), axis: .vertical)
                            .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary).lineLimit(1...4)
                    }
                }
            } header: { Text("Sprints").textCase(nil) }
        }
    }

    private func chuoiSprint(_ ref: String, _ k: String, _ cu: String?) -> Binding<String> {
        Binding(get: { cu ?? "" }, set: { v in vm.suaKeHoach { $0.suaDuAn(duAn) { $0.suaTrongMang("sprints", ref: ref) { $0[k] = .chuoi(v) } } } })
    }

    @ViewBuilder
    private func moDun(_ p: CTWKeHoachCM.DuAn) -> some View {
        if let ds = p.components, !ds.isEmpty {
            Section {
                ForEach(Array(ds.enumerated()), id: \.offset) { i, c in
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Module", text: Binding(get: { c.name ?? "" }, set: { v in suaMoDun(i, "name", v) })).font(.ctw(size: 14, weight: .semibold))
                        TextField("Description", text: Binding(get: { c.description ?? "" }, set: { v in suaMoDun(i, "description", v) }), axis: .vertical)
                            .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary).lineLimit(1...4)
                    }
                }
            } header: { Text("Modules").textCase(nil) }
            .id("modun")
        }
    }

    private func suaMoDun(_ i: Int, _ k: String, _ v: String) {
        vm.suaKeHoach { $0.suaDuAn(duAn) { p in
            guard var a = p["components"]?.mang, a.indices.contains(i) else { return }
            a[i][k] = .chuoi(String(v.prefix(k == "name" ? 60 : 300))); p["components"] = .mang(a)
        } }
    }

    @ViewBuilder
    private func viec(_ p: CTWKeHoachCM.DuAn, thanhVien: [CTWKeHoachCM.ThanhVien]) -> some View {
        let ten = Dictionary(thanhVien.map { ($0.ref, $0.name ?? "") }, uniquingKeysWith: { a, _ in a })
        let sp = Dictionary((p.sprints ?? []).map { ($0.ref, $0.name ?? "") }, uniquingKeysWith: { a, _ in a })
        ForEach(p.epic) { e in
            Section {
                hangViec(e, ten: ten, sp: sp, epic: true)
                ForEach(p.con(e.ref)) { s in
                    hangViec(s, ten: ten, sp: sp)
                    ForEach(p.con(s.ref)) { c in hangViec(c, ten: ten, sp: sp, cap: 1) }
                }
                Button { themViec(cha: e.ref) } label: { Label("Add story", systemImage: "plus") }.font(.ctw(size: 13))
            }
        }
        let le = p.leLe
        if !le.isEmpty {
            Section {
                ForEach(le) { v in hangViec(v, ten: ten, sp: sp) }
            } header: { Text("Other work").textCase(nil) }
        }
        Section {
            Button { themViec(cha: nil) } label: { Label("Add epic", systemImage: "plus.rectangle.on.rectangle") }
        }
    }

    private func hangViec(_ v: CTWKeHoachCM.Viec, ten: [String: String], sp: [String: String], epic: Bool = false, cap: Int = 0) -> some View {
        Button { sua = ViecSuaCM(duAn: duAn, viec: v) } label: {
            HStack(alignment: .top, spacing: 8) {
                Text(verbatim: NhanCM.loaiViec(v.kind))
                    .font(.ctw(size: 10, weight: .bold)).foregroundColor(epic ? AppColors.onPrimary : AppColors.textSecondary)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(epic ? AppColors.primary : AppColors.backgroundTertiary))
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: v.title ?? "").font(.ctw(size: epic ? 15 : 14, weight: epic ? .semibold : .regular))
                        .foregroundColor(AppColors.textPrimary).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    let phu = [v.assigneeRef.flatMap { ten[$0] }, v.sprintRef.flatMap { sp[$0] } ?? (epic ? nil : String(localized: "Backlog")),
                               CTW.ngayNgan(v.due)].compactMap { $0 }
                    if !phu.isEmpty { Text(verbatim: phu.joined(separator: " · ")).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary) }
                }
                Spacer(minLength: 0)
                if v.locked == true {
                    Image(systemName: "lock.fill").font(.ctw(size: 10)).foregroundColor(AppColors.textTertiary)
                        .accessibilityLabel(Text("You edited this — kept as is when rebalancing"))
                }
                if let d = NhanCM.diem(v.points), !epic {
                    Text(verbatim: d).font(.ctw(size: 11, weight: .semibold)).monospacedDigit().foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(AppColors.backgroundTertiary))
                }
            }
            .padding(.leading, CGFloat(cap) * 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func themViec(cha: String?) {
        let ref = "u\(Int(Date().timeIntervalSince1970 * 1000) % 100_000_000)"
        let moi: CTWJSON = .doiTuong([
            "ref": .chuoi(ref), "kind": .chuoi(cha == nil ? "EPIC" : "STORY"), "parentRef": cha.map { .chuoi($0) } ?? .null,
            "title": .chuoi(cha == nil ? String(localized: "New epic") : String(localized: "New story")), "locked": .bool(true),
        ])
        vm.suaKeHoach { $0.suaDuAn(duAn) { p in p["items"] = .mang((p["items"]?.mang ?? []) + [moi]) } }
        if let v = moi.giai(CTWKeHoachCM.Viec.self) { sua = ViecSuaCM(duAn: duAn, viec: v) }
    }

    private func thanhNut(_ soDuAn: Int) -> some View {
        ThanhNutCM {
            HStack(spacing: 8) {
                TextField("Ask CuongMini to change something — e.g. “give the report to the BA”", text: $loiDan, axis: .vertical)
                    .font(.ctw(size: 14)).lineLimit(1...3)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColors.backgroundCard))
                Button { let t = loiDan; loiDan = ""; Task { await vm.nhoSua(t) } } label: { Image(systemName: "wand.and.stars") }
                    .buttonStyle(.bordered)
                    .disabled(vm.dangGui || loiDan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel(Text("Ask CuongMini"))
            }
            HStack(spacing: 8) {
                Button { vm.ep = .hieu } label: { Label("Summary", systemImage: "chevron.left") }.buttonStyle(.bordered)
                Button { Task { await vm.canLai() } } label: { Label("Rebalance", systemImage: "scalemass") }.buttonStyle(.bordered).disabled(vm.dangGui)
                Spacer(minLength: 0)
                Toggle("Send invitations", isOn: Binding(get: { vm.dauVao.team?.sendInvites ?? false }, set: { b in vm.suaDauVao { $0.team?.sendInvites = b } }))
                    .labelsHidden()
                Text("Invite").font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
            }
            .font(.ctw(size: 13, weight: .medium))
            Button { Task { await vm.tao() } } label: {
                HStack { if vm.dangGui { ProgressView().tint(AppColors.onPrimary) } else { Image(systemName: "checkmark") }
                    Text(soDuAn > 1 ? String(localized: "Create \(soDuAn) projects") : String(localized: "Create project")) }
                    .font(.ctw(size: 16, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.dangGui)
            .accessibilityIdentifier("cm.create")
        }
    }
}

struct ViecSuaCM: Identifiable { var duAn: Int; var viec: CTWKeHoachCM.Viec; var id: String { viec.ref } }

/// Sửa một epic/story/việc của kế hoạch.
struct SuaViecCMView: View {
    @ObservedObject var vm: BanNhapCMVM
    let sua: ViecSuaCM
    @Environment(\.dismiss) private var dong
    @State private var tieuDe = ""
    @State private var moTa = ""
    @State private var diem = ""
    @State private var nguoi: String?
    @State private var sprint: String?
    @State private var tieuChi = ""

    var body: some View {
        let kh = vm.keHoach?.giai(CTWKeHoachCM.self)
        let p = kh?.projects?[cm: sua.duAn]
        let tv = kh?.members?.filter { $0.projectRef == p?.ref } ?? []
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $tieuDe, axis: .vertical).lineLimit(1...4)
                    TextField("Description", text: $moTa, axis: .vertical).lineLimit(3...10)
                }
                if !sua.viec.laEpic {
                    Section {
                        HStack {
                            Text("Points")
                            TextField("—", text: $diem).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        }
                        Picker("Assignee", selection: $nguoi) {
                            Text("Unassigned").tag(String?.none)
                            ForEach(tv) { m in Text(verbatim: m.name ?? m.ref).tag(Optional(m.ref)) }
                        }
                        Picker("Sprint", selection: $sprint) {
                            Text("Backlog").tag(String?.none)
                            ForEach(p?.sprints ?? []) { s in Text(verbatim: s.name ?? s.ref).tag(Optional(s.ref)) }
                        }
                    }
                }
                Section {
                    TextField("Given … when … then …", text: $tieuChi, axis: .vertical).lineLimit(2...10)
                } header: { Text("Acceptance criteria (one per line)").textCase(nil) }
                Section {
                    Button("Remove from plan", role: .destructive) {
                        vm.suaKeHoach { $0.suaDuAn(sua.duAn) { p in
                            let bo = Set([sua.viec.ref] + (p["items"]?.mang ?? []).compactMap { $0["parentRef"]?.chuoi == sua.viec.ref ? $0["ref"]?.chuoi : nil })
                            p["items"] = .mang((p["items"]?.mang ?? []).filter { !bo.contains($0["ref"]?.chuoi ?? "") })
                        } }
                        dong()
                    }
                }
            }
            .navigationTitle(Text(NhanCM.loaiViec(sua.viec.kind)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { luu(); dong() }.disabled(tieuDe.trimmingCharacters(in: .whitespaces).isEmpty) }
            }
            .onAppear {
                tieuDe = sua.viec.title ?? ""
                moTa = sua.viec.description ?? ""
                diem = NhanCM.diem(sua.viec.points) ?? ""
                nguoi = sua.viec.assigneeRef
                sprint = sua.viec.sprintRef
                tieuChi = (sua.viec.criteria ?? []).joined(separator: "\n")
            }
        }
    }

    private func luu() {
        let d = Double(diem.replacingOccurrences(of: ",", with: "."))
        let tc = tieuChi.split(separator: "\n").map { String($0.trimmingCharacters(in: .whitespaces).prefix(400)) }.filter { !$0.isEmpty }.prefix(15)
        vm.suaKeHoach { $0.suaDuAn(sua.duAn) { p in
            p.suaTrongMang("items", ref: sua.viec.ref) { i in
                i["title"] = .chuoi(String(tieuDe.trimmingCharacters(in: .whitespacesAndNewlines).prefix(255)))
                i["description"] = .chuoi(String(moTa.prefix(8000)))
                i["criteria"] = .mang(tc.map { .chuoi($0) })
                if !sua.viec.laEpic {
                    i["points"] = d.map { .so(min(100, max(0, $0))) } ?? .null
                    i["assigneeRef"] = nguoi.map { .chuoi($0) } ?? .null
                    i["sprintRef"] = sprint.map { .chuoi($0) } ?? .null
                }
                i["locked"] = .bool(true)
            }
        } }
    }
}
