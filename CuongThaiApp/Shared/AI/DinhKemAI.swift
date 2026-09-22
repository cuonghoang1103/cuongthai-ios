import SwiftUI
import UniformTypeIdentifiers
import PDFKit

/// Một thứ người dùng đính vào câu hỏi.
///
/// Backend nhận **data URL** (`data:<mime>;base64,<...>`) chứ không nhận byte
/// thô — xem `parseChatImages` / `parseChatDocuments` trong `ai.routes.ts`.
struct DinhKemAI: Identifiable, Equatable {
    let id = UUID()
    let ten: String
    let mime: String
    let duLieu: Data
    /// Dòng phụ hiện dưới tên: "42 trang · đã đọc chữ", "1,2 MB"…
    var moTa: String? = nil

    var laAnh: Bool { mime.hasPrefix("image/") }

    /// Chuỗi gửi lên. Cả ảnh lẫn tệp đều cùng một dạng.
    var dataURL: String { "data:\(mime);base64," + duLieu.base64EncodedString() }

    var bieuTuong: String { Self.bieuTuong(cho: ten) }

    /// Biểu tượng theo ĐUÔI TÊN, không theo mime: PDF đã rút chữ đi lên dưới
    /// dạng `text/plain` nhưng người dùng vẫn phải thấy đó là một tệp PDF.
    static func bieuTuong(cho ten: String) -> String {
        switch (ten as NSString).pathExtension.lowercased() {
        case "pdf":              return "doc.richtext"
        case "docx":             return "doc.text"
        case "csv":              return "tablecells"
        case "jpg", "jpeg", "png", "heic", "webp", "gif": return "photo"
        default:                 return "doc.plaintext"
        }
    }
}

enum HanMucDinhKem {
    /// Khớp `MAX_CHAT_IMAGES` / `MAX_CHAT_DOCS` / `MAX_DOC_BYTES` của backend.
    /// Chặn ở đây để người dùng biết NGAY, thay vì gửi đi rồi ăn 400.
    static let soAnh = 4
    static let soTep = 3
    static let byteMoiTep = 6 * 1024 * 1024

    /// Tổng thân gửi đi (đã base64) tối đa, chặn TRƯỚC khi gửi.
    ///
    /// Máy chủ cho người đã đăng nhập ~47MB (`CHAT_BODY_LIMIT_BYTES`, suy ra
    /// từ chính các hạn mức ở trên). Để hẳn 40MB cho có khoảng thở: câu hỏi,
    /// lịch sử và ảnh kèm lại từ lượt trước cũng nằm trong thân đó.
    static let tongGuiToiDa = 40 * 1024 * 1024

    /// PDF > 6MB không gửi nguyên được, nhưng vẫn ĐỌC trên máy (rút chữ hoặc
    /// chụp trang) — xem `NapTep`. Trần này chỉ để không nạp một tệp khổng lồ
    /// vào bộ nhớ điện thoại.
    static let bytePdfToiDa = 150 * 1024 * 1024

    /// Chữ rút từ MỘT PDF, tối đa. Máy chủ còn cắt theo ngân sách của cả lượt
    /// (`documentsAsText`), nên gửi quá mức này chỉ tốn đường truyền.
    static let kyTuPdfToiDa = 200_000

    /// Đúng `ALLOWED_DOC_TYPES`. `.doc` đời cũ KHÔNG có trong danh sách —
    /// backend trả lời hẳn một câu riêng bảo lưu lại thành .docx.
    static let loaiTep: [UTType] = [
        .pdf, .plainText, .commaSeparatedText,
        UTType(filenameExtension: "docx") ?? .data,
        UTType(filenameExtension: "md") ?? .plainText,
    ]

    /// Suy ra mime từ đuôi tệp.
    ///
    /// ⚠️ `UTType.preferredMIMEType` trả `nil` cho .docx và .md trên vài máy,
    /// mà gửi mime sai là backend từ chối thẳng. Nên tra tay trước.
    static func mime(cho url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf":  return "application/pdf"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "md", "markdown": return "text/markdown"
        case "csv":  return "text/csv"
        case "txt":  return "text/plain"
        default:
            return UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "text/plain"
        }
    }

    static func coChu(_ byte: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(byte), countStyle: .file)
    }
}

// MARK: - Nạp tệp

/// Đọc một tệp người dùng chọn từ Files thành thứ gửi được cho AI.
///
/// ⛔⛔ ĐỪNG "TỐI ƯU" BẰNG CÁCH RÚT CHỮ MỌI PDF TRÊN MÁY (đo thật 22/09/2026)
///
/// Nghe hợp lý — máy chủ cũng chỉ lấy chữ ra (`documentsAsText` →
/// `extractPdf`), rút sẵn trên máy thì gửi vài chục KB thay vì vài MB. Tôi đã
/// viết đúng như vậy, rồi SO với bộ rút của máy chủ trên cùng tệp:
///
///     SWR302.pdf (in từ trình duyệt)   máy chủ: 6 từ vỡ    PDFKit: 409 từ vỡ
///     MAS291.pdf                        máy chủ: 4          PDFKit: 450
///
/// PDFKit (`string` lẫn `selectionsByLine`) coi mỗi mẩu chữ là một dòng:
/// "Sof ⏎ tware Requ ⏎ iremen ⏎ t_Yê". Gửi thứ đó thì AI đọc sai hoặc đoán mò.
/// Bộ của máy chủ dựng lại dòng theo toạ độ nên đọc đúng.
///
/// Vậy chia theo ĐÚNG thứ đo được (`dòng trung vị` = độ dài dòng ở giữa):
///
///     sách JUnit 534 tr 15,9MB    dòng TV 48   → PDFKit đọc TỐT
///     sách SW Requirements 21MB   dòng TV 89   → TỐT
///     slide lab SWT301 9,7MB      dòng TV 38   → được
///     syllabus in từ trình duyệt  dòng TV  6   → VỠ
///     slide Canva 56MB            dòng TV  1   → vỡ, thực chất là ảnh
///
///  1. **Bản scan / chỉ có ảnh** (mọi cỡ) → chụp trang thành ẢNH. Máy chủ vốn
///     KHÔNG đọc được loại này — nó chỉ báo "không rút được chữ".
///  2. **≤ 6MB có chữ** → gửi NGUYÊN tệp, máy chủ rút (tốt hơn PDFKit).
///  3. **> 6MB, chữ PDFKit đọc tốt** (dòng TV ≥ 20) → rút chữ trên máy. Trước
///     đây mọi tệp > 6MB bị chặn thẳng — gần hết sách và slide bài giảng.
///  4. **> 6MB, chữ vỡ** → chụp các trang đầu thành ảnh.
///
/// .docx / .txt / .md / .csv vẫn gửi nguyên: iOS không có sẵn bộ đọc .docx,
/// còn nhóm văn bản thuần thì vốn đã là chữ.
///
/// Lỗi 413 ("Máy chủ trả lỗi 413") KHÔNG do chỗ này mà do trần thân JSON
/// 10MB ở máy chủ — đã vá bằng `CHAT_BODY_LIMIT_BYTES` trong `ai.routes.ts`.
enum NapTep {
    struct KetQua {
        var dinhKem: [DinhKemAI] = []
        /// Câu nói ra cho người dùng (PDF scan đã chụp trang, tệp bị bỏ…).
        var thongBao: [String] = []
    }

    /// - Parameter conChoAnh: số ảnh còn được thêm (tối đa 4 ảnh một lượt,
    ///   tính cả ảnh chụp trang của PDF scan).
    static func nap(_ url: URL, conChoAnh: Int) async -> KetQua {
        // Tệp ngoài hộp cát cần xin quyền rồi TRẢ LẠI, không thì lần chọn
        // sau bị từ chối im lặng.
        let mo = url.startAccessingSecurityScopedResource()
        defer { if mo { url.stopAccessingSecurityScopedResource() } }

        let ten = url.lastPathComponent
        if url.pathExtension.lowercased() == "pdf" {
            // PDFKit rút chữ một cuốn vài trăm trang mất cả giây — đừng làm
            // trên luồng giao diện.
            return await Task.detached(priority: .userInitiated) {
                docPdf(url, ten: ten, conChoAnh: conChoAnh)
            }.value
        }

        guard let d = try? Data(contentsOf: url) else {
            return KetQua(thongBao: ["Không đọc được “\(ten)”."])
        }
        guard d.count <= HanMucDinhKem.byteMoiTep else {
            return KetQua(thongBao: ["“\(ten)” nặng \(HanMucDinhKem.coChu(d.count)) — tệp loại này tối đa 6 MB."])
        }
        return KetQua(dinhKem: [DinhKemAI(ten: ten, mime: HanMucDinhKem.mime(cho: url),
                                          duLieu: d, moTa: HanMucDinhKem.coChu(d.count))])
    }

    private static func docPdf(_ url: URL, ten: String, conChoAnh: Int) -> KetQua {
        let byte = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard byte <= HanMucDinhKem.bytePdfToiDa else {
            return KetQua(thongBao: ["“\(ten)” nặng \(HanMucDinhKem.coChu(byte)) — quá lớn để đọc trên máy."])
        }
        guard let pdf = PDFDocument(url: url) else {
            return KetQua(thongBao: ["Không mở được “\(ten)”. Tệp có thể bị hỏng."])
        }
        if pdf.isLocked {
            return KetQua(thongBao: ["“\(ten)” có mật khẩu — hãy mở khoá rồi lưu lại bản không mật khẩu."])
        }
        let soTrang = pdf.pageCount

        // ── 1. Bản scan? Lấy MẪU vài trang rải đều, đừng đọc cả cuốn: sách 673
        //    trang mà gọi `pdf.string` là mất 2 giây chỉ để biết "có chữ". Rải
        //    đều vì trang bìa thường là ảnh trơn.
        let mau = Set((0..<min(8, soTrang)).map { $0 * soTrang / max(min(8, soTrang), 1) })
        let chuMau = mau.compactMap { pdf.page(at: $0)?.string }.joined()
        if demChu(chuMau) < 40 {
            return chupTrang(pdf, ten: ten, conChoAnh: conChoAnh,
                             lyDo: "là bản scan (không có chữ chọn được)")
        }

        // ── 2. Vừa sức máy chủ → gửi NGUYÊN, để bộ rút của máy chủ đọc.
        if byte <= HanMucDinhKem.byteMoiTep, let d = try? Data(contentsOf: url) {
            return KetQua(dinhKem: [DinhKemAI(ten: ten, mime: "application/pdf", duLieu: d,
                                              moTa: "\(soTrang) trang · \(HanMucDinhKem.coChu(byte))")])
        }

        // ── 3 · 4. Quá 6MB: rút chữ trên máy nếu PDFKit đọc tốt, không thì ảnh.
        let chu = (pdf.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard dongTrungVi(chu) >= 20 else {
            return chupTrang(pdf, ten: ten, conChoAnh: conChoAnh,
                             lyDo: "nặng \(HanMucDinhKem.coChu(byte)) và chữ trong tệp bị vỡ khi đọc trên máy")
        }
        let catBot = chu.count > HanMucDinhKem.kyTuPdfToiDa
        var than = "[Tệp PDF “\(ten)” — \(soTrang) trang. Chữ được rút ngay trên thiết bị; "
                 + "bảng và hình có thể mất bố cục.]\n\n"
                 + (catBot ? String(chu.prefix(HanMucDinhKem.kyTuPdfToiDa)) : chu)
        if catBot {
            than += "\n\n[…Phần sau bị CẮT vì tài liệu quá dài — hãy nói với người dùng rằng bạn chỉ đọc được phần đầu.]"
        }
        return KetQua(dinhKem: [DinhKemAI(ten: ten, mime: "text/plain", duLieu: Data(than.utf8),
                                          moTa: "\(soTrang) trang · đọc chữ trên máy")])
    }

    /// Đếm chữ THẬT, không đếm khoảng trắng: bản scan thường vẫn có vài dấu
    /// xuống dòng lạc trong lớp chữ rỗng.
    private static func demChu(_ s: String) -> Int {
        s.unicodeScalars.lazy.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }.count
    }

    /// Độ dài dòng ở giữa. Chữ thật ~40–90 ký tự một dòng; PDFKit đọc vỡ thì
    /// mỗi "dòng" chỉ còn vài ký tự ("Syllab", "us De", "tails").
    static func dongTrungVi(_ s: String) -> Int {
        let dai = s.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces).count }
            .filter { $0 > 0 }
            .sorted()
        return dai.isEmpty ? 0 : dai[dai.count / 2]
    }

    private static func chupTrang(_ pdf: PDFDocument, ten: String, conChoAnh: Int, lyDo: String) -> KetQua {
        let soTrang = pdf.pageCount
        guard conChoAnh > 0 else {
            return KetQua(thongBao: ["“\(ten)” \(lyDo) nên phải gửi dưới dạng ảnh, "
                                   + "nhưng đã đủ \(HanMucDinhKem.soAnh) ảnh. Bỏ bớt ảnh rồi thử lại."])
        }
        var anh: [DinhKemAI] = []
        for i in 0..<min(conChoAnh, soTrang) {
            guard let trang = pdf.page(at: i), let d = anhTrang(trang) else { continue }
            anh.append(DinhKemAI(ten: "\(ten) — tr.\(i + 1)", mime: "image/jpeg",
                                 duLieu: d, moTa: "trang \(i + 1)/\(soTrang)"))
        }
        guard !anh.isEmpty else {
            return KetQua(thongBao: ["Không đọc được chữ lẫn hình trong “\(ten)”."])
        }
        let phan = anh.count < soTrang ? "\(anh.count)/\(soTrang) trang đầu" : "cả \(soTrang) trang"
        return KetQua(dinhKem: anh,
                      thongBao: ["“\(ten)” \(lyDo) — đã chụp \(phan) thành ảnh để AI đọc."])
    }

    /// Vẽ một trang PDF thành JPEG cạnh dài 1600px — đúng ngưỡng của ảnh chụp
    /// (`jpegDataForUpload`), đủ nét để model đọc chữ in.
    private static func anhTrang(_ trang: PDFPage) -> Data? {
        let khung = trang.bounds(for: .mediaBox)
        guard khung.width > 0, khung.height > 0 else { return nil }
        let tiLe = 1600 / max(khung.width, khung.height)
        let co = CGSize(width: khung.width * tiLe, height: khung.height * tiLe)
        return trang.thumbnail(of: co, for: .mediaBox).jpegDataForUpload()
    }
}
