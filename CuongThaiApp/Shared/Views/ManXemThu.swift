#if DEBUG
import SwiftUI

/// Cửa XEM MÀN HÌNH — chỉ tồn tại trong bản DEBUG.
///
/// Vì sao có: app bắt đăng nhập ở `ContentView`, nên không mở được một màn cụ
/// thể trên máy mô phỏng để soi giao diện. Suốt 22/08/2026 tôi phải nhờ người
/// dùng chụp màn hình mới biết bố cục lệch — và họ đã phải chỉ ra hai lần.
///
/// Dùng: đặt biến môi trường khi mở app.
///
///     xcrun simctl launch --console <udid> com.cuongthai.app \
///       --setenv CT_XEM_MAN=codelab
///
/// ⚠️ Nằm trọn trong `#if DEBUG` nên KHÔNG vào bản Release. Đây đúng thứ đã
/// từng hỏng theo chiều ngược lại: cờ `DEBUG` đặt nhầm ở `settings.base` lọt
/// vào Release làm TestFlight đăng ký APNs sandbox (xem `project.yml`). Giờ cờ
/// đó nằm đúng trong `configs: Debug:`, đã kiểm lại trước khi viết file này.
struct ManXemThu: View {
    let ten: String

    /// Ngôn ngữ giả để dựng những màn cần `NgonNgu` mà không phải gọi mạng.
    private var tiengNhat: NgonNgu {
        NgonNgu(id: 2, name: "Tiếng Nhật", nameEn: "Japanese", code: "ja",
                flagEmoji: "🇯🇵", order: 2, isActive: true, counts: nil)
    }

    var body: some View {
        NavigationStack {
            switch ten.lowercased() {
            case "codelab": CodeLabView()
            case "snippet", "snippets": SnippetsView()
            case "tudien": TuDienView(ngonNgu: tiengNhat)
            case "lotrinh": LoTrinhView(ngonNgu: tiengNhat)
            case "phongthi": PhongThiView()
            case "noidungthi": ThuNoiDungThi()
            default:
                VStack(spacing: Spacing.sm) {
                    Text("Không có màn tên “\(ten)”")
                        .font(.system(size: 15, weight: .semibold))
                    Text("codelab · snippets · tudien · lotrinh · phongthi · noidungthi")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }
}

/// Bàn thử cho `NoiDungThi`.
///
/// Phòng thi ĐÒI ĐĂNG NHẬP nên không mở được đề thật để soi. Màn này dựng
/// đúng những dạng nội dung mà đề thi có — song ngữ `|||`, công thức KaTeX,
/// sơ đồ mermaid, bảng, mã đã tô màu sẵn ở máy chủ, ảnh — để kiểm bộ dựng mà
/// không cần tài khoản.
struct ThuNoiDungThi: View {
    @State private var ngonNgu: NgonNguDe = .anh

    private let mau: [(String, String)] = [
        ("Song ngữ (|||)",
         "Which feature of critique can be found in the theorist's writing?|||Đặc điểm phê phán nào thể hiện trong bài viết của nhà lý luận?"),
        ("Đáp án song ngữ",
         "Unjust ideologies maintain unequal power structures.|||Các ý thức hệ bất công duy trì cấu trúc quyền lực bất bình đẳng."),
        ("Công thức trong dòng",
         "<p>Cho \\(f(x)=x^2+3x-4\\). Nghiệm của \\(f(x)=0\\) là bao nhiêu?</p>"),
        ("Công thức tách dòng",
         "<p>Tính tích phân sau:</p>$$\\int_{0}^{1} \\frac{2x}{x^2+1}\\,dx = \\ln 2$$"),
        ("Bảng",
         "<table><thead><tr><th>Toán tử</th><th>Ý nghĩa</th><th>Độ ưu tiên</th></tr></thead><tbody><tr><td><code>*</code></td><td>Nhân</td><td>Cao</td></tr><tr><td><code>+</code></td><td>Cộng</td><td>Thấp</td></tr></tbody></table>"),
        ("Mã đã tô màu ở máy chủ",
         "<pre><code><span class=\"hljs-keyword\">SELECT</span> <span class=\"hljs-built_in\">count</span>(*) <span class=\"hljs-keyword\">FROM</span> orders <span class=\"hljs-comment\">-- đếm đơn</span>\n<span class=\"hljs-keyword\">WHERE</span> total &gt; <span class=\"hljs-number\">100</span>;</code></pre>"),
        ("Sơ đồ",
         "<pre class=\"mermaid\">flowchart LR\n  A[Nhập đơn] --> B{Đã thanh toán?}\n  B -->|Rồi| C[Giao hàng]\n  B -->|Chưa| D[Chờ]</pre>"),
        ("Mục La Mã trong đề (phải xuống dòng)",
         "Cho \\(P(x)\\) là hàm mệnh đề trên \\(\\{-2,-1,0,1,2,3\\}\\). Tìm mệnh đề tương đương logic với \\(\\forall x[(x \\ge 1) \\to P(x)]\\). (i) \\(P(1) \\to (P(2) \\wedge P(3))\\) (ii) \\(P(1) \\vee P(2) \\vee P(3)\\) (iii) \\(P(1) \\wedge P(2) \\wedge P(3)\\) (iv) \\(P(1) \\to (P(2) \\vee P(3))\\)"),
        ("Một (i) lẻ — KHÔNG được xuống dòng",
         "Đơn vị ảo (i) thoả \\(i^2 = -1\\), dùng trong số phức."),
        ("Định dạng",
         "<p><strong>In đậm</strong>, <em>in nghiêng</em>, <u>gạch chân</u>, mã <code>x = 1</code>.</p><ul><li>Gạch đầu dòng một</li><li>Gạch đầu dòng hai</li></ul>"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                ForEach(Array(mau.enumerated()), id: \.offset) { _, m in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(m.0.uppercased())
                            .font(.system(size: 10, weight: .bold)).kerning(0.5)
                            .foregroundColor(AppColors.textTertiary)
                        NoiDungThi(chu: m.1, coChu: 15, laDeBai: m.0.contains("La Mã") || m.0.contains("lẻ"))
                    }
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                        .fill(AppColors.backgroundCard))
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Thử nội dung đề")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { ngonNgu = ngonNgu.doiSang } label: {
                    Text(ngonNgu.nhanNut).font(.system(size: 13, weight: .bold))
                }
            }
        }
        .environment(\.ngonNguDe, ngonNgu)
    }
}
#endif
