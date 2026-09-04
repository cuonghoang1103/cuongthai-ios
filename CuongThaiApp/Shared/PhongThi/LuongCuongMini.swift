import Foundation

// ════════════════════════════════════════════════════════════════
// ĐỌC LUỒNG SSE CỦA `POST /exams/attempts/:a/ai/ask-stream`
//
// Đường này giữ kết nối mở và đẩy từng mẩu chữ, không trả JSON một cục.
// `APIClient.request` sẽ treo tới khi máy chủ đóng kết nối rồi mới hiện cả
// câu — mất hẳn cảm giác "AI đang gõ" mà web có.
//
// Khung sự kiện, đọc từ `exam.routes.ts`:
//   {type:'delta', text}            → một mẩu chữ
//   {type:'done',  answer, cached}  → xong; `answer` là bản ĐẦY ĐỦ
//   {type:'error', error}           → hỏng
//
// ⚠️ Khác `LuongChat`: ở đây KHÔNG có sự kiện `connected`/`model`/`nguon`.
// Đừng chép nguyên bộ kia sang rồi ngồi đợi `connected` mãi không tới.
//
// ⚠️ `{type:'done'}` mang `answer` ĐẦY ĐỦ chứ không phải mẩu cuối. Nối nó
// vào phần đã tích là ra một câu trả lời DÀI GẤP ĐÔI — phải THAY, không nối.
// ════════════════════════════════════════════════════════════════

enum SuKienMini {
    case mau(String)
    case xong(traLoi: String, coSan: Bool)
    case hong(String)
}

enum LuongCuongMini {
    /// Gọi `/ai/ask-stream` và trả về dòng sự kiện đọc dần.
    ///
    /// - Parameters:
    ///   - lichSu: các lượt TRƯỚC đó. Máy chủ không nhớ hộ.
    ///   - nhaCungCap: `nil` = để máy chủ tự chọn (Opus trước, lùi Sol).
    static func hoi(attemptId: Int,
                    questionId: Int,
                    cheDo: CheDoHoi,
                    cauHoi: String?,
                    lichSu: [[String: String]],
                    nhaCungCap: String?) -> AsyncStream<SuKienMini> {
        AsyncStream { tiep in
            Task {
                let duong = APIClient.diaChiGoc
                    + "/api/v1/exams/attempts/\(attemptId)/ai/ask-stream"
                guard let url = URL(string: duong) else {
                    tiep.yield(.hong("Địa chỉ máy chủ không hợp lệ")); tiep.finish(); return
                }
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                // Thiếu header này thì một số proxy gom cả luồng rồi mới trả,
                // và chữ hiện ra một cục — hết ý nghĩa của việc stream.
                req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                if let token = StorageManager.shared.getAuthToken() {
                    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                var than: [String: Any] = ["questionId": questionId, "mode": cheDo.rawValue]
                if let cauHoi, !cauHoi.isEmpty { than["question"] = cauHoi }
                if !lichSu.isEmpty { than["history"] = lichSu }
                if let nhaCungCap { than["provider"] = nhaCungCap }
                req.httpBody = try? JSONSerialization.data(withJSONObject: than)
                // Opus qua cổng rambo có thể mất hơn một phút cho câu khó;
                // mặc định 60s sẽ cắt ngang giữa câu.
                req.timeoutInterval = 180

                do {
                    let (bytes, resp) = try await URLSession.shared.bytes(for: req)
                    if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                        tiep.yield(.hong(thongBaoLoi(http.statusCode)))
                        tiep.finish(); return
                    }
                    var daNhan = ""
                    for try await dong in bytes.lines {
                        // `: ka` là nhịp giữ kết nối (keep-alive) máy chủ gửi
                        // mỗi 15 giây — không phải dữ liệu.
                        guard dong.hasPrefix("data:") else { continue }
                        let phan = dong.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        guard !phan.isEmpty,
                              let d = phan.data(using: .utf8),
                              let m = try? JSONSerialization.jsonObject(with: d) as? [String: Any]
                        else { continue }

                        switch m["type"] as? String {
                        case "delta":
                            if let t = m["text"] as? String, !t.isEmpty {
                                daNhan += t
                                tiep.yield(.mau(t))
                            }
                        case "done":
                            let day = (m["answer"] as? String) ?? daNhan
                            tiep.yield(.xong(traLoi: day, coSan: m["cached"] as? Bool ?? false))
                            tiep.finish(); return
                        case "error":
                            tiep.yield(.hong((m["error"] as? String) ?? "CuongMini chưa trả lời được."))
                            tiep.finish(); return
                        default:
                            break
                        }
                    }
                    // Luồng đứt mà chưa có `done`: có chữ thì vẫn dùng được,
                    // không có chữ nào mới là hỏng thật.
                    if daNhan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        tiep.yield(.hong("Luồng trả lời bị ngắt giữa chừng."))
                    } else {
                        tiep.yield(.xong(traLoi: daNhan, coSan: false))
                    }
                    tiep.finish()
                } catch {
                    if !(error is CancellationError) {
                        tiep.yield(.hong(error.localizedDescription))
                    }
                    tiep.finish()
                }
            }
        }
    }

    /// ⚠️ 403 ở đây KHÔNG phải "không có quyền" chung chung — nó là cổng Pro
    /// của `requireProForAi()`. Nói đúng tên ra, không thì người dùng đi tìm
    /// lỗi đăng nhập.
    private static func thongBaoLoi(_ ma: Int) -> String {
        switch ma {
        case 401: return "Phiên đăng nhập đã hết hạn."
        case 403: return "Hỏi CuongMini là tính năng Pro."
        case 400: return "Bài thi đã nộp, không hỏi CuongMini được nữa."
        case 404: return "Không tìm thấy câu hỏi này trong lượt thi."
        default:  return "Máy chủ trả lỗi \(ma)"
        }
    }
}
