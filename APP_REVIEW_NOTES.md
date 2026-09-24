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

2b. **Bật đăng nhập Google** (không bắt buộc để nộp, nút tự ẩn khi chưa bật):

   Client OAuth loại **Web** của trang web **KHÔNG dùng lại được**. Google cấm
   app di động giữ `client_secret` — ai cũng mở file `.ipa` ra đọc — nên app
   phải có client loại **iOS**: không secret, ràng danh tính bằng Bundle ID,
   nhận chuyển hướng qua URL scheme riêng. Đưa client Web cho SDK iOS sẽ nhận
   thẳng lỗi `Custom scheme URIs are not allowed for 'WEB' client type`.

   - console.cloud.google.com → **cùng project `650641212127`** (project đang
     chạy Google login của web) → APIs & Services → Credentials
     → Create credentials → OAuth client ID → **iOS**
     → Bundle ID: `com.cuongthai.app` → Create
   - Màn hình hiện ra một **Client ID**, KHÔNG có secret. Chép nó.
   - Mở `CuongThaiApp/iOS/Info.plist`, thay hai chỗ:
     - `GIDClientID` → dán client ID
     - `CFBundleURLSchemes` → dán client ID **đảo ngược**:
       `123-abc.apps.googleusercontent.com` → `com.googleusercontent.apps.123-abc`
   - Không phải sửa dòng mã nào. Chưa dán thì nút Google tự ẩn.

   ⚠️ Backend KHÔNG cần đổi: `/auth/oauth/token` nhận `provider` bất kỳ, đúng
   đường Sign in with Apple đang đi.

   ⛔ **GitHub thì không làm kiểu này được.** GitHub bắt buộc `client_secret`
   để đổi code lấy token và **không hỗ trợ PKCE** cho OAuth App, nên app di
   động không tự làm được — phải thêm một endpoint ở backend đứng ra đổi hộ,
   giống việc NextAuth đang làm cho web.
3. **Backend (chưa đụng theo yêu cầu):** `POST /api/v1/auth/oauth/token` hiện TIN
   email + providerId do client gửi mà không xác minh chữ ký. App đã gửi kèm
   `identityToken` và `authorizationCode` của Apple, nên khi vá backend chỉ cần
   verify token đó — **không phải cập nhật app**. Đây là lỗ hổng có sẵn từ luồng
   Google/GitHub, không phải do đợt sửa này tạo ra.
4. Chuẩn bị **tài khoản demo** (bật Pro) và điền vào App Review Information.
5. Khai App Privacy labels — PHẢI khớp `Resources/PrivacyInfo.xcprivacy`
   (soát 24/09/2026): Email, Tên, ID người dùng, Device ID (push token), Ảnh/
   video, Dữ liệu âm thanh (luyện nói → Groq Whisper), Email hoặc tin nhắn
   (tin nhắn trong app), Nội dung người dùng khác, Thông tin tài chính khác
   (mục Tiền), Vị trí chính xác (chỉ khi tự chia sẻ trong chat) — đều "Linked
   to you", mục đích "App Functionality", **không** dùng để theo dõi.
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

Third-party AI (Guideline 5.1.2(i)):
- A separate consent dialog is shown the first time any AI feature is
  used (Agree / No). If declined, nothing is sent to AI.
- Sent only when the user uses that feature: questions, chat history,
  attachments, related notes (Notes assistant), finance data (Finance AI),
  CV / interview answers / submitted work, and speaking-practice audio
  (uploaded to our server, transcribed by Groq Whisper, not stored).
- Providers: Anthropic (Claude) and OpenAI (GPT) via gateways rambo.ai.vn
  and modelapi.vn; Groq (Whisper).
- Withdraw anytime: Settings > Chính sách bảo mật > "Cho phép gửi dữ liệu tới AI".

Account deletion (Guideline 5.1.1(v)):
  Settings (gear icon on the Profile tab) > Xoá tài khoản (Delete account).
  The account and personal data are erased and cannot be recovered.

Sign in with Apple is offered alongside username/password.

The app contains no purchases, no external purchase links, and no
media downloading of any kind.
```

---

## Cho người duyệt TESTFLIGHT (bản 31 — cập nhật 22/08/2026)

⚠️ Đây là ô **KHÁC** với ô App Store ở trên. Đường đi:
App Store Connect → app CuongThai → tab **TestFlight** → **Test Information**
→ ô **Review Notes** (áp cho vòng duyệt beta bên ngoài).

Cùng trang đó có ô **Privacy Policy URL** — điền:

```
https://cuongthai.com/chinh-sach-bao-mat
```

(Đã kiểm 22/08: trả HTTP 200, 617 chữ, dẫn Nghị định 13/2023/NĐ-CP. Không
phải trang 404 đội lốt 200.)

Tài khoản thử **đã điền sẵn** trong Sign-In Information: `apple_review1` —
đã thử đăng nhập thật vào `https://cuongthai.com/api/v1/auth/login` ngày
22/08, HTTP 200 kèm token.

### Dán nguyên khối dưới đây vào ô Review Notes

```
CuongThai is a Vietnamese-language learning and social platform: video
courses, coding labs, notes, messaging, and foreign-language study
(English, Japanese, Chinese). All content is in Vietnamese.

=== SIGNING IN ===
The app requires an account. Please use the demo account supplied in the
Sign-In Information fields of this submission (username: apple_review1).
Enter it on the first screen.

=== WHAT IS NEW IN BUILD 31 ===
1) Exam Room. Tab "Hoc" (Learn) -> card "Phong thi". 190 timed
   multiple-choice exams. Open any exam, start it, answer the questions,
   then submit to see the score.

2) AI Speaking Practice. Tab "Hoc" -> card "Ngoai ngu" -> choose a
   language -> "Luyen noi". iOS asks for Microphone and Speech Recognition
   permission on first use.
   Language conversation practice uses Apple's SFSpeechRecognizer: on-device
   when the device supports it, otherwise Apple's speech servers. The
   recognized text is sent to the AI tutor to generate a reply.
   IELTS speaking practice (and "shadowing" in video lessons, and voice
   chat with the AI) DOES upload the audio recording: it goes to our server,
   then to Groq (Whisper) for transcription, and the transcript goes to an
   AI model for scoring/replying. The audio is not stored after
   transcription.

=== THIRD-PARTY AI & CONSENT (Guideline 5.1.2(i)) ===
The first time the user uses ANY AI feature, the app shows a separate
consent dialog ("Cho phep gui du lieu toi AI?") listing what is sent and to
whom, with "Dong y" (Agree) / "Khong" (No). If the user taps No, nothing
is sent. Consent can be withdrawn in Settings > Chinh sach bao mat
(Privacy Policy) > toggle "Cho phep gui du lieu toi AI".
What is sent (only when the user uses that feature): questions, chat
history, attached images/files; related notes (Notes assistant); income/
expense data (Finance AI); CV text, interview answers, submitted code or
writing; speaking-practice audio (see above).
Providers: Anthropic (Claude) and OpenAI (GPT) models via the gateways
rambo.ai.vn and modelapi.vn; Groq (Whisper speech-to-text). Data is used
only to produce the requested answer. Passwords and private messages
between users are never sent to AI.

=== WHY EACH PERMISSION IS REQUESTED ===
- Microphone: voice calls, voice messages, recording video, recording a
  study session into the handwriting notebook (stored on device only), and
  IELTS speaking / AI voice practice (uploaded for transcription, see above).
- Speech Recognition: language conversation practice (on-device when
  supported, otherwise Apple's servers).
- Camera and Photo Library: attaching photos or video to posts, setting a
  profile picture, and scanning book pages/documents into the notebook.
- Location: sent only when the user explicitly taps "share location"
  inside a conversation. The app never tracks location in the background.
- Notifications: new messages and incoming calls.

=== MODERATION (Guideline 1.2) ===
- Community rules must be accepted on first launch.
- Every post has a ... menu: Hide, Report, Block author.
- Every comment has a ... menu: Report.
- Blocked users are managed in Settings > Danh sach chan (Blocked list).
- Reports reach a moderation queue and are reviewed within 24 hours.

=== ACCOUNT DELETION (Guideline 5.1.1(v)) ===
Settings (gear icon on the Profile tab) > Xoa tai khoan (Delete account).
The account and personal data are erased and cannot be recovered.

=== OTHER ===
- Sign in with Apple is offered alongside username/password.
- The app contains no purchases, no external purchase links, and no media
  downloading of any kind.
- 1-to-1 voice calling needs two accounts signed in on two devices, so it
  may not be fully exercisable with a single reviewer account. Every other
  feature works with the demo account alone.

Contact: cuongthaihnhe176322@gmail.com
```

### ⚠️ Vì sao phải dán tay

Khoá API `SW4TM47WHC` **đọc được mọi thứ nhưng KHÔNG ghi được**. Đo thật
22/08: `GET` apps / builds / betaAppReviewDetail / users đều 200, còn
`PATCH betaAppReviewDetails` và `PATCH betaAppLocalizations` đều trả
**403 `FORBIDDEN_ERROR` — "The API key in use does not allow this request"**.
Nó đủ quyền `altool --upload-app` nhưng không đủ quyền sửa metadata.

Muốn tự động hoá về sau thì tạo khoá mới vai trò **App Manager** (hoặc
Admin) ở Users and Access → Integrations, rồi cập nhật `phat-hanh.env`.
