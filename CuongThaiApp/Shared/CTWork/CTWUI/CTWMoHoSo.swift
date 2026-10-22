import SwiftUI

// MARK: - Chạm avatar ⇒ mở hồ sơ người đó (22/10/2026)
//
// Dùng chung (cả hai app biên dịch): màn CT Work dùng chung (chi tiết thẻ, bình luận…) chỉ gắn `.ctwChamMoHoSo(id)` lên
// avatar. App CT Work đặt hành động vào môi trường ở gốc mỗi cột (`.ctwHoSoTamPhu()` — Modules/ThanhVien/HoSoNguoiCTW.swift)
// ⇒ tấm phủ hồ sơ kiểu Messenger. App chính không đặt ⇒ avatar vẫn là ảnh tĩnh như cũ (không đổi hành vi).

private struct CTWMoHoSoKhoa: EnvironmentKey {
    static let defaultValue: ((Int) -> Void)? = nil
}

extension EnvironmentValues {
    /// Mở hồ sơ một người theo user id. `nil` ⇒ nơi này không mở hồ sơ được.
    var ctwMoHoSo: ((Int) -> Void)? {
        get { self[CTWMoHoSoKhoa.self] }
        set { self[CTWMoHoSoKhoa.self] = newValue }
    }
}

private struct ChamMoHoSo: ViewModifier {
    let id: Int?
    @Environment(\.ctwMoHoSo) private var mo

    func body(content: Content) -> some View {
        if let id, id > 0, let mo {
            Button { mo(id) } label: { content }
                .buttonStyle(.plain)
                .accessibilityHint(Text("Opens their profile"))
        } else {
            content
        }
    }
}

extension View {
    /// Chạm ⇒ hồ sơ người `id` (khi nơi chứa có cài hành động mở hồ sơ).
    func ctwChamMoHoSo(_ id: Int?) -> some View { modifier(ChamMoHoSo(id: id)) }
}
