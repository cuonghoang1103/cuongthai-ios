#if DEBUG
import Foundation

// MARK: - Máy chủ giả: trợ lý AI bản STREAM (`POST /work/projects/7/ai/chat/stream`)
//
// Phát đúng hợp đồng `docs/ctw-ai-stream.md`: progress preparing → reading(items) → thinking → delta… → done (cùng hình
// dạng `/ai/chat`, câu hỏi + trả lời lưu vào `AIGia`). Mẩu byte cắt NGẪU NHIÊN ở cỡ cố định (kể cả giữa ký tự UTF-8 nhiều
// byte, giữa `data:` và JSON) + dòng `: ping` ⇒ kiểm bộ đọc SSE trên đường thật.
//   · Câu hỏi chứa "#fail" ⇒ preparing → thinking → `error` WORK_AI_BAD_OUTPUT (câu hỏi lưu kèm lỗi ⇒ "Ask again").
//   · `CT_XEM_LUONG=0` ⇒ tuyến trả 404 "Route not found" (như máy chủ chưa deploy) ⇒ app lùi về `/ai/chat`.
//   · `CT_XEM_LUONG_CHAM=<hệ số>` ⇒ chậm lại (chụp màn giữa chừng).
// ⚠️ Cả tệp trong `#if DEBUG` (CLAUDE.md A6).

enum DuLieuGiaLuongAI {
    struct PhanHoi {
        var trangThai: Int
        var loaiNoiDung: String
        /// (giây kể từ lúc bắt đầu, mẩu byte)
        var mau: [(Double, Data)]
    }

    static func luong(method: String, path: String, body: [String: Any]) -> PhanHoi? {
        guard method == "POST", path.hasSuffix("/ai/chat/stream") else { return nil }
        let env = ProcessInfo.processInfo.environment
        if env["CT_XEM_LUONG"] == "0" {
            let goi: [String: Any] = ["success": false, "message": "Route not found", "code": "NOT_FOUND"]
            return PhanHoi(trangThai: 404, loaiNoiDung: "application/json; charset=utf-8",
                           mau: [(0.1, (try? JSONSerialization.data(withJSONObject: goi)) ?? Data())])
        }
        let cham = Double(env["CT_XEM_LUONG_CHAM"] ?? "") ?? 1
        let tid = body["threadId"] as? Int ?? 0
        let cau = body["message"] as? String ?? ""
        let retry = body["retryMessageId"] as? Int

        var t = 0.0
        var ra: [(Double, Data)] = []
        func phat(_ o: [String: Any], sau: Double, cat: Int? = nil) {
            t += sau * cham
            let json = String(decoding: (try? JSONSerialization.data(withJSONObject: o)) ?? Data(), as: UTF8.self)
            let khung = Data("event: \(o["type"] as? String ?? "message")\ndata: \(json)\n\n".utf8)
            guard let cat, khung.count > cat else { ra.append((t, khung)); return }
            var i = khung.startIndex
            while i < khung.endIndex {
                let j = khung.index(i, offsetBy: cat, limitedBy: khung.endIndex) ?? khung.endIndex
                ra.append((t, khung[i..<j]))
                i = j
                t += 0.004 * cham
            }
        }
        ra.append((0.05, Data("retry: 5000\n\n".utf8)))

        // Máy chủ LƯU câu hỏi trước rồi mới gọi model ⇒ có `questionId` ngay ở `preparing`.
        let kq: Any = retry.map { AIGia.hoiLai($0) } ?? AIGia.hoi(["threadId": tid, "message": cau], traLoi: AIGia.traLoiCho(cau) == AIGia.traLoiHomNay ? AIGia.traLoiHomNay : AIGia.traLoiBang)
        let qid = retry ?? AIGia.idCauHoiCuoi(tid) ?? 0
        phat(["type": "progress", "phase": "preparing", "threadId": tid, "questionId": qid], sau: 0.15)
        if cau.contains("#fail") {
            phat(["type": "progress", "phase": "thinking", "round": 0], sau: 0.4)
            phat(["type": "error", "code": "WORK_AI_BAD_OUTPUT", "message": "The AI returned an answer we could not read. Please try again.", "status": 502], sau: 1.2)
            return PhanHoi(trangThai: 200, loaiNoiDung: "text/event-stream; charset=utf-8", mau: ra)
        }
        phat(["type": "progress", "phase": "reading", "round": 0, "items": ["NW-12", "NW-17", "NW-19"], "prefetched": true], sau: 0.5)
        phat(["type": "progress", "phase": "thinking", "round": 0], sau: 1.2)
        ra.append((t + 0.3 * cham, Data(": ping\n\n".utf8)))
        phat(["type": "progress", "phase": "reading", "round": 1, "items": ["Docs #3 — Notification payloads", "Sprint 6"]], sau: 1.0)
        phat(["type": "progress", "phase": "thinking", "round": 1], sau: 1.2)

        // Lượt nháp hỏng giữa chừng (model xin đọc thêm) ⇒ `reset` rồi viết lại — như ReplyStreamer phát.
        phat(["type": "delta", "text": "Đang xem lại…"], sau: 0.6)
        phat(["type": "reset"], sau: 0.3)

        let reply = ((kq as? [String: Any])?["reply"] as? String) ?? AIGia.traLoiBang
        // Mẩu chữ ~14 ký tự, mỗi mẩu cắt thành nhiều gói 23 byte (rơi giữa ký tự tiếng Việt nhiều byte).
        var cs = Array(reply)
        var lan = 0.4
        while !cs.isEmpty {
            let n = min(14, cs.count)
            phat(["type": "delta", "text": String(cs.prefix(n))], sau: lan, cat: 23)
            cs.removeFirst(n)
            lan = 0.07
        }
        var xong: [String: Any] = (kq as? [String: Any]) ?? [:]
        xong["type"] = "done"
        phat(xong, sau: 0.3, cat: 997)
        return PhanHoi(trangThai: 200, loaiNoiDung: "text/event-stream; charset=utf-8", mau: ra)
    }
}
#endif
