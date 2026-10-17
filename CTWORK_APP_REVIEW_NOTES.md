# App Review Notes — CT Work iOS (`com.cuongthai.ctwork`)

Phần đầu (tiếng Việt) là ghi chú cho chủ app. Khối **"Cho người duyệt"** (tiếng Anh)
dán nguyên vào App Store Connect → App Review Information → Notes.
Kiến trúc mã: `CuongThaiApp/CTWorkApp/KIEN_TRUC.md`.

---

## 1. App này là gì (để trả lời 4.3 — mục đích riêng)

App quản lý công việc nhóm: My Work, bảng kéo thả, backlog/sprint, danh sách có lọc,
chi tiết thẻ (sửa trạng thái/người làm/ưu tiên/hạn, bình luận, đính kèm, lịch sử, thẻ con,
liên kết), tạo thẻ nhanh, hộp thư thông báo, chat nhóm theo kênh (realtime), đọc + tìm tài
liệu dự án, deep link `ctwork://` + thông báo đẩy. Không có mạng xã hội, khoá học, nhạc,
tiền nong… của app chính ⇒ không phải bản sao app CuongThai.

## 2. Luật Apple đã đáp ứng

| Guideline | Làm gì | Ở đâu |
|---|---|---|
| 3.1.1 / 3.1.3(b) | Không giá, không nút mua/nâng cấp, không link ra trang mua. Không có màn tài chính/CRM. Header `X-Client-Platform: ios` để máy chủ bỏ lời mời mua trong câu lỗi | toàn app (đã grep chuỗi "Pro", "upgrade", "price", "buy", "payment") |
| 4.3 | Mục đích riêng: quản lý công việc nhóm; bundle, biểu tượng, tên riêng | `project.yml` target CTWorkApp |
| 2.1 | Mọi màn chạy thật, không placeholder; mô-đun chưa làm KHÔNG hiện mục (bảng đăng ký mô-đun) | `Core/CTWDangKyMoDun.swift` |
| 4.8 | Sign in with Apple (cạnh tài khoản cuongthai.com) | `Modules/Account/DangNhapCTW.swift` + entitlement |
| 5.1.1(v) | Xoá tài khoản trong app: Account → Delete account (cùng luồng máy chủ với app chính, 72 giờ, rút lại được) | `Modules/Account/TaiKhoanCTW.swift` |
| 1.2 | (1) đồng ý quy tắc cộng đồng lần đầu; (2) báo cáo bình luận + tin chat; (3) chặn người dùng (ẩn mọi bình luận/tin/thông báo của họ); (4) liên hệ: Account → Help & contact; nội dung đã báo cáo ẩn ngay | `DongYQuyTacCTW`, `CTWKiemDuyet.swift`, `ChatCTW.swift`, `CTWorkIssueView.swift` |
| 4.7 / 1.2 (AI) | Thành viên AI agent luôn có nhãn "AI agent" + ✦ trên avatar ở bình luận, chat, người làm, lịch sử, bộ chọn người; bình luận AI soạn có nhãn "AI-drafted"; báo cáo được như mọi nội dung | `CTWNhanAI`, `CTWAvatar` |
| 5.1.2(i) | App KHÔNG gửi dữ liệu cho AI bên thứ ba (không có tính năng AI trong app). Agent do admin workspace thêm trên web, đọc dự án như một thành viên — ghi rõ ở Privacy + chọn người làm | `TrangPhapLyView` |
| 5.1.1 / 5.1.2 | `PrivacyInfo.xcprivacy` riêng (UserDefaults CA92.1, FileTimestamp C617.1; dữ liệu thu: email, tên, user ID, device ID, ảnh/tệp, tin nhắn, nội dung khác — đều Linked, không tracking). Chỉ MỘT chuỗi quyền: máy ảnh (chụp ảnh đính kèm). Chọn ảnh = PhotosPicker (không cần quyền), chọn tệp = fileImporter | `CTWorkApp/PrivacyInfo.xcprivacy`, `Info.plist` |
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
- Chat tab: team channels, send a message (real-time).
- Inbox: CT Work notifications (assignments, mentions, comments).
- Projects > Docs: read and search project pages.

=== USER-GENERATED CONTENT (Guideline 1.2) ===
- Community rules must be accepted on first launch.
- Comments: touch and hold > Report comment / Block user.
- Chat messages: touch and hold > Report message / Block user.
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
  attach a picture to an issue. Photo Library uses the system picker.
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

**A — Chat / Họp / Thông báo**
- Không có route BÁO CÁO tin chat ⇒ app dùng đường chung `/academy/advisor/report-answer`.
  Đề xuất `POST /projects/:pid/chat/channels/:cid/messages/:mid/report` (như report bình luận:
  audit + WORK_ALERT cho admin) + ẩn tin cho người báo cáo phía máy chủ.
- Chặn người dùng (`/messages/blocks`) chưa áp vào chat/bình luận/thông báo CT Work phía máy chủ
  (app lọc phía máy).
- Tin chat thường (không @, không trả lời) không có push — chỉ socket `work:chat:notify`.
  Cần push "tin mới trong kênh" theo cài đặt `notify` của kênh nếu muốn báo khi app tắt.
- Họp video: cần endpoint cấp phòng/token (TURN) cho WebRTC native; hiện họp là link ngoài.
- Thông báo có hành động (Trả lời/Duyệt ngay trên thông báo) cần route trả lời gọn
  (vd `POST /work/notifications/:id/reply`) + `category` trong gói APNs.

**B — Kế hoạch / Báo cáo**
- Đã có burndown/velocity/sprint/epics/contributions/timeline/capacity/okrs/poker/retros trên web;
  cần đối chiếu hình dạng từng route khi làm (một số trả CSV). Workload/Portfolio cấp không gian:
  kiểm `GET /workspaces/:wsId/...` có cho tài khoản thường không.

**C — Docs/Spec/Phê duyệt/…**
- Sửa Docs trên app: route `PATCH /pages/:num` nhận `contentJson` TipTap + đồng bộ cộng tác
  (`collab.service.ts`) — app cần chiến lược khoá/ghi đè (version) rõ ràng.
- Ảnh trong tài liệu là đường tương đối CẦN token (`/api/v1/work/projects/:pid/images/:id`) —
  app đã gắn `Authorization`; nếu chuyển sang url ký sẵn thì tốt hơn cho bộ đệm ảnh.

**D — Tính năng riêng iOS**
- Widget/Live Activity/Siri cần endpoint gọn, nhẹ, có thể gọi bằng token riêng (App Group):
  vd `GET /me/work?limit=5&fields=key,title,dueDate`; Live Activity cần push `liveactivity`
  (APNs token riêng) cho sprint/timer.
- Share Extension "Tạo thẻ từ nội dung chia sẻ": dùng được `POST /projects/:pid/issues` hiện có.
- Spotlight: dùng `/search` hiện có.
