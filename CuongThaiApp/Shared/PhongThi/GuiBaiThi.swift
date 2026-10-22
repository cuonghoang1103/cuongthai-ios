import Foundation
#if os(iOS)
import UIKit
#endif

// ════════════════════════════════════════════════════════════════
// NỘP BÀI PE — ba đường multipart của `exam.routes.ts`
//
// Đọc thẳng từ route (22/10/2026), đừng đoán:
//
//   submit-code   multer `zipUpload.single('file')`, trần 30MB
//                 trường: file (.zip) · timeSpentSeconds
//   submit-write  multer `diagramUpload.any()`, 8MB/tệp, tối đa 10 tệp
//                 trường: essays (CHUỖI JSON {questionId: text}) ·
//                 image_<questionId> (png/jpeg/webp/gif) · timeSpentSeconds
//   submit-speak  multer `audioUpload.array('audio', 12)`, 20MB/tệp
//                 trường: audio (lặp lại, đúng thứ tự câu) · questionId ·
//                 timeSpentSeconds
//
// Cả ba trả về TRỌN BẢN XEM LẠI (`finalizePe` → `buildReview`), giống
// `submit-fe` — nên màn kết quả không cần gọi thêm gì.
//
// ⚠️ Ba đường này gửi bài làm (mã, bài viết, ẢNH sơ đồ, GIỌNG NÓI) tới AI
// bên thứ ba để chấm, mà đường dẫn KHÔNG chứa `/ai/` nên chốt chung
// `DongYChiaSeAI.laDuongAI` không bắt được ⇒ hỏi đồng ý NGAY Ở ĐÂY (5.1.2(i)).
// ════════════════════════════════════════════════════════════════

/// Thân `multipart/form-data`. Tách riêng để kiểm thử được từng byte.
struct ThanNhieuPhan {
    let ranhGioi: String
    private(set) var duLieu = Data()

    init(ranhGioi: String = "CuongThai-\(UUID().uuidString)") { self.ranhGioi = ranhGioi }

    var kieuNoiDung: String { "multipart/form-data; boundary=\(ranhGioi)" }

    mutating func them(truong ten: String, giaTri: String) {
        ghi("--\(ranhGioi)\r\n")
        ghi("Content-Disposition: form-data; name=\"\(ThanNhieuPhan.thoat(ten))\"\r\n\r\n")
        ghi(giaTri)
        ghi("\r\n")
    }

    mutating func them(tep ten: String, tenTep: String, kieu: String, duLieu d: Data) {
        ghi("--\(ranhGioi)\r\n")
        ghi("Content-Disposition: form-data; name=\"\(ThanNhieuPhan.thoat(ten))\"; filename=\"\(ThanNhieuPhan.thoat(tenTep))\"\r\n")
        ghi("Content-Type: \(kieu)\r\n\r\n")
        duLieu.append(d)
        ghi("\r\n")
    }

    /// Đóng thân — gọi đúng MỘT lần, sau trường cuối.
    mutating func dong() { ghi("--\(ranhGioi)--\r\n") }

    private mutating func ghi(_ s: String) { duLieu.append(Data(s.utf8)) }

    /// Dấu nháy kép và xuống dòng trong tên trường/tên tệp làm vỡ tiêu đề.
    static func thoat(_ s: String) -> String {
        s.replacingOccurrences(of: "\"", with: "%22")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }
}

enum GuiBaiThi {
    enum Loi: LocalizedError {
        case tepQuaLon(String)
        case khongCoGi(String)
        var errorDescription: String? {
            switch self { case .tepQuaLon(let m), .khongCoGi(let m): return m }
        }
    }

    static let tranZip = 30 * 1024 * 1024
    static let tranAnh = 8 * 1024 * 1024
    static let tranAmThanh = 20 * 1024 * 1024

    // MARK: Ba đường nộp

    static func nopCode(attemptId: Int, zip: Data, tenTep: String, giay: Int) async throws -> XemLaiBaiThi {
        guard zip.count <= tranZip else { throw Loi.tepQuaLon(T("Tệp .zip vượt 30MB — máy chủ không nhận.")) }
        var t = ThanNhieuPhan()
        t.them(tep: "file", tenTep: tenTep.lowercased().hasSuffix(".zip") ? tenTep : tenTep + ".zip",
               kieu: "application/zip", duLieu: zip)
        t.them(truong: "timeSpentSeconds", giaTri: String(max(0, giay)))
        t.dong()
        return try await gui("/api/v1/exams/attempts/\(attemptId)/submit-code", than: t)
    }

    /// - Parameter anh: ảnh sơ đồ theo id câu (đã nén JPEG).
    static func nopViet(attemptId: Int, bai: [Int: String], anh: [Int: Data], giay: Int) async throws -> XemLaiBaiThi {
        var t = ThanNhieuPhan()
        let essays = Dictionary(uniqueKeysWithValues: bai.map { (String($0.key), $0.value) })
        let json = (try? JSONSerialization.data(withJSONObject: essays, options: [.sortedKeys]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        t.them(truong: "essays", giaTri: json)
        for (qid, d) in anh.sorted(by: { $0.key < $1.key }) {
            guard d.count <= tranAnh else { throw Loi.tepQuaLon(T("Ảnh sơ đồ vượt 8MB — hãy chọn ảnh nhỏ hơn.")) }
            t.them(tep: "image_\(qid)", tenTep: "so-do-\(qid).jpg", kieu: "image/jpeg", duLieu: d)
        }
        t.them(truong: "timeSpentSeconds", giaTri: String(max(0, giay)))
        t.dong()
        return try await gui("/api/v1/exams/attempts/\(attemptId)/submit-write", than: t)
    }

    /// - Parameter amThanh: các bản ghi THEO THỨ TỰ câu hỏi phụ (m4a/AAC).
    static func nopNoi(attemptId: Int, questionId: Int, amThanh: [URL], giay: Int) async throws -> XemLaiBaiThi {
        guard !amThanh.isEmpty else { throw Loi.khongCoGi(T("Hãy thu âm ít nhất một câu.")) }
        var t = ThanNhieuPhan()
        for (i, u) in amThanh.prefix(12).enumerated() {
            let d = try Data(contentsOf: u)
            guard d.count <= tranAmThanh else { throw Loi.tepQuaLon(T("Một bản ghi vượt 20MB — hãy thu ngắn hơn.")) }
            // Whisper (Groq) đọc đuôi tệp để đoán định dạng — đuôi phải khớp nội dung.
            t.them(tep: "audio", tenTep: "answer-\(i + 1).m4a", kieu: "audio/m4a", duLieu: d)
        }
        t.them(truong: "questionId", giaTri: String(questionId))
        t.them(truong: "timeSpentSeconds", giaTri: String(max(0, giay)))
        t.dong()
        return try await gui("/api/v1/exams/attempts/\(attemptId)/submit-speak", than: t)
    }

    // MARK: Vận chuyển

    private static func gui(_ duong: String, than: ThanNhieuPhan) async throws -> XemLaiBaiThi {
        // Chưa đồng ý chia sẻ với AI ⇒ dừng TRƯỚC khi có byte nào rời máy.
        try await DongYChiaSeAI.batBuoc()
        do {
            return try await guiMotLan(duong, than: than)
        } catch APIError.unauthorized {
            // Token hết hạn. Lớp `APIClient` tự làm mới phiên khi một lời gọi
            // của nó gặp 401 — mượn một lời gọi GET rẻ để kích việc đó, rồi
            // gửi lại ĐÚNG MỘT lần (không vòng lặp: lần hai 401 là ném luôn).
            let _: [LuotDaLam]? = try? await APIClient.shared.request(.luotThiCuaToi)
            return try await guiMotLan(duong, than: than)
        }
    }

    private static func guiMotLan(_ duong: String, than: ThanNhieuPhan) async throws -> XemLaiBaiThi {
        guard let url = URL(string: APIClient.diaChiGoc + duong) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        // AI chấm mỗi câu một lượt — đề 8 câu có thể quá 60 giây mặc định.
        req.timeoutInterval = 240
        req.setValue(APIClient.nenTang, forHTTPHeaderField: "X-Client-Platform")
        req.setValue(than.kieuNoiDung, forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = StorageManager.shared.getAuthToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, resp) = try await URLSession.shared.upload(for: req, from: than.duLieu)
        guard let http = resp as? HTTPURLResponse else { throw APIError.unknown }
        if http.statusCode == 401 { throw APIError.unauthorized }
        let bao = try? JSONDecoder().decode(EmptyEnvelope.self, from: data)
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 413 { throw Loi.tepQuaLon(T("Tệp quá lớn — máy chủ từ chối.")) }
            if let m = bao?.message, !m.isEmpty { throw APIError.serverError(m) }
            throw APIError.serverError(String(format: T("Nộp bài thất bại (mã %d)."), http.statusCode))
        }
        do {
            let r = try JSONDecoder().decode(APIResponse<XemLaiBaiThi>.self, from: data)
            guard r.success, let x = r.data else {
                throw APIError.serverError(r.message ?? T("Máy chủ không trả về kết quả chấm."))
            }
            return x
        } catch let e as APIError {
            throw e
        } catch {
            APIClient.ghiLoiGiaiMa(error, duong: duong)
            throw APIError.decodingError(error)
        }
    }
}

// MARK: - Tệp mã nguồn theo ngôn ngữ

enum TepMaNguon {
    /// Đuôi tệp theo `ExamQuestion.language`. Bộ chấm (`extractCodeFromZip`)
    /// CHỈ đọc tệp có đuôi mã nguồn quen — `.txt` cũng được nhận, nên ngôn
    /// ngữ lạ rơi về `.txt` chứ không bị vứt.
    static func duoi(_ ngonNgu: String?) -> String {
        switch (ngonNgu ?? "").lowercased().trimmingCharacters(in: .whitespaces) {
        case "c": return "c"
        case "cpp", "c++": return "cpp"
        case "cs", "c#", "csharp": return "cs"
        case "java": return "java"
        case "python", "py": return "py"
        case "javascript", "js", "node": return "js"
        case "jsx", "react": return "jsx"
        case "typescript", "ts": return "ts"
        case "tsx": return "tsx"
        case "sql", "tsql", "mysql", "postgresql": return "sql"
        case "html": return "html"
        case "css": return "css"
        case "go": return "go"
        case "kotlin", "kt": return "kt"
        case "swift": return "swift"
        case "php": return "php"
        case "ruby", "rb": return "rb"
        case "rust", "rs": return "rs"
        case "dart": return "dart"
        default: return "txt"
        }
    }

    /// `Q1.c`, `Q2.c`… — trùng tên tệp trong bộ "Given" của đề PE.
    static func ten(thuTu: Int, ngonNgu: String?) -> String { "Q\(thuTu).\(duoi(ngonNgu))" }

    /// Gói các câu đã gõ thành một .zip. Câu bỏ trống thì không đưa vào.
    static func dongGoi(cau: [CauHoiThi], ma: [Int: String]) -> Data? {
        var tep: [ZipDon.Tep] = []
        for (i, c) in cau.enumerated() {
            let m = (ma[c.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !m.isEmpty else { continue }
            tep.append(.init(ten: ten(thuTu: i + 1, ngonNgu: c.language), duLieu: Data((ma[c.id] ?? "").utf8)))
        }
        return tep.isEmpty ? nil : ZipDon.dongGoi(tep)
    }
}

// MARK: - Địa chỉ tài nguyên của đề

enum DuongDanThi {
    /// Máy chủ trả KHOÁ/đường TƯƠNG ĐỐI (`/exam-assets/PRF192-given.zip`)
    /// hoặc URL đầy đủ. `blob:`/`data:` để nguyên — bẫy 02/07.
    static func day(_ s: String?) -> URL? {
        guard let s, !s.isEmpty else { return nil }
        if s.hasPrefix("http") || s.hasPrefix("data:") { return URL(string: s) }
        let duong = s.hasPrefix("/") ? s : "/" + s
        return URL(string: APIClient.diaChiGoc + duong)
    }
}

#if os(iOS)
// MARK: - Nén ảnh sơ đồ

enum NenAnhThi {
    /// Ảnh chụp 12MP ra 4–6MB; trần máy chủ 8MB/tệp, và model thị giác cũng
    /// chẳng cần hơn ~2400px cạnh dài để đọc một sơ đồ.
    static func jpeg(_ d: Data, canhToiDa: CGFloat = 2400, chatLuong: CGFloat = 0.8) -> Data? {
        guard let anh = UIImage(data: d) else { return nil }
        let to = max(anh.size.width, anh.size.height)
        var dich = anh
        if to > canhToiDa {
            let k = canhToiDa / to
            let co = CGSize(width: floor(anh.size.width * k), height: floor(anh.size.height * k))
            let ve = UIGraphicsImageRenderer(size: co)
            dich = ve.image { _ in anh.draw(in: CGRect(origin: .zero, size: co)) }
        }
        var q = chatLuong
        var ra = dich.jpegData(compressionQuality: q)
        while let r = ra, r.count > GuiBaiThi.tranAnh, q > 0.3 {
            q -= 0.15
            ra = dich.jpegData(compressionQuality: q)
        }
        return ra
    }
}
#endif
