import Foundation

// MARK: - Trợ lý AI bản STREAM (SSE) — `POST /projects/:pid/ai/chat/stream` (backend 20/10/2026)
//
// Hợp đồng: api-backend `docs/ctw-ai-stream.md` + chú thích tuyến trong `work.routes.ts`.
//   · Lỗi TRƯỚC khi mở luồng ⇒ JSON thường y như `/ai/chat` (400/402/403/429/503…) — đọc `{message, code}`.
//   · Luồng: `progress` {phase preparing|reading(items)|thinking|checking} · `delta` {text} (NỐI vào nháp) ·
//     `reset` (XOÁ nháp) · `done` = đúng `data` của `/ai/chat` (reply CHUẨN + actions) · `error` {code,message,status}.
//     Dòng `: ping` là nhịp tim. `retry:` bỏ qua — KHÔNG tự kết nối lại (POST; hỏi lại = yêu cầu mới).
//   · Ngắt kết nối (rời màn, bấm Dừng) ⇒ máy chủ thôi gọi model và đánh dấu câu hỏi lỗi (`WORK_AI_CANCELLED`).
// Tuyến CHƯA deploy ở mọi máy chủ ⇒ 404/405/501 hoặc phản hồi không phải `text/event-stream` ⇒ `LoiLuongAI.khongHoTro`
// và ghi nhớ trong phiên (`LuongAICTW.khongCoLuong`) ⇒ VM lặng lẽ dùng `POST /ai/chat` như cũ.

/// Một khung SSE đã ráp xong (có thể từ nhiều mẩu mạng / nhiều dòng `data:`).
struct KhungSSE: Equatable {
    var suKien: String?
    var duLieu: String
}

/// Bộ đọc SSE THUẦN (không mạng) — nạp từng mẩu byte bất kỳ, nhả các khung hoàn chỉnh.
/// Tách dòng theo byte `\n` nên ký tự UTF-8 nhiều byte bị cắt giữa hai mẩu vẫn ráp đúng.
/// ⚠️ Không dùng `bytes.lines` của URLSession: nó NUỐT dòng trống — mà dòng trống chính là dấu kết thúc một khung.
struct BoDocSSE {
    private var dem = Data()
    private var tenSuKien: String?
    private var dongDuLieu: [String] = []

    mutating func nap(_ d: Data) -> [KhungSSE] {
        dem.append(d)
        var ra: [KhungSSE] = []
        while let i = dem.firstIndex(of: 0x0A) {
            var dong = dem[dem.startIndex..<i]
            if dong.last == 0x0D { dong = dong.dropLast() }
            dem.removeSubrange(dem.startIndex...i)
            if let k = xuLy(String(decoding: dong, as: UTF8.self)) { ra.append(k) }
        }
        return ra
    }

    /// Máy chủ đóng luồng: dòng dở + khung chưa có dòng trống kết thúc vẫn được nhả.
    mutating func ketThuc() -> [KhungSSE] {
        var ra: [KhungSSE] = []
        if !dem.isEmpty {
            let con = String(decoding: dem, as: UTF8.self)
            dem.removeAll()
            if let k = xuLy(con) { ra.append(k) }
        }
        if let k = xuLy("") { ra.append(k) }
        return ra
    }

    private mutating func xuLy(_ dong: String) -> KhungSSE? {
        if dong.isEmpty {
            defer { tenSuKien = nil; dongDuLieu = [] }
            guard !dongDuLieu.isEmpty else { return nil }
            return KhungSSE(suKien: tenSuKien, duLieu: dongDuLieu.joined(separator: "\n"))
        }
        if dong.hasPrefix(":") { return nil }   // chú thích — nhịp tim `: ping`
        let truong: Substring, giaTri: Substring
        if let c = dong.firstIndex(of: ":") {
            truong = dong[..<c]
            var v = dong[dong.index(after: c)...]
            if v.first == " " { v = v.dropFirst() }
            giaTri = v
        } else {
            truong = Substring(dong); giaTri = ""
        }
        switch truong {
        case "event": tenSuKien = String(giaTri)
        case "data": dongDuLieu.append(String(giaTri))
        default: break   // id, retry — bỏ qua (không tự kết nối lại)
        }
        return nil
    }
}

/// Sự kiện của trợ lý AI đã giải nghĩa.
enum SuKienAICTW: Equatable {
    case chuanBi(threadId: Int?, questionId: Int?)
    case doc(vong: Int, muc: [String])
    case nghi(vong: Int)
    case kiemTra
    case manh(String)
    case xoaNhap
    /// JSON THÔ của `done` (giải bằng `CTWAIKetQua`, cùng hình dạng `/ai/chat`).
    case xong(Data)
    case loi(ma: String, thongDiep: String, trangThai: Int?)

    /// Khung SSE ⇒ sự kiện. `data` luôn là MỘT JSON có `type`; thiếu `type` thì lấy tên `event:`.
    static func tu(_ k: KhungSSE) -> SuKienAICTW? {
        guard let d = k.duLieu.data(using: .utf8),
              let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { return nil }
        let loai = (o["type"] as? String) ?? k.suKien
        func so(_ x: Any?) -> Int? { (x as? Int) ?? (x as? Double).map { Int($0) } ?? (x as? String).flatMap { Int($0) } }
        switch loai {
        case "progress":
            switch o["phase"] as? String {
            case "preparing": return .chuanBi(threadId: so(o["threadId"]), questionId: so(o["questionId"]))
            case "reading": return .doc(vong: so(o["round"]) ?? 0, muc: (o["items"] as? [Any])?.compactMap { $0 as? String } ?? [])
            case "thinking": return .nghi(vong: so(o["round"]) ?? 0)
            case "checking": return .kiemTra
            default: return nil
            }
        case "delta":
            guard let t = o["text"] as? String, !t.isEmpty else { return nil }
            return .manh(t)
        case "reset": return .xoaNhap
        case "done": return .xong(d)
        case "error":
            return .loi(ma: (o["code"] as? String) ?? "INTERNAL_ERROR",
                        thongDiep: (o["message"] as? String) ?? "",
                        trangThai: so(o["status"]))
        default: return nil
        }
    }
}

enum LoiLuongAI: Error, Equatable {
    /// Máy chủ chưa có tuyến stream (hoặc trả thứ không phải SSE) ⇒ dùng `/ai/chat`.
    case khongHoTro
    /// Luồng đóng mà không có `done`/`error` (mất mạng giữa chừng).
    case dutGiuaChung
}

enum LuongAICTW {
    /// Phiên này đã biết máy chủ KHÔNG có tuyến stream ⇒ đi thẳng `/ai/chat` (không thử lại mỗi câu).
    nonisolated(unsafe) static var khongCoLuong = false

    enum PhanLoai: Equatable { case luong, khongHoTro, loiJSON, phienHetHan }

    /// Phân loại phản hồi đầu tiên của tuyến stream.
    static func phanLoai(trangThai: Int, contentType: String?) -> PhanLoai {
        let ct = (contentType ?? "").lowercased()
        if (200..<300).contains(trangThai) { return ct.contains("text/event-stream") ? .luong : .khongHoTro }
        // 404/405/501 = tuyến chưa có (nginx/Express trả "Route not found" — kể cả JSON). Dự án không tồn tại thì
        // `/ai/chat` cũng trả đúng lỗi đó ⇒ lùi về không mất gì.
        if [404, 405, 501].contains(trangThai) { return .khongHoTro }
        if trangThai == 401 { return .phienHetHan }
        return .loiJSON
    }

    static func duongDan(pid: Int) -> String { "/api/v1/work/projects/\(pid)/ai/chat/stream" }

    /// Thân yêu cầu — y như `/ai/chat` (+ `retryMessageId` để hỏi lại câu đã lưu).
    static func than(cauHoi: String, threadId: Int?, so: Int? = nil, hoiLai: Int? = nil) -> [String: Any] {
        var t: [String: Any] = ["message": String(cauHoi.prefix(8000))]
        if let threadId { t["threadId"] = threadId }
        if let so { t["issueNumber"] = so }
        if let hoiLai { t["retryMessageId"] = hoiLai }
        return t
    }

    /// Mở luồng. Ném `LoiLuongAI.khongHoTro` (lùi về `/ai/chat`), `APIError` (lỗi JSON trước khi mở luồng),
    /// `CancellationError`/`URLError` khi bị huỷ/mất mạng. Huỷ Task đang lặp ⇒ đóng kết nối.
    static func mo(pid: Int, than: [String: Any]) -> AsyncThrowingStream<SuKienAICTW, Error> {
        AsyncThrowingStream { tiep in
            let viec = Task {
                do {
                    guard let url = URL(string: APIClient.diaChiGoc + duongDan(pid: pid)) else { throw LoiLuongAI.khongHoTro }
                    var req = URLRequest(url: url)
                    req.httpMethod = "POST"
                    req.timeoutInterval = 300   // nhịp tim 15 s giữ kết nối; trần nginx 300 s
                    req.setValue(APIClient.nenTang, forHTTPHeaderField: "X-Client-Platform")
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    if let token = StorageManager.shared.getAuthToken() {
                        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    }
                    req.httpBody = try? JSONSerialization.data(withJSONObject: than)

                    let (bytes, resp) = try await URLSession.shared.bytes(for: req)
                    let http = resp as? HTTPURLResponse
                    switch phanLoai(trangThai: http?.statusCode ?? 0, contentType: http?.value(forHTTPHeaderField: "Content-Type")) {
                    case .khongHoTro:
                        khongCoLuong = true
                        throw LoiLuongAI.khongHoTro
                    case .phienHetHan:
                        // Để `APIClient` (có làm mới token) lo lượt này; KHÔNG ghi nhớ — tuyến vẫn có.
                        throw LoiLuongAI.khongHoTro
                    case .loiJSON:
                        var buf = Data()
                        for try await b in bytes { buf.append(b); if buf.count > 32_768 { break } }
                        throw loiTuThan(buf, trangThai: http?.statusCode ?? 0)
                    case .luong:
                        break
                    }

                    var bo = BoDocSSE()
                    var mau = Data()
                    mau.reserveCapacity(512)
                    var ketThuc = false
                    // Gom byte thành mẩu nhỏ: nạp từng byte vào bộ đọc thì chậm; chờ cả dòng thì chậm chữ ⇒ cắt ở `\n`.
                    for try await b in bytes {
                        mau.append(b)
                        guard b == 0x0A else { continue }
                        for k in bo.nap(mau) {
                            guard let s = SuKienAICTW.tu(k) else { continue }
                            tiep.yield(s)
                            if case .xong = s { ketThuc = true }
                            if case .loi = s { ketThuc = true }
                        }
                        mau.removeAll(keepingCapacity: true)
                        if ketThuc { break }
                    }
                    if !ketThuc {
                        var con = bo.nap(mau)
                        con += bo.ketThuc()
                        for k in con {
                            guard let s = SuKienAICTW.tu(k) else { continue }
                            tiep.yield(s)
                            if case .xong = s { ketThuc = true }
                            if case .loi = s { ketThuc = true }
                        }
                    }
                    try Task.checkCancellation()
                    if !ketThuc { throw LoiLuongAI.dutGiuaChung }
                    tiep.finish()
                } catch {
                    tiep.finish(throwing: error)
                }
            }
            tiep.onTermination = { _ in viec.cancel() }
        }
    }

    /// Thân lỗi JSON `{success:false, message, code}` ⇒ `APIError` như `APIClient` dựng.
    static func loiTuThan(_ d: Data, trangThai: Int) -> APIError {
        let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any]
        let m = (o?["message"] as? String) ?? ""
        if let ma = o?["code"] as? String, !ma.isEmpty { return .coMa(ma: ma, thongDiep: m) }
        return m.isEmpty ? .serverError(String(localized: "The server returned an error (\(trangThai)).")) : .serverError(m)
    }

    /// Dòng trạng thái cho người dùng ("Đang đọc LFD-75, Docs #3…").
    static func nhan(_ s: SuKienAICTW) -> String? {
        switch s {
        case .chuanBi: return String(localized: "Getting ready…")
        case .doc(_, let muc):
            let ds = muc.prefix(3).map { $0.count > 40 ? String($0.prefix(38)) + "…" : $0 }
            if ds.isEmpty { return String(localized: "Reading the project…") }
            let ten = ds.joined(separator: ", ")
            return muc.count > 3 ? String(localized: "Reading \(ten) and \(muc.count - 3) more…") : String(localized: "Reading \(ten)…")
        case .nghi: return String(localized: "Thinking…")
        case .kiemTra: return String(localized: "Checking the suggested changes…")
        default: return nil
        }
    }
}
