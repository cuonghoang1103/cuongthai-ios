#if os(iOS)
import PencilKit
import SwiftData
import SwiftUI
import UIKit

// MARK: - "Ghi khi học" (24/10/2026) — nút ✍ nổi trong các màn học
//
// Ba việc, một cụm nút nổi (kéo dời được, nhớ vị trí):
//   ✍  Ghi nhanh — mở trang Vở của ĐÚNG bài đang học (`VoHocKy.trangChoBaiHoc`: môn theo mã, cuốn "Ghi khi học"
//      giấy Cornell, trang mang tên bài; mở lại bài ⇒ cùng trang). iPad (rộng): cột Vở bên phải, bài vẫn đọc bên
//      trái. iPhone / cửa sổ hẹp: sheet nửa màn hình (`.medium`/`.large`), bài vẫn cuộn được phía trên.
//   ✏️ Viết lên bài — lớp mực đè lên nội dung (VietDeBai.swift). Chỉ màn có khối native (khoá kiểu sách, Academy).
//   ⌗  Chụp đoạn — kéo khung chọn một vùng màn bài ⇒ ảnh dán vào trang Vở của bài (hoặc trang đang mở ở cột Vở).
//      Chụp bằng `drawHierarchy` của CỬA SỔ (ra đúng PencilKit, ruby furigana, WebView), không dùng ImageRenderer.

/// Bài đang học — đủ để tìm/lập trang Vở của nó.
struct NguCanhGhi: Equatable {
    /// Mã môn ("FER202", "JPD113", "IELTS"…) — tên môn trong Vở là "<mã> · <tên>".
    var maMon: String
    var tenMon: String
    /// Nguồn bài: slug khoá Academy, "dekiru", "ielts", "thi"… (nối trang = "bai|<nguon>|<khoaBai>").
    var nguon: String?
    /// Id bài trong nguồn (chuỗi).
    var khoaBai: String
    /// Id số của bài Academy (để màn Vở mở lại đúng bài Academy).
    var lessonIdSo: Int? = nil
    var tieuDeBai: String
    /// Bài của khoá kiểu sách (Dekiru/IELTS…) — màn Vở mở lại bằng `MoBaiSachHocView`.
    var sachHoc = false

    /// Khoá lớp "viết lên bài" (VietDeBai): theo nguồn + bài.
    var khoaVietDe: String { "\(nguon ?? maMon)/\(khoaBai)" }

    @MainActor @discardableResult
    func layTrang(kho: ModelContext) -> (CuonVo, TrangVo) {
        if let so = lessonIdSo, !sachHoc {
            return VoHocKy.trangChoBaiHoc(maMon: maMon, tenMon: tenMon, courseSlug: nguon, lessonId: so,
                                          tieuDeBai: tieuDeBai, kho: kho)
        }
        return VoHocKy.trangChoBaiHoc(maMon: maMon, tenMon: tenMon, nguon: nguon, khoaBai: khoaBai,
                                      tieuDeBai: tieuDeBai, sachHoc: sachHoc, kho: kho)
    }

    // MARK: Dựng cho từng loại màn

    /// Khoá kiểu sách. Dekiru ⇒ JPD113 (Bài 0–3) / JPD123 (Bài 4–7) / DEKIRU (còn lại); IELTS ⇒ "IELTS".
    static func sachHoc(khoa: String, tenKhoa: String?, baiId: String, soBai: Int?, tieuDe: String) -> NguCanhGhi {
        let (ma, ten) = maMonSachHoc(khoa: khoa, tenKhoa: tenKhoa, soBai: soBai)
        let td = tieuDe.isEmpty ? baiId : tieuDe
        let dau = soBai.map { "\(T("Bài")) \($0) · " } ?? ""
        return NguCanhGhi(maMon: ma, tenMon: ten, nguon: khoa, khoaBai: baiId,
                          tieuDeBai: td.hasPrefix(dau) || dau.isEmpty ? td : dau + td, sachHoc: true)
    }

    static func maMonSachHoc(khoa: String, tenKhoa: String?, soBai: Int?) -> (String, String) {
        switch khoa {
        case "dekiru":
            if let n = soBai, (0...3).contains(n) { return ("JPD113", "Tiếng Nhật 1 · できる日本語") }
            if let n = soBai, (4...7).contains(n) { return ("JPD123", "Tiếng Nhật 2 · できる日本語") }
            return ("DEKIRU", "できる日本語")
        case "ielts": return ("IELTS", "IELTS nền tảng")
        case "jp": return ("JP", "Tiếng Nhật từ 0")
        case "ch": return ("CH", "Tiếng Trung từ 0")
        default: return (khoa.uppercased(), tenKhoa ?? khoa)
        }
    }

    /// Bài Academy: mã môn từ `courseCode` (đúng mẫu mã FPT) — không có thì theo slug.
    @MainActor static func academy(slug: String, courseCode: String?, tenKhoa: String, lessonId: Int, tieuDe: String) -> NguCanhGhi {
        let ma = courseCode.flatMap { VoHocKy.maMon(trong: $0) } ?? VoHocKy.maMon(trong: tenKhoa)
            ?? (courseCode?.isEmpty == false ? courseCode!.uppercased() : String(slug.uppercased().prefix(24)))
        return NguCanhGhi(maMon: ma, tenMon: tenKhoa, nguon: slug, khoaBai: String(lessonId),
                          lessonIdSo: lessonId, tieuDeBai: tieuDe)
    }
}

// MARK: - Modifier gắn vào màn học

extension View {
    /// Gắn cụm "Ghi khi học" vào một màn học.
    /// - `vietDe`: phiên "viết lên bài" của màn (nil ⇒ màn không có nút Viết lên bài).
    /// - `moVo`: màn muốn biết cột Vở đang mở (ẩn cột phụ của chính nó) — tuỳ chọn.
    func ghiKhiHoc(_ ngc: NguCanhGhi?, vietDe: PhienVietDe? = nil, moVo: Binding<Bool>? = nil) -> some View {
        modifier(GhiKhiHocModifier(ngc: ngc, vietDe: vietDe, moVoNgoai: moVo))
    }
}

/// Cầu nối giữa cụm nút và khung Vở đang mở (để chụp đoạn dán vào ĐÚNG trang đang mở, sau khi lưu nét).
@MainActor
final class CauNoiGhiNhanh: ObservableObject {
    let ve = CauNoiBangVe()
    @Published var idTrangDangMo: UUID?
}

struct GhiKhiHocModifier: ViewModifier {
    let ngc: NguCanhGhi?
    let vietDe: PhienVietDe?
    let moVoNgoai: Binding<Bool>?

    @Environment(\.horizontalSizeClass) private var lop
    @State private var moVoTrong = false
    @State private var dangChup = false
    @State private var bao: String?
    @State private var rongMan: CGFloat = 0
    @StateObject private var cauNoi = CauNoiGhiNhanh()

    private var moVo: Bool { moVoNgoai?.wrappedValue ?? moVoTrong }
    private func datMoVo(_ v: Bool) {
        if let b = moVoNgoai { b.wrappedValue = v } else { moVoTrong = v }
    }

    /// iPad toàn màn (hoặc Split View đủ rộng) ⇒ cột Vở bên cạnh; hẹp ⇒ sheet nửa màn.
    private var cotBen: Bool { lop == .regular && rongMan >= 700 }
    private var rongCot: CGFloat { min(max(rongMan * 0.42, 340), 560) }

    func body(content: Content) -> some View {
        HStack(spacing: 0) {
            content
                // Thanh viết đè ĐẨY nội dung xuống (vùng an toàn trên), không nằm đè lên tiêu đề bài.
                .safeAreaInset(edge: .top, spacing: 0) {
                    if let vietDe { ThanhVietDeNeuBat(phien: vietDe) }
                }
                // Cột Vở đang mở ⇒ cụm nút nổi nhường chỗ (Viết lên bài / Chụp đoạn có ở thanh trên của cột Vở),
                // không đè lên cột cuối của bảng.
                .overlay { if let ngc, !dangChup, !(cotBen && moVo) {
                    CumNutGhi(coVietDe: vietDe != nil, vietDe: vietDe, moVo: moVo,
                              moGhi: { datMoVo(!moVo) }, chup: { batChup() }, tenBai: ngc.tieuDeBai)
                } }
            if let ngc, cotBen, moVo {
                Divider()
                KhungVietNhanh(ngc: ngc, laCotBen: true, cauNoi: cauNoi, vietDe: vietDe, chup: { batChup() }) { datMoVo(false) }
                    .frame(width: rongCot)
                    .modelContainer(KhoSwiftData.chung)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: moVo && cotBen)
        .background(GeometryReader { g in
            Color.clear
                .onAppear { rongMan = g.size.width }
                .onChange(of: g.size.width) { _, w in rongMan = w }
        })
        .sheet(isPresented: Binding(get: { ngc != nil && moVo && !cotBen }, set: { if !$0 { datMoVo(false) } })) {
            if let ngc {
                KhungVietNhanh(ngc: ngc, laCotBen: false, cauNoi: cauNoi, vietDe: vietDe, chup: { datMoVo(false); batChup() }) { datMoVo(false) }
                    .modelContainer(KhoSwiftData.chung)
                    .presentationDetents([.medium, .large])
                    // Nửa màn: bài phía trên vẫn cuộn/chạm được — "vừa đọc vừa ghi".
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                    .presentationContentInteraction(.resizes)
                    .interactiveDismissDisabled(false)
            }
        }
        .overlay {
            if dangChup {
                LopChupDoan(khiXong: { vung, cuaSo in chupXong(vung, cuaSo) },
                            khiHuy: { dangChup = false })
            }
        }
        .overlay(alignment: .top) {
            if let bao {
                Text(bao)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(AppColors.onPrimary)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Capsule().fill(AppColors.textPrimary.opacity(0.9)))
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: bao)
        .onChange(of: ngc?.khoaVietDe) { _, k in vietDe?.doiBai(k) }
        .onAppear {
            vietDe?.doiBai(ngc?.khoaVietDe)
            #if DEBUG
            thuTuDong()
            #endif
        }
        .onDisappear {
            vietDe?.dangViet = false
            vietDe?.ghiNgay()
        }
    }

    // MARK: Chụp đoạn

    private func batChup() {
        vietDe?.dangViet = false
        dangChup = true
        Haptics.cham()
    }

    /// `vung` theo toạ độ CỬA SỔ. Lớp chọn đã gỡ (đợi một nhịp để nó rời màn) rồi mới chụp.
    private func chupXong(_ vung: CGRect, _ cuaSo: UIWindow?) {
        dangChup = false
        guard let ngc, let cuaSo else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard let anh = ChupDoan.cat(cuaSo, vung: vung) else {
                hienBao(T("Vùng chọn nhỏ quá — kéo một khung lớn hơn"))
                return
            }
            danVaoVo(anh, ngc)
        }
    }

    @MainActor
    private func danVaoVo(_ anh: UIImage, _ ngc: NguCanhGhi) {
        let kho = KhoSwiftData.chung.mainContext
        DongBoVo.shared.gan(kho: kho)
        // Cột Vở đang mở một trang ⇒ dán vào ĐÚNG trang đó (lưu nét đang viết dở trước, để đặt ảnh dưới nét).
        var dich: TrangVo?
        var net: PKDrawing?
        if moVo, let id = cauNoi.idTrangDangMo,
           let t = ((try? kho.fetch(FetchDescriptor<TrangVo>(predicate: #Predicate { $0.id == id }))) ?? []).first {
            cauNoi.ve.luuNgay()
            if cauNoi.ve.idTrangDangMo == id { net = cauNoi.ve.banVe }
            dich = t
        }
        let t = dich ?? ngc.layTrang(kho: kho).1
        guard KhoAnhDan.dan(anh, vao: t, nguon: ngc.tieuDeBai, net: net, kho: kho) != nil else {
            hienBao(T("Chưa dán được ảnh vào Vở"))
            return
        }
        Haptics.xong()
        hienBao(moVo ? T("Đã dán vào trang đang mở") : "\(T("Đã dán vào Vở")) · \(t.tieuDe ?? ngc.tieuDeBai)")
        DongBoVo.shared.batDau()
    }

    private func hienBao(_ s: String) {
        bao = s
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { if bao == s { bao = nil } }
    }

    #if DEBUG
    /// Màn soi (`CT_GHI_*`): mở Vở / bật viết / chụp một vùng cố định — máy ảo không có Pencil, simctl không chạm.
    private func thuTuDong() {
        let env = ProcessInfo.processInfo.environment
        if env["CT_GHI_MO"] == "1" { DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { datMoVo(true) } }
        if env["CT_GHI_KHUNG"] != nil { DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { dangChup = true } }
        if env["CT_GHI_VIET"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                vietDe?.ngonTayVe = env["CT_GHI_NGONTAY"] == "1"
                vietDe?.dangViet = true
            }
        }
        if let s = env["CT_GHI_CHUP"] {
            let so = s.split(separator: ",").compactMap { Double($0) }
            guard so.count == 4 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(env["CT_GHI_CHUP_SAU"] ?? "") ?? 5.0)) {
                guard let cs = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first,
                      let ngc else { return }
                if let anh = ChupDoan.cat(cs, vung: CGRect(x: so[0], y: so[1], width: so[2], height: so[3])) {
                    danVaoVo(anh, ngc)
                }
            }
        }
    }
    #endif
}

/// Thanh công cụ chỉ hiện khi đang bật viết (quan sát phiên ở đây, không bắt cả màn bài dựng lại).
private struct ThanhVietDeNeuBat: View {
    @ObservedObject var phien: PhienVietDe
    var body: some View {
        if phien.dangViet {
            ThanhVietDe(phien: phien)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(AppColors.backgroundPrimary.opacity(0.97))
                .overlay(alignment: .bottom) { Divider() }
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Cụm nút nổi

private struct CumNutGhi: View {
    let coVietDe: Bool
    let vietDe: PhienVietDe?
    let moVo: Bool
    let moGhi: () -> Void
    let chup: () -> Void
    let tenBai: String

    /// Vị trí theo TỈ LỆ khung màn (0…1) — xoay máy / mở cột Vở vẫn ở đúng góc người dùng đã kéo tới.
    @AppStorage("ghikhihoc.nut.x") private var tlX: Double = 1.0
    @AppStorage("ghikhihoc.nut.y") private var tlY: Double = 0.62
    @State private var keo: CGSize = .zero
    @State private var thuGon = false
    @ScaledMetric(relativeTo: .body) private var coGoc: CGFloat = 44

    /// Cỡ nút theo Dynamic Type, chặn trần để cụm không che nửa màn.
    /// 44pt ở cỡ chữ mặc định: cả cụm rộng 52pt — lọt lề phải của cột đọc 720pt trên iPad 11" dọc (lề 57pt).
    private var co: CGFloat { min(max(coGoc, 44), 62) }

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let cao = thuGon ? co + 20 : co * (coVietDe ? 3 : 2) + 24
            let x = min(max(co / 2 + 6, CGFloat(tlX) * w + keo.width), w - co / 2 - 4)
            let y = min(max(cao / 2 + 8, CGFloat(tlY) * h + keo.height), h - cao / 2 - 8)
            cum
                .position(x: x, y: y)
                .gesture(
                    DragGesture(minimumDistance: 12, coordinateSpace: .global)
                        .onChanged { keo = $0.translation }
                        .onEnded { v in
                            tlX = Double(min(max(0, (CGFloat(tlX) * w + v.translation.width) / max(w, 1)), 1))
                            tlY = Double(min(max(0, (CGFloat(tlY) * h + v.translation.height) / max(h, 1)), 1))
                            keo = .zero
                        })
        }
    }

    @ViewBuilder private var cum: some View {
        VStack(spacing: 4) {
            // Tay nắm: kéo để dời cụm; chạm để thu gọn / mở rộng.
            Capsule().fill(AppColors.textTertiary.opacity(0.6)).frame(width: 18, height: 4)
                .frame(width: co, height: 12)
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.easeInOut(duration: 0.18)) { thuGon.toggle() } }
                .accessibilityLabel(thuGon ? T("Mở rộng cụm Ghi khi học") : T("Thu gọn cụm Ghi khi học"))
                .accessibilityAddTraits(.isButton)
            nut(moVo ? "book.closed.fill" : "square.and.pencil", nen: AppColors.primary, chu: AppColors.onPrimary,
                nhan: moVo ? T("Đóng trang Vở") : T("Ghi nhanh vào Vở"), goi: "\(T("Trang của bài")) \(tenBai)", lam: moGhi)
            if !thuGon {
                if coVietDe, let vietDe { NutVietDe(phien: vietDe, co: co) }
                nut("viewfinder", nen: AppColors.backgroundCard, chu: AppColors.textPrimary,
                    nhan: T("Chụp đoạn bài vào Vở"), goi: T("Kéo khung chọn một vùng của bài"), lam: chup)
            }
        }
        .padding(4)
        .background(Capsule(style: .continuous).fill(.regularMaterial))
        .overlay(Capsule(style: .continuous).strokeBorder(AppColors.border, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
    }

    private func nut(_ hinh: String, nen: Color, chu: Color, nhan: String, goi: String,
                     lam: @escaping () -> Void) -> some View {
        Button(action: lam) {
            Image(systemName: hinh)
                .font(.system(size: co * 0.42, weight: .semibold))
                .foregroundStyle(chu)
                .frame(width: co, height: co)
                .background(Circle().fill(nen))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(nhan)
        .accessibilityHint(goi)
    }
}

private struct NutVietDe: View {
    @ObservedObject var phien: PhienVietDe
    let co: CGFloat
    var body: some View {
        Button {
            phien.dangViet.toggle()
            if !phien.dangViet { phien.ghiNgay() }
            Haptics.cham()
        } label: {
            Image(systemName: phien.dangViet ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle")
                .font(.system(size: co * 0.5, weight: .semibold))
                .foregroundStyle(phien.dangViet ? AppColors.onPrimary : AppColors.textPrimary)
                .frame(width: co, height: co)
                .background(Circle().fill(phien.dangViet ? AppColors.warning : AppColors.backgroundCard))
                .overlay(alignment: .topTrailing) {
                    // Chấm nhỏ: bài này đã có nét viết đè (kể cả khi lớp đang ẩn).
                    if phien.coNet && !phien.dangViet {
                        Circle().fill(phien.hienLop ? AppColors.primary : AppColors.textTertiary)
                            .frame(width: 9, height: 9).offset(x: -3, y: 3)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(phien.dangViet ? T("Tắt viết lên bài") : T("Viết lên bài bằng Apple Pencil"))
    }
}

// MARK: - Khung Vở nhanh (cột bên / sheet)

/// Một trang Vở bản gọn cho nửa màn hình: thanh trên mảnh (Về bài · tên trang · hoàn tác · ngón tay · bảng bút ·
/// mở cả cuốn) + khung vẽ `BangVe` của trang. Màn Vở đầy đủ (`ManVietView`) mở bằng nút ⤢.
struct KhungVietNhanh: View {
    let ngc: NguCanhGhi
    let laCotBen: Bool
    @ObservedObject var cauNoi: CauNoiGhiNhanh
    /// Lớp viết đè của bài (nil ⇒ màn không có). Đang viết đè ⇒ ẨN bảng bút hệ thống của Vở: mỗi lúc chỉ MỘT bộ bút.
    @ObservedObject private var vietDe: PhienVietDe
    private let coVietDe: Bool
    let chup: (() -> Void)?
    let dong: () -> Void

    init(ngc: NguCanhGhi, laCotBen: Bool, cauNoi: CauNoiGhiNhanh, vietDe: PhienVietDe?, chup: (() -> Void)?,
         dong: @escaping () -> Void) {
        self.ngc = ngc
        self.laCotBen = laCotBen
        self.cauNoi = cauNoi
        self.vietDe = vietDe ?? PhienVietDe.khong
        self.coVietDe = vietDe != nil
        self.chup = chup
        self.dong = dong
    }

    @Environment(\.modelContext) private var kho
    @State private var trang: TrangVo?
    @State private var cuon: CuonVo?
    @State private var moCaCuon = false
    /// Tăng ⇒ dựng lại khung vẽ (sau khi đóng màn Vở đầy đủ: nét trên đĩa mới hơn nét trong khung).
    @State private var lanDung = 0
    @State private var hienCongCu = true
    @AppStorage("vo.ngontay.cuon") private var nganTayCuon = false
    @AppStorage(CaiDatKhoTrang.khoaTuNoiDai) private var tuNoiDai = true

    var body: some View {
        VStack(spacing: 0) {
            thanhTren
            Divider()
            if let trang {
                BangVe(idTrang: trang.id, giay: trang.giay, khoTrang: trang.khoTrang, khoGoc: trang.khoGoc,
                       khiGanDay: {
                           guard tuNoiDai, trang.noiDaiNuaTrang() else { return }
                           ThaoTacTrang.danhDauCay(trang.cuon)
                           try? kho.save()
                       },
                       nenPdfTen: trang.nenPdfTen, nenPdfTrang: trang.nenPdfTrang, nenAnhTen: trang.nenAnhTen,
                       hienCongCu: hienCongCu && !moCaCuon && !vietDe.dangViet,
                       khiLuu: { d in
                           trang.coNet = !d.strokes.isEmpty
                           trang.suaLuc = Date()
                           trang.cuon?.suaLuc = Date()
                           DongBoVo.danhDauBan(trang)
                       },
                       nganTayCuon: nganTayCuon,
                       cauNoi: cauNoi.ve,
                       canhTren: true)
                    .id("\(trang.id.uuidString)#\(lanDung)")
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AppColors.backgroundPrimary)
        .onAppear(perform: nap)
        .onChange(of: ngc) { _, _ in
            cauNoi.ve.luuNgay()
            nap()
        }
        .onDisappear {
            cauNoi.ve.luuNgay()
            cauNoi.idTrangDangMo = nil
            DongBoVo.shared.batDau()
        }
        .fullScreenCover(isPresented: $moCaCuon, onDismiss: { lanDung += 1 }) {
            if let cuon, let trang {
                ManVietView(cuon: cuon, moTrang: trang.id)
                    .modelContainer(KhoSwiftData.chung)
            }
        }
    }

    private func nap() {
        DongBoVo.shared.gan(kho: kho)
        let (c, t) = ngc.layTrang(kho: kho)
        cuon = c
        trang = t
        cauNoi.idTrangDangMo = t.id
    }

    /// Hai hàng: [Về bài] … công cụ / tên trang + môn · cuốn — cột 340pt vẫn đọc được tên trang.
    private var thanhTren: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Button {
                    cauNoi.ve.luuNgay()
                    dong()
                } label: {
                    Label(T("Về bài"), systemImage: laCotBen ? "chevron.right" : "chevron.down")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize()
                }
                .accessibilityHint(T("Đóng trang Vở, quay lại bài đang học"))
                Spacer(minLength: 4)
                if coVietDe {
                    nutNho(vietDe.dangViet ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle",
                           vietDe.dangViet ? T("Tắt viết lên bài") : T("Viết lên bài bằng Apple Pencil"),
                           bat: vietDe.dangViet) {
                        vietDe.dangViet.toggle()
                        if !vietDe.dangViet { vietDe.ghiNgay() }
                        Haptics.cham()
                    }
                }
                if let chup { nutNho("viewfinder", T("Chụp đoạn bài vào Vở"), chup) }
                nutNho("arrow.uturn.backward", T("Hoàn tác")) { cauNoi.ve.hoanTac() }
                nutNho(nganTayCuon ? "hand.draw" : "pencil.and.scribble",
                       nganTayCuon ? T("Ngón tay đang cuộn trang") : T("Ngón tay đang viết"),
                       bat: nganTayCuon) { nganTayCuon.toggle(); Haptics.cham() }
                nutNho(hienCongCu ? "paintpalette.fill" : "paintpalette", hienCongCu ? T("Ẩn bảng bút") : T("Hiện bảng bút"),
                       bat: hienCongCu && !vietDe.dangViet) { hienCongCu.toggle() }
                nutNho("arrow.up.left.and.arrow.down.right", T("Mở trang trong Vở đầy đủ")) {
                    cauNoi.ve.luuNgay()
                    moCaCuon = true
                }
            }
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(trang?.tieuDe ?? ngc.tieuDeBai)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                    Text("\(cuon?.mon?.ten ?? ngc.maMon) · \(cuon?.ten ?? T("Ghi khi học"))")
                        .font(.caption2)
                        .foregroundStyle(AppColors.textTertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if vietDe.dangViet {
                    // Mỗi lúc MỘT bộ bút: đang viết lên bài ⇒ bảng bút của Vở tạm ẩn — nói ra để khỏi tưởng mất.
                    Text(T("Bảng bút Vở tạm ẩn khi viết lên bài"))
                        .font(.caption2).foregroundStyle(AppColors.textTertiary).lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
                HuyHieuDongBo()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppColors.backgroundSecondary)
    }

    private func nutNho(_ hinh: String, _ nhan: String, bat: Bool = false, _ lam: @escaping () -> Void) -> some View {
        Button(action: lam) {
            Image(systemName: hinh)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(bat ? AppColors.primary : AppColors.textPrimary)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(nhan)
    }
}

// MARK: - Chụp đoạn

enum ChupDoan {
    /// Cắt vùng `vung` (toạ độ cửa sổ) ra khỏi ẢNH ĐANG HIỂN THỊ của cửa sổ — `drawHierarchy` vẽ đúng thứ trên màn
    /// (PencilKit, ruby furigana, WKWebView), khác `ImageRenderer` chỉ dựng lại SwiftUI.
    @MainActor
    static func cat(_ cuaSo: UIWindow, vung: CGRect) -> UIImage? {
        let r = vung.standardized.intersection(cuaSo.bounds)
        guard r.width >= 24, r.height >= 24 else { return nil }
        let dinhDang = UIGraphicsImageRendererFormat()
        dinhDang.scale = cuaSo.traitCollection.displayScale
        dinhDang.opaque = true
        let anh = UIGraphicsImageRenderer(size: r.size, format: dinhDang).image { ctx in
            AppColorsNen.mauNen(cuaSo.traitCollection).setFill()
            ctx.fill(CGRect(origin: .zero, size: r.size))
            cuaSo.drawHierarchy(in: CGRect(x: -r.minX, y: -r.minY, width: cuaSo.bounds.width, height: cuaSo.bounds.height),
                                afterScreenUpdates: false)
        }
        return anh
    }
}

/// Màu nền dự phòng của ảnh chụp (vùng trong suốt) theo sáng/tối của cửa sổ.
private enum AppColorsNen {
    static func mauNen(_ t: UITraitCollection) -> UIColor {
        t.userInterfaceStyle == .dark ? UIColor(white: 0.08, alpha: 1) : .white
    }
}

/// Lớp phủ chọn vùng: kéo một khung chữ nhật; thả tay ⇒ chụp. Nằm trên CẢ màn học.
struct LopChupDoan: View {
    let khiXong: (CGRect, UIWindow?) -> Void
    let khiHuy: () -> Void

    @State private var dau: CGPoint?
    @State private var cuoi: CGPoint?
    @State private var cuaSo: UIWindow?

    private var khung: CGRect? {
        guard let dau, let cuoi else { return nil }
        return CGRect(x: min(dau.x, cuoi.x), y: min(dau.y, cuoi.y), width: abs(dau.x - cuoi.x), height: abs(dau.y - cuoi.y))
    }

    var body: some View {
        GeometryReader { g in
            let goc = g.frame(in: .global).origin
            ZStack(alignment: .top) {
                // Màn mờ, khoét đúng khung đang chọn (tô chẵn-lẻ: hình chữ nhật cả màn trừ khung).
                Path { p in
                    p.addRect(CGRect(origin: .zero, size: g.size))
                    if let k = khung { p.addRect(k.offsetBy(dx: -goc.x, dy: -goc.y)) }
                }
                .fill(Color.gray.opacity(0.45), style: FillStyle(eoFill: true))
                if let k = khung {
                    Rectangle().strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [7, 4]))
                        .foregroundStyle(AppColors.primary)
                        .frame(width: k.width, height: k.height)
                        .position(x: k.midX - goc.x, y: k.midY - goc.y)
                }
                HStack(spacing: 10) {
                    Image(systemName: "viewfinder")
                    Text(khung == nil ? T("Kéo khung quanh đoạn muốn chép vào Vở") : T("Thả tay để chụp"))
                        .font(.callout.weight(.semibold))
                    Button(T("Huỷ"), action: khiHuy)
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(AppColors.backgroundCard))
                }
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Capsule().fill(.regularMaterial))
                .padding(.top, max(g.safeAreaInsets.top, 24) + 66)   // dưới thanh tiêu đề
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .global)
                    .onChanged { v in
                        if dau == nil { dau = v.startLocation }
                        cuoi = v.location
                    }
                    .onEnded { _ in
                        if let k = khung, k.width >= 24, k.height >= 24 {
                            khiXong(k, cuaSo)
                        } else {
                            dau = nil; cuoi = nil
                        }
                    })
        }
        .background(MocCuaSo { cuaSo = $0 })
        #if DEBUG
        // Màn soi: `CT_GHI_KHUNG=x,y,w,h` ⇒ vẽ sẵn khung chọn (toạ độ cửa sổ) — simctl không kéo được.
        .onAppear {
            let so = (ProcessInfo.processInfo.environment["CT_GHI_KHUNG"] ?? "").split(separator: ",").compactMap { Double($0) }
            if so.count == 4 { dau = CGPoint(x: so[0], y: so[1]); cuoi = CGPoint(x: so[0] + so[2], y: so[1] + so[3]) }
        }
        #endif
        .ignoresSafeArea()
        .transition(.opacity)
    }
}

/// Lấy `UIWindow` chứa màn (đúng cửa sổ, kể cả khi iPad mở hai cửa sổ cạnh nhau).
private struct MocCuaSo: UIViewRepresentable {
    let khiCo: (UIWindow) -> Void
    func makeUIView(context: Context) -> MocView { let v = MocView(); v.khiCo = khiCo; return v }
    func updateUIView(_ v: MocView, context: Context) {}
    final class MocView: UIView {
        var khiCo: ((UIWindow) -> Void)?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let w = window { DispatchQueue.main.async { [weak self] in self?.khiCo?(w) } }
        }
    }
}

// MARK: - Mở lại bài kiểu sách từ Vở

/// Bài kiểu sách mở từ trang Vở "ghi khi học" (menu ⋯ của màn Vở).
struct MoBaiSachHocView: View {
    let khoa: String
    let baiId: String
    @StateObject private var vm: SachHocVM
    @Environment(\.dismiss) private var dong

    init(khoa: String, baiId: String) {
        self.khoa = khoa
        self.baiId = baiId
        _vm = StateObject(wrappedValue: SachHocVM(khoa: khoa))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let m = muc {
                    BaiSachHocView(vm: vm, muc: m)
                } else if let loi = vm.loi {
                    KhungLoiSH(loi: loi) { Task { await vm.nap() } }
                } else if vm.khoa != nil {
                    Text(T("Không tìm thấy bài này trong khoá.")).foregroundStyle(AppColors.textSecondary)
                } else {
                    ProgressView()
                }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(T("Đóng")) { dong() } } }
        }
        .task { if vm.khoa == nil { await vm.nap() } }
    }

    private var muc: MucDocSH? {
        guard let k = vm.khoa else { return nil }
        if baiId == k.gioiThieu.id { return .gioiThieu }
        if k.phu.contains(where: { $0.id == baiId }) { return .phu(id: baiId) }
        if let b = k.buoi.first(where: { $0.bai.contains { $0.id == baiId } }) { return .bai(buoi: b.n, id: baiId) }
        return nil
    }
}
#endif
