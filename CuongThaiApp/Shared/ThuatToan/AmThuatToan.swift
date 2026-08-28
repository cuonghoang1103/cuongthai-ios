import Foundation

// ════════════════════════════════════════════════════════════════
// ÂM THANH TRANG THUẬT TOÁN
//
// ⚠️ Web KHÔNG có âm thanh ở trang này (đo 28/08/2026: không `AudioContext`,
// không `Oscillator` trong `components/algorithms/`). Đây là phần LÀM MỚI
// theo yêu cầu, không phải port — nên nếu sau này đối chiếu với web mà thấy
// khác thì đó là chủ ý, không phải trôi dạt.
//
// Dùng lại đúng bộ tổng hợp của mô phỏng để không có hai bảng âm sắc.
// ════════════════════════════════════════════════════════════════

@MainActor
enum AmThuatToan {
    /// Bật/tắt riêng — người học có thể muốn tiếng ở mô phỏng mà im ở đây.
    static var bat: Bool {
        get { UserDefaults.standard.object(forKey: "thuattoan.am") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "thuattoan.am") }
    }

    /// Chọn tiếng theo thứ THẬT SỰ đổi giữa hai khung, không phát bừa mỗi bước.
    ///
    /// ⚠️ Một thuật toán 500 bước mà bước nào cũng kêu thì thành tiếng ồn và
    /// người học tắt ngay. Chỉ kêu khi có việc đáng chú ý:
    ///   · dữ liệu ĐỔI CHỖ  → tiếng gõ ngắn (đây là thao tác đắt nhất)
    ///   · vùng đang xét đổi → tiếng blip nhẹ
    ///   · chạy tới bước cuối → hợp âm xong việc
    static func theoKhung(truoc: [String: TrangThaiTracer],
                          sau: [String: TrangThaiTracer],
                          cuoi: Bool) {
        guard bat else { return }
        if cuoi { AmMoPhong.shared.phat(.success); return }
        for (k, b) in sau {
            guard let a = truoc[k] else { continue }
            if let d1 = a.data, let d2 = b.data, d1 != d2 {
                AmMoPhong.shared.phat(.click)
                return
            }
            if a.selected != b.selected || a.patched != b.patched {
                AmMoPhong.shared.phat(.blip)
                return
            }
        }
    }
}
