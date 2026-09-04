import SwiftUI

// ════════════════════════════════════════════════════════════════
// LOGO CUONGTHAI — MỘT NÉT LIỀN, BẤM VÀO THÌ ÁNH SÁNG CHẠY HẾT NÉT
//
// Yêu cầu: dấu hiệu vẽ bằng MỘT nét liền, bấm vào thì có một vệt sáng chạy
// từ đầu tới cuối nét, rồi trang cuộn về đầu (hoặc tải lại).
//
// ⚠️ KHÔNG được giống logo Threads. Threads là một cuộn tròn kiểu ký tự "@",
// TOÀN đường cong, không có đoạn thẳng nào. Nên bộ nét ở đây cố ý mang thứ
// Threads không có: **đoạn THẲNG** — gạch ngang chữ T, hoặc nét chéo vươn lên.
// Giống nhau ở chỗ "một nét + ánh sáng chạy" là giống Ý TƯỞNG TRÌNH BÀY, thứ
// không ai độc quyền được; khác nhau ở HÌNH, thứ mới là bản quyền.
// ════════════════════════════════════════════════════════════════

/// Nét logo "CT" trong hệ toạ độ 100×100 — MỘT nét liền.
///
/// Hình: gạch ngang chữ **T** nằm trên, chữ **C** ôm lấy bên trái và dưới,
/// thân chữ T dựng ngược lên chạm gạch. Đầu trái của gạch ngang cũng chính là
/// đầu trên của chữ C — nên chỉ cần một nét mà đọc ra hai chữ cái.
///
/// ⚠️ Thứ tự lệnh vẽ CÓ Ý NGHĨA: hiệu ứng sáng dùng `trim(from:to:)`, tức vệt
/// sáng chạy đúng theo thứ tự dưới đây — sang trái theo gạch, vòng quanh chữ
/// C, rồi dựng ngược lên thân chữ T. Đảo thứ tự là hoạt ảnh chạy ngược.
///
/// ⚠️ KHÔNG được giống Threads. Threads là một cuộn tròn kiểu "@", TOÀN đường
/// cong, không có đoạn thẳng nào và không đọc ra chữ cái. Ở đây có hai đoạn
/// THẲNG (gạch ngang + thân T) và đọc ra "CT" — khác hẳn về hình, thứ mới là
/// bản quyền. Giống nhau ở "một nét + ánh sáng chạy" là giống cách TRÌNH BÀY,
/// thứ không ai độc quyền được.
///
/// Đã soi ba phương án cạnh nhau trên máy thật (`CT_XEM_MAN=logo`) rồi mới
/// chọn cái này: bản "thân có khe hở" đọc thành chữ G, bản "gạch cắt qua
/// miệng chữ C" thì rối, cỡ 30pt trên thanh trên cùng là nát.
struct NetLogo: Shape {
    func path(in r: CGRect) -> Path {
        let s = min(r.width, r.height) / 100
        let ox = r.minX + (r.width - 100 * s) / 2
        let oy = r.minY + (r.height - 100 * s) / 2
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) }

        var d = Path()
        d.move(to: p(90, 26))                                            // đầu phải gạch T
        d.addLine(to: p(40, 26))                                         // gạch ngang chữ T
        d.addCurve(to: p(12, 58), control1: p(22, 26), control2: p(12, 38))   // sườn trái chữ C
        d.addCurve(to: p(66, 92), control1: p(12, 80), control2: p(38, 92))   // đáy chữ C
        d.addLine(to: p(66, 26))                                         // thân chữ T dựng lên
        return d
    }
}

// MARK: - Logo có hiệu ứng sáng chạy

/// Bấm vào là một vệt sáng chạy dọc nét từ ĐẦU tới CUỐI, rồi gọi `khiBam`.
///
/// ⚠️ Không dùng một khoảng `trim(from: t-0.2, to: t)` chạy vòng: `trim`
/// KHÔNG quấn vòng, `from` âm là cả đoạn biến mất, nên vệt sáng sẽ nháy tắt ở
/// đầu và cuối. Thay vào đó chạy hai chặng — đầu vệt đi trước (0→1), rồi đuôi
/// đuổi theo (0→1). Nhìn đúng như "ánh sáng chạy hết nét" mà không có khe hở.
struct LogoCuongThai: View {
    var canh: CGFloat = 30
    var doDamNet: CGFloat = 11
    /// Hiện chữ "CuongThai" cạnh dấu hiệu.
    var coChu = true
    var khiBam: () -> Void = {}

    // ⚠️ Trạng thái NGHỈ là `duoi=0, dau=1` — tức vệt sáng phủ TOÀN BỘ nét,
    // logo lúc không bấm cũng là logo sáng. Khai `duoi=1` thì `trim(from:1,
    // to:1)` không vẽ gì và logo nằm im ở nét nền mờ, phải bấm mới sáng —
    // nhìn như logo bị hỏng chứ không như logo có hiệu ứng.
    @State private var dau: CGFloat = 1     // đầu vệt sáng
    @State private var duoi: CGFloat = 0    // đuôi vệt sáng
    @State private var dangChay = false

    private var netDam: StrokeStyle {
        StrokeStyle(lineWidth: doDamNet * (canh / 100), lineCap: .round, lineJoin: .round)
    }

    var body: some View {
        // ⚠️ Phải là `Button`, KHÔNG dùng `.onTapGesture`. Đặt trong
        // `ToolbarItem` thì cử chỉ chạm tự khai không nhận được chạm — đo
        // thật 05/09/2026: bấm logo trên thanh trên cùng không có phản ứng
        // nào, cả hoạt ảnh lẫn cuộn. Thanh công cụ chỉ giao chạm cho các
        // điều khiển thật sự (Button/NavigationLink).
        Button(action: chay) { than }
            .buttonStyle(.plain)
            .accessibilityLabel("CuongThai — về đầu trang")
    }

    private var than: some View {
        HStack(spacing: 7) {
            ZStack {
                // Nét nền — luôn thấy, kể cả khi không có hoạt ảnh.
                NetLogo()
                    .stroke(AppColors.primary.opacity(0.30), style: netDam)

                // Vệt sáng: một bản mờ to để toả quầng, một bản nét sắc đè lên.
                NetLogo()
                    .trim(from: duoi, to: dau)
                    .stroke(AppColors.brandGradient, style: netDam)
                    .blur(radius: 6)
                NetLogo()
                    .trim(from: duoi, to: dau)
                    .stroke(AppColors.brandGradient, style: netDam)
            }
            .frame(width: canh, height: canh)

            if coChu {
                Text("CuongThai")
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.brandGradient)
                    .fixedSize()
            }
        }
        .contentShape(Rectangle())
    }

    private func chay() {
        guard !dangChay else { return }
        dangChay = true
        Haptics.cham()
        khiBam()

        // Chặng 0: thu vệt về điểm xuất phát, KHÔNG hoạt ảnh.
        var tuc = Transaction(); tuc.disablesAnimations = true
        withTransaction(tuc) { dau = 0; duoi = 0 }

        // Chặng 1: đầu vệt chạy hết nét.
        withAnimation(.easeInOut(duration: 0.55)) { dau = 1 }
        // Chặng 2: đuôi đuổi theo — nét sáng dần "quét" qua rồi trả về nền.
        withAnimation(.easeInOut(duration: 0.55).delay(0.28)) { duoi = 1 }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            // Trả về trạng thái nghỉ: nét sáng phủ TOÀN BỘ (dau=1, duoi=0)
            // thì logo lúc không bấm cũng là logo sáng, không phải nét mờ.
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { dau = 1; duoi = 0 }
            dangChay = false
        }
    }
}
