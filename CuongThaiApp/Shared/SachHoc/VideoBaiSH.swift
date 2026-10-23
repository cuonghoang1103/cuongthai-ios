import SwiftUI
import AVKit

// ════════════════════════════════════════════════════════════════
// VIDEO TRONG BÀI — bản native của VideoBai.tsx. Hai nguồn, hai chỗ hiện:
//  1. `videos` (đầu bài): YouTube tuyển chọn hoặc mp4.
//  2. `videoNeo[neo]`: mp4 TỰ LÀM gắn vào đúng MỤC — neo `#<đầu tiêu đề>` hiện
//     NGAY DƯỚI khối `h` đầu tiên khớp (luật `khopNeo` của web — sửa thì sửa cả
//     hai), `dau-bai` và neo không khớp thì lên đầu bài (không bao giờ mất video).
// Phát NGAY TẠI CHỖ (AVPlayer / khung YouTube), chỉ nạp khi bấm ảnh bìa. Một video
// chạy thì video khác + giọng đọc dừng. Nhớ vị trí xem dở trên máy.
// ════════════════════════════════════════════════════════════════

enum NeoVideoSH {
    /// Chữ tiêu đề để so neo: bỏ furigana, bỏ `** == ~~`, NFKC, gộp khoảng trắng.
    static func chuan(_ t: String) -> String {
        PhanTichChuSH.tron(t).replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "==", with: "").replacingOccurrences(of: "~~", with: "")
            .precomposedStringWithCompatibilityMapping
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func khop(_ tieuDe: String, _ neo: String) -> Bool {
        guard neo.hasPrefix("#") else { return false }
        let can = chuan(String(neo.dropFirst()))
        let h = chuan(tieuDe)
        guard !can.isEmpty, h.hasPrefix(can) else { return false }
        func laSoChu(_ c: Character?) -> Bool { c.map { $0.isASCII && ($0.isLetter || $0.isNumber) } ?? false }
        let sau = h.dropFirst(can.count).first
        return !(laSoChu(sau) && laSoChu(can.last))
    }

    /// Chia video theo neo: chỉ số khối `h` ⇒ video; phần còn lại lên đầu bài.
    static func chia(_ b: BaiSH) -> (dauBai: [VideoMucSH], theoKhoi: [Int: [VideoMucSH]]) {
        var dau: [VideoMucSH] = []
        var theo: [Int: [VideoMucSH]] = [:]
        for (neo, vs) in (b.videoNeo ?? [:]).sorted(by: { $0.key < $1.key }) where !vs.isEmpty {
            if neo != "dau-bai", let i = b.blocks.firstIndex(where: { if case .h(let t) = $0 { return khop(t, neo) }; return false }) {
                theo[i, default: []] += vs
            } else {
                dau += vs
            }
        }
        return (dau, theo)
    }
}

/// Video nào đang phát (chỉ một) — video khác thấy đổi thì tự dừng.
@MainActor
final class VideoDangPhatSH: ObservableObject {
    static let chung = VideoDangPhatSH()
    @Published var id: String?
}

/// Một video mp4 phát tại chỗ: ảnh bìa + nút ▶, bấm mới nạp.
struct VideoNoiSH: View {
    let v: VideoMucSH
    @ObservedObject private var dang = VideoDangPhatSH.chung
    @State private var player: AVPlayer?

    private var ma: String { v.id ?? v.src }
    private var khoaViTri: String { "sachhoc.video.\(ma)" }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                if let player {
                    VideoPlayer(player: player)
                } else {
                    Button { batDau() } label: {
                        ZStack {
                            if let p = v.poster, let u = URL(string: p) {
                                AsyncImage(url: u) { $0.resizable().scaledToFill() } placeholder: { Color.black }
                            } else {
                                LinearGradient(colors: [Color(hex: 0x1E1B4B), Color(hex: 0x7A45E8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            }
                            Image(systemName: "play.circle.fill").font(.system(size: 54)).foregroundStyle(.white, .black.opacity(0.35))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Phát video \(v.tieuDe)")
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "film").font(.system(size: 12)).foregroundColor(AppColors.brandPink)
                ChuSH(text: v.tieuDe, co: 14.5, dam: true)
                if let g = v.thoiLuongGiay, g > 0 { Text(gio(g)).font(.system(size: 12).monospacedDigit()).foregroundColor(AppColors.textTertiary) }
            }
            if let gc = v.ghiChu, !gc.isEmpty { ChuSH(text: gc, co: 13, mau: .mo) }
        }
        .onChange(of: dang.id) { _, id in if id != ma { luuViTri(); player?.pause() } }
        .onDisappear { luuViTri(); player?.pause() }
    }

    private func batDau() {
        guard let u = URL(string: v.src) else { return }
        GiongSachHoc.chung.dung()
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        let p = AVPlayer(url: u)
        let t = UserDefaults.standard.double(forKey: khoaViTri)
        if t > 5 { p.seek(to: CMTime(seconds: t, preferredTimescale: 600)) }
        player = p
        dang.id = ma
        p.play()
    }

    private func luuViTri() {
        guard let p = player else { return }
        let t = p.currentTime().seconds
        if t.isFinite { UserDefaults.standard.set(t, forKey: khoaViTri) }
    }

    private func gio(_ g: Double) -> String {
        let t = Int(g.rounded())
        return t >= 3600 ? String(format: "%d:%02d:%02d", t / 3600, t % 3600 / 60, t % 60) : String(format: "%d:%02d", t / 60, t % 60)
    }
}

/// Video YouTube tuyển chọn — ảnh bìa, bấm mới nạp khung YouTube ngay trong bài.
struct VideoYouTubeSH: View {
    let v: VideoBaiSH
    @State private var mo = false
    @Environment(\.openURL) private var moURL

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                #if os(iOS)
                if mo {
                    YouTubePlayer(videoId: v.id)
                } else {
                    anhBia
                }
                #else
                anhBia
                #endif
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "play.rectangle.fill").font(.system(size: 12)).foregroundColor(.red)
                Text(v.credit ?? "Video YouTube").font(.system(size: 13.5, weight: .semibold)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                if let d = v.dur { Text(d).font(.system(size: 12).monospacedDigit()).foregroundColor(AppColors.textTertiary) }
            }
            if let n = v.note, !n.isEmpty { ChuSH(text: n, co: 13, mau: .mo) }
        }
    }

    private var anhBia: some View {
        Button {
            GiongSachHoc.chung.dung()
            #if os(iOS)
            mo = true
            #else
            if let u = URL(string: "https://www.youtube.com/watch?v=\(v.id)") { moURL(u) }
            #endif
        } label: {
            ZStack {
                AsyncImage(url: URL(string: "https://i.ytimg.com/vi/\(v.id)/hqdefault.jpg")) { $0.resizable().scaledToFill() } placeholder: { Color.black }
                Image(systemName: "play.circle.fill").font(.system(size: 54)).foregroundStyle(.white, .red)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Phát video \(v.credit ?? "")")
    }
}
