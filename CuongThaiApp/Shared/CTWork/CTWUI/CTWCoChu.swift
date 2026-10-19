import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - CTWUI — cỡ chữ THEO Dynamic Type (19/10/2026)
//
// Cả giao diện CT Work từng ghi cỡ chữ cứng `.system(size: 13)` (hơn 1.300 chỗ) ⇒ người dùng đặt chữ lớn trong
// Cài đặt › Trợ năng mà app vẫn y nguyên. `.ctw(size:)` giữ đúng cỡ thiết kế ở mức chữ mặc định (Large) và
// nhân theo tỉ lệ Dynamic Type của hệ thống (đo bằng UIFontMetrics trên kiểu Body).
//
// Trần 1,4× (đo 19/10: 1,6× làm vỡ hàng siêu dữ liệu của My Work): các mức "Accessibility" (tới ~3×) làm vỡ bố cục có khung cố định (avatar, ô đếm, chip). 1,4× ≈ mức
// XXXL — đủ cho người cần chữ to mà bố cục vẫn đọc được. Thành phần hệ thống (List, thanh điều hướng, nút mặc
// định) vẫn theo Dynamic Type đầy đủ như thường.
// Đổi cỡ chữ lúc app đang mở: gốc app gắn `.id(dynamicTypeSize)` (CTWorkAppMain) để dựng lại toàn bộ.

enum CTWCoChu {
    #if os(iOS)
    nonisolated(unsafe) private static var dem: (UIContentSizeCategory, CGFloat)?
    #endif

    /// Tỉ lệ so với mức mặc định (Large = 1).
    static var tiLe: CGFloat {
        #if os(iOS)
        let cat = UIApplication.shared.preferredContentSizeCategory
        if let d = dem, d.0 == cat { return d.1 }
        let t = UITraitCollection(preferredContentSizeCategory: cat)
        let s = UIFontMetrics(forTextStyle: .body).scaledValue(for: 17, compatibleWith: t) / 17
        let r = min(max(s, 0.82), 1.4)
        dem = (cat, r)
        return r
        #else
        return 1
        #endif
    }

    static func co(_ goc: CGFloat) -> CGFloat { (goc * tiLe).rounded(.toNearestOrEven) }
}

extension Font {
    /// Thay cho `.system(size:weight:design:)` — cùng tham số, nhưng theo Dynamic Type (xem trên).
    static func ctw(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        .system(size: CTWCoChu.co(size), weight: weight, design: design)
    }
}
