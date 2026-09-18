#if os(iOS)
import PencilKit
import PhotosUI
import SwiftUI

// ════════════════════════════════════════════════════════════════
// TRỢ LÝ TRANG — con robot nổi trong vở
//
// Bản iPad của con robot nổi trên app desktop (`desktop/src/renderer/robot.tsx`),
// nhưng KHÔNG bê nguyên: ở đó robot là một CỬA SỔ riêng nổi trên cả hệ điều
// hành, còn ở đây nó là một lớp phủ trong màn viết. Điều đó đổi hai thứ:
//
//  · Nó biết ĐANG ở trang nào. Hỏi "giải bài này đi" là đủ — không phải chụp
//    màn hình rồi kéo thả vào. Chính chỗ này mới là lý do làm riêng cho vở.
//  · Nó không cần đa cửa sổ, nên không cần IPC, không cần hút mép màn hình.
//
// ⚠️ CHỈ iPad. Người dùng nói thẳng 18/09/2026: "iphone nhỏ quá thì thôi".
// Khung hỏi rộng 360pt cộng bàn phím thì trên iPhone nó che gần hết trang
// giấy — mà trang giấy mới là thứ người ta đang nhìn.
//
// Thao tác:
//   · chạm      → mở/đóng khung hỏi
//   · chạm đúp  → mở CuongMini đầy đủ
//   · giữ       → menu: ẩn trợ lý, đổi mép, nhích lên/xuống
//
// Bản desktop cho KÉO con robot; ở đây thì không — xem ghi chú ở `nutRobot`.
// ════════════════════════════════════════════════════════════════

enum CaiDatTroLy {
    static let khoaHien = "vo.troly.hien"
    /// Chỗ đứng lưu theo TỈ LỆ khung (0…1), không theo điểm ảnh: xoay máy hay
    /// chia đôi màn hình thì điểm ảnh cũ trỏ ra ngoài màn, còn tỉ lệ thì không.
    static let khoaX = "vo.troly.x"
    static let khoaY = "vo.troly.y"
    /// Bóp Apple Pencil → khoanh vùng hỏi AI.
    ///
    /// ⚠️ Khoá ĐỔI TÊN (thêm `.v2`) và mặc định BẬT. Bản đầu mặc định tắt và
    /// bắt tự tìm công tắc trong menu ⋯; người dùng bật rồi mà log vẫn đọc
    /// `false` — cái bật không giữ được, và họ phải quay lại báo hai lần.
    /// Đổi tên khoá là cách duy nhất để giá trị `false` cũ trên máy không đè
    /// mất mặc định mới.
    static let khoaBopBut = "vo.troly.bopbut.v2"

    static var dangHien: Bool {
        UserDefaults.standard.object(forKey: khoaHien) as? Bool ?? true
    }

    /// Chỉ iPad. Xem ghi chú đầu tệp.
    static var chayDuoc: Bool { UIDevice.current.userInterfaceIdiom == .pad }
}

struct TroLyTrang: View {
    let trang: TrangVo?
    let tenCuon: String
    /// Tăng một nấc = xin mở khung hỏi từ bên ngoài.
    var xinMo: Int = 0
    /// Tăng một nấc = mở khung RỒI VÀO THẲNG khoanh vùng trên ẢNH CẢ TRANG.
    var xinKhoanh: Int = 0
    /// Vùng vừa khoanh THẲNG TRÊN TRANG, do màn viết cắt và đưa sang.
    var vungNgoai: Binding<AnhVungCat?> = .constant(nil)

    @AppStorage(CaiDatTroLy.khoaHien) private var hien = true
    @AppStorage(CaiDatTroLy.khoaX) private var tiLeX = 0.93
    @AppStorage(CaiDatTroLy.khoaY) private var tiLeY = 0.78

    @State private var moKhung = false
    @State private var choChamDon: Task<Void, Never>?
    @State private var soCham = 0
    @State private var moChatDayDu = false
    @State private var khoanhNgay = 0

    private let canhNut: CGFloat = 62

    var body: some View {
        if CaiDatTroLy.chayDuoc && hien {
            GeometryReader { g in
                let tam = tamRobot(trong: g.size)

                ZStack(alignment: .topLeading) {
                    if moKhung {
                        KhungHoiTrang(trang: trang, tenCuon: tenCuon,
                                      khoanhNgay: khoanhNgay,
                                      vungNgoai: vungNgoai,
                                      dong: { moKhung = false; khoanhNgay = 0 },
                                      moDayDu: { moKhung = false; moChatDayDu = true })
                            .frame(width: rongKhung(g.size), height: caoKhung(g.size))
                            .position(viTriKhung(quanh: tam, trong: g.size))
                            .transition(.scale(scale: 0.9, anchor: .bottomTrailing)
                                .combined(with: .opacity))
                    }

                    nutRobot(trong: g.size)
                        .position(tam)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.82), value: moKhung)
            }
            .ignoresSafeArea(.keyboard)
            .onChange(of: vungNgoai.wrappedValue?.id) { _, moi in
                guard moi != nil else { return }
                if !moKhung {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { moKhung = true }
                }
            }
            .onChange(of: xinKhoanh) { _, moi in
                NhatKy.vo.info("trợ lý: xin KHOANH #\(moi)")
                khoanhNgay = moi
                if !moKhung {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { moKhung = true }
                }
            }
            .onChange(of: xinMo) { _, moi in
                NhatKy.vo.info("trợ lý: nhận xin mở #\(moi), moKhung = \(moKhung)")
                guard !moKhung else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { moKhung = true }
            }
            .sheet(isPresented: $moChatDayDu) {
                AIChatView(cauMoDau: cauMoDauChoChat, bacBanDau: .pro)
            }
        }
    }

    /// Tâm con robot, đã kẹp trong khung.
    ///
    /// ⚠️ Tách ra khỏi `body` vì trình biên dịch KHÔNG suy được kiểu của cả
    /// biểu thức khi nó nằm trong `GeometryReader` ("unable to type-check this
    /// expression in reasonable time"). Đây là lỗi BUILD, không phải lỗi chạy.
    private func tamRobot(trong kho: CGSize) -> CGPoint {
        let le: CGFloat = canhNut / 2 + 6
        let x: CGFloat = kho.width * tiLeX
        let y: CGFloat = kho.height * tiLeY
        let xKep: CGFloat = min(max(x, le), max(kho.width - le, le))
        let yKep: CGFloat = min(max(y, le), max(kho.height - le, le))
        return CGPoint(x: xKep, y: yKep)
    }

    // ── Con robot ───────────────────────────────────────────────
    private func nutRobot(trong _: CGSize) -> some View {
        RobotChaoMung(gon: true)
            .frame(width: canhNut, height: canhNut)
            .background(
                Circle()
                    .fill(AppColors.backgroundCard)
                    .shadow(color: .black.opacity(0.22), radius: 10, y: 4),
            )
            .overlay(
                Circle().stroke(moKhung ? AppColors.primary.opacity(0.7)
                                        : AppColors.border, lineWidth: moKhung ? 2 : 1),
            )
            .contentShape(Circle())
            // ⚠️ KHÔNG cho KÉO con robot. Bản desktop kéo được vì nó là một
            // CỬA SỔ của hệ điều hành; ở đây robot nổi trên `PKCanvasView`,
            // và cú kéo về tay SwiftUI luôn CỤT — đo bốn lần trên máy ảo, kéo
            // hẳn 760pt sang trái mà `translation` lúc thả chỉ còn vài chục,
            // nên robot không bao giờ lật nổi sang mép kia. Thử cả
            // `.position` lẫn `.offset`, cả gộp lẫn tách cử chỉ chạm: vẫn thế.
            // Khung vẽ nằm dưới nuốt mất quãng giữa.
            //
            // Nên đổi chỗ bằng LỆNH RÕ RÀNG trong menu giữ — hai góc, một cú
            // chạm, lần nào cũng đúng. Một nút bấm là chạy được ăn đứt một cử
            // chỉ kéo chạy được một nửa.
            .onTapGesture(count: 2) {
                choChamDon?.cancel(); choChamDon = nil
                soCham = 0
                moKhung = false
                moChatDayDu = true
                Haptics.cham()
            }
            .onTapGesture { demCham() }
            .contextMenu {
                Button {
                    moKhung = false
                    hien = false
                } label: {
                    Label(T("Ẩn trợ lý"), systemImage: "eye.slash")
                }
                Button { moChatDayDu = true } label: {
                    Label(T("Mở CuongMini đầy đủ"), systemImage: "arrow.up.left.and.arrow.down.right")
                }
                Divider()
                Button { doiBen() } label: {
                    Label(tiLeX > 0.5 ? T("Đổi sang mép trái") : T("Đổi sang mép phải"),
                          systemImage: tiLeX > 0.5 ? "arrow.left.to.line" : "arrow.right.to.line")
                }
                Button { doiCao(-0.18) } label: {
                    Label(T("Đưa lên trên"), systemImage: "arrow.up")
                }
                .disabled(tiLeY <= 0.13)
                Button { doiCao(0.18) } label: {
                    Label(T("Đưa xuống dưới"), systemImage: "arrow.down")
                }
                .disabled(tiLeY >= 0.89)
            }
            .accessibilityLabel(T("Trợ lý trang"))
            .accessibilityHint(T("Chạm để hỏi về trang này, chạm đúp để mở CuongMini, giữ để đổi chỗ"))
    }

    /// Đếm cú chạm để phân biệt chạm đơn với chạm đúp.
    ///
    /// Chạm đơn phải ĐỢI xem có cú thứ hai không, nếu không mỗi cú chạm đúp
    /// sẽ mở khung hỏi rồi mới nhảy sang màn chat đầy đủ — người dùng thấy
    /// một cái nháy vô nghĩa. 260ms là ngưỡng nhấp đúp quen thuộc, lấy đúng
    /// con số bản desktop đã chốt.
    private func demCham() {
        soCham += 1
        choChamDon?.cancel()
        choChamDon = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            guard !Task.isCancelled else { return }
            if soCham >= 2 {
                moKhung = false
                moChatDayDu = true
            } else {
                moKhung.toggle()
            }
            soCham = 0
            Haptics.cham()
        }
    }

    /// Đổi mép đứng của robot. Hai góc, không có trạng thái lửng ở giữa.
    private func doiBen() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            tiLeX = tiLeX > 0.5 ? 0.07 : 0.93
        }
        Haptics.cham()
    }

    /// Nhích robot lên hoặc xuống một nấc.
    private func doiCao(_ buoc: Double) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            tiLeY = min(max(tiLeY + buoc, 0.12), 0.9)
        }
        Haptics.cham()
    }

    // ── Chỗ đặt khung hỏi ───────────────────────────────────────
    private func rongKhung(_ kho: CGSize) -> CGFloat { min(380, kho.width - 32) }
    private func caoKhung(_ kho: CGSize) -> CGFloat { min(520, kho.height - 32) }

    private func viTriKhung(quanh tam: CGPoint, trong kho: CGSize) -> CGPoint {
        let w = rongKhung(kho), h = caoKhung(kho)
        // Mở về phía TRONG màn: robot dính mép phải thì khung nở sang trái.
        let x = tam.x > kho.width / 2 ? tam.x - w / 2 - canhNut / 2
                                      : tam.x + w / 2 + canhNut / 2
        let y = tam.y - h / 2 - canhNut / 2
        return CGPoint(x: min(max(x, w / 2 + 8), kho.width - w / 2 - 8),
                       y: min(max(y, h / 2 + 8), kho.height - h / 2 - 8))
    }

    private var cauMoDauChoChat: String? {
        guard let t = trang else { return nil }
        return "Mình đang viết trang \(t.thuTu + 1) trong vở “\(tenCuon)”. "
    }
}

// MARK: - Khung hỏi

struct KhungHoiTrang: View {
    let trang: TrangVo?
    let tenCuon: String
    /// Khác 0 = vào màn là mở khoanh vùng ngay.
    var khoanhNgay: Int = 0
    /// Vùng khoanh thẳng trên trang do màn viết đưa sang.
    var vungNgoai: Binding<AnhVungCat?> = .constant(nil)
    let dong: () -> Void
    let moDayDu: () -> Void

    @StateObject private var vm = AIChatViewModel()
    @StateObject private var mayDoc = MayDoc()
    @StateObject private var ghiAm = GhiAmThoai()
    @State private var cauHoi = ""
    @State private var dinhKem: [DinhKemAI] = []
    @State private var anhChon: [PhotosPickerItem] = []
    @State private var dangDungAnhTrang = false
    @State private var dangNhanDang = false
    @State private var anhDeKhoanh: AnhKhoanh?
    /// Vùng vừa cắt, đang chờ người dùng chọn hỏi gì.
    @State private var vungChoHoi: DinhKemAI?
    @FocusState private var dangGo: Bool

    /// Ba câu hỏi hay dùng nhất khi đang ngồi học — bấm một cái là gửi luôn
    /// KÈM ảnh trang, không phải gõ rồi còn nhớ đính ảnh.
    private static let goiY: [(String, String, String)] = [
        ("Giải bài trong trang này", "function", "Giải giúp mình bài trong trang này, trình bày từng bước."),
        ("Chấm bài mình viết", "checkmark.seal", "Xem bài mình viết trong trang này có sai chỗ nào không, sai thì chỉ ra và sửa."),
        ("Giảng lại trang này", "lightbulb", "Giảng lại nội dung trang này cho mình theo cách dễ hiểu nhất."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            thanhDau
            Divider()
            noiDung
            Divider()
            bangBaoLoi
            if !dinhKem.isEmpty { dayDinhKem }
            oNhap
        }
        .background(AppColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .stroke(AppColors.border, lineWidth: 1),
        )
        .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
        // ⚠️ `.task(id:)` chứ KHÔNG phải `.onChange`. Khung hỏi chỉ được dựng
        // SAU khi vùng đã cắt xong (cắt xong mới mở khung), nên `onChange`
        // không bao giờ thấy "thay đổi" — nó ra đời khi giá trị đã nằm sẵn ở
        // đó. Triệu chứng: khoanh xong khung mở ra nhưng bảng chọn câu hỏi
        // không hiện. `.task(id:)` chạy cả lúc XUẤT HIỆN lẫn lúc đổi.
        .task(id: vungNgoai.wrappedValue?.id) {
            guard let v = vungNgoai.wrappedValue else { return }
            vungChoHoi = v.anh
            vungNgoai.wrappedValue = nil
        }
        .task(id: khoanhNgay) {
            guard khoanhNgay != 0, anhDeKhoanh == nil else { return }
            await moKhoanhVung()
        }
        .onChange(of: anhChon) { _, moi in
            guard !moi.isEmpty else { return }
            Task { await napAnh(moi) }
        }
        .sheet(item: $anhDeKhoanh) { muc in
            KhoanhVungView(anh: muc.anh) { cat in
                vungChoHoi = DinhKemAI(ten: "vung-\(Int(Date().timeIntervalSince1970)).jpg",
                                       mime: "image/jpeg", duLieu: cat)
                Haptics.cham()
            }
        }
        // Khoanh xong là hỏi được NGAY bằng một chạm. Đính vào ô nhập rồi bắt
        // gõ câu hỏi là bắt người đang cầm bút giữa giờ học đi gõ chữ.
        .confirmationDialog(T("Hỏi gì về vùng này?"), isPresented: Binding(
            get: { vungChoHoi != nil },
            set: { if !$0 { vungChoHoi = nil } }), titleVisibility: .visible) {
            ForEach(HoiVung.allCases) { h in
                Button(h.nhan) { hoiVeVung(h) }
            }
            Button(T("Chỉ đính vào ô nhập")) {
                if let v = vungChoHoi {
                    namBacNeuCan()
                    dinhKem.removeAll { $0.ten.hasPrefix("vung-") }
                    dinhKem.append(v)
                }
                vungChoHoi = nil
            }
            Button(T("Huỷ"), role: .cancel) { vungChoHoi = nil }
        }
    }

    // ── Đầu khung ───────────────────────────────────────────────
    private var thanhDau: some View {
        HStack(spacing: Spacing.sm) {
            RobotChaoMung(gon: true).frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 0) {
                Text(T("Trợ lý trang"))
                    .font(Font.bodyMedium.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                if let t = trang {
                    Text("\(tenCuon) · \(T("trang")) \(t.thuTu + 1)")
                        .font(.caption2)
                        .foregroundStyle(AppColors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: Spacing.xs)

            Menu {
                Picker(T("Bậc AI"), selection: $vm.bac) {
                    ForEach(BacAI.allCases) { b in
                        Label(b.ten, systemImage: b.bieuTuong).tag(b)
                    }
                }
                Divider()
                Button { vm.hoiMoi() } label: {
                    Label(T("Cuộc mới"), systemImage: "square.and.pencil")
                }
                Button(action: moDayDu) {
                    Label(T("Mở CuongMini đầy đủ"), systemImage: "arrow.up.left.and.arrow.down.right")
                }
            } label: {
                Image(systemName: vm.bac.bieuTuong)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(AppColors.primary.opacity(0.14)))
            }

            Button(action: dong) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(T("Đóng"))
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    // ── Thân khung ──────────────────────────────────────────────
    @ViewBuilder
    private var noiDung: some View {
        if vm.tin.isEmpty && !vm.dangTraLoi {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(T("Hỏi gì về trang này?"))
                        .font(.caption)
                        .foregroundStyle(AppColors.textTertiary)
                    ForEach(Self.goiY, id: \.0) { nhan, icon, cau in
                        Button {
                            Task { await guiKemTrang(cau) }
                        } label: {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: icon)
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppColors.primary)
                                    .frame(width: 26)
                                Text(T(nhan))
                                    .font(Font.bodyMedium)
                                    .foregroundStyle(AppColors.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(AppColors.backgroundCard))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(trang == nil || dangDungAnhTrang)
                    }
                    Text(T("Ba nút này tự gửi kèm ảnh trang bạn đang mở."))
                        .font(.caption2)
                        .foregroundStyle(AppColors.textTertiary)
                        .padding(.top, 2)
                }
                .padding(Spacing.md)
            }
        } else {
            ScrollViewReader { doc in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Spacing.sm) {
                        ForEach(vm.tin) { t in
                            BongBongAI(tin: t, mayDoc: mayDoc)
                                .id(t.id)
                        }
                        if let b = vm.buocHienTai, !b.isEmpty {
                            Text(b)
                                .font(.caption2)
                                .foregroundStyle(AppColors.textTertiary)
                        }
                    }
                    .padding(Spacing.md)
                }
                .onChange(of: vm.tin.last?.noiDung) { _, _ in
                    guard let id = vm.tin.last?.id else { return }
                    withAnimation(.easeOut(duration: 0.15)) { doc.scrollTo(id, anchor: .bottom) }
                }
            }
        }
    }

    // ── Báo lỗi ─────────────────────────────────────────────────
    //
    // ⚠️ Chỗ này KHÔNG phải trang trí. Máy chủ hạ bậc Pro → Mini **im lặng**
    // khi tài khoản chưa có Pro (`reason: 'pro_required'` trong
    // `ai.service.ts`), mà nhánh Mini thì VỨT ảnh đi. Người dùng bấm "Giải bài
    // trong trang này" và nhận đúng một câu: "bạn gửi lại nội dung bài tập
    // giúp mình" — ảnh đã gửi rồi, không ai nói là nó bị bỏ. Đo thật
    // 18/09/2026 trên tài khoản thử (không Pro).
    @ViewBuilder
    private var bangBaoLoi: some View {
        if canPro {
            dongBao(chu: T("Ảnh chỉ gửi được khi có gói Pro — bậc miễn phí bỏ ảnh đi mà không báo."),
                    icon: "crown", mau: AppColors.warning, dong: nil)
        } else if let e = vm.loi {
            dongBao(chu: e, icon: "exclamationmark.triangle", mau: AppColors.error,
                    dong: { vm.loi = nil })
        }
    }

    /// Bậc ĐÃ CHỌN đọc được ảnh, nhưng câu trả lời lại đến từ bậc Mini ⇒ máy
    /// chủ đã hạ bậc vì tài khoản chưa có Pro.
    private var canPro: Bool {
        guard vm.bac.nhanTep else { return false }
        return vm.tin.last { !$0.cuaNguoi }?.model == BacAI.mini.maModel
    }

    private func dongBao(chu: String, icon: String, mau: Color,
                         dong: (() -> Void)?) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon).font(.system(size: 12))
            Text(chu).font(.caption2).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let dong {
                Button(action: dong) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(mau)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(mau.opacity(0.12))
    }

    // ── Đính kèm ────────────────────────────────────────────────
    private var dayDinhKem: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(dinhKem) { d in
                    HStack(spacing: 4) {
                        Image(systemName: d.bieuTuong).font(.system(size: 11))
                        Text(d.ten).font(.caption2).lineLimit(1)
                        Button {
                            dinhKem.removeAll { $0.id == d.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(AppColors.backgroundTertiary))
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
        }
    }

    // ── Ô nhập ──────────────────────────────────────────────────
    private var oNhap: some View {
        HStack(spacing: Spacing.xs) {
            Button {
                Task { await themAnhTrang() }
            } label: {
                Image(systemName: dangDungAnhTrang ? "hourglass" : "doc.viewfinder")
            }
            .buttonStyle(.plain)
            .disabled(trang == nil || dangDungAnhTrang)
            .accessibilityLabel(T("Đính ảnh trang này"))

            Button {
                Task { await moKhoanhVung() }
            } label: {
                Image(systemName: "crop")
            }
            .buttonStyle(.plain)
            .disabled(trang == nil || dangDungAnhTrang)
            .accessibilityLabel(T("Khoanh một vùng để hỏi"))

            PhotosPicker(selection: $anhChon, maxSelectionCount: HanMucDinhKem.soAnh,
                         matching: .images) {
                Image(systemName: "photo")
            }
            .accessibilityLabel(T("Chọn ảnh"))

            TextField(T("Hỏi về trang này…"), text: $cauHoi, axis: .vertical)
                .textFieldStyle(.plain)
                .font(Font.bodyMedium)
                .lineLimit(1...4)
                .focused($dangGo)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(AppColors.backgroundCard))

            if cauHoi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && dinhKem.isEmpty {
                Image(systemName: dangNhanDang ? "waveform"
                                               : (ghiAm.dangGhi ? "mic.fill" : "mic"))
                    .foregroundStyle(ghiAm.dangGhi ? AppColors.error : AppColors.primary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
                    .gesture(
                        // GIỮ để nói, thả ra là nhận dạng — giống màn chat đầy
                        // đủ. Bấm-một-lần-để-bật thì đang viết bài dễ chạm
                        // nhầm và micro chạy ngầm không ai biết.
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                guard !ghiAm.dangGhi, !dangNhanDang else { return }
                                Haptics.cham()
                                Task { await ghiAm.batDau() }
                            }
                            .onEnded { _ in ketThucNoi() },
                    )
                    .disabled(dangNhanDang)
            } else {
                Button { gui() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppColors.primary)
                }
                .buttonStyle(.plain)
                .disabled(vm.dangTraLoi)
            }
        }
        .font(.system(size: 17))
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
    }

    // ── Việc ────────────────────────────────────────────────────
    private func gui() {
        let c = cauHoi.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !c.isEmpty || !dinhKem.isEmpty else { return }
        let anh = dinhKem.filter(\.laAnh).map(\.dataURL)
        let tep = dinhKem.filter { !$0.laAnh }
        cauHoi = ""
        dinhKem = []
        dangGo = false
        Haptics.cham()
        vm.gui(c, anh: anh, tep: tep.map(\.dataURL), tenTep: tep.map(\.ten))
    }

    /// Nút gợi ý: dựng ảnh trang rồi gửi luôn.
    private func guiKemTrang(_ cau: String) async {
        guard let anh = await anhTrangChoAI() else {
            vm.loi = "Chưa dựng được ảnh trang này."
            return
        }
        namBacNeuCan()
        Haptics.cham()
        vm.gui(cau + ghiChuTrang(), anh: [anh.dataURL])
    }

    /// Mở khung khoanh vùng trên ẢNH đã dựng của trang.
    ///
    /// ⚠️ Cố ý KHÔNG cho kéo khung chọn ngay trên trang giấy. `PKCanvasView`
    /// nằm dưới nuốt mất quãng giữa của cú kéo — đã trả giá cho chuyện này ở
    /// con robot nổi. Khoanh trên một tấm ảnh trong cửa sổ riêng thì không có
    /// gì tranh cử chỉ, và người dùng thấy đúng thứ sắp gửi đi.
    private func moKhoanhVung() async {
        guard let d = await anhTrangChoAI(), let anh = UIImage(data: d.duLieu) else {
            vm.loi = "Chưa dựng được ảnh trang này."
            return
        }
        anhDeKhoanh = AnhKhoanh(anh: anh)
    }

    /// Gửi luôn vùng vừa khoanh kèm câu hỏi đã chọn.
    private func hoiVeVung(_ h: HoiVung) {
        guard let v = vungChoHoi else { return }
        vungChoHoi = nil
        namBacNeuCan()
        Haptics.cham()
        vm.gui(h.cauHoi + ghiChuTrang(), anh: [v.dataURL])
    }

    private func themAnhTrang() async {
        guard let anh = await anhTrangChoAI() else {
            vm.loi = "Chưa dựng được ảnh trang này."
            return
        }
        namBacNeuCan()
        dinhKem.removeAll { $0.ten == anh.ten }
        dinhKem.append(anh)
        Haptics.cham()
    }

    /// Câu ngữ cảnh gắn thêm vào lời hỏi.
    ///
    /// Model nhìn được ảnh nhưng KHÔNG biết mình đang ở đâu trong vở. Thiếu
    /// câu này thì câu trả lời hay mở đầu bằng "bạn đang hỏi về ảnh nào?".
    private func ghiChuTrang() -> String {
        guard let t = trang else { return "" }
        var s = "\n\n(Ảnh kèm là trang \(t.thuTu + 1) trong vở “\(tenCuon)”"
        if let ch = t.tenChuong, !ch.isEmpty { s += ", chương “\(ch)”" }
        s += ". Mình viết tay trên iPad.)"
        return s
    }

    /// Bậc Mini KHÔNG đọc được ảnh (backend chỉ cho Pro/Max) — tự nâng, và
    /// nói ra. Gửi ảnh ở bậc Mini thì nó rơi vào hư không mà không báo gì.
    private func namBacNeuCan() {
        guard !vm.bac.nhanTep else { return }
        vm.bac = .pro
        vm.loi = "Đã chuyển sang CuongMini Pro — chỉ bậc Pro và Max mới đọc được ảnh."
    }

    private func napAnh(_ mucs: [PhotosPickerItem]) async {
        for muc in mucs.prefix(HanMucDinhKem.soAnh) {
            guard let d = try? await muc.loadTransferable(type: Data.self) else { continue }
            let nen = PlatformImage(data: d)?.jpegDataForUpload() ?? d
            namBacNeuCan()
            dinhKem.append(DinhKemAI(ten: "ảnh.jpg", mime: "image/jpeg", duLieu: nen))
        }
        anhChon = []
    }

    private func ketThucNoi() {
        guard let thu = ghiAm.dungLai() else { return }
        dangNhanDang = true
        Task {
            defer { dangNhanDang = false }
            do {
                if let chu = try await GiongNoiAI.chuTuGiong(thu.data) {
                    cauHoi = cauHoi.isEmpty ? chu : cauHoi + " " + chu
                } else {
                    vm.loi = "Chưa nghe rõ, thử nói lại gần micro hơn nhé."
                }
            } catch {
                vm.loi = "Không nhận dạng được giọng nói."
            }
        }
    }

    // ── Dựng ảnh trang ──────────────────────────────────────────
    /// Vẽ lại trang thành ẢNH THẬT để gửi cho model.
    ///
    /// ⚠️ KHÔNG dùng `KhoVo.anhNho`: ảnh thu nhỏ của dải trang vẽ ở tỉ lệ
    /// 0,25 — một trang A4 ra ~310px, chữ viết tay ở cỡ đó model đọc thành
    /// chữ khác. Ở đây dựng lại ở cạnh dài 1600px, đúng ngưỡng mà
    /// `jpegDataForUpload` dùng cho ảnh chụp.
    ///
    /// ⚠️ Phải vẽ CẢ NỀN (PDF/ảnh đã nhập) chứ không chỉ nét bút: người dùng
    /// viết đè lên đề bài chụp từ sách, gửi mỗi nét bút thì model nhận được
    /// phần trả lời mà không có câu hỏi.
    private func anhTrangChoAI() async -> DinhKemAI? {
        guard let t = trang else { return nil }
        dangDungAnhTrang = true
        defer { dangDungAnhTrang = false }

        // Đọc mọi thứ của `TrangVo` TRÊN luồng chính rồi mới rời đi — nó là
        // một `@Model` của SwiftData, đụng vào từ luồng khác là hành vi không
        // xác định.
        let kho = t.khoTrang
        let net = KhoVo.nap(t.id)
        let pdfTen = t.nenPdfTen
        let pdfTrang = t.nenPdfTrang
        let anhTen = t.nenAnhTen
        let soTrang = t.thuTu + 1

        let duLieu: Data? = await Task.detached(priority: .userInitiated) {
            let ty = min(1.0, 1600 / max(kho.width, kho.height))
            let khoVe = CGSize(width: kho.width * ty, height: kho.height * ty)
            let o = CGRect(origin: .zero, size: khoVe)
            let anh = UIGraphicsImageRenderer(size: khoVe).image { ctx in
                UIColor.white.setFill()
                ctx.fill(o)
                if let ten = pdfTen,
                   let nen = NenTrangView.veTrangPdf(ten: ten, trang: pdfTrang, kho: khoVe) {
                    nen.draw(in: o)
                } else if let ten = anhTen,
                          let d = try? Data(contentsOf: KhoVo.duongDanNen(ten)),
                          let nen = UIImage(data: d) {
                    nen.draw(in: o)
                }
                if !net.bounds.isEmpty {
                    net.image(from: CGRect(origin: .zero, size: kho), scale: ty).draw(in: o)
                }
            }
            return anh.jpegData(compressionQuality: 0.8)
        }.value

        guard let duLieu else { return nil }
        return DinhKemAI(ten: "trang-\(soTrang).jpg", mime: "image/jpeg", duLieu: duLieu)
    }
}
// MARK: - Khoanh một vùng để hỏi

/// Vùng vừa cắt từ màn hình, chuyển từ màn viết sang trợ lý.
struct AnhVungCat: Identifiable {
    let id = UUID()
    let anh: DinhKemAI
}

/// `UIImage` không `Identifiable`, mà `.sheet(item:)` thì cần.
struct AnhKhoanh: Identifiable {
    let id = UUID()
    let anh: UIImage
}

/// Kéo một khung chữ nhật trên ảnh trang, cắt đúng phần đó gửi cho AI.
///
/// Vì sao chỉ gửi một vùng: model đọc cả trang thì hay trả lời về bài KHÁC
/// trên cùng trang, và mỗi lượt cũng đắt hơn. Khoanh đúng bài đang vướng thì
/// câu trả lời trúng hơn hẳn.
struct KhoanhVungView: View {
    let anh: UIImage
    let xong: (Data) -> Void

    @Environment(\.dismiss) private var dong
    @State private var dau: CGPoint?
    @State private var cuoi: CGPoint?
    /// Bề rộng/cao thật của khung chứa. Ghi lại lúc vẽ vì `cat()` cần nó để
    /// đổi toạ độ mà không với tới `GeometryReader` được.
    @State private var khoKhung: CGSize = .zero

    private var vung: CGRect? {
        guard let a = dau, let b = cuoi else { return nil }
        let r = CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
                       width: abs(a.x - b.x), height: abs(a.y - b.y))
        // Khung bé quá thường là chạm nhầm, không phải ý định khoanh.
        return (r.width > 24 && r.height > 24) ? r : nil
    }

    var body: some View {
        NavigationStack {
            GeometryReader { g in
                let khung = khungAnh(trong: g.size)
                ZStack(alignment: .topLeading) {
                    Color.black.opacity(0.9).ignoresSafeArea()

                    Image(uiImage: anh)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: khung.width, height: khung.height)
                        .position(x: g.size.width / 2, y: g.size.height / 2)

                    if let v = vung {
                        Rectangle()
                            .stroke(AppColors.primary, lineWidth: 2)
                            .background(Rectangle().fill(AppColors.primary.opacity(0.18)))
                            .frame(width: v.width, height: v.height)
                            .position(x: v.midX, y: v.midY)
                            .allowsHitTesting(false)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { t in
                            if dau == nil { dau = t.startLocation }
                            cuoi = t.location
                        },
                )
                .onAppear { khoKhung = g.size }
                .onChange(of: g.size) { _, moi in
                    khoKhung = moi
                    // Xoay máy là khung đổi, khung chọn cũ trỏ sai chỗ.
                    dau = nil; cuoi = nil
                }
            }
            .navigationTitle(T("Khoanh vùng để hỏi"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Huỷ")) { dong() }
                }
                ToolbarItem(placement: .principal) {
                    Text(vung == nil ? T("Kéo để khoanh vùng cần hỏi") : T("Khoanh vùng để hỏi"))
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Dùng vùng này")) { cat() }
                        .fontWeight(.semibold)
                        .disabled(vung == nil)
                }
            }
        }
    }

    /// Kích thước ảnh sau khi vừa khung, để đổi toạ độ màn → toạ độ ảnh.
    private func khungAnh(trong kho: CGSize) -> CGSize {
        let ty = min(kho.width / max(anh.size.width, 1), kho.height / max(anh.size.height, 1))
        return CGSize(width: anh.size.width * ty, height: anh.size.height * ty)
    }

    private func cat() {
        guard let v = vung, khoKhung.width > 0 else { return }
        // Đổi từ toạ độ MÀN sang toạ độ ẢNH GỐC. Ảnh vẽ vừa khung và CĂN
        // GIỮA, nên phải trừ phần lề rồi mới nhân tỉ lệ — quên bước lề là
        // cắt lệch đúng bằng nửa khoảng trống hai bên.
        let khungAnhHT = khungAnh(trong: khoKhung)
        let leX = (khoKhung.width - khungAnhHT.width) / 2
        let leY = (khoKhung.height - khungAnhHT.height) / 2
        let ty = anh.size.width / max(khungAnhHT.width, 1)

        let x = max(0, (v.minX - leX) * ty)
        let y = max(0, (v.minY - leY) * ty)
        let r = CGRect(x: x, y: y,
                       width: min(v.width * ty, anh.size.width - x),
                       height: min(v.height * ty, anh.size.height - y))
        guard r.width > 8, r.height > 8,
              let cg = anh.cgImage?.cropping(to: r),
              let d = UIImage(cgImage: cg, scale: anh.scale, orientation: anh.imageOrientation)
                  .jpegData(compressionQuality: 0.85)
        else { return }
        xong(d)
        dong()
    }
}
// MARK: - Hỏi gì về vùng vừa khoanh

/// Các câu hỏi hay dùng nhất khi khoanh trúng một từ / một câu / một hình.
///
/// Vì sao là danh sách CỐ ĐỊNH chứ không bắt gõ: người dùng đang cầm bút
/// giữa giờ học, gõ một câu hỏi là bỏ mất mạch bài. Một chạm phải ra câu
/// trả lời.
enum HoiVung: String, CaseIterable, Identifiable {
    case nghia, doc, giang, laGi, dich, tuVung

    var id: String { rawValue }

    var nhan: String {
        switch self {
        case .nghia:  return T("Nghĩa là gì?")
        case .doc:    return T("Đọc thế nào?")
        case .giang:  return T("Giảng cho tôi phần này")
        case .laGi:   return T("Đây là gì?")
        case .dich:   return T("Dịch sang tiếng Việt")
        case .tuVung: return T("Tách từ vựng + ví dụ")
        }
    }

    var bieuTuong: String {
        switch self {
        case .nghia:  return "character.book.closed"
        case .doc:    return "speaker.wave.2"
        case .giang:  return "lightbulb"
        case .laGi:   return "questionmark.circle"
        case .dich:   return "character.bubble"
        case .tuVung: return "list.bullet.rectangle"
        }
    }

    /// Câu gửi lên model. Nói rõ "trong ảnh" vì model không biết bối cảnh.
    var cauHoi: String {
        switch self {
        case .nghia:
            return "Phần mình khoanh trong ảnh nghĩa là gì? Nếu là tiếng Nhật, cho cả cách đọc (hiragana + romaji) rồi mới tới nghĩa tiếng Việt. Ngắn gọn."
        case .doc:
            return "Phần mình khoanh trong ảnh đọc thế nào? Ghi hiragana, romaji, và tách từng âm tiết. Nếu có kanji thì nói rõ âm on/kun đang dùng."
        case .giang:
            return "Giảng cho mình phần được khoanh trong ảnh: ý chính, ngữ pháp dùng ở đây, và một ví dụ tương tự. Giảng như cho người mới học."
        case .laGi:
            return "Trong ảnh mình khoanh một vùng — đó là cái gì? Mô tả rồi giải thích ngắn gọn."
        case .dich:
            return "Dịch phần được khoanh trong ảnh sang tiếng Việt. Giữ nguyên bố cục dòng nếu có nhiều dòng."
        case .tuVung:
            return "Tách toàn bộ từ vựng trong vùng khoanh thành bảng: từ · cách đọc · nghĩa tiếng Việt. Mỗi từ thêm một câu ví dụ ngắn."
        }
    }
}
#endif
