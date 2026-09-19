import SwiftUI

/// Nút đổi giọng đọc, đặt ở MỌI màn IELTS có phát tiếng.
///
/// Vì sao cần: `DocTu` vốn ĐÃ tôn trọng giọng người dùng chọn
/// (`CaiDatGiong.luaChon("en")`) — nhưng màn chọn giọng chỉ mở được từ My
/// Language (`NgonNguView`). Người học IELTS không có lý do nào đi vào đó,
/// nên họ nghe mãi giọng mặc định của hệ thống rồi kết luận app đọc dở.
/// Người dùng báo 19/09/2026: *"giọng mặc định khó nghe quá"* — và đúng là
/// không có nút nào để đổi.
///
/// Bài học chung: một thiết lập chỉ có giá trị ở nơi người ta NGHE THẤY vấn
/// đề. Cài nó vào một màn khác thì bằng không có.
struct NutGiongIelts: View {
    @State private var mo = false

    var body: some View {
        Button { mo = true } label: {
            Image(systemName: "waveform")
        }
        .accessibilityLabel(T("Đổi giọng đọc"))
        .sheet(isPresented: $mo) {
            ChonGiongView(code: "en", tenNgonNgu: T("Tiếng Anh"))
        }
    }
}
