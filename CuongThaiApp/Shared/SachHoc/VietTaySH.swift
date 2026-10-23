#if os(iOS)
import SwiftUI
import PencilKit

// ════════════════════════════════════════════════════════════════
// KHỐI `write` — tập viết tay bằng Apple Pencil / ngón tay (bản native của
// WriteBlock.tsx). Mỗi mục một hàng: ô MẪU (KanjiVG, ▶ chạy thứ tự nét, số nét)
// + ô LUYỆN (PencilKit) trên nền ô 田:
//   • mục MỘT chữ  ⇒ 1 dòng × 3 ô, chữ mờ ở ô đầu để tô;
//   • mục là TỪ k chữ ⇒ lưới min(k,6) cột: dòng trên chữ mờ để tô, dòng dưới tự viết.
// "Che mẫu" (khối có từ / có `goi`) giấu mẫu, chỉ còn gợi ý + 🔊. ✨ AI xem chữ:
// ghép các hàng đã viết thành MỘT ảnh nền trắng (KHÔNG có chữ mờ — AI phải thấy
// nét của người học) ⇒ `POST /ielts/ai/xem-chu-viet` như web.
//
// Nét LƯU theo hệ "thiết kế" (mỗi ô 100 điểm) chứ không theo điểm màn hình: xoay
// iPad / đổi cỡ thì co giãn lại, nét vẫn nằm đúng ô (web lưu toạ độ chuẩn hoá vì
// cùng lý do). Mỗi hàng một PKCanvasView, chia trang 10 hàng.
//
// ⚠️ Bề dày bút ≥ 2,4pt: nét PencilKit mảnh hơn thì VÔ HÌNH trên iPad thật dù máy
// ảo vẫn hiện (bài học Vở 09/2026).
// Khoá tiếng Trung (`zh`): dữ liệu KanjiVG không có chữ giản thể ⇒ `VietHanZhSH`
// (nét hanzi-writer từ máy chủ + `LuyenVietPencil` chấm từng nét), như VietHanZh.tsx.
// ════════════════════════════════════════════════════════════════

/// Lưới ô luyện của một mục — `luoiCua` của web.
struct LuoiVietSH {
    let cot: Int
    let dong: Int
    /// Chữ mờ của ô thứ i (trái → phải, trên → dưới); nil = ô trống.
    let o: [String?]
    let laTu: Bool

    static let O_THIET_KE: CGFloat = 100

    static func cua(_ muc: String) -> LuoiVietSH {
        let ky = muc.map(String.init)
        if ky.count <= 1 { return LuoiVietSH(cot: 3, dong: 1, o: [muc, nil, nil], laTu: false) }
        let cot = min(ky.count, 6)
        let moiLuot = Int(ceil(Double(ky.count) / Double(cot)))
        func luot(_ mo: Bool) -> [String?] { (0..<(moiLuot * cot)).map { mo && $0 < ky.count ? ky[$0] : nil } }
        return LuoiVietSH(cot: cot, dong: moiLuot * 2, o: luot(true) + luot(false), laTu: true)
    }

    var rongThietKe: CGFloat { CGFloat(cot) * Self.O_THIET_KE }
    var caoThietKe: CGFloat { CGFloat(dong) * Self.O_THIET_KE }
}

// MARK: - Lưu nét trên máy

/// Nét đã viết của mỗi khối (theo khoá `<khoá>:ink:<id khối>` như web) — tệp plist trong Application Support.
@MainActor
enum KhoNetVietSH {
    private static func tep(_ khoa: String) -> URL {
        let goc = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        let d = goc.appendingPathComponent("SachHocNet", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        let ten = khoa.map { $0.isLetter || $0.isNumber || $0 == "-" ? String($0) : "_" }.joined()
        return d.appendingPathComponent(ten + ".plist")
    }

    static func doc(_ khoa: String) -> [String: PKDrawing] {
        guard let d = try? Data(contentsOf: tep(khoa)),
              let m = try? PropertyListDecoder().decode([String: Data].self, from: d) else { return [:] }
        return m.compactMapValues { try? PKDrawing(data: $0) }
    }

    /// Số mục đã viết (đếm khoá, không giải mã nét) — thẻ của màn Luyện viết.
    static func soDaViet(_ khoa: String) -> Int {
        guard let d = try? Data(contentsOf: tep(khoa)),
              let m = try? PropertyListDecoder().decode([String: Data].self, from: d) else { return 0 }
        return m.count
    }

    static func ghi(_ khoa: String, _ ink: [String: PKDrawing]) {
        let u = tep(khoa)
        let m = ink.filter { !$0.value.strokes.isEmpty }.mapValues { $0.dataRepresentation() }
        if m.isEmpty { try? FileManager.default.removeItem(at: u); return }
        if let d = try? PropertyListEncoder().encode(m) { try? d.write(to: u, options: .atomic) }
    }
}

// MARK: - Bút

struct ButVietSH: Equatable {
    var tay = false           // true = tẩy
    var mau = 0               // 0 đen · 1 xanh · 2 đỏ

    static let MAU: [UIColor] = [UIColor(hex: 0x1F2328), UIColor(hex: 0x1D4ED8), UIColor(hex: 0xDC2626)]

    func tool(_ doDay: CGFloat) -> PKTool {
        if tay { return PKEraserTool(.vector) }
        return PKInkingTool(.pen, color: Self.MAU[mau], width: max(2.4, min(20, doDay)))
    }
}

// MARK: - Ô vẽ PencilKit

/// PKCanvasView ĐẦU TIÊN của tiến trình chạy `+[PKTiledCanvasView initialize]` ⇒ `registerDefaults`
/// ⇒ `UserDefaults.didChangeNotification` ⇒ MỌI view có `@AppStorage` đang hiện (mỗi `ChuSH` có 2)
/// dựng lại. Đo 23/10 (call stack + `_printChanges`): đúng lúc cuộn tới khối viết ⇒ một khung
/// 120–300 ms. Khởi động sẵn lúc MỞ bài có khối viết (trước khi nội dung hiện) thì cái giá đó
/// rơi vào lúc chưa có gì trên màn.
@MainActor
enum KhoiDongPencilSH {
    private static var xong = false
    static func mot() {
        guard !xong else { return }
        xong = true
        _ = PKCanvasView(frame: .zero)
    }
}

/// PKCanvasView trong suốt; nét vào/ra theo hệ thiết kế (`rongThietKe`), co theo `rong` thật.
struct OVietPK: UIViewRepresentable {
    let ve: PKDrawing
    /// Đổi khi bên ngoài thay nét (hoàn tác, xoá, nạp) — lúc đó mới gán lại `drawing`.
    let phienBan: Int
    let rongThietKe: CGFloat
    let rong: CGFloat
    let but: ButVietSH
    /// Bề dày bút theo hệ thiết kế.
    var doDay: CGFloat = 6
    let doi: (PKDrawing) -> Void
    var batDau: () -> Void = {}

    func makeCoordinator() -> DieuPhoi { DieuPhoi() }

    func makeUIView(context: Context) -> PKCanvasView {
        let c = PKCanvasView()
        c.backgroundColor = .clear
        c.isOpaque = false
        // `.default`: iPad bật "Chỉ vẽ bằng Apple Pencil" thì ngón tay để cuộn bài; iPhone thì ngón tay vẽ.
        c.drawingPolicy = .default
        c.isScrollEnabled = false
        c.minimumZoomScale = 1
        c.maximumZoomScale = 1
        c.delegate = context.coordinator
        return c
    }

    func updateUIView(_ c: PKCanvasView, context: Context) {
        let co = context.coordinator
        co.doi = doi
        co.batDau = batDau
        co.rongThietKe = rongThietKe
        co.rong = rong
        guard rong > 1 else { return }
        c.tool = but.tool(doDay * rong / rongThietKe)
        if co.phienBan != phienBan || abs(co.rongDaDat - rong) > 0.5 {
            co.phienBan = phienBan
            co.rongDaDat = rong
            co.dangDat = true
            let k = rong / rongThietKe
            c.drawing = ve.transformed(using: CGAffineTransform(scaleX: k, y: k))
            co.dangDat = false
        }
    }

    final class DieuPhoi: NSObject, PKCanvasViewDelegate {
        var doi: (PKDrawing) -> Void = { _ in }
        var batDau: () -> Void = {}
        var phienBan = -1
        var rong: CGFloat = 0
        var rongDaDat: CGFloat = -1
        var rongThietKe: CGFloat = 100
        var dangDat = false

        func canvasViewDrawingDidChange(_ c: PKCanvasView) {
            guard !dangDat, rong > 1 else { return }
            let k = rongThietKe / rong
            doi(c.drawing.transformed(using: CGAffineTransform(scaleX: k, y: k)))
        }

        func canvasViewDidBeginUsingTool(_ c: PKCanvasView) { batDau() }
    }
}

// MARK: - Nền ô luyện (ô 田 + chữ mờ)

struct NenLuoiVietSH: View {
    let luoi: LuoiVietSH
    let net: [String: [String]]?
    let mo: Bool

    var body: some View {
        Canvas { ctx, size in
            let c = size.width / CGFloat(luoi.cot)
            var dut = Path()
            for r in 0..<luoi.dong {
                for i in 0..<luoi.cot {
                    let x = CGFloat(i) * c, y = CGFloat(r) * c
                    dut.move(to: CGPoint(x: x + c / 2, y: y)); dut.addLine(to: CGPoint(x: x + c / 2, y: y + c))
                    dut.move(to: CGPoint(x: x, y: y + c / 2)); dut.addLine(to: CGPoint(x: x + c, y: y + c / 2))
                }
            }
            ctx.stroke(dut, with: .color(AppColors.border), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            var lien = Path()
            for i in 1..<max(1, luoi.cot) { lien.move(to: CGPoint(x: CGFloat(i) * c, y: 0)); lien.addLine(to: CGPoint(x: CGFloat(i) * c, y: size.height)) }
            for r in 1..<max(1, luoi.dong) where !(luoi.laTu && r == luoi.dong / 2) {
                lien.move(to: CGPoint(x: 0, y: CGFloat(r) * c)); lien.addLine(to: CGPoint(x: size.width, y: CGFloat(r) * c))
            }
            ctx.stroke(lien, with: .color(AppColors.textTertiary.opacity(0.35)), lineWidth: 1.2)
            if luoi.laTu {
                var giua = Path()
                giua.move(to: CGPoint(x: 0, y: CGFloat(luoi.dong / 2) * c)); giua.addLine(to: CGPoint(x: size.width, y: CGFloat(luoi.dong / 2) * c))
                ctx.stroke(giua, with: .color(AppColors.textTertiary.opacity(0.6)), lineWidth: 2.5)
            }
            guard mo else { return }
            let mauMo = AppColors.info.opacity(0.2)
            for (i, ch) in luoi.o.enumerated() {
                guard let ch else { continue }
                let goc = CGRect(x: CGFloat(i % luoi.cot) * c, y: CGFloat(i / luoi.cot) * c, width: c, height: c)
                if let ps = net?[ch], !ps.isEmpty {
                    let khung = goc.insetBy(dx: c * 0.06, dy: c * 0.06)
                    ctx.stroke(ChuKVG(paths: ps).path(in: khung), with: .color(mauMo),
                               style: StrokeStyle(lineWidth: max(2.4, c * 0.045), lineCap: .round, lineJoin: .round))
                } else {
                    ctx.draw(Text(ch).font(.system(size: c * 0.68, design: .serif)).foregroundColor(mauMo), at: CGPoint(x: goc.midX, y: goc.midY))
                }
            }
        }
    }
}

// MARK: - Ô mẫu

private struct OMauVietSH: View {
    let muc: String
    let net: [String: [String]]?
    let goi: String?
    let che: Bool
    @StateObject private var phat: PhatNetSH

    init(muc: String, net: [String: [String]]?, goi: String?, che: Bool) {
        self.muc = muc; self.net = net; self.goi = goi; self.che = che
        _phat = StateObject(wrappedValue: PhatNetSH(soNet: muc.map { net?[String($0)]?.count ?? 0 }.reduce(0, +)))
    }

    private var ky: [String] { muc.map(String.init) }

    var body: some View {
        let tong = phat.soNet
        VStack(alignment: .leading, spacing: 6) {
            if che {
                VStack(spacing: 4) {
                    Text("?").font(.system(size: 30, weight: .heavy)).foregroundColor(AppColors.textTertiary)
                    if let goi { ChuSH(text: goi, co: 13.5, mau: .phu, giua: true) }
                }
                .frame(maxWidth: .infinity, minHeight: 80)
                .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.backgroundTertiary))
                HStack(spacing: 6) {
                    NutLoaSH(text: muc, co: 28)
                    Text("\(ky.count) chữ").font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
                }
            } else {
                if ky.count > 1 {
                    HStack(spacing: 3) {
                        ForEach(Array(ky.enumerated()), id: \.offset) { i, c in
                            KhungNetSH(chu: c, paths: net?[c], phat: phat, bu: ky.prefix(i).map { net?[$0]?.count ?? 0 }.reduce(0, +))
                                .frame(maxWidth: 64)
                                .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.backgroundCard))
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(AppColors.border, lineWidth: 1))
                        }
                    }
                } else {
                    KhungNetSH(chu: muc, paths: net?[muc], phat: phat)
                        .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.backgroundCard))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.border, lineWidth: 1))
                }
                HStack(spacing: 6) {
                    if tong > 0 {
                        Button { phat.phat(tu: 0) } label: {
                            Label("\(tong) nét", systemImage: "play.fill").font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(Capsule().fill(AppColors.primary.opacity(0.12)))
                                .foregroundColor(AppColors.primary)
                        }
                        .buttonStyle(.plain)
                        .disabled(phat.dangChay)
                        .accessibilityLabel("Xem thứ tự nét \(muc)")
                    }
                    if ky.count > 1 { NutLoaSH(text: muc, co: 26) }
                }
                if let goi { ChuSH(text: goi, co: 12.5, mau: .mo) }
            }
        }
    }
}

// MARK: - Một hàng luyện

private struct HangVietSH: View {
    let muc: String
    let net: [String: [String]]?
    let goi: String?
    let che: Bool
    let mo: Bool
    let ve: PKDrawing
    let phienBan: Int
    let but: ButVietSH
    let doi: (PKDrawing) -> Void
    let kichHoat: () -> Void
    let hoanTac: () -> Void
    let xoa: () -> Void

    private var luoi: LuoiVietSH { .cua(muc) }

    var body: some View {
        let l = luoi
        Group {
            if l.laTu {
                VStack(alignment: .leading, spacing: 8) {
                    OMauVietSH(muc: muc, net: net, goi: goi, che: che).id("\(muc)|\(net == nil)").frame(maxWidth: CGFloat(l.cot) * 66, alignment: .leading)
                    oLuyen(l).frame(maxWidth: CGFloat(l.cot) * 110, alignment: .leading)
                }
            } else {
                HStack(alignment: .top, spacing: 10) {
                    OMauVietSH(muc: muc, net: net, goi: goi, che: che).id("\(muc)|\(net == nil)").frame(width: 96)
                    oLuyen(l).frame(maxWidth: 3 * 136)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func oLuyen(_ l: LuoiVietSH) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Color.clear
                .aspectRatio(CGFloat(l.cot) / CGFloat(l.dong), contentMode: .fit)
                .overlay(
                    GeometryReader { g in
                        ZStack {
                            NenLuoiVietSH(luoi: l, net: net, mo: mo)
                            OVietPK(ve: ve, phienBan: phienBan, rongThietKe: l.rongThietKe, rong: g.size.width, but: but, doi: doi, batDau: kichHoat)
                        }
                    }
                )
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.theoCheDo(sang: Color(hex: 0xFFFEFB), toi: Color(hex: 0x1A1C20))))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(AppColors.textTertiary.opacity(0.45), lineWidth: 1.2))
                .accessibilityLabel("Ô tập viết \(l.laTu ? "từ" : "chữ") \(muc)")
            HStack(spacing: 6) {
                nutNho("arrow.uturn.backward", "Hoàn tác nét \(muc)", hoanTac)
                nutNho("xmark", "Xoá hàng \(muc)", xoa)
            }
        }
    }

    private func nutNho(_ bt: String, _ ten: String, _ lam: @escaping () -> Void) -> some View {
        Button(action: lam) {
            Image(systemName: bt).font(.system(size: 12, weight: .bold))
                .frame(width: 30, height: 26)
                .background(RoundedRectangle(cornerRadius: 7).fill(AppColors.backgroundTertiary))
                .foregroundColor(AppColors.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ten)
    }
}

// MARK: - Khối

struct VietTaySH: View {
    let id: String
    let title: String
    let chars: [String]
    let note: String?
    var goi: [String: String] = [:]
    @EnvironmentObject private var vm: SachHocVM

    @State private var ink: [String: PKDrawing] = [:]
    @State private var phienBan: [String: Int] = [:]
    @State private var trang = 0
    @State private var but = ButVietSH()
    @State private var mo = true
    @State private var che = false
    @State private var dangHoat: String?
    @State private var daNap = false
    @State private var dangXem = false
    @State private var ketQua: (chu: String, diem: Int?)?
    @State private var loi: String?
    @State private var hoiXoaHet = false

    private static let TRANG = 10
    private var ds: [String] { var seen = Set<String>(); return chars.filter { seen.insert($0).inserted } }
    private var coTu: Bool { ds.contains { $0.count > 1 } }
    private var khoaLuu: String { "\(vm.khoaId):ink:\(id)" }

    var body: some View {
        let ds = self.ds
        let soTrang = Int(ceil(Double(ds.count) / Double(Self.TRANG)))
        let hien = Array(ds.dropFirst(trang * Self.TRANG).prefix(Self.TRANG))
        let daViet = ds.filter { !(ink[$0]?.strokes.isEmpty ?? true) }
        #if DEBUG
        let _ = DemBodySH.tang("VietTaySH")
        #endif
        let vien = AppColors.primary.opacity(0.35)
        // Mỗi hàng luyện một LÁT (phần tử lazy riêng) — xem `LatSH`. Đo 23/10: 10 hàng PencilKit dựng
        // trong một khung hình ~400 ms ⇒ giật khi cuộn tới khối viết.
        LatSH {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "pencil.and.scribble").font(.system(size: 16, weight: .bold)).foregroundColor(AppColors.primary).padding(.top, 2)
                    ChuSH(text: title, co: 17, dam: true)
                }
                ChuSH(text: note ?? (coTu
                    ? "Bấm ▶ xem thứ tự nét, tô theo chữ mờ ở dòng trên rồi tự viết lại cả từ ở dòng dưới (mỗi ô một chữ). Bật “Che mẫu” để tự nhớ ra từ từ nghĩa + 🔊."
                    : "Bấm ▶ xem thứ tự nét, rồi tô theo chữ mờ ở ô đầu và tự viết ở hai ô sau. Viết bằng Apple Pencil hoặc ngón tay."),
                      co: 13.5, mau: .phu)
                thanhCongCu(daViet: daViet.count)
                if soTrang > 1 { thanhTrang(ds, soTrang) }
            }
            .latTheSH(tren: true, vien: vien)
            .task {
                await vm.napNet()
                guard !daNap else { return }
                daNap = true
                ink = KhoNetVietSH.doc(khoaLuu)
                #if DEBUG
                // Màn soi: `CT_SACHHOC_DIEN=1` ⇒ ô đầu có sẵn nét "viết tay" dựng từ KanjiVG (máy ảo không vẽ được bằng lệnh).
                if ProcessInfo.processInfo.environment["CT_SACHHOC_DIEN"] == "1", ink.isEmpty, let ch = ds.first, let ps = vm.net?[ch] {
                    ink[ch] = Self.netGia(ps, o: 1)
                }
                #endif
                phienBan = Dictionary(uniqueKeysWithValues: ink.keys.map { ($0, 1) })
            }
            .confirmationDialog("Xoá hết chữ đã viết trong khối này?", isPresented: $hoiXoaHet, titleVisibility: .visible) {
                Button("Xoá hết", role: .destructive) {
                    for k in ink.keys { phienBan[k, default: 0] += 1 }
                    ink = [:]; ketQua = nil
                    KhoNetVietSH.ghi(khoaLuu, ink)
                }
            }
            ForEach(hien.indices.map { IdLatSH(khoa: "viet|\(id)|\(trang)", i: $0) }) { k in
                let ch = hien[k.i]
                VStack(alignment: .leading, spacing: 4) {
                    HangVietSH(muc: ch, net: vm.net, goi: goi[ch], che: che, mo: mo, ve: ink[ch] ?? PKDrawing(), phienBan: phienBan[ch] ?? 0, but: but,
                               doi: { capNhat(ch, $0, ngoai: false) },
                               kichHoat: { dangHoat = ch },
                               hoanTac: { hoanTac(ch) },
                               xoa: { capNhat(ch, PKDrawing(), ngoai: true) })
                    if ch != hien.last { Divider() }
                }
                .padding(.top, ch == hien.first ? 10 : 4)
                .latTheSH(vien: vien)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Đã viết \(daViet.count)/\(ds.count) \(coTu ? "mục" : "chữ")").font(.system(size: 14, weight: .bold)).foregroundColor(AppColors.textPrimary)
                    Spacer()
                    NutSH(ten: dangXem ? "AI đang xem…" : "AI xem chữ", bieuTuong: "sparkles") { Task { await hoiAI(daViet) } }
                        .disabled(dangXem || daViet.isEmpty).opacity(dangXem || daViet.isEmpty ? 0.5 : 1)
                }
                if daViet.count > 16 { Text("AI xem tối đa 16 \(coTu ? "mục" : "chữ") đầu đã viết mỗi lần.").font(.system(size: 12.5)).foregroundColor(AppColors.textTertiary) }
                if let loi { PhanHoiSH(dung: false, chu: loi) }
                if let kq = ketQua {
                    VStack(alignment: .leading, spacing: 8) {
                        if let d = kq.diem {
                            Text("Điểm AI: \(d)/100").font(.system(size: 15, weight: .heavy)).foregroundColor(d >= 70 ? AppColors.success : AppColors.warning)
                        }
                        NoiDungMarkdown(noiDung: kq.chu)
                        Button("Đóng nhận xét") { ketQua = nil }.font(.system(size: 13.5, weight: .semibold))
                    }
                    .theKhoiSH(vien: AppColors.primary.opacity(0.35), nen: AppColors.primary.opacity(0.05))
                }
                Text("Thứ tự nét: KanjiVG © Ulrich Apel, CC BY-SA 3.0").font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
            }
            .padding(.top, 10)
            .latTheSH(duoi: true, vien: vien)
        }
    }

    private func thanhCongCu(daViet: Int) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                congCu("pencil.tip", "Bút", !but.tay) { but.tay = false }
                congCu("eraser", "Tẩy", but.tay) { but.tay = true }
                ForEach(0..<3, id: \.self) { i in
                    Button { but.mau = i; but.tay = false } label: {
                        Circle().fill(Color(ButVietSH.MAU[i])).frame(width: 20, height: 20)
                            .overlay(Circle().strokeBorder(AppColors.primary, lineWidth: but.mau == i && !but.tay ? 2.5 : 0).padding(-4))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(["Mực đen", "Mực xanh", "Mực đỏ"][i])
                }
                congCu("arrow.uturn.backward", "Hoàn tác", false) { if let h = dangHoat { hoanTac(h) } }
                congCu("trash", "Xoá hết", false) { if daViet > 0 { hoiXoaHet = true } }
                congCu(mo ? "eye" : "eye.slash", "Chữ mờ", mo) { mo.toggle() }
                if coTu || !goi.isEmpty {
                    congCu("eye.slash.circle", "Che mẫu", che) { che.toggle(); if che { mo = false } }
                }
            }
        }
    }

    private func congCu(_ bt: String, _ ten: String, _ bat: Bool, _ lam: @escaping () -> Void) -> some View {
        Button(action: lam) {
            Label(ten, systemImage: bt).font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Capsule().fill(bat ? AppColors.primary.opacity(0.16) : AppColors.backgroundTertiary))
                .overlay(Capsule().strokeBorder(bat ? AppColors.primary : Color.clear, lineWidth: 1))
                .foregroundColor(bat ? AppColors.primary : AppColors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private func thanhTrang(_ ds: [String], _ soTrang: Int) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(0..<soTrang, id: \.self) { i in
                    Button { trang = i } label: {
                        Text(ds.dropFirst(i * Self.TRANG).prefix(Self.TRANG).joined(separator: coTu ? "・" : ""))
                            .font(.system(size: 14, weight: .medium)).lineLimit(1)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .frame(maxWidth: 220)
                            .background(Capsule().fill(i == trang ? AppColors.primary : AppColors.backgroundTertiary))
                            .foregroundColor(i == trang ? .white : AppColors.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func capNhat(_ ch: String, _ d: PKDrawing, ngoai: Bool) {
        ink[ch] = d.strokes.isEmpty ? nil : d
        if ngoai { phienBan[ch, default: 0] += 1 }
        KhoNetVietSH.ghi(khoaLuu, ink)
    }

    private func hoanTac(_ ch: String) {
        guard var d = ink[ch], !d.strokes.isEmpty else { return }
        d.strokes.removeLast()
        capNhat(ch, d, ngoai: true)
    }

    #if DEBUG
    /// Nét giả cho màn soi: lấy mẫu dọc đường KanjiVG, đặt vào ô thứ `o` (hệ thiết kế, ô 100).
    /// Bề rộng điểm 6 (≥ 2,4 — nét tự dựng mảnh hơn thì vô hình trên iPad thật).
    static func netGia(_ ps: [String], o: Int) -> PKDrawing {
        let k = LuoiVietSH.O_THIET_KE / DuongKVG.KHUNG
        let strokes: [PKStroke] = ps.map { d in
            let p = DuongKVG.path(d)
            let pts: [PKStrokePoint] = (0...24).compactMap { i in
                let t = CGFloat(i) / 24
                guard let c = (t == 0 ? p.trimmedPath(from: 0, to: 0.001) : p.trimmedPath(from: 0, to: t)).currentPoint else { return nil }
                let q = CGPoint(x: CGFloat(o) * LuoiVietSH.O_THIET_KE + c.x * k + sin(t * 9) * 1.2, y: c.y * k + cos(t * 7) * 1.2)
                return PKStrokePoint(location: q, timeOffset: Double(i) * 0.02, size: CGSize(width: 6, height: 6), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
            }
            return PKStroke(ink: PKInk(.pen, color: ButVietSH.MAU[0]), path: PKStrokePath(controlPoints: pts, creationDate: Date()))
        }
        return PKDrawing(strokes: strokes)
    }
    #endif

    // MARK: AI xem chữ

    /// Ghép các hàng đã viết thành MỘT ảnh (số hàng bên trái, lưới bên phải), trần cao 3200.
    private func ghepAnh(_ daViet: [String]) -> (String, [String])? {
        let o: CGFloat = 150, nhan: CGFloat = 44, dem: CGFloat = 10, tranCao: CGFloat = 3200
        var hang: [String] = []
        var cao = dem
        for ch in daViet {
            if hang.count >= 16 { break }
            let h = CGFloat(LuoiVietSH.cua(ch).dong) * o + dem
            if !hang.isEmpty && cao + h > tranCao { break }
            hang.append(ch); cao += h
        }
        guard !hang.isEmpty else { return nil }
        let rong = nhan + (hang.map { CGFloat(LuoiVietSH.cua($0).cot) * o }.max() ?? o) + dem
        let fm = UIGraphicsImageRendererFormat()
        fm.scale = 1
        let anh = UIGraphicsImageRenderer(size: CGSize(width: rong, height: cao), format: fm).image { ctxR in
            let ctx = ctxR.cgContext
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: rong, height: cao))
            var y = dem
            for (i, ch) in hang.enumerated() {
                let l = LuoiVietSH.cua(ch)
                let w = CGFloat(l.cot) * o, h = CGFloat(l.dong) * o
                let so = NSAttributedString(string: "\(i + 1)", attributes: [.font: UIFont.boldSystemFont(ofSize: 22), .foregroundColor: UIColor(hex: 0x6B7280)])
                let k = so.size()
                so.draw(at: CGPoint(x: (nhan - k.width) / 2, y: y + min(h, o) / 2 - k.height / 2))
                // Lưới (bản xuất: xám nhạt, không chữ mờ).
                ctx.setStrokeColor(UIColor(hex: 0xE3E5E8).cgColor); ctx.setLineWidth(1); ctx.setLineDash(phase: 0, lengths: [4, 4])
                for r in 0..<l.dong { for c in 0..<l.cot {
                    let x0 = nhan + CGFloat(c) * o, y0 = y + CGFloat(r) * o
                    ctx.move(to: CGPoint(x: x0 + o / 2, y: y0)); ctx.addLine(to: CGPoint(x: x0 + o / 2, y: y0 + o))
                    ctx.move(to: CGPoint(x: x0, y: y0 + o / 2)); ctx.addLine(to: CGPoint(x: x0 + o, y: y0 + o / 2))
                } }
                ctx.strokePath(); ctx.setLineDash(phase: 0, lengths: [])
                ctx.setStrokeColor(UIColor(hex: 0xC9CCD1).cgColor)
                for c in 0...l.cot { ctx.setLineWidth(1.5); ctx.move(to: CGPoint(x: nhan + CGFloat(c) * o, y: y)); ctx.addLine(to: CGPoint(x: nhan + CGFloat(c) * o, y: y + h)); ctx.strokePath() }
                for r in 0...l.dong {
                    ctx.setLineWidth(l.laTu && r == l.dong / 2 ? 3 : 1.5)
                    ctx.move(to: CGPoint(x: nhan, y: y + CGFloat(r) * o)); ctx.addLine(to: CGPoint(x: nhan + w, y: y + CGFloat(r) * o)); ctx.strokePath()
                }
                if let d = ink[ch] {
                    var anhNet = UIImage()
                    // Mực luôn là bản SÁNG (đen trên trắng) dù máy đang ở giao diện tối.
                    UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
                        anhNet = d.image(from: CGRect(x: 0, y: 0, width: l.rongThietKe, height: l.caoThietKe), scale: o / LuoiVietSH.O_THIET_KE)
                    }
                    anhNet.draw(in: CGRect(x: nhan, y: y, width: w, height: h))
                }
                y += h + dem
            }
        }
        guard let png = anh.pngData() else { return nil }
        return (png.base64EncodedString(), hang)
    }

    private func hoiAI(_ daViet: [String]) async {
        guard let (b64, hang) = ghepAnh(daViet) else { return }
        dangXem = true; loi = nil; ketQua = nil
        defer { dangXem = false }
        struct Kq: Decodable { let ketQua: String?; let diem: Double?; let lyDo: String? }
        do {
            let kq: Kq = try await APIClient.shared.request(.sachHocXemChuViet(["image": b64, "chars": hang, "lang": vm.khoa?.ngonNgu ?? "ja"]))
            if let k = kq.ketQua, !k.isEmpty {
                let d = kq.diem.map { max(0, min(100, Int($0.rounded()))) }
                ketQua = (k, d)
                if let d { vm.baoDiem(id, d) }
            } else {
                loi = kq.lyDo == "ai_unavailable" ? "AI xem chữ đang tạm tắt." : "AI chưa xem được, thử lại nhé."
            }
        } catch APIError.unauthorized {
            loi = "Đăng nhập để AI xem chữ."
        } catch {
            loi = error.localizedDescription
        }
    }
}

// MARK: - Tiếng Trung: chữ giản thể (hanzi-writer)

struct VietHanZhSH: View {
    let title: String
    let chars: [String]
    let note: String?
    @State private var dangLuyen: ChuLuyenZH?
    private let cot = [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 10)]

    struct ChuLuyenZH: Identifiable { let id: String }

    var body: some View {
        KhungBaiTapSH(bieuTuong: "pencil.and.scribble", tieuDe: title,
                      huongDan: note.map(PhanTichChuSH.tron) ?? "Bấm “Xem nét” để xem thứ tự nét, rồi “Luyện viết”: tô theo chữ mờ → theo mốc → tự viết không nhìn; máy chấm từng nét.") {
            LazyVGrid(columns: cot, spacing: 10) {
                ForEach(chars, id: \.self) { c in
                    OChuZH(chu: c) { dangLuyen = ChuLuyenZH(id: c) }
                }
            }
        }
        #if DEBUG
        .onAppear { if ProcessInfo.processInfo.environment["CT_SACHHOC_LUYENZH"] == "1", dangLuyen == nil, let c = chars.first { dangLuyen = ChuLuyenZH(id: c) } }
        #endif
        .sheet(item: $dangLuyen) { c in
            GeometryReader { g in
                LuyenVietPencil(chu: c.id, phienAm: nil, lang: "zh", canh: min(420, g.size.width - 32))
            }
        }
    }
}

private struct OChuZH: View {
    let chu: String
    let luyen: () -> Void
    @State private var net: NetChu?
    @State private var loi = false
    @State private var den = 0
    @State private var viec: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                LuoiDienSH(canh: 120)
                if let n = net {
                    ForEach(0..<n.strokes.count, id: \.self) { i in
                        let hinh = DuongSVG.doi(n.strokes[i], canh: 120)
                        if n.laDuongTim {
                            hinh.stroke(i < den ? AppColors.textPrimary : AppColors.textTertiary.opacity(0.22),
                                        style: StrokeStyle(lineWidth: n.beDayNet(canh: 120), lineCap: .round, lineJoin: .round))
                        } else {
                            hinh.fill(i < den ? (i == den - 1 && den < n.strokes.count ? MauChuSH.mau(0xDC2626).color : AppColors.textPrimary) : AppColors.textTertiary.opacity(0.22))
                        }
                    }
                } else if loi {
                    Text(chu).font(.system(size: 80)).foregroundColor(AppColors.textPrimary)
                } else {
                    ProgressView()
                }
            }
            .frame(width: 120, height: 120)
            .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.backgroundCard))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.border, lineWidth: 1))
            Text(net.map { "\($0.strokes.count) nét" } ?? (loi ? "Chưa tải được dữ liệu nét" : " "))
                .font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
            HStack(spacing: 6) {
                Button { chay() } label: {
                    Label("Xem nét", systemImage: "play.fill").font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .background(Capsule().fill(AppColors.primary.opacity(0.12))).foregroundColor(AppColors.primary)
                }
                .buttonStyle(.plain).disabled(net == nil)
                NutLoaSH(text: chu, co: 28)
            }
            Button(action: luyen) {
                Label("Luyện viết", systemImage: "pencil").font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    .frame(maxWidth: .infinity).padding(.vertical, 7)
                    .background(Capsule().fill(AppColors.primary)).foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.backgroundTertiary.opacity(0.5)))
        .task {
            if net == nil, let n = await KhoNetChu.shared.lay(chu, lang: "zh") { net = n; den = n.strokes.count } else if net == nil { loi = true }
        }
        .onDisappear { viec?.cancel() }
    }

    private func chay() {
        guard let n = net else { return }
        viec?.cancel()
        den = 0
        viec = Task {
            for i in 1...max(1, n.strokes.count) {
                try? await Task.sleep(nanoseconds: 550_000_000)
                if Task.isCancelled { return }
                withAnimation(.easeOut(duration: 0.25)) { den = i }
            }
        }
    }
}
#endif
