#if os(iOS)
import SwiftUI
#if canImport(Kingfisher)
import Kingfisher
#endif

// ════════════════════════════════════════════════════════════════
// HỌC TIẾNG ANH BẰNG VIDEO — màn duyệt
//
// Bản trước là một `List` chữ trắng trên nền đen, gom 963 video của 48 môn
// vào một cột dọc, và hiện nguyên tiêu đề thô `EN|||VI`. Người dùng gọi
// đúng tên bệnh: "đen thui không có ảnh bìa và lộn vào 1 chỗ rất khó nhìn".
//
// Bản này: hàng chip chủ đề ở trên, bên dưới là các HÀNG NGANG có ẢNH BÌA
// (lấy thẳng CDN của YouTube theo `videoId` — không tốn R2, không cần
// backend lưu gì), mỗi hàng là một môn.
//
// Cả thư viện về trong MỘT lời gọi `/thu-vien` nên đổi chip, tìm kiếm và
// "xem tất cả" đều xảy ra tức thì, không phải chờ mạng lần nữa.
// ════════════════════════════════════════════════════════════════

struct VideoHocView: View {
    @State private var thuVien = ThuVienVideo.rong
    @State private var dangTai = true
    @State private var loi: String?
    @State private var tim = ""
    @State private var nhomLonChon: String?       // nil = Tất cả (tầng NGOÀI)
    @State private var nhomChon: String?          // nil = Tất cả (tầng TRONG, chỉ Academy)
    @State private var hienThemVideo = false
    /// Đổi NGAY khi bấm rồi mới gọi mạng — tim phải đỏ trong cùng nhịp chạm,
    /// chờ một vòng mạng thì người dùng bấm lại lần nữa và thành huỷ thích.
    @State private var daThich: Set<Int> = []

    @Environment(\.horizontalSizeClass) private var beNgang

    private var rong: Bool { beNgang == .regular }
    private var rongThe: CGFloat { rong ? 268 : 210 }

    private var tuKhoa: String { tim.trimmingCharacters(in: .whitespaces).lowercased() }

    /// Các hàng thuộc chip đang chọn — lọc theo CẢ HAI tầng.
    private var khoaHienThi: [KhoaVideo] {
        var ds = thuVien.khoa
        if let l = nhomLonChon { ds = ds.filter { $0.nhomLon == l } }
        if nhomLonChon == "swe", let n = nhomChon { ds = ds.filter { $0.nhom == n } }
        return ds
    }

    /// Hàng chip tầng TRONG chỉ hiện khi đang đứng trong Academy: 12 nhóm
    /// chuyên môn không có nghĩa gì với hoạt hình hay nhạc.
    private var hienChipCon: Bool { nhomLonChon == "swe" && !thuVien.nhom.isEmpty }

    /// Khi đang tìm: gom TẤT CẢ video khớp, kèm tên môn để biết nó ở đâu.
    private var ketQuaTim: [(khoa: KhoaVideo, video: VideoHoc)] {
        guard !tuKhoa.isEmpty else { return [] }
        var ra: [(KhoaVideo, VideoHoc)] = []
        for k in khoaHienThi {
            for v in k.video where v.tieuDe.lowercased().contains(tuKhoa)
                || (v.tieuDeVi ?? "").lowercased().contains(tuKhoa)
                || k.title.lowercased().contains(tuKhoa) {
                ra.append((k, v))
                if ra.count >= 200 { return ra }   // đủ nhìn; đừng vẽ 963 ô
            }
        }
        return ra
    }

    private var tongVideo: Int { thuVien.khoa.reduce(0) { $0 + $1.soVideo } }

    var body: some View {
        Group {
            if dangTai {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let l = loi, thuVien.khoa.isEmpty {
                KhungTrongTien(bieuTuong: "wifi.slash", tieuDe: T("Không tải được"), moTa: l)
            } else if thuVien.khoa.isEmpty {
                KhungTrongTien(bieuTuong: "play.rectangle",
                               tieuDe: T("Chưa có video nào có phụ đề"),
                               moTa: T("Phụ đề được nạp lúc deploy. Thử lại sau lần deploy tới."))
            } else {
                noiDung
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(T("Học bằng video"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $tim, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: T("Tìm video hoặc môn"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { hienThemVideo = true } label: {
                    Label(T("Thêm video"), systemImage: "plus.rectangle.on.rectangle")
                }
            }
        }
        .sheet(isPresented: $hienThemVideo) {
            ThemVideoView { await nap() }
        }
        .task { await nap() }
        .refreshable { await nap() }
    }

    // MARK: Thân

    private var noiDung: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                hangChip
                if tuKhoa.isEmpty {
                    if !videoDaThich.isEmpty && nhomLonChon == nil { hangYeuThich }
                    if !thuVien.cuaToi.isEmpty && nhomLonChon == nil { hangCuaToi }
                    ForEach(khoaHienThi) { k in hangKhoa(k) }
                    chanTrang
                } else {
                    luoiTimKiem
                }
            }
            .padding(.vertical, Spacing.md)
        }
    }

    /// HAI hàng chip. Tầng ngoài luôn hiện; tầng trong chỉ hiện trong
    /// Academy. Chỉ liệt kê nhóm THẬT SỰ có video — backend đã lọc.
    private var hangChip: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ChipChuDe(icon: "square.grid.2x2", ten: T("Tất cả"), so: tongVideo,
                              chon: nhomLonChon == nil) {
                        nhomLonChon = nil; nhomChon = nil
                    }
                    ForEach(thuVien.nhomLon) { n in
                        ChipChuDe(icon: n.icon, ten: n.ten, so: n.soVideo,
                                  chon: nhomLonChon == n.ma) {
                            // Đổi tầng ngoài là bỏ lọc tầng trong — giữ lại
                            // thì bấm sang "Âm nhạc" mà vẫn còn lọc "Backend"
                            // nên màn hình trống trơn, trông như hỏng.
                            nhomLonChon = (nhomLonChon == n.ma) ? nil : n.ma
                            nhomChon = nil
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
            }

            if hienChipCon {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ChipCon(ten: T("Tất cả môn"), chon: nhomChon == nil) { nhomChon = nil }
                        ForEach(thuVien.nhom) { n in
                            ChipCon(ten: n.ten, so: n.soVideo, chon: nhomChon == n.ma) {
                                nhomChon = (nhomChon == n.ma) ? nil : n.ma
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }
                .transition(.opacity)
            }
        }
    }

    /// Mọi video đã thích, theo đúng thứ tự máy chủ trả (mới nhất trước).
    private var videoDaThich: [VideoHoc] {
        var bang: [Int: VideoHoc] = [:]
        for k in thuVien.khoa { for v in k.video { bang[v.lessonId] = v } }
        for v in thuVien.cuaToi { bang[v.lessonId] = v }
        return thuVien.yeuThich.compactMap { bang[$0] }.filter { daThich.contains($0.lessonId) }
    }

    private var hangYeuThich: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(T("Yêu thích"), systemImage: "heart.fill")
                .font(.headline).foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, Spacing.md)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: Spacing.md) {
                    ForEach(videoDaThich) { v in
                        NavigationLink { manHoc(v) } label: {
                            TheVideo(video: v, rong: rongThe, daThich: true)
                        }
                        .buttonStyle(.plain)
                        .contextMenu { nutThich(v) }
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
        }
    }

    @ViewBuilder private func nutThich(_ v: VideoHoc) -> some View {
        Button {
            Task { await doiThich(v) }
        } label: {
            Label(daThich.contains(v.lessonId) ? T("Bỏ yêu thích") : T("Yêu thích"),
                  systemImage: daThich.contains(v.lessonId) ? "heart.slash" : "heart")
        }
    }

    private func manHoc(_ v: VideoHoc) -> some View {
        ManHocVideoView(video: v, daThich: daThich.contains(v.lessonId)) { moi in
            if moi { daThich.insert(v.lessonId) } else { daThich.remove(v.lessonId) }
        }
    }

    private func doiThich(_ v: VideoHoc) async {
        let truoc = daThich.contains(v.lessonId)
        if truoc { daThich.remove(v.lessonId) } else { daThich.insert(v.lessonId) }
        do {
            let sau = try await VideoHocAPI.doiYeuThich(v.lessonId)
            if sau { daThich.insert(v.lessonId) } else { daThich.remove(v.lessonId) }
        } catch {
            // Máy chủ từ chối → trả về đúng trạng thái CŨ, đừng để tim đỏ
            // trong khi máy chủ không ghi gì.
            if truoc { daThich.insert(v.lessonId) } else { daThich.remove(v.lessonId) }
        }
    }

    /// Video người dùng tự thêm — đứng ĐẦU, vì đó là thứ họ vừa bỏ công
    /// thêm vào và sẽ tìm ngay lần mở kế tiếp.
    private var hangCuaToi: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Label(T("Mới thêm"), systemImage: "clock.arrow.circlepath")
                    .font(.headline).foregroundStyle(AppColors.textPrimary)
                Text("\(thuVien.cuaToi.count)")
                    .font(.caption).foregroundStyle(AppColors.textTertiary)
                Spacer()
                Button { hienThemVideo = true } label: {
                    Label(T("Thêm"), systemImage: "plus").font(.caption)
                }
            }
            .padding(.horizontal, Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: Spacing.md) {
                    // ⚠️ CHỈ 14 ô. Thư viện có gần trăm video ngoài bài
                    // giảng, mà một dải cuộn ngang dài 97 ô thì không ai
                    // cuộn tới cuối — phần còn lại tìm bằng CHIP chủ đề.
                    ForEach(thuVien.cuaToi.prefix(14)) { v in
                        NavigationLink { manHoc(v) } label: {
                            TheVideo(video: v, rong: rongThe,
                                     daThich: daThich.contains(v.lessonId))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            nutThich(v)
                            Button(role: .destructive) {
                                Task { await xoa(v) }
                            } label: { Label(T("Xoá khỏi thư viện"), systemImage: "trash") }
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
        }
    }

    /// Một môn = một hàng ngang cuộn được.
    private func hangKhoa(_ k: KhoaVideo) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            NavigationLink { LuoiVideoView(khoa: k) } label: {
                HStack(spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(k.title).font(.headline)
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(1)
                        Text(String(format: T("%d video"), k.soVideo))
                            .font(.caption).foregroundStyle(AppColors.textTertiary)
                    }
                    Spacer(minLength: Spacing.sm)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppColors.textTertiary)
                }
                .padding(.horizontal, Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: Spacing.md) {
                    // Hàng ngang chỉ vẽ 14 ô đầu; phần còn lại nằm sau ô
                    // "Xem tất cả" — cuộn ngang 101 ô là thứ không ai cuộn hết.
                    ForEach(k.video.prefix(14)) { v in
                        NavigationLink { manHoc(v) } label: {
                            TheVideo(video: v, rong: rongThe,
                                     daThich: daThich.contains(v.lessonId))
                        }
                        .buttonStyle(.plain)
                        .contextMenu { nutThich(v) }
                    }
                    if k.soVideo > 14 {
                        NavigationLink { LuoiVideoView(khoa: k) } label: {
                            OXemTatCa(con: k.soVideo - 14, rong: rongThe)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
        }
    }

    private var luoiTimKiem: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(String(format: T("%d video khớp"), ketQuaTim.count))
                .font(.caption).foregroundStyle(AppColors.textTertiary)
                .padding(.horizontal, Spacing.md)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: rongThe), spacing: Spacing.md)],
                      alignment: .leading, spacing: Spacing.lg) {
                ForEach(ketQuaTim, id: \.video.lessonId) { cap in
                    NavigationLink { manHoc(cap.video) } label: {
                        TheVideo(video: cap.video, rong: rongThe, tenKhoa: cap.khoa.title,
                                 daThich: daThich.contains(cap.video.lessonId))
                    }
                    .buttonStyle(.plain)
                    .contextMenu { nutThich(cap.video) }
                }
            }
            .padding(.horizontal, Spacing.md)

            if ketQuaTim.isEmpty {
                KhungTrongTien(bieuTuong: "magnifyingglass",
                               tieuDe: T("Không tìm thấy video nào"),
                               moTa: T("Thử từ khoá tiếng Anh, hoặc bỏ bớt chip chủ đề."))
            }
        }
    }

    private var chanTrang: some View {
        Text(String(format: T("%d video tiếng Anh có phụ đề · %d môn"),
                    tongVideo, thuVien.khoa.count))
            .font(.caption).foregroundStyle(AppColors.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, Spacing.sm)
    }

    private func xoa(_ v: VideoHoc) async {
        guard v.laCuaToi else { return }
        try? await VideoHocAPI.xoaVideoCuaToi(v.idCuaToi)
        await nap()
    }

    private func nap() async {
        dangTai = thuVien.khoa.isEmpty
        defer { dangTai = false }
        do { thuVien = try await VideoHocAPI.thuVien(); daThich = Set(thuVien.yeuThich); loi = nil }
        catch { loi = error.localizedDescription }
    }
}

// MARK: - Chip chủ đề

private struct ChipChuDe: View {
    let icon: String
    let ten: String
    let so: Int
    let chon: Bool
    let cham: () -> Void

    var body: some View {
        Button(action: cham) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption)
                Text(ten).font(.subheadline.weight(chon ? .semibold : .regular))
                Text("\(so)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(chon ? AppColors.onPrimary.opacity(0.75)
                                          : AppColors.textTertiary)
            }
            .foregroundStyle(chon ? AppColors.onPrimary : AppColors.textSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule().fill(chon ? AppColors.primary : AppColors.backgroundCard)
            )
            .overlay(
                Capsule().stroke(chon ? .clear : AppColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Chip tầng TRONG — nhỏ hơn, viền nhạt hơn để mắt phân biệt ngay hai tầng.
private struct ChipCon: View {
    let ten: String
    var so: Int? = nil
    let chon: Bool
    let cham: () -> Void

    var body: some View {
        Button(action: cham) {
            HStack(spacing: 4) {
                Text(ten).font(.caption.weight(chon ? .semibold : .regular))
                if let s = so {
                    Text("\(s)").font(.caption2)
                        .foregroundStyle(chon ? AppColors.primary.opacity(0.7)
                                              : AppColors.textTertiary)
                }
            }
            .foregroundStyle(chon ? AppColors.primary : AppColors.textSecondary)
            .padding(.horizontal, Spacing.sm + 2)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(chon ? AppColors.primary.opacity(0.14) : .clear)
            )
            .overlay(
                Capsule().stroke(chon ? AppColors.primary.opacity(0.45)
                                      : AppColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ô video có ảnh bìa

struct TheVideo: View {
    let video: VideoHoc
    let rong: CGFloat
    var tenKhoa: String? = nil
    var daThich: Bool = false

    private var cao: CGFloat { rong * 9 / 16 }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ZStack(alignment: .bottomTrailing) {
                anhBia
                    .frame(width: rong, height: cao)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))

                if daThich {
                    Image(systemName: "heart.fill")
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(Circle().fill(Color.black.opacity(0.55)))
                        .padding(6)
                        .frame(width: rong, height: cao, alignment: .topTrailing)
                }

                if let t = video.thoiLuong {
                    Text(t)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.black.opacity(0.78))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(6)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(video.tieuDe)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                // Tiêu đề tiếng Việt: người học đang học TIẾNG ANH, nhưng
                // chọn bài thì vẫn chọn bằng tiếng mẹ đẻ cho nhanh.
                if let vi = video.tieuDeVi, !vi.isEmpty, vi != video.tieuDe {
                    Text(vi).font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    if let k = tenKhoa {
                        Text(k).lineLimit(1)
                        Text("·")
                    }
                    Text(String(format: T("%d câu"), video.soCau))
                }
                .font(.caption2)
                .foregroundStyle(AppColors.textTertiary)
            }
            .frame(width: rong, alignment: .leading)
        }
    }

    @ViewBuilder private var anhBia: some View {
        #if canImport(Kingfisher)
        if let u = video.anhBia {
            KFImage(u)
                .placeholder { khungCho }
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else { khungCho }
        #else
        if let u = video.anhBia {
            AsyncImage(url: u) { i in i.resizable().aspectRatio(contentMode: .fill) }
                placeholder: { khungCho }
        } else { khungCho }
        #endif
    }

    private var khungCho: some View {
        ZStack {
            LinearGradient(colors: [AppColors.primary.opacity(0.25),
                                    AppColors.primary.opacity(0.08)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "play.rectangle.fill")
                .font(.title2).foregroundStyle(AppColors.primary.opacity(0.7))
        }
    }
}

private struct OXemTatCa: View {
    let con: Int
    let rong: CGFloat

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(AppColors.backgroundCard)
                    .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(AppColors.border, lineWidth: 1))
                VStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.title3).foregroundStyle(AppColors.primary)
                    Text(String(format: T("Xem tất cả\n+%d video"), con))
                        .font(.caption).multilineTextAlignment(.center)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .frame(width: rong, height: rong * 9 / 16)
            Spacer(minLength: 0)
        }
        .frame(width: rong)
    }
}

// MARK: - Toàn bộ video của một môn

struct LuoiVideoView: View {
    let khoa: KhoaVideo

    @State private var tim = ""
    @Environment(\.horizontalSizeClass) private var beNgang

    private var rongThe: CGFloat { beNgang == .regular ? 268 : 210 }

    private var loc: [VideoHoc] {
        let t = tim.trimmingCharacters(in: .whitespaces).lowercased()
        guard !t.isEmpty else { return khoa.video }
        return khoa.video.filter {
            $0.tieuDe.lowercased().contains(t) || ($0.tieuDeVi ?? "").lowercased().contains(t)
        }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: rongThe), spacing: Spacing.md)],
                      alignment: .leading, spacing: Spacing.lg) {
                ForEach(loc) { v in
                    NavigationLink { ManHocVideoView(video: v) } label: {
                        TheVideo(video: v, rong: rongThe)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(khoa.title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $tim, prompt: T("Tìm trong môn này"))
    }
}
#endif
