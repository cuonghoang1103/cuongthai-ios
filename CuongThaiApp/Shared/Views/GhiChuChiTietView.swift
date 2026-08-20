import SwiftUI

/// Đọc một ghi chú. Nội dung vẽ bằng `RichContentView` (WKWebView + bộ CSS đã
/// chép từ web) nên bảng, khối mã, tiêu đề… hiện y như trên web.
struct GhiChuChiTietView: View {
    let ghiChuId: Int
    /// Gọi lại khi có thay đổi, để danh sách phía ngoài tải lại.
    var doiRoi: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var ghiChu: Note?
    @State private var dangTai = true
    @State private var loi: String?
    @State private var hienSoan = false
    @State private var hoiXoa = false
    @State private var hienLichSu = false
    @State private var hienTroLy = false
    @State private var hienTuVung = false

    var body: some View {
        Group {
            if dangTai {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let g = ghiChu {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text(g.title)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                            .padding(.horizontal, Spacing.md)

                        dongTrangThai(g)

                        if let html = g.contentHtml, !html.isEmpty {
                            RichContent(html: html)
                                .padding(.horizontal, Spacing.md)
                        } else {
                            Text("Ghi chú này chưa có nội dung.")
                                .font(.bodyMedium)
                                .foregroundColor(AppColors.textTertiary)
                                .padding(.horizontal, Spacing.md)
                        }
                    }
                    .padding(.vertical, Spacing.md)
                }
            } else {
                ErrorStateView(message: loi ?? "Không mở được ghi chú") {
                    Task { await tai() }
                }
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Ghi chú")
        .navigationBarTitleDisplayModeInline()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { hienSoan = true } label: { Label("Sửa", systemImage: "pencil") }
                    if let g = ghiChu {
                        Button { Task { await doCo("isPinned", !g.isPinned) } } label: {
                            Label(g.isPinned ? "Bỏ ghim" : "Ghim", systemImage: g.isPinned ? "pin.slash" : "pin")
                        }
                        Button { Task { await doCo("isFavorite", !g.isFavorite) } } label: {
                            Label(g.isFavorite ? "Bỏ yêu thích" : "Yêu thích",
                                  systemImage: g.isFavorite ? "star.slash" : "star")
                        }
                        Button { Task { await doCo("isArchived", !g.isArchived) } } label: {
                            Label(g.isArchived ? "Bỏ lưu trữ" : "Lưu trữ", systemImage: "archivebox")
                        }
                    }
                    Button { hienTuVung = true } label: {
                        Label("Từ vựng & thẻ ghi nhớ", systemImage: "character.book.closed")
                    }
                    Button { Task { await nhanBan() } } label: {
                        Label("Nhân bản", systemImage: "doc.on.doc")
                    }
                    Button { hienLichSu = true } label: {
                        Label("Lịch sử phiên bản", systemImage: "clock.arrow.circlepath")
                    }
                    Button { hienTroLy = true } label: {
                        Label("Hỏi trợ lý", systemImage: "sparkles")
                    }
                    Divider()
                    Button(role: .destructive) { hoiXoa = true } label: {
                        Label("Xoá", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task { await tai() }
        .sheet(isPresented: $hienSoan) {
            if let g = ghiChu {
                SoanGhiChuView(ghiChu: g) { moi in
                    ghiChu = moi
                    doiRoi()
                }
            }
        }
        .sheet(isPresented: $hienLichSu) {
            PhienBanGhiChuView(ghiChuId: ghiChuId) {
                Task { await tai() }
                doiRoi()
            }
        }
        .sheet(isPresented: $hienTroLy) { TroLyGhiChuView() }
        .sheet(isPresented: $hienTuVung) {
            TuVungView(ghiChuId: ghiChuId, tenGhiChu: ghiChu?.title ?? "Ghi chú")
        }
        .alert("Xoá ghi chú?", isPresented: $hoiXoa) {
            Button("Xoá", role: .destructive) { Task { await xoa() } }
            Button("Huỷ", role: .cancel) { }
        } message: {
            Text("Ghi chú vào thùng rác, khôi phục được trên web.")
        }
        .alert("Ghi chú", isPresented: .constant(loi != nil && ghiChu != nil)) {
            Button("OK") { loi = nil }
        } message: { Text(loi ?? "") }
    }

    private func dongTrangThai(_ g: Note) -> some View {
        HStack(spacing: 10) {
            if g.isPinned { nhan("pin.fill", "Đã ghim", .orange) }
            if g.isFavorite { nhan("star.fill", "Yêu thích", .yellow) }
            if g.isArchived { nhan("archivebox.fill", "Lưu trữ", .purple) }
            Spacer()
            Text("Sửa \(TimeFormatter.gioCuThe(g.updatedAt))")
                .font(.system(size: 11))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.horizontal, Spacing.md)
    }

    private func nhan(_ icon: String, _ chu: String, _ mau: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9))
            Text(chu).font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(mau)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Capsule().fill(mau.opacity(0.14)))
    }

    // MARK: Việc

    private func tai() async {
        dangTai = true
        defer { dangTai = false }
        do { ghiChu = try await APIClient.shared.request(.layGhiChu(id: ghiChuId)) }
        catch { loi = error.localizedDescription }
    }

    private func doCo(_ ten: String, _ giaTri: Bool) async {
        do {
            let moi: Note = try await APIClient.shared.request(.updateNote(id: ghiChuId, [ten: giaTri]))
            ghiChu = moi
            Haptics.cham()
            doiRoi()
        } catch { loi = error.localizedDescription }
    }

    private func nhanBan() async {
        do {
            let _: Note = try await APIClient.shared.request(.nhanBanGhiChu(id: ghiChuId))
            Haptics.xong()
            loi = "Đã tạo một bản sao."
            doiRoi()
        } catch { loi = error.localizedDescription }
    }

    private func xoa() async {
        do {
            let _: EmptyResponse = try await APIClient.shared.request(.deleteNote(id: ghiChuId))
            doiRoi()
            dismiss()
        } catch { loi = error.localizedDescription }
    }
}
