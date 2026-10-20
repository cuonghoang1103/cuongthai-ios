import XCTest
@testable import CTWork

/// Kiểm thử bản dịch + đổi ngôn ngữ (20/10/2026).
///
/// · Mọi khoá trong catalog của app / widget / Share Extension / InfoPlist phải có bản `vi` đã dịch.
/// · Bản dịch phải giữ ĐÚNG các đặc tả định dạng của khoá (`%@`, `%lld`, `%1$@`…) — lệch là app sập lúc
///   `String(format:)` hoặc in sai số (vd khoá `%lld` mà bản dịch `%@`).
/// · Đổi ngôn ngữ trong app ⇒ `String(localized:)` đổi NGAY (Bundle.main đã tráo).
///
/// Catalog đọc thẳng từ mã nguồn (`#filePath`) — máy mô phỏng đọc được đĩa của máy Mac.
final class NgonNguCTWTests: XCTestCase {
    /// Trả lại tiếng Anh trong bộ nhớ cho các bộ kiểm chạy sau (xem KhoiDongKiemThuCTW).
    override func tearDown() {
        KhoiDongKiemThuCTW.veTiengAnh()
        super.tearDown()
    }

    private var goc: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private func docCatalog(_ duongDan: String) throws -> [String: Any] {
        let d = try Data(contentsOf: goc.appendingPathComponent(duongDan))
        let j = try XCTUnwrap(JSONSerialization.jsonObject(with: d) as? [String: Any])
        XCTAssertEqual(j["sourceLanguage"] as? String, "en", duongDan)
        return try XCTUnwrap(j["strings"] as? [String: Any])
    }

    /// Đặc tả định dạng trong một chuỗi, chuẩn hoá: `%1$@` ⇒ (1,"@"), `%lld` ⇒ (thứ tự, "lld"). `%%` bỏ qua.
    static func dacTa(_ s: String) -> [String] {
        let re = try! NSRegularExpression(pattern: #"%(?:(\d+)\$)?[-+#0']*\d*(?:\.\d+)?(hh|h|ll|l|q|z|t|j|L)?([@dDuUxXoOfFeEgGcCsSpaAi%])"#)
        var kq: [String] = []
        var thuTu = 0
        let ns = s as NSString
        for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            let loai = ns.substring(with: m.range(at: 3))
            if loai == "%" { continue }
            thuTu += 1
            let viTri = m.range(at: 1).location != NSNotFound ? Int(ns.substring(with: m.range(at: 1)))! : thuTu
            let dai = m.range(at: 2).location != NSNotFound ? ns.substring(with: m.range(at: 2)) : ""
            // %d và %lld đều là số nguyên; %@ là đối tượng — đổi nhóm là lỗi.
            let nhom: String
            switch loai {
            case "@": nhom = "@"
            case "d", "D", "i", "u", "U", "x", "X", "o", "O", "c", "C": nhom = "int\(dai == "ll" || dai == "q" || dai == "l" || dai == "z" || dai == "t" || dai == "j" ? "64" : "")"
            case "f", "F", "e", "E", "g", "G", "a", "A": nhom = "float"
            default: nhom = loai
            }
            kq.append("\(viTri):\(nhom)")
        }
        return kq.sorted()
    }

    /// Mọi chuỗi dịch của một mục (stringUnit hoặc biến thể số nhiều/thiết bị).
    private func chuoiDich(_ loc: [String: Any]) -> [String] {
        var ds: [String] = []
        if let su = loc["stringUnit"] as? [String: Any], let v = su["value"] as? String { ds.append(v) }
        if let bt = loc["variations"] as? [String: Any] {
            for (_, nhom) in bt {
                for (_, muc) in (nhom as? [String: Any]) ?? [:] { ds += chuoiDich((muc as? [String: Any]) ?? [:]) }
            }
        }
        return ds
    }

    private func kiemCatalog(_ duongDan: String, kiemDinhDang: Bool = true) throws {
        let ds = try docCatalog(duongDan)
        XCTAssertFalse(ds.isEmpty, duongDan)
        var thieu: [String] = []
        var lech: [String] = []
        for (khoa, giaTri) in ds {
            let muc = (giaTri as? [String: Any]) ?? [:]
            if muc["shouldTranslate"] as? Bool == false { continue }
            if muc["extractionState"] as? String == "stale" { continue }
            let locs = (muc["localizations"] as? [String: Any]) ?? [:]
            guard let vi = locs["vi"] as? [String: Any] else { thieu.append(khoa); continue }
            let cacBan = chuoiDich(vi)
            if cacBan.isEmpty || cacBan.contains(where: { $0.trimmingCharacters(in: .whitespaces).isEmpty && !khoa.trimmingCharacters(in: .whitespaces).isEmpty }) {
                thieu.append(khoa); continue
            }
            if let su = vi["stringUnit"] as? [String: Any], let tt = su["state"] as? String, tt != "translated" {
                thieu.append(khoa); continue
            }
            guard kiemDinhDang else { continue }
            // Nguồn: bản en riêng (nếu có) hoặc chính khoá.
            let nguon = ((locs["en"] as? [String: Any]).flatMap { chuoiDich($0).first }) ?? khoa
            let can = Self.dacTa(nguon)
            for b in cacBan where Self.dacTa(b) != can && vi["variations"] == nil {
                lech.append("\(khoa) ⇒ \(b)")
            }
        }
        XCTAssertTrue(thieu.isEmpty, "\(duongDan): \(thieu.count) khoá thiếu bản vi:\n" + thieu.sorted().prefix(40).joined(separator: "\n"))
        XCTAssertTrue(lech.isEmpty, "\(duongDan): đặc tả định dạng lệch:\n" + lech.sorted().prefix(40).joined(separator: "\n"))
    }

    func testCatalogAppDuBanViVaDungDinhDang() throws { try kiemCatalog("CTWorkApp/Localizable.xcstrings") }
    func testCatalogWidgetDuBanVi() throws { try kiemCatalog("CTWorkWidget/Localizable.xcstrings") }
    func testCatalogShareDuBanVi() throws { try kiemCatalog("CTWorkShare/Localizable.xcstrings") }
    func testCatalogInfoPlistDuBanVi() throws { try kiemCatalog("CTWorkApp/InfoPlist.xcstrings", kiemDinhDang: false) }
    func testCatalogMaTrangThaiDuBanVi() throws { try kiemCatalog("CTWorkApp/TrangThaiCTW.xcstrings", kiemDinhDang: false) }

    /// Mã trạng thái máy chủ ⇒ nhãn theo ngôn ngữ; mã lạ ⇒ chữ tự dựng (không bao giờ lộ "IN_REVIEW").
    func testNhanMaTrangThaiTheoNgonNgu() {
        let cu = NgonNguCTW.cheDo
        defer { NgonNguCTW.dat(cu) }
        NgonNguCTW.dat(.vi)
        XCTAssertEqual(CTWMauTrangThai.nhan("IN_REVIEW"), "Đang review")
        XCTAssertEqual(CTWMauTrangThai.nhan("SOMETHING_NEW"), "Something new")
        NgonNguCTW.dat(.en)
        XCTAssertEqual(CTWMauTrangThai.nhan("IN_REVIEW"), "In review")
        XCTAssertEqual(CTWMauTrangThai.nhan("SOMETHING_NEW"), "Something new")
    }

    func testBoKiemDacTaBatDuocLech() {
        XCTAssertEqual(Self.dacTa("%lld issues"), Self.dacTa("%lld thẻ"))
        XCTAssertNotEqual(Self.dacTa("%lld issues"), Self.dacTa("%@ thẻ"))
        XCTAssertEqual(Self.dacTa("%1$@ assigned %2$@"), Self.dacTa("%2$@ được %1$@ giao"))
        XCTAssertNotEqual(Self.dacTa("%@ and %@"), Self.dacTa("%@"))
        XCTAssertEqual(Self.dacTa("100%% done"), Self.dacTa("Xong 100%%"))
    }

    /// Đổi ngôn ngữ trong app ⇒ chuỗi đổi ngay, không khởi động lại; trả lại lựa chọn cũ khi xong.
    func testDoiNgonNguApDungNgay() throws {
        let cu = NgonNguCTW.cheDo
        defer { NgonNguCTW.dat(cu) }
        NgonNguCTW.dat(.vi); CTWDinhDang.locale = NgonNguCTW.locale
        XCTAssertEqual(NgonNguCTW.ma, "vi")
        XCTAssertEqual(String(localized: "Account"), "Tài khoản")
        XCTAssertEqual(NSLocalizedString("Account", comment: ""), "Tài khoản")
        XCTAssertEqual(String(localized: "\(3) open issues"), "3 thẻ mở", "chuỗi có nội suy")
        XCTAssertEqual(CTWModule.dich("Project"), "Dự án")
        NgonNguCTW.dat(.en); CTWDinhDang.locale = NgonNguCTW.locale
        XCTAssertEqual(NgonNguCTW.ma, "en")
        XCTAssertEqual(String(localized: "Account"), "Account", "en: bảng nguồn bị Xcode bỏ — phải trả khoá, không rơi về vi")
        XCTAssertEqual(UserDefaults.standard.array(forKey: "AppleLanguages") as? [String], ["en"])
    }

    func testNgayTheoNgonNgu() {
        var c = DateComponents(); c.year = 2026; c.month = 10; c.day = 5; c.hour = 12
        var lich = Calendar(identifier: .gregorian); lich.timeZone = TimeZone(identifier: "UTC")!
        let d = lich.date(from: c)!
        let cu = CTWDinhDang.locale
        defer { CTWDinhDang.locale = cu }
        CTWDinhDang.locale = Locale(identifier: "en_US")
        XCTAssertEqual(CTWDinhDang.mau("MMMd", muiGio: TimeZone(identifier: "UTC")).string(from: d), "Oct 5")
        CTWDinhDang.locale = Locale(identifier: "vi_VN")
        XCTAssertEqual(CTWDinhDang.mau("MMMd", muiGio: TimeZone(identifier: "UTC")).string(from: d), "5 thg 10")
    }
}
