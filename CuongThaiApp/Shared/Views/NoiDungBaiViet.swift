import SwiftUI
import UniformTypeIdentifiers

// ════════════════════════════════════════════════════════════════
// DỰNG NỘI DUNG BÀI VIẾT — bắt chước ĐÚNG luật của web
//
// Web (`frontend/src/components/social/CodeBlock.tsx`) quyết định kiểu trình
// bày bằng ba luật, chép nguyên sang đây để hai bên nhìn giống nhau:
//
//   • `looksStructured`: bài phải dài ≥400 ký tự VÀ có ≥1 đường kẻ ngăn phần
//     HOẶC ≥2 tiêu đề. Không có thì bài đăng thường "🎉 xong rồi" sẽ bị biến
//     thành tiêu đề to đùng.
//   • `headingOf`: dòng ĐỨNG RIÊNG (trên dưới đều trống), ≤80 ký tự, mở đầu
//     bằng emoji, và KHÔNG kết thúc bằng `.` `,` `;` — kết thúc bằng dấu ngắt
//     câu nghĩa là câu văn, không phải tiêu đề.
//   • Tiêu đề ĐẦU TIÊN là tiêu đề BÀI: to nhất, có nền và vạch màu bên trái.
//
// Trước đây app chỉ `Text(post.content)` — chữ trơn, khối mã hiện cả dấu ```,
// không tiêu đề, không phân đoạn.
// ════════════════════════════════════════════════════════════════

struct NoiDungBaiViet: View {
    let noiDung: String

    var body: some View {
        let khoi = BoTachBaiViet.tach(noiDung)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(khoi.enumerated()), id: \.offset) { _, k in
                switch k {
                case .tieuDeBai(let emoji, let chu):   tieuDeBai(emoji, chu)
                case .tieuDeMuc(let emoji, let chu):   tieuDeMuc(emoji, chu)
                case .duongKe:                          duongKe
                case .doan(let chu):                    doan(chu)
                case .khoiMa(let ma, let ngonNgu):      KhoiMaView(ma: ma, ngonNgu: ngonNgu)
                }
            }
        }
    }

    private func tieuDeBai(_ emoji: String, _ chu: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(emoji).font(.system(size: 20))
            Text(chu)
                .font(.system(size: 17, weight: .heavy))
                .foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [AppColors.primary.opacity(0.16),
                                              Color(hex: 0x06B6D4).opacity(0.10)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(AppColors.primary).frame(width: 3)
        }
        .padding(.bottom, 8)
    }

    private func tieuDeMuc(_ emoji: String, _ chu: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(emoji).font(.system(size: 15))
            Text(chu)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(AppColors.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    private var duongKe: some View {
        // Mờ dần hai đầu như web, thay vì một vạch cứng chạy hết bề ngang.
        LinearGradient(colors: [.clear, AppColors.border, .clear],
                       startPoint: .leading, endPoint: .trailing)
            .frame(height: 1)
            .padding(.vertical, 12)
    }

    private func doan(_ chu: String) -> some View {
        ChuCoMaTrongDong(chu: chu)
            .padding(.vertical, 2)
    }
}

// MARK: - Chữ có `mã` xen giữa

/// Dòng chữ thường, nhưng phần nằm giữa cặp dấu huyền `…` hiện dạng mã.
///
/// Dùng `AttributedString` chứ không ghép nhiều `Text`: ghép `Text` bằng `+`
/// thì xuống dòng tính sai và câu dài bị cắt cụt giữa chừng.
private struct ChuCoMaTrongDong: View {
    let chu: String

    var body: some View {
        Text(dung())
            .font(.system(size: 14.5))
            .foregroundColor(AppColors.textPrimary)
            .lineSpacing(4.5)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dung() -> AttributedString {
        var ra = AttributedString()
        // Tách theo cặp `…`: phần chỉ số LẺ chính là ruột của cặp.
        let manh = chu.components(separatedBy: "`")
        for (i, m) in manh.enumerated() {
            var a = AttributedString(m)
            if i % 2 == 1 && !m.contains("\n") {
                a.font = .system(size: 13.5, design: .monospaced)
                a.foregroundColor = AppColors.primary
                a.backgroundColor = AppColors.primary.opacity(0.10)
            }
            ra += a
        }
        return ra
    }
}

// MARK: - Khối mã

struct KhoiMaView: View {
    let ma: String
    let ngonNgu: String?
    @State private var daChep = false
    @State private var hienLuu = false

    /// Đuôi file suy từ tên ngôn ngữ model ghi sau ```.
    ///
    /// Chỉ những cái CHẮC CHẮN — tên lạ thì để `.txt`, vì đoán sai đuôi còn
    /// khó chịu hơn không đoán (macOS mở nhầm ứng dụng).
    private var duoi: String {
        switch (ngonNgu ?? "").lowercased() {
        case "swift": return "swift"
        case "python", "py": return "py"
        case "javascript", "js": return "js"
        case "typescript", "ts": return "ts"
        case "java": return "java"
        case "kotlin", "kt": return "kt"
        case "csharp", "cs", "c#": return "cs"
        case "c": return "c"
        case "cpp", "c++": return "cpp"
        case "go": return "go"
        case "rust", "rs": return "rs"
        case "php": return "php"
        case "ruby", "rb": return "rb"
        case "sql": return "sql"
        case "html": return "html"
        case "css": return "css"
        case "json": return "json"
        case "yaml", "yml": return "yml"
        case "sh", "bash", "shell", "zsh": return "sh"
        case "markdown", "md": return "md"
        default: return "txt"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text((ngonNgu?.isEmpty == false ? ngonNgu! : "code").uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
                Spacer()
                Button {
                    #if os(iOS)
                    UIPasteboard.general.string = ma
                    #endif
                    Haptics.cham()
                    daChep = true
                    Task { try? await Task.sleep(nanoseconds: 1_600_000_000); daChep = false }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: daChep ? "checkmark" : "doc.on.doc")
                        Text(daChep ? "Đã chép" : "Chép")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(daChep ? Color(hex: 0x34D399) : .white.opacity(0.7))
                }
                .buttonStyle(.plain)
                Button { hienLuu = true } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.doc")
                        Text("Lưu")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .padding(.leading, 10)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color(hex: 0x1E1E2E))
            .fileExporter(isPresented: $hienLuu,
                          document: TepVanBan(noiDung: ma),
                          contentType: .plainText,
                          defaultFilename: "doan-ma.\(duoi)") { _ in }

            // Cuộn NGANG: mã thường dài hơn bề ngang điện thoại, mà tự xuống
            // dòng thì thụt lề vỡ hết và mã hết đọc được.
            ScrollView(.horizontal, showsIndicators: false) {
                Text(ma)
                    .font(.system(size: 12.5, design: .monospaced))
                    .foregroundColor(Color(hex: 0xE4E4E7))
                    .textSelection(.enabled)
                    .padding(12)
            }
            .background(Color(hex: 0x18181B))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.vertical, 8)
    }
}

// MARK: - Bộ tách

enum KhoiBaiViet {
    case tieuDeBai(emoji: String, chu: String)
    case tieuDeMuc(emoji: String, chu: String)
    case duongKe
    case doan(String)
    case khoiMa(ma: String, ngonNgu: String?)
}

enum BoTachBaiViet {
    /// Đường kẻ ngăn phần — chép từ `HR_RE` của web: ký tự vẽ khung Unicode
    /// (U+2500…U+257F) từ 4 cái trở lên, hoặc `-`/`=`/`_` từ 5 cái.
    static let mauDuongKe = #"^\s*(?:[\u{2500}-\u{257F}]{4,}|-{5,}|={5,}|_{5,})\s*$"#
    static let daiToiDaTieuDe = 80

    static func tach(_ noiDung: String) -> [KhoiBaiViet] {
        var ra: [KhoiBaiViet] = []
        let coCauTruc = coCauTrucKhong(noiDung)
        var daLayTieuDe = !coCauTruc

        let dong = noiDung.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var dem: [String] = []
        var i = 0

        func xaDem() {
            let chu = dem.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            dem = []
            if !chu.isEmpty { ra.append(.doan(chu)) }
        }

        while i < dong.count {
            let d = dong[i]

            // Khối mã ``` — xử lý TRƯỚC mọi luật khác, vì bên trong khối mã có
            // thể có dòng trông y hệt đường kẻ hoặc tiêu đề.
            if d.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                xaDem()
                let ngonNgu = String(d.trimmingCharacters(in: .whitespaces).dropFirst(3))
                    .trimmingCharacters(in: .whitespaces)
                var than: [String] = []
                i += 1
                while i < dong.count, !dong[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    than.append(dong[i]); i += 1
                }
                if i < dong.count { i += 1 }
                ra.append(.khoiMa(ma: than.joined(separator: "\n"),
                                  ngonNgu: ngonNgu.isEmpty ? nil : ngonNgu))
                continue
            }

            if coCauTruc, d.range(of: mauDuongKe, options: .regularExpression) != nil {
                xaDem()
                ra.append(.duongKe)
                i += 1
                continue
            }

            if coCauTruc, let td = tieuDeTaiDong(dong, i) {
                xaDem()
                if !daLayTieuDe && ra.isEmpty {
                    daLayTieuDe = true
                    ra.append(.tieuDeBai(emoji: td.emoji, chu: td.chu))
                } else {
                    ra.append(.tieuDeMuc(emoji: td.emoji, chu: td.chu))
                }
                i += 1
                continue
            }

            dem.append(d)
            i += 1
        }
        xaDem()
        return ra
    }

    /// Bài có đáng trình bày theo cấu trúc không — luật của web.
    static func coCauTrucKhong(_ noiDung: String) -> Bool {
        guard noiDung.count >= 400 else { return false }
        let dong = noiDung.components(separatedBy: "\n")
        var ke = 0, tieuDe = 0
        for i in dong.indices {
            if dong[i].range(of: mauDuongKe, options: .regularExpression) != nil { ke += 1 }
            else if tieuDeTaiDong(dong, i) != nil { tieuDe += 1 }
        }
        return ke >= 1 || tieuDe >= 2
    }

    /// Dòng thứ `i` có phải tiêu đề không.
    ///
    /// Dấu hiệu QUYẾT ĐỊNH là đứng riêng — trên dưới đều là dòng trống. Không
    /// phải dấu câu: tiêu đề thật vẫn có thể kết thúc bằng dấu ("HELLO, JAVA!"),
    /// còn một câu văn mở đầu bằng emoji thì gần như luôn dính liền đoạn của nó.
    static func tieuDeTaiDong(_ dong: [String], _ i: Int) -> (emoji: String, chu: String)? {
        let t = dong[i].trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, t.count <= daiToiDaTieuDe else { return nil }
        if i > 0, !dong[i - 1].trimmingCharacters(in: .whitespaces).isEmpty { return nil }
        if i < dong.count - 1, !dong[i + 1].trimmingCharacters(in: .whitespaces).isEmpty { return nil }
        guard let (emoji, con) = emojiDauDong(t) else { return nil }
        // Kết thúc bằng dấu ngắt câu giữa chừng ⇒ là câu văn.
        if con.hasSuffix(".") || con.hasSuffix(",") || con.hasSuffix(";") { return nil }
        return (emoji, con)
    }

    /// Tách cụm emoji ở đầu dòng. Trả `nil` nếu dòng không mở đầu bằng emoji.
    static func emojiDauDong(_ dong: String) -> (String, String)? {
        var emoji = ""
        var con = Substring(dong)
        while let c = con.first {
            // `isEmoji` đúng cả với emoji ghép nhiều điểm mã (cờ, gia đình,
            // biến thể màu da) vì Swift đếm theo cụm ký tự người đọc thấy.
            if c.unicodeScalars.first?.properties.isEmojiPresentation == true
                || c.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation })
                || (c.unicodeScalars.first.map { (0x1F000...0x1FAFF).contains(Int($0.value)) } ?? false) {
                emoji.append(c); con = con.dropFirst()
            } else if c == " " && !emoji.isEmpty {
                con = con.dropFirst()
                break
            } else {
                break
            }
        }
        let chu = con.trimmingCharacters(in: .whitespaces)
        return (emoji.isEmpty || chu.isEmpty) ? nil : (emoji, chu)
    }
}

extension BoTachBaiViet {
    /// Lột dấu định dạng cho phần XEM TRƯỚC.
    ///
    /// Trong thẻ bảng tin ta hiện chữ trơn một dòng, mà `**đậm**` và `` `mã` ``
    /// để nguyên thì người đọc thấy đúng hai dấu sao — trông như bài đăng bị
    /// lỗi. Màn chi tiết thì KHÔNG lột: ở đó chúng được dựng thành định dạng
    /// thật.
    static func lotDauMarkdown(_ chu: String) -> String {
        var s = chu
        for mau in [#"\*\*(.+?)\*\*"#, #"__(.+?)__"#, #"~~(.+?)~~"#, "`([^`]+)`"] {
            s = s.replacingOccurrences(of: mau, with: "$1", options: .regularExpression)
        }
        // Link markdown: giữ chữ, bỏ địa chỉ.
        s = s.replacingOccurrences(of: #"\[([^\]]+)\]\([^)]+\)"#, with: "$1", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}


/// Bọc một chuỗi thành tài liệu để `fileExporter` ghi ra đĩa.
///
/// `.plainText` cho MỌI đuôi: khai `contentType` theo từng ngôn ngữ thì phải
/// dựng `UTType` riêng cho thứ hệ thống chưa biết, và nó lặng lẽ từ chối ghi.
/// Nội dung là chữ thuần, đuôi file mới là thứ quyết định app nào mở nó.
struct TepVanBan: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    let noiDung: String

    init(noiDung: String) { self.noiDung = noiDung }
    init(configuration: ReadConfiguration) throws {
        noiDung = configuration.file.regularFileContents
            .flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(noiDung.utf8))
    }
}
