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
            case "aichat-bong": ThuAIChatBong()
            case "aichat-toanman": ThuAIChatToanMan()
            // Màn Thời khoá biểu — để soi menu "+" mà không cần phiên đăng nhập.
            case "lichtuan": ThuLichTuan()
            // Bộ dựng câu trả lời AI — soi SVG, bảng, màu mã.
            case "traloi": ThuTraLoi()
            case "anhbai": ThuAnhBaiHoc()
            // Trang chủ với dữ liệu GIẢ. Trang chủ nằm sau đăng nhập, nên
            // không có cửa này thì mọi trạng thái của nó (rỗng, lỗi, tên môn
            // dài, một ngày mười việc) chỉ đoán được chứ không nhìn được.
            case "tongquan":      ThuTongQuan(kieu: .day)
            case "tongquan-rong": ThuTongQuan(kieu: .rong)
            case "tongquan-dai":  ThuTongQuan(kieu: .dai)
            case "tongquan-tai":  ThuTongQuan(kieu: .tai)
            case "tongquan-loi":  ThuTongQuan(kieu: .loi)
            // Trang chủ ĐẶT TRONG thanh tab thật — để kiểm hai thứ chỉ hỏng
            // khi có thanh tab: cuộn tới đáy có bị thanh tab che không, và
            // bàn phím bật lên có phá bố cục không.
            case "tongquan-tab":  ThuTongQuanTab()

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
            // Bố cục cột đôi của iPad/macOS. Các màn bên trong cần đăng nhập
            // nên chúng hiện trạng thái rỗng — đủ để soi CẤU TRÚC hai cột,
            // không phải để soi nội dung.
            case "vo": VoView()
            case "cotdoi": BoCucCotDoi()
            case "trangchu": HomeView()
            case "khoahoc": CoursesView()      // → vào khoá → bài → màn HỌC BÀI
            case "daluu": DaLuuView()
            case "lichsu": LichSuThiView()
            case "tim": SearchView()

            default:
                VStack(spacing: Spacing.sm) {
                    Text("Không có màn tên “\(ten)”")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Không cần đăng nhập:\ncodelab · snippets · tudien · lotrinh · phongthi · noidungthi · logo\ntongquan · tongquan-rong · tongquan-dai · tongquan-tai · tongquan-loi · tongquan-tab")
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


/// Soi ẢNH BÀI HỌC ở cả hai trạng thái: tải được, và tải HỎNG.
private struct ThuAnhBaiHoc: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("1 · Ảnh THẬT (slide LAB211)")
                    .font(.system(size: 13, weight: .bold)).foregroundColor(AppColors.textSecondary)
                AnhBaiHoc(duong: "https://media.cuongthai.com/code-lab/lab211/hdc/hd-02.png")

                Text("2 · Ảnh HỎNG — phải hiện nút thử lại, KHÔNG xoay mãi")
                    .font(.system(size: 13, weight: .bold)).foregroundColor(AppColors.textSecondary)
                AnhBaiHoc(duong: "https://media.cuongthai.com/khong-he-ton-tai-9x8y7z.png")
            }
            .padding()
        }
        .background(AppColors.backgroundPrimary)
    }
}



// ════════════════════════════════════════════════════════════════
// BÀN THỬ TRANG CHỦ
//
// Trang chủ đòi đăng nhập, và Claude không gõ mật khẩu. Bàn này nhồi dữ liệu
// giả thẳng vào `TongQuanVM` rồi dựng ĐÚNG `TongQuanView` thật — không phải
// một bản chép lại, nên bố cục nhìn ở đây chính là bố cục người dùng thấy.
//
// ⚠️ `dueAt` chứ không `remindAt`: `NhacViec.datLai` chỉ xin quyền thông báo
// khi có `remindAt` còn hạn, và hộp thoại xin quyền sẽ che mất màn hình đang
// cần soi.
// ════════════════════════════════════════════════════════════════

struct ThuTongQuan: View {
    enum Kieu { case day, rong, dai, tai, loi }
    let kieu: Kieu

    var body: some View {
        TongQuanView(banThu: dungVM())
    }

    private func dungVM() -> TongQuanVM {
        let vm = TongQuanVM()
        let homNay = PhamViViec.today.moc()

        switch kieu {
        case .tai:
            vm.dangTai = true
            return vm

        case .loi:
            vm.loi = "The Internet connection appears to be offline."
            return vm

        case .rong:
            // Tài khoản mới tinh: chưa lịch, chưa việc, chưa EXP nào.
            return vm

        case .day:
            vm.trangThai = TrangThaiTongQuan(level: 7, exp: 64, totalExp: 664)
            vm.chuoiNgay = 5
            vm.buoiHoc = lich
            vm.viec = [
                viec(1, homNay, "Làm 3 bài Lab của LAB211", exp: 15, uu: 3,
                     gio: "\(ngayISO(0))T19:00:00+07:00"),
                viec(2, homNay, "Đọc slide chương 4 SWT301", exp: 10, xong: true),
                viec(3, homNay, "Ôn 20 từ vựng JPD123", exp: 10, lap: "daily"),
            ] + viecNgayToi()
            return vm

        case .dai:
            vm.trangThai = TrangThaiTongQuan(level: 12, exp: 95, totalExp: 1295)
            vm.chuoiNgay = 41
            vm.buoiHoc = [
                BuoiHoc(id: 90, subject: "PRN232 – Building Cross-Platform Back-End Application With .NET",
                        classCode: "SE1815-NJ", teacher: "Nguyễn Thị Minh Phương Thảo",
                        room: "Beta Building – Phòng thực hành số 214",
                        weekday: thuHomNay, startTime: "07:30", endTime: "09:50",
                        color: nil, note: nil, remindMinutes: 15,
                        startDate: nil, endDate: nil, slot: 1, meetUrl: nil, materialsUrl: nil),
            ]
            vm.viec = (0..<9).map { i in
                viec(100 + i, homNay,
                     "Hoàn thành toàn bộ phần bài tập chương \(i + 1) của môn PRN232 và nộp lên hệ thống trước hạn",
                     exp: 15, uu: i == 0 ? 3 : 0, xong: i > 6)
            }
            return vm
        }
    }

    // ── Dữ liệu giả ──────────────────────────────────────────────

    private var thuHomNay: Int {
        BuoiHoc.thuViet(tuLich: Calendar.current.component(.weekday, from: Date()))
    }

    private var lich: [BuoiHoc] {
        [
            BuoiHoc(id: 1, subject: "SWT301 – Software Testing", classCode: "SE1815",
                    teacher: "Trần Văn Nam", room: "AL-306", weekday: thuHomNay,
                    startTime: "07:30", endTime: "09:50", color: nil, note: nil,
                    remindMinutes: 15, startDate: nil, endDate: nil, slot: 1,
                    meetUrl: nil, materialsUrl: nil),
            BuoiHoc(id: 2, subject: "LAB211 – OOP with Java Lab", classCode: "SE1815",
                    teacher: "Lê Thu Hà", room: "BE-201", weekday: thuHomNay,
                    startTime: "12:50", endTime: "15:10", color: nil, note: nil,
                    remindMinutes: 15, startDate: nil, endDate: nil, slot: 3,
                    meetUrl: nil, materialsUrl: nil),
            BuoiHoc(id: 3, subject: "JPD123 – Elementary Japanese 2.1", classCode: "SE1815",
                    teacher: "Phạm Minh", room: "AL-112",
                    weekday: (thuHomNay == BuoiHoc.thuLon ? BuoiHoc.thuNho : thuHomNay + 1),
                    startTime: "10:00", endTime: "12:20", color: nil, note: nil,
                    remindMinutes: 15, startDate: nil, endDate: nil, slot: 2,
                    meetUrl: nil, materialsUrl: nil),
        ]
    }

    private func viecNgayToi() -> [ViecTongQuan] {
        var ra: [ViecTongQuan] = []
        var id = 200
        for n in [1, 2] {
            let ngay = ngayISO(n)
            let soViec = n == 1 ? 4 : 1
            for k in 0..<soViec {
                ra.append(viec(id, ngay, "Ôn tập buổi \(k + 1) cho ngày mai", exp: 10))
                id += 1
            }
        }
        return ra
    }

    private func ngayISO(_ sauNgay: Int) -> String {
        let d = Calendar.current.date(byAdding: .day, value: sauNgay, to: Date()) ?? Date()
        return PhamViViec.today.moc(d)
    }

    private func viec(_ id: Int, _ ngay: String, _ ten: String, exp: Int,
                      uu: Int = 0, xong: Bool = false, lap: String = "none",
                      gio: String? = nil) -> ViecTongQuan {
        ViecTongQuan(id: id, scope: PhamViViec.today.rawValue, date: ngay, title: ten,
                     done: xong, exp: exp, note: nil, dueAt: gio, remindAt: nil,
                     priority: uu, repeatMode: lap, parentId: nil, sortOrder: id)
    }
}

/// Trang chủ giả, đặt trong đúng bộ tab của app.
///
/// Bốn tab kia để trống có chủ đích: thứ cần kiểm là CHIỀU CAO mà thanh tab
/// chừa lại cho trang chủ, không phải nội dung của các tab khác.
struct ThuTongQuanTab: View {
    var body: some View {
        TabView {
            ThuTongQuan(kieu: .day)
                .tabItem { Label(AppState.AppTab.home.title,
                                 systemImage: AppState.AppTab.home.icon) }
            trong(AppState.AppTab.learn)
            trong(AppState.AppTab.create)
            trong(AppState.AppTab.messages)
            trong(AppState.AppTab.profile)
        }
        .tint(AppColors.primary)
    }

    private func trong(_ tab: AppState.AppTab) -> some View {
        Color.clear
            .tabItem { Label(tab.title, systemImage: tab.icon) }
    }
}


/// Bong bóng tin người dùng có ẢNH + TỆP + chữ, và khay đính kèm đang chờ gửi.
private struct ThuAIChatBong: View {
    @StateObject private var vm = AIChatViewModel()
    var body: some View {
        AIChatView(vmNgoai: vm, toanMan: true, doiCheDo: {})
            .onAppear {
                let a1 = Self.anhMau("Đề bài 1", .systemTeal)
                let a2 = Self.anhMau("Hình vẽ", .systemOrange)
                vm.bac = .pro
                vm.tin = [
                    TinAI(cuaNguoi: true, noiDung: "Giải giúp mình câu 2 trong đề này, đối chiếu với giáo trình nhé",
                          anh: [a1, a2], tep: [""], tenTep: ["SWR302-giao-trinh.pdf"],
                          moTaTep: ["6 trang · 1,5 MB"]),
                    TinAI(cuaNguoi: false, noiDung: "Câu 2 hỏi về **yêu cầu phi chức năng**. Theo giáo trình trang 3…"),
                    TinAI(cuaNguoi: true, noiDung: "", anh: [a2]),
                ]
                vm.dinhKemNhap = [
                    DinhKemAI(ten: "Software_Requirements.pdf", mime: "text/plain", duLieu: Data("x".utf8),
                              moTa: "673 trang · đọc chữ trên máy"),
                ]
            }
    }
    static func anhMau(_ chu: String, _ mau: UIColor) -> String {
        let r = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 420))
        let img = r.image { c in
            mau.setFill(); c.fill(CGRect(x: 0, y: 0, width: 600, height: 420))
            (chu as NSString).draw(at: CGPoint(x: 40, y: 170),
                withAttributes: [.font: UIFont.boldSystemFont(ofSize: 56), .foregroundColor: UIColor.white])
        }
        return "data:image/jpeg;base64," + (img.jpegData(compressionQuality: 0.8) ?? Data()).base64EncodedString()
    }
}

/// Mở AI Chat qua `moAIChat` THẬT — để bấm thử nút phóng to / thu nhỏ.
private struct ThuAIChatToanMan: View {
    @State private var mo = false
    var body: some View {
        VStack(spacing: 16) {
            Text("Màn gọi AI Chat").font(.title3)
            Button("Mở AI Chat") { mo = true }.buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .moAIChat(dangMo: $mo, cauMoDau: "Câu mở đầu thử", bacBanDau: .pro)
        .onAppear { mo = true }
    }
}

#endif
