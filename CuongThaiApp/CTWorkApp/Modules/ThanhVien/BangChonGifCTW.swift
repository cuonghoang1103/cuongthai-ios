import SwiftUI
import Kingfisher

// MARK: - Bảng chọn GIF + nhãn dán (22/10/2026 — bản 1.1)
//
// GIF: proxy GIPHY của backend (`GET /api/v1/gifs?q=&offset=` — khoá ở máy chủ, không bao giờ trong app). Thịnh hành khi ô
// tìm trống, gõ ⇒ chờ 350 ms rồi tìm (lượt về muộn của chữ cũ bị bỏ). Cuộn tới cuối ⇒ trang sau (`TrangGifCTW`; máy chủ
// chưa có `offset` trả lại trang đầu ⇒ lọc trùng ⇒ dừng). Gửi như web MessageInput: `media: {url, kind: "gif"}`.
// Nhãn dán: `GET /api/v1/stickers/packs` + `/packs/:id/stickers` (kho của site) ⇒ `media: {url, kind: "sticker"}`.
// Ghi công GIPHY ("Powered by GIPHY") theo điều khoản của GIPHY. Lọc nội dung: máy chủ gọi GIPHY với `rating=pg-13`.

@MainActor
final class GifVM: ObservableObject {
    @Published var tuKhoa = ""
    @Published private(set) var trang = TrangGifCTW()
    @Published private(set) var dangTai = false
    @Published var loi: String?
    private var luot = 0
    private var cho: Task<Void, Never>?

    func doiTuKhoa() {
        cho?.cancel()
        cho = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await self?.taiLai()
        }
    }

    func taiLai() async {
        luot += 1
        trang = TrangGifCTW()
        await taiThem(luotGoi: luot)
    }

    func taiThem() async { await taiThem(luotGoi: luot) }

    private func taiThem(luotGoi: Int) async {
        guard !dangTai, !trang.het else { return }
        dangTai = true
        defer { dangTai = false }
        do {
            let ds: [CTWGif] = try await APIClient.shared.request(TinNhanAPI.gif(q: tuKhoa, offset: trang.offset))
            guard luotGoi == luot else { return }   // chữ đã đổi trong lúc chờ
            trang.ghep(ds)
            loi = nil
        } catch {
            guard luotGoi == luot else { return }
            loi = CTW.loi(error)
            trang.het = true
        }
    }
}

struct BangChonGifCTW: View {
    let chon: (String, String) -> Void   // (url, kind)
    @StateObject private var vm = GifVM()
    @Environment(\.dismiss) private var dong
    @State private var phan: Int

    /// `batDau`: 0 = GIF, 1 = nhãn dán.
    init(batDau: Int = 0, chon: @escaping (String, String) -> Void) {
        self.chon = chon
        _phan = State(initialValue: batDau)
    }
    @State private var goi: [CTWGoiNhanDan] = []
    @State private var goiChon: Int?
    @State private var nhanDan: [CTWNhanDan] = []
    @State private var daTaiNhanDan = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Type", selection: $phan) {
                    Text("GIFs").tag(0)
                    Text("Stickers").tag(1)
                }
                .pickerStyle(.segmented).padding(.horizontal, 16).padding(.vertical, 8)
                .accessibilityIdentifier("gif.tabs")
                if phan == 0 { gif } else { stickers }
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle(phan == 0 ? "GIFs" : "Stickers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dong() } } }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task { await vm.taiLai() }
    }

    // MARK: GIF

    private var gif: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(AppColors.textTertiary)
                TextField("Search GIPHY", text: $vm.tuKhoa)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .submitLabel(.search)
                    .onChange(of: vm.tuKhoa) { _, _ in vm.doiTuKhoa() }
                    .accessibilityIdentifier("gif.search")
                if !vm.tuKhoa.isEmpty {
                    Button { vm.tuKhoa = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textTertiary) }
                        .accessibilityLabel("Clear")
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.backgroundSecondary))
            .padding(.horizontal, 16).padding(.bottom, 8)
            ScrollView {
                if vm.trang.ds.isEmpty && !vm.dangTai {
                    if let l = vm.loi {
                        CTWOLoi(loi: l) { Task { await vm.taiLai() } }.padding(.top, 30)
                    } else {
                        CTWOTrong(bieuTuong: "photo.on.rectangle.angled", tieuDe: String(localized: "No GIFs found"),
                                  moTa: String(localized: "Try another word.")).padding(.top, 30)
                    }
                }
                HStack(alignment: .top, spacing: 6) {
                    ForEach(0..<2, id: \.self) { c in
                        LazyVStack(spacing: 6) {
                            ForEach(Array(vm.trang.ds.enumerated()).filter { $0.offset % 2 == c }, id: \.element.id) { i, g in
                                Button { chon(g.url, "gif"); CTWRung.chon(); dong() } label: {
                                    KFAnimatedImage(DuongDanAnh.url(g.previewUrl) ?? URL(string: g.previewUrl))
                                        .placeholder { RoundedRectangle(cornerRadius: 10).fill(AppColors.backgroundSecondary) }
                                        .scaledToFill()
                                        .frame(height: i % 3 == 0 ? 150 : 118)
                                        .frame(maxWidth: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("GIF \(i + 1)")
                                .accessibilityIdentifier("gif.item.\(i)")
                                .onAppear { if i >= vm.trang.ds.count - 6 { Task { await vm.taiThem() } } }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                if vm.dangTai { ProgressView().padding(16) }
                Text("Powered by GIPHY").font(.ctw(size: 11, weight: .semibold)).foregroundColor(AppColors.textTertiary).padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }

    // MARK: Nhãn dán

    private var stickers: some View {
        VStack(spacing: 0) {
            if goi.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(goi) { g in
                            Button { goiChon = g.id } label: {
                                HStack(spacing: 6) {
                                    if let u = DuongDanAnh.url(g.coverUrl) { KFImage(u).resizable().scaledToFit().frame(width: 22, height: 22) }
                                    Text(verbatim: g.name ?? "").font(.ctw(size: 13, weight: .medium)).fixedSize()
                                }
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Capsule().fill(goiChon == g.id ? AppColors.primary.opacity(0.15) : AppColors.backgroundSecondary))
                                .foregroundColor(goiChon == g.id ? AppColors.primary : AppColors.textPrimary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 8)
                }
            }
            ScrollView {
                if daTaiNhanDan && goi.isEmpty {
                    CTWOTrong(bieuTuong: "face.smiling", tieuDe: String(localized: "No stickers yet"),
                              moTa: String(localized: "Sticker packs added on cuongthai.com appear here.")).padding(.top, 30)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(nhanDan) { s in
                        Button { chon(s.url, "sticker"); CTWRung.chon(); dong() } label: {
                            KFAnimatedImage(DuongDanAnh.url(s.url) ?? URL(string: s.url)).placeholder { ProgressView() }
                                .scaledToFit().frame(height: 76)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: s.label ?? String(localized: "Sticker")))
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .task {
            guard !daTaiNhanDan else { return }
            goi = (try? await APIClient.shared.request(TinNhanAPI.goiNhanDan())) ?? []
            goiChon = goi.first?.id
            daTaiNhanDan = true
        }
        .task(id: goiChon) {
            guard let g = goiChon else { nhanDan = []; return }
            nhanDan = (try? await APIClient.shared.request(TinNhanAPI.nhanDan(goi: g))) ?? []
        }
    }
}
