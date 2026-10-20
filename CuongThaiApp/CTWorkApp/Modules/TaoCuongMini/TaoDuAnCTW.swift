import SwiftUI

// MARK: - Tạo dự án (web `workspace/CreateProjectDialog.tsx`): loại ⇒ mẫu ⇒ tên + mã (+ dữ liệu mẫu)
//
// `POST /workspaces/:wsId/projects` {name, key, type, template, kind, visibility, description?} — mô-đun mặc định do máy chủ
// đặt theo loại. Dữ liệu mẫu: `POST /projects/:pid/sample-data` (lỗi thì dự án vẫn đã tạo). Lối sang "Tạo cùng CuongMini"
// mang tên/mã/mẫu đã gõ sang bản nháp. Quyền: chỉ vai OWNER/ADMIN/MEMBER thấy lối vào; máy chủ kiểm lại.

struct TaoDuAnCTW: View {
    let ws: CTWWorkspace
    let xong: (CTWDuAnMoi) -> Void
    let sangCuongMini: (CTWDauVaoCM) -> Void
    @Environment(\.dismiss) private var dong
    @State private var loai: LoaiDuAnCTW = .SCHOOL
    @State private var mau: MauDuAnCTW = .SWP391
    @State private var ten = ""
    @State private var ma = ""
    @State private var maTuDong = true
    @State private var bang = "SCRUM"
    @State private var quyen = "WORKSPACE"
    @State private var moTa = ""
    @State private var duLieuMau = false
    @State private var dangTao = false
    @State private var loi: String?

    private var maHopLe: Bool { MaDuAnCTW.hopLe(ma) }
    private var taoDuoc: Bool { !ten.trimmingCharacters(in: .whitespaces).isEmpty && maHopLe && !dangTao }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Project type", selection: Binding(get: { loai }, set: { l in loai = l; mau = l.mauGoiY; bang = "SCRUM" })) {
                        ForEach(LoaiDuAnCTW.allCases) { l in Label(l.ten, systemImage: l.bieuTuong).tag(l) }
                    }
                    .pickerStyle(.navigationLink)
                    Picker("Template", selection: $mau) {
                        ForEach(MauDuAnCTW.allCases) { m in
                            VStack(alignment: .leading, spacing: 2) {
                                Label(m.ten, systemImage: m.bieuTuong)
                                Text(m.moTa).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                            }
                            .tag(m)
                        }
                    }
                    .pickerStyle(.navigationLink)
                } footer: {
                    Text(loai.moTa + " " + String(localized: "You can change modules later in Project settings."))
                }

                Section {
                    TextField("Project name", text: Binding(get: { ten }, set: { v in
                        ten = String(v.prefix(120))
                        if maTuDong { ma = MaDuAnCTW.tuTen(v) }
                    }))
                    .accessibilityIdentifier("newProject.name")
                    HStack {
                        Text("Project key")
                        TextField("SWP", text: Binding(get: { ma }, set: { v in
                            ma = String(v.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.prefix(10))
                            maTuDong = ma.isEmpty
                        }))
                        .multilineTextAlignment(.trailing).font(.ctw(size: 16, design: .monospaced))
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .accessibilityIdentifier("newProject.key")
                    }
                } footer: {
                    if !ma.isEmpty && !maHopLe {
                        Text("The key is 2–10 letters or digits and starts with a letter.").foregroundColor(AppColors.error)
                    } else {
                        Text(ma.isEmpty ? String(localized: "Filled in from the name.") : String(localized: "Issue keys will look like \(ma)-12."))
                    }
                }

                Section {
                    Picker("Board", selection: $bang) {
                        Text(verbatim: "Scrum").tag("SCRUM")
                        Text(verbatim: "Kanban").tag("KANBAN")
                    }
                    .pickerStyle(.segmented)
                    Picker("Access", selection: $quyen) {
                        Text("Everyone in the workspace").tag("WORKSPACE")
                        Text("Only invited members").tag("PRIVATE")
                    }
                    TextField("Description (optional)", text: $moTa, axis: .vertical).lineLimit(1...5)
                    Toggle("Add sample data to explore", isOn: $duLieuMau)
                } footer: {
                    Text(bang == "KANBAN" ? String(localized: "Continuous flow on a board, no sprints.") : String(localized: "Plan in sprints from a backlog."))
                }

                Section {
                    Button {
                        var dv = CTWDauVaoCM()
                        dv.overview?.name = ten.trimmingCharacters(in: .whitespaces)
                        dv.overview?.key = maHopLe ? ma : ""
                        dv.overview?.template = mau.rawValue
                        dv.overview?.type = bang
                        dv.overview?.kind = loai.rawValue
                        sangCuongMini(dv)
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "sparkles").foregroundColor(AppColors.primary).frame(width: 24)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Create with CuongMini").font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                                Text("Upload the brief, code, member list and deadline — CuongMini builds the epics, issues, sprints, assignments and docs for you. You review it before anything is created.")
                                    .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .accessibilityIdentifier("newProject.cuongmini")
                }
            }
            .navigationTitle(Text("New project"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    if dangTao { ProgressView() } else {
                        Button("Create") { Task { await tao() } }.disabled(!taoDuoc).accessibilityIdentifier("newProject.create")
                    }
                }
            }
            .onChange(of: mau) { _, m in
                // Đổi sang/khỏi CAPSTONE ⇒ loại theo mẫu (như web).
                if m == .CAPSTONE { loai = .SCHOOL }
            }
            .alert(loi ?? "", isPresented: Binding(get: { loi != nil }, set: { if !$0 { loi = nil } })) { Button("OK", role: .cancel) {} }
        }
    }

    private func tao() async {
        dangTao = true
        defer { dangTao = false }
        do {
            let p: CTWDuAnMoi = try await APIClient.shared.request(CTWAPI.taoDuAn(
                ws: ws.id, ten: ten.trimmingCharacters(in: .whitespaces), ma: ma, loaiBang: bang, mau: mau.rawValue,
                loai: loai.rawValue, quyen: quyen, moTa: moTa.trimmingCharacters(in: .whitespacesAndNewlines)))
            if duLieuMau {
                // Lỗi dữ liệu mẫu không chặn: dự án đã có.
                try? await APIClient.shared.send(CTWAPI.themDuLieuMau(pid: p.id))
            }
            CTWRung.thanhCong()
            xong(p)
        } catch {
            CTWRung.loi()
            loi = CTW.loi(error)
        }
    }
}

// MARK: - Lối vào (nút "+" của bảng chọn dự án)

/// Tấm phủ tạo mới — MỘT `.sheet(item:)` (CLAUDE.md C5).
enum TaoMoiCTW: Identifiable {
    case duAn(CTWWorkspace)
    case cuongMini(CTWWorkspace, CTWDauVaoCM?)
    var id: String {
        switch self {
        case .duAn(let w): return "p-\(w.id)"
        case .cuongMini(let w, _): return "cm-\(w.id)"
        }
    }
    /// Vai được tạo dự án trong không gian (`workspace.createProject` = OWNER/ADMIN/MEMBER).
    static func duocTao(_ ws: CTWWorkspace) -> Bool { ["OWNER", "ADMIN", "MEMBER"].contains(ws.role ?? "") }
}

/// Menu "+": New project · Create with CuongMini (theo từng không gian được phép).
struct MenuTaoMoiCTW: View {
    let dsKhongGian: [CTWWorkspace]
    let chon: (TaoMoiCTW) -> Void

    var body: some View {
        let ds = dsKhongGian.filter(TaoMoiCTW.duocTao)
        if !ds.isEmpty {
            Menu {
                if ds.count == 1, let w = ds.first {
                    muc(w)
                } else {
                    ForEach(ds) { w in Section(w.name) { muc(w) } }
                }
            } label: { Image(systemName: "plus") }
            .accessibilityLabel(Text("Create"))
            .accessibilityIdentifier("projects.create")
        }
    }

    @ViewBuilder
    private func muc(_ w: CTWWorkspace) -> some View {
        Button { chon(.duAn(w)) } label: { Label("New project", systemImage: "folder.badge.plus") }
        Button { chon(.cuongMini(w, nil)) } label: { Label("Create with CuongMini", systemImage: "sparkles") }
    }
}
