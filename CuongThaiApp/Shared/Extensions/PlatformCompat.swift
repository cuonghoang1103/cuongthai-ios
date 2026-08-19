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
