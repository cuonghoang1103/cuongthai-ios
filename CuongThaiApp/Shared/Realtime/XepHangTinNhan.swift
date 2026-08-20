import Foundation

/// Chỗ chèn một hội thoại vừa có tin mới vào danh sách.
///
/// Tách riêng khỏi `MessagesViewModel` để kiểm được bằng `swiftc` — luật ghim
/// ở đây nhìn thì hiển nhiên, nhưng sai một chỗ là hàng ghim bị tin mới đẩy
/// xuống và người dùng mất luôn cái mình đã cố định.
///
/// - Parameters:
///   - daGhimTheoThuTu: cờ ghim của danh sách SAU KHI đã bỏ hàng cũ ra.
///   - hangDuocGhim: hàng vừa có tin mới có đang được ghim không.
/// - Returns: chỉ số để chèn vào.
public func viTriChen(daGhimTheoThuTu: [Bool], hangDuocGhim: Bool) -> Int {
    // Hàng ghim lên đầu hẳn: giữa mấy hàng ghim với nhau thì mới nhất trước.
    if hangDuocGhim { return 0 }
    // Hàng thường phải nằm DƯỚI mọi hàng ghim, nhưng TRÊN mọi hàng thường.
    return daGhimTheoThuTu.prefix(while: { $0 }).count
}
