import SwiftUI

// MARK: - Support contact
//
// App Store Guideline 1.2 requires published contact information so users can
// reach the moderation team. This is the same address published on the website
// footer, so the two never drift apart.
enum SupportContact {
    static let email = "cuongthaihnhe176322@gmail.com"
    static let privacyPolicyURL = URL(string: "https://cuongthai.com/chinh-sach-bao-mat")!
    static let websiteURL = URL(string: "https://cuongthai.com")!
    /// Apple's standard EULA, referenced by the terms below.
    static let appleEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

// MARK: - Terms of Use (EULA)

struct TermsView: View {
    /// Đặt `true` khi mở dạng sheet để có nút "Xong".
    var dismissible: Bool = false

    var body: some View {
        LegalScrollView(title: "Điều khoản sử dụng", dismissible: dismissible) {
            LegalSection("1. Chấp nhận điều khoản") {
                Text("Khi tạo tài khoản hoặc sử dụng ứng dụng CuongThai, bạn đồng ý với các điều khoản dưới đây. Nếu không đồng ý, vui lòng ngừng sử dụng ứng dụng.")
            }

            LegalSection("2. Quy tắc nội dung — KHÔNG KHOAN NHƯỢNG") {
                Text("CuongThai áp dụng chính sách không khoan nhượng với nội dung phản cảm và hành vi lạm dụng. Bạn KHÔNG được đăng tải, gửi hoặc chia sẻ:")
                LegalBullet("Nội dung quấy rối, đe doạ, bắt nạt hoặc thù ghét nhắm vào cá nhân hay nhóm người")
                LegalBullet("Nội dung khiêu dâm, bạo lực, máu me hoặc gây sốc")
                LegalBullet("Nội dung vi phạm bản quyền hoặc quyền sở hữu trí tuệ của người khác")
                LegalBullet("Spam, lừa đảo, quảng cáo trá hình, mã độc")
                LegalBullet("Thông tin sai sự thật gây hại, hoặc thông tin cá nhân của người khác khi chưa được phép")
                Text("Vi phạm dẫn tới gỡ nội dung và khoá tài khoản vĩnh viễn, không hoàn lại quyền lợi.")
                    .fontWeight(.semibold)
            }

            LegalSection("3. Báo cáo và chặn") {
                Text("Mỗi bài viết đều có nút Báo cáo, và bạn có thể chặn bất kỳ người dùng nào từ bài viết, trang cá nhân hoặc cuộc trò chuyện của họ. Nội dung bị báo cáo được ẩn khỏi màn hình của bạn ngay lập tức.")
                Text("Đội ngũ kiểm duyệt xem xét mọi báo cáo trong vòng 24 giờ và gỡ nội dung vi phạm cùng tài khoản đăng tải nội dung đó.")
            }

            LegalSection("4. Tài khoản của bạn") {
                Text("Bạn chịu trách nhiệm giữ an toàn cho mật khẩu và mọi hoạt động diễn ra dưới tài khoản của mình. Bạn phải từ 13 tuổi trở lên để sử dụng ứng dụng.")
                Text("Bạn có thể xoá tài khoản bất cứ lúc nào trong Cài đặt → Xoá tài khoản.")
            }

            LegalSection("5. Nội dung bạn đăng") {
                Text("Bạn giữ quyền sở hữu nội dung mình đăng. Bạn cấp cho CuongThai quyền lưu trữ và hiển thị nội dung đó trong ứng dụng nhằm mục đích vận hành dịch vụ. Khi bạn xoá nội dung hoặc tài khoản, nội dung sẽ được gỡ khỏi dịch vụ.")
            }

            LegalSection("6. Nội dung do AI tạo") {
                Text("Một số tính năng sử dụng trí tuệ nhân tạo. Câu trả lời của AI có thể không chính xác và không thay thế lời khuyên chuyên môn. Vui lòng kiểm chứng trước khi sử dụng, và báo cáo nếu AI tạo ra nội dung không phù hợp.")
            }

            LegalSection("7. Giới hạn trách nhiệm") {
                Text("Dịch vụ được cung cấp \"nguyên trạng\". Chúng tôi không chịu trách nhiệm với thiệt hại gián tiếp phát sinh từ việc sử dụng ứng dụng, trong phạm vi pháp luật cho phép.")
            }

            LegalSection("8. Liên hệ") {
                Text("Mọi thắc mắc, khiếu nại hoặc yêu cầu gỡ nội dung: \(SupportContact.email)")
                Link("Điều khoản mẫu của Apple (Apple Standard EULA)", destination: SupportContact.appleEULA)
                    .font(.footnote)
            }
        }
    }
}

// MARK: - Privacy Policy

struct PrivacyPolicyView: View {
    /// Đặt `true` khi mở dạng sheet để có nút "Xong".
    var dismissible: Bool = false

    var body: some View {
        LegalScrollView(title: "Chính sách bảo mật", dismissible: dismissible) {
            LegalSection("Dữ liệu chúng tôi thu thập") {
                LegalBullet("Thông tin tài khoản: tên đăng nhập, email, họ tên, ảnh đại diện")
                LegalBullet("Nội dung bạn tạo: bài viết, bình luận, tin nhắn, ghi chú, ảnh và video bạn tải lên")
                LegalBullet("Dữ liệu sử dụng: khoá học đã đăng ký, tiến độ học, thời điểm đăng nhập")
            }

            LegalSection("Cách chúng tôi dùng dữ liệu") {
                Text("Chỉ để vận hành dịch vụ: hiển thị nội dung cho đúng người, đồng bộ giữa thiết bị và website, chống lạm dụng. Chúng tôi KHÔNG bán dữ liệu cá nhân và KHÔNG dùng dữ liệu để theo dõi bạn trên ứng dụng của bên thứ ba.")
            }

            LegalSection("Đăng nhập bằng Apple") {
                Text("Nếu bạn dùng Đăng nhập bằng Apple và chọn ẩn email, chúng tôi chỉ nhận được địa chỉ chuyển tiếp riêng tư của Apple. Chúng tôi lưu địa chỉ đó để nhận diện tài khoản, không dùng cho mục đích nào khác.")
            }

            LegalSection("Lưu trữ và bảo mật") {
                Text("Dữ liệu lưu trên máy chủ tại Việt Nam. Mã đăng nhập trên máy bạn được cất trong Keychain của iOS — mã hoá và không đi theo bản sao lưu iCloud.")
            }

            LegalSection("Quyền của bạn") {
                LegalBullet("Xem và sửa dữ liệu cá nhân trong Cài đặt → Chỉnh sửa hồ sơ")
                LegalBullet("Xoá tài khoản và toàn bộ dữ liệu trong Cài đặt → Xoá tài khoản")
                LegalBullet("Yêu cầu bản sao dữ liệu qua email \(SupportContact.email)")
            }

            LegalSection("Liên hệ") {
                Text(SupportContact.email)
                Link("Bản đầy đủ trên website", destination: SupportContact.privacyPolicyURL)
                    .font(.footnote)
            }
        }
    }
}

// MARK: - Help / moderation contact

struct HelpView: View {
    /// Đặt `true` khi mở dạng sheet để có nút "Xong".
    var dismissible: Bool = false

    var body: some View {
        LegalScrollView(title: "Trợ giúp", dismissible: dismissible) {
            LegalSection("Báo cáo nội dung xấu") {
                Text("Chạm biểu tượng ••• ở góc phải mỗi bài viết → Báo cáo. Bài viết sẽ được ẩn khỏi bảng tin của bạn ngay và chuyển tới đội kiểm duyệt.")
            }
            LegalSection("Chặn một người") {
                Text("Chạm ••• trên bài viết của họ → Chặn người này. Bạn có thể bỏ chặn bất cứ lúc nào trong Cài đặt → Danh sách chặn.")
            }
            LegalSection("Quên mật khẩu") {
                Text("Đăng xuất rồi dùng chức năng quên mật khẩu trên website \(SupportContact.websiteURL.absoluteString). Mã xác thực sẽ gửi tới email của bạn.")
            }
            LegalSection("Liên hệ đội ngũ") {
                Text("Email: \(SupportContact.email)")
                Text("Chúng tôi phản hồi mọi báo cáo trong vòng 24 giờ.")
                Link("cuongthai.com", destination: SupportContact.websiteURL)
                    .font(.footnote)
            }
        }
    }
}

// MARK: - First-launch consent (Guideline 1.2)

struct TermsConsentView: View {
    let onAccept: () -> Void
    @State private var showTerms = false

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 52))
                .foregroundColor(AppColors.primary)
                .padding(.top, Spacing.xxl)

            Text("Quy tắc cộng đồng")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppColors.textPrimary)

            VStack(alignment: .leading, spacing: Spacing.md) {
                LegalBullet("Không quấy rối, đe doạ hay xúc phạm người khác")
                LegalBullet("Không đăng nội dung khiêu dâm, bạo lực hay vi phạm bản quyền")
                LegalBullet("Nội dung vi phạm bị gỡ và tài khoản bị khoá vĩnh viễn")
                LegalBullet("Mọi bài viết đều có nút Báo cáo; bạn có thể chặn bất kỳ ai")
            }
            .padding(Spacing.lg)
            .background(AppColors.backgroundSecondary)
            .cornerRadius(CornerRadius.large)
            .padding(.horizontal, Spacing.lg)

            Button("Đọc toàn bộ điều khoản") { showTerms = true }
                .font(.footnote)
                .foregroundColor(AppColors.primary)

            Spacer()

            Button {
                StorageManager.shared.hasAcceptedTerms = true
                onAccept()
            } label: {
                Text("Tôi đồng ý")
                    .font(.buttonText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(AppColors.primary)
                    .foregroundColor(.white)
                    .cornerRadius(CornerRadius.medium)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundPrimary)
        .sheet(isPresented: $showTerms) {
            NavigationStack { TermsView(dismissible: true) }
        }
    }
}

// MARK: - Shared layout helpers

private struct LegalScrollView<Content: View>: View {
    let title: String
    /// Mở dạng sheet thì PHẢI có nút đóng. Không có thì người dùng bấm khắp
    /// màn hình không ra gì và tưởng app treo — đúng nghĩa đen đã xảy ra.
    /// Vuốt xuống vẫn đóng được, nhưng không ai đoán ra khi màn hình đầy chữ.
    /// Khi được đẩy vào từ Cài đặt thì KHÔNG đặt cờ này: đã có nút Back.
    let dismissible: Bool
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss

    init(title: String, dismissible: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        self.dismissible = dismissible
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                content
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if dismissible {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xong") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct LegalSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            content
                .font(.system(size: 15))
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LegalBullet: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text("•")
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .font(.system(size: 15))
        .foregroundColor(AppColors.textSecondary)
    }
}
