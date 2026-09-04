import Foundation

// ════════════════════════════════════════════════════════════════
// BỘ ĐỌC LUỒNG SSE CHO MỌI ĐƯỜNG HỎI-ĐÁP CỦA WEB
//
// Ba đường của web dùng CHUNG một khuôn sự kiện (đọc từ `exam.routes.ts` và
// `course.routes.ts`):
//
//   {type:'delta', text}            → một mẩu chữ
//   {type:'done',  answer, cached}  → xong; `answer` là bản ĐẦY ĐỦ
//   {type:'error', error}           → hỏng
//
//   POST /exams/attempts/:a/ai/ask-stream        — CuongMini (phòng thi)
//   POST /courses/lessons/:id/ai/ask-stream      — gia sư từng bài Academy
//
// ⚠️ Tách ra đây chứ KHÔNG chép sang từng màn. Vòng lặp này có bốn chỗ dễ sai
// mà chỉ hỏng lúc chạy thật, không hỏng lúc build — chép ra hai bản là sớm
// muộn cũng có một bản sót một chỗ:
//   1. `{done}` mang bản ĐẦY ĐỦ ⇒ phải THAY, nối vào là câu trả lời dài gấp đôi
//   2. `: ka` là nhịp giữ kết nối 15 giây, không phải dữ liệu
//   3. thiếu `Accept: text/event-stream` thì proxy gom cả luồng rồi mới trả
//   4. luồng đứt giữa chừng mà đã có chữ thì phải GIỮ, không phải bỏ đi
// ════════════════════════════════════════════════════════════════

enum SuKienHoiDap {
    case mau(String)
    case xong(traLoi: String, coSan: Bool)
    case hong(String)
}

enum LuongHoiDap {
    /// - Parameters:
    ///   - duong: đường dẫn tuyệt đối tính từ gốc, ví dụ `/api/v1/…/ai/ask-stream`.
    ///   - loiTheoMa: đổi mã HTTP thành câu người dùng đọc được. Mỗi tính năng
    ///     một bộ câu riêng — 403 ở đây là cổng Pro, không phải "không có quyền"
    ///     chung chung, và nói sai là người dùng đi tìm nhầm chỗ.
    static func doc(duong: String,
                    than: [String: Any],
                    loiTheoMa: @escaping (Int) -> String) -> AsyncStream<SuKienHoiDap> {
        AsyncStream { tiep in
            Task {
                guard let url = URL(string: APIClient.diaChiGoc + duong) else {
                    tiep.yield(.hong("Địa chỉ máy chủ không hợp lệ")); tiep.finish(); return
                }
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                if let token = StorageManager.shared.getAuthToken() {
                    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                req.httpBody = try? JSONSerialization.data(withJSONObject: than)
                // Câu khó qua Opus có thể mất hơn một phút; mặc định 60s cắt
                // ngang giữa câu.
                req.timeoutInterval = 240

                do {
                    let (bytes, resp) = try await URLSession.shared.bytes(for: req)
                    if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                        tiep.yield(.hong(loiTheoMa(http.statusCode)))
                        tiep.finish(); return
                    }
                    var daNhan = ""
                    for try await dong in bytes.lines {
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
                            tiep.yield(.hong((m["error"] as? String) ?? "AI chưa trả lời được."))
                            tiep.finish(); return
                        default:
                            break
                        }
                    }
                    if daNhan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        tiep.yield(.hong("Luồng trả lời bị ngắt giữa chừng."))
                    } else {
                        tiep.yield(.xong(traLoi: daNhan, coSan: false))
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
