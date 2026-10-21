import Foundation
import Combine
import SwiftUI

// MARK: - Kho chung của Thành viên + Tin nhắn riêng
//
// MỘT nơi giữ danh bạ (người cùng không gian + trạng thái), danh sách hội thoại, tín hiệu socket (online, đang gõ)
// và hội thoại đang mở — để chấm xanh ở Thành viên, ở danh sách hội thoại và ở đầu khung chat nói cùng một điều.

@MainActor
final class KhoTinNhanCTW: ObservableObject {
    static let shared = KhoTinNhanCTW()

    /// Hội thoại đang mở trên màn — `DayCTW.willPresent` (nonisolated) đọc để không hiện băng cho chính hội thoại đó.
    nonisolated(unsafe) static var hoiThoaiDangMo: Int?

    @Published private(set) var danhBa: [CTWThanhVien] = []
    @Published private(set) var hoiThoai: [MessageThread] = []
    @Published private(set) var daTaiDanhBa = false
    @Published private(set) var daTaiHoiThoai = false
    @Published var loiDanhBa: String?
    @Published var loiHoiThoai: String?
    /// Người xem bật "Hiển thị trạng thái hoạt động" (máy chủ trả ở `/work/me/people`; hồ sơ là nguồn chính).
    @Published var toiHienTrangThai = true
    /// Socket nói đang online / vừa rời (mốc lúc rời) — bù cho dữ liệu máy chủ đã cũ.
    @Published private(set) var socketOnline: Set<Int> = []
    @Published private(set) var vuaRoi: [Int: Date] = [:]
    /// threadId ⇒ những người đang gõ.
    @Published private(set) var dangGo: [Int: Set<Int>] = [:]
    /// Hội thoại cần mở (thông báo đẩy / "Nhắn tin" từ hồ sơ) — danh sách hội thoại đẩy màn chat rồi xoá.
    @Published var canMo: Int?
    /// Hồ sơ thành viên cần mở (màn Tìm mọi thứ) — danh sách Thành viên mở tấm phủ hồ sơ rồi xoá.
    @Published var hoSoCanMo: Int?
    /// Phân đoạn đang chọn của tab Chat (iPhone): kenh | tinNhan | thanhVien.
    @Published var phan: String = UserDefaults.standard.string(forKey: "ctw.hubChat.phan") ?? "kenh" {
        didSet { UserDefaults.standard.set(phan, forKey: "ctw.hubChat.phan") }
    }

    private var huy = Set<AnyCancellable>()
    private var hetGo: [Int: Task<Void, Never>] = [:]

    private init() {
        let r = RealtimeCTW.shared
        r.tinNhanMoi.sink { [weak self] e in self?.nhanTinMoi(e.threadId, e.tin) }.store(in: &huy)
        r.tinNhanDangGo.sink { [weak self] e in self?.datDangGo(e.threadId, e.userId, e.dangGo) }.store(in: &huy)
        r.hienDien.sink { [weak self] e in
            guard let self else { return }
            if e.online { socketOnline.insert(e.userId); vuaRoi[e.userId] = nil }
            else { socketOnline.remove(e.userId); vuaRoi[e.userId] = Date() }
        }.store(in: &huy)
        r.tinNhanDaDoc.sink { [weak self] e in
            guard let self, e.readerId == AppState.shared.currentUser?.id else { return }
            // Đọc ở thiết bị khác ⇒ xoá chấm chưa đọc ở đây.
            if let i = hoiThoai.firstIndex(where: { $0.id == e.threadId }) { hoiThoai[i] = hoiThoai[i].daDocHet() }
        }.store(in: &huy)
    }

    // MARK: Tải

    func taiDanhBa() async {
        do {
            let d: CTWDanhBa = try await APIClient.shared.request(CTWAPI.thanhVien())
            datDanhBa(d)
            loiDanhBa = nil
        } catch {
            if danhBa.isEmpty { loiDanhBa = CTW.loi(error) }
        }
        daTaiDanhBa = true
    }

    func taiHoiThoai() async {
        do {
            let ds: [MessageThread] = try await APIClient.shared.request(.getThreads(cursor: nil, limit: 50))
            hoiThoai = ds.filter { !$0.daLuuTru }.sorted { ($0.updatedAt ?? "") > ($1.updatedAt ?? "") }
            loiHoiThoai = nil
        } catch {
            if hoiThoai.isEmpty { loiHoiThoai = CTW.loi(error) }
        }
        daTaiHoiThoai = true
    }

    /// Nạp một danh bạ (máy chủ / kiểm thử).
    func datDanhBa(_ d: CTWDanhBa) {
        danhBa = d.people ?? []
        if let b = d.viewerShowsActiveStatus { toiHienTrangThai = b }
    }

    /// Kiểm thử: giả sự kiện socket `presence:update`.
    func datSocket(_ id: Int, online: Bool, luc: Date = Date()) {
        if online { socketOnline.insert(id); vuaRoi[id] = nil } else { socketOnline.remove(id); vuaRoi[id] = luc }
    }

    func xoaHet() {
        danhBa = []; hoiThoai = []; socketOnline = []; vuaRoi = [:]; dangGo = [:]; canMo = nil; hoSoCanMo = nil
        daTaiDanhBa = false; daTaiHoiThoai = false; toiHienTrangThai = true
        Self.hoiThoaiDangMo = nil
    }

    // MARK: Trạng thái hoạt động

    func thanhVien(_ id: Int) -> CTWThanhVien? { danhBa.first { $0.id == id } }

    /// Mốc của một người, gộp máy chủ + socket, áp luật riêng tư.
    /// - `lastActiveAt` của hội thoại (peer) dùng khi người đó không nằm trong danh bạ CT Work.
    func moc(_ id: Int, mocHoiThoai: String? = nil, bayGio: Date = Date()) -> TrangThaiHoatDongCTW.Moc {
        let chan = ModerationStore.shared.blockedUserIds.contains(id)
        if let n = thanhVien(id) {
            let p = n.presence
            let hien = TrangThaiHoatDongCTW.duocHien(toiBat: toiHienTrangThai, hoBat: p?.visible ?? false,
                                                     laAgent: n.laAgent, daChan: chan || n.blocked == true)
            let online = socketOnline.contains(id) || (p?.online == true && vuaRoi[id] == nil)
            let m = vuaRoi[id] ?? (p?.lastActiveAt).flatMap(Date.tuChuoiISO)
            return TrangThaiHoatDongCTW.phanLoai(hien: hien, online: online, moc: m, bayGio: bayGio)
        }
        // Ngoài danh bạ: máy chủ đã che `lastActiveAt` của người tắt trạng thái (nil ⇒ không biết ⇒ im).
        let mocMay = mocHoiThoai.flatMap(Date.tuChuoiISO)
        let biet = mocMay != nil || socketOnline.contains(id)
        let hien = TrangThaiHoatDongCTW.duocHien(toiBat: toiHienTrangThai, hoBat: biet, daChan: chan)
        return TrangThaiHoatDongCTW.phanLoai(hien: hien, online: socketOnline.contains(id), moc: vuaRoi[id] ?? mocMay, bayGio: bayGio)
    }

    /// Danh bạ đã sắp: đang hoạt động trước (như Messenger), rồi gần nhất, rồi theo tên; lọc theo ô tìm.
    func danhBaDaSap(tim: String, bayGio: Date = Date()) -> [CTWThanhVien] {
        let t = tim.trimmingCharacters(in: .whitespaces).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        let loc = t.isEmpty ? danhBa : danhBa.filter { n in
            [n.ten, n.username ?? "", n.dongPhu].contains {
                $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).contains(t)
            }
        }
        func diem(_ n: CTWThanhVien) -> (Int, Double) {
            switch moc(n.id, bayGio: bayGio) {
            case .dangHoatDong: return (0, 0)
            case .an: return (2, 0)
            default:
                let d = vuaRoi[n.id] ?? (n.presence?.lastActiveAt).flatMap(Date.tuChuoiISO)
                return (1, -(d?.timeIntervalSince1970 ?? 0))
            }
        }
        return loc.sorted { a, b in
            let (x, y) = (diem(a), diem(b))
            if x != y { return x < y }
            return a.ten.localizedCompare(b.ten) == .orderedAscending
        }
    }

    // MARK: Hội thoại

    /// Mở (tạo nếu chưa có) hội thoại 1-1 với một người rồi trả hội thoại.
    func moVoi(_ userId: Int) async throws -> MessageThread {
        if let t = hoiThoai.first(where: { $0.peer?.id == userId && $0.laNhanRieng }) { return t }
        let t: MessageThread = try await APIClient.shared.request(.openThread(peerId: userId))
        if !hoiThoai.contains(where: { $0.id == t.id }) { hoiThoai.insert(t, at: 0) }
        RealtimeCTW.shared.vaoHoiThoai(t.id)
        return t
    }

    /// Mở một hội thoại theo id (thông báo đẩy / deep link): chuyển tới Tin nhắn, danh sách đẩy màn chat.
    func moHoiThoai(_ id: Int) {
        phan = "tinNhan"
        AppState.shared.muc = .moDun("tin-nhan")
        canMo = id
    }

    /// Mở mô-đun Tin nhắn / Thành viên (màn Tìm mọi thứ): iPhone ⇒ tab Chat đúng phân đoạn, iPad ⇒ mục thanh bên.
    /// Đặt `phan` TRỰC TIẾP — `app.muc` có thể đã là mô-đun đó (người dùng tự đổi phân đoạn sau) ⇒ `onChange` không chạy.
    func moMoDun(_ id: String) {
        phan = id == "tin-nhan" ? "tinNhan" : "thanhVien"
        AppState.shared.muc = .moDun(id)
    }

    /// Mở hồ sơ một người trong Thành viên (màn Tìm mọi thứ gõ tên).
    func moHoSo(_ userId: Int) {
        moMoDun("thanh-vien")
        hoSoCanMo = userId
    }

    func hoiThoai(_ id: Int) -> MessageThread? { hoiThoai.first { $0.id == id } }

    func danhDauDaDoc(_ id: Int) {
        if let i = hoiThoai.firstIndex(where: { $0.id == id }) { hoiThoai[i] = hoiThoai[i].daDocHet() }
        Task {
            _ = try? await APIClient.shared.send(.markRead(threadId: id))
            await AppState.shared.taiSoChuaDoc()
        }
    }

    func capNhatTinCuoi(_ threadId: Int, _ tin: Message) {
        if let i = hoiThoai.firstIndex(where: { $0.id == threadId }) {
            let t = hoiThoai.remove(at: i).voiTinMoi(tin, tangChuaDoc: false)
            hoiThoai.insert(t, at: 0)
        }
    }

    private func nhanTinMoi(_ threadId: Int, _ tin: Message) {
        datDangGo(threadId, tin.senderId, false)
        let cuaToi = tin.senderId == AppState.shared.currentUser?.id
        let dangXem = Self.hoiThoaiDangMo == threadId
        if let i = hoiThoai.firstIndex(where: { $0.id == threadId }) {
            let t = hoiThoai.remove(at: i).voiTinMoi(tin, tangChuaDoc: !cuaToi && !dangXem)
            hoiThoai.insert(t, at: 0)
        } else {
            Task { await taiHoiThoai() }
        }
        if !cuaToi && !dangXem { Task { await AppState.shared.taiSoChuaDoc() } }
    }

    private func datDangGo(_ threadId: Int, _ userId: Int, _ go: Bool) {
        var tap = dangGo[threadId] ?? []
        if go { tap.insert(userId) } else { tap.remove(userId) }
        dangGo[threadId] = tap.isEmpty ? nil : tap
        hetGo[threadId]?.cancel()
        guard go else { return }
        // Máy chủ không bảo đảm phát "thôi gõ" (người kia đóng app) ⇒ tự tắt sau 6 s.
        hetGo[threadId] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            self?.datDangGo(threadId, userId, false)
        }
    }

    // MARK: Riêng tư

    /// Bật/tắt "Hiển thị trạng thái hoạt động" (`PUT /profile {showActiveStatus}`). Socket đọc cờ này LÚC NỐI
    /// (messaging.socket.ts) ⇒ nối lại để có hiệu lực ngay; tải lại danh bạ (máy chủ áp luật đối ứng).
    func datHienTrangThai(_ bat: Bool) async throws {
        try await APIClient.shared.send(TinNhanAPI.datTrangThaiHoatDong(bat))
        toiHienTrangThai = bat
        if var u = AppState.shared.currentUser { u.showActiveStatus = bat; AppState.shared.currentUser = u }
        RealtimeCTW.shared.noiLai()
        await taiDanhBa()
    }
}
