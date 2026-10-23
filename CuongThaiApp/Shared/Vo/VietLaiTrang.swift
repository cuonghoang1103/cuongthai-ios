#if os(iOS)
import CoreText
import PencilKit
import SwiftData
import SwiftUI
import UIKit

// ════════════════════════════════════════════════════════════════
// ✍️ AI VIẾT LẠI TRANG — chữ viết vội thành bản sạch, vẫn "nét chữ người"
//
// Người dùng 28/09/2026: "AI viết lại chữ cho tôi đúng và đẹp + căn dòng căn
// lề, viết hoa, thường, ngắt câu… tạo bảng nếu có. Xong có nút HOÀN TÁC nếu
// không thích và nút LƯU nếu thấy ok."
//
// Luồng: ảnh nét bút (nền trắng) + chữ Vision đọc trên máy → `POST
// /api/v1/vo/viet-lai` (gpt-6-sol) → KHỐI có cấu trúc (tiêu đề, đoạn, danh
// sách, bảng, công thức, code, ghi chú) + danh sách chỗ đã sửa → app DỰNG
// các khối bằng phông chữ tay (Patrick Hand + Yomogi, OFL), đặt từng dòng
// lên đúng dòng kẻ của giấy đang dùng.
//
// ── Vì sao lớp chữ đẹp là ẢNH NỀN, không phải nét PKStroke ─────────
// Phông chữ tay là hình KÍN (đường viền tô đặc); đổi ra PKStroke thì hoặc
// thành chữ rỗng ruột, hoặc phải tô bằng hàng trăm nét zigzag — nặng, xấu,
// và không có phông nét-đơn nào đủ dấu tiếng Việt lẫn kana/kanji. Ảnh nền thì
// đi được MỌI đường sẵn có mà không viết thêm dòng đồng bộ nào:
//   · `TrangVo.nenAnhTen` (PNG trong suốt, 3× khổ trang) — màn viết, ảnh nhỏ,
//     xuất PDF, đọc chữ Vision đều đã vẽ nền;
//   · đồng bộ đi đường nền sẵn có (`/vo/nen/duong-day`, khoá sha256);
//   · người dùng VẪN VIẾT TIẾP bằng bút lên trên — nét nằm ở lớp riêng.
// Đánh dấu "đây là lớp chữ AI, không phải ảnh quét" bằng `nenPdfTrang =
// TrangVo.trangLopChuAI` (xem đó): số đó vốn vô nghĩa với nền ảnh, máy chủ
// cũ đã lưu và trả lại nguyên (`bgPage`), nên KHÔNG cần migration, và máy
// chưa cập nhật app vẫn hiện được ảnh (chỉ là khổ theo A4 như ảnh quét).
//
// ── Bản gốc không bao giờ mất ──────────────────────────────────────
// "Thay trang này" = trang đẹp MỚI chen vào đúng chỗ, trang viết tay GỐC dời
// ngay sau với tên "… (bản gốc)" — không xoá nét nào, không ghi đè tệp nào.
// "Hoàn tác" trên dải báo = xoá trang mới (vào hàng đợi xoá như xoá tay) rồi
// trả tên/nhãn chương cho trang gốc.
// ════════════════════════════════════════════════════════════════

// MARK: - Dữ liệu máy chủ trả về

/// Một khối nội dung. Mọi trường `var` + optional (C4 của CLAUDE.md kho iOS).
struct KhoiVietLai: Decodable, Hashable {
    var loai: String?
    var cap: Int?
    var chu: String?
    var kieu: String?
    var muc: [String]?
    var coTieuDe: Bool?
    var hang: [[String]]?
    var latex: String?
    var ngonNgu: String?
}

struct SuaVietLai: Decodable, Hashable {
    var truoc: String?
    var sau: String?
    var loai: String?

    var nhanLoai: String {
        switch loai {
        case "chinhTa": return T("Chính tả")
        case "dau": return T("Dấu")
        case "vietHoa": return T("Viết hoa")
        case "dauCau": return T("Dấu câu")
        case "vietTat": return T("Viết tắt")
        default: return T("Khác")
        }
    }
}

struct KetQuaVietLai: Decodable {
    /// Lượt chạy nền: `false` = máy chủ còn đang chép.
    var xong: Bool?
    var khoi: [KhoiVietLai]?
    var sua: [SuaVietLai]?
    var chuThuan: String?
    var canhBao: [String]?
    var soKhongDoc: Int?
    var model: String?
}

// MARK: - Gọi máy chủ

enum VietLaiTrang {
    private struct Viec: Decodable { var viec: String? }
    /// Chốt đồng ý chia sẻ AI chạy trong `APIClient` (`laDuongAI` bắt
    /// `POST /vo/viet-lai`). Đừng gọi thêm `batBuoc()` — hai chốt là hỏi hai lần.
    static func goi(anh: Data, goiY: String, giay: LoaiGiay) async throws -> KetQuaVietLai {
        let than: [String: Any] = [
            "anh": anh.base64EncodedString(),
            "goiY": String(goiY.prefix(6000)),
            "giay": giay.rawValue,
        ]
        // ⚠️ Gửi việc rồi HỎI LẠI mỗi 3 giây, không chờ một cục: Cloudflare cắt
        // yêu cầu quá 100 giây (524) mà một trang dày mất tới 90 giây.
        let kq: KetQuaVietLai = try await ViecNen.cho(han: 240, gui: {
            let v: Viec = try await APIClient.shared.request(.voVietLai(than: than))
            guard let id = v.viec else {
                throw APIError.coMa(ma: "AI_LOI", thongDiep: T("Máy chủ chưa nhận lượt viết lại — thử lại."))
            }
            return id
        }, xem: { id in
            let k: KetQuaVietLai = try await APIClient.shared.request(.voVietLaiXem(viec: id))
            return k.xong == true ? k : nil
        })
        guard !(kq.khoi ?? []).isEmpty else {
            throw APIError.coMa(ma: "TRANG_TRONG", thongDiep: T("Không đọc ra chữ nào trên trang này."))
        }
        return kq
    }

    static func cauLoi(_ e: Error) -> String {
        if let u = e as? URLError, u.code == .timedOut {
            return T("Chờ quá lâu mà AI chưa chép xong. Thử lại, hoặc chia trang thành hai phần.")
        }
        if case APIError.serverError(let m) = e, m.contains("404") || m.contains("not found") {
            return T("Máy chủ chưa có tính năng này — sắp có.")
        }
        return (e as? LocalizedError)?.errorDescription ?? e.localizedDescription
    }

    /// Ảnh gửi đi: CHỈ nét bút (không nền tài liệu, không dòng kẻ) trên nền
    /// trắng, cắt sát vùng có chữ, cạnh dài ≤ 1600px, JPEG. Dòng kẻ chỉ làm
    /// model nhầm gạch chân với kẻ bảng; nền PDF thì nó sẽ chép luôn chữ in.
    static func anhGui(_ d: PKDrawing, khoTrang: CGSize) -> Data? {
        let b = d.bounds
        guard !b.isNull, !b.isEmpty else { return nil }
        let trang = CGRect(origin: .zero, size: khoTrang)
        var vung = b.insetBy(dx: -24, dy: -24).intersection(trang.insetBy(dx: -40, dy: -40))
        if vung.isNull || vung.width < 8 { vung = b }
        let s = min(3, 1600 / max(vung.width, vung.height, 1))
        let kho = CGSize(width: (vung.width * s).rounded(), height: (vung.height * s).rounded())
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        fmt.opaque = true
        var ra: UIImage?
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            let muc = d.image(from: vung, scale: s)
            ra = UIGraphicsImageRenderer(size: kho, format: fmt).image { c in
                UIColor.white.setFill()
                c.fill(CGRect(origin: .zero, size: kho))
                muc.draw(in: CGRect(origin: .zero, size: kho))
            }
        }
        return ra?.jpegData(compressionQuality: 0.82)
    }
}

// MARK: - Phông chữ tay

/// Patrick Hand (Latin + đủ dấu tiếng Việt) → Yomogi (kana/kanji, cũng đủ
/// dấu Việt) → phông hệ thống. Cả hai giấy phép SIL OFL 1.1, tệp giấy phép đi
/// kèm trong `Resources/PhongChu/`.
///
/// ⚠️ Đăng ký lúc CHẠY (`CTFontManagerRegisterFontsForURL`), không khai
/// `UIAppFonts` trong Info.plist: chỉ màn này dùng, không cần nạp 4MB phông
/// Nhật mỗi lần app mở.
enum PhongChuTay {
    static let tenChinh = "PatrickHand-Regular"
    static let tenNhat = "Yomogi-Regular"

    private static let daDangKy: Bool = {
        var ok = true
        for ten in ["PatrickHand-Regular", "Yomogi-Regular"] {
            guard let url = Bundle.main.url(forResource: ten, withExtension: "ttf") else {
                NhatKy.vo.error("viết lại: thiếu tệp phông \(ten).ttf trong gói app")
                ok = false
                continue
            }
            var loi: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &loi) {
                // Đã đăng ký từ trước (mã 105) là bình thường khi màn mở lần hai.
                let e = loi?.takeRetainedValue()
                if let e, CFErrorGetCode(e) != 105 {
                    NhatKy.vo.error("viết lại: đăng ký phông \(ten) hỏng — \(e)")
                }
            }
        }
        return ok
    }()

    static func chu(_ co: CGFloat) -> UIFont {
        _ = daDangKy
        let nhat = UIFontDescriptor(fontAttributes: [.name: tenNhat])
        let d = UIFontDescriptor(fontAttributes: [.name: tenChinh, .cascadeList: [nhat]])
        let f = UIFont(descriptor: d, size: co)
        // Không nạp được phông (gói hỏng) ⇒ vẫn dựng được bằng phông hệ thống,
        // xấu hơn nhưng không trắng trang.
        return f.fontName == tenChinh ? f : UIFont.systemFont(ofSize: co)
    }

    static func ma(_ co: CGFloat) -> UIFont {
        UIFont.monospacedSystemFont(ofSize: co, weight: .regular)
    }
}

// MARK: - Dựng bản đẹp

/// Một trang bản đẹp đã dàn xong: danh sách lệnh vẽ theo toạ độ TRANG.
struct TrangChuDep {
    enum Lenh {
        /// Một dòng chữ, `goc` = đầu đường chân chữ (baseline).
        case dong(CTLine, goc: CGPoint)
        case duong(CGPoint, CGPoint, day: CGFloat, mo: CGFloat)
        case nen(CGRect, bo: CGFloat, mo: CGFloat)
    }
    var lenh: [Lenh] = []
    /// Chữ thuần của riêng trang này — chỉ mục tìm kiếm.
    var chu: [String] = []
}

enum DungChuDep {

    private static func mm(_ x: CGFloat) -> CGFloat { x / 25.4 * 72 }
    /// Khoá thuộc tính "đậm giả" (độ dày viền, pt) — xem `thuocTinh`.
    static let khoaDam = NSAttributedString.Key("vietlai.dam")

    /// Khuôn của một loại giấy: các đường chân chữ, lề trái/phải, cỡ chữ.
    struct Khuon {
        var dong: [CGFloat]
        var x0: CGFloat
        var x1: CGFloat
        var co: CGFloat
        /// Khoảng cách hai đường chân chữ liền nhau.
        var buoc: CGFloat
    }

    /// ⚠️ Đường chân chữ lấy từ `GiayNenView.dongChanChu` — CÙNG nguồn với
    /// giấy vẽ trên màn, nên chữ nằm đúng trên dòng kẻ chứ không lơ lửng.
    static func khuon(giay: LoaiGiay, kho: CGSize) -> Khuon {
        let w = kho.width, h = kho.height
        var dong = GiayNenView.dongChanChu(giay: giay, khoTrang: kho, caoGoc: h)
        var x0: CGFloat = 54, x1: CGFloat = w - 54
        switch giay {
        case .keNgang:
            x0 = mm(25) + 7; x1 = w - mm(12) - 4
        case .cornell:
            x0 = w * 0.30 + mm(3) + 5; x1 = w - mm(12) - 4
        case .oLy, .cham:
            // Ô 5mm quá sát cho một dòng chữ ⇒ cứ HAI ô một dòng (≈ vở ô ly
            // của học sinh: chữ cao hai ô).
            dong = stride(from: 3, to: dong.count, by: 2).map { dong[$0] }
            x0 = mm(5) * 3; x1 = w - mm(5) * 3
        case .bonDong:
            x0 = mm(12) + 6; x1 = w - mm(12) - 6
        case .luoiCode:
            x0 = mm(16) + mm(3.5); x1 = w - mm(8) - 4
        case .tuVung3Cot:
            x0 = mm(10) + 5; x1 = w - mm(10) - 5
        case .trang, .genkou, .nhacLy, .soDoTuDuy, .bangSoSanh:
            dong = []
        }
        if dong.count < 3 {
            // Giấy không có dòng chân: dòng ẢO 24pt, chừa lề như vở trắng.
            dong = Array(stride(from: CGFloat(72), to: h - 48, by: 24))
        }
        let buoc = dong.count > 1 ? dong[1] - dong[0] : 24
        var co = min(22, max(14, buoc * 0.8))
        if giay == .bonDong {
            // x-height của Patrick Hand = 0,467em ⇒ chữ thường cao đúng một
            // tầng (đỉnh chữ thường chạm đường giữa nét đứt).
            co = mm(4.5) / 0.467 * 0.92
        }
        return Khuon(dong: dong, x0: x0, x1: max(x0 + 120, x1), co: co, buoc: buoc)
    }

    // MARK: Dàn trang

    private final class BoDan {
        let k: Khuon
        let muc: UIColor
        var trangs: [TrangChuDep] = [TrangChuDep()]
        var i = 0   // chỉ số đường chân chữ KẾ TIẾP trên trang hiện tại

        init(k: Khuon, muc: UIColor) { self.k = k; self.muc = muc }

        var conLai: Int { k.dong.count - i }
        func sangTrangMoi() { trangs.append(TrangChuDep()); i = 0 }
        /// Bảo đảm còn đủ `n` dòng trên trang (không đủ ⇒ sang trang mới).
        func can(_ n: Int) { if conLai < min(n, k.dong.count) { sangTrangMoi() } }
        func them(_ l: TrangChuDep.Lenh) { trangs[trangs.count - 1].lenh.append(l) }
        func ghiChu(_ s: String) { trangs[trangs.count - 1].chu.append(s) }
        /// Bỏ một dòng trống (không ở đầu trang).
        func dongTrong() { if i > 0 { i += 1; if conLai <= 0 { sangTrangMoi() } } }

        func thuocTinh(_ f: UIFont, dam: CGFloat = 0) -> [NSAttributedString.Key: Any] {
            // Màu chữ lấy từ NGỮ CẢNH lúc vẽ (không đóng cứng vào dòng) — cùng
            // một bản dàn vẽ được mực sáng (ảnh lưu) lẫn mực tối (xem trước
            // chế độ tối). Đóng cứng màu thì xem trước tối ra chữ đen trên giấy đen.
            var a: [NSAttributedString.Key: Any] = [
                .font: f,
                NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true,
            ]
            // Phông chữ tay không có bản đậm ⇒ "đậm giả" bằng viền cùng màu:
            // số ÂM = vừa tô vừa viền (dương là chỉ viền, chữ rỗng ruột).
            // (Không dùng `kCTStrokeWidth`: viền của nó KHÔNG lấy màu ngữ cảnh.
            // Ghi độ đậm vào khoá riêng, lúc vẽ bật chế độ tô+viền của ngữ cảnh.)
            if dam > 0 { a[DungChuDep.khoaDam] = dam * f.pointSize / 100 }
            return a
        }

        /// Ngắt chữ thành các dòng vừa bề rộng `rong`. Xuống dòng cứng theo "\n".
        func ngat(_ s: String, _ tt: [NSAttributedString.Key: Any], rong: CGFloat,
                  catKyTu: Bool = false) -> [CTLine] {
            var ra: [CTLine] = []
            for doan in s.components(separatedBy: "\n") {
                if doan.isEmpty { ra.append(CTLineCreateWithAttributedString(NSAttributedString(string: " ", attributes: tt))); continue }
                let as_ = NSAttributedString(string: doan, attributes: tt)
                let ts = CTTypesetterCreateWithAttributedString(as_)
                var dau = 0
                let n = as_.length
                while dau < n {
                    var dem = catKyTu
                        ? CTTypesetterSuggestClusterBreak(ts, dau, Double(rong))
                        : CTTypesetterSuggestLineBreak(ts, dau, Double(rong))
                    if dem <= 0 { dem = max(1, CTTypesetterSuggestClusterBreak(ts, dau, Double(rong))) }
                    ra.append(CTTypesetterCreateLine(ts, CFRange(location: dau, length: dem)))
                    dau += dem
                }
            }
            return ra
        }

        func rongDong(_ l: CTLine) -> CGFloat {
            CGFloat(CTLineGetTypographicBounds(l, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(l))
        }

        /// Đặt một dòng lên đường chân chữ kế tiếp.
        @discardableResult
        func dat(_ l: CTLine, x: CGFloat) -> CGFloat {
            if conLai <= 0 { sangTrangMoi() }
            let y = k.dong[i]
            them(.dong(l, goc: CGPoint(x: x, y: y)))
            i += 1
            return y
        }
    }

    /// Dàn các khối thành một hoặc nhiều trang (tràn ⇒ trang tiếp theo).
    static func dan(_ khoi: [KhoiVietLai], giay: LoaiGiay, kho: CGSize, muc: UIColor) -> [TrangChuDep] {
        let k = khuon(giay: giay, kho: kho)
        let b = BoDan(k: k, muc: muc)
        let rong = k.x1 - k.x0
        let chu = PhongChuTay.chu(k.co)
        let ttChu = b.thuocTinh(chu)

        for (so, kh) in khoi.enumerated() {
            switch kh.loai ?? "doan" {
            case "tieuDe":
                let cap = kh.cap ?? 1
                let co = k.co * (cap == 1 ? 1.45 : cap == 2 ? 1.22 : 1.08)
                let tt = b.thuocTinh(PhongChuTay.chu(co), dam: cap == 1 ? 3.2 : 2.6)
                if so > 0 && cap <= 2 { b.dongTrong() }
                let ds = b.ngat(kh.chu ?? "", tt, rong: rong)
                b.can(min(ds.count + 1, 3))
                for l in ds {
                    let w = b.rongDong(l)
                    let x = cap == 1 ? k.x0 + max(0, (rong - w) / 2) : k.x0
                    let y = b.dat(l, x: x)
                    if cap == 2 {
                        // Gạch chân nhẹ như người ta hay kẻ dưới đề mục.
                        b.them(.duong(CGPoint(x: x, y: y + co * 0.2), CGPoint(x: x + w, y: y + co * 0.2),
                                      day: 1.1, mo: 0.55))
                    }
                }
                b.ghiChu(kh.chu ?? "")

            case "danhSach":
                let so_ = kh.kieu == "so"
                var dem: [Int: Int] = [:]
                for m in kh.muc ?? [] {
                    let dauCach = m.prefix { $0 == " " }.count
                    let cap = min(3, dauCach / 2)
                    for c in dem.keys where c > cap { dem[c] = nil }
                    dem[cap, default: 0] += 1
                    let dauMuc = so_ ? "\(dem[cap] ?? 1)." : (cap == 0 ? "•" : "–")
                    let thut = CGFloat(cap) * k.co * 1.4
                    let lDau = CTLineCreateWithAttributedString(NSAttributedString(string: dauMuc, attributes: ttChu))
                    let lech = max(k.co * 1.3, b.rongDong(lDau) + k.co * 0.45)
                    let noi = m.trimmingCharacters(in: .whitespaces)
                    let ds = b.ngat(noi, ttChu, rong: rong - thut - lech)
                    for (j, l) in ds.enumerated() {
                        if j == 0 {
                            if b.conLai <= 0 { b.sangTrangMoi() }
                            b.them(.dong(lDau, goc: CGPoint(x: k.x0 + thut, y: k.dong[b.i])))
                        }
                        b.dat(l, x: k.x0 + thut + lech)
                    }
                    b.ghiChu(noi)
                }

            case "bang":
                danBang(kh, b: b, k: k, ttChu: ttChu)

            case "congThuc":
                let tt = b.thuocTinh(PhongChuTay.chu(k.co * 1.1))
                // Dấu phẩy trên (′ ″) không có trong Patrick Hand ⇒ rơi sang phông
                // khác, lệch khoảng. Dấu nháy thường nhìn như viết tay hơn.
                let ct = (kh.chu ?? kh.latex ?? "").replacingOccurrences(of: "″", with: "''")
                    .replacingOccurrences(of: "′", with: "'")
                for l in b.ngat(ct, tt, rong: rong - k.co * 2) {
                    b.dat(l, x: k.x0 + max(0, (rong - b.rongDong(l)) / 2))
                }
                b.ghiChu(kh.chu ?? "")

            case "code":
                let tt = b.thuocTinh(PhongChuTay.ma(max(11, k.co * 0.74)))
                let dem = k.co * 0.6
                let ds = b.ngat(kh.chu ?? "", tt, rong: rong - dem * 2, catKyTu: true)
                b.dongTrong()
                danHop(ds, b: b, k: k, x: k.x0 + dem, mo: 0.06, vien: 0.28, vach: false)
                b.dongTrong()
                b.ghiChu(kh.chu ?? "")

            case "ghiChu":
                let dem = k.co * 0.75
                let ds = b.ngat(kh.chu ?? "", ttChu, rong: rong - dem * 1.6)
                b.dongTrong()
                danHop(ds, b: b, k: k, x: k.x0 + dem, mo: 0.07, vien: 0, vach: true)
                b.dongTrong()
                b.ghiChu(kh.chu ?? "")

            default:   // "doan" và mọi loại lạ: đoạn văn thường
                for l in b.ngat(kh.chu ?? "", ttChu, rong: rong) { b.dat(l, x: k.x0) }
                b.ghiChu(kh.chu ?? "")
            }
        }
        return b.trangs.filter { !$0.lenh.isEmpty }
    }

    /// Hộp nền (code / ghi chú) ôm các dòng, tách hộp khi sang trang.
    private static func danHop(_ ds: [CTLine], b: BoDan, k: Khuon, x: CGFloat,
                               mo: CGFloat, vien: CGFloat, vach: Bool) {
        var dauHop: CGFloat?
        var cuoiHop: CGFloat = 0
        func dong() {
            guard let d = dauHop else { return }
            let r = CGRect(x: k.x0, y: d - k.buoc * 0.74, width: k.x1 - k.x0,
                           height: cuoiHop - d + k.buoc * 1.02)
            b.them(.nen(r, bo: vach ? 3 : 6, mo: mo))
            if vien > 0 {
                let p = r.insetBy(dx: 0.5, dy: 0.5)
                for (a, c) in [(CGPoint(x: p.minX, y: p.minY), CGPoint(x: p.maxX, y: p.minY)),
                               (CGPoint(x: p.maxX, y: p.minY), CGPoint(x: p.maxX, y: p.maxY)),
                               (CGPoint(x: p.maxX, y: p.maxY), CGPoint(x: p.minX, y: p.maxY)),
                               (CGPoint(x: p.minX, y: p.maxY), CGPoint(x: p.minX, y: p.minY))] {
                    b.them(.duong(a, c, day: 0.8, mo: vien))
                }
            }
            if vach {
                b.them(.duong(CGPoint(x: r.minX + 1.5, y: r.minY + 2), CGPoint(x: r.minX + 1.5, y: r.maxY - 2),
                              day: 3, mo: 0.75))
            }
            dauHop = nil
        }
        for l in ds {
            if b.conLai <= 0 { dong(); b.sangTrangMoi() }
            let y = b.dat(l, x: x)
            if dauHop == nil { dauHop = y }
            cuoiHop = y
        }
        dong()
    }

    /// Bảng: đo độ rộng tự nhiên từng cột, co cho vừa lề, ngắt chữ trong ô,
    /// mỗi hàng chiếm đủ số dòng kẻ của ô cao nhất. Tràn trang thì đóng khung
    /// ở trang này và lặp lại hàng tiêu đề ở trang sau.
    private static func danBang(_ kh: KhoiVietLai, b: BoDan, k: Khuon,
                                ttChu: [NSAttributedString.Key: Any]) {
        let hang = (kh.hang ?? []).filter { !$0.isEmpty }
        guard let soCot = hang.map(\.count).max(), soCot > 0 else { return }
        let coTieuDe = (kh.coTieuDe ?? true) && hang.count > 1
        let ttDam = b.thuocTinh(PhongChuTay.chu(k.co), dam: 2.6)
        let dem = k.co * 0.45
        let rong = k.x1 - k.x0

        // 1. Độ rộng tự nhiên (một dòng) của mỗi cột.
        var tuNhien = Array(repeating: CGFloat(k.co * 2), count: soCot)
        for (r, h) in hang.enumerated() {
            for c in 0..<soCot {
                let s = c < h.count ? h[c] : ""
                let l = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: r == 0 && coTieuDe ? ttDam : ttChu))
                tuNhien[c] = max(tuNhien[c], b.rongDong(l) + dem * 2)
            }
        }
        // 2. Co cho vừa: cột nào ngắn hơn phần chia đều thì giữ nguyên, phần
        //    dư chia cho các cột dài theo tỉ lệ.
        var rongCot = tuNhien
        let tong = tuNhien.reduce(0, +)
        if tong > rong {
            let deu = rong / CGFloat(soCot)
            let ngan = tuNhien.enumerated().filter { $0.element <= deu }
            let conLai = rong - ngan.map(\.element).reduce(0, +)
            let dai = tuNhien.enumerated().filter { $0.element > deu }
            let tongDai = dai.map(\.element).reduce(0, +)
            for (c, w) in dai { rongCot[c] = max(k.co * 2.2, conLai * w / max(tongDai, 1)) }
        }
        var xCot: [CGFloat] = [k.x0]
        for w in rongCot { xCot.append(xCot.last! + w) }

        // 3. Ngắt chữ từng ô.
        let o: [[[CTLine]]] = hang.enumerated().map { r, h in
            (0..<soCot).map { c in
                b.ngat(c < h.count ? h[c] : "", r == 0 && coTieuDe ? ttDam : ttChu,
                       rong: max(10, rongCot[c] - dem * 2))
            }
        }

        b.dongTrong()
        var dinhDoan: CGFloat?     // mép trên đoạn bảng trên trang hiện tại
        var danhSachY: [CGFloat] = []  // vạch ngang giữa các hàng
        func dongDoan(_ day: CGFloat) {
            guard let d = dinhDoan else { return }
            for y in danhSachY {
                b.them(.duong(CGPoint(x: xCot.first!, y: y), CGPoint(x: xCot.last!, y: y), day: 1, mo: 0.8))
            }
            b.them(.duong(CGPoint(x: xCot.first!, y: day), CGPoint(x: xCot.last!, y: day), day: 1, mo: 0.8))
            for x in xCot {
                b.them(.duong(CGPoint(x: x, y: d), CGPoint(x: x, y: day), day: 1, mo: 0.8))
            }
            dinhDoan = nil
            danhSachY = []
        }
        func datHang(_ r: Int) {
            let n = max(1, o[r].map(\.count).max() ?? 1)
            if b.conLai < n {
                dongDoan(k.dong[max(0, b.i - 1)] + k.buoc * 0.28)
                b.sangTrangMoi()
                if coTieuDe && r > 0 { datHang(0) }   // lặp hàng tiêu đề
            }
            let yDau = k.dong[b.i]
            let dinh = yDau - k.buoc * 0.72
            if dinhDoan == nil { dinhDoan = dinh } else { danhSachY.append(dinh) }
            if r == 0 && coTieuDe {
                let cuoi = k.dong[min(k.dong.count - 1, b.i + n - 1)]
                b.them(.nen(CGRect(x: xCot.first!, y: dinh, width: xCot.last! - xCot.first!,
                                   height: cuoi + k.buoc * 0.28 - dinh), bo: 0, mo: 0.08))
            }
            for c in 0..<soCot {
                for (j, l) in o[r][c].enumerated() {
                    // Ô cao hơn cả một trang (hiếm): dòng thừa chồng ở đáy thay vì văng app.
                    b.them(.dong(l, goc: CGPoint(x: xCot[c] + dem, y: k.dong[min(k.dong.count - 1, b.i + j)])))
                }
            }
            b.i += n
        }
        for r in 0..<hang.count {
            datHang(r)
            b.ghiChu(hang[r].joined(separator: " | "))
        }
        dongDoan(k.dong[max(0, b.i - 1)] + k.buoc * 0.28)
        b.dongTrong()
    }

    // MARK: Vẽ

    /// Vẽ một trang bản đẹp ra ảnh TRONG SUỐT đúng khổ trang, tỉ lệ `tyLe`.
    static func veAnh(_ tr: TrangChuDep, kho: CGSize, muc: UIColor, tyLe: CGFloat) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = tyLe
        fmt.opaque = false
        return UIGraphicsImageRenderer(size: kho, format: fmt).image { c in
            ve(tr, vao: c.cgContext, muc: muc)
        }
    }

    /// Vẽ lệnh của một trang lên một ngữ cảnh đang ở toạ độ TRANG (y hướng xuống).
    static func ve(_ tr: TrangChuDep, vao ctx: CGContext, muc: UIColor) {
        ctx.setLineCap(.round)
        for l in tr.lenh {
            switch l {
            case .nen(let r, let bo, let mo):
                ctx.setFillColor(muc.withAlphaComponent(mo).cgColor)
                ctx.addPath(UIBezierPath(roundedRect: r, cornerRadius: bo).cgPath)
                ctx.fillPath()
            case .duong(let a, let b, let day, let mo):
                ctx.setStrokeColor(muc.withAlphaComponent(mo).cgColor)
                ctx.setLineWidth(day)
                ctx.move(to: a); ctx.addLine(to: b)
                ctx.strokePath()
            case .dong(let line, let goc):
                ctx.saveGState()
                // Ngữ cảnh UIKit lật trục y ⇒ lật ngược ma trận chữ để chữ đứng.
                ctx.setFillColor(muc.cgColor)
                ctx.setStrokeColor(muc.cgColor)
                ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
                ctx.textPosition = goc
                let runs = CTLineGetGlyphRuns(line) as? [CTRun] ?? []
                let dam = runs.first.flatMap { (CTRunGetAttributes($0) as NSDictionary)[khoaDam.rawValue] as? CGFloat } ?? 0
                if dam > 0 {
                    ctx.setTextDrawingMode(.fillStroke)
                    ctx.setLineWidth(dam)
                    ctx.setLineJoin(.round)
                }
                CTLineDraw(line, ctx)
                ctx.restoreGState()
            }
        }
    }

    /// Màu mực của bút đang cầm, trừ khi nó quá nhạt để đọc (bút dạ vàng…).
    static func mauMuc(_ but: PKInkingTool?) -> UIColor {
        let macDinh = UIColor(red: 0.09, green: 0.14, blue: 0.32, alpha: 1)
        guard let but, but.inkType != .marker else { return macDinh }
        var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0, a: CGFloat = 0
        guard but.color.getRed(&r, green: &g, blue: &bl, alpha: &a) else { return macDinh }
        let sang = 0.2126 * r + 0.7152 * g + 0.0722 * bl
        return sang > 0.62 ? macDinh : UIColor(red: r, green: g, blue: bl, alpha: 1)
    }
}

// MARK: - Mực ở chế độ tối

/// Đổi ảnh mực trong suốt sang màu đọc được trên giấy TỐI — cùng ý với việc
/// PencilKit tự đảo mực: đen → trắng, xanh đậm → xanh nhạt (đảo độ sáng, giữ
/// sắc màu = đảo màu rồi xoay sắc 180°). Làm trên dữ liệu đã nhân alpha nên
/// điểm trong suốt vẫn trong suốt.
enum MucToi {
    private static let dem = NSCache<NSString, UIImage>()

    /// Bản tối đã tính sẵn (không tính mới) — gọi được trên luồng chính.
    static func coSan(_ khoa: String) -> UIImage? { dem.object(forKey: khoa as NSString) }

    static func doi(_ anh: UIImage, khoa: String? = nil) -> UIImage? {
        if let khoa, let co = dem.object(forKey: khoa as NSString) { return co }
        guard let cg = anh.cgImage else { return nil }
        let w = cg.width, h = cg.height
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let p = ctx.data?.bindMemory(to: UInt8.self, capacity: w * h * 4) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        // Ma trận xoay sắc 180° (CSS hue-rotate) nhân với phép đảo: ra = a − M·c
        // (hàng của M cộng lại bằng 1 nên a·1 − M·(a·c) = a·M·(1 − c)).
        let m: [Float] = [-0.574, 1.430, 0.144,
                           0.426, 0.430, 0.144,
                           0.426, 1.430, -0.856]
        for i in stride(from: 0, to: w * h * 4, by: 4) {
            let a = Float(p[i + 3])
            if a == 0 { continue }
            let r = Float(p[i]), g = Float(p[i + 1]), b = Float(p[i + 2])
            for k in 0..<3 {
                let v = a - (m[k * 3] * r + m[k * 3 + 1] * g + m[k * 3 + 2] * b)
                p[i + k] = UInt8(max(0, min(a, v)))
            }
        }
        guard let ra = ctx.makeImage() else { return nil }
        let img = UIImage(cgImage: ra, scale: anh.scale, orientation: .up)
        if let khoa { dem.setObject(img, forKey: khoa as NSString) }
        return img
    }
}

// MARK: - Lưu vào vở

/// Cách lưu bản viết lại.
enum CachLuuVietLai: String, CaseIterable, Identifiable {
    /// Trang đẹp chen vào ĐÚNG chỗ trang đang mở; bản viết tay dời ngay sau.
    case thayTrang
    /// Trang đẹp thêm ngay SAU trang đang mở; trang gốc giữ nguyên.
    case themSau
    var id: String { rawValue }
}

/// Đủ để hoàn tác một lần lưu.
struct LuotLuuVietLai: Equatable {
    let idMoi: [UUID]
    let idGoc: UUID
    let tieuDeGoc: String?
    let tenChuongGoc: String?
    let cach: CachLuuVietLai
    let lan = UUID()
    static func == (a: LuotLuuVietLai, b: LuotLuuVietLai) -> Bool { a.lan == b.lan }
}

extension TrangVo {
    /// Trang này là trang "✍️ AI viết lại" (nền = lớp chữ đẹp, không phải ảnh quét).
    var laLopChuAI: Bool { nenAnhTen != nil && nenPdfTrang == TrangVo.trangLopChuAI }
}

@MainActor
enum LuuVietLai {
    /// Khổ trang đẹp sẽ có: khổ riêng của trang gốc, hoặc khổ của cuốn.
    /// (Trang gốc có nền PDF thì khổ gốc của nó là A4 theo tài liệu — trang
    /// đẹp KHÔNG có nền tài liệu nên theo cuốn.)
    static func khoDich(cho goc: TrangVo) -> CGSize {
        let k = goc.khoGiayRieng.flatMap(KhoGiay.init(rawValue:)) ?? goc.cuon?.kho ?? .a4
        return k.kho(goc.huong)
    }

    /// Giấy của trang đẹp: như trang gốc; trang gốc là PDF/ảnh quét (thường
    /// giấy trơn) thì lấy giấy mặc định của cuốn.
    static func giayDich(cho goc: TrangVo) -> LoaiGiay {
        if goc.coNenTaiLieu && !goc.laLopChuAI {
            return LoaiGiay(rawValue: goc.cuon?.giayMacDinh ?? "") ?? .keNgang
        }
        return goc.giay
    }

    /// Ghi các trang đẹp vào kho. Trả về lượt để hoàn tác, `nil` nếu hỏng.
    static func luu(_ trangs: [TrangChuDep], goc: TrangVo, cach: CachLuuVietLai,
                    muc: UIColor, kho: ModelContext) -> LuotLuuVietLai? {
        guard let cuon = goc.cuon, !trangs.isEmpty else { return nil }
        let khoTrang = khoDich(cho: goc)
        let giay = giayDich(cho: goc)
        // 3× khổ trang (A4 ≈ 1785×2526px) — nét như chữ in khi phóng 3×; trang
        // rất to thì chặn cạnh dài ~3600px cho nhẹ đồng bộ.
        let ty = min(3, 3600 / max(khoTrang.width, khoTrang.height, 1))
        var ds = cuon.trangsTheoThuTu
        guard let viTri = ds.firstIndex(where: { $0.id == goc.id }) else { return nil }
        let tieuDeGoc = goc.tieuDe, tenChuongGoc = goc.tenChuong

        var moi: [TrangVo] = []
        for (so, tr) in trangs.enumerated() {
            let anh = DungChuDep.veAnh(tr, kho: khoTrang, muc: muc, tyLe: ty)
            guard let png = anh.pngData(), let ten = KhoVo.luuAnhNen(png, duoi: "png") else { continue }
            let t = TrangVo(cuon: cuon, thuTu: ds.count, giay: giay, huong: goc.huong)
            t.nenAnhTen = ten
            t.nenPdfTrang = TrangVo.trangLopChuAI
            t.khoGiayRieng = goc.khoGiayRieng
            if let td = tieuDeGoc, !td.isEmpty {
                t.tieuDe = trangs.count > 1 ? "\(td) (\(so + 1))" : td
            }
            // Tìm kiếm: chữ sạch của đúng trang này. Mốc nhận dạng = mốc sửa
            // ⇒ lượt đọc Vision nền không đọc lại (và không đè) cho tới khi
            // người dùng viết thêm lên trang.
            t.chuNhanDang = tr.chu.joined(separator: "\n")
            t.suaLuc = Date()
            t.nhanDangLuc = t.suaLuc
            t.coNet = false
            kho.insert(t)
            KhoVo.dungAnhNho(PKDrawing(), kho: t.khoTrang, khoNen: t.khoGoc, cho: t.id, nenAnhTen: ten)
            moi.append(t)
        }
        guard !moi.isEmpty else { return nil }

        switch cach {
        case .thayTrang:
            ds.insert(contentsOf: moi, at: viTri)
            // Nhãn chương đi theo trang đẹp (mục lục trỏ vào bản sạch); trang
            // gốc mang tên "(bản gốc)" để nhìn dải trang là biết.
            moi[0].tenChuong = tenChuongGoc
            goc.tenChuong = nil
            goc.tieuDe = goc.tenHienThi(so: viTri + 1) + " " + T("(bản gốc)")
            goc.suaLuc = Date()
        case .themSau:
            ds.insert(contentsOf: moi, at: viTri + 1)
        }
        ThaoTacTrang.danhSoLai(ds)
        ThaoTacTrang.danhDauCay(cuon)
        do { try kho.save() } catch {
            NhatKy.vo.error("viết lại: lưu kho hỏng — \(error.localizedDescription)")
        }
        DongBoVo.shared.batDau()
        NhatKy.vo.info("viết lại: lưu \(moi.count) trang (\(cach.rawValue)) · khổ \(Int(khoTrang.width))×\(Int(khoTrang.height)) · giấy \(giay.rawValue)")
        return LuotLuuVietLai(idMoi: moi.map(\.id), idGoc: goc.id, tieuDeGoc: tieuDeGoc,
                              tenChuongGoc: tenChuongGoc, cach: cach)
    }

    /// Hoàn tác một lần lưu: xoá trang đẹp (vào hàng đợi xoá — đã lên mây thì
    /// vào thùng rác 30 ngày), trả tên + nhãn chương cho trang gốc.
    @discardableResult
    static func hoanTac(_ l: LuotLuuVietLai, trongCuon cuon: CuonVo, kho: ModelContext) -> Bool {
        let ds = cuon.trangsTheoThuTu
        let xoa = ds.filter { l.idMoi.contains($0.id) }
        let tepNen = xoa.compactMap(\.nenAnhTen)
        if !xoa.isEmpty {
            guard ThaoTacTrang.xoa(xoa, kho: kho) != nil else { return false }
        }
        if let goc = cuon.trangsTheoThuTu.first(where: { $0.id == l.idGoc }) {
            goc.tieuDe = l.tieuDeGoc
            goc.tenChuong = l.tenChuongGoc
            goc.suaLuc = Date()
            ThaoTacTrang.danhDauCay(cuon)
            try? kho.save()
        }
        // Ảnh lớp chữ không còn trang nào dùng ⇒ dọn (chưa lên mây thì không
        // còn ai cần; đã lên thì máy chủ vẫn giữ bản của nó).
        let conDung = Set(((try? kho.fetch(FetchDescriptor<TrangVo>())) ?? []).compactMap(\.nenAnhTen))
        for t in tepNen where !conDung.contains(t) {
            try? FileManager.default.removeItem(at: KhoVo.duongDanNen(t))
        }
        NhatKy.vo.info("viết lại: hoàn tác — gỡ \(xoa.count) trang đẹp")
        return true
    }
}
#endif
