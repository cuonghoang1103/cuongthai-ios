import SwiftUI

// ════════════════════════════════════════════════════════════════
// THẺ GHI NHỚ
//
// Chạm để lật, vuốt để sang thẻ sau. Đây là chỗ điện thoại hơn hẳn web:
// một tay cầm máy, ngón cái làm hết.
// ════════════════════════════════════════════════════════════════

struct TheGhiNhoView: View {
    let tu: [TuNgoaiNgu]
    let ngonNgu: NgonNgu
    let chuDe: ChuDeTu?

    @Environment(\.dismiss) private var dismiss
    @State private var viTri = 0
    @State private var lat = false
    @State private var keo: CGFloat = 0
    @ObservedObject private var doc = DocTu.shared

    private var hienTai: TuNgoaiNgu? { viTri < tu.count ? tu[viTri] : nil }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                thanhDau

                Spacer()

                if let t = hienTai {
                    theTu(t)
                        .offset(x: keo)
                        .rotationEffect(.degrees(Double(keo) / 26))
                        .gesture(
                            DragGesture()
                                .onChanged { keo = $0.translation.width }
                                .onEnded { g in
                                    // 90pt: đủ xa để không nhầm với cú chạm
                                    // lệch tay, đủ gần để vuốt bằng ngón cái.
                                    if abs(g.translation.width) > 90 {
                                        sang(g.translation.width < 0 ? 1 : -1)
                                    } else {
                                        withAnimation(.spring(response: 0.3)) { keo = 0 }
                                    }
                                }
                        )
                } else {
                    manXong
                }

                Spacer()

                if hienTai != nil { thanhDuoi }
            }
        }
    }

    // ── Thẻ ─────────────────────────────────────────────────────
    private func theTu(_ t: TuNgoaiNgu) -> some View {
        VStack(spacing: Spacing.md) {
            if lat {
                Text(t.nghia)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)

                if let vd = t.exampleSentence, !vd.isEmpty, vd != t.word {
                    VStack(spacing: 4) {
                        Text(vd)
                            .font(.system(size: 17))
                            .foregroundColor(AppColors.textSecondary)
                        if let vn = t.exampleMeaning, !vn.isEmpty {
                            Text(vn)
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.sm)
                }

                if let n = t.note, !n.isEmpty {
                    Text(n)
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.accent)
                }
            } else {
                Text(t.word)
                    .font(.system(size: 46, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.4)

                if let pa = t.phienAm {
                    Text(pa)
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.secondary)
                }

                Text("Chạm để xem nghĩa")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.top, Spacing.sm)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 340)
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(AppColors.backgroundCard)
                .shadow(color: .black.opacity(0.14), radius: 14, y: 6)
        )
        .padding(.horizontal, Spacing.lg)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) { lat.toggle() }
            Haptics.cham()
        }
    }

    private var manXong: some View {
        VStack(spacing: Spacing.md) {
            Text("🎉").font(.system(size: 56))
            Text("Xong \(tu.count) từ")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            Button("Học lại từ đầu") {
                viTri = 0; lat = false
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, Spacing.lg).padding(.vertical, Spacing.sm + 2)
            .background(Capsule().fill(AppColors.primary))
        }
    }

    // ── Thanh trên / dưới ───────────────────────────────────────
    private var thanhDau: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Đóng")

                Spacer()
                Text("\(min(viTri + 1, tu.count)) / \(tu.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .monospacedDigit()
                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }

            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColors.backgroundTertiary)
                    Capsule().fill(AppColors.primary)
                        .frame(width: g.size.width * CGFloat(viTri) / CGFloat(max(tu.count, 1)))
                }
            }
            .frame(height: 4)
            .padding(.horizontal, Spacing.md)
        }
        .padding(.top, Spacing.sm)
    }

    private var thanhDuoi: some View {
        HStack(spacing: Spacing.xl) {
            Button { sang(-1) } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(viTri > 0 ? AppColors.textPrimary : AppColors.textTertiary)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(AppColors.backgroundTertiary))
            }
            .disabled(viTri == 0)
            .accessibilityLabel("Từ trước")

            if DocTu.doDuoc(ngonNgu.code), let t = hienTai {
                Button {
                    doc.doc(t.word, code: ngonNgu.code, id: t.id)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 21))
                        .foregroundColor(.white)
                        .frame(width: 62, height: 62)
                        .background(Circle().fill(AppColors.primary))
                }
                .accessibilityLabel("Nghe cách đọc")
            }

            Button { sang(1) } label: {
                Image(systemName: "arrow.right")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(AppColors.backgroundTertiary))
            }
            .accessibilityLabel("Từ sau")
        }
        .padding(.bottom, Spacing.xl)
    }

    private func sang(_ buoc: Int) {
        let moi = viTri + buoc
        guard moi >= 0, moi <= tu.count else {
            withAnimation(.spring(response: 0.3)) { keo = 0 }
            return
        }
        Haptics.cham()
        withAnimation(.easeOut(duration: 0.16)) {
            keo = buoc > 0 ? -420 : 420
        }
        // Đổi nội dung khi thẻ đã ra khỏi màn, rồi mới thả nó về giữa —
        // đặt lại `keo = 0` cùng lúc đổi từ thì thấy rõ thẻ nháy một cái.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(160))
            lat = false
            viTri = moi
            keo = 0
        }
    }
}
