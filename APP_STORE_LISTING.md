# Hồ sơ App Store — bản 1.0.0 (soạn 24/09/2026)

Chép từng ô vào App Store Connect → app CuongThai → phiên bản iOS.
Ngôn ngữ chính của app là **vi** nên mọi ô dưới đây là tiếng Việt.

⚠️ Phiên bản trên App Store Connect đang tên **`1.0`**, còn build mang
`1.0.0` (`MARKETING_VERSION` trong `project.yml`). **Đổi tên phiên bản thành
`1.0.0`** trước, không thì build không hiện ra ở ô chọn Build.

---

## App Information (áp cho mọi phiên bản)

| Ô | Giá trị |
|---|---|
| Subtitle (≤30) | `Học IT, luyện thi, cộng đồng` |
| Primary category | **Education** |
| Secondary category | Productivity |
| Privacy Policy URL | `https://cuongthai.com/chinh-sach-bao-mat` |
| Content Rights | Không chứa nội dung bên thứ ba cần giấy phép — chọn *No* (video YouTube chỉ được NHÚNG bằng trình phát chính thức) |

## Phiên bản 1.0.0

**Promotional Text (≤170)**
```
Học lập trình, luyện đề, học ngoại ngữ và ghi chú trong một app — kèm trợ lý AI giải thích từng bước và cộng đồng sinh viên IT.
```

**Description**
```
CuongThai là nơi học và làm việc cho sinh viên công nghệ thông tin Việt Nam.

HỌC
• Khoá học video theo chương, lưu tiến độ, học tiếp đúng chỗ đã dừng
• Code Lab: đọc bài, làm bài tập lập trình, chấm tự động
• Phòng thi: làm đề trắc nghiệm có giờ, xem điểm và lời giải
• Ngoại ngữ: từ vựng, lộ trình, luyện nói với AI (Anh, Nhật, Trung), luyện IELTS
• Thư viện sách, mô phỏng thuật toán và hệ thống trực quan

GHI CHÚ & VỞ
• Ghi chú theo môn, vở viết tay trên iPad, ghi âm buổi học
• Đồng bộ với tài khoản trên web

LÀM VIỆC
• CT Work: bảng công việc kiểu Kanban cho nhóm dự án — thẻ, người phụ trách, hạn, bình luận
• Quản lý chi tiêu cá nhân

CỘNG ĐỒNG
• Bảng tin, bài viết, bình luận, tin 24 giờ
• Nhắn tin, gọi thoại 1–1
• Báo cáo và chặn người dùng, nội dung vi phạm được xử lý trong 24 giờ

TRỢ LÝ AI
• Hỏi đáp, giải thích bài, gợi ý sửa CV, tóm tắt video bài học
• Nội dung do AI tạo có thể sai — mỗi câu trả lời đều báo cáo được

Đăng nhập bằng tài khoản CuongThai hoặc Sign in with Apple.
Xoá tài khoản ngay trong app: Cài đặt → Xoá tài khoản.
```

**Keywords (≤100 ký tự, phẩy không cách)**
```
học lập trình,sinh viên IT,luyện thi,code,java,IELTS,tiếng Anh,ghi chú,kanban,flashcard
```

**Support URL:** `https://cuongthai.com/about` (có email liên hệ)
**Marketing URL:** `https://cuongthai.com`
**Copyright:** `2026 Hoàng Nghĩa Cường`

**What's New:** để trống (bản đầu).

---

## Age Rating — trả lời bảng câu hỏi

| Câu | Trả lời |
|---|---|
| Nội dung do người dùng tạo (User-Generated Content) | **Yes** |
| Nhắn tin / chat (Messaging and Chat) | **Yes** |
| Mạng xã hội (Social Media) | **Yes** |
| Truy cập web không giới hạn | No (chỉ mở link trong bài, không có trình duyệt tự do) |
| Quảng cáo | No |
| Cờ bạc, bạo lực, tình dục, rượu/thuốc, kinh dị, tục tĩu… | None |
| Công cụ kiểm soát phụ huynh / xác minh tuổi | No |

Kết quả dự kiến: **13+** (UGC + chat).

## App Privacy — nhãn dữ liệu

Tất cả: **Linked to the user**, mục đích **App Functionality**, **KHÔNG** dùng để theo dõi (tracking).

| Loại | Dữ liệu |
|---|---|
| Contact Info | Email Address, Name |
| User Content | Photos or Videos, Audio Data (luyện nói — gửi lên máy chủ để chấm, không lưu), Emails or Text Messages (tin nhắn trong app), Other User Content (bài viết, ghi chú, bình luận) |
| Identifiers | User ID, Device ID (mã đẩy thông báo) |
| Location | Precise Location — chỉ khi người dùng tự bấm chia sẻ vị trí trong tin nhắn |
| Financial Info | Other Financial Info (module chi tiêu cá nhân) |
| Usage Data | Product Interaction (tiến độ học) |

## Pricing & Availability

- Giá: **Free**
- Quốc gia: tuỳ bạn (tối thiểu Việt Nam)
- ⚠️ Mục *"iPhone and iPad Apps on Apple Silicon Macs"*: **bỏ chọn** — app
  chưa thử trên Mac.

## App Review Information

- Sign-in required: **Yes** — `apple_review1` / *(mật khẩu)*. **Bật Pro cho tài
  khoản này** để người duyệt thử được tính năng AI.
- Contact: Hoàng Nghĩa Cường · email `cuongthaihnhe176322@gmail.com` · SĐT
- Notes: xem khối *"Cho người duyệt"* trong `APP_REVIEW_NOTES.md`, và thêm
  đoạn dưới đây:

```
=== ABOUT "PRO" ===
Some AI features require a "Pro" account. Pro is an account-level
membership of the CuongThai web service (cuongthai.com), used across
web, desktop and mobile (Guideline 3.1.3(b)). This app does not sell
anything, shows no prices, and contains no links or instructions to
purchase outside the app. The demo account has Pro enabled so every
feature can be reviewed.

=== ACCOUNT DELETION ===
Settings (gear icon, Profile tab) > Xoa tai khoan. The account and
personal data are erased automatically 72 hours after the request
(the user can withdraw it during those 72 hours).
```

## Ảnh chụp màn hình (bắt buộc)

App chạy cả iPhone lẫn iPad ⇒ cần hai bộ:
- **iPhone 6.9"** — 1320 × 2868 (máy giả lập iPhone 17 Pro Max), 3–10 ảnh
- **iPad 13"** — 2064 × 2752 (iPad Pro 13" M4/M5), 3–10 ảnh

Không có ảnh chứa giá tiền, chữ "Pro"/"nâng cấp", hay thông tin cá nhân thật.
