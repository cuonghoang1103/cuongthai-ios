import SwiftUI

@MainActor
final class LoTrinhNgheChiTietVM: ObservableObject {
    @Published var lt: LoTrinhChiTietNghe?
    @Published var daXong: Set<Int> = []
    @Published var dangTai = true
    @Published var loi: String?
    /// Nút đang gửi lên máy chủ — chặn bấm liên tục một nút.
    @Published var dangGui: Set<Int> = []

    func nap(_ slug: String) async {
        dangTai = true; defer { dangTai = false }
        do {
            let d: LoTrinhChiTietNghe = try await APIClient.shared.request(.loTrinhNghe(slug: slug))
            lt = d
            daXong = d.daXong
            loi = d.cacChang.isEmpty ? T("Lộ trình này chưa có bước nào.") : nil
        } catch { loi = error.localizedDescription }
    }

    /// Đánh dấu xong/chưa xong.
    ///
    /// ⚠️ Lật ở giao diện TRƯỚC rồi mới gọi máy chủ, và trả lại nếu hỏng.
    /// Đợi mạng mới đổi dấu tick thì trên 4G có thể mất cả giây — người dùng
    /// bấm lại lần nữa và thành ra lật hai lần.
    func doiXong(_ id: Int) async {
        guard !dangGui.contains(id) else { return }
        dangGui.insert(id); defer { dangGui.remove(id) }
        let truoc = daXong
        if daXong.contains(id) { daXong.remove(id) } else { daXong.insert(id) }
        do {
            let _: DapAnRongLoTrinh = try await APIClient.shared.request(.danhDauNutLoTrinhNghe(nodeId: id))
        } catch {
            daXong = truoc
            loi = T("Chưa lưu được. Đăng nhập rồi thử lại.")
        }
    }
}

/// Máy chủ trả `{ success, data }` mà `data` có thể rỗng — chỉ cần biết là
/// không ném lỗi.
struct DapAnRongLoTrinh: Codable {}

struct LoTrinhNgheChiTietView: View {
    let tom: LoTrinhNgheTom
    @StateObject private var vm = LoTrinhNgheChiTietVM()
    @State private var moChang: Set<Int> = [0]
    @State private var chiConThieu = false

    private var mau: Color { vm.lt?.mau ?? tom.mau }
    private var tong: Int { vm.lt?.tongNut ?? tom.soNut }
    private var xong: Int { vm.daXong.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                NeoDauTrang()
                dauTrang
                if vm.dangTai && vm.lt == nil {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, Spacing.xl)
                } else if let l = vm.lt {
                    ForEach(l.cacChang) { c in chang(c) }
                }
                if let e = vm.loi, vm.lt == nil {
                    Text(e).font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity).padding(.top, Spacing.xl)
                }
                Color.clear.frame(height: 72)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(tom.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.nap(tom.slug) }
    }

    // MARK: Đầu trang

    private var dauTrang: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                Image(systemName: tom.bieuTuong)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(LinearGradient(colors: [mau, mau.opacity(0.65)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(tom.title)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("\(xong)/\(tong) \(T("bước"))")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundColor(mau)
                }
                Spacer(minLength: 0)
            }
            if let d = vm.lt?.description ?? tom.description, !d.isEmpty {
                Text(d)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColors.backgroundTertiary)
                    Capsule().fill(mau)
                        .frame(width: g.size.width * (tong > 0 ? Double(xong) / Double(tong) : 0))
                }
            }
            .frame(height: 6)

            HStack(spacing: Spacing.sm) {
                Toggle(isOn: $chiConThieu) {
                    Text(T("Chỉ hiện bước chưa xong"))
                        .font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                }
                .toggleStyle(.switch)
                .tint(mau)
            }
            .padding(.top, 2)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    // MARK: Một chặng

    @ViewBuilder private func chang(_ c: ChangLoTrinhNghe) -> some View {
        let nut = chiConThieu ? c.cacNut.filter { !vm.daXong.contains($0.id) } : c.cacNut
        if !nut.isEmpty {
            let mo = moChang.contains(c.stage)
            let xongChang = c.cacNut.filter { vm.daXong.contains($0.id) }.count
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        if mo { moChang.remove(c.stage) } else { moChang.insert(c.stage) }
                    }
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Text("\(c.stage + 1)")
                            .font(.system(size: 11, weight: .heavy).monospacedDigit())
                            .foregroundColor(xongChang == c.cacNut.count ? .white : mau)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(xongChang == c.cacNut.count
                                                      ? mau : mau.opacity(0.16)))
                        Text(c.nhan)
                            .font(.system(size: 14.5, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Text("\(xongChang)/\(c.cacNut.count)")
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundColor(AppColors.textTertiary)
                        Image(systemName: mo ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(Spacing.md)
                }
                .buttonStyle(.plain)

                if mo {
                    VStack(spacing: Spacing.sm) {
                        ForEach(nut) { n in NutNgheView(nut: n, mau: mau, vm: vm) }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.md)
                }
            }
            .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
        }
    }
}

// MARK: - Một bước

private struct NutNgheView: View {
    let nut: NutLoTrinhNghe
    let mau: Color
    @ObservedObject var vm: LoTrinhNgheChiTietVM
    @State private var mo = false

    private var xong: Bool { vm.daXong.contains(nut.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Button { Task { await vm.doiXong(nut.id) } } label: {
                    Image(systemName: xong ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(xong ? mau : AppColors.textTertiary.opacity(0.6))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Image(systemName: nut.bieuTuong)
                            .font(.system(size: 11)).foregroundColor(mau.opacity(0.85))
                        Text(nut.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(xong ? AppColors.textTertiary : AppColors.textPrimary)
                            .strikethrough(xong, color: AppColors.textTertiary)
                            .multilineTextAlignment(.leading)
                    }
                    if let s = nut.subtitle, !s.isEmpty {
                        Text(s).font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                    }
                    HStack(spacing: 5) {
                        Text(nut.nhanLoai)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(nhanMau)
                            .padding(.horizontal, 5).padding(.vertical, 1.5)
                            .background(Capsule().fill(nhanMau.opacity(0.15)))
                        if !nut.cacTaiNguyen.isEmpty {
                            Text("\(nut.cacTaiNguyen.count) \(T("tài nguyên"))")
                                .font(.system(size: 9)).foregroundColor(AppColors.textTertiary)
                        }
                    }
                    .padding(.top, 1)
                }
                Spacer(minLength: 0)
                if nut.description != nil || !nut.cacTaiNguyen.isEmpty {
                    Button { withAnimation(.easeInOut(duration: 0.16)) { mo.toggle() } } label: {
                        Image(systemName: mo ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppColors.textTertiary)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }
            }

            if mo {
                if let d = nut.description, !d.isEmpty {
                    Text(d)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 28)
                }
                ForEach(nut.cacTaiNguyen) { r in
                    if let u = URL(string: r.url) {
                        Link(destination: u) {
                            HStack(spacing: 6) {
                                Image(systemName: r.bieuTuong).font(.system(size: 10))
                                Text(r.title ?? r.url)
                                    .font(.system(size: 11.5))
                                    .lineLimit(1)
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 8, weight: .bold))
                                Spacer(minLength: 0)
                            }
                            .foregroundColor(mau)
                            .padding(.horizontal, Spacing.sm).padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 7).fill(mau.opacity(0.10)))
                        }
                        .padding(.leading, 28)
                    }
                }
            }
        }
        .padding(Spacing.sm + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundTertiary.opacity(xong ? 0.35 : 0.7)))
    }

    private var nhanMau: Color {
        switch nut.loai {
        case .chinh: return mau
        case .thayThe: return AppColors.textSecondary
        case .thongTin: return AppColors.textTertiary
        }
    }
}
