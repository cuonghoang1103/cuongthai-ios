#if os(iOS)
import PencilKit
import SwiftData
import SwiftUI

// ════════════════════════════════════════════════════════════════
// KHỔ GIẤY CỦA CUỐN + NỐI DÀI TRANG
//
// Người dùng 28/09/2026: "trang vở nhìn nhỏ quá, viết được tý là hết; có nút
// chỉnh kích cỡ trang không; chỉnh một trang thì cả cuốn đồng bộ theo".
//
// Hai núm, đúng như GoodNotes/Notability làm:
//   1. KHỔ của cả cuốn (A5 … A3, 16:9, Bảng lớn) — đổi một chỗ, mọi trang
//      theo. Trang có nền PDF/ảnh giữ khổ tài liệu.
//   2. NỐI DÀI từng trang (+½ trang, tới 4× chiều cao gốc) — bấm tay, hoặc
//      tự nối khi viết tới gần đáy.
//
// ⚠️ Nét KHÔNG BAO GIỜ bị dời hay cắt. Toạ độ nét giữ nguyên (gốc góc
// trên-trái); đổi sang khổ nhỏ hơn mà trang có nét nằm ngoài thì:
//   · nét chỉ tràn xuống dưới ⇒ trang đó tự nối dài cho đủ chỗ;
//   · nét tràn sang phải     ⇒ trang đó GIỮ khổ cũ (`khoGiayRieng`).
// ════════════════════════════════════════════════════════════════

@MainActor
enum DoiKhoGiay {

    /// Một trang sẽ ra sao nếu đổi cuốn sang khổ `moi`.
    enum KetQuaTrang: Equatable {
        case theoCuon            // vừa khổ mới
        case noiDai(Double)      // theo khổ mới, nối dài thêm (pt)
        case giuKhoCu(KhoGiay)   // nét tràn bề ngang ⇒ giữ khổ cũ
        case khoTaiLieu          // trang PDF/ảnh — không đổi
    }

    struct TomTat {
        var theoCuon = 0
        var noiDai = 0
        var giuKhoCu = 0
        var taiLieu = 0
        var chiTiet: [UUID: KetQuaTrang] = [:]
    }

    /// Xét từng trang. Đọc tệp nét từ đĩa ⇒ gọi `luuNgay` của khung vẽ TRƯỚC,
    /// kẻo 2 giây nét cuối chưa kịp lưu không được tính.
    static func xet(_ cuon: CuonVo, sang moi: KhoGiay) -> TomTat {
        var tt = TomTat()
        for t in cuon.trangsTheoThuTu {
            let kq = xetMotTrang(t, sang: moi)
            tt.chiTiet[t.id] = kq
            switch kq {
            case .theoCuon: tt.theoCuon += 1
            case .noiDai: tt.noiDai += 1
            case .giuKhoCu: tt.giuKhoCu += 1
            case .khoTaiLieu: tt.taiLieu += 1
            }
        }
        return tt
    }

    static func xetMotTrang(_ t: TrangVo, sang moi: KhoGiay) -> KetQuaTrang {
        if t.coNenTaiLieu { return .khoTaiLieu }
        let goc = moi.kho(t.huong)
        // KHÔNG tin cờ `coNet`: trang kéo về / gieo bằng mã có thể chưa đặt
        // cờ mà tệp nét vẫn có — đọc thẳng tệp mới chắc không cắt mất nét.
        let b = KhoVo.nap(t.id).bounds
        guard !b.isNull, !b.isEmpty else { return .theoCuon }
        // Lề 2pt: `renderBounds` tính cả nửa độ dày nét, nét sát mép vẫn "vừa".
        if b.maxX > goc.width + 2 { return .giuKhoCu(t.khoGiayApDung) }
        let thieu = Double(b.maxY - goc.height)
        guard thieu > 2 else { return .theoCuon }
        // Làm tròn LÊN theo nấc nửa trang — cùng nấc với nút "Nối dài".
        let buoc = Double(goc.height / 2)
        let them = (thieu / buoc).rounded(.up) * buoc
        // Vượt trần 4× (Bảng lớn → A5 chẳng hạn) ⇒ giữ khổ cũ, không nối vô hạn.
        if them > Double(goc.height) * 3 + 0.5 { return .giuKhoCu(t.khoGiayApDung) }
        return .noiDai(them)
    }

    /// Áp khổ mới cho cả cuốn. Trả về bản tóm tắt để báo cho người dùng.
    @discardableResult
    static func ap(_ cuon: CuonVo, sang moi: KhoGiay, kho: ModelContext) -> TomTat {
        let tt = xet(cuon, sang: moi)
        // Chiều cao CŨ (gồm phần nối) chụp trước khi đổi khổ cuốn.
        let caoCu = Dictionary(uniqueKeysWithValues: cuon.trangsTheoThuTu.map { ($0.id, $0.khoTrang.height) })
        cuon.khoGiay = moi == .a4 ? nil : moi.rawValue
        for t in cuon.trangsTheoThuTu {
            switch tt.chiTiet[t.id] ?? .theoCuon {
            case .theoCuon:
                t.khoGiayRieng = nil
                // Khổ to ra: phần nối dài cũ thành thừa — nhưng người dùng
                // có thể đã nối để dành chỗ viết. Chỉ gỡ khi khổ mới đã cao
                // hơn cả trang cũ (gồm phần nối).
                if t.chieuCaoThem > 0, moi.kho(t.huong).height >= (caoCu[t.id] ?? .infinity) {
                    t.chieuCaoThem = 0
                }
            case .noiDai(let them):
                t.khoGiayRieng = nil
                t.chieuCaoThem = max(t.chieuCaoThem, them)
            case .giuKhoCu(let k):
                t.khoGiayRieng = k.rawValue
            case .khoTaiLieu:
                break
            }
            t.suaLuc = Date()
        }
        cuon.suaLuc = Date()
        ThaoTacTrang.danhDauCay(cuon)
        try? kho.save()
        return tt
    }

    /// Thu phần nối dài về mức nhỏ nhất vẫn chứa hết nét (theo nấc ½ trang).
    static func thuGon(_ t: TrangVo) -> Bool {
        guard t.chieuCaoThem > 0 else { return false }
        let goc = t.khoGoc
        let b = KhoVo.nap(t.id).bounds
        let thieu = (b.isNull || b.isEmpty) ? 0 : Double(b.maxY - goc.height)
        let buoc = Double(goc.height / 2)
        let can = thieu > 2 ? (thieu / buoc).rounded(.up) * buoc : 0
        guard can < t.chieuCaoThem else { return false }
        t.chieuCaoThem = can
        t.suaLuc = Date()
        return true
    }
}

// MARK: - Cửa sổ chọn khổ

struct KhoGiayCuonView: View {
    let cuon: CuonVo
    /// Trang đang mở — để hiện phần "Trang này" (nối dài).
    let trang: TrangVo?
    /// Lưu nét đang dở của khung vẽ xuống đĩa trước khi xét.
    let luuTruoc: () -> Void
    let bao: (String) -> Void

    @Environment(\.dismiss) private var dong
    @Environment(\.modelContext) private var kho
    @AppStorage(CaiDatKhoTrang.khoaTuNoiDai) private var tuNoiDai = true
    @State private var chon: KhoGiay = .a4
    @State private var tomTat: DoiKhoGiay.TomTat?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: Spacing.sm)],
                              spacing: Spacing.sm) {
                        ForEach(KhoGiay.allCases) { k in oKho(k) }
                    }
                    .padding(.vertical, Spacing.xs)
                } header: {
                    Text(T("Khổ giấy của cả cuốn"))
                } footer: {
                    Text(T("Đổi một lần, mọi trang trong cuốn theo — kể cả trang thêm sau này. Nét đã viết giữ nguyên chỗ; trang có nền PDF/ảnh giữ khổ tài liệu."))
                }

                if chon != cuon.kho, let tt = tomTat {
                    Section(T("Sẽ thay đổi")) {
                        if tt.theoCuon > 0 {
                            dongTomTat("checkmark.circle", AppColors.success,
                                       "\(tt.theoCuon) \(T("trang theo khổ")) \(chon.ten)")
                        }
                        if tt.noiDai > 0 {
                            dongTomTat("arrow.down.to.line", AppColors.primary,
                                       "\(tt.noiDai) \(T("trang có nét dưới đáy khổ mới — tự nối dài cho đủ chỗ"))")
                        }
                        if tt.giuKhoCu > 0 {
                            dongTomTat("exclamationmark.triangle", AppColors.warning,
                                       "\(tt.giuKhoCu) \(T("trang có nét tràn bề ngang — GIỮ khổ cũ, không cắt nét nào"))")
                        }
                        if tt.taiLieu > 0 {
                            dongTomTat("doc.richtext", AppColors.textSecondary,
                                       "\(tt.taiLieu) \(T("trang PDF/ảnh giữ khổ tài liệu"))")
                        }
                    }
                }

                if let t = trang {
                    Section {
                        Button {
                            if t.noiDaiNuaTrang() {
                                ThaoTacTrang.danhDauCay(cuon)
                                try? kho.save()
                                bao(T("Đã nối dài trang thêm ½ trang"))
                            }
                        } label: {
                            Label(T("Nối dài trang này (+½ trang)"), systemImage: "arrow.down.to.line.compact")
                        }
                        .disabled(!t.noiDaiDuoc)
                        if t.chieuCaoThem > 0 {
                            Button {
                                luuTruoc()
                                if DoiKhoGiay.thuGon(t) {
                                    ThaoTacTrang.danhDauCay(cuon)
                                    try? kho.save()
                                    bao(T("Đã thu gọn phần nối dài"))
                                } else {
                                    bao(T("Phần nối dài đang có nét — không thu được"))
                                }
                            } label: {
                                Label(T("Thu gọn phần nối dài (giữ hết nét)"), systemImage: "arrow.up.to.line.compact")
                            }
                        }
                        Toggle(isOn: $tuNoiDai) {
                            Label(T("Tự nối dài khi viết tới gần đáy"), systemImage: "arrow.down.doc")
                        }
                    } header: {
                        Text(T("Trang này"))
                    } footer: {
                        Text(chuTrangNay(t))
                    }
                }
            }
            .navigationTitle(T("Khổ giấy"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Huỷ")) { dong() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Áp dụng")) { apDung() }
                        .fontWeight(.semibold)
                        .disabled(chon == cuon.kho)
                }
            }
            .onAppear {
                luuTruoc()
                chon = cuon.kho
                #if DEBUG
                // Bàn thử: CT_KHO_CHON=a5 ⇒ chọn sẵn để thấy phần "Sẽ thay đổi".
                if let k = ProcessInfo.processInfo.environment["CT_KHO_CHON"].flatMap(KhoGiay.init(rawValue:)) {
                    chon = k
                }
                #endif
            }
            .onChange(of: chon) { _, k in
                tomTat = k == cuon.kho ? nil : DoiKhoGiay.xet(cuon, sang: k)
            }
        }
    }

    private func chuTrangNay(_ t: TrangVo) -> String {
        let k = t.khoTrang
        let mm = { (p: CGFloat) in Int((p / 72 * 25.4).rounded()) }
        var s = "\(T("Trang đang mở")): \(mm(k.width))×\(mm(k.height)) mm"
        if t.chieuCaoThem > 0 {
            s += " · " + T("đã nối dài") + " \(mm(CGFloat(t.chieuCaoThem))) mm"
        }
        if t.khoGiayRieng != nil { s += " · " + T("giữ khổ riêng") + " \(t.khoGiayApDung.ten)" }
        return s + ". " + T("Tối đa gấp 4 chiều cao gốc.")
    }

    private func dongTomTat(_ icon: String, _ mau: Color, _ chu: String) -> some View {
        Label {
            Text(chu).font(.subheadline).foregroundStyle(AppColors.textPrimary)
        } icon: {
            Image(systemName: icon).foregroundStyle(mau)
        }
    }

    /// Một ô khổ: hình chữ nhật đúng TỈ LỆ và đúng CỠ tương đối (A4 làm mốc),
    /// để thấy ngay A3 to gấp đôi A4, A5 bằng nửa.
    private func oKho(_ k: KhoGiay) -> some View {
        let dangChon = chon == k
        let huong = trang?.huong ?? .doc
        let kt = k.kho(huong)
        let s: CGFloat = 92 / 2263   // cạnh dài Bảng lớn = 92pt; A4 ≈ 34pt
        return Button {
            chon = k
            Haptics.cham()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(dangChon ? AppColors.primary : AppColors.border,
                                          lineWidth: dangChon ? 2 : 1))
                        .frame(width: max(10, kt.width * s), height: max(10, kt.height * s))
                        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                }
                .frame(height: 96, alignment: .bottom)
                Text(k.ten)
                    .font(.subheadline.weight(dangChon ? .semibold : .regular))
                    .foregroundStyle(dangChon ? AppColors.primary : AppColors.textPrimary)
                Text(k.moTa)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 28, alignment: .top)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(dangChon ? AppColors.primary.opacity(0.08) : Color.clear))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(k.ten + ", " + k.moTa)
        .accessibilityAddTraits(dangChon ? .isSelected : [])
    }

    private func apDung() {
        luuTruoc()
        let tt = DoiKhoGiay.ap(cuon, sang: chon, kho: kho)
        var cau = "\(T("Cả cuốn đã sang khổ")) \(chon.ten)"
        if tt.giuKhoCu > 0 { cau += " · \(tt.giuKhoCu) \(T("trang giữ khổ cũ"))" }
        bao(cau)
        Haptics.xong()
        DongBoVo.shared.batDau()
        dong()
    }
}

/// Khoá cài đặt dùng chung giữa màn viết và cửa sổ khổ giấy.
enum CaiDatKhoTrang {
    static let khoaTuNoiDai = "vo.tuNoiDaiTrang"
}
#endif
