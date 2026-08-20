import SwiftUI

/// Lịch sử phiên bản của một ghi chú: xem lại bản cũ và khôi phục.
struct PhienBanGhiChuView: View {
    let ghiChuId: Int
    var khoiPhucXong: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var ds: [PhienBanGhiChu] = []
    @State private var dangTai = true
    @State private var xemBan: NoiDungPhienBan?
    @State private var hoiKhoiPhuc: PhienBanGhiChu?
    @State private var loi: String?
    @State private var dangLam = false

    var body: some View {
        NavigationStack {
            Group {
                if dangTai {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if ds.isEmpty {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 38))
                            .foregroundColor(AppColors.textTertiary)
                        Text("Ghi chú này chưa có bản lưu nào")
                            .font(.bodyMedium)
                            .foregroundColor(AppColors.textSecondary)
                        Text("Bấm \"Lưu mốc\" để tạo một điểm quay về.")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(ds) { p in
                            Button {
                                Task { await xem(p.version) }
                            } label: {
                                hang(p)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button("Khôi phục") { hoiKhoiPhuc = p }
                                    .tint(AppColors.primary)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Lịch sử")
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Đóng") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await luuMoc() }
                    } label: {
                        if dangLam { ProgressView() } else { Text("Lưu mốc") }
                    }
                    .disabled(dangLam)
                }
            }
            .task { await tai() }
            .sheet(item: Binding(get: { xemBan.map { BocNoiDung(noi: $0) } },
                                 set: { _ in xemBan = nil })) { boc in
                NavigationStack {
                    ScrollView {
                        RichContent(html: boc.noi.contentHtml ?? "<p>(trống)</p>")
                            .padding(Spacing.md)
                    }
                    .background(AppColors.backgroundPrimary)
                    .navigationTitle("Bản \(boc.noi.version ?? 0)")
                    .navigationBarTitleDisplayModeInline()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Đóng") { xemBan = nil }
                        }
                    }
                }
            }
            .alert("Khôi phục bản này?", isPresented: Binding(get: { hoiKhoiPhuc != nil },
                                                             set: { if !$0 { hoiKhoiPhuc = nil } })) {
                Button("Khôi phục") {
                    if let p = hoiKhoiPhuc { Task { await khoiPhuc(p.version) } }
                }
                Button("Huỷ", role: .cancel) { hoiKhoiPhuc = nil }
            } message: {
                Text("Nội dung hiện tại được lưu thành một bản mới trước khi ghi đè, nên vẫn quay lại được.")
            }
            .alert("Lịch sử", isPresented: .constant(loi != nil)) {
                Button("OK") { loi = nil }
            } message: { Text(loi ?? "") }
        }
    }

    private struct BocNoiDung: Identifiable {
        let noi: NoiDungPhienBan
        var id: Int { noi.version ?? 0 }
    }

    private func hang(_ p: PhienBanGhiChu) -> some View {
        HStack(spacing: Spacing.sm) {
            Text("v\(p.version)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.primary)
                .frame(width: 38, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(p.title?.isEmpty == false ? p.title! : "Untitled")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(p.nhanNguon)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(AppColors.backgroundTertiary))
                    Text(TimeFormatter.formatTimeAgo(p.createdAt))
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textTertiary)
                    if let u = p.user { Text("· \(u.name)")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textTertiary) }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func tai() async {
        dangTai = true
        defer { dangTai = false }
        do { ds = try await APIClient.shared.request(.layPhienBan(noteId: ghiChuId)) }
        catch { loi = error.localizedDescription }
    }

    private func xem(_ v: Int) async {
        do { xemBan = try await APIClient.shared.request(.layMotPhienBan(noteId: ghiChuId, version: v)) }
        catch { loi = error.localizedDescription }
    }

    private func luuMoc() async {
        dangLam = true
        defer { dangLam = false }
        do {
            let _: NoiDungPhienBan = try await APIClient.shared.request(.luuMocPhienBan(noteId: ghiChuId))
            Haptics.xong()
            await tai()
        } catch { loi = error.localizedDescription }
    }

    private func khoiPhuc(_ v: Int) async {
        hoiKhoiPhuc = nil
        do {
            let _: NoiDungPhienBan = try await APIClient.shared
                .request(.khoiPhucPhienBan(noteId: ghiChuId, version: v))
            Haptics.xong()
            khoiPhucXong()
            dismiss()
        } catch { loi = error.localizedDescription }
    }
}
