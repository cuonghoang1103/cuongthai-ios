import SwiftUI
import AVFoundation
import Kingfisher

// MARK: - Một tin chat (kiểu Slack: avatar + tên + chữ, gộp tin liền nhau của cùng người)
//
// Hiện: chữ markdown (tô @nhắc, nhắc TÔI có nền), ảnh thu nhỏ (url ký sẵn), tệp
// (chạm ⇒ Xem nhanh), voice note (phát + bản phiên âm tự động), thẻ/tài liệu được
// nhắc, link web, cảm xúc (chạm để thả/bỏ), số trả lời, dấu ghim, "(edited)".
// Tin của AI agent luôn có nhãn "AI agent" (4.7).

/// Hành động mà một hàng tin gọi ra màn kênh.
struct HanhDongTinCTW {
    var camXuc: ((CTWChatMessage, String) -> Void)?
    var themCamXuc: ((CTWChatMessage) -> Void)?
    var moChuoi: ((CTWChatMessage) -> Void)?
    var xemTep: ((CTWChatFile) -> Void)?
    var moCuocGoi: ((URL) -> Void)?
}

struct TinChatCTW: View {
    let tin: CTWChatMessage
    var pid: Int = 0
    var gop = false
    var laCuaToi = false
    var hanhDong = HanhDongTinCTW()
    @EnvironmentObject private var app: AppState
    @Environment(\.openURL) private var moUrl

    var body: some View {
        if tin.laHeThong { tinHeThong } else { tinNguoi }
    }

    // MARK: Tin hệ thống

    private var tinHeThong: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: tin.laCuocGoi ? "phone.fill" : "info.circle").font(.system(size: 11))
                Text("\(tin.author?.ten ?? "CT Work") \(tin.body ?? "")").font(.system(size: 12))
                    .multilineTextAlignment(.center)
                Text(CTWChatThoiGian.gio(tin.createdAt)).font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
            }
            .foregroundColor(AppColors.textSecondary)
            if tin.laCuocGoi, let s = tin.meta?.url, let u = URL(string: s) {
                Button { hanhDong.moCuocGoi?(u) } label: {
                    Label("Join call", systemImage: "video.fill").font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Capsule().fill(AppColors.success.opacity(0.15)))
                        .foregroundColor(AppColors.success)
                }
                .buttonStyle(.plain)
            }
            if let k = tin.meta?.key, tin.meta?.type == "issue", let u = tin.meta?.url {
                Button { DinhTuyenCTW.mo(duongDan: u) } label: {
                    Label("Open \(k)", systemImage: "checkmark.square").font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundColor(AppColors.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    // MARK: Tin người

    private var tinNguoi: some View {
        HStack(alignment: .top, spacing: 10) {
            if gop { Color.clear.frame(width: 36, height: 1) } else { CTWAvatar(user: tin.author, size: 36) }
            VStack(alignment: .leading, spacing: 4) {
                if !gop {
                    HStack(spacing: 6) {
                        Text(tin.author?.ten ?? "Deleted user").font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary).lineLimit(1)
                        if tin.author?.laAgent == true { CTWNhanAI() }
                        Text(CTWChatThoiGian.gio(tin.createdAt)).font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                        if tin.daGhim {
                            Image(systemName: "pin.fill").font(.system(size: 9)).foregroundColor(AppColors.warning)
                                .accessibilityLabel("Pinned")
                        }
                    }
                }
                if tin.daXoa {
                    Text("This message was deleted.").font(.system(size: 14).italic()).foregroundColor(AppColors.textTertiary)
                } else {
                    noiDung
                }
                if let n = tin.replyCount, n > 0 {
                    Button { hanhDong.moChuoi?(tin) } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrowshape.turn.up.left.2.fill").font(.system(size: 10))
                            Text(n == 1 ? "1 reply" : "\(n) replies").font(.system(size: 12, weight: .semibold))
                            if let l = tin.lastReplyAt {
                                Text("· \(CTWChatThoiGian.gio(l))").font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                            }
                        }
                        .foregroundColor(AppColors.primary)
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, gop ? 0 : 8)
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(nhacToi ? AppColors.warning.opacity(0.08) : (tin.daGhim ? AppColors.warning.opacity(0.05) : Color.clear))
        )
        .contentShape(Rectangle())
    }

    private var nhacToi: Bool {
        guard let toi = app.currentUser?.id else { return false }
        return (tin.mentions ?? []).contains(toi)
    }

    @ViewBuilder private var noiDung: some View {
        if let b = tin.body, !b.isEmpty {
            Text(CTWChatChu.dung(b, toi: app.currentUser?.username))
                .font(.system(size: 15)).foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        let tep = tin.files ?? []
        let anh = tep.filter { $0.laAnh && !$0.laGiongNoi }
        if !anh.isEmpty {
            LuoiAnhChatCTW(pid: pid, anh: anh) { hanhDong.xemTep?($0) }
        }
        ForEach(tep.filter { !$0.laAnh || $0.laGiongNoi }) { f in
            if f.laGiongNoi {
                GiongNoiChatCTW(pid: pid, tep: f)
            } else {
                TheTepChatCTW(tep: f) { hanhDong.xemTep?(f) }
            }
        }
        ForEach(Array((tin.previews ?? []).prefix(3).enumerated()), id: \.offset) { _, p in
            Button { if let u = p.url { DinhTuyenCTW.mo(duongDan: u) } } label: {
                HStack(spacing: 7) {
                    Image(systemName: p.t == "doc" ? "doc.text" : (p.t == "meeting" ? "calendar" : "checkmark.square"))
                        .foregroundColor(AppColors.primary)
                    Text(p.key ?? "").font(.system(size: 12, weight: .semibold).monospaced()).foregroundColor(AppColors.textSecondary)
                    Text(p.title ?? "").font(.system(size: 13)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .frame(maxWidth: 420, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(AppColors.backgroundSecondary))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(AppColors.border, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        ForEach(Array((tin.links ?? []).prefix(2).enumerated()), id: \.offset) { _, l in
            if let s = l.url, let u = URL(string: s) {
                Button { moUrl(u) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "link").foregroundColor(AppColors.primary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(l.title ?? l.domain ?? s).font(.system(size: 13, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                            if let d = l.domain { Text(d).font(.system(size: 11)).foregroundColor(AppColors.textSecondary) }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .frame(maxWidth: 420, alignment: .leading)
                    .overlay(alignment: .leading) { Rectangle().fill(AppColors.primary).frame(width: 3) }
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(AppColors.backgroundSecondary))
                }
                .buttonStyle(.plain)
            }
        }
        if tin.editedAt != nil {
            Text("(edited)").font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
        }
        if let r = tin.reactions, !r.isEmpty {
            HangCamXucCTW(ds: r) { e in hanhDong.camXuc?(tin, e) } them: { hanhDong.themCamXuc?(tin) }
        }
    }
}

// MARK: - Chữ tin: markdown dòng + tô @nhắc

enum CTWChatChu {
    static func dung(_ s: String, toi: String?) -> AttributedString {
        var a = CTWKhoiView.dong(s)
        let chu = String(a.characters)
        guard chu.contains("@"), let re = try? NSRegularExpression(pattern: "(?<![\\w@./-])@([A-Za-z0-9_][A-Za-z0-9_.-]{0,39})") else { return a }
        let ns = chu as NSString
        for m in re.matches(in: chu, range: NSRange(location: 0, length: ns.length)) {
            guard let r = Range(m.range, in: chu),
                  let lo = AttributedString.Index(r.lowerBound, within: a),
                  let hi = AttributedString.Index(r.upperBound, within: a) else { continue }
            let ten = String(chu[r].dropFirst()).lowercased()
            a[lo..<hi].foregroundColor = AppColors.primary
            a[lo..<hi].font = .system(size: 15, weight: .semibold)
            if let toi, ten == toi.lowercased() { a[lo..<hi].backgroundColor = AppColors.primary.opacity(0.14) }
        }
        return a
    }
}

// MARK: - Cảm xúc

struct HangCamXucCTW: View {
    let ds: [CTWReaction]
    let bam: (String) -> Void
    let them: () -> Void

    var body: some View {
        // Bọc dòng: nhiều cảm xúc xuống hàng thay vì tràn.
        BoCucBocDongCTW(khoang: 5) {
            ForEach(ds, id: \.emoji) { x in
                Button { bam(x.emoji) } label: {
                    HStack(spacing: 4) {
                        Text(x.emoji).font(.system(size: 14))
                        Text("\(x.count ?? 0)").font(.system(size: 12, weight: .semibold).monospacedDigit())
                            .foregroundColor(x.mine == true ? AppColors.primary : AppColors.textSecondary)
                    }
                    .padding(.horizontal, 8).frame(height: 28)
                    .background(Capsule().fill(x.mine == true ? AppColors.primary.opacity(0.14) : AppColors.backgroundTertiary))
                    .overlay(Capsule().strokeBorder(x.mine == true ? AppColors.primary.opacity(0.5) : Color.clear, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(x.emoji) \(x.count ?? 0)\(x.mine == true ? ", you reacted" : "")")
            }
            Button(action: them) {
                Image(systemName: "face.smiling").font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 9).frame(height: 28)
                    .background(Capsule().fill(AppColors.backgroundTertiary))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add reaction")
        }
    }
}

/// Bố cục bọc dòng tối giản (chip cảm xúc, chip tệp nháp).
struct BoCucBocDongCTW: Layout {
    var khoang: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rong = proposal.width ?? 320
        var x: CGFloat = 0, y: CGFloat = 0, cao: CGFloat = 0, max: CGFloat = 0
        for s in subviews {
            let c = s.sizeThatFits(.unspecified)
            if x > 0 && x + c.width > rong { x = 0; y += cao + khoang; cao = 0 }
            x += c.width + khoang
            cao = Swift.max(cao, c.height)
            max = Swift.max(max, x - khoang)
        }
        return CGSize(width: max, height: y + cao)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, cao: CGFloat = 0
        for s in subviews {
            let c = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + c.width > bounds.maxX { x = bounds.minX; y += cao + khoang; cao = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(c))
            x += c.width + khoang
            cao = Swift.max(cao, c.height)
        }
    }
}

// MARK: - Ảnh

struct LuoiAnhChatCTW: View {
    let pid: Int
    let anh: [CTWChatFile]
    let bam: (CTWChatFile) -> Void

    var body: some View {
        if anh.count == 1, let a = anh.first {
            AnhTepChatCTW(pid: pid, tep: a, co: CGSize(width: 260, height: 200)) { bam(a) }
        } else {
            LazyVGrid(columns: [GridItem(.fixed(124), spacing: 6), GridItem(.fixed(124), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(anh.prefix(6)) { a in
                    AnhTepChatCTW(pid: pid, tep: a, co: CGSize(width: 124, height: 124)) { bam(a) }
                }
            }
        }
    }
}

struct AnhTepChatCTW: View {
    let pid: Int
    let tep: CTWChatFile
    let co: CGSize
    let bam: () -> Void
    @State private var url: URL?
    @State private var hong = false

    var body: some View {
        Button(action: bam) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColors.backgroundTertiary)
                if hong && AppState.shared.cheDoXemThu {
                    AnhMauCTW(hat: tep.id)
                } else if let url {
                    KFImage(url)
                        .placeholder { ProgressView() }
                        .resizable()
                        .scaledToFill()
                } else if hong {
                    Image(systemName: "photo").foregroundColor(AppColors.textTertiary)
                } else {
                    ProgressView()
                }
            }
            .frame(width: co.width, height: co.height)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(AppColors.border, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Image \(tep.fileName ?? "")")
        .task(id: tep.id) {
            #if DEBUG
            if AppState.shared.cheDoXemThu { hong = true; return }
            #endif
            do { url = try await UrlTepChatCTW.lay(pid: pid, fid: tep.id) } catch { hong = true }
        }
    }
}

/// Ảnh minh hoạ trong chế độ xem thử (máy chủ giả không phục vụ ảnh) — chỉ hiện khi `cheDoXemThu`.
struct AnhMauCTW: View {
    let hat: Int
    var body: some View {
        let mau: [Color] = hat % 2 == 0 ? [AppColors.primary, AppColors.secondary] : [AppColors.accent, AppColors.brandPink]
        ZStack {
            LinearGradient(colors: mau, startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.85)).frame(width: 60, height: 8)
                RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.6)).frame(width: 90, height: 6)
                RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.35)).frame(width: 80, height: 40)
            }
        }
    }
}

// MARK: - Tệp

struct TheTepChatCTW: View {
    let tep: CTWChatFile
    let bam: () -> Void

    var body: some View {
        Button(action: bam) {
            HStack(spacing: 10) {
                Image(systemName: tep.bieuTuong).font(.system(size: 17, weight: .medium)).foregroundColor(AppColors.primary)
                    .frame(width: 38, height: 38)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(AppColors.primary.opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(tep.fileName ?? "File").font(.system(size: 14, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                    Text([tep.coChu, (tep.fileName as NSString?)?.pathExtension.uppercased()].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.system(size: 11)).foregroundColor(AppColors.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "eye").font(.system(size: 13)).foregroundColor(AppColors.textTertiary)
            }
            .padding(10)
            .frame(maxWidth: 360, alignment: .leading)
            .ctwThe(11)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("File \(tep.fileName ?? ""), \(tep.coChu ?? ""). Double tap to preview.")
    }
}

// MARK: - Voice note

@MainActor
final class TrinhPhatGiongNoiCTW: ObservableObject {
    static let shared = TrinhPhatGiongNoiCTW()
    @Published private(set) var dangPhat: Int?
    @Published private(set) var tienDo: Double = 0
    private var player: AVPlayer?
    private var quanSat: Any?
    private var ketThuc: NSObjectProtocol?

    func batTat(fid: Int, url: URL) {
        if dangPhat == fid { dung(); return }
        dung()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        let p = AVPlayer(url: url)
        player = p
        dangPhat = fid
        tienDo = 0
        quanSat = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.2, preferredTimescale: 600), queue: .main) { [weak self] t in
            guard let d = p.currentItem?.duration.seconds, d.isFinite, d > 0 else { return }
            Task { @MainActor in self?.tienDo = t.seconds / d }
        }
        ketThuc = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: p.currentItem, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.dung() }
        }
        p.play()
    }

    func dung() {
        player?.pause()
        if let quanSat { player?.removeTimeObserver(quanSat) }
        if let ketThuc { NotificationCenter.default.removeObserver(ketThuc) }
        quanSat = nil; ketThuc = nil; player = nil
        dangPhat = nil
        tienDo = 0
    }
}

struct GiongNoiChatCTW: View {
    let pid: Int
    let tep: CTWChatFile
    @ObservedObject private var phat = TrinhPhatGiongNoiCTW.shared
    @State private var dangLay = false
    @State private var loi = false

    private var giay: Int { (tep.voice?.durationMs ?? 0) / 1000 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Button {
                    Task {
                        dangLay = true
                        defer { dangLay = false }
                        do { phat.batTat(fid: tep.id, url: try await UrlTepChatCTW.lay(pid: pid, fid: tep.id)) } catch { loi = true }
                    }
                } label: {
                    ZStack {
                        Circle().fill(AppColors.primary)
                        if dangLay { ProgressView().tint(.white) } else {
                            Image(systemName: phat.dangPhat == tep.id ? "pause.fill" : "play.fill")
                                .font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                        }
                    }
                    .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(phat.dangPhat == tep.id ? "Pause voice note" : "Play voice note, \(giay) seconds")
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppColors.primary.opacity(0.18))
                            Capsule().fill(AppColors.primary)
                                .frame(width: g.size.width * (phat.dangPhat == tep.id ? phat.tienDo : 0))
                        }
                    }
                    .frame(height: 5)
                    Text(String(format: "%d:%02d", giay / 60, giay % 60) + (loi ? " · Couldn't load" : ""))
                        .font(.system(size: 11).monospacedDigit()).foregroundColor(AppColors.textSecondary)
                }
                .frame(width: 150)
            }
            if let t = tep.voice?.transcript, !t.isEmpty, tep.voice?.transcriptStatus == "DONE" {
                VStack(alignment: .leading, spacing: 3) {
                    Label("Auto transcript", systemImage: "text.quote").font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                    Text(t).font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            } else if tep.voice?.transcriptStatus == "PENDING" {
                Text("Transcribing…").font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(10)
        .frame(maxWidth: 360, alignment: .leading)
        .ctwThe(12)
    }
}

// MARK: - Thời gian

enum CTWChatThoiGian {
    static func date(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }

    static func gio(_ s: String?) -> String {
        guard let d = date(s) else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = Calendar.current.isDateInToday(d) ? "HH:mm" : "MMM d, HH:mm"
        return f.string(from: d)
    }

    /// Nhãn vạch ngày: Today · Yesterday · Monday, Oct 13 · Oct 13, 2025.
    static func nhanNgay(_ d: Date) -> String {
        let c = Calendar.current
        if c.isDateInToday(d) { return "Today" }
        if c.isDateInYesterday(d) { return "Yesterday" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        if let tuan = c.date(byAdding: .day, value: -6, to: Date()), d > tuan {
            f.dateFormat = "EEEE, MMM d"
        } else {
            f.dateFormat = c.isDate(d, equalTo: Date(), toGranularity: .year) ? "EEEE, MMM d" : "MMM d, yyyy"
        }
        return f.string(from: d)
    }

    static func phut(_ a: String?, _ b: String?) -> Double {
        guard let x = date(a), let y = date(b) else { return 99 }
        return abs(y.timeIntervalSince(x)) / 60
    }
}
