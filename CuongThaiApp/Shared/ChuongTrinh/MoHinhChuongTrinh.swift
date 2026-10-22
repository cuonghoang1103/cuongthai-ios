import Foundation

// ════════════════════════════════════════════════════════════════
// CHƯƠNG TRÌNH ĐÀO TẠO (/courses của web) — 4 năm → 15 kỳ → khoá (22/10/2026)
//
// Nguồn: `GET /api/v1/courses/chuong-trinh` (backend nhánh courses-chuong-trinh,
// `src/routes/course.routes.ts › dongGoiMonChuongTrinh / xepChuongTrinh /
// nhomSapRaMat`, khung năm/kỳ ở `src/config/chuongTrinhKhoaHoc.ts`):
//
//   { nam: [{ so, ten, tenEn, moTa, moTaEn, ky: [{ so, nam, ten, tenEn, moTa, moTaEn, mon: [Mon] }] }],
//     chuaXep: [Mon],                      // "Khoá mới" — KHÔNG BAO GIỜ giấu
//     sapRaMat: [{ ma, ten, tenEn, mon: [Mon + soChuongDuKien, soBaiDuKien] }],
//     tong: { khoa, bai, gio, sapRaMat } }
//
// Giải mã KHOAN DUNG ở mọi tầng (CLAUDE.md C3/C4): mọi trường optional trừ
// `id` + `slug`, số nhận cả dạng chuỗi (`SoLinhHoat` — Decimal của Prisma),
// mảng bỏ phần tử hỏng (`MangKhoan`, cả hai dùng chung với Phòng thi), trường
// lạ bị bỏ qua. Một khoá hỏng không được làm trống cả màn.
//
// ⚠️ Endpoint CHƯA lên prod lúc viết (prod trả 404 — rơi vào `/:slug`). Khi đó
// VM lùi về `/courses?gon=1` và dựng `ChuongTrinhDaoTao.tuDanhSach` (nhóm theo
// chuyên ngành) — backend deploy xong là màn tự sáng đủ 15 kỳ, không cần bản app mới.
// ════════════════════════════════════════════════════════════════

// MARK: - Một khoá

struct MonChuongTrinh: Codable, Identifiable, Hashable {
    var id: Int
    var slug: String
    /// Song ngữ "EN|||VI" (một số khoá chỉ một thứ tiếng) — hiện bằng `ten(_:)`.
    var title: String?
    var courseCode: String?
    var shortDescription: String?
    var thumbnailUrl: String?
    var price: Double?
    var isFree: Bool?
    var level: String?
    var totalLessons: Int?
    var totalDurationSeconds: Int?
    var totalStudents: Int?
    var categoryName: String?
    var categorySlug: String?
    var loTrinhKy: Int?
    var loTrinhThuTu: Int?
    var isEnrolled: Bool?
    /// % bài đã xong — chỉ có khi đăng nhập VÀ đã ghi danh; không thì `nil`.
    var progress: Int?
    /// Khoá "Sắp ra mắt" (status COMING_SOON): chỉ có khung, chưa ghi danh được.
    var sapRaMat: Bool?
    var soChuongDuKien: Int?
    var soBaiDuKien: Int?

    enum CodingKeys: String, CodingKey {
        case id, slug, title, courseCode, shortDescription, thumbnailUrl, price, isFree, level
        case totalLessons, totalDurationSeconds, totalStudents, categoryName, categorySlug
        case loTrinhKy, loTrinhThuTu, isEnrolled, progress, sapRaMat, soChuongDuKien, soBaiDuKien
    }

    init(id: Int, slug: String, title: String? = nil, courseCode: String? = nil,
         shortDescription: String? = nil, thumbnailUrl: String? = nil, price: Double? = nil,
         isFree: Bool? = true, level: String? = nil, totalLessons: Int? = nil,
         totalDurationSeconds: Int? = nil, totalStudents: Int? = nil, categoryName: String? = nil,
         categorySlug: String? = nil, loTrinhKy: Int? = nil, loTrinhThuTu: Int? = nil,
         isEnrolled: Bool? = nil, progress: Int? = nil, sapRaMat: Bool? = nil,
         soChuongDuKien: Int? = nil, soBaiDuKien: Int? = nil) {
        self.id = id; self.slug = slug; self.title = title; self.courseCode = courseCode
        self.shortDescription = shortDescription; self.thumbnailUrl = thumbnailUrl; self.price = price
        self.isFree = isFree; self.level = level; self.totalLessons = totalLessons
        self.totalDurationSeconds = totalDurationSeconds; self.totalStudents = totalStudents
        self.categoryName = categoryName; self.categorySlug = categorySlug; self.loTrinhKy = loTrinhKy
        self.loTrinhThuTu = loTrinhThuTu; self.isEnrolled = isEnrolled; self.progress = progress
        self.sapRaMat = sapRaMat; self.soChuongDuKien = soChuongDuKien; self.soBaiDuKien = soBaiDuKien
    }

    /// Chỉ `id` + `slug` là bắt buộc — thiếu một trong hai thì không mở được
    /// khoá, nên phần tử đó bị `MangKhoan` bỏ qua. Mọi trường khác hỏng ⇒ `nil`.
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        guard let id = c.so(.id).map({ Int($0) }) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "thiếu id")
        }
        guard let slug = c.chu(.slug), !slug.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .slug, in: c, debugDescription: "thiếu slug")
        }
        self.id = id
        self.slug = slug
        title = c.chu(.title)
        courseCode = c.chu(.courseCode)
        shortDescription = c.chu(.shortDescription)
        thumbnailUrl = c.chu(.thumbnailUrl)
        price = c.so(.price)
        isFree = c.co(.isFree)
        level = c.chu(.level)
        totalLessons = c.so(.totalLessons).map { Int($0) }
        totalDurationSeconds = c.so(.totalDurationSeconds).map { Int($0) }
        totalStudents = c.so(.totalStudents).map { Int($0) }
        categoryName = c.chu(.categoryName)
        categorySlug = c.chu(.categorySlug)
        loTrinhKy = c.so(.loTrinhKy).map { Int($0) }
        loTrinhThuTu = c.so(.loTrinhThuTu).map { Int($0) }
        isEnrolled = c.co(.isEnrolled)
        progress = c.so(.progress).map { Int($0.rounded()) }
        sapRaMat = c.co(.sapRaMat)
        soChuongDuKien = c.so(.soChuongDuKien).map { Int($0) }
        soBaiDuKien = c.so(.soBaiDuKien).map { Int($0) }
    }

    // MARK: Hiển thị

    var laSapRaMat: Bool { sapRaMat == true }
    var soBai: Int { totalLessons ?? 0 }
    var soGiay: Int { totalDurationSeconds ?? 0 }
    var daGhiDanh: Bool { isEnrolled == true }

    /// Tên theo ngôn ngữ giao diện; không có tên thì dùng slug (vẫn hơn ô trống).
    func ten(_ anh: Bool) -> String {
        let t = (title ?? "").tachSongNgu(anh ? .anh : .viet)
        return t.isEmpty ? slug : t
    }

    func moTa(_ anh: Bool) -> String? {
        let t = (shortDescription ?? "").tachSongNgu(anh ? .anh : .viet)
        return t.isEmpty ? nil : t
    }

    /// App Store 3.1.1 — cùng luật với hub cũ (`CoursesViewModel.hienDuoc`, 24/09/2026): app KHÔNG bán
    /// nội dung số ngoài IAP, nên khoá TRẢ PHÍ mà người dùng chưa sở hữu không được hiện (nó sẽ kèm nút
    /// ghi danh trả 402 "mua hoặc nhập mã"). Khoá Sắp ra mắt không bán gì nên luôn hiện. Thiếu `isFree`
    /// ⇒ coi như miễn phí (prod: 75/75 khoá đều miễn phí lúc viết).
    var hienDuoc: Bool { laSapRaMat || isFree != false || daGhiDanh }
}

// MARK: - Khung năm / kỳ

struct KyHocCT: Codable, Identifiable, Hashable {
    var so: Int
    var nam: Int?
    var ten: String?
    var tenEn: String?
    var moTa: String?
    var moTaEn: String?
    var mon: [MonChuongTrinh]

    var id: Int { so }

    enum CodingKeys: String, CodingKey { case so, nam, ten, tenEn, moTa, moTaEn, mon }

    init(so: Int, nam: Int? = nil, ten: String? = nil, tenEn: String? = nil, moTa: String? = nil,
         moTaEn: String? = nil, mon: [MonChuongTrinh] = []) {
        self.so = so; self.nam = nam; self.ten = ten; self.tenEn = tenEn
        self.moTa = moTa; self.moTaEn = moTaEn; self.mon = mon
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        guard let so = c.so(.so).map({ Int($0) }) else {
            throw DecodingError.dataCorruptedError(forKey: .so, in: c, debugDescription: "thiếu số kỳ")
        }
        self.so = so
        nam = c.so(.nam).map { Int($0) }
        ten = c.chu(.ten); tenEn = c.chu(.tenEn); moTa = c.chu(.moTa); moTaEn = c.chu(.moTaEn)
        mon = c.mang(.mon)
    }

    func tenHien(_ anh: Bool) -> String { chonNgonNguCT(ten, tenEn, anh) ?? String(format: T("Học kỳ %d"), so) }
    func moTaHien(_ anh: Bool) -> String? { chonNgonNguCT(moTa, moTaEn, anh) }
}

struct NamHocCT: Codable, Identifiable, Hashable {
    var so: Int
    var ten: String?
    var tenEn: String?
    var moTa: String?
    var moTaEn: String?
    var ky: [KyHocCT]

    var id: Int { so }

    enum CodingKeys: String, CodingKey { case so, ten, tenEn, moTa, moTaEn, ky }

    init(so: Int, ten: String? = nil, tenEn: String? = nil, moTa: String? = nil, moTaEn: String? = nil,
         ky: [KyHocCT] = []) {
        self.so = so; self.ten = ten; self.tenEn = tenEn; self.moTa = moTa; self.moTaEn = moTaEn; self.ky = ky
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        guard let so = c.so(.so).map({ Int($0) }) else {
            throw DecodingError.dataCorruptedError(forKey: .so, in: c, debugDescription: "thiếu số năm")
        }
        self.so = so
        ten = c.chu(.ten); tenEn = c.chu(.tenEn); moTa = c.chu(.moTa); moTaEn = c.chu(.moTaEn)
        ky = c.mang(.ky)
    }

    func tenHien(_ anh: Bool) -> String { chonNgonNguCT(ten, tenEn, anh) ?? "" }
    func moTaHien(_ anh: Bool) -> String? { chonNgonNguCT(moTa, moTaEn, anh) }
}

/// Nhóm "Môn tự chọn · Sắp ra mắt" (Mobile, Kiến trúc & Backend, AI, Nghề nghiệp, Môn khác).
struct NhomTuChonCT: Codable, Identifiable, Hashable {
    var ma: String
    var ten: String?
    var tenEn: String?
    var mon: [MonChuongTrinh]

    var id: String { ma }

    enum CodingKeys: String, CodingKey { case ma, ten, tenEn, mon }

    init(ma: String, ten: String? = nil, tenEn: String? = nil, mon: [MonChuongTrinh] = []) {
        self.ma = ma; self.ten = ten; self.tenEn = tenEn; self.mon = mon
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        ten = c.chu(.ten); tenEn = c.chu(.tenEn)
        // Thiếu `ma` thì lấy tên làm khoá — nhóm vẫn hiện, không mất khoá nào.
        ma = c.chu(.ma) ?? c.chu(.ten) ?? "khac"
        // Nhóm Sắp ra mắt ⇒ mọi khoá trong nó LÀ sắp ra mắt, kể cả khi máy chủ quên cờ.
        let ds: [MonChuongTrinh] = c.mang(.mon)
        mon = ds.map { m in var m = m; m.sapRaMat = true; return m }
    }

    func tenHien(_ anh: Bool) -> String { chonNgonNguCT(ten, tenEn, anh) ?? T("Khác") }
}

// MARK: - Cả chương trình

struct ChuongTrinhDaoTao: Equatable {
    enum Nguon: Equatable {
        /// `GET /courses/chuong-trinh` — đủ năm/kỳ.
        case chuongTrinh
        /// Đường lùi `/courses?gon=1` (endpoint chưa có trên máy chủ) — chỉ có danh sách khoá.
        case danhSach
    }

    var nam: [NamHocCT]
    var chuaXep: [MonChuongTrinh]
    var sapRaMat: [NhomTuChonCT]
    var nguon: Nguon

    // MARK: Giải mã

    private struct Than: Decodable {
        var nam: [NamHocCT]
        var chuaXep: [MonChuongTrinh]
        var sapRaMat: [NhomTuChonCT]
        enum CodingKeys: String, CodingKey { case nam, chuaXep, sapRaMat }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            nam = c.mang(.nam); chuaXep = c.mang(.chuaXep); sapRaMat = c.mang(.sapRaMat)
        }
    }

    private struct VoBoc<T: Decodable>: Decodable {
        let success: Bool?
        let data: T?
    }

    /// Giải mã thân `{success, data}` của `/courses/chuong-trinh`. Ném lỗi khi
    /// không có gì dùng được (để VM lùi về danh sách) — KHÔNG trả chương trình rỗng.
    static func giai(_ duLieu: Data) throws -> ChuongTrinhDaoTao {
        let v = try JSONDecoder().decode(VoBoc<Than>.self, from: duLieu)
        guard v.success != false, let t = v.data else { throw LoiChuongTrinh.khongCoDuLieu }
        let ct = ChuongTrinhDaoTao(nam: t.nam.sorted { $0.so < $1.so }, chuaXep: t.chuaXep,
                                   sapRaMat: t.sapRaMat, nguon: .chuongTrinh)
        guard !ct.tatCaMon.isEmpty else { throw LoiChuongTrinh.khongCoDuLieu }
        return ct
    }

    /// Một trang `/courses?gon=1&size=…` ⇒ (khoá, tổng số trang).
    static func giaiTrangDanhSach(_ duLieu: Data) throws -> (mon: [MonChuongTrinh], soTrang: Int) {
        struct PhanTrang: Decodable { let totalPages: SoLinhHoat? }
        struct Trang: Decodable {
            let success: Bool?
            let data: MangKhoan<MonChuongTrinh>?
            let pagination: PhanTrang?
        }
        let t = try JSONDecoder().decode(Trang.self, from: duLieu)
        guard t.success != false, let ds = t.data else { throw LoiChuongTrinh.khongCoDuLieu }
        return (ds.phanTu, max(1, t.pagination?.totalPages?.int ?? 1))
    }

    /// Dựng "chương trình" từ danh sách phẳng — đường lùi khi máy chủ chưa có endpoint. Không có
    /// năm/kỳ ⇒ màn tự chỉ mở hai chế độ Chuyên ngành / Tất cả.
    static func tuDanhSach(_ ds: [MonChuongTrinh]) -> ChuongTrinhDaoTao {
        var daCo = Set<Int>()
        let sach = ds.filter { daCo.insert($0.id).inserted }
        return ChuongTrinhDaoTao(nam: [], chuaXep: sach.filter { !$0.laSapRaMat },
                                 sapRaMat: [], nguon: .danhSach)
    }

    // MARK: Lọc theo luật App Store

    /// Bỏ khoá không hiện được (`MonChuongTrinh.hienDuoc`) ở MỌI tầng; kỳ/năm vẫn giữ (kỳ trống vẫn là kỳ).
    func locHienDuoc() -> ChuongTrinhDaoTao {
        var ra = self
        ra.nam = nam.map { n in
            var n = n
            n.ky = n.ky.map { k in var k = k; k.mon = k.mon.filter(\.hienDuoc); return k }
            return n
        }
        ra.chuaXep = chuaXep.filter(\.hienDuoc)
        return ra
    }

    // MARK: Tra cứu

    var coLoTrinh: Bool { nguon == .chuongTrinh && !nam.isEmpty }
    var tatCaKy: [KyHocCT] { nam.flatMap(\.ky) }
    var monTrongKy: [MonChuongTrinh] { tatCaKy.flatMap(\.mon) }
    var monSapRaMat: [MonChuongTrinh] { sapRaMat.flatMap(\.mon) }
    /// Khoá HỌC ĐƯỢC (đã xếp + chưa xếp) — không gồm Sắp ra mắt.
    var monHocDuoc: [MonChuongTrinh] { monTrongKy + chuaXep }
    var tatCaMon: [MonChuongTrinh] { monHocDuoc + monSapRaMat }

    /// Số liệu đầu trang, TÍNH TỪ khoá đang hiện (không lấy `tong` của máy chủ: sau
    /// `locHienDuoc` hai con số có thể lệch, và màn hình phải đếm đúng thứ nó cho xem).
    var tong: (khoa: Int, ky: Int, bai: Int, gio: Int, sapRaMat: Int) {
        let hd = monHocDuoc
        let giay = hd.reduce(0) { $0 + $1.soGiay }
        return (hd.count, tatCaKy.count, hd.reduce(0) { $0 + $1.soBai },
                Int((Double(giay) / 3600).rounded()), monSapRaMat.count)
    }

    /// Đang học dở, nhiều tiến độ nhất trước — dải "Bạn đang học".
    var dangHoc: [MonChuongTrinh] {
        monHocDuoc.filter { $0.daGhiDanh && ($0.progress ?? 0) < 100 }
            .sorted { ($0.progress ?? 0) > ($1.progress ?? 0) }
    }

    /// Kỳ để giới thiệu ở thẻ lối vào: kỳ thấp nhất còn khoá ĐANG học dở; không có thì
    /// kỳ đầu tiên còn khoá chưa học xong (chưa đăng nhập ⇒ Kỳ 1).
    var kyHienTai: (ky: KyHocCT, dangHoc: Bool)? {
        let ds = tatCaKy.filter { !$0.mon.isEmpty }
        if let k = ds.first(where: { $0.mon.contains { $0.daGhiDanh && ($0.progress ?? 0) < 100 } }) {
            return (k, true)
        }
        if let k = ds.first(where: { $0.mon.contains { ($0.progress ?? 0) < 100 } }) {
            return (k, false)
        }
        return ds.first.map { ($0, false) }
    }

    /// Chuyên ngành (theo danh mục khoá), đông nhất trước; khoá không danh mục ⇒ nhóm "Khác" (slug rỗng).
    func cacNganh(trong ds: [MonChuongTrinh]? = nil) -> [NganhCT] {
        var dem: [String: NganhCT] = [:]
        for m in ds ?? tatCaMon {
            let slug = m.categorySlug ?? m.categoryName ?? ""
            var n = dem[slug] ?? NganhCT(slug: slug, ten: m.categoryName ?? "", so: 0)
            n.so += 1
            dem[slug] = n
        }
        return dem.values.sorted { $0.so != $1.so ? $0.so > $1.so : $0.ten.localizedCompare($1.ten) == .orderedAscending }
    }

    /// Nhóm theo chuyên ngành, mỗi nhóm xếp theo kỳ rồi thứ tự trong kỳ (khoá chưa xếp/sắp ra mắt cuối nhóm).
    func nhomTheoNganh(_ ds: [MonChuongTrinh]) -> [(nganh: NganhCT, mon: [MonChuongTrinh])] {
        cacNganh(trong: ds).map { n in
            let mon = ds.filter { ($0.categorySlug ?? $0.categoryName ?? "") == n.slug }
                .sorted(by: ChuongTrinhDaoTao.theoLoTrinh)
            return (n, mon)
        }
    }

    static func theoLoTrinh(_ a: MonChuongTrinh, _ b: MonChuongTrinh) -> Bool {
        let ka = a.laSapRaMat ? 999 : (a.loTrinhKy ?? 99), kb = b.laSapRaMat ? 999 : (b.loTrinhKy ?? 99)
        if ka != kb { return ka < kb }
        let ta = a.loTrinhThuTu ?? 99, tb = b.loTrinhThuTu ?? 99
        if ta != tb { return ta < tb }
        return (a.title ?? a.slug).localizedCompare(b.title ?? b.slug) == .orderedAscending
    }
}

struct NganhCT: Identifiable, Hashable {
    var slug: String
    var ten: String
    var so: Int
    var id: String { slug.isEmpty ? "_khac" : slug }
    var tenHien: String { ten.isEmpty ? T("Khác") : ten }
}

enum LoiChuongTrinh: LocalizedError {
    case khongCoDuLieu
    var errorDescription: String? { T("Chưa tải được chương trình đào tạo.") }
}

// MARK: - Lọc / tìm

enum CapDoCT: String, CaseIterable, Identifiable {
    case coBan = "BEGINNER", trungCap = "INTERMEDIATE", nangCao = "ADVANCED"
    var id: String { rawValue }
    var ten: String {
        switch self {
        case .coBan: return T("Cơ bản")
        case .trungCap: return T("Trung cấp")
        case .nangCao: return T("Nâng cao")
        }
    }
    static func nhan(_ ma: String?) -> String? {
        guard let ma, !ma.isEmpty else { return nil }
        return CapDoCT(rawValue: ma.uppercased())?.ten ?? ma.capitalized
    }
}

struct BoLocCT: Equatable {
    var tuKhoa = ""
    var capDo: CapDoCT?
    var nganh: String?   // slug chuyên ngành; nil = mọi chuyên ngành

    var coLoc: Bool { !tuKhoa.trimmingCharacters(in: .whitespaces).isEmpty || capDo != nil || nganh != nil }

    /// `boQuaNganh`: chế độ Lộ trình không lọc theo chuyên ngành (giống web).
    func khop(_ m: MonChuongTrinh, boQuaNganh: Bool = false) -> Bool {
        if let capDo, m.level?.uppercased() != capDo.rawValue { return false }
        if !boQuaNganh, let nganh, (m.categorySlug ?? m.categoryName ?? "") != nganh { return false }
        return BoLocCT.khopTuKhoa(m, tuKhoa)
    }

    /// Bỏ dấu tiếng Việt (cả "đ"), không phân biệt hoa thường; MỌI từ phải có mặt — giống
    /// `khopTuKhoa` của web. Tìm trong tên (CẢ HAI thứ tiếng), mô tả, mã môn, slug, chuyên ngành.
    static func khopTuKhoa(_ m: MonChuongTrinh, _ tuKhoa: String) -> Bool {
        let k = TinhNang.chuanHoa(tuKhoa)
        guard !k.isEmpty else { return true }
        let hay = TinhNang.chuanHoa([m.title, m.shortDescription, m.courseCode, m.slug, m.categoryName]
            .compactMap { $0 }.joined(separator: " ")
            .replacingOccurrences(of: "|||", with: " ")
            .replacingOccurrences(of: "-", with: " "))
        return k.split(whereSeparator: \.isWhitespace).allSatisfy { hay.contains($0) }
    }
}

// MARK: - Chữ

func chonNgonNguCT(_ vi: String?, _ en: String?, _ anh: Bool) -> String? {
    let v = (vi ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let e = (en ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let ra = anh ? (e.isEmpty ? v : e) : (v.isEmpty ? e : v)
    return ra.isEmpty ? nil : ra
}

enum ChuCT {
    static func so(_ n: Int, _ anh: Bool) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: anh ? "en_US" : "vi_VN")
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    /// "3,2 giờ" · "45 phút" · "" khi không có thời lượng (nhiều khoá dạy bằng slide) — như `dinhGio` của web.
    static func gio(_ giay: Int, _ anh: Bool) -> String {
        guard giay >= 60 else { return "" }
        if giay < 3600 {
            let m = Int((Double(giay) / 60).rounded())
            return anh ? "\(m) min" : "\(m) phút"
        }
        let h = (Double(giay) / 3600 * 10).rounded() / 10
        let f = NumberFormatter()
        f.locale = Locale(identifier: anh ? "en_US" : "vi_VN")
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 0
        let s = f.string(from: NSNumber(value: h)) ?? "\(h)"
        return anh ? "\(s) h" : "\(s) giờ"
    }

    static func khoa(_ n: Int, _ anh: Bool) -> String {
        anh ? "\(so(n, true)) \(n == 1 ? "course" : "courses")" : "\(so(n, false)) khoá"
    }

    static func bai(_ n: Int, _ anh: Bool) -> String {
        anh ? "\(so(n, true)) \(n == 1 ? "lesson" : "lessons")" : "\(so(n, false)) bài"
    }

    /// "Năm thứ nhất" / "Year one".
    static func nam(_ so: Int, _ anh: Bool) -> String {
        let vi = ["nhất", "hai", "ba", "tư"], en = ["one", "two", "three", "four"]
        let i = so - 1
        if anh { return "Year " + (en.indices.contains(i) ? en[i] : "\(so)") }
        return "Năm thứ " + (vi.indices.contains(i) ? vi[i] : "\(so)")
    }

    static func hocKy(_ so: Int, _ anh: Bool) -> String { anh ? "Term \(so)" : "Học kỳ \(so)" }
    static func ky(_ so: Int, _ anh: Bool) -> String { anh ? "Term \(so)" : "Kỳ \(so)" }

    static func tienDo(_ p: Int, _ anh: Bool) -> String {
        if p >= 100 { return anh ? "Completed" : "Đã học xong" }
        return anh ? "\(p)% complete" : "Đã học \(p)%"
    }

    static func khung(_ phan: Int, _ bai: Int, _ anh: Bool) -> String {
        anh ? "\(phan) parts · \(bai) planned lessons" : "\(phan) phần · \(bai) bài dự kiến"
    }

    static func ketQua(_ n: Int, _ anh: Bool) -> String {
        anh ? "\(so(n, true)) \(n == 1 ? "course matches" : "courses match")" : "\(so(n, false)) khoá khớp"
    }
}

// MARK: - Giải mã khoan dung: tiện ích

fileprivate extension KeyedDecodingContainer {
    /// Chuỗi; số ⇒ đổi thành chuỗi; kiểu khác/thiếu ⇒ nil.
    func chu(_ k: Key) -> String? {
        if let s = try? decodeIfPresent(String.self, forKey: k) { return s }
        if let so = try? decodeIfPresent(SoLinhHoat.self, forKey: k) { return so.chu }
        return nil
    }

    /// Số; nhận cả "12" (Decimal → chuỗi), hỏng/thiếu ⇒ nil.
    func so(_ k: Key) -> Double? {
        guard let v = try? decodeIfPresent(SoLinhHoat.self, forKey: k) else { return nil }
        return v.so
    }

    /// Bool; nhận cả 0/1 và "true"/"false".
    func co(_ k: Key) -> Bool? {
        if let b = try? decodeIfPresent(Bool.self, forKey: k) { return b }
        if let s = try? decodeIfPresent(String.self, forKey: k) {
            switch s.lowercased() { case "true", "1": return true; case "false", "0": return false; default: return nil }
        }
        if let n = so(k) { return n != 0 }
        return nil
    }

    /// Mảng bỏ phần tử hỏng; không phải mảng/thiếu ⇒ [].
    func mang<T: Codable>(_ k: Key) -> [T] {
        guard let v = try? decodeIfPresent(MangKhoan<T>.self, forKey: k) else { return [] }
        return v.phanTu
    }
}
