import SwiftUI

@MainActor
final class LichSuChatViewModel: ObservableObject {
    @Published var phien: [PhienChat] = []
    @Published var thuMuc: [ThuMucChat] = []
    @Published var dangTai = false
    @Published var loi: String?
    @Published var tuKhoa = ""
    @Published var xemLuuTru = false
    /// `nil` = tất cả · `"none"` = chưa xếp thư mục · id = một thư mục.
    @Published var thuMucLoc: String?

    func nap() async {
        dangTai = true
        defer { dangTai = false }
        do {
            async let ds: [PhienChat] = APIClient.shared.request(
                .dsPhienChat(luuTru: xemLuuTru, thuMucId: thuMucLoc))
            async let tm: [ThuMucChat] = APIClient.shared.request(.dsThuMucChat)
            phien = try await ds
            thuMuc = (try? await tm) ?? []
        } catch {
            loi = "Không tải được lịch sử: \(error.localizedDescription)"
        }
    }

    /// Lọc tại chỗ. Backend chưa có tìm kiếm cho phiên, mà `title` chính là câu
    /// hỏi đầu tiên nên lọc theo tên đã đủ dùng cho 100 cuộc gần nhất.
    func locTheoTuKhoa() -> [PhienChat] {
        let k = tuKhoa.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !k.isEmpty else { return phien }
        return phien.filter { $0.ten.lowercased().contains(k) }
    }

    func doiTen(_ p: PhienChat, thanh ten: String) async {
        let t = ten.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        await sua(p, ["title": t])
    }

    func datGhim(_ p: PhienChat, _ ghim: Bool) async { await sua(p, ["pinned": ghim]) }

    func datLuuTru(_ p: PhienChat, _ luu: Bool) async {
        await sua(p, ["archived": luu])
        // Cất đi thì nó rời khỏi danh sách đang xem — nạp lại để nó biến mất
        // thật, chứ không nằm đó làm người dùng tưởng nút không ăn.
        await nap()
    }

    func chuyen(_ p: PhienChat, _ thuMucId: String?) async {
        try? await APIClient.shared.send(.chuyenThuMuc(id: p.id, thuMucId: thuMucId))
        await nap()
    }

    func xoa(_ p: PhienChat) async {
        // Bỏ khỏi màn hình NGAY rồi mới gọi máy chủ: chờ mạng xong mới xoá thì
        // hàng vẫn nằm đó vài trăm ms và người dùng bấm xoá lần nữa.
        let luu = phien
        phien.removeAll { $0.id == p.id }
        do {
            try await APIClient.shared.send(.xoaPhienChat(id: p.id))
        } catch {
            phien = luu
            loi = "Không xoá được: \(error.localizedDescription)"
        }
    }

    func taoThuMuc(_ ten: String) async {
        let t = ten.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        // Backend trả 200 (không phải 201) khi thư mục trùng tên đã có — nó
        // đưa lại cái cũ thay vì đẻ bản sao. Nạp lại là thấy đúng trạng thái.
        try? await APIClient.shared.send(.taoThuMucChat(ten: t, mau: nil))
        await nap()
    }

    func xoaThuMuc(_ t: ThuMucChat) async {
        try? await APIClient.shared.send(.xoaThuMucChat(id: t.id))
        if thuMucLoc == t.id { thuMucLoc = nil }
        await nap()
    }

    private func sua(_ p: PhienChat, _ than: [String: Any]) async {
        try? await APIClient.shared.send(.suaPhienChat(id: p.id, than))
        await nap()
    }
}
