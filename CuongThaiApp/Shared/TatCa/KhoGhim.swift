import Foundation
import SwiftUI

/// Danh sách tính năng người dùng GHIM — hiện thành lưới "Đi nhanh" ở Hôm nay
/// và mục "Công cụ" ở thanh bên iPad. Thứ tự là thứ tự người dùng sắp.
///
/// Lưu dạng MỘT chuỗi `rawValue` nối dấu phẩy trong UserDefaults (không phải
/// `[String]` mã hoá JSON): đọc tay được khi soi máy, và một `rawValue` lạ
/// (tính năng đã bỏ, vd. bản cũ có mục khác) chỉ bị bỏ qua chứ không làm hỏng
/// cả danh sách như một lượt giải mã JSON hỏng.
///
/// ⚠️ "Chưa từng chỉnh" (khoá KHÔNG tồn tại) ≠ "đã bỏ ghim hết" (khoá là chuỗi
/// rỗng). Gộp hai cái làm một là người dùng bỏ ghim hết rồi mở lại app thấy
/// sáu mục mặc định mọc lại.
@MainActor
final class KhoGhim: ObservableObject {
    static let shared = KhoGhim()
    static let khoa = "tatCa.ghim"

    @Published private(set) var ds: [TinhNang]
    private let kho: UserDefaults

    init(kho: UserDefaults = .standard) {
        self.kho = kho
        ds = Self.doc(kho)
    }

    static func doc(_ kho: UserDefaults) -> [TinhNang] {
        guard let chuoi = kho.string(forKey: khoa) else { return TinhNang.ghimMacDinh }
        var thay = Set<TinhNang>()
        return chuoi.split(separator: ",").compactMap { TinhNang(rawValue: String($0)) }
            .filter { thay.insert($0).inserted }   // bỏ trùng, giữ lần đầu
    }

    func coGhim(_ f: TinhNang) -> Bool { ds.contains(f) }

    func ghim(_ f: TinhNang) {
        guard !ds.contains(f) else { return }
        ds.append(f)
        luu()
    }

    func boGhim(_ f: TinhNang) {
        ds.removeAll { $0 == f }
        luu()
    }

    func batTat(_ f: TinhNang) { coGhim(f) ? boGhim(f) : ghim(f) }

    func diChuyen(tu nguon: IndexSet, toi dich: Int) {
        ds.move(fromOffsets: nguon, toOffset: dich)
        luu()
    }

    func veMacDinh() {
        ds = TinhNang.ghimMacDinh
        kho.removeObject(forKey: Self.khoa)
    }

    private func luu() {
        kho.set(ds.map(\.rawValue).joined(separator: ","), forKey: Self.khoa)
    }
}
