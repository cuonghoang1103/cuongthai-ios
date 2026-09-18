import SwiftUI

/// Đặt mục tiêu chi tiêu cho NGÀY / TUẦN / THÁNG.
///
/// Ba kỳ độc lập nhau — đặt một cái không ràng buộc hai cái kia. Đặt `0` là
/// tắt kỳ đó (backend giữ hàng lại để còn biết "đặt từ bao giờ", xem
/// `datMucTieu` trong `nhacNhiem.service.ts`).
struct MucTieuChiView: View {
    @ObservedObject var vm: TienVM
    @Environment(\.dismiss) private var dong

    @State private var chu: [String: String] = ["DAY": "", "WEEK": "", "MONTH": ""]
    @State private var dangLuu: String?

    private let cacKy: [(String, String, String)] = [
        ("DAY", "Mỗi ngày", "Giữ nhịp tiêu hằng ngày — thông báo 20h so với mốc này"),
        ("WEEK", "Mỗi tuần", "Tuần tính từ thứ Hai"),
        ("MONTH", "Mỗi tháng", "Tính từ ngày 1"),
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(cacKy, id: \.0) { ky, ten, moTa in
                    Section {
                        ONhapTien(nhan: T(ten), chu: Binding(
                            get: { chu[ky] ?? "" },
                            set: { chu[ky] = $0 }
                        ))
                        if let m = vm.mucTieu.first(where: { $0.ky == ky }) {
                            VStack(alignment: .leading, spacing: 4) {
                                ThanhTienDoTien(tiLe: Double(m.tiLe) / 100,
                                            mau: m.vuot ? AppColors.error
                                                : (m.tiLe >= 80 ? AppColors.warning : AppColors.success))
                                Text("\(T("Đã tiêu")) \(DinhDangTien.day(m.daTieu)) · "
                                     + (m.vuot ? "\(T("vượt")) \(DinhDangTien.day(-m.conLai))"
                                               : "\(T("còn")) \(DinhDangTien.day(m.conLai))"))
                                    .font(.caption)
                                    .foregroundStyle(m.vuot ? AppColors.error : AppColors.textSecondary)
                            }
                        }
                        Button {
                            Task { await luu(ky) }
                        } label: {
                            HStack {
                                Spacer()
                                if dangLuu == ky { ProgressView() } else { Text(T("Lưu mục tiêu")) }
                                Spacer()
                            }
                        }
                        .disabled(dangLuu != nil || DinhDangTien.doc(chu[ky] ?? "") == nil)
                    } header: {
                        Text(T(ten))
                    } footer: {
                        Text(T(moTa))
                    }
                }

                Section {
                    Text(T("Đặt 0 để tắt mục tiêu của một kỳ."))
                        .font(.caption).foregroundStyle(AppColors.textTertiary)
                }
            }
            .navigationTitle(T("Mục tiêu chi tiêu"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Đóng")) { dong() } }
            }
            .task {
                // `.task` chứ không `.onAppear` + `.onChange`: khi màn này mở,
                // `vm.mucTieu` ĐÃ có sẵn (màn Tổng quan nạp rồi), nên
                // `.onChange` sẽ không bao giờ chạy và ô nhập sẽ trống trơn
                // dù mục tiêu đang tồn tại.
                for m in vm.mucTieu where m.mucTieu > 0 {
                    chu[m.ky] = String(Int(m.mucTieu))
                }
            }
        }
    }

    private func luu(_ ky: String) async {
        guard let v = DinhDangTien.doc(chu[ky] ?? "") else { return }
        dangLuu = ky
        defer { dangLuu = nil }
        _ = await vm.datMucTieu(ky: ky, soTien: v)
    }
}
