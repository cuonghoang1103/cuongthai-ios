import SwiftUI

/// Thời khoá biểu theo TUẦN, bám bố cục trang FAP: chuyển tuần, xếp theo
/// SLOT, mỗi buổi có phòng/mã môn/giờ, chấm điểm danh ngay tại chỗ, và tuần
/// thi thì hiện luôn lịch thi.
///
/// Không dựng lưới 7 cột như trang web: trên màn 402pt mỗi cột còn ~50pt,
/// không đủ cho "SWT301 at DE-412". Xếp theo NGÀY, trong ngày xếp theo slot —
/// vẫn đọc được cả tuần bằng cách cuộn, mà không phải phóng to.
struct LichTuanView: View {
    @ObservedObject var vm: TongQuanVM
    @State private var sua: BuoiHoc?
    @State private var themMoi = false
    @State private var suaThi: BuoiThi?
    @State private var themThi = false
    @State private var nhapNhanh = false
    @State private var hoiXoa: BuoiHoc?

    private var homNay: String { PhamViViec.dinhDang.string(from: Date()) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                thanhTuan

                if !vm.lichThi.isEmpty { khoiThi }

                if vm.dangTaiLich && vm.buoiHoc.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, Spacing.xxl)
                } else if vm.buoiHoc.isEmpty {
                    trong
                } else {
                    ForEach(vm.ngayTrongTuan, id: \.self) { ngay in
                        let thu = BuoiHoc.thuViet(tuLich: Calendar.current.component(.weekday, from: ngay))
                        let ds = vm.buoiHoc.filter { $0.weekday == thu }
                            .sorted { $0.phutBatDau < $1.phutBatDau }
                        if !ds.isEmpty { khoiNgay(ngay, thu, ds) }
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
                Menu {
                    Button { themMoi = true } label: { Label(T("Thêm buổi học"), systemImage: "calendar.badge.plus") }
                    Button { themThi = true } label: { Label(T("Thêm buổi thi"), systemImage: "pencil.and.list.clipboard") }
                    Button { nhapNhanh = true } label: { Label(T("Nhập nhanh cả tuần"), systemImage: "text.badge.plus") }
                    NavigationLink { HocKyView(vm: vm) } label: { Label(T("Kỳ học"), systemImage: "graduationcap") }
                } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $themMoi) { NavigationStack { SuaBuoiHocView(vm: vm, buoi: nil) } }
        .sheet(item: $sua) { b in NavigationStack { SuaBuoiHocView(vm: vm, buoi: b) } }
        .sheet(isPresented: $themThi) { NavigationStack { SuaBuoiThiView(vm: vm, thi: nil) } }
        .sheet(isPresented: $nhapNhanh) { NavigationStack { NhapNhanhLichView(vm: vm) } }
        .sheet(item: $suaThi) { t in NavigationStack { SuaBuoiThiView(vm: vm, thi: t) } }
        .confirmationDialog(T("Xoá buổi học này?"), isPresented: .constant(hoiXoa != nil), titleVisibility: .visible) {
            Button(T("Xoá"), role: .destructive) {
                if let b = hoiXoa { Task { await vm.xoaBuoiHoc(b) } }
                hoiXoa = nil
            }
            Button(T("Huỷ"), role: .cancel) { hoiXoa = nil }
        } message: { Text(hoiXoa?.subject ?? "") }
        .task {
            if vm.buoiHoc.isEmpty { await vm.napLich() }
            await vm.napHocKy()
            await vm.napTuan()
        }
    }

    // MARK: Thanh chuyển tuần

    private var thanhTuan: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Button { vm.doiTuan(-1) } label: {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(AppColors.backgroundTertiary))
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(khoangNgay)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    if let n = vm.nhanTuan {
                        Text(n)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(n.contains(T("TUẦN THI")) ? AppColors.error : AppColors.primary)
                    } else if vm.kyDangHoc == nil {
                        NavigationLink { HocKyView(vm: vm) } label: {
                            Text(T("Đặt kỳ học để hiện số tuần"))
                                .font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                        }
                    }
                }
                Spacer()
                Button { vm.doiTuan(1) } label: {
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(AppColors.backgroundTertiary))
                }
            }
            .foregroundColor(AppColors.textPrimary)

            if PhamViViec.dinhDang.string(from: vm.tuanDangXem)
                != PhamViViec.dinhDang.string(from: TongQuanVM.thuHai(Date())) {
                Button(T("Về tuần này")) {
                    vm.tuanDangXem = TongQuanVM.thuHai(Date())
                    Task { await vm.napTuan() }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.primary)
            }
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    private var khoangNgay: String {
        let f = DateFormatter(); f.dateFormat = "dd/MM"
        let cuoi = Calendar.current.date(byAdding: .day, value: 6, to: vm.tuanDangXem) ?? vm.tuanDangXem
        return "\(f.string(from: vm.tuanDangXem)) – \(f.string(from: cuoi))"
    }

    // MARK: Lịch thi

    private var khoiThi: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12)).foregroundColor(AppColors.error)
                Text(T("LỊCH THI TUẦN NÀY"))
                    .font(.system(size: 11, weight: .heavy)).tracking(1)
                    .foregroundColor(AppColors.error)
            }
            ForEach(vm.lichThi) { t in
                HangBuoiThi(thi: t)
                    .contentShape(Rectangle())
                    .onTapGesture { suaThi = t }
            }
        }
    }

    // MARK: Một ngày

    private func khoiNgay(_ ngay: Date, _ thu: Int, _ ds: [BuoiHoc]) -> some View {
        let s = PhamViViec.dinhDang.string(from: ngay)
        let laHomNay = s == homNay
        let f = DateFormatter(); f.dateFormat = "dd/MM"
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Text(BuoiHoc.tenThu(thu))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(laHomNay ? AppColors.primary : AppColors.textPrimary)
                Text(f.string(from: ngay))
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundColor(AppColors.textTertiary)
                if laHomNay {
                    Text(T("hôm nay"))
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(AppColors.onPrimary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(AppColors.primary))
                }
                Spacer()
            }
            ForEach(ds) { b in
                OBuoiHoc(buoi: b, ngay: ngay, vm: vm,
                         moSua: { sua = b }, moXoa: { hoiXoa = b })
            }
        }
    }

    private var trong: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle().fill(AppColors.primary.opacity(0.12)).frame(width: 84, height: 84)
                Image(systemName: "calendar.badge.plus").font(.system(size: 32)).foregroundColor(AppColors.primary)
            }
            Text(T("Chưa có thời khoá biểu"))
                .font(.system(size: 19, weight: .bold)).foregroundColor(AppColors.textPrimary)
            Text(T("Thêm từng buổi học để app nhắc bạn trước giờ lên lớp và ghi điểm danh."))
                .font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Button { themMoi = true } label: {
                Text(T("Thêm buổi học đầu tiên"))
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(AppColors.onPrimary)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(LinearGradient(colors: [AppColors.primary, AppColors.primaryDark],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            }
            .padding(.top, Spacing.xs)
            Button(T("Nhập nhanh cả tuần")) { nhapNhanh = true }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.primary)
        }
        .padding(Spacing.lg).frame(maxWidth: 380).frame(maxWidth: .infinity).padding(.top, Spacing.xl)
    }
}

// MARK: - Một ô buổi học (có điểm danh)

private struct OBuoiHoc: View {
    let buoi: BuoiHoc
    let ngay: Date
    @ObservedObject var vm: TongQuanVM
    let moSua: () -> Void
    let moXoa: () -> Void

    /// FAP cho nghỉ tối đa 4 buổi/môn. Chạm 4 là trượt, nên cảnh báo từ 3.
    private let nguongVang = 4

    var body: some View {
        let tt = vm.trangThai(buoi, ngay)
        let vang = vm.soVang(buoi)
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                RoundedRectangle(cornerRadius: 2).fill(mau).frame(width: 3.5, height: 42)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(buoi.subject)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary).lineLimit(1)
                        if let s = buoi.slot ?? SlotFAP.doTuGio(buoi.startTime) {
                            Text("Slot \(s)")
                                .font(.system(size: 9.5, weight: .heavy))
                                .foregroundColor(mau)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Capsule().fill(mau.opacity(0.16)))
                        }
                    }
                    Text([buoi.room, buoi.classCode, buoi.teacher]
                            .compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " · "))
                        .font(.system(size: 12)).foregroundColor(AppColors.textTertiary).lineLimit(1)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(buoi.startTime)
                        .font(.system(size: 13.5, weight: .semibold).monospacedDigit())
                        .foregroundColor(AppColors.textPrimary)
                    Text(buoi.endTime)
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            HStack(spacing: 6) {
                ForEach(TrangThaiDiemDanh.allCases) { t in
                    Button {
                        // Bấm lại trạng thái đang chọn = GỠ chấm. Chấm nhầm một
                        // buổi chưa diễn ra thì phải gỡ được, chứ không phải
                        // chọn bừa một trạng thái khác.
                        Task { await vm.cham(buoi, ngay, tt == t ? nil : t) }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: t.bieuTuong).font(.system(size: 11))
                            Text(t.ten).font(.system(size: 11.5, weight: tt == t ? .bold : .regular))
                        }
                        .foregroundColor(tt == t ? AppColors.onPrimary : AppColors.textSecondary)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(Capsule().fill(tt == t ? mauTrangThai(t) : AppColors.backgroundTertiary))
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
                if vang > 0 {
                    Text(String(format: T("nghỉ %d/%d"), vang, nguongVang))
                        .font(.system(size: 10.5, weight: .semibold).monospacedDigit())
                        .foregroundColor(vang >= nguongVang - 1 ? AppColors.error : AppColors.textTertiary)
                }
            }

            if let m = buoi.meetUrl, let u = URL(string: m) {
                Link(destination: u) {
                    HStack(spacing: 5) {
                        Image(systemName: "video").font(.system(size: 11))
                        Text(T("Vào lớp trực tuyến")).font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(AppColors.secondary)
                }
            }
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
        .contextMenu {
            Button(action: moSua) { Label(T("Sửa"), systemImage: "pencil") }
            Button(role: .destructive, action: moXoa) { Label(T("Xoá"), systemImage: "trash") }
        }
    }

    private func mauTrangThai(_ t: TrangThaiDiemDanh) -> Color {
        switch t {
        case .co:   return AppColors.success
        case .vang: return AppColors.error
        case .phep: return AppColors.warning
        }
    }

    private var mau: Color {
        if let h = buoi.color, let c = Color(hexChuoi: h) { return c }
        let bang: [Color] = [AppColors.primary, AppColors.secondary, AppColors.accent,
                             AppColors.success, AppColors.warning, AppColors.error]
        return bang[abs(buoi.subject.hashValue) % bang.count]
    }
}

// MARK: - Một hàng lịch thi

struct HangBuoiThi: View {
    let thi: BuoiThi

    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(spacing: 1) {
                Text(thi.kieu.nhan)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(AppColors.onPrimary)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(thi.kieu.mau))
                Text(ngayNgan)
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundColor(AppColors.textTertiary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(thi.monHoc)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary).lineLimit(1)
                Text([thi.maMon, thi.phong, thi.soBaoDanh.map { "SBD \($0)" }]
                        .compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " · "))
                    .font(.system(size: 12)).foregroundColor(AppColors.textTertiary).lineLimit(1)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 1) {
                Text(thi.batDau)
                    .font(.system(size: 13.5, weight: .semibold).monospacedDigit())
                    .foregroundColor(AppColors.textPrimary)
                Text(thi.ketThuc)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(AppColors.backgroundCard)
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.large)
                    .stroke(thi.kieu.mau.opacity(0.45), lineWidth: 1.2))
        )
    }

    private var ngayNgan: String {
        guard let d = PhamViViec.dinhDang.date(from: thi.ngayGon) else { return thi.ngayGon }
        let f = DateFormatter(); f.dateFormat = "dd/MM"
        return f.string(from: d)
    }
}
