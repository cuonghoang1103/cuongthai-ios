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

    static var dangHien: Bool {
        UserDefaults.standard.object(forKey: khoaHien) as? Bool ?? true
    }

    /// Chỉ iPad. Xem ghi chú đầu tệp.
    static var chayDuoc: Bool { UIDevice.current.userInterfaceIdiom == .pad }
}

struct TroLyTrang: View {
    let trang: TrangVo?
    let tenCuon: String

    @AppStorage(CaiDatTroLy.khoaHien) private var hien = true
    @AppStorage(CaiDatTroLy.khoaX) private var tiLeX = 0.93
    @AppStorage(CaiDatTroLy.khoaY) private var tiLeY = 0.78

    @State private var moKhung = false
    @State private var choChamDon: Task<Void, Never>?
    @State private var soCham = 0
    @State private var moChatDayDu = false

    private let canhNut: CGFloat = 62

    var body: some View {
        if CaiDatTroLy.chayDuoc && hien {
            GeometryReader { g in
                let tam = tamRobot(trong: g.size)

                ZStack(alignment: .topLeading) {
                    if moKhung {
                        KhungHoiTrang(trang: trang, tenCuon: tenCuon,
                                      dong: { moKhung = false },
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
        .onChange(of: anhChon) { _, moi in
            guard !moi.isEmpty else { return }
            Task { await napAnh(moi) }
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
#endif
