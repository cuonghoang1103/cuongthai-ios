import SwiftUI
import UniformTypeIdentifiers

// MARK: - "Create with CuongMini" — màn MỘT bản nháp: Điền ⇒ CuongMini tóm tắt ⇒ Kế hoạch ⇒ Xong
// (web `components/work/setup/SetupWizard.tsx` + FillForm/UnderstandingView/PlanPreview/ProgressView/ResultView).
// Bản điện thoại: chỉ những ô đáng gõ trên máy (đề bài, tệp/link, thành viên, hạn, cách chia việc). Phần còn lại
// (rubric, mã nguồn, dữ liệu mẫu, luật phân công chi tiết…) để mặc định của máy chủ; bản nháp mở trên web vẫn đủ.

struct BanNhapCuongMiniCTW: View {
    let ws: CTWWorkspace
    let xong: (CTWKetQuaCM.DuAn) -> Void
    @StateObject private var vm: BanNhapCMVM

    init(id: Int, ws: CTWWorkspace, xong: @escaping (CTWKetQuaCM.DuAn) -> Void) {
        self.ws = ws
        self.xong = xong
        _vm = StateObject(wrappedValue: BanNhapCMVM(id: id, ws: ws.id))
    }

    var body: some View {
        Group {
            if vm.nhap == nil {
                if let l = vm.loiTai { CTWOLoi(loi: l) { Task { await vm.tai() } } } else { CTWKhungTai(soHang: 5, coAvatar: false) }
            } else {
                switch vm.cheDo {
                case .tienDo: TienDoCMView(vm: vm)
                case .xong: KetQuaCMView(vm: vm, xong: xong)
                case .dien: DienCMView(vm: vm)
                case .hieu: HieuCMView(vm: vm)
                case .keHoach: KeHoachCMView(vm: vm)
                }
            }
        }
        .background(AppColors.backgroundPrimary)
        .safeAreaInset(edge: .top, spacing: 0) { if vm.nhap != nil { thanhBuoc } }
        .navigationTitle(Text(vm.nhap?.title.flatMap { $0.isEmpty ? nil : $0 } ?? String(localized: "Create with CuongMini")))
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.tai() }
        .onDisappear { vm.dung() }
        .alert(vm.loi ?? "", isPresented: Binding(get: { vm.loi != nil }, set: { if !$0 { vm.loi = nil } })) { Button("OK", role: .cancel) {} }
    }

    /// Bước 1–4 + trạng thái lưu (như dải bước của web).
    private var thanhBuoc: some View {
        let ten = [String(localized: "Fill in"), String(localized: "Summary"), String(localized: "Plan"), String(localized: "Created")]
        return VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { i in
                    HStack(spacing: 4) {
                        if i < vm.buoc { Image(systemName: "checkmark").font(.ctw(size: 10, weight: .bold)) }
                        else { Text(verbatim: "\(i + 1)").font(.ctw(size: 11, weight: .bold)).monospacedDigit() }
                        Text(ten[i]).font(.ctw(size: 12, weight: .medium)).lineLimit(1)
                    }
                    .foregroundColor(i == vm.buoc ? AppColors.primary : (i < vm.buoc ? AppColors.textSecondary : AppColors.textTertiary))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(i == vm.buoc ? AppColors.primary.opacity(0.12) : Color.clear))
                    if i < 3 { Rectangle().fill(AppColors.border).frame(height: 1).frame(maxWidth: 14) }
                }
                Spacer(minLength: 0)
                Group {
                    switch vm.luu {
                    case .dangLuu: Text("Saving…")
                    case .daLuu: Text("Saved")
                    case .loi: Text("Not saved")
                    case .yen: EmptyView()
                    }
                }
                .font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
            }
            .padding(.horizontal, Spacing.md).padding(.vertical, 8)
            .accessibilityElement(children: .combine)
            if let d = vm.nhap, let e = d.error, !d.dangChay, d.status != "APPLIED" {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(AppColors.warning)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: e).font(.ctw(size: 13)).foregroundColor(AppColors.textPrimary).fixedSize(horizontal: false, vertical: true)
                        if d.failedPhase != nil {
                            Button { Task { await vm.thuLai() } } label: { Label("Try again", systemImage: "arrow.counterclockwise") }
                                .font(.ctw(size: 13, weight: .semibold)).buttonStyle(.bordered).disabled(vm.dangGui)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColors.warning.opacity(0.10)))
                .padding(.horizontal, Spacing.md).padding(.bottom, 8)
            }
            Divider()
        }
        .background(.bar)
    }
}

/// Thanh nút dính đáy chung cho các bước.
struct ThanhNutCM<C: View>: View {
    @ViewBuilder let noiDung: () -> C
    var body: some View {
        VStack(spacing: 8) { noiDung() }
            .padding(.horizontal, Spacing.md).padding(.top, 10).padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .background(.bar)
            .overlay(alignment: .top) { Divider() }
    }
}

// MARK: - Bước 1: Điền

struct DienCMView: View {
    @ObservedObject var vm: BanNhapCMVM
    @State private var link = ""
    @State private var danDanhSach = ""
    @State private var moDan = false
    @State private var chonTep = false
    @State private var dangThem = false
    @State private var thongBao: String?

    private var dv: CTWDauVaoCM { vm.dauVao }
    private func chuoi(_ k: WritableKeyPath<CTWDauVaoCM, String?>) -> Binding<String> {
        Binding(get: { vm.dauVao[keyPath: k] ?? "" }, set: { v in vm.suaDauVao { $0[keyPath: k] = v } })
    }
    private func ngay(_ k: WritableKeyPath<CTWDauVaoCM, String?>, macDinh: Int) -> Binding<Date> {
        Binding(get: { CTW.ngayDate(vm.dauVao[keyPath: k]) ?? Calendar.current.date(byAdding: .day, value: macDinh, to: Date())! },
                set: { d in vm.suaDauVao { $0[keyPath: k] = CTW.chuoiNgay(d) } })
    }
    private func coNgay(_ k: WritableKeyPath<CTWDauVaoCM, String?>, macDinh: Int) -> Binding<Bool> {
        Binding(get: { !(vm.dauVao[keyPath: k] ?? "").isEmpty },
                set: { b in vm.suaDauVao { $0[keyPath: k] = b ? CTW.chuoiNgay(Calendar.current.date(byAdding: .day, value: macDinh, to: Date())!) : "" } })
    }

    var body: some View {
        Form {
            Section {
                TextField(vm.nhap?.laKhongGian == true ? "Plan name (e.g. the class or programme)" : "Project name", text: Binding(
                    get: { dv.overview?.name ?? "" },
                    set: { v in
                        vm.suaDauVao {
                            let maCu = $0.overview?.key ?? ""
                            let tuDong = maCu.isEmpty || maCu == MaDuAnCTW.tuTen($0.overview?.name ?? "")
                            $0.overview?.name = v
                            if tuDong { $0.overview?.key = MaDuAnCTW.tuTen(v) }
                        }
                    }))
                    .accessibilityIdentifier("cm.name")
                if vm.nhap?.laKhongGian != true {
                    HStack {
                        Text("Key").foregroundColor(AppColors.textSecondary)
                        TextField("NTS", text: Binding(get: { dv.overview?.key ?? "" }, set: { v in
                            vm.suaDauVao { $0.overview?.key = String(v.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(10)) }
                        }))
                        .multilineTextAlignment(.trailing).textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .font(.ctw(size: 15, design: .monospaced))
                    }
                }
                Picker("Template", selection: Binding(get: { dv.overview?.template ?? "SWP391" }, set: { v in
                    vm.suaDauVao {
                        $0.overview?.template = v
                        if let m = MauDuAnCTW(rawValue: v) { $0.overview?.kind = m.loai.rawValue }
                    }
                })) {
                    ForEach(MauDuAnCTW.allCases) { m in Text(m.ten).tag(m.rawValue) }
                }
                Picker("Language of the content", selection: chuoi(\.overview!.language)) {
                    Text(verbatim: "Tiếng Việt").tag("vi")
                    Text(verbatim: "English").tag("en")
                    Text("Both (Vietnamese + English)").tag("both")
                }
                TextField("Goal in one paragraph", text: chuoi(\.overview!.goal), axis: .vertical).lineLimit(2...6)
            } header: { Text("Overview").textCase(nil) } footer: {
                Text("The name, course and language decide the board, the issue keys and the language CuongMini writes in.")
            }

            Section {
                TextField("Paste the brief, user stories, meeting notes…", text: chuoi(\.brief!.text), axis: .vertical)
                    .lineLimit(4...14)
                    .accessibilityIdentifier("cm.brief")
                ForEach(vm.nhap?.sources ?? []) { s in hangNguon(s) }
                HStack {
                    TextField("Paste a link (Google Docs, Drive, GitHub…)", text: $link)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .onSubmit { themLink() }
                    Button("Add link") { themLink() }.disabled(link.trimmingCharacters(in: .whitespaces).count < 4 || dangThem)
                }
                Button { chonTep = true } label: { Label("Attach a file", systemImage: "paperclip") }
                    .disabled(dangThem || vm.dangGui)
            } header: { Text("Brief & requirements").textCase(nil) } footer: {
                Text("PDF, DOCX, XLSX, PPTX, ZIP, images or text — up to 25 MB each. Shared links must be viewable by anyone with the link.")
            }

            Section {
                ForEach(Array((dv.team?.members ?? []).enumerated()), id: \.element.id) { i, m in hangNguoi(i, m) }
                    .onDelete { idx in vm.suaDauVao { $0.team?.members?.remove(atOffsets: idx) } }
                Button { vm.suaDauVao { let cu = $0.team?.members ?? []; $0.team?.members = cu + [CTWThanhVienCM()] } } label: {
                    Label("Add a person", systemImage: "person.badge.plus")
                }
                Button { moDan = true } label: { Label("Paste from Excel", systemImage: "tablecells") }
                Toggle("Send email invitations", isOn: Binding(get: { dv.team?.sendInvites ?? false }, set: { b in vm.suaDauVao { $0.team?.sendInvites = b } }))
            } header: {
                Text((dv.team?.members ?? []).isEmpty ? String(localized: "Members") : String(localized: "Members (\((dv.team?.members ?? []).count))")).textCase(nil)
            } footer: {
                Text("Names, level and hours help CuongMini share the work fairly and pair beginners with stronger members. Only rows with an email get an invitation; people without a CT Work account keep their work under “Planned owner”.")
            }

            Section {
                Toggle("Start date", isOn: coNgay(\.timeline!.startDate, macDinh: 0))
                if !(dv.timeline?.startDate ?? "").isEmpty {
                    DatePicker("Start date", selection: ngay(\.timeline!.startDate, macDinh: 0), displayedComponents: .date).labelsHidden()
                }
                Toggle("Final deadline", isOn: coNgay(\.timeline!.endDate, macDinh: 70))
                if !(dv.timeline?.endDate ?? "").isEmpty {
                    DatePicker("Final deadline", selection: ngay(\.timeline!.endDate, macDinh: 70), displayedComponents: .date).labelsHidden()
                }
                Picker("Sprint length", selection: Binding(get: { dv.timeline?.sprintWeeks ?? 2 }, set: { n in vm.suaDauVao { $0.timeline?.sprintWeeks = n } })) {
                    ForEach(1...4, id: \.self) { n in Text(n == 1 ? String(localized: "1 week") : String(localized: "\(n) weeks")).tag(n) }
                }
            } header: { Text("Schedule").textCase(nil) } footer: {
                Text("CuongMini plans backwards from the deadline: sprints, due dates and milestones that fit.")
            }

            if vm.nhap?.laKhongGian == true {
                Section {
                    ForEach(Array((dv.groups ?? []).enumerated()), id: \.element.id) { i, _ in
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Group name", text: Binding(get: { vm.dauVao.groups?[cm: i]?.name ?? "" }, set: { v in vm.suaDauVao { $0.groups?[i].name = v } }))
                            TextField("Leader (name or student ID)", text: Binding(get: { vm.dauVao.groups?[cm: i]?.leader ?? "" }, set: { v in vm.suaDauVao { $0.groups?[i].leader = v } }))
                                .font(.ctw(size: 14))
                            TextField("Own topic / product (optional)", text: Binding(get: { vm.dauVao.groups?[cm: i]?.topic ?? "" }, set: { v in vm.suaDauVao { $0.groups?[i].topic = v } }), axis: .vertical)
                                .font(.ctw(size: 14)).lineLimit(1...4)
                        }
                    }
                    .onDelete { idx in vm.suaDauVao { $0.groups?.remove(atOffsets: idx) } }
                    Button { vm.suaDauVao { let cu = $0.groups ?? []; $0.groups = cu + [CTWNhomCM()] } } label: { Label("Add group", systemImage: "plus") }
                } header: { Text("Groups / projects").textCase(nil) } footer: {
                    Text("Each group becomes its own project with a leader. Leave the topic empty to use the shared brief. Or use the “Group” column in the member list.")
                }
            }

            Section {
                TextField("How to split the work, what to stress, what to skip…", text: chuoi(\.split!.prompt), axis: .vertical).lineLimit(2...8)
                Picker("Level of detail", selection: Binding(get: { dv.split?.detail ?? "SUBTASKS" }, set: { v in vm.suaDauVao { $0.split?.detail = v } })) {
                    Text("Epics + a few stories").tag("EPICS")
                    Text("Epics + stories").tag("STORIES")
                    Text("Epics + stories + subtasks").tag("SUBTASKS")
                }
            } header: { Text("How to split the work").textCase(nil) } footer: {
                Text("Tell CuongMini how you want the work split — it follows your words before its own habits.")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .disabled(!vm.suaDuoc)
        .safeAreaInset(edge: .bottom) {
            if vm.suaDuoc {
                ThanhNutCM {
                    if vm.hieu != nil {
                        Button(vm.nhap?.status == "READY" ? "Go to the plan" : "Go to the summary") { vm.ep = vm.nhap?.status == "READY" ? nil : .hieu }
                            .font(.ctw(size: 14, weight: .medium))
                    }
                    Button { Task { await vm.doc() } } label: {
                        HStack { if vm.dangGui { ProgressView().tint(AppColors.onPrimary) } else { Image(systemName: "wand.and.stars") }
                            Text(vm.hieu == nil ? "Read & summarize" : "Read again") }
                            .font(.ctw(size: 16, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.dangGui || !vm.docDuoc)
                    .accessibilityIdentifier("cm.read")
                    if !vm.docDuoc {
                        Text("Add a name, a goal, a brief or a file first").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                    }
                }
            }
        }
        .fileImporter(isPresented: $chonTep, allowedContentTypes: [.pdf, .plainText, .commaSeparatedText, .zip, .image, .item]) { kq in
            if case .success(let u) = kq { Task { await vm.themTep(u) } }
        }
        .sheet(isPresented: $moDan) { danExcel }
        .alert(thongBao ?? "", isPresented: Binding(get: { thongBao != nil }, set: { if !$0 { thongBao = nil } })) { Button("OK", role: .cancel) {} }
    }

    private func themLink() {
        let u = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard u.count >= 4 else { return }
        dangThem = true
        Task {
            if await vm.themLink(u) { link = "" }
            dangThem = false
        }
    }

    private func hangNguon(_ s: CTWNguonCM) -> some View {
        HStack(spacing: 10) {
            Image(systemName: s.kind == "FILE" ? "doc" : (s.kind == "REPO" ? "chevron.left.forwardslash.chevron.right" : "link"))
                .foregroundColor(AppColors.textSecondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: s.name ?? s.url ?? "").font(.ctw(size: 14)).lineLimit(1)
                Text(nhanNguon(s)).font(.ctw(size: 11.5))
                    .foregroundColor(s.status == "OK" ? AppColors.success : (s.status == "EMPTY" ? AppColors.textTertiary : AppColors.warning))
            }
            Spacer(minLength: 0)
            Button(role: .destructive) { Task { await vm.xoaNguon(s) } } label: { Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textTertiary) }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Remove \(s.name ?? "")"))
        }
    }

    private func nhanNguon(_ s: CTWNguonCM) -> String {
        let tt: String
        switch s.status {
        case "OK": tt = String(localized: "read")
        case "EMPTY": tt = String(localized: "no text")
        case "PRIVATE": tt = String(localized: "not shared publicly")
        default: tt = String(localized: "error")
        }
        if let c = s.chars, c > 0, s.status == "OK" { return String(localized: "\(tt) · \(max(1, c / 1000))k characters") }
        return tt
    }

    private func hangNguoi(_ i: Int, _ m: CTWThanhVienCM) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Full name", text: Binding(get: { vm.dauVao.team?.members?[cm: i]?.name ?? "" }, set: { v in vm.suaDauVao { $0.team?.members?[i].name = v } }))
                .font(.ctw(size: 15, weight: .medium))
            HStack(spacing: 8) {
                TextField("Email", text: Binding(get: { vm.dauVao.team?.members?[cm: i]?.email ?? "" }, set: { v in vm.suaDauVao { $0.team?.members?[i].email = v } }))
                    .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Role", text: Binding(get: { vm.dauVao.team?.members?[cm: i]?.role ?? "" }, set: { v in vm.suaDauVao { $0.team?.members?[i].role = v } }))
                    .frame(maxWidth: 110)
            }
            .font(.ctw(size: 13))
            Picker("Level", selection: Binding(get: { vm.dauVao.team?.members?[cm: i]?.level ?? 3 }, set: { n in vm.suaDauVao { $0.team?.members?[i].level = n } })) {
                Text("1 · beginner").tag(1); Text("2 · basic").tag(2); Text("3 · average").tag(3); Text("4 · good").tag(4); Text("5 · very strong").tag(5)
            }
            .font(.ctw(size: 13))
            if vm.nhap?.laKhongGian == true {
                TextField("Group", text: Binding(get: { vm.dauVao.team?.members?[cm: i]?.group ?? "" }, set: { v in vm.suaDauVao { $0.team?.members?[i].group = v } }))
                    .font(.ctw(size: 13))
            }
        }
        .padding(.vertical, 2)
    }

    private var danExcel: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $danDanhSach).frame(minHeight: 200).font(.ctw(size: 13, design: .monospaced))
                } footer: {
                    Text("Copy the cells from Excel/Sheets with the header row: Full name · Student ID · Email · Role · Level · Hours/week. Vietnamese or English headers both work.")
                }
            }
            .navigationTitle(Text("Paste from Excel"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { moDan = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Read list") {
                        let t = danDanhSach
                        Task {
                            let n = await vm.docDanhSach(t)
                            if n > 0 { danDanhSach = ""; moDan = false; thongBao = n == 1 ? String(localized: "Added 1 person") : String(localized: "Added \(n) people") }
                        }
                    }
                    .disabled(danDanhSach.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

extension Array {
    subscript(cm i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

// MARK: - Tiến độ job (đọc / lập kế hoạch / tạo)

struct TienDoCMView: View {
    @ObservedObject var vm: BanNhapCMVM

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(tieuDe).font(.ctw(size: 17, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                }
                Text("You can leave this screen — the work keeps running and you can come back to it.")
                    .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 10) {
                    let ds = vm.nhap?.progress ?? []
                    if ds.isEmpty {
                        Label("Starting…", systemImage: "circle.dashed").font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
                    }
                    ForEach(ds, id: \.key) { b in
                        HStack(alignment: .top, spacing: 10) {
                            Group {
                                switch b.status {
                                case "done": Image(systemName: "checkmark.circle.fill").foregroundColor(AppColors.success)
                                case "error": Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.error)
                                case "skipped": Image(systemName: "minus.circle").foregroundColor(AppColors.textTertiary)
                                case "pending": Image(systemName: "circle").foregroundColor(AppColors.textTertiary)
                                default: ProgressView().controlSize(.mini)
                                }
                            }
                            .frame(width: 18, height: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(NhanCM.buoc(b.key)).font(.ctw(size: 14))
                                    .foregroundColor(b.status == "done" ? AppColors.textSecondary : AppColors.textPrimary)
                                if let d = b.detail, !d.isEmpty {
                                    Text(verbatim: d).font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .ctwThe(14)
                HStack {
                    let n = vm.nhap?.usage?.calls ?? 0
                    Text(vm.nhap?.status == "APPLYING" ? String(localized: "If anything fails, nothing is left half-created.")
                         : (n == 1 ? String(localized: "1 AI call so far") : String(localized: "\(n) AI calls so far")))
                        .font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                    Spacer()
                    Button(role: .destructive) { Task { await vm.huy() } } label: { Label("Cancel", systemImage: "stop.fill") }
                        .buttonStyle(.bordered).font(.ctw(size: 13, weight: .semibold))
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }

    private var tieuDe: String {
        switch vm.nhap?.status {
        case "READING": return String(localized: "CuongMini is reading everything…")
        case "APPLYING": return String(localized: "Creating in CT Work…")
        default: return String(localized: "CuongMini is planning…")
        }
    }
}

// MARK: - Bước 2: "Đây là điều CuongMini hiểu"

struct HieuCMView: View {
    @ObservedObject var vm: BanNhapCMVM
    @State private var docLai: String?

    var body: some View {
        let h = vm.hieu?.giai(CTWHieuCM.self)
        Form {
            Section {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles").foregroundColor(AppColors.primary).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Here's what CuongMini understood").font(.ctw(size: 16, weight: .semibold))
                            CTWNhanAI(chu: String(localized: "AI-generated"))
                        }
                        Text("Fix anything wrong and answer the open questions — CuongMini plans from this summary, not from the original files.")
                            .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .listRowBackground(Color.clear)
            }
            let cauHoi = h?.questions ?? []
            if !cauHoi.isEmpty {
                Section {
                    ForEach(Array(cauHoi.enumerated()), id: \.offset) { i, q in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(verbatim: q.q ?? "").font(.ctw(size: 14, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                            TextField("Your answer (leave empty and CuongMini will assume)", text: Binding(
                                get: { vm.hieu?["questions"]?.mang?[cm: i]?["answer"]?.chuoi ?? "" },
                                set: { v in vm.suaHieu { j in
                                    guard var a = j["questions"]?.mang, a.indices.contains(i) else { return }
                                    a[i]["answer"] = .chuoi(v); j["questions"] = .mang(a)
                                } }), axis: .vertical)
                                .font(.ctw(size: 14)).lineLimit(1...5)
                        }
                    }
                } header: {
                    let mo = cauHoi.filter { ($0.answer ?? "").isEmpty }.count
                    Text(mo > 0 ? String(localized: "Open questions (\(mo))") : String(localized: "Questions")).textCase(nil)
                }
            }
            Section {
                TextField("Goal", text: Binding(get: { vm.hieu?["goal"]?.chuoi ?? "" }, set: { v in vm.suaHieu { $0["goal"] = .chuoi(v) } }), axis: .vertical)
                    .lineLimit(2...8)
            } header: { Text("Goal").textCase(nil) }
            ds(String(localized: "In scope"), h?.scopeIn)
            ds(String(localized: "Out of scope"), h?.scopeOut)
            if let sp = h?.deliverables, !sp.isEmpty {
                Section {
                    ForEach(Array(sp.enumerated()), id: \.offset) { _, d in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(verbatim: d.name ?? "").font(.ctw(size: 14, weight: .medium))
                                Spacer()
                                if let due = d.due, !due.isEmpty { Text(verbatim: CTW.ngayNgan(due) ?? due).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary) }
                            }
                            if let c = d.criteria, !c.isEmpty { Text(verbatim: c).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary) }
                        }
                    }
                } header: { Text("Deliverables & grading").textCase(nil) }
            }
            if let tm = h?.team, !tm.isEmpty {
                Section {
                    ForEach(Array(tm.enumerated()), id: \.offset) { _, n in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(verbatim: n.name ?? "").font(.ctw(size: 14, weight: .medium))
                                Spacer()
                                Text(verbatim: n.proposedRole ?? "").font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.primary)
                            }
                            if let w = n.why, !w.isEmpty { Text(verbatim: w).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary) }
                        }
                    }
                } header: { Text("Team & proposed roles").textCase(nil) }
            }
            ds(String(localized: "Schedule, milestones & sprints"), h?.timeline)
            ds(String(localized: "How the work is split"), h?.strategy)
            ds(String(localized: "Tech stack"), h?.tech?.stack)
            ds(String(localized: "Assumptions"), h?.assumptions)
            ds(String(localized: "Risks"), h?.risks)
            Section {
                TextField("Extra instructions — these win over everything above", text: Binding(get: { vm.hieu?["notes"]?.chuoi ?? "" }, set: { v in vm.suaHieu { $0["notes"] = .chuoi(v) } }), axis: .vertical)
                    .lineLimit(2...8)
            } header: { Text("Anything else CuongMini should know").textCase(nil) }
        }
        .scrollDismissesKeyboard(.interactively)
        .disabled(!vm.suaDuoc)
        .safeAreaInset(edge: .bottom) {
            if vm.suaDuoc {
                ThanhNutCM {
                    Toggle("Review the plan before creating", isOn: Binding(get: { vm.dauVao.reviewFirst ?? true }, set: { b in vm.suaDauVao { $0.reviewFirst = b } }))
                        .font(.ctw(size: 14))
                    HStack(spacing: 8) {
                        Button { vm.ep = .dien } label: { Label("Edit inputs", systemImage: "chevron.left") }
                            .buttonStyle(.bordered)
                        Button { docLai = "" } label: { Label("Read again", systemImage: "arrow.clockwise") }
                            .buttonStyle(.bordered)
                        Spacer(minLength: 0)
                    }
                    .font(.ctw(size: 13, weight: .medium))
                    Button { Task { await vm.chapNhan() } } label: {
                        HStack { if vm.dangGui { ProgressView().tint(AppColors.onPrimary) } else { Image(systemName: "checkmark") }
                            Text((vm.dauVao.reviewFirst ?? true) ? "Accept & plan" : "Accept & create") }
                            .font(.ctw(size: 16, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.dangGui)
                    .accessibilityIdentifier("cm.accept")
                }
            }
        }
        .alert("Read again", isPresented: Binding(get: { docLai != nil }, set: { if !$0 { docLai = nil } })) {
            TextField("What should CuongMini look at again? (optional)", text: Binding(get: { docLai ?? "" }, set: { docLai = $0 }))
            Button("Cancel", role: .cancel) { docLai = nil }
            Button("Read again") { let t = docLai; docLai = nil; Task { await vm.doc(docLai: t) } }
        }
    }

    @ViewBuilder
    private func ds(_ tieuDe: String, _ dong: [String]?) -> some View {
        if let dong, !dong.isEmpty {
            Section {
                ForEach(Array(dong.enumerated()), id: \.offset) { _, t in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(verbatim: "•").foregroundColor(AppColors.textTertiary)
                        Text(verbatim: t).font(.ctw(size: 14)).fixedSize(horizontal: false, vertical: true)
                    }
                }
            } header: { Text(tieuDe).textCase(nil) }
        }
    }
}

// MARK: - Xong: dự án đã tạo

struct KetQuaCMView: View {
    @ObservedObject var vm: BanNhapCMVM
    let xong: (CTWKetQuaCM.DuAn) -> Void

    var body: some View {
        let r = vm.nhap?.result
        let ds = r?.projects ?? []
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").font(.ctw(size: 26)).foregroundColor(AppColors.success)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ds.count > 1 ? String(localized: "\(ds.count) projects are ready") : String(localized: "Your project is ready"))
                            .font(.ctw(size: 20, weight: .bold)).foregroundColor(AppColors.textPrimary)
                        Text("Everything is editable — board, backlog, Docs, risks and meetings. Each person got their brief on an onboarding issue.")
                            .font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                ForEach(ds) { p in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            CTWProjectMark(ma: p.key, co: 30, caMa: true)
                            Text(verbatim: p.name).font(.ctw(size: 16, weight: .semibold)).lineLimit(2)
                            Spacer(minLength: 0)
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                            o(p.issues, String(localized: "issues")); o(p.sprints, String(localized: "sprints")); o(p.pages, String(localized: "pages"))
                            o(p.tests, String(localized: "tests")); o(p.risks, String(localized: "risks")); o(p.meetings, String(localized: "meetings"))
                        }
                        let phu = [(p.files ?? 0) > 0 ? String(localized: "\(p.files ?? 0) files attached") : nil,
                                   (p.invited ?? 0) > 0 ? String(localized: "\(p.invited ?? 0) invited") : nil,
                                   (p.planned ?? 0) > 0 ? String(localized: "\(p.planned ?? 0) planned people waiting to join") : nil].compactMap { $0 }
                        if !phu.isEmpty { Text(verbatim: phu.joined(separator: " · ")).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary) }
                        Button { xong(p) } label: {
                            Label("Open project", systemImage: "arrow.up.forward.app").font(.ctw(size: 15, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 40)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("cm.open.\(p.key)")
                    }
                    .padding(14)
                    .ctwThe(14)
                }
                if let m = r?.invites, (m.sent ?? 0) > 0 || (m.added ?? 0) > 0 {
                    Label(String(localized: "Invitations: \(m.sent ?? 0) sent, \(m.added ?? 0) added directly"), systemImage: "envelope")
                        .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }

    private func o(_ n: Int?, _ nhan: String) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: "\(n ?? 0)").font(.ctw(size: 18, weight: .semibold)).monospacedDigit().foregroundColor(AppColors.textPrimary)
            Text(nhan).font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(AppColors.backgroundTertiary))
    }
}
