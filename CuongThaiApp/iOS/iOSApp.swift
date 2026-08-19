import SwiftUI

@main
struct CuongThaiApp: App {
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                // Google trả người dùng về app qua URL scheme riêng. Thiếu
                // dòng này thì luồng đăng nhập mở ra được, người dùng chọn
                // xong tài khoản, rồi app KHÔNG bao giờ nhận lại kết quả.
                .onOpenURL { url in
                    _ = GoogleSignInService.nhanURL(url)
                }
        }
    }
}
