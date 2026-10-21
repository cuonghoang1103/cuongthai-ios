import SwiftUI

// MARK: - Đăng ký mô-đun Chat
//
// iPhone: TAB riêng (`.tabRieng`). Deep link `/work/<ws>/<KEY>/chat?c=<kênh>&m=<tin>&t=<chuỗi>`.
// Route con: `RouteKenhCTW` (một kênh).

extension CTWModule {
    static let chat = CTWModule(
        id: "chat", ten: "Chat", bieuTuong: "bubble.left.and.bubble.right", nhom: .giaoTiep,
        moTa: "Team channels and private groups", thuTu: 10, viTriIPhone: .tabRieng, doanWeb: "chat",
        // iPhone: tab Chat = Kênh · Tin nhắn · Thành viên (Modules/ThanhVien/HubChatCTW.swift).
        manTabIPhone: { AnyView(HubChatCTW()) },
        man: { c in AnyView(ChatCTW(nguCanh: c)) },
        dichDen: { v in
            AnyView(v.navigationDestination(for: RouteKenhCTW.self) { r in
                KenhChatCTW(pid: r.pid, kenh: r.kenh, tenDuAn: r.tenDuAn, toiTin: r.toiTin, moChuoi: r.moChuoi)
            })
        })
}
