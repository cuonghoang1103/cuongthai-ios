import SwiftUI

/// Cài đặt → Giao diện → Chủ đề & hiệu ứng.
///
/// Lưới thẻ xem trước (thẻ nào cũng CHẠY THẬT bằng đúng bộ vẽ của nền app, chỉ thu nhỏ) · công tắc Hiệu ứng động ·
/// Mật độ · Trang trí góc · Hạt ở mọi trang · Hiệu ứng khi chạm · Sáng/Tối/Tự động. Mọi thay đổi có hiệu lực ngay.
struct CaiDatChuDeView: View {
    @Bindable private var ql = QuanLyChuDe.shared
    @ObservedObject private var giaoDien = QuanLyGiaoDien.shared
    @Environment(\.accessibilityReduceMotion) private var giamChuyenDong

    private let cot = [GridItem(.adaptive(minimum: 150, maximum: 240), spacing: 12)]

    var body: some View {
        List {
            Section {
                LazyVGrid(columns: cot, spacing: 12) {
                    ForEach(ChuDe.allCases) { c in
                        TheXemThuChuDe(chuDe: c, dangChon: ql.chuDe == c,
                                       chay: ql.hieuUngDong && !giamChuyenDong && !ql.nguonThap) {
                            withAnimation(.easeInOut(duration: 0.3)) { ql.chuDe = c }
                            Haptics.cham()
                        }
                    }
                }
                .padding(.vertical, 6)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                .listRowBackground(Color.clear)
            } header: {
                Text(T("Chủ đề"))
            } footer: {
                if ql.chuDe == .tuDong, let m = ql.mua {
                    Text(String(format: T("Đang là mùa %@. Đông: tháng 11–12 · Xuân: 1–3 · Hạ: 4–7 · Thu: 8–10."), m.ten))
                }
            }

            Section {
                Toggle(isOn: $ql.hieuUngDong) {
                    nhan(T("Hiệu ứng động"), T("Hoa rơi, tuyết rơi, sóng, đèn nháy"), "sparkles")
                }
                VStack(alignment: .leading, spacing: 8) {
                    nhan(T("Mật độ"), nil, "circle.grid.3x3.fill")
                    Picker(T("Mật độ"), selection: $ql.matDo) {
                        ForEach(MatDoHat.allCases) { Text($0.ten).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .disabled(!ql.hieuUngDong)
                Toggle(isOn: $ql.trangTriGoc) {
                    nhan(T("Trang trí góc màn"), T("Đèn lồng, mặt trời, cây thông, chim cánh cụt…"), "square.dashed")
                }
                Toggle(isOn: $ql.hatMoiTrang) {
                    nhan(T("Hạt rơi ở mọi trang"), T("Vài hạt thưa ở mép các trang con"), "rectangle.stack")
                }
                .disabled(!ql.hieuUngDong)
                Toggle(isOn: $ql.hieuUngCham) {
                    nhan(T("Hiệu ứng khi chạm"), T("Bung vài cánh hoa / bông tuyết chỗ bạn chạm"), "hand.tap")
                }
                .disabled(!ql.hieuUngDong)
            } header: {
                Text(T("Hiệu ứng"))
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if giamChuyenDong {
                        Text(T("Đang đứng yên vì bạn bật Giảm chuyển động trong Cài đặt trợ năng."))
                    } else if ql.nguonThap {
                        Text(T("Đang đứng yên vì máy bật Chế độ nguồn điện thấp."))
                    }
                    Text(T("Màn đọc dài (bài học, đọc sách, Vở, làm bài thi, video) tự tắt chuyển động để bạn tập trung."))
                }
            }
            .disabled(ql.chuDe == .macDinh)

            Section {
                ForEach(CheDoGiaoDien.allCases) { c in
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { giaoDien.cheDo = c }
                        Haptics.cham()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: c.bieuTuong)
                                .foregroundColor(giaoDien.cheDo == c ? AppColors.primary : AppColors.textSecondary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.ten).foregroundColor(AppColors.textPrimary)
                                Text(c.moTa).font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
                            }
                            Spacer(minLength: 0)
                            if giaoDien.cheDo == c {
                                Image(systemName: "checkmark").font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text(T("Sáng / Tối"))
            }
        }
        .navigationTitle(T("Chủ đề & hiệu ứng"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .tint(AppColors.primary)
    }

    private func nhan(_ ten: String, _ moTa: String?, _ bieuTuong: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: bieuTuong).foregroundColor(AppColors.primary).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(ten).foregroundColor(AppColors.textPrimary)
                if let moTa { Text(moTa).font(.system(size: 12)).foregroundColor(AppColors.textTertiary) }
            }
        }
    }
}

/// Thẻ xem trước MỘT chủ đề: nền + hạt + trang trí chạy thật (thu nhỏ), một "thẻ nội dung" giả bằng chính bảng
/// màu của chủ đề đó — để thấy chữ trên nền trông ra sao trước khi chọn.
struct TheXemThuChuDe: View {
    let chuDe: ChuDe
    let dangChon: Bool
    var chay = true
    let chon: () -> Void
    @State private var dangHien = false

    var body: some View {
        let mua = chuDe.mua()
        let b = BangMauChuDe.cua(mua)
        Button(action: chon) {
            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    ZStack {
                        b.backgroundPrimary
                        NenMua(mua: mua, kieu: .xemThu, matDo: .vua, trangTri: true, chay: chay && dangHien)
                    }
                    // thẻ nội dung giả
                    VStack(alignment: .leading, spacing: 5) {
                        Capsule().fill(b.textPrimary).frame(width: 56, height: 6)
                        Capsule().fill(b.textSecondary.opacity(0.7)).frame(width: 78, height: 5)
                        Capsule().fill(b.primary).frame(width: 40, height: 12)
                    }
                    .padding(9)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(b.backgroundCard))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(b.border))
                    .padding(.leading, 26).padding(.bottom, 30)
                }
                .frame(height: 112)
                .clipped()

                HStack(spacing: 6) {
                    Image(systemName: chuDe.bieuTuong).font(.system(size: 13, weight: .semibold))
                        .foregroundColor(b.primary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(chuDe.ten).font(.system(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                            .lineLimit(1).minimumScaleFactor(0.8)
                        Text(chuDe.moTa).font(.system(size: 11)).foregroundColor(AppColors.textSecondary)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 0)
                    if dangChon {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(AppColors.primary)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(AppColors.backgroundCard)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(dangChon ? AppColors.primary : AppColors.border, lineWidth: dangChon ? 2.5 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(chuDe.ten)
        .accessibilityHint(chuDe.moTa)
        .accessibilityAddTraits(dangChon ? .isSelected : [])
        .onAppear { dangHien = true }
        .onDisappear { dangHien = false }
    }
}
