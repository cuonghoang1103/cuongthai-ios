import SwiftUI

/// Hỏi trợ lý dựa trên CHÍNH kho ghi chú của bạn. Máy chủ tìm các ghi chú liên
/// quan rồi trả lời kèm nguồn — nên câu trả lời luôn chỉ được về đâu mà kiểm.
struct TroLyGhiChuView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var cauHoi = ""
    @State private var traLoi: TraLoiTroLy?
    @State private var dangHoi = false
    @State private var loi: String?
    @FocusState private var dangGo: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(alignment: .bottom, spacing: Spacing.sm) {
                        TextField("Hỏi gì đó về ghi chú của bạn…", text: $cauHoi, axis: .vertical)
                            .font(.bodyMedium)
                            .lineLimit(1...4)
                            .focused($dangGo)
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.backgroundTertiary))
                        Button {
                            Task { await hoi() }
                        } label: {
                            if dangHoi { ProgressView() }
                            else {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(dangHoi || cauHoi.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    if let t = traLoi {
                        Text(t.answer)
                            .font(.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Spacing.md)
                            .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.backgroundSecondary))

                        if let ng = t.sources, !ng.isEmpty {
                            Text("Dựa trên \(ng.count) ghi chú")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary)
                            ForEach(ng) { n in
                                NavigationLink {
                                    GhiChuChiTietView(ghiChuId: n.noteId)
                                } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(n.title ?? "Ghi chú")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(AppColors.primary)
                                        if let tr = n.trich, !tr.isEmpty {
                                            Text(tr)
                                                .font(.system(size: 12))
                                                .foregroundColor(AppColors.textSecondary)
                                                .lineLimit(3)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(Spacing.sm)
                                    .background(RoundedRectangle(cornerRadius: 10)
                                        .stroke(AppColors.border, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else if !dangHoi {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Ví dụ")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary)
                            ForEach(["Tôi đã ghi gì về đạo hàm?",
                                     "Tóm tắt những gì tôi học tuần này",
                                     "Có ghi chú nào nhắc tới PostgreSQL không?"], id: \.self) { v in
                                Button {
                                    cauHoi = v
                                    Task { await hoi() }
                                } label: {
                                    Text(v)
                                        .font(.system(size: 13))
                                        .foregroundColor(AppColors.textPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12).padding(.vertical, 9)
                                        .background(RoundedRectangle(cornerRadius: 10)
                                            .fill(AppColors.backgroundSecondary))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, Spacing.sm)
                    }
                }
                .padding(Spacing.md)
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Trợ lý ghi chú")
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Đóng") { dismiss() } }
            }
            .alert("Trợ lý", isPresented: .constant(loi != nil)) {
                Button("OK") { loi = nil }
            } message: { Text(loi ?? "") }
        }
    }

    private func hoi() async {
        let q = cauHoi.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        dangGo = false
        dangHoi = true
        defer { dangHoi = false }
        do {
            traLoi = try await APIClient.shared.request(.hoiTroLyGhiChu(question: q))
        } catch {
            loi = error.localizedDescription
        }
    }
}
