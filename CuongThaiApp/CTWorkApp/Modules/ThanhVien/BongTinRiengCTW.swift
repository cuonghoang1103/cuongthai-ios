import SwiftUI
import AVFoundation
import Kingfisher

// MARK: - Bong bóng tin nhắn riêng kiểu Messenger (22/10/2026 — bản 1.1)
//
// Bo góc theo vị trí trong nhóm (`GocBongCTW` — góc nối với tin cùng nhóm bo nhỏ), avatar người kia MỘT lần ở cuối nhóm,
// trích dẫn trả lời, ảnh aspect-fit (§21), GIF tự chạy + nhãn dán (không nền), tin thoại (phát/tạm dừng, sóng âm),
// thẻ tệp (Xem nhanh), emoji lớn, link bấm được, viên cảm xúc (chạm ⇒ ai đã bày tỏ), "Tin nhắn đã thu hồi".
// Chạm ⇒ hiện giờ gửi; nhấn giữ ⇒ menu (thanh cảm xúc + thao tác) do màn chat vẽ (`MenuGiuTinRiengCTW`).

struct BongTinRiengCTW: View {
    let m: Message
    let cuaToi: Bool
    let viTri: ViTriNhomCTW
    let nguoiKia: CTWUser
    let tenKia: String
    let toi: Int?
    var hienGio = false
    /// Đang vẽ trong menu nhấn giữ (không avatar, không cử chỉ).
    var xemTruoc = false
    var cham: () -> Void = {}
    var giu: () -> Void = {}
    var xemAnh: (URL) -> Void = { _ in }
    var moTep: (MessageAttachment) -> Void = { _ in }
    var moHoSo: () -> Void = {}
    var xemCamXuc: () -> Void = {}
    var denTinGoc: (Int) -> Void = { _ in }

    static let rongToiDa: CGFloat = 520

    private var goc: GocBongCTW { GocBongCTW.cho(viTri, cuaToi: cuaToi) }
    private var hinh: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: goc.trenTrai, bottomLeadingRadius: goc.duoiTrai,
                               bottomTrailingRadius: goc.duoiPhai, topTrailingRadius: goc.trenPhai, style: .continuous)
    }
    private var mauNen: Color { cuaToi ? AppColors.primary : AppColors.backgroundSecondary }
    private var mauChu: Color { cuaToi ? AppColors.onPrimary : AppColors.textPrimary }
    private var camXuc: [MessageReaction] { m.reactions ?? [] }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if cuaToi { Spacer(minLength: 48) } else if !xemTruoc {
                Group {
                    if NhomTinCTW.hienAvatar(BoCucTinCTW(viTri: viTri, mocThoiGian: false), cuaToi: false) {
                        Button(action: moHoSo) { CTWAvatar(user: nguoiKia, size: 28) }
                            .buttonStyle(.plain)
                            .accessibilityLabel(String(localized: "\(tenKia), view profile"))
                            .accessibilityIdentifier("dm.avatar")
                    } else { Color.clear }
                }
                .frame(width: 28, height: 28)
            }
            VStack(alignment: cuaToi ? .trailing : .leading, spacing: 2) {
                if let p = m.parentMessage, !m.daXoaHoacThuHoi { trichDan(p) }
                noiDung
                    .overlay(alignment: cuaToi ? .bottomLeading : .bottomTrailing) { vienCamXuc }
                    .padding(.bottom, camXuc.isEmpty ? 0 : 14)
                if hienGio, let d = m.ngayGio {
                    Text(NhanMocCTW.chuoi(d)).font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                        .padding(.horizontal, 4).transition(.opacity)
                }
            }
            // iPad / màn rộng: bong bóng không kéo dài cả hàng (Messenger giữ ~ 500 pt).
            .frame(maxWidth: Self.rongToiDa, alignment: cuaToi ? .trailing : .leading)
            if !cuaToi { Spacer(minLength: 48) }
        }
        .padding(.horizontal, 10)
    }

    // MARK: Nội dung

    @ViewBuilder private var noiDung: some View {
        if m.daXoaHoacThuHoi {
            Text(cuaToi ? String(localized: "You unsent a message") : String(localized: "\(tenKia) unsent a message"))
                .font(.ctw(size: 14).italic()).foregroundColor(AppColors.textTertiary)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .overlay(hinh.stroke(AppColors.border, lineWidth: 1))
                .modifier(CuChiTin(cham: cham, giu: giu, tat: xemTruoc))
        } else {
            VStack(alignment: cuaToi ? .trailing : .leading, spacing: 2) {
                let anh = TomTatTinCTW.anhTep(m)
                if !anh.isEmpty { luoiAnh(anh) }
                if TomTatTinCTW.laGif(m), let u = DuongDanAnh.url(m.mediaUrl) { gif(u) }
                if TomTatTinCTW.laNhanDan(m), let u = DuongDanAnh.url(m.mediaUrl) { nhanDan(u) }
                ForEach(TomTatTinCTW.amThanh(m)) { a in
                    ThoaiCTW(tep: a, cuaToi: cuaToi).background(hinh.fill(mauNen)).clipShape(hinh)
                        .modifier(CuChiTin(cham: cham, giu: giu, tat: xemTruoc))
                }
                ForEach(TomTatTinCTW.tepKhac(m)) { a in theTep(a) }
                if let c = m.content, !c.isEmpty { chu(c) }
            }
        }
    }

    @ViewBuilder private func chu(_ c: String) -> some View {
        if EmojiLonCTW.la(c) {
            Text(verbatim: c).font(.system(size: 46))
                .accessibilityLabel(c)
                .modifier(CuChiTin(cham: cham, giu: giu, tat: xemTruoc))
        } else {
            Text(LienKetCTW.coLink(c))
                .font(.ctw(size: 16))
                .foregroundColor(mauChu)
                .tint(cuaToi ? AppColors.onPrimary : AppColors.primary)
                .padding(.horizontal, 13).padding(.vertical, 8)
                .background(hinh.fill(mauNen))
                .modifier(CuChiTin(cham: cham, giu: giu, tat: xemTruoc))
                .accessibilityLabel(c)
                .accessibilityAction(named: Text("Message actions"), giu)
        }
    }

    private func trichDan(_ p: MessageParent) -> some View {
        let t = TrichDanCTW.tu(p, toi: toi, tenKia: tenKia)
        return VStack(alignment: cuaToi ? .trailing : .leading, spacing: 2) {
            Label { Text(t.nhanTraLoi(nguoiTraLoiLaToi: cuaToi, tenKia: tenKia)) } icon: {
                Image(systemName: "arrowshape.turn.up.left.fill")
            }
            .font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
            Text(verbatim: t.chu)
                .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary).lineLimit(2)
                .padding(.horizontal, 12).padding(.top, 7).padding(.bottom, 12)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppColors.backgroundTertiary))
                .padding(.bottom, -8)
                .onTapGesture { if !xemTruoc { denTinGoc(p.id) } }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(Text("Shows the original message"))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("dm.quote")
    }

    @ViewBuilder private func luoiAnh(_ ds: [MessageAttachment]) -> some View {
        let urls = ds.compactMap { DuongDanAnh.urlAnh($0.url) ?? URL(string: $0.url) }
        if urls.count == 1, let u = urls.first {
            AnhVuaTiLeCTW(url: u, khoa: "dm-\(u.absoluteString)", toiDa: CGSize(width: 240, height: 300), bo: 0) { ProgressView() }
                .clipShape(hinh)
                .contentShape(Rectangle())
                .onTapGesture { if !xemTruoc { xemAnh(u) } }
                .onLongPressGesture(minimumDuration: 0.35) { if !xemTruoc { CTWRung.chon(); giu() } }
                .accessibilityLabel("Photo")
        } else {
            let cot = urls.count == 2 || urls.count == 4 ? 2 : 3
            let o: CGFloat = cot == 2 ? 118 : 78
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(o), spacing: 3), count: min(cot, urls.count)), spacing: 3) {
                ForEach(urls, id: \.self) { u in
                    KFImage(u).placeholder { Rectangle().fill(AppColors.backgroundSecondary) }
                        .resizable().scaledToFill()
                        .frame(width: o, height: o).clipped()
                        .contentShape(Rectangle())
                        .onTapGesture { if !xemTruoc { xemAnh(u) } }
                        .accessibilityLabel("Photo")
                }
            }
            .clipShape(hinh)
            .onLongPressGesture(minimumDuration: 0.35) { if !xemTruoc { CTWRung.chon(); giu() } }
        }
    }

    private func gif(_ u: URL) -> some View {
        KFAnimatedImage(u)
            .placeholder { RoundedRectangle(cornerRadius: 12).fill(AppColors.backgroundSecondary).overlay(ProgressView()) }
            .scaledToFit()
            .frame(maxWidth: 220, maxHeight: 220)
            .frame(minWidth: 120, minHeight: 90)
            .clipShape(hinh)
            .overlay(alignment: .bottomLeading) {
                Text(verbatim: "GIF").font(.ctw(size: 10, weight: .heavy)).foregroundColor(.white)
                    .padding(.horizontal, 5).padding(.vertical, 2).background(Capsule().fill(.black.opacity(0.45))).padding(6)
            }
            .modifier(CuChiTin(cham: cham, giu: giu, tat: xemTruoc))
            .accessibilityLabel("GIF")
            .accessibilityIdentifier("dm.gif")
    }

    private func nhanDan(_ u: URL) -> some View {
        KFAnimatedImage(u).placeholder { ProgressView() }
            .scaledToFit().frame(width: 128, height: 128)
            .modifier(CuChiTin(cham: cham, giu: giu, tat: xemTruoc))
            .accessibilityLabel("Sticker")
    }

    private func theTep(_ a: MessageAttachment) -> some View {
        Button { moTep(a) } label: {
            HStack(spacing: 10) {
                Image(systemName: Self.bieuTuongTep(a.fileName))
                    .font(.ctw(size: 18, weight: .semibold))
                    .foregroundColor(cuaToi ? AppColors.primary : AppColors.onPrimary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(cuaToi ? AppColors.onPrimary : AppColors.primary))
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: a.fileName ?? String(localized: "File")).font(.ctw(size: 14, weight: .semibold)).lineLimit(2)
                    if let s = a.fileSize {
                        Text(ByteCountFormatter.string(fromByteCount: Int64(s), countStyle: .file)).font(.ctw(size: 11)).opacity(0.8)
                    }
                }
                .multilineTextAlignment(.leading)
            }
            .foregroundColor(mauChu)
            .padding(10)
            .frame(maxWidth: 250, alignment: .leading)
            .background(hinh.fill(mauNen))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.35).onEnded { _ in if !xemTruoc { CTWRung.chon(); giu() } })
        .accessibilityLabel(String(localized: "File \(a.fileName ?? "")"))
    }

    static func bieuTuongTep(_ ten: String?) -> String {
        switch ((ten ?? "") as NSString).pathExtension.lowercased() {
        case "pdf": return "doc.richtext"
        case "zip", "rar", "7z": return "doc.zipper"
        case "xls", "xlsx", "csv": return "tablecells"
        case "doc", "docx", "txt", "md": return "doc.text"
        case "ppt", "pptx", "key": return "rectangle.on.rectangle"
        case "mp4", "mov": return "film"
        default: return "doc"
        }
    }

    @ViewBuilder private var vienCamXuc: some View {
        if !camXuc.isEmpty {
            let v = CamXucCTW.vien(camXuc)
            let cua = CamXucCTW.cuaToi(camXuc, toi: toi)
            Button(action: xemCamXuc) {
                HStack(spacing: 1) {
                    ForEach(v.emoji, id: \.self) { Text(verbatim: $0).font(.ctw(size: 13)) }
                    if v.tong > 1 { Text(verbatim: "\(v.tong)").font(.ctw(size: 11, weight: .semibold)).foregroundColor(AppColors.textSecondary).padding(.leading, 2) }
                }
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(AppColors.backgroundCard))
                .overlay(Capsule().strokeBorder(cua.isEmpty ? AppColors.border : AppColors.primary.opacity(0.55), lineWidth: 1))
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
            }
            .buttonStyle(.plain)
            .disabled(xemTruoc)
            .offset(x: cuaToi ? -6 : 6, y: 16)
            .accessibilityLabel(String(localized: "Reactions: \(camXuc.map { "\($0.emoji) \($0.count)" }.joined(separator: ", "))"))
            .accessibilityIdentifier("dm.reactions.\(m.id)")
        }
    }
}

/// Chạm (hiện giờ) + nhấn giữ (menu) — tắt khi vẽ trong menu.
private struct CuChiTin: ViewModifier {
    let cham: () -> Void
    let giu: () -> Void
    let tat: Bool
    func body(content: Content) -> some View {
        if tat { content } else {
            content
                .contentShape(Rectangle())
                .onTapGesture(perform: cham)
                .onLongPressGesture(minimumDuration: 0.35) { CTWRung.chon(); giu() }
        }
    }
}

// MARK: - Mốc thời gian giữa các tin

struct MocThoiGianTinCTW: View {
    let d: Date
    var body: some View {
        Text(NhanMocCTW.chuoi(d))
            .font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, 14).padding(.bottom, 6)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - "Đang nhập…" (bong bóng ba chấm nhún)

struct BongDangGoCTW: View {
    let nguoi: CTWUser
    @Environment(\.accessibilityReduceMotion) private var giamChuyenDong
    @State private var pha = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            CTWAvatar(user: nguoi, size: 28)
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle().fill(AppColors.textTertiary).frame(width: 7, height: 7)
                        .offset(y: pha && !giamChuyenDong ? -3 : 2)
                        .animation(giamChuyenDong ? nil : .easeInOut(duration: 0.45).repeatForever().delay(Double(i) * 0.15), value: pha)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Capsule().fill(AppColors.backgroundSecondary))
            Spacer()
        }
        .padding(.horizontal, 10).padding(.top, 6)
        .onAppear { pha = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "\(nguoi.ten) is typing…"))
        .accessibilityIdentifier("dm.typing")
    }
}

// MARK: - Tin thoại

@MainActor
final class TrinhPhatThoaiCTW: ObservableObject {
    static let shared = TrinhPhatThoaiCTW()
    @Published private(set) var dang: URL?
    @Published private(set) var chay = false
    @Published private(set) var tienDo: Double = 0
    @Published private(set) var hong: Set<URL> = []
    private var p: AVPlayer?
    private var quanSat: Any?
    private var huy: [NSObjectProtocol] = []
    /// Độ dài đã biết theo url (giây).
    static var doDai: [URL: Double] = [:]

    func batTat(_ u: URL) {
        if dang == u, let p {
            if chay { p.pause(); chay = false } else { p.play(); chay = true }
            return
        }
        dung()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        let item = AVPlayerItem(url: u)
        let p = AVPlayer(playerItem: item)
        self.p = p; dang = u; tienDo = 0
        quanSat = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] t in
            Task { @MainActor in
                guard let self, let d = self.p?.currentItem?.duration.seconds, d.isFinite, d > 0 else { return }
                self.tienDo = min(1, t.seconds / d)
                Self.doDai[u] = d
            }
        }
        huy.append(NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.dung() }
        })
        huy.append(NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.hong.insert(u); self?.dung() }
        })
        p.play(); chay = true
        // Tệp web ghi bằng `audio/webm` (Chrome) iOS không giải được ⇒ đánh dấu để bong bóng mời mở bằng Xem nhanh.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            if item.status == .failed { self?.hong.insert(u); self?.dung() }
        }
    }

    func dung() {
        p?.pause()
        if let quanSat { p?.removeTimeObserver(quanSat) }
        quanSat = nil
        huy.forEach(NotificationCenter.default.removeObserver)
        huy = []
        p = nil; dang = nil; chay = false; tienDo = 0
    }
}

struct ThoaiCTW: View {
    let tep: MessageAttachment
    let cuaToi: Bool
    @ObservedObject private var trinh = TrinhPhatThoaiCTW.shared
    @State private var doDai: Double?

    private var url: URL? { DuongDanAnh.url(tep.url) ?? URL(string: tep.url) }
    private var dangPhat: Bool { url != nil && trinh.dang == url }
    private var mau: Color { cuaToi ? AppColors.onPrimary : AppColors.primary }

    /// Sóng âm giả lập ổn định theo id tệp (máy chủ không trả mẫu sóng).
    private var cot: [CGFloat] {
        var h = UInt64(truncatingIfNeeded: tep.id &* 2654435761)
        return (0..<26).map { _ in
            h = h &* 6364136223846793005 &+ 1442695040888963407
            return 0.25 + CGFloat((h >> 33) % 75) / 100
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Button { if let url { trinh.batTat(url) } } label: {
                Image(systemName: dangPhat && trinh.chay ? "pause.fill" : "play.fill")
                    .font(.ctw(size: 15, weight: .bold)).foregroundColor(cuaToi ? AppColors.primary : AppColors.onPrimary)
                    .frame(width: 34, height: 34).background(Circle().fill(mau))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(dangPhat && trinh.chay ? String(localized: "Pause voice message") : String(localized: "Play voice message"))
            HStack(alignment: .center, spacing: 2) {
                ForEach(Array(cot.enumerated()), id: \.offset) { i, c in
                    let da = dangPhat && Double(i) / Double(cot.count) <= trinh.tienDo
                    Capsule().fill(mau.opacity(da ? 1 : 0.45)).frame(width: 3, height: 26 * c)
                }
            }
            .frame(height: 28)
            .accessibilityHidden(true)
            Text(verbatim: Self.dongHo(doDai ?? url.flatMap { TrinhPhatThoaiCTW.doDai[$0] }))
                .font(.ctw(size: 12, weight: .semibold).monospacedDigit())
                .foregroundColor(cuaToi ? AppColors.onPrimary : AppColors.textSecondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            if let url, trinh.hong.contains(url) {
                Text("Can't play here — open the file instead").font(.ctw(size: 10)).foregroundColor(cuaToi ? AppColors.onPrimary : AppColors.error)
                    .offset(y: 14)
            }
        }
        .task {
            guard let url, doDai == nil else { return }
            if let d = try? await AVURLAsset(url: url).load(.duration).seconds, d.isFinite, d > 0 {
                doDai = d; TrinhPhatThoaiCTW.doDai[url] = d
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Voice message"))
    }

    static func dongHo(_ giay: Double?) -> String {
        guard let giay, giay.isFinite else { return "0:00" }
        let g = Int(giay.rounded())
        return "\(g / 60):" + String(format: "%02d", g % 60)
    }
}
