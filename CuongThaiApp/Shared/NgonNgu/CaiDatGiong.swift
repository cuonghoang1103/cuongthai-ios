import Foundation
import AVFoundation

// ════════════════════════════════════════════════════════════════
// CHỌN GIỌNG ĐỌC CHO MỤC NGOẠI NGỮ
//
// Trước 09/09/2026 giọng là CỐ ĐỊNH: `DocTu` chỉ truyền mã ngôn ngữ
// (`ja-JP`, `zh-CN`, `en-US`) nên iOS trả về giọng MẶC ĐỊNH — thường là bản
// "Compact", chính là cái nghe máy móc nhất. Người dùng không có cách nào đổi.
//
// Nay: chọn được giọng riêng cho từng ngôn ngữ, nhớ lại giữa các lần mở app,
// kèm tốc độ đọc (học ngoại ngữ thường cần chậm hơn bình thường).
//
// ⚠️ Danh sách giọng KHÔNG cố định theo mã máy — nó là những gói người dùng
// đã tải trong Cài đặt → Trợ năng → Nội dung đọc → Giọng nói. Vì thế luôn
// LIỆT KÊ LÚC CHẠY, đừng bao giờ ghi cứng một danh sách.
// ════════════════════════════════════════════════════════════════

/// Một lựa chọn giọng — hoặc giọng trong máy, hoặc giọng chạy ở máy nhà.
enum NguonGiong: Equatable, Hashable {
    /// `AVSpeechSynthesisVoice.identifier`
    case trongMay(String)
    /// Mã giọng của `/api/v1/voice-mini/tts` (vd `robot-walle`).
    case mayNha(String)
}

struct LuaChonGiong: Identifiable, Equatable {
    let nguon: NguonGiong
    let ten: String
    /// "Compact" · "Enhanced" · "Premium" · "Máy nhà"
    let chatLuong: String
    var id: String {
        switch nguon {
        case .trongMay(let x): return "may:\(x)"
        case .mayNha(let x):   return "nha:\(x)"
        }
    }
    var laMayNha: Bool { if case .mayNha = nguon { return true }; return false }
}

@MainActor
final class CaiDatGiong: ObservableObject {
    static let shared = CaiDatGiong()

    /// mã ngôn ngữ ("en"/"ja"/"zh") → id lựa chọn. Rỗng = dùng mặc định của máy.
    @Published private(set) var daChon: [String: String] = [:]
    /// Tốc độ đọc, 0.3…0.6. Mặc định 0.45 — chậm hơn `AVSpeechUtteranceDefaultSpeechRate`
    /// (0.5) một chút, vì đây là chữ NGƯỜI HỌC chưa quen, không phải tiếng mẹ đẻ.
    @Published var tocDo: Double {
        didSet { UserDefaults.standard.set(tocDo, forKey: Self.khoaTocDo) }
    }

    private static let khoaGiong = "giongNgoaiNgu"
    private static let khoaTocDo = "tocDoDocNgoaiNgu"

    private init() {
        daChon = (UserDefaults.standard.dictionary(forKey: Self.khoaGiong) as? [String: String]) ?? [:]
        let t = UserDefaults.standard.double(forKey: Self.khoaTocDo)
        tocDo = t > 0 ? t : 0.45
    }

    func chon(_ id: String?, cho code: String) {
        if let id { daChon[code] = id } else { daChon.removeValue(forKey: code) }
        UserDefaults.standard.set(daChon, forKey: Self.khoaGiong)
    }

    func idDaChon(_ code: String) -> String? { daChon[code] }

    /// Giọng đang dùng cho một ngôn ngữ, `nil` = mặc định của máy.
    func luaChon(_ code: String) -> LuaChonGiong? {
        guard let id = daChon[code] else { return nil }
        return Self.danhSach(code).first { $0.id == id }
    }

    // ── Liệt kê ──────────────────────────────────────────────────

    /// Mã vùng của iOS cho mỗi mã ngôn ngữ của máy chủ.
    static func maVung(_ code: String) -> String? {
        switch code {
        case "ja":  return "ja-JP"
        case "zh":  return "zh-CN"
        case "en":  return "en-US"
        case "fr":  return "fr-FR"
        case "ger": return "de-DE"
        case "rus": return "ru-RU"
        default:    return nil
        }
    }

    /// Bốn giọng TIẾNG ANH chạy ở máy nhà.
    ///
    /// ⚠️ CHỈ tiếng Anh. Đo thật 18/08/2026 bằng `GET /voice-mini/voices`:
    /// khoá đó phục vụ 4 giọng Anh, còn lại (18 giọng Việt + 8 giọng F5) đều
    /// là tiếng Việt — KHÔNG có giọng Nhật hay Trung nào. Đưa chúng vào mục
    /// tiếng Nhật là hứa một thứ sẽ đọc sai bét.
    static let GIONG_MAY_NHA_ANH: [LuaChonGiong] = [
        .init(nguon: .mayNha("robot-walle"),  ten: "Robot (máy nhà)",      chatLuong: "Máy nhà"),
        .init(nguon: .mayNha("en-default"),   ten: "Anh — chuẩn",          chatLuong: "Máy nhà"),
        .init(nguon: .mayNha("en-cham"),      ten: "Anh — chậm rãi",       chatLuong: "Máy nhà"),
        .init(nguon: .mayNha("en-bieu-cam"),  ten: "Anh — nhiều biểu cảm", chatLuong: "Máy nhà"),
    ]

    /// Mọi giọng dùng được cho một ngôn ngữ, giọng chất lượng cao xếp trước.
    static func danhSach(_ code: String) -> [LuaChonGiong] {
        guard let vung = maVung(code) else { return [] }
        let goc = String(vung.prefix(2))

        let trongMay: [LuaChonGiong] = AVSpeechSynthesisVoice.speechVoices()
            // So theo GỐC ngôn ngữ chứ không so đủ "en-US": người dùng có thể
            // đã tải en-GB hoặc en-AU, và chúng đọc tiếng Anh hoàn toàn tốt.
            .filter { $0.language.hasPrefix(goc) }
            .filter { !laGiongVuiNhon($0) }
            .map { g in
                let cl: String
                switch g.quality {
                case .premium:  cl = "Premium"
                case .enhanced: cl = "Enhanced"
                default:        cl = "Compact"
                }
                // Kèm mã vùng để phân biệt Anh-Mỹ với Anh-Anh khi trùng tên.
                return LuaChonGiong(nguon: .trongMay(g.identifier),
                                    ten: "\(g.name) · \(g.language)",
                                    chatLuong: cl)
            }
            // Premium → Enhanced → Compact. Giọng hay nhất phải ở trên cùng,
            // không thì người dùng chọn ngay cái đầu tiên và vẫn nghe máy móc.
            .sorted { a, b in
                let thu = ["Premium": 0, "Enhanced": 1, "Compact": 2]
                let x = thu[a.chatLuong] ?? 3, y = thu[b.chatLuong] ?? 3
                return x != y ? x < y : a.ten < b.ten
            }

        return code == "en" ? GIONG_MAY_NHA_ANH + trongMay : trongMay
    }

    /// Giọng "vui nhộn" của Apple — Albert, Bad News, Bahh, Zarvox, Trinoids…
    ///
    /// ⚠️ Đây là thứ khiến bản đầu bị chê "nghe như người ngoài hành tinh".
    /// `AVSpeechSynthesisVoice.speechVoices()` trả về CẢ chúng lẫn giọng thật,
    /// không có cờ nào phân biệt — nên phải nhận bằng ĐỊNH DANH.
    ///
    /// Apple đặt tên định danh theo hai lối khác hẳn nhau:
    ///   • giọng vui nhộn / kế thừa từ macOS đời cũ:
    ///       com.apple.speech.synthesis.voice.Albert
    ///   • giọng đọc thật:
    ///       com.apple.voice.compact.en-US.Samantha
    ///       com.apple.voice.enhanced.ja-JP.Kyoko
    ///       com.apple.ttsbundle.siri_…
    /// Nên chỉ cần loại đúng một tiền tố. Danh sách tên bên dưới là lớp thứ
    /// hai phòng khi Apple đổi cách đặt định danh.
    private static let TEN_VUI_NHON: Set<String> = [
        "Albert", "Bad News", "Bahh", "Bells", "Boing", "Bubbles", "Cellos",
        "Deranged", "Good News", "Hysterical", "Jester", "Organ", "Princess",
        "Ralph", "Superstar", "Trinoids", "Whisper", "Wobble", "Zarvox",
        "Bruce", "Fred", "Junior", "Kathy", "Victoria",
    ]

    static func laGiongVuiNhon(_ g: AVSpeechSynthesisVoice) -> Bool {
        g.identifier.hasPrefix("com.apple.speech.synthesis.voice.")
            || TEN_VUI_NHON.contains(g.name)
    }

    /// Máy đã có giọng chất lượng cao cho ngôn ngữ này chưa — để còn gợi ý tải.
    static func coGiongTot(_ code: String) -> Bool {
        danhSach(code).contains { $0.chatLuong == "Enhanced" || $0.chatLuong == "Premium" }
    }
}
