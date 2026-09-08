import SwiftUI

// ════════════════════════════════════════════════════════════════
// ROBOT CHÀO MỪNG — hero của trang chủ
//
// Bản iOS của con robot trên web (`LandingRobotRail.tsx`), nhưng KHÔNG bê
// nguyên SVG sang: vẽ thẳng bằng SwiftUI Shape.
//   • nét ở mọi kích thước và mọi tỉ lệ màn hình, không cần @2x/@3x
//   • đổi màu theo AppColors, nên chế độ sáng/tối tự khớp
//   • không thêm một byte tài nguyên nào vào gói cài
//
// ⚠️ Tôn trọng "Giảm chuyển động" của hệ thống. Người bật nó thường vì chóng
// mặt/say chuyển động — hiệu ứng gõ chữ chạy liên tục là đúng thứ gây khó
// chịu. Bật thì hiện thẳng trạng thái cuối, không animation nào.
// ════════════════════════════════════════════════════════════════

/// Một dòng trong "màn hình" của robot.
private struct DongCode {
    let chu: String
    /// Dòng kết — hiện to, đậm, màu nhấn. Các dòng trên là code phụ hoạ.
    var laKet = false
}

private let KICH_BAN: [DongCode] = [
    .init(chu: "let hocVien = \"Cường\""),
    .init(chu: "func chaoMung(_ ai: String)"),
    .init(chu: "print(chaoMung(hocVien))"),
    .init(chu: "Welcome to CuongThai", laKet: true),
]

struct RobotChaoMung: View {
    /// Tên hiện dưới lời chào. Rỗng thì chỉ chào chung.
    var ten: String?

    @Environment(\.accessibilityReduceMotion) private var giamChuyenDong

    /// Số dòng đã gõ xong, và phần chữ đang gõ dở của dòng hiện tại.
    @State private var dongXong = 0
    @State private var chuDangGo = ""
    @State private var hienConTro = true
    @State private var nhayMat = false
    @State private var sangAngten = false
    @State private var daXong = false
    @State private var dangTho = false

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            robot
            manHinh
        }
        .padding(Spacing.md)
        .background(nen)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AppColors.primary.opacity(0.22), lineWidth: 1)
        )
        .task { await chay() }
        // Người dùng đọc bằng VoiceOver không cần nghe từng dòng code phụ hoạ.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Welcome to CuongThai"))
    }

    // ── Nền: dải sáng chéo rất nhẹ, không chọi với nội dung ──────
    private var nen: some View {
        LinearGradient(
            colors: [AppColors.primary.opacity(0.16),
                     AppColors.secondary.opacity(0.10),
                     AppColors.backgroundCard],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // ── Con robot ────────────────────────────────────────────────
    //
    // Vẽ phẳng mà trông có KHỐI: không có mẹo nào ngoài việc xếp đúng thứ tự
    // ba lớp ánh sáng thật — nguồn sáng chính trên-trái, viền sáng ôm mép
    // trên, và bóng đổ xuống nền. Bỏ một lớp là nó lại thành hình dán.
    private var robot: some View {
        VStack(spacing: 0) {
            angTen
            khoiDau
            khoiThan
            // Bóng đổ dưới chân: elip mờ, hẹp hơn thân. Đây là thứ khiến con
            // robot "đứng trên" mặt phẳng thay vì lơ lửng như sticker.
            Ellipse()
                .fill(Color.black.opacity(0.28))
                .frame(width: 46, height: 7)
                .blur(radius: 5)
                .offset(y: 1)
        }
        .frame(width: 72)
        // Thở nhẹ lên xuống — biên độ 3pt, đủ để thấy là "đang sống" mà
        // không kéo mắt khỏi phần chữ bên cạnh.
        .offset(y: dangTho ? -3 : 0)
    }

    private var angTen: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(AppColors.success)
                    .frame(width: 7, height: 7)
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 2.5, height: 2.5)
                    .offset(x: -1.2, y: -1.2)
            }
            .shadow(color: AppColors.success.opacity(sangAngten ? 0.95 : 0.25),
                    radius: sangAngten ? 7 : 2)
            .scaleEffect(sangAngten ? 1.12 : 0.94)

            Capsule()
                .fill(LinearGradient(colors: [AppColors.textTertiary.opacity(0.75),
                                              AppColors.textTertiary.opacity(0.30)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 2, height: 8)
        }
    }

    private var khoiDau: some View {
        ZStack {
            // Vỏ đầu: dốc sáng từ trên-trái xuống dưới-phải.
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.white.opacity(0.26),
                             AppColors.primary.opacity(0.42),
                             AppColors.primary.opacity(0.20)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 64, height: 52)

            // Viền sáng ôm mép trên-trái, tối dần xuống dưới-phải.
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(LinearGradient(
                    colors: [Color.white.opacity(0.55),
                             AppColors.primary.opacity(0.30),
                             Color.black.opacity(0.22)],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.3)
                .frame(width: 64, height: 52)

            // Kính che mặt: hõm tối, để mắt sáng nổi bật trên nền đen.
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(LinearGradient(colors: [Color.black.opacity(0.80),
                                                  Color.black.opacity(0.55)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 48, height: 32)

                HStack(spacing: 12) { mat; mat }

                // Vệt loá trên mặt kính — nửa trên, xiên. Chi tiết nhỏ này
                // làm phẳng thành cong.
                Ellipse()
                    .fill(LinearGradient(colors: [Color.white.opacity(0.30), .clear],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 42, height: 14)
                    .offset(y: -9)
                    .blur(radius: 1.5)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.45), lineWidth: 1)
                    .frame(width: 48, height: 32)
            )

            // Hai tai: khối nhỏ hai bên, gợi chiều sâu ngang.
            HStack {
                tai
                Spacer(minLength: 0)
                tai
            }
            .frame(width: 74)
        }
        .shadow(color: Color.black.opacity(0.30), radius: 7, y: 4)
    }

    private var tai: some View {
        Capsule()
            .fill(LinearGradient(colors: [AppColors.primary.opacity(0.55),
                                          AppColors.primary.opacity(0.22)],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: 6, height: 16)
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 0.8))
    }

    private var khoiThan: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.white.opacity(0.18),
                             AppColors.primary.opacity(0.34),
                             AppColors.primary.opacity(0.14)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 46, height: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(LinearGradient(
                            colors: [Color.white.opacity(0.45), Color.black.opacity(0.20)],
                            startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                )

            // Đèn ngực: sáng theo cùng nhịp với ăng-ten.
            Circle()
                .fill(AppColors.secondary)
                .frame(width: 6, height: 6)
                .shadow(color: AppColors.secondary.opacity(sangAngten ? 0.9 : 0.3),
                        radius: sangAngten ? 5 : 1.5)
        }
        .offset(y: -3)
        .shadow(color: Color.black.opacity(0.25), radius: 5, y: 3)
    }

    /// Một con mắt. Nháy = co chiều cao xuống gần 0 trong chốc lát.
    private var mat: some View {
        Capsule()
            .fill(LinearGradient(colors: [Color.white, AppColors.primary],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: 9, height: nhayMat ? 1.5 : 13)
            .shadow(color: AppColors.primary.opacity(0.95), radius: 5)
            .shadow(color: AppColors.primary.opacity(0.55), radius: 10)
    }

    // ── "Màn hình" chữ ───────────────────────────────────────────
    private var manHinh: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Ba chấm kiểu thanh tiêu đề cửa sổ — báo cho mắt biết đây là
            // một khung terminal, không phải chữ trôi nổi.
            HStack(spacing: 4) {
                ForEach([AppColors.error, AppColors.warning, AppColors.success], id: \.self) { c in
                    Circle().fill(c.opacity(0.75)).frame(width: 6, height: 6)
                }
                Spacer(minLength: 0)
            }
            .padding(.bottom, 1)

            ForEach(Array(KICH_BAN.enumerated()), id: \.offset) { i, d in
                if i < dongXong {
                    dong(d, d.chu)
                } else if i == dongXong {
                    dong(d, chuDangGo, dangGo: true)
                }
            }

            if let t = ten, !t.isEmpty, daXong {
                Text("Chào \(t) 👋")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Chốt chiều cao: chữ gõ dần làm khối cao dần, và cả trang chủ bên
        // dưới sẽ nhảy giật theo từng ký tự nếu không giữ chỗ sẵn.
        .frame(minHeight: 104, alignment: .top)
    }

    @ViewBuilder
    private func dong(_ d: DongCode, _ chu: String, dangGo: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if d.laKet {
                Text("▸")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColors.success)
                Text(chu)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
            } else {
                Text(chu)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(AppColors.textTertiary)
            }
            if dangGo && hienConTro {
                Rectangle()
                    .fill(d.laKet ? AppColors.success : AppColors.primary)
                    .frame(width: 6, height: d.laKet ? 15 : 12)
            }
            Spacer(minLength: 0)
        }
    }

    // ── Chạy hiệu ứng ────────────────────────────────────────────
    private func chay() async {
        // Đã chạy rồi thì thôi — `.task` chạy lại mỗi lần view xuất hiện
        // lại (đổi tab rồi quay về), và gõ lại từ đầu mỗi lần là phiền.
        guard dongXong == 0, chuDangGo.isEmpty else { return }

        guard !giamChuyenDong else {
            dongXong = KICH_BAN.count
            daXong = true
            hienConTro = false
            return
        }

        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            sangAngten = true
        }
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            dangTho = true
        }
        Task { await nhay() }
        Task { await nhapNhayConTro() }

        for (i, d) in KICH_BAN.enumerated() {
            for ky in d.chu {
                guard !Task.isCancelled else { return }
                chuDangGo.append(ky)
                // Dòng kết gõ chậm hơn để mắt kịp đọc câu chào.
                try? await Task.sleep(nanoseconds: d.laKet ? 55_000_000 : 22_000_000)
            }
            try? await Task.sleep(nanoseconds: 260_000_000)
            guard !Task.isCancelled else { return }
            dongXong = i + 1
            chuDangGo = ""
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
            daXong = true
        }
        hienConTro = false
    }

    private func nhay() async {
        while !Task.isCancelled {
            // Khoảng nghỉ ngẫu nhiên — nháy đều tăm tắp trông như máy hỏng.
            try? await Task.sleep(nanoseconds: UInt64.random(in: 2_200_000_000...4_500_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.07)) { nhayMat = true }
            try? await Task.sleep(nanoseconds: 90_000_000)
            withAnimation(.easeInOut(duration: 0.09)) { nhayMat = false }
        }
    }

    private func nhapNhayConTro() async {
        while !Task.isCancelled && !daXong {
            try? await Task.sleep(nanoseconds: 480_000_000)
            hienConTro.toggle()
        }
    }
}
