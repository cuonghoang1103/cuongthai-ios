#if os(iOS)
import Foundation
import SwiftData
import SwiftUI

// MARK: - Vở tự theo học kỳ (23/10/2026)
//
// Nguồn dữ liệu — KHÔNG có bảng mới, KHÔNG đổi @Model:
//   • Môn của kỳ: `GET /hoc-tap/tong-quan` (mã môn, tên, màu, `courseSlug`
//     của khoá Academy cùng mã — máy chủ gắn lúc thêm môn, `themMon`).
//   • Buổi học: `GET /class-schedule?ngay=` (thời khoá biểu theo TUẦN: thứ,
//     giờ, slot, khoảng ngày của kỳ).
//   • Ngày bắt đầu kỳ: `GET /hoc-ky` (kỳ đang học).
//
// "Slot N" trong tên trang = buổi THỨ N của môn trong kỳ — đúng nghĩa "Slot"
// trên đề cương FPT (Slot 1…30), KHÔNG phải khung giờ slot 1–5 của TKB. Đếm từ
// ngày bắt đầu của lịch (hoặc của kỳ) tới ngày buổi đó, mọi buổi của môn.
//
// Nối buổi ↔ trang vở bằng bảng nhỏ trong UserDefaults (khoá "mã|ngày|giờ" ⇒
// id trang), không suy từ tên: người dùng đổi tên trang thì vẫn mở đúng trang.
// Trang tạo LƯỜI: chỉ khi tới giờ học (môn đã có vở) hoặc khi người dùng bấm —
// không tạo hàng loạt trang rác cho cả kỳ.

/// Một môn của kỳ đang học, đã gộp từ Huấn luyện học kỳ + TKB.
struct MonKyNay: Identifiable, Equatable {
    var id: String { maMon }
    var maMon: String
    var ten: String
    var mauHex: Int
    var courseSlug: String?
    var buoi: [BuoiHoc]

    /// "SWT301 · Software Testing" — tên môn trong Vở.
    var tenVo: String {
        let t = ten.trimmingCharacters(in: .whitespaces)
        if t.isEmpty || t.uppercased() == maMon { return maMon }
        return "\(maMon) · \(t)"
    }
}

/// Một buổi học cụ thể (ngày + mục TKB).
struct BuoiVo: Identifiable, Equatable {
    var mon: MonKyNay
    var buoi: BuoiHoc
    var ngay: Date
    /// Buổi thứ mấy của môn trong kỳ. `nil` = không biết ngày bắt đầu kỳ.
    var soSlot: Int?
    var chuDe: String?

    var id: String { khoa }
    var khoa: String { "\(mon.maMon)|\(PhamViViec.dinhDang.string(from: ngay))|\(buoi.startTime)" }

    /// "Slot 3 · 21/10 · Black-box testing"
    var tieuDeTrang: String {
        let f = DateFormatter(); f.dateFormat = "dd/MM"
        var s = soSlot.map { "Slot \($0)" } ?? T("Buổi")
        s += " · " + f.string(from: ngay)
        if let c = chuDe?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
            s += " · " + String(c.prefix(48))
        }
        return s
    }

    /// Đang học (từ 10 phút trước giờ vào tới giờ tan) — lúc trang tự tạo.
    func dangDienRa(_ bayGio: Date = Date()) -> Bool {
        guard Calendar.current.isDate(ngay, inSameDayAs: bayGio) else { return false }
        let c = Calendar.current
        let p = c.component(.hour, from: bayGio) * 60 + c.component(.minute, from: bayGio)
        return p >= buoi.phutBatDau - 10 && p <= buoi.phutKetThuc
    }

    func daQua(_ bayGio: Date = Date()) -> Bool {
        let c = Calendar.current
        let p = c.component(.hour, from: bayGio) * 60 + c.component(.minute, from: bayGio)
        return p > buoi.phutKetThuc
    }
}

// MARK: - Bộ não (thuần, không giao diện)

@MainActor
enum VoHocKy {

    // MARK: Lưu nối

    private static let khoaMon = "vo.hocky.mon"        // maMon ⇒ MonVo.id
    private static let khoaTrang = "vo.hocky.trang"    // khoá buổi / bài ⇒ TrangVo.id
    private static let khoaKhoa = "vo.hocky.khoa"      // maMon ⇒ courseSlug
    private static let khoaBaiCuaTrang = "vo.bai.trang" // TrangVo.id ⇒ "slug|lessonId"

    private static func doc(_ k: String) -> [String: String] {
        (UserDefaults.standard.dictionary(forKey: k) as? [String: String]) ?? [:]
    }
    private static func ghi(_ k: String, _ khoa: String, _ v: String?) {
        var d = doc(k)
        d[khoa] = v
        UserDefaults.standard.set(d, forKey: k)
    }

    // MARK: Mã môn

    /// Mã môn FPT trong một chuỗi: 3 chữ + 3 số (+ 1 chữ thường tuỳ chọn) —
    /// "SWT301", "JPD123", "MAE101c". KHÔNG khớp mã lớp "SE1801" (4 số).
    static func maMon(trong s: String) -> String? {
        let re = try? NSRegularExpression(pattern: "(?<![A-Za-z0-9])([A-Za-z]{3}[0-9]{3})(?![0-9])")
        let r = NSRange(s.startIndex..., in: s)
        guard let m = re?.firstMatch(in: s, range: r), let rr = Range(m.range(at: 1), in: s) else { return nil }
        return String(s[rr]).uppercased()
    }

    static func emoji(choMa ma: String) -> String {
        let bang: [String: String] = [
            "SWT": "🧪", "SWR": "📐", "SWP": "🛠️", "SWD": "🏗️", "SWE": "💻", "PRJ": "☕",
            "PRO": "☕", "PRF": "🐍", "FER": "⚛️", "WED": "🌐", "CSD": "🧮", "DBI": "🗄️",
            "JPD": "🇯🇵", "CHN": "🇨🇳", "ENW": "🇬🇧", "SSL": "🗣️", "SSG": "🗣️", "MAE": "📈",
            "MAD": "🔢", "MAS": "📊", "CSI": "🖥️", "OSG": "🐧", "NWC": "🌐", "IOT": "🔌",
            "LAB": "🧑‍💻", "PRM": "📱", "MLN": "📕", "VNR": "📜", "HCM": "📗", "EXE": "🚀",
        ]
        return bang[String(ma.prefix(3))] ?? "📘"
    }

    private static let bangMau: [Int] = [0x6366F1, 0xEC4899, 0xF59E0B, 0x10B981, 0x06B6D4, 0xEF4444, 0x8B5CF6, 0x84CC16]

    static func hex(_ s: String?) -> Int? {
        guard var h = s?.trimmingCharacters(in: .whitespaces), !h.isEmpty else { return nil }
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let v = Int(h, radix: 16) else { return nil }
        return v
    }

    // MARK: Gộp môn của kỳ

    static func gopMon(tongQuan: TongQuanHT?, lich: [BuoiHoc]) -> [MonKyNay] {
        var ds: [String: MonKyNay] = [:]
        var thuTu: [String] = []
        for (i, m) in (tongQuan?.mon ?? []).enumerated() {
            let ma = m.maMon.uppercased()
            ds[ma] = MonKyNay(maMon: ma, ten: m.ten, mauHex: hex(m.mau) ?? bangMau[i % bangMau.count],
                              courseSlug: m.courseSlug, buoi: [])
            thuTu.append(ma)
        }
        for b in lich {
            guard let ma = maMon(trong: b.subject) ?? b.classCode.flatMap({ maMon(trong: $0) }) else { continue }
            if ds[ma] == nil {
                // Tên môn = phần còn lại sau khi bỏ mã ("SWT301 - Software Testing").
                var ten = b.subject.replacingOccurrences(of: ma, with: "", options: .caseInsensitive)
                ten = ten.trimmingCharacters(in: CharacterSet(charactersIn: " -–·:|()[]"))
                ds[ma] = MonKyNay(maMon: ma, ten: ten, mauHex: hex(b.color) ?? bangMau[thuTu.count % bangMau.count],
                                  courseSlug: nil, buoi: [])
                thuTu.append(ma)
            }
            ds[ma]?.buoi.append(b)
        }
        for (ma, m) in ds { if let s = m.courseSlug { ghi(khoaKhoa, ma, s) } }
        return thuTu.compactMap { ds[$0] }
    }

    // MARK: Đếm slot

    private static var lich: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }

    private static func ngay(_ s: String?) -> Date? {
        guard let s, s.count >= 10 else { return nil }
        return PhamViViec.dinhDang.date(from: String(s.prefix(10)))
    }

    /// Buổi THỨ mấy của môn tính tới `buoi` ngày `vao` (kể cả nó).
    static func soSlot(_ buoi: BuoiHoc, vao: Date, cacBuoi: [BuoiHoc], batDauKy: Date?) -> Int? {
        let l = lich
        let cuoi = l.startOfDay(for: vao)
        let goc = cacBuoi.compactMap { ngay($0.startDate) }.min() ?? batDauKy
        guard let goc0 = goc else { return nil }
        var d = l.startOfDay(for: goc0)
        guard d <= cuoi else { return nil }
        var dem = 0
        var buocDi = 0
        while d <= cuoi && buocDi < 400 {
            let thu = BuoiHoc.thuViet(tuLich: l.component(.weekday, from: d))
            let trongNgay = cacBuoi.filter { b in
                guard b.weekday == thu else { return false }
                if let a = ngay(b.startDate), d < l.startOfDay(for: a) { return false }
                if let z = ngay(b.endDate), d > l.startOfDay(for: z) { return false }
                return true
            }.sorted { $0.phutBatDau < $1.phutBatDau }
            for b in trongNgay {
                dem += 1
                if d == cuoi && b.id == buoi.id { return dem }
            }
            d = l.date(byAdding: .day, value: 1, to: d) ?? d.addingTimeInterval(86_400)
            buocDi += 1
        }
        return nil
    }

    /// Buổi của mọi môn trong ngày `vao`, xếp theo giờ.
    static func buoiTrongNgay(_ mons: [MonKyNay], vao: Date, batDauKy: Date?, tongQuan: TongQuanHT?) -> [BuoiVo] {
        let l = lich
        let thu = BuoiHoc.thuViet(tuLich: l.component(.weekday, from: vao))
        let ymd = PhamViViec.dinhDang.string(from: vao)
        var ra: [BuoiVo] = []
        for m in mons {
            for b in m.buoi where b.weekday == thu {
                if let a = ngay(b.startDate), l.startOfDay(for: vao) < l.startOfDay(for: a) { continue }
                if let z = ngay(b.endDate), l.startOfDay(for: vao) > l.startOfDay(for: z) { continue }
                // Chủ đề: việc của môn đặt cho đúng ngày này trong Huấn luyện học kỳ.
                let chuDe = (tongQuan?.lich ?? []).first { $0.ngay.prefix(10) == ymd }?
                    .viec.first { $0.maMon.uppercased() == m.maMon }?.tieuDe
                ra.append(BuoiVo(mon: m, buoi: b, ngay: l.startOfDay(for: vao),
                                 soSlot: soSlot(b, vao: vao, cacBuoi: m.buoi, batDauKy: batDauKy),
                                 chuDe: chuDe))
            }
        }
        return ra.sorted { $0.buoi.phutBatDau < $1.buoi.phutBatDau }
    }

    // MARK: Môn ↔ vở

    /// Vở (môn) của một mã môn, nếu đã có: theo bảng nối, không thì theo tên
    /// bắt đầu bằng mã ("SWT301 · …").
    static func monVo(cho ma: String, kho: ModelContext) -> MonVo? {
        let mons = (try? kho.fetch(FetchDescriptor<MonVo>())) ?? []
        if let s = doc(khoaMon)[ma], let id = UUID(uuidString: s), let m = mons.first(where: { $0.id == id }) {
            return m
        }
        if let m = mons.first(where: { maMon(trong: $0.ten) == ma }) {
            ghi(khoaMon, ma, m.id.uuidString)
            return m
        }
        return nil
    }

    /// Mã môn của một cuốn (để nối sang Academy).
    static func maMon(cuaCuon c: CuonVo) -> String? {
        guard let m = c.mon else { return nil }
        if let ma = doc(khoaMon).first(where: { $0.value == m.id.uuidString })?.key { return ma }
        return maMon(trong: m.ten)
    }

    /// Khoá Academy của môn chứa cuốn này (nếu Huấn luyện học kỳ đã gắn).
    static func courseSlug(cho c: CuonVo) -> String? {
        guard let ma = maMon(cuaCuon: c) else { return nil }
        return doc(khoaKhoa)[ma]
    }

    /// Bài Academy của một trang tạo từ "ghi khi học" (`trangChoBaiHoc`).
    static func baiCuaTrang(_ t: TrangVo) -> (slug: String, lessonId: Int)? {
        guard let s = doc(khoaBaiCuaTrang)[t.id.uuidString] else { return nil }
        let p = s.split(separator: "|")
        guard p.count == 2, let id = Int(p[1]) else { return nil }
        return (String(p[0]), id)
    }

    /// Lập vở cho một môn của kỳ: Môn "SWT301 · Software Testing" (màu, emoji
    /// riêng) + một cuốn mang tên kỳ. Đã có thì trả cái đang có.
    @discardableResult
    static func lapVo(_ m: MonKyNay, tenKy: String?, kho: ModelContext) -> (MonVo, CuonVo) {
        let mon: MonVo
        if let co = monVo(cho: m.maMon, kho: kho) {
            mon = co
        } else {
            let thuTu = ((try? kho.fetch(FetchDescriptor<MonVo>()))?.map(\.thuTu).max() ?? 0) + 1
            mon = MonVo(ten: m.tenVo, emoji: emoji(choMa: m.maMon), mauHex: m.mauHex, thuTu: thuTu)
            kho.insert(mon)
            ghi(khoaMon, m.maMon, mon.id.uuidString)
        }
        if let s = m.courseSlug { ghi(khoaKhoa, m.maMon, s) }
        let ten = (tenKy?.trimmingCharacters(in: .whitespaces)).flatMap { $0.isEmpty ? nil : $0 } ?? T("Kỳ này")
        if let c = mon.cuonsTheoThuTu.first(where: { $0.ten == ten }) ?? mon.cuonsTheoThuTu.first {
            return (mon, c)
        }
        let c = CuonVo(ten: ten, mon: mon, mauBiaHex: m.mauHex, giay: .keNgang, huong: .doc,
                       thuTu: (mon.cuonsTheoThuTu.map(\.thuTu).max() ?? 0) + 1)
        kho.insert(c)
        // Vở mới có sẵn một trang (đúng như "Lập cuốn vở" ở màn Môn) — trang
        // đầu tiên này sẽ được dùng lại cho buổi đầu tiên người dùng mở.
        kho.insert(TrangVo(cuon: c, thuTu: 0, giay: .keNgang, huong: .doc))
        try? kho.save()
        DongBoVo.shared.batDau()
        return (mon, c)
    }

    /// Trang của một buổi: có rồi thì trả, chưa có thì tạo (ở cuối cuốn kỳ này,
    /// đặt tên "Slot N · dd/MM · chủ đề"). Môn chưa có vở thì lập luôn — chỉ
    /// gọi khi NGƯỜI DÙNG bấm; lượt tự tạo dùng `taoNeuDangHoc`.
    @discardableResult
    static func trangChoBuoi(_ b: BuoiVo, tenKy: String?, kho: ModelContext) -> (CuonVo, TrangVo) {
        let (_, cuon) = lapVo(b.mon, tenKy: tenKy, kho: kho)
        return trang(khoa: b.khoa, tieuDe: b.tieuDeTrang, trongCuon: cuon, kho: kho)
    }

    /// Trang đã gắn với khoá (buổi/bài), hoặc tạo mới ở cuối `cuon`.
    private static func trang(khoa: String, tieuDe: String, trongCuon cuon: CuonVo,
                              kho: ModelContext) -> (CuonVo, TrangVo) {
        let tatCa = (try? kho.fetch(FetchDescriptor<TrangVo>())) ?? []
        if let s = doc(khoaTrang)[khoa], let id = UUID(uuidString: s),
           let t = tatCa.first(where: { $0.id == id }), let c = t.cuon {
            return (c, t)
        }
        // Cuốn mới tinh còn đúng MỘT trang trắng chưa đặt tên ⇒ dùng luôn,
        // khỏi để lại một trang trống đứng đầu cuốn.
        let ds = cuon.trangsTheoThuTu
        let t: TrangVo
        if ds.count == 1, let dau = ds.first, dau.tieuDe == nil, !dau.coNet,
           dau.nenPdfTen == nil, dau.nenAnhTen == nil, !doc(khoaTrang).values.contains(dau.id.uuidString) {
            t = dau
        } else {
            t = ThaoTacTrang.chenTrangTrang(vao: cuon, viTri: ds.count,
                                            giay: LoaiGiay(rawValue: cuon.giayMacDinh) ?? .keNgang,
                                            huong: HuongGiay(rawValue: cuon.huongMacDinh) ?? .doc, kho: kho)
        }
        ThaoTacTrang.doiTen(t, thanh: tieuDe, kho: kho)
        cuon.trangDangDoc = cuon.trangsTheoThuTu.firstIndex { $0.id == t.id } ?? cuon.trangDangDoc
        ghi(khoaTrang, khoa, t.id.uuidString)
        try? kho.save()
        DongBoVo.shared.batDau()
        return (cuon, t)
    }

    /// Trang của buổi đã từng tạo chưa (để hiện "Mở trang" thay vì "Tạo trang").
    static func daCoTrang(_ b: BuoiVo, kho: ModelContext) -> TrangVo? {
        guard let s = doc(khoaTrang)[b.khoa], let id = UUID(uuidString: s) else { return nil }
        return ((try? kho.fetch(FetchDescriptor<TrangVo>(predicate: #Predicate { $0.id == id }))) ?? []).first
    }

    /// "Tạo khi tới buổi": buổi đang diễn ra mà môn ĐÃ có vở (người dùng đã
    /// chọn ghi môn này) ⇒ tạo sẵn trang. Môn chưa lập vở thì KHÔNG tự tạo.
    @discardableResult
    static func taoNeuDangHoc(_ ds: [BuoiVo], tenKy: String?, kho: ModelContext) -> Int {
        var n = 0
        for b in ds where b.dangDienRa() && daCoTrang(b, kho: kho) == nil {
            guard monVo(cho: b.mon.maMon, kho: kho) != nil else { continue }
            trangChoBuoi(b, tenKy: tenKy, kho: kho)
            n += 1
        }
        return n
    }

    // MARK: - API cho "ghi nhanh khi học" (màn học Academy)

    /// Trang Vở của MỘT bài học Academy — có rồi thì trả, chưa có thì tạo.
    ///
    /// Môn theo mã (`maMon`, vd "SWT301"); chưa có vở môn đó thì lập (tên
    /// "SWT301 · <tenMon>"). Trang nằm trong cuốn "Ghi khi học" của môn, tên
    /// trang = tên bài. Gọi lại với cùng `courseSlug` + `lessonId` ⇒ cùng trang.
    ///
    /// ```swift
    /// let (cuon, trang) = VoHocKy.trangChoBaiHoc(maMon: "SWT301", tenMon: "Software Testing",
    ///     courseSlug: "software-testing", lessonId: 446, tieuDeBai: "1.1 — What is testing?", kho: kho)
    /// // rồi: ManVietView(cuon: cuon, moTrang: trang.id) — hoặc dùng sẵn `TrangVoNhanh`.
    /// ```
    @discardableResult
    static func trangChoBaiHoc(maMon: String, tenMon: String, courseSlug: String?, lessonId: Int,
                               tieuDeBai: String, kho: ModelContext) -> (CuonVo, TrangVo) {
        let ma = maMon.uppercased()
        let m = MonKyNay(maMon: ma, ten: tenMon, mauHex: bangMau[ma.unicodeScalars.reduce(0) { $0 + Int($1.value) } % bangMau.count],
                         courseSlug: courseSlug, buoi: [])
        let (mon, _) = lapVo(m, tenKy: nil, kho: kho)
        let tenCuon = T("Ghi khi học")
        let cuon: CuonVo
        if let c = mon.cuonsTheoThuTu.first(where: { $0.ten == tenCuon }) {
            cuon = c
        } else {
            cuon = CuonVo(ten: tenCuon, mon: mon, mauBiaHex: mon.mauHex, giay: .cornell, huong: .doc,
                          thuTu: (mon.cuonsTheoThuTu.map(\.thuTu).max() ?? 0) + 1)
            kho.insert(cuon)
            try? kho.save()
        }
        let khoa = "bai|\(courseSlug ?? ma)|\(lessonId)"
        let kq = trang(khoa: khoa, tieuDe: String(tieuDeBai.prefix(120)), trongCuon: cuon, kho: kho)
        if let s = courseSlug { ghi(khoaBaiCuaTrang, kq.1.id.uuidString, "\(s)|\(lessonId)") }
        return kq
    }
}

// MARK: - VM nạp dữ liệu kỳ

@MainActor
final class VoHocKyVM: ObservableObject {
    @Published private(set) var mons: [MonKyNay] = []
    @Published private(set) var homNay: [BuoiVo] = []
    @Published private(set) var tenKy: String?
    @Published private(set) var daNap = false
    @Published var loi: String?

    private var tongQuan: TongQuanHT?
    private var batDauKy: Date?

    func nap() async {
        async let tq: TongQuanHT? = try? APIClient.shared.request(.hocTapTongQuan)
        async let lh: DapAnLichHoc? = try? APIClient.shared.request(.lichHoc(ngay: PhamViViec.today.moc()))
        async let hk: DapAnHocKy? = try? APIClient.shared.request(.dsHocKy)
        let (a, b, c) = await (tq, lh, hk)
        tongQuan = a
        let ky = c?.items.first(where: \.dangHoc) ?? c?.items.first
        batDauKy = ky?.ngayBatDau
        tenKy = a?.hocKy?.ten ?? ky?.ten
        mons = VoHocKy.gopMon(tongQuan: a, lich: b?.items ?? [])
        homNay = VoHocKy.buoiTrongNgay(mons, vao: Date(), batDauKy: batDauKy, tongQuan: a)
        daNap = true
    }

    #if DEBUG
    /// Dữ liệu mẫu cho bàn thử (`CT_VO_HOCKY=mau`): 3 môn, buổi hôm nay có một
    /// buổi ĐANG học (giờ đặt quanh giờ máy) để chụp được trạng thái "Đang học".
    func napMau() {
        let c = Calendar.current, bay = Date()
        let thu = BuoiHoc.thuViet(tuLich: c.component(.weekday, from: bay))
        let p = c.component(.hour, from: bay) * 60 + c.component(.minute, from: bay)
        func gio(_ m: Int) -> String { String(format: "%02d:%02d", max(0, min(23, m / 60)), m % 60) }
        let batDau = c.date(byAdding: .day, value: -24, to: bay)!
        let bd = PhamViViec.dinhDang.string(from: batDau)
        func buoi(_ id: Int, _ mon: String, _ t: Int, _ a: Int, _ b: Int) -> BuoiHoc {
            BuoiHoc(id: id, subject: mon, classCode: "SE1912", teacher: nil, room: "BE-301", weekday: t,
                    startTime: gio(a), endTime: gio(b), color: nil, note: nil, remindMinutes: 30,
                    startDate: bd, endDate: nil, slot: 2, meetUrl: nil, materialsUrl: nil)
        }
        let lich = [
            buoi(1, "SWT301 - Software Testing", thu, p - 30, p + 110),
            buoi(2, "SWT301 - Software Testing", thu == 8 ? 3 : thu + 1, 450, 590),
            buoi(3, "SWR302 - Software Requirement", thu, p + 130, p + 270),
            buoi(4, "PRJ301 - Java Web", thu == 2 ? 4 : 2, 770, 910),
        ]
        mons = VoHocKy.gopMon(tongQuan: nil, lich: lich)
        mons = mons.map { m in var m = m; if m.maMon == "SWT301" { m.courseSlug = "software-testing" }; return m }
        tenKy = "Fall 2026"
        batDauKy = batDau
        homNay = VoHocKy.buoiTrongNgay(mons, vao: bay, batDauKy: batDau, tongQuan: nil)
        if let i = homNay.firstIndex(where: { $0.mon.maMon == "SWT301" }) { homNay[i].chuDe = "Black-box testing" }
        daNap = true
    }
    #endif

    /// Buổi nên mời mở ngay: đang học > sắp học > buổi vừa tan gần nhất.
    var buoiNoiBat: BuoiVo? {
        homNay.first { $0.dangDienRa() } ?? homNay.first { !$0.daQua() } ?? homNay.last
    }
}

// MARK: - Dải "Hôm nay" trên màn Vở

struct DaiHomNayVo: View {
    @ObservedObject var vm: VoHocKyVM
    let soTheCanOn: Int
    let moBuoi: (BuoiVo) -> Void
    let moOnThe: () -> Void
    let moGoiY: () -> Void
    @Environment(\.modelContext) private var kho

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(vm.homNay) { b in theBuoi(b) }
                    if soTheCanOn > 0 {
                        Button(action: moOnThe) {
                            HStack(spacing: 8) {
                                Image(systemName: "rectangle.stack.fill").font(.system(size: 17))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(String(format: T("%d thẻ cần ôn"), soTheCanOn))
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(T("Ôn thẻ hôm nay")).font(.system(size: 11.5)).opacity(0.8)
                                }
                            }
                            .foregroundStyle(AppColors.onPrimary)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(LinearGradient(colors: [AppColors.secondary, AppColors.secondary.opacity(0.75)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing)))
                        }
                        .buttonStyle(.plain)
                    }
                    if !vm.mons.isEmpty {
                        Button(action: moGoiY) {
                            Label(T("Môn kỳ này"), systemImage: "graduationcap")
                                .font(.system(size: 13.5, weight: .semibold))
                                .padding(.horizontal, 14).padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(AppColors.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppColors.textPrimary)
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
        }
    }

    private func theBuoi(_ b: BuoiVo) -> some View {
        let dang = b.dangDienRa()
        let co = VoHocKy.daCoTrang(b, kho: kho) != nil
        let mau = Color(hex: UInt32(b.mon.mauHex))
        return Button { moBuoi(b) } label: {
            HStack(spacing: 10) {
                Text(VoHocKy.emoji(choMa: b.mon.maMon)).font(.system(size: 24))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(dang ? T("Đang học") : (b.daQua() ? T("Hôm nay · đã học") : T("Hôm nay")))
                            .font(.system(size: 10.5, weight: .heavy))
                            .foregroundStyle(dang ? AppColors.onPrimary : mau)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(dang ? mau : mau.opacity(0.14)))
                        Text("\(b.buoi.startTime)–\(b.buoi.endTime)")
                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                            .foregroundStyle(AppColors.textTertiary)
                    }
                    Text("\(b.mon.maMon) · \(b.soSlot.map { "Slot \($0)" } ?? T("Buổi học"))")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(co ? T("Mở trang ghi của buổi →") : T("Ghi buổi này →"))
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(minWidth: 230, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppColors.backgroundCard))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(mau).frame(width: 4).padding(.vertical, 10)
            }
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(dang ? mau.opacity(0.6) : AppColors.border.opacity(0.6), lineWidth: dang ? 1.5 : 1))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(b.mon.tenVo), \(b.tieuDeTrang)")
    }
}

// MARK: - Cửa sổ "Môn kỳ này"

struct GoiYMonKyNayView: View {
    @ObservedObject var vm: VoHocKyVM
    @Environment(\.modelContext) private var kho
    @Environment(\.dismiss) private var dong
    @State private var chon: Set<String> = []
    @State private var daLap: Set<String> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(vm.mons) { m in
                        let co = daLap.contains(m.maMon)
                        Button {
                            guard !co else { return }
                            if chon.contains(m.maMon) { chon.remove(m.maMon) } else { chon.insert(m.maMon) }
                        } label: {
                            HStack(spacing: Spacing.md) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color(hex: UInt32(m.mauHex)))
                                        .frame(width: 38, height: 48)
                                    Text(VoHocKy.emoji(choMa: m.maMon)).font(.system(size: 20))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(m.tenVo).font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(AppColors.textPrimary)
                                    Text(moTa(m)).font(.system(size: 12)).foregroundStyle(AppColors.textTertiary)
                                }
                                Spacer()
                                if co {
                                    Label(T("Đã có vở"), systemImage: "checkmark.seal.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(AppColors.success)
                                } else {
                                    Image(systemName: chon.contains(m.maMon) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundStyle(chon.contains(m.maMon) ? AppColors.primary : AppColors.textTertiary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(vm.tenKy.map { String(format: T("Môn của %@"), $0) } ?? T("Môn kỳ này"))
                } footer: {
                    Text(T("Mỗi môn thành một môn trong Vở (mã + tên, màu riêng) với một cuốn cho kỳ này. Trang của từng buổi được tạo khi tới giờ học hoặc khi bạn bấm vào buổi đó — không tạo sẵn cả kỳ."))
                }
            }
            .navigationTitle(T("Vở theo học kỳ"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Đóng")) { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(chon.isEmpty ? T("Lập vở") : String(format: T("Lập %d vở"), chon.count)) { lap() }
                        .fontWeight(.semibold)
                        .disabled(chon.isEmpty)
                }
            }
            .onAppear {
                daLap = Set(vm.mons.filter { VoHocKy.monVo(cho: $0.maMon, kho: kho) != nil }.map(\.maMon))
                chon = Set(vm.mons.map(\.maMon)).subtracting(daLap)
            }
        }
    }

    private func moTa(_ m: MonKyNay) -> String {
        let soBuoi = m.buoi.count
        var s = soBuoi == 0 ? T("Chưa có trong thời khoá biểu")
                            : String(format: T("%d buổi mỗi tuần"), soBuoi)
        if m.courseSlug != nil { s += " · " + T("có khoá Academy") }
        return s
    }

    private func lap() {
        for m in vm.mons where chon.contains(m.maMon) {
            VoHocKy.lapVo(m, tenKy: vm.tenKy, kho: kho)
        }
        Haptics.xong()
        dong()
    }
}

// MARK: - Trang Vở nhanh (cho "ghi nhanh khi học")

/// Mở trang Vở của một bài Academy, dựng sẵn nếu chưa có — để màn học bày nửa
/// màn hình (sheet `.presentationDetents([.medium, .large])` hoặc cột bên).
///
/// ```swift
/// .sheet(isPresented: $ghiNhanh) {
///     TrangVoNhanh(maMon: "SWT301", tenMon: "Software Testing",
///                  courseSlug: "software-testing", lessonId: 446, tieuDeBai: bai.title)
///         .presentationDetents([.medium, .large])
/// }
/// ```
/// Kho SwiftData lấy từ môi trường — chỗ gọi phải nằm dưới
/// `.modelContainer(KhoSwiftData.chung)` như màn Vở.
struct TrangVoNhanh: View {
    let maMon: String
    let tenMon: String
    let courseSlug: String?
    let lessonId: Int
    let tieuDeBai: String
    @Environment(\.modelContext) private var kho
    @State private var mo: (CuonVo, UUID)?

    var body: some View {
        Group {
            if let mo {
                ManVietView(cuon: mo.0, moTrang: mo.1)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            guard mo == nil else { return }
            DongBoVo.shared.gan(kho: kho)
            let (c, t) = VoHocKy.trangChoBaiHoc(maMon: maMon, tenMon: tenMon, courseSlug: courseSlug,
                                                lessonId: lessonId, tieuDeBai: tieuDeBai, kho: kho)
            mo = (c, t.id)
        }
    }
}
#endif
