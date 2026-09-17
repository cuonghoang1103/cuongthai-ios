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

    /// Văn bản mà máy đọc được từ nét viết tay (Đợt 3). Để sẵn cột ở đây để
    /// tìm kiếm sau này không phải migrate.
    var chuNhanDang: String?

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

    /// Khổ trang tính bằng point (1pt = 1/72 inch), đúng khổ A4 để in ra
    /// không phải co giãn.
    var khoTrang: CGSize { huong.khoA4 }
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
