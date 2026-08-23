import SwiftUI

// ════════════════════════════════════════════════════════════════
// LUYỆN VIẾT — AI CHẤM BÀI
//
// `POST /my-language/ai/writing`. Đây là mảnh cuối của lộ trình: 4 trong 38
// nút lộ trình tiếng Anh có `linkType = writing` và trước 24/08/2026 chúng mở
// ra màn TRỐNG vì app chưa có gì cho loại này.
//
// ⚠️ ĐỪNG nhầm với `LuyenVietView` — cái kia là viết CHỮ bằng ngón tay (nét
// chữ Hán, bảng chữ). Hai thứ trùng tên tiếng Việt nhưng khác hẳn nhau.
// ════════════════════════════════════════════════════════════════

struct ChamBaiVietView: View {
    let ngonNgu: NgonNgu

    /// Trần của máy chủ: `text.length > 4000` là `BadRequestError`. Chặn ở
    /// đây để người học không gõ xong 20 phút rồi mới nhận lỗi.
    private static let tranKyTu = 4000

    @State private var deBai = ""
    @State private var bai = ""
    @State private var kq: ChamBaiViet?
    @State private var dangCham = false
    @State private var loi: String?
    @FocusState private var dangGo: Bool

    private var soKyTu: Int { bai.count }
    private var guiDuoc: Bool {
        !bai.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && soKyTu <= Self.tranKyTu && !dangCham
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                oDeBai
                oBaiViet
                nutCham
                if let l = loi { hopLoi(l) }
                if let k = kq { ketQua(k) }
                Spacer(minLength: Spacing.xl)
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Luyện viết")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Xong") { dangGo = false }
            }
        }
    }

    // ── Nhập ─────────────────────────────────────────────────────
    private var oDeBai: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("ĐỀ BÀI (không bắt buộc)")
                .font(.system(size: 10, weight: .bold)).kerning(0.5)
                .foregroundColor(AppColors.textTertiary)
            TextField("Ví dụ: Viết 100 từ về kỳ nghỉ gần nhất", text: $deBai)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(Spacing.sm + 2)
                .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(AppColors.backgroundCard))
        }
    }

    private var oBaiViet: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text("BÀI VIẾT CỦA BẠN")
                    .font(.system(size: 10, weight: .bold)).kerning(0.5)
                    .foregroundColor(AppColors.textTertiary)
                Spacer()
                Text("\(soKyTu)/\(Self.tranKyTu)")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundColor(soKyTu > Self.tranKyTu ? AppColors.error : AppColors.textTertiary)
            }
            TextEditor(text: $bai)
                .focused($dangGo)
                .font(.system(size: 15))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 200)
                .padding(Spacing.sm)
                .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(AppColors.backgroundCard))
                .overlay(alignment: .topLeading) {
                    // `TextEditor` không có placeholder — tự vẽ, và phải cho
                    // chạm xuyên qua bằng `allowsHitTesting(false)`.
                    if bai.isEmpty {
                        Text("Viết bằng \(ngonNgu.name)…")
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.textTertiary)
                            .padding(.horizontal, Spacing.sm + 5)
                            .padding(.vertical, Spacing.sm + 8)
                            .allowsHitTesting(false)
                    }
                }
            if soKyTu > Self.tranKyTu {
                Text("Máy chủ chỉ nhận tối đa \(Self.tranKyTu) ký tự — cắt bớt \(soKyTu - Self.tranKyTu) ký tự.")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.error)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var nutCham: some View {
        Button {
            dangGo = false
            Task { await cham() }
        } label: {
            HStack(spacing: Spacing.sm) {
                if dangCham { ProgressView().tint(.white) }
                Image(systemName: "checkmark.seal.fill")
                Text(dangCham ? "AI đang chấm…" : "Chấm bài")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(AppColors.onPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(guiDuoc ? AppColors.primary : AppColors.backgroundTertiary))
        }
        .buttonStyle(.plain)
        .disabled(!guiDuoc)
    }

    private func hopLoi(_ l: String) -> some View {
        Text(l)
            .font(.system(size: 13))
            .foregroundColor(AppColors.warning)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(AppColors.warning.opacity(0.12)))
    }

    private func cham() async {
        dangCham = true; loi = nil; defer { dangCham = false }
        do {
            kq = try await APIClient.shared.request(
                .aiChamBaiViet(code: ngonNgu.code,
                               chu: bai.trimmingCharacters(in: .whitespacesAndNewlines),
                               deBai: deBai.trimmingCharacters(in: .whitespaces))
            )
        } catch {
            kq = nil
            loi = error.localizedDescription
        }
    }

    // ── Kết quả ──────────────────────────────────────────────────
    private func ketQua(_ k: ChamBaiViet) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                Text("\(k.diem)")
                    .font(.system(size: 34, weight: .bold).monospacedDigit())
                    .foregroundColor(mauDiem(k.diem))
                VStack(alignment: .leading, spacing: 2) {
                    if !k.tenMuc.isEmpty {
                        Text(k.tenMuc)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                    }
                    if let lv = k.level, !lv.isEmpty {
                        Text("Trình độ ước lượng: \(lv)")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(AppColors.backgroundCard))

            if !k.nhanXet.isEmpty { khoi("NHẬN XÉT", k.nhanXet) }

            if !k.dsSua.isEmpty {
                Text("CHỖ CẦN SỬA (\(k.dsSua.count))")
                    .font(.system(size: 10, weight: .bold)).kerning(0.5)
                    .foregroundColor(AppColors.textTertiary)
                ForEach(k.dsSua) { s in hangSua(s) }
            }

            if let bs = k.banSua { khoi("BẢN ĐÃ SỬA", bs) }
        }
    }

    private func khoi(_ ten: String, _ chu: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(ten)
                .font(.system(size: 10, weight: .bold)).kerning(0.5)
                .foregroundColor(AppColors.textTertiary)
            Text(chu)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundCard))
    }

    private func hangSua(_ s: ChamBaiViet.Sua) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let o = s.original, !o.isEmpty {
                Text(o)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.error)
                    .strikethrough()
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .top, spacing: Spacing.xs) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.success)
                Text(s.suggestion ?? "")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.success)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let n = s.note, !n.isEmpty {
                Text(n)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundCard))
    }

    private func mauDiem(_ d: Int) -> Color {
        d >= 85 ? AppColors.success : (d >= 60 ? AppColors.warning : AppColors.error)
    }
}
