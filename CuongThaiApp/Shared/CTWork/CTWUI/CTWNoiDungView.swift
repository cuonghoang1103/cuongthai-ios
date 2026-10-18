import SwiftUI
#if canImport(Kingfisher)
import Kingfisher
#endif

// MARK: - CT Work — dựng nội dung CHỈ ĐỌC
//
// Hai nguồn, hai bộ dựng, cùng một bộ khối hiển thị:
//   · TipTap JSON (mô tả thẻ, bình luận) → `CTWTipTapView`
//   · Markdown (tài liệu `/pages/:n/markdown`, tin chat) → `CTWMarkdownView`
// Không dùng WKWebView: chữ phải theo cỡ chữ hệ thống + chế độ tối, và một
// màn chi tiết thẻ không đáng một tiến trình web riêng.

// MARK: Khối hiển thị chung

enum CTWKhoi: Hashable {
    case doan(AttributedString)
    case tieuDe(AttributedString, Int)
    case muc(AttributedString, nhan: String, cap: Int)
    case viec(AttributedString, xong: Bool, cap: Int)
    case ma(String)
    case trichDan([CTWKhoi])
    case ke
    case anh(String, alt: String)
    case bang([[String]])
}

struct CTWKhoiView: View {
    let khoi: [CTWKhoi]
    var coChu: CGFloat = 15

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(khoi.enumerated()), id: \.offset) { _, k in mot(k) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func mot(_ k: CTWKhoi) -> some View {
        switch k {
        case .doan(let a):
            Text(a).font(.system(size: coChu)).foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        case .tieuDe(let a, let cap):
            Text(a)
                .font(.system(size: cap <= 1 ? coChu + 7 : (cap == 2 ? coChu + 4 : coChu + 2), weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, cap <= 2 ? 6 : 2)
                .accessibilityAddTraits(.isHeader)
        case .muc(let a, let nhan, let cap):
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(nhan).font(.system(size: coChu, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                    .frame(minWidth: 14, alignment: .trailing)
                Text(a).font(.system(size: coChu)).foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, CGFloat(cap) * 16)
        case .viec(let a, let xong, let cap):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: xong ? "checkmark.square.fill" : "square")
                    .foregroundColor(xong ? AppColors.success : AppColors.textTertiary)
                Text(a).font(.system(size: coChu))
                    .foregroundColor(xong ? AppColors.textSecondary : AppColors.textPrimary)
                    .strikethrough(xong)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, CGFloat(cap) * 16)
            .accessibilityElement(children: .combine)
            .accessibilityValue(xong ? "Done" : "Not done")
        case .ma(let s):
            // ⚠️ `fixedSize(horizontal: true)` BẮT BUỘC — thiếu là dòng dài
            // bị cắt cụt trong khi trông như cuộn được (bẫy SwiftUI đã dính).
            ScrollView(.horizontal, showsIndicators: false) {
                Text(s).font(.system(size: coChu - 2, design: .monospaced))
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: true, vertical: false)
                    .textSelection(.enabled)
                    .padding(12)
            }
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColors.backgroundTertiary))
        case .trichDan(let con):
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(AppColors.primary.opacity(0.5)).frame(width: 3)
                CTWKhoiView(khoi: con, coChu: coChu)
            }
            .fixedSize(horizontal: false, vertical: true)
        case .ke:
            Divider().padding(.vertical, 4)
        case .anh(let src, let alt):
            CTWAnhCoXacThuc(src: src, alt: alt)
        case .bang(let hang):
            ScrollView(.horizontal, showsIndicators: true) {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                    ForEach(Array(hang.enumerated()), id: \.offset) { i, h in
                        GridRow {
                            ForEach(Array(h.enumerated()), id: \.offset) { _, o in
                                Text(Self.dong(o))
                                    .font(.system(size: coChu - 1, weight: i == 0 ? .semibold : .regular))
                                    .foregroundColor(AppColors.textPrimary)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                        if i == 0 { Divider() }
                    }
                }
                .padding(12)
            }
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(AppColors.border))
        }
    }

    static func dong(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(s)
    }
}

/// Ảnh trong tài liệu/mô tả. Đường dẫn tương đối `/api/v1/work/.../images/:id`
/// là ảnh CẦN đăng nhập ⇒ gắn `Authorization` (chỉ khi cùng máy chủ của app).
struct CTWAnhCoXacThuc: View {
    let src: String
    var alt = ""

    private var url: URL? {
        if src.hasPrefix("http") { return URL(string: src) }
        if src.hasPrefix("/") { return URL(string: APIClient.diaChiGoc + src) }
        return nil
    }

    var body: some View {
        if let url {
            #if canImport(Kingfisher)
            KFImage(url)
                .requestModifier(AnyModifier { r in
                    var r = r
                    if r.url?.absoluteString.hasPrefix(APIClient.diaChiGoc) == true,
                       let t = StorageManager.shared.getAuthToken() {
                        r.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
                    }
                    return r
                })
                .placeholder { ProgressView().frame(maxWidth: .infinity, minHeight: 80) }
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 420)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityLabel(alt.isEmpty ? "Image" : alt)
            #else
            Label(alt.isEmpty ? "Image" : alt, systemImage: "photo")
            #endif
        } else {
            Label(alt.isEmpty ? "Image" : alt, systemImage: "photo").foregroundColor(AppColors.textSecondary)
        }
    }
}

// MARK: TipTap → khối

enum CTWTipTap {
    static func khoi(_ doc: CTWNode?) -> [CTWKhoi] {
        guard let doc else { return [] }
        var out: [CTWKhoi] = []
        di(doc.content ?? [], cap: 0, ra: &out)
        return out
    }

    private static func di(_ ds: [CTWNode], cap: Int, ra out: inout [CTWKhoi]) {
        for n in ds {
            switch n.type {
            case "paragraph":
                let a = dong(n)
                if !a.characters.isEmpty { out.append(.doan(a)) }
            case "heading":
                out.append(.tieuDe(dong(n), n.level ?? 2))
            case "bulletList", "orderedList", "taskList":
                for (i, muc) in (n.content ?? []).enumerated() {
                    let con = muc.content ?? []
                    let dau = con.first { $0.type == "paragraph" }
                    let a = dau.map(dong) ?? AttributedString("")
                    if n.type == "taskList" || muc.type == "taskItem" {
                        out.append(.viec(a, xong: muc.checked == true, cap: cap))
                    } else {
                        out.append(.muc(a, nhan: n.type == "orderedList" ? "\(i + 1)." : "•", cap: cap))
                    }
                    let conLai = con.filter { $0 != dau }
                    di(conLai, cap: cap + 1, ra: &out)
                }
            case "codeBlock":
                out.append(.ma(n.content?.compactMap(\.text).joined() ?? ""))
            case "blockquote":
                var con: [CTWKhoi] = []
                di(n.content ?? [], cap: 0, ra: &con)
                out.append(.trichDan(con))
            case "horizontalRule":
                out.append(.ke)
            case "image":
                if let s = n.src { out.append(.anh(s, alt: "")) }
            case "table":
                let hang = (n.content ?? []).map { r in (r.content ?? []).map { $0.chuTron } }
                if !hang.isEmpty { out.append(.bang(hang)) }
            default:
                if n.content != nil { di(n.content ?? [], cap: cap, ra: &out) }
                else if let t = n.text, !t.isEmpty { out.append(.doan(AttributedString(t))) }
            }
        }
    }

    /// Dòng chữ trong một khối: nối các nút text, giữ đậm/nghiêng/mã/link/@nhắc.
    static func dong(_ n: CTWNode) -> AttributedString {
        var a = AttributedString()
        func them(_ x: CTWNode) {
            if let t = x.text {
                var s = AttributedString(t)
                let m = Set(x.marks ?? [])
                if m.contains("bold") { s.inlinePresentationIntent = (s.inlinePresentationIntent ?? []).union(.stronglyEmphasized) }
                if m.contains("italic") { s.inlinePresentationIntent = (s.inlinePresentationIntent ?? []).union(.emphasized) }
                if m.contains("code") { s.inlinePresentationIntent = (s.inlinePresentationIntent ?? []).union(.code) }
                if m.contains("strike") { s.inlinePresentationIntent = (s.inlinePresentationIntent ?? []).union(.strikethrough) }
                if let h = x.href, let u = URL(string: h) { s.link = u }
                a += s
            } else if x.type == "mention" {
                var s = AttributedString("@" + (x.nhan ?? ""))
                s.foregroundColor = AppColors.primary
                a += s
            } else if x.type == "hardBreak" {
                a += AttributedString("\n")
            } else {
                x.content?.forEach(them)
            }
        }
        n.content?.forEach(them)
        return a
    }
}

struct CTWTipTapView: View {
    let doc: CTWNode?
    var coChu: CGFloat = 15
    var body: some View { CTWKhoiView(khoi: CTWTipTap.khoi(doc), coChu: coChu) }
}

// MARK: Markdown → khối

enum CTWMarkdown {
    static func khoi(_ md: String) -> [CTWKhoi] {
        var out: [CTWKhoi] = []
        var doan: [String] = []
        var trich: [String] = []
        var bang: [[String]] = []
        var ma: [String]? = nil

        func xaDoan() {
            if !doan.isEmpty { out.append(.doan(CTWKhoiView.dong(doan.joined(separator: "\n")))); doan = [] }
        }
        func xaTrich() {
            if !trich.isEmpty { out.append(.trichDan(khoi(trich.joined(separator: "\n")))); trich = [] }
        }
        func xaBang() {
            if !bang.isEmpty { out.append(.bang(bang)); bang = [] }
        }
        func xaHet() { xaDoan(); xaTrich(); xaBang() }

        for dongGoc in md.components(separatedBy: "\n") {
            let dong = dongGoc.replacingOccurrences(of: "\r", with: "")
            let gon = dong.trimmingCharacters(in: .whitespaces)
            if var m = ma {
                if gon.hasPrefix("```") { out.append(.ma(m.joined(separator: "\n"))); ma = nil }
                else { m.append(dong); ma = m }
                continue
            }
            if gon.hasPrefix("```") { xaHet(); ma = []; continue }
            if gon.isEmpty { xaHet(); continue }
            if gon.hasPrefix(">") {
                xaDoan(); xaBang()
                trich.append(String(gon.dropFirst()).trimmingCharacters(in: .whitespaces))
                continue
            }
            xaTrich()
            if gon.hasPrefix("|") {
                xaDoan()
                let o = gon.trimmingCharacters(in: CharacterSet(charactersIn: "|"))
                    .components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                // Dòng kẻ `| --- | :---: |` bỏ qua.
                if o.allSatisfy({ !$0.isEmpty && $0.allSatisfy { "-: ".contains($0) } }) { continue }
                bang.append(o)
                continue
            }
            xaBang()
            if gon == "---" || gon == "***" || gon == "___" { xaDoan(); out.append(.ke); continue }
            if let h = gon.firstIndex(where: { $0 != "#" }), gon.hasPrefix("#"),
               gon[h] == " ", gon.distance(from: gon.startIndex, to: h) <= 6 {
                xaDoan()
                let cap = gon.distance(from: gon.startIndex, to: h)
                out.append(.tieuDe(CTWKhoiView.dong(String(gon[h...]).trimmingCharacters(in: .whitespaces)), cap))
                continue
            }
            if gon.hasPrefix("!["), let a = gon.range(of: "]("), gon.hasSuffix(")") {
                xaDoan()
                let alt = String(gon[gon.index(gon.startIndex, offsetBy: 2)..<a.lowerBound])
                let src = String(gon[a.upperBound..<gon.index(before: gon.endIndex)])
                    .components(separatedBy: " ").first ?? ""
                out.append(.anh(src, alt: alt))
                continue
            }
            let thut = dong.prefix { $0 == " " }.count / 2
            if gon.hasPrefix("- [ ] ") || gon.hasPrefix("- [x] ") || gon.hasPrefix("- [X] ") {
                xaDoan()
                out.append(.viec(CTWKhoiView.dong(String(gon.dropFirst(6))), xong: !gon.hasPrefix("- [ ]"), cap: thut))
                continue
            }
            if gon.hasPrefix("- ") || gon.hasPrefix("* ") || gon.hasPrefix("+ ") {
                xaDoan()
                out.append(.muc(CTWKhoiView.dong(String(gon.dropFirst(2))), nhan: "•", cap: thut))
                continue
            }
            if let cham = gon.firstIndex(of: "."), gon[..<cham].allSatisfy(\.isNumber), !gon[..<cham].isEmpty,
               gon.index(after: cham) < gon.endIndex, gon[gon.index(after: cham)] == " " {
                xaDoan()
                out.append(.muc(CTWKhoiView.dong(String(gon[gon.index(cham, offsetBy: 2)...])),
                                nhan: String(gon[...cham]), cap: thut))
                continue
            }
            doan.append(gon)
        }
        if let m = ma { out.append(.ma(m.joined(separator: "\n"))) }
        xaHet()
        return out
    }
}

struct CTWMarkdownView: View {
    let markdown: String
    var coChu: CGFloat = 15
    var body: some View { CTWKhoiView(khoi: CTWMarkdown.khoi(markdown), coChu: coChu) }
}

// MARK: Nhãn AI agent (App Store 4.7 / 1.2)

/// Gắn cạnh tên MỌI nội dung do agent tạo — người dùng phải luôn biết đang
/// đọc chữ của máy.
struct CTWNhanAI: View {
    var chu = "AI agent"
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles").font(.system(size: 9, weight: .bold))
            Text(chu).font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(AppColors.primary)
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(Capsule().fill(AppColors.primary.opacity(0.12)))
        // Đọc ĐÚNG chữ đang hiện ("AI agent", "AI-generated", "AI-drafted"…) — trước đây luôn đọc "AI agent",
        // VoiceOver nói sai với nhãn bản nháp AI (và kiểm thử 4.7 không tìm thấy nhãn).
        .accessibilityLabel(chu)
    }
}
