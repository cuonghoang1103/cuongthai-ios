import Foundation

// ════════════════════════════════════════════════════════════════
// KHO SÁCH TRÊN MÁY
//
// Tải MỘT LẦN rồi cắt theo chương, dựng từng chương. Lý do, đo thật
// 25/08/2026 trên tập 25 (Networking):
//
//   · Cả cuốn: 1.002 KB · 14.172 thẻ · 120 bảng · 3.620 ô · 133 khối lệnh.
//     Nạp nguyên cuốn giết tiến trình nội dung của `WKWebView` — và giết cả
//     `SFSafariViewController` ("Đã có sự cố xảy ra liên tục"), tức KHÔNG
//     phải lỗi của app mà là trang quá nặng cho WebKit trên điện thoại.
//   · Cắt theo chương: head 21 KB + một chương trung bình 40 KB = **61 KB**
//     mỗi lần dựng — nhẹ hơn **16 lần**.
//
// ⚠️ Máy chủ trả `cache-control: no-cache, no-store, must-revalidate` cho MỌI
// thứ (nginx dán đè, xem CLAUDE.md), nên không lưu ở đây thì mỗi lần mở sách
// là tải lại đủ 1 MB. Lưu vào `Caches` — hệ thống được phép dọn khi thiếu chỗ,
// đúng bản chất của thứ tải lại được.
//
// ⚠️ Cấu trúc sách: `section.chap-open` chỉ là ĐẦU chương (eyebrow, tựa, đoạn
// dẫn, mục tiêu). Nội dung nằm ở các `section.col` ANH EM phía sau, cho tới
// `chap-open` kế tiếp. Cắt theo "từ chap-open này tới chap-open sau", KHÔNG
// phải cắt theo thẻ đóng của chính nó.

struct SachDaCat {
    /// `<head>…</head>` — mang toàn bộ CSS 21 KB của sách.
    let dau: String
    /// Bìa + trang đầu + mục lục, tức mọi thứ trước chương đầu tiên.
    let mo: String
    /// Từng chương: số chương (`0`, `1`, …) và HTML của nó.
    let chuong: [(so: String, html: String)]
    /// Mục lục lấy từ chính khối `.toc-row` của sách.
    let mucLuc: [MucLucSach]
    /// Bản dịch: hash → HTML tiếng Việt.
    let dich: [String: String]
}

enum KhoSachCucBo {
    private static var thuMuc: URL? {
        guard let c = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        else { return nil }
        let d = c.appendingPathComponent("sach", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    /// Tải (hoặc lấy từ máy) rồi cắt sẵn. Ném lỗi nếu không có mạng mà cũng
    /// chưa có bản lưu.
    static func nap(_ s: Sach) async throws -> SachDaCat {
        let html = try await lay(ten: "\(s.slug).html", tu: s.duongSach)
        // Bản dịch KHÔNG bắt buộc: thiếu thì đọc tiếng Anh, đừng chặn cả cuốn.
        let jsonChu = try? await lay(ten: "\(s.slug).vi.json", tu: s.duongDich)
        return cat(html, dichJSON: jsonChu)
    }

    private static func lay(ten: String, tu: URL?) async throws -> String {
        let tep = thuMuc?.appendingPathComponent(ten)
        if let tep, let s = try? String(contentsOf: tep, encoding: .utf8), !s.isEmpty {
            return s
        }
        guard let tu else { throw URLError(.badURL) }
        let (d, resp) = try await URLSession.shared.data(from: tu)
        if let h = resp as? HTTPURLResponse, !(200...299).contains(h.statusCode) {
            throw URLError(.badServerResponse)
        }
        guard let s = String(data: d, encoding: .utf8) else { throw URLError(.cannotDecodeContentData) }
        if let tep { try? s.write(to: tep, atomically: true, encoding: .utf8) }
        return s
    }

    /// Xoá bản lưu của một cuốn — dùng khi web cập nhật nội dung.
    static func xoa(_ s: Sach) {
        for t in ["\(s.slug).html", "\(s.slug).vi.json"] {
            if let u = thuMuc?.appendingPathComponent(t) { try? FileManager.default.removeItem(at: u) }
        }
    }

    // MARK: Cắt

    static func cat(_ html: String, dichJSON: String?) -> SachDaCat {
        let dau = giua(html, "<head", "</head>").map { "<head\($0)</head>" } ?? ""
        let vtBody = html.range(of: "<body")
        let than = vtBody.map { String(html[$0.lowerBound...]) } ?? html

        // Vị trí mọi `<section class="chap-open"`.
        let moc = "<section class=\"chap-open\""
        var viTri: [String.Index] = []
        var tim = than.startIndex
        while let r = than.range(of: moc, range: tim..<than.endIndex) {
            viTri.append(r.lowerBound)
            tim = r.upperBound
        }

        let mo: String
        var chuong: [(so: String, html: String)] = []
        if let dauTien = viTri.first {
            mo = String(than[than.startIndex..<dauTien])
            for (i, a) in viTri.enumerated() {
                let b = i + 1 < viTri.count ? viTri[i + 1] : than.endIndex
                let doan = String(than[a..<b])
                chuong.append((so: soChuong(doan) ?? "\(i)", html: doan))
            }
        } else {
            mo = than
        }

        var dich: [String: String] = [:]
        if let j = dichJSON?.data(using: .utf8),
           let o = try? JSONSerialization.jsonObject(with: j) as? [String: Any],
           let ds = o["blocks"] as? [[String: Any]] {
            for b in ds {
                if let h = b["h"] as? String, let v = b["vi"] as? String { dich[h] = v }
            }
        }

        return SachDaCat(dau: dau, mo: mo, chuong: chuong,
                         mucLuc: docMucLuc(mo, chuong: chuong, dich: dich), dich: dich)
    }

    /// `id="ch12"` → `"12"`, `id="chA"` → `"A"`.
    ///
    /// ⚠️ CHỈ đọc trong THẺ MỞ. Thân chương có đầy `href="#ch3"` trỏ chéo nhau;
    /// dò `id="ch` trên cả đoạn thì chương phụ lục `chA` (không có số) rơi về
    /// chỉ số vòng lặp và trùng số với chương `ch1` thật.
    private static func soChuong(_ doan: String) -> String? {
        guard let het = doan.firstIndex(of: ">") else { return nil }
        let the = doan[doan.startIndex...het]
        guard let r = the.range(of: "id=\"ch") else { return nil }
        let so = the[r.upperBound...].prefix { $0 != "\"" }
        return so.isEmpty ? nil : String(so)
    }

    /// Mục lục từ `.toc-row`, kèm tựa tiếng Việt tra qua tiêu đề của CHÍNH
    /// chương đó (`h2`, hoặc `h1.chap-title`).
    ///
    /// ⚠️ Ghép theo SỐ CHƯƠNG, không theo vị trí: thứ tự hàng mục lục KHÔNG
    /// trùng thứ tự chương (tập 09 lệch 5/17).
    private static func docMucLuc(_ mo: String,
                                  chuong: [(so: String, html: String)],
                                  dich: [String: String]) -> [MucLucSach] {
        var viTheoSo: [String: String] = [:]
        for c in chuong {
            guard let td = giua(c.html, "<h2", "</h2>") ?? giua(c.html, "<h1 class=\"chap-title\"", "</h1>")
            else { continue }
            let chu = gonChu(boThe(td))
            if let v = dich[bamFNV(chu)] { viTheoSo[c.so] = gonChu(boThe(v)) }
        }

        var ra: [MucLucSach] = []
        var tim = mo.startIndex
        while let r = mo.range(of: "<div class=\"toc-row", range: tim..<mo.endIndex) {
            let het = mo.range(of: "</div>", range: r.upperBound..<mo.endIndex)?.upperBound ?? mo.endIndex
            // Một hàng có thể chứa nhiều </div>; lấy rộng tới hàng kế cho chắc.
            let ke = mo.range(of: "<div class=\"toc-row", range: r.upperBound..<mo.endIndex)?.lowerBound
            let doan = String(mo[r.lowerBound..<(ke ?? max(het, r.upperBound))])
            tim = r.upperBound
            guard let n = giua(doan, "<span class=\"toc-n\"", "</span>"),
                  let t = giua(doan, "<span class=\"toc-t\"", "</span>") else { continue }
            let so = gonChu(boThe(n))
            let tua = gonChu(boThe(boSmall(t)))
            guard !tua.isEmpty else { continue }
            ra.append(MucLucSach(id: so, tua: tua, tuaVi: viTheoSo[so]))
        }
        return ra
    }

    // MARK: Tiện ích chuỗi

    /// Lấy phần giữa `mo` và `dong`, TÍNH TỪ SAU dấu `>` đầu tiên của thẻ mở.
    private static func giua(_ s: String, _ mo: String, _ dong: String) -> String? {
        guard let a = s.range(of: mo),
              let dauNhon = s.range(of: ">", range: a.upperBound..<s.endIndex),
              let b = s.range(of: dong, range: dauNhon.upperBound..<s.endIndex)
        else { return nil }
        return String(s[dauNhon.upperBound..<b.lowerBound])
    }
    private static func boSmall(_ s: String) -> String {
        guard let a = s.range(of: "<small"), let b = s.range(of: "</small>") else { return s }
        return String(s[s.startIndex..<a.lowerBound]) + String(s[b.upperBound...])
    }
    private static func boThe(_ s: String) -> String {
        s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
    private static func gonChu(_ s: String) -> String {
        s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
         .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// FNV-1a 32-bit — PHẢI khớp `hashBlockText` của web, không thì không tra
    /// được đoạn nào.
    static func bamFNV(_ s: String) -> String {
        var h: UInt32 = 0x811c9dc5
        for u in s.unicodeScalars {
            // Web băm theo ĐƠN VỊ UTF-16 (`charCodeAt`). Ký tự ngoài BMP phải
            // tách thành cặp surrogate, không thì hash lệch ở đúng những đoạn
            // có emoji.
            for cu in String(u).utf16 {
                h ^= UInt32(cu)
                h = h &* 0x01000193
            }
        }
        return String(format: "%08x", h)
    }
}
