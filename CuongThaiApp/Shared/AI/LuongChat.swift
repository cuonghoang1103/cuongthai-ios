import Foundation

// ════════════════════════════════════════════════════════════════
// ĐỌC LUỒNG SSE CỦA `POST /api/v1/ai/chat`
//
// Đường này KHÔNG trả JSON một cục như mọi API khác — nó giữ kết nối mở và
// đẩy từng mẩu chữ. Dùng `APIClient.request` ở đây sẽ treo cho tới khi máy chủ
// đóng kết nối, rồi mới hiện cả câu một lần — mất hẳn cảm giác "AI đang gõ".
//
// Các loại sự kiện máy chủ phát (đọc từ `ai.routes.ts`):
//   connected  → có `sessionId`, đến TRƯỚC mọi thứ
//   model      → model thật sự chạy, và `fellBack` nếu bị hạ bậc
//   buoc       → bước đang làm (tìm tài liệu, đọc file…)
//   nguon      → nguồn tham khảo
//   reasoning  → mạch suy nghĩ
//   chunk      → MỘT MẨU CHỮ trả lời
//   figure_fix → hình vẽ sửa lại
//   done       → xong, kèm `tokens`, `model`, `messageId`
//   error      → hỏng
// ════════════════════════════════════════════════════════════════

enum SuKienChat {
    case ketNoi(sessionId: String)
    case model(ten: String, haBac: Bool, lyDo: String?)
    case buoc(String)
    case mau(String)
    case suyNghi(String)
    case nguon([String])
    case xong(messageId: Int?, model: String?, tokens: Int?)
    case hong(String)
}

@MainActor
final class LuongChat {
    /// Gọi `POST /ai/chat` và trả về một dòng sự kiện đọc dần.
    ///
    /// Dùng `URLSession.bytes(for:)` — nó giao từng byte về ngay khi máy chủ
    /// gửi, khác `data(for:)` vốn đợi hết rồi mới trả.
    static func gui(cauHoi: String,
                    sessionId: String?,
                    model: String?,
                    anh: [String] = []) -> AsyncStream<SuKienChat> {
        AsyncStream { tiep in
            Task {
                guard let url = URL(string: APIClient.diaChiGoc + "/api/v1/ai/chat") else {
                    tiep.yield(.hong("Địa chỉ máy chủ không hợp lệ")); tiep.finish(); return
                }
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                // Bắt buộc: thiếu header này một số proxy sẽ gom cả luồng lại
                // rồi mới trả, và chữ hiện ra một cục.
                req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                if let token = StorageManager.shared.getAuthToken() {
                    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                var than: [String: Any] = ["message": cauHoi]
                if let sessionId { than["sessionId"] = sessionId }
                if let model { than["model"] = model }
                if !anh.isEmpty { than["images"] = anh }
                req.httpBody = try? JSONSerialization.data(withJSONObject: than)
                // Câu trả lời dài có thể mất hơn một phút; mặc định 60s sẽ cắt
                // ngang giữa câu.
                req.timeoutInterval = 180

                do {
                    let (bytes, resp) = try await URLSession.shared.bytes(for: req)
                    if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                        tiep.yield(.hong(http.statusCode == 401
                                         ? "Phiên đăng nhập đã hết hạn."
                                         : "Máy chủ trả lỗi \(http.statusCode)"))
                        tiep.finish(); return
                    }
                    for try await dong in bytes.lines {
                        // Khung SSE là "data: {...}". Dòng trống là dấu ngắt
                        // giữa hai khung, bỏ qua.
                        guard dong.hasPrefix("data:") else { continue }
                        let phan = dong.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        guard !phan.isEmpty,
                              let d = phan.data(using: .utf8),
                              let m = try? JSONSerialization.jsonObject(with: d) as? [String: Any]
                        else { continue }

                        switch m["type"] as? String {
                        case "connected":
                            if let s = m["sessionId"] as? String { tiep.yield(.ketNoi(sessionId: s)) }
                            else if let n = m["sessionId"] as? Int { tiep.yield(.ketNoi(sessionId: String(n))) }
                        case "model":
                            tiep.yield(.model(ten: m["effective"] as? String ?? "",
                                              haBac: m["fellBack"] as? Bool ?? false,
                                              lyDo: m["reason"] as? String))
                        case "buoc":
                            tiep.yield(.buoc(m["chu"] as? String ?? m["viec"] as? String ?? ""))
                        case "reasoning":
                            tiep.yield(.suyNghi(m["step"] as? String ?? ""))
                        case "nguon":
                            if let ns = m["nguon"] as? [Any] {
                                tiep.yield(.nguon(ns.compactMap { ($0 as? [String: Any])?["title"] as? String
                                                                  ?? $0 as? String }))
                            }
                        case "chunk":
                            if let t = m["text"] as? String, !t.isEmpty { tiep.yield(.mau(t)) }
                        case "done":
                            tiep.yield(.xong(messageId: m["messageId"] as? Int,
                                             model: m["model"] as? String,
                                             tokens: m["tokens"] as? Int))
                            tiep.finish(); return
                        case "error":
                            tiep.yield(.hong(m["error"] as? String ?? "AI gặp lỗi"))
                            tiep.finish(); return
                        default:
                            break
                        }
                    }
                    tiep.finish()
                } catch {
                    // Người dùng bấm dừng thì `Task` bị huỷ — đó không phải lỗi.
                    if !(error is CancellationError) {
                        tiep.yield(.hong(error.localizedDescription))
                    }
                    tiep.finish()
                }
            }
        }
    }
}
