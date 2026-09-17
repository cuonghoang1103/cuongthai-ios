#if os(iOS)
import PencilKit
import SwiftUI

/// Luyện viết một chữ bằng Apple Pencil, chấm từng nét.
///
/// Khác `LuyenVietView` cũ (ngón tay + `DragGesture` + `Path`): ở đây là
/// `PKCanvasView`, nên có độ trễ bút của hệ thống (~9ms), có lực nhấn và độ
/// nghiêng, và nét hiện ra đúng như viết bút thật. Phần CHẤM thì dùng lại
/// nguyên `ChamNet` đã có — nó nhận `[CGPoint]`, và một nét PencilKit đổi
/// sang mảng điểm là xong.
struct LuyenVietPencil: View {
    let chu: String
    let phienAm: String?
    let lang: String
    /// Gọi khi người học viết xong cả chữ.
    var khiXong: (() -> Void)?

    @Environment(\.dismiss) private var dong
    @State private var net: NetChu?
    @State private var dangTai = true
    @State private var loiTai: String?
    @State private var netHienTai = 0
    @State private var soLanSai = 0
    @State private var hienGoiY = false
    @State private var xong = false
    @State private var mucDo: MucDo = .toMo
    /// Dữ liệu nét của máy chủ có khớp số nét chuẩn không. Sai thì KHÔNG
    /// chấm từng nét — xem `SoNetChuan`.
    @State private var chamDuoc = true
    @State private var banVe = PKDrawing()
    @State private var lanXoa = 0
    @State private var bao: String?

    enum MucDo: String, CaseIterable, Identifiable {
        case toMo, theoMoc, tuDo
        var id: String { rawValue }
        var ten: String {
            switch self {
            case .toMo:    return T("Tô mờ")
            case .theoMoc: return T("Theo mốc")
            case .tuDo:    return T("Tự do")
            }
        }
        var moTa: String {
            switch self {
            case .toMo:    return T("Chữ mẫu mờ bên dưới — tô theo")
            case .theoMoc: return T("Chỉ chấm đầu nét — tự nhớ hướng")
            case .tuDo:    return T("Không gợi ý gì — viết từ trí nhớ")
            }
        }
    }

    /// Ô viết. Vuông, và mọi toạ độ (nét người viết lẫn đường tim) đều quy
    /// về cạnh này — lệch một chút là chấm sai hết.
    private var canh: CGFloat { 420 }

    var body: some View {
        VStack(spacing: Spacing.md) {
            thanhDau

            if dangTai {
                Spacer(); ProgressView(); Spacer()
            } else if let loiTai {
                Spacer()
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "questionmark.square.dashed")
                        .font(.system(size: 40))
                        .foregroundStyle(AppColors.textTertiary)
                    Text(loiTai).font(Font.bodyMedium)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            } else if let n = net {
                oViet(n)
                thanhDuoi(n)
            }
        }
        .background(AppColors.backgroundPrimary)
        .overlay(alignment: .top) { loiNhan }
        .animation(AppAnimations.quick, value: bao)
        .task { await tai() }
    }

    // MARK: Thanh trên

    private var thanhDau: some View {
        HStack(spacing: Spacing.md) {
            Button { dong() } label: { Image(systemName: "xmark.circle.fill") }
                .foregroundStyle(AppColors.textTertiary)

            VStack(spacing: 0) {
                Text(chu).font(.system(size: 30, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary)
                if let phienAm, !phienAm.isEmpty {
                    Text(phienAm).font(.caption).foregroundStyle(AppColors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)

            Picker("", selection: $mucDo) {
                ForEach(MucDo.allCases) { Text($0.ten).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)
            .disabled(!chamDuoc)
            .onChange(of: mucDo) { _, _ in lamLai() }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(AppColors.backgroundSecondary)
    }

    // MARK: Ô viết

    private func oViet(_ n: NetChu) -> some View {
        ZStack {
            // Ô kiểu 原稿用紙: khung + chữ thập mờ để canh chữ vào tâm.
            OGenkou(canh: canh)

            // Chữ mẫu mờ — chỉ ở mức "Tô mờ".
            if mucDo == .toMo {
                // ⚠️ `.fill`, KHÔNG phải `.stroke`. Path trong dữ liệu là
                // ĐƯỜNG VIỀN của nét (outline), không phải đường tim — tô
                // viền của một đường viền thì ra nét đôi rỗng ruột. Màn
                // `LuyenVietView` cũ cũng `.fill`, và hai màn dùng CHUNG một
                // nguồn dữ liệu nên phải vẽ giống nhau.
                ChuMau(net: n, canh: canh, denNet: n.strokes.count)
                    .fill(AppColors.textPrimary.opacity(0.13))
            }

            // Các nét ĐÃ viết đúng — vẽ lại bằng chữ mẫu để nét luôn đẹp,
            // thay vì giữ nguyên nét nguệch ngoạc của người học.
            if netHienTai > 0 {
                ChuMau(net: n, canh: canh, denNet: netHienTai)
                    .fill(AppColors.textPrimary)
            }

            // Gợi ý nét hiện tại: hiện khi xin, hoặc sau 2 lần sai.
            if (hienGoiY || soLanSai >= 2), netHienTai < n.strokes.count {
                MotNet(net: n, canh: canh, chiSo: netHienTai)
                    .stroke(AppColors.primary.opacity(0.55),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round, dash: [10, 8]))
                DauBatDau(net: n, canh: canh, chiSo: netHienTai)
            } else if mucDo == .theoMoc, netHienTai < n.strokes.count {
                DauBatDau(net: n, canh: canh, chiSo: netHienTai)
            }

            // Khung vẽ trong suốt nằm trên cùng.
            KhungVietMotNet(banVe: $banVe, lanXoa: lanXoa) { net in
                chamMotNet(net)
            }
            .frame(width: canh, height: canh)
        }
        .frame(width: canh, height: canh)
        .background(AppColors.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .strokeBorder(AppColors.border, lineWidth: 1))
    }

    // MARK: Thanh dưới

    private func thanhDuoi(_ n: NetChu) -> some View {
        VStack(spacing: Spacing.sm) {
            if chamDuoc {
            HStack(spacing: Spacing.xs) {
                ForEach(0..<n.strokes.count, id: \.self) { i in
                    Capsule()
                        .fill(i < netHienTai ? AppColors.success
                              : (i == netHienTai ? AppColors.primary : AppColors.divider))
                        .frame(height: 5)
                }
            }
            .frame(maxWidth: canh)

            Text(xong ? T("Xong — viết đúng cả \(n.strokes.count) nét")
                      : "\(T("Nét")) \(netHienTai + 1)/\(n.strokes.count)")
                .font(Font.bodyMedium)
                .foregroundStyle(xong ? AppColors.success : AppColors.textSecondary)
            }

            HStack(spacing: Spacing.md) {
                Button { hienGoiY.toggle() } label: {
                    Label(hienGoiY ? T("Ẩn gợi ý") : T("Gợi ý"), systemImage: "lightbulb")
                }
                Button { lamLai() } label: {
                    Label(T("Làm lại"), systemImage: "arrow.counterclockwise")
                }
                if xong {
                    Button { khiXong?(); dong() } label: {
                        Label(T("Chữ tiếp"), systemImage: "arrow.right")
                    }
                    .fontWeight(.semibold)
                }
            }
            .font(Font.bodyMedium)
            .padding(.top, Spacing.xs)

            if chamDuoc {
                Text(mucDo.moTa).font(.caption).foregroundStyle(AppColors.textTertiary)
            } else {
                Label(T("Chữ này chưa có dữ liệu nét chuẩn — cứ tô theo mẫu, app không chấm từng nét"),
                      systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(AppColors.warning)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, Spacing.sm)
    }

    private var loiNhan: some View {
        Group {
            if let bao {
                Text(bao)
                    .font(Font.bodyMedium.weight(.semibold))
                    .foregroundStyle(AppColors.onPrimary)
                    .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm)
                    .background(Capsule().fill(AppColors.primary.opacity(0.92)))
                    .padding(.top, 70)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: Chấm

    /// Chấm MỘT nét vừa viết xong.
    ///
    /// ⚠️ Chấm ngay khi nhấc bút, không đợi viết hết chữ. Sai ở nét thứ ba
    /// mà tới cuối mới báo thì người học đã viết sai thêm bốn nét nữa, và
    /// không biết hỏng từ đâu.
    private func chamMotNet(_ diem: [CGPoint]) {
        guard chamDuoc else { return }   // dữ liệu nét lệch chuẩn: chỉ cho tô
        guard let n = net, netHienTai < n.strokes.count, !xong else { return }
        let tim = n.duongTim(netHienTai, canh: canh)
        if ChamNet.dat(nguoiVe: diem, duongTim: tim, canh: canh) {
            netHienTai += 1
            soLanSai = 0
            hienGoiY = false
            lanXoa += 1                    // xoá nét thô, để bản vẽ đẹp hiện lên
            if netHienTai >= n.strokes.count {
                xong = true
                khoe(T("Xong! Đúng cả \(n.strokes.count) nét"))
            }
        } else {
            soLanSai += 1
            lanXoa += 1
            khoe(soLanSai >= 2 ? T("Chưa đúng — xem nét gợi ý") : T("Chưa đúng, viết lại nét này"))
        }
    }

    private func khoe(_ s: String) {
        bao = s
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            if bao == s { bao = nil }
        }
    }

    private func lamLai() {
        netHienTai = 0
        soLanSai = 0
        xong = false
        hienGoiY = false
        lanXoa += 1
    }

    private func tai() async {
        dangTai = true
        defer { dangTai = false }
        if let n = await KhoNetChu.shared.lay(chu, lang: lang) {
            net = n
            chamDuoc = SoNetChuan.chamTungNetDuoc(chu: chu, soNetMayChu: n.strokes.count)
            if !chamDuoc {
                mucDo = .toMo
                NhatKy.vo.info("nét '\(chu)': máy chủ trả \(n.strokes.count), chuẩn \(SoNetChuan.cua(chu) ?? -1) — chỉ cho tô theo mẫu")
            }
        } else {
            loiTai = T("Chưa có dữ liệu nét cho chữ này.\nBạn vẫn viết được ở Vở thường.")
        }
    }
}

// MARK: - Khung vẽ một nét

/// `PKCanvasView` rút gọn: mỗi lần nhấc bút là trả về MỘT nét dạng mảng điểm
/// rồi tự xoá, để màn ngoài chấm và tự vẽ lại cho đẹp.
private struct KhungVietMotNet: UIViewRepresentable {
    @Binding var banVe: PKDrawing
    let lanXoa: Int
    let khiXongMotNet: ([CGPoint]) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let c = PKCanvasView()
        c.backgroundColor = .clear
        c.isOpaque = false
        c.delegate = context.coordinator
        c.drawingPolicy = .default
        c.tool = PKInkingTool(.pen, color: .label, width: 12)
        // Không cuộn, không phóng: đây là một ô cố định, mọi toạ độ phải
        // trùng khít với đường tim thì chấm mới đúng.
        c.isScrollEnabled = false
        c.minimumZoomScale = 1
        c.maximumZoomScale = 1
        return c
    }

    func updateUIView(_ c: PKCanvasView, context: Context) {
        if context.coordinator.lanXoaDaLam != lanXoa {
            context.coordinator.lanXoaDaLam = lanXoa
            c.drawing = PKDrawing()
        }
    }

    func makeCoordinator() -> Dieu { Dieu(khiXongMotNet: khiXongMotNet) }

    final class Dieu: NSObject, PKCanvasViewDelegate {
        let khiXongMotNet: ([CGPoint]) -> Void
        var lanXoaDaLam = 0
        private var soNetTruoc = 0

        init(khiXongMotNet: @escaping ([CGPoint]) -> Void) {
            self.khiXongMotNet = khiXongMotNet
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let strokes = canvasView.drawing.strokes
            // Chỉ xử lý khi có nét MỚI. `canvasViewDrawingDidChange` còn bắn
            // lúc ta tự gán `drawing = PKDrawing()`, và coi đó là "vừa viết"
            // thì mỗi lần xoá lại chấm thêm một lần nữa.
            guard strokes.count > soNetTruoc, let cuoi = strokes.last else {
                soNetTruoc = strokes.count
                return
            }
            soNetTruoc = strokes.count
            khiXongMotNet(Self.diemCua(cuoi))
        }

        /// Đổi một nét PencilKit thành mảng điểm để `ChamNet` đọc được.
        ///
        /// Lấy mẫu theo KHOẢNG CÁCH chứ không theo số điểm: viết nhanh và
        /// viết chậm cho ra số điểm rất khác nhau, mà hình dạng mới là thứ
        /// cần chấm.
        static func diemCua(_ stroke: PKStroke) -> [CGPoint] {
            let duong = stroke.path
            var ds: [CGPoint] = []
            for diem in duong.interpolatedPoints(by: .distance(3)) {
                ds.append(diem.location.applying(stroke.transform))
            }
            if ds.isEmpty {
                ds = duong.map { $0.location.applying(stroke.transform) }
            }
            return ds
        }
    }
}

// MARK: - Hình vẽ phụ

private struct OGenkou: View {
    let canh: CGFloat
    var body: some View {
        ZStack {
            Rectangle().strokeBorder(AppColors.border, lineWidth: 1)
            Path { p in
                p.move(to: CGPoint(x: canh / 2, y: 0)); p.addLine(to: CGPoint(x: canh / 2, y: canh))
                p.move(to: CGPoint(x: 0, y: canh / 2)); p.addLine(to: CGPoint(x: canh, y: canh / 2))
            }
            .stroke(AppColors.divider, style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
        }
    }
}

private struct ChuMau: Shape {
    let net: NetChu
    let canh: CGFloat
    let denNet: Int
    func path(in rect: CGRect) -> Path {
        var p = Path()
        for i in 0..<min(denNet, net.strokes.count) {
            p.addPath(DuongSVG.doi(net.strokes[i], canh: canh))
        }
        return p
    }
}

private struct MotNet: Shape {
    let net: NetChu
    let canh: CGFloat
    let chiSo: Int
    func path(in rect: CGRect) -> Path {
        guard net.medians.indices.contains(chiSo) else { return Path() }
        var p = Path()
        let diem = net.duongTim(chiSo, canh: canh)
        guard let dau = diem.first else { return p }
        p.move(to: dau)
        for d in diem.dropFirst() { p.addLine(to: d) }
        return p
    }
}

/// Chấm tròn đánh dấu ĐẦU nét — thứ quyết định viết đúng hướng hay không.
private struct DauBatDau: View {
    let net: NetChu
    let canh: CGFloat
    let chiSo: Int
    var body: some View {
        if let dau = net.duongTim(chiSo, canh: canh).first {
            Circle()
                .fill(AppColors.primary)
                .frame(width: 16, height: 16)
                .position(dau)
                .overlay(
                    Circle().stroke(AppColors.primary.opacity(0.3), lineWidth: 8)
                        .frame(width: 26, height: 26).position(dau)
                )
        }
    }
}
#endif
