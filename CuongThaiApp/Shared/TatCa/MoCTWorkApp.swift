import Foundation
#if os(iOS)
import UIKit
#endif

/// Mở app CT Work RIÊNG (bundle `com.cuongthai.ctwork`, App Store id 6824877696).
///
/// Từ 22/10/2026 app chính KHÔNG còn nhúng CT Work (App Store 4.3 — hai app
/// cùng một module là "app nhân bản"). Mục "CT Work" trong danh mục, thông báo
/// đẩy CT Work và thông báo WORK_* trong chuông đều đi qua đây:
///   · máy đã cài app CT Work ⇒ mở `ctwork://…` (đúng thẻ nếu có đường dẫn);
///   · chưa cài ⇒ trang App Store của nó (`LSApplicationQueriesSchemes` khai
///     `ctwork` trong Info.plist — thiếu thì `canOpenURL` luôn sai).
///
/// ⚠️ Tệp này CHỈ thuộc app chính (thư mục `Shared/TatCa`). `Shared/CTWork/
/// MoAppCTWork.swift` là bản cũ biên dịch cùng app CT Work — không đụng tới.
enum MoCTWorkApp {
    static let appStoreID = "6824877696"
    static let urlAppStore = URL(string: "https://apps.apple.com/app/id\(appStoreID)")!

    /// `duongDan` web (`/work/<ws>/<KEY>/issue/12`, kể cả URL đầy đủ
    /// `https://cuongthai.com/work/...`) ⇒ `ctwork://work/<ws>/<KEY>/issue/12`.
    /// App CT Work đọc `ctwork://<host><path>` thành `/<host><path>`
    /// (`CTWorkApp/App/DinhTuyenCTW.swift`). Không có đường dẫn ⇒ `ctwork://`.
    static func urlApp(duongDan: String? = nil) -> URL {
        guard var d = duongDan?.trimmingCharacters(in: .whitespaces), !d.isEmpty else {
            return URL(string: "ctwork://")!
        }
        if let r = d.range(of: "://"), let sau = d[r.upperBound...].firstIndex(of: "/") {
            d = String(d[sau...])   // bỏ scheme + host
        }
        while d.hasPrefix("/") { d.removeFirst() }
        return URL(string: "ctwork://" + d) ?? URL(string: "ctwork://")!
    }

    @MainActor
    static func mo(duongDan: String? = nil) {
        #if os(iOS)
        let app = urlApp(duongDan: duongDan)
        if UIApplication.shared.canOpenURL(URL(string: "ctwork://")!) {
            UIApplication.shared.open(app) { ok in
                if !ok { UIApplication.shared.open(urlAppStore) }
            }
        } else {
            UIApplication.shared.open(urlAppStore)
        }
        #endif
    }
}
