import SwiftUI

/// Danh sách cuộc trò chuyện với AI.
///
/// Trước bản này app KHÔNG có màn nào như vậy: đóng khung chat là mất sạch,
/// dù backend đã lưu đủ từ lâu (`ChatSession` + `ChatMessage`).
struct LichSuChatView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = LichSuChatViewModel()
    /// Gọi khi người dùng chọn một cuộc — khung chat nạp lại nội dung cuộc đó.
    let moCuoc: (PhienChat) -> Void

    @State private var doiTen: PhienChat?
    @State private var tenMoi = ""
    @State private var themThuMuc = false
    @State private var tenThuMuc = ""

    var body: some View {
        NavigationStack {
            Group {
                if vm.dangTai && vm.phien.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.phien.isEmpty {
                    trong
                } else {
                    danhSach
                }
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle(vm.xemLuuTru ? "Đã lưu trữ" : "Lịch sử")
            .navigationBarTitleDisplayModeInline()
            .searchable(text: $vm.tuKhoa, prompt: "Tìm trong lịch sử")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Đóng") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Xem", selection: $vm.xemLuuTru) {
                            Label("Đang hoạt động", systemImage: "bubble.left.and.bubble.right").tag(false)
                            Label("Đã lưu trữ", systemImage: "archivebox").tag(true)
                        }
                        Divider()
                        Button { tenThuMuc = ""; themThuMuc = true } label: {
                            Label("Thư mục mới", systemImage: "folder.badge.plus")
                        }
                        if !vm.thuMuc.isEmpty {
                            Divider()
                            Picker("Thư mục", selection: $vm.thuMucLoc) {
                                Text("Tất cả").tag(String?.none)
                                Text("Chưa xếp").tag(String?.some("none"))
                                ForEach(vm.thuMuc) { t in
                                    Text(t.ten).tag(String?.some(t.id))
                                }
                            }
                        }
                    } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
                }
            }
            .task { await vm.nap() }
            .onChange(of: vm.xemLuuTru) { _, _ in Task { await vm.nap() } }
            .onChange(of: vm.thuMucLoc) { _, _ in Task { await vm.nap() } }
            .refreshable { await vm.nap() }
            .alert("Đổi tên", isPresented: .constant(doiTen != nil)) {
                TextField("Tên cuộc trò chuyện", text: $tenMoi)
                Button("Huỷ", role: .cancel) { doiTen = nil }
                Button("Lưu") {
                    if let p = doiTen { Task { await vm.doiTen(p, thanh: tenMoi) } }
                    doiTen = nil
                }
            }
            .alert("Thư mục mới", isPresented: $themThuMuc) {
                TextField("Tên thư mục", text: $tenThuMuc)
                Button("Huỷ", role: .cancel) {}
                Button("Tạo") { Task { await vm.taoThuMuc(tenThuMuc) } }
            }
            .alert("Lỗi", isPresented: .constant(vm.loi != nil)) {
                Button("OK") { vm.loi = nil }
            } message: { Text(vm.loi ?? "") }
        }
    }

    private var trong: some View {
        VStack(spacing: 12) {
            Image(systemName: vm.xemLuuTru ? "archivebox" : "bubble.left.and.bubble.right")
                .font(.system(size: 44)).foregroundColor(AppColors.textTertiary)
            Text(vm.tuKhoa.isEmpty
                 ? (vm.xemLuuTru ? "Chưa lưu trữ cuộc nào" : "Chưa có cuộc trò chuyện nào")
                 : "Không tìm thấy cuộc nào khớp")
                .font(.bodyMedium).foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var danhSach: some View {
        List {
            ForEach(vm.locTheoTuKhoa()) { p in
                Button {
                    moCuoc(p)
                    dismiss()
                } label: { hang(p) }
                .buttonStyle(.plain)
                // Vuốt TRÁI = việc phá huỷ, vuốt PHẢI = việc lành. Trộn hai
                // bên là người dùng xoá nhầm khi định ghim.
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await vm.xoa(p) }
                    } label: { Label("Xoá", systemImage: "trash") }
                    Button {
                        Task { await vm.datLuuTru(p, !p.daLuuTru) }
                    } label: {
                        Label(p.daLuuTru ? "Bỏ lưu trữ" : "Lưu trữ",
                              systemImage: p.daLuuTru ? "tray.and.arrow.up" : "archivebox")
                    }
                    .tint(AppColors.warning)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        Task { await vm.datGhim(p, !p.pinned) }
                    } label: {
                        Label(p.pinned ? "Bỏ ghim" : "Ghim",
                              systemImage: p.pinned ? "pin.slash" : "pin")
                    }
                    .tint(AppColors.primary)
                }
                .contextMenu {
                    Button { tenMoi = p.ten; doiTen = p } label: {
                        Label("Đổi tên", systemImage: "pencil")
                    }
                    Button { Task { await vm.datGhim(p, !p.pinned) } } label: {
                        Label(p.pinned ? "Bỏ ghim" : "Ghim", systemImage: "pin")
                    }
                    Menu {
                        Button("Bỏ khỏi thư mục") { Task { await vm.chuyen(p, nil) } }
                        ForEach(vm.thuMuc) { t in
                            Button(t.ten) { Task { await vm.chuyen(p, t.id) } }
                        }
                    } label: { Label("Chuyển thư mục", systemImage: "folder") }
                    Divider()
                    Button(role: .destructive) { Task { await vm.xoa(p) } } label: {
                        Label("Xoá", systemImage: "trash")
                    }
                }
                .listRowBackground(AppColors.backgroundPrimary)
            }
        }
        .listStyle(.plain)
    }

    private func hang(_ p: PhienChat) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: p.pinned ? "pin.fill" : "bubble.left")
                .font(.system(size: 14))
                .foregroundColor(p.pinned ? AppColors.primary : AppColors.textTertiary)
                .frame(width: 18)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(p.ten).font(.system(size: 15.5, weight: .medium))
                    .foregroundColor(AppColors.textPrimary).lineLimit(2)
                HStack(spacing: 7) {
                    if let n = p.soTin { Text("\(n) tin") }
                    if let u = p.updatedAt { Text("·"); Text(TimeFormatter.formatTimeAgo(u)) }
                    if let f = p.folder {
                        Text("·")
                        Label(f.ten, systemImage: "folder.fill").labelStyle(.titleAndIcon)
                    }
                }
                .font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}
