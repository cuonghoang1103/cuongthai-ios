import SwiftUI
import AVKit
import Kingfisher

// MARK: - Bảng tin — ảnh/video (lưới + xem toàn màn), tệp, thẻ link, thẻ CT Work, bình chọn
//
// URL ký sẵn sống 10 phút (`urlExpiresAt`) ⇒ hết hạn thì xin lại `GET /feed/attachments/:id/url?variant=` trước khi
// tải/phát. Ảnh đệm theo khoá CỐ ĐỊNH `ctwfeed-<id>-<kiểu>` (URL ký đổi mỗi lần tải lại bài — đệm theo URL là tải lại
// ảnh mỗi lần kéo làm mới).

enum DuongTepBangTin {
    /// URL dùng được ngay (còn hạn) hoặc xin lại.
    static func url(_ a: CTWFeedAttachment, kieu: String) async -> URL? {
        let san: String? = kieu == "thumb" ? (a.thumbUrl ?? a.posterUrl ?? a.url) : kieu == "poster" ? (a.posterUrl ?? a.thumbUrl) : a.url
        if !a.hetHan(), let s = san, let u = DuongDanAnh.url(s) ?? URL(string: s) { return u }
        guard let r: CTWFeedURL = try? await APIClient.shared.request(CTWAPI.duongTep(a.id, kieu: kieu)), let s = r.url else { return nil }
        return URL(string: s)
    }

    static func urlNgay(_ a: CTWFeedAttachment, kieu: String) -> URL? {
        let s: String? = kieu == "thumb" ? (a.thumbUrl ?? a.posterUrl ?? a.url) : kieu == "poster" ? (a.posterUrl ?? a.thumbUrl) : a.url
        return s.flatMap { DuongDanAnh.url($0) ?? URL(string: $0) }
    }
}

/// Ảnh của một tệp đính kèm — đệm theo id, tự xin lại URL khi hết hạn.
struct AnhTepBangTinCTW: View {
    let a: CTWFeedAttachment
    var kieu = "thumb"
    var vuaKhung = false
    @State private var url: URL?

    var body: some View {
        Group {
            if let url {
                KFImage(source: .network(KF.ImageResource(downloadURL: url, cacheKey: "ctwfeed-\(a.id)-\(kieu)")))
                    .placeholder { nen }
                    .fade(duration: 0.2)
                    .resizable()
                    .aspectRatio(contentMode: vuaKhung ? .fit : .fill)
            } else { nen }
        }
        .task(id: a.id) {
            if !a.hetHan(), let u = DuongTepBangTin.urlNgay(a, kieu: kieu) { url = u } else { url = await DuongTepBangTin.url(a, kieu: kieu) }
        }
    }

    private var nen: some View {
        Rectangle().fill(AppColors.backgroundTertiary)
            .overlay(Image(systemName: a.laVideo ? "video" : "photo").font(.ctw(size: 20)).foregroundColor(AppColors.textTertiary))
            .anhLuot()
    }
}

// MARK: - Lưới ảnh/video 1 · 2 · 3 · 4+

struct LuoiPhuongTienCTW: View {
    let ds: [CTWFeedAttachment]
    let mo: (Int) -> Void

    var body: some View {
        if let b = BoCucAnh.chon(ds) {
            Color.clear
                .aspectRatio(tiLeKhung(b), contentMode: .fit)
                .overlay { GeometryReader { g in luoi(b, g.size) } }
                .clipped()
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text(ds.count == 1 ? String(localized: "1 photo or video") : String(localized: "\(ds.count) photos or videos")))
        }
    }

    private func tiLeKhung(_ b: BoCucAnh) -> CGFloat {
        switch b {
        case .mot(let r): return r
        case .hai: return 1.6
        case .ba: return 4.0 / 3
        case .bon: return 1
        }
    }

    @ViewBuilder private func luoi(_ b: BoCucAnh, _ s: CGSize) -> some View {
        let k: CGFloat = 2
        switch b {
        case .mot:
            o(0, s.width, s.height)
        case .hai:
            HStack(spacing: k) { o(0, (s.width - k) / 2, s.height); o(1, (s.width - k) / 2, s.height) }
        case .ba:
            HStack(spacing: k) {
                o(0, (s.width - k) * 0.62, s.height)
                VStack(spacing: k) {
                    o(1, (s.width - k) * 0.38, (s.height - k) / 2)
                    o(2, (s.width - k) * 0.38, (s.height - k) / 2)
                }
            }
        case .bon(let thua):
            let w = (s.width - k) / 2, h = (s.height - k) / 2
            VStack(spacing: k) {
                HStack(spacing: k) { o(0, w, h); o(1, w, h) }
                HStack(spacing: k) { o(2, w, h); o(3, w, h, thua: thua) }
            }
        }
    }

    private func o(_ i: Int, _ w: CGFloat, _ h: CGFloat, thua: Int = 0) -> some View {
        let a = ds[i]
        return Button { mo(i) } label: {
            AnhTepBangTinCTW(a: a, kieu: "thumb")
                .frame(width: w, height: h)
                .clipped()
                .overlay {
                    if a.laVideo {
                        ZStack {
                            Circle().fill(.black.opacity(0.45)).frame(width: 52, height: 52)
                            Image(systemName: "play.fill").font(.system(size: 22, weight: .bold)).foregroundColor(.white).offset(x: 2)
                        }
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if a.laVideo, let ms = a.durationMs {
                        Text(Self.thoiLuong(ms)).font(.ctw(size: 11, weight: .semibold).monospacedDigit())
                            .foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(.black.opacity(0.6)))
                            .padding(8)
                    }
                }
                .overlay {
                    if thua > 0 {
                        ZStack {
                            Color.black.opacity(0.5)
                            Text(verbatim: "+\(thua)").font(.ctw(size: 28, weight: .bold)).foregroundColor(.white)
                        }
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(nhanTroNang(a, i, thua))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("feed.media.\(i)")
    }

    private func nhanTroNang(_ a: CTWFeedAttachment, _ i: Int, _ thua: Int) -> Text {
        let loai = a.laVideo ? String(localized: "Video") : String(localized: "Photo")
        var s = String(localized: "\(loai) \(i + 1) of \(ds.count)")
        if let alt = a.alt, !alt.isEmpty { s += ". " + alt }
        if thua > 0 { s += ". " + String(localized: "\(thua) more") }
        return Text(s)
    }

    static func thoiLuong(_ ms: Int) -> String {
        let g = ms / 1000
        return String(format: "%d:%02d", g / 60, g % 60)
    }
}

// MARK: - Xem toàn màn hình: lật trang · phóng to bằng hai ngón · kéo xuống để đóng

struct XemPhuongTienCTW: View {
    let ds: [CTWFeedAttachment]
    @State var chiSo: Int
    @Environment(\.dismiss) private var dong
    @Environment(\.accessibilityReduceMotion) private var giam
    @State private var keo: CGSize = .zero
    @State private var phong: CGFloat = 1
    @State private var hienKhung = true

    var body: some View {
        ZStack {
            Color.black.opacity(1 - min(0.7, abs(keo.height) / 500)).ignoresSafeArea()
            TabView(selection: $chiSo) {
                ForEach(Array(ds.enumerated()), id: \.element.id) { i, a in
                    Group {
                        if a.laVideo { VideoBaiCTW(a: a, tuPhat: i == chiSo) }
                        else { KhungZoomCTW(a: a, phong: $phong) { withAnimation(.easeOut(duration: 0.15)) { hienKhung.toggle() } } }
                    }
                    .tag(i)
                    .accessibilityLabel(Text(a.alt?.isEmpty == false ? a.alt! : (a.laVideo ? String(localized: "Video") : String(localized: "Photo"))))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .offset(y: keo.height)
            .scaleEffect(giam ? 1 : 1 - min(0.15, abs(keo.height) / 2000))
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { v in
                        guard phong <= 1.01, abs(v.translation.height) > abs(v.translation.width) else { return }
                        keo = CGSize(width: 0, height: v.translation.height)
                    }
                    .onEnded { v in
                        if abs(keo.height) > 120 || abs(v.predictedEndTranslation.height) > 400 { dong() }
                        else { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { keo = .zero } }
                    }
            )
            if hienKhung { thanhTren }
        }
        .statusBarHidden(!hienKhung)
        .onChange(of: chiSo) { _, _ in phong = 1 }
        .accessibilityAction(.escape) { dong() }
    }

    private var thanhTren: some View {
        VStack {
            HStack {
                Button { dong() } label: {
                    Image(systemName: "xmark").font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                        .frame(width: 44, height: 44).background(Circle().fill(.white.opacity(0.15)))
                }
                .accessibilityLabel(Text("Close"))
                .accessibilityIdentifier("feed.viewer.close")
                Spacer()
                if ds.count > 1 {
                    Text(verbatim: "\(chiSo + 1) / \(ds.count)").font(.ctw(size: 15, weight: .semibold).monospacedDigit()).foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6).background(Capsule().fill(.white.opacity(0.15)))
                }
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 12)
            Spacer()
            if ds.indices.contains(chiSo), let alt = ds[chiSo].alt, !alt.isEmpty {
                Text(alt).font(.ctw(size: 14)).foregroundColor(.white).multilineTextAlignment(.leading)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom))
            }
        }
        .transition(.opacity)
    }
}


/// Ảnh phóng to được (UIScrollView: hai ngón + chạm đúp) — ở mức 1× thì cử chỉ ngang đi về TabView để lật trang.
struct KhungZoomCTW: UIViewRepresentable {
    let a: CTWFeedAttachment
    @Binding var phong: CGFloat
    var chamMot: () -> Void = {}

    func makeCoordinator() -> DieuPhoi { DieuPhoi(self) }

    func makeUIView(context: Context) -> UIScrollView {
        let sv = UIScrollView()
        sv.delegate = context.coordinator
        sv.minimumZoomScale = 1
        sv.maximumZoomScale = 4
        sv.showsVerticalScrollIndicator = false
        sv.showsHorizontalScrollIndicator = false
        sv.contentInsetAdjustmentBehavior = .never
        sv.backgroundColor = .clear
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.isAccessibilityElement = true
        iv.accessibilityLabel = a.alt
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
        let dup = UITapGestureRecognizer(target: context.coordinator, action: #selector(DieuPhoi.chamDup(_:)))
        dup.numberOfTapsRequired = 2
        sv.addGestureRecognizer(dup)
        let mot = UITapGestureRecognizer(target: context.coordinator, action: #selector(DieuPhoi.chamMot))
        mot.require(toFail: dup)
        sv.addGestureRecognizer(mot)
        // Ảnh nhỏ (thumbnail, đã đệm) hiện ngay, rồi thay bản gốc.
        let kf = KingfisherManager.shared
        Task { @MainActor in
            if let t = await DuongTepBangTin.url(a, kieu: "thumb"),
               let r = try? await kf.retrieveImage(with: .network(KF.ImageResource(downloadURL: t, cacheKey: "ctwfeed-\(a.id)-thumb"))) {
                if iv.image == nil { iv.image = r.image }
            }
            if let g = await DuongTepBangTin.url(a, kieu: "full"),
               let r = try? await kf.retrieveImage(with: .network(KF.ImageResource(downloadURL: g, cacheKey: "ctwfeed-\(a.id)-full"))) {
                iv.image = r.image
            }
        }
        return sv
    }

    func updateUIView(_ sv: UIScrollView, context: Context) {
        context.coordinator.cha = self
        if phong <= 1.01, sv.zoomScale > 1.01 { sv.setZoomScale(1, animated: false) }
    }

    final class DieuPhoi: NSObject, UIScrollViewDelegate {
        var cha: KhungZoomCTW
        weak var anh: UIImageView?
        init(_ c: KhungZoomCTW) { cha = c }
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { anh }
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            let z = scrollView.zoomScale
            DispatchQueue.main.async { self.cha.phong = z }
        }
        @objc func chamDup(_ g: UITapGestureRecognizer) {
            guard let sv = g.view as? UIScrollView else { return }
            if sv.zoomScale > 1.01 { sv.setZoomScale(1, animated: true); return }
            let p = g.location(in: anh)
            let w = sv.bounds.width / 2.5, h = sv.bounds.height / 2.5
            sv.zoom(to: CGRect(x: p.x - w / 2, y: p.y - h / 2, width: w, height: h), animated: true)
        }
        @objc func chamMot() { cha.chamMot() }
    }
}

// MARK: - Video: ảnh bìa + nút phát ⇒ AVPlayer (chạm để phát)

struct VideoBaiCTW: View {
    let a: CTWFeedAttachment
    var tuPhat = false
    @State private var player: AVPlayer?
    @State private var dangMo = false

    var body: some View {
        ZStack {
            if let player {
                VideoPlayer(player: player)
                    .onDisappear { player.pause() }
            } else {
                AnhTepBangTinCTW(a: a, kieu: "poster", vuaKhung: true)
                Button { Task { await phat() } } label: {
                    ZStack {
                        Circle().fill(.black.opacity(0.5)).frame(width: 64, height: 64)
                        if dangMo { ProgressView().tint(.white) }
                        else { Image(systemName: "play.fill").font(.system(size: 26, weight: .bold)).foregroundColor(.white).offset(x: 2) }
                    }
                }
                .accessibilityLabel(Text("Play video"))
                .accessibilityIdentifier("feed.video.play")
            }
        }
        .task(id: tuPhat) { if tuPhat, player == nil { await phat() } }
        .onChange(of: tuPhat) { _, b in if !b { player?.pause() } }
    }

    private func phat() async {
        dangMo = true
        defer { dangMo = false }
        guard let u = await DuongTepBangTin.url(a, kieu: "full") else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        let p = AVPlayer(url: u)
        player = p
        p.play()
    }
}

// MARK: - Tệp (Xem nhanh)

struct ChipTepCTW: View {
    let a: CTWFeedAttachment
    var dangTai = false
    let mo: () -> Void

    var body: some View {
        Button(action: mo) {
            HStack(spacing: 10) {
                Image(systemName: Self.bieuTuong(a))
                    .font(.ctw(size: 18, weight: .semibold)).foregroundColor(AppColors.primary)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColors.primary.opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(a.fileName ?? String(localized: "File")).font(.ctw(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary).lineLimit(1).truncationMode(.middle)
                    Text([a.size.map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) },
                          (a.fileName as NSString?)?.pathExtension.uppercased()].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                }
                Spacer(minLength: 0)
                if dangTai { ProgressView() } else {
                    Image(systemName: "arrow.down.circle").font(.ctw(size: 18)).foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppColors.backgroundSecondary))
            .contentShape(Rectangle())
        }
        .buttonStyle(.nhan)
        .accessibilityLabel(Text("File \(a.fileName ?? "")"))
        .accessibilityHint(Text("Opens a preview"))
    }

    static func bieuTuong(_ a: CTWFeedAttachment) -> String {
        let m = (a.mime ?? "").lowercased(), d = ((a.fileName ?? "") as NSString).pathExtension.lowercased()
        if m.contains("pdf") || d == "pdf" { return "doc.richtext" }
        if ["xls", "xlsx", "csv"].contains(d) || m.contains("sheet") { return "tablecells" }
        if ["doc", "docx", "md", "txt", "rtf"].contains(d) || m.contains("word") || m.hasPrefix("text/") { return "doc.text" }
        if ["ppt", "pptx", "key"].contains(d) { return "rectangle.on.rectangle.angled" }
        if ["zip", "rar", "7z", "gz"].contains(d) { return "doc.zipper" }
        if m.hasPrefix("audio/") { return "waveform" }
        return "doc"
    }
}

// MARK: - Thẻ link web ngoài

struct TheLinkCTW: View {
    let l: CTWFeedLinkPreview
    let mo: (URL) -> Void

    var body: some View {
        Button { if let s = l.url, let u = URL(string: s) { mo(u) } } label: {
            VStack(alignment: .leading, spacing: 0) {
                if let s = l.imageUrl, let u = URL(string: s) {
                    KFImage(u).placeholder { Rectangle().fill(AppColors.backgroundTertiary) }
                        .resizable().aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity).aspectRatio(1.91, contentMode: .fit)
                        .clipped()
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: (l.siteName ?? l.domain ?? "").uppercased())
                        .font(.ctw(size: 11, weight: .semibold)).foregroundColor(AppColors.textTertiary).lineLimit(1)
                    if let t = l.title { Text(verbatim: t).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary).lineLimit(2) }
                    if let d = l.description, !d.isEmpty {
                        Text(verbatim: d).font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary).lineLimit(2)
                    }
                }
                .multilineTextAlignment(.leading)
                .padding(12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(AppColors.border, lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.nhan)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Opens the link"))
    }
}

// MARK: - Thẻ CT Work (thẻ / test / tài liệu / cuộc họp)

struct TheThamChieuCTW: View {
    let r: CTWFeedRef
    let mo: (URL) -> Void

    var body: some View {
        Button { if let u = DichBangTin.urlWeb(r.url) { mo(u) } } label: {
            HStack(spacing: 10) {
                bieuTuong
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        if let k = r.key { Text(verbatim: k).font(.ctw(size: 12, weight: .semibold).monospaced()).foregroundColor(AppColors.primary) }
                        if let pr = r.project { Text(verbatim: pr).font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary).lineLimit(1) }
                    }
                    Text(verbatim: r.title ?? "").font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                        .lineLimit(2).multilineTextAlignment(.leading)
                    if let w = r.when, let d = Date.tuChuoiISO(w) {
                        Text(CTWDinhDang.mau("EEEMMMd").string(from: d) + " " + CTWDinhDang.gio(d))
                            .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 6) {
                    if let s = r.status { CTWStatusChip(ten: s.name, category: s.category).fixedSize() }
                    if let a = r.assignee, let id = a.id {
                        CTWAvatar(user: CTWUser(id: id, displayName: a.name, avatarUrl: a.avatarUrl), size: 22)
                    }
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppColors.backgroundSecondary))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(AppColors.border, lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.nhan)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var bieuTuong: some View {
        switch r.t {
        case "issue":
            Image(systemName: CTW.bieuTuongLoai(key: r.type?.key))
                .font(.ctw(size: 12, weight: .bold)).foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(CTW.mau(r.type?.color, macDinh: AppColors.info)))
        default:
            Image(systemName: r.t == "doc" ? "doc.text.fill" : r.t == "meeting" ? "video.fill" : "checkmark.seal.fill")
                .font(.ctw(size: 13, weight: .bold)).foregroundColor(AppColors.primary)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(AppColors.primary.opacity(0.12)))
        }
    }
}

// MARK: - Bình chọn

struct BinhChonCTW: View {
    let poll: CTWFeedPoll
    var choBau = true
    let bau: ([String]) -> Void

    private var daBau: Set<String> { Set(poll.myVotes ?? []) }
    private var hienKetQua: Bool { !daBau.isEmpty || poll.closed == true }
    private var tong: Int { max(1, poll.totalVotes ?? 0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(poll.options ?? []) { o in
                let chon = daBau.contains(o.id)
                let tl = Double(o.votes ?? 0) / Double(tong)
                Button { bamChon(o.id) } label: {
                    ZStack(alignment: .leading) {
                        GeometryReader { g in
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(chon ? AppColors.primary.opacity(0.22) : AppColors.backgroundTertiary)
                                .frame(width: hienKetQua ? max(0, g.size.width * tl) : 0)
                                .animation(.easeOut(duration: 0.35), value: tl)
                        }
                        HStack(spacing: 8) {
                            Image(systemName: chon ? (poll.multi == true ? "checkmark.square.fill" : "checkmark.circle.fill")
                                                   : (poll.multi == true ? "square" : "circle"))
                                .foregroundColor(chon ? AppColors.primary : AppColors.textTertiary)
                            Text(verbatim: o.text ?? "").font(.ctw(size: 14, weight: chon ? .semibold : .regular))
                                .foregroundColor(AppColors.textPrimary).lineLimit(2).multilineTextAlignment(.leading)
                            Spacer(minLength: 4)
                            if hienKetQua {
                                Text(verbatim: "\(Int((tl * 100).rounded()))%").font(.ctw(size: 13, weight: .semibold).monospacedDigit())
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        .padding(.horizontal, 10)
                    }
                    .frame(minHeight: 40)
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(chon ? AppColors.primary : AppColors.border, lineWidth: chon ? 1.5 : 0.5))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!choBau || poll.closed == true)
                .accessibilityValue(hienKetQua ? Text("\(o.votes ?? 0) votes") : Text(""))
                .accessibilityAddTraits(chon ? .isSelected : [])
            }
            HStack(spacing: 4) {
                let n = poll.voters ?? poll.totalVotes ?? 0
                Text(n == 1 ? String(localized: "1 vote") : String(localized: "\(n) votes"))
                if poll.closed == true { Text(verbatim: "·"); Text("Poll closed") }
                else if let c = poll.closesAt, let d = Date.tuChuoiISO(c) { Text(verbatim: "·"); Text("Closes \(CTWDinhDang.tuongDoi(d))") }
                if poll.multi == true { Text(verbatim: "·"); Text("Choose several") }
                if !daBau.isEmpty && poll.closed != true {
                    Spacer()
                    Button("Undo vote") { bau([]) }.font(.ctw(size: 12, weight: .semibold))
                }
            }
            .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
        }
    }

    private func bamChon(_ id: String) {
        if poll.multi == true {
            var s = daBau
            if s.contains(id) { s.remove(id) } else { s.insert(id) }
            bau(Array(s).sorted())
        } else {
            bau(daBau == [id] ? [] : [id])
        }
    }
}
