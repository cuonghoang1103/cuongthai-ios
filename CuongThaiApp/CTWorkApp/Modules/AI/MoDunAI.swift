import SwiftUI

// MARK: - Đăng ký mô-đun "CuongMini" (trợ lý AI mentor của dự án — web 18/10/2026; đổi tên + thêm lối vào 21/10/2026)
//
// Hiện khi người dùng được hỏi AI trong dự án (`permissions.useAi` = vai ADMIN/MEMBER; khách cổng, người xem và
// agent không có). Web mở trợ lý bằng bảng trượt (không có đường riêng) ⇒ `doanWeb: nil`. Id giữ là `ai` (ghim đồng bộ
// `navPins` của web dùng id này). Lối vào khác (nút ✦, thẻ My Work, nút trong thẻ): `CuongMiniCTW.swift` ⇒ `RouteCuongMiniCTW`.
// App Store 5.1.2(i)/4.7: đồng ý trước câu hỏi đầu + nhãn AI + báo cáo câu trả lời — xem `TroLyAICTW.swift`.

extension CTWModule {
    static let ai = CTWModule(
        id: "ai", ten: "CuongMini", bieuTuong: "sparkles", nhom: .duAn,
        moTa: "Your project's AI assistant", thuTu: 5, doanWeb: nil,
        hien: { cfg in CuongMini.coTheDung(cfg) },
        man: { c in AnyView(TroLyAICTW(pid: c.pid, maDuAn: c.maDuAn)) },
        dichDen: { v in
            AnyView(v.navigationDestination(for: RouteCuongMiniCTW.self) { r in
                TroLyAICTW(pid: r.pid, maDuAn: r.maDuAn, the: r.the, khoiDau: r.khoiDau)
            })
        })
}
