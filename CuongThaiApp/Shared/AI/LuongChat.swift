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
    case nguon([NguonWeb])
    case xong(messageId: Int?, model: String?, tokens: Int?)
    case hong(String)
}

/// Một nguồn web model đã đọc để trả lời.
struct NguonWeb: Identifiable, Hashable {
    let id = UUID()
    let tieuDe: String
    let url: String
    let mien: String

    init?(tu m: [String: Any]) {
        guard let u = m["url"] as? String, !u.isEmpty else { return nil }
        url = u
        tieuDe = (m["tieuDe"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? u
        mien = (m["mien"] as? String) ?? URL(string: u)?.host ?? ""
    }
}

@MainActor
final class LuongChat {
    /// Gọi `POST /ai/chat` và trả về một dòng sự kiện đọc dần.
    ///
    /// Dùng `URLSession.bytes(for:)` — nó giao từng byte về ngay khi máy chủ
    /// gửi, khác `data(for:)` vốn đợi hết rồi mới trả.
    /// - Parameter lichSu: các lượt TRƯỚC đó. Backend KHÔNG tự nạp lịch sử
    ///   theo `sessionId` — `streamChat` chỉ GHI vào phiên chứ không đọc ra.
    ///   Không gửi cái này thì mỗi câu hỏi là một cuộc đời mới.
    /// Câu báo lỗi cho người dùng từ mã HTTP + thân lỗi của máy chủ.
    ///
    /// Máy chủ trả `{success:false, message, code}`. Câu của nó ưu tiên hơn
    /// câu soạn sẵn ở đây — trừ 5xx, vì máy chủ cố ý giấu chi tiết ở đó và
    /// chỉ còn "Internal Server Error" tiếng Anh.
    static func cauLoi(_ ma: Int, than: Data) -> String {
        let json = (try? JSONSerialization.jsonObject(with: than)) as? [String: Any]
        let cuaMay = (json?["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        switch ma {
        case 401:
            return "Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại."
        case 413:
            // Bản máy chủ cũ trả "request entity too large" tiếng Anh.
            if let cuaMay, cuaMay.contains("gửi kèm") { return cuaMay }
            return "Ảnh hoặc tệp gửi kèm quá lớn. Hãy bớt tệp, hoặc gửi tệp nhỏ hơn."
        case 429:
            return cuaMay ?? "Bạn gửi hơi nhanh — đợi vài giây rồi thử lại nhé."
        case 400..<500:
            return cuaMay.flatMap { $0.isEmpty ? nil : $0 } ?? "Yêu cầu không hợp lệ (mã \(ma))."
        default:
            return "Máy chủ đang gặp sự cố (mã \(ma)). Thử lại sau ít phút."
        }
    }

    static func gui(cauHoi: String,
                    sessionId: String?,
                    model: String?,
                    lichSu: [[String: String]] = [],
                    anh: [String] = [],
                    taiLieu: [String] = [],
                    tenTaiLieu: [String] = [],
                    timWeb: Bool = true,
                    voice: Bool = false) -> AsyncStream<SuKienChat> {
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
                if !lichSu.isEmpty { than["history"] = lichSu }
                if !anh.isEmpty { than["images"] = anh }
                if !taiLieu.isEmpty { than["documents"] = taiLieu }
                if !tenTaiLieu.isEmpty { than["documentNames"] = tenTaiLieu }
                // Mặc định của backend là BẬT. Bậc nhanh tắt đi để khỏi mất
                // mấy giây tìm web cho câu hỏi thường ngày.
                if !timWeb { than["choTimWeb"] = false }
                if voice {
                    // ⚠️ Backend đã có sẵn `VOICE_RULES` (2-4 câu, không
                    // markdown, số viết thành chữ). Trước đây app tự nhét một
                    // câu chỉ dẫn tương tự vào MỖI lượt — vừa thừa vừa tốn
                    // token, mà lại kém hơn bản backend. Chỉ cần bật cờ.
                    than["voice"] = true
                }
                // "Hôm nay" và "bây giờ" theo MÁY NÀY, không để máy chủ tự tính:
                // container chạy UTC còn người dùng ở +07, nên từ 17:00 giờ VN
                // trở đi máy chủ đã sang hôm sau và sẽ đọc lịch của ngày mai.
                let lich = Calendar.current
                let nay = Date()
                let d = lich.dateComponents([.year, .month, .day, .hour, .minute], from: nay)
                if let y = d.year, let m = d.month, let ng = d.day, let h = d.hour, let p = d.minute {
                    than["homNay"] = String(format: "%04d-%02d-%02d", y, m, ng)
                    than["gioPhut"] = String(format: "%02d:%02d", h, p)
                }
                req.httpBody = try? JSONSerialization.data(withJSONObject: than)
                // Câu trả lời dài có thể mất hơn một phút; mặc định 60s sẽ cắt
                // ngang giữa câu.
                req.timeoutInterval = 180

                do {
                    let (bytes, resp) = try await URLSession.shared.bytes(for: req)
                    if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                        // ĐỌC thân lỗi. Bản cũ chỉ in con số — người dùng gửi hai
                        // PDF và nhận "Máy chủ trả lỗi 413", không một chữ nào nói
                        // là do tệp to, trong khi máy chủ có trả câu giải thích.
                        var than = Data()
                        for try await b in bytes {
                            than.append(b)
                            if than.count > 16_384 { break }
                        }
                        tiep.yield(.hong(Self.cauLoi(http.statusCode, than: than)))
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
                            // ⚠️ Backend gửi `tieuDe` / `url` / `mien` — KHÔNG
                            // phải `title`. Bản trước đọc `title` nên mảng
                            // luôn rỗng, và vì nó bị `break` bỏ đi nên không
                            // ai thấy. Hai lỗi câm chồng lên nhau.
                            if let ns = m["nguon"] as? [[String: Any]] {
                                tiep.yield(.nguon(ns.compactMap(NguonWeb.init(tu:))))
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
