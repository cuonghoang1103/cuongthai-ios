import SwiftUI

/// Màn Tiền nong — cổng vào của cả mảng.
///
/// Trật tự trên màn hình đi theo thứ tự CẤP BÁCH, không theo thứ tự các mảng
/// dữ liệu: nợ quá hạn → mục tiêu chi hôm nay → số liệu tháng → lối vào từng
/// mảng. Người mở app lúc 8h sáng vì vừa nhận thông báo nhắc nợ phải thấy
/// khoản đó ngay, không phải cuộn qua bốn thẻ thống kê.
struct TienView: View {
    /// `true` khi màn này được mở dạng tấm phủ (iPhone) — lúc đó phải có nút
    /// Đóng, vì tấm phủ toàn màn không có cạnh nào để vuốt ra.
    var coNutDong = false

    @StateObject private var vm = TienVM()
    @Environment(\.dismiss) private var dong
    @EnvironmentObject private var appState: AppState
    @State private var moGhiNhanh = false
    @State private var moCoVan = false
    @State private var moMucTieu = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    ThanhChonThang(thang: vm.thang) { b in Task { await vm.doiThang(b) } }

                    if !vm.noCanGap.isEmpty { khoiNoGap }
                    khoiMucTieuNgay
                    khoiSoLieu
                    khoiCoVan
                    khoiLoiVao
                    if let b = vm.bang, !b.expenseByCategory.isEmpty { khoiTheoNhom(b) }
                    if let b = vm.bang, !b.budgets.isEmpty { khoiNganSach(b) }
                }
                .padding(Spacing.md)
                .padding(.bottom, 80)
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle(T("Tiền nong"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                if coNutDong {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(T("Đóng")) { dong() }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { moGhiNhanh = true } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel(T("Ghi khoản chi"))
                }
            }
            .refreshable { await vm.napTatCa() }
            .task {
                guard !vm.daNapLanDau else { return }
                await vm.napTatCa()
            }
            // Chạm thông báo 20h ⇒ mở thẳng ô ghi chi. `.task` chứ không
            // `.onChange`: cờ được ĐẶT TRƯỚC khi màn này tồn tại (định tuyến
            // chạy lúc app vừa bật), nên `.onChange` sẽ không bao giờ thấy nó
            // đổi và ô ghi chi không bao giờ mở.
            .task(id: appState.ghiChiNgaySauKhiMoTien) {
                guard appState.ghiChiNgaySauKhiMoTien else { return }
                appState.ghiChiNgaySauKhiMoTien = false
                // Chờ danh mục về trước: mở ô ghi chi lúc `dsNhom`/`dsVi` còn
                // trống thì nút Lưu mờ và trông như hỏng.
                await vm.napDanhMuc()
                moGhiNhanh = true
            }
            .sheet(isPresented: $moGhiNhanh) { GhiChiView(vm: vm, sua: nil) }
            .sheet(isPresented: $moCoVan) { CoVanAIView(vm: vm) }
            .sheet(isPresented: $moMucTieu) { MucTieuChiView(vm: vm) }
            .alert(T("Lỗi"), isPresented: Binding(get: { vm.loi != nil }, set: { if !$0 { vm.loi = nil } })) {
                Button(T("Đóng"), role: .cancel) { vm.loi = nil }
            } message: { Text(vm.loi ?? "") }
        }
    }

    // MARK: - Nợ cần gấp

    private var khoiNoGap: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppColors.error)
                Text(T("Nợ cần trả")).font(.titleSmall).foregroundStyle(AppColors.textPrimary)
                Spacer()
                NavigationLink { NoView(vm: vm) } label: {
                    Text(T("Xem hết")).font(.caption).foregroundStyle(AppColors.primary)
                }
            }
            ForEach(vm.noCanGap.prefix(4)) { k in
                HStack(spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(k.lenderName).font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                        Text(nhanHan(k)).font(.caption)
                            .foregroundStyle(k.isOverdue ? AppColors.error : AppColors.warning)
                    }
                    Spacer()
                    Text(DinhDangTien.day(k.amountDue, k.currency))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(k.isOverdue ? AppColors.error : AppColors.textPrimary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(Spacing.md)
        .background(AppColors.error.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: CornerRadius.large)
            .stroke(AppColors.error.opacity(0.3), lineWidth: 1))
        .cornerRadius(CornerRadius.large)
    }

    private func nhanHan(_ k: KyNoSapToi) -> String {
        guard let con = NgayTien.conBaoNhieuNgay(k.dueDate) else { return NgayTien.ngayDay(k.dueDate) }
        if con < 0 { return "\(T("QUÁ HẠN")) \(-con) \(T("ngày")) · \(NgayTien.ngayGon(k.dueDate))" }
        if con == 0 { return "\(T("Tới hạn HÔM NAY")) · \(NgayTien.ngayGon(k.dueDate))" }
        return "\(T("Còn")) \(con) \(T("ngày")) · \(NgayTien.ngayGon(k.dueDate))"
    }

    // MARK: - Mục tiêu hôm nay

    private var khoiMucTieuNgay: some View {
        Button { moMucTieu = true } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text(T("Mục tiêu chi tiêu")).font(.titleSmall).foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(AppColors.textTertiary)
                }
                if let l = vm.loiMucTieu {
                    Text(l).font(.caption).foregroundStyle(AppColors.error)
                        .multilineTextAlignment(.leading)
                } else if vm.mucTieu.isEmpty {
                    Text(T("Chưa đặt mục tiêu nào. Chạm để đặt cho ngày / tuần / tháng."))
                        .font(.bodySmall).foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.leading)
                } else {
                    ForEach(vm.mucTieu) { m in dongMucTieu(m) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(AppColors.backgroundCard)
            .cornerRadius(CornerRadius.large)
        }
        .buttonStyle(.plain)
    }

    private func dongMucTieu(_ m: MucTieuChi) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(m.tenKy).font(.bodySmall).foregroundStyle(AppColors.textSecondary)
                Spacer()
                Text("\(DinhDangTien.ngan(m.daTieu)) / \(DinhDangTien.ngan(m.mucTieu))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(m.vuot ? AppColors.error : AppColors.textPrimary)
            }
            ThanhTienDoTien(tiLe: Double(m.tiLe) / 100,
                        mau: m.vuot ? AppColors.error : (m.tiLe >= 80 ? AppColors.warning : AppColors.success))
            Text(m.vuot
                 ? "\(T("Vượt")) \(DinhDangTien.day(-m.conLai))"
                 : "\(T("Còn")) \(DinhDangTien.day(m.conLai))")
                .font(.caption2)
                .foregroundStyle(m.vuot ? AppColors.error : AppColors.textTertiary)
        }
    }

    // MARK: - Số liệu tháng

    private var khoiSoLieu: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                TheSoTien(nhan: T("Tổng số dư"), so: vm.bang?.totalBalance ?? 0,
                          mau: AppColors.primary, bieuTuong: "creditcard.fill")
                TheSoTien(nhan: T("Giá trị ròng"), so: vm.bang?.netWorth ?? 0,
                          mau: (vm.bang?.netWorth ?? 0) >= 0 ? AppColors.success : AppColors.error,
                          bieuTuong: "chart.line.uptrend.xyaxis")
            }
            HStack(spacing: Spacing.sm) {
                TheSoTien(nhan: T("Thu tháng này"), so: vm.bang?.incomeThisMonth ?? 0,
                          mau: AppColors.success, bieuTuong: "arrow.down.circle.fill")
                TheSoTien(nhan: T("Chi tháng này"), so: vm.bang?.expenseThisMonth ?? 0,
                          mau: AppColors.error, bieuTuong: "arrow.up.circle.fill")
            }
            HStack(spacing: Spacing.sm) {
                TheSoTien(nhan: T("Để dành"), so: vm.bang?.savingsThisMonth ?? 0,
                          mau: (vm.bang?.savingsThisMonth ?? 0) >= 0 ? AppColors.success : AppColors.error,
                          bieuTuong: "banknote.fill",
                          phu: vm.bang?.spendingVsIncomePct.map { "\(T("Chi")) \(Int($0))% \(T("thu"))" })
                TheSoTien(nhan: T("Nợ còn lại"), so: vm.bang?.totalRemainingDebt ?? 0,
                          mau: (vm.bang?.totalRemainingDebt ?? 0) > 0 ? AppColors.warning : AppColors.textSecondary,
                          bieuTuong: "doc.text.fill")
            }
            if vm.bang?.hasUnconvertedUsd == true {
                Text(T("Có khoản bằng USD chưa quy đổi nên chưa cộng vào tổng — cần đặt tỷ giá."))
                    .font(.caption2).foregroundStyle(AppColors.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Cố vấn AI

    private var khoiCoVan: some View {
        Button { moCoVan = true } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(.titleMedium)
                    .foregroundStyle(AppColors.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(T("AI quản lí tiền")).font(.titleSmall).foregroundStyle(AppColors.textPrimary)
                    Text(vm.nhanXetAI.map { $0.replacingOccurrences(of: "\n", with: " · ") }
                         ?? T("Xem nhận xét về nợ, chi tiêu và mục tiêu của bạn"))
                        .font(.caption).foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(AppColors.textTertiary)
            }
            .padding(Spacing.md)
            .background(LinearGradient(colors: [AppColors.primary.opacity(0.12), AppColors.secondary.opacity(0.10)],
                                       startPoint: .leading, endPoint: .trailing))
            .cornerRadius(CornerRadius.large)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Lối vào từng mảng

    private var khoiLoiVao: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Spacing.sm)], spacing: Spacing.sm) {
            NavigationLink { ChiTieuView(vm: vm) } label: {
                oLoiVao("Chi tiêu", "cart.fill", AppColors.error, DinhDangTien.ngan(vm.bang?.expenseThisMonth ?? 0))
            }.buttonStyle(.plain)
            NavigationLink { ThuNhapView(vm: vm) } label: {
                oLoiVao("Thu nhập", "briefcase.fill", AppColors.success, DinhDangTien.ngan(vm.bang?.incomeThisMonth ?? 0))
            }.buttonStyle(.plain)
            NavigationLink { NoView(vm: vm) } label: {
                oLoiVao("Nợ", "doc.text.fill", AppColors.warning, DinhDangTien.ngan(vm.bang?.totalRemainingDebt ?? 0))
            }.buttonStyle(.plain)
            NavigationLink { ViView(vm: vm) } label: {
                oLoiVao("Ví", "wallet.pass.fill", AppColors.primary, "\(vm.dsVi.count) \(T("ví"))")
            }.buttonStyle(.plain)
            NavigationLink { TietKiemView(vm: vm) } label: {
                oLoiVao("Tiết kiệm", "lock.shield.fill", AppColors.secondary, DinhDangTien.ngan(vm.bang?.totalSavings ?? 0))
            }.buttonStyle(.plain)
            NavigationLink { DauTuView(vm: vm) } label: {
                oLoiVao("Đầu tư", "chart.pie.fill", AppColors.accent, DinhDangTien.ngan(vm.bang?.totalAssetValue ?? 0))
            }.buttonStyle(.plain)
        }
    }

    private func oLoiVao(_ ten: String, _ bt: String, _ mau: Color, _ phu: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: bt)
                .font(.titleMedium)
                .foregroundStyle(mau)
                .frame(width: 34, height: 34)
                .background(mau.opacity(0.14))
                .cornerRadius(CornerRadius.small)
            VStack(alignment: .leading, spacing: 1) {
                Text(T(ten)).font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                Text(phu).font(.caption2).foregroundStyle(AppColors.textTertiary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.sm + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.medium)
    }

    // MARK: - Chi theo nhóm

    private func khoiTheoNhom(_ b: BangTien) -> some View {
        let tong = max(1, b.expenseByCategory.reduce(0) { $0 + $1.total })
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(T("Chi theo nhóm")).font(.titleSmall).foregroundStyle(AppColors.textPrimary)
            ForEach(b.expenseByCategory.prefix(8)) { e in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("\(e.category?.bieuTuong ?? "🏷️") \(e.category?.name ?? T("Chưa phân nhóm"))")
                            .font(.bodySmall).foregroundStyle(AppColors.textPrimary)
                        Spacer()
                        Text(DinhDangTien.day(e.total))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    ThanhTienDoTien(tiLe: e.total / tong, mau: AppColors.primary.opacity(0.8), cao: 5)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    // MARK: - Ngân sách nhóm

    private func khoiNganSach(_ b: BangTien) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(T("Ngân sách tháng")).font(.titleSmall).foregroundStyle(AppColors.textPrimary)
            ForEach(b.budgets) { ns in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("\(ns.category.bieuTuong) \(ns.category.name)")
                            .font(.bodySmall).foregroundStyle(AppColors.textPrimary)
                        Spacer()
                        Text("\(Int(ns.ratio))%")
                            .font(.captionBold)
                            .foregroundStyle(mauNganSach(ns.status))
                    }
                    ThanhTienDoTien(tiLe: ns.ratio / 100, mau: mauNganSach(ns.status), cao: 5)
                    Text("\(DinhDangTien.day(ns.used)) / \(DinhDangTien.day(ns.budget))")
                        .font(.caption2).foregroundStyle(AppColors.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    private func mauNganSach(_ s: String) -> Color {
        switch s {
        case "over": return AppColors.error
        case "warn": return AppColors.warning
        default: return AppColors.success
        }
    }
}
