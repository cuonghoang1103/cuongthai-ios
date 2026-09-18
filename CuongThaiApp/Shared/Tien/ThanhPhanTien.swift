import SwiftUI

// MARK: - Ô nhập số tiền
//
// Bàn phím `.numberPad` KHÔNG có dấu chấm và KHÔNG có nút xong; `.decimalPad`
// có dấu chấm nhưng người Việt gõ `1.500.000` theo thói quen và `Double("1.5")`
// đọc ra 1,5 chứ không phải 1,5 triệu. Nên ô này nhận chữ tự do rồi để
// `DinhDangTien.doc` hiểu, và hiện lại số đã hiểu ngay bên dưới — người dùng
// thấy được máy hiểu đúng hay sai TRƯỚC khi bấm lưu.
struct ONhapTien: View {
    let nhan: String
    @Binding var chu: String
    var tienTe: String = "VND"

    private var hieu: Double? { DinhDangTien.doc(chu) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(nhan).font(.captionBold).foregroundStyle(AppColors.textSecondary)
            HStack {
                TextField("0", text: $chu)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    #if os(iOS)
                    .keyboardType(.numbersAndPunctuation)
                    #endif
                Text(tienTe == "USD" ? "$" : "₫")
                    .font(.titleMedium).foregroundStyle(AppColors.textTertiary)
            }
            .padding(Spacing.sm)
            .background(AppColors.backgroundTertiary)
            .cornerRadius(CornerRadius.medium)

            // `v > 0` là SAI ở đây: `0` là số hợp lệ (ví mới mở, mục tiêu tắt),
            // và bắt nó rơi vào nhánh dưới làm ô "Số dư ban đầu 0" hiện dòng đỏ
            // "Chưa đọc được số này" ngay khi vừa mở form.
            if let v = hieu {
                Text("= \(DinhDangTien.day(v, tienTe))")
                    .font(.caption).foregroundStyle(AppColors.primary)
            } else if !chu.isEmpty {
                Text(T("Chưa đọc được số này"))
                    .font(.caption).foregroundStyle(AppColors.error)
            } else {
                // Giữ chỗ để khung không nhảy lên xuống khi bắt đầu gõ.
                Text(T("Gõ được cả 1.500.000 hay 1,5tr"))
                    .font(.caption).foregroundStyle(AppColors.textTertiary)
            }
        }
    }
}

// MARK: - Thẻ số liệu

struct TheSoTien: View {
    let nhan: String
    let so: Double
    var mau: Color = AppColors.textPrimary
    var bieuTuong: String?
    var phu: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                if let b = bieuTuong {
                    Image(systemName: b).font(.caption).foregroundStyle(mau)
                }
                Text(nhan).font(.caption).foregroundStyle(AppColors.textSecondary)
            }
            Text(DinhDangTien.ngan(so))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(mau)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let p = phu {
                Text(p).font(.caption2).foregroundStyle(AppColors.textTertiary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.sm + 2)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.medium)
    }
}

// MARK: - Thanh tiến độ

struct ThanhTienDoTien: View {
    let tiLe: Double          // 0…1 (vượt thì >1, tự kẹp lại khi vẽ)
    var mau: Color = AppColors.primary
    var cao: CGFloat = 8

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(AppColors.backgroundTertiary)
                Capsule().fill(mau)
                    .frame(width: max(0, min(1, tiLe)) * g.size.width)
            }
        }
        .frame(height: cao)
    }
}

// MARK: - Dòng trống

struct KhungTrongTien: View {
    let bieuTuong: String
    let tieuDe: String
    var moTa: String?
    var tenNut: String?
    var lamGi: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: bieuTuong)
                .font(.system(size: 40))
                .foregroundStyle(AppColors.textTertiary.opacity(0.6))
            Text(tieuDe).font(.titleSmall).foregroundStyle(AppColors.textPrimary)
            if let m = moTa {
                Text(m).font(.bodySmall).foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if let t = tenNut, let f = lamGi {
                Button(t, action: f)
                    .font(.buttonSmall)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(AppColors.primary)
                    .foregroundStyle(Color.white)
                    .cornerRadius(CornerRadius.full)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }
}

// MARK: - Bộ chọn ví / nhóm

struct ChonVi: View {
    let dsVi: [Vi]
    @Binding var viId: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(T("Ví")).font(.captionBold).foregroundStyle(AppColors.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(dsVi) { v in
                        Button { viId = v.id } label: {
                            HStack(spacing: 4) {
                                Text(v.bieuTuong)
                                Text(v.name).font(.bodySmall)
                            }
                            .padding(.horizontal, Spacing.sm + 2)
                            .padding(.vertical, 7)
                            .background(viId == v.id ? AppColors.primary : AppColors.backgroundTertiary)
                            .foregroundStyle(viId == v.id ? Color.white : AppColors.textPrimary)
                            .cornerRadius(CornerRadius.full)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
}

struct ChonNhomChi: View {
    let dsNhom: [NhomChi]
    @Binding var nhomId: Int?
    var choPhepTatCa = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(T("Nhóm")).font(.captionBold).foregroundStyle(AppColors.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    if choPhepTatCa {
                        the(T("Tất cả"), "🗂", nhomId == nil) { nhomId = nil }
                    }
                    ForEach(dsNhom) { n in
                        the(n.name, n.bieuTuong, nhomId == n.id) { nhomId = n.id }
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    private func the(_ ten: String, _ bt: String, _ chon: Bool, _ bam: @escaping () -> Void) -> some View {
        Button(action: bam) {
            HStack(spacing: 4) {
                Text(bt)
                Text(ten).font(.bodySmall)
            }
            .padding(.horizontal, Spacing.sm + 2)
            .padding(.vertical, 7)
            .background(chon ? AppColors.primary : AppColors.backgroundTertiary)
            .foregroundStyle(chon ? Color.white : AppColors.textPrimary)
            .cornerRadius(CornerRadius.full)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chọn tháng

struct ThanhChonThang: View {
    let thang: String
    let doi: (Int) -> Void

    var body: some View {
        HStack {
            Button { doi(-1) } label: {
                Image(systemName: "chevron.left").font(.bodyMedium)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColors.primary)

            Spacer(minLength: 0)
            Text(NgayTien.tenThang(thang))
                .font(.titleSmall)
                .foregroundStyle(AppColors.textPrimary)
            Spacer(minLength: 0)

            // Chặn đi tới TƯƠNG LAI: số liệu tháng sau luôn rỗng, và một màn
            // rỗng không có gì nói lên rằng nó rỗng vì chưa tới.
            Button { doi(1) } label: {
                Image(systemName: "chevron.right").font(.bodyMedium)
            }
            .buttonStyle(.plain)
            .foregroundStyle(thang >= NgayTien.thangHienTai() ? AppColors.textTertiary : AppColors.primary)
            .disabled(thang >= NgayTien.thangHienTai())
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.medium)
    }
}

// MARK: - Chọn ngày (gọn, không mở lịch)

struct ChonNgayTien: View {
    let nhan: String
    @Binding var ngay: String   // yyyy-MM-dd

    private var ngayDate: Binding<Date> {
        Binding(
            get: { NgayTien.mayChu.date(from: ngay) ?? Date() },
            set: { ngay = NgayTien.mayChu.string(from: $0) }
        )
    }

    var body: some View {
        HStack {
            Text(nhan).font(.captionBold).foregroundStyle(AppColors.textSecondary)
            Spacer()
            DatePicker("", selection: ngayDate, displayedComponents: .date)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "vi_VN"))
        }
    }
}
