import SwiftUI

// MARK: - CTWUI — ngôn ngữ hình ảnh CHUNG với web CT Work (20/10/2026)
//
// Người dùng chuyển qua lại web ↔ app nên dấu dự án, glyph trạng thái, chip hạn, nhãn, điểm và màu avatar theo
// người lấy ĐÚNG luật của web (`frontend/src/components/work/ui.tsx`, `board/BoardCard.tsx`). Dùng chung cho cả app
// chính lẫn app CT Work riêng — chỉ dùng `AppColors.*` + màu dữ liệu (màu loại thẻ, nhãn) nên tự theo sáng/tối.

enum CTWKieuWeb {
    /// `AVATAR_COLORS` của web — mọi màu đạt ≥ 4,7:1 với chữ trắng (đo 20/10/2026).
    static let bangMau: [UInt32] = [0x5E6AD2, 0x2A8159, 0xA9561F, 0xB83F6F, 0x2A6FD1, 0x8A4FD1, 0x0D7A76, 0x8F6212, 0xC9423E, 0x56627A]

    /// `hashStr` của web: h = h·31 + mã UTF-16 (gói 32 bit có dấu), lấy trị tuyệt đối ⇒ cùng chuỗi cùng màu ở web và app.
    static func bam(_ s: String) -> Int {
        var h: Int32 = 0
        for c in s.utf16 { h = h &* 31 &+ Int32(c) }
        return Int(Int64(h).magnitude % UInt64(Int.max))
    }

    /// Màu cố định theo chuỗi (mã dự án, username).
    static func mau(_ hat: String) -> Color {
        Color(hex: bangMau[bam(hat.isEmpty ? "?" : hat) % bangMau.count])
    }

    /// "In review" thay vì "IN REVIEW" (web `sentenceCase`): viết hoa chữ đầu, giữ chữ viết tắt ≤ 3 ký tự (QA, UAT).
    static func chuCau(_ ten: String) -> String {
        let tu = ten.split(whereSeparator: \.isWhitespace)
        // Cả tên VIẾT HOA ("IN REVIEW") ⇒ không có chữ viết tắt nào để giữ — hạ hết (web giữ "IN" ⇒ "IN review").
        let caTenHoa = ten == ten.uppercased()
        return tu.enumerated().map { i, w -> String in
            let s = String(w)
            if !caTenHoa, s.count > 1, s.count <= 3, s == s.uppercased(), s.rangeOfCharacter(from: .letters) != nil { return s }
            let thuong = s.lowercased()
            return i == 0 ? thuong.prefix(1).uppercased() + thuong.dropFirst() : thuong
        }.joined(separator: " ")
    }

    /// Màu nhóm trạng thái (đồ hoạ — glyph/chấm): chưa làm xám · đang làm xanh dương · xong xanh lá.
    static func mauNhom(_ category: String?) -> Color {
        switch category {
        case "DONE": return AppColors.success
        case "IN_PROGRESS": return AppColors.info
        default: return AppColors.textTertiary
        }
    }

    // MARK: Ngày

    /// Ngày `YYYY-MM-DD` (hoặc ISO) ⇒ "Oct 5" / "5 thg 10" (khác năm: "Oct 5, 2027" / "5 thg 10, 2027") theo NGÔN NGỮ
    /// APP đang chọn (`CTWDinhDang.locale` — đổi trong Account là đổi ngay), không theo ngôn ngữ máy.
    static func ngay(_ s: String?) -> String? {
        guard let d = CTW.ngayDate(s) else { return nil }
        var lich = Calendar(identifier: .gregorian)
        let utc = TimeZone(identifier: "UTC") ?? .current
        lich.timeZone = utc
        let khacNam = lich.component(.year, from: d) != Calendar.current.component(.year, from: Date())
        return CTWDinhDang.mau(khacNam ? "yMMMd" : "MMMd", muiGio: utc).string(from: d)
    }

    /// Hạn rơi vào HÔM NAY (theo ngày máy).
    static func laHomNay(_ s: String?) -> Bool {
        guard let d = CTW.ngay(s) else { return false }
        return d == CTW.chuoiNgay(Date())
    }
}

// MARK: - Dấu dự án (web `ProjectMark`)

/// Ô vuông bo màu theo mã dự án + chữ đầu (hoặc cả mã khi `caMa`). Cùng màu với web.
struct CTWProjectMark: View {
    let ma: String
    var co: CGFloat = 20
    var caMa = false

    var body: some View {
        Text(caMa ? ma : String(ma.prefix(1)).uppercased())
            .font(.ctw(size: caMa ? max(9, co * 0.3) : co * 0.52, weight: .bold, design: caMa ? .monospaced : .default))
            .foregroundColor(.white)
            .lineLimit(1).minimumScaleFactor(0.5)
            .padding(.horizontal, caMa ? 3 : 0)
            .frame(width: co, height: co)
            .background(RoundedRectangle(cornerRadius: co * 0.26, style: .continuous).fill(CTWKieuWeb.mau(ma)))
            .overlay(RoundedRectangle(cornerRadius: co * 0.26, style: .continuous).strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5))
            .accessibilityHidden(true)
    }
}

// MARK: - Glyph trạng thái (web `StatusGlyph`)

/// Hình + màu (không chỉ màu — cho người mù màu): vòng rỗng = chưa làm · vòng nửa đặc = đang làm · đặc có ✓ = xong.
struct CTWStatusGlyph: View {
    let category: String?
    var co: CGFloat = 12

    var body: some View {
        let mau = CTWKieuWeb.mauNhom(category)
        ZStack {
            switch category {
            case "DONE":
                Circle().fill(mau)
                Image(systemName: "checkmark").font(.system(size: co * 0.55, weight: .heavy)).foregroundColor(AppColors.backgroundCard)
            case "IN_PROGRESS":
                Circle().strokeBorder(mau, lineWidth: max(1.3, co * 0.12))
                NuaPhai().fill(mau).padding(co * 0.27)
            default:
                Circle().strokeBorder(mau, lineWidth: max(1.3, co * 0.12))
            }
        }
        .frame(width: co, height: co)
        .accessibilityHidden(true)
    }

    private struct NuaPhai: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: r.midX, y: r.minY))
            p.addArc(center: CGPoint(x: r.midX, y: r.midY), radius: r.width / 2, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
            p.closeSubpath()
            return p
        }
    }
}

// MARK: - Chip hạn (web `DueChip`)

/// Lịch + "Oct 5". Quá hạn ⇒ đỏ trên nền đỏ nhạt; hôm nay ⇒ cam "Today"; còn lại xám trên nền lõm.
struct CTWDueChip: View {
    let dueDate: String?
    /// Thẻ đã xong ⇒ không còn "quá hạn".
    var xong = false
    var co: CGFloat = 11

    var body: some View {
        if let chu = CTWKieuWeb.ngay(dueDate) {
            let tre = !xong && CTW.quaHan(dueDate)
            let homNay = !xong && CTWKieuWeb.laHomNay(dueDate)
            let mau = tre ? AppColors.error : (homNay ? AppColors.accent : AppColors.textSecondary)
            HStack(spacing: 3) {
                Image(systemName: "calendar").font(.ctw(size: co - 1, weight: .semibold))
                if homNay { Text("Today") } else { Text(chu) }
            }
            .font(.ctw(size: co, weight: tre || homNay ? .semibold : .medium).monospacedDigit())
            .foregroundColor(mau)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(tre || homNay ? mau.opacity(0.12) : AppColors.backgroundTertiary))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(tre ? Text("Overdue, was due \(chu)") : (homNay ? Text("Due today") : Text("Due \(chu)")))
        }
    }
}

// MARK: - Nhãn + điểm (web `LabelChip` · `PointsBadge`)

struct CTWLabelChip: View {
    let label: CTWLabel

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(CTW.mau(label.color, macDinh: AppColors.textTertiary))
                .frame(width: 7, height: 7)
            Text(label.name).lineLimit(1)
        }
        .font(.ctw(size: 11, weight: .medium))
        .foregroundColor(AppColors.textSecondary)
        .padding(.horizontal, 6).padding(.vertical, 2.5)
        .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(AppColors.backgroundTertiary))
        .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(AppColors.border, lineWidth: 0.5))
    }
}

struct CTWPointsBadge: View {
    let diem: Double

    var body: some View {
        let chu = diem == diem.rounded() ? String(Int(diem)) : String(format: "%.1f", diem)
        Text(chu)
            .font(.ctw(size: 11, weight: .semibold).monospacedDigit())
            .foregroundColor(AppColors.textSecondary)
            .padding(.horizontal, 5).padding(.vertical, 1.5)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(AppColors.backgroundTertiary))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(AppColors.border, lineWidth: 0.5))
            .accessibilityLabel(Text("\(chu) points"))
    }
}
