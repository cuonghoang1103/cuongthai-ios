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
///
/// 22/10/2026 (rút gọn): ⌘1…⌘5 = năm điểm đến chính · ⌘K = tìm kiếm toàn cục
/// (tính năng + người + bài + khoá) · ⇧⌘A = Tất cả tính năng. Tính năng lẻ
/// không còn phím riêng — ⌘K rồi gõ hai chữ nhanh hơn nhớ mười một tổ hợp.
struct LenhDieuHuong: Commands {
    @ObservedObject var appState: AppState

    var body: some Commands {
        CommandMenu(T("Đi tới")) {
            ForEach(Array(AppState.AppTab.allCases.enumerated()), id: \.element) { i, tab in
                Button(tab.title) { appState.selectedTab = tab }
                    .keyboardShortcut(KeyEquivalent(Character(String(i + 1))), modifiers: .command)
            }
            Divider()
            Button(T("Tìm kiếm…")) { appState.bangGoc = .timKiem }
                .keyboardShortcut("k", modifiers: .command)
            Button(T("Tất cả tính năng")) { appState.moTatCa() }
                .keyboardShortcut("a", modifiers: [.command, .shift])
        }
    }
}
