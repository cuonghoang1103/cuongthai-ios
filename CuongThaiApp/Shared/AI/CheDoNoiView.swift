import SwiftUI

// ════════════════════════════════════════════════════════════════
// NÓI CHUYỆN VỚI AI — RẢNH TAY
//
// Vòng: GIỮ mic nói → thả → AI trả lời → tự ĐỌC lên → sẵn sàng lượt sau.
// Không phải bấm gì giữa các lượt ngoài việc giữ mic.
//
// Dùng CHUNG `AIChatViewModel` với khung chat chữ, cố ý: lượt nói và lượt gõ
// nằm trong cùng một cuộc, cùng một lịch sử. Đóng chế độ nói ra là thấy
// nguyên hội thoại vừa rồi dưới dạng chữ — không phải hai thế giới rời nhau.
//
// ⚠️ HAI ĐIỀU KHÔNG ĐƯỢC PHÁ:
//
//  1. **Không bao giờ nghe trong lúc loa đang nói.** Micro sẽ thu chính giọng
//     AI, nhận ra thành chữ, gửi lại cho AI — hai bên tự nói với nhau và
//     người dùng ngồi nhìn. Mọi đường vào `batNghe()` đều phải qua `sanSang`.
//
//  2. **GIỮ để nói, THẢ để gửi.** Bản tự-cắt-theo-im-lặng đã thử ở mục Ngoại
//     ngữ và hỏng: đồng hồ chạy từ lúc BẬT mic chứ không phải từ lúc người ta
//     bắt đầu nói, nên ai cũng bị cắt trước khi kịp mở miệng.
// ════════════════════════════════════════════════════════════════

@MainActor
struct CheDoNoiView: View {
    @ObservedObject var vm: AIChatViewModel
    @ObservedObject var mayDoc: MayDoc
    @Environment(\.dismiss) private var dong
    @Environment(\.accessibilityReduceMotion) private var itChuyenDong

    @StateObject private var nghe = NgheLienTuc()
    @State private var daXinQuyen = false
    @State private var thieuQuyen = false
    @State private var dangGiu = false
    @State private var doiDoc: UUID?
    @State private var nhip = false

    /// Id các tin AI đã đọc rồi — không có nó thì mỗi lần khung vẽ lại là một
    /// lần đọc lại từ đầu.
    @State private var daDoc = Set<UUID>()

    private var tinCuoiCuaAI: TinAI? {
        vm.tin.last(where: { !$0.cuaNguoi && !$0.dangChay })
    }

    private var trangThai: String {
        if thieuQuyen { return "Cần quyền micro" }
        if nghe.dangNghe { return "Đang nghe…" }
        if vm.dangTraLoi { return "CuongMini đang nghĩ…" }
        if mayDoc.dangCho { return "Đang tạo giọng…" }
        if mayDoc.dangDoc != nil { return "Đang nói…" }
        return "Giữ nút mic rồi nói"
    }

    /// Rảnh hẳn — không nghe, không nghĩ, không nói.
    private var sanSang: Bool {
        !vm.dangTraLoi && mayDoc.dangDoc == nil && !mayDoc.dangCho
    }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                thanhTren
                Spacer(minLength: 0)
                quaCau
                Spacer(minLength: 0)
                loiDangNoi
                Text(trangThai)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.bottom, Spacing.lg)
                nutMic
                    .padding(.bottom, Spacing.xl)
            }
        }
        .task {
            // Xin quyền NGAY khi mở, không đợi tới lúc giữ nút: hộp xin quyền
            // bật lên đúng lúc người ta đang giữ ngón tay thì cử chỉ đứt, và
            // lượt nói đầu tiên mất trắng.
            daXinQuyen = await NgheLienTuc.xinQuyen()
            thieuQuyen = !daXinQuyen
        }
        .onAppear { noiDay() }
        .onDisappear { nghe.dung(); mayDoc.dung() }
        // Trả lời xong thì đọc lên — đây là mắt xích biến chat chữ thành hội thoại.
        .onChange(of: vm.dangTraLoi) { _, con in
            guard !con, let t = tinCuoiCuaAI, !daDoc.contains(t.id) else { return }
            daDoc.insert(t.id)
            doiDoc = t.id
            mayDoc.batTat(t.id, chu: t.noiDung)
        }
        .onChange(of: nghe.loi) { _, moi in
            if let moi, !moi.isEmpty { vm.loi = moi; nghe.loi = nil }
        }
    }

    // MARK: - Các mảnh

    private var thanhTren: some View {
        HStack {
            Button { dong() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(AppColors.backgroundTertiary))
            }
            Spacer()
            Text("Nói chuyện")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            // Giữ chỗ cho cân đối với nút đóng bên trái.
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
    }

    /// Quả cầu ở giữa — thứ duy nhất cho biết máy đang ở trạng thái nào khi
    /// người dùng không nhìn chữ.
    ///
    /// ⚠️ Bản đầu dùng `RadialGradient(center: .topLeading)` cho vầng sáng và
    /// mỗi vòng một nhịp riêng. Trên máy ảo nhìn ra ba vòng tròn rời nhau,
    /// lệch tâm, như giao diện vỡ. Nay: cùng MỘT tâm, cùng MỘT nhịp, vầng
    /// sáng toả từ giữa — không có cách nào lệch được nữa.
    private var quaCau: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(mauTrangThai.opacity(0.22 - Double(i) * 0.06), lineWidth: 1)
                    .frame(width: 172 + CGFloat(i) * 46, height: 172 + CGFloat(i) * 46)
            }
            Circle()
                .fill(mauTrangThai.opacity(0.18))
                .frame(width: 172, height: 172)
                .blur(radius: 18)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [mauTrangThai.opacity(0.95), mauTrangThai.opacity(0.55)],
                        startPoint: .top, endPoint: .bottom))
                .frame(width: 132, height: 132)
                .overlay(
                    Image(systemName: bieuTuongTrangThai)
                        .font(.system(size: 42, weight: .light))
                        .foregroundColor(.white.opacity(0.95)))
                .shadow(color: mauTrangThai.opacity(0.45), radius: 24)
        }
        .frame(width: 264, height: 264)
        .scaleEffect(nhip && !itChuyenDong ? 1.05 : 1.0)
        .animation(
            itChuyenDong ? nil
                : .easeInOut(duration: 1.7).repeatForever(autoreverses: true),
            value: nhip)
        .animation(.easeInOut(duration: 0.3), value: mauTrangThai)
        .onAppear { nhip = true }
    }

    private var mauTrangThai: Color {
        if nghe.dangNghe { return AppColors.primary }
        if vm.dangTraLoi || mayDoc.dangCho { return AppColors.textSecondary }
        if mayDoc.dangDoc != nil { return .green }
        return AppColors.primary.opacity(0.6)
    }

    private var bieuTuongTrangThai: String {
        if nghe.dangNghe { return "waveform" }
        if vm.dangTraLoi || mayDoc.dangCho { return "ellipsis" }
        if mayDoc.dangDoc != nil { return "speaker.wave.3.fill" }
        return "mic.fill"
    }

    /// Chữ nghe được, hiện ngay trong lúc nói.
    ///
    /// Không có nó thì người dùng giữ nút, nói xong, thả ra và không biết máy
    /// có nghe được gì không — chỉ thấy một khoảng lặng rồi AI trả lời trật.
    private var loiDangNoi: some View {
        Group {
            if !nghe.chuTamThoi.isEmpty {
                Text(nghe.chuTamThoi)
                    .font(.system(size: 17))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            } else if let t = tinCuoiCuaAI, mayDoc.dangDoc == t.id {
                Text(t.noiDung.prefix(180))
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }
        }
        .frame(minHeight: 84)
        .padding(.horizontal, Spacing.xl)
        .animation(.easeInOut(duration: 0.2), value: nghe.chuTamThoi)
    }

    private var nutMic: some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(dangGiu ? AppColors.primary : AppColors.backgroundTertiary)
                    .frame(width: 84, height: 84)
                    .scaleEffect(dangGiu ? 1.12 : 1.0)
                    .animation(.spring(response: 0.28, dampingFraction: 0.6), value: dangGiu)
                Image(systemName: "mic.fill")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundColor(dangGiu ? .white : AppColors.textSecondary)
            }
            // ⚠️ `.contentShape` để cả vòng tròn ăn cử chỉ, không chỉ mỗi
            // hình cái mic bên trong.
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !dangGiu, sanSang, daXinQuyen else { return }
                        dangGiu = true
                        Haptics.cham()
                        // Cắt tiếng AI nếu người dùng muốn chen ngang — đúng
                        // như nói chuyện với người.
                        mayDoc.dung()
                        nghe.batDau(code: "vi")
                    }
                    .onEnded { _ in
                        guard dangGiu else { return }
                        dangGiu = false
                        Haptics.cham()
                        guard nghe.dangNghe else { return }
                        nghe.chotNgay()
                    }
            )
            .disabled(!sanSang || !daXinQuyen)
            .opacity(sanSang && daXinQuyen ? 1 : 0.45)

            Text(thieuQuyen
                 ? "Bật micro và Nhận dạng giọng nói trong Cài đặt để nói chuyện"
                 : "Giữ để nói · thả để gửi")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
        }
    }

    // MARK: - Nối dây

    private func noiDay() {
        nghe.khiXongCau = { chu in
            Task { @MainActor in
                let sach = chu.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !sach.isEmpty else { return }
                vm.gui(sach)
            }
        }
        nghe.khiRong = {
            Task { @MainActor in
                vm.loi = "Chưa nghe rõ, thử nói lại gần micro hơn nhé."
            }
        }
        // Tin AI đã có sẵn trước khi mở chế độ nói thì KHÔNG đọc lại — người
        // dùng đã đọc chúng bằng mắt rồi.
        for t in vm.tin where !t.cuaNguoi { daDoc.insert(t.id) }
    }
}
