import XCTest
import SwiftUI
@testable import CuongThaiApp

/// Chủ đề 4 mùa (23/10/2026): tương phản WCAG của MỌI bảng × sáng/tối, luật tháng → mùa, Tết, lời chào.
@MainActor
final class ChuDeTests: XCTestCase {

    private func rgb(_ c: Color, _ kieu: UIUserInterfaceStyle) -> (Double, Double, Double, Double) {
        let u = UIColor(c).resolvedColor(with: UITraitCollection(userInterfaceStyle: kieu))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        u.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }

    private func doChoi(_ c: (Double, Double, Double, Double)) -> Double {
        func f(_ x: Double) -> Double { x <= 0.03928 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4) }
        return 0.2126 * f(c.0) + 0.7152 * f(c.1) + 0.0722 * f(c.2)
    }

    private func tuongPhan(_ a: Color, _ b: Color, _ kieu: UIUserInterfaceStyle) -> Double {
        let la = doChoi(rgb(a, kieu)), lb = doChoi(rgb(b, kieu))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Chữ (3 bậc) + primary làm chữ ≥ 4,5:1 trên cả 4 nền; chữ trắng trên nút primary ≥ 4,5 (sáng) / 3 (tối).
    /// Màu tín hiệu chung (success/error/warning/info) cũng phải đạt ≥ 4,5 (sáng) / 3 (tối) trên nền của mọi mùa.
    func testTuongPhanMoiChuDe() {
        var loi: [String] = []
        for mua in [nil] + Mua.allCases.map(Optional.some) {
            let b = BangMauChuDe.cua(mua)
            let ten = mua?.rawValue ?? "macDinh"
            let nen: [(String, Color)] = [("bg1", b.backgroundPrimary), ("bg2", b.backgroundSecondary),
                                          ("bg3", b.backgroundTertiary), ("card", b.backgroundCard)]
            for kieu in [UIUserInterfaceStyle.light, .dark] {
                let tk = kieu == .light ? "sáng" : "tối"
                for (tc, chu) in [("text1", b.textPrimary), ("text2", b.textSecondary), ("text3", b.textTertiary),
                                  ("primary", b.primary)] {
                    for (tn, n) in nen {
                        let c = tuongPhan(chu, n, kieu)
                        if c < 4.5 { loi.append("\(ten)/\(tk): \(tc) trên \(tn) = \(String(format: "%.2f", c))") }
                    }
                }
                let trang = tuongPhan(.white, b.primary, kieu)
                if trang < (kieu == .light ? 4.5 : 3.0) {
                    loi.append("\(ten)/\(tk): chữ trắng trên primary = \(String(format: "%.2f", trang))")
                }
                for (ts, s) in [("success", AppColors.success), ("error", AppColors.error),
                                ("warning", AppColors.warning), ("info", AppColors.info)] {
                    let c = tuongPhan(s, b.backgroundCard, kieu)
                    if c < (kieu == .light ? 4.5 : 3.0) {
                        loi.append("\(ten)/\(tk): \(ts) trên card = \(String(format: "%.2f", c))")
                    }
                }
            }
        }
        XCTAssertTrue(loi.isEmpty, loi.joined(separator: "\n"))
    }

    func testThangRaMua() {
        XCTAssertEqual((1...12).map { Mua.theoThang($0) },
                       [.xuan, .xuan, .xuan, .ha, .ha, .ha, .ha, .thu, .thu, .thu, .dong, .dong])
        XCTAssertNil(ChuDe.macDinh.mua())
        XCTAssertEqual(ChuDe.dong.mua(), .dong)
    }

    func testTetVaCanChi() {
        let l = Calendar.current
        XCTAssertEqual(NgayLe.tet(nam: 2027).map { l.dateComponents([.month, .day], from: $0) },
                       DateComponents(month: 2, day: 6))
        XCTAssertEqual(NgayLe.canChi(2026), "Bính Ngọ")
        XCTAssertEqual(NgayLe.canChi(2027), "Đinh Mùi")
        // Năm ngoài bảng ⇒ lùi về lịch Trung Hoa (2036: 28/01).
        XCTAssertEqual(NgayLe.tet(nam: 2036).map { l.dateComponents([.month, .day], from: $0) },
                       DateComponents(month: 1, day: 28))
    }

    func testLoiChaoDemNguoc() {
        let l = Calendar.current
        let ngay = l.date(from: DateComponents(year: 2026, month: 12, day: 20))!
        XCTAssertTrue(NgayLe.loiMua(.dong, ngay)?.chu.contains("5") == true)
        let sauNoel = l.date(from: DateComponents(year: 2026, month: 12, day: 27))!
        XCTAssertTrue(NgayLe.loiMua(.dong, sauNoel)?.chu.contains("Đinh Mùi") == true)
        XCTAssertNil(NgayLe.loiMua(nil, ngay))
    }
}
