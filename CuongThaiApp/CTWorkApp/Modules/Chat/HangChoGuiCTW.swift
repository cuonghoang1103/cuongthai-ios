import Foundation
import Combine
import Network
import UIKit

// MARK: - Hàng chờ GỬI tin khi mất mạng
//
// Người dùng đang ở ngoài (thang máy, tàu, quán cà phê) bấm Gửi ⇒ tin vào hàng
// chờ NGAY (hiện mờ "Waiting for network"), không mất chữ đã gõ. Có mạng lại
// (NWPathMonitor báo thông / app trở lại / socket nối lại) ⇒ gửi lần lượt.
//
// Không bao giờ thành HAI tin: mỗi tin mang `clientKey` cố định từ lúc gõ —
// máy chủ gặp lại khoá cũ thì trả đúng tin đã lưu (`chat.service.postMessage`).
// Lỗi THẬT của máy chủ (4xx: kênh lưu trữ, mất quyền…) ⇒ đánh dấu "Failed",
// để người dùng chọn Thử lại / Xoá — không thử vô hạn.
// Tệp đính kèm cần mạng để tải lên trước (máy chủ trả id nháp) ⇒ hàng chờ chỉ
// giữ CHỮ; tin có tệp mà mất mạng thì báo lỗi tại chỗ.

struct TinChoGuiCTW: Codable, Identifiable, Hashable {
    enum TrangThai: String, Codable { case cho, dangGui, loi }
    /// = clientKey gửi lên máy chủ.
    var id: String
    var pid: Int
    var cid: Int
    var parentId: Int?
    var body: String
    var taoLuc: Date
    var trangThai: TrangThai = .cho
    var loi: String?
}

@MainActor
final class HangChoGuiCTW: ObservableObject {
    static let shared = HangChoGuiCTW()

    @Published private(set) var ds: [TinChoGuiCTW] = []
    @Published private(set) var coMang = true

    /// Tin vừa gửi xong từ hàng chờ (màn kênh/chuỗi chèn vào danh sách của mình).
    let daGui = PassthroughSubject<(TinChoGuiCTW, CTWChatMessage), Never>()
    /// Tin bị bộ lọc nội dung của máy chủ chặn (422 CONTENT_BLOCKED, build 7): RỜI hàng chờ (gửi lại y nguyên vẫn bị chặn)
    /// ⇒ màn kênh/chuỗi trả chữ về ô soạn + báo tại chỗ. Kèm câu lỗi đã theo ngôn ngữ app.
    let biChan = PassthroughSubject<(TinChoGuiCTW, String), Never>()
    /// Lần `them` gần nhất bị chặn ⇒ id tin (để `them` báo lại cho nơi gọi đang chờ).
    private var vuaChan: [String: String] = [:]

    private let khoa = "com.cuongthai.ctwork.hangChoGui"
    private let monitor = NWPathMonitor()
    private var dangXa = false

    private init() {
        if let d = UserDefaults.standard.data(forKey: khoa),
           let a = try? JSONDecoder().decode([TinChoGuiCTW].self, from: d) {
            // Tin đang gửi dở lúc app bị tắt ⇒ về "chờ" để gửi lại (clientKey chống trùng).
            ds = a.map { var t = $0; if t.trangThai == .dangGui { t.trangThai = .cho }; return t }
        }
        monitor.pathUpdateHandler = { [weak self] p in
            let thong = p.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                let truoc = self.coMang
                self.coMang = thong
                if thong && !truoc { await self.xa() }
            }
        }
        monitor.start(queue: DispatchQueue(label: "ctw.hangChoGui"))
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.xa() }
        }
    }

    func cua(pid: Int, cid: Int, chuoi: Int? = nil) -> [TinChoGuiCTW] {
        ds.filter { $0.pid == pid && $0.cid == cid && $0.parentId == chuoi }
    }

    /// Thêm một tin rồi thử gửi ngay. Trả về tin máy chủ đã lưu nếu gửi được liền.
    @discardableResult
    func them(pid: Int, cid: Int, parentId: Int?, body: String) async -> CTWChatMessage? {
        if case .daGui(let m) = await themKQ(pid: pid, cid: cid, parentId: parentId, body: body) { return m }
        return nil
    }

    enum KetQuaThem { case daGui(CTWChatMessage?), biChan(String) }

    /// Như `them` nhưng nói rõ khi máy chủ CHẶN nội dung — nơi gọi giữ lại chữ trong ô soạn.
    func themKQ(pid: Int, cid: Int, parentId: Int?, body: String) async -> KetQuaThem {
        let t = TinChoGuiCTW(id: "ios-\(UUID().uuidString.prefix(23))", pid: pid, cid: cid, parentId: parentId,
                             body: body, taoLuc: Date())
        ds.append(t)
        luu()
        let m = await gui(t.id)
        if let l = vuaChan.removeValue(forKey: t.id) { return .biChan(l) }
        return .daGui(m)
    }

    func thuLai(_ id: String) async {
        guard let i = ds.firstIndex(where: { $0.id == id }) else { return }
        ds[i].trangThai = .cho
        ds[i].loi = nil
        luu()
        await gui(id)
    }

    func xoa(_ id: String) {
        ds.removeAll { $0.id == id }
        luu()
    }

    func xoaHet() {
        ds = []
        UserDefaults.standard.removeObject(forKey: khoa)
    }

    /// Xả hàng chờ: gửi lần lượt những tin đang "chờ".
    func xa() async {
        guard !dangXa, AppState.shared.isAuthenticated else { return }
        dangXa = true
        defer { dangXa = false }
        for t in ds where t.trangThai == .cho {
            if await gui(t.id) == nil, ds.first(where: { $0.id == t.id })?.trangThai == .cho { break }
        }
    }

    @discardableResult
    private func gui(_ id: String) async -> CTWChatMessage? {
        guard let i = ds.firstIndex(where: { $0.id == id }), ds[i].trangThai != .dangGui else { return nil }
        ds[i].trangThai = .dangGui
        let t = ds[i]
        do {
            let m: CTWChatMessage = try await APIClient.shared.request(
                CTWAPI.guiTin(pid: t.pid, cid: t.cid, chu: t.body, traLoi: t.parentId, khoa: t.id))
            ds.removeAll { $0.id == id }
            luu()
            daGui.send((t, m))
            return m
        } catch where CTWLoiDich.laNoiDungBiChan(error) {
            let l = CTW.loi(error)
            ds.removeAll { $0.id == id }
            luu()
            vuaChan[id] = l
            biChan.send((t, l))
            return nil
        } catch {
            guard let j = ds.firstIndex(where: { $0.id == id }) else { return nil }
            if error is URLError {
                ds[j].trangThai = .cho          // mất mạng ⇒ đợi
                ds[j].loi = nil
            } else {
                ds[j].trangThai = .loi          // máy chủ từ chối ⇒ người dùng quyết
                ds[j].loi = CTW.loi(error)
            }
            luu()
            return nil
        }
    }

    private func luu() {
        if let d = try? JSONEncoder().encode(ds) { UserDefaults.standard.set(d, forKey: khoa) }
    }
}
