#if os(iOS)
import PencilKit
import SwiftUI
import UIKit

// ════════════════════════════════════════════════════════════════
// ✨ LÀM GỌN CHỮ — cửa sổ xem trước/sau rồi mới áp dụng
//
// ⚠️ Cửa sổ này KHÔNG BAO GIỜ đụng vào khung vẽ cho tới khi bấm "Áp dụng".
// Xem trước là ẢNH dựng từ một bản sao `PKDrawing`, không phải đặt tạm bản
// mới lên khung: khung vẽ tự lưu sau 2 giây, đặt tạm là bản xem trước có
// thể bị ghi xuống đĩa và đẩy lên máy chủ khi người dùng còn chưa quyết.
//
// Áp dụng đi qua `CauNoiBangVe.datBanVe` ⇒ vào bộ hoàn tác của khung: nút ↶
// trên thanh và ⌘Z trả lại y nguyên.
// ════════════════════════════════════════════════════════════════

struct LamGonView: View {
    let idTrang: UUID
    let goc: PKDrawing
    let giay: LoaiGiay
    let khoTrang: CGSize
    /// Chiều cao GỐC (chưa nối dài) — đường chân chữ Cornell phụ thuộc nó.
    var caoGoc: CGFloat? = nil
    /// Vùng khoanh (toạ độ trang); `nil` = cả trang.
    let vung: CGRect?
    /// Trả `false` nếu không áp được (khung đã sang trang khác) — cửa sổ ở lại.
    let apDung: (PKDrawing) -> Bool

    @Environment(\.dismiss) private var dong
    // Nhớ lựa chọn giữa các lần mở: người không thích nắn hình tắt một lần là xong.
    @AppStorage("vo.lamgon.muot") private var lamMuot = true
    @AppStorage("vo.lamgon.dong") private var thangHang = true
    @AppStorage("vo.lamgon.bang") private var nanBang = true
    @AppStorage("vo.lamgon.hinh") private var nanHinh = true

    @State private var ketQua: KetQuaLamGon?
    @State private var anhGoc: UIImage?
    @State private var anhSau: UIImage?
    @State private var xemGoc = false
    /// Đang giữ ngón trên ảnh ⇒ tạm hiện bản gốc (thả ra là về "sau").
    @State private var dangGiu = false
    @State private var dangTinh = false
    @State private var loi: String?

    private var tuyChon: TuyChonLamGon {
        TuyChonLamGon(lamMuot: lamMuot, thangHang: thangHang, nanBang: nanBang, nanHinh: nanHinh)
    }

    /// Vùng dựng ảnh: vùng khoanh, hoặc khung bao mọi nét (trước + sau) nới
    /// ra một chút. Dựng cả khổ A4 thì trang chỉ có ba dòng chữ nhìn như ba
    /// sợi chỉ giữa một tờ giấy trắng.
    private var vungAnh: CGRect {
        let trang = CGRect(origin: .zero, size: khoTrang)
        var r = vung ?? goc.bounds
        if let sau = ketQua?.drawing.bounds, vung == nil { r = r.union(sau) }
        if r.isNull || r.width < 1 { return trang }
        r = r.insetBy(dx: -24, dy: -24).intersection(trang)
        return r.isNull ? trang : r
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                khungXem
                Divider()
                bangChon
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle(vung == nil ? T("Làm gọn chữ") : T("Làm gọn vùng khoanh"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(T("Huỷ")) { dong() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Áp dụng")) { bamApDung() }
                        .fontWeight(.semibold)
                        .disabled(ketQua == nil || dangTinh || (ketQua?.soNetDoi ?? 0) == 0)
                }
            }
        }
        .modifier(CoTrangLon())
        .task(id: tuyChon) { await tinh() }
        #if DEBUG
        .onAppear {
            // Bàn thử máy ảo: CT_LAMGON_XEM=goc mở sẵn ở bản gốc để chụp.
            if ProcessInfo.processInfo.environment["CT_LAMGON_XEM"] == "goc" { xemGoc = true }
        }
        #endif
    }

    // MARK: Xem trước

    private var khungXem: some View {
        VStack(spacing: Spacing.sm) {
            Picker("", selection: $xemGoc) {
                Text(T("Trước")).tag(true)
                Text(T("Sau")).tag(false)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
            .padding(.top, Spacing.sm)

            GeometryReader { geo in
                ScrollView([.vertical]) {
                    let anh = (xemGoc || dangGiu) ? anhGoc : anhSau
                    ZStack {
                        if let anh {
                            Image(uiImage: anh)
                                .resizable()
                                .interpolation(.high)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: geo.size.width - 24)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                        } else {
                            ProgressView().frame(height: 200)
                        }
                        if dangTinh && anh != nil {
                            ProgressView().padding(Spacing.md)
                                .background(Circle().fill(AppColors.backgroundCard.opacity(0.9)))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    // Giữ lâu trên ảnh = xem bản gốc, thả ra = về bản sau. So
                    // nhanh bằng cách nhấp nháy tại chỗ, không phải kéo mắt qua lại.
                    .onLongPressGesture(minimumDuration: 30, maximumDistance: 40,
                                        pressing: { dangGiu = $0 }, perform: {})
                }
            }

            Text((xemGoc || dangGiu) ? T("Bản GỐC — giữ nguyên cho tới khi bấm Áp dụng")
                                     : T("Giữ ngón trên ảnh để so với bản gốc"))
                .font(.caption)
                .foregroundStyle((xemGoc || dangGiu) ? AppColors.primary : AppColors.textTertiary)
                .padding(.bottom, Spacing.xs)
        }
    }

    // MARK: Công tắc

    private var bangChon: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            dongChon($lamMuot, "scribble", T("Làm mượt nét"),
                     T("Khử run tay, giữ nguyên góc gãy; độ đậm nét đều hơn"))
            dongChon($thangHang, "text.alignleft", T("Thẳng hàng theo dòng"),
                     giay == .trang || GiayNenView.dongChanChu(giay: giay, khoTrang: khoTrang, caoGoc: caoGoc).isEmpty
                        ? T("Nắn dòng nghiêng cho ngang, chữ về cùng đường chân")
                        : T("Nắn dòng nghiêng, đặt chữ lên dòng kẻ, đều cỡ vừa phải"))
            dongChon($nanBang, "tablecells", T("Nắn nét thẳng và bảng"),
                     T("Đường gần thẳng thành thẳng; hàng cột gióng thẳng; chữ vào giữa ô"))
            dongChon($nanHinh, "circle.square", T("Nắn hình"),
                     T("Tròn, elip, chữ nhật, tam giác, mũi tên thành hình chuẩn"))

            if let loi {
                Text(loi).font(.caption).foregroundStyle(AppColors.error)
            } else if let k = ketQua {
                Text(tomTat(k)).font(.caption.monospacedDigit()).foregroundStyle(AppColors.textSecondary)
            }
            Text(T("Vẫn là nét tay của bạn — không thay bằng phông chữ, không gửi đi đâu. Áp dụng xong bấm ↶ để trả lại."))
                .font(.caption2)
                .foregroundStyle(AppColors.textTertiary)
        }
        .padding(Spacing.md)
    }

    private func dongChon(_ bat: Binding<Bool>, _ icon: String, _ ten: String, _ moTa: String) -> some View {
        Toggle(isOn: bat) {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon).frame(width: 24).foregroundStyle(AppColors.primary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(ten).font(Font.bodyMedium.weight(.medium)).foregroundStyle(AppColors.textPrimary)
                    Text(moTa).font(.caption).foregroundStyle(AppColors.textTertiary)
                }
            }
        }
    }

    private func tomTat(_ k: KetQuaLamGon) -> String {
        if k.soNetDoi == 0 { return T("Không có gì để làm gọn với các phép đang bật") }
        var p = ["\(T("Sửa")) \(k.soNetDoi) \(T("nét"))"]
        if k.soDong > 0 { p.append("\(k.soDong) \(T("dòng"))") }
        if k.soBang > 0 { p.append("\(k.soBang) \(T("bảng"))") }
        if k.soHinh > 0 { p.append("\(k.soHinh) \(T("hình"))") }
        if k.soNetThang > 0 { p.append("\(k.soNetThang) \(T("nét thẳng"))") }
        p.append("\(Int(k.mili.rounded())) ms")
        return p.joined(separator: " · ")
    }

    // MARK: Tính + áp dụng

    private func tinh() async {
        dangTinh = true
        defer { dangTinh = false }
        let tc = tuyChon, d = goc, v = vung
        let dk = GiayNenView.dongChanChu(giay: giay, khoTrang: khoTrang, caoGoc: caoGoc)
        // Chạy NỀN: trang dày hai nghìn nét mất vài chục mili giây — nhỏ,
        // nhưng bật/tắt công tắc liên tục thì cộng dồn thành giật.
        let kq = await Task.detached(priority: .userInitiated) {
            LamGonChu.lamGon(d, tuyChon: tc, vung: v, dongKe: dk)
        }.value
        guard !Task.isCancelled else { return }
        ketQua = kq
        let r = vungAnh
        anhGoc = Self.dungAnh(goc, giay: giay, khoTrang: khoTrang, caoGoc: caoGoc, vung: r)
        anhSau = Self.dungAnh(kq.drawing, giay: giay, khoTrang: khoTrang, caoGoc: caoGoc, vung: r)
        NhatKy.vo.info("làm gọn: \(kq.soNetDoi) nét · \(kq.soDong) dòng · \(kq.soBang) bảng · \(kq.soHinh) hình · \(Int(kq.mili)) ms")
        #if DEBUG
        // Bàn thử máy ảo: CT_LAMGON=ap ⇒ tự bấm Áp dụng khi đã có kết quả.
        if ProcessInfo.processInfo.environment["CT_LAMGON"] == "ap" {
            try? await Task.sleep(for: .seconds(1.5))
            bamApDung()
        }
        #endif
    }

    private func bamApDung() {
        guard let k = ketQua else { return }
        if apDung(k.drawing) {
            Haptics.xong()
            dong()
        } else {
            loi = T("Trang đang mở đã đổi — đóng cửa sổ này rồi mở lại.")
        }
    }

    /// Ảnh giấy + mực của vùng `vung`, luôn ở giao diện SÁNG (giấy thật).
    static func dungAnh(_ d: PKDrawing, giay: LoaiGiay, khoTrang: CGSize, caoGoc: CGFloat? = nil, vung: CGRect,
                        rongPx: CGFloat = 1600) -> UIImage {
        let s = max(0.5, min(6, rongPx / max(vung.width, 1)))
        let kho = CGSize(width: vung.width * s, height: vung.height * s)
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        var ra = UIImage()
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            let nen = GiayNenView(frame: CGRect(origin: .zero, size: khoTrang))
            nen.giay = giay; nen.khoTrang = khoTrang; nen.caoGoc = caoGoc; nen.tyLe = 1
            let muc = d.image(from: vung, scale: s)
            ra = UIGraphicsImageRenderer(size: kho, format: fmt).image { c in
                c.cgContext.saveGState()
                c.cgContext.scaleBy(x: s, y: s)
                c.cgContext.translateBy(x: -vung.minX, y: -vung.minY)
                nen.draw(CGRect(origin: .zero, size: khoTrang))
                c.cgContext.restoreGState()
                muc.draw(in: CGRect(origin: .zero, size: kho))
            }
        }
        return ra
    }
}
/// Cửa sổ khổ TRANG trên iPad (iOS 18+). Khổ "form" mặc định chỉ ~540pt —
/// ảnh xem trước bé tới mức không thấy chữ đã thẳng hàng hay chưa (đo trên
/// máy ảo 28/09). iOS 17 vẫn dùng khổ mặc định.
struct CoTrangLon: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.presentationSizing(.page)
        } else {
            content
        }
    }
}
#endif
