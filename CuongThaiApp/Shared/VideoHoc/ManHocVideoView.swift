#if os(iOS)
import SwiftUI

// ════════════════════════════════════════════════════════════════
// MÀN HỌC BẰNG VIDEO
//
// iPad: video BÊN TRÁI, phụ đề BÊN PHẢI — vừa xem vừa đọc, không phải cuộn
// qua lại. iPhone hẹp: video trên, phụ đề dưới.
//
// ⚠️ Máy ảo iOS KHÔNG phát được YouTube. Màn này chỉ nghiệm thu được trên
// máy thật — xem chú thích trong `TrinhPhatYouTube`.
// ════════════════════════════════════════════════════════════════

struct ManHocVideoView: View {
    let video: VideoHoc

    @StateObject private var dk = DieuKhienVideo()
    @State private var goi: GoiPhuDe?
    @State private var dangTai = true
    @State private var loi: String?

    @State private var tuDongCuon = true
    @State private var anPhuDe = false
    @State private var tocDo = 1.0
    @State private var cauHoiAI: String?
    @State private var tuTraCuu: String?

    @Environment(\.horizontalSizeClass) private var beNgang

    /// Chỉ số câu đang nói. `nil` khi chưa phát hoặc chưa có phụ đề.
    private var chiSoDangNoi: Int? {
        guard let cs = goi?.cues, !cs.isEmpty else { return nil }
        // Tìm câu CUỐI CÙNG có mốc ≤ giây hiện tại. Duyệt ngược vì người xem
        // thường ở gần cuối đoạn đã xem, và danh sách có thể 300+ câu.
        for i in stride(from: cs.count - 1, through: 0, by: -1) where cs[i].t <= dk.giay + 0.25 {
            return i
        }
        return 0
    }

    var body: some View {
        Group {
            if beNgang == .regular {
                HStack(spacing: 0) {
                    khungVideo.frame(maxWidth: .infinity)
                    Divider()
                    bangPhuDe.frame(width: 380)
                }
            } else {
                VStack(spacing: 0) {
                    khungVideo.frame(height: 220)
                    bangPhuDe
                }
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(video.tieuDe)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .primaryAction) { menuCongCu } }
        .task { await nap() }
        .sheet(item: Binding(get: { tuTraCuu.map(ChuoiID.init) },
                             set: { tuTraCuu = $0?.chu })) { c in
            HoiVeChuView(chu: c.chu, boiCanh: video.tieuDe, tuKho: nil)
        }
        .sheet(item: Binding(get: { cauHoiAI.map(ChuoiID.init) },
                            set: { cauHoiAI = $0?.chu })) { c in
            HoiVeChuView(chu: c.chu, boiCanh: video.tieuDe, tuKho: nil)
        }
    }

    // MARK: Video

    private var khungVideo: some View {
        VStack(spacing: 0) {
            TrinhPhatYouTube(videoId: video.videoId, dk: dk)
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(Color.black)
            thanhDieuKhien
        }
    }

    private var thanhDieuKhien: some View {
        HStack(spacing: Spacing.md) {
            // Lùi 5 giây — thao tác dùng nhiều nhất khi nghe không kịp.
            Button { dk.tua(max(0, dk.giay - 5)) } label: {
                Image(systemName: "gobackward.5")
            }
            Button { dk.dangPhat ? dk.dung() : dk.phat() } label: {
                Image(systemName: dk.dangPhat ? "pause.fill" : "play.fill")
                    .font(.title3)
            }
            Button { dk.tua(dk.giay + 5) } label: { Image(systemName: "goforward.5") }

            Spacer()

            if dk.lapTu != nil {
                Button { dk.thoiLap() } label: {
                    Label(T("Đang lặp"), systemImage: "repeat.1")
                        .font(.caption).foregroundStyle(AppColors.warning)
                }
            }
            Text(mocChu(dk.giay)).font(.caption).monospacedDigit()
                .foregroundStyle(AppColors.textTertiary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(AppColors.backgroundCard)
    }

    private var menuCongCu: some View {
        Menu {
            Toggle(T("Tự cuộn theo lời"), isOn: $tuDongCuon)
            Toggle(T("Ẩn phụ đề (luyện nghe)"), isOn: $anPhuDe)
            Divider()
            if let g = goi, !g.cues.isEmpty {
                NavigationLink {
                    NgheChepView(video: video, cues: g.cues)
                } label: { Label(T("Nghe — chép câu này"), systemImage: "pencil.and.scribble") }
            }
            Divider()
            Menu(T("Tốc độ")) {
                ForEach([0.5, 0.75, 1.0, 1.25, 1.5], id: \.self) { x in
                    Button {
                        tocDo = x; dk.tocDo(x)
                    } label: {
                        Label(String(format: "%.2gx", x),
                              systemImage: tocDo == x ? "checkmark" : "")
                    }
                }
            }
        } label: { Image(systemName: "slider.horizontal.3") }
    }

    // MARK: Bảng phụ đề

    private var bangPhuDe: some View {
        Group {
            if dangTai {
                VStack { ProgressView(); Text(T("Đang tải phụ đề…")).font(.caption) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let l = loi {
                KhungTrongTien(bieuTuong: "captions.bubble", tieuDe: T("Chưa có phụ đề"), moTa: l)
            } else if anPhuDe {
                // Luyện nghe: giấu chữ nhưng VẪN cho bật lại một chạm. Giấu
                // mà phải vào menu tìm thì không ai dùng chế độ này lần hai.
                VStack(spacing: Spacing.md) {
                    Image(systemName: "ear").font(.largeTitle).foregroundStyle(AppColors.textTertiary)
                    Text(T("Đang luyện nghe — phụ đề đã ẩn")).font(.bodySmall)
                    Button(T("Hiện lại")) { anPhuDe = false }.buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                danhSachCau
            }
        }
    }

    private var danhSachCau: some View {
        ScrollViewReader { cuon in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array((goi?.cues ?? []).enumerated()), id: \.offset) { i, c in
                        DongPhuDe(cau: c, dangNoi: i == chiSoDangNoi,
                                  tua: { dk.tua(c.t) },
                                  lap: { lapCau(i) },
                                  hoi: { cauHoiAI = c.en },
                                  traTu: { tuTraCuu = $0 })
                            .id(i)
                    }
                }
                .padding(.vertical, Spacing.sm)
            }
            .onChange(of: chiSoDangNoi) { _, moi in
                guard tuDongCuon, let m = moi else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    cuon.scrollTo(m, anchor: .center)
                }
            }
        }
    }

    // MARK: Việc

    private func lapCau(_ i: Int) {
        guard let cs = goi?.cues, i < cs.count else { return }
        let den = i + 1 < cs.count ? cs[i + 1].t : cs[i].t + 6
        dk.lapCau(tu: cs[i].t, den: den)
    }

    private func nap() async {
        dangTai = true
        defer { dangTai = false }
        do { goi = try await VideoHocAPI.phuDe(video.lessonId) }
        catch { loi = error.localizedDescription }
    }

    private func mocChu(_ g: Double) -> String {
        let s = Int(g)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// Bọc `String` thành `Identifiable` để dùng với `.sheet(item:)`.
private struct ChuoiID: Identifiable {
    let chu: String
    var id: String { chu }
    init(_ c: String) { chu = c }
}

// MARK: - Một dòng phụ đề

private struct DongPhuDe: View {
    let cau: CauPhuDe
    let dangNoi: Bool
    let tua: () -> Void
    let lap: () -> Void
    let hoi: () -> Void
    let traTu: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Text(cau.mocChu)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(dangNoi ? AppColors.primary : AppColors.textTertiary)
                    .frame(width: 38, alignment: .leading)
                Text(cau.en)
                    .font(.system(size: dangNoi ? 16 : 15,
                                  weight: dangNoi ? .semibold : .regular))
                    .foregroundStyle(dangNoi ? AppColors.textPrimary : AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(dangNoi ? AppColors.primary.opacity(0.10) : .clear)
        .contentShape(Rectangle())
        // Chạm câu = tua tới đó. Đây là thao tác chính của cả màn hình, nên
        // nó phải là cú chạm ĐƠN, không nấp trong menu.
        .onTapGesture(perform: tua)
        .contextMenu {
            Button { lap() } label: { Label(T("Lặp câu này"), systemImage: "repeat.1") }
            Button { hoi() } label: { Label(T("Hỏi AI về câu này"), systemImage: "sparkles") }
            Menu(T("Tra từ")) {
                // Chỉ những từ đáng tra: bỏ từ ngắn và dấu câu, không thì
                // danh sách dài 18 mục toàn "the", "of", "a".
                ForEach(tuDangTra, id: \.self) { t in
                    Button(t) { traTu(t) }
                }
            }
        }
    }

    private var tuDangTra: [String] {
        let sach = cau.en.split(whereSeparator: { !$0.isLetter && $0 != "'" }).map(String.init)
        var thay = Set<String>()
        return sach.filter { t in
            guard t.count >= 4, !thay.contains(t.lowercased()) else { return false }
            thay.insert(t.lowercased())
            return true
        }.prefix(12).map { $0 }
    }
}
#endif
