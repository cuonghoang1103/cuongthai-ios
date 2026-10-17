import SwiftUI

// MARK: - CT Work — Tạo thẻ nhanh
//
// Trường cốt lõi: loại, tiêu đề, mô tả, độ ưu tiên, người nhận, hạn, nhãn.
// Tạo từ bảng Scrum đang có sprint thì gắn luôn vào sprint đó — không thì thẻ
// rơi vào backlog và biến khỏi bảng ngay khi vừa tạo, trông như tạo hỏng.

struct CTWCreateIssueView: View {
    let cauHinh: CTWProjectConfig
    let sprintId: Int?
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
    @State private var vaoSprint = true
    @State private var dangGui = false
    @State private var loi: String?
    @FocusState private var oTieuDe: Bool

    /// Sub-task cần thẻ cha, epic nằm ở tầng trên — form này tạo tầng 0 (và epic nếu có).
    private var dsLoai: [CTWIssueType] {
        let t = cauHinh.dsLoai.filter { ($0.level ?? 0) >= 0 }
        return t.isEmpty ? cauHinh.dsLoai : t
    }

    var body: some View {
        NavigationStack {
            Form {
                if let loi {
                    Section { CTWErrorBanner(text: loi) }
                }
                Section {
                    Picker("Type", selection: $loaiId) {
                        ForEach(dsLoai) { t in
                            Label(t.name, systemImage: CTW.bieuTuongLoai(t)).tag(Optional(t.id))
                        }
                    }
                    TextField("Summary", text: $tieuDe, axis: .vertical)
                        .lineLimit(1...4)
                        .focused($oTieuDe)
                    TextField("Description (optional)", text: $moTa, axis: .vertical)
                        .lineLimit(3...10)
                }
                Section {
                    Picker("Priority", selection: $uuTien) {
                        ForEach(CTW.doUuTien, id: \.so) { p in
                            Label(p.ten, systemImage: p.bieuTuong).tag(p.so)
                        }
                    }
                    Picker("Assignee", selection: $nguoiId) {
                        Text("Unassigned").tag(Int?.none)
                        ForEach(cauHinh.nguoiGiaoDuoc) { u in
                            Text(u.laAgent ? "\(u.ten) · AI agent" : u.ten).tag(Optional(u.id))
                        }
                    }
                    Toggle("Due date", isOn: $coHan.animation())
                    if coHan {
                        DatePicker("Due", selection: $han, displayedComponents: .date)
                    }
                    if !(cauHinh.labels ?? []).isEmpty {
                        NavigationLink {
                            List(cauHinh.labels ?? []) { l in
                                Button {
                                    if nhan.contains(l.id) { nhan.remove(l.id) } else { nhan.insert(l.id) }
                                } label: {
                                    HStack {
                                        Circle().fill(CTW.mau(l.color, macDinh: AppColors.textSecondary)).frame(width: 9, height: 9)
                                        Text(l.name).foregroundColor(AppColors.textPrimary)
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
                    if sprintId != nil {
                        Toggle("Add to current sprint", isOn: $vaoSprint)
                    }
                } footer: {
                    if nguoiId.flatMap(cauHinh.thanhVien)?.laAgent == true {
                        Text("This assignee is an AI agent operated by its owner. It will be able to read this issue.")
                    }
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
                            .disabled(loaiId == nil || tieuDe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .onAppear {
                if loaiId == nil {
                    loaiId = (dsLoai.first { $0.key == "TASK" } ?? dsLoai.first { ($0.level ?? 0) == 0 } ?? dsLoai.first)?.id
                }
                oTieuDe = true
            }
        }
        .frame(minWidth: 360, minHeight: 360)
    }

    private func tao() async {
        guard let loaiId else { return }
        let td = tieuDe.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !td.isEmpty else { return }
        var than: [String: Any] = ["typeId": loaiId, "title": String(td.prefix(255)), "priority": uuTien]
        let mt = moTa.trimmingCharacters(in: .whitespacesAndNewlines)
        if !mt.isEmpty { than["descriptionJson"] = CTWNode.docTuChu(mt) }
        if let nguoiId { than["assigneeId"] = nguoiId }
        if let sprintId, vaoSprint { than["sprintId"] = sprintId }
        if coHan { than["dueDate"] = CTW.chuoiNgay(han) }
        if !nhan.isEmpty { than["labelIds"] = Array(nhan) }
        dangGui = true
        defer { dangGui = false }
        do {
            let t: CTWIssueDetail = try await APIClient.shared.request(.workTaoThe(pid: cauHinh.id, than: than))
            xong(t.number)
            dong()
        } catch {
            loi = CTW.loi(error)
        }
    }
}
