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

// MARK: - Chữ tắt & tên ngắn của một người (22/10/2026)
//
// Lỗi thật trên ảnh nộp App Store (build 4): tên hiển thị "Minh (Demo)" ⇒ avatar "M(" khắp app (chữ tắt lấy ký tự đầu
// của 2 từ, kể cả dấu ngoặc) và hàng "Đang hoạt động" ghi "(Demo)" (lấy từ CUỐI). MỘT chỗ cho cả hai app:
//   · bỏ phần trong ngoặc (`(Demo)`, `[Bot]`, `{…}`, `（…）`, `【…】`) — đó là chú thích, không phải tên;
//   · một "từ" chỉ tính CHỮ CÁI (`Character.isLetter` — tiếng Việt có dấu, CJK… đều đúng); dấu câu/emoji/số bị bỏ;
//   · chữ tắt = chữ đầu của từ ĐẦU + từ CUỐI (cùng luật `initialsOf` của web), tối đa 2;
//   · tên ngắn = từ CUỐI (tên gọi của người Việt: "Hoàng Nghĩa Cường" ⇒ "Cường"; tên kiểu Tây "Linh Tran" ⇒ "Tran" —
//     giữ luật từ cuối cho đơn giản và đoán được).

enum TenNguoi {
    private static let ngoac = #"[\(\[\{（【][^\)\]\}）】]*[\)\]\}）】]"#

    /// Tên đã bỏ phần trong ngoặc + khoảng trắng thừa. Bỏ xong mà rỗng (cả tên nằm trong ngoặc) ⇒ chỉ bỏ ký tự ngoặc.
    static func boNgoac(_ ten: String) -> String {
        let bo = ten.replacingOccurrences(of: ngoac, with: " ", options: .regularExpression)
        let gon = bo.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        if gon.contains(where: \.isLetter) { return gon }
        return ten.filter { !"()[]{}（）【】".contains($0) }
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Các từ (tách theo khoảng trắng) còn chữ cái, mỗi từ đã cắt dấu câu/emoji ở HAI ĐẦU ("Anne-Marie", "O'Brien" giữ nguyên).
    static func cacTu(_ ten: String) -> [String] {
        boNgoac(ten).split(whereSeparator: \.isWhitespace).compactMap { tu -> String? in
            guard let dau = tu.firstIndex(where: \.isLetter), let cuoi = tu.lastIndex(where: \.isLetter) else { return nil }
            return String(tu[dau...cuoi])
        }
    }

    /// Chữ tắt cho avatar: tối đa 2 chữ cái (từ đầu + từ cuối), viết hoa. Không có chữ cái nào ⇒ thử `duPhong`
    /// (vd username), rồi "?".
    static func chuCaiDau(_ ten: String?, duPhong: String? = nil) -> String {
        for s in [ten, duPhong] {
            let tu = cacTu(s ?? "")
            guard let dau = tu.first?.first(where: \.isLetter) else { continue }
            var kq = String(dau).uppercased()
            if tu.count > 1, let cuoi = tu.last?.first(where: \.isLetter) { kq += String(cuoi).uppercased() }
            return kq
        }
        return "?"
    }

    /// Tên ngắn (hàng "Đang hoạt động", ghế poker…): từ cuối còn chữ cái, bỏ ngoặc/dấu câu. Không có ⇒ tên gốc đã gọn.
    static func tenNgan(_ ten: String) -> String {
        if let cuoi = cacTu(ten).last { return cuoi }
        let gon = ten.trimmingCharacters(in: .whitespacesAndNewlines)
        return gon
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
