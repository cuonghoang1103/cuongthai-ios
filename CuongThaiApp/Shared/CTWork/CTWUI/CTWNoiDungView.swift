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

    /// Khoảng giữa hai dòng trong một đoạn — câu trả lời AI dài đọc dễ hơn (21/10/2026).
    private var gianDong: CGFloat { max(2, coChu * 0.22) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(khoi.enumerated()), id: \.offset) { i, k in
                mot(k).padding(.top, i == 0 ? 0 : CTWKhoiView.khoangTruoc(k, sau: khoi[i - 1], coChu: coChu))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Khoảng trống TRƯỚC một khối, theo khối liền trên (21/10/2026 — câu trả lời CuongMini dài): mục danh sách liền nhau
    /// sát hơn (đọc thành MỘT danh sách), đoạn ↔ đoạn thoáng hơn, tiêu đề tách hẳn khỏi phần trên. Trước đây mọi khối cách
    /// đều 0,7× cỡ chữ nên danh sách rời rạc như các đoạn riêng mà tiêu đề lại dính phần trước.
    static func khoangTruoc(_ k: CTWKhoi, sau truoc: CTWKhoi, coChu: CGFloat) -> CGFloat {
        func laMuc(_ x: CTWKhoi) -> Bool {
            switch x { case .muc, .viec: return true; default: return false }
        }
        if case .tieuDe(_, let cap) = k { return coChu * (cap <= 2 ? 1.1 : 0.9) }
        if case .tieuDe = truoc { return coChu * 0.45 }
        if laMuc(k) && laMuc(truoc) { return coChu * 0.4 }
        return max(8, coChu * 0.75)
    }

    /// Kiểu chữ trong dòng: `mã` ⇒ chữ đơn cách trên nền nhạt (Text không có nền theo đoạn ⇒ dùng thuộc tính
    /// `backgroundColor` của AttributedString); link ⇒ màu nhấn. Chữ dài không có dấu cách (đường dẫn, mã) vẫn bọc dòng.
    private func kieu(_ a: AttributedString) -> AttributedString {
        var x = a
        for r in x.runs {
            if r.inlinePresentationIntent?.contains(.code) == true {
                x[r.range].font = .ctw(size: coChu - 1.5, design: .monospaced)
                x[r.range].backgroundColor = AppColors.backgroundTertiary
                x[r.range].foregroundColor = AppColors.textPrimary
            }
            if r.link != nil {
                x[r.range].foregroundColor = AppColors.primary
            }
        }
        return x
    }

    @ViewBuilder
    private func mot(_ k: CTWKhoi) -> some View {
        switch k {
        case .doan(let a):
            Text(kieu(a)).font(.ctw(size: coChu)).foregroundColor(AppColors.textPrimary)
                .lineSpacing(gianDong)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        case .tieuDe(let a, let cap):
            Text(kieu(a))
                .font(.ctw(size: cap <= 1 ? coChu + 6 : (cap == 2 ? coChu + 3.5 : coChu + 1.5), weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        case .muc(let a, let nhan, let cap):
            // Nhãn có cột cố định (số "10." không đẩy chữ lệch hàng) + thụt theo cấp; dòng thứ hai thẳng hàng với chữ.
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(nhan).font(.ctw(size: coChu, weight: nhan == "•" ? .bold : .semibold))
                    .foregroundColor(nhan == "•" ? AppColors.textTertiary : AppColors.textSecondary)
                    .monospacedDigit()
                    .frame(minWidth: nhan == "•" ? 12 : coChu * 1.3, alignment: .trailing)
                Text(kieu(a)).font(.ctw(size: coChu)).foregroundColor(AppColors.textPrimary)
                    .lineSpacing(gianDong)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .padding(.leading, CGFloat(cap) * 18)
        case .viec(let a, let xong, let cap):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: xong ? "checkmark.square.fill" : "square")
                    .foregroundColor(xong ? AppColors.success : AppColors.textTertiary)
                Text(kieu(a)).font(.ctw(size: coChu))
                    .foregroundColor(xong ? AppColors.textSecondary : AppColors.textPrimary)
                    .lineSpacing(gianDong)
                    .strikethrough(xong)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, CGFloat(cap) * 18)
            .accessibilityElement(children: .combine)
            .accessibilityValue(xong ? "Done" : "Not done")
        case .ma(let s):
            // ⚠️ `fixedSize(horizontal: true)` BẮT BUỘC — thiếu là dòng dài
            // bị cắt cụt trong khi trông như cuộn được (bẫy SwiftUI đã dính).
            ScrollView(.horizontal, showsIndicators: false) {
                Text(s).font(.ctw(size: coChu - 2, design: .monospaced))
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
            CTWBangView(hang: hang, coChu: coChu, kieu: kieu)
        }
    }

    static func dong(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(s)
    }
}

/// Bảng Markdown: cuộn NGANG trong khung riêng (bảng rộng không bị cắt, không đẩy cả trang rộng ra), hàng tiêu đề
/// có nền, hàng xen kẽ màu, ô chữ dài bọc dòng trong bề rộng giới hạn (thay vì kéo cột thành một dòng dài vô tận).
struct CTWBangView: View {
    let hang: [[String]]
    var coChu: CGFloat = 15
    var kieu: (AttributedString) -> AttributedString = { $0 }

    private var soCot: Int { hang.map(\.count).max() ?? 0 }

    /// Ô dài (> ~24 ký tự) ⇒ bề rộng cố định theo độ dài (90…240 pt) và bọc dòng; ô ngắn ⇒ một dòng.
    static func rongO(_ s: String, coChu: CGFloat) -> CGFloat? {
        let n = s.count
        guard n > 24 else { return nil }
        return min(240, max(90, CGFloat(n) * coChu * 0.42))
    }

    var body: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                ForEach(Array(hang.enumerated()), id: \.offset) { i, h in
                    GridRow {
                        ForEach(0..<soCot, id: \.self) { c in
                            o(c < h.count ? h[c] : "", hang: i)
                        }
                    }
                    if i == 0 { Divider().gridCellUnsizedAxes(.horizontal) }
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(AppColors.border))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .scrollIndicators(.visible)
        .frame(maxWidth: .infinity, alignment: .leading)
        #if DEBUG
        // Chụp màn "bảng đã cuộn": `CT_XEM_BANG_CUOI=1` mở bảng ở mép phải.
        .defaultScrollAnchor(ProcessInfo.processInfo.environment["CT_XEM_BANG_CUOI"] == "1" ? .trailing : .leading)
        #endif
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Table"))
    }

    @ViewBuilder
    private func o(_ s: String, hang i: Int) -> some View {
        let dau = i == 0
        let t = Text(kieu(CTWKhoiView.dong(s)))
            .font(.ctw(size: coChu - 1.5, weight: dau ? .semibold : .regular))
            .foregroundColor(AppColors.textPrimary)
            .lineSpacing(2)
        Group {
            if let w = Self.rongO(s, coChu: coChu) {
                t.fixedSize(horizontal: false, vertical: true).frame(width: w, alignment: .leading)
            } else {
                t.fixedSize(horizontal: true, vertical: false).frame(minWidth: 36, alignment: .leading)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Nền theo Ô (mọi ô cùng hàng cao bằng nhau nhờ maxHeight) — hàng tiêu đề đậm, hàng chẵn nhạt.
        .background(dau ? AppColors.backgroundTertiary : (i % 2 == 0 ? AppColors.backgroundTertiary.opacity(0.45) : Color.clear))
    }
}

/// Ảnh trong tài liệu/mô tả. Đường dẫn tương đối `/api/v1/work/.../images/:id`
/// là ảnh CẦN đăng nhập ⇒ gắn `Authorization` (chỉ khi cùng máy chủ của app).
struct CTWAnhCoXacThuc: View {
    let src: String
    var alt = ""

    /// Tải hỏng ⇒ nhãn "ảnh" thay vì vòng quay mãi (20/10/2026).
    @State private var hong = false

    /// Tuyệt đối / tương đối (`/api/v1/...`) / khoá R2 trần — một bộ giải chung (`DuongDanAnh`); SVG ⇒ nil.
    private var url: URL? { DuongDanAnh.urlAnh(src) }

    var body: some View {
        if let url, !hong {
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
                .onFailure { _ in hong = true }
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 420)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityLabel(alt.isEmpty ? String(localized: "Image") : alt)
            #else
            Label(alt.isEmpty ? String(localized: "Image") : alt, systemImage: "photo")
            #endif
        } else {
            Label(alt.isEmpty ? String(localized: "Image") : alt, systemImage: "photo").foregroundColor(AppColors.textSecondary)
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

        let cacDong = md.components(separatedBy: "\n")
        /// Dòng kẻ của bảng: `| --- | :---: |` hoặc `---|---` (chỉ `-`, `:`, `|`, dấu cách; có `-` và `|`).
        func laDongKe(_ x: String) -> Bool {
            let g = x.trimmingCharacters(in: .whitespaces)
            return g.contains("-") && g.contains("|") && g.allSatisfy { "-:| ".contains($0) }
        }
        var trongBang = false
        for (soDong, dongGoc) in cacDong.enumerated() {
            let dong = dongGoc.replacingOccurrences(of: "\r", with: "")
            let gon = dong.trimmingCharacters(in: .whitespaces)
            if var m = ma {
                if gon.hasPrefix("```") { out.append(.ma(m.joined(separator: "\n"))); ma = nil }
                else { m.append(dong); ma = m }
                continue
            }
            if gon.hasPrefix("```") { xaHet(); ma = []; continue }
            if gon.isEmpty { xaHet(); trongBang = false; continue }
            if gon.hasPrefix(">") {
                xaDoan(); xaBang()
                trich.append(String(gon.dropFirst()).trimmingCharacters(in: .whitespaces))
                continue
            }
            xaTrich()
            // Bảng: dòng bắt đầu bằng `|`, hoặc dòng có `|` mà dòng SAU là dòng kẻ (bảng không viền ngoài `a | b`).
            let batDauBang = !gon.hasPrefix("|") && gon.contains("|") && soDong + 1 < cacDong.count && laDongKe(cacDong[soDong + 1])
            if gon.hasPrefix("|") || batDauBang || (trongBang && gon.contains("|")) {
                xaDoan()
                trongBang = true
                let o = gon.trimmingCharacters(in: CharacterSet(charactersIn: "|"))
                    .components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                // Dòng kẻ `| --- | :---: |` bỏ qua.
                if o.allSatisfy({ !$0.isEmpty && $0.allSatisfy { "-: ".contains($0) } }) { continue }
                bang.append(o)
                continue
            }
            xaBang()
            trongBang = false
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
            // "1. " và "1) " (model hay viết kiểu sau khi trả lời tiếng Việt).
            if let cham = gon.firstIndex(where: { $0 == "." || $0 == ")" }), gon[..<cham].allSatisfy(\.isNumber), !gon[..<cham].isEmpty,
               gon.index(after: cham) < gon.endIndex, gon[gon.index(after: cham)] == " " {
                xaDoan()
                out.append(.muc(CTWKhoiView.dong(String(gon[gon.index(cham, offsetBy: 2)...])),
                                nhan: String(gon[..<cham]) + ".", cap: thut))
                continue
            }
            // Dòng thụt đầu nối tiếp mục danh sách ngay trên (mục nhiều dòng) ⇒ gộp vào mục đó, không thành đoạn rời.
            if thut > 0, doan.isEmpty, let cuoi = out.last {
                switch cuoi {
                case .muc(var a, let nhan, let cap):
                    a.append(AttributedString(" ")); a.append(CTWKhoiView.dong(gon))
                    out[out.count - 1] = .muc(a, nhan: nhan, cap: cap); continue
                case .viec(var a, let xong, let cap):
                    a.append(AttributedString(" ")); a.append(CTWKhoiView.dong(gon))
                    out[out.count - 1] = .viec(a, xong: xong, cap: cap); continue
                default: break
                }
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
            Image(systemName: "sparkles").font(.ctw(size: 9, weight: .bold))
            Text(chu).font(.ctw(size: 10, weight: .bold))
        }
        .foregroundColor(AppColors.primary)
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(Capsule().fill(AppColors.primary.opacity(0.12)))
        // Đọc ĐÚNG chữ đang hiện ("AI agent", "AI-generated", "AI-drafted"…) — trước đây luôn đọc "AI agent",
        // VoiceOver nói sai với nhãn bản nháp AI (và kiểm thử 4.7 không tìm thấy nhãn).
        .accessibilityLabel(chu)
    }
}
