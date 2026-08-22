import SwiftUI

// MARK: - Bảng xếp hạng tuần

struct BangXepHangView: View {
    let ngonNgu: NgonNgu
    @State private var bang: BangXepHang?
    @State private var dangTai = true
    @State private var loi: String?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.sm) {
                if dangTai {
                    ProgressView().padding(.top, Spacing.xxl)
                } else if let b = bang, !b.entries.isEmpty {
                    Text("Tính theo XP kiếm được trong tuần \(b.week). Đầu tuần mới là về 0.")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, Spacing.xs)

                    ForEach(b.entries) { e in hang(e) }

                    // Ngoài top 50 thì vẫn phải thấy mình đứng đâu — không thì
                    // bảng xếp hạng chỉ có ý nghĩa với người đang dẫn đầu.
                    if let me = b.me, !b.entries.contains(where: { $0.isMe }) {
                        Text("Vị trí của bạn")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, Spacing.md)
                        hang(me)
                    }
                } else {
                    trong
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Bảng xếp hạng")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            dangTai = true
            do { bang = try await APIClient.shared.request(.bangXepHang(code: ngonNgu.code)) }
            catch { loi = error.localizedDescription }
            dangTai = false
        }
    }

    private var trong: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "trophy").font(.system(size: 40))
                .foregroundColor(AppColors.textTertiary)
            Text(loi ?? "Tuần này chưa ai kiếm được XP nào. Học một bài là bạn đứng đầu.")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Spacing.xxl)
    }

    private func hang(_ e: HangNguoiChoi) -> some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                if e.rank <= 3 {
                    Image(systemName: "medal.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: [0xF59E0B, 0x94A3B8, 0xB45309][e.rank - 1]))
                } else {
                    Text("\(e.rank)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .frame(width: 30)

            UserAvatarView(url: e.avatarUrl, size: 36)

            Text(e.name)
                .font(.system(size: 15, weight: e.isMe ? .bold : .medium))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)

            Spacer(minLength: Spacing.sm)

            Text("\(e.weeklyXp) XP")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(hex: 0xF59E0B))
        }
        .padding(Spacing.sm + 2)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(e.isMe ? AppColors.primary.opacity(0.12) : AppColors.backgroundCard)
        )
    }
}

// MARK: - Thành tích

struct ThanhTichView: View {
    let ngonNgu: NgonNgu
    @State private var tt: ThanhTich?
    @State private var dangTai = true
    @State private var loi: String?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                if dangTai {
                    ProgressView().padding(.top, Spacing.xxl)
                } else if let t = tt {
                    tongKet(t)
                    Text("HUY HIỆU — ĐÃ ĐẠT \(t.earnedCount)/\(t.badges.count)")
                        .font(.system(size: 11, weight: .bold))
                        .kerning(0.6)
                        .foregroundColor(AppColors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(t.badges) { h in huyHieu(h) }
                    }
                } else {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "rosette").font(.system(size: 40))
                            .foregroundColor(AppColors.textTertiary)
                        Text(loi ?? "Chưa có thành tích nào.")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.top, Spacing.xxl)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Thành tích")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            dangTai = true
            do { tt = try await APIClient.shared.request(.thanhTich(code: ngonNgu.code)) }
            catch { loi = error.localizedDescription }
            dangTai = false
        }
    }

    private func tongKet(_ t: ThanhTich) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                  spacing: Spacing.sm) {
            o("\(t.totals.xp)", "tổng XP", 0xF59E0B)
            o("\(t.level.level)", "cấp", 0x8C5AF0)
            o("\(t.totals.longestStreak)", "chuỗi dài nhất", 0xE5484D)
            o("\(t.totals.lessonsPlayed)", "bài đã chơi", 0x0E93A6)
            o("\(t.totals.lessonsPassed)", "bài đạt", 0x2BA84A)
            o("\(t.totals.goldCrowns)", "vương miện vàng", 0xD97706)
        }
    }

    private func o(_ so: String, _ nhan: String, _ mau: UInt32) -> some View {
        VStack(spacing: 3) {
            Text(so)
                .font(.system(size: 20, weight: .black))
                .foregroundColor(Color(hex: mau))
                .lineLimit(1).minimumScaleFactor(0.5)
            Text(nhan)
                .font(.system(size: 10))
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundCard))
    }

    private func huyHieu(_ h: HuyHieu) -> some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color(hex: h.mau).opacity(h.earned ? 0.18 : 0.07))
                    .frame(width: 46, height: 46)
                Image(systemName: h.bieuTuong)
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: h.mau).opacity(h.earned ? 1 : 0.4))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(h.label)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(h.earned ? AppColors.textPrimary : AppColors.textSecondary)
                Text(h.description)
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                if !h.earned {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppColors.backgroundTertiary)
                            Capsule().fill(Color(hex: h.mau))
                                .frame(width: g.size.width * min(1, max(0, h.progress)))
                        }
                    }
                    .frame(height: 5)
                    Text("\(h.current)/\(h.goal)")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            Spacer(minLength: 0)
            if h.earned {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 17))
                    .foregroundColor(AppColors.success)
            }
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large)
            .fill(AppColors.backgroundCard))
    }
}
