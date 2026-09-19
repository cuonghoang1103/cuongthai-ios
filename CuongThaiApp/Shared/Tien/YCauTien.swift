import AppIntents
import Foundation

// ════════════════════════════════════════════════════════════════
// SIRI & PHÍM TẮT cho Tiền nong.
//
// Đặt trong TARGET CHÍNH, không tách extension riêng: chạy trong tiến trình
// app thì dùng lại được phiên đăng nhập trong Keychain. Tách ra là phải chia
// khoá sang một tiến trình nữa — thêm một chỗ rò, đổi lấy đúng vài trăm mili
// giây khởi động.
//
// Mục đích: ghi một khoản chi mà KHÔNG phải mở app. Nhắc 8h/12h/19h và mục
// tiêu chi tiêu chỉ có giá trị nếu chỗ GHI VÀO đủ nhanh; bắt mở app → vào
// Tiền nong → bấm thêm → điền, thì vài hôm là người ta bỏ.
// ════════════════════════════════════════════════════════════════

// MARK: - Ví

struct ViYCau: AppEntity {
    let id: Int
    let ten: String
    let soDu: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Ví" }
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(ten)", subtitle: "\(soDu)")
    }
    static var defaultQuery = ViTimKiem()
}

struct ViTimKiem: EntityQuery {
    func entities(for ids: [Int]) async throws -> [ViYCau] {
        try await moiVi().filter { ids.contains($0.id) }
    }
    func suggestedEntities() async throws -> [ViYCau] { try await moiVi() }

    private func moiVi() async throws -> [ViYCau] {
        try await TienAPI.dsVi()
            .filter { !$0.isArchived }
            .map { ViYCau(id: $0.id, ten: $0.name,
                          soDu: DinhDangTien.day($0.balance, $0.currency)) }
    }
}

// MARK: - Nhóm chi

struct NhomChiYCau: AppEntity {
    let id: Int
    let ten: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Nhóm chi" }
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(ten)") }
    static var defaultQuery = NhomChiTimKiem()
}

struct NhomChiTimKiem: EntityQuery {
    func entities(for ids: [Int]) async throws -> [NhomChiYCau] {
        try await moiNhom().filter { ids.contains($0.id) }
    }
    func suggestedEntities() async throws -> [NhomChiYCau] { try await moiNhom() }

    private func moiNhom() async throws -> [NhomChiYCau] {
        try await TienAPI.dsNhomChi().map { NhomChiYCau(id: $0.id, ten: $0.name) }
    }
}

// MARK: - Ghi một khoản chi

struct GhiChiTieuYCau: AppIntent {
    static var title: LocalizedStringResource = "Ghi một khoản chi"
    static var description = IntentDescription(
        "Ghi nhanh một khoản chi vào Tiền nong mà không cần mở app.")
    /// Không mở app: cả điểm của việc này là ghi xong trong hai giây.
    static var openAppWhenRun = false

    @Parameter(title: "Số tiền") var soTien: Double
    @Parameter(title: "Nhóm chi") var nhom: NhomChiYCau
    @Parameter(title: "Ví") var vi: ViYCau
    @Parameter(title: "Ghi chú") var ghiChu: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Ghi \(\.$soTien) vào \(\.$nhom), trừ từ \(\.$vi)") {
            \.$ghiChu
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard soTien > 0 else {
            return .result(dialog: "Số tiền phải lớn hơn 0.")
        }
        _ = try await TienAPI.themChi(nhomId: nhom.id, viId: vi.id, soTien: soTien,
                                      ngay: NgayTien.homNay(), moTa: ghiChu)

        // Cập nhật ảnh chụp cho widget bằng số của MÁY CHỦ, không tự cộng
        // thêm ở máy: cộng tay thì mỗi lần ghi lệch một ít, và sau vài ngày
        // widget nói một đằng app nói một nẻo mà không ai biết bên nào đúng.
        await capNhatAnhChup()

        let chu = DinhDangTien.day(soTien)
        return .result(dialog: "Đã ghi \(chu) vào \(nhom.ten).")
    }

    private func capNhatAnhChup() async {
        guard var a = KhoAnhChupTien.doc() else { return }
        if let mt = try? await TienAPI.mucTieu().mucTieu.first(where: { $0.ky == "DAY" }) {
            a.chiHomNay = mt.daTieu
            a.hanMucNgay = mt.mucTieu
            a.chiHomNayChu = DinhDangTien.ngan(mt.daTieu)
            a.hanMucNgayChu = DinhDangTien.ngan(mt.mucTieu)
            a.nhanChi = "Chi hôm nay"
        }
        a.luc = Date()
        KhoAnhChupTien.ghi(a)
        LamMoiWidget.ngay()
    }
}

// MARK: - Hỏi nhanh tình hình nợ

struct XemNoYCau: AppIntent {
    static var title: LocalizedStringResource = "Xem nợ và lãi"
    static var description = IntentDescription("Tổng dư nợ, lãi mỗi tháng và kỳ sắp phải trả.")
    static var openAppWhenRun = false

    /// ⚠️ Đọc ẢNH CHỤP, không gọi mạng. Câu hỏi này phải trả lời được cả khi
    /// mất sóng — và nó thường được hỏi lúc đang đứng ở quầy thanh toán.
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let a = KhoAnhChupTien.doc() else {
            return .result(dialog: "Chưa có số liệu. Mở Tiền nong một lần rồi hỏi lại nhé.")
        }
        var cau = "Bạn còn nợ \(a.duNo), lãi \(a.laiMoiThang) mỗi tháng."
        if let k = a.kyToi.first {
            let f = DateFormatter()
            f.dateFormat = "dd/MM"
            f.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
            cau += k.quaHan
                ? " \(k.ten) đã QUÁ HẠN, \(k.soTien)."
                : " Kỳ gần nhất: \(k.ten) \(k.soTien) ngày \(f.string(from: k.ngay))."
        }
        return .result(dialog: IntentDialog(stringLiteral: cau))
    }
}

// MARK: - Câu gọi Siri

struct PhimTatCuongThai: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GhiChiTieuYCau(),
            phrases: [
                "Ghi chi tiêu với \(.applicationName)",
                "Ghi một khoản chi với \(.applicationName)",
                "Thêm khoản chi vào \(.applicationName)",
            ],
            shortTitle: "Ghi chi tiêu",
            systemImageName: "cart.badge.plus")

        AppShortcut(
            intent: XemNoYCau(),
            phrases: [
                "Tôi còn nợ bao nhiêu trong \(.applicationName)",
                "Xem nợ trong \(.applicationName)",
            ],
            shortTitle: "Xem nợ & lãi",
            systemImageName: "percent")
    }
}
