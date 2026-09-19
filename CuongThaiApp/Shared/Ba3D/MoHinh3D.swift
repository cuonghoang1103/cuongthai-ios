import Foundation
import SwiftUI

// MARK: - Mô hình 3D
//
// ⚠️ ĐÂY LÀ TRÌNH DỰNG KHỐI, KHÔNG PHẢI TRÌNH DỰNG LƯỚI. Nó ghép các khối cơ
// bản (hộp, cầu, trụ, nón, phẳng, xuyến), đặt vị trí, xoay, phóng và tô màu
// cho từng khối. Nó KHÔNG nặn được từng đỉnh, không chạm khắc, không trải UV.
//
// Nói thẳng ngay ở đây vì một trình dựng lưới đầy đủ là nhiều tháng, và
// Shapr3D/Nomad trên iPad đã làm tốt hơn. Dựng khối vẫn đủ cho việc thật hay
// gặp nhất: phác hình dáng một vật, dựng bố cục cảnh, và xuất `.usdz` để xem
// ở AR hoặc gửi cho người khác.

enum LoaiKhoi: String, Codable, CaseIterable, Identifiable {
    case hop, cau, tru, non, phang, xuyen
    /// Mô hình người dùng nhập từ tệp `.usdz`/`.obj`. KHÔNG nằm trong
    /// `allCases` dùng cho bảng "Thêm khối" — nó vào bằng nút nhập tệp, và
    /// hiện nó cạnh hộp với cầu thì người dùng bấm vào rồi không hiểu vì sao
    /// không có gì xuất hiện.
    case nhap

    static var cacKhoiDung: [LoaiKhoi] { [.hop, .cau, .tru, .non, .phang, .xuyen] }

    var id: String { rawValue }

    var ten: String {
        switch self {
        case .hop: return T("Hộp")
        case .cau: return T("Cầu")
        case .tru: return T("Trụ")
        case .non: return T("Nón")
        case .phang: return T("Mặt phẳng")
        case .xuyen: return T("Xuyến")
        case .nhap: return T("Tệp nhập")
        }
    }

    var bieuTuong: String {
        switch self {
        case .hop: return "cube"
        case .cau: return "circle.circle"
        case .tru: return "cylinder"
        case .non: return "cone"
        case .phang: return "rectangle"
        case .xuyen: return "circle.dashed"
        case .nhap: return "square.and.arrow.down"
        }
    }
}

/// Một khối trong cảnh.
///
/// `SCNVector3` không `Codable` nên toạ độ tách thành ba số. Viết một bộ mã
/// hoá riêng cho kiểu của SceneKit thì tốn công hơn, và một mảnh dữ liệu chỉ
/// gồm số thì lưu dạng số là cách đọc được bằng mắt khi cần dò lỗi.
struct KhoiBa: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var loai: LoaiKhoi
    var ten: String = ""

    var x: Double = 0
    var y: Double = 0
    var z: Double = 0

    /// Góc xoay, ĐỘ (không phải radian) — số hiện trên thanh trượt phải là
    /// thứ người dùng hiểu, và không ai nghĩ bằng radian.
    var xoayX: Double = 0
    var xoayY: Double = 0
    var xoayZ: Double = 0

    var coX: Double = 1
    var coY: Double = 1
    var coZ: Double = 1

    var mau: String = "#7A45E8"
    /// 0 = nhựa mờ, 1 = kim loại bóng.
    var kimLoai: Double = 0.1
    var nham: Double = 0.45

    /// Tên nhóm. Khối cùng nhóm KÉO ĐI CÙNG NHAU.
    ///
    /// Dựng một nhân vật là dựng mười mấy khối; không có nhóm thì dời cánh
    /// tay phải dời từng khối một, và chỉ cần lệch một khối là hỏng cả hình.
    var nhom: String?

    /// Khoá lại — không chọn, không kéo được. Dành cho sàn và tường nền:
    /// chúng nằm dưới mọi thứ nên rất hay bị chạm trúng thay vì khối đang cần.
    var khoa: Bool = false

    /// Tên tệp `.usdz`/`.obj` trong thư mục của chính cảnh này (chỉ khi
    /// `loai == .nhap`). Chép tệp vào thư mục cảnh chứ không giữ đường dẫn
    /// gốc: tệp người dùng chọn nằm trong hộp cát của app Tệp, và cái quyền
    /// đọc đó hết hiệu lực ngay khi đóng bảng chọn.
    var tepNhap: String?
    /// Chỉ có nghĩa với khối NHẬP: tô đè màu bên dưới lên mọi mặt của mô
    /// hình. Mặc định TẮT vì mô hình có sẵn vật liệu thì đè lên là xoá mất
    /// thứ người ta nhập nó vào để dùng — nhưng tệp `.obj` trần không có
    /// vật liệu nào cả, và khi đó ô màu không bật được thì nhìn như hỏng.
    var toDe: Bool = false

    var tenHien: String { ten.isEmpty ? loai.ten : ten }

    // ⚠️⚠️ BỘ GIẢI MÃ VIẾT TAY, KHÔNG DÙNG BẢN SWIFT TỰ SINH.
    //
    // Bản tự sinh ĐÒI đủ mọi khoá, kể cả khoá có giá trị mặc định trong Swift.
    // Thêm một trường mới (`nhom`, `khoa`, `tepNhap`) là mọi tệp đã lưu trước
    // đó KHÔNG giải mã được nữa — `compactMap` trong `nap()` lặng lẽ bỏ qua,
    // và người dùng mở app thấy TRỐNG TRƠN. Không lỗi, không cảnh báo, chỉ là
    // mất hết những gì họ đã dựng.
    //
    // Đo thật 19/09/2026: thêm ba trường xong, mô hình dựng lúc trước biến mất
    // sạch. Nếu không chạy thử mà chỉ dựng xanh rồi giao thì người dùng là
    // người phát hiện ra, và lúc đó công của họ đã mất thật.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        loai = try c.decodeIfPresent(LoaiKhoi.self, forKey: .loai) ?? .hop
        ten = try c.decodeIfPresent(String.self, forKey: .ten) ?? ""
        x = try c.decodeIfPresent(Double.self, forKey: .x) ?? 0
        y = try c.decodeIfPresent(Double.self, forKey: .y) ?? 0
        z = try c.decodeIfPresent(Double.self, forKey: .z) ?? 0
        xoayX = try c.decodeIfPresent(Double.self, forKey: .xoayX) ?? 0
        xoayY = try c.decodeIfPresent(Double.self, forKey: .xoayY) ?? 0
        xoayZ = try c.decodeIfPresent(Double.self, forKey: .xoayZ) ?? 0
        coX = try c.decodeIfPresent(Double.self, forKey: .coX) ?? 1
        coY = try c.decodeIfPresent(Double.self, forKey: .coY) ?? 1
        coZ = try c.decodeIfPresent(Double.self, forKey: .coZ) ?? 1
        mau = try c.decodeIfPresent(String.self, forKey: .mau) ?? "#7A45E8"
        kimLoai = try c.decodeIfPresent(Double.self, forKey: .kimLoai) ?? 0.1
        nham = try c.decodeIfPresent(Double.self, forKey: .nham) ?? 0.45
        nhom = try c.decodeIfPresent(String.self, forKey: .nhom)
        khoa = try c.decodeIfPresent(Bool.self, forKey: .khoa) ?? false
        tepNhap = try c.decodeIfPresent(String.self, forKey: .tepNhap)
        toDe = try c.decodeIfPresent(Bool.self, forKey: .toDe) ?? false
    }

    init(loai: LoaiKhoi, ten: String = "",
         x: Double = 0, y: Double = 0, z: Double = 0,
         xoayX: Double = 0, xoayY: Double = 0, xoayZ: Double = 0,
         coX: Double = 1, coY: Double = 1, coZ: Double = 1,
         mau: String = "#7A45E8", kimLoai: Double = 0.1, nham: Double = 0.45,
         nhom: String? = nil, khoa: Bool = false, tepNhap: String? = nil,
         toDe: Bool = false) {
        self.loai = loai; self.ten = ten
        self.x = x; self.y = y; self.z = z
        self.xoayX = xoayX; self.xoayY = xoayY; self.xoayZ = xoayZ
        self.coX = coX; self.coY = coY; self.coZ = coZ
        self.mau = mau; self.kimLoai = kimLoai; self.nham = nham
        self.nhom = nhom; self.khoa = khoa; self.tepNhap = tepNhap
        self.toDe = toDe
    }
}

struct CanhBa: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var ten: String
    var khoi: [KhoiBa] = []
    var mauNen: String = "#1A1A24"
    /// Hiện lưới sàn. Dựng map thì lưới là thứ duy nhất cho biết ô có đều
    /// nhau không; dựng nhân vật thì nó vướng mắt, nên bật/tắt được.
    var luoi: Bool = true
    /// Bước bắt điểm, đơn vị thế giới. `0` = tắt.
    ///
    /// Ghép hai khối cho khít bằng tay là việc bất khả thi trên màn cảm ứng:
    /// lệch 0,03 thì mắt không thấy nhưng khe hở hiện ra ngay khi xoay camera.
    var buocBat: Double = 0.25
    var taoLuc: Date = Date()
    var suaLuc: Date = Date()

    /// Cùng lý do với `KhoiBa`: thêm `luoi`/`buocBat` mà để Swift tự sinh bộ
    /// giải mã thì mọi cảnh đã lưu trước đó biến mất khỏi danh sách.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        ten = try c.decodeIfPresent(String.self, forKey: .ten) ?? T("Mô hình")
        khoi = try c.decodeIfPresent([KhoiBa].self, forKey: .khoi) ?? []
        mauNen = try c.decodeIfPresent(String.self, forKey: .mauNen) ?? "#1A1A24"
        luoi = try c.decodeIfPresent(Bool.self, forKey: .luoi) ?? true
        buocBat = try c.decodeIfPresent(Double.self, forKey: .buocBat) ?? 0.25
        taoLuc = try c.decodeIfPresent(Date.self, forKey: .taoLuc) ?? Date()
        suaLuc = try c.decodeIfPresent(Date.self, forKey: .suaLuc) ?? Date()
    }

    init(ten: String) { self.ten = ten }
}

// MARK: - Kho cảnh

@MainActor
final class KhoCanhBa: ObservableObject {
    static let chung = KhoCanhBa()

    @Published private(set) var danhSach: [CanhBa] = []

    private init() { nap() }

    static func thuMuc() -> URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("mo-hinh-3d", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    private static func duong(_ id: UUID) -> URL {
        thuMuc().appendingPathComponent("\(id.uuidString).json")
    }

    /// Thư mục chứa tệp mô hình nhập của MỘT cảnh.
    static func thuMucTep(_ id: UUID) -> URL {
        let d = thuMuc().appendingPathComponent(id.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    func nap() {
        let bo = JSONDecoder()
        bo.dateDecodingStrategy = .iso8601
        let tep = (try? FileManager.default.contentsOfDirectory(at: Self.thuMuc(), includingPropertiesForKeys: nil)) ?? []
        danhSach = tep
            .filter { $0.pathExtension == "json" }
            .compactMap { u in
                guard let d = try? Data(contentsOf: u) else { return nil }
                return try? bo.decode(CanhBa.self, from: d)
            }
            .sorted { $0.suaLuc > $1.suaLuc }
    }

    func luu(_ c: CanhBa) {
        var v = c
        v.suaLuc = Date()
        let ma = JSONEncoder()
        ma.dateEncodingStrategy = .iso8601
        guard let d = try? ma.encode(v) else { return }
        try? d.write(to: Self.duong(v.id), options: .atomic)
        if let i = danhSach.firstIndex(where: { $0.id == v.id }) { danhSach[i] = v }
        else { danhSach.insert(v, at: 0) }
        danhSach.sort { $0.suaLuc > $1.suaLuc }
    }

    func xoa(_ c: CanhBa) {
        try? FileManager.default.removeItem(at: Self.duong(c.id))
        // Xoá luôn thư mục tệp nhập — bỏ sót là để lại vài chục MB mô hình
        // mồ côi mà không màn hình nào còn trỏ tới.
        try? FileManager.default.removeItem(at: Self.thuMucTep(c.id))
        danhSach.removeAll { $0.id == c.id }
    }

    func moi(ten: String) -> CanhBa {
        // Cảnh trống hoàn toàn là màn đen không có gì để xoay, và người dùng
        // tưởng nó hỏng. Cho sẵn một khối và một mặt sàn để có cái mà nhìn.
        var c = CanhBa(ten: ten.isEmpty ? T("Mô hình mới") : ten)
        c.khoi = [
            KhoiBa(loai: .phang, ten: T("Sàn"), y: -0.5, xoayX: -90,
                   coX: 12, coY: 12, coZ: 1, mau: "#56565F", kimLoai: 0, nham: 0.9,
                   khoa: true),
            KhoiBa(loai: .hop, ten: T("Khối 1")),
        ]
        luu(c)
        return c
    }
}
