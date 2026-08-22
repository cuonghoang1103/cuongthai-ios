import SwiftUI

/// Nút "Lưu vào sổ tay" cho các màn AI.
///
/// Backend có sẵn `POST /notebook/save` đúng cho việc này. Không có nút thì sổ
/// tay chỉ đầy lên bằng cách gõ tay, mà thứ đáng lưu nhất lại chính là câu
/// AI vừa dịch hoặc vừa sửa cho mình.
struct NutLuuSoTay: View {
    let ngonNgu: NgonNgu
    let loai: LoaiMuc
    let tieuDe: String
    let than: String
    var cachDoc: String?
    var nghia: String?

    @State private var trangThai: TrangThai = .san
    private enum TrangThai { case san, dangLuu, xong, hong }

    var body: some View {
        Button {
            Task { await luu() }
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: bieuTuong).font(.system(size: 13))
                Text(nhan).font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(trangThai == .xong ? AppColors.success : AppColors.primary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule().strokeBorder(
                    (trangThai == .xong ? AppColors.success : AppColors.primary).opacity(0.4),
                    lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(trangThai == .dangLuu || trangThai == .xong)
    }

    private var nhan: String {
        switch trangThai {
        case .san: return "Lưu vào sổ tay"
        case .dangLuu: return "Đang lưu…"
        case .xong: return "Đã lưu"
        case .hong: return "Thử lại"
        }
    }
    private var bieuTuong: String {
        switch trangThai {
        case .xong: return "checkmark.circle.fill"
        case .hong: return "exclamationmark.circle"
        default: return "bookmark"
        }
    }

    private func luu() async {
        trangThai = .dangLuu
        do {
            // Tiêu đề tối đa 255 ký tự ở backend; cắt sẵn để không bị từ chối
            // cả lượt chỉ vì người dùng dịch một đoạn dài.
            let td = String(tieuDe.prefix(200))
            let _: MucSoTay = try await APIClient.shared.request(
                .taoMucSoTay(code: ngonNgu.code, thuMucId: nil, loai: loai.rawValue,
                             tieuDe: td.isEmpty ? loai.ten : td, than: than,
                             cachDoc: cachDoc, nghia: nghia))
            trangThai = .xong
        } catch {
            trangThai = .hong
        }
    }
}
