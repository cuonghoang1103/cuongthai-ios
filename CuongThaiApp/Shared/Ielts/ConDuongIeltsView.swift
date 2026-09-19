import SwiftUI

// ════════════════════════════════════════════════════════════════
// CON ĐƯỜNG IELTS
//
// Thay cái lưới 8 ô đếm số bằng một CON ĐƯỜNG: luôn có đúng MỘT việc đang
// mở, và nó nói thẳng "bây giờ làm cái này". Người dùng nói thẳng
// 19/09/2026: *"nhìn vào không muốn học"* — nội dung thì đã có 597 mục,
// cái thiếu là chỗ bắt đầu và lý do quay lại ngày mai.
//
// ⚠️ Mọi con số ở đây (chuỗi ngày, XP, đã xong) tính từ TIẾN ĐỘ THẬT trên
// máy chủ. Không bịa số cho đẹp: một cái chuỗi "7 ngày" sai là thứ người
// dùng phát hiện ra trong đúng một giây, và sau đó không tin cái nào nữa.
// ════════════════════════════════════════════════════════════════

struct ConDuongIeltsView: View {
    @ObservedObject var vm: IeltsVM

    private var nhip: NhipHocIelts { NhipHocIelts.tinh(mocXong: vm.mocXong) }

    private var duong: [NutDuongIelts] {
        guard let c = vm.changHienTai else { return [] }
        var soMuc: [String: Int] = [:]
        var xongSo: [String: Int] = [:]
        for p in c.phanTheoThuTu {
            soMuc[p.kind] = p.soMuc
            xongSo[p.kind] = p.daXong
        }
        return DungConDuong.dung(soMuc: soMuc, daXongSo: xongSo)
    }

    var body: some View {
        VStack(spacing: 0) {
            thanhNhip
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    theHomNay
                    khungConDuong
                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)
            }
        }
        .background(AppColors.backgroundPrimary)
    }

    // MARK: Thanh trên — chuỗi ngày, XP, band

    private var thanhNhip: some View {
        HStack(spacing: Spacing.md) {
            oNhip("🔥", "\(nhip.chuoiNgay)", T("ngày liền"),
                  nhip.chuoiNgay > 0 ? AppColors.warning : AppColors.textTertiary)
            oNhip("⚡", "\(nhip.xpHomNay)/\(nhip.mucTieuNgay)", T("XP hôm nay"),
                  nhip.daDatMucTieu ? AppColors.success : AppColors.primary)
            oNhip("🎯", vm.bandCuaChang?.band ?? "—", T("mục tiêu"), AppColors.primary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(AppColors.backgroundCard)
        .overlay(alignment: .bottom) {
            // Thanh tiến độ ngày chạy sát đáy: nhìn một cái là biết còn
            // bao nhiêu nữa thì xong hôm nay.
            GeometryReader { g in
                Rectangle().fill(AppColors.success)
                    .frame(width: g.size.width * nhip.tiLeNgay, height: 3)
            }
            .frame(height: 3)
        }
    }

    private func oNhip(_ hinh: String, _ so: String, _ nhan: String, _ mau: Color) -> some View {
        VStack(spacing: 1) {
            HStack(spacing: 3) {
                Text(hinh).font(.system(size: 15))
                Text(so).font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(mau).lineLimit(1).minimumScaleFactor(0.6)
            }
            Text(nhan).font(.system(size: 9)).foregroundStyle(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Kế hoạch hôm nay

    private var theHomNay: some View {
        let viec = DungConDuong.viecHomNay(duong)
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(T("Hôm nay")).font(.titleSmall).foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text("~\(max(viec.count * 4, 4)) \(T("phút"))")
                    .font(.caption).foregroundStyle(AppColors.textTertiary)
            }
            if viec.isEmpty {
                Text(T("Bạn đã xong chặng này. Thử Phòng thi để đo band thật."))
                    .font(.bodySmall).foregroundStyle(AppColors.textSecondary)
            } else {
                // ⚠️ Nói việc CỤ THỂ, không nói "học 20 phút mỗi ngày". Lời
                // khuyên chung là thứ đọc xong vẫn không biết mở cái gì ra.
                ForEach(Array(viec.enumerated()), id: \.element.id) { i, n in
                    HStack(spacing: Spacing.sm) {
                        Text("\(i + 1)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(AppColors.primary.opacity(0.15)))
                            .foregroundStyle(AppColors.primary)
                        Image(systemName: n.bieuTuong).font(.caption)
                            .foregroundStyle(AppColors.textSecondary).frame(width: 16)
                        Text(n.ten).font(.bodySmall).foregroundStyle(AppColors.textPrimary)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    // MARK: Con đường

    private var khungConDuong: some View {
        VStack(spacing: 0) {
            ForEach(Array(duong.enumerated()), id: \.element.id) { i, n in
                NutTrenDuong(nut: n, lech: lech(i), vm: vm)
                if i < duong.count - 1 {
                    // Đoạn nối: nhạt dần khi chưa mở, để mắt biết đường còn
                    // đi tiếp nhưng chưa tới lượt.
                    Rectangle()
                        .fill(n.xong ? AppColors.success.opacity(0.5)
                                     : AppColors.border.opacity(0.5))
                        .frame(width: 4, height: 22)
                        .offset(x: (lech(i) + lech(i + 1)) / 2)
                }
            }
        }
    }

    /// Đường đi zigzag. Biên độ nhỏ (56pt) để màn hẹp vẫn không tràn.
    private func lech(_ i: Int) -> CGFloat {
        [0, 56, 0, -56][i % 4]
    }
}

// MARK: - Một nút trên đường

private struct NutTrenDuong: View {
    let nut: NutDuongIelts
    let lech: CGFloat
    @ObservedObject var vm: IeltsVM
    @State private var nhay = false

    var body: some View {
        NavigationLink {
            ManCuaPhanIelts(kind: nut.kind, vm: vm)
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(mauNen)
                        .frame(width: nut.laMoc ? 72 : 60, height: nut.laMoc ? 72 : 60)
                        .shadow(color: dangMo ? AppColors.primary.opacity(0.35) : .clear,
                                radius: nhay ? 14 : 6)
                    if nut.xong {
                        Image(systemName: "checkmark").font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: nut.moKhoa ? nut.bieuTuong : "lock.fill")
                            .font(.system(size: nut.laMoc ? 26 : 22, weight: .semibold))
                            .foregroundStyle(nut.moKhoa ? .white : AppColors.textTertiary)
                    }
                }
                Text(nut.ten)
                    .font(.system(size: 11, weight: dangMo ? .bold : .regular))
                    .foregroundStyle(nut.moKhoa ? AppColors.textPrimary : AppColors.textTertiary)
                    .lineLimit(1)
            }
            .offset(x: lech)
        }
        .buttonStyle(.plain)
        .disabled(!nut.moKhoa)
        .onAppear {
            guard dangMo else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                nhay = true
            }
        }
    }

    /// Nút ĐANG MỞ và chưa xong — chỗ duy nhất được nhấp nháy. Nhấp nháy
    /// nhiều chỗ thì không chỗ nào còn nghĩa là "bắt đầu ở đây".
    private var dangMo: Bool { nut.moKhoa && !nut.xong }

    private var mauNen: Color {
        if nut.xong { return AppColors.success }
        if nut.moKhoa { return AppColors.primary }
        return AppColors.backgroundTertiary
    }
}

// MARK: - Mở đúng màn của từng loại

struct ManCuaPhanIelts: View {
    let kind: String
    @ObservedObject var vm: IeltsVM

    var body: some View {
        switch kind {
        case "readings": DanhSachDocView(vm: vm)
        case "listenings": DanhSachNgheView(vm: vm)
        case "writings": DanhSachVietView(vm: vm)
        case "speakings": DanhSachNoiView(vm: vm)
        case "vocab": TuVungIeltsView(vm: vm)
        case "units": BaiHocIeltsView(vm: vm)
        default:
            // `exercises` chưa có màn riêng. Nói thẳng thay vì mở màn trống:
            // một nút dẫn tới hư không phá lòng tin nhanh hơn cả không có nút.
            KhungTrongTien(bieuTuong: "hammer",
                           tieuDe: T("Phần này đang làm"),
                           moTa: T("Bài học, Từ vựng, Đọc, Nghe, Viết và Nói đã dùng được."))
        }
    }
}
