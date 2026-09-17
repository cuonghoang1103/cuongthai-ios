import Foundation
import SwiftData

/// Kho SwiftData của Vở.
///
/// ⚠️ Dựng THỦ CÔNG chứ không dùng `.modelContainer(for:)` của SwiftUI, vì
/// container đó dựng lại theo vòng đời của view và nuốt lỗi mở kho: schema
/// hỏng thì nó chỉ `fatalError` ở một chỗ không nói được gì. Ở đây nếu mở
/// thất bại thì LÙI sang kho trong bộ nhớ — app vẫn chạy, vở của phiên này
/// vẫn viết được, và người dùng thấy cảnh báo thay vì màn hình đen.
///
/// Nét vẽ KHÔNG nằm trong kho này (xem `KhoVo`) nên kho hỏng cũng không mất
/// bài — chỉ mất tên môn và thứ tự trang, dựng lại được.
@MainActor
enum KhoSwiftData {
    private(set) static var loiMoKho: String?

    static let chung: ModelContainer = {
        let schema = Schema([MonVo.self, CuonVo.self, TrangVo.self, ViecXoaCho.self, TienDoChu.self])
        let cauHinh = ModelConfiguration("Vo", schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [cauHinh])
        } catch {
            loiMoKho = error.localizedDescription
            let tam = ModelConfiguration("VoTam", schema: schema, isStoredInMemoryOnly: true)
            // Kho tạm cũng hỏng thì không còn gì để làm — nhưng để nó ném ở
            // đây, kèm mô tả, thay vì `try!` không lời.
            return try! ModelContainer(for: schema, configurations: [tam])
        }
    }()
}
