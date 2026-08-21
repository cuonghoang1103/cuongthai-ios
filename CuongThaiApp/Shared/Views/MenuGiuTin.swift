import SwiftUI

// ════════════════════════════════════════════════════════════════
// MENU NHẤN GIỮ KIỂU MESSENGER
//
// `.contextMenu` sẵn có của SwiftUI KHÔNG chèn được hàng cảm xúc lên trên
// menu — nó chỉ nhận danh sách nút. Mà hàng cảm xúc chính là thứ người dùng
// nhận ra ngay ở Messenger. Nên dựng tay:
//
//   nền mờ + tối  →  bong bóng NHẤC LÊN đúng chỗ nó đang nằm
//                 →  hàng cảm xúc phía trên
//                 →  danh sách hành động phía dưới
//
// Bong bóng phải ở ĐÚNG chỗ cũ, không phải giữa màn hình: mắt người dùng đang
// nhìn vào đó, nhảy chỗ là mất mạch. Vị trí lấy bằng `anchorPreference` —
// cách duy nhất biết được toạ độ thật của một view trong SwiftUI.
// ════════════════════════════════════════════════════════════════

/// Toạ độ bong bóng đang bị giữ, gửi ngược lên khung chat.
struct NeoTinKey: PreferenceKey {
    static var defaultValue: [Int: Anchor<CGRect>] = [:]
    static func reduce(value: inout [Int: Anchor<CGRect>], nextValue: () -> [Int: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, moi in moi }
    }
}

/// Một hành động trong menu.
struct HanhDongTin: Identifiable {
    let id = UUID()
    let ten: String
    let icon: String
    var doTuoi = false
    let chay: () -> Void
}

struct MenuGiuTin: View {
    /// Bong bóng gốc, vẽ lại y hệt.
    let bongBong: AnyView
    /// Khung của bong bóng trong toạ độ màn hình.
    let khung: CGRect
    let cuaMinh: Bool
    let camXuc: [String]
    let daChon: String?
    let thaCamXuc: (String) -> Void
    let hanhDong: [HanhDongTin]
    let dong: () -> Void

    @State private var hien = false

    private let caoHangCamXuc: CGFloat = 54
    private let caoMoiHang: CGFloat = 46

    var body: some View {
        GeometryReader { g in
            let caoMenu = CGFloat(hanhDong.count) * caoMoiHang + 16
            // Giữ nguyên chỗ cũ nếu vừa; không vừa thì đẩy lên vừa đủ để hàng
            // cảm xúc và menu không tràn ra ngoài màn hình.
            let tren = caoHangCamXuc + 14
            let duoi = caoMenu + 14
            let yMin = g.safeAreaInsets.top + tren + 8
            let yMax = g.size.height - g.safeAreaInsets.bottom - duoi - 8 - khung.height
            let yGoc = khung.minY
            let y = yMax < yMin ? yMin : min(max(yGoc, yMin), yMax)

            ZStack(alignment: .topLeading) {
                // Nền: chạm đâu cũng đóng.
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(Color.black.opacity(0.22))
                    .ignoresSafeArea()
                    .opacity(hien ? 1 : 0)
                    .onTapGesture { dongLai() }

                VStack(alignment: cuaMinh ? .trailing : .leading, spacing: 10) {
                    hangCamXuc
                    bongBong
                        .frame(width: khung.width, height: khung.height)
                    bangHanhDong
                }
                .frame(width: max(khung.width, 240),
                       alignment: cuaMinh ? .trailing : .leading)
                // Ghim theo mép PHẢI cho tin của mình, mép TRÁI cho tin người
                // khác — đúng phía bong bóng vốn nằm.
                .position(x: cuaMinh
                          ? khung.maxX - max(khung.width, 240) / 2
                          : khung.minX + max(khung.width, 240) / 2,
                          y: y + khung.height / 2)
                .scaleEffect(hien ? 1 : 0.92, anchor: cuaMinh ? .bottomTrailing : .bottomLeading)
                .opacity(hien ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { hien = true }
        }
    }

    private func dongLai() {
        withAnimation(.easeOut(duration: 0.18)) { hien = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { dong() }
    }

    private var hangCamXuc: some View {
        HStack(spacing: 4) {
            ForEach(camXuc, id: \.self) { e in
                Button {
                    Haptics.cham()
                    thaCamXuc(e)
                    dongLai()
                } label: {
                    Text(e)
                        .font(.system(size: 30))
                        .padding(5)
                        // Cảm xúc đang chọn được khoanh tròn — không thì bấm
                        // lại lần nữa để gỡ mà không biết mình đang thả cái gì.
                        .background(
                            Circle().fill(daChon == e
                                          ? AppColors.primary.opacity(0.25)
                                          : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(.regularMaterial)
                .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        )
    }

    private var bangHanhDong: some View {
        VStack(spacing: 0) {
            ForEach(Array(hanhDong.enumerated()), id: \.element.id) { i, h in
                Button {
                    Haptics.cham()
                    h.chay()
                    dongLai()
                } label: {
                    HStack {
                        Text(h.ten)
                            .font(.system(size: 16))
                            .foregroundColor(h.doTuoi ? AppColors.error : AppColors.textPrimary)
                        Spacer(minLength: 12)
                        Image(systemName: h.icon)
                            .font(.system(size: 15))
                            .foregroundColor(h.doTuoi ? AppColors.error : AppColors.textPrimary)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 46)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if i < hanhDong.count - 1 { Divider().padding(.leading, 16) }
            }
        }
        .frame(width: 240)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
        )
    }
}
