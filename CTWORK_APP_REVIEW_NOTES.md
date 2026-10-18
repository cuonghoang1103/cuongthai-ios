# App Review Notes — CT Work iOS (`com.cuongthai.ctwork`)

Phần đầu (tiếng Việt) là ghi chú cho chủ app. Khối **"Cho người duyệt"** (tiếng Anh)
dán nguyên vào App Store Connect → App Review Information → Notes.
Kiến trúc mã: `CuongThaiApp/CTWorkApp/KIEN_TRUC.md`.

---

## 1. App này là gì (để trả lời 4.3 — mục đích riêng)

App quản lý công việc nhóm: My Work, bảng kéo thả, backlog/sprint, danh sách có lọc,
chi tiết thẻ (sửa trạng thái/người làm/ưu tiên/hạn, bình luận, đính kèm, lịch sử, thẻ con,
liên kết), tạo thẻ nhanh, hộp thư thông báo (lọc/gộp theo thẻ-kênh, trả lời + duyệt ngay,
nút hành động trên thông báo), chat nhóm theo kênh + nhóm riêng (realtime, ảnh/tệp/voice
note, cảm xúc, @nhắc, ghim, tìm, chuỗi trả lời, "đang gõ", hàng chờ ngoại tuyến), cuộc họp
(lịch, vào họp Meet/Zoom/Teams/Jitsi, RSVP, chương trình, biên bản, quyết định, việc ⇒ thẻ,
bản ghi lời, thêm vào Lịch), đọc + tìm tài liệu dự án, deep link `ctwork://` + thông báo đẩy. Không có mạng xã hội, khoá học, nhạc,
tiền nong… của app chính ⇒ không phải bản sao app CuongThai.
Mảng D (18/10/2026) — thứ CHỈ app gốc làm được: widget "My work today" + "Timer" (Màn hình chính + Màn hình khoá),
Live Activity đồng hồ bấm giờ (Dynamic Island, nút Pause/Stop), Siri/Shortcuts ("What's on my plate in CT Work",
"Start a CT Work timer on NW-12", "Stop my CT Work timer"), Share Extension (ảnh/link/chữ ⇒ tạo thẻ hoặc bình luận),
Spotlight (thẻ đã xem gần đây), khoá Face ID (tuỳ chọn, mặc định tắt).

## 2. Luật Apple đã đáp ứng

| Guideline | Làm gì | Ở đâu |
|---|---|---|
| 3.1.1 / 3.1.3(b) | Không giá, không nút mua/nâng cấp, không link ra trang mua. Tài chính dự án CHỈ XEM (ngân sách, chi phí, mốc chỉ hiện trạng thái) — không nút/link thanh toán; không CRM. Cổng khách KHÔNG hiện mục thanh toán. Header `X-Client-Platform: ios` để máy chủ bỏ lời mời mua trong câu lỗi | toàn app (đã grep chuỗi "Pro", "upgrade", "price", "buy", "payment") |
| 4.3 | Mục đích riêng: quản lý công việc nhóm; bundle, biểu tượng, tên riêng | `project.yml` target CTWorkApp |
| 2.1 | Mọi màn chạy thật, không placeholder; mô-đun chưa làm KHÔNG hiện mục (bảng đăng ký mô-đun) | `Core/CTWDangKyMoDun.swift` |
| 4.8 | Sign in with Apple (cạnh tài khoản cuongthai.com) | `Modules/Account/DangNhapCTW.swift` + entitlement |
| 5.1.1(v) | Xoá tài khoản trong app: Account → Delete account (cùng luồng máy chủ với app chính, 72 giờ, rút lại được) | `Modules/Account/TaiKhoanCTW.swift` |
| 1.2 | (1) đồng ý quy tắc cộng đồng lần đầu; (2) báo cáo bình luận, tin chat (kênh + chuỗi), ghi chú/biên bản cuộc họp; (3) chặn người dùng (ẩn mọi bình luận/tin/thông báo/ghi chú họp của họ); (4) liên hệ: Account → Help & contact; nội dung đã báo cáo ẩn ngay | `DongYQuyTacCTW`, `CTWKiemDuyet.swift`, `Modules/Chat/KenhChatCTW.swift` + `ChuoiTraLoiCTW.swift`, `Modules/Meetings/ChiTietHopCTW.swift`, `CTWorkIssueView.swift` |
| 4.7 / 1.2 (AI) | Thành viên AI agent luôn có nhãn "AI agent" + ✦ trên avatar ở bình luận, chat, người làm, lịch sử, bộ chọn người, gợi ý @nhắc, thành viên kênh, người dự họp, hộp thư; bình luận AI soạn có nhãn "AI-drafted"; bản nháp biên bản họp do AI đề xuất có nhãn "AI-generated" + câu "check before applying"; bản phiên âm voice note có nhãn "Auto transcript"; báo cáo được như mọi nội dung | `CTWNhanAI`, `CTWAvatar`, `ChiTietHopCTW.banNhapAI`, `GiongNoiChatCTW` |
| 5.1.2(i) | App không gọi AI. NGOẠI LỆ DUY NHẤT: voice note trong chat — máy chủ gửi âm thanh cho **Groq** (chuyển giọng nói thành chữ) để đồng đội đọc được. Trước lần ghi ĐẦU TIÊN app hiện hộp "Voice notes are transcribed" nói rõ tên Groq và mục đích; chỉ ghi khi người dùng bấm "Allow and record". App KHÔNG gọi "đề xuất biên bản AI" / "gợi ý việc AI" (các nút đó chỉ có trên web). Agent do admin workspace thêm trên web — ghi rõ ở Privacy + chọn người làm. ⚠️ Chủ app: thêm Groq vào Privacy Policy (mục bên thứ ba) | `Modules/Chat/GhiAmCTW.swift` (`CongBoGiongNoiCTW`), `SoanTinCTW.swift`, `TrangPhapLyView` |
| 5.1.1 / 5.1.2 | `PrivacyInfo.xcprivacy` riêng (UserDefaults CA92.1, FileTimestamp C617.1; dữ liệu thu: email, tên, user ID, device ID, ảnh/tệp, **âm thanh (voice note)**, tin nhắn, nội dung khác — đều Linked, không tracking). HAI chuỗi quyền: máy ảnh (chụp ảnh đính kèm thẻ/tin chat) và **micro (chỉ khi ghi voice note chat)**. Chọn ảnh = PhotosPicker (không cần quyền), chọn tệp = fileImporter. Họp video mở app Meet/Zoom/Teams/Jitsi (hoặc Safari) bằng hệ thống ⇒ KHÔNG camera/micro cho cuộc gọi, KHÔNG VoIP/CallKit, KHÔNG background mode. "Add to Calendar" = EventKitUI ngoài tiến trình ⇒ KHÔNG quyền Lịch | `CTWorkApp/PrivacyInfo.xcprivacy`, `Info.plist` |
| 3.1.1 (web trong app) | Lối "Open CT Work on the web" chung ĐÃ GỠ (Account, Help, trang Projects). Lối web còn lại (trình soạn Docs đầy đủ, sơ đồ, SRS, Wiegers, dashboard) mở bằng `TrinhDuyetCuongThaiCTW` (WKWebView) — CHẶN điều hướng tới `/pro`, `/pricing`, `/checkout`, `/nang-cap`, cổng thanh toán, và ẨN mọi link trỏ tới đó (web CT Work có nút "Upgrade to Pro" ở bảng AI/agent/báo cáo tuần). Không câu nào bảo "mua trên web" | `Modules/Account/TrinhDuyetCTW.swift` |
| 5.1.1 Face ID | `NSFaceIDUsageDescription` — CHỈ vì khoá Face ID tuỳ chọn (Account → Security, mặc định TẮT, lùi về mật mã máy) | `Modules/Account/KhoaAppCTW.swift` |
| Widget / Share / Spotlight | Bản sao dữ liệu CỦA CHÍNH người dùng, chỉ trên máy (App Group `group.com.cuongthai.ctwork`): việc hôm nay, đồng hồ, dự án, thẻ đã xem (chỉ mã + tiêu đề vào chỉ mục Spotlight). Widget không gọi mạng. Share Extension đọc token từ Keychain chia sẻ. Đăng xuất ⇒ xoá hết + xoá chỉ mục Spotlight + kết thúc Live Activity | `CTWorkShared/NhomCTW.swift`, `App/ChiaSeNhomCTW.swift` |
| ITSAppUsesNonExemptEncryption | `false` | `Info.plist` |
| 2.3 / A6 | Cửa xem màn `CT_XEM_MAN` + máy chủ giả CHỈ trong `#if DEBUG` — đo bản Release: `grep -a -c CT_XEM_MAN` = 0 | `Debug/XemThuCTW.swift` |
| 4.2 | Ứng dụng gốc SwiftUI (bảng kéo thả, chat realtime, Xem nhanh tệp, thông báo đẩy). Chỉ một lối "Open project on the web" (SFSafariViewController) cho công cụ nặng — không dùng để mua |  |
| C12 iPad | Bố cục iPad riêng (NavigationSplitView, thanh bên theo nhóm), đủ 4 hướng |  |

## 3. Việc CHỦ APP phải làm trước khi nộp

**Apple Developer (Certificates, IDs & Profiles → Identifiers):**
1. Tạo App ID `com.cuongthai.ctwork` (team UR32PFUQ38), bật **Sign in with Apple**,
   **Push Notifications**, **Associated Domains**, **App Groups** (`group.com.cuongthai.ctwork`). Tạo thêm App ID cho hai
   extension: `com.cuongthai.ctwork.widget` và `com.cuongthai.ctwork.share` — cả hai bật **App Groups** (cùng group).
   Tạo App Group `group.com.cuongthai.ctwork` (Identifiers → App Groups). Keychain Sharing KHÔNG cần bật trên portal
   (nhóm keychain tiền tố đội tự hợp lệ). Chi tiết bảng ở mục 8.
2. (Sign in with Apple) gộp vào cùng nhóm "primary App ID" với `com.cuongthai.app` nếu muốn
   cùng một Apple ID đăng nhập ra cùng tài khoản ở hai app (Apple trả cùng `user` cho các app
   trong một nhóm).

**App Store Connect:**
3. Tạo app mới "CT Work", bundle `com.cuongthai.ctwork`, SKU tuỳ ý, ngôn ngữ chính English,
   danh mục **Productivity** (phụ: Business).
4. Privacy Policy URL `https://cuongthai.com/chinh-sach-bao-mat`; **Support URL** (bắt buộc).
5. App Privacy: khai ĐÚNG danh sách ở `PrivacyInfo.xcprivacy` — Email, Name, User ID,
   Device ID, Photos or Videos, **Audio Data** (voice note → Groq phiên âm), Emails or Text Messages, Other User Content;
   Linked, không Tracking, App Functionality. ⚠️ Audio Data hay bị quên — đã có trong bản khai, phải khai cả trên ASC.
6. Age rating: có **nội dung người dùng tạo** (chat/bình luận) — khai trung thực.
7. Ảnh màn hình: iPhone 6.9" và iPad 13" (chụp bằng `CT_XEM_MAN`, xem KIEN_TRUC.md mục 7).
8. Tài khoản demo + dữ liệu demo (mục 4), điền vào Sign-In Information.
9. Sau khi có Apple ID của app: điền `MoAppCTWork.appStoreID` (Shared/CTWork/MoAppCTWork.swift).
10. Nộp: archive scheme `CTWorkApp` (Release), `ExportOptions.plist` hiện tại dùng được
    (kiểm `manageAppVersionAndBuildNumber = false`), kiểm IPA: `aps-environment = production`.

## 4. Tài khoản demo + dữ liệu demo (KHÔNG tự sửa DB production)

Reviewer cần MỘT tài khoản đã vào một workspace có dữ liệu. Đề xuất (phiên chính/chủ app làm
trên web, không cần chạm DB):
1. Tạo tài khoản `apple_review_ctw` (hoặc dùng lại `apple_review1`), xác thực email.
2. Đăng nhập web → CT Work → tạo workspace "CT Work Demo" → tạo dự án Scrum "Demo App" (mã DEMO)
   → nút **Add sample data** (`POST /projects/:pid/sample-data`) để có sprint, thẻ, nhãn.
3. Thêm tay: 3–4 bình luận trên một thẻ, 1 ảnh đính kèm, 1–2 trang Docs (bật mô-đun Docs),
   kênh #general có vài tin, giao 3–4 thẻ cho tài khoản demo (để My Work có dữ liệu, có 1 thẻ quá hạn).
4. (Tuỳ chọn) thêm một AI agent vào workspace để reviewer thấy nhãn "AI agent".
5. Thêm tài khoản thứ hai (thành viên) để bình luận/tin của "người khác" có nút Report/Block.

---

## Cho người duyệt (dán vào App Review Notes)

```
CT Work is a team work-management app (issues, boards, sprints, comments,
team chat and project docs) for teams that use CT Work on cuongthai.com.

=== SIGNING IN ===
Use the demo account in the Sign-In Information fields. It belongs to the
"CT Work Demo" workspace, which already contains a project with a sprint,
issues, comments, files, chat messages and documents.
Sign in with Apple is also offered.

=== WHAT TO TRY ===
- My Work: issues assigned to you, grouped by due date.
- Projects > Board: touch and hold a card, then drag it to another column
  (or use the card's context menu "Move to...").
- Projects > Backlog & issues: sprints, backlog, and "All issues" with filters.
- Open any issue: change status / assignee / priority / due date, add a
  comment, attach a photo or file (+ next to Attachments), see History.
- Chat tab: team channels and private groups. Send a message, a photo, a
  file or a voice note; react, pin, search, reply in a thread. Messages
  typed while offline are queued and sent when the connection returns.
- Projects > Meetings: upcoming meetings, RSVP, "Join with Google Meet /
  Zoom / Teams / Jitsi" (opens that app or Safari), notes, decisions,
  action items -> "Create issues", transcript, Add to Calendar.
- Inbox: CT Work notifications (assignments, mentions, replies, approvals,
  alerts). Reply, Approve / Reject and Mark as read right from the inbox.
- Projects > Docs: read, search, create and edit pages (formatting bar,
  photos from the camera or Photos, issue links), version history, comments.
  The editor never overwrites a teammate's newer edit: it shows a conflict
  screen instead.
- Projects > Approvals: approve or reject (a comment is required to reject).
- Projects > Tests: open a test cycle, run a test step by step
  (Pass / Fail / Blocked), attach a photo as evidence, create a bug from a
  failed step.
- Projects > Change requests, RAID, Reviews, Requirements, Service desk,
  Team, AI agents, Diagrams (pinch to zoom), Finance (read-only).
- My Work > Agenda: today and the next two weeks across all projects
  (due dates, meetings with a Join button, sprint and release dates).
- Time tracking: start a timer on an issue; it appears as a Live Activity on
  the Lock Screen / Dynamic Island with Pause and Stop buttons.
- Widgets: add "My work today" or "Timer" from the Home Screen widget gallery.
- Siri / Shortcuts: "What's on my plate in CT Work", "Start a CT Work timer",
  "Stop my CT Work timer".
- Share sheet: share a photo, link or text from another app to "CT Work" to
  create an issue or comment on a recent issue.
- Spotlight: issues you opened recently can be found from Home Screen search.
- Account > Security: optional Face ID lock (off by default).

=== USER-GENERATED CONTENT (Guideline 1.2) ===
- Community rules must be accepted on first launch.
- Comments: touch and hold > Report comment / Block user.
- Page comments, approval comments, ticket replies, class stream comments,
  intake messages and form responses: touch and hold > Report / Block.
- Chat messages (channels and threads): touch and hold > Report message /
  Block user.
- Meeting notes: Meetings > open a meeting > ... > Report notes / Block.
- Reported content is hidden for the reporter immediately; reports reach our
  moderation queue and are reviewed within 24 hours.
- Blocked users: Account > Blocked users & hidden content.
- Contact: Account > Help & contact (cuongthaihnhe176322@gmail.com).

=== AI AGENTS (Guideline 4.7) ===
Workspace admins can add AI agents as members on the web. Anything an agent
writes is labelled "AI agent" (and a sparkle badge on its avatar) everywhere
in the app, and can be reported like any other content. The app itself does
not send user data to any third-party AI service.

=== ACCOUNT DELETION (Guideline 5.1.1(v)) ===
Account tab > Delete account. The account and personal data are erased 72
hours after the request (the user can cancel within that window).

=== OTHER ===
- No purchases, prices or external purchase links anywhere in the app.
  Accounts are free.
- Camera permission is requested only when the user taps "Take Photo" to
  attach a picture to an issue or chat message. Photo Library uses the
  system picker.
- Microphone permission is requested only when the user taps the microphone
  to record a voice note in chat. Before the first recording the app asks
  for consent: voice notes are transcribed by Groq (a third-party
  speech-to-text service). Video meetings open in Google Meet / Zoom /
  Teams / Jitsi (or Safari); the app itself does not access the camera or
  microphone for calls.
- Add to Calendar uses the system event editor; no calendar permission.
- Push notifications: assignments, mentions, comments, approvals and meeting
  reminders. Long-press a notification to Reply, Approve / Reject or Join the
  meeting. Which ones you get is set in Inbox > ... > Notification settings.
- Face ID is used only if the user turns on the optional app lock
  (Account > Security). It is off by default.
- Widgets, Siri and Spotlight use a copy of the user's own data stored on the
  device only; signing out deletes it.
- There are no purchases in the app. Pages opened from the app on
  cuongthai.com hide and block any upgrade or payment links.
- iPad uses a dedicated split-view layout.
```

## 5. Phần BACKEND còn thiếu / nên có (không sửa ở phiên app)

> **Cập nhật 18/10/2026 (phiên backend):** mục đánh dấu ✅ đã có trong mã backend — ĐÃ LÊN PROD (commit `d9c35114`
> của `api-backend`, migration `20261018120000_work_notify_push_prefs`).
> Test: `WORK_DB_TEST=1 npx tsx --test src/routes/work.ios.db.test.ts` (11 bước xanh) + `src/services/push/goiDayCtw.test.ts`.
>
> **Cập nhật 18/10/2026 (phiên app):** mọi mục ✅ đã NỐI vào app (đánh dấu **📱 app đã nối**). Máy chủ giả
> (`Debug/XemThuCTW+D.swift`, `+GiaoTiep.swift`) theo đúng hình dạng service; kiểm thử `CTWorkTests/MangDTests.swift`.
> Tóm tắt nối:
> - Hộp thư/huy hiệu: `?surface=work`, `unread-count?surface=work`, "Read all" = `PATCH {all, surface:'work'}`.
> - Đẩy: thêm category `CTW_MEETING` (nút **Join** mở `meetingUrl`, chỉ http/https); `approvalId` đọc ở gói đẩy (lùi tìm
>   2 trang `surface=work` nếu thiếu); hộp thư có nút "Join meeting" cho nhắc họp.
> - Cài đặt: "Push me about" (6 công tắc `push.*`) + "Use this device's time zone" (`timezone` IANA / null).
> - Báo cáo (1.2): `POST /work/report` cho chat_message, page_comment, retro_card, change_request, raid_item,
>   approval_step, intake_message, form_answer, class_comment, diagram_comment; họp qua `POST /meetings/:num/report`.
>   CÒN đi đường chung cũ (máy chủ CHƯA có kind): mô tả ticket service desk, mô tả phê duyệt, bình luận bài nộp lớp học.
> - Docs: PATCH gửi `baseVersion` (bỏ flush+GET+so tay); 409 `WORK_PAGE_CONFLICT` ⇒ màn "This page changed while you were
>   editing" với Reload / Compare (diff theo dòng) / lưu bản mình thành trang con / chép chữ.
> - My Work → tab **Agenda** (`/me/agenda` 14 ngày, mọi dự án); Calendar dùng `/me/agenda` (−30…+89 ngày, trần 120), lùi
>   cách gộp cũ khi lỗi. Time → "My week" = `/me/timesheet` (mọi dự án, trạng thái phiếu theo dự án), lùi `reports/time`.
> - Chat: "New direct message" (`POST /chat/dm`), mục "Direct messages" đổi tên `dm-<a>-<b>` thành tên người kia; 403
>   `USER_BLOCKED` báo rõ. Dashboard: `GET /dashboards/:id` (deep link + làm mới khi mở). Yêu cầu SWR: `GET /swr/requirements/:num`.

**Chung / nền**
- ✅ 📱 `GET /social/notifications?surface=work` (chỉ `WORK_*`; `unreadCount` đi kèm cũng theo bề mặt) +
  `GET /social/notifications/unread-count?surface=work` ⇒ `{unreadCount}`. Thêm `surface=social` (mọi thứ trừ WORK_*) và
  `PATCH /social/notifications {all:true, surface:'work'}` (chỉ đánh dấu đọc thông báo CT Work).
  ⇒ App: bỏ vòng tải 4–6 trang tự lọc, gọi thẳng `?surface=work`.
- ✅ `sender.kind` (`HUMAN`|`AGENT`) có trong danh sách thông báo + sự kiện socket `social:notification`.
- `apple-app-site-association` CHƯA có (`frontend/public/.well-known/` chỉ có security.txt) ⇒
  Universal Link chưa chạy. Cần phục vụ `/.well-known/apple-app-site-association`
  (`application/json`, không redirect) với `applinks.details[].appIDs = ["UR32PFUQ38.com.cuongthai.ctwork"]`,
  `components: [{"/": "/work/*"}]`, và nginx cho đi qua. App đã khai `applinks:cuongthai.com`.
- `POST /auth/oauth/token` KHÔNG xác minh `identityToken` của Apple (lỗ hổng có sẵn từ trước —
  ai cũng POST email bất kỳ được). App đã gửi `identityToken` + `authorizationCode`; cần verify
  chữ ký JWKS Apple, `aud` ∈ {`com.cuongthai.app`, `com.cuongthai.ctwork`}.
- Push app CT Work: phiên chính đang làm trường `app` ở `/devices` + topic theo app (chưa deploy).

**A — Chat / Họp / Thông báo** (cập nhật 18/10/2026 — app ĐÃ làm phần của mình, chờ máy chủ)
1. ✅ 📱 app đã nối. **Nút trên thông báo đẩy (cần nhất).** Máy chủ đã gửi `aps.category` + `thread-id` + khoá ngoài cùng
   (`src/services/push/goiDayCtw.ts`, cắm ở `notification.service.ts → dayRaNgoaiApp`): `CTW_REPLY` (WORK_COMMENT/WORK_MENTION
   có `url`, cả tin chat), `CTW_APPROVAL` (chỉ khi người nhận còn bước PENDING tới lượt — tính lúc đẩy) + `approvalId` (luôn có
   khi thông báo thuộc một phê duyệt), `CTW_MEETING` + `meetingUrl` (nhắc họp có link), `CTW_DEFAULT` còn lại. `thread-id` =
   `ctw-<issueKey>` / `ctw-<KEY>-chat-<cid>`. ⇒ App: đăng ký thêm category `CTW_MEETING` (nút Join đọc `meetingUrl`).
   Mô tả gốc: App đã đăng ký 3 category + xử lý nền
   (`Modules/Inbox/HanhDongThongBaoCTW.swift`). Máy chủ chỉ cần thêm vào gói APNs
   (`push/apns.ts` `NoiDungDay` + `notification.service.ts → dayRaNgoaiApp`):
   - `aps.category`: `CTW_REPLY` cho WORK_COMMENT / WORK_MENTION có `url`; `CTW_APPROVAL`
     cho WORK_ALERT có `payload.approvalId` mà người nhận là người duyệt đang chờ;
     `CTW_DEFAULT` cho WORK_* còn lại.
   - `approvalId` ở cấp ngoài cùng của `duLieu` (cạnh `thongBaoId`, `duongDan`) — thiếu thì app
     tự lục 4 trang thông báo để tìm, chậm hơn.
   - `thread-id`: `ctw-<issueKey>` / `ctw-<projectKey>-chat-<cid>` thay cho `xh-WORK_*` ⇒ iOS
     xếp chồng theo thẻ/kênh như hộp thư gộp của app.
   Không cần route mới: Trả lời dùng `POST …/issues/:n/comments {bodyJson, parentId}` hoặc
   `POST …/chat/channels/:cid/messages {body, parentId, clientKey}`; Duyệt dùng
   `POST /projects/:pid/approvals/:aid/decide {decision}`; Đã đọc dùng `PATCH /social/notifications {ids}`.
2. ✅ 📱 app đã nối. **Lọc thông báo theo bề mặt:** `GET /social/notifications?surface=work` (+ `GET …/unread-count?surface=work`
   ⇒ `{unreadCount}`) — app đang tải tối đa 4–6 trang rồi tự lọc `WORK_*` để đếm huy hiệu.
3. ✅ 📱 app đã nối. **Báo cáo tin chat:** `POST /projects/:pid/chat/channels/:cid/messages/:mid/report {reason, detail?}` ⇒
   `{reported, duplicate}` (201). `reason` ∈ spam|harassment|hate|sexual|violence|other. Ghi hàng chờ BAO_CAO của quản trị
   (chống trùng theo người) + audit + WORK_ALERT cho ADMIN dự án. Tin đã báo ⇒ trong `GET …/messages` mang
   `reportedByMe/hiddenForMe: true` (chỉ với người báo). ⇒ App: đổi `BaoCaoTinCTW` sang route này (giữ ẩn tại chỗ).
   Mô tả gốc: `POST /projects/:pid/chat/channels/:cid/messages/:mid/report {reason, detail?}` ⇒
   `{reported: true}` (audit + WORK_ALERT cho admin dự án, ẩn tin cho người báo cáo). Hiện đi đường chung
   `/academy/advisor/report-answer` (`BaoCaoTinCTW.swift` — đổi MỘT chỗ).
4. ✅ 📱 app đã nối. **Báo cáo ghi chú cuộc họp:** `POST /projects/:pid/meetings/:num/report {reason, detail?}` (khoá sửa không chặn).
   Mô tả gốc: `POST /projects/:pid/meetings/:num/report {reason, detail?}` ⇒ `{reported: true}`.
   Hiện cũng đi đường chung (`ChiTietHopCTW.guiBaoCao`).
5. ✅ (một phần) **Chặn áp phía máy chủ:** người nhận đã chặn người gửi ⇒ KHÔNG chuông/đẩy/email cho WORK_COMMENT /
   WORK_MENTION (thẻ + chat) của người đó; chat: không âm/toast/đẩy; tin chat + bình luận thẻ của người bị chặn mang cờ
   `authorBlocked/hiddenForMe` (không bị xoá khỏi danh sách để luồng/phân trang đúng — app thu gọn theo cờ). Giao việc /
   phê duyệt / nhắc hạn vẫn tới. CHƯA áp: ghi chú họp, bình luận trang/sơ đồ/lớp (app vẫn lọc phía máy). Mô tả gốc: `/messages/blocks` chưa áp vào chat/bình luận/ghi chú họp/thông báo CT Work
   (app lọc phía máy).
6. ✅ 📱 app đã nối. **Push tin chat thường:** tin GỐC (không phải trả lời luồng) ở kênh đặt ALL, người nhận không bị @/trả lời ⇒ đẩy
   CHỈ tới app CT Work (không dòng hộp thư), `duongDan = chatUrl`, `category = CTW_REPLY`, `kieu = 'WORK_CHAT'`, không có
   `thongBaoId`; tôn trọng tắt tiếng kênh/toàn bộ, giờ im lặng, chế độ MENTIONS và công tắc `push.chatAll`. Mô tả gốc: kênh đặt `notify = ALL` mà tin không @/không trả lời ⇒ hiện chỉ có socket
   `work:chat:notify`, KHÔNG có push khi app tắt. Đề xuất push-only (không thêm dòng hộp thư) với
   `duongDan = chatUrl`, `category = CTW_REPLY`, tôn trọng mute/giờ im lặng như `alert` của socket.
7. ✅ 📱 app đã nối. **Cài đặt thông báo theo loại (push):** `GET|PUT /work/me/notify-settings` có `push: {assign, comment, mention,
   alert, approval, chatAll}` (thiếu khoá = bật; PUT gửi một phần được). Mô tả gốc: `GET|PUT /work/me/notify-settings` thêm
   `push: {assign, comment, mention, alert, approval, chatAll}: boolean` ⇒ lọc trong `dayRaNgoaiApp`.
   App hiện có: email (INSTANT/DIGEST/OFF), giờ im lặng, chat ALL/MENTIONS, tạm dừng, email tóm tắt,
   chỉnh từng kênh — đủ những gì máy chủ có.
8. ✅ 📱 app đã nối. **Giờ im lặng theo múi giờ người dùng:** `timezone` (IANA, `null` = Asia/Ho_Chi_Minh) trong notify-settings —
   áp cho email tức thì và âm/đẩy chat; sai tên ⇒ 400 `WORK_BAD_TIMEZONE`. ⇒ App: gửi `TimeZone.current.identifier`, bỏ chữ
   "Vietnam time" khi đã đặt. Mô tả gốc: máy chủ cố định `Asia/Ho_Chi_Minh` — app ghi rõ "Vietnam time".
   Đề xuất trường `timezone` trong notify-settings.
9. ✅ 📱 app đã nối. **Nhắn riêng 1-1:** `POST /projects/:pid/chat/dm {userId}` ⇒ `{id, kind:'DM', channelKind:'PRIVATE', name:'dm-<a>-<b>',
   with:{id,username}, created}` (201 tạo mới / 200 kênh cũ, tự bỏ lưu trữ). Thực chất là kênh PRIVATE hai thành viên (mọi
   luật kênh riêng áp nguyên; trong `GET …/chat/channels` nó hiện là kênh `dm-…` — app nên đổi tên hiển thị thành tên người
   kia). Khách cổng/agent không dùng được; một bên đã chặn ⇒ 403 `USER_BLOCKED`. Mô tả gốc: CT Work chỉ có kênh/nhóm riêng (tên 2–40 ký tự). Đề xuất
   `POST /projects/:pid/chat/dm {userId}` ⇒ `{id, kind: 'DM', name}` (trả kênh cũ nếu đã có).
10. **Họp video trong app (tuỳ chọn, chưa cần):** họp hiện là link Meet/Zoom/Teams/Jitsi — app mở bằng
    hệ thống (Universal Link vào app của họ) nên không cần WebRTC/CallKit/quyền camera. Muốn gọi ngay
    trong app: `POST /projects/:pid/meetings/:num/room-token` ⇒ `{provider, url, token, expiresAt, iceServers}`
    (Jitsi tự host có JWT, hoặc LiveKit) + push VoIP riêng nếu muốn đổ chuông.
11. ✅ 📱 app đã nối. **Nhắc họp có nút "Join":** nhắc họp (WORK_ALERT `reminder:true`) có `meetingUrl` trong payload và gói đẩy,
    category `CTW_MEETING`. Mô tả gốc: nhắc trước giờ họp (`reminderMinutes`) nên là push WORK_ALERT kèm
    `meetingUrl` + `category = CTW_MEETING` (app sẽ thêm nút Join khi máy chủ gửi).
12. **Chính sách bảo mật web** (`/chinh-sach-bao-mat`): thêm Groq (phiên âm voice note) vào mục bên thứ ba.

**B — Kế hoạch / Báo cáo**
- ✅ 📱 `GET /work/me/agenda?from=YYYY-MM-DD&to=YYYY-MM-DD` (mặc định hôm nay → +30 ngày, tối đa 120): `items[]` mỗi mục
  `{type: due|sprint|release|stage|meeting, date (YMD giờ VN), title, project:{id,key,name,workspaceSlug}, url, …}` — due có
  `key/number/priority/status`; sprint có `end/goal/status`; stage có `event: started|completed`; meeting có
  `startsAt/endsAt/timezone/location/meetingUrl/rsvp/client`. Cùng phạm vi với lịch .ics. ⇒ App: thay việc gộp
  `/me/work` + `timeline/markers` + `meetings` từng dự án bằng MỘT lời gọi.
- ✅ 📱 `GET /work/me/timesheet?week=YYYY-MM-DD` (ngày bất kỳ trong tuần ⇒ tuần bắt đầu thứ Hai): `{weekStart, weekEnd, days,
  totalMin, byDay, projects:[{project, totalMin, byDay, timesheetStatus, issues:[…]}], logs:[…]}`.
- ✅ `GET /projects/:pid/timeline/markers` cắt ngày theo giờ VN (sprint không còn lệch một ngày).
- ✅ Burndown (`/reports/burndown`) trả thêm `totalIssues/doneIssues` (sprint đã đóng: theo bản chụp lúc đóng).
- ✅ `GET /projects/:pid/versions/:id` có `counts: {total, done, inProgress, todo, percent}` + `overdue`.
- ✅ 📱 `GET /projects/:pid/dashboards/:dashId` ⇒ `{id, name, shared, ownerId, widgets, canEdit, …}`.
- ✅ `GET /projects/:pid` — `permissions.viewReports` vốn đã luôn có (s4Flags); không cần đổi.
- Đã có burndown/velocity/sprint/epics/contributions/timeline/capacity/okrs/poker/retros trên web;
  cần đối chiếu hình dạng từng route khi làm (một số trả CSV). Workload/Portfolio cấp không gian:
  kiểm `GET /workspaces/:wsId/...` có cho tài khoản thường không.

**C — Tài liệu & quản trị dự án (đã làm 18/10/2026; dưới đây là thứ backend còn thiếu)**
- ✅ 📱 *Docs — sửa cùng lúc:* `PATCH /pages/:num` nhận `baseVersion` — máy chủ ghi phòng đồng soạn xuống CSDL rồi so, lệch ⇒
  409 `WORK_PAGE_CONFLICT` (`data: {version, baseVersion, by}`), khớp ⇒ gộp ba chiều đúng gốc (đi qua Yjs nếu phòng mở) —
  hết khe "flush → PATCH". ⇒ App: gửi `baseVersion` thay cho `collab/flush` + GET + so tay. Mô tả gốc: PATCH `/pages/:num` khi trang "đang có collab" BỎ QUA `version` và trộn trên bản CSDL
  (`pages.service.ts` 419–470) ⇒ app tự làm an toàn: `collab/flush` → GET lại → chỉ ghi khi `version` khớp (hoặc
  markdown máy chủ không đổi), lệch thì KHÔNG ghi, đưa lựa chọn (lưu bản mình thành trang con / chép / tải bản mới).
  Còn hở một khe nhỏ giữa flush và PATCH. Cần: PATCH tôn trọng `version` cả khi đi qua collab (409 nếu lệch), hoặc
  `baseVersion` để máy chủ trộn 3 chiều đúng gốc của client.
- ✅ *Docs — đổi tên khi phòng collab đang mở:* PATCH `title` cập nhật luôn `metadata.title` của phòng đang mở ⇒ không bị
  ghi ngược. Mô tả gốc: `materializePage` lấy lại `metadata.title` của Y.Doc ⇒ tiêu đề REST có
  thể bị ghi ngược (web cũng dính). Cần cập nhật `metadata.title` của phòng khi PATCH `title`.
- *Docs — nội dung markdown không giữ được:* trang có @nhắc tên / chú thích gắn đoạn / ô bảng gộp ⇒ app KHÔNG cho
  sửa (sửa sẽ làm mất). Cần endpoint sửa theo khối (`PATCH /pages/:num/blocks`) hoặc nhận TipTap kèm `baseVersion`.
- ✅ 📱 *Báo cáo nội dung (1.2):* `POST /work/report {kind, id, reason, detail?}` ⇒ `{reported, duplicate}`. `kind` ∈
  `chat_message · issue_comment · page_comment · meeting_note (id = id cuộc họp) · retro_card · change_request · raid_item ·
  review_item · approval_step (id bước, có comment) · intake_message (id đề xuất intake) · form_answer (id câu trả lời) ·
  class_post · class_comment · diagram_comment`; `id` = id nội bộ của dòng đó. Kiểm người báo THẤY nội dung (không thấy ⇒
  404), tự báo ⇒ 400 `WORK_REPORT_SELF`. Lưu: hàng chờ BAO_CAO quản trị (cùng chỗ đường chung cũ) + audit `content.report` +
  WORK_ALERT cho ADMIN dự án (lớp học: GV + chủ lớp). Khách cổng gọi được `POST …/issues/:n/comments/:cid/report` (chỉ bình
  luận PUBLIC trên thẻ đã chia sẻ) và báo tin ở kênh CLIENT. "Ẩn phía máy chủ" mới có cho tin chat + bình luận thẻ
  (`hiddenForMe`). ⇒ App: thay `/academy/advisor/report-answer` bằng route này ở mọi chỗ. Mô tả gốc: chỉ bình luận THẺ có route báo cáo. Thiếu cho: bình luận trang Docs, bước phê duyệt,
  mô tả CR/RAID, ghi chú review, bình luận sơ đồ, tin Intake, câu trả lời Form, bảng tin + bình luận lớp học ⇒ app
  đang đi đường chung `/academy/advisor/report-answer`. Đề xuất MỘT route `POST /work/report {kind,id,reason}` (ghi
  audit + báo admin + ẩn phía máy chủ cho người báo cáo). Khách cổng chưa gọi được route báo cáo bình luận thẻ
  (thêm vào danh sách cho phép `permissions.ts` ~467–493).
- *Bình luận còn thiếu:* CR, RAID, review, use case/rule/screen/feature (hiện chỉ thảo luận qua thẻ liên kết).
- ✅ (phần mã khoá) Mã khoá sửa: backend chỉ phát `WORK_EDIT_LOCKED` (423) — không có chỗ nào phát `EDIT_LOCKED`; app có thể
  bỏ nhánh so đuôi. Phần "chờ tôi theo dự án" + `data` của lỗi 409 vẫn như cũ.
- *Phê duyệt:* không có "chờ tôi" theo dự án (app lọc `/me/approvals`). `APIClient` bỏ `data` của lỗi ⇒ 409
  `WORK_GATE_OPEN_ISSUES` chưa hiện được danh sách thẻ mở. Mã khoá sửa lúc `WORK_EDIT_LOCKED` lúc `EDIT_LOCKED`.
- ✅ *Kiểm thử:* `PATCH /test-cycles/:id {addNumbers}` trả `{updated, runs:[{number, runId}]}` (kể cả số đã có sẵn trong chu kỳ).
  Còn thiếu: bằng
  chứng và bug không gắn được với BƯỚC (`/attachments/complete` không nhận `stepResultId`, `WorkTestRunDefect`
  không lưu bước).
- ✅ 📱 *Yêu cầu:* `GET /projects/:pid/swr/requirements/:num` (service `getRequirement`). Còn thiếu: GET gọn một use case/screen.
- *Sơ đồ:* ảnh chỉ có sau khi đã có người mở trên web (`WORK_DIAGRAM_NOT_RENDERED`) ⇒ bật Kroki
  (`CTW_MERMAID_RENDER_URL`) hoặc route dựng theo yêu cầu.
- ✅ *Đội/agent:* `agent-leases` có thêm `issueNumber/issueKey/issueTitle`. Còn thiếu: chưa có link mời cấp DỰ ÁN
  (`POST /projects/:pid/invite-links`); app chưa đọc `clientView` của cấu hình dự án (lõi `CTWProjectConfig`).
- *Lớp học/cổng khách:* chưa có route chi tiết một nhóm cho giảng viên; khách không mở được tệp đính kèm của yêu cầu
  (route URL tệp ngoài danh sách cho phép); chấm điểm rubric (`PUT …/grade`) để web.
- *Tài chính:* người không có `manageFinance` chỉ thấy cài đặt + bảng công — muốn họ xem % ngân sách cần summary rút gọn.

**D — Tính năng riêng iOS (app ĐÃ làm 18/10/2026 — không cần backend mới để chạy)**
- Widget "My work today" + "Timer": KHÔNG gọi mạng — app ghi ảnh chụp vào App Group (`/me/agenda` hôm nay + thẻ quá hạn
  của `/me/work`; đồng hồ từ `/me/timer`) mỗi lần ra tiền cảnh / mở My Work / đổi đồng hồ.
- Live Activity đồng hồ: chạy CỤC BỘ (`pushType: nil`). Còn thiếu (tuỳ chọn): push `liveactivity` để đồng hồ đổi ở
  web/desktop cập nhật Live Activity khi app đang tắt — cần app gửi push token của activity lên máy chủ
  (`POST /work/me/timer/live-activity-token`) + máy chủ đẩy `apns-push-type: liveactivity` khi `work:timer` đổi.
- Share Extension: `POST /projects/:pid/issues {title, typeKey:"TASK", descriptionJson}`, `POST …/comments {bodyJson}`,
  đính kèm ảnh presign → PUT → complete — đều là route có sẵn. Token từ Keychain chia sẻ.
- Siri/App Intents: chạy trong tiến trình app (dùng `APIClient` sẵn có), thẻ chọn từ "đã xem gần đây" hoặc `/search`.
- Spotlight: chỉ mục cục bộ thẻ đã mở (CoreSpotlight), không cần route.
- Còn thiếu (3.1.1, phía WEB): trang `/work` có nút "Upgrade to Pro" (`UpgradeDialog`, `BuiltinBits`, `WeeklyReportTab`).
  App đã chặn + ẩn trong trình duyệt nội bộ; bền hơn nếu web ẩn các nút đó khi mở từ app iOS (vd tham số `?app=ios`).

---

## 6. Guideline 4.3 — đoạn trả lời Resolution Center (dán khi bị hỏi "app trùng app CuongThai")

Dùng khi reviewer gửi 4.3(a) "Spam / similar to another app from your account". Dán nguyên khối dưới (tiếng Anh):

```
Hello App Review team,

Thank you for the review. CT Work is a separate product from our "CuongThai"
app, with a different audience, purpose and feature set:

1. Audience and purpose. CuongThai is a personal learning and community app
   (courses, social feed, notes, personal finance). CT Work is a team
   work-management tool for project teams and their clients: issues, boards,
   sprints, approvals, team chat, meetings, documents and time tracking. A
   person can use one without ever installing the other.

2. Features that exist only in CT Work and are built natively for iOS:
   - Home Screen and Lock Screen widgets: "My work today" and "Timer".
   - A Live Activity for the running time tracker, with Pause and Stop
     buttons on the Lock Screen and in the Dynamic Island.
   - Siri and Shortcuts: "What's on my plate in CT Work", "Start a CT Work
     timer on <issue>", "Stop my CT Work timer".
   - A Share Extension that turns a photo, link or text from any app into a
     new issue or a comment on an issue.
   - Spotlight search for recently opened issues.
   - Actionable notifications: reply to a comment, approve or reject a
     request, or join a meeting directly from the notification.
   - A client portal view, so a project's clients can follow shared issues,
     approvals and meetings without seeing internal work.
   - A dedicated iPad layout with a sidebar grouped by project area.

3. Separate identity. CT Work has its own bundle ID (com.cuongthai.ctwork),
   name, icon, App Store listing, privacy manifest and permissions. It does
   not include any of CuongThai's learning, social or finance features.
   CuongThai only keeps a lightweight issue viewer for existing users; chat,
   meetings, approvals, documents, time tracking, widgets, Live Activities,
   Siri and the Share Extension are available only in CT Work.

4. Business model. Both apps are free; CT Work has no purchases.

We are happy to provide a short screen recording of these features if that
helps. Thank you.
```

## 7. Checklist dữ liệu DEMO cho reviewer (KHÔNG tự tạo trên prod — chủ app làm trên web)

Mục tiêu: reviewer mở MỌI tab chính đều thấy dữ liệu, không gặp màn trống. Tài khoản demo vào sẵn workspace
"CT Work Demo", dự án Scrum **DEMO**:

- [ ] **Thẻ ở nhiều trạng thái**: ≥ 3 thẻ To Do, ≥ 2 In Progress, ≥ 1 In Review, ≥ 2 Done; vài thẻ có hạn hôm nay,
      1 thẻ quá hạn; ≥ 4 thẻ **giao cho tài khoản demo** (My Work + widget "My work today" có dữ liệu).
- [ ] **Sprint đang chạy** (ACTIVE) có ngày bắt đầu/kết thúc bao quanh ngày nộp duyệt + 1 sprint PLANNED kế tiếp.
- [ ] **Chat**: kênh #general có ≥ 5 tin (1 ảnh, 1 tin @nhắc tài khoản demo), 1 nhóm riêng, 1 tin nhắn riêng 1-1
      (Chat → New direct message) với tài khoản thứ hai.
- [ ] **1 cuộc họp sắp tới** (trong 1–7 ngày tới, mời tài khoản demo, có link Meet/Zoom) — hiện ở Meetings,
      My Work → Agenda, Calendar; bật nhắc trước để có thông báo có nút Join.
- [ ] **1 trang Docs** (bật mô-đun Docs) có nội dung + 1 bình luận của tài khoản thứ hai.
- [ ] **1 phê duyệt đang CHỜ tài khoản demo** (Approvals, tài khoản demo là người duyệt bước hiện tại) — thử nút
      Approve/Reject ở Inbox + trên thông báo.
- [ ] 3–4 bình luận trên một thẻ (1 của tài khoản thứ hai để có Report/Block), 1 ảnh đính kèm.
- [ ] Ghi giờ vài lần trong tuần (Time → My week có cột), không để đồng hồ chạy sẵn.
- [ ] (Tuỳ chọn) 1 AI agent trong workspace để thấy nhãn "AI agent".
- [ ] Tài khoản demo: email đã xác thực, KHÔNG bật 2FA, mật khẩu ghi vào Sign-In Information; mở app thử một lần
      để widget/Spotlight có dữ liệu khi reviewer xem.

## 8. TestFlight — bundle ID, capability, lệnh phát hành (18/10/2026)

**Lệnh (một dòng):** `bash scripts/phat-hanh-ctwork.sh` — tăng số dựng ở `CuongThaiApp/CTWorkApp/PhienBanCTW.xcconfig`
→ `xcodegen` → archive Release → export (ký lại bằng profile phân phối) → kiểm IPA (số phiên bản app = widget = share,
PrivacyInfo trong cả 3 gói, `aps-environment = production`, `get-task-allow = false`, App Group, `CT_XEM_MAN` = 0)
→ upload bằng khoá trong `phat-hanh.env`. `--khong-day` = dừng trước upload; `--thu` = archive không ký chỉ để kiểm.
Phiên bản 1.0.0, số dựng bắt đầu 1 (lần chạy đầu ⇒ 2; muốn nộp đúng số 1 thì `--khong-tang`).

**Tạo trên developer.apple.com → Certificates, IDs & Profiles (team UR32PFUQ38):**

| Loại | Identifier | Capability phải bật |
|---|---|---|
| App ID (app) | `com.cuongthai.ctwork` | Sign in with Apple · Push Notifications · Associated Domains · App Groups |
| App ID (widget + Live Activity) | `com.cuongthai.ctwork.widget` | App Groups |
| App ID (Share Extension) | `com.cuongthai.ctwork.share` | App Groups |
| App Group | `group.com.cuongthai.ctwork` | gán cho CẢ BA App ID trên |
| Keychain group | `<TEAM>.com.cuongthai.ctwork.shared` | không cần tạo trên portal (tiền tố đội tự hợp lệ) |

Không cần: Siri capability (App Shortcuts/App Intents không đòi), Background Modes, Time Sensitive, iCloud.
Live Activities không phải capability — chỉ cần `NSSupportsLiveActivities` (đã có trong Info.plist).
Xcode ký tự động (`-allowProvisioningUpdates`) tự tạo provisioning profile khi App ID đã tồn tại.

**Chủ app tự bấm (Claude không làm được):**
1. Tạo 3 App ID + App Group như bảng trên (hoặc mở `CuongThaiApp.xcodeproj` → target CTWorkApp → Signing một lần để
   Xcode tự đăng ký, rồi kiểm lại capability trên portal).
2. App Store Connect → My Apps → **+ New App**: iOS, tên "CT Work", bundle `com.cuongthai.ctwork`, SKU tuỳ ý, English.
3. Chạy `bash scripts/phat-hanh-ctwork.sh` trên máy đã đăng nhập Xcode (tài khoản team UR32PFUQ38).
4. TestFlight → Internal Testing → thêm nhóm (thành viên trong team ASC) → chọn build. Nhóm External cần Beta App Review
   (điền "What to Test" + tài khoản demo mục 7).
5. Trước khi nộp App Store: tài khoản demo (mục 7), Privacy Policy thêm **Groq**, App Privacy khai **Audio Data**,
   Support URL, ảnh màn hình (`/Users/admin/Documents/ctwork-ios-anh-chup-18-10/`), điền `MoAppCTWork.appStoreID`.
