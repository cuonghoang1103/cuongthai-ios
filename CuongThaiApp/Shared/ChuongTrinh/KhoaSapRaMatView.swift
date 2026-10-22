import SwiftUI

// ════════════════════════════════════════════════════════════════
// KHOÁ "SẮP RA MẮT" — trang giới thiệu CHỈ ĐỌC (22/10/2026)
//
// Backend (`services/khoaSapRaMat.ts` + `khungSapRaMat` trong course.routes.ts):
// khoá status COMING_SOON là KHUNG — ảnh bìa, tên, mô tả, mục lục chương/bài,
// CHƯA có nội dung. `GET /courses/:slug` trả bản giới thiệu: `comingSoon: true`,
// mọi cờ truy cập tắt, `sections[].lessons[]` chỉ có tên, cộng `soChuongDuKien`
// / `soBaiDuKien`. Ghi danh/mở bài/mua ⇒ 409 COURSE_COMING_SOON.
//
// ⇒ Màn này KHÔNG có nút ghi danh hay "Bắt đầu học" (App Store 2.1: không đặt nút
// bấm không làm gì). Phần đầu hiện ngay từ dữ liệu của danh sách; mục lục tải sau.
// Khoá đã được mở (status khác COMING_SOON) ⇒ đưa một lối sang màn khoá học thật.
// ════════════════════════════════════════════════════════════════

struct KhungKhoaSapRaMat: Codable {
    struct Bai: Codable, Identifiable, Hashable {
        var id: Int
        var title: String?
    }
    struct Chuong: Codable, Identifiable, Hashable {
        var id: Int
        var title: String?
        var description: String?
        var lessons: MangKhoan<Bai>?
        var lessonCount: SoLinhHoat?

        var dsBai: [Bai] { lessons?.phanTu ?? [] }
        var soBai: Int { lessonCount?.int ?? dsBai.count }

        static func == (a: Chuong, b: Chuong) -> Bool { a.id == b.id }
        func hash(into h: inout Hasher) { h.combine(id) }
    }

    var title: String?
    var shortDescription: String?
    var description: String?
    var thumbnailUrl: String?
    var level: String?
    var categoryName: String?
    var status: String?
    var comingSoon: Bool?
    var whatYouLearn: String?
    var requirements: String?
    var soChuongDuKien: SoLinhHoat?
    var soBaiDuKien: SoLinhHoat?
    var sections: MangKhoan<Chuong>?

    enum CodingKeys: String, CodingKey {
        case title, shortDescription, description, thumbnailUrl, level, categoryName, status, comingSoon
        case whatYouLearn, requirements, soChuongDuKien, soBaiDuKien, sections
    }

    /// Từng trường một `try?` — một trường sai kiểu không làm mất cả trang giới thiệu.
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        func chu(_ k: CodingKeys) -> String? { (try? c.decodeIfPresent(String.self, forKey: k)) ?? nil }
        title = chu(.title); shortDescription = chu(.shortDescription); description = chu(.description)
        thumbnailUrl = chu(.thumbnailUrl); level = chu(.level); categoryName = chu(.categoryName)
        status = chu(.status); whatYouLearn = chu(.whatYouLearn); requirements = chu(.requirements)
        comingSoon = (try? c.decodeIfPresent(Bool.self, forKey: .comingSoon)) ?? nil
        soChuongDuKien = (try? c.decodeIfPresent(SoLinhHoat.self, forKey: .soChuongDuKien)) ?? nil
        soBaiDuKien = (try? c.decodeIfPresent(SoLinhHoat.self, forKey: .soBaiDuKien)) ?? nil
        sections = (try? c.decodeIfPresent(MangKhoan<Chuong>.self, forKey: .sections)) ?? nil
    }

    var dsChuong: [Chuong] { sections?.phanTu ?? [] }
    /// Máy chủ nói khoá ĐÃ mở (đổi sang PUBLISHED) ⇒ màn này chỉ còn là lối chuyển sang trang khoá thật.
    var daMo: Bool { comingSoon != true && (status ?? "").uppercased() == "PUBLISHED" }
}

struct KhoaSapRaMatView: View {
    let mon: MonChuongTrinh
    /// DEBUG/kiểm thử: cắm nguồn giả. `nil` ⇒ gọi `GET /courses/:slug`.
    var taiKhung: ((String) async throws -> KhungKhoaSapRaMat)? = nil

    @State private var khung: KhungKhoaSapRaMat?
    @State private var dangTai = true
    @State private var loi = false
    @State private var moChuong: Set<Int> = []

    @ObservedObject private var nn = QuanLyNgonNguApp.shared
    @Environment(\.horizontalSizeClass) private var lopNgang
    @ScaledMetric(relativeTo: .largeTitle) private var coTieuDe: CGFloat = 30

    private var anh: Bool { nn.ngonNgu == .anh }
    private var rong: Bool { lopNgang == .regular }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AnhBiaCT(url: khung?.thumbnailUrl ?? mon.thumbnailUrl,
                         chuDuPhong: AnhBiaCT.chuCho(mon, ten: tieuDe), coChu: rong ? 30 : 22)
                    .frame(maxWidth: .infinity)

                dauTrang.padding(.top, 20)

                if khung?.daMo == true {
                    NavigationLink { CourseDetailView(slug: mon.slug) } label: {
                        HStack {
                            Text(T("Khoá đã mở — xem khoá học")).font(.subheadline.weight(.semibold))
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .foregroundColor(MauCT.nhan)
                        .padding(14)
                        .overlay(Rectangle().stroke(MauCT.nhan, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 20)
                } else {
                    loiNhan.padding(.top, 20)
                }

                if let y = khung?.whatYouLearn?.tachSongNgu(anh ? .anh : .viet), !y.isEmpty {
                    muc(T("Bạn sẽ học được gì"), y).padding(.top, 28)
                }

                mucLuc.padding(.top, 32)
            }
            .padding(.horizontal, rong ? 40 : Spacing.md)
            .padding(.top, Spacing.sm)
            .padding(.bottom, 56)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(MauCT.giay.ignoresSafeArea())
        .navigationTitle(T("Sắp ra mắt"))
        .navigationBarTitleDisplayMode(.inline)
        .task { if khung == nil { await tai() } }
        .refreshable { await tai() }
    }

    private var tieuDe: String {
        let t = (khung?.title ?? "").tachSongNgu(anh ? .anh : .viet)
        return t.isEmpty ? mon.ten(anh) : t
    }

    private var moTa: String? {
        for s in [khung?.description, khung?.shortDescription, mon.shortDescription] {
            let t = (s ?? "").tachSongNgu(anh ? .anh : .viet).trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        return nil
    }

    private var soChuong: Int {
        if let n = khung?.soChuongDuKien?.int { return n }
        if let k = khung, !k.dsChuong.isEmpty { return k.dsChuong.count }
        return mon.soChuongDuKien ?? 0
    }

    private var soBai: Int {
        if let n = khung?.soBaiDuKien?.int { return n }
        if let k = khung, !k.dsChuong.isEmpty { return k.dsChuong.reduce(0) { $0 + $1.soBai } }
        return mon.soBaiDuKien ?? 0
    }

    // MARK: Đầu trang

    private var dauTrang: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                NhanSapRaMat()
                Text([mon.categoryName ?? khung?.categoryName, CapDoCT.nhan(khung?.level ?? mon.level)]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundColor(MauCT.muc3)
            }
            Text(tieuDe)
                .font(.system(size: coTieuDe, weight: .regular, design: .serif))
                .foregroundColor(MauCT.muc)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let moTa {
                Text(moTa)
                    .font(.body)
                    .foregroundColor(MauCT.muc2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if soBai > 0 {
                Text(ChuCT.khung(soChuong, soBai, anh))
                    .font(.footnote.monospacedDigit())
                    .foregroundColor(MauCT.muc3)
                    .padding(.top, 2)
            }
        }
    }

    private var loiNhan: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle().fill(MauCT.nhan).frame(width: 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(T("Chưa mở đăng ký"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(MauCT.muc)
                Text(T("Khung chương trình đã sẵn — mục lục từng phần, từng bài. Nội dung mở dần khi soạn xong."))
                    .font(.footnote)
                    .foregroundColor(MauCT.muc2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    private func muc(_ ten: String, _ noiDung: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(ten).font(ChuCTFont.serif(.title3)).foregroundColor(MauCT.muc).accessibilityAddTraits(.isHeader)
            Text(noiDung).font(.subheadline).foregroundColor(MauCT.muc2).fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Mục lục

    @ViewBuilder
    private var mucLuc: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(MauCT.keDam).frame(height: 2)
            HStack(alignment: .firstTextBaseline) {
                Text(T("Mục lục dự kiến"))
                    .font(ChuCTFont.serif(.title2))
                    .foregroundColor(MauCT.muc)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if let k = khung, !k.dsChuong.isEmpty {
                    Button(moChuong.count == k.dsChuong.count ? T("Thu gọn") : T("Mở tất cả")) {
                        Haptics.cham()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            moChuong = moChuong.count == k.dsChuong.count ? [] : Set(k.dsChuong.map(\.id))
                        }
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(MauCT.nhan)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 8)

            if let k = khung, !k.dsChuong.isEmpty {
                ForEach(Array(k.dsChuong.enumerated()), id: \.element.id) { i, ch in
                    hangChuong(ch, i)
                    KeMong()
                }
            } else if dangTai {
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonBox(height: 16, radius: 2).padding(.vertical, 14)
                    KeMong()
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(loi ? T("Chưa tải được mục lục.") : T("Mục lục đang được soạn."))
                        .font(.footnote)
                        .foregroundColor(MauCT.muc2)
                    if loi {
                        Button(T("Thử lại")) { Task { await tai() } }
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(MauCT.nhan)
                    }
                }
                .padding(.vertical, 16)
            }
        }
    }

    private func hangChuong(_ ch: KhungKhoaSapRaMat.Chuong, _ i: Int) -> some View {
        let mo = moChuong.contains(ch.id)
        let ten = (ch.title ?? "").tachSongNgu(anh ? .anh : .viet)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                Haptics.cham()
                withAnimation(.easeInOut(duration: 0.2)) {
                    if mo { moChuong.remove(ch.id) } else { moChuong.insert(ch.id) }
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(String(format: "%02d", i + 1))
                        .font(ChuCTFont.serif(.callout))
                        .monospacedDigit()
                        .foregroundColor(MauCT.nhan)
                        .frame(width: 26, alignment: .leading)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(ten.isEmpty ? String(format: T("Phần %d"), i + 1) : ten)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(MauCT.muc)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(ChuCT.bai(ch.soBai, anh))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(MauCT.muc3)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(MauCT.muc3)
                        .rotationEffect(.degrees(mo ? 180 : 0))
                }
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(mo ? T("Đang mở") : T("Đang đóng"))

            if mo {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(ch.dsBai.enumerated()), id: \.element.id) { j, b in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(j + 1)")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(MauCT.muc3)
                                .frame(width: 22, alignment: .trailing)
                            Text((b.title ?? "").tachSongNgu(anh ? .anh : .viet))
                                .font(.footnote)
                                .foregroundColor(MauCT.muc2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 6)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.leading, 28)
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: Tải

    private func tai() async {
        dangTai = true
        defer { dangTai = false }
        do {
            let k: KhungKhoaSapRaMat
            #if DEBUG
            let taiKhung = taiKhung ?? ThuChuongTrinh.khungTuMoiTruong()
            #endif
            if let taiKhung {
                k = try await taiKhung(mon.slug)
            } else {
                let slug = mon.slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? mon.slug
                k = try await APIClient.shared.request(
                    .tuyChinh(duong: "/api/v1/courses/\(slug)", phuongThuc: "GET", than: nil))
            }
            khung = k
            loi = false
            if moChuong.isEmpty, let dau = k.dsChuong.first { moChuong = [dau.id] }
        } catch {
            if ChuongTrinhDaoTaoVM.laHuy(error) { return }
            loi = khung == nil
        }
    }
}
