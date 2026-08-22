import SwiftUI

// MARK: - Tô màu mã nguồn
//
// Người dùng nói thẳng 23/08/2026: "code mẫu ở trong bài tập, đề bài, bài học
// chưa có màu như VSCode rất khó nhìn".
//
// Làm THUẦN SWIFT chứ không nhúng highlight.js vào WKWebView, vì mã xuất hiện
// ở rất nhiều chỗ (ví dụ của bài tập, lời giải, khối mã trong bài học, mẩu mã)
// — mỗi khối một WebView thì vừa chậm vừa tốn bộ nhớ, lại phải chờ mạng. Bản
// này chạy trên chuỗi, không cần mạng, và trả về `AttributedString` để `Text`
// dựng thẳng.
//
// Bảng màu lấy theo **VS Code Dark+ / Light+** cho quen mắt người học.

enum ToMauMa {

    // MARK: Bảng màu

    private struct Bang {
        let thuong, chuThich, chuoi, so, tuKhoa, kieu, ham: Color
    }

    private static func bang(_ toi: Bool) -> Bang {
        toi
        ? Bang(thuong: Color(hex: 0xD4D4D4), chuThich: Color(hex: 0x6A9955),
               chuoi: Color(hex: 0xCE9178), so: Color(hex: 0xB5CEA8),
               tuKhoa: Color(hex: 0x569CD6), kieu: Color(hex: 0x4EC9B0),
               ham: Color(hex: 0xDCDCAA))
        : Bang(thuong: Color(hex: 0x1F1F1F), chuThich: Color(hex: 0x008000),
               chuoi: Color(hex: 0xA31515), so: Color(hex: 0x098658),
               tuKhoa: Color(hex: 0x0000FF), kieu: Color(hex: 0x267F99),
               ham: Color(hex: 0x795E26))
    }

    // MARK: Từ khoá theo họ ngôn ngữ

    private static let chung: Set<String> = [
        "if","else","for","while","do","return","break","continue","switch","case","default",
        "new","this","null","true","false","try","catch","finally","throw","throws","import",
        "from","export","class","extends","implements","interface","enum","struct","function",
        "func","def","var","let","const","static","public","private","protected","void","in",
        "of","as","is","not","and","or","await","async","yield","with","lambda","pass","elif",
        "end","then","begin","use","require","package","module","namespace","typedef","sizeof",
        "goto","match","when","where","select","type","fn","impl","trait","mut","pub","defer",
    ]
    private static let sql: Set<String> = [
        "select","from","where","insert","into","values","update","set","delete","create","table",
        "alter","drop","index","view","join","inner","left","right","full","outer","on","group",
        "by","order","having","limit","offset","distinct","as","and","or","not","null","is",
        "primary","key","foreign","references","constraint","unique","check","default","cascade",
        "union","all","exists","between","like","ilike","in","case","when","then","else","end",
        "with","returning","conflict","do","nothing","begin","commit","rollback","transaction",
        "asc","desc","count","sum","avg","min","max","coalesce","cast","text","integer","boolean",
        "serial","varchar","timestamp","date","numeric","jsonb","grant","schema","database",
    ]
    private static let kieuChung: Set<String> = [
        "String","Int","Double","Bool","Array","Dictionary","Set","Optional","Any","Void",
        "int","long","short","char","float","double","bool","boolean","string","object",
        "number","str","list","dict","tuple","byte","unsigned","signed","const","auto",
        "List","Map","Set","Object","Number","Boolean","Promise","Error","Date","JSON",
    ]

    private static func tuKhoa(_ ngonNgu: String?) -> Set<String> {
        let l = (ngonNgu ?? "").lowercased()
        if l.contains("sql") { return sql }
        return chung
    }

    /// Ngôn ngữ nào dùng `#` mở đầu chú thích một dòng.
    private static func chuThichThang(_ l: String) -> Bool {
        ["python","py","bash","sh","shell","zsh","ruby","rb","yaml","yml","toml","r","perl"]
            .contains(l)
    }

    // MARK: Cắt token

    /// Trả về `AttributedString` đã tô màu.
    ///
    /// ⚠️ Duyệt trên `Array<Character>` chứ không trên `String.Index`: chuỗi mã
    /// vài nghìn ký tự mà nhảy chỉ số kiểu `String` thì mỗi bước phải giải mã
    /// lại từ đầu cụm, chậm thấy rõ khi cuộn.
    static func to(_ ma: String, ngonNgu: String?, toi: Bool) -> AttributedString {
        let b = bang(toi)
        let l = (ngonNgu ?? "").lowercased()
        let tk = tuKhoa(l)
        let dungThang = chuThichThang(l)
        let dungGachDoi = l.contains("sql")

        var ra = AttributedString()
        let c = Array(ma)
        var i = 0
        var dem = ""

        func xa() {
            guard !dem.isEmpty else { return }
            var s = AttributedString(dem)
            s.foregroundColor = b.thuong
            ra += s
            dem = ""
        }
        func them(_ chu: String, _ mau: Color) {
            xa()
            var s = AttributedString(chu)
            s.foregroundColor = mau
            ra += s
        }

        while i < c.count {
            let ch = c[i]

            // ── chú thích ──
            if ch == "/" && i + 1 < c.count && c[i + 1] == "/" {
                var j = i
                while j < c.count && c[j] != "\n" { j += 1 }
                them(String(c[i..<j]), b.chuThich); i = j; continue
            }
            if ch == "/" && i + 1 < c.count && c[i + 1] == "*" {
                var j = i + 2
                while j + 1 < c.count && !(c[j] == "*" && c[j + 1] == "/") { j += 1 }
                j = min(j + 2, c.count)
                them(String(c[i..<j]), b.chuThich); i = j; continue
            }
            if dungThang && ch == "#" {
                var j = i
                while j < c.count && c[j] != "\n" { j += 1 }
                them(String(c[i..<j]), b.chuThich); i = j; continue
            }
            if dungGachDoi && ch == "-" && i + 1 < c.count && c[i + 1] == "-" {
                var j = i
                while j < c.count && c[j] != "\n" { j += 1 }
                them(String(c[i..<j]), b.chuThich); i = j; continue
            }

            // ── chuỗi ──
            if ch == "\"" || ch == "'" || ch == "`" {
                let mo = ch
                var j = i + 1
                while j < c.count {
                    if c[j] == "\\" { j += 2; continue }
                    if c[j] == mo { j += 1; break }
                    // Chuỗi không đóng trước khi hết dòng thì dừng ở đó, không
                    // thì một dấu nháy lẻ nhuộm đỏ cả phần mã còn lại.
                    if c[j] == "\n" && mo != "`" { break }
                    j += 1
                }
                them(String(c[i..<min(j, c.count)]), b.chuoi); i = min(j, c.count); continue
            }

            // ── số ──
            if ch.isNumber && (i == 0 || !(c[i - 1].isLetter || c[i - 1] == "_")) {
                var j = i
                while j < c.count && (c[j].isNumber || c[j] == "." || c[j] == "x"
                                      || (c[j].isHexDigit && j > i && c[i + 1 <= j ? i + 1 : i] == "x")) { j += 1 }
                them(String(c[i..<j]), b.so); i = j; continue
            }

            // ── định danh ──
            if ch.isLetter || ch == "_" || ch == "@" || ch == "$" {
                var j = i
                while j < c.count && (c[j].isLetter || c[j].isNumber || c[j] == "_"
                                      || c[j] == "@" || c[j] == "$") { j += 1 }
                let tu = String(c[i..<j])
                var k = j
                while k < c.count && c[k] == " " { k += 1 }
                let laHam = k < c.count && c[k] == "("

                if tk.contains(tu.lowercased()) || tk.contains(tu) {
                    them(tu, b.tuKhoa)
                } else if kieuChung.contains(tu) {
                    them(tu, b.kieu)
                } else if let f = tu.first, f.isUppercase, tu.count > 1 {
                    // Tên bắt đầu bằng chữ HOA coi là kiểu — quy ước đúng với
                    // Java/C#/Swift/TS, và với SQL thì từ khoá đã bắt ở trên.
                    them(tu, b.kieu)
                } else if laHam {
                    them(tu, b.ham)
                } else {
                    dem += tu
                }
                i = j; continue
            }

            dem.append(ch); i += 1
        }
        xa()
        return ra
    }
}

// MARK: - Khối mã dùng chung

/// Khối mã có tô màu, cuộn ngang, kèm nút chép.
///
/// Cuộn NGANG chứ không bẻ dòng: bẻ giữa chừng làm sai thụt lề, mà thụt lề là
/// thứ duy nhất nói lên cấu trúc trong Python hay YAML.
struct KhoiMaNguon: View {
    let ma: String
    var ngonNgu: String?
    var tieuDe: String?
    var choChep = true

    @Environment(\.colorScheme) private var che
    @State private var daChep = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if (tieuDe?.isEmpty == false) || choChep {
                HStack(spacing: Spacing.sm) {
                    if let t = tieuDe, !t.isEmpty {
                        Text(t)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                    }
                    if let n = ngonNgu, !n.isEmpty {
                        Text(n)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(AppColors.textTertiary)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().fill(AppColors.backgroundTertiary))
                    }
                    Spacer(minLength: 0)
                    if choChep {
                        Button {
                            #if os(iOS)
                            UIPasteboard.general.string = ma
                            #endif
                            withAnimation { daChep = true }
                            Task {
                                try? await Task.sleep(nanoseconds: 1_500_000_000)
                                await MainActor.run { daChep = false }
                            }
                        } label: {
                            Image(systemName: daChep ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 12))
                                .foregroundColor(daChep ? AppColors.success : AppColors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.sm + 2)
                .padding(.vertical, 6)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(ToMauMa.to(ma, ngonNgu: ngonNgu, toi: che == .dark))
                    .font(.system(size: 12.5, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(.horizontal, Spacing.sm + 2)
                    .padding(.bottom, Spacing.sm + 2)
                    .padding(.top, (tieuDe?.isEmpty == false) || choChep ? 0 : Spacing.sm + 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                // Nền mã tối hơn nền thẻ một bậc, giống hệt cách VS Code tách
                // vùng mã khỏi vùng chữ.
                .fill(che == .dark ? Color(hex: 0x1E1E1E) : Color(hex: 0xF6F8FA))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(AppColors.border.opacity(0.6), lineWidth: 1)
        )
    }
}
