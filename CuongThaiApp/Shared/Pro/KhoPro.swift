#if os(iOS)
import Foundation
import StoreKit

// ════════════════════════════════════════════════════════════════
// MUA PRO QUA APP STORE
//
// Quy tắc gốc: **máy chủ là nơi phán quyết.** StoreKit chỉ nói "Apple đã thu
// tiền"; việc bạn có Pro hay không vẫn do backend trả lời qua `isPro` trong
// `/api/v1/profile`. App KHÔNG tự mở khoá tính năng dựa trên
// `Transaction.currentEntitlements` — làm thế là tự cấp quyền dựa trên thứ
// nằm trên máy người dùng, và nó lệch ngay với gói mua trên web.
//
// ⛔⛔ BẪY CHẾT NGƯỜI: `transaction.finish()` PHẢI gọi SAU khi máy chủ đã
// ghi nhận xong, không phải ngay khi mua xong. `finish()` là lời hứa với
// Apple rằng "tôi đã giao hàng"; gọi sớm rồi mạng rớt giữa chừng thì Apple
// không bao giờ phát lại giao dịch đó nữa — người dùng mất tiền và không có
// Pro, không đường cứu nào ngoài khiếu nại thủ công.
//
// Chưa `finish()` thì ngược lại rất lành: StoreKit phát lại giao dịch ở mỗi
// lần mở app cho tới khi xong, và khoá duy nhất `transaction_id` phía máy
// chủ đảm bảo không cấp hai lần.
// ════════════════════════════════════════════════════════════════

@MainActor
final class KhoPro: ObservableObject {
    static let shared = KhoPro()

    /// Mã sản phẩm trên App Store Connect. Phải khớp ĐÚNG bảng `SAN_PHAM_PRO`
    /// ở `src/services/appleIAP/quyTac.ts` — lệch một ký tự là máy chủ trả
    /// "Không biết sản phẩm".
    /// CÔNG TẮC BÁN PRO TRONG APP. Bản 1.0 lên App Store KHÔNG bán qua IAP
    /// (quyết định 24/09/2026): Pro mua trên web, app chỉ đọc `isPro` của
    /// máy chủ. Tắt ở đây thì không nạp bảng giá ⇒ hàng "Gói" trong Cài đặt
    /// không bấm được ⇒ màn `MuaProView` không có lối vào, và không nghe
    /// `Transaction.updates`. Bị Apple trả về theo 3.1.1 thì bật `true` là
    /// đường IAP (app + backend `/pro/apple/transactions`) chạy lại nguyên vẹn.
    static let banTrongApp = false

    static let maSanPham = [
        "com.cuongthai.app.pro.1m",
        "com.cuongthai.app.pro.3m",
        "com.cuongthai.app.pro.6m",
        "com.cuongthai.app.pro.12m",
    ]

    @Published private(set) var goi: [Product] = []
    @Published private(set) var dangTai = false
    @Published private(set) var dangMua: String?
    @Published var loi: String?
    /// Đặt khi một lượt mua vừa được máy chủ ghi nhận — để màn hình đóng lại
    /// và hiện lời cảm ơn.
    @Published var vuaXong = false

    private var theoDoi: Task<Void, Never>?

    private init() {}

    // MARK: Vòng đời

    /// Gọi một lần lúc app khởi động.
    ///
    /// ⚠️ Phải bắt đầu nghe `Transaction.updates` NGAY, trước cả khi người
    /// dùng mở màn mua. Đó là đường Apple dùng để giao những giao dịch xảy ra
    /// ngoài app: mua lúc app đang tắt, "Hỏi để mua" của trẻ em được bố mẹ
    /// duyệt sau, gia hạn, và giao dịch lần trước chưa `finish()`.
    func batDauNghe() {
        guard Self.banTrongApp, theoDoi == nil else { return }
        theoDoi = Task.detached { [weak self] in
            for await kq in Transaction.updates {
                await self?.xuLy(kq, tuNgoai: true)
            }
        }
    }

    func napGoi() async {
        guard Self.banTrongApp, goi.isEmpty, !dangTai else { return }
        dangTai = true
        defer { dangTai = false }
        do {
            // StoreKit trả về theo thứ tự bất kỳ — xếp theo giá để bảng giá
            // không nhảy chỗ giữa các lần mở.
            goi = try await Product.products(for: Self.maSanPham)
                .sorted { $0.price < $1.price }
        } catch {
            loi = "Không tải được bảng giá: \(error.localizedDescription)"
        }
    }

    // MARK: Mua

    func mua(_ sp: Product, userId: Int) async {
        guard dangMua == nil else { return }
        dangMua = sp.id
        defer { dangMua = nil }
        loi = nil
        do {
            // `appAccountToken` để máy chủ biết lượt mua này thuộc tài khoản
            // CuongThai nào — cần cho những thông báo Apple gửi thẳng tới máy
            // chủ, lúc đó không có phiên đăng nhập nào để hỏi.
            let kq = try await sp.purchase(options: [.appAccountToken(Self.theTaiKhoan(userId))])
            switch kq {
            case .success(let xacThuc):
                await xuLy(xacThuc, tuNgoai: false)
            case .userCancelled:
                break                      // người dùng tự huỷ — không phải lỗi
            case .pending:
                // "Hỏi để mua": chờ phụ huynh duyệt. Giao dịch sẽ tới sau qua
                // `Transaction.updates`, nên ở đây chỉ báo cho biết.
                loi = "Giao dịch đang chờ duyệt. Bạn sẽ nhận Pro ngay khi được chấp nhận."
            @unknown default:
                loi = "Kết quả mua không nhận ra. Hãy thử lại."
            }
        } catch {
            loi = "Mua không thành công: \(error.localizedDescription)"
        }
    }

    /// Khôi phục: đọc lại những gì tài khoản Apple này đang sở hữu rồi gửi
    /// lên máy chủ. Máy chủ khử trùng lặp nên gửi lại bao nhiêu lần cũng được.
    func khoiPhuc() async {
        dangMua = "khoi-phuc"
        defer { dangMua = nil }
        loi = nil
        var soLuot = 0
        for await kq in Transaction.currentEntitlements {
            await xuLy(kq, tuNgoai: true)
            soLuot += 1
        }
        // Gói KHÔNG tự gia hạn không nằm trong `currentEntitlements` sau khi
        // hết hạn — nên "không thấy gì" là chuyện bình thường, đừng báo như lỗi.
        if soLuot == 0 {
            loi = "Không tìm thấy lượt mua nào trên tài khoản Apple này."
        }
    }

    // MARK: Xử lý một giao dịch

    private func xuLy(_ kq: VerificationResult<Transaction>, tuNgoai: Bool) async {
        // StoreKit đã kiểm chữ ký hộ ở đây, nhưng ta vẫn gửi JWS thô lên máy
        // chủ để nó tự kiểm lại. Tin phán quyết của một thư viện chạy trên
        // máy người dùng là tin sai chỗ.
        guard case .verified(let gd) = kq else {
            if !tuNgoai { loi = "Giao dịch không qua được bước xác minh của Apple." }
            return
        }

        do {
            let _: KetQuaGiaoDichApple = try await APIClient.shared
                .request(.guiGiaoDichApple(jws: kq.jwsRepresentation))
            // CHỈ tới đây mới được `finish()` — máy chủ đã ghi nhận xong.
            await gd.finish()
            await AppState.shared.fetchProfile()   // kéo `isPro` mới về
            vuaXong = true
        } catch {
            // KHÔNG `finish()`. Giao dịch ở lại hàng đợi của Apple và sẽ được
            // phát lại lần mở app sau, cho tới khi máy chủ nhận được.
            if !tuNgoai {
                loi = "Đã thanh toán nhưng chưa kích hoạt được: \(error.localizedDescription)\n"
                    + "Pro sẽ tự bật khi có mạng — bạn không bị tính tiền lần nữa."
            }
        }
    }

    // MARK: Gắn tài khoản

    /// UUID suy thẳng từ `userId`, không lưu ở đâu cả.
    ///
    /// Apple bắt `appAccountToken` phải là UUID. Sinh ngẫu nhiên rồi cất máy
    /// thì cài lại app là mất, còn dựng từ userId thì luôn ra cùng một giá
    /// trị và máy chủ **đọc ngược lại được** — không cần thêm bảng tra.
    static func theTaiKhoan(_ userId: Int) -> UUID {
        let hex = String(format: "%012x", userId)
        return UUID(uuidString: "00000000-0000-4000-8000-\(hex)")
            ?? UUID(uuidString: "00000000-0000-4000-8000-000000000000")!
    }
}

/// Máy chủ trả về sau khi ghi nhận. Chỉ khai những trường app dùng tới.
struct KetQuaGiaoDichApple: Decodable {
    let moi: Bool
    let soNgay: Int
    let proDenNgay: String?
    let proTronDoi: Bool
}
#endif
