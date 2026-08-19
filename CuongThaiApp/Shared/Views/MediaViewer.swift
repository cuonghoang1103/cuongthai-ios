import SwiftUI
import AVKit
#if canImport(Kingfisher)
import Kingfisher
#endif

// MARK: - Xem ảnh / video toàn màn hình
//
// Trước đây chạm vào ảnh trong bảng tin KHÔNG có gì xảy ra — ảnh bị cắt vuông
// trong lưới và không có cách nào xem đủ. Video thì chỉ hiện ảnh nền kèm một
// biểu tượng play không bấm được.

struct MediaViewer: View {
    let media: [SocialMedia]
    @State private var chiSo: Int
    @Environment(\.dismiss) private var dismiss

    init(media: [SocialMedia], batDauTai: Int = 0) {
        self.media = media
        _chiSo = State(initialValue: batDauTai)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $chiSo) {
                ForEach(Array(media.enumerated()), id: \.offset) { i, item in
                    OMediaToanManHinh(media: item)
                        .tag(i)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: media.count > 1 ? .automatic : .never))
            #endif

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(11)
                            .background(.black.opacity(0.55))
                            .clipShape(Circle())
                    }

                    Spacer()

                    if media.count > 1 {
                        Text("\(chiSo + 1)/\(media.count)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.55))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    if let url = URL(string: media[safe: chiSo]?.url ?? "") {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(11)
                                .background(.black.opacity(0.55))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.sm)

                Spacer()
            }
        }
        #if os(iOS)
        .statusBarHidden()
        #endif
    }
}

/// Một ảnh (phóng to được) hoặc một video.
private struct OMediaToanManHinh: View {
    let media: SocialMedia

    @State private var tyLe: CGFloat = 1
    @State private var tyLeCuoi: CGFloat = 1
    @State private var lech: CGSize = .zero
    @State private var lechCuoi: CGSize = .zero

    var body: some View {
        if media.type == "VIDEO", let url = URL(string: media.url) {
            // Video của bảng tin nằm trên R2 dưới dạng file phát thẳng được,
            // nên dùng trình phát hệ thống — khác hẳn video bài học (nhúng
            // YouTube, phải đi qua web view).
            VideoPlayer(player: AVPlayer(url: url))
                .ignoresSafeArea()
        } else {
            anh
        }
    }

    @ViewBuilder
    private var anh: some View {
        GeometryReader { g in
            Group {
                #if canImport(Kingfisher)
                if let url = URL(string: media.url) {
                    KFImage(url)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Color.black
                }
                #else
                Color.black
                #endif
            }
            .frame(width: g.size.width, height: g.size.height)
            .scaleEffect(tyLe)
            .offset(lech)
            .gesture(
                MagnificationGesture()
                    .onChanged { gt in tyLe = min(max(tyLeCuoi * gt, 1), 5) }
                    .onEnded { _ in
                        tyLeCuoi = tyLe
                        if tyLe <= 1 { veChoCu() }
                    },
            )
            .simultaneousGesture(
                // Chỉ cho kéo khi ĐANG phóng to. Không chặn thì cử chỉ kéo
                // nuốt luôn thao tác vuốt sang ảnh kế bên.
                DragGesture()
                    .onChanged { gt in
                        guard tyLe > 1 else { return }
                        lech = CGSize(width: lechCuoi.width + gt.translation.width,
                                      height: lechCuoi.height + gt.translation.height)
                    }
                    .onEnded { _ in lechCuoi = lech },
            )
            .onTapGesture(count: 2) {
                // Chạm hai lần: phóng to / thu về, như mọi app ảnh khác.
                withAnimation(.snappy(duration: 0.25)) {
                    if tyLe > 1 { veChoCu() } else { tyLe = 2.5; tyLeCuoi = 2.5 }
                }
            }
        }
    }

    private func veChoCu() {
        tyLe = 1; tyLeCuoi = 1; lech = .zero; lechCuoi = .zero
    }
}

extension Array {
    /// Lấy phần tử theo chỉ số, `nil` nếu ngoài khoảng — tránh sập khi chỉ số
    /// của trang và mảng lệch nhau một nhịp lúc đang chuyển ảnh.
    subscript(safe i: Int) -> Element? {
        indices.contains(i) ? self[i] : nil
    }
}


/// `fullScreenCover(item:)` đòi Identifiable; Int thì không có sẵn.
extension Int: @retroactive Identifiable {
    public var id: Int { self }
}
