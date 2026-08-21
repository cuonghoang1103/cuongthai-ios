import SwiftUI

// ── Chọn ngôn ngữ ───────────────────────────────────────────────

struct NgonNguView: View {
    @StateObject private var vm = NgonNguVM()

    private let cot = [GridItem(.adaptive(minimum: 150), spacing: Spacing.md)]

    var body: some View {
        ScrollView {
            if vm.dangTai && vm.dsNgonNgu.isEmpty {
                ProgressView().padding(.top, Spacing.xxl)
            } else if let loi = vm.loi, vm.dsNgonNgu.isEmpty {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "globe")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.textTertiary)
                    Text(loi)
                        .font(.body)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Spacing.xxl)
                .padding(.horizontal, Spacing.lg)
            } else {
                LazyVGrid(columns: cot, spacing: Spacing.md) {
                    ForEach(vm.dsNgonNgu) { n in
                        NavigationLink(destination: NgonNguHomeView(ngonNgu: n)) {
                            TheNgonNgu(n: n)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Spacing.md)
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Ngoại ngữ")
        .navigationBarTitleDisplayMode(.large)
        .task { if vm.dsNgonNgu.isEmpty { await vm.tai() } }
        .refreshable { await vm.tai() }
    }
}

private struct TheNgonNgu: View {
    let n: NgonNgu

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(n.co).font(.system(size: 40))

            Text(n.name)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)

            if let sl = n.counts {
                Text("\(sl.words ?? 0) từ · \(sl.grammar ?? 0) ngữ pháp")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(AppColors.backgroundCard)
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.large)
                    .strokeBorder(AppColors.border, lineWidth: 1))
        )
    }
}

// ── Trang chủ một ngôn ngữ ──────────────────────────────────────

struct NgonNguHomeView: View {
    let ngonNgu: NgonNgu
    @StateObject private var vm = ChuDeVM()

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                // Ôn tập đặt TRÊN CÙNG, không nằm lẫn trong danh sách chủ đề.
                // Ôn đúng hạn quan trọng hơn học từ mới, mà thứ nằm dưới thì
                // người ta không cuộn tới.
                NavigationLink(destination: OnTapView(ngonNgu: ngonNgu)) {
                    TheOnTap()
                }
                .buttonStyle(.plain)

                if !vm.dsCap.isEmpty { thanhCap }

                if vm.dangTai && vm.tatCa.isEmpty {
                    ProgressView().padding(.top, Spacing.xl)
                } else {
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(vm.hienThi) { c in
                            NavigationLink(destination: TuNgoaiNguView(ngonNgu: ngonNgu, chuDe: c)) {
                                HangChuDe(c: c)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("\(ngonNgu.co) \(ngonNgu.name)")
        .navigationBarTitleDisplayMode(.inline)
        .task { if vm.tatCa.isEmpty { await vm.tai(ngonNgu.code) } }
    }

    private var thanhCap: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(vm.dsCap, id: \.self) { c in
                    let chon = vm.cap == c
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { vm.cap = c }
                        Haptics.cham()
                    } label: {
                        Text(c)
                            .font(.system(size: 14, weight: chon ? .semibold : .regular))
                            .foregroundColor(chon ? .white : AppColors.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(chon ? AppColors.primary : AppColors.backgroundTertiary)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

private struct TheOnTap: View {
    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 46, height: 46)
                .background(Circle().fill(AppColors.primary))

            VStack(alignment: .leading, spacing: 2) {
                Text("Ôn tập hôm nay")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Text("Những từ đã tới hạn gặp lại")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(AppColors.backgroundCard)
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.large)
                    .strokeBorder(AppColors.primary.opacity(0.35), lineWidth: 1))
        )
    }
}

private struct HangChuDe: View {
    let c: ChuDeTu

    var body: some View {
        HStack(spacing: Spacing.md) {
            Text(c.icon ?? "📚").font(.system(size: 26))

            VStack(alignment: .leading, spacing: 2) {
                Text(c.tenGon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text("\(c.soTu) từ")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer(minLength: Spacing.sm)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm + 2)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(AppColors.backgroundCard)
        )
    }
}

// ── Lối vào từ tab Học ───────────────────────────────────────────
//
// ⚠️ Bản đầu tôi chỉ để một biểu tượng 🌐 nhỏ trên thanh công cụ. Người
// dùng KHÔNG TÌM RA — và đó là mục họ mong đợi nhất trong cả app. Thanh
// công cụ là chỗ để những thứ phụ trợ; một mảng chức năng lớn phải có mặt
// ngay trong thân trang, cùng cỡ với Academy.
struct NgoaiNguEntryCard: View {
    var body: some View {
        NavigationLink {
            NgonNguView()
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "character.book.closed.fill")
                    .font(.system(size: 22))
                    .foregroundColor(AppColors.onPrimary)
                    .frame(width: 46, height: 46)
                    .background(
                        LinearGradient(colors: [Color(hex: 0x0E93A6), Color(hex: 0x21D4ED)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text("Ngoại ngữ")
                            .font(.titleSmall)
                            .foregroundColor(AppColors.textPrimary)
                        Text("🇬🇧 🇯🇵 🇨🇳").font(.system(size: 12))
                    }
                    Text("25.000+ từ vựng · thẻ ghi nhớ · ôn tập theo lịch")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: Spacing.sm)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(Spacing.md)
            .background(AppColors.backgroundCard)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(AppColors.secondary.opacity(0.3), lineWidth: 1),
            )
            .cornerRadius(CornerRadius.medium)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.md)
    }
}
