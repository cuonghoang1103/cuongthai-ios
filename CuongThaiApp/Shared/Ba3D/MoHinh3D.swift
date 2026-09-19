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
    var id: String { rawValue }

    var ten: String {
        switch self {
        case .hop: return T("Hộp")
        case .cau: return T("Cầu")
        case .tru: return T("Trụ")
        case .non: return T("Nón")
        case .phang: return T("Mặt phẳng")
        case .xuyen: return T("Xuyến")
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

    var tenHien: String { ten.isEmpty ? loai.ten : ten }
}

struct CanhBa: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var ten: String
    var khoi: [KhoiBa] = []
    var mauNen: String = "#1A1A24"
    var taoLuc: Date = Date()
    var suaLuc: Date = Date()
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
        danhSach.removeAll { $0.id == c.id }
    }

    func moi(ten: String) -> CanhBa {
        // Cảnh trống hoàn toàn là màn đen không có gì để xoay, và người dùng
        // tưởng nó hỏng. Cho sẵn một khối và một mặt sàn để có cái mà nhìn.
        var c = CanhBa(ten: ten.isEmpty ? T("Mô hình mới") : ten)
        c.khoi = [
            KhoiBa(loai: .phang, ten: T("Sàn"), y: -0.5, xoayX: -90,
                   coX: 6, coY: 6, coZ: 1, mau: "#56565F", kimLoai: 0, nham: 0.9),
            KhoiBa(loai: .hop, ten: T("Khối 1")),
        ]
        luu(c)
        return c
    }
}
