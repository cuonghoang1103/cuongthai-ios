# App CT Work iOS — KIẾN TRÚC (đọc trước khi thêm mô-đun)

Target `CTWorkApp` · bundle `com.cuongthai.ctwork` · tên hiển thị "CT Work" · iOS 17+ · iPhone + iPad.
Giao diện **chỉ tiếng Anh** (quyết định sản phẩm của CT Work); chú thích mã tiếng Việt.
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
| Nhóm thanh bên | — | Project · Communication · Planning · Docs & knowledge · Admin |

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

Luật màu: CHỈ `AppColors.*` (tự đổi sáng/tối). Biểu tượng: SF Symbols. Chạm tối thiểu 44pt.
Chữ trong `ScrollView(.horizontal)` phải `.fixedSize` (bẫy cắt chữ). Một view chỉ MỘT
`.sheet` — nhiều tấm phủ thì `.sheet(item:)` + enum, hoặc gắn ở view con khác (CLAUDE.md C5).

## 5. Lõi: mạng · lỗi · phân trang · realtime · thông báo

- **Mạng:** `APIClient.shared.request(CTWAPI.x(...))` (giải mã `data` của envelope), `.send(...)`
  (chỉ cần `success`). Đường dẫn CT Work đi qua `APIEndpoint.workGoi` — nơi gọi không gõ chuỗi.
  Header `X-Client-Platform: ios` tự gắn (máy chủ bỏ lời mời mua cho iOS).
- **Lỗi:** `CTW.loi(error)` ra câu tiếng Anh cho người dùng; `CTW.laXungDot(error)` (409 phiên bản
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
- Chữ hiện cho người dùng: TIẾNG ANH. Chú thích: tiếng Việt, giải thích VÌ SAO.
- Model API: `var` + optional; ngày `String` (đọc bằng `CTW.ngay`, `CTW.thoiDiem`, `CTWChatThoiGian`).
- Nhật ký chẩn đoán: chỉ trong `#if DEBUG`.
