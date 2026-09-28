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
        /// Câu hỏi đã sinh ra câu trả lời này — đi kèm báo cáo (A12).
        var cauHoi: String? = nil
        var kiemSo: KiemSoAI? = nil
        /// `true` = câu trả lời thật của AI (có nút báo cáo); `false` = dòng
        /// lỗi/thông báo của app.
        var laAI: Bool = false
    }

    /// Câu hỏi nhanh: máy chủ gợi ý theo đúng số liệu; rỗng thì dùng mặc định.
    private var goiY: [String] { vm.goiYAI.isEmpty ? goiYMacDinh : vm.goiYAI }

    private let goiYMacDinh = [
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

                if !loiThoai.isEmpty { hangGoiY }
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
                // Tuần tự (không async let — xem bài học "let+aw"): gợi ý về
                // trong vài trăm ms, nhận xét AI mới là phần chậm.
                await vm.napGoiYAI()
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
                dongKiemSo(vm.kiemSoTomTat)
                HStack {
                    Spacer()
                    NutBaoCaoTraLoiAI(nguon: "AI · Quản lí tiền",
                                      cauHoi: "Tóm tắt tình hình tài chính",
                                      traLoi: n)
                }
            } else if vm.thieuKhoaAI {
                Text(T("Phần nhận xét bằng AI đang tắt. Các con số bên dưới vẫn đúng và vẫn dùng được."))
                    .font(.bodySmall).foregroundStyle(AppColors.textSecondary)
            } else {
                Text(T("Chưa có nhận xét."))
                    .font(.bodySmall).foregroundStyle(AppColors.textTertiary)
            }

            Divider()
            soNhanh
            khoiCanhBao
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    @ViewBuilder
    private var soNhanh: some View {
        if let so = vm.soLieuAI {
            // Đúng bảng số máy chủ đưa cho AI — người dùng đối chiếu được.
            HStack(spacing: Spacing.sm) {
                oSo(T("Số dư"), so.tongSoDu, AppColors.primary)
                oSo(T("Nợ gốc"), so.tongNoConLai, AppColors.warning)
                oSo(T("Lãi còn trả"), so.tongLaiConPhaiTra ?? 0, AppColors.error)
                oSo(T("Còn lại"), so.deDanhThangNay,
                    so.deDanhThangNay >= 0 ? AppColors.success : AppColors.error)
            }
            Text(T("“Còn lại” = thu − chi − trả nợ tháng này."))
                .font(.caption2).foregroundStyle(AppColors.textTertiary)
        } else {
            HStack(spacing: Spacing.sm) {
                oSo(T("Số dư"), vm.bang?.totalBalance ?? 0, AppColors.primary)
                oSo(T("Nợ"), vm.bang?.totalRemainingDebt ?? 0, AppColors.warning)
                oSo(T("Để dành"), vm.bang?.savingsThisMonth ?? 0,
                    (vm.bang?.savingsThisMonth ?? 0) >= 0 ? AppColors.success : AppColors.error)
            }
        }
    }

    /// Cảnh báo do máy chủ chốt — cùng danh sách với màn Phân tích.
    @ViewBuilder
    private var khoiCanhBao: some View {
        let ds = vm.canhBaoAI.isEmpty ? (vm.phanTich?.canhBao ?? []) : vm.canhBaoAI
        if !ds.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "bell.badge.fill").foregroundStyle(MauTien.muc(MauTien.nangNhat(ds)))
                    Text(T("Cảnh báo")).font(.captionBold).foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    if ds.count > 4 {
                        NavigationLink { PhanTichView(vm: vm) } label: {
                            Text("\(T("Xem hết")) \(ds.count)").font(.caption).foregroundStyle(AppColors.primary)
                        }
                    }
                }
                ForEach(Array(ds.prefix(4))) { c in DongCanhBaoTien(vm: vm, c: c) }
            }
            .padding(.top, 4)
        }
    }

    /// Dòng nhỏ màu cam khi máy chủ thấy số trong câu trả lời không khớp bảng tính.
    @ViewBuilder
    private func dongKiemSo(_ k: KiemSoAI?) -> some View {
        if let k, k.hopLe == false {
            let ds = (k.soKhongKhop ?? []).prefix(6).joined(separator: ", ")
            Label("\(T("Có số không khớp bảng tính")): \(ds.isEmpty ? "…" : ds)",
                  systemImage: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(AppColors.accent)
                .fixedSize(horizontal: false, vertical: true)
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
        HStack(alignment: .top) {
            if d.cuaToi { Spacer(minLength: 40) }
            // Câu của MÌNH là chữ mình vừa gõ — vẽ thẳng. Câu của AI mới
            // cần dựng markdown; đưa chữ người dùng qua bộ dựng thì một dấu
            // sao họ gõ thật sẽ biến mất.
            Group {
                if d.cuaToi {
                    Text(d.chu).font(.bodyMedium).foregroundStyle(Color.white)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        NoiDungMarkdown(noiDung: d.chu)
                        dongKiemSo(d.kiemSo)
                        if d.laAI {
                            HStack {
                                Spacer()
                                NutBaoCaoTraLoiAI(nguon: "AI · Quản lí tiền",
                                                  cauHoi: d.cauHoi ?? "",
                                                  traLoi: d.chu)
                            }
                        }
                    }
                }
            }
                .fixedSize(horizontal: false, vertical: true)
                .padding(Spacing.sm + 2)
                .background(d.cuaToi ? AppColors.primary : AppColors.backgroundCard)
                .cornerRadius(CornerRadius.large)
            if !d.cuaToi { Spacer(minLength: 40) }
        }
    }

    /// Câu hỏi nhanh dạng hàng cuộn ngang — để hỏi TIẾP sau lượt đầu.
    private var hangGoiY: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(goiY, id: \.self) { g in
                    Button { Task { await hoi(T(g)) } } label: {
                        Text(T(g)).font(.caption).lineLimit(1)
                            .padding(.horizontal, Spacing.sm + 2).padding(.vertical, 6)
                            .background(AppColors.backgroundCard)
                            .foregroundStyle(AppColors.textPrimary)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppColors.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(dangHoi)
                }
            }
            .padding(.horizontal, Spacing.sm + 2)
            .padding(.vertical, 6)
        }
        .background(AppColors.backgroundSecondary)
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
            if let g = kq.goiY, !g.isEmpty { vm.goiYAI = g }
            if let c = kq.chu, !c.isEmpty {
                loiThoai.append(DongCoVan(cuaToi: false, chu: c, cauHoi: t, kiemSo: kq.kiemSo, laAI: true))
            } else {
                loiThoai.append(DongCoVan(
                    cuaToi: false,
                    chu: kq.thieuKhoaAI
                        ? T("Phần trả lời bằng AI đang tắt trên máy chủ.")
                        : T("Chưa có câu trả lời.")))
            }
        } catch {
            loiThoai.append(DongCoVan(cuaToi: false, chu: error.localizedDescription))
        }
    }
}
