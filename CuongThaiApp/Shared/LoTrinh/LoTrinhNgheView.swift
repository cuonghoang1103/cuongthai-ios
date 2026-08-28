import SwiftUI

// MARK: - Danh sách lộ trình

@MainActor
final class LoTrinhNgheVM: ObservableObject {
    @Published var vaiTro: [LoTrinhNgheTom] = []
    @Published var kyNang: [LoTrinhNgheTom] = []
    @Published var dangTai = false
    @Published var loi: String?

    func nap() async {
        guard vaiTro.isEmpty, kyNang.isEmpty, !dangTai else { return }
        dangTai = true; defer { dangTai = false }
        do {
            let d: DanhSachLoTrinhNghe = try await APIClient.shared.request(.dsLoTrinh)
            vaiTro = d.vaiTro; kyNang = d.kyNang
            loi = (vaiTro.isEmpty && kyNang.isEmpty) ? T("Chưa có lộ trình nào.") : nil
        } catch { loi = error.localizedDescription }
    }
}

struct LoTrinhNgheView: View {
    @StateObject private var vm = LoTrinhNgheVM()
    @State private var tab = 0
    @State private var tim = ""

    private var dsHien: [LoTrinhNgheTom] {
        let goc = tab == 0 ? vm.vaiTro : vm.kyNang
        let k = tim.trimmingCharacters(in: .whitespaces).chuanHoaTim
        guard !k.isEmpty else { return goc }
        return goc.filter { $0.title.chuanHoaTim.contains(k)
                         || ($0.description ?? "").chuanHoaTim.contains(k) }
    }

    var body: some View {
        ScrollViewReader { cuon in
        ScrollView {
            VStack(spacing: Spacing.md) {
                NeoDauTrang()

                // Hai loại lộ trình là hai câu hỏi khác nhau — "tôi muốn làm
                // nghề gì" và "tôi muốn giỏi thứ gì" — nên tách tab chứ không
                // trộn một danh sách 33 mục.
                Picker("", selection: $tab) {
                    Text("\(T("Vai trò")) (\(vm.vaiTro.count))").tag(0)
                    Text("\(T("Kỹ năng")) (\(vm.kyNang.count))").tag(1)
                }
                .pickerStyle(.segmented)

                HStack(spacing: Spacing.sm) {
                    Image(systemName: "magnifyingglass").foregroundColor(AppColors.textTertiary)
                    TextField(T("Tìm lộ trình…"), text: $tim)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if !tim.isEmpty {
                        Button { tim = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textTertiary)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(Spacing.sm + 2)
                .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.backgroundCard))

                if vm.dangTai && dsHien.isEmpty {
                    ProgressView().padding(.top, Spacing.xl)
                } else if dsHien.isEmpty {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "map").font(.system(size: 40))
                            .foregroundColor(AppColors.textTertiary)
                        Text(vm.loi ?? T("Không có lộ trình nào khớp."))
                            .font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.top, Spacing.xl * 2)
                } else {
                    ForEach(dsHien) { lt in
                        NavigationLink { LoTrinhNgheChiTietView(tom: lt) } label: { the(lt) }
                            .buttonStyle(.plain)
                    }
                }
                Color.clear.frame(height: 72)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
        }
        .onChange(of: tab) { _, _ in cuon.veDauTrang() }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(T("Lộ trình"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.nap() }
    }

    private func the(_ lt: LoTrinhNgheTom) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: lt.bieuTuong)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 46, height: 46)
                .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(LinearGradient(colors: [lt.mau, lt.mau.opacity(0.65)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)))
            VStack(alignment: .leading, spacing: 3) {
                Text(lt.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                if let d = lt.description, !d.isEmpty {
                    Text(d)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2).multilineTextAlignment(.leading)
                }
                if lt.soNut > 0 {
                    Text("\(lt.soNut) \(T("bước"))")
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        .foregroundColor(lt.mau)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Capsule().fill(lt.mau.opacity(0.15)))
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }
}

// MARK: - Lối vào từ tab Học

struct LoTrinhNgheEntryCard: View {
    var body: some View {
        NavigationLink { LoTrinhNgheView() } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "map.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 46, height: 46)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: 0x4F46E5), Color(hex: 0x818CF8)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(T("Lộ trình"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("14 \(T("vai trò")) · 19 \(T("kỹ năng")) · \(T("đánh dấu từng bước"))")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1).minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(Spacing.md)
            .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(AppColors.backgroundCard))
        }
        .buttonStyle(.plain)
    }
}
