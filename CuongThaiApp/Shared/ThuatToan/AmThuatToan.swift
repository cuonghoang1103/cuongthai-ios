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
    /// Chọn tiếng theo thứ THẬT SỰ đổi giữa hai khung, không phát bừa mỗi bước.
    ///
    /// ⚠️ Một thuật toán 500 bước mà bước nào cũng kêu thì thành tiếng ồn và
    /// người học tắt ngay. Chỉ kêu khi có việc đáng chú ý:
    ///   · dữ liệu ĐỔI CHỖ  → tiếng gõ ngắn (thao tác đắt nhất của thuật toán)
    ///   · vùng đang xét đổi → blip nhẹ
    ///   · chạy tới bước cuối → hợp âm xong việc
    ///
    /// ⚠️ Duyệt theo THỨ TỰ khoá, không duyệt từ điển thẳng. Từ điển Swift
    /// không giữ thứ tự, nên cùng một bước lúc chạm khối mảng trước, lúc chạm
    /// khối nhật ký trước ⇒ ra tiếng khác nhau ở những lần chạy khác nhau.
    /// Đó chính là cái "kêu không đúng".
    ///
    /// ⚠️ Và ưu tiên có THỨ BẬC: đổi dữ liệu quan trọng hơn đổi vùng chọn, nên
    /// phải quét HẾT mọi tracer tìm thay đổi dữ liệu rồi mới xét vùng chọn —
    /// thoát sớm ở tracer đầu tiên là bỏ sót phép hoán vị ở tracer thứ hai.
    static func theoKhung(truoc: [String: TrangThaiTracer],
                          sau: [String: TrangThaiTracer],
                          cuoi: Bool) {
        guard bat else { return }
        if cuoi { AmMoPhong.shared.phat(.success); return }
        let khoa = sau.keys.sorted()
        for k in khoa {
            guard let a = truoc[k], let b = sau[k] else { continue }
            if a.data != b.data || a.data2 != b.data2 {
                AmMoPhong.shared.phat(.click)
                return
            }
        }
        for k in khoa {
            guard let a = truoc[k], let b = sau[k] else { continue }
            if a.selected != b.selected || a.patched != b.patched
                || a.selectedKeys != b.selectedKeys || a.patchedKeys != b.patchedKeys {
                AmMoPhong.shared.phat(.blip)
                return
            }
        }
    }
}
