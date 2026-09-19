import SwiftUI
#if canImport(PencilKit)
import PencilKit
#endif

/// Chia đôi màn: nội dung bên trái, giấy nháp bên phải.
///
/// Đây là thứ iPad làm được mà iPhone không: đọc một bài 300 từ và ghi ý ra
/// giấy CÙNG LÚC, không phải nhớ rồi chuyển màn. Trên màn hẹp nó vô nghĩa —
/// hai cột 190pt thì cột nào cũng không đọc nổi — nên lối vào chỉ hiện trên
/// iPad, và nếu cửa sổ bị kéo hẹp lại thì nó tự xếp chồng dọc.
///
/// Vạch chia KÉO ĐƯỢC. Cố định 50/50 nghe hợp lý cho tới lúc người dùng gặp
/// một bài đọc dài: lúc đó họ cần 70% cho bài và 30% cho nháp, và một vạch
/// không kéo được biến cả tính năng thành thứ dùng một lần rồi thôi.
struct ChiaDoiView<Trai: View, Phai: View>: View {
    let trai: Trai
    let phai: Phai
    /// Khoá để nhớ tỉ lệ vạch chia của riêng màn này.
    let khoa: String

    @State private var tiLe: Double = 0.58
    @State private var keoTu: Double?

    init(khoa: String, @ViewBuilder trai: () -> Trai, @ViewBuilder phai: () -> Phai) {
        self.khoa = khoa
        self.trai = trai()
        self.phai = phai()
    }

    private var khoaLuu: String { "chiadoi.tile.\(khoa)" }

    var body: some View {
        GeometryReader { g in
            // 640pt là ngưỡng đo thật: hẹp hơn thì cột nội dung xuống dưới
            // 380pt và một dòng văn xuôi bắt đầu gãy ở giữa cụm từ.
            if g.size.width >= 640 {
                HStack(spacing: 0) {
                    trai.frame(width: max(220, g.size.width * tiLe))
                    vach(g.size.width)
                    phai.frame(maxWidth: .infinity)
                }
            } else {
                VStack(spacing: 0) {
                    trai.frame(height: g.size.height * 0.55)
                    Divider()
                    phai.frame(maxHeight: .infinity)
                }
            }
        }
        .task {
            let v = UserDefaults.standard.double(forKey: khoaLuu)
            if v > 0.2 && v < 0.85 { tiLe = v }
        }
    }

    private func vach(_ rong: Double) -> some View {
        ZStack {
            Rectangle().fill(AppColors.divider).frame(width: 1)
            // Vùng bắt kéo rộng 16pt nhưng chỉ VẼ 1pt: một vạch 1pt thì ngón
            // tay không bao giờ trúng, mà vẽ dày 16pt thì nhìn như lỗi bố cục.
            Rectangle().fill(Color.clear).frame(width: 16).contentShape(Rectangle())
            Capsule().fill(AppColors.textTertiary.opacity(0.5))
                .frame(width: 3, height: 34)
        }
        .frame(width: 16)
        .gesture(
            DragGesture()
                .onChanged { g in
                    let goc = keoTu ?? tiLe
                    if keoTu == nil { keoTu = tiLe }
                    tiLe = min(0.82, max(0.24, goc + g.translation.width / rong))
                }
                .onEnded { _ in
                    keoTu = nil
                    UserDefaults.standard.set(tiLe, forKey: khoaLuu)
                }
        )
        #if os(iOS)
        .hoverEffect(.lift)
        #endif
    }
}

// MARK: - Giấy nháp

#if os(iOS)
/// Giấy nháp dùng chung cho màn chia đôi — viết bằng Pencil hoặc ngón tay.
///
/// Khác lớp tô của bài đọc (`LopToIelts`) ở chỗ nó là GIẤY TRẮNG riêng, không
/// phủ lên chữ: chỗ này để ghi ý của mình, không phải để gạch chân bài người
/// khác. Nên `drawingPolicy` là `.anyInput` — không có gì bên dưới để cuộn,
/// và bắt người dùng phải có Pencil mới ghi được là chặn vô cớ.
struct GiayNhapView: UIViewRepresentable {
    let ma: String

    static func thuMuc() -> URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ielts-nhap", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    private var duong: URL { Self.thuMuc().appendingPathComponent("\(ma).drawing") }

    func makeUIView(context: Context) -> PKCanvasView {
        let v = PKCanvasView()
        v.backgroundColor = UIColor.systemBackground
        v.drawingPolicy = .anyInput
        v.tool = PKInkingTool(.pen, color: .label, width: 3)
        v.alwaysBounceVertical = true
        if let d = try? Data(contentsOf: duong), let dr = try? PKDrawing(data: d) { v.drawing = dr }
        v.delegate = context.coordinator
        context.coordinator.duong = duong

        // Bảng công cụ để đổi bút/màu/tẩy. Không có nó thì giấy nháp chỉ viết
        // được đúng một màu một cỡ, và người dùng tưởng app thiếu tính năng.
        // ⚠️ Gắn theo ĐÚNG cửa sổ của bảng vẽ — xem chú thích cùng nội
        // dung ở `KhungVeView`. Bản cũ còn rơi về `connectedScenes.first`
        // khi `v.window` chưa có, mà cửa sổ đầu tiên thì chẳng liên quan gì.
        if let cuaSo = v.window {
            let picker = PKToolPicker.shared(for: cuaSo)
            picker?.addObserver(v)
            picker?.setVisible(true, forFirstResponder: v)
            context.coordinator.picker = picker
        }
        DispatchQueue.main.async { v.becomeFirstResponder() }
        return v
    }

    func updateUIView(_ v: PKCanvasView, context: Context) {}

    func makeCoordinator() -> Luu { Luu() }

    final class Luu: NSObject, PKCanvasViewDelegate {
        var duong: URL?
        var picker: PKToolPicker?
        private var hen: DispatchWorkItem?

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
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
struct GiayNhapView: View {
    let ma: String
    var body: some View { Color.clear }
}
#endif

// MARK: - Đọc và ghi cùng lúc

/// Bài đọc bên trái, giấy nháp bên phải.
struct DocVaGhiView: View {
    @ObservedObject var vm: IeltsVM
    let bai: BaiDocIelts
    @Environment(\.dismiss) private var dong

    var body: some View {
        ChiaDoiView(khoa: "docvaghi") {
            ScrollView {
                BaiDocIeltsView(vm: vm, bai: bai, gonTrongChiaDoi: true)
            }
        } phai: {
            VStack(spacing: 0) {
                HStack {
                    Label(T("Giấy nháp"), systemImage: "square.and.pencil")
                        .font(.captionBold).foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    Text(T("Tự lưu")).font(.caption2).foregroundStyle(AppColors.textTertiary)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(AppColors.backgroundCard)
                Divider()
                GiayNhapView(ma: bai.id)
            }
        }
        .navigationTitle(bai.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
