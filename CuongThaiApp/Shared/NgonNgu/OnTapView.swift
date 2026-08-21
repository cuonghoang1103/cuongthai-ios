import SwiftUI

// ════════════════════════════════════════════════════════════════
// ÔN TẬP THEO LỊCH (SRS)
//
// Máy chủ dùng SM-2 (`recordProgress`): người học tự chấm 0-5, thuật toán
// tính ngày gặp lại. Ở đây rút xuống BỐN nút.
//
// Vì sao không sáu: sáu mức làm người ta đứng cân nhắc "3 hay 4 đây" lâu
// hơn cả thời gian nhớ ra từ, mà chính lúc cân nhắc đó lại phá mất phép đo
// — họ đã nhìn đáp án thêm mấy giây rồi.
// ════════════════════════════════════════════════════════════════

struct OnTapView: View {
    let ngonNgu: NgonNgu
    @StateObject private var vm: OnTapVM
    @ObservedObject private var doc = DocTu.shared
    @Environment(\.dismiss) private var dismiss

    init(ngonNgu: NgonNgu) {
        self.ngonNgu = ngonNgu
        _vm = StateObject(wrappedValue: OnTapVM(code: ngonNgu.code))
    }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            if vm.dangTai && vm.hang.isEmpty {
                ProgressView()
            } else if vm.xong {
                manXong
            } else if let muc = vm.hienTai, let t = muc.word {
                VStack(spacing: 0) {
                    tienDo
                    Spacer()
                    the(t)
                    Spacer()
                    if vm.lat { nutCham } else { nutXemDapAn }
                }
            } else if let loi = vm.loi {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 34))
                        .foregroundColor(AppColors.warning)
                    Text(loi)
                        .font(.body)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(Spacing.lg)
            }
        }
        .navigationTitle("Ôn tập")
        .navigationBarTitleDisplayMode(.inline)
        .task { if vm.hang.isEmpty { await vm.tai() } }
    }

    private var tienDo: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(AppColors.backgroundTertiary)
                Capsule().fill(AppColors.primary)
                    .frame(width: g.size.width * CGFloat(vm.viTri) / CGFloat(max(vm.hang.count, 1)))
            }
        }
        .frame(height: 4)
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
    }

    private func the(_ t: TuNgoaiNgu) -> some View {
        VStack(spacing: Spacing.md) {
            Text(t.word)
                .font(.system(size: 44, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.4)

            // ⚠️ PHIÊN ÂM CHỈ HIỆN SAU KHI LẬT.
            //
            // Nó là một nửa đáp án: thấy "ohayou" là đọc được ngay, chẳng
            // còn gì để nhớ. Hiện sẵn thì phép đo SRS đo nhầm — người học
            // tưởng mình thuộc trong khi chỉ đang đọc theo.
            if vm.lat {
                if let pa = t.phienAm {
                    Text(pa)
                        .font(.system(size: 19))
                        .foregroundColor(AppColors.secondary)
                }
                Text(t.nghia)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)

                if let vd = t.exampleSentence, !vd.isEmpty, vd != t.word {
                    Text(vd)
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }

                if DocTu.doDuoc(ngonNgu.code) {
                    Button {
                        doc.doc(t.word, code: ngonNgu.code, id: t.id)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(Circle().fill(AppColors.primary))
                    }
                    .padding(.top, Spacing.sm)
                    .accessibilityLabel("Nghe cách đọc")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
    }

    private var nutXemDapAn: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { vm.lat = true }
        } label: {
            Text("Xem đáp án")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Capsule().fill(AppColors.primary))
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.xl)
    }

    private var nutCham: some View {
        VStack(spacing: Spacing.sm) {
            Text("Bạn nhớ từ này tới đâu?")
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)

            HStack(spacing: Spacing.sm) {
                ForEach(MucNho.allCases, id: \.rawValue) { m in
                    Button {
                        Task { await vm.cham(m) }
                    } label: {
                        VStack(spacing: 2) {
                            Text(m.nhan)
                                .font(.system(size: 14, weight: .semibold))
                            Text(m.uocLuong)
                                .font(.system(size: 10))
                                .opacity(0.85)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(Color(hex: m.mau))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.xl)
    }

    private var manXong: some View {
        VStack(spacing: Spacing.md) {
            Text(vm.daHoc > 0 ? "🎉" : "✅").font(.system(size: 56))
            Text(vm.daHoc > 0 ? "Ôn xong \(vm.daHoc) từ" : "Chưa có từ nào tới hạn")
                .font(.system(size: 21, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            Text(vm.daHoc > 0
                 ? "Hẹn gặp lại những từ này đúng lúc bạn sắp quên."
                 : "Học thêm từ mới ở các chủ đề, rồi chúng sẽ tự xuất hiện ở đây theo lịch.")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            Button("Quay lại") { dismiss() }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, Spacing.lg).padding(.vertical, Spacing.sm + 2)
                .background(Capsule().fill(AppColors.primary))
                .padding(.top, Spacing.sm)
        }
    }
}
