import SwiftUI

struct BaoCaoPhongVanView: View {
    let phienId: Int
    let tua: String
    @State private var bc: BaoCaoPV?
    @State private var dangTai = true
    @State private var loi: String?
    @State private var moLuot: Set<Int> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                NeoDauTrang()
                if dangTai {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, Spacing.xl * 2)
                } else if let e = loi {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "doc.questionmark").font(.system(size: 40))
                            .foregroundColor(AppColors.textTertiary)
                        Text(e).font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.top, Spacing.xl * 2)
                } else if let b = bc {
                    if let r = b.report { khoiTong(r) }
                    ForEach(b.cacLuot) { l in khoiLuot(l) }
                }
                Color.clear.frame(height: 72)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(T("Báo cáo"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await nap() }
    }

    private func nap() async {
        dangTai = true; defer { dangTai = false }
        do { bc = try await APIClient.shared.request(.pvBaoCao(id: phienId)) }
        catch {
            // ⚠️ ĐỪNG nuốt lỗi thành một câu cố định. Bản đầu tôi viết
            // `catch { loi = "Chưa có báo cáo" }` và nó NÓI DỐI: phiên có báo
            // cáo hẳn hoi (lịch sử hiện 98 điểm, hạng A), thứ hỏng là bản giải
            // mã. Thông báo sai làm tôi đi tìm nhầm chỗ mất mấy phút.
            NhatKy.sach.error("báo cáo \(phienId): \(error)")
            let m = error.localizedDescription
            loi = m.contains("404") ? T("Chưa có báo cáo cho phiên này.") : m
        }
    }

    // MARK: Tổng quan

    private func khoiTong(_ r: NoiDungBaoCao) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .center, spacing: Spacing.md) {
                VStack(spacing: 0) {
                    Text(String(format: "%.0f", r.overallScore ?? 0))
                        .font(.system(size: 40, weight: .heavy).monospacedDigit())
                        .foregroundColor(diemMau(r.overallScore ?? 0))
                    Text("/100").font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(tua.isEmpty ? T("Phiên phỏng vấn") : tua)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    HStack(spacing: 5) {
                        if let g = r.letterGrade {
                            Text(g).font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                                .padding(.horizontal, 7).padding(.vertical, 2.5)
                                .background(Capsule().fill(diemMau(r.overallScore ?? 0)))
                        }
                        if let n = r.nhanTuyen {
                            Text(n).font(.system(size: 11, weight: .bold))
                                .foregroundColor(r.mauTuyen)
                                .padding(.horizontal, 7).padding(.vertical, 2.5)
                                .background(Capsule().fill(r.mauTuyen.opacity(0.15)))
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            if !r.diemManh.isEmpty { danhSach(T("Điểm mạnh"), r.diemManh, "checkmark.circle.fill", Color(hex: 0x22C55E)) }
            if !r.diemYeu.isEmpty { danhSach(T("Cần cải thiện"), r.diemYeu, "exclamationmark.circle.fill", Color(hex: 0xF59E0B)) }
            if let a = r.actionableAdvice, !a.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label(T("Nên làm gì tiếp"), systemImage: "arrow.forward.circle.fill")
                        .font(.system(size: 11, weight: .bold)).foregroundColor(AppColors.primary)
                    // ⚠️ `actionableAdvice` là MARKDOWN (`## Immediate
                    // Actions`, danh sách đánh số, khối mã) — in bằng `Text`
                    // thì người đọc thấy nguyên dấu `##` và ``` .
                    NoiDungMarkdown(noiDung: a)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    private func danhSach(_ ten: String, _ ds: [String], _ hinh: String, _ mau: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(ten, systemImage: hinh)
                .font(.system(size: 11, weight: .bold)).foregroundColor(mau)
            ForEach(ds, id: \.self) { t in
                HStack(alignment: .top, spacing: 7) {
                    Circle().fill(mau).frame(width: 4, height: 4).padding(.top, 6)
                    Text(t).font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: Từng câu

    private func khoiLuot(_ l: LuotBaoCao) -> some View {
        let mo = moLuot.contains(l.order)
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    if mo { moLuot.remove(l.order) } else { moLuot.insert(l.order) }
                }
            } label: {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Text("\(l.order + 1)")
                        .font(.system(size: 11, weight: .heavy).monospacedDigit())
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(diemMau(l.diem ?? 0)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.questionText ?? "—")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(mo ? nil : 2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 6) {
                            if let t = l.topic { Text(t).font(.system(size: 10)).foregroundColor(AppColors.textTertiary) }
                            if l.needsReview == true {
                                Text(T("Cần rà lại")).font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Color(hex: 0xF59E0B))
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    if let d = l.diem {
                        Text(String(format: "%.0f", d))
                            .font(.system(size: 14, weight: .bold).monospacedDigit())
                            .foregroundColor(diemMau(d))
                    }
                    Image(systemName: mo ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold)).foregroundColor(AppColors.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if mo {
                if let a = l.userAnswer, !a.isEmpty {
                    doan(T("Bạn trả lời"), a, AppColors.textSecondary)
                }
                if let r = l.referenceAnswer, !r.isEmpty {
                    doan(T("Đáp án tham khảo"), r, Color(hex: 0x22C55E))
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    private func doan(_ ten: String, _ chu: String, _ mau: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(ten.uppercased())
                .font(.system(size: 9.5, weight: .bold)).tracking(0.5).foregroundColor(mau)
            Text(chu).font(.system(size: 12.5))
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundTertiary.opacity(0.5)))
    }
}
