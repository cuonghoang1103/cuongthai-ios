import Foundation
import SwiftUI

// MARK: - Bản vẽ

/// Khổ giấy của một bản vẽ.
///
/// Có sẵn kích thước THẬT của máy và của web: thiết kế một màn iPhone trên
/// khung vuông rồi mới biết nó không vừa là mất công làm lại từ đầu.
enum KhoVe: String, Codable, CaseIterable, Identifiable {
    case tuDo, iphone, ipad, web, vuong, a4
    case bang, bangLon, voCucLon

    var id: String { rawValue }

    var ten: String {
        switch self {
        case .tuDo: return T("Tự do")
        case .iphone: return "iPhone"
        case .ipad: return "iPad"
        case .web: return "Web"
        case .vuong: return T("Vuông")
        case .a4: return "A4"
        case .bang: return T("Bảng giảng")
        case .bangLon: return T("Bảng lớn")
        case .voCucLon: return T("Vô cực")
        }
    }

    /// Kích thước điểm. `tuDo` trả về `nil` — khung co theo màn hình.
    var co: CGSize? {
        switch self {
        case .tuDo: return nil
        case .iphone: return CGSize(width: 393, height: 852)
        case .ipad: return CGSize(width: 1024, height: 1366)
        case .web: return CGSize(width: 1440, height: 900)
        case .vuong: return CGSize(width: 1080, height: 1080)
        case .a4: return CGSize(width: 794, height: 1123)
        // Dạy học thì cần chỗ: một sơ đồ mạch hay một bài toán nhiều bước
        // không nhét vừa khổ 1440×900 — người dùng báo 20/09/2026 "diện
        // tích được có tý".
        case .bang: return CGSize(width: 3000, height: 2000)
        case .bangLon: return CGSize(width: 6000, height: 4000)
        case .voCucLon: return CGSize(width: 12000, height: 8000)
        }
    }

    var moTa: String {
        guard let c = co else { return T("Khung co theo màn hình") }
        return "\(Int(c.width)) × \(Int(c.height))"
    }
}

/// Loại hình khối chèn được.
enum LoaiHinh: String, Codable, CaseIterable, Identifiable {
    case chuNhat, bo, elip, duong, muiTen, chu
    case tamGiac, thoi, trUong, saoNam, muiTenHai, netDut, trucToaDo
    var id: String { rawValue }

    var ten: String {
        switch self {
        case .chuNhat: return T("Chữ nhật")
        case .bo: return T("Bo góc")
        case .elip: return T("Elip")
        case .duong: return T("Đường")
        case .muiTen: return T("Mũi tên")
        case .chu: return T("Chữ")
        case .tamGiac: return T("Tam giác")
        case .thoi: return T("Hình thoi")
        case .trUong: return T("Trụ (CSDL)")
        case .saoNam: return T("Ngôi sao")
        case .muiTenHai: return T("Mũi tên hai đầu")
        case .netDut: return T("Đường nét đứt")
        case .trucToaDo: return T("Trục toạ độ")
        }
    }

    var bieuTuong: String {
        switch self {
        case .chuNhat: return "rectangle"
        case .bo: return "rectangle.roundedtop"
        case .elip: return "circle"
        case .duong: return "line.diagonal"
        case .muiTen: return "arrow.right"
        case .chu: return "textformat"
        case .tamGiac: return "triangle"
        case .thoi: return "diamond"
        case .trUong: return "cylinder"
        case .saoNam: return "star"
        case .muiTenHai: return "arrow.left.and.right"
        case .netDut: return "line.diagonal"
        case .trucToaDo: return "chart.xyaxis.line"
        }
    }
}

/// Một hình trên bản vẽ.
///
/// Toạ độ là điểm TRONG khung vẽ, không phải trên màn hình — nhờ vậy phóng
/// to thu nhỏ hay đổi khổ giấy thì hình vẫn nằm đúng chỗ của nó trên bản vẽ.
struct HinhVe: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var loai: LoaiHinh
    var x: Double
    var y: Double
    var rong: Double
    var cao: Double
    /// Màu nền, dạng `#RRGGBB` kèm độ mờ riêng. Rỗng = không tô.
    var mauNen: String = "#7A45E8"
    var doMo: Double = 1
    var mauVien: String = ""
    var dayVien: Double = 0
    var goc: Double = 12
    var chu: String = ""
    var coChu: Double = 20
    var mauChu: String = "#14141C"

    var khung: CGRect { CGRect(x: x, y: y, width: rong, height: cao) }
}

/// Nền giấy. Dạy toán thì lưới ô vuông và giấy kẻ ca-rô là thứ dùng nhiều
/// nhất — vẽ trục toạ độ hay hình học trên giấy trắng là canh bằng mắt.
enum KieuGiay: String, Codable, CaseIterable, Identifiable {
    case trang, oVuong, caRo, chamBi, keDong, tamGiac
    var id: String { rawValue }
    var ten: String {
        switch self {
        case .trang:    return T("Trắng")
        case .oVuong:   return T("Ô vuông")
        case .caRo:     return T("Ca-rô nhỏ")
        case .chamBi:   return T("Chấm bi")
        case .keDong:   return T("Kẻ dòng")
        case .tamGiac:  return T("Tam giác đều")
        }
    }
    var bieuTuong: String {
        switch self {
        case .trang:   return "square"
        case .oVuong:  return "grid"
        case .caRo:    return "square.grid.4x3.fill"
        case .chamBi:  return "circle.grid.3x3"
        case .keDong:  return "list.dash"
        case .tamGiac: return "triangle"
        }
    }
    /// Bước lưới mặc định (điểm).
    var buoc: Double {
        switch self {
        case .caRo: return 20
        case .chamBi: return 40
        case .keDong: return 36
        case .tamGiac: return 48
        default: return 50
        }
    }
}

/// Một bản vẽ hoàn chỉnh.
struct BanVe: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var ten: String
    var kho: KhoVe = .tuDo
    var nen: String = "#FFFFFF"
    /// Kiểu giấy nền. Mặc định trắng để bản vẽ cũ không đổi vẻ ngoài.
    var giay: KieuGiay = .trang
    /// Bước lưới, `0` = dùng mặc định của kiểu giấy.
    var buocLuoi: Double = 0
    var hinh: [HinhVe] = []
    var taoLuc: Date = Date()
    var suaLuc: Date = Date()

    var coKhung: CGSize { kho.co ?? CGSize(width: 1024, height: 768) }
    var buocThat: Double { buocLuoi > 0 ? buocLuoi : giay.buoc }

    /// ⚠️ TỰ VIẾT bộ giải mã. `Decodable` tự sinh đòi ĐỦ MỌI khoá kể cả khi
    /// thuộc tính có giá trị mặc định — thêm `giay`/`buocLuoi` mà để nó tự
    /// sinh thì MỌI bản vẽ đã lưu biến mất khỏi danh sách, im lặng.
    init(from bo: Decoder) throws {
        let c = try bo.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        ten = try c.decodeIfPresent(String.self, forKey: .ten) ?? T("Bản vẽ")
        kho = try c.decodeIfPresent(KhoVe.self, forKey: .kho) ?? .tuDo
        nen = try c.decodeIfPresent(String.self, forKey: .nen) ?? "#FFFFFF"
        giay = try c.decodeIfPresent(KieuGiay.self, forKey: .giay) ?? .trang
        buocLuoi = try c.decodeIfPresent(Double.self, forKey: .buocLuoi) ?? 0
        hinh = try c.decodeIfPresent([HinhVe].self, forKey: .hinh) ?? []
        taoLuc = try c.decodeIfPresent(Date.self, forKey: .taoLuc) ?? Date()
        suaLuc = try c.decodeIfPresent(Date.self, forKey: .suaLuc) ?? Date()
    }

    init(ten: String, kho: KhoVe = .tuDo) {
        self.ten = ten
        self.kho = kho
    }
}

// MARK: - Kho lưu

/// Lưu bản vẽ ra tệp trong `Documents/xuong-ve/`.
///
/// Mỗi bản vẽ hai tệp: `<id>.json` (khổ giấy, hình khối) và `<id>.drawing`
/// (nét vẽ tay của PencilKit). Tách đôi vì `PKDrawing` là dữ liệu nhị phân
/// đã nén — nhét vào JSON dạng base64 làm tệp phình ~33% và mỗi lần lưu phải
/// mã hoá lại cả khối.
///
/// Không dùng SwiftData: bản vẽ là TỆP, người dùng cần xuất ra, chép đi, gửi
/// cho người khác. Một hàng trong cơ sở dữ liệu không làm được việc đó mà
/// không thêm một tầng xuất/nhập.
@MainActor
final class KhoBanVe: ObservableObject {
    static let chung = KhoBanVe()

    @Published private(set) var danhSach: [BanVe] = []

    private init() { nap() }

    static func thuMuc() -> URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("xuong-ve", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    static func duongNet(_ id: UUID) -> URL {
        thuMuc().appendingPathComponent("\(id.uuidString).drawing")
    }

    private static func duongJson(_ id: UUID) -> URL {
        thuMuc().appendingPathComponent("\(id.uuidString).json")
    }

    func nap() {
        let d = Self.thuMuc()
        let tep = (try? FileManager.default.contentsOfDirectory(at: d, includingPropertiesForKeys: nil)) ?? []
        let bo = JSONDecoder()
        bo.dateDecodingStrategy = .iso8601
        danhSach = tep
            .filter { $0.pathExtension == "json" }
            // Một tệp hỏng KHÔNG được làm trống cả danh sách: `compactMap` bỏ
            // riêng nó và giữ những bản còn lại. Mất một bản vẽ đã tệ; mất
            // hết vì một bản hỏng thì không ai tha thứ.
            .compactMap { u -> BanVe? in
                guard let data = try? Data(contentsOf: u) else { return nil }
                return try? bo.decode(BanVe.self, from: data)
            }
            .sorted { $0.suaLuc > $1.suaLuc }
    }

    func luu(_ b: BanVe) {
        var v = b
        v.suaLuc = Date()
        let ma = JSONEncoder()
        ma.dateEncodingStrategy = .iso8601
        guard let data = try? ma.encode(v) else { return }
        try? data.write(to: Self.duongJson(v.id), options: .atomic)
        if let i = danhSach.firstIndex(where: { $0.id == v.id }) {
            danhSach[i] = v
        } else {
            danhSach.insert(v, at: 0)
        }
        danhSach.sort { $0.suaLuc > $1.suaLuc }
    }

    func xoa(_ b: BanVe) {
        try? FileManager.default.removeItem(at: Self.duongJson(b.id))
        try? FileManager.default.removeItem(at: Self.duongNet(b.id))
        danhSach.removeAll { $0.id == b.id }
    }

    func moi(ten: String, kho: KhoVe) -> BanVe {
        let b = BanVe(ten: ten.isEmpty ? T("Bản vẽ mới") : ten, kho: kho)
        luu(b)
        return b
    }
}

// MARK: - Màu

extension Color {
    /// `#RRGGBB` → `Color`. Chuỗi lạ thì trả về xám, KHÔNG sập.
    init(maHex: String) {
        let s = maHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard s.count == 6, let v = UInt32(s, radix: 16) else {
            self = .gray
            return
        }
        self.init(
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255
        )
    }

    /// Đổi ngược ra `#RRGGBB` để cất vào JSON.
    var maHex: String {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        #else
        return "#000000"
        #endif
    }
}

/// Bảng màu dựng sẵn.
///
/// Có bảng sẵn chứ không chỉ có bánh xe màu của hệ thống: chọn màu từ bánh xe
/// cho ra những bộ màu chói và lệch nhau, còn một bảng đã chọn lọc thì bản vẽ
/// nào cũng nhìn được ngay cả khi người vẽ không rành phối màu.
enum BangMau {
    static let mau: [String] = [
        "#14141C", "#56565F", "#9999A6", "#FFFFFF",
        "#7A45E8", "#9B6BFF", "#2E6FD9", "#21D4ED",
        "#1A8F35", "#33C759", "#FAD129", "#D97706",
        "#D32F2F", "#F54336", "#DB2777", "#F472B6",
    ]
}
