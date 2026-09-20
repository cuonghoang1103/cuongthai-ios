import SwiftUI

// ════════════════════════════════════════════════════════════════
// DỰNG MARKDOWN CHO CÂU TRẢ LỜI AI
//
// Vì sao KHÔNG dùng lại `NoiDungBaiViet`: bộ đó bắt chước luật trình bày của
// BÀI ĐĂNG trên web — tiêu đề phải mở đầu bằng emoji, và cả bài phải dài ≥400
// ký tự mới được coi là "có cấu trúc". Model thì trả về markdown chuẩn:
// `## Tiêu đề`, bảng `|…|`, `**đậm**`, danh sách `- `. Đưa markdown vào bộ kia
// thì mọi dấu cú pháp hiện nguyên xi ra màn hình — người dùng thấy đúng thế:
// "nhìn xấu và khó hiểu, không chuyên nghiệp".
//
// ⚠️ Bộ này chạy lại TỪ ĐẦU sau mỗi mẩu chữ của luồng SSE, nên nó phải:
//   • rẻ — chỉ quét dòng một lượt, không hồi quy
//   • chịu được markdown DỞ DANG: bảng mới có nửa hàng, ``` chưa đóng,
//     `**` mới mở. Vỡ ở đây là chữ nhảy loạn trong lúc model đang gõ.
// ════════════════════════════════════════════════════════════════

struct NoiDungMarkdown: View {
    let noiDung: String


    /// Bản CHỮ TRẦN của một câu trả lời AI — gỡ hết dấu cú pháp markdown.
    ///
    /// ⚠️ CHỈ dùng cho chỗ KHÔNG dựng được markdown: dòng xem trước một–hai
    /// dòng trên thẻ, nội dung thông báo đẩy, chuỗi đưa cho máy đọc to. Mọi
    /// chỗ hiện ĐẦY ĐỦ câu trả lời phải dùng `NoiDungMarkdown` để chữ đậm ra
    /// chữ đậm, chứ không phải xoá dấu đi cho xong.
    ///
    /// Vì sao có hàm này: model trả `**Shoppe 2**` và một `Text` trần hiện
    /// nguyên hai dấu sao giữa câu. Người dùng phải nhắc hai lần (19/09/2026)
    /// vì lần đầu tôi chỉ vá đúng một màn thay vì sửa ở chỗ dùng chung.
    static func chuTran(_ s: String) -> String {
        var r = ""
        var i = s.startIndex
        while i < s.endIndex {
            let c = s[i]
            if c == "*" || c == "_" || c == "`" {
                // Nuốt cả cụm dấu liền nhau (**, __, ```) trong một lượt.
                var j = i
                while j < s.endIndex, s[j] == c { j = s.index(after: j) }
                i = j
                continue
            }
            // `## Tiêu đề` và `- mục` ở ĐẦU DÒNG là dấu cú pháp; giữa dòng thì
            // không (một phép trừ "5 - 3" không phải gạch đầu dòng).
            if (c == "#" || c == ">" ) && (r.isEmpty || r.hasSuffix("\n")) {
                var j = i
                while j < s.endIndex, s[j] == c || s[j] == " " { j = s.index(after: j) }
                i = j
                continue
            }
            r.append(c)
            i = s.index(after: i)
        }
        return r.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(KhoiMD.tach(noiDung).enumerated()), id: \.offset) { _, k in
                switch k {
                case .tieuDe(let bac, let chu):      tieuDe(bac, chu)
                case .doan(let chu):                 doan(chu)
                case .gach(let dau, let chu):        gach(dau, chu)
                case .trichDan(let chu):             trichDan(chu)
                case .duongKe:                       Divider().background(AppColors.divider)
                case .bang(let dau, let hang):       BangMD(dau: dau, hang: hang)
                case .khoiMa(let ma, let ngonNgu):
                // Khối ```mermaid dựng thành SƠ ĐỒ, không phải một đống chữ.
                // Đặt ở đây (chỗ dùng chung) chứ không ở từng màn: mọi câu
                // trả lời AI trong app đều đi qua bộ dựng này.
                if (ngonNgu ?? "").lowercased() == "mermaid" {
                    SoDoTuMarkdown(ma: ma)
                } else {
                    KhoiMaView(ma: ma, ngonNgu: ngonNgu)
                }
                }
            }
        }
    }

    // ── Tiêu đề: ba bậc, cỡ giảm dần ──
    private func tieuDe(_ bac: Int, _ chu: String) -> some View {
        Text(inline(chu))
            .font(.system(size: bac == 1 ? 21 : bac == 2 ? 18.5 : 16.5, weight: .bold))
            .foregroundColor(AppColors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, bac == 1 ? 6 : 4)
    }

    private func doan(_ chu: String) -> some View {
        Text(inline(chu))
            .font(.system(size: 15.5))
            .foregroundColor(AppColors.textPrimary)
            .lineSpacing(3.5)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Một mục danh sách. Dấu đầu dòng nằm CỘT RIÊNG để dòng thứ hai của mục
    /// thụt vào thẳng hàng với chữ, thay vì trôi về sát lề.
    private func gach(_ dau: String, _ chu: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(dau)
                .font(.system(size: 15, weight: dau.hasSuffix(".") ? .semibold : .regular))
                .foregroundColor(AppColors.primary)
                .frame(minWidth: 16, alignment: .trailing)
            Text(inline(chu))
                .font(.system(size: 15.5))
                .foregroundColor(AppColors.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 2)
    }

    private func trichDan(_ chu: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(AppColors.primary.opacity(0.55)).frame(width: 3)
            Text(inline(chu))
                .font(.system(size: 15))
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// `**đậm**`, `*nghiêng*`, `` `mã` ``, `[chữ](đường dẫn)`.
    ///
    /// `.inlineOnlyPreservingWhitespace` là lựa chọn có chủ ý: dạng đầy đủ sẽ
    /// tự nuốt xuống dòng và gộp mọi thứ thành một khối, còn ở đây việc cắt
    /// khối đã do `KhoiMD.tach` lo rồi.
    private func inline(_ s: String) -> AttributedString {
        chuInline(s)
    }
}

// ── Bảng ────────────────────────────────────────────────────────

/// Bảng markdown. Cuộn NGANG trong khung riêng — bảng so sánh của model
/// thường 3-4 cột, ép vừa bề ngang điện thoại là chữ vỡ vụn từng ký tự.
private struct BangMD: View {
    let dau: [String]
    let hang: [[String]]

    private var rong: [CGFloat] {
        // Cột rộng theo ô DÀI NHẤT của chính nó, chặn hai đầu để một ô dài
        // bất thường không đẩy các cột khác biến mất.
        (0..<dau.count).map { c in
            // Đo theo DÒNG dài nhất: một ô có "<br>" giờ xuống dòng thật, lấy
            // tổng số ký tự thì cột rộng gấp đôi mức cần.
            let dai = ([dau[c]] + hang.map { c < $0.count ? $0[c] : "" })
                .flatMap { $0.boXuongDongHTML.split(separator: "\n", omittingEmptySubsequences: false) }
                .map(\.count).max() ?? 8
            return min(max(CGFloat(dai) * 7.6 + 22, 86), 240)
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(Array(dau.enumerated()), id: \.offset) { i, o in
                        o0(o, rong: rong[i], dam: true)
                    }
                }
                .background(AppColors.primary.opacity(0.10))
                ForEach(Array(hang.enumerated()), id: \.offset) { r, h in
                    HStack(spacing: 0) {
                        ForEach(Array(dau.indices).map { $0 }, id: \.self) { i in
                            o0(i < h.count ? h[i] : "", rong: rong[i], dam: false)
                        }
                    }
                    .background(r % 2 == 1 ? AppColors.backgroundTertiary.opacity(0.5) : Color.clear)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.divider, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.vertical, 2)
        }
    }

    private func o0(_ chu: String, rong: CGFloat, dam: Bool) -> some View {
        Text(chuInline(chu))
            .font(.system(size: 13.5, weight: dam ? .semibold : .regular))
            .foregroundColor(dam ? AppColors.textPrimary : AppColors.textSecondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: rong, alignment: .leading)
            .padding(.horizontal, 9).padding(.vertical, 7)
            .overlay(Rectangle().frame(width: 1).foregroundColor(AppColors.divider), alignment: .trailing)
    }
}

// ── Bộ tách khối ────────────────────────────────────────────────

enum KhoiMD {
    case tieuDe(bac: Int, chu: String)
    case doan(String)
    case gach(dau: String, chu: String)
    case trichDan(String)
    case duongKe
    case bang(dau: [String], hang: [[String]])
    case khoiMa(ma: String, ngonNgu: String?)

    static func tach(_ vao: String) -> [KhoiMD] {
        var ra: [KhoiMD] = []
        let dong = vao.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var dem: [String] = []
        var i = 0

        func xa() {
            let c = dem.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            dem = []
            if !c.isEmpty { ra.append(.doan(c)) }
        }

        while i < dong.count {
            let d = dong[i]
            let t = d.trimmingCharacters(in: .whitespaces)

            // Khối mã trước tiên: bên trong nó mọi luật khác đều không áp dụng.
            if t.hasPrefix("```") {
                xa()
                let ng = String(t.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var than: [String] = []
                i += 1
                while i < dong.count, !dong[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    than.append(dong[i]); i += 1
                }
                if i < dong.count { i += 1 }   // nuốt ``` đóng; thiếu cũng không sao
                ra.append(.khoiMa(ma: than.joined(separator: "\n"), ngonNgu: ng.isEmpty ? nil : ng))
                continue
            }

            // Bảng: hàng `|…|` + hàng ngăn `|---|`. Thiếu hàng ngăn thì đó chỉ
            // là câu văn có dấu gạch đứng, không phải bảng.
            if t.hasPrefix("|"), i + 1 < dong.count, laHangNgan(dong[i + 1]) {
                xa()
                let dau = oCua(t)
                var hang: [[String]] = []
                i += 2
                while i < dong.count, dong[i].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                    hang.append(oCua(dong[i].trimmingCharacters(in: .whitespaces)))
                    i += 1
                }
                ra.append(.bang(dau: dau, hang: hang))
                continue
            }

            if t.hasPrefix("#") {
                let bac = t.prefix(6).prefix(while: { $0 == "#" }).count
                let chu = String(t.dropFirst(bac)).trimmingCharacters(in: .whitespaces)
                if !chu.isEmpty {
                    xa()
                    ra.append(.tieuDe(bac: min(bac, 3), chu: chu))
                    i += 1
                    continue
                }
            }

            if t == "---" || t == "***" || t == "___" {
                xa(); ra.append(.duongKe); i += 1; continue
            }

            if t.hasPrefix("> ") {
                xa()
                ra.append(.trichDan(String(t.dropFirst(2))))
                i += 1
                continue
            }

            // Danh sách: `- `, `* `, hoặc `1. `
            if let m = mucDanhSach(t) {
                xa()
                ra.append(.gach(dau: m.dau, chu: m.chu))
                i += 1
                continue
            }

            dem.append(d)
            i += 1
        }
        xa()
        return ra
    }

    /// `|---|:---:|` — hàng ngăn giữa đầu bảng và thân.
    private static func laHangNgan(_ d: String) -> Bool {
        let t = d.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix("|") else { return false }
        let ruot = t.trimmingCharacters(in: CharacterSet(charactersIn: "|"))
        guard !ruot.isEmpty else { return false }
        return ruot.allSatisfy { "-: |".contains($0) } && ruot.contains("-")
    }

    private static func oCua(_ d: String) -> [String] {
        var t = d
        if t.hasPrefix("|") { t.removeFirst() }
        if t.hasSuffix("|") { t.removeLast() }
        return t.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func mucDanhSach(_ t: String) -> (dau: String, chu: String)? {
        for d in ["- ", "* ", "• "] where t.hasPrefix(d) {
            return ("•", String(t.dropFirst(2)))
        }
        // `12. nội dung` — số rồi chấm rồi khoảng trắng.
        let so = t.prefix(while: \.isNumber)
        if !so.isEmpty, so.count <= 2 {
            let con = t.dropFirst(so.count)
            if con.hasPrefix(". ") {
                return (so + ".", String(con.dropFirst(2)))
            }
        }
        return nil
    }
}


// ── Chữ trong dòng ──────────────────────────────────────────────

/// Dựng markdown trong-dòng, sau khi đã dọn HTML mà model chèn vào.
private func chuInline(_ s: String) -> AttributedString {
    let c = s.boXuongDongHTML
    return (try? AttributedString(
        markdown: c,
        options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    )) ?? AttributedString(c)
}

extension String {
    /// Đổi `<br>` / `<br/>` / `<br />` thành xuống dòng thật.
    ///
    /// Vì sao cần: markdown KHÔNG có cách xuống dòng trong một ô bảng, nên
    /// model dùng `<br>` — đó là cách viết đúng của nó, không phải lỗi model.
    /// Bộ dựng của ta không đọc HTML nên nó in nguyên chữ "<br>" ra màn hình:
    /// người dùng thấy `3. Tính từ い/な<br>4. Mời rủ & đếm`.
    ///
    /// ⚠️ KHÔNG đụng phần trong dấu nháy ngược — bài học về HTML có quyền
    /// nhắc tới `<br>` như một ví dụ, và đổi nó đi là làm sai nội dung bài.
    var boXuongDongHTML: String {
        guard range(of: "<br", options: .caseInsensitive) != nil,
              let re = try? NSRegularExpression(pattern: "<br\\s*/?>", options: [.caseInsensitive])
        else { return self }
        return split(separator: "`", omittingEmptySubsequences: false)
            .enumerated()
            .map { i, phan -> String in
                guard i % 2 == 0 else { return String(phan) }
                let t = String(phan)
                return re.stringByReplacingMatches(
                    in: t, range: NSRange(t.startIndex..., in: t), withTemplate: "\n")
            }
            .joined(separator: "`")
    }
}

#if os(iOS)
/// Bọc `SoDoMermaidView` cho dùng được trong `NoiDungMarkdown`.
///
/// Hỏng thì LÙI về khối mã chứ không hiện khung trắng: sơ đồ sai cú pháp là
/// chuyện model hay làm, và một khung trắng không nói cho người học biết
/// rằng vẫn còn nội dung đọc được.
private struct SoDoTuMarkdown: View {
    let ma: String
    @State private var cao: CGFloat = 180
    @State private var hong = false

    var body: some View {
        if hong {
            KhoiMaView(ma: ma, ngonNgu: "mermaid")
        } else {
            SoDoMermaidView(ma: ma, chieuCao: $cao, hong: $hong)
                .frame(height: cao)
                .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(AppColors.backgroundCard))
        }
    }
}
#endif
