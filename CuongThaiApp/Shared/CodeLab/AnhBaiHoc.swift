import SwiftUI
import Kingfisher

// ════════════════════════════════════════════════════════════════
// ẢNH TRONG BÀI HỌC — slide cắt từ PDF của thầy
//
// ⚠️ TRƯỚC ĐÂY DÙNG `AsyncImage` DẠNG HAI-CLOSURE, VÀ DẠNG ĐÓ KHÔNG CÓ NHÁNH
// LỖI:
//
//     AsyncImage(url: url) { anh in ... } placeholder: { ProgressView() }
//
// Tải hỏng là nó nằm mãi ở `placeholder` — vòng xoay quay vĩnh viễn, không
// báo lỗi, không thử lại, không có gì để bấm. Người dùng báo đúng thế
// 11/09/2026: "mấy cái ảnh pdf... load mãi không được".
//
// Mà đây là loại ảnh dễ hỏng nhất trong app:
//   · nặng 80 KB – 900 KB mỗi tấm (đo thật bộ hướng dẫn LAB211)
//   · lần đầu CDN chưa cache thì tốn tới 23,8 giây (đo thật hd-01.png)
//   · một bài có cả chục slide
// Cộng lại: trên 4G/5G chập chờn, hỏng một tấm là gần như chắc chắn.
//
// Ba thứ ở đây mà `AsyncImage` không cho:
//   1. **Cache xuống ĐĨA** (Kingfisher) — mở lại bài là hiện ngay, không tải lại.
//   2. **Nhánh LỖI nhìn thấy được** — thay vì xoay mãi.
//   3. **Bấm để thử lại** — đổi `lanThu` là đổi id của view, Kingfisher tải lại.
// ════════════════════════════════════════════════════════════════

struct AnhBaiHoc: View {
    let duong: String
    var caoToiDa: CGFloat = 460

    @State private var lanThu = 0
    @State private var hong = false

    var body: some View {
        Group {
            if let u = URL(string: duong) {
                if hong {
                    khoiHong
                } else {
                    KFImage(u)
                        .onFailure { _ in hong = true }
                        .placeholder {
                            ZStack {
                                RoundedRectangle(cornerRadius: CornerRadius.medium)
                                    .fill(AppColors.backgroundTertiary)
                                ProgressView()
                            }
                            .frame(height: 160)
                        }
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: caoToiDa)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                        // Đổi id để Kingfisher dựng lại từ đầu khi bấm thử lại.
                        .id("\(duong)#\(lanThu)")
                }
            }
        }
    }

    private var khoiHong: some View {
        Button {
            hong = false
            lanThu += 1
        } label: {
            VStack(spacing: Spacing.xs) {
                Image(systemName: "arrow.clockwise.circle")
                    .font(.system(size: 26))
                    .foregroundColor(AppColors.primary)
                Text(T("Chưa tải được ảnh — chạm để thử lại"))
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
            .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(AppColors.backgroundTertiary))
        }
        .buttonStyle(.plain)
    }
}
