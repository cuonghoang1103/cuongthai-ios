import SwiftUI

// ── Bảng chữ cái ────────────────────────────────────────────────
//
// Chạm một chữ → mở màn luyện viết bằng ngón tay.

struct BangChuView: View {
    let ngonNgu: NgonNgu

    @State private var nhom: [NhomChu] = []
    @State private var dangTai = true
    @State private var loi: String?
    @State private var chonNhom: Int?
    @State private var chuDangViet: NhomChu.ChuCai?
    @ObservedObject private var doc = DocTu.shared

    private let cot = [GridItem(.adaptive(minimum: 64), spacing: 10)]

    private var nhomHienThi: NhomChu? {
        guard let id = chonNhom else { return nhom.first }
        return nhom.first { $0.id == id } ?? nhom.first
    }

    var body: some View {
        ScrollView {
            if dangTai {
                ProgressView().padding(.top, Spacing.xxl)
            } else if nhom.isEmpty {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "textformat")
                        .font(.system(size: 38))
                        .foregroundColor(AppColors.textTertiary)
                    Text(loi ?? "Ngôn ngữ này chưa có bảng chữ.")
                        .font(.body)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Spacing.xxl).padding(.horizontal, Spacing.lg)
            } else {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    thanhNhom

                    if let n = nhomHienThi {
                        if let mo = n.description, !mo.isEmpty {
                            Text(mo)
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        LazyVGrid(columns: cot, spacing: 10) {
                            ForEach(n.chu) { c in
                                oChu(c)
                            }
                        }
                    }
                }
                .padding(Spacing.md)
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Bảng chữ")
        .navigationBarTitleDisplayMode(.inline)
        .task { await tai() }
        .fullScreenCover(item: $chuDangViet) { c in
            LuyenVietView(chu: c.character,
                          phienAm: c.romanization,
                          // Máy chủ nói rõ: ja và zh bất đồng về vài chữ
                          // (気 vs 氣), nên phải truyền đúng thứ tiếng.
                          lang: ngonNgu.code == "zh" ? "zh" : "ja")
        }
    }

    private var thanhNhom: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(nhom) { n in
                    let chon = (nhomHienThi?.id == n.id)
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { chonNhom = n.id }
                        Haptics.cham()
                    } label: {
                        Text(n.name)
                            .font(.system(size: 13, weight: chon ? .semibold : .regular))
                            .foregroundColor(chon ? .white : AppColors.textSecondary)
                            .lineLimit(1)
                            .padding(.horizontal, 13).padding(.vertical, 7)
                            .background(Capsule().fill(chon ? AppColors.primary
                                                            : AppColors.backgroundTertiary))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func oChu(_ c: NhomChu.ChuCai) -> some View {
        Button {
            chuDangViet = c
        } label: {
            VStack(spacing: 2) {
                Text(c.character)
                    .font(.system(size: 27))
                    .foregroundColor(AppColors.textPrimary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                if let r = c.romanization, !r.isEmpty {
                    Text(r)
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(AppColors.backgroundCard)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Giữ để NGHE, chạm để VIẾT. Hai việc khác nhau nên hai cử chỉ khác
        // nhau — nhét cả hai vào một nút thì phải thêm nút loa vào ô 62pt,
        // vừa chật vừa dễ bấm nhầm.
        .onLongPressGesture(minimumDuration: 0.3) {
            if DocTu.doDuoc(ngonNgu.code) {
                doc.doc(c.character, code: ngonNgu.code, id: c.id)
                Haptics.cham()
            }
        }
        .accessibilityLabel("\(c.character) \(c.romanization ?? ""), chạm để luyện viết")
    }

    private func tai() async {
        dangTai = true; defer { dangTai = false }
        do {
            nhom = try await APIClient.shared.request(.bangChu(code: ngonNgu.code))
            loi = nil
        } catch { loi = error.localizedDescription }
    }
}
