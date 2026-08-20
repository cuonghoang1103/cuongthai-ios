import SwiftUI

// ════════════════════════════════════════════════════════════════
// BẢNG CHỌN GIF
//
// Đi qua proxy GIPHY của backend (`GET /api/v1/gifs?q=`), KHÔNG gọi thẳng
// GIPHY: khoá phải ở lại phía máy chủ. Web từng gọi thẳng bằng
// `NEXT_PUBLIC_GIPHY_API_KEY` rồi rơi về khoá beta công khai đã bị thu hồi ⇒
// 403, và cái proxy này ra đời chính vì chuyện đó.
// ════════════════════════════════════════════════════════════════

struct GifItem: Codable, Identifiable, Hashable {
    let id: String
    let url: String
    let previewUrl: String
}

struct BangChonGif: View {
    /// Gọi lại với URL GIF đã chọn.
    let chon: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var tuKhoa = ""
    @State private var ds: [GifItem] = []
    @State private var dangTai = true
    @State private var loi: String?
    @State private var viecTim: Task<Void, Never>?

    private let cot = [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                oTim
                Divider()
                noiDung
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("GIF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
        .task { await tai("") }
        .onDisappear { viecTim?.cancel() }
    }

    private var oTim: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass").foregroundColor(AppColors.textTertiary)
            TextField("Tìm GIF…", text: $tuKhoa)
                .font(.system(size: 15))
                .foregroundColor(AppColors.textPrimary)
                .oKhongTuSua()
                .onChange(of: tuKhoa) { _, moi in
                    // Hoãn 400ms: gõ "chào" là 4 ký tự, không hoãn thì 4 lượt
                    // gọi mạng cho một lần tìm, và lượt về sau có thể tới TRƯỚC
                    // lượt về trước rồi ghi đè kết quả đúng bằng kết quả cũ.
                    viecTim?.cancel()
                    viecTim = Task {
                        try? await Task.sleep(nanoseconds: 400_000_000)
                        guard !Task.isCancelled else { return }
                        await tai(moi)
                    }
                }
            if !tuKhoa.isEmpty {
                Button { tuKhoa = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.md)
    }

    @ViewBuilder
    private var noiDung: some View {
        if dangTai && ds.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let loi {
            VStack(spacing: Spacing.sm) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 32))
                    .foregroundColor(AppColors.textTertiary)
                Text(loi)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Thử lại") { Task { await tai(tuKhoa) } }
                    .font(.buttonSmall)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if ds.isEmpty {
            Text("Không tìm thấy GIF nào.")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: cot, spacing: 6) {
                    ForEach(ds) { g in
                        Button {
                            Haptics.cham()
                            chon(g.url)
                            dismiss()
                        } label: {
                            AsyncImage(url: URL(string: g.previewUrl)) { pha in
                                if let img = try? pha.image {
                                    img.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    AppColors.backgroundSecondary
                                }
                            }
                            .frame(height: 110)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.md)
            }
        }
    }

    private func tai(_ q: String) async {
        dangTai = true
        loi = nil
        do {
            let kq: [GifItem] = try await APIClient.shared.request(.searchGifs(q: q))
            ds = kq
        } catch {
            // 503 = máy chủ chưa cắm GIPHY_API_KEY. Nói đúng nguyên nhân, đừng
            // để người dùng tưởng mất mạng.
            loi = error.localizedDescription
            ds = []
        }
        dangTai = false
    }
}
