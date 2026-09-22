import SwiftUI

// ════════════════════════════════════════════════════════════════
// ẢNH VÀ TỆP HIỆN TRONG BONG BÓNG TIN CỦA NGƯỜI DÙNG
//
// Trước 22/09/2026 bong bóng chỉ vẽ `Text(tin.noiDung)`. Ảnh và tên tệp CÓ
// nằm sẵn trong `TinAI` (`anh`, `tenTep`) nhưng không dòng nào vẽ chúng —
// người dùng gửi ảnh xong không thấy dấu vết gì là đã gửi, còn gửi ảnh không
// kèm chữ thì ra một bong bóng tím RỖNG.
// ════════════════════════════════════════════════════════════════

/// Ảnh thu nhỏ của một data URL, bấm vào để xem lớn.
///
/// Giải mã ở `.task` trên luồng nền và thu về ~360px: bong bóng bị dựng lại
/// liên tục trong lúc câu trả lời đang chảy, giải mã base64 cả trăm KB ngay
/// trong `body` là giật cả khung chat.
struct AnhTrongTin: View {
    let dataURL: String
    var canh: CGFloat = 116

    @State private var anh: PlatformImage?
    @State private var xemLon = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.backgroundTertiary)
            if let anh {
                Image(platformImage: anh).resizable().scaledToFill()
            } else {
                ProgressView().scaleEffect(0.6)
            }
        }
        .frame(width: canh, height: canh)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { if anh != nil { xemLon = true } }
        .task(id: dataURL) { anh = await Self.giaiMa(dataURL, canhDai: 360) }
        .accessibilityLabel("Ảnh đã gửi")
        #if os(iOS)
        .fullScreenCover(isPresented: $xemLon) { XemAnhLon(dataURL: dataURL) }
        #endif
    }

    /// data URL → ảnh, thu về cạnh dài `canhDai` (nil = giữ nguyên cỡ).
    static func giaiMa(_ s: String, canhDai: CGFloat?) async -> PlatformImage? {
        await Task.detached(priority: .userInitiated) { () -> PlatformImage? in
            guard let phay = s.firstIndex(of: ","),
                  let d = Data(base64Encoded: String(s[s.index(after: phay)...])),
                  let goc = PlatformImage(data: d) else { return nil }
            #if os(iOS)
            if let canhDai {
                let tl = canhDai / max(goc.size.width, goc.size.height, 1)
                if tl < 1 {
                    return goc.preparingThumbnail(of: CGSize(width: goc.size.width * tl,
                                                             height: goc.size.height * tl)) ?? goc
                }
            }
            #endif
            return goc
        }.value
    }
}

/// Xem một ảnh đã gửi ở cỡ thật: chụm để phóng, chạm đúp để về cỡ vừa khung.
struct XemAnhLon: View {
    let dataURL: String
    @Environment(\.dismiss) private var dismiss
    @State private var anh: PlatformImage?
    @State private var tiLe: CGFloat = 1
    @State private var tiLeTruoc: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let anh {
                Image(platformImage: anh)
                    .resizable().scaledToFit()
                    .scaleEffect(tiLe)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { g in tiLe = min(max(tiLeTruoc * g.magnification, 1), 5) }
                            .onEnded { _ in tiLeTruoc = tiLe }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.easeOut(duration: 0.2)) { tiLe = 1; tiLeTruoc = 1 }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView().tint(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.18)))
            }
            .padding(Spacing.md)
            .accessibilityLabel("Đóng")
        }
        .task { anh = await AnhTrongTin.giaiMa(dataURL, canhDai: nil) }
    }
}

/// Thẻ một tệp đã gửi: biểu tượng theo đuôi tệp + tên + dòng phụ.
struct TheTepTrongTin: View {
    let ten: String
    let moTa: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: DinhKemAI.bieuTuong(cho: ten))
                .font(.system(size: 17))
                .foregroundColor(AppColors.primary)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(AppColors.primary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 1) {
                Text(ten)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1).truncationMode(.middle)
                if !moTa.isEmpty {
                    Text(moTa)
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(maxWidth: 280, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(AppColors.backgroundSecondary))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(AppColors.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tệp đã gửi: \(ten)")
    }
}
