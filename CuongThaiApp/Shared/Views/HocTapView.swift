import SwiftUI

// ════════════════════════════════════════════════════════════════
// MỤC HỌC TẬP
//
// Ba loạt bài nhiều kỳ (100 Ngày Java / Database / Tiếng Anh) sống TRỌN trong
// mục này. Bảng tin chung gọi `excludeSeries=true` nên chúng không tràn sang
// "Tất cả" — đo 20/08/2026: 135 trong 145 bài của bảng tin là bài loạt, để
// nguyên thì bài thường bị dìm mất.
//
// Vì sao là lưới ngày chứ không phải danh sách cuộn: một loạt có tới 100 kỳ.
// Muốn xem lại Ngày 7 mà phải cuộn qua 93 bài thì không ai cuộn.
// ════════════════════════════════════════════════════════════════

// MARK: - Bộ nạp mục lục

@MainActor
final class HocTapViewModel: ObservableObject {
    @Published var mucLuc: [String: PostSeries] = [:]
    @Published var dangTai = true
    @Published var loi: String?

    func tai() async {
        dangTai = true
        loi = nil
        var thu: [String: PostSeries] = [:]
        var loiDau: String?
        // Ba lời gọi độc lập chạy song song — tuần tự thì màn hình đứng chờ
        // ba vòng mạng liên tiếp.
        await withTaskGroup(of: (String, Result<PostSeries, Error>).self) { nhom in
            for loat in LoatBai.tatCa {
                nhom.addTask {
                    do {
                        let d: PostSeries = try await APIClient.shared.request(.getSeries(slug: loat.slug))
                        return (loat.slug, .success(d))
                    } catch {
                        return (loat.slug, .failure(error))
                    }
                }
            }
            for await (slug, kq) in nhom {
                switch kq {
                case .success(let d): thu[slug] = d
                case .failure(let e): loiDau = loiDau ?? e.localizedDescription
                }
            }
        }
        mucLuc = thu
        // Chỉ báo lỗi khi KHÔNG loạt nào về. Một loạt hỏng mà hai loạt kia chạy
        // thì che cả màn hình là mất nhiều hơn được.
        loi = thu.isEmpty ? loiDau : nil
        dangTai = false
    }
}

// MARK: - Danh sách loạt bài

struct HocTapView: View {
    @StateObject private var vm = HocTapViewModel()

    private let cot = [GridItem(.flexible())]

    var body: some View {
        Group {
            if vm.dangTai && vm.mucLuc.isEmpty {
                ScrollView {
                    VStack(spacing: Spacing.md) {
                        ForEach(0..<3, id: \.self) { _ in TheLoatKhungXuong() }
                    }
                    .padding(Spacing.md)
                }
                .disabled(true)
            } else if let loi = vm.loi {
                ErrorStateView(message: loi) { Task { await vm.tai() } }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        loiMoDau

                        ForEach(LoatBai.tatCa) { loat in
                            if let d = vm.mucLuc[loat.slug] {
                                NavigationLink(destination: ChiTietLoatView(loat: loat, mucLuc: d)) {
                                    TheLoat(loat: loat, mucLuc: d)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        chanTrang
                    }
                    .padding(Spacing.md)
                }
                .refreshable { await vm.tai() }
            }
        }
        .task { if vm.mucLuc.isEmpty { await vm.tai() } }
    }

    private var loiMoDau: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Loạt bài theo ngày")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
            Text("Mỗi loạt là một hành trình 100 ngày. Chạm vào một ngày để mở bài của ngày đó.")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, Spacing.xs)
    }

    private var chanTrang: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
            Text("Bài của các loạt này chỉ nằm trong mục Học tập, không lẫn vào Bảng tin.")
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 12))
        .foregroundColor(AppColors.textTertiary)
        .padding(.top, Spacing.sm)
    }
}

// MARK: - Thẻ một loạt

private struct TheLoat: View {
    let loat: LoatBai
    let mucLuc: PostSeries

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: loat.mau.map { Color(hex: $0) },
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: loat.bieuTuong)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 3) {
                    Text(loat.tenNgan)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text(loat.moTa)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }

            ThanhTienDo(tiLe: mucLuc.tiLe, mau: Color(hex: loat.mau[0]))

            HStack {
                Text("Đã đăng \(mucLuc.soDaDang)/\(mucLuc.total) ngày")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                if mucLuc.soDaDang >= mucLuc.total {
                    NhanNho(chu: "Trọn bộ", mau: AppColors.success)
                } else {
                    NhanNho(chu: "Đang ra", mau: Color(hex: loat.mau[0]))
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.backgroundSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }
}

private struct TheLoatKhungXuong: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(AppColors.backgroundSecondary)
            .frame(height: 140)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 1)
            )
    }
}

private struct ThanhTienDo: View {
    let tiLe: Double
    let mau: Color

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(AppColors.border)
                Capsule()
                    .fill(LinearGradient(colors: [mau.opacity(0.75), mau],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, min(1, tiLe)) * g.size.width)
            }
        }
        .frame(height: 6)
    }
}

private struct NhanNho: View {
    let chu: String
    let mau: Color

    var body: some View {
        Text(chu)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(mau)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(mau.opacity(0.14)))
    }
}
