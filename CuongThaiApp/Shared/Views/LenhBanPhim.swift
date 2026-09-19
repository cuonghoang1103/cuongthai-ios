import SwiftUI

/// Phím tắt bàn phím — iPad có Magic Keyboard, và bản macOS.
///
/// Vì sao cần: đo 19/09/2026 thì cả app KHÔNG có một `.keyboardShortcut` nào.
/// Người dùng cắm bàn phím vào iPad Pro mà vẫn phải rời tay ra chạm màn hình
/// để đổi module — thứ mà mọi app máy tính làm bằng một phím.
///
/// Đặt ở tầng `Scene` chứ không rải vào từng màn: `.commands` là chỗ DUY NHẤT
/// iPadOS gom phím tắt để hiện ra khi giữ ⌘, và nó sống bất kể đang mở màn
/// nào. Rải `.keyboardShortcut` vào nút trong màn thì phím chỉ ăn khi cái nút
/// đó đang nằm trên cây hiển thị.
struct LenhDieuHuong: Commands {
    @ObservedObject var appState: AppState

    var body: some Commands {
        CommandMenu(T("Đi tới")) {
            ForEach(AppState.AppTab.allCases) { tab in
                Button(tab.title) { appState.selectedTab = tab }
                    .keyboardShortcut(Self.phim(tab), modifiers: .command)
            }
        }
    }

    /// ⌘1…⌘9 rồi ⌘0 cho mục thứ MƯỜI — đúng nếp Safari/Finder/Chrome đã dùng
    /// hàng chục năm, nên không ai phải học lại.
    ///
    /// ⚠️ Quá 10 mục thì phải nghĩ lại cách gán, không được lặng lẽ để mấy
    /// mục cuối không có phím: người dùng đếm tới mục thứ 11 rồi bấm ⌘1 và
    /// nhảy về đầu, không hiểu vì sao.
    private static func phim(_ t: AppState.AppTab) -> KeyEquivalent {
        let i = t.rawValue
        return KeyEquivalent(Character(i < 9 ? String(i + 1) : "0"))
    }
}
