import SwiftUI

// MARK: - Pháo nhỏ "Xong!" khi một thẻ vừa sang trạng thái DONE (21/10/2026)
//
// Bảng (dùng chung hai app) + chuyển nhanh ở My Work gọi `CTWNoXong.shared.phat()` SAU khi máy chủ nhận
// (không phải lúc vừa bấm). Lớp vẽ (`ctwLopNoXong()`) chỉ app CT Work gắn ở gốc — app chính không gắn nên lời gọi
// chỉ đổi một số đếm, không vẽ gì. Âm `xong.caf` đi qua móc `amThanh` (app CT Work đặt, theo công tắc Account ›
// Âm thanh). Giảm chuyển động ⇒ chỉ dấu tích mờ dần, không bắn hạt.

@MainActor
final class CTWNoXong: ObservableObject {
    static let shared = CTWNoXong()
    /// Tăng mỗi lần nổ — lớp vẽ nghe số này.
    @Published private(set) var lan = 0
    /// Móc âm thanh (app CT Work gán lúc khởi động).
    var amThanh: (() -> Void)?

    func phat() {
        lan += 1
        amThanh?()
    }

    /// Trạng thái đích có phải nhóm DONE không (cfg của dự án).
    static func laXong(_ statusId: Int, cfg: CTWProjectConfig?) -> Bool {
        cfg?.trangThai(statusId)?.category == "DONE"
    }
}

private struct LopNoXong: ViewModifier {
    @ObservedObject private var no = CTWNoXong.shared
    @State private var dangNo: Int?

    func body(content: Content) -> some View {
        content
            .overlay {
                if let lan = dangNo {
                    PhaoXongCTW()
                        .id(lan)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .onChange(of: no.lan) { _, moi in
                dangNo = moi
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_100_000_000)
                    if dangNo == moi { withAnimation(.easeOut(duration: 0.2)) { dangNo = nil } }
                }
            }
    }
}

extension View {
    /// Gắn ở gốc app CT Work: vẽ pháo "Xong!" khi `CTWNoXong.shared.phat()`.
    func ctwLopNoXong() -> some View { modifier(LopNoXong()) }
}

/// Dấu tích xanh nảy + 14 hạt màu bắn ra theo vòng tròn rồi rơi nhẹ.
struct PhaoXongCTW: View {
    @Environment(\.accessibilityReduceMotion) private var giam
    @State private var batDau = Date()

    private static let mau: [Color] = [AppColors.success, AppColors.primary, AppColors.accent, AppColors.secondary,
                                       Color(red: 1, green: 0.8, blue: 0.3)]

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSince(batDau)
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height * 0.42)
                let mo = 1 - DuongCong.doan(t, 0.7, 1.05)
                // Dấu tích trong vòng tròn.
                let co = giam ? 1 : CGFloat(DuongCong.loXo(t, tanSo: 14, giam: 8))
                let R: CGFloat = 34 * co
                var vong = ctx
                vong.opacity = mo
                vong.addFilter(.shadow(color: AppColors.success.opacity(0.35), radius: 14, y: 6))
                vong.fill(Path(ellipseIn: CGRect(x: c.x - R, y: c.y - R, width: R * 2, height: R * 2)), with: .color(AppColors.success))
                var tich = Path()
                tich.move(to: CGPoint(x: c.x - R * 0.42, y: c.y + R * 0.02))
                tich.addLine(to: CGPoint(x: c.x - R * 0.1, y: c.y + R * 0.34))
                tich.addLine(to: CGPoint(x: c.x + R * 0.46, y: c.y - R * 0.3))
                var ct = ctx
                ct.opacity = mo
                ct.stroke(tich.trimmedPath(from: 0, to: giam ? 1 : DuongCong.ra(DuongCong.doan(t, 0.08, 0.3))),
                          with: .color(.white), style: StrokeStyle(lineWidth: R * 0.17, lineCap: .round, lineJoin: .round))
                guard !giam else { return }
                // Hạt.
                let p = DuongCong.ra(DuongCong.doan(t, 0.05, 0.8))
                for i in 0..<14 {
                    let goc = Double(i) / 14 * 2 * .pi + 0.2
                    let xa = 58 + 34 * p + Double(i % 3) * 6
                    let x = c.x + CGFloat(cos(goc) * xa * p)
                    let y = c.y + CGFloat(sin(goc) * xa * p + 30 * p * p)
                    let r: CGFloat = i % 2 == 0 ? 4.5 : 3
                    var h = ctx
                    h.opacity = mo
                    let hinh = i % 3 == 0
                        ? Path(roundedRect: CGRect(x: x - r, y: y - r / 2, width: r * 2, height: r), cornerRadius: 1)
                        : Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                    h.fill(hinh, with: .color(Self.mau[i % Self.mau.count]))
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
