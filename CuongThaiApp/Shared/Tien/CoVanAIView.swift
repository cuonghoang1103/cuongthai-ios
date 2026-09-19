import SwiftUI

/// Cố vấn tiền nong — AI đọc số liệu THẬT rồi nhận xét, và hỏi đáp tự do.
///
/// Số liệu do MÁY CHỦ tính (`soLieuCoVan` trong `coVan.service.ts`), model chỉ
/// diễn giải. Thiếu khoá AI thì phần chữ trống nhưng các con số vẫn hiện —
/// chúng mới là phần đắt giá.
struct CoVanAIView: View {
    @ObservedObject var vm: TienVM
    @Environment(\.dismiss) private var dong

    @State private var loiThoai: [DongCoVan] = []
    @State private var cauHoi = ""
    @State private var dangHoi = false

    struct DongCoVan: Identifiable {
        let id = UUID()
        let cuaToi: Bool
        let chu: String
    }

    private let goiY = [
        "Tôi nên trả khoản nợ nào trước?",
        "Tháng này tôi tiêu quá tay chỗ nào?",
        "Với mức thu này tôi để dành được bao nhiêu mỗi tháng?",
        "Tình hình tiền nong của tôi đang ổn hay đáng lo?",
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { cuon in
                    ScrollView {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            theTomTat
                            ForEach(loiThoai) { d in dongChat(d) }
                            if dangHoi {
                                HStack(spacing: 6) {
                                    ProgressView().scaleEffect(0.8)
                                    Text(T("Đang xem số liệu…"))
                                        .font(.caption).foregroundStyle(AppColors.textTertiary)
                                }
                            }
                            if loiThoai.isEmpty { khoiGoiY }
                            Color.clear.frame(height: 1).id("cuoi")
                        }
                        .padding(Spacing.md)
                    }
                    .onChange(of: loiThoai.count) { _, _ in
                        withAnimation { cuon.scrollTo("cuoi", anchor: .bottom) }
                    }
                }

                oNhap
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle(T("AI quản lí tiền"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Đóng")) { dong() } }
            }
            .task {
                if vm.nhanXetAI == nil { await vm.hoiAITomTat() }
            }
        }
    }

    // MARK: - Thẻ tóm tắt

    private var theTomTat: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundStyle(AppColors.primary)
                Text(T("Nhận xét")).font(.titleSmall).foregroundStyle(AppColors.textPrimary)
                Spacer()
                Button { Task { await vm.hoiAITomTat() } } label: {
                    Image(systemName: "arrow.clockwise").font(.caption)
                }
                .disabled(vm.dangHoiAI)
            }

            if vm.dangHoiAI && vm.nhanXetAI == nil {
                HStack { ProgressView().scaleEffect(0.8); Text(T("Đang xem…")).font(.caption) }
            } else if let n = vm.nhanXetAI, !n.isEmpty {
                NoiDungMarkdown(noiDung: n)
            } else if vm.thieuKhoaAI {
                Text(T("Phần nhận xét bằng AI đang tắt. Các con số bên dưới vẫn đúng và vẫn dùng được."))
                    .font(.bodySmall).foregroundStyle(AppColors.textSecondary)
            } else {
                Text(T("Chưa có nhận xét."))
                    .font(.bodySmall).foregroundStyle(AppColors.textTertiary)
            }

            Divider()
            soNhanh
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    private var soNhanh: some View {
        HStack(spacing: Spacing.sm) {
            oSo(T("Số dư"), vm.bang?.totalBalance ?? 0, AppColors.primary)
            oSo(T("Nợ"), vm.bang?.totalRemainingDebt ?? 0, AppColors.warning)
            oSo(T("Để dành"), vm.bang?.savingsThisMonth ?? 0,
                (vm.bang?.savingsThisMonth ?? 0) >= 0 ? AppColors.success : AppColors.error)
        }
    }

    private func oSo(_ nhan: String, _ v: Double, _ mau: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(nhan).font(.caption2).foregroundStyle(AppColors.textTertiary)
            Text(DinhDangTien.ngan(v))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(mau).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Gợi ý & hội thoại

    private var khoiGoiY: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(T("Hỏi thử")).font(.captionBold).foregroundStyle(AppColors.textSecondary)
            ForEach(goiY, id: \.self) { g in
                Button { Task { await hoi(T(g)) } } label: {
                    HStack {
                        Text(T(g)).font(.bodySmall).foregroundStyle(AppColors.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right").font(.caption2)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                    .padding(Spacing.sm + 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.backgroundCard)
                    .cornerRadius(CornerRadius.medium)
                }
                .buttonStyle(.plain)
                .disabled(dangHoi)
            }
        }
    }

    private func dongChat(_ d: DongCoVan) -> some View {
        HStack {
            if d.cuaToi { Spacer(minLength: 40) }
            // Câu của MÌNH là chữ mình vừa gõ — vẽ thẳng. Câu của AI mới
            // cần dựng markdown; đưa chữ người dùng qua bộ dựng thì một dấu
            // sao họ gõ thật sẽ biến mất.
            Group {
                if d.cuaToi {
                    Text(d.chu).font(.bodyMedium).foregroundStyle(Color.white)
                } else {
                    NoiDungMarkdown(noiDung: d.chu)
                }
            }
                .fixedSize(horizontal: false, vertical: true)
                .padding(Spacing.sm + 2)
                .background(d.cuaToi ? AppColors.primary : AppColors.backgroundCard)
                .cornerRadius(CornerRadius.large)
            if !d.cuaToi { Spacer(minLength: 40) }
        }
    }

    private var oNhap: some View {
        HStack(spacing: Spacing.sm) {
            TextField(T("Hỏi về tiền của bạn…"), text: $cauHoi, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, Spacing.sm + 2)
                .padding(.vertical, Spacing.sm)
                .background(AppColors.backgroundTertiary)
                .cornerRadius(CornerRadius.large)
                .onSubmit { Task { await hoi(cauHoi) } }

            Button { Task { await hoi(cauHoi) } } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(guiDuoc ? AppColors.primary : AppColors.textTertiary)
            }
            .disabled(!guiDuoc)
        }
        .padding(Spacing.sm + 2)
        .background(AppColors.backgroundSecondary)
    }

    private var guiDuoc: Bool {
        !dangHoi && cauHoi.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    private func hoi(_ c: String) async {
        let t = c.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 2, !dangHoi else { return }
        cauHoi = ""
        loiThoai.append(DongCoVan(cuaToi: true, chu: t))
        dangHoi = true
        defer { dangHoi = false }
        do {
            let kq = try await TienAPI.aiHoi(t)
            loiThoai.append(DongCoVan(
                cuaToi: false,
                chu: kq.chu ?? (kq.thieuKhoaAI
                    ? T("Phần trả lời bằng AI đang tắt trên máy chủ.")
                    : T("Chưa có câu trả lời."))))
        } catch {
            loiThoai.append(DongCoVan(cuaToi: false, chu: error.localizedDescription))
        }
    }
}
