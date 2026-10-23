import SwiftUI

// ════════════════════════════════════════════════════════════════
// TẤT CẢ TÍNH NĂNG — danh mục đầy đủ, ghim/bỏ ghim, sắp thứ tự ghim.
//
// Lối vào: ô "Tất cả" cuối lưới Đi nhanh (Hôm nay) · hàng "Tất cả tính năng"
// ở Tôi · "Tất cả tính năng…" ở thanh bên iPad · ⇧⌘A.
// Mục đã ghim hiện ở lưới Đi nhanh của Hôm nay và mục "Công cụ" thanh bên iPad.
// ════════════════════════════════════════════════════════════════

struct TatCaView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var kho = KhoGhim.shared
    @State private var tuKhoa = ""
    #if os(iOS)
    /// Tự giữ chế độ sửa thay vì `EditButton()`: nút hệ thống lấy chữ theo
    /// ngôn ngữ của GÓI app (hiện "Edit" giữa màn tiếng Việt), không theo `T()`.
    @State private var cheDoSua: EditMode = .inactive
    #endif

    private var dangTim: Bool { !TinhNang.chuanHoa(tuKhoa).isEmpty }

    var body: some View {
        List {
            if dangTim {
                let kq = TinhNang.tim(tuKhoa)
                if kq.isEmpty {
                    ContentUnavailableView.search(text: tuKhoa)
                        .listRowBackground(Color.clear)
                } else {
                    Section(T("Kết quả")) {
                        ForEach(kq) { f in HangTinhNang(tinhNang: f) }
                    }
                }
            } else {
                Section {
                    if kho.ds.isEmpty {
                        Text(T("Chưa ghim mục nào. Chạm biểu tượng ghim ở một tính năng để nó hiện ở Hôm nay."))
                            .font(.footnote)
                            .foregroundColor(AppColors.textSecondary)
                    } else {
                        ForEach(kho.ds) { f in HangTinhNang(tinhNang: f) }
                            .onMove { kho.diChuyen(tu: $0, toi: $1) }
                            .onDelete { $0.map { kho.ds[$0] }.forEach(kho.boGhim) }
                    }
                } header: {
                    Text(T("Đã ghim"))
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(T("Mục đã ghim hiện ở Đi nhanh của Hôm nay. Bấm Sửa để kéo đổi thứ tự."))
                        if kho.ds != TinhNang.ghimMacDinh {
                            Button(T("Khôi phục mặc định")) {
                                withAnimation { kho.veMacDinh() }
                            }
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(AppColors.primary)
                        }
                    }
                }

                ForEach(TinhNang.Nhom.allCases) { nhom in
                    Section(nhom.ten) {
                        ForEach(TinhNang.allCases.filter { $0.nhom == nhom }) { f in
                            HangTinhNang(tinhNang: f)
                        }
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        .searchable(text: $tuKhoa, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: T("Tìm tính năng"))
        .toolbar {
            if !dangTim && !kho.ds.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button(cheDoSua.isEditing ? T("Xong") : T("Sửa")) {
                        withAnimation { cheDoSua = cheDoSua.isEditing ? .inactive : .active }
                    }
                    .fontWeight(cheDoSua.isEditing ? .semibold : .regular)
                }
            }
        }
        .environment(\.editMode, $cheDoSua)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .scrollContentBackground(.hidden)
        .nenChuDe(tieuDeLon: true)
        .navigationTitle(T("Tất cả tính năng"))
        .animation(.default, value: kho.ds)
    }
}

/// Một hàng của danh mục: biểu tượng · tên · mô tả · nút ghim.
private struct HangTinhNang: View {
    let tinhNang: TinhNang
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var kho = KhoGhim.shared

    var body: some View {
        Group {
            if tinhNang.cachMo == .day {
                NavigationLink { ManTinhNang(tinhNang: tinhNang) } label: { noiDung }
            } else {
                Button { appState.moTinhNang(tinhNang) } label: { noiDung }
                    .buttonStyle(.plain)
            }
        }
        .contextMenu { nutGhim }
        #if os(iOS)
        .swipeActions(edge: .leading) { nutGhim.tint(AppColors.primary) }
        #endif
    }

    private var noiDung: some View {
        HStack(spacing: 12) {
            OBieuTuongTinhNang(tinhNang: tinhNang, canh: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(tinhNang.ten)
                    .font(.body.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                Text(tinhNang.moTa)
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if tinhNang.cachMo == .ngoai {
                Image(systemName: "arrow.up.forward.app")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(AppColors.textTertiary)
                    .accessibilityHidden(true)
            }
            Button { withAnimation { kho.batTat(tinhNang) }; Haptics.cham() } label: {
                Image(systemName: kho.coGhim(tinhNang) ? "pin.fill" : "pin")
                    .font(.body)
                    .foregroundColor(kho.coGhim(tinhNang) ? AppColors.primary : AppColors.textTertiary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(kho.coGhim(tinhNang)
                                ? String(format: T("Bỏ ghim %@"), tinhNang.ten)
                                : String(format: T("Ghim %@"), tinhNang.ten))
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
    }

    private var nutGhim: some View {
        Button { withAnimation { kho.batTat(tinhNang) } } label: {
            if kho.coGhim(tinhNang) {
                Label(T("Bỏ ghim"), systemImage: "pin.slash")
            } else {
                Label(T("Ghim vào Hôm nay"), systemImage: "pin")
            }
        }
    }
}

/// Ô biểu tượng bo góc tô màu nhạt — kiểu ô của app Cài đặt, dùng ở danh mục,
/// lưới Đi nhanh và kết quả tìm kiếm.
struct OBieuTuongTinhNang: View {
    let tinhNang: TinhNang
    var canh: CGFloat = 34

    var body: some View {
        Image(systemName: tinhNang.bieuTuong)
            .font(.system(size: canh * 0.46, weight: .semibold))
            .foregroundColor(tinhNang.mau)
            .frame(width: canh, height: canh)
            .background(RoundedRectangle(cornerRadius: canh * 0.28, style: .continuous)
                .fill(tinhNang.mau.opacity(0.15)))
            .accessibilityHidden(true)
    }
}

// MARK: - Lưới "Đi nhanh" (Hôm nay)

/// Các tính năng ĐÃ GHIM + ô "Tất cả" cuối lưới. Phải nằm trong
/// `NavigationStack(path:)` của Hôm nay — ô đẩy bằng `DichHomNay`.
struct LuoiDiNhanh: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var kho = KhoGhim.shared

    private let cot = [GridItem(.adaptive(minimum: 150), spacing: Spacing.sm)]

    var body: some View {
        LazyVGrid(columns: cot, spacing: Spacing.sm) {
            ForEach(kho.ds) { f in
                o(f)
                    .contextMenu {
                        Button(role: .destructive) { withAnimation { kho.boGhim(f) } } label: {
                            Label(T("Bỏ ghim"), systemImage: "pin.slash")
                        }
                        Button { appState.duongHomNay.append(.tatCa) } label: {
                            Label(T("Sắp xếp lại…"), systemImage: "arrow.up.arrow.down")
                        }
                    }
            }
            NavigationLink(value: DichHomNay.tatCa) {
                the(bieuTuong: OTatCaBieuTuong(), ten: T("Tất cả"), phu: T("Mọi tính năng, ghim thêm"))
            }
            .buttonStyle(.nhan)
            .accessibilityLabel(T("Tất cả tính năng"))
        }
        .animation(.default, value: kho.ds)
    }

    @ViewBuilder
    private func o(_ f: TinhNang) -> some View {
        let nhan = the(bieuTuong: OBieuTuongTinhNang(tinhNang: f, canh: 36), ten: f.ten, phu: f.moTa)
        if f.cachMo == .day {
            NavigationLink(value: DichHomNay.tinhNang(f)) { nhan }
                .buttonStyle(.nhan)
        } else {
            Button { appState.moTinhNang(f) } label: { nhan }
                .buttonStyle(.nhan)
        }
    }

    private func the<B: View>(bieuTuong: B, ten: String, phu: String) -> some View {
        HStack(spacing: 10) {
            bieuTuong
            VStack(alignment: .leading, spacing: 2) {
                Text(ten)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(phu)
                    .font(.caption2)
                    .foregroundColor(AppColors.textTertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large + 4, style: .continuous)
                .fill(AppColors.backgroundCard)
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.large + 4, style: .continuous)
                    .strokeBorder(AppColors.border, lineWidth: 1))
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Biểu tượng ô "Tất cả": bốn chấm trên nền chuyển màu thương hiệu.
private struct OTatCaBieuTuong: View {
    var body: some View {
        Image(systemName: "square.grid.2x2.fill")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 36, height: 36)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppColors.brandGradient))
            .accessibilityHidden(true)
    }
}
