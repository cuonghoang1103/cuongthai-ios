# App CT Work iOS — KIẾN TRÚC (đọc trước khi thêm mô-đun)

Target `CTWorkApp` · bundle `com.cuongthai.ctwork` · tên hiển thị "CT Work" · iOS 17+ · iPhone + iPad.
Giao diện **Tiếng Việt + English**, đổi ngay trong app (Account › Language, mục 12 — thay quyết định "chỉ tiếng Anh" cũ,
chủ app đổi 20/10/2026); chú thích mã tiếng Việt.
Luật Apple + bẫy của kho: `ios-app/CLAUDE.md` (PHẦN A, C). Ghi chú duyệt: `ios-app/CTWORK_APP_REVIEW_NOTES.md`.

## 1. Thư mục

```
CuongThaiApp/
├─ CTWorkApp/                       ← CHỈ target CTWorkApp biên dịch
│  ├─ App/                          khung: @main, AppState, thanh tab/thanh bên, deep link, push, socket
│  │   CTWorkAppMain.swift · AppStateCTW.swift · KhungCTW.swift · DinhTuyenCTW.swift
│  │   DayCTW.swift (APNs) · RealtimeCTW.swift (Socket.IO)
│  ├─ Core/                         CTWModule.swift (kiểu) · CTWDangKyMoDun.swift (BẢNG ĐĂNG KÝ)
│  ├─ Modules/<TenMoDun>/           mỗi mô-đun một thư mục:
│  │   MoDun<Ten>.swift             đăng ký (`extension CTWModule { static let … }`)
│  │   CTWAPI+<Ten>.swift           đường API của mô-đun
│  │   CTWModels+<Ten>.swift        model Codable của mô-đun
│  │   <Ten>CTW.swift …             màn
│  │   (hiện có: MyWork · Project · Board · Backlog · Docs · Chat · Meetings · Inbox · Account …)
│  ├─ Debug/XemThuCTW.swift         máy chủ GIẢ + dữ liệu mẫu (chỉ #if DEBUG)
│  ├─ Info.plist · PrivacyInfo.xcprivacy · CTWorkApp.entitlements (xcodegen sinh) · Assets.xcassets
│  └─ KIEN_TRUC.md                  (tệp này — bị loại khỏi gói, xem project.yml `excludes`)
├─ Shared/CTWork/                   ← DÙNG CHUNG với app chính (cả hai target biên dịch)
│  ├─ CTWorkModels.swift            model lõi: dự án, quy trình, thẻ, bình luận, TipTap, `CTW` (tiện ích)
│  ├─ CTWModels+Issues.swift        đính kèm, danh sách/backlog, lịch sử, tìm kiếm
│  ├─ CTWAPI.swift                  LÕI gọi API (`CTWAPI.get` / `CTWAPI.goi`)
│  ├─ CTWAPI+Issues.swift           thẻ, bình luận, đính kèm, backlog, tìm kiếm
│  ├─ CTWTaiLen.swift               tải tệp lên R2 (presign → PUT → complete)
│  ├─ CTWKiemDuyet.swift            ẩn nội dung đã báo cáo + lý do báo cáo (1.2)
│  ├─ CTWorkBoardView / CTWorkIssueView / CTWorkCreateIssueView / CTWorkView.swift
│  └─ CTWUI/                        THƯ VIỆN GIAO DIỆN (mục 4)
├─ CTWorkShared/                    ← app + CTWorkWidget (+ CTWorkShare chỉ NhomCTW.swift) cùng biên dịch
│  ├─ NhomCTW.swift                 App Group `group.com.cuongthai.ctwork` (ảnh chụp JSON: việc hôm nay, đồng hồ,
│  │                                dự án, thẻ đã xem) + Keychain chia sẻ token cho Share Extension
│  └─ DongHoActivityCTW.swift       `CTWDongHoAttributes` (Live Activity) + `NutDongHoLiveIntent` (nút Pause/Stop)
├─ CTWorkWidget/                    target CTWorkWidget (com.cuongthai.ctwork.widget): "My work today", "Timer", Live Activity
├─ CTWorkShare/                     target CTWorkShare (com.cuongthai.ctwork.share): ảnh/link/chữ ⇒ thẻ mới hoặc bình luận
├─ CTWorkTests/                     kiểm thử đơn vị (target CTWorkAppTests)
└─ CTWorkUITests/                   kiểm thử giao diện (target CTWorkAppUITests)
```

⚠️ Thứ gì đặt trong `Shared/` thì app chính CŨNG biên dịch. Mô-đun mới của app CT Work
đặt ở `CTWorkApp/Modules/…` (không làm phình app chính). Chỉ đưa vào `Shared/CTWork`
thứ thật sự dùng chung (model lõi, thành phần CTWUI).
⚠️ Tệp `Shared/...` mới mà target CTWorkApp cần ⇒ thêm đường dẫn vào `sources` của
target trong `project.yml` (target KHÔNG kéo cả `Shared` — xem chú thích ở đó).
⚠️ Thêm/đổi tên tệp `.swift` ⇒ chạy `xcodegen generate` (CLAUDE.md C11).

## 2. Khung điều hướng

| | iPhone (cỡ ngang hẹp) | iPad (cỡ ngang rộng) |
|---|---|---|
| Khung | `TabView`: My Work · Projects · Chat · Inbox · Account | `NavigationSplitView`: thanh bên theo nhóm |
| Mô-đun `.trangDuAn` | một dòng trong trang **Projects** (`Modules/Project/TrangDuAnCTW.swift`) | một mục trong nhóm của nó |
| Mô-đun `.tabRieng` | một TAB riêng (tối đa 1 — hiện là Chat) | một mục trong nhóm |
| Nhóm thanh bên | — | Project · Communication · Planning · Docs & knowledge · Requirements & testing · Governance · Admin |

- Mỗi tab/cột là một `CotCTW`: `NavigationStack(path:)` + một `NganXepCTW` (environment
  object). Mô-đun đẩy màn bằng `NavigationLink(value:)` hoặc `nganXep.duong.append(...)`.
- Màn của mô-đun **KHÔNG tự bọc NavigationStack** (khung bọc sẵn).
- Nhóm không có mô-đun nào hiện ⇒ ẩn nhóm. Mô-đun bị dự án tắt ⇒ ẩn mục.
- Chọn bố cục theo `horizontalSizeClass` — iPad Slide Over hẹp tự về thanh tab.
- ⛔ Thanh bên iPad PHẢI dùng `NavigationLink(value:)`; `.tag()` chết câm trên iOS.

## 3. Thêm một mô-đun (vd "Timeline")

1. Tạo `CTWorkApp/Modules/Timeline/`:
   - `CTWModels+Timeline.swift` — model (mọi trường `var` + optional, ngày là `String`; CLAUDE.md C3/C4).
   - `CTWAPI+Timeline.swift` — `extension CTWAPI { static func timeline(pid: Int) -> APIEndpoint { get("/projects/\(pid)/timeline") } }`
   - `TimelineCTW.swift` — màn (chỉ nội dung).
   - `MoDunTimeline.swift`:
     ```swift
     extension CTWModule {
         static let timeline = CTWModule(
             id: "timeline", ten: "Timeline", bieuTuong: "calendar.day.timeline.left", nhom: .keHoach,
             moTa: "Roadmap across sprints", thuTu: 20, doanWeb: "timeline",
             hien: { cfg in cfg?.coQuyen("…") ?? true },          // tuỳ chọn
             man: { c in AnyView(TimelineCTW(pid: c.pid)) },
             dichDen: { v in AnyView(v.navigationDestination(for: RouteTimeline.self) { r in … }) })  // nếu có màn con
     }
     ```
2. Thêm **một dòng** `.timeline,` vào `CTWDangKyMoDun.dangKyMoDun` (Core/CTWDangKyMoDun.swift).
3. `xcodegen generate`. Xong — thanh tab, thanh bên, trang dự án, deep link tự nhận.

Luật:
- **2.1:** chưa xong thì KHÔNG đăng ký (không có mục "Coming soon").
- **`id` nên trùng đoạn đường web** (`/work/<ws>/<KEY>/<id>`) — deep link tự đi đúng.
- Ẩn/hiện theo dự án: `cfg.batMoDun("docs")` (map `modules` của `GET /projects/:pid`),
  `cfg.coQuyen("viewFinance")` (mọi cờ `permissions`, kể cả cờ chưa có trường riêng).
- Cấu hình dự án đang chọn có sẵn ở `AppState.cauHinhDuAn` — đừng gọi lại `GET /projects/:pid` chỉ để đọc quyền.
- Kiểm thử `DangKyMoDunTests` bắt id/đoạn web trùng.

## 4. Thư viện giao diện `Shared/CTWork/CTWUI/`

| Thành phần | Dùng cho |
|---|---|
| `.ctwThe(radius)` | mặt thẻ chuẩn (nền thẻ, bo liền, viền mảnh, bóng nhẹ) |
| `CTWStatusChip` · `CTWPriorityIcon` · `CTWTypeIcon` | chip trạng thái có chấm màu, ưu tiên, loại thẻ |
| `CTWAvatar(user:size:)` | avatar gradient/ảnh; **tự gắn ✦ cho AI agent** |
| `CTWNhanAI()` | nhãn "AI agent" cạnh tên/nội dung do AI tạo (4.7) |
| `CTWSectionHeader` | tiêu đề khối có biểu tượng + đếm + nút phải |
| `CTWOTrong` · `CTWOLoi` · `CTWErrorBanner` | ô trống · ô lỗi toàn màn · dải lỗi tại chỗ |
| `CTWKhungTai` | khung tải (skeleton), tôn trọng Reduce Motion |
| `CTWThanhLoc` + `CTWChipLoc` | hàng chip lọc cuộn ngang |
| `CTWChonNguoiView` · `CTWChonTrangThaiMenu` · `CTWChonUuTienMenu` | bảng chọn người (nhãn agent) / trạng thái theo quy trình / ưu tiên |
| `CTWSoanMarkdown` | soạn markdown nhẹ (thanh định dạng + xem trước) |
| `CTWMarkdownView` · `CTWTipTapView` · `CTWKhoiView` | dựng markdown / TipTap JSON chỉ đọc |
| `CTWAnhCoXacThuc` | ảnh cần token (`/api/v1/work/.../images/:id`) |
| `CTWXemTep.taiVe` + `.ctwXemTep($url)` | tải url ký sẵn rồi Xem nhanh (QuickLook) |
| `CTWRung.thanhCong/loi/chon` | haptics |
| `SafariCTW` (App/…/TaiKhoanCTW.swift) | mở trang web trong app (KHÔNG dùng cho mua bán — 3.1.1) |
| `CTWChipChu` · `CTWNhanNho` · `CTWMauTrangThai` | chip trạng thái CHUỖI (APPROVED/FAIL/AT_RISK…) · nhãn nhỏ · bảng màu theo trạng thái |
| `CTWHangTruong` + `CTWKhoiTruong` · `CTWODem` · `CTWThanhPhanDoan` | dòng "trường — giá trị" trong khối thẻ · ô số đếm · thanh tiến độ nhiều màu |
| `CTWBinhLuanDong` · `CTWHopSoan` · `.ctwMenuBaoCaoChan` | bình luận chung (markdown/TipTap, nhãn AI, ẩn khi đã báo cáo/chặn) · ô soạn · menu Copy/Report/Block (1.2) cho MỌI nội dung người dùng không có route báo cáo riêng (`AnNoiDungChungCTW`, khoá chuỗi `"<loai>-<id>"`) |
| `CTWOSoanTaiLieu` + `CTWBoSoan` + `CTWThanhDinhDang` | trình soạn tài liệu markdown (UITextView, chèn đúng con trỏ, tự nối danh sách) + thanh định dạng trên bàn phím |
| `CTWWeb.url(slug:ma:doan:)` | đường web của một màn (mở bằng `SafariCTW` cho phần thiết kế nặng) |
| `CTWKieuWeb` · `CTWProjectMark` · `CTWStatusGlyph` · `CTWDueChip` · `CTWLabelChip` · `CTWPointsBadge` | ngôn ngữ hình ảnh CHUNG với web (20/10): màu theo mã dự án/username (`avatarColor` của web), glyph trạng thái (hình + màu), chip hạn (đỏ quá hạn, cam hôm nay), ngày theo ngôn ngữ máy (`CTWKieuWeb.ngay`) |
| `DuongDanAnh.url/urlAnh` (Shared/Components/UserAvatarView.swift) | MỌI đường ảnh từ máy chủ: tuyệt đối giữ nguyên · `/images/…` ghép `APIClient.diaChiGoc` · khoá R2 trần ghép `media.cuongthai.com` · bỏ `blob:`/`data:` · `urlAnh` bỏ SVG (Kingfisher không giải). `UserAvatarView(duPhong:)` hiện avatar chữ cái khi không có/đang tải/hỏng |

Luật màu: CHỈ `AppColors.*` (tự đổi sáng/tối). Biểu tượng: SF Symbols. Chạm tối thiểu 44pt.
Chữ trong `ScrollView(.horizontal)` phải `.fixedSize` (bẫy cắt chữ). Một view chỉ MỘT
`.sheet` — nhiều tấm phủ thì `.sheet(item:)` + enum, hoặc gắn ở view con khác (CLAUDE.md C5).

## 5. Lõi: mạng · lỗi · phân trang · realtime · thông báo

- **Mạng:** `APIClient.shared.request(CTWAPI.x(...))` (giải mã `data` của envelope), `.send(...)`
  (chỉ cần `success`). Đường dẫn CT Work đi qua `APIEndpoint.workGoi` — nơi gọi không gõ chuỗi.
  Header `X-Client-Platform: ios` tự gắn (máy chủ bỏ lời mời mua cho iOS).
- **Lỗi:** `CTW.loi(error)` ra câu cho người dùng theo ngôn ngữ app (máy chủ chỉ nói tiếng Anh — câu quen thuộc/mã lỗi được dịch ở client, mục 12); `CTW.laXungDot(error)` (409 phiên bản
  ⇒ nạp lại); mã máy chủ trong `APIError.coMa(ma, _)` (`MODULE_DISABLED`, `WORK_AGENT_FORBIDDEN`…).
- **Phân trang:** mỗi route một kiểu — thẻ: `nextCursor` (chuỗi rank); chat: `before` + `hasMoreBefore`;
  tìm kiếm: `offset/hasMore`; thông báo: `cursor` số + `hasNextPage`.
- **Realtime:** `RealtimeCTW.shared` (Socket.IO, `auth.token`). Kênh chat: `vaoKenh/roiKenh`
  ⇒ sự kiện `suKienChat`. Thêm sự kiện mới: thêm `s.on("work:…")` + một `PassthroughSubject` ở đó.
- **Thông báo đẩy:** `DayCTW` — đăng ký `POST /api/v1/devices {token, sandbox, platform:"ios", app:"com.cuongthai.ctwork"}`.
  Chạm thông báo ⇒ `duongDan`/`maThe` ⇒ `DinhTuyenCTW`.
- **Ngoại tuyến:** `APIClient` tự lưu mọi GET (`KhoNgoaiTuyen`) và trả bản lưu khi mất mạng.

## 6. Deep link

`DinhTuyenCTW.mo(url:)` / `mo(duongDan:)` nhận `ctwork://…`, `https://cuongthai.com/work/…`, `duongDan` của thông báo.
- `/work/<ws>/<KEY>/issue/<n>` ⇒ lõi mở thẻ (tab My Work).
- `/work/<ws>/<KEY>/<doan>/…` ⇒ mô-đun có `doanWeb == doan`: khung chọn dự án, chuyển tới chỗ
  mô-đun, đặt `AppState.dichCho = DichMoDunCTW(moDun:, pid:, duongDan:)`.
- Mô-đun nhận đích bằng `.task(id: app.dichCho)`; đọc `duongDan.phanCon` / `.tham`; mở phần con;
  ⚠️ **xoá cờ ở CUỐI** (`defer { app.dichCho = nil }`) — xoá sớm làm `.task(id:)` tự huỷ và mọi
  `await` sau đó ném CancellationError (đã dính).
- `ctwork://issue/KEY-12` ⇒ tìm thẻ qua `/search`.
- App chính mở app này bằng `MoAppCTWork.mo(duongDan:)` (Shared/CTWork/MoAppCTWork.swift).

## 7. Chụp màn hình thử bằng dữ liệu mẫu (không tài khoản thật)

```bash
U=$(xcrun simctl list devices available | grep -m1 'iPhone 17 Pro (' | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
xcodebuild -project CuongThaiApp.xcodeproj -scheme CTWorkApp \
  -destination "platform=iOS Simulator,id=$U" -derivedDataPath /tmp/dd build
xcrun simctl install $U /tmp/dd/Build/Products/Debug-iphonesimulator/CTWork.app
SIMCTL_CHILD_CT_XEM_MAN=board xcrun simctl launch $U com.cuongthai.ctwork
sleep 5 && xcrun simctl io $U screenshot board.png
```
Tên màn: `dongy · dangnhap · mywork · duan · board · backlog · list · issue · binhluan · lichsu ·
docs · trang · chat · kenh · inbox · account · chonduan`. Chế độ tối: `xcrun simctl ui $U appearance dark`.
Mảng Giao tiếp (`Debug/XemThuCTW+GiaoTiep.swift`): `chat2 · kenhday · chuoi · ttkenh · taokenh · hop ·
chitiethop · taohop · hopthu · hopthunhom · caidattb · traloinhanh`.

- **Mô-đun mới không cần sửa `XemThuCTW.swift`:** `CT_XEM_MAN=mod:<id>[/<màn con>]` mở thẳng mô-đun
  (`Debug/XemThuCTW+MoDun.swift`; mô-đun đọc màn con bằng `XemThuCTW.conCua("<id>")` trong `#if DEBUG`).
  Dữ liệu mẫu của mảng đặt ở `Debug/XemThuCTW+<Mảng>.swift` (`enum DuLieuGia<Mảng> { static func route… -> Any? }`)
  rồi nối MỘT dòng vào `DuLieuGiaMoDun.boXuLy` — bộ đó được hỏi TRƯỚC bộ định tuyến lõi.
  Vd Docs: `mod:docs` · `mod:docs/page` · `mod:docs/edit` · `mod:docs/history` · `mod:docs/new` · `mod:kb`.
- Máy chủ giả: `MayChuGia` (URLProtocol) chặn mọi `/api/v1/*`, trả `DuLieuGia.route(...)`.
  **Mô-đun mới thêm dữ liệu mẫu** bằng một nhánh trong `route` (đúng HÌNH DẠNG backend — đọc service)
  và một tên màn trong `batNeuCan()`. Dữ liệu mẫu cũng là đầu vào của kiểm thử giải mã.
- ⚠️ Toàn bộ `Debug/XemThuCTW.swift` nằm trong `#if DEBUG`. Kiểm bản Release:
  `grep -a -c CT_XEM_MAN <Release>/CTWork.app/CTWork` phải = 0.
- ⚠️ Biến môi trường cho app trong simulator phải có tiền tố `SIMCTL_CHILD_`.

## 8. Kiểm thử

```bash
xcodebuild test -project CuongThaiApp.xcodeproj -scheme CTWorkApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0.1'
xcodebuild test -project CuongThaiApp.xcodeproj -scheme CTWorkApp -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)'
```
- `CTWorkTests` (đơn vị): giải mã dữ liệu mẫu bằng model thật, bộ tách đường dẫn, markdown,
  bảng đăng ký mô-đun. Mô-đun mới: thêm một hàm `test…` giải mã dữ liệu mẫu của mình.
- `CTWorkUITests` (giao diện): BẤM THẬT trên máy mô phỏng — tab, trang dự án, mở thẻ + bình luận,
  gửi/báo cáo tin chat, đăng nhập/xoá tài khoản, thanh bên iPad.

## 9. Quy ước đặt tên

- Kiểu/tệp của app CT Work: tiền tố `CTW` (dùng chung) hoặc hậu tố `CTW` (màn của app riêng).
- Tên hàm/biến tiếng Việt không dấu như cả kho (`tai`, `taiThem`, `loi`, `dangTai`, `nganXep`).
- Chữ hiện cho người dùng: viết bằng TIẾNG ANH trong mã (là khoá của catalog) rồi dịch trong `Localizable.xcstrings` (mục 12).
  Chú thích: tiếng Việt, giải thích VÌ SAO.
- Model API: `var` + optional; ngày `String` (đọc bằng `CTW.ngay`, `CTW.thoiDiem`, `CTWChatThoiGian`).
- Nhật ký chẩn đoán: chỉ trong `#if DEBUG`.

## 10. Mảng D — widget · Live Activity · Siri · Share · Spotlight · Face ID (18/10/2026)

- **Một chiều dữ liệu:** APP ghi vùng chung (`App/ChiaSeNhomCTW.swift` → `CTWorkShared/NhomCTW.swift`), widget/extension
  chỉ ĐỌC. Widget không gọi mạng, không cầm token. App ghi lại khi: ra tiền cảnh (`lamMoiViecHomNay`, `DongHoCTW.taiLai`,
  `dongBoToken`), mở My Work → Agenda, đồng hồ đổi (`DongHoCTW.khiDoi` → `LiveActivityDongHoCTW.capNhat`), mở một thẻ
  (`CTWIssueView(khiMo:)` → Spotlight + "thẻ gần đây"), chọn dự án. Đăng xuất ⇒ `donKhiDangXuat` xoá hết.
- ⚠️ Hàm gọi từ `didSet` của `AppState` KHÔNG được đọc `AppState.shared` (lúc khởi tạo ⇒ `dispatch_once` gọi lại chính nó
  ⇒ SIGTRAP khi mở app — đã dính 18/10). Bản DEBUG nhận ra máy chủ giả bằng `XemThuCTW.man`, không bằng `AppState`.
- **Live Activity:** cục bộ (`pushType: nil`). Nút trên nó là `LiveActivityIntent` ⇒ `perform()` chạy trong tiến trình APP
  (`NutDongHoLiveIntent.thucThi` gắn ở `AppDelegateCTW`). Info.plist: `NSSupportsLiveActivities`.
- **Siri/App Intents:** `Intents/YDinhCTW.swift` (trong target app ⇒ dùng `APIClient`). Không cần capability Siri.
- **Share Extension:** tự gọi API (`MangChiaSe`), token từ Keychain chia sẻ `<TEAM>.com.cuongthai.ctwork.shared`
  (Info.plist `CTWNhomKeychain`, entitlement `keychain-access-groups` — nhóm ĐẦU của app giữ bằng App ID để token cũ đọc được).
- **Face ID:** `Modules/Account/KhoaAppCTW.swift`, mặc định TẮT, `.deviceOwnerAuthentication` (lùi mật mã).
- **3.1.1:** web cuongthai.com mở bằng `TrinhDuyetCuongThaiCTW` (chặn + ẩn `/pro`, `/pricing`, cổng thanh toán).
  Đừng dùng SFSafariViewController cho trang của cuongthai.com nữa (không chặn được điều hướng).
- **Số phiên bản:** `PhienBanCTW.xcconfig` cho cả 3 target (ITMS-90473). KHÔNG khai MARKETING_VERSION ở target trong project.yml.
- **Phát hành:** `bash scripts/phat-hanh-ctwork.sh` (xem CTWORK_APP_REVIEW_NOTES.md mục 8).
- **Màn thử mới:** `agenda` (My Work → Agenda) · `khoa` (màn khoá Face ID). Tuyến máy chủ giả mới: `Debug/XemThuCTW+D.swift`.
- **Bản khai quyền riêng tư:** mỗi extension có `PrivacyInfo.xcprivacy` riêng (không nhóm API nào).

## 11. Bản nộp App Store đầu (19/10/2026) — Code · AI assistant · Dynamic Type

- **Code** (`Modules/Code/`): `MoDunCode` hiện khi `AppState.codeDaNoi == true` (nạp `GET /code/status` cùng cấu hình dự án,
  bỏ qua với khách cổng). Route con `RouteCodeCTW` (thư mục · tệp · lịch sử · commit). Chip mã thẻ là `Button` đẩy
  `CTWRoute.the` — ⚠️ KHÔNG dùng NavigationLink trong hàng List có nhiều đích (cả hàng thành một link). Thông báo Git
  (`payload.git`) có chip "Code" trong Hộp thư; deep link `/code?tab=pulls&pr=N`.
- **AI assistant** (`Modules/AI/`): đồng ý 5.1.2(i) bằng `@AppStorage("com.cuongthai.ctwork.ai.dongY")` (Account › Privacy
  rút lại; đăng xuất xoá). Câu lỗi qua `TroLyAICTW.loi` (không lọt lời mời mua). Link trong câu trả lời: `OpenURLAction`
  của màn — `/work/.../issue/n` đẩy thẻ trong ngăn xếp hiện tại; `/work/...` khác ⇒ `DinhTuyenCTW`; trang mua ⇒ chặn.
  `APIEndpoint.thoiGianCho` = 180 s cho `/ai/chat` + `/retry`.
- **Cỡ chữ:** dùng `.ctw(size:weight:design:)` (Shared/CTWork/CTWUI/CTWCoChu.swift) thay `.system(size:)` — nhân theo
  Dynamic Type, trần 1,4×. Gốc app `.id(dynamicTypeSize)` để dựng lại khi đổi cỡ chữ.
- **Màu:** `AppColors.info` (xanh "đang làm") thay `Color(hex: 0x2563EB)` cố định; `textTertiary`/`success`/`warning`
  bản sáng đã đậm lại cho đạt ≥ 4,5:1.
- **Máy chủ giả:** tuyến trả `LoiGiaCTW(trangThai:ma:thongDiep:)` ⇒ phong bì lỗi thật (502/409/429…);
  `CT_XEM_LOI_MANG=<đoạn đường>` (hoặc `*`) ⇒ giả mất mạng; query của GET được đưa vào `body` của tuyến giả.
  Màn thử: `mod:code[/branches|/pulls|/source]` · `mod:ai[/thread|/loi|/dongy]`; câu hỏi chứa `#fail` ⇒ 502.
- **Kiểm thử:** `CTWorkTests/CodeAITests.swift`; `CTWorkUITests/ToanBoMoDunUITests.swift` (mở MỌI mô-đun có/không mạng,
  luồng Code, AI đồng ý → hỏi → link → 502 → Ask again → Report, công tắc + thông báo Git).
- **"Hiện dần" (phản hồi "nhiều nút, rối"):** trang Projects (iPhone) và thanh bên (iPad) chỉ hiện mô-đun ĐÃ GHIM —
  mặc định `GhimMoDunCTW.macDinh` = AI · Board · Backlog · Chat · Docs · Meetings · Calendar · Code (Code tự ẩn khi chưa
  nối repo). Mọi mô-đun khác ở **More tools** (`Modules/Project/ThemMoDunCTW.swift`: lưới theo nhóm, ô tìm, nút ghim
  44 pt + nhấn giữ). Ghim lưu theo user id (UserDefaults `com.cuongthai.ctwork.ghimMoDun`). `MucCTW.them` (iPad) /
  `RouteThemCTW` (iPhone). Mô-đun mới vẫn chỉ cần đăng ký — nó tự vào More tools; muốn mặc định hiện thì thêm id vào
  `macDinh`. Bảng (Board): một nút chính (+), "Only my issues" + chọn sprint vào menu "…". Account: 6 khối theo chủ đề;
  Thông báo: email/giờ im lặng/múi giờ thu vào "Advanced".
- ⛔ **iPad — màn được ĐẨY không thấy environmentObject của cột detail** (SIGTRAP khi đọc `NganXepCTW`, đo 19/10: Docs ›
  trang › Version history, Code › Source). Ngăn xếp detail do `KhungRongCTW` giữ và gắn `.environmentObject` ở CẢ
  NavigationSplitView. Thêm environmentObject mới cho màn con ⇒ gắn ở cấp split view, không ở cột.

## 12. Giao diện theo web (20/10/2026)

- **Bảng màu:** target CTWorkApp có cờ `CTWORK_APP` (project.yml) ⇒ `AppColors` (Shared/Theme.swift) dùng bảng màu web CT Work
  (indigo `#4F5BD5`/`#737DEA`, nền ấm `#F4F3F0`/`#0D0D0F`, chữ 3 bậc). App chính không có cờ ⇒ giữ tím. Đổi màu ⇒ đo lại
  tương phản (chú thích ngay trong Theme.swift).
- **My Work** (`Modules/MyWork/DanhSachViecCTW.swift`, chỉ app riêng — app chính vẫn `CTWMyWorkView`): công tắc Issues/Agenda
  nằm TRONG List (cùng lề ô tìm); ô đếm = bộ lọc; nhóm Hạn/Dự án/Trạng thái (`ctw.myWork.nhomTheo`), gập nhóm
  (`ctw.myWork.thuGon`), 12 thẻ + "Show all"; vuốt Move (`ChuyenNhanhCTW` — chỉ bước quy trình hợp lệ) / Log time / Board.
- **Tab Projects** (`TrangDuAnCTW`): vào thẳng dự án, công tắc Board · Backlog · List · More (`ctw.duAn.che`), menu đổi dự án ở
  đầu (`DuAnGanDayCTW`, xoá khi đăng xuất). Deep link mô-đun board/backlog ⇒ đổi công tắc, mô-đun khác ⇒ đẩy màn như cũ.
- **Board** (`Shared/CTWork/CTWorkBoardView.swift`): iPhone bật từng cột (`scrollTargetBehavior(.viewAligned)`), cột đích sáng +
  rung khi kéo (`dropDestination(isTargeted:)`), menu nhấn giữ liệt kê thẳng bước "Move to…", MỘT menu Filters (như web đợt 8D).
- Màn thử: `mywork` · `board` (= trang dự án, công tắc Board) · `backlog` · `list` · `duan` (công tắc More) · `chonduan` · `issue`.
  Nhóm/gập My Work khi chụp: `xcrun simctl spawn <U> defaults write com.cuongthai.ctwork ctw.myWork.nhomTheo duAn`.

## 13. Ngôn ngữ — Tiếng Việt / English (20/10/2026)

**Đổi ngay trong app:** Account › Language: "Device language" (mặc định — máy tiếng Việt ⇒ tiếng Việt) · Tiếng Việt · English.
- Lõi `CTWorkShared/NgonNguCTW.swift` (app + widget + Share Extension): lựa chọn lưu ở UserDefaults chuẩn + chép ra App Group
  (`ngon-ngu.json`, đọc tệp nên extension không phải khai API "required reason"); `caiDatBundle()` **tráo lớp `Bundle.main`**
  (`BundleNgonNguCTW`) ⇒ `String(localized:)`, `NSLocalizedString` tra `<ma>.lproj` đang chọn (phải chặn cả biến thể
  `__localizedString(…localizations:)` của iOS 18.4+). ⚠️ `Text("…")`/`Label`/`Button`/`.navigationTitle` của SwiftUI KHÔNG đi
  qua Bundle — chúng tra theo `.environment(\.locale)`, và chỉ nhận locale NGÔN NGỮ TRẦN (`"vi"`/`"en"`; đo 20/10/2026 trên
  iOS 26: `vi_VN` làm SwiftUI rơi về ngôn ngữ lúc khởi động). Ghi cả
  `AppleLanguages` ⇒ phần hệ thống vẽ (UIKit, App Intents, bảng chọn ảnh) theo từ lần mở sau. Đổi ở Cài đặt iOS › CT Work ›
  Ngôn ngữ cũng được nhận (`dongBoVoiCaiDatHeThong`).
- `CTWorkApp/App/NgonNguApCTW.swift`: `@Published ma` ⇒ `GocCTW` gắn `.environment(\.locale, …)` + `.id("\(cỡ chữ)-\(ma)")`
  ⇒ cả cây dựng lại (tab đang chọn giữ vì nằm ở `AppState.muc`; ngăn xếp điều hướng về gốc). Đổi xong: đăng ký lại nút trên
  thông báo (`NutThongBaoCTW.dangKy`) + `WidgetCenter.reloadAllTimelines()`. Widget/Share gọi `NgonNguCTW.caiDatBundle()` lúc khởi tạo.
- Ngày/số HIỂN THỊ: `CTWDinhDang` (`Shared/CTWork/CTWUI/CTWDinhDang.swift`) — `mau("MMMd")` ("Oct 5" / "5 thg 10"),
  `gio`, `tuongDoi` ("2 giờ trước"), `so`. Chip hạn kiểu web (`CTWKieuWeb.ngay` ⇒ `CTWDueChip`, Board, My Work, chi tiết thẻ) cũng đi qua `CTWDinhDang`. ⛔ Không dùng `Locale(identifier: "en_US")` để hiển thị; ĐỌC ngày máy chủ vẫn
  `en_US_POSIX`. App chính (cũng biên dịch `Shared/CTWork`) không đặt `CTWDinhDang.locale` ⇒ vẫn `en_US`, không catalog ⇒ vẫn chữ Anh.

**Catalog:** `CTWorkApp/Localizable.xcstrings` · `CTWorkApp/InfoPlist.xcstrings` (chuỗi xin quyền; tên "CT Work" giữ nguyên) ·
`CTWorkWidget/Localizable.xcstrings` · `CTWorkShare/Localizable.xcstrings`. Ngôn ngữ nguồn `en`, khoá = chữ tiếng Anh.
Info.plist của cả 3 target khai `CFBundleLocalizations` = en, vi.

**Thêm một chuỗi mới:**
1. Viết chữ tiếng Anh như thường. `Text("…")`, `Label`, `Button`, `Section`, `.navigationTitle("…")`, `.alert("…")`… nhận
   literal là tự dịch được. Chữ đi vào một **`String`** (biến, `return` của thuộc tính tính toán, tham số `String` của view
   CTWUI như `CTWOTrong(tieuDe:)`, `CTWSectionHeader`, `CTWHangTruong`, `?? "Untitled"`, câu lỗi/toast, tiêu đề
   `UNNotificationAction`) ⇒ bọc `String(localized: "…")` (nội suy giữ trong chuỗi: `String(localized: "\(n) issues")`).
2. ⛔ KHÔNG `String(localized:)` trong `static let`/hằng toàn cục (dịch MỘT lần ⇒ đóng băng ngôn ngữ cũ khi đổi trong app):
   dùng `static var { … }` tính lại, hoặc lưu `LocalizedStringResource` (vd `CTWModule(ten:moTa:)` ⇒ `CTWModule.dich`) /
   `LocalizedStringKey`.
3. Số nhiều: viết hai câu đủ (`n == 1 ? "1 issue" : "\(n) issues"`), không ghép `"issue" + "s"`. Câu có nhiều phần ⇒ một
   chuỗi có nội suy, không ghép mảnh bằng `+` (tiếng Việt đổi trật tự từ).
4. Dựng app (máy mô phỏng) rồi đồng bộ catalog từ `.stringsdata` trình biên dịch sinh (`SWIFT_EMIT_LOC_STRINGS=YES` đã bật):
   ```bash
   B=<DerivedData>/Build/Intermediates.noindex/CuongThaiApp.build/Debug-iphonesimulator
   xcrun xcstringstool sync CuongThaiApp/CTWorkApp/Localizable.xcstrings \
     --stringsdata $(find $B/CTWorkApp.build/Objects-normal/arm64 -name '*.stringsdata' | grep -v /XemThuCTW)
   ```
   (tương tự `CTWorkWidget`, `CTWorkShare`) — hoặc mở catalog trong Xcode, nó tự thêm khoá sau khi dựng.
5. Thêm bản `vi`. **Thuật ngữ theo web CT Work**: `api-backend/frontend/src/components/work/i18n/GLOSSARY.md` + `vi/*.ts`
   (giữ tiếng Anh Sprint, Backlog, Epic, Story point, Test case…; Issue = "Thẻ", Assignee = "Người thực hiện"…). Giữ nguyên
   đặc tả định dạng (`%@`, `%lld`, đổi chỗ thì `%1$@`).
6. `NgonNguCTWTests` ĐỎ nếu một khoá thiếu bản vi hoặc bản dịch lệch đặc tả định dạng; nó cũng kiểm đổi ngôn ngữ áp ngay.
   `NgonNguUITests` bấm thật Account › Language (vi ⇄ en) không khởi động lại.

Dữ liệu máy chủ (tên dự án, trạng thái, thẻ, người, câu lỗi máy chủ trả) là nội dung người dùng — KHÔNG dịch. Máy chủ CT Work
không đọc `Accept-Language` (20/10/2026) — lỗi/thông báo đẩy luôn tiếng Anh; `CTW.loi` dịch các mã/câu lỗi quen thuộc ở client
(bảng lấy từ `frontend/src/components/work/i18n/errors.ts`).
Chụp màn thử bằng tiếng Việt: `xcrun simctl spawn $U defaults write com.cuongthai.ctwork com.cuongthai.ctwork.ngonNgu vi`
trước khi `simctl launch` (giá trị `system` | `vi` | `en`).

## 14. Mảng A — Sửa thẻ đầy đủ như web (20/10/2026)

- **Mô tả:** REST chỉ nhận `descriptionJson` (TipTap) — app tự đổi Markdown ⇄ TipTap ở `Shared/CTWork/CTWMoTaThe.swift` (bộ nút =
  bộ của `RichEditor`/`docMarkdown.ts`). Mô tả có nhắc tên/bảng/dấu lạ ⇒ không cho soạn (nói lý do). Tick ô việc ở chế độ đọc sửa
  thẳng JSON THÔ (`CTWJSON` — lossless; ⛔ đừng ghi lại qua `CTWNode`, nó bỏ `attrs`/`marks`). 409 ⇒ giữ nháp, Lưu lần nữa = ghi đè.
- **Một phản hồi, hai model:** `CTWIssueVM` đọc `/issues/:n` và `/projects/:pid` THÔ (`requestRaw` + `CTWAPI.giaiMa`) ⇒ model lõi
  (`CTWIssueDetail`, `CTWProjectConfig` — không sửa) + phần thêm (`CTWIssueThem`, `CTWCauHinhThem`) trong `CTWModels+IssueEdit.swift`.
- **Khối:** `CTWIssueTruongView` (Details/Planning/More, trường tuỳ chỉnh, thời gian) · `CTWIssueMoTaView` · `CTWIssueTheConView` +
  `CTWIssueLienKetView` · `CTWIssueThemView.swift` (Work log, tài liệu, link web, Share to channel, Move to project) · bảng chọn chung
  `CTWBoChonThe.swift`. Menu "…": Clone · Move · Delete (hỏi lại) · Share to channel. Tab: Activity/Comments/History/Work log/Links.
- **Móc app riêng:** `CTWIssueView(moRong: .ctwApp)` (`Modules/IssueEdit/MoRongTheCTW.swift`) cắm `NutGhiGioTheCTW` + mở trang Docs;
  app chính để `nil`.
- **Màn thử:** `the:suamota · the:tick · the:tuychinh · the:thecon · the:lienket · the:ghigio · the:nhatky · the:taothe · the:chiase ·
  the:chuyen` (`Debug/XemThuCTW+SuaThe.swift`). Chụp: `ChupSuaTheUITests` với `TEST_RUNNER_CTW_CHUP_A=<thư mục>`.
- **Không làm (thiếu tuyến / ngoài mảng):** sửa số phút của worklog (máy chủ chỉ PATCH activity/workProduct), "Draft with AI" khi tạo thẻ
  (mảng C + đồng ý 5.1.2(i)), đổi loại thẻ (PATCH từ chối `typeKey`).

## 15. Mảng B — Board · Backlog · List · tìm kiếm · ghim · tên mặc định (21/10/2026)

- **Tên trạng thái/loại MẶC ĐỊNH dịch khi hiển thị** (web `i18n/names.ts`): `CTWTen.trangThai/loai/trangThaiCau` (Shared/CTWork/CTWUI/
  CTWTenMacDinh.swift) + bảng `CTWorkApp/TenMacDinhCTW.xcstrings` (khoá `st.*`/`ty.*`). Chỉ tên mẫu ("To Do", "Story"…); tên tự đặt
  giữ nguyên; ⛔ không bao giờ gửi tên đã dịch lên máy chủ (JQL, đổi trạng thái theo tên). `CTWStatusChip`/`CTWChonTrangThaiMenu` đã áp sẵn.
  Chi tiết thẻ của mảng A cũng đi qua `CTWTen` (tên loại ở đầu thẻ, menu trạng thái + nhãn trợ năng, dòng lịch sử
  "moved from … to …", menu "Change status" của việc con, bộ chọn Loại khi tạo thẻ) — thêm chỗ hiện tên mặc định ⇒ dùng `CTWTen`.
- **Board** (Shared): bộ lọc + chia làn thuần ở `CTWBangNhom.swift` (port `grouping.ts`); nhóm theo/gập làn/gập cột nhớ theo dự án
  (`ctw.bang.<pid>.*`). Epic tải riêng (`GET /issues?type=<epic>&includeDone`), bộ phận khi `modules.teams`.
- **Sửa hàng loạt** dùng chung Board/Backlog/List: `CTWThanhHangLoat` + `CTWHangLoat` (`POST /issues/bulk`, đổi trạng thái THEO TÊN
  mỗi quy trình một lượt — web `board/bulk.ts`). API ở `Shared/CTWork/CTWAPI+KeHoach.swift`.
- **Backlog** = `Modules/Backlog/KeHoachSprintCTW.swift` (ScrollView + `dropDestination` từng hàng; xếp hạng `CTWXepHang` ⇒
  `POST /issues/:n/move {sprintId?, beforeIssueId, afterIssueId}`). **List** = `DanhSachCTW.swift` (JQL `JqlCTW.swift`, bộ lọc đã lưu,
  sắp xếp, trường hiện `ctw.list.cot`, xuất CSV). Tìm mọi dự án = `MyWork/TimKiemNangCaoCTW.swift` (`/search` + `/search/facets`).
- **Ghim** đồng bộ web: `Project/GhimDongBoCTW.swift` (`users.preferences.work.navPins`, cốt lõi = web `coreFor` + `ai`), store
  `GhimMoDunCTW` (ThemMoDunCTW.swift). PATCH chỉ gửi `work.navPins.<pid>`.
- Màn thử: `board` + `CT_XEM_NHOM=assignee|epic|priority|subtasks`, `CT_XEM_LOC=1`, `CT_XEM_CHON=1` · `backlog` + `CT_XEM_DICH=backlog|124`
  · `list` + `CT_XEM_JQL=…` (`CT_XEM_GO=1` mở bàn phím, thấy gợi ý) · `timkiem` · `them`. Dữ liệu mẫu: `Debug/XemThuCTW+DotB.swift`.
- Kiểm thử: `CTWorkTests/DotBTests.swift`.

## 16. Mảng C — AI stream · Create with CuongMini · New project · AI usage (21/10/2026)

- **Trợ lý AI bản stream** (`Modules/AI/LuongAICTW.swift`): `POST /projects/:pid/ai/chat/stream` (hợp đồng
  `api-backend/docs/ctw-ai-stream.md`). `BoDocSSE` tự tách dòng theo byte (⛔ đừng dùng `bytes.lines` — nó nuốt dòng trống,
  mà dòng trống là dấu hết khung). 404/405/501 hoặc không phải `text/event-stream` ⇒ `LuongAICTW.khongCoLuong = true` (nhớ
  trong phiên) ⇒ VM lặng lẽ về `/ai/chat`. Nháp đẩy ~12 lần/giây; `done.reply` thay nháp, đề xuất CHỈ từ `done`, câu hỏi +
  trả lời ghép tại chỗ (không nạp lại). Nút Dừng/rời màn (ngăn xếp NGẮN lại) ⇒ huỷ Task ⇒ đóng kết nối. Hỏi lại = stream với
  `retryMessageId`. Máy chủ giả phát SSE thật, cắt mẩu 23 byte (`Debug/XemThuCTW+LuongAI.swift`); màn thử `mod:ai/doc` ·
  `mod:ai/viet` · `mod:ai/stream` (+ `CT_XEM_LUONG=0` giả tuyến chưa deploy, `CT_XEM_BANG_CUOI=1` mở bảng ở mép phải).
- **Markdown** (`CTWNoiDungView`): bảng = `CTWBangView` (cuộn ngang trong khung riêng, ô dài bọc dòng 90–240 pt, hàng xen
  màu), giãn dòng theo cỡ chữ, `mã` có nền, mục danh sách nhiều dòng gộp, bảng không viền `a | b` + dòng kẻ.
- **Create with CuongMini** (`Modules/TaoCuongMini/`): lối vào là nút **+** của bảng chọn dự án (`ChonDuAnCTW` →
  `MenuTaoMoiCTW`, chỉ vai OWNER/ADMIN/MEMBER) ⇒ `TaoDuAnCTW` (New project) hoặc `TaoCuongMiniCTW` (bản nháp). `input` khai
  đủ trường zod; `understanding`/`plan` giữ JSON thô `CTWJSON` (sửa tại chỗ, gửi lại nguyên vẹn — trường không khai không
  rơi). iOS luôn `reviewFirst = true`. KHÔNG có chọn/mở khoá model (3.1.1). Máy chủ giả: `CT_XEM_MAN=chonduan` +
  `CT_XEM_TAO=duan | cm | cm/dien | cm/dangdoc | cm/hieu | cm/kehoach | cm/xong`.
- **AI usage** (`Modules/AIUsage/`, mô-đun `ai-usage`, nhóm Admin): dự án ⇄ không gian, chỉ đọc, nhãn "ước lượng" / "tự khai"
  như web. Màn thử `mod:ai-usage` · `mod:ai-usage/ws`.
- ⚠️ Chụp màn tiếng Việt khi app ĐÃ có tệp prefs trong container (vd sau khi chạy test): `simctl spawn … defaults write`
  ghi vào miền khác, app vẫn đọc "system" ⇒ sửa thẳng `<container>/Library/Preferences/com.cuongthai.ctwork.plist`
  (khoá có dấu chấm ⇒ dùng `plistlib`, không dùng `plutil -replace`).

## 17. CuongMini — lối vào trợ lý AI (21/10/2026)

Phản hồi chủ app: "không tìm thấy chat AI" (trước đó chỉ là MỘT dòng "AI assistant" giữa ~40 mô-đun). Trợ lý giờ tên
**CuongMini** ("Hỏi CuongMini" / "Ask CuongMini"; mô-đun id vẫn `ai` — ghim `navPins` của web dùng id đó). Mọi lối vào đẩy
`RouteCuongMiniCTW(pid, maDuAn, the, khoiDau)` vào ngăn xếp đang đứng; đích đăng ký ở `MoDunAI.dichDen` ⇒
`TroLyAICTW(pid:maDuAn:the:khoiDau:)`. Mã: `Modules/AI/CuongMiniCTW.swift`.

| Lối vào | Ở đâu |
|---|---|
| Nút ✦ (`NutCuongMiniCTW`, id `cuongmini.toolbar`) | iPhone: cạnh công tắc Board · Backlog · List · More của trang dự án (`TrangDuAnCTW`) — ⛔ không đặt trên thanh điều hướng (Board có 3 nút phải ⇒ đè menu tên dự án). iPad/More tools: màn Board/Backlog (`ManMoDunCTW`) |
| Thẻ nổi bật "Hỏi CuongMini" (`TheCuongMiniCTW`, `cuongmini.card`) | ĐẦU trang More (thay dòng mô-đun "ai" trong danh sách ghim) |
| "Hôm nay tôi nên làm gì?" (`TheCuongMiniCTW(homNay: true)`, `cuongmini.today`) | My Work (dưới công tắc Issues/Agenda) ⇒ CuongMini của `app.luaChon` + hỏi ngay qua chat (KHÔNG `/ai/daily-brief`: tuyến đó viết bản tin cho CẢ NHÓM và ghi đè `settings.dailyBrief`) |
| Nút "CuongMini" trong thẻ (`NutCuongMiniTheCTW`, `cuongmini.issue`) | Hàng trạng thái của `CTWIssueView` — móc `CTWIssueMoRong.nutCuongMini` (Shared; app chính để `nil`) ⇒ bảng: việc một chạm theo loại thẻ + 3 câu gợi ý + "Hỏi câu khác…" |
| Mô-đun "CuongMini" | Thanh bên iPad / More tools như mọi mô-đun |

- **Việc một chạm** = `CuongMini.mucNhanh(loai:)` (port `AiIssueMenu.tsx` `itemsFor`: Summarize luôn có; EPIC ⇒ split "Chia thành story";
  STORY/TASK/BUG ⇒ split; STORY/REQUIREMENT ⇒ generate_tests + review_story; BUG ⇒ improve_bug) ⇒ `POST /ai/quick
  {task, issueNumber, threadId, label}` (`thoiGianCho` 180 s). `label` = nhãn theo ngôn ngữ app. Trả cùng hình dạng `/ai/chat`
  ⇒ `ghep` vào hội thoại (tạo trước, gắn `issueNumber`). Không có bản stream.
- **Ngữ cảnh thẻ** (`TroLyAIVM.the`): mọi câu hỏi + hội thoại mới gửi `issueNumber`; chip "Về NW-12 ✕" trên ô soạn bỏ được;
  mở hội thoại có `issueNumber` ⇒ tự gắn lại. Màn trống đổi sang câu gợi ý về thẻ + việc một chạm.
- **Đồng ý 5.1.2(i)**: việc mở sẵn (`khoiDau`) và việc một chạm cũng đi qua `chay(_:)` ⇒ chưa đồng ý thì hiện `DongYAICTW` trước,
  đồng ý xong mới chạy (`TamPhuAI.dongY(KhoiDauCuongMini)`). Nhãn AI + Report giữ nguyên trên mọi câu trả lời.
- **Markdown câu trả lời dài** (`CTWKhoiView.khoangTruoc`): mục danh sách liền nhau cách 0,4× cỡ chữ, đoạn 0,75×, trước tiêu đề
  1,1× (H1/H2) — danh sách đọc thành một khối, tiêu đề tách phần trên; `1)` đọc như `1.`; tiêu đề nhỏ lại (+6/+3,5/+1,5).
- Màn thử: `mod:ai/homnay` (câu trả lời dài tiếng Việt) · `mod:ai/the` · `mod:ai/nhanh` · `mod:ai/chia` · `the:cuongmini` (mở bảng
  trong thẻ). Máy chủ giả: `/ai/quick` + `AIGia.traLoiHomNay` (`Debug/XemThuCTW+Code.swift`).
- Kiểm thử: `CTWorkTests/CuongMiniTests.swift`; `CTWorkUITests/ChupCuongMiniUITests.swift` (bấm thật các lối vào; chụp khi có
  `TEST_RUNNER_CTW_CHUP_CM=<thư mục>`).
