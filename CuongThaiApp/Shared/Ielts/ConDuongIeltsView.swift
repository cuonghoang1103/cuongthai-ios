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
    @ObservedObject private var tim = TimIelts.chung
    @State private var anMung = false
    @State private var soXongTruoc = -1

    // ⚠️ TÍNH MỘT LẦN rồi giữ, KHÔNG để là thuộc tính tính-lại.
    //
    // Bản đầu khai `duong` và `nhip` là `private var { ... }`, mà SwiftUI đọc
    // chúng nhiều lần trong MỖI lần dựng lại — riêng `duong` bị đọc ở ba chỗ,
    // mỗi lần dựng lại tới 60 nút. Cộng với một hoạt ảnh `repeatForever`
    // đang chạy, cây view không bao giờ đứng yên và màn hình đơ cứng.
    @State private var duong: [NutDuongIelts] = []
    @State private var nhip = NhipHocIelts()

    private func tinhLai() {
        nhip = NhipHocIelts.tinh(mocXong: vm.mocXong)
        guard let c = vm.changHienTai else { duong = []; return }
        var soMuc: [String: Int] = [:]
        var xongSo: [String: Int] = [:]
        for p in c.phanTheoThuTu {
            soMuc[p.kind] = p.soMuc
            xongSo[p.kind] = p.daXong
        }
        duong = DungConDuong.dung(soMuc: soMuc, daXongSo: xongSo)
    }

    // ⚠️ KHÔNG có ScrollView ở đây. Màn IELTS đã bọc toàn bộ trong một
    // `ScrollView`, và lồng hai ScrollView CÙNG TRỤC thì cái trong nuốt cử
    // chỉ kéo còn cái ngoài đứng im — cả trang thành "đơ một cục, không di
    // chuyển được" (người dùng báo 19/09/2026). Đây là một khối NỘI DUNG,
    // cha lo việc cuộn.
    var body: some View {
        VStack(spacing: Spacing.lg) {
            thanhNhip
            loiRobot
            theHomNay
            khungConDuong
        }
        .background(AppColors.backgroundPrimary)
        .overlay {
            if anMung { AnMungXongView(xp: NhipHocIelts.xpMoiMuc,
                                       chuoiNgay: nhip.chuoiNgay, hien: $anMung) }
        }
        // ⚠️ Bắt theo SỐ MỤC ĐÃ XONG, không theo "vừa bấm nút xong". Người
        // dùng có thể xong một mục ở màn khác (Phòng thi, tra từ) rồi quay
        // lại — ăn mừng phải đúng lúc con số nhích lên, bất kể nó nhích ở đâu.
        .onChange(of: vm.daXong.count) { cu, moi in
            if soXongTruoc >= 0 && moi > cu { withAnimation { anMung = true } }
            soXongTruoc = moi
            NhacChuoiIelts.datLai(daHocHomNay: nhip.xpHomNay > 0, chuoiNgay: nhip.chuoiNgay)
        }
        .onAppear {
            soXongTruoc = vm.daXong.count
            tinhLai()
            NhacChuoiIelts.datLai(daHocHomNay: nhip.xpHomNay > 0, chuoiNgay: nhip.chuoiNgay)
        }
        // Tính lại ĐÚNG khi dữ liệu đổi, không phải mỗi lần vẽ.
        .onChange(of: vm.changDangXem) { _, _ in tinhLai() }
        .onChange(of: vm.daXong.count) { _, _ in tinhLai() }
        .onChange(of: vm.loTrinh?.chang.count ?? 0) { _, _ in tinhLai() }
    }

    // MARK: Nhân vật

    /// Robot nói một câu theo TÌNH HÌNH THẬT, không phải câu chúc chung.
    /// "Cố lên nhé!" lặp mỗi lần mở app là thứ người ta thôi đọc sau hai hôm.
    private var loiRobot: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text("🤖").font(.system(size: 34))
            Text(cauCuaRobot)
                .font(.bodySmall).foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.primary.opacity(0.08))
        .cornerRadius(CornerRadius.large)
    }

    private var cauCuaRobot: String {
        let n = nhip
        if n.daDatMucTieu {
            return T("Xong mục tiêu hôm nay rồi. Học thêm thì tốt, nghỉ cũng không mất chuỗi.")
        }
        if n.xpHomNay > 0 {
            let con = (n.mucTieuNgay - n.xpHomNay) / NhipHocIelts.xpMoiMuc
            return String(format: T("Còn %d mục nữa là xong hôm nay."), max(con, 1))
        }
        if n.chuoiNgay > 0 {
            return String(format: T("Chuỗi %d ngày đang treo. Một mục thôi là giữ được."), n.chuoiNgay)
        }
        return T("Bắt đầu từ nút đang sáng bên dưới — hết đúng một mục là có chuỗi ngày đầu tiên.")
    }

    // MARK: Thanh trên — chuỗi ngày, XP, band

    private var thanhNhip: some View {
        HStack(spacing: Spacing.md) {
            oNhip("🔥", "\(nhip.chuoiNgay)", T("ngày liền"),
                  nhip.chuoiNgay > 0 ? AppColors.warning : AppColors.textTertiary)
            oNhip("⚡", "\(nhip.xpHomNay)/\(nhip.mucTieuNgay)", T("XP hôm nay"),
                  nhip.daDatMucTieu ? AppColors.success : AppColors.primary)
            oNhip("❤️", "\(tim.con)", T("tim hôm nay"),
                  tim.con > 2 ? AppColors.error : AppColors.textTertiary)
            oNhip("🎯", vm.bandCuaChang?.band ?? "—", T("mục tiêu"), AppColors.primary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
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
                .onAppear { vm.moMuc = nut.id }
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
            // ⚠️ `repeatForever` chỉ được bật MỘT lần. View dựng lại (đổi
            // chặng, kéo làm mới) mà bật thêm lần nữa thì các lớp hoạt ảnh
            // chồng lên nhau và CPU quay mãi cho một cái nhấp nháy.
            guard dangMo, !nhay else { return }
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
