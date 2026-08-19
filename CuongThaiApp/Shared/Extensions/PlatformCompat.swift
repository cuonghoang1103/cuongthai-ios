import SwiftUI

// MARK: - macOS Compatibility Shims
// The Shared views are written with iOS navigation APIs. These shims let the
// same code compile on macOS without sprinkling `#if os(iOS)` at every call site.
#if os(macOS)

// `navigationBarTitleDisplayMode(_:)` is iOS-only. Provide a no-op that accepts
// the same `.automatic` / `.inline` / `.large` call syntax.
struct BarTitleDisplayMode {
    static let automatic = BarTitleDisplayMode()
    static let inline = BarTitleDisplayMode()
    static let large = BarTitleDisplayMode()
}

extension View {
    func navigationBarTitleDisplayMode(_ mode: BarTitleDisplayMode) -> some View { self }
}

// `.navigationBarLeading` / `.navigationBarTrailing` placements don't exist on
// macOS — map them to the nearest cross-platform toolbar placements.
extension ToolbarItemPlacement {
    static var navigationBarLeading: ToolbarItemPlacement { .navigation }
    static var navigationBarTrailing: ToolbarItemPlacement { .primaryAction }
}

#endif


// MARK: - Bàn phím: iOS có, macOS không
//
// `textInputAutocapitalization` và `keyboardType` CHỈ tồn tại trên iOS. Gọi
// thẳng trong file dùng chung thì target iOS xanh còn macOS đỏ — và lỗi báo ra
// là "cannot infer contextual base in reference to member 'never'", đọc không
// ra nguyên nhân. Hai hàm dưới bọc lại, trên macOS thành lệnh rỗng.

extension View {
    /// Không tự viết hoa, không tự sửa chính tả — cho tên đăng nhập, email.
    func oKhongTuSua() -> some View {
        #if os(iOS)
        return self.textInputAutocapitalization(.never).autocorrectionDisabled()
        #else
        return self.autocorrectionDisabled()
        #endif
    }

    /// Bàn phím có sẵn phím @ và dấu chấm.
    func banPhimEmail() -> some View {
        #if os(iOS)
        return self.keyboardType(.emailAddress)
        #else
        return self
        #endif
    }
}
