import Foundation

// ════════════════════════════════════════════════════════════════
// BẢNG DỊCH VIỆT → ANH
//
// Khoá là CHÍNH chuỗi tiếng Việt đang nằm trong mã. Xem lý do ở
// `QuanLyNgonNguApp.swift`.
//
// ⚠️ Đây mới là ĐỢT 1: các màn người dùng gặp đầu tiên (thanh tab, Trang chủ,
// Cài đặt, Hồ sơ, Tạo bài viết, các khối dùng chung). Toàn app có **1.249
// chuỗi khác nhau ở 112/134 file** — đo 24/08/2026 — nên còn nhiều đợt nữa.
// Chuỗi chưa có trong bảng thì hiện nguyên tiếng Việt, KHÔNG bao giờ ra khoá
// thô, nên dịch dở vẫn dùng được.
//
// ⚠️⚠️ Bật tiếng Anh KHÔNG làm mọi chữ trên màn hình thành tiếng Anh, vì
// phần lớn NỘI DUNG do máy chủ trả về và vốn là tiếng Việt theo thiết kế:
// nghĩa từ vựng (`meaningVi`), giải thích ngữ pháp, bản dịch bài đọc, lời phê
// của AI (lời nhắc ở backend ghi thẳng "ALWAYS write feedback in
// Vietnamese"), nội dung bài đăng, tên khoá học, thông báo. Đo thật: nội dung
// tiếng Anh của My Language vẫn có 4–7% ký tự tiếng Việt. Muốn hết thì phải
// làm nội dung ở backend, không phải việc của app.
enum BangDich {
    static let anh: [String: String] = [
        // ── Thanh tab ────────────────────────────────────────────
        "Trang chủ": "Home",
        "Học": "Learn",
        "Tạo": "Create",
        "Tin nhắn": "Messages",
        "Cá nhân": "Profile",

        // ── Dùng chung ───────────────────────────────────────────
        "Hủy": "Cancel",
        "Đóng": "Close",
        "Xong": "Done",
        "Lưu": "Save",
        "Xoá": "Delete",
        "Sửa": "Edit",
        "Thử lại": "Try again",
        "Tải lại": "Reload",
        "Đang tải...": "Loading…",
        "Đã xảy ra lỗi": "Something went wrong",
        "Không có dữ liệu": "No data",
        "Thử tải lại trang": "Try reloading the page",
        "Thông báo": "Notice",
        "Chọn một mục": "Pick an item",

        // ── Trang chủ ────────────────────────────────────────────
        "Tất cả": "All",
        "Học tập": "Lessons",
        "Bài viết": "Posts",
        "Video": "Videos",
        "File": "Files",
        "Chưa có bài viết": "No posts yet",
        "Hãy là người đầu tiên chia sẻ!": "Be the first to share!",
        "Xem loạt bài 100 ngày": "Browse the 100-day series",

        // ── Tạo bài viết ─────────────────────────────────────────
        "Tạo bài viết": "New post",
        "Đăng": "Post",
        "Bạn đang nghĩ gì?": "What's on your mind?",
        "Thêm ảnh": "Add photos",
        "Tạo cuộc thăm dò": "Create a poll",
        "Câu hỏi của bạn": "Your question",
        "Thêm tùy chọn": "Add option",
        "Ai có thể xem bài viết?": "Who can see this post?",
        "Công khai": "Public",
        "Bạn bè": "Friends",
        "Riêng tư": "Only me",
        "Vui lòng nhập nội dung bài viết": "Please write something first",
        "Bài viết đã được đăng!": "Your post is up!",
        "Bạn đang bật thăm dò nhưng chưa nhập câu hỏi. Bài viết chưa được đăng.":
            "The poll is on but has no question. Your post was not published.",

        // ── Hồ sơ ────────────────────────────────────────────────
        "Hồ sơ": "Profile",
        "Chỉnh sửa": "Edit",
        "Chỉnh sửa hồ sơ": "Edit profile",
        "Theo dõi": "Follow",
        "Đang theo dõi": "Following",
        "Người theo dõi": "Followers",
        "Đã lưu": "Saved",
        "Khoá học": "Courses",
        "Chưa lưu bài nào": "Nothing saved yet",
        "Chạm ••• trên một bài viết rồi chọn Lưu để đọc lại sau.":
            "Tap ••• on a post and choose Save to read it later.",
        "Chưa ghi danh khoá nào": "Not enrolled in any course",
        "Vào tab Học, chọn một khoá và bấm Ghi danh.":
            "Open the Learn tab, pick a course and tap Enrol.",
        "Chưa có bài viết nào": "No posts yet",
        "Tạo bài viết đầu tiên của bạn": "Write your first post",
        "Người dùng này chưa đăng bài viết nào": "This person hasn't posted yet",
        "Không đổi được ảnh": "Couldn't change the photo",
        "Không đọc được ảnh vừa chọn.": "Couldn't read the photo you picked.",

        // ── Cài đặt ──────────────────────────────────────────────
        "Cài đặt": "Settings",
        "Giao diện": "Appearance",
        "Ngôn ngữ": "Language",
        "Tài khoản": "Account",
        "Đổi mật khẩu": "Change password",
        "Danh sách chặn": "Blocked people",
        "An toàn & quyền riêng tư": "Safety & privacy",
        "Quy tắc cộng đồng & Điều khoản": "Community rules & Terms",
        "Chính sách bảo mật": "Privacy policy",
        "Chúng tôi không khoan nhượng với nội dung phản cảm. Mọi báo cáo được xử lý trong 24 giờ.":
            "We have zero tolerance for objectionable content. Every report is handled within 24 hours.",
        "Hỗ trợ": "Support",
        "Trợ giúp & liên hệ": "Help & contact",
        "Email hỗ trợ": "Support email",
        "Giới thiệu": "About",
        "Phiên bản": "Version",
        "Đăng xuất": "Sign out",
        "Bạn có chắc muốn đăng xuất không?": "Sign out of your account?",
        "Xoá tài khoản": "Delete account",
        "Xoá vĩnh viễn tài khoản và dữ liệu cá nhân của bạn.":
            "Permanently delete your account and personal data.",

        // ── Chế độ giao diện ─────────────────────────────────────
        "Sáng": "Light",
        "Tối": "Dark",
        "Theo hệ thống": "Match system",
        "Theo giờ": "By time of day",
    ]
}
