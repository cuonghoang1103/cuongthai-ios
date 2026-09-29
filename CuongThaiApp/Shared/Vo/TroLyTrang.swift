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
//   · chạm      → mở/đóng khung hỏi — NGAY LẬP TỨC
//   · giữ       → menu: mở CuongMini đầy đủ, ẩn trợ lý, đổi mép, nhích lên/xuống
//
// ⚠️ 28/09/2026 người dùng: "ấn vào 1-2s sau nó mới mở ra". Thủ phạm là cú
// CHẠM ĐÚP: có `onTapGesture(count: 2)` thì SwiftUI bắt chạm đơn đợi xem có
// cú thứ hai không (~0,35s), rồi `demCham()` lại tự đợi thêm 260ms, rồi mới
// tới hoạt ảnh lò xo. Chạm đúp đã bỏ — "Mở CuongMini đầy đủ" nằm ở menu giữ
// và menu trong khung hỏi. Đừng thêm lại cử chỉ chạm đúp lên con robot.
//
// Bản desktop cho KÉO con robot; ở đây thì không — xem ghi chú ở `nutRobot`.
//
// 28/09/2026 LỘT XÁC giao diện (người dùng: "sơ xài và xấu quá"):
//   · robot nổi là một NÚT THƯƠNG HIỆU (tím, vòng sáng) có ba trạng thái đọc
//     được từ xa: thở nhẹ khi rảnh · vòng sáng chạy khi AI đang trả lời (kể
//     cả khi khung đóng) · chấm hồng khi có câu trả lời chưa xem;
//   · khung hỏi bằng kính dày, hai cỡ: NỔI GỌN cạnh robot và NEO CẠNH PHẢI
//     (trang vẫn viết được bên trái) — nhớ lựa chọn qua `khoaNeo`;
//   · thêm chế độ 🎨 Vẽ giúp (`VeBangNet.swift`).
// Avatar robot là `MatRobot` vẽ riêng ở cuối tệp, KHÔNG phải `RobotChaoMung`:
// bản gọn của cái kia có khung cố định 56×70, ép vào ô 30×30 là tràn ra ngoài
// — đúng cái avatar "bị cắt mép" trong ảnh người dùng gửi.
// ════════════════════════════════════════════════════════════════

enum CaiDatTroLy {
    static let khoaHien = "vo.troly.hien"
    /// Chỗ đứng lưu theo TỈ LỆ khung (0…1), không theo điểm ảnh: xoay máy hay
    /// chia đôi màn hình thì điểm ảnh cũ trỏ ra ngoài màn, còn tỉ lệ thì không.
    static let khoaX = "vo.troly.x"
    static let khoaY = "vo.troly.y"
    /// Khung hỏi neo cạnh phải (true) hay nổi gọn cạnh robot (false).
    static let khoaNeo = "vo.troly.neo"
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

/// Khung hỏi đang ở chế độ nào. Sống ở `TroLyTrang` để đóng–mở giữ nguyên.
enum CheDoTroLy: String { case hoi, ve }

struct TroLyTrang: View {
    let trang: TrangVo?
    let tenCuon: String
    /// Tăng một nấc = xin mở khung hỏi từ bên ngoài.
    var xinMo: Int = 0
    /// Tăng một nấc = mở khung RỒI VÀO THẲNG khoanh vùng trên ẢNH CẢ TRANG.
    var xinKhoanh: Int = 0
    /// Vùng vừa khoanh THẲNG TRÊN TRANG, do màn viết cắt và đưa sang.
    var vungNgoai: Binding<AnhVungCat?> = .constant(nil)
    /// Đặt hình AI vẽ lên trang. `nil` = màn viết chưa nối — nút "Vẽ lên
    /// trang" vẫn hiện nhưng báo "sắp có".
    var chenHinhVe: ((HinhVeAI) -> Void)? = nil
    /// Mở "✍️ AI viết lại trang" của màn viết. `nil` = không hiện thẻ.
    var vietLaiTrang: (() -> Void)? = nil

    @AppStorage(CaiDatTroLy.khoaHien) private var hien = true
    @AppStorage(CaiDatTroLy.khoaX) private var tiLeX = 0.93
    @AppStorage(CaiDatTroLy.khoaY) private var tiLeY = 0.78
    @AppStorage(CaiDatTroLy.khoaNeo) private var neoCanh = false

    @State private var moKhung = false
    @State private var moChatDayDu = false
    /// Cuộc trò chuyện sống ở ĐÂY chứ không trong khung hỏi: khung bị gỡ khỏi
    /// cây mỗi lần đóng, để `@StateObject` trong khung thì đóng–mở lại là mất
    /// sạch câu vừa hỏi, và lần mở nào cũng phải dựng lại từ đầu.
    @StateObject private var vm = AIChatViewModel()
    /// Cùng lý do với `vm`: một lượt vẽ chạy 30–90 giây, đóng khung giữa
    /// chừng mà mất luôn lượt đó là bắt người ta chờ lại từ đầu.
    @StateObject private var mayVe = MayVe()
    @State private var cheDo: CheDoTroLy = .hoi
    @State private var khoanhNgay = 0
    /// Có câu trả lời (hoặc hình vẽ) về trong lúc khung ĐÓNG — chấm báo trên robot.
    @State private var coMoi = false

    /// Vùng chạm của robot (≥ 44pt theo HIG). Phần hình nhìn thấy là 58.
    private let canhNut: CGFloat = 64
    private let loXo = Animation.spring(response: 0.34, dampingFraction: 0.86)

    var body: some View {
        if CaiDatTroLy.chayDuoc && hien {
            GeometryReader { g in
                let tam = tamRobot(trong: g.size)
                let khung = khungHoi(quanh: tam, trong: g.size)

                ZStack(alignment: .topLeading) {
                    if moKhung {
                        khungHoiView
                            .frame(width: khung.width, height: khung.height)
                            .position(x: khung.midX, y: khung.midY)
                            .transition(chuyenCanh(tam: tam, kho: g.size))
                    }

                    if !robotBiChe(tam: tam, khung: khung) {
                        nutRobot(trong: g.size)
                            .position(tam)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
                .animation(loXo, value: moKhung)
                .animation(loXo, value: neoCanh)
            }
            .ignoresSafeArea(.keyboard)
            .onChange(of: vungNgoai.wrappedValue?.id) { _, moi in
                guard moi != nil else { return }
                cheDo = .hoi
                if !moKhung {
                    withAnimation(loXo) { moKhung = true }
                }
            }
            .onChange(of: xinKhoanh) { _, moi in
                NhatKy.vo.info("trợ lý: xin KHOANH #\(moi)")
                khoanhNgay = moi
                cheDo = .hoi
                if !moKhung {
                    withAnimation(loXo) { moKhung = true }
                }
            }
            .onChange(of: xinMo) { _, moi in
                NhatKy.vo.info("trợ lý: nhận xin mở #\(moi), moKhung = \(moKhung)")
                guard !moKhung else { return }
                withAnimation(loXo) { moKhung = true }
            }
            // Trả lời xong / vẽ xong trong lúc khung đóng ⇒ chấm báo.
            .onChange(of: vm.dangTraLoi) { cu, moi in
                if cu && !moi && !moKhung { coMoi = true }
            }
            .onChange(of: mayVe.dangVe) { cu, moi in
                if cu && !moi && !moKhung { coMoi = true }
            }
            .onChange(of: moKhung) { _, mo in if mo { coMoi = false } }
            .moAIChat(dangMo: $moChatDayDu, cauMoDau: cauMoDauChoChat, bacBanDau: .pro)
            #if DEBUG
            .task { apDungBanThu() }
            #endif
        }
    }

    private var khungHoiView: some View {
        KhungHoiTrang(vm: vm, mayVe: mayVe, cheDo: $cheDo,
                      trang: trang, tenCuon: tenCuon,
                      khoanhNgay: khoanhNgay,
                      vungNgoai: vungNgoai,
                      neo: neoCanh,
                      chenHinhVe: chenHinhVe,
                      vietLaiTrang: vietLaiTrang,
                      doiNeo: { withAnimation(loXo) { neoCanh.toggle() }; Haptics.cham() },
                      dong: { moKhung = false; khoanhNgay = 0 },
                      moDayDu: { moKhung = false; moChatDayDu = true })
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
        var yKep: CGFloat = min(max(y, le), max(kho.height - le, le))
        // Né nút bút AI (khoanh ✨) — nó đứng góc dưới-phải, và robot mà đè lên
        // thì chạm robot hay chạm bút là chuyện may rủi.
        let r = CGRect(x: xKep - canhNut / 2, y: yKep - canhNut / 2, width: canhNut, height: canhNut)
        let but = Self.vungNutBut(trong: kho)
        if r.intersects(but) { yKep = but.minY - canhNut / 2 }
        return CGPoint(x: xKep, y: yKep)
    }

    /// Chỗ của `NutButAI`, nới thêm một khoảng thở.
    ///
    /// ⚠️ Số CHÉP TAY từ `ManVietView` (`.padding(.trailing, Spacing.lg)`,
    /// `.padding(.bottom, 108)`, nút 52×52). Đổi chỗ nút bút bên đó thì đổi
    /// cả ở đây — không có đường nào để hai lớp phủ tự hỏi nhau.
    static func vungNutBut(trong kho: CGSize) -> CGRect {
        CGRect(x: kho.width - Spacing.lg - 52, y: kho.height - 108 - 52, width: 52, height: 52)
            .insetBy(dx: -18, dy: -18)
    }

    // ── Con robot ───────────────────────────────────────────────
    private func nutRobot(trong _: CGSize) -> some View {
        NutRobotTroLy(dangNghi: vm.dangTraLoi || mayVe.dangVe,
                      coMoi: coMoi, dangMo: moKhung)
            .frame(width: canhNut, height: canhNut)
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
            .onTapGesture {
                moKhung.toggle()
                Haptics.cham()
            }
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
                Button { cheDo = .ve; moKhung = true } label: {
                    Label(T("Vẽ giúp"), systemImage: "paintbrush.pointed")
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
            .accessibilityValue(vm.dangTraLoi || mayVe.dangVe ? T("Đang trả lời")
                                : (coMoi ? T("Có câu trả lời mới") : ""))
            .accessibilityHint(T("Chạm để hỏi về trang này, giữ để mở CuongMini hoặc đổi chỗ"))
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
    /// Khung chữ nhật của khung hỏi, trong toạ độ lớp phủ.
    ///
    /// NEO: dính cạnh phải, cao gần trọn màn — nhưng CHỪA đáy cho nút bút AI:
    /// lớp phủ nút bút nằm TRÊN lớp phủ này (thứ tự trong `ManVietView`), để
    /// khung phủ xuống tới đáy thì nút bút nổi đè lên giữa ô nhập.
    private func khungHoi(quanh tam: CGPoint, trong kho: CGSize) -> CGRect {
        if neoCanh {
            let w = min(440, max(380, kho.width * 0.4), kho.width - 24)
            // Lớp phủ trải cả dưới thanh điều hướng của màn viết (đo trên máy
            // ảo: đặt 12 là đầu khung đè lên nút trang/bút). Chừa ~ một thanh.
            let tren: CGFloat = 60
            let duoi = Self.vungNutBut(trong: kho).minY - 4
            return CGRect(x: kho.width - w - 12, y: tren, width: w, height: max(320, duoi - tren))
        }
        let w = min(400, kho.width - 32)
        let h = min(620, kho.height - 76)
        // Mở về phía TRONG màn: robot dính mép phải thì khung nở sang trái.
        let x = tam.x > kho.width / 2 ? tam.x - w - canhNut / 2 - 6
                                      : tam.x + canhNut / 2 + 6
        let y = tam.y + canhNut / 2 - h
        return CGRect(x: min(max(x, 8), kho.width - w - 8),
                      y: min(max(y, 60), kho.height - h - 8),
                      width: w, height: h)
    }

    /// Khung neo che mất robot (robot đang đứng mép phải) ⇒ ẩn robot; nút
    /// đóng nằm sẵn trên đầu khung.
    private func robotBiChe(tam: CGPoint, khung: CGRect) -> Bool {
        moKhung && neoCanh && khung.insetBy(dx: -canhNut / 2, dy: 0).contains(tam)
    }

    private func chuyenCanh(tam: CGPoint, kho: CGSize) -> AnyTransition {
        if neoCanh {
            return .move(edge: .trailing).combined(with: .opacity)
        }
        let neo: UnitPoint = tam.x > kho.width / 2 ? .bottomTrailing : .bottomLeading
        return .scale(scale: 0.86, anchor: neo).combined(with: .opacity)
    }

    private var cauMoDauChoChat: String? {
        guard let t = trang else { return nil }
        return "Mình đang viết trang \(t.thuTu + 1) trong vở “\(tenCuon)”. "
    }

    #if DEBUG
    /// Bàn thử giao diện: `SIMCTL_CHILD_CT_TROLY=mo,neo,hoi …` cùng
    /// `CT_XEM_MAN=vo-viet`. Chỉ dựng trạng thái, không gọi mạng.
    ///   mo · neo · gon · hoi (hội thoại giả) · nghi (đang trả lời) · moi (chấm báo)
    ///   ve (màn nhập vẽ) · ve-meo · ve-oxy · ve-cho · trai (robot mép trái)
    private func apDungBanThu() {
        guard let s = ProcessInfo.processInfo.environment["CT_TROLY"] else { return }
        let c = Set(s.split(separator: ",").map { String($0) })
        if c.contains("neo") { neoCanh = true }
        if c.contains("gon") { neoCanh = false }
        if c.contains("trai") { tiLeX = 0.07 } else { tiLeX = 0.93 }
        if c.contains("hoi") || c.contains("nghi") {
            vm.bac = .pro
            vm.tin = [
                TinAI(cuaNguoi: true, noiDung: "Giải giúp mình bài trong trang này, trình bày từng bước."),
                TinAI(cuaNguoi: false, noiDung: """
                **Bài 2.** Giải phương trình 2x + 3 = 11

                1. Chuyển 3 sang vế phải: 2x = 11 − 3 = 8
                2. Chia hai vế cho 2: **x = 4**

                Thử lại: 2·4 + 3 = 11 ✓ — nghiệm đúng.
                """, model: "cuongmini-pro"),
            ]
        }
        if c.contains("nghi") {
            vm.tin.append(TinAI(cuaNguoi: true, noiDung: "Câu b thì sao?"))
            vm.tin.append(TinAI(cuaNguoi: false, noiDung: "", dangChay: true))
            vm.dangTraLoi = true
            vm.buocHienTai = "Đang đọc ảnh trang…"
        }
        if c.contains("ve") { cheDo = .ve }
        if c.contains("ve-meo") {
            cheDo = .ve; mayVe.de = "Con mèo ngồi"; mayVe.kieu = .hinh
            mayVe.gia(.xong(HinhVeMau.meo, model: "gpt-6-sol"))
        }
        if c.contains("ve-oxy") {
            cheDo = .ve; mayVe.de = "Trục toạ độ Oxy"; mayVe.kieu = .sodo
            mayVe.gia(.xong(HinhVeMau.oxy, model: "gpt-6-sol"))
        }
        if c.contains("ve-cho") {
            cheDo = .ve; mayVe.de = "Chu trình nước"; mayVe.kieu = .sodo
            mayVe.gia(.dangVe(batDau: Date().addingTimeInterval(-23)))
        }
        // Hai mục mới (29/09): ve-nhap-han · ve-nhap-khoi (màn nhập) · ve-han (学)
        // · ve-han3 (日本語) · ve-chon (chọn ứng viên "gaku") · ve-mvc · ve-jwt
        if c.contains("ve-nhap-han") { cheDo = .ve; mayVe.kieu = .chuHan; mayVe.de = "học" }
        if c.contains("ve-nhap-khoi") { cheDo = .ve; mayVe.kieu = .soDoKhoi; mayVe.de = "Mô hình MVC" }
        if c.contains("ve-han") && !c.contains("ve-han3") { cheDo = .ve; mayVe.giaHan("学", thongTin: MauVeMoi.hoc) }
        if c.contains("ve-han3") { cheDo = .ve; mayVe.giaHan("日本語", thongTin: MauVeMoi.nhatBanNgu) }
        if c.contains("ve-chon") {
            cheDo = .ve; mayVe.kieu = .chuHan; mayVe.de = "gaku"
            mayVe.gia(.chonChu(MauVeMoi.gaku))
        }
        if c.contains("ve-mvc") { cheDo = .ve; mayVe.giaSoDo(MauVeMoi.mvc, de: "Mô hình MVC") }
        if c.contains("ve-jwt") { cheDo = .ve; mayVe.giaSoDo(MauVeMoi.jwt, de: "Luồng đăng nhập JWT") }
        if c.contains("mo") { moKhung = true }
        if c.contains("moi") { coMoi = true }
    }
    #endif
}

// MARK: - Nút robot nổi

/// Con robot nổi: nút tròn tím thương hiệu + mặt robot + trạng thái.
///
/// Ba trạng thái phải đọc được từ XA, lúc mắt đang ở trang giấy:
///   · rảnh      — quầng sáng thở chậm (2,6 giây một nhịp);
///   · đang nghĩ — vòng sáng nhiều màu chạy quanh, mắt robot liếc qua lại;
///   · có mới    — chấm hồng góc trên-phải.
/// "Giảm chuyển động" bật ⇒ không thở, không quay: vòng sáng đứng yên vẫn
/// đủ báo "đang nghĩ".
struct NutRobotTroLy: View {
    let dangNghi: Bool
    let coMoi: Bool
    let dangMo: Bool
    var canh: CGFloat = 58

    @Environment(\.accessibilityReduceMotion) private var giamChuyenDong
    @State private var tho = false

    var body: some View {
        ZStack {
            // Quầng sáng: đủ để robot "nổi" khỏi giấy kẻ mà không cần viền đậm.
            Circle()
                .fill(RadialGradient(colors: [AppColors.primary.opacity(dangNghi ? 0.45 : 0.28), .clear],
                                     center: .center, startRadius: canh * 0.35, endRadius: canh * 0.8))
                .frame(width: canh * 1.6, height: canh * 1.6)
                .scaleEffect(tho ? 1.08 : 0.92)
                .animation(giamChuyenDong ? nil : .easeInOut(duration: 2.6).repeatForever(autoreverses: true),
                           value: tho)
                .allowsHitTesting(false)

            if dangNghi {
                VongSangNghi(canh: canh + 7, dungYen: giamChuyenDong)
                    .transition(.opacity)
            }

            LoiRobot(canh: canh, dangNghi: dangNghi)
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(dangMo ? 0.9 : 0), lineWidth: 2.5)
                        .padding(-1)
                )

            if coMoi && !dangNghi {
                Circle()
                    .fill(AppColors.brandPink)
                    .frame(width: 15, height: 15)
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 2.5))
                    .shadow(color: AppColors.brandPink.opacity(0.6), radius: 4)
                    .offset(x: canh * 0.36, y: -canh * 0.36)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .scaleEffect(dangMo ? 0.94 : 1)
        .animation(.snappy(duration: 0.22), value: dangMo)
        .animation(.easeInOut(duration: 0.3), value: dangNghi)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: coMoi)
        .onAppear { if !giamChuyenDong { tho = true } }
    }
}

/// Lõi tròn tím + mặt robot. Dùng chung cho robot nổi và avatar đầu khung.
struct LoiRobot: View {
    let canh: CGFloat
    var dangNghi = false

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [AppColors.primaryLight, AppColors.primary, AppColors.primaryDark],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            // Vệt sáng nửa trên — làm phẳng thành khối cầu.
            Circle()
                .fill(LinearGradient(colors: [Color.white.opacity(0.38), .clear],
                                     startPoint: .top, endPoint: .center))
                .padding(canh * 0.05)
            Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: max(0.8, canh / 60))
            MatRobot(dangNghi: dangNghi)
                .frame(width: canh * 0.6, height: canh * 0.6)
        }
        .frame(width: canh, height: canh)
        .shadow(color: AppColors.primaryDark.opacity(0.45), radius: canh * 0.2, y: canh * 0.1)
        .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
    }
}

/// Mặt robot: đầu trắng bo tròn, kính tối, hai mắt sáng, một ăng-ten.
///
/// Vẽ theo KHUNG được giao (mọi số là tỉ lệ của cạnh), nên đặt vào ô 24pt
/// hay 60pt đều vừa — không có kích thước cố định nào để tràn ra như
/// `RobotChaoMung(gon:)`.
///
/// Chớp mắt bằng `TimelineView(.periodic)` ~8 hình/giây: đủ cho một cái
/// chớp, và rẻ hơn hẳn một đồng hồ 60 hình/giây chạy suốt buổi viết bài.
struct MatRobot: View {
    var dangNghi = false
    @Environment(\.accessibilityReduceMotion) private var giamChuyenDong

    var body: some View {
        GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            TimelineView(.periodic(from: .now, by: 0.125)) { tl in
                mat(s: s, t: giamChuyenDong ? 0 : tl.date.timeIntervalSinceReferenceDate)
            }
            .frame(width: g.size.width, height: g.size.height)
        }
    }

    private func mat(s: CGFloat, t: TimeInterval) -> some View {
        // Chớp một lần mỗi 4,2 giây, nhắm ~0,15 giây.
        // ⚠️ Bản đầu đếm nhịp `Int(t * 8) % 32 == 0` và robot NHẮM MẮT SUỐT
        // (đo bằng ảnh chụp máy ảo): ngày của lịch `.periodic` không rơi đúng
        // lưới 1/8 giây như tưởng. Tính theo pha thời gian thì không phụ
        // thuộc lịch rơi vào đâu.
        let nham = !giamChuyenDong && t.truncatingRemainder(dividingBy: 4.2) < 0.15
        // Đang nghĩ: mắt liếc trái–giữa–phải–giữa, mỗi chặng 0,4 giây.
        let lech: CGFloat = {
            guard dangNghi, !giamChuyenDong else { return 0 }
            let chang = Int(t / 0.4) % 4
            return [0, -1, 0, 1][chang] * s * 0.06
        }()
        let mauMat = Color(hex: 0x8FF3FF)
        return VStack(spacing: 0) {
            // Ăng-ten
            Circle()
                .fill(dangNghi ? AppColors.brandPink : Color.white)
                .frame(width: s * 0.13, height: s * 0.13)
                .shadow(color: (dangNghi ? AppColors.brandPink : Color.white).opacity(0.9), radius: s * 0.06)
            Capsule().fill(Color.white.opacity(0.85))
                .frame(width: s * 0.045, height: s * 0.1)
            // Đầu
            ZStack {
                RoundedRectangle(cornerRadius: s * 0.24, style: .continuous)
                    .fill(Color.white)
                RoundedRectangle(cornerRadius: s * 0.16, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0x241B45), Color(hex: 0x14102A)],
                                         startPoint: .top, endPoint: .bottom))
                    .padding(s * 0.08)
                HStack(spacing: s * 0.17) {
                    ForEach(0..<2, id: \.self) { _ in
                        Capsule()
                            .fill(mauMat)
                            .frame(width: s * 0.12, height: nham ? s * 0.03 : s * 0.2)
                            .shadow(color: mauMat.opacity(0.9), radius: s * 0.05)
                    }
                }
                .offset(x: lech)
                .animation(.easeInOut(duration: 0.2), value: lech)
            }
            .frame(width: s * 0.92, height: s * 0.66)
        }
        .frame(width: s, height: s)
        .accessibilityHidden(true)
    }
}

/// Vòng sáng chạy quanh robot khi AI đang làm việc.
///
/// `TimelineView(.animation)` chỉ tồn tại KHI đang nghĩ (view bị gỡ lúc
/// rảnh), nên không có đồng hồ nào chạy ngầm cả buổi.
struct VongSangNghi: View {
    let canh: CGFloat
    let dungYen: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 45, paused: dungYen)) { tl in
            let goc = dungYen ? 0 : tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.6) / 1.6 * 360
            Circle()
                .strokeBorder(
                    AngularGradient(colors: [AppColors.primaryLight, AppColors.brandPink,
                                             AppColors.secondary, AppColors.primaryLight],
                                    center: .center),
                    lineWidth: 3.5)
                .rotationEffect(.degrees(goc))
                .blur(radius: 0.4)
                .shadow(color: AppColors.brandPink.opacity(0.5), radius: 6)
        }
        .frame(width: canh, height: canh)
        .allowsHitTesting(false)
    }
}

// MARK: - Khung hỏi

struct KhungHoiTrang: View {
    @ObservedObject var vm: AIChatViewModel
    @ObservedObject var mayVe: MayVe
    @Binding var cheDo: CheDoTroLy
    let trang: TrangVo?
    let tenCuon: String
    /// Khác 0 = vào màn là mở khoanh vùng ngay.
    var khoanhNgay: Int = 0
    /// Vùng khoanh thẳng trên trang do màn viết đưa sang.
    var vungNgoai: Binding<AnhVungCat?> = .constant(nil)
    var neo = false
    var chenHinhVe: ((HinhVeAI) -> Void)? = nil
    var vietLaiTrang: (() -> Void)? = nil
    var doiNeo: () -> Void = {}
    let dong: () -> Void
    let moDayDu: () -> Void

    @StateObject private var mayDoc = MayDoc()
    @StateObject private var ghiAm = GhiAmThoai()
    @State private var cauHoi = ""
    @State private var dinhKem: [DinhKemAI] = []
    @State private var anhChon: [PhotosPickerItem] = []
    @State private var moThuVien = false
    @State private var dangDungAnhTrang = false
    @State private var dangNhanDang = false
    @State private var anhDeKhoanh: AnhKhoanh?
    @Environment(\.modelContext) private var khoVo
    @Environment(\.colorScheme) private var cheDoMau
    /// Câu hỏi + ảnh của lượt khoanh đang chờ câu trả lời, để lưu thành thẻ.
    @State private var dangChoTraLoi: (cauHoi: String, anhTen: String?)?
    /// Vùng vừa cắt, đang chờ người dùng chọn hỏi gì.
    @State private var vungChoHoi: DinhKemAI?
    @FocusState private var dangGo: Bool
    @Namespace private var khoiChon

    /// Ba câu hỏi hay dùng nhất khi đang ngồi học — bấm một cái là gửi luôn
    /// KÈM ảnh trang, không phải gõ rồi còn nhớ đính ảnh.
    private static let goiY: [(String, String, String, String)] = [
        ("Giải bài", "Từng bước, kèm ảnh trang", "function",
         "Giải giúp mình bài trong trang này, trình bày từng bước."),
        ("Chấm bài", "Chỉ chỗ sai và sửa", "checkmark.seal",
         "Xem bài mình viết trong trang này có sai chỗ nào không, sai thì chỉ ra và sửa."),
        ("Giảng lại", "Cách dễ hiểu nhất", "lightbulb",
         "Giảng lại nội dung trang này cho mình theo cách dễ hiểu nhất."),
    ]

    private static let bo = RoundedRectangle(cornerRadius: 28, style: .continuous)

    var body: some View {
        VStack(spacing: 0) {
            thanhDau
            chonCheDo
            if cheDo == .hoi {
                noiDung
                bangBaoLoi
                if !dinhKem.isEmpty { dayDinhKem }
                oNhap
            } else {
                KhungVeGiup(may: mayVe, chen: chenHinhVe, dong: dong)
                    .transition(.opacity)
            }
        }
        .background(nenKinh)
        .clipShape(Self.bo)
        .overlay(
            Self.bo.strokeBorder(
                LinearGradient(colors: [Color.white.opacity(cheDoMau == .dark ? 0.18 : 0.9),
                                        AppColors.border],
                               startPoint: .top, endPoint: .bottom),
                lineWidth: 1),
        )
        .shadow(color: .black.opacity(cheDoMau == .dark ? 0.45 : 0.16), radius: 28, y: 14)
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        .animation(.snappy(duration: 0.22), value: cheDo)
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
        .onChange(of: vm.tin.last?.dangChay) { _, _ in luuTheNeuXong() }
        .onChange(of: anhChon) { _, moi in
            guard !moi.isEmpty else { return }
            Task { await napAnh(moi) }
        }
        // Chọn ảnh bằng cờ chứ không đặt `PhotosPicker` trong menu "+": nằm
        // trong `Menu` thì bấm vào nó menu đóng lại mà trình chọn không mở.
        .photosPicker(isPresented: $moThuVien, selection: $anhChon,
                      maxSelectionCount: HanMucDinhKem.soAnh, matching: .images)
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

    /// Kính DÀY + một lớp màu nền mỏng: kính mỏng thì dòng kẻ của trang giấy
    /// xuyên qua sau chữ, đọc rất mệt — đúng lời chê "nền trắng đục nhạt
    /// nhoà thấy lưới giấy mờ phía sau".
    private var nenKinh: some View {
        ZStack {
            Rectangle().fill(.thickMaterial)
            AppColors.backgroundSecondary.opacity(cheDoMau == .dark ? 0.55 : 0.5)
            LinearGradient(colors: [AppColors.primary.opacity(cheDoMau == .dark ? 0.16 : 0.09), .clear],
                           startPoint: .top, endPoint: .init(x: 0.5, y: 0.35))
        }
    }

    // ── Đầu khung ───────────────────────────────────────────────
    private var thanhDau: some View {
        HStack(spacing: 12) {
            LoiRobot(canh: 40, dangNghi: vm.dangTraLoi || mayVe.dangVe)

            VStack(alignment: .leading, spacing: 1) {
                Text(T("Trợ lý trang"))
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Text(dongPhu)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

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
                HStack(spacing: 4) {
                    Image(systemName: vm.bac.bieuTuong)
                        .font(.system(size: 11, weight: .bold))
                    Text(tenBacNgan)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .opacity(0.7)
                }
                .foregroundStyle(AppColors.primary)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Capsule().fill(AppColors.primary.opacity(0.13)))
            }
            .accessibilityLabel(T("Bậc AI") + ": " + vm.bac.ten)

            nutDau(neo ? "arrow.down.right.and.arrow.up.left" : "sidebar.right",
                   nhan: neo ? T("Thu gọn khung") : T("Neo cạnh phải"), lam: doiNeo)
            nutDau("xmark", nhan: T("Đóng"), lam: dong)
        }
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var dongPhu: String {
        guard let t = trang else { return T("Sẵn sàng giúp bạn") }
        // Số trang ĐI TRƯỚC: tên vở dài thì bị cắt đuôi, mà số trang mới là
        // thứ cho biết trợ lý đang nhìn đúng trang chưa.
        return "\(T("Trang")) \(t.thuTu + 1) · \(tenCuon)"
    }

    private var tenBacNgan: String {
        switch vm.bac {
        case .mini: return "Mini"
        case .pro:  return "Pro"
        case .max:  return "Max"
        }
    }

    private func nutDau(_ icon: String, nhan: String, lam: @escaping () -> Void) -> some View {
        Button(action: lam) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(AppColors.textPrimary.opacity(0.07)))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, -6)
        .accessibilityLabel(nhan)
    }

    // ── Chọn chế độ Hỏi / Vẽ ────────────────────────────────────
    private var chonCheDo: some View {
        HStack(spacing: 4) {
            oCheDo(.hoi, T("Hỏi đáp"), "bubble.left.and.text.bubble.right", bao: false)
            oCheDo(.ve, T("Vẽ giúp"), "paintbrush.pointed", bao: mayVe.dangVe)
        }
        .padding(3)
        .background(Capsule().fill(AppColors.textPrimary.opacity(0.06)))
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private func oCheDo(_ c: CheDoTroLy, _ chu: String, _ icon: String, bao: Bool) -> some View {
        let chon = cheDo == c
        return Button {
            cheDo = c
            Haptics.cham()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(chu).font(.subheadline.weight(chon ? .semibold : .medium))
                if bao {
                    Circle().fill(AppColors.brandPink).frame(width: 6, height: 6)
                }
            }
            .foregroundStyle(chon ? AppColors.textPrimary : AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background {
                if chon {
                    Capsule()
                        .fill(cheDoMau == .dark ? AnyShapeStyle(Color.white.opacity(0.14))
                                                : AnyShapeStyle(AppColors.backgroundCard))
                        .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
                        .matchedGeometryEffect(id: "o", in: khoiChon)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(chon ? .isSelected : [])
    }

    // ── Thân khung ──────────────────────────────────────────────
    @ViewBuilder
    private var noiDung: some View {
        if vm.tin.isEmpty && !vm.dangTraLoi {
            ScrollView { manTrong.padding(.horizontal, 14).padding(.vertical, 8) }
                .scrollDismissesKeyboard(.interactively)
        } else {
            ScrollViewReader { doc in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(vm.tin) { t in
                            tinView(t).id(t.id)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: vm.tin.last?.noiDung) { _, _ in
                    guard let id = vm.tin.last?.id else { return }
                    withAnimation(.easeOut(duration: 0.15)) { doc.scrollTo(id, anchor: .bottom) }
                }
                .onAppear {
                    if let id = vm.tin.last?.id { doc.scrollTo(id, anchor: .bottom) }
                }
            }
        }
    }

    @ViewBuilder
    private func tinView(_ t: TinAI) -> some View {
        if t.cuaNguoi {
            BongBongAI(tin: t, mayDoc: mayDoc)
        } else if t.dangChay && t.noiDung.isEmpty {
            DangNghiAI(buoc: vm.buocHienTai)
        } else {
            // Không có cột avatar: khung rộng ~400pt, mất 32pt cho avatar là
            // hàng nút Chép/Nghe/Báo cáo của `BongBongAI` gãy chữ ("Ngh e").
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    BongBongAI(tin: t, mayDoc: mayDoc)
                    // Bước đang làm GIỮA chừng câu trả lời (tìm web, đọc tệp…).
                    if t.dangChay, let b = vm.buocHienTai, !b.isEmpty {
                        Label(b, systemImage: "sparkle")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(2)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppColors.backgroundCard.opacity(cheDoMau == .dark ? 0.7 : 0.85)))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(AppColors.border, lineWidth: 1))
            }
        }
    }

    // ── Màn trống ───────────────────────────────────────────────
    private var manTrong: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(T("Chào bạn 👋"))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppColors.brandGradient)
                Text(trang.map { T("Mình đang xem") + " \(T("trang")) \($0.thuTu + 1) " + T("của") + " “\(tenCuon)”. " + T("Chọn một việc, hoặc hỏi bất cứ điều gì.") }
                     ?? T("Chọn một việc, hoặc hỏi bất cứ điều gì."))
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                      spacing: 10) {
                let mau: [Color] = [AppColors.primary, AppColors.success, AppColors.accent]
                ForEach(Array(Self.goiY.enumerated()), id: \.offset) { i, g in
                    theGoiY(T(g.0), T(g.1), g.2, mau[i]) {
                        Task { await guiKemTrang(g.3) }
                    }
                    .disabled(trang == nil || dangDungAnhTrang)
                }
                theGoiY(T("Khoanh vùng"), T("Hỏi đúng một chỗ"), "lasso", AppColors.secondary) {
                    Task { await moKhoanhVung() }
                }
                .disabled(trang == nil || dangDungAnhTrang)
            }

            theVe
            if vietLaiTrang != nil { theVietLai }

            Label(T("Ba thẻ đầu tự gửi kèm ảnh trang bạn đang mở."), systemImage: "photo.on.rectangle")
                .font(.caption)
                .foregroundStyle(AppColors.textTertiary)
        }
    }

    private func theGoiY(_ ten: String, _ phu: String, _ icon: String, _ mau: Color,
                         lam: @escaping () -> Void) -> some View {
        Button(action: lam) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(mau.gradient))
                    .shadow(color: mau.opacity(0.35), radius: 5, y: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ten)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(phu)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppColors.backgroundCard.opacity(cheDoMau == .dark ? 0.65 : 0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(LinearGradient(colors: [mau.opacity(0.10), .clear],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing)),
                    ),
            )
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AppColors.border, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(NhanThe())
    }

    /// Thẻ rộng "Vẽ giúp" — mở chế độ vẽ.
    private var theVe: some View {
        Button {
            cheDo = .ve
            Haptics.cham()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "paintbrush.pointed.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(LinearGradient(colors: [AppColors.primary, AppColors.brandPink],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(T("Vẽ giúp"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(T("Tranh hoặc sơ đồ học tập, vẽ bằng nét bút"))
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: [AppColors.primary.opacity(0.12), AppColors.brandPink.opacity(0.10)],
                                         startPoint: .leading, endPoint: .trailing)),
            )
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AppColors.primary.opacity(0.22), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(NhanThe())
    }

    /// Thẻ rộng "✍️ AI viết lại trang" — đóng khung hỏi rồi mở cửa sổ viết
    /// lại của màn viết (xem trước → Hoàn tác / Lưu).
    private var theVietLai: some View {
        Button {
            Haptics.cham()
            dong()
            vietLaiTrang?()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "character.book.closed.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(LinearGradient(colors: [AppColors.secondary, AppColors.primary],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(T("AI viết lại trang"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(T("Chép sạch chữ viết vội, căn dòng, tạo bảng — giữ nguyên ý"))
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: [AppColors.secondary.opacity(0.12), AppColors.primary.opacity(0.10)],
                                         startPoint: .leading, endPoint: .trailing)),
            )
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AppColors.secondary.opacity(0.25), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(NhanThe())
        .disabled(trang?.coNet != true)
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
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
            Text(chu).font(.caption).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let dong {
                Button(action: dong) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(T("Đóng"))
            }
        }
        .foregroundStyle(mau)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(mau.opacity(0.12)))
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    // ── Đính kèm ────────────────────────────────────────────────
    private var dayDinhKem: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(dinhKem) { d in
                    HStack(spacing: 6) {
                        Image(systemName: d.bieuTuong).font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.primary)
                        Text(d.ten).font(.caption).lineLimit(1)
                        Button {
                            dinhKem.removeAll { $0.id == d.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 14))
                                .foregroundStyle(AppColors.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(T("Bỏ đính kèm"))
                    }
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.leading, 10).padding(.trailing, 6)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(AppColors.backgroundCard.opacity(0.9)))
                    .overlay(Capsule().strokeBorder(AppColors.border, lineWidth: 1))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
        }
    }

    // ── Ô nhập ──────────────────────────────────────────────────
    private var rongChu: Bool {
        cauHoi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && dinhKem.isEmpty
    }

    private var oNhap: some View {
        HStack(alignment: .bottom, spacing: 6) {
            Menu {
                Button {
                    Task { await themAnhTrang() }
                } label: {
                    Label(T("Đính ảnh trang này"), systemImage: "doc.viewfinder")
                }
                .disabled(trang == nil || dangDungAnhTrang)
                Button {
                    Task { await moKhoanhVung() }
                } label: {
                    Label(T("Khoanh một vùng để hỏi"), systemImage: "lasso")
                }
                .disabled(trang == nil || dangDungAnhTrang)
                Button { moThuVien = true } label: {
                    Label(T("Ảnh từ thư viện"), systemImage: "photo.on.rectangle")
                }
            } label: {
                Image(systemName: dangDungAnhTrang ? "hourglass" : "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(AppColors.textPrimary.opacity(0.07)))
                    .frame(width: 40, height: 40)
                    .contentShape(Circle())
            }
            .accessibilityLabel(T("Đính kèm"))

            TextField(T("Hỏi về trang này…"), text: $cauHoi, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .lineLimit(1...5)
                .focused($dangGo)
                .padding(.vertical, 10)
                .frame(minHeight: 40)

            nutPhai
        }
        .padding(.leading, 4)
        .padding(.trailing, 4)
        .padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(AppColors.backgroundCard.opacity(cheDoMau == .dark ? 0.85 : 0.95)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(dangGo ? AppColors.primary.opacity(0.55) : AppColors.border,
                          lineWidth: dangGo ? 1.5 : 1))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 1)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    /// Nút cuối ô nhập: DỪNG khi AI đang trả lời · GỬI khi có chữ · MIC khi trống.
    @ViewBuilder
    private var nutPhai: some View {
        if vm.dangTraLoi {
            Button { vm.dung(); Haptics.cham() } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.backgroundSecondary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(AppColors.textPrimary))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(T("Dừng trả lời"))
        } else if rongChu {
            Image(systemName: dangNhanDang ? "waveform"
                                           : (ghiAm.dangGhi ? "mic.fill" : "mic"))
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(ghiAm.dangGhi ? Color.white : AppColors.primary)
                .symbolEffect(.variableColor.iterative, isActive: dangNhanDang)
                .frame(width: 34, height: 34)
                .background(Circle().fill(ghiAm.dangGhi ? AnyShapeStyle(AppColors.error)
                                                        : AnyShapeStyle(AppColors.primary.opacity(0.1))))
                .frame(width: 40, height: 40)
                .contentShape(Circle())
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
                .accessibilityLabel(T("Giữ để nói"))
        } else {
            Button { gui() } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppColors.onPrimary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(AppColors.primary))
                    .shadow(color: AppColors.primary.opacity(0.4), radius: 5, y: 2)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .transition(.scale.combined(with: .opacity))
            .accessibilityLabel(T("Gửi"))
        }
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
        // Nhớ lại để lưu thành thẻ khi câu trả lời về.
        dangChoTraLoi = (h.nhan, KhoVo.luuAnhHoi(v.duLieu))
        vm.gui(h.cauHoi + ghiChuTrang(), anh: [v.dataURL])
    }

    /// Lưu một lượt khoanh–hỏi thành thẻ ôn tập.
    ///
    /// ⚠️ Chỉ lưu khi câu trả lời đã XONG (`dangChay == false`) và không
    /// rỗng. Lưu lúc đang chảy thì thẻ chỉ có mấy chữ đầu, mà người dùng
    /// không có cách nào biết để sửa.
    private func luuTheNeuXong() {
        guard let cho = dangChoTraLoi,
              let cuoi = vm.tin.last, !cuoi.cuaNguoi,
              !cuoi.dangChay else { return }
        let loi = cuoi.noiDung.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !loi.isEmpty else { return }
        dangChoTraLoi = nil
        let the = TheHoiAI(trangId: trang?.id,
                           tenCuon: tenCuon,
                           soTrang: (trang?.thuTu ?? 0) + 1,
                           anhTen: cho.anhTen,
                           cauHoi: cho.cauHoi,
                           traLoi: loi)
        khoVo.insert(the)
        try? khoVo.save()
        NhatKy.vo.info("thẻ hỏi: đã lưu “\(cho.cauHoi)” (\(loi.count) ký tự)")
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
        // Nền tài liệu phủ khổ GỐC; phần nối dài bên dưới là giấy trắng.
        let khoNen = t.khoGoc
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
                let oNen = CGRect(x: 0, y: 0, width: khoNen.width * ty, height: khoNen.height * ty)
                if let ten = pdfTen,
                   let nen = NenTrangView.veTrangPdf(ten: ten, trang: pdfTrang, kho: oNen.size) {
                    nen.draw(in: oNen)
                } else if let ten = anhTen,
                          let d = try? Data(contentsOf: KhoVo.duongDanNen(ten)),
                          let nen = UIImage(data: d) {
                    nen.draw(in: oNen)
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

// MARK: - Đang nghĩ

/// Bong bóng "đang nghĩ": ba chấm nhún lần lượt + bước đang làm.
///
/// Có bước thì HIỆN bước ("Đang đọc ảnh trang…") — 5–10 giây chỉ có ba chấm
/// là đủ lâu để người ta nghĩ máy treo.
struct DangNghiAI: View {
    let buoc: String?
    @Environment(\.accessibilityReduceMotion) private var giamChuyenDong

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            LoiRobot(canh: 24, dangNghi: true)
            VStack(alignment: .leading, spacing: 6) {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: giamChuyenDong)) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    HStack(spacing: 5) {
                        ForEach(0..<3, id: \.self) { i in
                            let pha = giamChuyenDong ? 0 : max(0, sin((t * 2 * .pi / 1.1) - Double(i) * 0.9))
                            Circle()
                                .fill(AppColors.primary.opacity(0.45 + 0.55 * pha))
                                .frame(width: 7, height: 7)
                                .offset(y: -4 * pha)
                        }
                    }
                    .frame(height: 14)
                }
                if let b = buoc, !b.isEmpty {
                    Text(b)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColors.backgroundCard.opacity(0.8)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AppColors.border, lineWidth: 1))
            .animation(.easeInOut(duration: 0.2), value: buoc)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(T("Trợ lý đang trả lời") + (buoc.map { ". " + $0 } ?? ""))
    }
}

/// Nhấn thẻ: lún nhẹ + mờ khi tắt. `.plain` không có phản hồi nào, thẻ to
/// bấm vào mà không lún thì người ta bấm lại lần hai.
struct NhanThe: ButtonStyle {
    @Environment(\.isEnabled) private var batDuoc

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(batDuoc ? 1 : 0.5)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
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
