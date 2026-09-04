import Foundation

// ════════════════════════════════════════════════════════════════
// CUONGMINI — GỌI `POST /exams/attempts/:a/ai/ask-stream`
//
// Vòng lặp đọc SSE nằm ở `LuongHoiDap` (dùng chung với gia sư Academy) — ở
// đây chỉ dựng thân yêu cầu và dịch mã lỗi sang tiếng người dùng.
// ════════════════════════════════════════════════════════════════

/// Giữ tên cũ cho các màn đang dùng; nó chính là `SuKienHoiDap`.
typealias SuKienMini = SuKienHoiDap

enum LuongCuongMini {
    /// - Parameters:
    ///   - lichSu: các lượt TRƯỚC đó. Máy chủ không nhớ hộ.
    ///   - nhaCungCap: `nil` = để máy chủ tự chọn (Opus trước, lùi Sol).
    static func hoi(attemptId: Int,
                    questionId: Int,
                    cheDo: CheDoHoi,
                    cauHoi: String?,
                    lichSu: [[String: String]],
                    nhaCungCap: String?) -> AsyncStream<SuKienMini> {
        var than: [String: Any] = ["questionId": questionId, "mode": cheDo.rawValue]
        if let cauHoi, !cauHoi.isEmpty { than["question"] = cauHoi }
        if !lichSu.isEmpty { than["history"] = lichSu }
        if let nhaCungCap { than["provider"] = nhaCungCap }

        return LuongHoiDap.doc(
            duong: "/api/v1/exams/attempts/\(attemptId)/ai/ask-stream",
            than: than,
            loiTheoMa: { ma in
                switch ma {
                case 401: return "Phiên đăng nhập đã hết hạn."
                // ⚠️ 403 ở đây là cổng Pro của `requireProForAi()`, không phải
                // "không có quyền" chung chung. Nói đúng tên ra, không thì
                // người dùng đi tìm lỗi đăng nhập.
                case 403: return "Hỏi CuongMini là tính năng Pro."
                case 400: return "Bài thi đã nộp, không hỏi CuongMini được nữa."
                case 404: return "Không tìm thấy câu hỏi này trong lượt thi."
                default:  return "Máy chủ trả lỗi \(ma)"
                }
            })
    }
}
