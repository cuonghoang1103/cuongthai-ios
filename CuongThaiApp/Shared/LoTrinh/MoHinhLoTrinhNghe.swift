import SwiftUI

// ════════════════════════════════════════════════════════════════
// LỘ TRÌNH NGHỀ (web: /roadmap)
//
// Đo thật 28/08/2026 trên production:
//   · `/api/v1/roadmaps` → { role: 14, skill: 19 } — CÔNG KHAI, không cần
//     đăng nhập.
//   · `/api/v1/roadmaps/<slug>` → 22 chặng · 86 nút (lộ trình Frontend),
//     mỗi nút có tới 105 tài nguyên trên toàn lộ trình.
//   · `POST /api/v1/roadmaps/nodes/<id>/done` — CẦN đăng nhập.
//
// ⚠️ Máy chủ trả **`stages`**, không phải `nodes` phẳng. Trường `nodes` ở
// tầng gốc KHÔNG tồn tại — đọc nhầm là danh sách rỗng mà không có lỗi nào.
//
// ⚠️ `doneNodeIds` đến từ `optionalAuth`: chưa đăng nhập thì nó là mảng RỖNG
// chứ không phải thiếu, nên đừng suy "rỗng = chưa tải xong".
// ════════════════════════════════════════════════════════════════

struct LoTrinhNgheTom: Codable, Identifiable, Hashable {
    let slug: String
    let title: String
    let type: String
    let description: String?
    let icon: String?
    let color: String?
    let nodeCount: Int?

    var id: String { slug }
    var soNut: Int { nodeCount ?? 0 }
    var mau: Color { Color(hex: UInt32((color ?? "#6366F1").dropFirst(), radix: 16) ?? 0x6366F1) }
    /// Tên icon của web là của bộ **lucide**; app dùng SF Symbols nên phải
    /// bắc cầu, và luôn có đường lùi chứ không để ô trống.
    var bieuTuong: String { BieuTuongLucide.sf(icon) }
}

struct DanhSachLoTrinhNghe: Codable {
    let role: [LoTrinhNgheTom]?
    let skill: [LoTrinhNgheTom]?
    var vaiTro: [LoTrinhNgheTom] { role ?? [] }
    var kyNang: [LoTrinhNgheTom] { skill ?? [] }
}

struct LoTrinhChiTietNghe: Codable {
    let slug: String
    let title: String
    let type: String?
    let description: String?
    let icon: String?
    let color: String?
    let stages: [ChangLoTrinhNghe]?
    let doneNodeIds: [Int]?
    let total: Int?

    var cacChang: [ChangLoTrinhNghe] { stages ?? [] }
    var daXong: Set<Int> { Set(doneNodeIds ?? []) }
    var tongNut: Int { total ?? cacChang.reduce(0) { $0 + $1.cacNut.count } }
    var mau: Color { Color(hex: UInt32((color ?? "#6366F1").dropFirst(), radix: 16) ?? 0x6366F1) }
}

struct ChangLoTrinhNghe: Codable, Identifiable, Hashable {
    let stage: Int
    let stageLabel: String?
    let nodes: [NutLoTrinhNghe]?
    var id: Int { stage }
    var nhan: String { stageLabel ?? "Chặng \(stage + 1)" }
    var cacNut: [NutLoTrinhNghe] { nodes ?? [] }
}

struct NutLoTrinhNghe: Codable, Identifiable, Hashable {
    let id: Int
    let stage: Int?
    /// Tên chặng, máy chủ lặp lại trên TỪNG nút (không chỉ ở tầng `stages`).
    /// Tiện cho tấm chi tiết: mở một bước ra là biết nó thuộc chặng nào mà
    /// không phải truyền thêm gì từ màn ngoài vào.
    let stageLabel: String?
    let order: Int?
    let side: String?
    let kind: String?
    let title: String
    let subtitle: String?
    let icon: String?
    let description: String?
    let linkType: String?
    let linkRef: String?
    let resources: [TaiNguyenNutNghe]?

    var cacTaiNguyen: [TaiNguyenNutNghe] { resources ?? [] }
    var bieuTuong: String { BieuTuongLucide.sf(icon) }

    /// Đo thật: `primary` 36 · `alternative` 29 · `info` 21 trên lộ trình
    /// Frontend. Ba loại này quyết định "phải học" hay "biết thì tốt", nên
    /// phải nhìn ra được ngay chứ không chỉ nằm trong dữ liệu.
    enum Loai { case chinh, thayThe, thongTin }
    var loai: Loai {
        switch (kind ?? "").lowercased() {
        case "primary": return .chinh
        case "alternative": return .thayThe
        default: return .thongTin
        }
    }
    var nhanLoai: String {
        switch loai {
        case .chinh: return T("Bắt buộc")
        case .thayThe: return T("Tuỳ chọn")
        case .thongTin: return T("Tham khảo")
        }
    }
}

struct TaiNguyenNutNghe: Codable, Hashable, Identifiable {
    let url: String
    let type: String?
    let title: String?
    var id: String { url }
    /// Đo thật: `official` 60 · `article` 43 · `course` 2.
    var bieuTuong: String {
        switch (type ?? "").lowercased() {
        case "official": return "checkmark.seal.fill"
        case "course": return "play.rectangle.fill"
        default: return "doc.text.fill"
        }
    }
}

// MARK: - lucide → SF Symbols

/// Web đặt tên biểu tượng theo bộ **lucide** (`Monitor`, `Globe`, `Braces`…),
/// iOS không có bộ đó. Bắc cầu sang SF Symbols, và tên lạ thì trả về một biểu
/// tượng trung tính — KHÔNG để trống, vì `Image(systemName:)` với tên sai chỉ
/// vẽ ra khoảng trắng chứ không báo lỗi, và cả hàng sẽ lệch.
enum BieuTuongLucide {
    private static let bang: [String: String] = [
        "Monitor": "display", "Server": "server.rack", "Globe": "globe",
        "Database": "cylinder.split.1x2", "Cloud": "cloud", "Code": "chevron.left.forwardslash.chevron.right",
        "FileCode": "doc.text", "Braces": "curlybraces", "Binary": "number",
        "GitBranch": "arrow.triangle.branch", "Container": "shippingbox",
        "Boxes": "square.stack.3d.up", "Blocks": "square.grid.2x2", "Layers": "square.3.layers.3d",
        "Atom": "atom", "Bot": "cpu", "Bug": "ladybug", "Gauge": "gauge.medium",
        "Check": "checkmark.circle", "Shield": "lock.shield", "Lock": "lock",
        "Terminal": "terminal", "Smartphone": "iphone", "Palette": "paintpalette",
        "Brain": "brain.head.profile", "Rocket": "paperplane", "Zap": "bolt",
        "Network": "point.3.connected.trianglepath.dotted", "Cpu": "cpu",
        "Settings": "gearshape", "Search": "magnifyingglass", "Wrench": "wrench.and.screwdriver",
        "BookOpen": "book", "GraduationCap": "graduationcap", "Users": "person.2",
        "LineChart": "chart.line.uptrend.xyaxis", "BarChart": "chart.bar",
        "PenTool": "pencil.tip", "Figma": "paintbrush.pointed", "Package": "shippingbox",
        "Workflow": "arrow.triangle.branch", "Key": "key", "Mail": "envelope",
    ]
    static func sf(_ ten: String?) -> String {
        guard let t = ten, !t.isEmpty else { return "circle.grid.2x2" }
        return bang[t] ?? "circle.grid.2x2"
    }
}
