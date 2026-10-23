import SwiftUI
import AVKit

// ════════════════════════════════════════════════════════════════
// MÀN ĐỌC MỘT BÀI của khoá kiểu sách.
// "Bài tiếp/Bài trước" đổi bài TẠI CHỖ (không đẩy thêm màn) — và ScrollView mang
// `.id(bài)` nên bài mới luôn mở từ ĐẦU trang (bài học 23/08: ScrollView giữ vị
// trí cuộn khi nội dung đổi ⇒ bài mới mở ra ở cuối trang).
// ════════════════════════════════════════════════════════════════

struct BaiSachHocView: View {
    @ObservedObject var vm: SachHocVM
    @State var muc: MucDocSH
    #if DEBUG
    /// Màn soi: cuộn tới khối thứ n lúc mở (`CT_SACHHOC_CUON`).
    var cuonToi: Int? = nil
    #endif

    @State private var bai: BaiSH?
    @State private var loi: String?
    @State private var banCu = false
    @State private var videoMo: VideoMoSH?
    @Environment(\.openURL) private var moURL
    @AppStorage(CaiDatDocSH.furigana) private var furi = true
    @AppStorage(CaiDatDocSH.romaji) private var roma = true
    @AppStorage(CaiDatDocSH.coChu) private var tiLe = 1.0
    @AppStorage(CaiDatDocSH.tocDo) private var tocDo = 1.0

    var body: some View {
        ScrollViewReader { cuon in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    dau
                    if let bai {
                        if !danhSachVideo(bai).isEmpty { khoiVideo(bai) }
                        ForEach(Array(nhom(bai).enumerated()), id: \.offset) { i, n in
                            nhomView(n).id(i)
                        }
                        cuoi
                    } else if let loi {
                        KhungLoiSH(loi: loi) { Task { await nap() } }
                    } else {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 60)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .id(muc)
            #if DEBUG
            .onChange(of: bai?.id) { _, _ in
                if let n = cuonToi, bai != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { cuon.scrollTo(n, anchor: .top) }
                }
            }
            #endif
        }
        .environment(\.baiDangDocSH, muc.id)
        .environmentObject(vm)
        .background(AppColors.backgroundPrimary)
        .navigationTitle(vm.meta(muc)?.nhan ?? "")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) { menuDoc }
        }
        .task(id: muc) { await nap() }
        .onDisappear { GiongSachHoc.chung.dung() }
        .sheet(item: $videoMo) { v in TrinhPhatVideoSH(video: v) }
    }

    private func nap() async {
        bai = nil; loi = nil
        GiongSachHoc.chung.dung()
        do {
            bai = try await vm.noiDungMuc(muc)
            if bai == nil { loi = "Không tìm thấy bài này trong khoá." }
        } catch {
            loi = error.localizedDescription
        }
    }

    // MARK: Đầu bài

    private var dau: some View {
        let m = vm.meta(muc)
        let kind = bai?.kind ?? m?.kind ?? "intro"
        let mau = mauLoaiSH(vm.khoa, kind)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(vm.khoa?.nhan(kind) ?? kind)
                    .font(.system(size: 12, weight: .bold)).foregroundColor(mau)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Capsule().fill(mau.opacity(0.13)))
                if let phu = vm.khoa?.nhanLoaiPhu[kind], phu != vm.khoa?.nhan(kind) {
                    Text(phu).font(.system(size: 12)).foregroundColor(AppColors.textTertiary).lineLimit(1)
                }
                Spacer()
                if let bai, bai.minutes > 0 {
                    Label("~\(bai.minutes) phút", systemImage: "clock").font(.system(size: 12.5)).foregroundColor(AppColors.textTertiary)
                }
            }
            ChuSH(text: bai?.title ?? m?.title ?? "", co: 25, dam: true)
            if let goal = bai?.goal, !goal.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "target").foregroundColor(mau).font(.system(size: 15, weight: .semibold)).padding(.top, 2)
                    ChuSH(text: goal, co: 16, mau: .phu)
                }
            }
            if banCu || vm.banLuu {
                Label("Đang xem bản đã lưu trên máy — không tới được máy chủ.", systemImage: "wifi.slash")
                    .font(.system(size: 12.5)).foregroundColor(AppColors.warning)
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: Video gắn bài

    private func danhSachVideo(_ b: BaiSH) -> [VideoMoSH] {
        var ds: [VideoMoSH] = []
        for (neo, vs) in (b.videoNeo ?? [:]).sorted(by: { $0.key < $1.key }) {
            for v in vs { ds.append(VideoMoSH(id: v.id ?? v.src, tieuDe: v.tieuDe, url: URL(string: v.src), youtube: nil, ghiChu: neo == "dau-bai" ? v.ghiChu : "Mục: " + neo.dropFirst())) }
        }
        for v in b.videos ?? [] {
            if let s = v.src { ds.append(VideoMoSH(id: v.id, tieuDe: v.note ?? v.credit ?? "Video", url: URL(string: s), youtube: nil, ghiChu: v.dur)) }
            else { ds.append(VideoMoSH(id: v.id, tieuDe: v.credit ?? "Video YouTube", url: nil, youtube: v.id, ghiChu: v.note)) }
        }
        return ds
    }

    private func khoiVideo(_ b: BaiSH) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🎬 VIDEO CỦA BÀI").font(.system(size: 11, weight: .heavy)).kerning(0.5).foregroundColor(AppColors.brandPink)
            ForEach(danhSachVideo(b)) { v in
                Button {
                    if let y = v.youtube, let u = URL(string: "https://www.youtube.com/watch?v=\(y)") { moURL(u) } else { videoMo = v }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.rectangle.fill").font(.system(size: 22)).foregroundColor(AppColors.brandPink)
                        VStack(alignment: .leading, spacing: 2) {
                            ChuSH(text: v.tieuDe, co: 15, dam: true)
                            if let g = v.ghiChu, !g.isEmpty { ChuSH(text: String(g), co: 12.5, mau: .mo) }
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .theKhoiSH(vien: AppColors.brandPink.opacity(0.35), nen: AppColors.brandPink.opacity(0.05))
    }

    // MARK: Khối, đóng khung ngữ pháp

    private enum NhomKhoi { case le(KhoiSH); case khung(String, [KhoiSH]) }

    /// Bài ngữ pháp: mỗi mục (từ khối `h`) đóng KHUNG cùng công thức + ví dụ của nó; bài tập đứng ngoài
    /// khung — như `Blocks framed` của web.
    private func nhom(_ b: BaiSH) -> [NhomKhoi] {
        guard b.kind == "grammar" else { return b.blocks.map(NhomKhoi.le) }
        var out: [NhomKhoi] = []
        var dang: (String, [KhoiSH])?
        func dong() { if let d = dang { out.append(.khung(d.0, d.1)); dang = nil } }
        for k in b.blocks {
            if case .h(let t) = k { dong(); dang = (t, []) }
            else if k.laBaiTap { dong(); out.append(.le(k)) }
            else if dang != nil { dang!.1.append(k) }
            else { out.append(.le(k)) }
        }
        dong()
        return out
    }

    @ViewBuilder
    private func nhomView(_ n: NhomKhoi) -> some View {
        switch n {
        case .le(let k): KhoiSHView(khoi: k)
        case .khung(let t, let ks) where ks.isEmpty:
            TieuDeSH(text: t)
        case .khung(let t, let ks):
            VStack(alignment: .leading, spacing: 14) {
                ChuSH(text: t, co: 19, dam: true, mau: .nhan)
                    .padding(.bottom, 2)
                ForEach(Array(ks.enumerated()), id: \.offset) { _, k in KhoiSHView(khoi: k) }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(AppColors.primary.opacity(0.045)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(AppColors.primary.opacity(0.3), lineWidth: 1.2))
        }
    }

    // MARK: Cuối bài

    private var cuoi: some View {
        let xong = vm.daXong.contains(muc.id)
        let truoc = vm.ke(muc, buoc: -1)
        let sau = vm.ke(muc, buoc: 1)
        return VStack(spacing: 12) {
            if case .phu = muc {} else {
                Button {
                    vm.danhDau(muc.id, xong: !xong)
                } label: {
                    Label(xong ? "Đã học xong bài này" : "Đánh dấu đã học", systemImage: xong ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .foregroundColor(xong ? AppColors.success : .white)
                        .background(RoundedRectangle(cornerRadius: 14).fill(xong ? AppColors.success.opacity(0.14) : AppColors.success))
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 10) {
                if let truoc { nutChuyen(truoc, sau: false) }
                if let sau { nutChuyen(sau, sau: true) }
            }
        }
        .padding(.top, 16)
    }

    private func nutChuyen(_ m: MucDocSH, sau: Bool) -> some View {
        Button {
            if sau, !vm.daXong.contains(muc.id), muc != .gioiThieu { if case .phu = muc {} else { vm.danhDau(muc.id, xong: true) } }
            muc = m
        } label: {
            VStack(alignment: sau ? .trailing : .leading, spacing: 3) {
                Text(sau ? "Bài tiếp →" : "← Bài trước").font(.system(size: 12, weight: .bold)).foregroundColor(AppColors.primary)
                Text(vm.meta(m)?.title ?? "").font(.system(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    .lineLimit(2).multilineTextAlignment(sau ? .trailing : .leading)
            }
            .frame(maxWidth: .infinity, alignment: sau ? .trailing : .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.backgroundCard))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AppColors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Cài đặt đọc

    private var menuDoc: some View {
        Menu {
            Section("Hiển thị") {
                Toggle(vm.khoa?.ngonNgu == "zh" ? "Pinyin trên chữ" : "Furigana (chữ nhỏ trên chữ Hán)", isOn: $furi)
                Toggle(vm.khoa?.ngonNgu == "zh" ? "Dòng pinyin" : "Romaji", isOn: $roma)
            }
            Section("Cỡ chữ") {
                Picker("Cỡ chữ", selection: $tiLe) {
                    Text("Nhỏ").tag(0.9)
                    Text("Vừa").tag(1.0)
                    Text("Lớn").tag(1.15)
                    Text("Rất lớn").tag(1.3)
                }
            }
            Section("Tốc độ nghe") {
                Picker("Tốc độ nghe", selection: $tocDo) {
                    Text("Chậm 0,75×").tag(0.75)
                    Text("Thường 1×").tag(1.0)
                    Text("Nhanh 1,25×").tag(1.25)
                }
            }
        } label: {
            Image(systemName: "textformat.size")
        }
        .accessibilityLabel("Cài đặt đọc")
    }
}

// MARK: - Phụ

struct KhungLoiSH: View {
    let loi: String
    let thuLai: () -> Void
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark").font(.system(size: 34)).foregroundColor(AppColors.textTertiary)
            Text(loi).font(.system(size: 15)).foregroundColor(AppColors.textSecondary).multilineTextAlignment(.center)
            NutSH(ten: "Thử lại", bieuTuong: "arrow.clockwise", hanhDong: thuLai)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
    }
}

struct VideoMoSH: Identifiable {
    let id: String
    let tieuDe: String
    let url: URL?
    let youtube: String?
    let ghiChu: String?
}

struct TrinhPhatVideoSH: View {
    let video: VideoMoSH
    @State private var player: AVPlayer?
    @Environment(\.dismiss) private var dong
    var body: some View {
        NavigationStack {
            VStack {
                if let player { VideoPlayer(player: player).aspectRatio(16 / 9, contentMode: .fit) }
                ChuSH(text: video.tieuDe, co: 16, dam: true).padding()
                Spacer()
            }
            .background(AppColors.backgroundPrimary)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Đóng") { dong() } } }
        }
        .onAppear {
            GiongSachHoc.chung.dung()
            if let u = video.url { player = AVPlayer(url: u); player?.play() }
        }
        .onDisappear { player?.pause() }
    }
}
