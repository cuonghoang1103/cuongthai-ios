import SwiftUI

// ════════════════════════════════════════════════════════════════
// THƯ VIỆN SÁCH
//
// Bìa vẽ NATIVE chứ không chép cách của web. Web phủ logo hãng bằng CSS mask
// lên file SVG ở `/books/logos/*.svg` — SwiftUI không dựng được SVG, mà kéo
// Kingfisher vào để tải SVG thì cũng không giải mã được. Nên bìa ở đây dựng
// bằng chính màu nhũ của từng tập + số tập + tên: sắc nét ở mọi mật độ điểm
// ảnh, không tốn một lượt mạng nào, và hợp với dáng kệ sách trên điện thoại
// hơn là bê nguyên bìa của web xuống.
// ════════════════════════════════════════════════════════════════

struct ThuVienSachView: View {
    @State private var tim = ""

    private var nhomHien: [NhomSach] {
        let k = tim.trimmingCharacters(in: .whitespaces)
        // ⚠️ Bỏ dấu trước khi so. Từ khi có 16 tập tiếng Việt (26–41), gõ
        // "lanh dao" — kiểu gõ tự nhiên nhất trên điện thoại — không ra
        // "Lãnh đạo và quản lý con người". Hồi thư viện chỉ có sách tiếng Anh
        // thì lỗi này không lộ ra.
        let kh = k.chuanHoaTim
        guard !k.isEmpty else { return KhoSach.nhom }
        return KhoSach.nhom.compactMap { n in
            let ds = n.sach.filter {
                $0.tua.chuanHoaTim.contains(kh) || $0.vol.contains(k)
            }
            return ds.isEmpty ? nil : NhomSach(tua: n.tua, moTa: n.moTa, sach: ds)
        }
    }

    private let cot = [GridItem(.flexible(), spacing: Spacing.md),
                       GridItem(.flexible(), spacing: Spacing.md)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                khoiSoLieu
                oTim
                if nhomHien.isEmpty {
                    Text("Không có tập nào khớp “\(tim)”.")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity).padding(.top, Spacing.xl)
                }
                ForEach(nhomHien) { n in
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(n.tua)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                        Text(n.moTa)
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        LazyVGrid(columns: cot, spacing: Spacing.md) {
                            ForEach(n.sach) { s in
                                NavigationLink { DocSachView(sach: s) } label: { bia(s) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, Spacing.xs)
                    }
                }
                Spacer(minLength: Spacing.xl)
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Thư viện sách")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var khoiSoLieu: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("CuongThai Book Series")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundColor(AppColors.textPrimary)
            // Sáu con số của cả bộ — cho người mở lần đầu thấy ngay tầm vóc.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.sm), count: 3),
                      spacing: Spacing.sm) {
                ForEach(KhoSach.thongKe, id: \.0) { so, nhan in
                    VStack(spacing: 1) {
                        Text(so)
                            .font(.system(size: 17, weight: .bold).monospacedDigit())
                            .foregroundColor(AppColors.primary)
                        Text(nhan)
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(AppColors.backgroundCard))
                }
            }
        }
    }

    private var oTim: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass").foregroundColor(AppColors.textTertiary)
            TextField("Tìm tập sách…", text: $tim)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
            if !tim.isEmpty {
                Button { tim = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.sm + 2)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundCard))
    }

    // ── Bìa sách ─────────────────────────────────────────────────
    //
    // Dựng lại BÌA VẢI ÉP NHŨ của web bằng SwiftUI thuần. Web làm bằng CSS:
    // nền `color-mix(--c 80%, #14121b)` + hai lớp sáng chếch · sợi linen bằng
    // hai lưới `repeating-linear-gradient` trộn soft-light · khung nhũ ép chìm
    // cách mép · gáy sách 18px · logo hãng phủ `-webkit-mask` ăn màu nhũ ·
    // tựa chữ nhũ serif.
    //
    // Bản đầu tôi làm nền phẳng + chữ trắng, người dùng nói ngay là "trên web
    // có ảnh bìa đẹp mà app không có". Đúng — bìa mới là thứ làm nó ra dáng
    // sách chứ không phải cái thẻ màu.
    private func bia(_ s: Sach) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ZStack(alignment: .topLeading) {
                nenVai(s)
                soiLinen
                khungNhu
                gay(s)
                noiDungBia(s)
            }
            .frame(height: 232)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.black.opacity(0.45), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 10, x: -3, y: 6)

            Text("\(s.soChuong) chương · \(s.soBaiTap) bài tập")
                .font(.system(size: 11))
                .foregroundColor(AppColors.textTertiary)
                .lineLimit(1)
        }
    }

    /// Nhũ vàng — cố định, KHÔNG theo chế độ sáng/tối của app. Bìa sách thật
    /// không đổi màu theo đèn phòng.
    private static let nhu = Color(hex: 0xE6C583)
    private static let nhuSang = Color(hex: 0xF5E7C2)

    private func nenVai(_ s: Sach) -> some View {
        // `color-mix(in oklab, var(--c) 80%, #14121b)` — trộn 80% màu tập với
        // nền tối, cho ra tông vải sâu thay vì màu tươi.
        ZStack {
            s.mau.opacity(0.8)
            Color(hex: 0x14121B).opacity(0.55)
            LinearGradient(colors: [.white.opacity(0.12), .clear],
                           startPoint: .topLeading, endPoint: .center)
            LinearGradient(colors: [.black.opacity(0.4), .clear],
                           startPoint: .bottomTrailing, endPoint: .center)
        }
    }

    /// Sợi vải: hai lưới kẻ mảnh 1px cách 3px, một ngang một dọc.
    private var soiLinen: some View {
        Canvas { ctx, cd in
            var ngang = Path()
            var y: CGFloat = 0
            while y < cd.height { ngang.addRect(CGRect(x: 0, y: y, width: cd.width, height: 1)); y += 3 }
            ctx.fill(ngang, with: .color(.black.opacity(0.07)))
            var doc = Path()
            var x: CGFloat = 0
            while x < cd.width { doc.addRect(CGRect(x: x, y: 0, width: 1, height: cd.height)); x += 3 }
            ctx.fill(doc, with: .color(.white.opacity(0.05)))
        }
        .allowsHitTesting(false)
    }

    private var khungNhu: some View {
        RoundedRectangle(cornerRadius: 2)
            .strokeBorder(Self.nhu.opacity(0.42), lineWidth: 1)
            .padding(EdgeInsets(top: 11, leading: 25, bottom: 11, trailing: 11))
            .allowsHitTesting(false)
    }

    /// Gáy sách bên trái: tông sâu hơn, số tập ép nhũ, hai vạch nhũ.
    private func gay(_ s: Sach) -> some View {
        HStack(spacing: 0) {
            ZStack {
                LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0.28)],
                               startPoint: .leading, endPoint: .trailing)
                VStack(spacing: 5) {
                    Rectangle().fill(Self.nhu.opacity(0.55)).frame(width: 10, height: 0.8)
                    Text(s.vol)
                        .font(.system(size: 10, weight: .heavy, design: .serif).monospacedDigit())
                        .foregroundColor(Self.nhuSang)
                    Rectangle().fill(Self.nhu.opacity(0.55)).frame(width: 10, height: 0.8)
                    Spacer(minLength: 0)
                }
                .padding(.top, 12)
            }
            .frame(width: 18)
            Spacer(minLength: 0)
        }
        .allowsHitTesting(false)
    }

    private func noiDungBia(_ s: Sach) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CUONGTHAI")
                .font(.system(size: 7, weight: .semibold))
                .kerning(1.4)
                .foregroundColor(Self.nhu.opacity(0.75))

            // Dấu ấn giữa bìa: logo hãng vẽ từ path SVG, tô bằng gradient nhũ
            // — đúng vai trò của `-webkit-mask` bên web.
            Spacer(minLength: 0)
            HStack {
                Spacer(minLength: 0)
                if let d = LogoSach.choTap(s.vol) {
                    HinhSVG(d: d)
                        .fill(LinearGradient(colors: [Self.nhuSang, Self.nhu],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 52, height: 52)
                        .shadow(color: .black.opacity(0.4), radius: 0, x: 0, y: 1)
                } else {
                    // Bốn tập là khái niệm thuần, web cũng không có logo hãng.
                    Image(systemName: "book.closed")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(LinearGradient(colors: [Self.nhuSang, Self.nhu],
                                                        startPoint: .top, endPoint: .bottom))
                }
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)

            Text(s.tua)
                .font(.system(size: 13.5, weight: .bold, design: .serif))
                .foregroundColor(Self.nhuSang)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.4), radius: 0, x: 0, y: 1)
            Divider().overlay(.white.opacity(0.14)).padding(.top, 7)
            Text("VOL \(s.vol) · \(s.soTu) từ")
                .font(.system(size: 9))
                .kerning(0.4)
                .foregroundColor(.white.opacity(0.6))
                .padding(.top, 6)
        }
        .padding(EdgeInsets(top: 18, leading: 32, bottom: 16, trailing: 16))
    }
}

// MARK: - Lối vào từ tab Học

struct SachEntryCard: View {
    var body: some View {
        NavigationLink { ThuVienSachView() } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 22))
                    .foregroundColor(AppColors.onPrimary)
                    .frame(width: 46, height: 46)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: 0x8A5A14), Color(hex: 0xC08A2E)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Thư viện sách")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("25 tập · 412 chương · song ngữ Anh–Việt")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(Spacing.md)
            .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(AppColors.backgroundCard))
        }
        .buttonStyle(.plain)
    }
}
