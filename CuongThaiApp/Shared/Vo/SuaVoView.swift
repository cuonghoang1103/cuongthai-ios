#if os(iOS)
import SwiftUI

/// Bảng màu dùng chung cho gáy môn và bìa vở. Lấy thẳng tông thương hiệu của
/// web nên vở nhìn ra là của cùng một sản phẩm.
enum MauVo {
    static let bang: [Int] = [
        0x7A45E8, 0x2E6FD9, 0x0E93A6, 0x1A8F35,
        0xB47600, 0xD97706, 0xD32F2F, 0xDB2777,
        0x6B7280, 0x14141C,
    ]
}

// MARK: - Tạo / sửa MÔN

struct SuaMonView: View {
    let mon: MonVo?
    let xong: (String, String, Int) -> Void

    @Environment(\.dismiss) private var dong
    @State private var ten = ""
    @State private var emoji = "📘"
    @State private var mau = MauVo.bang[0]
    @FocusState private var dangGoTen: Bool

    private let emojiGoiY = ["📘", "📐", "🧪", "🇯🇵", "🇬🇧", "💻", "🎨", "🎵",
                             "🧬", "🌏", "⚖️", "💰", "🩺", "📖", "✏️", "🔭"]

    var body: some View {
        NavigationStack {
            Form {
                Section(T("Tên môn")) {
                    TextField(T("Ví dụ: Toán cao cấp"), text: $ten)
                        .focused($dangGoTen)
                        .submitLabel(.done)
                }
                Section(T("Biểu tượng")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8),
                              spacing: Spacing.sm) {
                        ForEach(emojiGoiY, id: \.self) { e in
                            Button { emoji = e } label: {
                                Text(e)
                                    .font(.system(size: 26))
                                    .frame(width: 40, height: 40)
                                    .background(
                                        RoundedRectangle(cornerRadius: CornerRadius.small)
                                            .fill(emoji == e ? AppColors.primary.opacity(0.18)
                                                             : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, Spacing.xs)
                }
                Section(T("Màu")) {
                    ChonMau(dangChon: $mau)
                }
            }
            .navigationTitle(mon == nil ? T("Môn mới") : T("Sửa môn"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // ⚠️ Cửa sổ nào cũng phải có nút đóng. Sheet không lối ra đã
                // khiến người dùng báo "app đơ" — họ bấm khắp nơi mà không
                // biết phải vuốt xuống.
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Huỷ")) { dong() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Xong")) {
                        xong(ten.trimmingCharacters(in: .whitespacesAndNewlines), emoji, mau)
                        dong()
                    }
                    .disabled(ten.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let m = mon { ten = m.ten; emoji = m.emoji; mau = m.mauHex }
                // Bàn phím lên sẵn: mở ra là gõ được ngay, không phải chạm thêm.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { dangGoTen = true }
            }
        }
    }
}

// MARK: - Lập CUỐN VỞ

struct LapCuonVoView: View {
    let mauGoiY: Int
    let xong: (String, Int, LoaiGiay, HuongGiay) -> Void

    @Environment(\.dismiss) private var dong
    @State private var ten = ""
    @State private var mau: Int
    @State private var giay: LoaiGiay = .keNgang
    @State private var huong: HuongGiay = .doc
    @FocusState private var dangGoTen: Bool

    init(mauGoiY: Int, xong: @escaping (String, Int, LoaiGiay, HuongGiay) -> Void) {
        self.mauGoiY = mauGoiY
        self.xong = xong
        _mau = State(initialValue: mauGoiY)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(T("Tên cuốn vở")) {
                    TextField(T("Ví dụ: Học kỳ 1 — Giải tích"), text: $ten)
                        .focused($dangGoTen)
                }

                Section(T("Giấy")) {
                    ForEach(LoaiGiay.allCases) { g in
                        Button { giay = g } label: {
                            HStack(spacing: Spacing.md) {
                                Image(systemName: g.bieuTuong)
                                    .frame(width: 26)
                                    .foregroundStyle(giay == g ? AppColors.primary
                                                               : AppColors.textSecondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(g.ten)
                                        .font(Font.bodyLarge)
                                        .foregroundStyle(AppColors.textPrimary)
                                    Text(g.moTa)
                                        .font(.caption)
                                        .foregroundStyle(AppColors.textTertiary)
                                }
                                Spacer()
                                if giay == g {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppColors.primary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section(T("Hướng giấy")) {
                    Picker(T("Hướng"), selection: $huong) {
                        ForEach(HuongGiay.allCases) { Text($0.ten).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section(T("Màu bìa")) {
                    ChonMau(dangChon: $mau)
                }
            }
            .navigationTitle(T("Cuốn vở mới"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Huỷ")) { dong() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Lập vở")) {
                        let t = ten.trimmingCharacters(in: .whitespacesAndNewlines)
                        xong(t.isEmpty ? T("Vở mới") : t, mau, giay, huong)
                        dong()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { dangGoTen = true }
            }
        }
    }
}

// MARK: - Ô chọn màu

struct ChonMau: View {
    @Binding var dangChon: Int

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5),
                  spacing: Spacing.sm) {
            ForEach(MauVo.bang, id: \.self) { m in
                Button { dangChon = m } label: {
                    Circle()
                        .fill(Color(hex: UInt32(m)))
                        .frame(width: 36, height: 36)
                        .overlay {
                            if dangChon == m {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .overlay {
                            Circle().strokeBorder(AppColors.border, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}
#endif
