import SwiftUI
#if canImport(PencilKit)
import PencilKit
#endif

// MARK: - Bố cục chữ chảy theo dòng

/// Xếp các phần tử theo dòng, xuống dòng khi hết bề ngang — như chữ thật.
///
/// `HStack` trong `VStack` không làm được việc này: phải biết trước mỗi dòng
/// chứa mấy từ, mà điều đó phụ thuộc bề rộng thật của từng từ. `Layout` là
/// cách duy nhất đo được kích thước con trước khi quyết định chỗ đặt.
struct LuongChu: Layout {
    var dongCach: CGFloat = 3
    var tuCach: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rong = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var caoDong: CGFloat = 0
        for s in subviews {
            let kt = s.sizeThatFits(.unspecified)
            if x + kt.width > rong, x > 0 {
                x = 0
                y += caoDong + dongCach
                caoDong = 0
            }
            x += kt.width + tuCach
            caoDong = max(caoDong, kt.height)
        }
        return CGSize(width: rong == .infinity ? x : rong, height: y + caoDong)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var caoDong: CGFloat = 0
        for s in subviews {
            let kt = s.sizeThatFits(.unspecified)
            if x + kt.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += caoDong + dongCach
                caoDong = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(kt))
            x += kt.width + tuCach
            caoDong = max(caoDong, kt.height)
        }
    }
}

// MARK: - Đoạn văn chạm được từng từ

/// Hiện một đoạn văn mà **mỗi từ chạm được**.
///
/// Dùng `Text` + `.onTapGesture` chứ KHÔNG dùng `Button`: một đoạn 150 từ là
/// 150 phần tử, và `Button` mang theo cả bộ máy kiểu nút (nền, hiệu ứng nhấn,
/// trạng thái) cho từng cái. `Text` trần nhẹ hơn hẳn, mà thứ duy nhất cần ở
/// đây là biết người học chạm vào từ nào.
///
/// Dấu câu bám vào từ khi HIỆN (để đoạn văn đọc ra vẫn đúng) nhưng bị gỡ khi
/// GỬI đi hỏi — tra nghĩa của `"address,"` thì model phải đoán xem dấu phẩy
/// có phải một phần của từ không.
struct ChuChamDuoc: View {
    let chu: String
    var cachDong: CGFloat = 5
    let chonTu: (String) -> Void

    @State private var tuDangSang: Int?

    private var tu: [String] {
        chu.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
    }

    var body: some View {
        LuongChu(dongCach: cachDong, tuCach: 0) {
            ForEach(Array(tu.enumerated()), id: \.offset) { i, t in
                Text(t + " ")
                    .font(.system(size: 17))
                    .foregroundStyle(AppColors.textPrimary)
                    .background(tuDangSang == i ? AppColors.primary.opacity(0.25) : .clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Nháy sáng rồi tắt: không có phản hồi thì chạm trượt
                        // và chạm trúng nhìn y hệt nhau.
                        tuDangSang = i
                        Haptics.cham()
                        chonTu(t.trimmingCharacters(in: .punctuationCharacters))
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                            if tuDangSang == i { tuDangSang = nil }
                        }
                    }
            }
        }
    }
}

// MARK: - Lớp tô bằng Apple Pencil

#if os(iOS)
/// Lớp PencilKit phủ lên bài đọc để gạch chân / tô sáng bằng Apple Pencil.
///
/// Nét lưu **ngay trên máy**, theo id bài, trong `Documents/ielts-to/`. Cố ý
/// không đồng bộ: nét tô là thứ riêng của một lần đọc, và đẩy vài trăm KB lên
/// R2 cho mỗi bài đọc là trả tiền lưu trữ cho thứ không ai mở lại.
struct LopToIelts: UIViewRepresentable {
    let maBai: String

    static func thuMuc() -> URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ielts-to", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    /// Máy này có Apple Pencil chưa. `UIPencilInteraction.prefersPencilOnlyDrawing`
    /// chỉ đúng trên iPad; iPhone luôn trả về false, và đó là câu trả lời đúng.
    static func coBut() -> Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var duong: URL { Self.thuMuc().appendingPathComponent("\(maBai).drawing") }

    func makeUIView(context: Context) -> PKCanvasView {
        let v = PKCanvasView()
        v.backgroundColor = .clear
        v.isOpaque = false
        // `.pencilOnly` chứ không `.anyInput`: ngón tay phải còn CUỘN được
        // bài đọc. Để `.anyInput` thì bật lớp tô lên là bài đọc đứng im, và
        // người dùng tưởng app treo.
        v.drawingPolicy = .pencilOnly
        v.tool = PKInkingTool(.marker, color: UIColor.systemYellow.withAlphaComponent(0.45), width: 18)
        if let d = try? Data(contentsOf: duong), let dr = try? PKDrawing(data: d) {
            v.drawing = dr
        }
        v.delegate = context.coordinator
        context.coordinator.duong = duong
        return v
    }

    func updateUIView(_ v: PKCanvasView, context: Context) {}

    func makeCoordinator() -> Luu { Luu() }

    final class Luu: NSObject, PKCanvasViewDelegate {
        var duong: URL?
        private var hen: DispatchWorkItem?

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // Hoãn 1,2 giây rồi mới ghi: `didChange` bắn sau MỖI nét, và ghi
            // đĩa theo từng nét làm giật tay khi tô nhanh.
            hen?.cancel()
            let d = canvasView.drawing.dataRepresentation()
            guard let u = duong else { return }
            let viec = DispatchWorkItem { try? d.write(to: u, options: .atomic) }
            hen = viec
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.2, execute: viec)
        }
    }
}
#else
struct LopToIelts: View {
    let maBai: String
    static func coBut() -> Bool { false }
    var body: some View { Color.clear }
}
#endif
