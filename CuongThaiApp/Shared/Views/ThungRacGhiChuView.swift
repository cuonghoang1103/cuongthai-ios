import SwiftUI

/// Bộ lọc ghi chú: Tất cả · Yêu thích · Lưu trữ · Cần ôn · Thùng rác.
/// Thùng rác cho khôi phục hoặc xoá vĩnh viễn.
struct LocGhiChuView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var loc = "all"
    @State private var ds: [NoteSummary] = []
    @State private var dangTai = false
    @State private var loi: String?
    @State private var hoiXoaHan: NoteSummary?

    private let cacLoc: [(String, String, String)] = [
        ("all", "Tất cả", "tray"),
        ("favorites", "Yêu thích", "star"),
        ("archive", "Lưu trữ", "archivebox"),
        ("needs-review", "Cần ôn", "arrow.clockwise"),
        ("trash", "Thùng rác", "trash"),
    ]

    private var trongThungRac: Bool { loc == "trash" }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(cacLoc, id: \.0) { l in
                            Button {
                                loc = l.0
                                Task { await tai() }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: l.2).font(.system(size: 11))
                                    Text(l.1).font(.system(size: 13, weight: loc == l.0 ? .semibold : .regular))
                                }
                                .foregroundColor(loc == l.0 ? AppColors.onPrimary : AppColors.textSecondary)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Capsule().fill(loc == l.0 ? AppColors.primary : AppColors.backgroundTertiary))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                }

                Divider().background(AppColors.divider)

                if dangTai {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if ds.isEmpty {
                    Text(trongThungRac ? "Thùng rác trống." : "Không có ghi chú nào ở mục này.")
                        .font(.bodyMedium)
                        .foregroundColor(AppColors.textTertiary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(ds) { n in
                            if trongThungRac {
                                // Ghi chú trong thùng rác KHÔNG mở được —
                                // `getNote` lọc `deletedAt: null`. Cho bấm vào
                                // rồi báo 404 thì tệ hơn là không cho bấm.
                                HangGhiChu(n: n)
                                    .swipeActions(edge: .leading) {
                                        Button("Khôi phục") { Task { await khoiPhuc(n.id) } }
                                            .tint(AppColors.success)
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button("Xoá hẳn", role: .destructive) { hoiXoaHan = n }
                                    }
                            } else {
                                NavigationLink {
                                    GhiChuChiTietView(ghiChuId: n.id) { Task { await tai() } }
                                } label: { HangGhiChu(n: n) }
                                .buttonStyle(.plain)
                            }
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(AppColors.backgroundPrimary)
                    }
                    .listStyle(.plain)
                }
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Lọc ghi chú")
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Đóng") { dismiss() } }
            }
            .task { await tai() }
            .alert("Xoá vĩnh viễn?", isPresented: Binding(get: { hoiXoaHan != nil },
                                                          set: { if !$0 { hoiXoaHan = nil } })) {
                Button("Xoá hẳn", role: .destructive) {
                    if let n = hoiXoaHan { Task { await xoaHan(n.id) } }
                }
                Button("Huỷ", role: .cancel) { hoiXoaHan = nil }
            } message: {
                Text("Không khôi phục lại được nữa.")
            }
            .alert("Ghi chú", isPresented: .constant(loi != nil)) {
                Button("OK") { loi = nil }
            } message: { Text(loi ?? "") }
        }
    }

    private func tai() async {
        dangTai = true
        defer { dangTai = false }
        // Máy chủ trả `{filter, notes}` — bọc một lớp, không phải mảng trần.
        struct Boc: Decodable { let filter: String?; let notes: [NoteSummary] }
        do {
            let b: Boc = try await APIClient.shared.request(.locGhiChu(f: loc))
            ds = b.notes
        } catch { loi = error.localizedDescription; ds = [] }
    }

    private func khoiPhuc(_ id: Int) async {
        do {
            let _: Note = try await APIClient.shared.request(.khoiPhucGhiChu(id: id))
            Haptics.xong()
            await tai()
        } catch { loi = error.localizedDescription }
    }

    private func xoaHan(_ id: Int) async {
        hoiXoaHan = nil
        do {
            let _: EmptyResponse = try await APIClient.shared.request(.xoaVinhVien(id: id))
            await tai()
        } catch { loi = error.localizedDescription }
    }
}
