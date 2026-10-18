import Foundation
import SwiftUI

// MARK: - Trạng thái chung của app CT Work
//
// ⚠️ Tên lớp là `AppState` CỐ Ý: các màn trong `Shared/CTWork` (dùng chung với
// app chính) khai `@EnvironmentObject var appState: AppState` và đọc
// `currentUser` + `ctWorkDich`. Target CTWorkApp KHÔNG biên dịch
// `ViewModels/AppState.swift` của app chính (nó kéo theo socket tin nhắn, cuộc
// gọi, Tiền nong…), nên ở đây có một lớp cùng tên, cùng hai thành viên đó.
// Thêm thành viên mới mà `Shared/CTWork` đọc ⇒ phải thêm ở CẢ HAI lớp.

/// Một chỗ trong khung app: mục cố định hoặc một mô-đun đã đăng ký.
/// iPhone: thanh tab (mô-đun `.trangDuAn` gộp vào tab Projects); iPad: thanh bên.
enum MucCTW: Hashable {
    case viecCuaToi, duAn, hopThu, taiKhoan
    case moDun(String)

    var ten: String {
        switch self {
        case .viecCuaToi: return "My Work"
        case .duAn: return "Projects"
        case .hopThu: return "Inbox"
        case .taiKhoan: return "Account"
        case .moDun(let id): return CTWDangKyMoDun.moDun(id)?.ten ?? id
        }
    }
    var bieuTuong: String {
        switch self {
        case .viecCuaToi: return "checklist"
        case .duAn: return "rectangle.3.group"
        case .hopThu: return "bell"
        case .taiKhoan: return "person.crop.circle"
        case .moDun(let id): return CTWDangKyMoDun.moDun(id)?.bieuTuong ?? "square.grid.2x2"
        }
    }
}

/// Không gian + dự án đang chọn — NHỚ qua các lần mở app.
struct LuaChonCTW: Codable, Equatable {
    var slug: String
    var tenKhongGian: String
    var pid: Int
    var maDuAn: String
    var tenDuAn: String
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    /// Thẻ cần mở (thông báo đẩy, `ctwork://`, Universal Link). Màn nhận đích
    /// đọc rồi tự xoá.
    @Published var ctWorkDich: CTWDich?
    /// Đích chờ một MÔ-ĐUN nhận (kênh chat, trang tài liệu…) — xem `DichMoDunCTW`.
    @Published var dichCho: DichMoDunCTW?
    /// Chỗ đang mở trong khung (tab iPhone / mục thanh bên iPad).
    @Published var muc: MucCTW = .viecCuaToi
    @Published var luaChon: LuaChonCTW? {
        didSet {
            luuLuaChon()
            CTWChiaSeNhom.ghiDuAnDangChon(luaChon)
            if oldValue?.pid != luaChon?.pid { cauHinhDuAn = nil; Task { await napCauHinhDuAn() } }
        }
    }
    /// Cấu hình dự án đang chọn (quyền, mô-đun bật/tắt, thành viên…) — khung
    /// dùng để ẩn/hiện mô-đun; mô-đun dùng lại thay vì tự gọi `GET /projects/:pid`.
    @Published var cauHinhDuAn: CTWProjectConfig?
    /// Số thông báo CT Work chưa đọc (chỉ loại WORK_*), cho huy hiệu tab Inbox.
    @Published var hopThuChuaDoc = 0
    @Published var chatChuaDoc = 0
    @Published var daDongYDieuKhoan: Bool

    private let storage = StorageManager.shared
    private let khoaLuaChon = "com.cuongthai.ctwork.luaChon"
    private let khoaDongY = "com.cuongthai.ctwork.daDongYDieuKhoan"

    /// Bản DEBUG chạy với máy chủ GIẢ (`CT_XEM_MAN`) — không đụng Keychain.
    var cheDoXemThu = false

    private init() {
        daDongYDieuKhoan = UserDefaults.standard.bool(forKey: khoaDongY)
        if let d = UserDefaults.standard.data(forKey: khoaLuaChon),
           let l = try? JSONDecoder().decode(LuaChonCTW.self, from: d) {
            luaChon = l
        }
        if storage.getAuthToken() != nil {
            isAuthenticated = true
            Task { await fetchProfile() }
        }
    }

    func dongYDieuKhoan() {
        daDongYDieuKhoan = true
        UserDefaults.standard.set(true, forKey: khoaDongY)
    }

    private func luuLuaChon() {
        if let luaChon, let d = try? JSONEncoder().encode(luaChon) {
            UserDefaults.standard.set(d, forKey: khoaLuaChon)
        } else {
            UserDefaults.standard.removeObject(forKey: khoaLuaChon)
        }
    }

    func login(token: String, refreshToken: String? = nil) {
        storage.saveAuthToken(token, refreshToken: refreshToken)
        isAuthenticated = true
        CTWChiaSeNhom.dongBoToken()
        RealtimeCTW.shared.noiLai()
        Task { await fetchProfile() }
    }

    func logout() {
        DayCTW.shared.goTheKhiDangXuat()
        CTWChiaSeNhom.donKhiDangXuat()
        storage.clearAll()
        RealtimeCTW.shared.ngat()
        ModerationStore.shared.reset()
        AnNoiDungCTW.shared.xoaHet()
        HangChoGuiCTW.shared.xoaHet()
        AnNoiDungHopCTW.shared.xoaHet()
        TrinhPhatGiongNoiCTW.shared.dung()
        isAuthenticated = false
        currentUser = nil
        luaChon = nil
        hopThuChuaDoc = 0
        chatChuaDoc = 0
        muc = .viecCuaToi
        cauHinhDuAn = nil
        DayCTW.datHuyHieu(0)
    }

    func fetchProfile() async {
        for lan in 0..<3 {
            do {
                let u: User = try await APIClient.shared.request(.getProfile)
                currentUser = u
                storage.saveCurrentUser(u)
                await ModerationStore.shared.refreshBlocks()
                await DayCTW.shared.xinQuyenVaDangKy()
                RealtimeCTW.shared.noi()
                await taiSoChuaDoc()
                if cauHinhDuAn == nil { await napCauHinhDuAn() }
                return
            } catch {
                if case APIError.unauthorized = error { logout(); return }
                if lan == 2 {
                    if currentUser == nil { currentUser = storage.getCurrentUser() }
                    return
                }
                try? await Task.sleep(nanoseconds: UInt64(400_000_000) << lan)
            }
        }
    }

    func napCauHinhDuAn() async {
        guard let pid = luaChon?.pid, isAuthenticated else { return }
        if let c: CTWProjectConfig = try? await APIClient.shared.request(.workDuAn(pid: pid)), luaChon?.pid == pid {
            cauHinhDuAn = c
            // Tên dự án/không gian có thể đã đổi trên web — cập nhật bản nhớ.
            if var l = luaChon, l.tenDuAn != c.name || l.maDuAn != c.key {
                l.tenDuAn = c.name; l.maDuAn = c.key
                if let w = c.workspace?.name { l.tenKhongGian = w }
                luaChon = l
            }
        }
    }

    /// Đếm chưa đọc: chat (một lời gọi) + hộp thư (`unread-count?surface=work` — chỉ WORK_*).
    /// Huy hiệu biểu tượng = SỐ THÔNG BÁO WORK_* CHƯA ĐỌC — đúng con số máy chủ gắn
    /// vào gói APNs cho app này (`notification.service.ts → soCtw`). Cộng thêm số tin
    /// chat chưa đọc như trước làm số nhảy qua lại mỗi lần có đẩy.
    func taiSoChuaDoc() async {
        if let u: CTWChatUnread = try? await APIClient.shared.request(CTWAPI.chatChuaDoc()) {
            chatChuaDoc = u.total ?? 0
        }
        // Máy chủ đếm sẵn theo bề mặt (`?surface=work`, 18/10/2026) — MỘT lời gọi.
        var so = 0
        var docDuoc = false
        if let r: CTWSoChuaDoc = try? await APIClient.shared.request(CTWAPI.tbSoChuaDoc()), let n = r.unreadCount {
            so = n
            docDuoc = true
        } else {
            // Lối lùi (máy chủ cũ / lỗi tạm): đọc tối đa 4 trang 50 mới nhất rồi tự đếm WORK_*.
            var cursor: Int?
            for _ in 0..<4 {
                guard let r: NotificationsResponse = try? await APIClient.shared.request(.getNotifications(cursor: cursor, limit: 50)) else { break }
                docDuoc = true
                so += r.items.filter { $0.type.hasPrefix("WORK_") && !$0.isRead }.count
                guard r.pagination.hasNextPage, let c = r.pagination.nextCursor, r.items.contains(where: { !$0.isRead }) else { break }
                cursor = c
            }
        }
        if docDuoc { hopThuChuaDoc = so }
        DayCTW.datHuyHieu(hopThuChuaDoc)
    }
}
