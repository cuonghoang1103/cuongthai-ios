import SwiftUI
#if canImport(Kingfisher)
import Kingfisher
#endif

// MARK: - Đường dẫn ảnh từ máy chủ → URL tải được (20/10/2026)
//
// Chủ app báo trên iPhone thật: avatar thành viên và ảnh "không hiện". Máy chủ trả avatarUrl NHIỀU DẠNG (đo trên
// `GET /api/v1/social/posts` của prod):
//   · `https://media.cuongthai.com/images/post/….webp`  — tuyệt đối ⇒ dùng nguyên.
//   · `/images/cuongmini-avatar.svg`, `/images/bots/…svg` — TƯƠNG ĐỐI (web tự ghép với gốc trang) ⇒ `URL(string:)`
//     ra URL không có máy chủ ⇒ Kingfisher tải hỏng câm ⇒ vòng xám.
//   · khoá R2 trần (`avatars/12.webp`) ⇒ ghép CDN `media.cuongthai.com`.
//   · `.svg` — Kingfisher KHÔNG giải được SVG ⇒ coi như không có ảnh, hiện avatar chữ cái (nơi gọi truyền `duPhong`).
//   · `blob:` / `data:` — xem trước tạm của trình duyệt, không tải được ở đây ⇒ bỏ.
// Ảnh CẦN đăng nhập (`/api/v1/work/.../images/:id`) đi qua `CTWAnhCoXacThuc` (gắn Bearer chỉ cho máy chủ của app);
// ảnh chat / đính kèm xin URL ký sẵn (`UrlTepChatCTW`, `CTWAPI.urlDinhKem`) — không đi qua đây.

enum DuongDanAnh {
    static let cdn = "https://media.cuongthai.com"

    /// URL tuyệt đối cho một đường dẫn ảnh của máy chủ, hoặc nil nếu không tải được.
    static func url(_ s: String?, goc: String = APIClient.diaChiGoc) -> URL? {
        guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        let thuong = t.lowercased()
        if thuong.hasPrefix("blob:") || thuong.hasPrefix("data:") { return nil }
        let day: String
        if thuong.hasPrefix("https://") || thuong.hasPrefix("http://") {
            day = t
        } else if t.hasPrefix("//") {
            day = "https:" + t
        } else if t.hasPrefix("/") {
            day = goc + t
        } else if thuong.contains("://") {
            return nil   // lược đồ lạ (ftp:, file:…)
        } else {
            day = cdn + "/" + t
        }
        return URL(string: day) ?? day.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed).flatMap(URL.init(string:))
    }

    /// Như `url` nhưng chỉ ảnh BITMAP Kingfisher giải được — SVG ⇒ nil (nơi gọi hiện ảnh thay thế).
    static func urlAnh(_ s: String?, goc: String = APIClient.diaChiGoc) -> URL? {
        guard let u = url(s, goc: goc) else { return nil }
        return u.pathExtension.lowercased() == "svg" ? nil : u
    }
}

// MARK: - User Avatar
struct UserAvatarView: View {
    let url: String?
    let size: CGFloat
    /// Hiện khi không có ảnh, ảnh là SVG, đang tải hoặc tải HỎNG (vd avatar chữ cái của CT Work).
    /// nil ⇒ vòng xám có hình người như trước.
    var duPhong: AnyView? = nil

    var body: some View {
        Group {
            #if canImport(Kingfisher)
            if let imageURL = DuongDanAnh.urlAnh(url) {
                KFImage(imageURL)
                    // Kingfisher giữ placeholder cả khi tải HỎNG ⇒ không bao giờ ra vòng trống.
                    .placeholder { thayThe }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                thayThe
            }
            #else
            thayThe
            #endif
        }
    }

    @ViewBuilder private var thayThe: some View {
        if let duPhong { duPhong } else { avatarPlaceholder }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(AppColors.backgroundTertiary)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(AppColors.textSecondary)
                    .font(.system(size: size * 0.5))
            )
    }
}
