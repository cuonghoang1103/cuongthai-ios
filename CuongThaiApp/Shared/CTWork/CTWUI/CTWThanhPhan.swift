import SwiftUI

// MARK: - CTWUI — thành phần giao diện DÙNG CHUNG của CT Work
//
// Thư viện giao diện của cả app CT Work riêng lẫn module CT Work trong app
// chính. Mô-đun mới DÙNG LẠI những thứ ở đây (đừng tự vẽ avatar/chip riêng) để
// toàn app đồng bộ. Danh mục đầy đủ: `CuongThaiApp/CTWorkApp/KIEN_TRUC.md`.
// Luật màu: CHỈ dùng `AppColors.*` (màu ngữ nghĩa, tự đổi sáng/tối).

// MARK: - Vòng tròn người

struct CTWAvatar: View {
    let user: CTWUser?
    var size: CGFloat = 24

    var body: some View {
        Group {
            if let u = user {
                // Ảnh (đã giải đường dẫn tương đối / khoá R2, bỏ SVG — `DuongDanAnh`); không có, đang tải hoặc tải
                // HỎNG ⇒ avatar chữ cái (20/10: chủ app thấy vòng trống trên iPhone thật).
                if DuongDanAnh.urlAnh(u.avatarUrl) != nil {
                    UserAvatarView(url: u.avatarUrl, size: size, duPhong: AnyView(chuCai(u)))
                } else {
                    chuCai(u)
                }
            } else {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.ctw(size: size * 0.75))
                    .foregroundColor(AppColors.textTertiary)
                    .frame(width: size, height: size)
            }
        }
        // Agent AI: chấm ✦ góc dưới — nhận ra ngay cả ở chỗ chỉ có avatar
        // (thẻ trên bảng), không cần đọc tên.
        .overlay(alignment: .bottomTrailing) {
            if user?.laAgent == true {
                Image(systemName: "sparkles")
                    .font(.ctw(size: max(7, size * 0.3), weight: .bold))
                    .foregroundColor(.white)
                    .padding(max(1.5, size * 0.06))
                    .background(Circle().fill(AppColors.primary))
                    .overlay(Circle().strokeBorder(AppColors.backgroundCard, lineWidth: 1))
                    .offset(x: size * 0.12, y: size * 0.12)
            }
        }
        .accessibilityLabel(user.map { $0.laAgent ? String(localized: "\($0.ten), AI agent") : $0.ten } ?? String(localized: "Unassigned"))
    }

    /// Màu cố định theo người — cùng luật `avatarColor(username)` của web (CTWKieuWeb), nên một người mang cùng màu
    /// ở web lẫn app và các avatar trên bảng phân biệt được nhau. Agent: góc vuông bo (như web).
    private func chuCai(_ u: CTWUser) -> some View {
        let hinh = RoundedRectangle(cornerRadius: u.laAgent ? size * 0.3 : size / 2, style: .continuous)
        return Text(u.kyTuDau)
            .font(.ctw(size: size * 0.4, weight: .semibold))
            .foregroundColor(.white)
            .minimumScaleFactor(0.6)
            .frame(width: size, height: size)
            .background(hinh.fill(CTWKieuWeb.mau(u.username ?? u.ten)))
            .overlay(hinh.strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5))
    }
}

struct CTWTypeIcon: View {
    let type: CTWIssueType?
    var size: CGFloat = 14

    var body: some View {
        Image(systemName: CTW.bieuTuongLoai(type))
            .font(.ctw(size: size * 0.7, weight: .bold))
            .foregroundColor(.white)
            .frame(width: size + 4, height: size + 4)
            .background(RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(CTW.mau(type?.color, macDinh: AppColors.info)))
            .accessibilityLabel(type?.name ?? String(localized: "Issue"))
    }
}

struct CTWPriorityIcon: View {
    let priority: Int?
    var body: some View {
        let p = CTW.uuTien(priority)
        Image(systemName: p.bieuTuong)
            .font(.ctw(size: 11, weight: .bold))
            .foregroundColor(p.mau)
            .accessibilityLabel("\(p.ten) priority")
    }
}

struct CTWStatusChip: View {
    let ten: String?
    let category: String?

    init(status: CTWStatus?) { ten = status?.name; category = status?.category }
    init(ten: String?, category: String?) { self.ten = ten; self.category = category }

    /// Kiểu web `StatusBadge`: glyph (hình + màu) + tên viết kiểu câu, ô bo 6, nền pha màu nhóm. Chữ giữ màu chữ
    /// thường (không tô màu nhóm) ⇒ đạt tương phản ở mọi nhóm, màu chỉ nằm ở glyph/viền.
    var body: some View {
        let mau = CTWKieuWeb.mauNhom(category)
        let laTodo = category != "IN_PROGRESS" && category != "DONE"
        HStack(spacing: 5) {
            CTWStatusGlyph(category: category, co: CTWCoChu.co(11))
            Text(CTWKieuWeb.chuCau(ten ?? "—"))
                .font(.ctw(size: 12, weight: .medium))
                .foregroundColor(laTodo ? AppColors.textSecondary : AppColors.textPrimary)
                .lineLimit(1)
        }
        .padding(.leading, 6).padding(.trailing, 7).padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(laTodo ? AppColors.backgroundTertiary : mau.opacity(0.11)))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
            .strokeBorder(laTodo ? AppColors.border : mau.opacity(0.30), lineWidth: 0.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Status: \(ten ?? "")"))
    }
}

/// Tiêu đề một khối trong màn chi tiết — biểu tượng + chữ + đếm tuỳ chọn.
/// Một chỗ để các khối (Description, Sub-tasks, Comments…) đồng nhất.
struct CTWSectionHeader: View {
    let icon: String
    let title: String
    var count: String?
    var trailing: AnyView?

    init(_ icon: String, _ title: String, count: String? = nil, trailing: AnyView? = nil) {
        self.icon = icon; self.title = title; self.count = count; self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.ctw(size: 13, weight: .semibold))
                .foregroundColor(AppColors.primary)
            Text(title)
                .font(.ctw(size: 15, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            if let count {
                Text(count)
                    .font(.ctw(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Capsule().fill(AppColors.backgroundTertiary))
            }
            Spacer(minLength: 0)
            if let trailing { trailing }
        }
    }
}

/// Dải lỗi nhỏ đặt trên đầu màn — lỗi nói tại chỗ, không bật hộp thoại.
struct CTWErrorBanner: View {
    let text: String
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(AppColors.error)
            Text(text)
                .font(.ctw(size: 13))
                .foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark").font(.ctw(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppColors.error.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(AppColors.error.opacity(0.22), lineWidth: 0.5))
    }
}

extension View {
    /// Mặt thẻ chuẩn của CT Work: nền thẻ, bo góc liền mạch, viền mảnh và một
    /// lớp bóng rất nhẹ — để mọi thẻ trong module trông cùng một hệ, hợp HIG.
    /// Bóng đổ gắn THẲNG vào hình nền (không vào nội dung) nên chữ không nhoè.
    func ctwThe(_ radius: CGFloat = 14) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(AppColors.backgroundCard)
                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(AppColors.border, lineWidth: 0.5)
            )
    }

    /// `insetGrouped` chỉ có trên iOS — macOS dùng `inset`.
    @ViewBuilder
    func ctwKieuDanhSach() -> some View {
        #if os(iOS)
        self.listStyle(.insetGrouped)
        #else
        self.listStyle(.inset)
        #endif
    }

    /// Tiêu đề nhỏ (inline) — chỉ iOS có khái niệm này.
    @ViewBuilder
    func ctwTieuDeNho() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
