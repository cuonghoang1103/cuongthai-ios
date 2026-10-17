import Foundation
#if os(iOS)
import UIKit
#endif

// MARK: - Mở app CT Work riêng từ app chính (CHUẨN BỊ — chưa gắn vào giao diện)
//
// Kế hoạch (App Store 4.3): tab CT Work của app chính sẽ thay bằng nút "Open the
// CT Work app". Hàm này mở `ctwork://…`; máy chưa cài app CT Work thì mở trang
// App Store của nó (khi đã có App Store ID), không thì mở bản web.
//
// ⚠️ Dùng `open(_:options:completionHandler:)` — KHÔNG `canOpenURL`: `canOpenURL`
// đòi khai `LSApplicationQueriesSchemes` trong Info.plist của app chính, còn
// `open` tự báo thất bại qua completion mà không cần khai gì.

enum MoAppCTWork {
    /// Điền sau khi App Store Connect cấp Apple ID cho app CT Work (số trong
    /// `https://apps.apple.com/app/id<số>`). `nil` ⇒ lùi về bản web.
    static let appStoreID: String? = nil
    static let web = URL(string: "https://cuongthai.com/work")!

    /// `duongDan`: đường web của CT Work (`/work/<ws>/<KEY>/issue/12`) hoặc `nil` = mở app.
    @MainActor
    static func mo(duongDan: String? = nil) {
        #if os(iOS)
        var s = "ctwork://"
        if let d = duongDan, d.hasPrefix("/") { s += String(d.dropFirst()) }
        guard let u = URL(string: s) else { return }
        UIApplication.shared.open(u, options: [:]) { ok in
            guard !ok else { return }
            let lui: URL
            if let id = appStoreID, let store = URL(string: "itms-apps://apps.apple.com/app/id\(id)") {
                lui = store
            } else if let d = duongDan, let w = URL(string: "https://cuongthai.com" + d) {
                lui = w
            } else {
                lui = web
            }
            UIApplication.shared.open(lui)
        }
        #endif
    }
}
