import SwiftData
import SwiftUI
import UIKit

/// Thông báo đẩy BẮT BUỘC phải qua `UIApplicationDelegate` — SwiftUI thuần
/// không có chỗ nào nhận được thẻ thiết bị mà Apple trả về.
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// ⚠️⚠️ DELEGATE THÔNG BÁO PHẢI ĐẶT Ở ĐÂY, KHÔNG PHẢI TRONG `.task` CỦA VIEW.
    ///
    /// Chạm một thông báo lúc app đang tắt thì iOS giao cú chạm đó NGAY trong
    /// lúc khởi động — trước khi SwiftUI kịp dựng view, nên trước cả `.task`.
    /// Chưa có delegate ở thời điểm ấy thì iOS VỨT LUÔN cú chạm, không giữ lại
    /// và cũng không báo lỗi gì.
    ///
    /// Triệu chứng đúng như người dùng gặp: chạm thông báo tin nhắn thì app mở
    /// ra ở Trang chủ, không vào đoạn chat. Đo thật 21/08/2026: dòng nhật ký
    /// "CHẠM thông báo" KHÔNG hề xuất hiện — hàm xử lý chưa từng chạy, chứ
    /// không phải chạy rồi định tuyến sai.
    /// ⚠️ Chữ ký phải khớp CHÍNH XÁC `application:didFinishLaunchingWithOptions:`.
    /// Bản trước tôi viết `= nil` cho tham số — Swift sinh thêm một hàm nạp
    /// chồng và selector không còn khớp cái iOS gọi, nên app không khởi động
    /// theo đường thông báo nữa. KHÔNG đặt giá trị mặc định ở đây.
    @MainActor
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        NhatKy.thongBao.info("didFinishLaunching — đặt delegate thông báo")
        ThongBaoDay.shared.khoiDong()
        return true
    }

    func application(_ app: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
        Task { @MainActor in ThongBaoDay.shared.nhanThe(token) }
    }

    func application(_ app: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Hay gặp nhất: chạy trên MÁY MÔ PHỎNG (không có APNs), hoặc App ID
        // chưa bật Push Notifications ở Developer portal.
        print("[day] đăng ký thất bại: \(error.localizedDescription)")
    }
}

@main
struct CuongThaiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var appState = AppState.shared
    @StateObject private var giaoDien = QuanLyGiaoDien.shared
    @StateObject private var ngonNgu = QuanLyNgonNguApp.shared
    @Environment(\.scenePhase) private var scenePhase
    /// Màn khởi động động (iOS/KhoiDong) — chỉ lần mở nguội; sống ở App nên `.id(ngôn ngữ)` không dựng lại nó.
    @State private var hienKhoiDong = KhoiDongApp.nenHien()

    /// Khôi phục phiên coi như xong: chưa đồng ý quy tắc / chưa đăng nhập (vào thẳng màn đó) hoặc đã có hồ sơ.
    private var khoiPhucXong: Bool {
        !StorageManager.shared.hasAcceptedTerms || !appState.isAuthenticated || appState.currentUser != nil
    }

    init() {
        NhatKy.xoaCu()
        KhoiDongChung.shared.dangChieu = KhoiDongApp.nenHien()
        // ⚠️ Phải nghe `Transaction.updates` từ lúc app mở, KHÔNG đợi người
        // dùng vào màn mua. Đó là đường Apple giao những giao dịch xảy ra
        // ngoài app: mua lúc app đang tắt, "Hỏi để mua" được phụ huynh duyệt
        // sau, gia hạn, và lượt mua lần trước chưa `finish()` vì mất mạng.
        // Nghe muộn thì những giao dịch đó nằm lại hàng đợi — người dùng đã
        // trả tiền mà không thấy Pro đâu.
        KhoPro.shared.batDauNghe()
        // Chốt đồng ý chia sẻ dữ liệu với AI (5.1.2(i)) cho mọi lời gọi AI đi
        // qua `APIClient`. Xem `Shared/AI/DongYChiaSeAI.swift`.
        DongYChiaSeAI.ganVaoAPIClient()
        // Chủ đề mùa: áp bảng màu TRƯỚC màn đầu tiên (không nháy tím rồi mới đổi). Xem Shared/ChuDe.
        QuanLyChuDe.khoiDong()
    }

    /// Bọc chuỗi link thành `Identifiable` để dùng với `.sheet(item:)`.
    private struct LienChiaSe: Identifiable {
        let lien: String
        var id: String { lien }
        init(_ l: String) { lien = l }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .overlay {
                    if hienKhoiDong {
                        ManKhoiDongApp(khoiPhucXong: khoiPhucXong) {
                            hienKhoiDong = false
                            KhoiDongChung.shared.dangChieu = false
                        }
                    }
                }
                // Kho Vở (SwiftData). Gắn ở gốc để mọi màn con — kể cả màn
                // viết mở bằng `fullScreenCover` — đều thấy cùng một kho.
                .modelContainer(KhoSwiftData.chung)
                // Bảng "Thêm video" mở từ GỐC, không từ màn Học bằng video:
                // người dùng bấm chia sẻ khi đang ở bất kỳ tab nào, và bắt họ
                // tự đi tìm đúng màn thì coi như tính năng không có.
                .sheet(item: Binding(
                    get: { appState.videoChoThem.map(LienChiaSe.init) },
                    set: { appState.videoChoThem = $0?.lien })
                ) { l in
                    ThemVideoView(lienSan: l.lien) { }
                }
                // Cuộc gọi tới phải reo dù người dùng đang ở màn nào.
                .lopPhuCuocGoi()
                // `nil` = để iOS quyết định. Màu của app vốn đã thích ứng nên
                // chỉ cần một dòng này là cả app đổi theo.
                .preferredColorScheme(giaoDien.mauSac)
                // ⚠️ `.id(...)` dựng lại TOÀN BỘ cây khi đổi ngôn ngữ.
                //
                // `T(...)` là hàm thường, không phải `@Published`, nên
                // SwiftUI không có cách nào biết chữ vừa đổi — thiếu dòng này
                // thì bấm sang English xong màn hình vẫn y nguyên tiếng Việt
                // cho tới khi vô tình chuyển màn. Cái giá: trạng thái tạm của
                // màn đang mở bị dựng lại. Đổi ngôn ngữ là việc hiếm, và dựng
                // lại còn ĐÚNG hơn là để nửa màn hai thứ tiếng.
                .id(ngonNgu.ngonNgu)
                .onChange(of: scenePhase) { _, moi in
                    // Máy ngủ qua mốc 6h/18h thì `Timer` không chạy — tính lại
                    // khi quay lại, không thì mở app buổi tối vẫn thấy nền sáng.
                    if moi == .active { giaoDien.lamMoiKhiTroLai() }
                    // "Tự động theo mùa": qua 31/10 → 1/11 khi máy ngủ thì quay lại là sang Đông.
                    if moi == .active { QuanLyChuDe.shared.lamMoiKhiTroLai() }

                    // Báo "tôi đang dùng app" cho máy chủ, và NGỪNG khi xuống
                    // nền. Thiếu nửa đầu thì với mọi người khác mình luôn
                    // ngoại tuyến; thiếu nửa sau thì mình hiện "đang hoạt
                    // động" suốt đêm trong khi máy nằm trong túi.
                    if moi == .active { BaoHoatDong.shared.batDau() }
                    else { BaoHoatDong.shared.dungLai() }

                    // Chia sẻ từ app khác: `openURL` của extension có thể bị
                    // hệ thống từ chối, nên nhặt lại mỗi lần quay lại app.
                    if moi == .active { appState.nhatVideoDuocChiaSe() }
                }
                // Google trả người dùng về app qua URL scheme riêng. Thiếu
                // dòng này thì luồng đăng nhập mở ra được, người dùng chọn
                // xong tài khoản, rồi app KHÔNG bao giờ nhận lại kết quả.
                .onOpenURL { url in
                    // `cuongthai://tien` — widget Tiền nong mở về đúng màn đó.
                    //
                    // ⚠️ Phải xử lý TRƯỚC khi chuyển cho Google: `nhanURL`
                    // nhận mọi URL rồi tự quyết, và một ngày nào đó nó nuốt
                    // nhầm thì widget chết câm mà không ai nghĩ tới đây.
                    // Đọc ở `HanhDongURL.doc` (Shared/TatCa/DieuHuong.swift, có
                    // kiểm thử). `them-video`: Share Extension đã ghi link vào
                    // nhóm ứng dụng rồi mới mở app — ở đây chỉ việc nhặt lên.
                    if url.scheme == "cuongthai" {
                        if let h = HanhDongURL.doc(url) { appState.apDung(h) }
                        return
                    }
                    _ = GoogleSignInService.nhanURL(url)
                }
                .task {
                    // `khoiDong()` đã chạy ở `didFinishLaunchingWithOptions` —
                    // xem ghi chú ở AppDelegate. Ở đây chỉ còn việc xin quyền.
                    // Chỉ xin quyền khi ĐÃ đăng nhập: hỏi lúc mở app lần đầu
                    // thì đa số bấm "Không cho phép", và iOS KHÔNG cho hỏi
                    // lại lần hai — mất luôn cơ hội.
                    if appState.currentUser != nil {
                        await ThongBaoDay.shared.xinQuyenVaDangKy()
                    }
                }
                .onChange(of: appState.currentUser?.id) { _, moi in
                    guard moi != nil else { return }
                    Task {
                        await ThongBaoDay.shared.xinQuyenVaDangKy()
                        ThongBaoDay.shared.guiLaiNeuCan()
                    }
                }
        }
        // Phím tắt ⌘1…⌘5, ⌘K, ⇧⌘A — xem `LenhDieuHuong`.
        .commands { LenhDieuHuong(appState: appState) }

        // CỬA SỔ PHỤ — một module tách ra cửa sổ riêng, để đặt cạnh cửa sổ
        // chính trong Stage Manager / Split View.
        //
        // ⚠️ Nó KHÔNG đọc `appState.selectedTab`. Dùng chung biến đó thì hai
        // cửa sổ luôn hiện cùng một màn, và đổi bên này là bên kia nhảy theo
        // — tức là mất sạch lý do mở cửa sổ thứ hai. Module hiện ở đây đi
        // theo GIÁ TRỊ mà `openWindow` truyền vào.
        //
        // Khoá bằng `MucBen` (tab chính / tính năng / Tất cả) từ 22/10/2026.
        // `MucBen` vẫn giải mã được số `AppTab` cũ mà iPadOS cất lúc khôi phục
        // cửa sổ (`MucBen.tuTabCu`) — cửa sổ Vở mở từ bản trước vẫn ra Vở.
        WindowGroup(id: "cua-so-phu", for: MucBen.self) { $muc in
            ManCuaSo(muc: muc ?? .tinhNang(.vo))
                .environmentObject(appState)
                .modelContainer(KhoSwiftData.chung)
                .lopPhuCuocGoi()
                .preferredColorScheme(giaoDien.mauSac)
                .id(ngonNgu.ngonNgu)
        }
    }
}
