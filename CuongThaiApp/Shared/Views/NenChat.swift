import SwiftUI

// ════════════════════════════════════════════════════════════════
// HÌNH NỀN KHUNG CHAT
//
// Vẽ bằng gradient + hình khối SwiftUI chứ KHÔNG dùng ảnh: ảnh nền đẹp thì
// nặng vài trăm KB mỗi tấm, nhân sáu là gói cài phình lên vô ích, và ảnh bitmap
// co giãn theo màn hình sẽ vỡ trên iPad. Vẽ bằng vector thì sắc nét ở mọi cỡ.
//
// Lựa chọn lưu TẠI MÁY theo từng hội thoại — máy chủ không có trường nào cho
// việc này, và đây vốn là tuỳ chọn riêng của người xem (Messenger cũng đồng bộ
// cho cả hai bên, nhưng làm vậy thì phải thêm cột vào DB).
// ════════════════════════════════════════════════════════════════

enum NenChat: String, CaseIterable, Identifiable {
    case macDinh, hoangHon, daiDuong, rungDem, anhDao, vuTru, giayKe

    var id: String { rawValue }

    var ten: String {
        switch self {
        case .macDinh:  return "Mặc định"
        case .hoangHon: return "Hoàng hôn"
        case .daiDuong: return "Đại dương"
        case .rungDem:  return "Rừng đêm"
        case .anhDao:   return "Anh đào"
        case .vuTru:    return "Vũ trụ"
        case .giayKe:   return "Giấy kẻ"
        }
    }

    /// Nền tối thì chữ phụ và vạch ngăn phải sáng lên, không thì chìm nghỉm.
    var laNenToi: Bool {
        switch self {
        case .rungDem, .vuTru: return true
        default: return false
        }
    }

    private var mau: [Color] {
        switch self {
        case .macDinh:  return []
        case .hoangHon: return [Color(hex: 0xFF9A6B), Color(hex: 0xC86DD7), Color(hex: 0x6A5AE0)]
        case .daiDuong: return [Color(hex: 0x89F7FE), Color(hex: 0x66A6FF), Color(hex: 0x3A7BD5)]
        case .rungDem:  return [Color(hex: 0x0F2027), Color(hex: 0x203A43), Color(hex: 0x2C5364)]
        case .anhDao:   return [Color(hex: 0xFFD3E0), Color(hex: 0xFFE9F0), Color(hex: 0xF8C8DC)]
        case .vuTru:    return [Color(hex: 0x0B0B2B), Color(hex: 0x1B1B4B), Color(hex: 0x2A1B5E)]
        case .giayKe:   return [Color(hex: 0xFDFBF6), Color(hex: 0xF6F1E7)]
        }
    }

    @ViewBuilder
    var lop: some View {
        switch self {
        case .macDinh:
            AppColors.backgroundPrimary
        case .vuTru:
            ZStack {
                LinearGradient(colors: mau, startPoint: .top, endPoint: .bottom)
                SaoNho()
            }
        case .giayKe:
            ZStack {
                LinearGradient(colors: mau, startPoint: .top, endPoint: .bottom)
                DongKe()
            }
        default:
            LinearGradient(colors: mau, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

/// Chấm sao rải theo mẫu CỐ ĐỊNH, không dùng `random`: SwiftUI vẽ lại thân view
/// mỗi lần trạng thái đổi, nên sao ngẫu nhiên sẽ NHẢY chỗ mỗi lần gõ một chữ.
private struct SaoNho: View {
    var body: some View {
        Canvas { ctx, cd in
            var h: UInt64 = 0x9E3779B97F4A7C15
            for _ in 0..<70 {
                h = h &* 6364136223846793005 &+ 1442695040888963407
                let x = Double((h >> 16) % 10_000) / 10_000 * cd.width
                let y = Double((h >> 32) % 10_000) / 10_000 * cd.height
                let r = Double((h >> 48) % 100) / 100 * 1.1 + 0.5
                let mo = Double((h >> 8) % 100) / 100 * 0.5 + 0.25
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)),
                         with: .color(.white.opacity(mo)))
            }
        }
    }
}

private struct DongKe: View {
    var body: some View {
        Canvas { ctx, cd in
            var y: CGFloat = 28
            while y < cd.height {
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: cd.width, y: y))
                }, with: .color(Color(hex: 0x9BB7D4).opacity(0.35)), lineWidth: 0.7)
                y += 28
            }
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: 46, y: 0)); p.addLine(to: CGPoint(x: 46, y: cd.height))
            }, with: .color(Color(hex: 0xE08D8D).opacity(0.45)), lineWidth: 0.9)
        }
    }
}

// MARK: - Nhớ lựa chọn theo từng hội thoại

enum KhoNenChat {
    private static func khoa(_ threadId: Int) -> String { "nen-chat-\(threadId)" }

    static func doc(_ threadId: Int) -> NenChat {
        guard let s = UserDefaults.standard.string(forKey: khoa(threadId)),
              let n = NenChat(rawValue: s) else { return .macDinh }
        return n
    }

    static func ghi(_ threadId: Int, _ nen: NenChat) {
        if nen == .macDinh {
            UserDefaults.standard.removeObject(forKey: khoa(threadId))
        } else {
            UserDefaults.standard.set(nen.rawValue, forKey: khoa(threadId))
        }
    }
}

// MARK: - Bảng chọn

struct BangChonNen: View {
    @Binding var dangChon: NenChat
    let luu: (NenChat) -> Void
    @Environment(\.dismiss) private var dismiss

    private let cot = [GridItem(.adaptive(minimum: 104), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: cot, spacing: 12) {
                    ForEach(NenChat.allCases) { n in
                        Button {
                            Haptics.cham()
                            dangChon = n
                            luu(n)
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    n.lop
                                    // Hai bong bóng giả để thấy TRƯỚC chữ có
                                    // đọc được trên nền đó không.
                                    VStack(alignment: .trailing, spacing: 5) {
                                        HStack {
                                            Capsule().fill(AppColors.backgroundTertiary)
                                                .frame(width: 46, height: 15)
                                            Spacer()
                                        }
                                        Capsule().fill(AppColors.primary)
                                            .frame(width: 56, height: 15)
                                    }
                                    .padding(9)
                                }
                                .frame(height: 108)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(dangChon == n ? AppColors.primary : AppColors.border,
                                                lineWidth: dangChon == n ? 2.5 : 1)
                                )
                                .overlay(alignment: .topTrailing) {
                                    if dangChon == n {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(.white, AppColors.primary)
                                            .padding(6)
                                    }
                                }

                                Text(n.ten)
                                    .font(.system(size: 12, weight: dangChon == n ? .semibold : .regular))
                                    .foregroundColor(dangChon == n ? AppColors.primary : AppColors.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Spacing.md)
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Hình nền")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Xong") { dismiss() }
                }
            }
        }
    }
}
