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
| ITSAppUsesNonExemptEncryption | `false` | `Info.plist` |
| 2.3 / A6 | Cửa xem màn `CT_XEM_MAN` + máy chủ giả CHỈ trong `#if DEBUG` — đo bản Release: `grep -a -c CT_XEM_MAN` = 0 | `Debug/XemThuCTW.swift` |
| 4.2 | Ứng dụng gốc SwiftUI (bảng kéo thả, chat realtime, Xem nhanh tệp, thông báo đẩy). Chỉ một lối "Open project on the web" (SFSafariViewController) cho công cụ nặng — không dùng để mua |  |
| C12 iPad | Bố cục iPad riêng (NavigationSplitView, thanh bên theo nhóm), đủ 4 hướng |  |

## 3. Việc CHỦ APP phải làm trước khi nộp

**Apple Developer (Certificates, IDs & Profiles → Identifiers):**
1. Tạo App ID `com.cuongthai.ctwork` (team UR32PFUQ38), bật **Sign in with Apple**,
   **Push Notifications**, **Associated Domains**. Thiếu cái nào là bước ký hồ sơ trượt.
2. (Sign in with Apple) gộp vào cùng nhóm "primary App ID" với `com.cuongthai.app` nếu muốn
   cùng một Apple ID đăng nhập ra cùng tài khoản ở hai app (Apple trả cùng `user` cho các app
   trong một nhóm).

**App Store Connect:**
3. Tạo app mới "CT Work", bundle `com.cuongthai.ctwork`, SKU tuỳ ý, ngôn ngữ chính English,
   danh mục **Productivity** (phụ: Business).
4. Privacy Policy URL `https://cuongthai.com/chinh-sach-bao-mat`; **Support URL** (bắt buộc).
5. App Privacy: khai ĐÚNG danh sách ở `PrivacyInfo.xcprivacy` — Email, Name, User ID,
   Device ID, Photos or Videos, Emails or Text Messages, Other User Content; Linked, không
   Tracking, App Functionality.
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
- Push notifications: assignments, mentions and comments.
- iPad uses a dedicated split-view layout.
```

## 5. Phần BACKEND còn thiếu / nên có (không sửa ở phiên app)

**Chung / nền**
- `GET /social/notifications` chưa lọc theo loại ⇒ app tải nhiều trang rồi tự lọc `WORK_*`.
  Đề xuất `?surface=work` (payload WORK_* đã có `surface:'work'`) + `unread-count?surface=work`.
- `sender` của thông báo không có `kind` ⇒ hộp thư chưa gắn nhãn AI agent cho thông báo do agent
  gây ra. Thêm `kind` vào select `sender`.
- `apple-app-site-association` CHƯA có (`frontend/public/.well-known/` chỉ có security.txt) ⇒
  Universal Link chưa chạy. Cần phục vụ `/.well-known/apple-app-site-association`
  (`application/json`, không redirect) với `applinks.details[].appIDs = ["UR32PFUQ38.com.cuongthai.ctwork"]`,
  `components: [{"/": "/work/*"}]`, và nginx cho đi qua. App đã khai `applinks:cuongthai.com`.
- `POST /auth/oauth/token` KHÔNG xác minh `identityToken` của Apple (lỗ hổng có sẵn từ trước —
  ai cũng POST email bất kỳ được). App đã gửi `identityToken` + `authorizationCode`; cần verify
  chữ ký JWKS Apple, `aud` ∈ {`com.cuongthai.app`, `com.cuongthai.ctwork`}.
- Push app CT Work: phiên chính đang làm trường `app` ở `/devices` + topic theo app (chưa deploy).

**A — Chat / Họp / Thông báo** (cập nhật 18/10/2026 — app ĐÃ làm phần của mình, chờ máy chủ)
1. **Nút trên thông báo đẩy (cần nhất).** App đã đăng ký 3 category + xử lý nền
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
2. **Lọc thông báo theo bề mặt:** `GET /social/notifications?surface=work` (+ `GET …/unread-count?surface=work`
   ⇒ `{unreadCount}`) — app đang tải tối đa 4–6 trang rồi tự lọc `WORK_*` để đếm huy hiệu.
3. **Báo cáo tin chat:** `POST /projects/:pid/chat/channels/:cid/messages/:mid/report {reason, detail?}` ⇒
   `{reported: true}` (audit + WORK_ALERT cho admin dự án, ẩn tin cho người báo cáo). Hiện đi đường chung
   `/academy/advisor/report-answer` (`BaoCaoTinCTW.swift` — đổi MỘT chỗ).
4. **Báo cáo ghi chú cuộc họp:** `POST /projects/:pid/meetings/:num/report {reason, detail?}` ⇒ `{reported: true}`.
   Hiện cũng đi đường chung (`ChiTietHopCTW.guiBaoCao`).
5. **Chặn áp phía máy chủ:** `/messages/blocks` chưa áp vào chat/bình luận/ghi chú họp/thông báo CT Work
   (app lọc phía máy).
6. **Push tin chat thường:** kênh đặt `notify = ALL` mà tin không @/không trả lời ⇒ hiện chỉ có socket
   `work:chat:notify`, KHÔNG có push khi app tắt. Đề xuất push-only (không thêm dòng hộp thư) với
   `duongDan = chatUrl`, `category = CTW_REPLY`, tôn trọng mute/giờ im lặng như `alert` của socket.
7. **Cài đặt thông báo theo loại (push):** `GET|PUT /work/me/notify-settings` thêm
   `push: {assign, comment, mention, alert, approval, chatAll}: boolean` ⇒ lọc trong `dayRaNgoaiApp`.
   App hiện có: email (INSTANT/DIGEST/OFF), giờ im lặng, chat ALL/MENTIONS, tạm dừng, email tóm tắt,
   chỉnh từng kênh — đủ những gì máy chủ có.
8. **Giờ im lặng theo múi giờ người dùng:** máy chủ cố định `Asia/Ho_Chi_Minh` — app ghi rõ "Vietnam time".
   Đề xuất trường `timezone` trong notify-settings.
9. **Nhắn riêng 1-1:** CT Work chỉ có kênh/nhóm riêng (tên 2–40 ký tự). Đề xuất
   `POST /projects/:pid/chat/dm {userId}` ⇒ `{id, kind: 'DM', name}` (trả kênh cũ nếu đã có).
10. **Họp video trong app (tuỳ chọn, chưa cần):** họp hiện là link Meet/Zoom/Teams/Jitsi — app mở bằng
    hệ thống (Universal Link vào app của họ) nên không cần WebRTC/CallKit/quyền camera. Muốn gọi ngay
    trong app: `POST /projects/:pid/meetings/:num/room-token` ⇒ `{provider, url, token, expiresAt, iceServers}`
    (Jitsi tự host có JWT, hoặc LiveKit) + push VoIP riêng nếu muốn đổ chuông.
11. **Nhắc họp có nút "Join":** nhắc trước giờ họp (`reminderMinutes`) nên là push WORK_ALERT kèm
    `meetingUrl` + `category = CTW_MEETING` (app sẽ thêm nút Join khi máy chủ gửi).
12. **Chính sách bảo mật web** (`/chinh-sach-bao-mat`): thêm Groq (phiên âm voice note) vào mục bên thứ ba.

**B — Kế hoạch / Báo cáo**
- Đã có burndown/velocity/sprint/epics/contributions/timeline/capacity/okrs/poker/retros trên web;
  cần đối chiếu hình dạng từng route khi làm (một số trả CSV). Workload/Portfolio cấp không gian:
  kiểm `GET /workspaces/:wsId/...` có cho tài khoản thường không.

**C — Tài liệu & quản trị dự án (đã làm 18/10/2026; dưới đây là thứ backend còn thiếu)**
- *Docs — sửa cùng lúc:* PATCH `/pages/:num` khi trang "đang có collab" BỎ QUA `version` và trộn trên bản CSDL
  (`pages.service.ts` 419–470) ⇒ app tự làm an toàn: `collab/flush` → GET lại → chỉ ghi khi `version` khớp (hoặc
  markdown máy chủ không đổi), lệch thì KHÔNG ghi, đưa lựa chọn (lưu bản mình thành trang con / chép / tải bản mới).
  Còn hở một khe nhỏ giữa flush và PATCH. Cần: PATCH tôn trọng `version` cả khi đi qua collab (409 nếu lệch), hoặc
  `baseVersion` để máy chủ trộn 3 chiều đúng gốc của client.
- *Docs — đổi tên khi phòng collab đang mở:* `materializePage` lấy lại `metadata.title` của Y.Doc ⇒ tiêu đề REST có
  thể bị ghi ngược (web cũng dính). Cần cập nhật `metadata.title` của phòng khi PATCH `title`.
- *Docs — nội dung markdown không giữ được:* trang có @nhắc tên / chú thích gắn đoạn / ô bảng gộp ⇒ app KHÔNG cho
  sửa (sửa sẽ làm mất). Cần endpoint sửa theo khối (`PATCH /pages/:num/blocks`) hoặc nhận TipTap kèm `baseVersion`.
- *Báo cáo nội dung (1.2):* chỉ bình luận THẺ có route báo cáo. Thiếu cho: bình luận trang Docs, bước phê duyệt,
  mô tả CR/RAID, ghi chú review, bình luận sơ đồ, tin Intake, câu trả lời Form, bảng tin + bình luận lớp học ⇒ app
  đang đi đường chung `/academy/advisor/report-answer`. Đề xuất MỘT route `POST /work/report {kind,id,reason}` (ghi
  audit + báo admin + ẩn phía máy chủ cho người báo cáo). Khách cổng chưa gọi được route báo cáo bình luận thẻ
  (thêm vào danh sách cho phép `permissions.ts` ~467–493).
- *Bình luận còn thiếu:* CR, RAID, review, use case/rule/screen/feature (hiện chỉ thảo luận qua thẻ liên kết).
- *Phê duyệt:* không có "chờ tôi" theo dự án (app lọc `/me/approvals`). `APIClient` bỏ `data` của lỗi ⇒ 409
  `WORK_GATE_OPEN_ISSUES` chưa hiện được danh sách thẻ mở. Mã khoá sửa lúc `WORK_EDIT_LOCKED` lúc `EDIT_LOCKED`.
- *Kiểm thử:* `PATCH /test-cycles/:id {addNumbers}` chỉ trả `{updated}` (nên trả `runs:[{number,runId}]`); bằng
  chứng và bug không gắn được với BƯỚC (`/attachments/complete` không nhận `stepResultId`, `WorkTestRunDefect`
  không lưu bước).
- *Yêu cầu:* thiếu GET gọn một use case/screen (`/srs/use-cases/:n` vẫn dựng cả SRS), `GET /swr/requirements/:num`.
- *Sơ đồ:* ảnh chỉ có sau khi đã có người mở trên web (`WORK_DIAGRAM_NOT_RENDERED`) ⇒ bật Kroki
  (`CTW_MERMAID_RENDER_URL`) hoặc route dựng theo yêu cầu.
- *Đội/agent:* `agent-leases` chỉ trả `issueId` nội bộ (nên thêm số/mã/tiêu đề thẻ); chưa có link mời cấp DỰ ÁN
  (`POST /projects/:pid/invite-links`); app chưa đọc `clientView` của cấu hình dự án (lõi `CTWProjectConfig`).
- *Lớp học/cổng khách:* chưa có route chi tiết một nhóm cho giảng viên; khách không mở được tệp đính kèm của yêu cầu
  (route URL tệp ngoài danh sách cho phép); chấm điểm rubric (`PUT …/grade`) để web.
- *Tài chính:* người không có `manageFinance` chỉ thấy cài đặt + bảng công — muốn họ xem % ngân sách cần summary rút gọn.

**D — Tính năng riêng iOS**
- Widget/Live Activity/Siri cần endpoint gọn, nhẹ, có thể gọi bằng token riêng (App Group):
  vd `GET /me/work?limit=5&fields=key,title,dueDate`; Live Activity cần push `liveactivity`
  (APNs token riêng) cho sprint/timer.
- Share Extension "Tạo thẻ từ nội dung chia sẻ": dùng được `POST /projects/:pid/issues` hiện có.
- Spotlight: dùng `/search` hiện có.
