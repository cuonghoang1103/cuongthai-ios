import SwiftUI
#if canImport(Kingfisher)
import Kingfisher
#endif

// ════════════════════════════════════════════════════════════════
// TRÌNH CHIẾU SLIDE CỦA BÀI HỌC
//
// Slide trường (và slide ⭐ Chuyên sâu tự dựng) nằm sẵn trong HTML bài dưới
// dạng `.anh-slide` — 1280×720, chữ nhỏ. Xem chen giữa bài giảng trên điện
// thoại là phải chụm hai ngón mới đọc nổi. Ở đây: vuốt ngang từng tấm, chụm
// để phóng, chạm hai lần để phóng nhanh, chú thích "bộ · số/tổng — tên" ở
// dưới, và "Hỏi CuongMini về slide này" ngay tại chỗ.
// ════════════════════════════════════════════════════════════════

/// Dải ảnh nhỏ ngay trên nội dung bài — lối vào trình chiếu.
struct DaiSlideBai: View {
    let slides: [SlideBai]
    let khiMo: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .foregroundColor(AppColors.primary)
                Text(String(format: T("%d slide trong bài"), slides.count))
                    .font(.titleSmall).foregroundColor(AppColors.textPrimary)
                Spacer(minLength: 0)
                Button {
                    Haptics.cham(); khiMo(0)
                } label: {
                    Label(T("Trình chiếu"), systemImage: "play.rectangle.fill")
                        .font(.buttonSmall).foregroundColor(AppColors.primary)
                }
                .buttonStyle(.plain)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Spacing.sm) {
                    ForEach(slides) { s in
                        Button { Haptics.cham(); khiMo(s.viTri) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                anhNho(s)
                                    .frame(width: 168, height: 94.5)
                                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                                        .stroke(AppColors.border, lineWidth: 1))
                                Text(s.ten.isEmpty ? s.nhanSo : s.ten)
                                    .font(.system(size: 11.5)).foregroundColor(AppColors.textSecondary)
                                    .lineLimit(1).frame(width: 168, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(format: T("Slide %d: %@"), s.so, s.ten))
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous).fill(AppColors.backgroundCard))
    }

    @ViewBuilder
    private func anhNho(_ s: SlideBai) -> some View {
        #if canImport(Kingfisher)
        KFImage(URL(string: s.anh))
            .placeholder { AppColors.backgroundTertiary }
            .resizable()
            .aspectRatio(contentMode: .fill)
        #else
        AppColors.backgroundTertiary
        #endif
    }
}

/// Toàn màn hình: vuốt ngang, chụm phóng, chú thích, hỏi CuongMini.
struct XemSlideView: View {
    let slides: [SlideBai]
    @State var dangXem: Int
    /// `nil` = ẩn nút hỏi (người dùng chưa đăng nhập / không phải bài học).
    var khiHoi: ((SlideBai) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var anChrome = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $dangXem) {
                ForEach(slides) { s in
                    KhungPhongTo(url: URL(string: s.anh)) {
                        withAnimation(.easeInOut(duration: 0.2)) { anChrome.toggle() }
                    }
                    .tag(s.viTri)
                    .accessibilityLabel(String(format: T("Slide %d trên %d: %@"), s.so, max(s.tong, slides.count), s.ten))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            if !anChrome {
                VStack {
                    thanhTren
                    Spacer()
                    thanhDuoi
                }
                .transition(.opacity)
            }
        }
        .statusBarHidden(anChrome)
        .onChange(of: dangXem) { _, _ in Haptics.cham() }
    }

    private var hienTai: SlideBai? { slides.first { $0.viTri == dangXem } }

    private var thanhTren: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.16)))
            }
            .accessibilityLabel(T("Đóng"))
            Spacer()
            Text("\(dangXem + 1) / \(slides.count)")
                .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.16)))
            Spacer()
            if let s = hienTai, let u = URL(string: s.anh) {
                ShareLink(item: u) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.white.opacity(0.16)))
                }
                .accessibilityLabel(T("Chia sẻ slide"))
            } else {
                Color.clear.frame(width: 38, height: 38)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
    }

    @ViewBuilder
    private var thanhDuoi: some View {
        if let s = hienTai {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(s.nhanSo)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(AppColors.primaryLight)
                if !s.ten.isEmpty {
                    Text(s.ten).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: Spacing.sm) {
                    Button {
                        guard dangXem > 0 else { return }
                        withAnimation { dangXem -= 1 }
                    } label: { Image(systemName: "chevron.left").frame(width: 40, height: 36) }
                    .disabled(dangXem == 0)
                    .accessibilityLabel(T("Slide trước"))
                    Button {
                        guard dangXem + 1 < slides.count else { return }
                        withAnimation { dangXem += 1 }
                    } label: { Image(systemName: "chevron.right").frame(width: 40, height: 36) }
                    .disabled(dangXem + 1 >= slides.count)
                    .accessibilityLabel(T("Slide sau"))
                    Spacer(minLength: 0)
                    if let khiHoi {
                        Button {
                            Haptics.cham()
                            khiHoi(s)
                        } label: {
                            Label(T("Hỏi CuongMini về slide này"), systemImage: "sparkles")
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14).padding(.vertical, 9)
                                .background(Capsule().fill(AppColors.brandGradient))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .foregroundColor(.white)
                .font(.system(size: 15, weight: .semibold))
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea())
        }
    }
}

#if os(iOS)
/// Ảnh phóng to được bằng `UIScrollView` thật — `MagnificationGesture` của SwiftUI
/// không neo theo điểm chụm và không có quán tính, đọc slide chữ nhỏ rất mệt.
struct KhungPhongTo: UIViewRepresentable {
    let url: URL?
    var khiCham: () -> Void = {}

    func makeUIView(context: Context) -> UIScrollView {
        let sv = UIScrollView()
        sv.delegate = context.coordinator
        sv.minimumZoomScale = 1
        sv.maximumZoomScale = 5
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.backgroundColor = .clear
        sv.contentInsetAdjustmentBehavior = .never
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.isUserInteractionEnabled = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        sv.addSubview(iv)
        NSLayoutConstraint.activate([
            iv.widthAnchor.constraint(equalTo: sv.frameLayoutGuide.widthAnchor),
            iv.heightAnchor.constraint(equalTo: sv.frameLayoutGuide.heightAnchor),
            iv.leadingAnchor.constraint(equalTo: sv.contentLayoutGuide.leadingAnchor),
            iv.trailingAnchor.constraint(equalTo: sv.contentLayoutGuide.trailingAnchor),
            iv.topAnchor.constraint(equalTo: sv.contentLayoutGuide.topAnchor),
            iv.bottomAnchor.constraint(equalTo: sv.contentLayoutGuide.bottomAnchor),
        ])
        context.coordinator.anh = iv
        let hai = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.chamHai(_:)))
        hai.numberOfTapsRequired = 2
        sv.addGestureRecognizer(hai)
        let mot = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.chamMot))
        mot.require(toFail: hai)
        sv.addGestureRecognizer(mot)
        #if canImport(Kingfisher)
        iv.kf.indicatorType = .activity
        iv.kf.setImage(with: url)
        #endif
        return sv
    }

    func updateUIView(_ sv: UIScrollView, context: Context) {
        context.coordinator.khiCham = khiCham
    }

    func makeCoordinator() -> Coordinator { Coordinator(khiCham: khiCham) }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var anh: UIImageView?
        var khiCham: () -> Void
        init(khiCham: @escaping () -> Void) { self.khiCham = khiCham }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { anh }

        @objc func chamMot() { khiCham() }

        @objc func chamHai(_ g: UITapGestureRecognizer) {
            guard let sv = g.view as? UIScrollView else { return }
            if sv.zoomScale > 1.01 {
                sv.setZoomScale(1, animated: true)
            } else if let anh {
                let p = g.location(in: anh)
                let w = sv.bounds.width / 2.5, h = sv.bounds.height / 2.5
                sv.zoom(to: CGRect(x: p.x - w / 2, y: p.y - h / 2, width: w, height: h), animated: true)
            }
        }
    }
}
#endif
