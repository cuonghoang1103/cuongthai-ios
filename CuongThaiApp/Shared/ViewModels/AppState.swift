import Foundation
import Combine

// MARK: - App State
@MainActor
final class AppState: ObservableObject {

    /// Biệt danh vừa đổi ở một hội thoại.
    ///
    /// Biệt danh là thứ **chỉ người xem thấy** — máy chủ không phát sự kiện
    /// socket nào cho nó, nên không có đường realtime sẵn để bám vào. Mà
    /// `MessagesViewModel` lại là `@StateObject` RIÊNG của màn danh sách:
    /// `ChatView` không với tới được nó.
    ///
    /// Thiếu kênh này thì đổi biệt danh xong, danh sách bên ngoài vẫn hiện
    /// tên cũ cho tới lượt tải lại kế tiếp — người dùng thấy là "app đơ".
    let bietDanhDoi = PassthroughSubject<(threadId: Int, ten: String), Never>()
    static let shared = AppState()

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var unreadMessages = 0
    @Published var unreadNotifications = 0
    /// Điểm đến chính đang chọn. ĐẶT nó (kể cả đặt lại đúng giá trị cũ) là rời
    /// mục riêng của thanh bên iPad — thông báo đẩy đặt `.tinNhan` thì cột chi
    /// tiết phải chuyển sang Tin nhắn, không được kẹt ở Tiền nong.
    @Published var selectedTab: AppTab = .homNay {
        didSet { if mucBenRieng != nil { mucBenRieng = nil } }
    }

    private let storage = StorageManager.shared
    private var huyDangKy = Set<AnyCancellable>()
    /// Hội thoại đang mở — tin mới của chính nó KHÔNG cộng vào huy hiệu.
    var hoiThoaiDangMo: Int?
    /// Hội thoại cần mở sau khi người dùng chạm vào thông báo đẩy. Màn Tin
    /// nhắn đọc rồi xoá — không xoá thì lần sau vào tab đó nó tự mở lại.
    @Published var hoiThoaiCanMo: Int?
    /// Bật lên khi người dùng chạm một thông báo mạng xã hội — Bảng tin
    /// (`HomeView`) mở bảng chuông rồi tự hạ cờ. Chỉ Bảng tin đọc cờ này, nên
    /// ai đặt nó phải đặt kèm `selectedTab = .bangTin`.
    @Published var moChuongThongBao = false

    /// Link video người dùng vừa CHIA SẺ từ app khác (YouTube/TikTok) sang
    /// CuongThai. Share Extension ghi vào nhóm ứng dụng, app gốc nhặt lên và
    /// mở thẳng bảng "Thêm video" — bất kể đang đứng ở tab nào.
    @Published var videoChoThem: String?

    static let nhomUngDung = "group.com.cuongthai.app"
    static let khoaVideoChoThem = "videoChoThem"

    /// Nhặt link Share Extension để lại. Gọi lúc app mở và mỗi lần quay lại
    /// tiền cảnh — mở app bằng `openURL` không phải lúc nào cũng thành công,
    /// nên nhóm ứng dụng mới là đường chắc chắn.
    func nhatVideoDuocChiaSe() {
        guard let d = UserDefaults(suiteName: Self.nhomUngDung),
              let lien = d.string(forKey: Self.khoaVideoChoThem), !lien.isEmpty
        else { return }
        // Xoá NGAY sau khi đọc: không xoá thì mỗi lần mở app lại bật bảng
        // thêm video với đúng cái link cũ.
        d.removeObject(forKey: Self.khoaVideoChoThem)
        videoChoThem = lien
    }

    /// NĂM điểm đến chính (22/10/2026 — đợt "rút gọn"). Chọn theo số đo dùng
    /// thật: Bảng tin đứng đầu, rồi Học/Academy, Tin nhắn, Tôi; Hôm nay là bảng
    /// việc trong ngày. MỌI tính năng khác (Vở, Tiền nong, IELTS, Xưởng…) là
    /// một `TinhNang` trong danh mục "Tất cả tính năng", không phải tab — thêm
    /// tab thứ sáu là iOS dồn nó vào "More" (chôn sau hai lần chạm).
    ///
    /// ⚠️ `rawValue` là CHUỖI có chủ ý: bản cũ là `Int` 0…10 với nghĩa khác
    /// (1 = Học, 2 = Tạo…). Một số cũ còn nằm trong dữ liệu khôi phục cửa sổ mà
    /// đọc nhầm thành tab mới là mở sai màn câm. Số cũ đi qua
    /// `MucBen.tuTabCu` — không bao giờ giải mã thẳng thành `AppTab`.
    enum AppTab: String, CaseIterable, Identifiable, Codable, Hashable {
        case homNay = "hom-nay"
        case bangTin = "bang-tin"
        case hoc
        case tinNhan = "tin-nhan"
        case toi
        var id: String { rawValue }
        /// ⚠️ Nhãn tab PHẢI trùng tiêu đề màn (`navigationTitle`) — bản cũ ghi
        /// "Trang chủ" ở tab mà màn lại là "Tổng quan", "Cá nhân" mà màn là
        /// "Hồ sơ": người dùng bấm một chữ, nhìn thấy chữ khác.
        var title: String {
            switch self {
            case .homNay: return T("Hôm nay")
            case .bangTin: return T("Bảng tin")
            case .hoc: return T("Học")
            case .tinNhan: return T("Tin nhắn")
            case .toi: return T("Tôi")
            }
        }
        var icon: String {
            switch self {
            case .homNay: return "sun.max.fill"
            case .bangTin: return "newspaper.fill"
            case .hoc: return "graduationcap.fill"
            case .tinNhan: return "message.fill"
            case .toi: return "person.crop.circle.fill"
            }
        }
    }

    /// Mã lỗi Keychain nếu kho khoá không dùng được. Khác nil nghĩa là phiên
    /// đăng nhập KHÔNG lưu được — phải nói ra chứ không để người dùng đăng
    /// nhập xong, mở lại app thấy mình bị đăng xuất mà không hiểu vì sao.
    @Published var loiKeychain: OSStatus?

    private init() {
        loiKeychain = KeychainStore.tuKiem()
        checkAuth()
        // Tin mới về qua socket thì cộng huy hiệu ngay, không đợi lần làm mới
        // sau. Bỏ qua tin của chính mình và tin của hội thoại đang mở.
        RealtimeClient.shared.tinMoi
            .sink { [weak self] su in
                guard let self else { return }
                guard su.message.senderId != self.currentUser?.id else { return }
                guard su.threadId != self.hoiThoaiDangMo else { return }
                self.unreadMessages += 1
                self.dongBoHuyHieu()
            }
            .store(in: &huyDangKy)
    }

    func checkAuth() {
        if storage.getAuthToken() != nil {
            isAuthenticated = true
            RealtimeClient.shared.noi()
            Task { await fetchProfile() }
        }
    }

    func login(token: String, refreshToken: String? = nil) {
        storage.saveAuthToken(token, refreshToken: refreshToken)
        isAuthenticated = true
        // `noiLai` chứ không phải `noi`: token nằm trong header của kết nối,
        // nên đăng nhập tài khoản khác mà chỉ gọi `noi()` thì socket cũ vẫn
        // sống với token cũ và ta nhận tin của người dùng TRƯỚC.
        RealtimeClient.shared.noiLai()
        Task { await fetchProfile() }
    }

    func logout() {
        storage.clearAll()
        RealtimeClient.shared.ngat()
        ModerationStore.shared.reset()
        isAuthenticated = false
        currentUser = nil
        trangThaiHoSo = .chuaNap
        unreadMessages = 0
        unreadNotifications = 0
    }

    // MARK: Điều hướng tới tính năng (22/10/2026)
    //
    // Thay cho năm cờ `moTienNong/moIelts/moXuongVe/moXuongBa/moCTWork` cũ: MỘT
    // lối `moTinhNang(_:)` cho mọi tính năng, mọi nguồn (lưới Đi nhanh, tìm
    // kiếm ⌘K, link `cuongthai://`, thông báo đẩy, phím tắt).

    /// Yêu cầu mở một tính năng kiểu `.day`. Bố cục ĐANG hiện tiêu thụ rồi xoá:
    /// iPhone (`iOSTabView`) ⇒ sang Hôm nay + đẩy vào `duongHomNay`; iPad
    /// (`BoCucCotDoi`) ⇒ hiện ở cột chi tiết. AppState không biết bề rộng
    /// cửa sổ nên không tự quyết — đặt cờ là để đúng bố cục nhặt.
    @Published var dichCanMo: DichHomNay?
    /// Stack của Hôm nay (iPhone, và cột Hôm nay trên iPad).
    @Published var duongHomNay: [DichHomNay] = []
    /// Mục thanh bên iPad KHÔNG phải tab (một tính năng ghim, "Tất cả tính
    /// năng"). `nil` = cột chi tiết hiện `selectedTab`. Đặt `selectedTab` (thông
    /// báo đẩy, màn Thông báo…) tự xoá nó — xem `didSet` ở `selectedTab`.
    @Published var mucBenRieng: MucBen?
    /// Bảng trình bày từ gốc: tìm kiếm, thông báo, ghi chú, cài đặt, soạn bài.
    @Published var bangGoc: BangGoc?
    /// AI Chat mở từ gốc (danh mục, tìm kiếm). Màn nào có nút AI riêng thì giữ cờ riêng.
    @Published var moAIChatGoc = false

    /// Mở một tính năng, bất kể nó mở kiểu gì.
    /// - `sauKhiDong`: gọi từ trong một sheet sắp đóng (tìm kiếm). Trình bày
    ///   chồng lúc sheet kia còn đang trượt xuống thì UIKit bỏ qua im lặng —
    ///   đợi một nhịp.
    func moTinhNang(_ f: TinhNang, sauKhiDong: Bool = false) {
        if sauKhiDong {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 450_000_000)
                self.moTinhNang(f)
            }
            return
        }
        switch f.cachMo {
        case .day:
            dichCanMo = .tinhNang(f)
        case .ngoai:
            MoCTWorkApp.mo()
        case .trinhBay:
            switch f {
            case .aiChat: moAIChatGoc = true
            case .notes: bangGoc = .notes
            case .thongBao: bangGoc = .thongBao
            case .caiDat: bangGoc = .caiDat
            default: bangGoc = nil
            }
        }
    }

    /// Mở danh mục "Tất cả tính năng" (⇧⌘A, ô "Tất cả" của Đi nhanh).
    func moTatCa() { dichCanMo = .tatCa }

    /// Áp một lệnh mở từ link `cuongthai://`.
    func apDung(_ h: HanhDongURL) {
        switch h {
        case .tinhNang(let f): moTinhNang(f)
        case .tab(let t): selectedTab = t
        case .nhatVideo: nhatVideoDuocChiaSe()
        case .timKiem: bangGoc = .timKiem
        }
    }

    /// Áp định tuyến của một cú chạm thông báo đẩy (đã cất ở `ThongBaoDay`).
    func apDung(_ d: DinhTuyenDay) {
        switch d {
        case .ctWork(let duongDan):
            // CT Work là app RIÊNG từ 22/10/2026 — mở nó (hoặc App Store).
            MoCTWorkApp.mo(duongDan: duongDan)
        case .chuong:
            // ⚠️ Bảng tin, KHÔNG phải Hôm nay: cờ `moChuongThongBao` chỉ
            // `HomeView` (Bảng tin) đọc. Bản cũ đưa về Trang chủ (Tổng quan) nên
            // chạm thông báo xã hội chỉ mở app, chuông không bao giờ bật (lỗi (a)).
            selectedTab = .bangTin
            moChuongThongBao = true
        case .tienNong(let ghiNgay):
            ghiChiNgaySauKhiMoTien = ghiNgay
            moTinhNang(.tienNong)
        case .tinNhan(let tid):
            selectedTab = .tinNhan
            if let tid { hoiThoaiCanMo = tid }
        }
    }

    /// Chạm thông báo 20h ("Hôm nay bạn đã chi tiêu những gì?") thì mở thẳng
    /// ô ghi khoản chi. Mở màn Tiền nong rồi bắt người dùng tự tìm nút cộng
    /// là bỏ phí đúng cái khoảnh khắc họ đang định ghi.
    @Published var ghiChiNgaySauKhiMoTien = false

    /// Hồ sơ nạp được chưa — để màn Hồ sơ biết vẽ gì.
    ///
    /// ⚠️ Trước 06/09/2026 hàm này nuốt MỌI lỗi không phải 401. `checkAuth()`
    /// bật `isAuthenticated = true` chỉ vì máy CÓ token (chưa hỏi máy chủ),
    /// nên một lần gọi hỏng lúc mở app — mạng chập, 500 thoáng qua, giải mã
    /// lệch — để lại trạng thái "đã đăng nhập mà không có người dùng"
    /// VĨNH VIỄN: không ai thử lại, không log, và ProfileView lấp chỗ trống
    /// bằng `?? "User"` nên người dùng thấy một hồ sơ giả "User / @username /
    /// 0 / 0 / 0". Nhìn y như app hỏng, và App Store đánh trượt vì đúng là
    /// nội dung giữ chỗ (Guideline 2.1).
    enum TrangThaiHoSo: Equatable { case chuaNap, dangNap, xong, loi(String) }
    @Published var trangThaiHoSo: TrangThaiHoSo = .chuaNap

    func fetchProfile() async {
        if case .dangNap = trangThaiHoSo { return }
        trangThaiHoSo = .dangNap
        // Thử lại có giãn cách: hỏng lúc mở app phần lớn là mạng chưa sẵn sàng.
        for lan in 0..<3 {
            do {
                let user: User = try await APIClient.shared.request(.getProfile)
                currentUser = user
                storage.saveCurrentUser(user)
                trangThaiHoSo = .xong
                await ModerationStore.shared.refreshBlocks()
                return
            } catch {
                if case APIError.unauthorized = error { logout(); return }
                if lan == 2 {
                    trangThaiHoSo = .loi(error.localizedDescription)
                    // Có bản lưu trong máy thì dùng tạm — thà hồ sơ cũ còn hơn
                    // hồ sơ giả.
                    if currentUser == nil, let luu = storage.getCurrentUser() {
                        currentUser = luu
                        trangThaiHoSo = .xong
                    }
                    return
                }
                try? await Task.sleep(nanoseconds: UInt64(400_000_000) << lan)
            }
        }
    }

    /// Đếm chưa đọc cho cả tin nhắn lẫn thông báo.
    ///
    /// Bản cũ giải mã `/messages/unread-count` thẳng ra `Int`, nhưng backend
    /// trả `{ "count": 5 }` — một ĐỐI TƯỢNG. Lệnh giải mã luôn ném lỗi, lỗi
    /// bị `catch { }` nuốt, nên huy hiệu tin nhắn VĨNH VIỄN bằng 0 mà không
    /// một dòng log nào. Hỏng câm đúng nghĩa.
    /// Huy hiệu app = tin chưa đọc + thông báo chưa đọc.
    ///
    /// Backend chỉ gửi SỐ TIN trong gói đẩy, nhưng người dùng nhìn biểu tượng
    /// thì hiểu là "có bao nhiêu thứ đang chờ tôi" — nên cộng cả hai. Quan
    /// trọng hơn: hàm này là chỗ DUY NHẤT biết cách hạ số xuống.
    func dongBoHuyHieu() {
        ThongBaoDay.datHuyHieu(unreadMessages + unreadNotifications)
    }

    func fetchUnreadCounts() async {
        do {
            let tin: UnreadMessageCount = try await APIClient.shared.request(.getUnreadMessageCount)
            unreadMessages = tin.count
        } catch {
            // Mất mạng thì giữ nguyên số cũ, đừng xoá về 0 —
            // "0 tin chưa đọc" là một lời khẳng định, không phải "không biết".
        }
        do {
            let tb: UnreadNotificationCount = try await APIClient.shared.request(.getUnreadNotificationCount)
            unreadNotifications = tb.unreadCount
        } catch { }
        // Máy chủ là nguồn sự thật — đồng bộ huy hiệu theo nó, kể cả khi số
        // GIẢM. Đây là lượt duy nhất huy hiệu có thể tụt xuống.
        dongBoHuyHieu()
    }
}
