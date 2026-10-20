import SwiftUI
import WidgetKit

// MARK: - Đổi ngôn ngữ TRONG app (Account › Language) — 20/10/2026
//
// Lõi (lựa chọn, tráo Bundle.main, App Group) ở `CTWorkShared/NgonNguCTW.swift`. Lớp này là phần SwiftUI:
// `ma` thay đổi ⇒ `GocCTW` gắn `.environment(\.locale, …)` + `.id(ma)` ⇒ cả cây dựng lại bằng ngôn ngữ mới,
// không phải khởi động lại. Nút trên thông báo đẩy + widget cũng được làm mới ngay.

@MainActor
final class NgonNguApCTW: ObservableObject {
    static let shared = NgonNguApCTW()

    @Published private(set) var cheDo: NgonNguCTW.CheDo = NgonNguCTW.cheDo
    @Published private(set) var ma: String = NgonNguCTW.ma

    var locale: Locale { NgonNguCTW.locale }

    /// Gọi trong `init` của App, TRƯỚC khi dựng view nào.
    nonisolated static func khoiDong() {
        NgonNguCTW.caiDatBundle()
        NgonNguCTW.dongBoVoiCaiDatHeThong()
        CTWDinhDang.locale = NgonNguCTW.locale
        #if DEBUG
        NSLog("[ctw-nn] ma=%@ bundle=%@ cls=%@ a=%@ b=%@ c=%@", NgonNguCTW.ma, NgonNguCTW.bundle?.bundlePath ?? "nil",
              String(describing: object_getClass(Bundle.main)), String(localized: "Account"),
              Bundle.main.localizedString(forKey: "Account", value: nil, table: nil),
              NSLocalizedString("Account", comment: ""))
        #endif
    }

    func dat(_ c: NgonNguCTW.CheDo) {
        guard c != cheDo else { return }
        NgonNguCTW.dat(c)
        CTWDinhDang.locale = NgonNguCTW.locale
        cheDo = c
        if ma != NgonNguCTW.ma { ma = NgonNguCTW.ma }
        // Nút trên thông báo (Reply/Approve…) đăng ký bằng chữ ⇒ đăng ký lại theo ngôn ngữ mới.
        NutThongBaoCTW.dangKy()
        // Widget đọc lựa chọn từ App Group ⇒ vẽ lại.
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Tên hiển thị của một lựa chọn — tên ngôn ngữ viết bằng CHÍNH ngôn ngữ đó (quy ước iOS), để người
    /// lỡ chọn nhầm vẫn đọc được đường về.
    static func ten(_ c: NgonNguCTW.CheDo) -> String {
        switch c {
        case .theoMay: return String(localized: "Device language")
        case .vi: return "Tiếng Việt"
        case .en: return "English"
        }
    }
}
