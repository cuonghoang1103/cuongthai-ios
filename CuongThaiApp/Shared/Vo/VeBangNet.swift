#if os(iOS)
import SwiftUI

// ════════════════════════════════════════════════════════════════
// VẼ GIÚP — AI vẽ bằng NÉT BÚT cho vở
//
// Máy chủ (`POST /api/v1/vo/ve`) nhờ model viết một SVG nét đơn rồi tự đổi ra
// danh sách điểm, co về khung cạnh dài = 1000. App chỉ việc:
//   · xem trước bằng `Path` (đúng thứ tự vẽ của model),
//   · đưa `HinhVeAI` cho màn viết đặt lên trang thành `PKStroke` thật —
//     người học tẩy/sửa/tô tiếp được như nét của chính mình.
//
// Vì sao là NÉT chứ không phải ẢNH: ảnh dán lên trang thì chết cứng, không
// sửa được một nét nào, và trông lạc loài giữa chữ viết tay.
//
// ⚠️ Chạy 30–90 giây (gpt-6-sol). `APIEndpoint.voVe` có `thoiGianCho` riêng;
// để mặc định 60 giây là app bỏ cuộc trong khi máy chủ vẫn vẽ và vẫn trừ hạn
// mức. Trạng thái sống ở `MayVe` do `TroLyTrang` giữ, nên đóng khung giữa
// chừng KHÔNG huỷ lượt vẽ — mở lại là thấy tiếp.
// ════════════════════════════════════════════════════════════════

/// Một hình AI vẽ, toạ độ trong khung `rong × cao` (cạnh dài = 1000).
struct HinhVeAI {
    let net: [[CGPoint]]
    let rong: CGFloat
    let cao: CGFloat
    /// Nhãn gợi ý (chỉ sơ đồ) — người học TỰ viết vào, AI không viết chữ hộ.
    let nhan: [String]
}

enum KieuVe: String, CaseIterable, Identifiable {
    case hinh, sodo
    var id: String { rawValue }

    var ten: String { self == .hinh ? T("Tranh") : T("Sơ đồ học tập") }
    var bieuTuong: String { self == .hinh ? "paintpalette" : "point.3.connected.trianglepath.dotted" }
    var moTa: String { self == .hinh ? T("Nét phác tự do") : T("Rõ khối, có nhãn") }
}

// MARK: - Gọi máy chủ

enum VeBangNet {
    /// Hình dạng câu trả lời. Mọi trường `var` + optional — xem C4 trong
    /// CLAUDE.md của kho: `let` có mặc định thì `Codable` bỏ qua im lặng.
    private struct KetQua: Decodable {
        var net: [[[Double]]]?
        var rong: Double?
        var cao: Double?
        var nhan: [String]?
        var model: String?
    }

    static func ve(de: String, kieu: KieuVe) async throws -> (HinhVeAI, String?) {
        // Chốt đồng ý chia sẻ với AI chạy trong `APIClient` (`laDuongAI` bắt
        // `POST /vo/ve` từ 28/09/2026). Đừng gọi thêm `batBuoc()` ở đây — hai
        // chốt là người dùng chưa đồng ý bị hỏi HAI lần liền.
        let kq: KetQua = try await APIClient.shared.request(.voVe(de: de, kieu: kieu.rawValue))
        let net: [[CGPoint]] = (kq.net ?? []).compactMap { n in
            let d = n.compactMap { p in p.count >= 2 ? CGPoint(x: p[0], y: p[1]) : nil }
            return d.isEmpty ? nil : d
        }
        guard !net.isEmpty else {
            throw APIError.coMa(ma: "VE_RONG", thongDiep: T("AI chưa vẽ được hình này — thử mô tả khác một chút."))
        }
        let hinh = HinhVeAI(net: net, rong: CGFloat(max(kq.rong ?? 1000, 1)),
                            cao: CGFloat(max(kq.cao ?? 1000, 1)), nhan: kq.nhan ?? [])
        return (hinh, kq.model)
    }

    /// Câu người dùng đọc. Máy chủ đã viết sẵn tiếng Việt cho các mã lỗi của
    /// nó; chỉ phải dịch hai chỗ nó không nói được: mất kết nối và 404 (bản
    /// app đi trước bản máy chủ — tuyến chưa lên production).
    static func cauLoi(_ e: Error) -> String {
        if let u = e as? URLError, u.code == .timedOut {
            return T("Chờ quá lâu mà chưa có hình. Thử lại, hoặc mô tả ngắn gọn hơn.")
        }
        if case APIError.serverError(let m) = e, m.contains("404") || m.contains("not found") {
            return T("Máy chủ chưa có tính năng vẽ — sắp có.")
        }
        return (e as? LocalizedError)?.errorDescription ?? e.localizedDescription
    }
}

// MARK: - Trạng thái

@MainActor
final class MayVe: ObservableObject {
    enum TrangThai {
        case rong
        case dangVe(batDau: Date)
        case xong(HinhVeAI, model: String?)
        case loi(String)
    }

    @Published var de = ""
    @Published var kieu: KieuVe = .hinh
    @Published private(set) var trangThai: TrangThai = .rong
    private var viec: Task<Void, Never>?

    var dangVe: Bool { if case .dangVe = trangThai { return true } else { return false } }
    var hinh: HinhVeAI? { if case .xong(let h, _) = trangThai { return h } else { return nil } }

    func ve() {
        let d = de.trimmingCharacters(in: .whitespacesAndNewlines)
        guard d.count >= 2, !dangVe else { return }
        trangThai = .dangVe(batDau: Date())
        Haptics.cham()
        let kieu = self.kieu
        viec = Task { [weak self] in
            do {
                let (h, m) = try await VeBangNet.ve(de: d, kieu: kieu)
                guard let self, !Task.isCancelled else { return }
                self.trangThai = .xong(h, model: m)
                Haptics.xong()
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.trangThai = .loi(VeBangNet.cauLoi(error))
                Haptics.hong()
            }
        }
    }

    /// Huỷ phía app. Máy chủ vẫn chạy nốt lượt đó — không có cách gọi nó dừng.
    func huy() {
        viec?.cancel()
        viec = nil
        trangThai = .rong
    }

    func veLai() { trangThai = .rong; ve() }
    func xoaKetQua() { trangThai = .rong }

    #if DEBUG
    /// Chỉ cho bàn thử `CT_TROLY` — dựng trạng thái mà không gọi mạng.
    func gia(_ t: TrangThai) { trangThai = t }
    #endif
}

// MARK: - Xem trước hình

/// Vẽ `HinhVeAI` bằng `Path`, co vừa khung, giữ tỉ lệ.
///
/// Nối điểm bằng đường cong bậc hai qua TRUNG ĐIỂM: nối thẳng từng điểm thì
/// nét tròn ra góc cạnh như đa giác, khác hẳn nét sẽ đặt lên trang.
struct HinhVeXemTruoc: View {
    let hinh: HinhVeAI
    var mau: Color = AppColors.textPrimary
    /// Vẽ dần theo đúng thứ tự nét lúc xuất hiện.
    var veDan = true

    @Environment(\.accessibilityReduceMotion) private var giamChuyenDong
    @State private var tien: CGFloat = 0

    var body: some View {
        GeometryReader { g in
            duong(trong: g.size)
                .trim(from: 0, to: (veDan && !giamChuyenDong) ? tien : 1)
                .stroke(mau, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
        }
        .aspectRatio(hinh.rong / max(hinh.cao, 1), contentMode: .fit)
        .onAppear {
            guard veDan, !giamChuyenDong else { return }
            tien = 0
            let tg = min(2.4, 0.6 + Double(hinh.net.count) * 0.04)
            withAnimation(.easeInOut(duration: tg)) { tien = 1 }
        }
        .accessibilityLabel(T("Hình xem trước"))
    }

    private func duong(trong kho: CGSize) -> Path {
        let ty = min(kho.width / max(hinh.rong, 1), kho.height / max(hinh.cao, 1))
        let leX = (kho.width - hinh.rong * ty) / 2
        let leY = (kho.height - hinh.cao * ty) / 2
        var p = Path()
        for net in hinh.net {
            let d = net.map { CGPoint(x: leX + $0.x * ty, y: leY + $0.y * ty) }
            guard let dau = d.first else { continue }
            p.move(to: dau)
            if d.count == 1 {
                // Một chấm (mắt, dấu chấm) — vẽ thành vòng nhỏ cho thấy được.
                p.addEllipse(in: CGRect(x: dau.x - 1, y: dau.y - 1, width: 2, height: 2))
                continue
            }
            for i in 1..<d.count {
                let giua = CGPoint(x: (d[i - 1].x + d[i].x) / 2, y: (d[i - 1].y + d[i].y) / 2)
                if i == 1 { p.addLine(to: giua) } else { p.addQuadCurve(to: giua, control: d[i - 1]) }
            }
            p.addLine(to: d[d.count - 1])
        }
        return p
    }
}

// MARK: - Khung Vẽ giúp (trong khung hỏi)

struct KhungVeGiup: View {
    @ObservedObject var may: MayVe
    /// `nil` = màn viết chưa nối việc đặt hình lên trang.
    let chen: ((HinhVeAI) -> Void)?
    let dong: () -> Void

    @FocusState private var dangGo: Bool
    @State private var baoSapCo = false

    /// Chip ví dụ: bấm là điền mô tả VÀ chọn luôn kiểu hợp với nó.
    private static let viDu: [(String, KieuVe)] = [
        ("Con mèo ngồi", .hinh),
        ("Chu trình nước", .sodo),
        ("Tế bào thực vật", .sodo),
        ("Trục toạ độ Oxy", .sodo),
        ("Cây xương rồng", .hinh),
        ("Mạch điện nối tiếp", .sodo),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                switch may.trangThai {
                case .rong:              manNhap
                case .dangVe(let luc):   ManChoVe(batDau: luc, de: may.de, huy: may.huy)
                case .xong(let h, let m): manKetQua(h, model: m)
                case .loi(let e):        manLoi(e)
                }
            }
            .padding(Spacing.md)
            .animation(.snappy(duration: 0.25), value: khoaTrangThai)
        }
        .scrollDismissesKeyboard(.interactively)
        .alert(T("Sắp có"), isPresented: $baoSapCo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(T("Đặt hình lên trang đang được hoàn thiện. Tạm thời bạn nhìn hình mẫu và vẽ theo nhé."))
        }
    }

    /// Chuỗi ổn định để khoá hoạt ảnh — xem C6 trong CLAUDE.md của kho.
    private var khoaTrangThai: String {
        switch may.trangThai {
        case .rong: return "rong"
        case .dangVe: return "ve"
        case .xong: return "xong"
        case .loi: return "loi"
        }
    }

    // ── Nhập mô tả ──────────────────────────────────────────────
    @ViewBuilder
    private var manNhap: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(T("Bạn muốn vẽ gì?"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
            Text(T("AI vẽ bằng nét bút — đặt lên trang rồi bạn tẩy, sửa, tô tiếp như nét của mình."))
                .font(.footnote)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        HStack(spacing: Spacing.sm) {
            ForEach(KieuVe.allCases) { k in theKieu(k) }
        }

        TextField(T("Ví dụ: sơ đồ quang hợp có mũi tên…"), text: $may.de, axis: .vertical)
            .font(.body)
            .lineLimit(2...5)
            .focused($dangGo)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.backgroundCard.opacity(0.85)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(dangGo ? AppColors.primary.opacity(0.6) : AppColors.border,
                              lineWidth: dangGo ? 1.5 : 1))

        VStack(alignment: .leading, spacing: 6) {
            Text(T("Gợi ý"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textTertiary)
                .textCase(.uppercase)
            LuoiChip(khoangCach: 6) {
                ForEach(Self.viDu, id: \.0) { chu, kieu in
                    Button {
                        may.de = T(chu)
                        may.kieu = kieu
                        Haptics.cham()
                    } label: {
                        Text(T(chu))
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(AppColors.primary.opacity(0.09)))
                            .overlay(Capsule().strokeBorder(AppColors.primary.opacity(0.18), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        Button {
            dangGo = false
            may.ve()
        } label: {
            Label(T("Vẽ giúp mình"), systemImage: "paintbrush.pointed.fill")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .foregroundStyle(AppColors.onPrimary)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [AppColors.primary, AppColors.brandPink],
                                         startPoint: .leading, endPoint: .trailing)))
                .opacity(coTheVe ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!coTheVe)

        Label(T("Thường mất 30–90 giây. Đóng khung vẫn vẽ tiếp."), systemImage: "clock")
            .font(.caption)
            .foregroundStyle(AppColors.textTertiary)
    }

    private var coTheVe: Bool {
        may.de.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    private func theKieu(_ k: KieuVe) -> some View {
        let chon = may.kieu == k
        return Button {
            may.kieu = k
            Haptics.cham()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: k.bieuTuong)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(chon ? AppColors.onPrimary : AppColors.primary)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(chon ? AnyShapeStyle(AppColors.primary) : AnyShapeStyle(AppColors.primary.opacity(0.12))))
                VStack(alignment: .leading, spacing: 1) {
                    Text(k.ten)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(k.moTa)
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.backgroundCard.opacity(chon ? 0.95 : 0.6)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(chon ? AppColors.primary : AppColors.border, lineWidth: chon ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(chon ? .isSelected : [])
    }

    // ── Kết quả ─────────────────────────────────────────────────
    @ViewBuilder
    private func manKetQua(_ h: HinhVeAI, model: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(T("Xong rồi!"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text("“\(may.de)” · \(h.net.count) \(T("nét"))")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }

        // Nền GIẤY trắng ở cả hai chế độ: hình sẽ nằm trên trang giấy, xem
        // trước trên nền tối là xem sai thứ sẽ thấy.
        HinhVeXemTruoc(hinh: h, mau: Color(hex: 0x1C1C24))
            .padding(Spacing.md)
            .frame(maxWidth: .infinity)
            .frame(maxHeight: 300)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1))
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)

        if !h.nhan.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Label(T("Nhãn gợi ý — bạn tự viết vào hình"), systemImage: "pencil.and.list.clipboard")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
                LuoiChip(khoangCach: 6) {
                    ForEach(Array(h.nhan.enumerated()), id: \.offset) { i, n in
                        HStack(spacing: 5) {
                            Text("\(i + 1)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(AppColors.onPrimary)
                                .frame(width: 17, height: 17)
                                .background(Circle().fill(AppColors.secondary))
                            Text(n)
                                .font(.footnote)
                                .foregroundStyle(AppColors.textPrimary)
                        }
                        .padding(.leading, 4).padding(.trailing, 10).padding(.vertical, 4)
                        .background(Capsule().fill(AppColors.secondary.opacity(0.12)))
                    }
                }
            }
        }

        Button {
            if let chen {
                // Đóng khung TRƯỚC rồi mới vẽ: hình vẽ dần lên trang, khung
                // hỏi còn mở là che mất đúng chỗ đang vẽ.
                dong()
                Haptics.xong()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { chen(h) }
            } else { baoSapCo = true }
        } label: {
            Label(T("Vẽ lên trang"), systemImage: "square.and.pencil")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .foregroundStyle(AppColors.onPrimary)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.primary))
        }
        .buttonStyle(.plain)

        HStack(spacing: Spacing.sm) {
            nutPhu(T("Vẽ lại"), "arrow.clockwise") { may.veLai() }
            nutPhu(T("Sửa mô tả"), "text.cursor") { may.xoaKetQua() }
        }

        if let model {
            Text(model)
                .font(.caption2)
                .foregroundStyle(AppColors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func manLoi(_ e: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "scribble.variable")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(AppColors.textTertiary)
                .padding(.top, Spacing.lg)
            Text(e)
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Spacing.sm) {
                nutPhu(T("Thử lại"), "arrow.clockwise") { may.veLai() }
                nutPhu(T("Sửa mô tả"), "text.cursor") { may.xoaKetQua() }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func nutPhu(_ chu: String, _ icon: String, _ lam: @escaping () -> Void) -> some View {
        Button(action: lam) {
            Label(chu, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(AppColors.textPrimary)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColors.textPrimary.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Màn chờ

/// Màn chờ 30–90 giây. Phải cho thấy ba thứ: MÁY ĐANG LÀM (không treo), ĐÃ
/// BAO LÂU và CÒN KHOẢNG BAO LÂU — thiếu cái cuối thì người ta bấm huỷ ở
/// giây 40 vì tưởng hỏng, đúng lúc hình sắp về.
private struct ManChoVe: View {
    let batDau: Date
    let de: String
    let huy: () -> Void

    @Environment(\.accessibilityReduceMotion) private var giamChuyenDong
    /// Mốc để thanh tiến độ tới ~95%. Không phải số đo — chỉ để thanh không
    /// đứng im; tới 95% là dừng, không bao giờ báo "xong" giả.
    private let moc: Double = 75

    var body: some View {
        VStack(spacing: Spacing.md) {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: giamChuyenDong)) { tl in
                ButVeCho(t: tl.date.timeIntervalSince(batDau), tinh: giamChuyenDong)
            }
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1))

            VStack(spacing: 4) {
                Text(T("Đang vẽ…"))
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Text("“\(de)”")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            TimelineView(.periodic(from: batDau, by: 1)) { tl in
                let da = max(0, tl.date.timeIntervalSince(batDau))
                VStack(spacing: 6) {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppColors.textPrimary.opacity(0.08))
                            Capsule()
                                .fill(LinearGradient(colors: [AppColors.primary, AppColors.brandPink],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: g.size.width * min(0.95, max(0.04, da / moc)))
                                .animation(.linear(duration: 1), value: Int(da))
                        }
                    }
                    .frame(height: 6)
                    HStack {
                        Text(dongHo(da))
                            .monospacedDigit()
                        Spacer()
                        Text(da < 90 ? T("thường 30–90 giây") : T("hình khó, chờ thêm chút"))
                    }
                    .font(.caption)
                    .foregroundStyle(AppColors.textTertiary)
                }
            }

            Button(role: .cancel, action: huy) {
                Text(T("Huỷ"))
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 8)
                    .foregroundStyle(AppColors.textPrimary)
                    .background(Capsule().fill(AppColors.textPrimary.opacity(0.07)))
            }
            .buttonStyle(.plain)
        }
        .accessibilityElement(children: .combine)
    }

    private func dongHo(_ s: TimeInterval) -> String {
        let n = Int(s)
        return String(format: "%d:%02d", n / 60, n % 60)
    }
}

/// Ngòi bút vẽ đi vẽ lại một đường lượn — gợi "đang vẽ", không giả làm hình thật.
private struct ButVeCho: View {
    let t: TimeInterval
    let tinh: Bool

    var body: some View {
        GeometryReader { g in
            let chu = tinh ? 0.7 : (t.truncatingRemainder(dividingBy: 2.6)) / 2.6
            let dau = max(0, chu - 0.45)
            let p = duong(g.size)
            ZStack {
                p.stroke(Color.black.opacity(0.06), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 6]))
                p.trim(from: dau, to: chu)
                    .stroke(LinearGradient(colors: [AppColors.primary.opacity(0.2), AppColors.primary],
                                           startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                Image(systemName: "pencil.tip")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
                    .rotationEffect(.degrees(-35))
                    .position(diem(chu, g.size))
                    .offset(x: 6, y: -9)
            }
        }
        .padding(.horizontal, 24)
    }

    /// Đường lượn hình số 8 nằm ngang — đọc ra ngay là "nét bút", và khép
    /// kín nên vòng lặp không có chỗ giật.
    private func diem(_ u: Double, _ k: CGSize) -> CGPoint {
        let a = u * 2 * .pi
        return CGPoint(x: k.width / 2 + sin(a) * k.width * 0.42,
                       y: k.height / 2 + sin(2 * a) * k.height * 0.28)
    }

    private func duong(_ k: CGSize) -> Path {
        var p = Path()
        let n = 120
        for i in 0...n {
            let d = diem(Double(i) / Double(n), k)
            if i == 0 { p.move(to: d) } else { p.addLine(to: d) }
        }
        return p
    }
}

// `LuoiChip` (xếp chip tự xuống dòng) dùng chung bản ở `Academy/SoDoMonHocView.swift`.

// MARK: - Hình mẫu (DEBUG)

#if DEBUG
/// Hình giả cho bàn thử — dựng bằng hình học, không gọi mạng.
enum HinhVeMau {
    private static func tron(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat,
                             tu: CGFloat = 0, den: CGFloat = 2 * .pi, n: Int = 40) -> [CGPoint] {
        (0...n).map { i in
            let a = tu + (den - tu) * CGFloat(i) / CGFloat(n)
            return CGPoint(x: cx + cos(a) * rx, y: cy + sin(a) * ry)
        }
    }

    static let meo = HinhVeAI(net: [
        tron(500, 330, 230, 200),                                            // đầu
        [CGPoint(x: 320, y: 220), CGPoint(x: 300, y: 40), CGPoint(x: 440, y: 150)],   // tai trái
        [CGPoint(x: 560, y: 150), CGPoint(x: 700, y: 40), CGPoint(x: 680, y: 220)],   // tai phải
        tron(420, 300, 28, 38), tron(580, 300, 28, 38),                      // mắt
        [CGPoint(x: 480, y: 380), CGPoint(x: 520, y: 380), CGPoint(x: 500, y: 405)],  // mũi
        tron(470, 420, 30, 25, tu: 0.2, den: 2.9, n: 12),                    // miệng
        tron(530, 420, 30, 25, tu: 0.2, den: 2.9, n: 12),
        [CGPoint(x: 360, y: 390), CGPoint(x: 180, y: 360)], [CGPoint(x: 360, y: 420), CGPoint(x: 190, y: 440)],
        [CGPoint(x: 640, y: 390), CGPoint(x: 820, y: 360)], [CGPoint(x: 640, y: 420), CGPoint(x: 810, y: 440)],
        tron(500, 720, 260, 230, tu: -2.6, den: -0.55 + 2 * .pi, n: 50),      // thân
        [CGPoint(x: 740, y: 820), CGPoint(x: 900, y: 760), CGPoint(x: 960, y: 600),
         CGPoint(x: 900, y: 520), CGPoint(x: 860, y: 580)],                   // đuôi
    ], rong: 1000, cao: 960, nhan: [])

    static let oxy: HinhVeAI = {
        var net: [[CGPoint]] = [
            [CGPoint(x: 40, y: 700), CGPoint(x: 1000, y: 700)],              // Ox
            [CGPoint(x: 960, y: 680), CGPoint(x: 1000, y: 700), CGPoint(x: 960, y: 720)],
            [CGPoint(x: 300, y: 980), CGPoint(x: 300, y: 20)],               // Oy
            [CGPoint(x: 280, y: 60), CGPoint(x: 300, y: 20), CGPoint(x: 320, y: 60)],
        ]
        net.append(tron(700, 300, 12, 12, n: 16))                             // điểm A
        for i in 0..<10 { net.append([CGPoint(x: 700, y: 330 + CGFloat(i) * 37), CGPoint(x: 700, y: 348 + CGFloat(i) * 37)]) }
        for i in 0..<10 { net.append([CGPoint(x: 330 + CGFloat(i) * 37, y: 300), CGPoint(x: 348 + CGFloat(i) * 37, y: 300)]) }
        return HinhVeAI(net: net, rong: 1000, cao: 1000,
                        nhan: ["O (gốc toạ độ)", "trục hoành Ox", "trục tung Oy", "A(2; 3)"])
    }()
}
#endif
#endif
