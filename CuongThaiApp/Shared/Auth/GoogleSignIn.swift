import SwiftUI
#if os(iOS)
import GoogleSignIn
import GoogleSignInSwift
import UIKit
#endif

// MARK: - Đăng nhập bằng Google
//
// Web đã có OAuth Google (client loại **Web**, có secret, nằm ở máy chủ). App
// KHÔNG dùng lại client đó được: Google cấm app di động giữ secret — ai cũng
// mở file .ipa ra đọc được — nên app phải có client loại **iOS**, không secret,
// ràng danh tính bằng Bundle ID và nhận chuyển hướng qua URL scheme riêng.
// Đưa client Web cho SDK iOS sẽ nhận thẳng lỗi:
//     "Custom scheme URIs are not allowed for 'WEB' client type"
//
// Cách bật (xem hướng dẫn đầy đủ trong APP_REVIEW_NOTES.md):
//   1. console.cloud.google.com → project 650641212127 → Credentials
//      → Create credentials → OAuth client ID → **iOS**
//      → Bundle ID: com.cuongthai.app
//   2. Dán client ID vào `GIDClientID` trong CuongThaiApp/iOS/Info.plist
//   3. Dán client ID ĐẢO NGƯỢC vào CFBundleURLSchemes ở cùng file
//      (ví dụ ID `123-abc.apps.googleusercontent.com`
//        → scheme `com.googleusercontent.apps.123-abc`)
//
// Chưa cấu hình thì `duocCauHinh` = false và nút Google KHÔNG hiện — thà không
// có nút còn hơn có nút bấm vào báo lỗi.

enum GoogleSignInError: LocalizedError {
    case chuaCauHinh
    case khongCoEmail
    case khongMoDuocManHinh
    case that(String)

    var errorDescription: String? {
        #if CTWORK_APP
        // App CT Work: chữ qua catalog (vi + en, đổi ngay trong app) — khoá là câu tiếng Anh (KIEN_TRUC mục 13).
        switch self {
        case .chuaCauHinh: return String(localized: "Sign in with Google isn't set up for this app.")
        case .khongCoEmail: return String(localized: "Your Google account didn't share an email address, so we couldn't sign you in.")
        case .khongMoDuocManHinh: return String(localized: "Couldn't open the Google sign-in window.")
        case .that(let m): return m
        }
        #else
        switch self {
        case .chuaCauHinh:
            return "Chưa cấu hình Google Sign-In cho ứng dụng này."
        case .khongCoEmail:
            return "Tài khoản Google không chia sẻ email nên không đăng nhập được."
        case .khongMoDuocManHinh:
            return "Không mở được cửa sổ đăng nhập Google."
        case .that(let m):
            return m
        }
        #endif
    }
}

enum GoogleSignInService {
    /// Client ID lấy từ Info.plist. Để trống nghĩa là chưa bật tính năng.
    static var clientID: String? {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
              !id.isEmpty,
              // Chuỗi mẫu trong Info.plist không phải ID thật.
              !id.hasPrefix("DAN-CLIENT-ID")
        else { return nil }
        return id
    }

    static var duocCauHinh: Bool { clientID != nil }

    #if os(iOS)
    /// Mở luồng Google rồi đổi lấy phiên của backend.
    @MainActor
    static func dangNhap() async throws -> AuthResponse {
        let payload = try await layThongTin()
        return try await APIClient.shared.request(.oauthToken(payload))
    }

    /// Bước 1 (chỉ phía Google): mở cửa sổ Google, trả thân `POST /auth/oauth/token`. Tách khỏi bước đổi phiên để màn
    /// đăng nhập CT Work chỉ hiện lớp "Đang đăng nhập…" SAU khi cửa sổ Google đóng (như luồng Apple).
    /// Người dùng huỷ ⇒ `CancellationError`.
    @MainActor
    static func layThongTin() async throws -> [String: Any] {
        guard let clientID else { throw GoogleSignInError.chuaCauHinh }
        guard let vc = manHinhDangHien() else { throw GoogleSignInError.khongMoDuocManHinh }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        let ketQua: GIDSignInResult
        do {
            ketQua = try await GIDSignIn.sharedInstance.signIn(withPresenting: vc)
        } catch {
            // Người dùng bấm huỷ không phải lỗi đáng báo.
            if (error as NSError).code == GIDSignInError.canceled.rawValue {
                throw CancellationError()
            }
            throw GoogleSignInError.that(error.localizedDescription)
        }

        let nguoiDung = ketQua.user
        guard let email = nguoiDung.profile?.email, !email.isEmpty else {
            throw GoogleSignInError.khongCoEmail
        }
        guard let providerId = nguoiDung.userID else {
            #if CTWORK_APP
            throw GoogleSignInError.that(String(localized: "Google didn't return an account ID. Please try again."))
            #else
            throw GoogleSignInError.that("Google không trả về mã người dùng.")
            #endif
        }

        var payload: [String: Any] = [
            "email": email,
            "provider": "google",
            "providerId": providerId,
        ]
        if let ten = nguoiDung.profile?.name { payload["fullName"] = ten }
        // Ảnh đại diện Google. Máy chủ TẢI VỀ rồi đẩy lên R2 chứ không lưu
        // thẳng URL này — địa chỉ `lh3.googleusercontent.com` gắn theo phiên
        // và sẽ chết, lúc đó avatar thành ô trống mà không có lỗi nào để thấy.
        //
        // ⚠️ Chỉ điền khi tài khoản CHƯA có ảnh — máy chủ tự lo, app không
        // cần biết. Đè ảnh người dùng tự chọn là mất dữ liệu.
        if let anh = nguoiDung.profile?.imageURL(withDimension: 256) {
            payload["avatarUrl"] = anh.absoluteString
        }
        // Gửi kèm để backend xác minh chữ ký khi nào siết bảo mật — hôm nay
        // endpoint bỏ qua trường thừa, nên gửi trước thì sau này không phải
        // cập nhật app. Giống hệt cách làm với Sign in with Apple.
        if let idToken = nguoiDung.idToken?.tokenString { payload["idToken"] = idToken }
        return payload
    }

    /// Google cần một UIViewController để trình bày. Lấy từ scene đang hiện,
    /// không dùng `UIApplication.shared.windows` (đã bỏ từ iOS 15).
    private static func manHinhDangHien() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var vc = scene?.keyWindow?.rootViewController
        while let tren = vc?.presentedViewController { vc = tren }
        return vc
    }

    /// Gọi từ `.onOpenURL` — Google chuyển hướng về app qua URL scheme riêng.
    static func nhanURL(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    /// URL này là chuyển hướng của Google Sign-In (scheme = client ID đảo ngược `com.googleusercontent.apps.<…>`)?
    /// Kiểm theo SCHEME chứ không đưa mọi URL cho `GIDSignIn.handle` trước: deep link `ctwork://…` và Universal Link
    /// không bao giờ được rơi vào SDK (CT Work, build 7).
    static func laURLChuyenHuong(_ url: URL) -> Bool {
        guard let sc = url.scheme?.lowercased() else { return false }
        if let id = clientID {
            let dao = id.components(separatedBy: ".").reversed().joined(separator: ".").lowercased()
            if sc == dao { return true }
        }
        return sc.hasPrefix("com.googleusercontent.apps.")
    }

    /// Chữ "G" bốn màu CHÍNH HÃNG — ảnh nằm trong gói tài nguyên của SDK (`GoogleSignIn_GoogleSignIn.bundle/google.png`,
    /// cùng ảnh `GoogleSignInButton` vẽ). Dùng cho nút tự dựng của CT Work (chữ theo ngôn ngữ app); KHÔNG tự vẽ lại.
    static var logoG: UIImage? {
        let ten = "GoogleSignIn_GoogleSignIn"
        let goi = Bundle.main.path(forResource: ten, ofType: "bundle").flatMap(Bundle.init(path:))
            ?? Bundle(for: GIDSignIn.self).path(forResource: ten, ofType: "bundle").flatMap(Bundle.init(path:))
            ?? Bundle.main.path(forResource: "GoogleSignIn", ofType: "bundle").flatMap(Bundle.init(path:))
        guard let goi else { return nil }
        return UIImage(named: "google", in: goi, compatibleWith: nil)
            ?? goi.path(forResource: "google@3x", ofType: "png").flatMap(UIImage.init(contentsOfFile:))
            ?? goi.path(forResource: "google", ofType: "png").flatMap(UIImage.init(contentsOfFile:))
    }
    #endif
}

// MARK: - Nút

#if !CTWORK_APP
// Nút của APP CHÍNH (`Haptics` chỉ có ở app chính). App CT Work dựng nút riêng ở `DangNhapCTW` — chữ "Continue with
// Google" phải đổi theo ngôn ngữ trong app, còn nút của SDK chỉ theo ngôn ngữ máy.
struct GoogleSignInButtonView: View {
    let onSignedIn: (AuthResponse) -> Void
    let onError: (String) -> Void

    @State private var dangChay = false

    var body: some View {
        #if os(iOS)
        if GoogleSignInService.duocCauHinh {
            ZStack {
                // Nút dựng sẵn của SDK: đúng chữ G bốn màu, đúng khoảng cách,
                // đúng quy định thương hiệu Google. Tự vẽ lại là vi phạm.
                GoogleSignInButton(
                    viewModel: GoogleSignInButtonViewModel(scheme: .light, style: .wide, state: .normal),
                ) {
                    Task { await bam() }
                }
                .frame(height: 48)
                .disabled(dangChay)
                .opacity(dangChay ? 0.5 : 1)

                if dangChay { ProgressView() }
            }
        }
        #endif
    }

    #if os(iOS)
    @MainActor
    private func bam() async {
        dangChay = true
        defer { dangChay = false }
        do {
            let res = try await GoogleSignInService.dangNhap()
            Haptics.xong()
            onSignedIn(res)
        } catch is CancellationError {
            // Người dùng tự huỷ — im lặng, không phải lỗi.
        } catch {
            Haptics.hong()
            onError(error.localizedDescription)
        }
    }
    #endif
}
#endif
