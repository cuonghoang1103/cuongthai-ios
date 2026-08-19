# App Review Notes — CuongThai iOS

Dán phần "Cho người duyệt" xuống dưới vào ô **App Review Information → Notes**
trong App Store Connect. Phần trên là ghi chú kỹ thuật cho chính mình.

---

## 1. Những gì đã sửa cho vòng duyệt đầu (19/08/2026)

| Guideline | Vấn đề | Đã làm |
|---|---|---|
| 4.8 Login Services | Backend có Google/GitHub OAuth nhưng app không có lựa chọn riêng tư | Thêm **Sign in with Apple** (`Shared/Auth/AppleSignIn.swift`) + entitlement |
| 5.1.1(v) Account Deletion | Không có đường xoá tài khoản trong app | **Cài đặt → Xoá tài khoản** (`Shared/Views/AccountViews.swift`) |
| 1.2 UGC | Không có báo cáo / chặn / EULA | Báo cáo bài + bình luận, ẩn bài, chặn người dùng, danh sách chặn, màn hình đồng ý quy tắc khi mở app lần đầu (`ModerationStore.swift`, `ModerationViews.swift`, `LegalViews.swift`) |
| 5.2.3 Media downloading | Module nhạc lấy audio từ YouTube | **Đã gỡ `MusicView.swift`** và mọi endpoint `/music/*` khỏi app. Sticker nhạc trong bài viết chỉ hiển thị tên bài, KHÔNG phát, KHÔNG tải |
| 3.1.1 IAP | Bề mặt thương mại | **Đã gỡ `ShopView.swift`**. App không hiện giá, không có nút mua, không link ra trang mua ngoài |
| 2.1 App Completeness | 8 màn hình placeholder chỉ có một dòng chữ; ảnh đăng lên là URL giả `example.com/placeholder.jpg`; menu ••• không làm gì | Viết thật: Sửa hồ sơ, Đổi mật khẩu, Điều khoản, Bảo mật, Trợ giúp, Danh sách chặn; **upload ảnh thật** qua `POST /api/v1/files/upload`; menu ••• hoạt động |
| 2.5 / ổn định | `Info.plist` khai `SceneDelegate` không tồn tại | Bỏ khỏi `UIApplicationSceneManifest` |
| Bảo mật | Token nằm ở `UserDefaults` | Chuyển sang **Keychain** (`KeychainStore.swift`), có migration một lần cho bản cũ |
| — | Mô tả quyền micro sai mục đích, khai `NSFaceIDUsageDescription` mà không dùng Face ID | Viết lại cả 3 chuỗi mục đích, bỏ chuỗi Face ID, thêm `ITSAppUsesNonExemptEncryption=false` |

Tab bar giờ là: **Trang chủ · Học · Tạo · Tin nhắn · Cá nhân**
(Tìm kiếm và Ghi chú chuyển lên thanh công cụ của Trang chủ).

## 2. Việc CÒN LẠI phải làm trước khi bấm Submit

1. **Bật "Sign in with Apple" cho App ID** trong Apple Developer portal
   (Certificates, IDs & Profiles → Identifiers → `com.cuongthai.app` → Capabilities).
   Không bật thì build sẽ trượt bước provisioning.
2. Đặt `DEVELOPMENT_TEAM` trong `project.yml` (đang để trống) rồi chạy `xcodegen generate`.
3. **Backend (chưa đụng theo yêu cầu):** `POST /api/v1/auth/oauth/token` hiện TIN
   email + providerId do client gửi mà không xác minh chữ ký. App đã gửi kèm
   `identityToken` và `authorizationCode` của Apple, nên khi vá backend chỉ cần
   verify token đó — **không phải cập nhật app**. Đây là lỗ hổng có sẵn từ luồng
   Google/GitHub, không phải do đợt sửa này tạo ra.
4. Chuẩn bị **tài khoản demo** (bật Pro) và điền vào App Review Information.
5. Khai App Privacy labels: Email, Tên, Ảnh, Nội dung người dùng, ID người dùng —
   đều "Linked to you", mục đích "App Functionality", **không** dùng để theo dõi.
6. Phân loại độ tuổi: khai có nội dung do người dùng tạo + chat AI.

## 3. Đã kiểm thật (không phải đọc mã)

- `xcodebuild -scheme CuongThaiApp` → **BUILD SUCCEEDED**
- `xcodebuild -scheme CuongThaiAppMac` → **BUILD SUCCEEDED** (target macOS không vỡ)
- Chạy trên iPhone 17 Pro (iOS 26): màn hình đồng ý quy tắc hiện đúng → bấm
  "Tôi đồng ý" → màn đăng nhập có nút **Sign in with Apple** → mở được
  **Điều khoản sử dụng**.
- **CHƯA kiểm được** (cần tài khoản thật): báo cáo/chặn, danh sách chặn, xoá tài
  khoản, đổi mật khẩu, upload ảnh. Cần đăng nhập một lần trước khi nộp.

---

## Cho người duyệt (dán vào App Review Notes)

```
Demo account:
  Username: <điền>
  Password: <điền>

CuongThai is a learning + community app for Vietnamese IT students.
Courses, coding lessons, notes, a social feed and direct messages.

Moderation (Guideline 1.2):
- Community rules must be accepted on first launch.
- Every post has a ••• menu: Hide, Report, Block author.
- Every comment has a ••• menu: Report.
- Blocked users are managed in Settings > Danh sách chặn (Blocked list).
- Reports reach a moderation queue and are reviewed within 24 hours.
- Contact: cuongthaihnhe176322@gmail.com

Account deletion (Guideline 5.1.1(v)):
  Settings (gear icon on the Profile tab) > Xoá tài khoản (Delete account).
  The account and personal data are erased and cannot be recovered.

Sign in with Apple is offered alongside username/password.

The app contains no purchases, no external purchase links, and no
media downloading of any kind.
```
