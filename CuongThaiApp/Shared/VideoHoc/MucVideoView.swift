#if os(iOS)
import SwiftUI

// ════════════════════════════════════════════════════════════════
// MỤC VIDEO — các phần có mốc thời gian, như chương của YouTube
//
// Người dùng 20/09/2026: *"tôi thấy trên youtube nó có phân chia đúng đoạn
// thời gian cụ thể như này đây"*.
//
// ⚠️ MỤC LỤC LẤY TỪ CHÍNH CÂU TÓM TẮT CỦA GIA SƯ, không phải một đường AI
// thứ hai. `THEM_PHONG_VIDEO` ở máy chủ đã bắt gia sư mở câu tóm tắt bằng
// khối **Các phần trong video** với mốc `[mm:ss - mm:ss]`. Xin riêng một
// mục lục là trả tiền hai lần cho cùng một thứ, và hai lần đó có thể chia
// phần KHÁC NHAU — người học bấm chương ở tab này rồi đọc tóm tắt ở tab kia
// sẽ thấy hai bản đồ không khớp.
//
// `cacheKey: "video_tomtat"` DÙNG CHUNG VỚI BẢN WEB và với nút "Tóm tắt
// video" ở tab Hỏi AI — bài đã có người tóm tắt thì mục lục hiện tức thì,
// không tốn lượt nào.
// ════════════════════════════════════════════════════════════════

struct MucVideoView: View {
    let video: VideoHoc
    /// Giây đang phát — để tô sáng phần đang xem.
    let giayHienTai: () -> Double
    let tua: (Double) -> Void

    @State private var chu = ""
    @State private var dangTai = false
    @State private var daGoi = false
    @State private var loi: String?
    /// Nhịp đồng hồ: `giayHienTai()` là closure nên SwiftUI không theo dõi
    /// được nó. Không có nhịp này thì phần đang xem không bao giờ đổi.
    @State private var giay: Double = 0

    private let nhip = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var phan: [MocThoiGian.Phan] { MocThoiGian.bocPhan(chu) }

    var body: some View {
        Group {
            if let e = loi {
                KhungTrongTien(bieuTuong: "exclamationmark.triangle",
                               tieuDe: T("Chưa tạo được mục lục"), moTa: e)
            } else if phan.isEmpty && dangTai {
                dangCho
            } else if phan.isEmpty && !chu.isEmpty {
                // Không bóc được phần nào thì HIỆN NGUYÊN câu tóm tắt — nó
                // vẫn hữu ích kể cả khi model không theo đúng khuôn.
                ScrollView {
                    NoiDungMarkdown(noiDung: MocThoiGian.themLienKet(chu))
                        .padding(Spacing.md)
                }
                .environment(\.openURL, OpenURLAction { u in
                    if let g = MocThoiGian.giayTuURL(u) { tua(g); return .handled }
                    return .systemAction
                })
            } else if phan.isEmpty {
                dangCho
            } else {
                danhSach
            }
        }
        .onReceive(nhip) { _ in giay = giayHienTai() }
        .task {
            // Chỉ gọi MỘT lần cho mỗi lần mở màn — `task` chạy lại khi view
            // được gắn lại, mà đổi tab qua lại là gắn lại.
            guard !daGoi else { return }
            daGoi = true
            await taiMucLuc()
        }
    }

    private var dangCho: some View {
        VStack(spacing: Spacing.sm) {
            ProgressView()
            Text(T("Gia sư đang đọc phụ đề và chia phần…"))
                .font(.subheadline).foregroundStyle(AppColors.textSecondary)
            Text(T("Bài đã có người xem thì lần sau hiện ngay."))
                .font(.caption).foregroundStyle(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.md)
    }

    private var danhSach: some View {
        let ds = phan
        // Phần đang xem: phần cuối cùng đã bắt đầu, và chưa tới phần sau.
        let dangO = ds.lastIndex { $0.tu <= giay } ?? -1

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: "list.bullet.rectangle").font(.caption2)
                    Text("\(ds.count) " + T("phần")).font(.caption.weight(.semibold))
                }
                .foregroundStyle(AppColors.textTertiary)
                .padding(.horizontal, Spacing.sm)
                .padding(.bottom, Spacing.xs)

                ForEach(Array(ds.enumerated()), id: \.element.id) { i, p in
                    Button { tua(p.tu) } label: {
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            Text(p.moc)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(i == dangO ? AppColors.primary : AppColors.textTertiary)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(p.ten)
                                    .font(.subheadline.weight(i == dangO ? .semibold : .medium))
                                    .foregroundStyle(AppColors.textPrimary)
                                    .multilineTextAlignment(.leading)
                                if !p.y.isEmpty {
                                    Text(p.y)
                                        .font(.caption)
                                        .foregroundStyle(AppColors.textSecondary)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(i == dangO ? AppColors.primary.opacity(0.14) : .clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.sm)
        }
    }

    private func taiMucLuc() async {
        // Video người dùng tự thêm có lessonId ÂM, không thuộc khoá nào —
        // gia sư bài học không có bối cảnh, nói thẳng thay vì gọi rồi lỗi.
        guard !video.laCuaToi else {
            loi = T("Mục lục hiện chỉ có với video bài giảng của khoá học.")
            return
        }
        dangTai = true
        defer { dangTai = false }

        var gom = ""
        for await sk in LuongHoiDap.doc(
            duong: "/api/v1/courses/lessons/\(video.lessonId)/ai/ask-stream",
            than: [
                "question": "Tóm tắt video này theo các phần có mốc thời gian.",
                "cacheKey": "video_tomtat",
                "phongVideo": true,
                "phuDeGiay": Int(giayHienTai()),
            ],
            loiTheoMa: { ma in
                switch ma {
                case 401: return T("Phiên đăng nhập đã hết hạn.")
                case 403: return T("Phòng học video cùng AI là tính năng Pro.")
                case 404: return T("Video này chưa gắn với bài học nào.")
                case 400: return T("AI đang không dùng được (hết hạn mức hôm nay, hoặc đang tạm nghỉ).")
                default:  return T("Máy chủ trả lỗi") + " \(ma)"
                }
            }) {
            switch sk {
            case .mau(let c):
                gom += c
                chu = gom
            case .xong(let traLoi, _):
                chu = traLoi.isEmpty ? gom : traLoi
            case .hong(let e):
                loi = e
            }
        }
    }
}
#endif
