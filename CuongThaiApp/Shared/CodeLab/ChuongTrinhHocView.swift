import SwiftUI

// MARK: - Chương trình học của một lộ trình

@MainActor
final class ChuongTrinhVM: ObservableObject {
    @Published var lt: LoTrinhChiTiet?
    @Published var daGiai: Set<Int> = []
    @Published var dangTai = true
    @Published var loi: String?
    @Published var moChuong: Set<Int> = []

    func tai(slug: String, loTrinhId: Int) async {
        dangTai = true; defer { dangTai = false }
        do {
            let d: LoTrinhChiTiet = try await APIClient.shared.request(.loTrinhChiTiet(slug: slug))
            lt = d
            // Mở sẵn chương ĐẦU: mở hết thì màn dài hàng nghìn dòng, còn gập
            // hết thì người mở lần đầu chỉ thấy một dãy tiêu đề.
            if let c = d.dsChuong.first { moChuong = [c.id] }
        } catch { loi = error.localizedDescription }

        // Tiến độ đòi đăng nhập — hỏng thì thôi, KHÔNG chặn chương trình học.
        if let ds: [TienDoBai] = try? await APIClient.shared.request(.tienDoCodeLab(loTrinhId: loTrinhId)) {
            daGiai = Set(ds.filter(\.daGiai).map(\.exerciseId))
        }
    }

    func soXong(_ c: ChuongCode) -> Int { c.dsBai.filter { daGiai.contains($0.id) }.count }

    func doiTrangThai(_ b: BaiTapGon) async {
        let dang = daGiai.contains(b.id)
        if dang { daGiai.remove(b.id) } else { daGiai.insert(b.id) }
        struct R: Codable { let status: String? }
        do {
            _ = try await APIClient.shared.request(
                .ghiTienDoBaiTap(baiId: b.id, trangThai: dang ? "IN_PROGRESS" : "SOLVED")) as R
        } catch {
            if dang { daGiai.insert(b.id) } else { daGiai.remove(b.id) }
        }
    }
}

struct ChuongTrinhHocView: View {
    let loTrinh: LoTrinhCode
    @StateObject private var vm = ChuongTrinhVM()

    private var tongXong: Int {
        (vm.lt?.dsChuong ?? []).reduce(0) { $0 + vm.soXong($1) }
    }
    private var tongBai: Int {
        (vm.lt?.dsChuong ?? []).reduce(0) { $0 + $1.dsBai.count }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                dauTrang
                if vm.dangTai {
                    ProgressView().padding(.top, Spacing.xl)
                } else if let d = vm.lt {
                    ForEach(Array(d.dsChuong.enumerated()), id: \.element.id) { i, c in
                        theChuong(c, so: i + 1, mau: d.mau)
                    }
                } else {
                    Text(vm.loi ?? "Không tải được lộ trình.")
                        .font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                        .padding(.top, Spacing.xl)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(loTrinh.ten)
        .navigationBarTitleDisplayMode(.inline)
        .task { if vm.lt == nil { await vm.tai(slug: loTrinh.slug ?? "", loTrinhId: loTrinh.id) } }
    }

    // MARK: Đầu trang

    private var dauTrang: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                Text(loTrinh.chuDau)
                    .font(.system(size: 17, weight: .black))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color(hex: loTrinh.mau)))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: Spacing.xs) {
                        Text(loTrinh.cap.ten)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: loTrinh.cap.mau))
                            .padding(.horizontal, Spacing.sm).padding(.vertical, 2)
                            .background(Capsule().fill(Color(hex: loTrinh.cap.mau).opacity(0.15)))
                        if let l = loTrinh.language, !l.isEmpty {
                            Text(l).font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                        }
                    }
                    Text("\(tongBai) bài · \(vm.lt?.dsChuong.count ?? loTrinh.soChuong) chương")
                        .font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                }
                Spacer(minLength: 0)
            }

            if tongBai > 0 {
                VStack(spacing: 4) {
                    HStack {
                        Text("Đã giải \(tongXong)/\(tongBai)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Text("\(tongBai > 0 ? tongXong * 100 / tongBai : 0)%")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: loTrinh.mau))
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppColors.backgroundTertiary)
                            Capsule().fill(Color(hex: loTrinh.mau))
                                .frame(width: g.size.width * CGFloat(tongBai > 0 ? Double(tongXong) / Double(tongBai) : 0))
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
        .padding(.bottom, Spacing.xs)
    }

    // MARK: Một chương

    private func theChuong(_ c: ChuongCode, so: Int, mau: UInt32) -> some View {
        let mo = vm.moChuong.contains(c.id)
        let xong = vm.soXong(c)
        return VStack(spacing: Spacing.sm) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    if mo { vm.moChuong.remove(c.id) } else { vm.moChuong.insert(c.id) }
                }
            } label: {
                HStack(spacing: Spacing.md) {
                    // Số chương trong vòng tròn — đầy màu khi cả chương đã xong.
                    ZStack {
                        Circle()
                            .fill(xong == c.dsBai.count && !c.dsBai.isEmpty
                                  ? Color(hex: mau) : Color(hex: mau).opacity(0.15))
                            .frame(width: 34, height: 34)
                        if xong == c.dsBai.count && !c.dsBai.isEmpty {
                            Image(systemName: "checkmark").font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(so)").font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(hex: mau))
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.ten)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(2).multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: Spacing.xs) {
                            if c.coBaiHoc {
                                Text("Có bài học")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Color(hex: 0x8C5AF0))
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(Capsule().fill(Color(hex: 0x8C5AF0).opacity(0.15)))
                            }
                            Text("\(xong)/\(c.dsBai.count) bài")
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: mo ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if mo {
                if let d = c.description, !d.isEmpty {
                    Text(d)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if c.coBaiHoc {
                    NavigationLink { BaiHocView(chuong: c, mauLoTrinh: mau) } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "book.fill").font(.system(size: 13))
                            Text("Đọc bài học").font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(Color(hex: 0x8C5AF0))
                        .padding(Spacing.sm + 2)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(Color(hex: 0x8C5AF0).opacity(0.10)))
                    }
                    .buttonStyle(.plain)
                }
                ForEach(c.dsBai) { b in hangBai(b) }
            }
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    private func hangBai(_ b: BaiTapGon) -> some View {
        HStack(spacing: Spacing.sm) {
            Button { Task { await vm.doiTrangThai(b) } } label: {
                Image(systemName: vm.daGiai.contains(b.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
                    .foregroundColor(vm.daGiai.contains(b.id) ? AppColors.success : AppColors.textTertiary)
            }
            .buttonStyle(.plain)

            NavigationLink { NapBaiTapView(slug: b.slug ?? "", ten: b.title) } label: {
                HStack(spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(b.title)
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(2).multilineTextAlignment(.leading)
                            .strikethrough(vm.daGiai.contains(b.id), color: AppColors.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: Spacing.xs) {
                            Text(b.doKho.ten)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Color(hex: b.doKho.mau))
                            if b.phut > 0 {
                                Text("· \(b.phut)′").font(.system(size: 9))
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            if b.diem > 0 {
                                Text("· \(b.diem)đ").font(.system(size: 9))
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Nạp một bài tập theo slug

/// Bài tập lồng trong chương chỉ là bản GỌN (không có đề bài, ví dụ, lời
/// giải), nên mở ra phải gọi thêm `/exercises/:slug`.
struct NapBaiTapView: View {
    let slug: String
    let ten: String

    @State private var bai: BaiTapCode?
    @State private var loi: String?

    var body: some View {
        Group {
            if let b = bai {
                BaiTapCodeView(bai: b)
            } else if let l = loi {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle").font(.system(size: 34))
                        .foregroundColor(AppColors.warning)
                    Text(l).font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(Spacing.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.backgroundPrimary)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.backgroundPrimary)
            }
        }
        .navigationTitle(ten)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard bai == nil else { return }
            do { bai = try await APIClient.shared.request(.baiTapTheoSlug(slug: slug)) }
            catch { loi = error.localizedDescription }
        }
    }
}
