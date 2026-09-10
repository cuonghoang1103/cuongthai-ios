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
            case "logo": ThuLogo()
            // Chế độ nói chuyện với AI. Không có cửa này thì không soi được:
            // AI Chat nằm sau đăng nhập, mà Claude không gõ mật khẩu.
            case "chedonoi": ThuCheDoNoi()
            // Cả màn AI Chat — để soi Ô NHẬP. Không gọi được AI vì chưa đăng
            // nhập, nhưng bố cục thanh dưới thì thấy đủ.
            case "aichat": AIChatView()
            // Màn Thời khoá biểu — để soi menu "+" mà không cần phiên đăng nhập.
            case "lichtuan": ThuLichTuan()
            // Bộ dựng câu trả lời AI — soi SVG, bảng, màu mã.
            case "traloi": ThuTraLoi()

            // Ba trạng thái của màn Hồ sơ khi CHƯA có dữ liệu. Không có cửa
            // này thì không cách nào nhìn thấy chúng: muốn tái hiện phải làm
            // hỏng mạng đúng lúc mở app.
            case "hoso-tai": ScrollView { HoSoDangTaiView() }
            case "hoso-loi":
                ScrollView {
                    HoSoTrongView(
                        bieuTuong: "wifi.exclamationmark",
                        tieuDe: "Không tải được hồ sơ",
                        moTa: "The Internet connection appears to be offline.",
                        nhanNut: "Thử lại", hanhDong: {},
                        nhanPhu: "Đăng xuất", hanhDongPhu: {})
                }
            case "hoso-chuadn":
                ScrollView {
                    HoSoTrongView(
                        bieuTuong: "person.crop.circle",
                        tieuDe: "Đăng nhập để xem hồ sơ",
                        moTa: "Hồ sơ lưu bài viết, khoá học và tiến độ học của bạn trên mọi thiết bị.",
                        nhanNut: "Đăng nhập", hanhDong: {})
                }

            // ── Cần PHIÊN ĐĂNG NHẬP mới có dữ liệu ───────────────────
            //
            // Cửa xem màn KHÔNG bỏ qua xác thực — nó chỉ bỏ qua màn đăng
            // nhập. Token nằm ở Keychain của máy mô phỏng, mà Keychain đó
            // **sống qua cả `simctl install` đè lẫn `simctl uninstall`**
            // (đo thật 23/08/2026: một token admin cũ sót lại làm danh sách
            // trả về cả bản nháp). Nên người dùng đăng nhập MỘT lần là mọi
            // lần dựng sau đều mở thẳng vào được, suốt 7 ngày — bằng tuổi
            // `JWT_REFRESH_EXPIRES_IN`.
            //
            // ⛔ `xcrun simctl erase` XOÁ Keychain ⇒ mất phiên, phải nhờ
            //    người dùng đăng nhập lại. Cần sạch thì dùng `uninstall`.
            case "trangchu": HomeView()
            case "khoahoc": CoursesView()      // → vào khoá → bài → màn HỌC BÀI
            case "daluu": DaLuuView()
            case "lichsu": LichSuThiView()
            case "tim": SearchView()

            default:
                VStack(spacing: Spacing.sm) {
                    Text("Không có màn tên “\(ten)”")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Không cần đăng nhập:\ncodelab · snippets · tudien · lotrinh · phongthi · noidungthi · logo")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                    Text("Cần phiên đăng nhập:\ntrangchu · khoahoc · daluu · lichsu · tim")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}

/// Bàn thử LOGO — soi hình nét ở cỡ lớn và cỡ THẬT, bấm để xem vệt sáng chạy.
///
/// Thiết kế thì phải NHÌN mới biết, đọc mã không ra. Ba phương án đã soi ở đây
/// rồi mới chọn — xem ghi chú ở `NetLogo`.
struct ThuLogo: View {
    var body: some View {
        VStack(spacing: Spacing.xl) {
            LogoCuongThai(canh: 140, doDamNet: 11, coChu: false)
            // Cỡ THẬT trên thanh trên cùng — hình đẹp ở 140pt mà rối ở 30pt
            // thì vẫn là hỏng.
            LogoCuongThai(canh: 30, coChu: true)
            Text("Bấm vào logo để xem vệt sáng chạy hết nét")
                .font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
            Spacer()
        }
        .padding(.top, Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Thử logo")
        .navigationBarTitleDisplayMode(.inline)
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
        // ⚠️ Mẫu này để bắt LỖI CHIỀU CAO: một đoạn HTML dài NHIỀU DÒNG.
        // 05/09/2026 lời giải trong thẻ "Hiện đáp án" của CuongMini bị cắt
        // đúng sau dòng đầu — phải có chỗ tái hiện được mà không cần đăng
        // nhập thì mới truy được nguyên nhân.
        ("Lời giải DÀI nhiều dòng (kiểm chiều cao)",
         "<p>In academic contexts an <strong>argument</strong> is a reasoned attempt to defend, validate or explain a conclusion by giving specific reasons or evidence. It is <em>not</em> an angry disagreement, nor a polite word for a fight, and it is not simply another word for the conclusion itself.</p><p>Therefore option B is the only one that matches the academic definition used throughout this course.</p>"),
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

/// Dựng `CheDoNoiView` với một cuộc chat giả — đủ để soi bố cục, các trạng
/// thái và cử chỉ giữ-mic mà không cần phiên đăng nhập.
private struct ThuCheDoNoi: View {
    @StateObject private var vm = AIChatViewModel()
    @StateObject private var mayDoc = MayDoc()
    @StateObject private var tongQuan = TongQuanVM()
    var body: some View {
        CheDoNoiView(vm: vm, mayDoc: mayDoc, tongQuan: tongQuan)
            .onAppear {
                vm.tin = [
                    TinAI(cuaNguoi: true, noiDung: "Con trỏ trong C là gì?"),
                    TinAI(cuaNguoi: false, noiDung: "Con trỏ là biến lưu địa chỉ của một biến khác."),
                ]
            }
    }
}


private struct ThuLichTuan: View {
    @StateObject private var vm = TongQuanVM()
    var body: some View { LichTuanView(vm: vm) }
}


/// Soi bộ dựng câu trả lời với ĐÚNG ba thứ người dùng báo hỏng:
/// SVG trong khối ```svg · bảng · khối mã cần tô màu.
private struct ThuTraLoi: View {
    private let mau = """
    Quy trình phân tích yêu cầu gồm bốn bước:

    ```svg
    <svg viewBox="0 0 420 90" xmlns="http://www.w3.org/2000/svg">
      <rect x="10" y="20" width="110" height="46" rx="6" fill="#e0e7ff" stroke="#4338ca"/>
      <text x="65" y="48" text-anchor="middle" font-size="14" fill="#1e1b4b">Elicitation</text>
      <path d="M 128 43 L 168 43" stroke="#334155" stroke-width="2"/>
      <rect x="175" y="20" width="110" height="46" rx="6" fill="#dcfce7" stroke="#15803d"/>
      <text x="230" y="48" text-anchor="middle" font-size="14" fill="#052e16">Analysis</text>
      <path d="M 293 43 L 333 43" stroke="#334155" stroke-width="2"/>
      <rect x="340" y="20" width="70" height="46" rx="6" fill="#fee2e2" stroke="#b91c1c"/>
      <text x="375" y="48" text-anchor="middle" font-size="13" fill="#450a0a">Spec</text>
    </svg>
    ```

    | Bước | Đầu ra | Ai làm |
    |---|---|---|
    | Elicitation | Danh sách yêu cầu thô | BA |
    | Analysis | Mô hình use-case | BA + Dev |
    | Validation | Biên bản duyệt | Khách hàng |

    Ví dụ mã Java:

    ```java
    public class Account {
        private double balance;   // số dư
        public void deposit(double amount) {
            if (amount <= 0) throw new IllegalArgumentException("amount must be > 0");
            this.balance += amount;
        }
    }
    ```
    """
    var body: some View {
        ScrollView {
            TraLoiAI(chu: mau, xong: true)
                .padding()
        }
        .background(AppColors.backgroundPrimary)
    }
}

#endif
