import SwiftUI

/// Thời khoá biểu theo tuần — xem, thêm, sửa, xoá buổi học.
struct LichTuanView: View {
    @ObservedObject var vm: TongQuanVM
    @State private var sua: BuoiHoc?
    @State private var themMoi = false
    @State private var hoiXoa: BuoiHoc?

    private var thuHomNay: Int {
        BuoiHoc.thuViet(tuLich: Calendar.current.component(.weekday, from: Date()))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if vm.dangTaiLich && vm.buoiHoc.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, Spacing.xxl)
                } else if vm.buoiHoc.isEmpty {
                    trong
                } else {
                    ForEach(BuoiHoc.thuNho...BuoiHoc.thuLon, id: \.self) { thu in
                        let ds = vm.buoiHoc.filter { $0.weekday == thu }
                            .sorted { $0.phutBatDau < $1.phutBatDau }
                        if !ds.isEmpty { ngay(thu, ds) }
                    }
                }
                Color.clear.frame(height: 80)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(T("Thời khoá biểu"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { themMoi = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel(T("Thêm buổi học"))
            }
        }
        .sheet(isPresented: $themMoi) {
            NavigationStack { SuaBuoiHocView(vm: vm, buoi: nil) }
        }
        .sheet(item: $sua) { b in
            NavigationStack { SuaBuoiHocView(vm: vm, buoi: b) }
        }
        .confirmationDialog(T("Xoá buổi học này?"), isPresented: .constant(hoiXoa != nil),
                            titleVisibility: .visible) {
            Button(T("Xoá"), role: .destructive) {
                if let b = hoiXoa { Task { await vm.xoaBuoiHoc(b) } }
                hoiXoa = nil
            }
            Button(T("Huỷ"), role: .cancel) { hoiXoa = nil }
        } message: {
            Text(hoiXoa?.subject ?? "")
        }
        .task { if vm.buoiHoc.isEmpty { await vm.napLich() } }
    }

    private var trong: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle().fill(AppColors.primary.opacity(0.12)).frame(width: 84, height: 84)
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 32)).foregroundColor(AppColors.primary)
            }
            Text(T("Chưa có thời khoá biểu"))
                .font(.system(size: 19, weight: .bold)).foregroundColor(AppColors.textPrimary)
            Text(T("Thêm từng buổi học để app nhắc bạn trước giờ lên lớp."))
                .font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Button { themMoi = true } label: {
                Text(T("Thêm buổi học đầu tiên"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.onPrimary)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(LinearGradient(colors: [AppColors.primary, AppColors.primaryDark],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            }
            .padding(.top, Spacing.xs)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: 380).frame(maxWidth: .infinity)
        .padding(.top, Spacing.xl)
    }

    private func ngay(_ thu: Int, _ ds: [BuoiHoc]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Text(BuoiHoc.tenThu(thu))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(thu == thuHomNay ? AppColors.primary : AppColors.textPrimary)
                if thu == thuHomNay {
                    Text(T("hôm nay"))
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(AppColors.onPrimary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(AppColors.primary))
                }
                Spacer()
                Text(String(format: T("%d buổi"), ds.count))
                    .font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
            }
            ForEach(ds) { b in
                HangBuoiHoc(buoi: b)
                    .contentShape(Rectangle())
                    .onTapGesture { sua = b }
                    .contextMenu {
                        Button { sua = b } label: { Label(T("Sửa"), systemImage: "pencil") }
                        Button(role: .destructive) { hoiXoa = b } label: {
                            Label(T("Xoá"), systemImage: "trash")
                        }
                    }
            }
        }
    }
}
