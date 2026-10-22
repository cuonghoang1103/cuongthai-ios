import SwiftUI

// MARK: - CTWUI — mảnh dựng màn chi tiết/danh sách dùng chung
//
// Phê duyệt, Change request, RAID, kiểm thử, ticket… đều có "trạng thái dạng
// chuỗi" (không thuộc quy trình thẻ) và "bảng trường: giá trị". Gom về đây để
// mọi mô-đun cùng một nhịp nhìn.

/// Màu theo trạng thái chuỗi của máy chủ (không phân biệt hoa thường).
enum CTWMauTrangThai {
    static func mau(_ s: String?) -> Color {
        switch (s ?? "").uppercased() {
        case "APPROVED", "PASS", "PASSED", "DONE", "CLOSED", "RESOLVED", "IMPLEMENTED", "ACCEPTED", "ACTIVE",
             "COMPLETED", "MET", "PAID", "ON_TRACK", "GREEN", "LOW", "SUBMITTED", "GRADED", "VERIFIED":
            return AppColors.success
        case "REJECTED", "FAIL", "FAILED", "BREACHED", "CRITICAL", "HIGH", "RED", "OVERDUE", "OFF_TRACK", "CANCELLED",
             "CANCELED", "RETIRED", "MISSING":
            return AppColors.error
        case "PENDING", "IN_REVIEW", "SUBMITTED_FOR_REVIEW", "BLOCKED", "AT_RISK", "MEDIUM", "AMBER", "PAUSED", "WAITING",
             "WAITING_ON_CUSTOMER", "CHANGES_REQUESTED", "LATE", "DUE_SOON", "ESCALATED":
            return AppColors.warning
        case "IN_PROGRESS", "EXECUTING", "OPEN", "NEW", "ANALYSIS", "UNDER_REVIEW", "SCHEDULED", "RUNNING", "ASSIGNED":
            return AppColors.info
        default:
            return AppColors.textSecondary
        }
    }

    /// "IN_REVIEW" → "In review" (tiếng Việt: "Đang review").
    /// Mã trạng thái của MÁY CHỦ (không phải tên người dùng tự đặt) ⇒ dịch qua bảng `TrangThaiCTW.xcstrings`
    /// (khoá = mã viết hoa). Mã lạ / app chính (không có bảng) ⇒ chữ tiếng Anh tự dựng như cũ.
    static func nhan(_ s: String?) -> String {
        guard let s, !s.isEmpty else { return "—" }
        let t = s.replacingOccurrences(of: "_", with: " ").lowercased()
        let tuDung = t.prefix(1).uppercased() + t.dropFirst()
        return Bundle.main.localizedString(forKey: s.uppercased(), value: tuDung, table: "TrangThaiCTW")
    }
}

/// Chip trạng thái chuỗi (cùng dáng `CTWStatusChip`).
struct CTWChipChu: View {
    let chu: String?
    var mau: Color?
    var body: some View {
        let m = mau ?? CTWMauTrangThai.mau(chu)
        HStack(spacing: 5) {
            Circle().fill(m).frame(width: 6, height: 6)
            Text(CTWMauTrangThai.nhan(chu).uppercased())
                .font(.ctw(size: 10.5, weight: .bold)).foregroundColor(m).lineLimit(1).fixedSize()
        }
        .padding(.horizontal, 8).padding(.vertical, 3.5)
        .background(Capsule().fill(m.opacity(0.14)))
        .overlay(Capsule().strokeBorder(m.opacity(0.22), lineWidth: 0.5))
        .accessibilityLabel("Status: \(CTWMauTrangThai.nhan(chu))")
    }
}

/// Nhãn nhỏ trung tính (loại, mã, nhãn tự do).
struct CTWNhanNho: View {
    let chu: String
    var bieuTuong: String?
    var mau: Color = AppColors.textSecondary
    var body: some View {
        HStack(spacing: 4) {
            if let bieuTuong { Image(systemName: bieuTuong).font(.ctw(size: 9.5, weight: .bold)) }
            Text(chu).font(.ctw(size: 11, weight: .semibold)).lineLimit(1).fixedSize()
        }
        .foregroundColor(mau)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Capsule().fill(mau.opacity(0.10)))
    }
}

/// Một dòng "Trường — giá trị" trong khối chi tiết.
struct CTWHangTruong<GiaTri: View>: View {
    let nhan: String
    var bieuTuong: String?
    @ViewBuilder let giaTri: () -> GiaTri

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            HStack(spacing: 6) {
                if let bieuTuong {
                    Image(systemName: bieuTuong).font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary).frame(width: 16)
                }
                Text(nhan).font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
            }
            .frame(minWidth: 110, alignment: .leading)
            Spacer(minLength: 8)
            giaTri()
                .font(.ctw(size: 14))
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }
}

extension CTWHangTruong where GiaTri == Text {
    init(_ nhan: String, _ giaTri: String?, bieuTuong: String? = nil) {
        self.nhan = nhan
        self.bieuTuong = bieuTuong
        let g = giaTri?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.giaTri = { Text(g.isEmpty ? "—" : g) }
    }
}

/// Khối chứa các hàng trường — mặt thẻ chuẩn, có vạch ngăn.
struct CTWKhoiTruong<NoiDung: View>: View {
    @ViewBuilder let noiDung: () -> NoiDung
    var body: some View {
        VStack(spacing: 0) { noiDung() }
            .padding(.horizontal, 14)
            .ctwThe(14)
    }
}

/// Ô số đếm (tổng quan): số lớn + nhãn + biểu tượng.
struct CTWODem: View {
    let so: String
    let nhan: String
    var bieuTuong: String = "circle"
    var mau: Color = AppColors.primary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: bieuTuong).font(.ctw(size: 13, weight: .semibold)).foregroundColor(mau)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(mau.opacity(0.13)))
            Text(so).font(.ctw(size: 22, weight: .bold).monospacedDigit()).foregroundColor(AppColors.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.6)
            // Luôn GIỮ chỗ 2 dòng: trong lưới, nhãn dài ("Người đóng góp · 30 ngày") xuống dòng còn nhãn ngắn thì không
            // ⇒ các ô cùng hàng cao lệch nhau (iPad tiếng Việt, 22/10/2026). Giữ chỗ ⇒ mọi ô cao bằng nhau.
            Text(nhan).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                .lineLimit(2, reservesSpace: true).minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .ctwThe(14)
        .accessibilityElement(children: .combine)
    }
}

/// Thanh tiến độ ngang nhiều màu (đếm theo nhóm: pass/fail/blocked/todo…).
struct CTWThanhPhanDoan: View {
    let doan: [(gt: Int, mau: Color)]
    var cao: CGFloat = 8

    var body: some View {
        let tong = max(1, doan.reduce(0) { $0 + $1.gt })
        GeometryReader { g in
            HStack(spacing: 1.5) {
                ForEach(Array(doan.enumerated()), id: \.offset) { _, d in
                    if d.gt > 0 {
                        Rectangle().fill(d.mau)
                            .frame(width: max(3, g.size.width * CGFloat(d.gt) / CGFloat(tong)))
                    }
                }
            }
            .frame(width: g.size.width, alignment: .leading)
        }
        .frame(height: cao)
        .background(AppColors.backgroundTertiary)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }
}

/// Mở một trang web CT Work trong trình duyệt an toàn trong app — cho phần thiết
/// kế nặng (sơ đồ lớn, mockup…). KHÔNG dùng cho mua bán (3.1.1).
enum CTWWeb {
    static func url(slug: String, ma: String, doan: String) -> URL? {
        URL(string: "\(APIClient.diaChiGoc)/work/\(CTWAPI.doan(slug))/\(CTWAPI.doan(ma))/\(doan)")
    }
}
