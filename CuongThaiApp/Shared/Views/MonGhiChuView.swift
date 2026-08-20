import SwiftUI

/// Trong một môn: chương và ghi chú.
///
/// Dữ liệu lấy TỪ CÂY (`/notes/tree`) chứ không gọi `/notes/subjects/:id` —
/// đường đó chỉ trả tệp đính kèm và liên kết, KHÔNG kèm chương hay ghi chú.
struct MonGhiChuView: View {
    let mon: NoteSubject
    var taiLaiCay: () async -> Void = {}

    @State private var dangTao = false
    @State private var loi: String?
    @State private var bang: [BangTomTat] = []

    private var ghiChuLe: [NoteSummary] { mon.notes ?? [] }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                if !bang.isEmpty { khoiBang }

                if ghiChuLe.isEmpty && (mon.chapters ?? []).isEmpty {
                    trong
                } else {
                    if !ghiChuLe.isEmpty {
                        khoi(tieuDe: nil, ds: ghiChuLe)
                    }
                    ForEach(mon.chapters ?? []) { ch in
                        khoi(tieuDe: ch.title, ds: ch.notes ?? [], chuongId: ch.id)
                    }
                }
            }
            .padding(.vertical, Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("\(mon.emoji ?? "📓") \(mon.name)")
        .navigationBarTitleDisplayModeInline()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await taoGhiChu(chuongId: nil) }
                } label: {
                    if dangTao { ProgressView() } else { Image(systemName: "square.and.pencil") }
                }
                .disabled(dangTao)
            }
        }
        .task {
            // Trang cơ sở dữ liệu KHÔNG nằm trong cây ghi chú — `getTree` lọc
            // `isDatabasePage: false`. Phải hỏi riêng, không thì chúng vô hình.
            bang = (try? await APIClient.shared.request(.layBangTheoMon(subjectId: mon.id))) ?? []
        }
        .alert("Ghi chú", isPresented: .constant(loi != nil)) {
            Button("OK") { loi = nil }
        } message: { Text(loi ?? "") }
    }

    private func khoi(tieuDe: String?, ds: [NoteSummary], chuongId: Int? = nil) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let tieuDe {
                HStack {
                    Text(tieuDe)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Button {
                        Task { await taoGhiChu(chuongId: chuongId) }
                    } label: {
                        Image(systemName: "plus").font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(AppColors.primary)
                }
                .padding(.horizontal, Spacing.md)
            }

            if ds.isEmpty {
                Text("Chưa có ghi chú nào")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.horizontal, Spacing.md)
            } else {
                ForEach(ds) { n in
                    NavigationLink {
                        GhiChuChiTietView(ghiChuId: n.id) { Task { await taiLaiCay() } }
                    } label: {
                        HangGhiChu(n: n)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var khoiBang: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Cơ sở dữ liệu")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, Spacing.md)

            ForEach(bang) { b in
                NavigationLink {
                    BangDuLieuView(bangId: b.id)
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Text(b.icon ?? "🗂").font(.system(size: 16)).frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(b.ten)
                                .font(.system(size: 15))
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(1)
                            Text("\(b.soDong) dòng · \(b.properties?.count ?? 0) cột")
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.textTertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var trong: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "doc.text")
                .font(.system(size: 38))
                .foregroundColor(AppColors.textTertiary)
            Text("Môn này chưa có ghi chú nào")
                .font(.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
            Button("Tạo ghi chú đầu tiên") { Task { await taoGhiChu(chuongId: nil) } }
                .font(.buttonSmall)
                .foregroundColor(AppColors.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func taoGhiChu(chuongId: Int?) async {
        dangTao = true
        defer { dangTao = false }
        do {
            let _: Note = try await APIClient.shared
                .request(.createNote(subjectId: mon.id, chapterId: chuongId, title: nil))
            Haptics.xong()
            await taiLaiCay()
        } catch { loi = error.localizedDescription }
    }
}

struct HangGhiChu: View {
    let n: NoteSummary

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 14))
                .foregroundColor(AppColors.primary.opacity(0.75))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(n.title.isEmpty ? "Untitled" : n.title)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                Text(TimeFormatter.formatTimeAgo(n.updatedAt))
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }
}
