import SwiftUI

// MARK: - Đăng ký mô-đun Chat
//
// iPhone: TAB riêng (`.tabRieng`). Deep link `/work/<ws>/<KEY>/chat?c=<kênh>`.
// Route con: `RouteKenhCTW` (một kênh).

extension CTWModule {
    static let chat = CTWModule(
        id: "chat", ten: "Chat", bieuTuong: "bubble.left.and.bubble.right", nhom: .giaoTiep,
        moTa: "Team channels", thuTu: 10, viTriIPhone: .tabRieng, doanWeb: "chat",
        man: { c in AnyView(ChatCTW(nguCanh: c)) },
        dichDen: { v in
            AnyView(v.navigationDestination(for: RouteKenhCTW.self) { r in
                KenhChatCTW(pid: r.pid, kenh: r.kenh, tenDuAn: r.tenDuAn)
            })
        })
}
