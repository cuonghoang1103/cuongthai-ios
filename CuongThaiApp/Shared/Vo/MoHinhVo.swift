import Foundation
import SwiftData

// MARK: - Cây dữ liệu của Vở
//
// Ba tầng, khớp 1-1 với ba bảng đã có sẵn ở backend (`notes.routes.ts`):
//
//   MonVo   ↔ NoteSubject   (Toán, Tiếng Nhật, Vật lý…)
//   CuonVo  ↔ NoteChapter   (một cuốn vở: "Học kỳ 1", "Chương Đạo hàm")
//   TrangVo ↔ Note          (MỘT TRANG GIẤY = MỘT `Note`)
//
// ⚠️ Vì sao một trang giấy lại là một `Note` chứ không phải bảng mới: `Note`
// đã mang sẵn `sortOrder`, `version`, lịch sử `NoteVersion`, thùng rác 30
// ngày, chia sẻ và đính kèm. Dựng bảng riêng cho trang ink là bỏ hết những
// thứ đó rồi viết lại. Đợt 2 chỉ cần thêm vài cột ink vào `Note`.
//
// "Chương" mà người dùng thấy trong mục lục KHÔNG phải một tầng thư mục nữa:
// nó là nhãn `tenChuong` đặt trên trang mở đầu chương, đúng như vở giấy —
// bạn không tạo thư mục, bạn viết tiếp rồi ghi "Chương 2" lên đầu trang.

// MARK: Môn

@Model
final class MonVo {
    // `#Index` bỏ ở đây: nó chỉ có từ iOS 18, mà app còn nhận iOS 17. Với
    // vài chục môn thì chỉ mục không đổi được gì đo được.
    var id: UUID = UUID()
    var ten: String = ""
    var emoji: String = "📘"
    /// Màu gáy vở, dạng `0xRRGGBB` để đối chiếu thẳng với bảng màu của web.
    var mauHex: Int = 0x7A45E8
    var thuTu: Int = 0
    var ghim: Bool = false
    var taoLuc: Date = Date()
    var suaLuc: Date = Date()

    /// `NoteSubject.id` trên máy chủ. `nil` = chưa từng đồng bộ.
    var idMayChu: Int?
    /// Cây (tên/thứ tự/màu) có thay đổi chưa đẩy.
    var canDayCay: Bool = true

    @Relationship(deleteRule: .cascade, inverse: \CuonVo.mon)
    var cuons: [CuonVo]? = []

    init(ten: String, emoji: String = "📘", mauHex: Int = 0x7A45E8, thuTu: Int = 0) {
        self.id = UUID()
        self.ten = ten
        self.emoji = emoji
        self.mauHex = mauHex
        self.thuTu = thuTu
        self.taoLuc = Date()
        self.suaLuc = Date()
    }

    /// SwiftData trả quan hệ là optional. Mọi chỗ đọc đều đi qua đây để khỏi
    /// rải `?? []` khắp nơi, và để luôn ra đúng thứ tự người dùng đã xếp.
    var cuonsTheoThuTu: [CuonVo] {
        (cuons ?? []).sorted { a, b in
            if a.ghim != b.ghim { return a.ghim }
            return a.thuTu < b.thuTu
        }
    }
}

// MARK: Cuốn vở

@Model
final class CuonVo {
    var id: UUID = UUID()
    var ten: String = ""
    /// Bìa vở: màu nền + hoạ tiết. Giữ đơn giản ở Đợt 1 — một màu.
    var mauBiaHex: Int = 0x7A45E8
    var thuTu: Int = 0
    var ghim: Bool = false
    var taoLuc: Date = Date()
    var suaLuc: Date = Date()
    var idMayChu: Int?
    /// Cây (tên/thứ tự/bìa) có thay đổi chưa đẩy.
    var canDayCay: Bool = true

    /// Giấy mặc định cho trang mới trong cuốn này. Đặt ở cuốn chứ không ở
    /// từng trang vì người ta chọn một lần lúc lập vở rồi thôi — nhưng từng
    /// trang vẫn đè được (`TrangVo.loaiGiay`).
    var giayMacDinh: String = LoaiGiay.keNgang.rawValue
    var huongMacDinh: String = HuongGiay.doc.rawValue

    /// Khổ giấy của CẢ cuốn (`KhoGiay.rawValue`). `nil` = A4 — mọi cuốn lập
    /// trước 28/09/2026.
    ///
    /// ⚠️ Thêm vào model ĐÃ có dữ liệu thật: phải OPTIONAL để SwiftData tự
    /// nâng kho cũ (xem ghi chú ở `TrangVo.tieuDe`). Đặt ở CUỐN chứ không ở
    /// từng trang: người dùng xin "chỉnh một trang thì cả cuốn theo" — vở
    /// thật cũng một khổ từ đầu tới cuối. Trang nào cần khác thì có
    /// `TrangVo.khoGiayRieng`.
    var khoGiay: String?

    /// VỞ LÀM BÀI (02/10/2026): tắt mọi AI (trợ lý, bút AI, viết lại, vẽ giúp,
    /// tóm tắt, làm gọn) và không nhận ảnh/PDF — chữ trên trang phải là chữ tự
    /// viết; có nút 📤 Nộp bài sang Huấn luyện học kỳ. MỘT CHIỀU: bật rồi không
    /// tắt được (không thì lách được). OPTIONAL để SwiftData tự nâng kho cũ.
    var voLamBai: Bool?

    /// Trang đang đọc dở. Mở lại vở là về đúng chỗ bỏ bút xuống — với cuốn
    /// 200 trang thì quay về trang 1 mỗi lần mở là thứ khiến người ta bỏ app.
    var trangDangDoc: Int = 0

    var mon: MonVo?

    @Relationship(deleteRule: .cascade, inverse: \TrangVo.cuon)
    var trangs: [TrangVo]? = []

    init(ten: String, mon: MonVo?, mauBiaHex: Int = 0x7A45E8,
         giay: LoaiGiay = .keNgang, huong: HuongGiay = .doc, thuTu: Int = 0) {
        self.id = UUID()
        self.ten = ten
        self.mon = mon
        self.mauBiaHex = mauBiaHex
        self.giayMacDinh = giay.rawValue
        self.huongMacDinh = huong.rawValue
        self.thuTu = thuTu
        self.taoLuc = Date()
        self.suaLuc = Date()
    }

    var trangsTheoThuTu: [TrangVo] {
        (trangs ?? []).sorted { $0.thuTu < $1.thuTu }
    }

    /// Khổ của cuốn, đã đọc ra enum (giá trị lạ/`nil` ⇒ A4).
    var kho: KhoGiay { KhoGiay(rawValue: khoGiay ?? "") ?? .a4 }

    var soTrang: Int { (trangs ?? []).count }

    /// Mục lục tự sinh: những trang có đặt tên chương.
    var mucLuc: [TrangVo] {
        trangsTheoThuTu.filter { !($0.tenChuong ?? "").isEmpty }
    }
}

// MARK: Trang

@Model
final class TrangVo {
    var id: UUID = UUID()
    var thuTu: Int = 0
    /// Nhãn chương đặt trên trang này (tuỳ chọn) — nguồn của mục lục.
    var tenChuong: String?
    /// Tên trang người dùng đặt ("Đổi tên trang"). `nil` ⇒ hiện "Trang N".
    ///
    /// ⚠️ Thêm 28/09/2026 vào một model ĐÃ có dữ liệu thật trên iPad. Phải là
    /// OPTIONAL (hoặc có giá trị mặc định) thì SwiftData mới tự nâng kho cũ
    /// lên được — thuộc tính bắt buộc không mặc định là kho mở hỏng, app lùi
    /// sang kho tạm trong bộ nhớ, và người dùng thấy vở TRỐNG. Đừng đổi tên
    /// hay bỏ thuộc tính nào đã lưu; muốn đổi thì thêm cái mới.
    var tieuDe: String?
    var loaiGiay: String = LoaiGiay.keNgang.rawValue
    var huongGiay: String = HuongGiay.doc.rawValue
    var danhDau: Bool = false
    var taoLuc: Date = Date()
    var suaLuc: Date = Date()
    var idMayChu: Int?

    /// Số byte của tệp nét vẽ lần ghi gần nhất. Dùng để biết trang có trống
    /// hay không mà KHÔNG phải nạp cả `PKDrawing` lên bộ nhớ — dải trang bên
    /// trái hiện hàng chục trang một lúc, nạp hết là app khựng.
    var coNet: Bool = false

    /// Văn bản mà máy đọc được từ nét viết tay — nguồn của tìm kiếm.
    var chuNhanDang: String?
    /// Lúc nhận dạng gần nhất, để biết chữ đã cũ so với nét hay chưa.
    var nhanDangLuc: Date?

    // ─── Nền trang: PDF hoặc ảnh quét ───────────────────────────────────
    /// Tên tệp PDF trong `Documents/Vo/nen/`. Nền là TỆP RIÊNG chứ không
    /// nhúng vào từng trang: một tệp slide 40 trang thì 40 trang vở dùng
    /// chung một tệp, chép 40 bản là phí chỗ và chậm.
    var nenPdfTen: String?
    /// Trang thứ mấy trong tệp PDF đó (đếm từ 0).
    var nenPdfTrang: Int = 0
    /// Tên tệp ảnh nền (trang sách chụp/quét) trong cùng thư mục.
    var nenAnhTen: String?

    /// Khoá R2 của tệp nền sau khi đã đẩy lên.
    ///
    /// ⚠️ Có giá trị nghĩa là nền ĐÃ lên mây và máy khác tải về được. Nil mà
    /// `nenPdfTen`/`nenAnhTen` có giá trị nghĩa là nền mới chỉ nằm trên máy
    /// này — đó chính là lỗ hổng trước 18/09/2026: người dùng chú thích cả
    /// học kỳ lên giáo trình, mở máy khác ra thì nét bút trôi trên giấy
    /// trắng vì tệp nền chưa từng rời khỏi iPad.
    var nenKhoaR2: String?
    /// "pdf" hoặc "img" — máy chủ cần biết để trả đúng loại về.
    var nenLoaiR2: String?

    // ─── Ghi âm buổi học ────────────────────────────────────────────────
    /// Tên tệp ghi âm (m4a) trong `Documents/Vo/tieng/`, nếu trang này có.
    var ghiAmTen: String?
    var ghiAmDai: Double = 0
    /// Mốc thời gian (giây tính từ đầu bản ghi) của TỪNG NÉT trên trang,
    /// theo đúng thứ tự nét trong `PKDrawing`.
    ///
    /// Đây là thứ làm nên "chạm vào chữ → nhảy tới đoạn giảng lúc viết chữ
    /// đó". Lưu mảng số thay vì bảng riêng: nó luôn đi cùng đúng một trang,
    /// và số nét một trang hiếm khi quá vài trăm.
    var mocNet: [Double] = []

    // ─── Đồng bộ ────────────────────────────────────────────────────────
    /// Phiên bản nét vẽ trên MÁY CHỦ mà bản cục bộ này đang dựa trên. Gửi
    /// kèm mỗi lượt đẩy; máy chủ so với bản nó giữ để biết có ai ghi chen
    /// vào giữa không.
    var phienBanNet: Int = 0
    /// Số nét tại thời điểm đẩy thành công lần cuối. Đây là RANH GIỚI để
    /// hợp nhất khi xung đột: những nét từ vị trí này trở đi là phần máy
    /// này viết thêm mà máy chủ chưa có.
    var soNetDaDay: Int = 0
    /// Có thay đổi chưa đẩy. Đặt khi lưu, gỡ khi đẩy xong.
    var canDay: Bool = true
    /// Lượt đẩy gần nhất vấp xung đột và chưa giải quyết — màn viết hiện
    /// cảnh báo, và KHÔNG tự ghi đè bản trên máy chủ.
    var vuongXungDot: Bool = false
    var dayLuc: Date?
    /// Nét CŨ đã bị viết lại (Làm gọn chữ) kể từ lần đẩy gần nhất.
    ///
    /// Hợp nhất xung đột dựa trên TIỀN TỐ NÉT: "`soNetDaDay` nét đầu hai bên
    /// cùng có". Làm gọn giữ nguyên SỐ nét nhưng đổi NỘI DUNG từng nét, nên
    /// phép đếm vẫn nói "chỉ vẽ thêm" — và nếu máy khác vừa ghi trang này, bản
    /// gộp sẽ lấy tiền tố của máy chủ, lặng lẽ vứt cả trang đã làm gọn. Cờ này
    /// bắt nhánh đó đi đường an toàn: giữ CẢ HAI thành hai trang.
    ///
    /// ⚠️ Thêm 28/09/2026 vào model đã có dữ liệu: phải có giá trị mặc định
    /// (xem ghi chú ở `tieuDe`).
    var daVietLaiNet: Bool = false

    // ─── Khổ trang (28/09/2026) ─────────────────────────────────────────
    /// Phần NỐI DÀI thêm dưới đáy trang, theo point. 0 = đúng khổ của cuốn.
    ///
    /// Người dùng: "trang vở nhìn nhỏ quá, viết được tý là hết". Nối dài
    /// giữ nguyên toạ độ nét (gốc ở góc trên-trái), chỉ thêm giấy ở dưới —
    /// không có nét nào phải dời chỗ. ⚠️ Mặc định 0 ⇒ kho cũ nâng được.
    var chieuCaoThem: Double = 0
    /// Khổ RIÊNG của trang này (`KhoGiay.rawValue`), đè khổ của cuốn.
    ///
    /// Chỉ dùng khi đổi khổ cả cuốn sang khổ HẸP hơn mà trang này có nét nằm
    /// ngoài khổ mới: trang đó giữ khổ cũ thay vì bị cắt mất nét. `nil` =
    /// theo cuốn.
    var khoGiayRieng: String?

    var cuon: CuonVo?

    init(cuon: CuonVo?, thuTu: Int, giay: LoaiGiay, huong: HuongGiay) {
        self.id = UUID()
        self.cuon = cuon
        self.thuTu = thuTu
        self.loaiGiay = giay.rawValue
        self.huongGiay = huong.rawValue
        self.taoLuc = Date()
        self.suaLuc = Date()
    }

    var giay: LoaiGiay { LoaiGiay(rawValue: loaiGiay) ?? .keNgang }
    var huong: HuongGiay { HuongGiay(rawValue: huongGiay) ?? .doc }

    /// Trang có nền tài liệu (PDF / ảnh quét) — khổ theo tài liệu, không
    /// theo cuốn.
    ///
    /// ⚠️ Lớp chữ "✍️ AI viết lại" (`nenPdfTrang == trangLopChuAI`) KHÔNG phải
    /// tài liệu: nó dựng đúng theo khổ + dòng kẻ của cuốn, nên khổ trang phải
    /// theo cuốn chứ không bị ép về A4 như ảnh quét.
    var coNenTaiLieu: Bool {
        nenPdfTen != nil || (nenAnhTen != nil && nenPdfTrang != TrangVo.trangLopChuAI)
    }

    /// Giá trị `nenPdfTrang` đánh dấu nền ảnh là LỚP CHỮ do "✍️ AI viết lại"
    /// dựng (PNG trong suốt), không phải trang sách quét. Với nền ảnh, số
    /// trang PDF vốn vô nghĩa, và máy chủ đã lưu/trả nguyên số này (`bgPage`)
    /// ⇒ đồng bộ sang máy khác KHÔNG cần cột mới. Đừng đổi số này: trang đã
    /// lưu trên máy chủ mang đúng giá trị cũ.
    static let trangLopChuAI = 1_000_000

    /// Khổ giấy đang áp cho trang (của riêng trang, hoặc của cuốn).
    var khoGiayApDung: KhoGiay {
        if let r = khoGiayRieng, let k = KhoGiay(rawValue: r) { return k }
        return cuon?.kho ?? .a4
    }

    /// Khổ GỐC — chưa tính phần nối dài. Nền tài liệu (PDF/ảnh) vẽ vừa đúng
    /// khung này, nên nối dài trang không kéo méo trang PDF.
    ///
    /// ⚠️ Trang có nền tài liệu GIỮ khổ cũ (A4 theo hướng của tài liệu): nét
    /// chú thích đã nằm đúng chỗ trên đề bài, đổi khổ cuốn mà co giãn nền là
    /// mọi nét lệch khỏi chữ nó chú thích.
    var khoGoc: CGSize {
        coNenTaiLieu ? huong.khoA4 : khoGiayApDung.kho(huong)
    }

    /// Khổ THẬT của trang tính bằng point (1pt = 1/72 inch): khổ gốc + phần
    /// nối dài. Mọi chỗ dựng ảnh / xuất PDF / đặt nét phải dùng số này, không
    /// mặc định A4.
    var khoTrang: CGSize {
        let g = khoGoc
        return CGSize(width: g.width, height: g.height + CGFloat(max(0, chieuCaoThem)))
    }

    /// Nối dài tối đa bao nhiêu — 4× chiều cao gốc là cả tờ giấy cuộn, quá
    /// nữa thì dải trang và PDF xuất ra thành một sợi mì.
    var chieuCaoThemToiDa: Double { Double(khoGoc.height) * 3 }
    var noiDaiDuoc: Bool { chieuCaoThem + 1 < chieuCaoThemToiDa }

    /// Nối thêm nửa trang (không vượt trần). Trả về có đổi hay không.
    @discardableResult
    func noiDaiNuaTrang() -> Bool {
        guard noiDaiDuoc else { return false }
        let buoc = (Double(khoGoc.height) / 2).rounded()
        chieuCaoThem = min(chieuCaoThemToiDa, chieuCaoThem + buoc)
        suaLuc = Date()
        return true
    }
}

// MARK: - Khổ giấy

/// Khổ giấy của một cuốn vở. Kích thước theo point (72 point = 1 inch), cạnh
/// NGẮN trước — `kho(_:)` xoay theo hướng giấy.
enum KhoGiay: String, CaseIterable, Identifiable {
    case a5, b5, a4, letter, b4, a3
    /// Khổ màn chiếu 16:9 — luôn NẰM NGANG, hợp chép slide.
    case rong169
    /// Bảng lớn: gần gấp đôi A3 theo cạnh, tỉ lệ √2 như khổ A.
    case bangLon

    var id: String { rawValue }

    var ten: String {
        switch self {
        case .a5: return "A5"
        case .b5: return "B5"
        case .a4: return "A4"
        case .letter: return "Letter"
        case .b4: return "B4"
        case .a3: return "A3"
        case .rong169: return T("Rộng 16:9")
        case .bangLon: return T("Bảng lớn")
        }
    }

    var moTa: String {
        switch self {
        case .a5: return T("148×210 mm · sổ tay nhỏ")
        case .b5: return T("176×250 mm · vở học sinh")
        case .a4: return T("210×297 mm · mặc định")
        case .letter: return T("216×279 mm · khổ Mỹ")
        case .b4: return T("250×353 mm · rộng hơn A4 một nấc")
        case .a3: return T("297×420 mm · gấp đôi A4")
        case .rong169: return T("Màn chiếu 16:9 · chép slide")
        case .bangLon: return T("Như bảng trắng · sơ đồ, bài dài")
        }
    }

    /// Khổ theo hướng DỌC (rộng < cao), riêng 16:9 là khổ ngang sẵn.
    private var goc: CGSize {
        switch self {
        case .a5: return CGSize(width: 420, height: 595)
        case .b5: return CGSize(width: 499, height: 709)
        case .a4: return CGSize(width: 595, height: 842)
        case .letter: return CGSize(width: 612, height: 792)
        case .b4: return CGSize(width: 709, height: 1001)
        case .a3: return CGSize(width: 842, height: 1191)
        case .rong169: return CGSize(width: 1280, height: 720)
        case .bangLon: return CGSize(width: 1600, height: 2263)
        }
    }

    /// Khổ theo hướng giấy. 16:9 bỏ qua hướng — dựng dọc thì nó thành một
    /// dải hẹp dài, không còn là "rộng".
    func kho(_ huong: HuongGiay) -> CGSize {
        if self == .rong169 { return goc }
        return huong == .doc ? goc : CGSize(width: goc.height, height: goc.width)
    }
}

// MARK: - Tiến độ luyện viết

/// Một chữ đã luyện viết bao nhiêu lần, đúng bao nhiêu.
///
/// Để ở kho CỤC BỘ chứ không đẩy lên máy chủ: tiến độ luyện nét là thứ đo
/// từng ngày, ghi rất dày, và mất cũng không tiếc như mất một trang vở.
/// Đẩy nó lên cùng đường đồng bộ của Vở chỉ tổ làm mỗi lượt đẩy nặng thêm.
@Model
final class TienDoChu {
    var id: UUID = UUID()
    /// Chính chữ đó, ví dụ "あ" hay "日".
    var chu: String = ""
    var lang: String = "ja"
    var soLanDung: Int = 0
    var soLanThu: Int = 0
    var lanCuoi: Date?

    /// Coi như đã thuộc sau 3 lượt viết đúng. Con số này là quy ước, không
    /// phải đo đạc — nhưng có một mốc rõ ràng thì lưới chữ mới nói được
    /// "còn bao nhiêu chữ nữa", và đó là thứ giữ người học đi tiếp.
    var daThuoc: Bool { soLanDung >= 3 }

    init(chu: String, lang: String) {
        self.id = UUID()
        self.chu = chu
        self.lang = lang
    }
}

// MARK: - Hàng đợi xoá

/// Một lệnh xoá CHƯA báo được lên máy chủ.
///
/// ⚠️ Vì sao phải có bảng riêng thay vì gọi API ngay lúc người dùng bấm xoá:
/// xoá lúc máy bay / mất sóng thì lời gọi hỏng, bản ghi cục bộ đã biến mất,
/// và **không còn gì để thử lại**. Lượt kéo về kế tiếp thấy trang vẫn nằm
/// trên máy chủ và mang nó SỐNG LẠI. Người dùng xoá xong thấy nó quay về,
/// xoá lần nữa, nó lại quay về.
///
/// Hàng đợi này sống trong kho cục bộ nên qua được cả lần tắt máy, và
/// `DongBoVo` xả nó TRƯỚC khi kéo về.
@Model
final class ViecXoaCho {
    var id: UUID = UUID()
    /// `clientId` của thứ bị xoá.
    var maDoiTuong: String = ""
    /// `"trang"` hoặc `"cuon"`.
    var loai: String = "trang"
    var taoLuc: Date = Date()
    /// Số lần thử hỏng. Quá nhiều lần thì thôi, đừng thử mãi mỗi lượt đồng bộ.
    var soLanHong: Int = 0

    init(maDoiTuong: String, loai: String) {
        self.id = UUID()
        self.maDoiTuong = maDoiTuong
        self.loai = loai
        self.taoLuc = Date()
    }
}

// MARK: - Giấy

enum LoaiGiay: String, Codable, CaseIterable, Identifiable {
    case trang
    case keNgang
    case oLy
    case cham
    case cornell
    case genkou
    case nhacLy
    /// Giấy tập viết tiếng Anh: mỗi hàng 4 dòng (đỉnh chữ hoa · đường giữa
    /// nét đứt · dòng chân · đuôi chữ g/y) — thêm 28/09/2026.
    case bonDong
    /// Lưới viết code tay: cột số dòng bên trái + ô vuông nhỏ canh thụt lề.
    case luoiCode

    var id: String { rawValue }

    var ten: String {
        switch self {
        case .trang:   return T("Trang trơn")
        case .keNgang: return T("Kẻ ngang")
        case .oLy:     return T("Ô ly")
        case .cham:    return T("Chấm")
        case .cornell: return T("Cornell")
        case .genkou:  return T("Ô vuông (tiếng Nhật)")
        case .nhacLy:  return T("Khuông nhạc")
        case .bonDong: return T("4 dòng tập viết (tiếng Anh)")
        case .luoiCode: return T("Lưới viết code")
        }
    }

    var moTa: String {
        switch self {
        case .trang:   return T("Không dòng kẻ — vẽ sơ đồ, ghi tự do")
        case .keNgang: return T("Dòng kẻ 8mm như vở thường")
        case .oLy:     return T("Ô 5mm — vẽ đồ thị, bảng biểu")
        case .cham:    return T("Lưới chấm 5mm — nhẹ mắt, vẫn canh thẳng được")
        case .cornell: return T("Chia ba vùng: từ khoá · ghi chép · tóm tắt")
        case .genkou:  return T("原稿用紙 — ô vuông có đường chéo mờ, tập kanji")
        case .nhacLy:  return T("Năm dòng kẻ nhạc")
        case .bonDong: return T("Đỉnh chữ hoa · đường giữa · dòng chân · đuôi — tập viết tay tiếng Anh")
        case .luoiCode: return T("Cột số dòng + ô 4mm để canh thụt lề khi viết code")
        }
    }

    var bieuTuong: String {
        switch self {
        case .trang:   return "doc"
        case .keNgang: return "list.bullet"
        case .oLy:     return "square.grid.3x3"
        case .cham:    return "circle.grid.3x3"
        case .cornell: return "rectangle.split.3x1"
        case .genkou:  return "square.grid.4x3.fill"
        case .nhacLy:  return "music.note.list"
        case .bonDong: return "textformat.abc"
        case .luoiCode: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

enum HuongGiay: String, Codable, CaseIterable, Identifiable {
    case doc
    case ngang

    var id: String { rawValue }
    var ten: String { self == .doc ? T("Dọc") : T("Ngang") }

    /// A4 = 210×297mm. Ở 72dpi ra 595×842pt.
    var khoA4: CGSize {
        self == .doc ? CGSize(width: 595, height: 842)
                     : CGSize(width: 842, height: 595)
    }
}

// MARK: - Thẻ hỏi AI

/// Một lần khoanh–hỏi đã lưu lại.
///
/// Hai việc trong một model, có chủ đích:
///
/// 1. **Câu trả lời không bay mất.** Trước đây hỏi xong đóng khung là hết —
///    người dùng tra một chữ giữa giờ học, tối về không còn gì.
/// 2. **Thành bộ ôn tập.** Khoanh 20 từ trong buổi học thì tối có sẵn 20
///    thẻ để lật lại, đúng những chỗ mình đã vướng chứ không phải một danh
///    sách từ vựng chung chung.
///
/// Ảnh vùng khoanh lưu thành TỆP (`Documents/Vo/hoi/`), không nhét `Data`
/// vào đây — cùng lý do với nét vẽ: nhét ảnh vào kho là nó phình theo từng
/// câu hỏi.
@Model
final class TheHoiAI {
    var id: UUID = UUID()
    /// Trang đã khoanh — để bấm vào thẻ là nhảy về đúng chỗ.
    var trangId: UUID?
    /// Chép lại tên cuốn và số trang: trang có thể bị xoá, mà thẻ thì nên
    /// còn đọc được.
    var tenCuon: String = ""
    var soTrang: Int = 0
    /// Tên tệp ảnh vùng khoanh trong `Documents/Vo/hoi/`.
    var anhTen: String?
    var cauHoi: String = ""
    var traLoi: String = ""
    var taoLuc: Date = Date()
    /// Đã thuộc thì thôi không hiện trong lượt ôn nữa.
    var daThuoc: Bool = false

    init(trangId: UUID?, tenCuon: String, soTrang: Int,
         anhTen: String?, cauHoi: String, traLoi: String) {
        self.id = UUID()
        self.trangId = trangId
        self.tenCuon = tenCuon
        self.soTrang = soTrang
        self.anhTen = anhTen
        self.cauHoi = cauHoi
        self.traLoi = traLoi
        self.taoLuc = Date()
        self.daThuoc = false
    }
}
