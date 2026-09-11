import SwiftUI

// ════════════════════════════════════════════════════════════════
// BUỔI HỌC KẾ TIẾP — thẻ điểm nhấn của trang chủ
//
// Trang chủ phải trả lời được câu hỏi đầu tiên của một ngày đi học: "sắp tới
// mình học gì, mấy giờ, ở đâu". Trước đây câu trả lời đó nằm dưới lời chào,
// con robot, khối chat và bốn ô thống kê — phải cuộn mới thấy.
//
// ⚠️ KHÔNG BỊA. Mọi thứ trên thẻ đều lấy từ `BuoiHoc` thật: tên môn, giờ,
// phòng, mã lớp. Trường nào rỗng thì dòng đó biến mất — không có ô trống mang
// dấu gạch ngang, và không có nút nào dẫn tới màn hình không tồn tại.
// ════════════════════════════════════════════════════════════════

/// Buổi học sắp diễn ra, quét trên CẢ TUẦN chứ không riêng hôm nay.
///
/// Tách khỏi View để tính được mà không phải dựng giao diện — giờ giấc là chỗ
/// dễ sai lệch-một (phút đầu, phút cuối, vắt qua Chủ nhật) mà nhìn mắt thường
/// không ra.
enum TimBuoiKeTiep {
    struct KetQua: Equatable {
        let buoi: BuoiHoc
        /// 0 = hôm nay, 1 = ngày mai, … Dùng để viết "Ngày mai" hay "Thứ 5".
        let soNgayNua: Int
    }

    /// - Parameters:
    ///   - thuHomNay: thứ theo hệ 2…8 của `BuoiHoc` (2 = thứ Hai, 8 = Chủ nhật).
    ///   - phutBayGio: số phút tính từ 00:00 của hôm nay.
    static func tim(_ ds: [BuoiHoc], thuHomNay: Int, phutBayGio: Int) -> KetQua? {
        guard !ds.isEmpty else { return nil }
        // Quét tám bước: hôm nay, sáu ngày tới, rồi vòng lại chính hôm nay của
        // tuần sau — để lịch chỉ có đúng một buổi vào thứ Ba vẫn tìm ra được
        // khi hôm nay LÀ thứ Ba và buổi đó đã tan.
        for buoc in 0...7 {
            let thu = ((thuHomNay - BuoiHoc.thuNho + buoc) % 7) + BuoiHoc.thuNho
            let trongNgay = ds
                .filter { $0.weekday == thu }
                .sorted { $0.phutBatDau < $1.phutBatDau }
            // Ngày 0 chỉ nhận buổi CHƯA tan — buổi đang học vẫn tính là "kế
            // tiếp" cho tới phút cuối, buổi đã tan thì không.
            let hop = buoc == 0
                ? trongNgay.first { $0.phutKetThuc > phutBayGio }
                : trongNgay.first
            if let b = hop { return KetQua(buoi: b, soNgayNua: buoc) }
        }
        return nil
    }
}

struct TheBuoiKeTiep: View {
    let ketQua: TimBuoiKeTiep.KetQua?
    /// Lịch có rỗng thật không. Phân biệt "chưa nhập thời khoá biểu" với
    /// "có nhập nhưng không dò ra buổi nào" — hai chuyện khác nhau, và lời
    /// khuyên cho người dùng cũng khác nhau.
    let coLich: Bool
    /// Hôm nay đã hết giờ học chưa. Chỉ để ghi thêm một dòng cho rõ khi buổi
    /// kế tiếp đã rơi sang ngày khác.
    var hetGioHomNay = false
    /// Phút trong ngày. Truyền vào để thẻ không phải giữ đồng hồ riêng —
    /// `TimelineView` ở ngoài lo nhịp cập nhật.
    let phutBayGio: Int

    var moChiTiet: (BuoiHoc) -> Void
    var moBaiHoc: ([String]) -> Void
    var moLich: () -> Void

    @ScaledMetric(relativeTo: .title2) private var coTenMon: CGFloat = 22

    var body: some View {
        if let kq = ketQua {
            theCoLich(kq)
        } else {
            theTrong
        }
    }

    // MARK: Có buổi học

    private func theCoLich(_ kq: TimBuoiKeTiep.KetQua) -> some View {
        let b = kq.buoi
        let tt: TrangThaiBuoi = kq.soNgayNua == 0
            ? TrangThaiBuoi.tinh(batDau: b.startTime, ketThuc: b.endTime, bayGio: phutBayGio)
            : .chuaToi(phut: 0)
        let dangHoc: Bool = { if case .dangHoc = tt { return true }; return false }()
        let mauNhan = dangHoc ? AppColors.success : AppColors.primary
        // Cùng phép rút mã môn mà hàng việc đang dùng. Không rút được mã thì
        // KHÔNG hiện nút — thà thiếu một nút còn hơn một nút mở ra màn rỗng.
        let dsMa = HocGiChoMonView.maMon(tu: "\(b.subject) \(b.classCode ?? "")")

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Button { moChiTiet(b) } label: {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: 6) {
                        Circle().fill(mauNhan).frame(width: 7, height: 7)
                        Text(nhan(kq, tt))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(mauNhan)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.textTertiary)
                    }

                    Text(b.subject)
                        .font(.system(size: coTenMon, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Giờ và phòng bám nhau trên một hàng và tự xuống dòng khi
                    // chữ to lên — `FlowLayout` chưa có trong dự án nên dùng
                    // hai hàng lồng, rẻ hơn là thêm layout mới.
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: Spacing.md) {
                            chiTiet("clock", "\(b.startTime)–\(b.endTime)")
                            if let p = b.room, !p.isEmpty { chiTiet("mappin.and.ellipse", p) }
                            Spacer(minLength: 0)
                        }
                        HStack(spacing: Spacing.md) {
                            if let l = b.classCode, !l.isEmpty { chiTiet("person.2", l) }
                            if let gv = b.teacher, !gv.isEmpty { chiTiet("person.crop.circle", gv) }
                            Spacer(minLength: 0)
                        }
                    }

                    if hetGioHomNay && kq.soNgayNua > 0 {
                        Text(T("Hôm nay đã hết giờ học."))
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(T("Mở chi tiết buổi học"))

            if !dsMa.isEmpty {
                Button { moBaiHoc(dsMa) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "book").font(.system(size: 12, weight: .semibold))
                        Text(T("Bài cần chuẩn bị")).font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(AppColors.primary)
                    .padding(.horizontal, 13)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(AppColors.primary.opacity(0.12)))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppColors.backgroundCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(mauNhan.opacity(dangHoc ? 0.55 : 0.26),
                                      lineWidth: dangHoc ? 1.5 : 1)
                )
        )
    }

    private func chiTiet(_ bieuTuong: String, _ chu: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: bieuTuong)
                .font(.system(size: 12))
                .foregroundColor(AppColors.textTertiary)
            Text(chu)
                .font(.system(size: 14, weight: .medium).monospacedDigit())
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    /// Nhãn trạng thái. CHỈ nói điều tính được từ dữ liệu.
    private func nhan(_ kq: TimBuoiKeTiep.KetQua, _ tt: TrangThaiBuoi) -> String {
        if kq.soNgayNua == 0 {
            switch tt {
            case .dangHoc(let conLai, _):
                return String(format: T("Đang học · còn %@"), TrangThaiBuoi.doDai(conLai))
            case .chuaToi(let phut):
                return phut <= 0
                    ? T("Sắp vào học")
                    : String(format: T("Vào học sau %@"), TrangThaiBuoi.doDai(phut))
            case .daXong:
                return T("Buổi học kế tiếp")
            }
        }
        if kq.soNgayNua == 1 { return String(format: T("Ngày mai · %@"), kq.buoi.startTime) }
        return "\(BuoiHoc.tenThu(kq.buoi.weekday)) · \(kq.buoi.startTime)"
    }

    // MARK: Chưa có buổi nào

    private var theTrong: some View {
        Button(action: moLich) {
            HStack(spacing: Spacing.md) {
                Image(systemName: coLich ? "calendar" : "calendar.badge.plus")
                    .font(.system(size: 22))
                    .foregroundColor(AppColors.primary)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(coLich ? T("Không có buổi học nào sắp tới")
                                : T("Chưa có thời khoá biểu"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(coLich ? T("Mở lịch tuần để xem lại")
                                : T("Thêm lịch để app nhắc bạn trước giờ lên lớp"))
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AppColors.backgroundCard)
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(AppColors.border, lineWidth: 1))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
