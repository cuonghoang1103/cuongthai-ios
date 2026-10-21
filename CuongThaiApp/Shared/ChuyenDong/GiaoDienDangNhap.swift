import SwiftUI

// MARK: - KHUNG ĐĂNG NHẬP DÙNG CHUNG (app CuongThai + app CT Work) — 21/10/2026
//
// Bố cục kiểu "hero + tấm trắng trượt lên": phần minh hoạ thương hiệu ở ~35% trên, tấm bo góc chứa form trượt
// lên khi mở màn. Tệp này CHỈ là vỏ + thành phần (ô nhập, nút viên thuốc, ô tích, lớp "đang đăng nhập") — chữ do
// từng app truyền vào ĐÃ DỊCH SẴN (CT Work: String Catalog; app chính: `T(...)`), nên ở đây mọi `Text` nhận `String`.
// Logic đăng nhập (gọi API, Apple/Google, xác thực email) nằm nguyên ở màn của từng app — vỏ này không đụng tới.
//
// Tránh bàn phím (iPhone SE tới iPad):
//   · Mọi thứ nằm trong MỘT ScrollView giữ vùng an toàn của bàn phím ⇒ hệ thống tự chừa chỗ.
//   · Đang gõ ⇒ hero thu nhỏ (tiết kiệm ~100pt trên SE) và cuộn ô đang gõ vào giữa (`cuonToi`).
//   · Màn rộng (iPad) ⇒ tấm form tối đa 520pt, căn giữa.

struct BoCucDangNhap<Hero: View, Tam: View, LopCho: View>: View {
    /// Nền vùng hero (dải màu thương hiệu).
    let nenHero: AnyShapeStyle
    /// Có ô nào đang gõ ⇒ thu hero.
    let dangGo: Bool
    /// Id của ô đang gõ (đặt `.id(...)` trên ô) ⇒ cuộn tới.
    let cuonToi: AnyHashable?
    /// Đang gửi đăng nhập ⇒ làm mờ nền + hiện lớp chờ.
    let dangDangNhap: Bool
    /// Tăng mỗi lần lỗi ⇒ tấm form lắc một lượt.
    let lanLac: Int
    @ViewBuilder let hero: (_ gon: Bool) -> Hero
    @ViewBuilder let tam: () -> Tam
    @ViewBuilder let lopCho: () -> LopCho

    @Environment(\.accessibilityReduceMotion) private var giam
    @Environment(\.colorScheme) private var cheDo
    @State private var daTruot = false
    @State private var lac: CGFloat = 0
    @ObservedObject private var khoiDong = KhoiDongChung.shared

    static var mauTam: Color {
        Color.theoCheDo(sang: .white, toi: Color(red: 0.09, green: 0.09, blue: 0.11))
    }

    var body: some View {
        GeometryReader { g in
            let caoMan = g.size.height + g.safeAreaInsets.top
            let caoHero = dangGo ? max(120, min(170, caoMan * 0.2)) : max(170, min(360, caoMan * 0.36))
            ZStack(alignment: .top) {
                Rectangle().fill(nenHero).ignoresSafeArea()
                // Nửa dưới màu tấm ⇒ kéo quá đáy không lộ dải màu hero.
                VStack { Spacer(); Self.mauTam.frame(height: g.size.height * 0.5) }.ignoresSafeArea()

                ScrollViewReader { cuon in
                    ScrollView {
                        VStack(spacing: 0) {
                            hero(dangGo)
                                .id("boCucDangNhap.dau")
                                .padding(.top, g.safeAreaInsets.top)
                                .frame(height: caoHero + g.safeAreaInsets.top)
                                .frame(maxWidth: .infinity)
                                .clipped()
                            VStack(spacing: 0) {
                                tam()
                                    .frame(maxWidth: 520)
                                    .padding(.horizontal, 24)
                                    .padding(.top, 26)
                                    .padding(.bottom, 24 + g.safeAreaInsets.bottom)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .background(
                                UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous)
                                    .fill(Self.mauTam)
                                    .shadow(color: .black.opacity(cheDo == .dark ? 0.4 : 0.08), radius: 18, y: -4)
                            )
                            .modifier(RungLac(lan: lac))
                            .offset(y: daTruot || giam ? 0 : g.size.height * 0.6)
                            .opacity(daTruot ? 1 : 0)
                        }
                        .frame(minHeight: g.size.height + g.safeAreaInsets.top + g.safeAreaInsets.bottom)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .scrollBounceBehavior(.basedOnSize)
                    .ignoresSafeArea(.container, edges: [.top, .bottom])
                    .onChange(of: cuonToi) { _, moi in
                        // Hết gõ (bàn phím xuống, đang gửi…) ⇒ trả về đầu: hero nở lại, không để màn lưng chừng.
                        guard let moi else {
                            withAnimation(.easeOut(duration: 0.3)) { cuon.scrollTo("boCucDangNhap.dau", anchor: .top) }
                            return
                        }
                        // Đợi bàn phím lên xong (~0,3 s) rồi mới cuộn — cuộn sớm thì vùng nhìn thấy còn tính cả chỗ bàn phím.
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 320_000_000)
                            withAnimation(.easeOut(duration: 0.25)) { cuon.scrollTo(moi, anchor: .center) }
                        }
                    }
                }
                .blur(radius: dangDangNhap ? 9 : 0)
                .allowsHitTesting(!dangDangNhap)

                if dangDangNhap {
                    ZStack {
                        Color.black.opacity(cheDo == .dark ? 0.35 : 0.12).ignoresSafeArea()
                        lopCho()
                    }
                    .transition(.opacity)
                    .zIndex(2)
                }
            }
            .animation(giam ? .easeOut(duration: 0.15) : .spring(response: 0.38, dampingFraction: 0.86), value: dangGo)
            .animation(.easeInOut(duration: 0.25), value: dangDangNhap)
        }
        // Tấm trượt lên khi màn đã LỘ RA: mở thẳng ⇒ ngay; sau màn khởi động ⇒ đúng lúc nó bắt đầu thoát.
        .onAppear { if !khoiDong.dangChieu { truotLen() } }
        .onChange(of: khoiDong.dangChieu) { _, che in if !che { truotLen() } }
        .onChange(of: lanLac) { _, _ in
            guard !giam else { return }
            lac = 0
            withAnimation(.linear(duration: 0.42)) { lac = 1 }
        }
    }
}

extension BoCucDangNhap {
    fileprivate func truotLen() {
        guard !daTruot else { return }
        withAnimation(giam ? .easeOut(duration: 0.25) : .spring(response: 0.62, dampingFraction: 0.84).delay(0.05)) {
            daTruot = true
        }
    }
}

// MARK: Ô nhập với viền tập trung chạy quanh

struct ODangNhap<F: Hashable>: View {
    let bieuTuong: String
    let goiY: String
    @Binding var chu: String
    var an = false
    let tapTrung: FocusState<F?>.Binding
    let gia: F
    var mau: Color = AppColors.primary
    var nhanHien = "Show password"
    var nhanAn = "Hide password"
    var maDinhDanh: String?

    @State private var hienMatKhau = false
    @Environment(\.accessibilityReduceMotion) private var giam
    @Environment(\.colorScheme) private var cheDo

    private var dangGo: Bool { tapTrung.wrappedValue == gia }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: bieuTuong)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(dangGo ? mau : AppColors.textTertiary)
                .frame(width: 22)
                .accessibilityHidden(true)
            Group {
                if an && !hienMatKhau {
                    SecureField(goiY, text: $chu)
                } else {
                    TextField(goiY, text: $chu)
                }
            }
            .font(.system(size: 16))
            .foregroundColor(AppColors.textPrimary)
            .focused(tapTrung, equals: gia)
            .accessibilityIdentifier(maDinhDanh ?? "")
            if an {
                Button {
                    hienMatKhau.toggle()
                    RungNhe.cham()
                    // Đổi SecureField ⇄ TextField làm mất tiêu điểm — trả lại ngay.
                    tapTrung.wrappedValue = gia
                } label: {
                    Image(systemName: hienMatKhau ? "eye.slash" : "eye")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hienMatKhau ? nhanAn : nhanHien)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 54)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cheDo == .dark ? Color.white.opacity(0.06) : Color(red: 0.96, green: 0.965, blue: 0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppColors.border, lineWidth: 1)
        )
        // Viền thương hiệu CHẠY QUANH ô lúc vừa chạm vào (trim 0→1), kèm quầng nhẹ.
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .inset(by: 0.8)
                .trim(from: 0, to: dangGo ? 1 : 0)
                .stroke(mau, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                .shadow(color: mau.opacity(dangGo ? 0.35 : 0), radius: 6)
                .animation(giam ? .easeOut(duration: 0.12) : .easeOut(duration: dangGo ? 0.38 : 0.18), value: dangGo)
        )
        .contentShape(Rectangle())
        .onTapGesture { tapTrung.wrappedValue = gia }
    }
}

// MARK: Nút viên thuốc

struct NutVienThuoc<Nen: ShapeStyle>: View {
    let nhan: String
    let nen: Nen
    var dangChay = false
    var bat = true
    var maDinhDanh: String?
    let hanhDong: () -> Void

    var body: some View {
        Button(action: hanhDong) {
            ZStack {
                Text(nhan).opacity(dangChay ? 0 : 1)
                if dangChay { ProgressView().tint(.white) }
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Capsule().fill(nen))
            .opacity(bat ? 1 : 0.5)
            .contentShape(Capsule())
        }
        .buttonStyle(KieuNutNhan(co: 0.97))
        .disabled(!bat || dangChay)
        .accessibilityIdentifier(maDinhDanh ?? "")
    }
}

// MARK: Ô tích

struct OTich: View {
    let nhan: String
    @Binding var bat: Bool
    var mau: Color = AppColors.primary

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) { bat.toggle() }
            RungNhe.cham()
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(bat ? mau : AppColors.textTertiary, lineWidth: 1.6)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(bat ? mau : .clear))
                        .frame(width: 20, height: 20)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.white)
                        .scaleEffect(bat ? 1 : 0.2)
                        .opacity(bat ? 1 : 0)
                }
                Text(nhan).font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                    .lineLimit(2).minimumScaleFactor(0.85)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(bat ? .isSelected : [])
    }
}

// MARK: Lớp "Đang đăng nhập…"

struct LopDangDangNhap<LinhVat: View, Mau: ShapeStyle>: View {
    let chu: String
    let mau: Mau
    @ViewBuilder let linhVat: () -> LinhVat

    var body: some View {
        VStack(spacing: 18) {
            linhVat()
            Text(chu)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            ThanhTienDoVoHan(mau: mau, cao: 7)
                .frame(width: 200)
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.12), radius: 24, y: 10)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(chu)
        .accessibilityIdentifier("dangNhap.dangCho")
    }
}

// MARK: Chip nổi lơ lửng trong hero

/// Lắc lư lên xuống nhẹ — hoạt hình lặp của Core Animation (KHÔNG dựng lại view mỗi khung hình: linh vật vẽ bằng
/// Canvas có bóng, dựng lại 60 lần/giây là phí). Giảm chuyển động ⇒ đứng yên.
struct NoiLoLung: ViewModifier {
    var bienDo: CGFloat = 6
    var chuKy: Double = 3.2
    var lech: Double = 0
    @Environment(\.accessibilityReduceMotion) private var giam
    @State private var len = false

    func body(content: Content) -> some View {
        content
            .offset(y: giam ? 0 : (len ? -bienDo : bienDo))
            .onAppear {
                guard !giam else { return }
                withAnimation(.easeInOut(duration: chuKy / 2).repeatForever(autoreverses: true).delay(lech * chuKy / 2)) {
                    len = true
                }
            }
    }
}

extension View {
    func noiLoLung(bienDo: CGFloat = 6, chuKy: Double = 3.2, lech: Double = 0) -> some View {
        modifier(NoiLoLung(bienDo: bienDo, chuKy: chuKy, lech: lech))
    }
}

/// Chip trắng bo tròn có bóng — "thẻ việc", "đã xong", "+20 EXP"…
struct ChipNoi: View {
    let bieuTuong: String
    let chu: String
    var mau: Color = AppColors.primary

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: bieuTuong).font(.system(size: 11, weight: .bold)).foregroundColor(mau)
            Text(chu).font(.system(size: 12, weight: .semibold)).foregroundColor(Color(red: 0.12, green: 0.13, blue: 0.2))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.white.opacity(0.95)).shadow(color: .black.opacity(0.12), radius: 8, y: 4))
        .accessibilityHidden(true)
    }
}
