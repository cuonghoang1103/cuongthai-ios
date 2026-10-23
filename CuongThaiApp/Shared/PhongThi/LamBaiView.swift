import SwiftUI
import Combine

// ════════════════════════════════════════════════════════════════
// LÀM BÀI — FE (trắc nghiệm + câu code) và PE (CODE / WRITE / SPEAK)
//
// Một câu một màn, vuốt/bấm để sang câu. Không dồn 50 câu vào một trang
// cuộn dài như web: trên điện thoại thì cuộn tìm câu 37 là cực hình, và
// người ta hay bấm nhầm đáp án của câu bên cạnh. iPad (ngang, cửa sổ rộng)
// có thêm CỘT danh sách câu bên trái, đúng như thanh bên của web.
//
// Hành vi bám theo `ExamRoomClient.tsx` của web (22/10/2026):
//   • đồng hồ theo `expiresAt` của MÁY CHỦ; hết giờ TỰ NỘP đúng MỘT lần
//     (sự cố 06/08 của web: tự nộp lặp vô hạn bắn 18.297 POST trong 10 phút)
//   • đánh dấu câu (cờ), lưới câu, tiến độ
//   • `integritySignals = {blurCount, auto}` — web đếm số lần rời tab; app
//     đếm số lần RỜI APP khi đang thi. Không thu gì hơn thế.
//   • PE CODE nộp MỘT .zip; WRITE nộp bài viết + ảnh sơ đồ; SPEAK nộp ghi âm
// ════════════════════════════════════════════════════════════════

/// Bản nháp của một lượt đang làm — GHI XUỐNG MÁY để thoát ra vào lại (hay
/// app bị hệ điều hành tắt) không mất các đáp án đã chọn. Máy chủ KHÔNG lưu
/// bài dở; web cũng mất nếu đóng tab.
struct NhapBaiThi: Codable {
    var chon: [Int: [Int]] = [:]
    var maCode: [Int: String] = [:]
    var baiViet: [Int: String] = [:]
    var co: [Int] = []
    var viTri = 0
    var soLanRoiApp = 0

    private static var thuMuc: URL {
        let goc = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return goc.appendingPathComponent("phong-thi-nhap", isDirectory: true)
    }
    static func duong(_ attemptId: Int) -> URL { thuMuc.appendingPathComponent("\(attemptId).json") }

    static func doc(_ attemptId: Int) -> NhapBaiThi? {
        guard let d = try? Data(contentsOf: duong(attemptId)) else { return nil }
        return try? JSONDecoder().decode(NhapBaiThi.self, from: d)
    }
    func ghi(_ attemptId: Int) {
        try? FileManager.default.createDirectory(at: Self.thuMuc, withIntermediateDirectories: true)
        if let d = try? JSONEncoder().encode(self) { try? d.write(to: Self.duong(attemptId), options: .atomic) }
    }
    static func xoa(_ attemptId: Int) { try? FileManager.default.removeItem(at: duong(attemptId)) }
}

/// Tệp .zip người dùng tự chọn (làm ở máy tính rồi nộp qua điện thoại).
struct TepZipChon: Equatable {
    let ten: String
    let duLieu: Data
}

@MainActor
final class LamBaiVM: ObservableObject {
    @Published var de: DeDangLam?
    @Published var luot: LuotThi?
    @Published var dangTai = true
    @Published var loi: String?
    /// Lỗi lúc NỘP — hiện thành hộp thoại, bài vẫn còn nguyên để nộp lại.
    @Published var loiNop: String?
    @Published var viTri = 0
    /// Đáp án đã chọn: id câu → các chỉ số đáp án.
    @Published var chon: [Int: Set<Int>] = [:] { didSet { henGhiNhap() } }
    /// Mã đã gõ — câu CODE trong đề FE (tiến độ) lẫn đề PE CODE.
    @Published var maCode: [Int: String] = [:] { didSet { henGhiNhap() } }
    @Published var baiViet: [Int: String] = [:] { didSet { henGhiNhap() } }
    @Published var anhSoDo: [Int: Data] = [:]
    @Published var zipChon: TepZipChon?
    @Published var cauNoiSinh: [CauNoiPhu] = []
    @Published var dangSinhCauNoi = false
    /// Câu đã gắn cờ "xem lại sau".
    @Published var co: Set<Int> = [] { didSet { henGhiNhap() } }
    @Published var conLai: Int = 0
    @Published var ketQua: XemLaiBaiThi?
    @Published var dangNop = false
    /// Ghi chú hiện ở màn kết quả (ví dụ: phần code không được chấm vì người
    /// dùng không đồng ý gửi cho AI).
    @Published var ghiChuNop: String?

    let examId: Int
    /// Phòng ôn tập CuongMini: KHÔNG tính giờ, có khung hỏi AI và bình luận.
    let coAI: Bool
    let deGoc: DeThi?
    #if os(iOS)
    let ghiAm: GhiAmThi
    #endif
    private var dayNoi: AnyCancellable?
    /// Bản xem thử (DEBUG): không gọi mạng, không nộp thật.
    private(set) var xemThu = false
    private var dongHo: Timer?
    private var hanChot: Date?
    private var batDauLuc = Date()
    private var daTuNop = false
    private var soLanRoiApp = 0
    private var viecGhi: Task<Void, Never>?

    init(examId: Int, coAI: Bool, deGoc: DeThi? = nil, deSan: DeDangLam? = nil) {
        self.examId = examId; self.coAI = coAI; self.deGoc = deGoc
        #if os(iOS)
        ghiAm = GhiAmThi(khoa: "\(examId)-\(coAI ? "ai" : "thi")")
        #endif
        self.de = deSan
        noiGhiAm()
    }

    /// Bộ thu âm là một `ObservableObject` riêng — chuyển tiếp thay đổi của
    /// nó lên đây để thanh tiến độ ("Đã thu 2/4") cập nhật theo.
    private func noiGhiAm() {
        #if os(iOS)
        dayNoi = ghiAm.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        #endif
    }

    #if DEBUG
    /// Bàn thử: dựng sẵn đề + lượt, không chạm mạng.
    init(xemThu de: DeDangLam, luot: LuotThi, deGoc: DeThi?) {
        self.examId = de.id; self.coAI = luot.aiAssisted ?? false; self.deGoc = deGoc
        #if os(iOS)
        ghiAm = GhiAmThi(khoa: "xem-thu-\(de.id)")
        #endif
        self.de = de; self.luot = luot; self.xemThu = true; self.dangTai = false
        noiGhiAm()
        batDongHo()
    }
    #endif

    var cauHoi: [CauHoiThi] { de?.questions ?? [] }
    var hienTai: CauHoiThi? { viTri < cauHoi.count ? cauHoi[viTri] : nil }
    var laPE: Bool { de?.laPE ?? deGoc?.laPE ?? false }
    var loaiPE: String? { de?.loaiPE ?? deGoc?.loaiPE }
    var coDongHo: Bool { !coAI && hanChot != nil }

    /// Câu hỏi phụ của đề NÓI (đề có sẵn, hoặc máy chủ vừa sinh).
    var cauNoi: [CauNoiPhu] {
        let q = cauHoi.first { $0.laNoi }
        if let s = q?.speakingPrompts, !s.isEmpty { return s }
        return cauNoiSinh
    }

    func daLam(_ c: CauHoiThi) -> Bool {
        if c.laCode { return !(maCode[c.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if c.laViet { return !(baiViet[c.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || anhSoDo[c.id] != nil }
        if c.laNoi {
            #if os(iOS)
            return !ghiAm.tep.isEmpty
            #else
            return false
            #endif
        }
        return !(chon[c.id] ?? []).isEmpty
    }
    var soDaLam: Int { cauHoi.filter { daLam($0) }.count }

    // MARK: Bắt đầu

    func batDau() async {
        dangTai = true; defer { dangTai = false }
        loi = nil
        do {
            // Bắt đầu lượt TRƯỚC rồi mới lấy đề: máy chủ tự nối lại lượt
            // đang dở nếu có, nên thoát ra vào lại là làm tiếp, không mất bài.
            let l: LuotThi = try await APIClient.shared.request(.batDauLuotThi(examId: examId, coAI: coAI))
            luot = l
            if de == nil {
                de = try await APIClient.shared.request(.deDangLam(examId: examId))
            }
            batDauLuc = Date()
            // Nối lại lượt cũ ⇒ khôi phục bản nháp trên máy (nếu có).
            if let n = NhapBaiThi.doc(l.attemptId) {
                chon = n.chon.mapValues { Set($0) }
                maCode = n.maCode
                baiViet = n.baiViet
                co = Set(n.co)
                viTri = min(max(0, n.viTri), max(0, cauHoi.count - 1))
                soLanRoiApp = n.soLanRoiApp
            }
            // Câu CODE: điền sẵn mã cho sẵn (starter) như web.
            for c in cauHoi where c.laCode && maCode[c.id] == nil {
                if let s = c.starterCode, !s.isEmpty { maCode[c.id] = s }
            }
            batDongHo()
            KhoLuotDangDo.chung.ghi(LuotDangDo(
                examId: examId, attemptId: l.attemptId,
                tieuDe: de?.title ?? deGoc?.title ?? "", maDe: de?.code ?? deGoc?.code,
                coAI: coAI, hetHan: l.expiresAt, moLuc: Date().timeIntervalSince1970, de: deGoc))
        } catch {
            loi = error.localizedDescription
        }
    }

    private func batDongHo() {
        // ⚠️ Phòng CuongMini KHÔNG tính giờ — máy chủ trả `expiresAt = null`
        // cho lượt `aiAssisted`. Không chặn ở đây thì nhánh dưới tự đặt đồng
        // hồ đủ `durationMinutes` rồi hết giờ TỰ NỘP một bài ôn tập.
        guard !coAI else { conLai = 0; hanChot = nil; return }
        if let het = luot?.expiresAt, let moc = Date.tuChuoiISO(het) {
            // Nối lại lượt cũ thì tính từ `expiresAt` của máy chủ, không phải
            // từ lúc mở màn — không thì thoát ra vào lại là được thêm giờ.
            hanChot = moc
        } else {
            let phut = de?.durationMinutes ?? 0
            guard phut > 0 else { hanChot = nil; return }
            hanChot = Date().addingTimeInterval(TimeInterval(phut * 60))
        }
        nhipDongHo()
        dongHo?.invalidate()
        dongHo = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.nhipDongHo() }
        }
    }

    /// Tính lại từ HẠN CHÓT mỗi nhịp — không trừ dần một biến đếm: app nằm
    /// nền vài phút thì `Timer` không chạy, trừ dần là đồng hồ chậm hơn thật.
    private func nhipDongHo() {
        guard let h = hanChot else { return }
        conLai = max(0, Int(h.timeIntervalSinceNow.rounded(.up)))
        if conLai == 5 * 60 || conLai == 60 { Haptics.hong() }
        if conLai == 0 && !daTuNop && ketQua == nil {
            // Tự nộp ĐÚNG MỘT LẦN, kể cả khi lần đó hỏng — hỏng thì người
            // dùng tự bấm "Nộp bài" (xem chú thích đầu tệp).
            daTuNop = true
            dongHo?.invalidate()
            Task { await nop(tuDong: true) }
        }
    }

    /// Phân số thời gian còn lại (0…1) cho thanh đồng hồ.
    var tiLeConLai: Double {
        let tong = Double(max(1, (de?.durationMinutes ?? 0) * 60))
        return min(1, Double(conLai) / tong)
    }

    // MARK: Trả lời

    func danhDau(_ cau: CauHoiThi, _ i: Int) {
        var s = chon[cau.id] ?? []
        if cau.chonNhieu {
            if s.contains(i) { s.remove(i) }
            else {
                // Đề nói rõ "chọn N đáp án" — chọn quá N thì bỏ cái chọn sớm
                // nhất, không chặn cứng (chặn là người dùng tưởng nút hỏng).
                if s.count >= cau.soDapAn, let dau = s.sorted().first, cau.soDapAn > 1 { s.remove(dau) }
                s.insert(i)
            }
        } else {
            s = s.contains(i) ? [] : [i]
        }
        chon[cau.id] = s
        Haptics.cham()

        // Chọn xong câu MỘT đáp án thì tự sang câu sau — bớt một cú bấm cho
        // mỗi câu, mà bài 50 câu thì đó là 50 cú bấm.
        if !cau.chonNhieu, !s.isEmpty, viTri + 1 < cauHoi.count {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(240))
                withAnimation(.easeOut(duration: 0.2)) { self.viTri += 1 }
            }
        }
    }

    func latCo(_ c: CauHoiThi) {
        if co.contains(c.id) { co.remove(c.id) } else { co.insert(c.id) }
        Haptics.cham()
    }

    func ghiRoiApp() {
        guard luot != nil, ketQua == nil, !coAI else { return }
        soLanRoiApp += 1
        henGhiNhap()
    }

    func sinhCauNoi() async {
        guard let q = cauHoi.first(where: { $0.laNoi }), !dangSinhCauNoi else { return }
        dangSinhCauNoi = true; defer { dangSinhCauNoi = false }
        do {
            let ds: [CauNoiPhu] = try await APIClient.shared.request(.taoCauHoiNoi(questionId: q.id, soCau: 4))
            cauNoiSinh = ds.filter { !$0.text.isEmpty }
            if cauNoiSinh.isEmpty { loiNop = T("Chưa tạo được câu hỏi. Thử lại nhé.") }
        } catch { loiNop = error.localizedDescription }
    }

    // MARK: Bản nháp

    private func henGhiNhap() {
        guard let a = luot?.attemptId, ketQua == nil, !xemThu else { return }
        viecGhi?.cancel()
        let n = NhapBaiThi(chon: chon.mapValues { Array($0).sorted() }, maCode: maCode,
                           baiViet: baiViet, co: Array(co), viTri: viTri, soLanRoiApp: soLanRoiApp)
        viecGhi = Task.detached(priority: .utility) {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            n.ghi(a)
        }
    }

    func ghiViTri() { henGhiNhap() }

    // MARK: Nộp

    func nop(tuDong: Bool = false) async {
        guard let l = luot, let de, !dangNop, ketQua == nil else { return }
        if xemThu {
            loiNop = T("Đây là bản xem thử — không nộp lên máy chủ.")
            return
        }
        dangNop = true; defer { dangNop = false }
        loiNop = nil
        let giay = Int(Date().timeIntervalSince(batDauLuc))
        do {
            let kq: XemLaiBaiThi
            if !de.laPE {
                kq = try await nopFE(l.attemptId, de: de, giay: giay, tuDong: tuDong)
            } else {
                switch de.loaiPE {
                case "CODE":  kq = try await nopCode(l.attemptId, giay: giay)
                case "WRITE": kq = try await GuiBaiThi.nopViet(attemptId: l.attemptId, bai: baiVietGui, anh: anhSoDo, giay: giay)
                case "SPEAK": kq = try await nopNoi(l.attemptId, giay: giay)
                default: throw APIError.serverError(T("Loại đề này chưa hỗ trợ nộp trên app."))
                }
            }
            dongHo?.invalidate()
            ketQua = kq
            NhapBaiThi.xoa(l.attemptId)
            KhoLuotDangDo.chung.xoa(examId: examId, coAI: coAI)
            #if os(iOS)
            ghiAm.donSach()
            #endif
            Haptics.xong()
        } catch {
            Haptics.hong()
            loiNop = (tuDong ? T("Hết giờ — tự nộp không thành công: ") : "")
                + error.localizedDescription
                + (tuDong ? T(" Bấm \"Nộp bài\" để thử lại.") : "")
        }
    }

    private var baiVietGui: [Int: String] {
        var m: [Int: String] = [:]
        for c in cauHoi where c.laViet { m[c.id] = baiViet[c.id] ?? "" }
        return m
    }

    private func nopFE(_ a: Int, de: DeDangLam, giay: Int, tuDong: Bool) async throws -> XemLaiBaiThi {
        let dapAn = chon.reduce(into: [String: [Int]]()) { m, kv in
            if !kv.value.isEmpty { m[String(kv.key)] = Array(kv.value).sorted() }
        }
        var ma: [String: String] = [:]
        for c in cauHoi where c.laCode {
            let v = maCode[c.id] ?? ""
            if !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { ma[String(c.id)] = v }
        }
        // Câu code được AI chấm ⇒ phải có đồng ý chia sẻ (5.1.2(i)). Từ chối
        // thì vẫn nộp phần trắc nghiệm — không để một hộp thoại làm hỏng cả
        // bài thi đang chạy đồng hồ.
        if !ma.isEmpty, !(await DongYChiaSeAI.xinPhep()) {
            ma = [:]
            ghiChuNop = T("Phần code không được gửi đi chấm vì bạn chưa đồng ý chia sẻ dữ liệu với AI — các câu đó tính 0 điểm.")
        }
        let tinHieu: [String: Any] = ["blurCount": soLanRoiApp, "auto": tuDong]
        return try await APIClient.shared.request(.nopBaiThiFE(
            attemptId: a, dapAn: dapAn, maCode: ma, giay: giay, tinHieu: tinHieu))
    }

    /// Thứ tự câu CODE (đánh số tệp Q1, Q2… theo đúng thứ tự này).
    var cauCode: [CauHoiThi] { cauHoi.filter { $0.laCode } }

    /// Danh sách tệp sẽ đi vào .zip (để màn xác nhận nói rõ trước khi nộp).
    var tepSeNop: [String] {
        if let z = zipChon { return [z.ten] }
        return cauCode.enumerated().compactMap { i, c in
            (maCode[c.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil : TepMaNguon.ten(thuTu: i + 1, ngonNgu: c.language)
        }
    }

    private func nopCode(_ a: Int, giay: Int) async throws -> XemLaiBaiThi {
        if let z = zipChon {
            return try await GuiBaiThi.nopCode(attemptId: a, zip: z.duLieu, tenTep: z.ten, giay: giay)
        }
        guard let zip = TepMaNguon.dongGoi(cau: cauCode, ma: maCode) else {
            throw GuiBaiThi.Loi.khongCoGi(T("Chưa có bài nào để nộp — hãy gõ code cho ít nhất một câu, hoặc chọn tệp .zip."))
        }
        return try await GuiBaiThi.nopCode(attemptId: a, zip: zip, tenTep: "bai-lam-\(examId).zip", giay: giay)
    }

    private func nopNoi(_ a: Int, giay: Int) async throws -> XemLaiBaiThi {
        #if os(iOS)
        guard let q = cauHoi.first(where: { $0.laNoi }) else {
            throw APIError.serverError(T("Đề này không có câu hỏi nói."))
        }
        ghiAm.dung()
        let tep = ghiAm.tepTheoThuTu(soCau: max(cauNoi.count, ghiAm.tep.keys.max().map { $0 + 1 } ?? 0))
        return try await GuiBaiThi.nopNoi(attemptId: a, questionId: q.id, amThanh: tep, giay: giay)
        #else
        throw APIError.serverError(T("Thu âm chỉ có trên iPhone/iPad."))
        #endif
    }

    /// Bài viết/mã đã nộp — màn xem lại cần vì bản xem lại của máy chủ KHÔNG
    /// trả bài viết PE theo từng câu (`answers` lưu dạng `{essays: {...}}`).
    var baiDaNop: [Int: String] {
        var m = maCode
        for (k, v) in baiViet { m[k] = v }
        return m
    }

    func dung() {
        dongHo?.invalidate(); dongHo = nil
        #if os(iOS)
        ghiAm.dung()
        #endif
    }
}

// MARK: - Màn làm bài

struct LamBaiView: View {
    let de: DeThi
    /// `true` → "Bắt đầu thi với CuongMini": không đồng hồ, có nút hỏi AI và
    /// bình luận dưới mỗi câu.
    let coAI: Bool
    /// ⚠️ Mặc định TIẾNG ANH — đề gốc là tiếng Anh, bản Việt là bản dịch kèm
    /// theo. Đúng như web (`useState<'en'|'vi'>('en')`).
    @State private var ngonNgu: NgonNguDe = .anh
    @StateObject private var vm: LamBaiVM
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var coNgang
    @Environment(\.scenePhase) private var pha
    @State private var hoiThoat = false
    @State private var tam: TamThi?

    /// Tấm trượt duy nhất — C5: hai `.sheet` trên cùng một view thì chỉ cái
    /// cuối chạy.
    enum TamThi: Identifiable {
        case luoi, mini, huongDan, xacNhan
        var id: Int { hashValue }
    }

    init(de: DeThi, coAI: Bool = false, deSan: DeDangLam? = nil) {
        self.de = de
        self.coAI = coAI
        _vm = StateObject(wrappedValue: LamBaiVM(examId: de.id, coAI: coAI, deGoc: de, deSan: deSan))
    }

    #if DEBUG
    init(xemThu d: DeDangLam, luot: LuotThi, deGoc: DeThi, viTri: Int = 0,
         chon: [Int: Set<Int>] = [:], co: Set<Int> = [], maCode: [Int: String] = [:],
         baiViet: [Int: String] = [:]) {
        self.de = deGoc
        self.coAI = luot.aiAssisted ?? false
        let m = LamBaiVM(xemThu: d, luot: luot, deGoc: deGoc)
        m.viTri = viTri; m.chon = chon; m.co = co; m.maCode = maCode; m.baiViet = baiViet
        _vm = StateObject(wrappedValue: m)
    }
    #endif

    private var rong: Bool { coNgang == .regular }

    /// Màn đọc/tập trung ⇒ chủ đề mùa tự dừng chuyển động khi màn này hiện (Shared/ChuDe).
    var body: some View { thanManYen.nenMuaYen() }

    @ViewBuilder private var thanManYen: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            if let kq = vm.ketQua {
                NavigationStack {
                    KetQuaView(kq: kq, de: de, baiDaNop: vm.baiDaNop, ghiChu: vm.ghiChuNop) { dismiss() }
                }
            } else if vm.dangTai {
                khungXuong
            } else if let l = vm.loi, vm.de == nil || vm.luot == nil {
                VStack(spacing: Spacing.md) {
                    ErrorStateView(message: l) { Task { await vm.batDau() } }
                    Button(T("Đóng")) { dismiss() }
                        .font(.subheadline.weight(.semibold))
                }
            } else {
                noiDung
            }
        }
        .task { if vm.luot == nil && !vm.xemThuDangChay { await vm.batDau() } }
        .onDisappear { vm.dung() }
        .onChange(of: pha) { _, p in if p != .active { vm.ghiRoiApp() } }
        .onChange(of: vm.viTri) { _, _ in vm.ghiViTri() }
        .alert(T("Thoát khỏi bài thi?"), isPresented: $hoiThoat) {
            Button(T("Ở lại"), role: .cancel) { }
            Button(T("Thoát"), role: .destructive) { vm.dung(); dismiss() }
        } message: {
            // Phòng ôn tập KHÔNG có đồng hồ — dọa "đồng hồ vẫn chạy" ở đó là
            // nói sai, và người ta sẽ vội vàng vì một sức ép không có thật.
            Text(coAI
                 ? T("Bài ôn tập được giữ lại trên máy. Vào lại đề này là làm tiếp từ đúng chỗ đang dở.")
                 : T("Bài đang làm được giữ lại trên máy. Vào lại đề này là làm tiếp, nhưng ĐỒNG HỒ VẪN CHẠY."))
        }
        .alert(T("Chưa nộp được"), isPresented: Binding(
            get: { vm.loiNop != nil }, set: { if !$0 { vm.loiNop = nil } })) {
            Button(T("Đã hiểu"), role: .cancel) { }
        } message: { Text(vm.loiNop ?? "") }
        .sheet(item: $tam) { t in
            switch t {
            case .luoi:
                NavigationStack { LuoiCauThi(vm: vm) { tam = nil } }
                    .presentationDetents([.medium, .large])
            case .huongDan:
                NavigationStack { HuongDanDeView(de: vm.de, deGoc: de) }
                    .presentationDetents([.large])
                    .environment(\.ngonNguDe, ngonNgu)
            case .xacNhan:
                XacNhanNopView(vm: vm) { nhay in
                    tam = nil
                    if let nhay { withAnimation { vm.viTri = nhay } }
                } nop: {
                    tam = nil
                    Task { await vm.nop() }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            case .mini:
                if let l = vm.luot, let c = vm.hienTai {
                    CuongMiniView(examId: de.id, attemptId: l.attemptId,
                                  questionId: c.id, nhanCau: T("Câu") + " \(vm.viTri + 1)")
                        // ⚠️ `id` phải đổi theo CÂU — không thì mở CuongMini ở
                        // câu 6 vẫn thấy cuộc hỏi của câu 5 (web: `key={questionId}`).
                        .id(c.id)
                        .presentationDetents([.fraction(0.62), .large])
                        .presentationDragIndicator(.visible)
                }
            }
        }
        // Cả màn dùng CHUNG một ngôn ngữ: bấm nút là đề bài và mọi đáp án đổi
        // cùng lúc, không có chuyện đề tiếng Anh mà đáp án tiếng Việt.
        .environment(\.ngonNguDe, ngonNgu)
        .interactiveDismissDisabled(vm.luot != nil && vm.ketQua == nil)
    }

    // MARK: Bố cục

    @ViewBuilder private var noiDung: some View {
        if rong && vm.cauHoi.count > 1 {
            HStack(spacing: 0) {
                CotDieuHuongThi(vm: vm, moNop: { tam = .xacNhan })
                    .frame(width: 300)
                    .background(AppColors.backgroundSecondary)
                Divider()
                VStack(spacing: 0) {
                    thanhDau
                    khungCauHienTai
                    thanhDuoi
                }
                .frame(maxWidth: .infinity)
            }
            .overlay(alignment: .bottomTrailing) { if coAI { nutMini.padding(.bottom, 70) } }
        } else {
            VStack(spacing: 0) {
                thanhDau
                khungCauHienTai
                thanhDuoi
            }
            .overlay(alignment: .bottomTrailing) { if coAI, vm.luot != nil, vm.hienTai != nil { nutMini.padding(.bottom, 70) } }
        }
    }

    private var khungXuong: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SkeletonBox(height: 14, width: 160)
            SkeletonBox(height: 6, radius: 3)
            SkeletonBox(height: 18)
            SkeletonBox(height: 18, width: 260)
            ForEach(0..<4, id: \.self) { _ in SkeletonBox(height: 52, radius: CornerRadius.medium) }
            Spacer()
        }
        .padding(Spacing.lg)
        .accessibilityLabel(T("Đang tải đề thi"))
    }

    // ── Nút nổi mở CuongMini ────────────────────────────────────
    private var nutMini: some View {
        Button {
            tam = .mini
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "sparkles").font(.system(size: 15, weight: .semibold))
                Text(T("Hỏi CuongMini")).font(.subheadline.weight(.semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Capsule().fill(
                LinearGradient(colors: [AppColors.primary, AppColors.primaryDark],
                               startPoint: .topLeading, endPoint: .bottomTrailing)))
            .shadow(color: AppColors.primary.opacity(0.35), radius: 10, y: 4)
        }
        .buttonStyle(.nhan)
        .padding(.trailing, Spacing.md)
    }

    // ── Thanh trên ──────────────────────────────────────────────
    private var thanhDau: some View {
        VStack(spacing: 6) {
            HStack(spacing: Spacing.sm) {
                Button { hoiThoat = true } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 40, height: 40).contentShape(Rectangle())
                }
                .accessibilityLabel(T("Thoát"))

                VStack(alignment: .leading, spacing: 1) {
                    Text(de.ten(ngonNgu))
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    Text(dongTienDo)
                        .font(.caption2)
                        .foregroundColor(AppColors.textTertiary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
                // Tên đề co lại trước — đồng hồ và các nút KHÔNG được bị đẩy ra mép.
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(-1)
                dongHoNhan

                if vm.de?.instructions?.isEmpty == false || vm.de?.attachmentUrl?.isEmpty == false {
                    Button { tam = .huongDan } label: {
                        Image(systemName: "doc.text")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textPrimary)
                            .frame(width: 36, height: 40).contentShape(Rectangle())
                    }
                    .accessibilityLabel(T("Hướng dẫn và tệp đề"))
                }

                // Nút đổi ngôn ngữ. Nhãn là ngôn ngữ SẮP chuyển sang.
                Button { ngonNgu = ngonNgu.doiSang } label: {
                    Text(ngonNgu.nhanNut)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(AppColors.border, lineWidth: 1))
                }
                .accessibilityLabel(ngonNgu == .viet ? T("Chuyển sang tiếng Anh") : T("Chuyển sang tiếng Việt"))

                if !rong && vm.cauHoi.count > 1 {
                    Button { tam = .luoi } label: {
                        Image(systemName: "square.grid.3x3")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textPrimary)
                            .frame(width: 36, height: 40).contentShape(Rectangle())
                    }
                    .accessibilityLabel(T("Danh sách câu hỏi"))
                }
            }

            // Thanh đồng hồ: co dần theo thời gian còn lại, đổi màu ở 5 phút
            // và 1 phút cuối. Không có đồng hồ thì là thanh TIẾN ĐỘ.
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColors.backgroundTertiary)
                    Capsule().fill(mauThanh)
                        .frame(width: g.size.width * CGFloat(vm.coDongHo ? vm.tiLeConLai : tiLeDaLam))
                        .animation(.linear(duration: 0.9), value: vm.conLai)
                        .animation(.easeOut(duration: 0.25), value: vm.soDaLam)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, Spacing.sm)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.top, Spacing.sm)
        .padding(.bottom, 6)
        .background(AppColors.backgroundPrimary)
    }

    private var tiLeDaLam: Double {
        vm.cauHoi.isEmpty ? 0 : Double(vm.soDaLam) / Double(vm.cauHoi.count)
    }

    private var mauThanh: Color {
        guard vm.coDongHo else { return AppColors.success }
        return vm.conLai <= 60 ? AppColors.error : vm.conLai <= 300 ? AppColors.warning : AppColors.primary
    }

    private var dongTienDo: String {
        if vm.loaiPE == "SPEAK" {
            #if os(iOS)
            return String(format: T("Đã thu %d/%d câu"), vm.ghiAm.tep.count, vm.cauNoi.count)
            #else
            return ""
            #endif
        }
        var s = String(format: T("Đã làm %d/%d"), vm.soDaLam, vm.cauHoi.count)
        if !vm.co.isEmpty { s += " · " + String(format: T("%d cờ"), vm.co.count) }
        return s
    }

    @ViewBuilder private var dongHoNhan: some View {
        if coAI {
            // Chỗ của đồng hồ, nhưng nói ngược lại: KHÔNG có đồng hồ.
            Label(T("Ôn tập · không tính giờ"), systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.primary)
                .lineLimit(1)
                .fixedSize()
        } else if vm.coDongHo {
            HStack(spacing: 4) {
                Image(systemName: "clock").font(.system(size: 12))
                Text(dinhDang(vm.conLai))
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .fixedSize()
            .foregroundColor(vm.conLai <= 60 ? AppColors.error : vm.conLai <= 300 ? AppColors.warning : AppColors.textPrimary)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(vm.conLai <= 300 ? mauThanh.opacity(0.12) : Color.clear))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(format: T("Còn %d phút %d giây"), vm.conLai / 60, vm.conLai % 60))
        }
    }

    // ── Câu hỏi ─────────────────────────────────────────────────
    @ViewBuilder private var khungCauHienTai: some View {
        if let c = vm.hienTai {
            ScrollViewReader { cuon in
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        NeoDauTrang()
                        KhungCauThi(vm: vm, cau: c, coAI: coAI)
                    }
                    .padding(Spacing.md)
                    .frame(maxWidth: 860)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                // Ba đường đổi câu mà KHÔNG rời màn — câu dài thì mở câu mới
                // ra ngay giữa trang. Cuộn về đầu mỗi lần đổi.
                .onChange(of: vm.viTri) { _, _ in cuon.veDauTrang() }
                .id(c.id)
                .transition(.opacity)
            }
        } else {
            Spacer()
        }
    }

    // ── Thanh dưới ──────────────────────────────────────────────
    private var thanhDuoi: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) { vm.viTri = max(0, vm.viTri - 1) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(vm.viTri > 0 ? AppColors.textPrimary : AppColors.textTertiary)
                    .frame(width: 50, height: 48)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(AppColors.backgroundTertiary))
            }
            .disabled(vm.viTri == 0)
            .buttonStyle(.nhan)
            .accessibilityLabel(T("Câu trước"))

            if let c = vm.hienTai, vm.cauHoi.count > 1 {
                let coCo = vm.co.contains(c.id)
                Button { vm.latCo(c) } label: {
                    Image(systemName: coCo ? "flag.fill" : "flag")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(coCo ? AppColors.warning : AppColors.textSecondary)
                        .frame(width: 50, height: 48)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(coCo ? AppColors.warning.opacity(0.14) : AppColors.backgroundTertiary))
                }
                .buttonStyle(.nhan)
                .accessibilityLabel(coCo ? T("Bỏ cờ câu này") : T("Gắn cờ để xem lại"))
            }

            if vm.viTri + 1 < vm.cauHoi.count {
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { vm.viTri += 1 }
                } label: {
                    Text(T("Câu tiếp"))
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(AppColors.primary))
                }
                .buttonStyle(.nhan)
            } else {
                Button { tam = .xacNhan } label: {
                    HStack(spacing: Spacing.sm) {
                        if vm.dangNop { ProgressView().tint(.white) }
                        Text(vm.dangNop ? (vm.laPE ? T("AI đang chấm…") : T("Đang nộp…")) : T("Nộp bài"))
                            .font(.body.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(AppColors.success))
                }
                .disabled(vm.dangNop)
                .buttonStyle(.nhan)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        .background(AppColors.backgroundPrimary)
    }

    private func dinhDang(_ g: Int) -> String {
        g >= 3600 ? String(format: "%d:%02d:%02d", g / 3600, (g % 3600) / 60, g % 60)
                  : String(format: "%d:%02d", g / 60, g % 60)
    }
}

extension LamBaiVM {
    /// Bàn thử đã dựng sẵn lượt — `.task` không được gọi mạng.
    var xemThuDangChay: Bool { xemThu }
}

// MARK: - Một câu hỏi (FE hoặc PE)

struct KhungCauThi: View {
    @ObservedObject var vm: LamBaiVM
    let cau: CauHoiThi
    let coAI: Bool
    @Environment(\.ngonNguDe) private var ngonNgu

    private var c: CauHoiThi { cau }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            dauCau

            // Đề bài đi qua `NoiDungThi`: tách `|||`, dựng công thức KaTeX,
            // sơ đồ mermaid, bảng, ảnh và mã đã tô màu — đúng bộ của web.
            NoiDungThi(chu: c.prompt, coChu: 17, laDeBai: true)

            if let m = c.imageUrl, !m.isEmpty {
                // ⚠️ Qua `AnhCauHoi`, KHÔNG dựng `KFImage` thẳng: ảnh đề là ảnh
                // cắt tự động và có lượt cắt hỏng thành dải trắng rất cao.
                AnhCauHoi(duong: DuongDanThi.day(m)?.absoluteString ?? m)
            }

            if let e = c.expectedOutput, !e.isEmpty, c.laCode {
                KhoiMaNguon(ma: e, ngonNgu: nil, tieuDe: T("Kết quả mong đợi"), choChep: false)
            }

            if c.laCode {
                KhungCodeThi(vm: vm, cau: c)
            } else if c.laViet {
                KhungVietThi(vm: vm, cau: c)
            } else if c.laNoi {
                #if os(iOS)
                KhungNoiThi(vm: vm, ghiAm: vm.ghiAm, cau: c)
                #endif
            } else if let ds = c.options, !ds.isEmpty {
                if let sc = c.starterCode, !sc.isEmpty {
                    KhoiMaNguon(ma: sc, ngonNgu: c.language, tieuDe: nil, choChep: false)
                }
                VStack(spacing: Spacing.sm) {
                    ForEach(Array(ds.enumerated()), id: \.offset) { i, o in
                        ODapAnThi(chon: vm.chon[c.id]?.contains(i) ?? false,
                                  nhieu: c.chonNhieu, chuCai: chuCai(i), chu: o.text) {
                            vm.danhDau(c, i)
                        }
                    }
                }
            } else {
                Text(T("Câu này không có phương án nào để chọn — có thể đề đang được cập nhật. Bỏ qua và làm câu khác."))
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.backgroundCard))
            }

            // Bình luận theo câu — CHỈ trong phòng CuongMini, đúng như web.
            // Trong lượt thi tính điểm mà mở sẵn lời giải của người khác ngay
            // dưới đề thì không còn là thi nữa.
            if coAI && !vm.laPE {
                BinhLuanCauHoiView(questionId: c.id, toiLa: AppState.shared.currentUser?.id)
                    .id(c.id)
                // Chỗ trống cho nút nổi CuongMini khỏi che nút "Gửi".
                Color.clear.frame(height: 64)
            }
        }
    }

    private var dauCau: some View {
        HStack(spacing: Spacing.sm) {
            Text(nhanCau)
                .font(.caption.weight(.bold))
                .foregroundColor(AppColors.primary)
            if c.chonNhieu {
                Text(String(format: T("Chọn %d đáp án"), c.soDapAn))
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(AppColors.accent))
            }
            if c.laCode {
                Label(T("Lập trình") + (c.language.map { " · \($0)" } ?? ""), systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(LoaiDe.thucHanh.mau)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(LoaiDe.thucHanh.mau.opacity(0.12)))
            }
            if vm.co.contains(c.id) {
                Image(systemName: "flag.fill").font(.caption2).foregroundColor(AppColors.warning)
                    .accessibilityLabel(T("Đã gắn cờ"))
            }
            Spacer()
            if c.diem > 0 {
                Text(String(format: T("%@ điểm"), DinhDangSo.gon(c.diem)))
                    .font(.caption2).foregroundColor(AppColors.textTertiary)
            }
        }
    }

    private var nhanCau: String {
        if c.laNoi { return T("Đề nói") }
        return T("Câu") + " \(vm.viTri + 1)/\(vm.cauHoi.count)"
    }

    private func chuCai(_ i: Int) -> String {
        guard i >= 0, i < 26, let v = Unicode.Scalar(65 + i) else { return "\(i + 1)" }
        return String(Character(v))
    }
}

/// Một phương án trắc nghiệm.
struct ODapAnThi: View {
    let chon: Bool
    let nhieu: Bool
    let chuCai: String
    let chu: String
    let bam: () -> Void

    var body: some View {
        Button(action: bam) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                ZStack {
                    if nhieu {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(chon ? AppColors.primary : Color.clear)
                            .overlay(RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(chon ? AppColors.primary : AppColors.border, lineWidth: 1.5))
                    } else {
                        Circle()
                            .fill(chon ? AppColors.primary : Color.clear)
                            .overlay(Circle().strokeBorder(chon ? AppColors.primary : AppColors.border, lineWidth: 1.5))
                    }
                    if chon {
                        Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                    } else {
                        Text(chuCai).font(.system(size: 12, weight: .bold)).foregroundColor(AppColors.textSecondary)
                    }
                }
                .frame(width: 26, height: 26)
                // Đáp án cũng có thể mang `|||`, công thức hay mã — dùng chung
                // bộ dựng với đề bài; chuỗi thường thì vẽ bằng `Text`.
                NoiDungThi(chu: chu, coChu: 15)
                Spacer(minLength: 0)
            }
            .padding(Spacing.md)
            .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(chon ? AppColors.primary.opacity(0.10) : AppColors.backgroundCard)
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .strokeBorder(chon ? AppColors.primary : AppColors.border.opacity(0.6), lineWidth: chon ? 1.5 : 1)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.nhan)
        .accessibilityLabel(T("Phương án") + " \(chuCai): " + chu.tachSongNgu().lotTheHTMLThi)
        .accessibilityAddTraits(chon ? [.isSelected] : [])
    }
}

// MARK: - Danh sách câu (lưới)

/// Lưới câu: dùng ở tấm trượt (iPhone) và cột trái (iPad).
struct LuoiCauThiNoiDung: View {
    @ObservedObject var vm: LamBaiVM
    var cot: Int = 6
    let chonCau: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: cot), spacing: 8) {
                ForEach(Array(vm.cauHoi.enumerated()), id: \.element.id) { i, c in
                    oCau(i, c)
                }
            }
            HStack(spacing: Spacing.md) {
                chuThich(mau: AppColors.primary, chu: T("Đã làm"))
                chuThich(mau: AppColors.backgroundCard, chu: T("Chưa làm"), vien: true)
                HStack(spacing: 4) {
                    Circle().fill(AppColors.warning).frame(width: 8, height: 8)
                    Text(T("Cờ")).font(.caption2).foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(.top, 2)
        }
    }

    private func oCau(_ i: Int, _ c: CauHoiThi) -> some View {
        let lam: Bool = vm.daLam(c)
        let hien: Bool = i == vm.viTri
        let coCo: Bool = vm.co.contains(c.id)
        let nhan: String = c.laCode ? "\(i + 1)⌨" : "\(i + 1)"
        let mauChu: Color = lam ? .white : AppColors.textPrimary
        let mauNen: Color = lam ? AppColors.primary : AppColors.backgroundCard
        let mauVien: Color = hien ? AppColors.accent : AppColors.border.opacity(0.5)
        var tro: String = T("Câu") + " \(i + 1)"
        tro += lam ? ", " + T("đã trả lời") : ", " + T("chưa trả lời")
        if coCo { tro += ", " + T("có cờ") }
        return Button { chonCau(i) } label: {
            ZStack(alignment: .topTrailing) {
                Text(nhan)
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(mauChu)
                    .frame(maxWidth: .infinity).frame(height: 42)
                    .background(RoundedRectangle(cornerRadius: 10).fill(mauNen))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(mauVien, lineWidth: hien ? 2.5 : 1))
                if coCo {
                    Circle().fill(AppColors.warning).frame(width: 9, height: 9).offset(x: -4, y: 4)
                }
            }
        }
        .buttonStyle(.nhan)
        .accessibilityLabel(tro)
    }

    private func chuThich(mau: Color, chu: String, vien: Bool = false) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3).fill(mau).frame(width: 12, height: 12)
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(vien ? AppColors.border : .clear))
            Text(chu).font(.caption2).foregroundColor(AppColors.textTertiary)
        }
    }
}

struct LuoiCauThi: View {
    @ObservedObject var vm: LamBaiVM
    let dong: () -> Void
    @State private var chiCo = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                LuoiCauThiNoiDung(vm: vm) { i in
                    vm.viTri = i
                    dong()
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(String(format: T("Đã làm %d/%d"), vm.soDaLam, vm.cauHoi.count))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Cột trái trên iPad: lưới câu + tóm tắt + nút nộp — như thanh bên của web.
struct CotDieuHuongThi: View {
    @ObservedObject var vm: LamBaiVM
    let moNop: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(T("Danh sách câu"))
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(AppColors.textSecondary)
                LuoiCauThiNoiDung(vm: vm, cot: 5) { i in
                    withAnimation(.easeOut(duration: 0.18)) { vm.viTri = i }
                }
                if !vm.co.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(T("Câu đã gắn cờ"))
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(AppColors.textSecondary)
                        ForEach(Array(vm.cauHoi.enumerated()).filter { vm.co.contains($0.element.id) }, id: \.element.id) { i, c in
                            Button { withAnimation { vm.viTri = i } } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "flag.fill").font(.caption2).foregroundColor(AppColors.warning)
                                    Text(T("Câu") + " \(i + 1)").font(.footnote.weight(.medium))
                                    Text(c.prompt.tachSongNgu().lotTheHTMLThi)
                                        .font(.caption).foregroundColor(AppColors.textTertiary).lineLimit(1)
                                }
                                .foregroundColor(AppColors.textPrimary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Button(action: moNop) {
                    Text(T("Nộp bài"))
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 46)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.success))
                }
                .buttonStyle(.nhan)
                .disabled(vm.dangNop)
                if vm.laPE {
                    Text(T("AI chấm và trả kết quả ngay sau khi nộp."))
                        .font(.caption2).foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(Spacing.md)
        }
    }
}

// MARK: - Xác nhận nộp

struct XacNhanNopView: View {
    @ObservedObject var vm: LamBaiVM
    /// `nil` = đóng; số = nhảy tới câu đó.
    let dong: (Int?) -> Void
    let nop: () -> Void

    private var chuaLam: [(Int, CauHoiThi)] {
        Array(vm.cauHoi.enumerated()).filter { !vm.daLam($0.element) }
    }
    private var coCo: [(Int, CauHoiThi)] {
        Array(vm.cauHoi.enumerated()).filter { vm.co.contains($0.element.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    HStack(spacing: Spacing.md) {
                        o("\(vm.soDaLam)/\(vm.cauHoi.count)", T("đã làm"), AppColors.success)
                        o("\(chuaLam.count)", T("chưa làm"), chuaLam.isEmpty ? AppColors.textTertiary : AppColors.warning)
                        o("\(vm.co.count)", T("gắn cờ"), vm.co.isEmpty ? AppColors.textTertiary : AppColors.accent)
                        if vm.coDongHo {
                            o(String(format: "%d:%02d", vm.conLai / 60, vm.conLai % 60), T("còn lại"), AppColors.primary)
                        }
                    }

                    if vm.laPE { phanPE }

                    if !chuaLam.isEmpty && vm.loaiPE != "SPEAK" {
                        nhom(T("Chưa làm — bấm để quay lại"), chuaLam, mau: AppColors.warning)
                    }
                    if !coCo.isEmpty {
                        nhom(T("Đã gắn cờ"), coCo, mau: AppColors.accent)
                    }

                    Text(vm.laPE
                         ? T("Bài được gửi tới AI để chấm theo tiêu chí của đề; kết quả hiện ngay. Nộp rồi thì không sửa được.")
                         : (chuaLam.isEmpty ? T("Nộp rồi thì không sửa được.")
                            : T("Những câu chưa làm tính 0 điểm. Nộp rồi thì không sửa được.")))
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Spacing.md)
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle(T("Nộp bài?"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Làm tiếp")) { dong(nil) } }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: nop) {
                    Text(T("Nộp bài"))
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.success))
                }
                .buttonStyle(.nhan)
                .padding(Spacing.md)
                .background(.bar)
            }
        }
    }

    @ViewBuilder private var phanPE: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch vm.loaiPE {
            case "CODE":
                Text(vm.zipChon != nil ? T("Sẽ nộp tệp bạn đã chọn:") : T("Sẽ đóng gói thành .zip:"))
                    .font(.footnote.weight(.semibold))
                if vm.tepSeNop.isEmpty {
                    Text(T("Chưa có tệp nào — hãy gõ code hoặc chọn tệp .zip."))
                        .font(.footnote).foregroundColor(AppColors.error)
                } else {
                    Text(vm.tepSeNop.joined(separator: " · "))
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundColor(AppColors.textSecondary)
                }
            case "WRITE":
                ForEach(Array(vm.cauHoi.enumerated()).filter { $0.element.laViet }, id: \.element.id) { i, c in
                    let tu = (vm.baiViet[c.id] ?? "").split { $0.isWhitespace || $0.isNewline }.count
                    Text(String(format: T("Câu %d: %d từ"), i + 1, tu) + (vm.anhSoDo[c.id] != nil ? " · " + T("có ảnh sơ đồ") : ""))
                        .font(.footnote).foregroundColor(AppColors.textSecondary)
                }
            case "SPEAK":
                #if os(iOS)
                Text(String(format: T("Đã thu %d/%d câu trả lời."), vm.ghiAm.tep.count, vm.cauNoi.count))
                    .font(.footnote).foregroundColor(vm.ghiAm.tep.isEmpty ? AppColors.error : AppColors.textSecondary)
                #endif
            default: EmptyView()
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.backgroundCard))
    }

    private func o(_ so: String, _ nhan: String, _ mau: Color) -> some View {
        VStack(spacing: 2) {
            Text(so).font(.system(.title3, design: .rounded).weight(.bold)).foregroundColor(mau).monospacedDigit()
            Text(nhan).font(.caption2).foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.backgroundCard))
    }

    private func nhom(_ tieuDe: String, _ ds: [(Int, CauHoiThi)], mau: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tieuDe).font(.footnote.weight(.semibold)).foregroundColor(AppColors.textSecondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(ds, id: \.1.id) { i, _ in
                    Button { dong(i) } label: {
                        Text("\(i + 1)")
                            .font(.system(size: 14, weight: .semibold)).monospacedDigit()
                            .foregroundColor(mau)
                            .frame(maxWidth: .infinity).frame(height: 38)
                            .background(RoundedRectangle(cornerRadius: 9).fill(mau.opacity(0.12)))
                    }
                    .buttonStyle(.nhan)
                    .accessibilityLabel(T("Tới câu") + " \(i + 1)")
                }
            }
        }
    }
}

// MARK: - Kết quả

struct KetQuaView: View {
    let kq: XemLaiBaiThi
    let de: DeThi
    var baiDaNop: [Int: String] = [:]
    var ghiChu: String?
    let dong: () -> Void
    @Environment(\.ngonNguDe) private var ngonNgu
    @State private var hien = false

    private var tiLe: Double { kq.tongDiem > 0 ? kq.diem / kq.tongDiem : 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                ZStack {
                    Circle().stroke(AppColors.backgroundTertiary, lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: hien ? tiLe : 0)
                        .stroke(kq.dat ? AppColors.success : AppColors.warning,
                                style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.9), value: hien)
                    VStack(spacing: 0) {
                        Text(DinhDangSo.gon(kq.diem))
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.textPrimary)
                        Text("/ " + DinhDangSo.gon(kq.tongDiem))
                            .font(.subheadline).foregroundColor(AppColors.textTertiary)
                    }
                }
                .frame(width: 168, height: 168)
                .padding(.top, Spacing.xl)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(format: T("Điểm %@ trên %@"), DinhDangSo.gon(kq.diem), DinhDangSo.gon(kq.tongDiem)))

                Label(kq.dat ? T("Đạt") : T("Chưa đạt"),
                      systemImage: kq.dat ? "checkmark.seal.fill" : "arrow.triangle.2.circlepath")
                    .font(.title3.weight(.bold))
                    .foregroundColor(kq.dat ? AppColors.success : AppColors.warning)

                if let dung = kq.soDung, let tong = kq.soCau, tong > 0 {
                    Text(String(format: T("Đúng %d/%d câu trắc nghiệm"), dung, tong))
                        .font(.subheadline).foregroundColor(AppColors.textSecondary)
                }
                if kq.laPE {
                    Text(T("AI đã chấm theo tiêu chí của đề — xem nhận xét từng câu bên dưới."))
                        .font(.footnote).foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Text(de.ten(ngonNgu))
                    .font(.footnote)
                    .foregroundColor(AppColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)

                if let g = ghiChu {
                    Label(g, systemImage: "info.circle")
                        .font(.footnote).foregroundColor(AppColors.warning)
                        .padding(Spacing.md)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.warning.opacity(0.1)))
                        .padding(.horizontal, Spacing.lg)
                }

                // Đáp án đúng + lời giải TỪNG câu đã nằm sẵn trong phản hồi
                // nộp bài, nên nút này không tốn thêm lời gọi mạng nào.
                NavigationLink {
                    XemLaiView(xemLai: kq, tenDe: de.title, baiDaNop: baiDaNop)
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "list.bullet.rectangle.portrait")
                        Text(T("Xem lại từng câu")).font(.body.weight(.semibold))
                    }
                    .foregroundColor(AppColors.primary)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(Capsule().strokeBorder(AppColors.primary.opacity(0.5), lineWidth: 1.5))
                }
                .buttonStyle(.nhan)
                .padding(.horizontal, Spacing.lg)

                Button(action: dong) {
                    Text(T("Xong"))
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Capsule().fill(AppColors.primary))
                }
                .buttonStyle(.nhan)
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .onAppear { hien = true }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Tiện ích

enum DinhDangSo {
    /// 10 → "10", 7.5 → "7.5", 6.67 → "6.67".
    static func gon(_ v: Double) -> String {
        if v == v.rounded() { return String(Int(v)) }
        let s = String(format: "%.2f", v)
        var t = s
        while t.hasSuffix("0") { t.removeLast() }
        if t.hasSuffix(".") { t.removeLast() }
        return t
    }
}

extension String {
    /// Lột thẻ HTML cho nhãn trợ năng / dòng tóm tắt một dòng.
    var lotTheHTMLThi: String {
        replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
