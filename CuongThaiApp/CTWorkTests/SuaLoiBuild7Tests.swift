import XCTest
@testable import CTWork

/// Build 7 (22/10/2026) — sửa theo bản soát App Review (`~/Documents/ctwork-appstore/AUDIT-REVIEW.md`):
/// R1/R2 privacy manifest của cả ba target, B4b trình duyệt trong app theo DANH SÁCH TRẮNG + chặn đường mua (3.1.1).
final class SuaLoiBuild7Tests: XCTestCase {

    private typealias TD = TrinhDuyetCuongThaiCTW

    private func cach(_ s: String) -> TD.CachMo { TD.cachMo(URL(string: s)!) }

    // MARK: B4b — trình duyệt trong app: danh sách trắng

    func testTrangPhapLyVaWorkMoTrongApp() {
        for s in [
            "https://cuongthai.com/chinh-sach-bao-mat",
            "https://cuongthai.com/chinh-sach-bao-mat/",
            "https://cuongthai.com/chinh-sach-bao-mat#13",
            "https://cuongthai.com/dieu-khoan-su-dung",
            "https://cuongthai.com/about",
            "https://cuongthai.com/work",
            "https://cuongthai.com/work/northwind/NW/docs/3",
            "https://cuongthai.com/work/northwind/NW/diagrams/2?tab=sql",
            "https://www.cuongthai.com/work/x",
            "https://cuongthai.com/login?redirect=/work/northwind",
            "https://cuongthai.com/forgot-password",
            "https://cuongthai.com/verify-otp?email=a",
            "https://cuongthai.com/reset-password?token=x",
            "https://cuongthai.com/courses/huong-dan-ct-work",
            "https://cuongthai.com/courses/huong-dan-ct-work/bai/1",
            "HTTPS://CuongThai.com/Work/northwind",
        ] {
            XCTAssertEqual(cach(s), .trongApp, s)
        }
    }

    func testTrangKhacCuaCuongThaiRaSafari() {
        for s in [
            "https://cuongthai.com/",
            "https://cuongthai.com",
            "https://cuongthai.com/about/bao-mat",        // /about chỉ trang gốc, trang con là portfolio
            "https://cuongthai.com/blog/abc",
            "https://cuongthai.com/register",
            "https://cuongthai.com/profile/7",
            "https://cuongthai.com/workshop",             // KHÔNG phải /work
            "https://cuongthai.com/chinh-sach-bao-mat-cu",
            "https://cuongthai.com/courses-free",         // không phải /courses/… nhưng cũng không trong danh sách
            "https://cuongthai.com/projects",
        ] {
            XCTAssertEqual(cach(s), .safari, s)
        }
    }

    func testTrangNgoaiRaSafari() {
        for s in ["https://figma.com/file/x", "https://github.com/cuonghoang1103/ctwork-demo-app",
                  "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/", "http://example.org/pro",
                  "mailto:cuongthaihnhe176322@gmail.com", "tel:+84123"] {
            XCTAssertEqual(cach(s), .safari, s)
        }
        XCTAssertFalse(TD.laDuongMua(URL(string: "https://example.org/pricing")!), "/pricing của trang khác không phải đường mua của mình")
    }

    func testDuongMuaBiChanHan() {
        for s in [
            "https://cuongthai.com/pro", "https://cuongthai.com/pro/checkout?plan=year", "https://cuongthai.com/PRICING",
            "https://cuongthai.com/upgrade", "https://cuongthai.com/checkout", "https://cuongthai.com/payment/return",
            "https://cuongthai.com/wallet", "https://cuongthai.com/cart", "https://cuongthai.com/shop/item/3",
            "https://cuongthai.com/my-orders", "https://cuongthai.com/courses", "https://cuongthai.com/courses/react",
            "https://cuongthai.com/huong-dan-mua-hang", "https://cuongthai.com/chinh-sach-thanh-toan",
            "https://cuongthai.com/chinh-sach-doi-tra", "https://cuongthai.com/chinh-sach-giao-hang",
            "https://cuongthai.com/work/../pro",
            "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html", "https://pay.payos.vn/web/abc",
            "https://checkout.stripe.com/c/pay", "https://www.paypal.com/checkoutnow",
        ] {
            XCTAssertEqual(cach(s), .chan, s)
        }
        // Đường tương đối (link trong câu trả lời AI) cũng bị chặn.
        XCTAssertTrue(TD.laDuongMua(URL(string: "/pro")!))
        XCTAssertFalse(TD.laDuongMua(URL(string: "/projects")!), "/projects không phải /pro")
        XCTAssertFalse(TD.laDuongMua(URL(string: "https://cuongthai.com/courses/huong-dan-ct-work")!), "hướng dẫn CT Work miễn phí")
    }

    func testLuocDoLaBiChan() {
        XCTAssertEqual(cach("javascript:alert(1)"), .chan)
        XCTAssertEqual(cach("file:///etc/hosts"), .chan)
        XCTAssertEqual(cach("ftp://cuongthai.com/work"), .chan)
    }

    /// Kịch bản trong trang dùng CHUNG danh sách với Swift (một nguồn) — đổi danh sách ở Swift là JS đổi theo.
    func testKichBanDungChungDanhSach() {
        let js = TD.kichBanAn
        for d in TD.duongMua + TD.duongChoPhep.map(\.0) + TD.mienThanhToan { XCTAssertTrue(js.contains("'\(d)'"), d) }
        XCTAssertTrue(js.contains("ctwMoNgoai"))
        XCTAssertTrue(js.contains("/\\.cuongthai\\.com$/"), "regex miền phải còn dấu \\ sau khi Swift thoát chuỗi")
        XCTAssertFalse(js.contains("\\("), "không còn nội suy Swift sót lại")
    }

    // MARK: R1 / R12 — privacy manifest

    private var goc: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private func manifest(_ duong: String) throws -> [String: Any] {
        let d = try Data(contentsOf: goc.appendingPathComponent(duong))
        return try XCTUnwrap(PropertyListSerialization.propertyList(from: d, format: nil) as? [String: Any])
    }

    private func lyDo(_ m: [String: Any], _ loai: String) -> [String] {
        let ds = (m["NSPrivacyAccessedAPITypes"] as? [[String: Any]]) ?? []
        return ds.first { $0["NSPrivacyAccessedAPIType"] as? String == loai }?["NSPrivacyAccessedAPITypeReasons"] as? [String] ?? []
    }

    /// Các tệp Swift một target biên dịch (theo `project.yml`) — chỉ những thư mục/tệp nhỏ của extension.
    private func nguon(_ ds: [String]) throws -> String {
        var kq = ""
        for d in ds {
            let u = goc.appendingPathComponent(d)
            var laThuMuc: ObjCBool = false
            FileManager.default.fileExists(atPath: u.path, isDirectory: &laThuMuc)
            let tep = laThuMuc.boolValue
                ? try FileManager.default.contentsOfDirectory(at: u, includingPropertiesForKeys: nil).filter { $0.pathExtension == "swift" }
                : [u]
            for t in tep { kq += try String(contentsOf: t, encoding: .utf8) }
        }
        return kq
    }

    /// Mỗi target khai ĐÚNG nhóm API "required reason" mà mã của nó dùng (ITMS-91053).
    func testManifestTheoMaCuaTungTarget() throws {
        let cacTarget: [(String, [String])] = [
            ("CTWorkWidget/PrivacyInfo.xcprivacy", ["CTWorkWidget", "CTWorkShared"]),
            ("CTWorkShare/PrivacyInfo.xcprivacy", ["CTWorkShare", "CTWorkShared/NhomCTW.swift", "CTWorkShared/NgonNguCTW.swift"]),
        ]
        let dauHieu: [(String, String)] = [
            ("NSPrivacyAccessedAPICategoryUserDefaults", #"UserDefaults|@AppStorage"#),
            ("NSPrivacyAccessedAPICategoryFileTimestamp", #"creationDate|modificationDate|ModificationDate|attributesOfItem|getattrlist|\bstat\("#),
            ("NSPrivacyAccessedAPICategorySystemBootTime", #"systemUptime|mach_absolute_time"#),
            ("NSPrivacyAccessedAPICategoryDiskSpace", #"volumeAvailableCapacity|systemFreeSize|statfs"#),
            ("NSPrivacyAccessedAPICategoryActiveKeyboards", #"activeInputModes"#),
        ]
        for (tep, src) in cacTarget {
            let m = try manifest(tep)
            // Bỏ dòng chú thích để không tính chữ "UserDefaults" trong lời giải thích.
            let ma = try nguon(src).split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }.joined(separator: "\n")
            for (loai, re) in dauHieu where ma.range(of: re, options: .regularExpression) != nil {
                XCTAssertFalse(lyDo(m, loai).isEmpty, "\(tep): mã dùng \(loai) mà manifest không khai")
            }
        }
        XCTAssertEqual(lyDo(try manifest("CTWorkWidget/PrivacyInfo.xcprivacy"), "NSPrivacyAccessedAPICategoryUserDefaults"), ["CA92.1"])
        XCTAssertEqual(lyDo(try manifest("CTWorkShare/PrivacyInfo.xcprivacy"), "NSPrivacyAccessedAPICategoryUserDefaults"), ["CA92.1"])
        let app = try manifest("CTWorkApp/PrivacyInfo.xcprivacy")
        XCTAssertEqual(lyDo(app, "NSPrivacyAccessedAPICategoryUserDefaults"), ["CA92.1"])
        XCTAssertEqual(lyDo(app, "NSPrivacyAccessedAPICategoryFileTimestamp"), ["C617.1"])
    }

    /// R12: khớp nhãn App Privacy trên App Store Connect — Search History (GIF ⇒ GIPHY), Not linked, App Functionality.
    func testManifestAppKhaiSearchHistoryKhongLienKet() throws {
        let ds = try XCTUnwrap(try manifest("CTWorkApp/PrivacyInfo.xcprivacy")["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
        let sh = try XCTUnwrap(ds.first { $0["NSPrivacyCollectedDataType"] as? String == "NSPrivacyCollectedDataTypeSearchHistory" })
        XCTAssertEqual(sh["NSPrivacyCollectedDataTypeLinked"] as? Bool, false)
        XCTAssertEqual(sh["NSPrivacyCollectedDataTypeTracking"] as? Bool, false)
        XCTAssertEqual(sh["NSPrivacyCollectedDataTypePurposes"] as? [String], ["NSPrivacyCollectedDataTypePurposeAppFunctionality"])
        XCTAssertEqual(ds.count, 10, "9 loại Linked + Search History — khớp APP-STORE-CONNECT.md §5")
    }

    // MARK: R2 — ngôn ngữ máy không đọc miền UserDefaults toàn cục

    func testNgonNguMayDocTuDanhSachUuTien() throws {
        XCTAssertEqual(NgonNguCTW.maTheoMay(["fr-FR", "vi-VN", "en-US"]), "vi")
        XCTAssertEqual(NgonNguCTW.maTheoMay(["en-GB", "vi"]), "en")
        XCTAssertEqual(NgonNguCTW.maTheoMay(["de-DE", "ja-JP"]), "en", "không có ngôn ngữ app hỗ trợ ⇒ en")
        XCTAssertEqual(NgonNguCTW.maTheoMay([]), "en")
        let ma = try String(contentsOf: goc.appendingPathComponent("CTWorkShared/NgonNguCTW.swift"), encoding: .utf8)
        XCTAssertFalse(ma.contains("UserDefaults.globalDomain"), "CA92.1 không cho đọc dữ liệu hệ thống ghi (AppleLanguages toàn cục)")
    }
}
