import SwiftUI

// MARK: - CT Work — Tạo thẻ
//
// Chỉ các trường cốt lõi: loại, tiêu đề, độ ưu tiên, người nhận. Tạo từ bảng
// Scrum đang có sprint thì gắn luôn vào sprint đó — không thì thẻ rơi vào
// backlog và biến khỏi bảng ngay khi vừa tạo, trông như tạo hỏng.

struct CTWCreateIssueView: View {
    let cauHinh: CTWProjectConfig
    let sprintId: Int?
    let xong: (Int) -> Void

    @Environment(\.dismiss) private var dong
    @State private var loaiId: Int?
    @State private var tieuDe = ""
    @State private var uuTien = 3
    @State private var nguoiId: Int?
    @State private var dangGui = false
    @State private var loi: String?

    /// Sub-task cần thẻ cha, epic nằm ở tầng trên — form này chỉ tạo tầng 0.
    private var dsLoai: [CTWIssueType] {
        let t = cauHinh.dsLoai.filter { ($0.level ?? 0) == 0 }
        return t.isEmpty ? cauHinh.dsLoai.filter { ($0.level ?? 0) >= 0 } : t
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
                            Text(u.ten).tag(Optional(u.id))
                        }
                    }
                } footer: {
                    Text(sprintId != nil ? "The issue will be added to the current sprint." : "")
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
                    loaiId = (dsLoai.first { $0.key == "TASK" } ?? dsLoai.first)?.id
                }
            }
        }
        .frame(minWidth: 360, minHeight: 360)
    }

    private func tao() async {
        guard let loaiId else { return }
        let td = tieuDe.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !td.isEmpty else { return }
        var than: [String: Any] = ["typeId": loaiId, "title": String(td.prefix(255)), "priority": uuTien]
        if let nguoiId { than["assigneeId"] = nguoiId }
        if let sprintId { than["sprintId"] = sprintId }
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
