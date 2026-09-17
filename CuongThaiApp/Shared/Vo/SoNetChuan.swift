#if os(iOS)
import Foundation

/// Số nét ĐÚNG của từng chữ kana.
///
/// ⚠️⚠️ Vì sao phải có bảng này: kho nét của máy chủ (`/hanzi-stroke/:char`)
/// là kho chữ HÁN, và với kana nó **sai ~35%**. Đo thật 17/09/2026 trên 20
/// kana: 7 chữ sai, tất cả đều THỪA đúng 1 nét, và tất cả đều là chữ có nét
/// cong — あ(4≠3) お(4≠3) す(3≠2) の(2≠1) ほ(5≠4) な(5≠4) む(4≠3).
///
/// Đã thử lọc nét trùng bằng cách so hình dạng: chỉ cứu được 1 chữ (21→22
/// trên 28) mà lại LÀM HỎNG `き` (bỏ nhầm một nét đúng, 4→3). Nên bỏ hẳn
/// hướng đó — một phép sửa tự động sai chỗ khác còn tệ hơn là không sửa.
///
/// Kanji thì kho nét CHÍNH XÁC (đo: 日4 本5 人2 山3 川3 一1 二2 三3 議20 — đúng
/// hết), nên chữ Hán vẫn chấm từng nét bình thường.
///
/// Cách dùng: chữ nào có trong bảng mà số nét máy chủ trả về KHÁC, thì không
/// chấm theo nét nữa — chuyển sang tô theo mẫu. Dạy sai thứ tự nét còn tai
/// hại hơn là không dạy, vì người học sẽ phải gỡ thói quen đó về sau.
enum SoNetChuan {

    static let hiragana: [String: Int] = [
        "あ":3,"い":2,"う":2,"え":2,"お":3, "か":3,"き":4,"く":1,"け":3,"こ":2,
        "さ":3,"し":1,"す":2,"せ":3,"そ":1, "た":4,"ち":2,"つ":1,"て":1,"と":2,
        "な":4,"に":3,"ぬ":2,"ね":2,"の":1, "は":3,"ひ":1,"ふ":4,"へ":1,"ほ":4,
        "ま":3,"み":2,"む":3,"め":2,"も":3, "や":3,"ゆ":2,"よ":2,
        "ら":2,"り":2,"る":1,"れ":2,"ろ":1, "わ":2,"を":3,"ん":1,
    ]

    static let katakana: [String: Int] = [
        "ア":2,"イ":2,"ウ":3,"エ":3,"オ":3, "カ":2,"キ":3,"ク":2,"ケ":3,"コ":2,
        "サ":3,"シ":3,"ス":2,"セ":2,"ソ":2, "タ":3,"チ":3,"ツ":3,"テ":3,"ト":2,
        "ナ":2,"ニ":2,"ヌ":2,"ネ":4,"ノ":1, "ハ":2,"ヒ":2,"フ":1,"ヘ":1,"ホ":4,
        "マ":2,"ミ":3,"ム":2,"メ":2,"モ":3, "ヤ":2,"ユ":2,"ヨ":3,
        "ラ":2,"リ":2,"ル":2,"レ":1,"ロ":3, "ワ":2,"ヲ":3,"ン":2,
    ]

    /// `nil` = không có trong bảng (kanji, hoặc kana biến âm) ⇒ tin máy chủ.
    static func cua(_ chu: String) -> Int? {
        hiragana[chu] ?? katakana[chu]
    }

    /// Dữ liệu nét của máy chủ có dùng để chấm TỪNG NÉT được không.
    static func chamTungNetDuoc(chu: String, soNetMayChu: Int) -> Bool {
        guard let chuan = cua(chu) else { return true }   // kanji: tin
        return chuan == soNetMayChu
    }
}
#endif
