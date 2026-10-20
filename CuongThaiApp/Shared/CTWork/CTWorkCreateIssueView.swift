import SwiftUI

// MARK: - CT Work — Tạo thẻ (đủ như web `CreateIssueDialog.tsx`, 20/10/2026)
//
// Loại · thẻ cha (epic / thẻ cha của sub-task) · tiêu đề (cảnh báo có thể TRÙNG — `/similar`, so chuỗi pg_trgm,
// không dùng AI) · mô tả markdown (tự điền MẪU theo loại thẻ khi chưa sửa — `/issue-templates`) · ưu tiên ·
// người làm · nhãn · sprint · story point / ước lượng giờ · hạn · "Create another" (giữ hộp mở, giữ loại/sprint/cha).
// Tạo từ bảng Scrum đang có sprint ⇒ mặc định vào sprint đó (thẻ không "biến mất" vào backlog).
// Khách cổng (CLIENT): không giao việc, không xếp sprint, không ước lượng — máy chủ cũng chặn.
// "Draft with AI" của web KHÔNG làm ở đây: đi qua AI bên thứ ba ⇒ cần màn đồng ý 5.1.2(i) của mảng AI.

struct CTWCreateIssueView: View {
    struct TheCha: Hashable {
        var id: Int
        var number: Int
        var title: String
    }

    let cauHinh: CTWProjectConfig
    let sprintId: Int?
    /// Có sẵn thẻ cha (bấm "Details…" ở Sub-tasks) ⇒ loại mặc định là sub-task.
    var cha: TheCha?
    let xong: (Int) -> Void

    @Environment(\.dismiss) private var dong
    @State private var loaiId: Int?
    @State private var tieuDe = ""
    @State private var moTa = ""
    @State private var uuTien = 3
    @State private var nguoiId: Int?
    @State private var coHan = false
    @State private var han = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var nhan: Set<Int> = []
    @State private var sprint: Int?
    @State private var theCha: TheCha?
    @State private var diem = ""
    @State private var taoTiep = false
    @State private var dangGui = false
    @State private var loi: String?
    @State private var vuaTao: String?
    @State private var daNap = false
    @State private var them: CTWCauHinhThem?
    @State private var mau: [CTWMauMoTa] = []
    /// Mẫu đang nằm trong ô mô tả (chưa sửa) — đổi loại thì đổi mẫu; người dùng gõ vào là thôi.
    @State private var mauDangDung: (loai: Int, chu: String)?
    @State private var tuongTu: [CTWTheTuongTu] = []
    @State private var chonCha = false
    @FocusState private var oTieuDe: Bool

    private var laKhach: Bool { cauHinh.role == "CLIENT" }
    private var loai: CTWIssueType? { loaiId.flatMap(cauHinh.loai) }
    private var cap: Int { loai?.level ?? 0 }
    private var loaiCha: [Int] { cauHinh.dsLoai.filter { ($0.level ?? 0) == cap + 1 }.map(\.id) }
    private var canCha: Bool { cap == -1 && theCha == nil }
    private var coTheTao: Bool {
        loaiId != nil && !tieuDe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !canCha && !dangGui
    }

    var body: some View {
        NavigationStack {
            Form {
                if let loi {
                    Section { CTWErrorBanner(text: loi) { self.loi = nil } }
                }
                if let vuaTao {
                    Section {
                        Label(vuaTao, systemImage: "checkmark.circle.fill").foregroundColor(AppColors.success)
                    }
                }
                Section {
                    Picker("Type", selection: $loaiId) {
                        ForEach(cauHinh.dsLoai) { t in
                            Label(t.name, systemImage: CTW.bieuTuongLoai(t)).tag(Optional(t.id))
                        }
                    }
                    if cap != 1 && !loaiCha.isEmpty {
                        Button { chonCha = true } label: {
                            HStack {
                                Text(cap == -1 ? "Parent" : "Epic").foregroundColor(AppColors.textPrimary)
                                Spacer()
                                Text(verbatim: theCha.map { "\(cauHinh.key)-\($0.number) \($0.title)" }
                                     ?? (cap == -1 ? String(localized: "Required") : String(localized: "None")))
                                    .foregroundColor(canCha ? AppColors.error : AppColors.textSecondary)
                                    .lineLimit(1)
                                Image(systemName: "chevron.right").font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                            }
                        }
                    }
                    TextField(cap == 1 ? "Epic name" : (loai?.key == "BUG" ? "What's wrong?" : "Summary"), text: $tieuDe, axis: .vertical)
                        .lineLimit(1...4)
                        .focused($oTieuDe)
                        .accessibilityIdentifier("ctw.tao.tieuDe")
                } footer: {
                    if !tuongTu.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Possible duplicates", systemImage: "exclamationmark.triangle.fill")
                                .font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.warning)
                            ForEach(tuongTu) { s in
                                Text(verbatim: "\(cauHinh.key)-\(s.number) · \(s.title)\(s.resolved == true ? " ✓" : "")")
                                    .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                Section {
                    TextField("Description (optional)", text: $moTa, axis: .vertical)
                        .lineLimit(3...12)
                        .onChange(of: moTa) { _, moi in
                            if let m = mauDangDung, CTWMoTaThe.chuan(moi) != CTWMoTaThe.chuan(m.chu) { mauDangDung = nil }
                        }
                } header: {
                    Text("Description")
                } footer: {
                    if let m = mauDangDung, let ten = mau.first(where: { $0.typeId == m.loai })?.name {
                        HStack {
                            Text("Template: \(ten)")
                            Spacer()
                            Button("Clear") { moTa = ""; mauDangDung = nil; mauDaXoa = m.loai }
                        }
                    } else {
                        Text("Markdown works: **bold**, - list, - [ ] checklist.")
                    }
                }
                Section {
                    Picker("Priority", selection: $uuTien) {
                        ForEach(CTW.doUuTien, id: \.so) { p in
                            Label(p.ten, systemImage: p.bieuTuong).tag(p.so)
                        }
                    }
                    if !laKhach {
                        Picker("Assignee", selection: $nguoiId) {
                            Text("Unassigned").tag(Int?.none)
                            ForEach(cauHinh.nguoiGiaoDuoc) { u in
                                Text(verbatim: u.laAgent ? String(localized: "\(u.ten) · AI agent") : u.ten).tag(Optional(u.id))
                            }
                        }
                    }
                    if !(cauHinh.labels ?? []).isEmpty {
                        NavigationLink {
                            List(cauHinh.labels ?? []) { l in
                                Button {
                                    if nhan.contains(l.id) { nhan.remove(l.id) } else { nhan.insert(l.id) }
                                } label: {
                                    HStack {
                                        Circle().fill(CTW.mau(l.color, macDinh: AppColors.textSecondary)).frame(width: 9, height: 9)
                                        Text(verbatim: l.name).foregroundColor(AppColors.textPrimary)
                                        Spacer()
                                        if nhan.contains(l.id) { Image(systemName: "checkmark").foregroundColor(AppColors.primary) }
                                    }
                                }
                            }
                            .navigationTitle("Labels")
                        } label: {
                            HStack {
                                Text("Labels")
                                Spacer()
                                Text(nhan.isEmpty ? "None" : "\(nhan.count) selected").foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                    if !laKhach && cap == 0 && cauHinh.type != "KANBAN" {
                        Picker("Sprint", selection: $sprint) {
                            Text("Backlog").tag(Int?.none)
                            ForEach((cauHinh.sprints ?? []).filter { $0.state != "CLOSED" }) { s in
                                Text(verbatim: s.state == "ACTIVE" ? String(localized: "\(s.name) · Active") : s.name).tag(Optional(s.id))
                            }
                        }
                    }
                    if !laKhach && cap != 1 {
                        HStack {
                            Text(them?.theoGio == true ? "Estimate (hours)" : "Story points")
                            Spacer()
                            TextField("0", text: $diem)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 90)
                        }
                    }
                    Toggle("Due date", isOn: $coHan.animation())
                    if coHan {
                        DatePicker("Due", selection: $han, displayedComponents: .date)
                    }
                } footer: {
                    if nguoiId.flatMap(cauHinh.thanhVien)?.laAgent == true {
                        Text("This assignee is an AI agent operated by its owner. It will be able to read this issue.")
                    }
                }
                Section {
                    Toggle("Create another", isOn: $taoTiep)
                } footer: {
                    Text("Keeps this form open with the same type, sprint and parent.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Create issue")
            .ctwTieuDeNho()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dong() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if dangGui {
                        ProgressView()
                    } else {
                        Button("Create") { Task { await tao() } }
                            .fontWeight(.semibold)
                            .disabled(!coTheTao)
                    }
                }
            }
            .sheet(isPresented: $chonCha) {
                CTWChonTheView(tieuDe: cap == -1 ? String(localized: "Choose a parent") : String(localized: "Choose an epic"),
                               pid: cauHinh.id, cfg: cauHinh, loai: loaiCha,
                               choBoChon: cap != -1 && theCha != nil, nhanBoChon: String(localized: "No epic")) { c in
                    theCha = c.map { TheCha(id: $0.id, number: $0.number, title: $0.title) }
                    return true
                }
            }
            .onAppear {
                guard !daNap else { return }
                daNap = true
                theCha = cha
                sprint = sprintId
                loaiId = loaiMacDinh?.id
                #if DEBUG
                // Chụp màn (`the:taothe`): điền sẵn tiêu đề, không bật bàn phím (máy ảo mới hiện gợi ý "slide to type").
                if ProcessInfo.processInfo.environment["CT_XEM_MAN"]?.lowercased() == "the:taothe" {
                    tieuDe = "Notification badge stays after reading"
                    return
                }
                #endif
                oTieuDe = true
            }
            .task { await taiPhu() }
            .task(id: tieuDe) { await timTrung() }
            .onChange(of: loaiId) { _, _ in
                // Như web: đổi loại ⇒ bỏ thẻ cha đã chọn (cấp cha đổi theo loại); sub-task giữ cha điền sẵn.
                theCha = cap == -1 ? cha : nil
                apMau()
            }
        }
        .frame(minWidth: 360, minHeight: 360)
    }

    @State private var mauDaXoa: Int?

    /// Như web: có thẻ cha ⇒ sub-task; khách ⇒ Bug/Task; người khác ⇒ Story/Task.
    private var loaiMacDinh: CTWIssueType? {
        let ds = cauHinh.dsLoai
        if cha != nil, let s = ds.first(where: { $0.level == -1 }) { return s }
        let uuTienMa = laKhach ? ["BUG", "TASK"] : ["STORY", "TASK"]
        for k in uuTienMa { if let t = ds.first(where: { $0.key == k }) { return t } }
        return ds.first { ($0.level ?? 0) == 0 } ?? ds.first
    }

    private func taiPhu() async {
        if them == nil, let d = try? await APIClient.shared.requestRaw(.workDuAn(pid: cauHinh.id)) {
            them = try? CTWAPI.giaiMa(CTWCauHinhThem.self, d)
        }
        if mau.isEmpty {
            mau = (try? await APIClient.shared.request(CTWAPI.mauMoTa(pid: cauHinh.id)) as [CTWMauMoTa]) ?? []
            apMau()
        }
    }

    /// Điền mẫu mô tả của loại đang chọn khi ô mô tả trống hoặc vẫn là mẫu cũ chưa sửa.
    private func apMau() {
        guard let loaiId, mauDaXoa != loaiId else { return }
        let dangLaMau = mauDangDung != nil || moTa.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard dangLaMau else { return }
        if let m = mau.first(where: { $0.typeId == loaiId }), let doc = m.doc, !CTWMoTaThe.trong(doc) {
            let chu = CTWMoTaThe.markdown(doc)
            moTa = chu
            mauDangDung = (loaiId, chu)
        } else if mauDangDung != nil {
            moTa = ""
            mauDangDung = nil
        }
    }

    private func timTrung() async {
        let t = tieuDe.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 8 else { tuongTu = []; return }
        try? await Task.sleep(nanoseconds: 350_000_000)
        guard !Task.isCancelled else { return }
        tuongTu = (try? await APIClient.shared.request(CTWAPI.theTuongTu(pid: cauHinh.id, tieuDe: t)) as [CTWTheTuongTu]) ?? []
    }

    private func tao() async {
        guard let loaiId, !canCha else { return }
        let td = tieuDe.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !td.isEmpty else { return }
        var than: [String: Any] = ["typeId": loaiId, "title": String(td.prefix(255)), "priority": uuTien]
        let mt = moTa.trimmingCharacters(in: .whitespacesAndNewlines)
        if !mt.isEmpty { than["descriptionJson"] = CTWMoTaThe.doc(mt).any }
        if let c = theCha, cap != 1 { than["parentId"] = c.id }
        if !laKhach {
            if let nguoiId { than["assigneeId"] = nguoiId }
            if cap == 0, let sprint { than["sprintId"] = sprint }
            if cap != 1, let n = Double(diem.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)), n >= 0 {
                if them?.theoGio == true { than["originalEstimateMin"] = Int((n * 60).rounded()) } else { than["storyPoints"] = min(n, 1000) }
            }
        }
        if coHan { than["dueDate"] = CTW.chuoiNgay(han) }
        if !nhan.isEmpty { than["labelIds"] = Array(nhan).sorted() }
        dangGui = true
        defer { dangGui = false }
        do {
            let t: CTWIssueDetail = try await APIClient.shared.request(CTWAPI.taoThe(pid: cauHinh.id, than))
            CTWRung.thanhCong()
            xong(t.number)
            if taoTiep {
                let noi = t.sprintId.flatMap { id in (cauHinh.sprints ?? []).first { $0.id == id }?.name }
                vuaTao = noi.map { String(localized: "Created \(cauHinh.key)-\(t.number) in \($0)") }
                    ?? String(localized: "Created \(cauHinh.key)-\(t.number)")
                tieuDe = ""
                diem = ""
                moTa = ""
                mauDangDung = nil
                tuongTu = []
                loi = nil
                apMau()
                oTieuDe = true
            } else {
                dong()
            }
        } catch {
            loi = CTW.loi(error)
            CTWRung.loi()
        }
    }
}
