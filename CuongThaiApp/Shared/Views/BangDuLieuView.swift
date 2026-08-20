import SwiftUI

/// Một trang cơ sở dữ liệu. Hiện dạng THẺ theo dòng chứ không phải lưới ngang:
/// bảng Notion thật thường 6-10 cột, nhét vào bề ngang điện thoại thì mỗi ô còn
/// ~30pt và không đọc được gì. Mỗi dòng là một thẻ, chạm vào mở ra sửa.
struct BangDuLieuView: View {
    let bangId: Int

    @State private var bang: BangDuLieu?
    @State private var dangTai = true
    @State private var loi: String?
    @State private var dongMo: DongBang?
    @State private var dangThem = false

    var body: some View {
        Group {
            if dangTai && bang == nil {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let b = bang {
                danhSach(b)
            } else {
                ErrorStateView(message: loi ?? "Không mở được bảng") {
                    Task { await tai() }
                }
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(bang.map { "\($0.icon ?? "🗂") \($0.ten)" } ?? "Bảng")
        .navigationBarTitleDisplayModeInline()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await themDong() }
                } label: {
                    if dangThem { ProgressView() } else { Image(systemName: "plus") }
                }
                .disabled(dangThem || bang == nil)
            }
        }
        .task { await tai() }
        .sheet(item: $dongMo) { d in
            if let b = bang {
                SuaDongBangView(bang: b, dong: d) { Task { await tai() } }
            }
        }
        .alert("Bảng", isPresented: .constant(loi != nil && bang != nil)) {
            Button("OK") { loi = nil }
        } message: { Text(loi ?? "") }
    }

    private func danhSach(_ b: BangDuLieu) -> some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if b.rows.isEmpty {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "tablecells")
                            .font(.system(size: 38))
                            .foregroundColor(AppColors.textTertiary)
                        Text("Bảng chưa có dòng nào")
                            .font(.bodyMedium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }

                ForEach(b.rows) { d in
                    Button { dongMo = d } label: { the(b, d) }
                        .buttonStyle(.plain)
                }

                if b.truncated == true {
                    Text("Bảng còn nhiều dòng hơn — máy chủ đã ngừng quét. Mở trên web để xem đủ.")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(Spacing.md)
                } else if let t = b.total {
                    Text("\(t) dòng")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.vertical, Spacing.sm)
                }
            }
            .padding(Spacing.md)
        }
    }

    private func the(_ b: BangDuLieu, _ d: DongBang) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let ct = b.cotTieuDe {
                Text(d.chu(ct).isEmpty ? "Chưa đặt tên" : d.chu(ct))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
            }
            // Chỉ hiện cột CÓ giá trị: bảng 10 cột mà dòng nào cũng liệt kê đủ
            // 10 dòng "— trống" thì thẻ dài ngoằng và không đọc được gì.
            ForEach(b.properties.filter { !$0.isTitle.orFalse && !d.chu($0).isEmpty }.prefix(4)) { c in
                HStack(spacing: 5) {
                    Image(systemName: c.kieu.bieuTuong)
                        .font(.system(size: 9))
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: 12)
                    Text(c.name)
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textTertiary)
                    Text(d.chu(c))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.backgroundSecondary))
        .contentShape(Rectangle())
    }

    private func tai() async {
        dangTai = true
        defer { dangTai = false }
        do { bang = try await APIClient.shared.request(.layBang(databaseId: bangId)) }
        catch { loi = error.localizedDescription }
    }

    private func themDong() async {
        dangThem = true
        defer { dangThem = false }
        do {
            let _: DongBang = try await APIClient.shared.request(.taoDongBang(databaseId: bangId))
            Haptics.xong()
            await tai()
        } catch { loi = error.localizedDescription }
    }
}

extension Optional where Wrapped == Bool {
    var orFalse: Bool { self ?? false }
}

