#if DEBUG
import SwiftUI

/// Bàn thử Chương trình đào tạo — CHỈ DEBUG (App Store 2.3: không tính năng ẩn trong bản phát hành).
///
/// Endpoint `/courses/chuong-trinh` chưa lên prod và máy mô phỏng không có phiên đăng nhập ⇒ cắm nguồn
/// giả đọc từ một thư mục trên máy Mac (fixture dựng từ dữ liệu THẬT của prod + khung kỳ của backend):
///
///     SIMCTL_CHILD_CT_XEM_MAN=chuongtrinh \
///     SIMCTL_CHILD_CT_XEM_CHUONGTRINH=/đường/tới/thư-mục-fixture \
///     xcrun simctl launch <udid> com.cuongthai.app
///
/// Thư mục cần: `fixture-chuong-trinh.json` (thân `/courses/chuong-trinh`), `prod-courses.json`
/// (thân `/courses?gon=1&size=100`), `fixture-khung-ios.json` (thân `/courses/ios-swift-swiftui` khoá Sắp ra mắt).
/// `CT_XEM_CHUONGTRINH_KIEU`: (trống) dữ liệu đủ · `duphong` máy chủ 404 ⇒ đường lùi · `tai` treo · `loi` mất mạng.
///
/// Màn (`CT_XEM_MAN`): chuongtrinh · chuongtrinh-nganh · chuongtrinh-tatca · chuongtrinh-tim ·
/// chuongtrinh-ky8 · chuongtrinh-moi · chuongtrinh-tuchon · chuongtrinh-chitiet · chuongtrinh-hub.
enum ThuChuongTrinh {
    private static var moiTruong: [String: String] { ProcessInfo.processInfo.environment }

    private static var thuMuc: String? {
        let v = moiTruong["CT_XEM_CHUONGTRINH"] ?? ""
        return v.isEmpty ? nil : v
    }

    private static func doc(_ ten: String) throws -> Data {
        guard let thuMuc else { throw URLError(.fileDoesNotExist) }
        return try Data(contentsOf: URL(fileURLWithPath: thuMuc).appendingPathComponent(ten))
    }

    static func nguonTuMoiTruong() -> NguonChuongTrinh? {
        guard thuMuc != nil else { return nil }
        let danhSach: (Int) async throws -> Data = { _ in try doc("prod-courses.json") }
        switch moiTruong["CT_XEM_CHUONGTRINH_KIEU"] ?? "" {
        case "duphong":
            // Đúng thứ prod trả hôm nay: 404 `{"success":false,"message":"Course not found"}`.
            return NguonChuongTrinh(chuongTrinh: { throw APIError.serverError("Course not found") },
                                    trangDanhSach: danhSach)
        case "tai":
            return NguonChuongTrinh(chuongTrinh: { try await Task.sleep(for: .seconds(3600)); throw CancellationError() },
                                    trangDanhSach: danhSach)
        case "loi":
            return NguonChuongTrinh(chuongTrinh: { throw URLError(.notConnectedToInternet) },
                                    trangDanhSach: { _ in throw APIError.networkError(URLError(.notConnectedToInternet)) })
        default:
            return NguonChuongTrinh(chuongTrinh: { try doc("fixture-chuong-trinh.json") }, trangDanhSach: danhSach)
        }
    }

    static func khungTuMoiTruong() -> ((String) async throws -> KhungKhoaSapRaMat)? {
        guard thuMuc != nil else { return nil }
        return { _ in
            let v = try JSONDecoder().decode(APIResponse<KhungKhoaSapRaMat>.self, from: try doc("fixture-khung-ios.json"))
            guard let k = v.data else { throw LoiChuongTrinh.khongCoDuLieu }
            return k
        }
    }

    /// Khoá Sắp ra mắt đầu tiên của fixture (iOS & iPadOS) — cho màn chi tiết.
    static func monSapRaMatDau() -> MonChuongTrinh {
        if let d = try? doc("fixture-chuong-trinh.json"), let ct = try? ChuongTrinhDaoTao.giai(d),
           let m = ct.monSapRaMat.first {
            return m
        }
        return MonChuongTrinh(id: 9000, slug: "ios-swift-swiftui",
                              title: "iOS & iPadOS with Swift + SwiftUI|||iOS & iPadOS với Swift + SwiftUI",
                              level: "BEGINNER", categoryName: "Frontend", sapRaMat: true,
                              soChuongDuKien: 17, soBaiDuKien: 117)
    }
}

struct ThuChuongTrinhView: View {
    let kieu: String

    var body: some View {
        switch kieu {
        case "chuongtrinh-nganh": ChuongTrinhView(cheDo: .chuyenNganh)
        case "chuongtrinh-tatca": ChuongTrinhView(cheDo: .tatCa)
        case "chuongtrinh-tim": ChuongTrinhView(cheDo: .tatCa, tuKhoa: "bao mat")
        case "chuongtrinh-ky8": ChuongTrinhView(kyMoDau: 8)
        case "chuongtrinh-moi": ChuongTrinhView(muc: "khoa-moi")
        case "chuongtrinh-tuchon": ChuongTrinhView(muc: "tu-chon")
        case "chuongtrinh-chitiet": KhoaSapRaMatView(mon: ThuChuongTrinh.monSapRaMatDau())
        case "chuongtrinh-hub": CoursesView()
        default: ChuongTrinhView()
        }
    }
}
#endif
