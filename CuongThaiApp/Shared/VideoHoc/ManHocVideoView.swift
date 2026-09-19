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
    /// Trạng thái tim lúc mở màn, và đường báo ngược về màn duyệt để nó
    /// cập nhật ô tương ứng mà không phải gọi lại cả thư viện.
    var daThich: Bool = false
    var doiThich: ((Bool) -> Void)? = nil

    @State private var thich = false

    @StateObject private var dk = DieuKhienVideo()
    @State private var goi: GoiPhuDe?
    @State private var dangTai = true
    @State private var loi: String?

    @State private var tuDongCuon = true
    @State private var anPhuDe = false
    @State private var tocDo = 1.0
    @State private var cauHoiAI: String?
    @State private var tuTraCuu: String?
    @State private var tab: TabBang = .phuDe
    @State private var hienDich = true
    @State private var baoLuu: String?

    /// Ba việc học trên cùng một video. Trước 19/09/2026 hai việc sau nằm
    /// trong menu ⋯ ở thanh công cụ và mở ra thành MÀN RIÊNG — nghĩa là có
    /// cũng như không. Đưa ra thành tab ngay cạnh phụ đề.
    enum TabBang: String, CaseIterable, Identifiable {
        case phuDe, nhaiTheo, ngheChep
        var id: String { rawValue }
        var ten: String {
            switch self {
            case .phuDe:    return T("Phụ đề")
            case .nhaiTheo: return T("Nhại theo")
            case .ngheChep: return T("Nghe chép")
            }
        }
        var icon: String {
            switch self {
            case .phuDe:    return "captions.bubble"
            case .nhaiTheo: return "waveform.and.mic"
            case .ngheChep: return "pencil.and.scribble"
            }
        }
    }

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
                    bangBenPhai.frame(width: 420)
                }
            } else {
                VStack(spacing: 0) {
                    khungVideo.frame(height: 220)
                    bangBenPhai
                }
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(video.tieuDe)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await batTatThich() }
                } label: {
                    Image(systemName: thich ? "heart.fill" : "heart")
                        .foregroundStyle(thich ? AppColors.error : AppColors.textSecondary)
                }
                .accessibilityLabel(thich ? T("Bỏ yêu thích") : T("Yêu thích"))
            }
            // Nút đổi giọng đọc. `DocTu` vốn ĐÃ tôn trọng giọng người dùng
            // chọn, nhưng màn chọn giọng trước nay chỉ mở được từ My
            // Language và 4 màn IELTS — KHÔNG có ở đây, đúng nơi người ta
            // bấm "Đọc to" rồi thấy giọng khó nghe. Lần thứ ba cùng một
            // dạng lỗi: thiết lập chỉ có giá trị ở nơi nghe thấy vấn đề.
            ToolbarItem(placement: .primaryAction) { NutGiongIelts() }
            ToolbarItem(placement: .primaryAction) { menuCongCu }
        }
        .task { thich = daThich; await nap() }
        .overlay(alignment: .bottom) {
            if let b = baoLuu {
                Text(b).font(.bodySmall).foregroundStyle(AppColors.onPrimary)
                    .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm)
                    .background(Capsule().fill(AppColors.textPrimary.opacity(0.9)))
                    .padding(.bottom, Spacing.xl)
                    .transition(.opacity)
                    .task {
                        try? await Task.sleep(nanoseconds: 1_800_000_000)
                        withAnimation { baoLuu = nil }
                    }
            }
        }
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
            ZStack {
                TrinhPhatYouTube(videoId: video.videoId, dk: dk)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .background(Color.black)

                // Luyện nghe mà NHÌN được hình thì đọc được khẩu hình và chữ
                // trên slide — mất sạch ý nghĩa bài tập. Che, nhưng nói rõ
                // là đang che chứ không phải video hỏng.
                if tab == .ngheChep {
                    Rectangle().fill(.ultraThinMaterial)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .overlay(
                            VStack(spacing: Spacing.sm) {
                                Image(systemName: "ear.fill")
                                    .font(.largeTitle).foregroundStyle(AppColors.primary)
                                Text(T("Đang luyện nghe — hình đã che"))
                                    .font(.bodySmall).foregroundStyle(AppColors.textSecondary)
                            }
                        )
                }
            }
            if tab == .phuDe { thanhDieuKhien }
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
            Toggle(T("Hiện bản dịch tiếng Việt"), isOn: $hienDich)
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

    /// Bảng bên phải: hàng tab ở trên, nội dung ở dưới.
    private var bangBenPhai: some View {
        VStack(spacing: 0) {
            hangTab
            Divider()
            Group {
                switch tab {
                case .phuDe:
                    bangPhuDe
                case .nhaiTheo:
                    if let g = goi, !g.cues.isEmpty {
                        NhaiTheoView(video: video, cues: g.cues, dkNgoai: dk)
                    } else { choPhuDe }
                case .ngheChep:
                    if let g = goi, !g.cues.isEmpty {
                        NgheChepView(video: video, cues: g.cues, dkNgoai: dk)
                    } else { choPhuDe }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AppColors.backgroundPrimary)
    }

    private var hangTab: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(TabBang.allCases) { t in
                Button {
                    // Đổi tab là ĐỔI VIỆC: dừng phát và bỏ vòng lặp câu cũ,
                    // không thì tiếng của việc trước còn chạy dưới nền.
                    dk.thoiLap(); dk.dung()
                    withAnimation(.easeInOut(duration: 0.15)) { tab = t }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: t.icon).font(.caption)
                        Text(t.ten).font(.subheadline.weight(tab == t ? .semibold : .regular))
                    }
                    .foregroundStyle(tab == t ? AppColors.onPrimary : AppColors.textSecondary)
                    .padding(.horizontal, Spacing.sm + 2)
                    .padding(.vertical, Spacing.sm)
                    .background(Capsule().fill(tab == t ? AppColors.primary : .clear))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(AppColors.backgroundCard)
    }

    private var choPhuDe: some View {
        KhungTrongTien(bieuTuong: "captions.bubble",
                       tieuDe: T("Chưa có phụ đề"),
                       moTa: T("Hai bài luyện này cần phụ đề của video."))
    }

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
                        DongPhuDe(cau: c,
                                  dich: hienDich ? dongDich(i) : nil,
                                  dangNoi: i == chiSoDangNoi,
                                  tua: { dk.tua(c.t) },
                                  lap: { lapCau(i) },
                                  hoi: { cauHoiAI = c.en },
                                  traTu: { tuTraCuu = $0 },
                                  viec: { chu, v in lamViec(chu, v, tai: i) })
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

    /// Dòng tiếng Việt của câu thứ `i`. `nil` khi bài chưa được dịch, hoặc
    /// khi số dòng dịch không khớp số câu — thà không hiện còn hơn hiện
    /// bản dịch của CÂU KHÁC lệch một nhịp.
    private func dongDich(_ i: Int) -> String? {
        guard let d = goi?.dichVi, d.count == (goi?.cues.count ?? -1),
              i < d.count, !d[i].isEmpty else { return nil }
        return d[i]
    }

    /// Việc người dùng chọn sau khi bôi chữ bằng bút hoặc ngón tay.
    private func lamViec(_ chu: String, _ v: ViecTrenChu, tai i: Int) {
        switch v {
        case .traNghia, .hoiAI, .dichCau:
            cauHoiAI = chu
        case .docTo:
            DocTu.shared.doc(chu, code: "en")
        case .lapDoan:
            lapCau(i)
        case .luuSoTay:
            Task { await luuSoTay(chu) }
        }
    }

    private func batTatThich() async {
        let truoc = thich
        thich.toggle()                     // đổi NGAY, không chờ mạng
        doiThich?(thich)
        do {
            let sau = try await VideoHocAPI.doiYeuThich(video.lessonId)
            thich = sau
            doiThich?(sau)
        } catch {
            thich = truoc
            doiThich?(truoc)
            baoLuu = T("Chưa lưu được — thử lại")
        }
    }

    private func luuSoTay(_ chu: String) async {
        do {
            let _: MucSoTay = try await APIClient.shared.request(
                .taoMucSoTay(code: "en", thuMucId: nil,
                             loai: chu.split(separator: " ").count <= 3
                                 ? LoaiMuc.tuVung.rawValue : LoaiMuc.ghiChu.rawValue,
                             tieuDe: String(chu.prefix(200)),
                             than: chu,
                             cachDoc: nil,
                             nghia: video.tieuDe))
            baoLuu = T("Đã lưu vào sổ tay")
        } catch {
            baoLuu = T("Chưa lưu được — thử lại")
        }
    }

    private func lapCau(_ i: Int) {
        guard let cs = goi?.cues, i < cs.count else { return }
        let den = i + 1 < cs.count ? cs[i + 1].t : cs[i].t + 6
        dk.lapCau(tu: cs[i].t, den: den)
    }

    private func nap() async {
        dangTai = true
        defer { dangTai = false }
        do { goi = try await VideoHocAPI.phuDeCua(video) }
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

/// Một câu tiếng Anh + (tuỳ chọn) bản dịch tiếng Việt ngay dưới.
///
/// Chữ tiếng Anh dùng `ChuChonDuoc`: bôi bằng Apple Pencil hoặc ngón tay để
/// tra nghĩa / hỏi AI / lưu sổ tay / đọc to / lặp đoạn. `Text` của SwiftUI
/// không làm được — nó không cho chọn một PHẦN câu, mà tra nghĩa cả câu
/// thì chẳng để làm gì.
private struct DongPhuDe: View {
    let cau: CauPhuDe
    let dich: String?
    let dangNoi: Bool
    let tua: () -> Void
    let lap: () -> Void
    let hoi: () -> Void
    let traTu: (String) -> Void
    let viec: (String, ViecTrenChu) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            // Mốc thời gian là chỗ chạm AN TOÀN để tua: nó nằm ngoài vùng
            // chữ nên không bao giờ giẫm lên thao tác bôi chọn.
            Button(action: tua) {
                Text(cau.mocChu)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(dangNoi ? AppColors.primary : AppColors.textTertiary)
                    .frame(width: 38, alignment: .leading)
                    .padding(.top, 3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                ChuChonDuoc(
                    chu: cau.en,
                    coChu: .systemFont(ofSize: dangNoi ? 16 : 15,
                                       weight: dangNoi ? .semibold : .regular),
                    mauChu: UIColor(dangNoi ? AppColors.textPrimary : AppColors.textSecondary),
                    cham: tua,
                    lam: viec)

                if let d = dich, !d.isEmpty {
                    Text(d)
                        .font(.system(size: dangNoi ? 14 : 13))
                        .foregroundStyle(AppColors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(dangNoi ? AppColors.primary.opacity(0.10) : .clear)
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
