#if os(iOS)
import SwiftUI
import PencilKit

// ════════════════════════════════════════════════════════════════
// THANH BÚT TRONG APP — bút · bút dạ · bút chì · tẩy · màu · độ dày
//
// Vì sao không chỉ dựa vào `PKToolPicker` của hệ thống: nó là một bảng NỔI
// gắn vào cửa sổ, và khi nó không gắn được (cửa sổ chưa sẵn sàng, Stage
// Manager hai cửa sổ, hoặc người dùng lỡ tắt) thì màn vẽ không còn MỘT cách
// nào để đổi bút — đúng tình huống người dùng gặp 20/09/2026: "ấn nút không
// có tẩy, bút, màu".
//
// Thanh này nằm TRONG màn hình nên không thể biến mất, và vẫn giữ song song
// bảng của hệ thống cho ai quen dùng.
// ════════════════════════════════════════════════════════════════

/// Trạng thái bút dùng chung giữa thanh công cụ và khung vẽ.
@MainActor
final class BoBut: ObservableObject {
    @Published var loai: LoaiBut = .but
    @Published var mau: Color = .black
    @Published var day: CGFloat = 3

    enum LoaiBut: String, CaseIterable, Identifiable {
        case but, butDa, butChi, buTLong, tay
        var id: String { rawValue }
        var ten: String {
            switch self {
            case .but:     return T("Bút")
            case .butDa:   return T("Bút dạ")
            case .butChi:  return T("Bút chì")
            case .buTLong: return T("Bút lông")
            case .tay:     return T("Tẩy")
            }
        }
        var icon: String {
            switch self {
            case .but:     return "pencil.tip"
            case .butDa:   return "highlighter"
            case .butChi:  return "pencil"
            case .buTLong: return "paintbrush.pointed"
            case .tay:     return "eraser"
            }
        }
        /// Khoảng độ dày hợp lý cho từng loại — bút dạ 1pt thì vô nghĩa,
        /// bút chì 40pt cũng vậy.
        var khoangDay: ClosedRange<CGFloat> {
            switch self {
            case .butDa:   return 8...60
            case .tay:     return 10...80
            default:       return 1...30
            }
        }
    }

    /// Đổi sang công cụ PencilKit tương ứng.
    var congCu: PKTool {
        switch loai {
        case .but:     return PKInkingTool(.pen, color: UIColor(mau), width: day)
        case .butDa:   return PKInkingTool(.marker, color: UIColor(mau), width: day)
        case .butChi:  return PKInkingTool(.pencil, color: UIColor(mau), width: day)
        case .buTLong: return PKInkingTool(.crayon, color: UIColor(mau), width: day)
        // Tẩy VÙNG chứ không tẩy cả nét: xoá nguyên nét thì sửa một chi
        // tiết nhỏ trong sơ đồ là mất cả đường.
        case .tay:     return PKEraserTool(.bitmap, width: day)
        }
    }
}

struct ThanhBut: View {
    @ObservedObject var bo: BoBut
    var hoanTac: (() -> Void)?
    var lamLai: (() -> Void)?
    var xoaHet: (() -> Void)?

    /// Bảng màu cho giảng dạy: đen để viết, đỏ để nhấn, xanh để chú thích,
    /// vàng để tô sáng. Bốn màu đó phủ gần hết việc trên bảng.
    private static let bangMau: [Color] = [
        .black, .red, .blue, .green, .orange,
        Color(red: 0.55, green: 0.25, blue: 0.85),
        Color(red: 0.95, green: 0.78, blue: 0.10),
        .white,
    ]

    var body: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                ForEach(BoBut.LoaiBut.allCases) { l in
                    Button {
                        bo.loai = l
                        bo.day = min(max(bo.day, l.khoangDay.lowerBound), l.khoangDay.upperBound)
                    } label: {
                        Image(systemName: l.icon)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(bo.loai == l ? AppColors.onPrimary : AppColors.textSecondary)
                            .frame(width: 40, height: 34)
                            .background(RoundedRectangle(cornerRadius: 8)
                                .fill(bo.loai == l ? AppColors.primary : .clear))
                    }
                    .accessibilityLabel(l.ten)
                }

                Divider().frame(height: 26)

                // Màu: tẩy thì không có màu, ẩn đi cho khỏi bấm nhầm.
                if bo.loai != .tay {
                    ForEach(Array(Self.bangMau.enumerated()), id: \.offset) { _, m in
                        Button { bo.mau = m } label: {
                            Circle()
                                .fill(m)
                                .frame(width: 22, height: 22)
                                .overlay(Circle().stroke(
                                    bo.mau == m ? AppColors.primary : AppColors.border,
                                    lineWidth: bo.mau == m ? 2.5 : 1))
                        }
                    }
                    ColorPicker("", selection: $bo.mau)
                        .labelsHidden()
                        .frame(width: 28)
                }

                Spacer(minLength: Spacing.sm)

                if let h = hoanTac {
                    Button(action: h) { Image(systemName: "arrow.uturn.backward") }
                        .frame(width: 34, height: 30)
                }
                if let l = lamLai {
                    Button(action: l) { Image(systemName: "arrow.uturn.forward") }
                        .frame(width: 34, height: 30)
                }
                if let x = xoaHet {
                    Button(role: .destructive, action: x) { Image(systemName: "trash") }
                        .frame(width: 34, height: 30)
                }
            }

            HStack(spacing: Spacing.sm) {
                Image(systemName: "lineweight").font(.caption)
                    .foregroundStyle(AppColors.textTertiary)
                Slider(value: $bo.day, in: bo.loai.khoangDay)
                Text(String(format: "%.0f", bo.day))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppColors.textTertiary).frame(width: 26)
                // Xem trước độ dày THẬT: con số 12 không nói lên điều gì
                // cho tới khi thấy nét dày bao nhiêu.
                Capsule()
                    .fill(bo.loai == .tay ? AppColors.textTertiary : bo.mau)
                    .frame(width: 44, height: max(2, min(bo.day, 26)))
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(AppColors.backgroundCard)
    }
}
#endif
