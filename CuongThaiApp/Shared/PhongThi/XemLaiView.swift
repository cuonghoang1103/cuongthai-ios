import SwiftUI

// MARK: - Xem lại từng câu

struct XemLaiView: View {
    let xemLai: XemLaiBaiThi
    let tenDe: String

    @State private var chiCauSai = false
    @State private var daDanhDau: Set<Int> = []

    private var cau: [CauHoiXemLai] {
        let ds = xemLai.questions.sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
        return chiCauSai ? ds.filter { !$0.lamDung } : ds
    }
    private var soSai: Int { xemLai.questions.filter { !$0.lamDung }.count }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.md) {
                tomTat
                ForEach(Array(cau.enumerated()), id: \.element.id) { i, c in
                    theCau(c, so: (c.sortOrder ?? i) + 1)
                }
                if cau.isEmpty {
                    Text("Không có câu nào sai. Trọn vẹn!")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.success)
                        .padding(.top, Spacing.xl)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Xem lại")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            daDanhDau = Set(xemLai.questions.filter { $0.bookmarked == true }.map(\.id))
        }
    }

    private var tomTat: some View {
        VStack(spacing: Spacing.sm) {
            Text(tenDe)
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            HStack(spacing: Spacing.lg) {
                o(String(format: "%.2g", xemLai.diem), "điểm", xemLai.dat ? 0x2BA84A : 0xF59E0B)
                if let d = xemLai.soDung, let t = xemLai.soCau { o("\(d)/\(t)", "câu đúng", 0x0E93A6) }
                o("\(soSai)", "câu sai", 0xE5484D)
            }
            // Lọc câu sai là việc người ta muốn làm ngay sau khi thi xong —
            // đọc lại 40 câu đã đúng chỉ để tìm 5 câu sai thì không ai đọc.
            Toggle("Chỉ hiện câu làm sai", isOn: $chiCauSai)
                .font(.system(size: 14))
                .tint(AppColors.primary)
                .padding(.top, Spacing.xs)
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large)
            .fill(AppColors.backgroundCard))
    }

    private func o(_ so: String, _ nhan: String, _ mau: UInt32) -> some View {
        VStack(spacing: 2) {
            Text(so).font(.system(size: 20, weight: .black)).foregroundColor(Color(hex: mau))
            Text(nhan).font(.system(size: 10)).foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func theCau(_ c: CauHoiXemLai, so: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Text("Câu \(so)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.onPrimary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(nhanMau(c)))
                if c.boTrong {
                    Text("bỏ trống")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.warning)
                }
                Spacer()
                Button {
                    Task { await lat(c) }
                } label: {
                    Image(systemName: daDanhDau.contains(c.id) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 15))
                        .foregroundColor(daDanhDau.contains(c.id) ? Color(hex: 0xF59E0B) : AppColors.textTertiary)
                }
                .buttonStyle(.plain)
            }

            NoiDungThi(chu: c.prompt, coChu: 15)

            if let ds = c.options, !ds.isEmpty {
                VStack(spacing: Spacing.xs) {
                    ForEach(Array(ds.enumerated()), id: \.offset) { i, lc in
                        hangLuaChon(lc.text, i: i, c: c)
                    }
                }
            } else if let chu = c.myAnswer?.chu, !chu.isEmpty {
                // Câu code/tự luận: hiện đúng thứ mình đã nộp, không phán
                // đúng sai — chấm là việc của người chấm.
                KhoiMaNguon(ma: chu, ngonNgu: nil, tieuDe: "Bài bạn đã nộp", choChep: false)
            }

            if let gt = c.explanation, !gt.isEmpty {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: 0xD97706))
                    // Lời giải cũng song ngữ và cũng có thể mang công thức.
                    NoiDungThi(chu: gt, coChu: 13, mauChu: AppColors.textSecondary)
                }
                .padding(Spacing.sm + 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(Color(hex: 0xD97706).opacity(0.10)))
            }
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large)
            .fill(AppColors.backgroundCard))
    }

    private func nhanMau(_ c: CauHoiXemLai) -> Color {
        guard c.laTracNghiem else { return AppColors.textTertiary }
        return c.lamDung ? AppColors.success : AppColors.error
    }

    /// Đáp án ĐÚNG luôn sáng lên, kể cả khi người ta chọn sai — không thấy
    /// đáp án đúng thì xem lại chẳng học được gì.
    private func hangLuaChon(_ chu: String, i: Int, c: CauHoiXemLai) -> some View {
        let dung = c.dapAnDung.contains(i)
        let daChon = c.daChon.contains(i)
        let mau: Color = dung ? AppColors.success : (daChon ? AppColors.error : AppColors.border)
        let nen: Color = dung ? AppColors.success.opacity(0.12)
            : (daChon ? AppColors.error.opacity(0.12) : Color.clear)

        return HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: dung ? "checkmark.circle.fill"
                  : (daChon ? "xmark.circle.fill" : "circle"))
                .font(.system(size: 15))
                .foregroundColor(dung ? AppColors.success
                                 : (daChon ? AppColors.error : AppColors.textTertiary))
            NoiDungThi(chu: chu, coChu: 14)
            Spacer(minLength: 0)
            if daChon && !dung {
                Text("bạn chọn")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppColors.error)
            }
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.small).fill(nen))
        .overlay(RoundedRectangle(cornerRadius: CornerRadius.small)
            .strokeBorder(mau.opacity(dung || daChon ? 0.7 : 0), lineWidth: 1.5))
    }

    private func lat(_ c: CauHoiXemLai) async {
        struct R: Codable { let bookmarked: Bool }
        let truoc = daDanhDau
        if daDanhDau.contains(c.id) { daDanhDau.remove(c.id) } else { daDanhDau.insert(c.id) }
        do {
            let r: R = try await APIClient.shared.request(.danhDauCauHoi(questionId: c.id))
            if r.bookmarked { daDanhDau.insert(c.id) } else { daDanhDau.remove(c.id) }
        } catch {
            daDanhDau = truoc
        }
    }
}
