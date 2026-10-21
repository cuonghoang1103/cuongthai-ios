import SwiftUI

// MARK: - Đăng ký mô-đun Thành viên + Tin nhắn riêng (21/10/2026)
//
// Cả hai là mô-đun CẤP ỨNG DỤNG (`capUngDung` — không cần dự án):
//   · iPad: hai mục ở khối đầu thanh bên (cạnh My Work, Inbox).
//   · iPhone: nằm TRONG tab Chat (`tabIPhone: "chat"`) — tab Chat = Kênh · Tin nhắn · Thành viên (`HubChatCTW`).
//     Không thêm tab thứ 6: iPhone chỉ hiện 5 tab, tab thứ 6 đẩy Inbox + Account vào "More".
// Deep link: `ctwork://dm/<threadId>` (chạm thông báo tin nhắn), `ctwork://members`.

/// Màn chat 1-1 trong ngăn xếp.
struct RouteChatRiengCTW: Hashable { var threadId: Int }
/// Hồ sơ một thành viên (đẩy trên iPad / iPhone khi không dùng tấm phủ).
struct RouteHoSoThanhVienCTW: Hashable { var userId: Int }

extension CTWModule {
    static let tinNhan = CTWModule(
        id: "tin-nhan", ten: "Messages", bieuTuong: "bubble.left.and.text.bubble.right", nhom: .giaoTiep,
        moTa: "Direct messages with your teammates", thuTu: 1, capUngDung: true, tabIPhone: "chat",
        man: { _ in AnyView(DanhSachTinNhanCTW()) },
        dichDen: { v in
            AnyView(v
                .navigationDestination(for: RouteChatRiengCTW.self) { r in ChatRiengCTW(threadId: r.threadId) }
                .navigationDestination(for: RouteHoSoThanhVienCTW.self) { r in HoSoThanhVienCTW(userId: r.userId) })
        })

    static let thanhVien = CTWModule(
        id: "thanh-vien", ten: "Members", bieuTuong: "person.2", nhom: .giaoTiep,
        moTa: "Everyone in your workspaces, with who is active now", thuTu: 2, capUngDung: true, tabIPhone: "chat",
        man: { _ in AnyView(DanhSachThanhVienCTW()) })
}

// MARK: - Tab Chat (iPhone): Kênh · Tin nhắn · Thành viên

struct HubChatCTW: View {
    @EnvironmentObject private var app: AppState
    @ObservedObject private var kho = KhoTinNhanCTW.shared

    var body: some View {
        Group {
            switch kho.phan {
            case "tinNhan": DanhSachTinNhanCTW()
            case "thanhVien": DanhSachThanhVienCTW()
            default: ManMoDunCTW(id: "chat")
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("Section", selection: $kho.phan) {
                Text("Channels").tag("kenh")
                Text(app.tinNhanChuaDoc > 0 ? String(localized: "Messages (\(app.tinNhanChuaDoc))") : String(localized: "Messages")).tag("tinNhan")
                Text("Members").tag("thanhVien")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(AppColors.backgroundPrimary)
            .accessibilityIdentifier("chat.hub")
        }
        // Tiêu đề nhỏ: tiêu đề lớn + ô tìm + thanh phân đoạn chồng nhau thành một khoảng trống cao (đo 21/10 trên iPhone 17).
        .navigationBarTitleDisplayMode(.inline)
        // Thông báo đẩy / deep link chọn "tin-nhan" hay "thanh-vien" ⇒ tab này + đúng phân đoạn.
        .onChange(of: app.muc, initial: true) { _, m in
            if m == .moDun("tin-nhan") { kho.phan = "tinNhan" }
            if m == .moDun("thanh-vien") { kho.phan = "thanhVien" }
        }
    }
}
