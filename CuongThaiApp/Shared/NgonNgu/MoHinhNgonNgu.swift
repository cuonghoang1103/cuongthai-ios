import Foundation

// ════════════════════════════════════════════════════════════════
// MY LANGUAGE — lớp dữ liệu
//
// Mọi hình dạng ở đây đo bằng cách GỌI THẬT production 21/08/2026, không
// đọc mã backend rồi suy ra. Hai chỗ đã sai nếu đoán:
//   · cờ là `flagEmoji`, KHÔNG phải `flag`
//   · `?level=` trên /vocab KHÔNG lọc gì cả (vẫn trả đủ 7.209 từ) —
//     phải lọc qua `categoryId`, còn cấp thì đọc từ chính chủ đề
// ════════════════════════════════════════════════════════════════

struct NgonNgu: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let nameEn: String?
    let code: String
    let flagEmoji: String?
    let order: Int?
    let isActive: Bool?
    let counts: SoLuong?

    struct SoLuong: Codable, Hashable {
        let words: Int?
        let grammar: Int?
        let listening: Int?
        let conversation: Int?
        let reading: Int?
        let qna: Int?
        let alphabet: Int?
        let lessons: Int?
    }

    /// Ngôn ngữ RỖNG thì không đưa vào app.
    ///
    /// Đo 21/08/2026: `fr`, `rus`, `ger` đều `isActive: true` mà 0 ở MỌI mục.
    /// Liệt kê chúng ra là người dùng bấm vào và gặp màn trắng — vừa trông
    /// như app hỏng, vừa đúng thứ App Store soi theo mục 2.1.
    var coNoiDung: Bool { (counts?.words ?? 0) > 0 }

    var co: String { flagEmoji ?? "🌐" }
}

struct ChuDeTu: Codable, Identifiable, Hashable {
    let id: Int
    let languageId: Int?
    let name: String
    let icon: String?
    let level: String?
    let order: Int?
    let wordCount: Int?

    var soTu: Int { wordCount ?? 0 }
    /// Tên chủ đề trên máy chủ mang sẵn tiền tố cấp: "N5 · Chào hỏi & giao
    /// tiếp". Cấp đã hiện ở thanh lọc phía trên rồi nên nhắc lại là thừa,
    /// mà trên màn hẹp thì phần tiền tố đó ăn mất chỗ của tên thật.
    var tenGon: String {
        guard let level, name.hasPrefix(level) else { return name }
        return name.dropFirst(level.count)
            .trimmingCharacters(in: CharacterSet(charactersIn: " ·-–—"))
    }
}

struct TuNgoaiNgu: Codable, Identifiable, Hashable {
    let id: Int
    let categoryId: Int?
    let word: String
    let meaningVi: String?
    let exampleSentence: String?
    let exampleMeaning: String?
    let imageUrl: String?
    let audioUrl: String?
    let note: String?
    let pronunciations: [CachDoc]?

    struct CachDoc: Codable, Identifiable, Hashable {
        let id: Int
        let type: String?
        let value: String?
        let order: Int?
    }

    /// Dòng phiên âm hiện dưới từ. Ưu tiên chữ Latinh (romaji/pinyin/IPA)
    /// vì đó là thứ người mới học đọc được; hiragana/chú âm để dành cho
    /// dòng phụ.
    var phienAm: String? {
        guard let ds = pronunciations, !ds.isEmpty else { return nil }
        let uuTien = ["romaji", "pinyin", "ipa", "romanization"]
        for t in uuTien {
            if let m = ds.first(where: { $0.type?.lowercased() == t }), let v = m.value, !v.isEmpty {
                return v
            }
        }
        return ds.first?.value
    }

    var phienAmPhu: String? {
        guard let ds = pronunciations else { return nil }
        let chinh = phienAm
        return ds.first(where: { $0.value != chinh && !($0.value ?? "").isEmpty })?.value
    }

    var nghia: String { meaningVi ?? "" }
}

// ── SRS ─────────────────────────────────────────────────────────

struct MucOnTap: Codable, Identifiable, Hashable {
    let progress: TienDo
    let word: TuNgoaiNgu?
    var id: Int { progress.id }

    struct TienDo: Codable, Hashable, Identifiable {
        let id: Int
        let itemType: String
        let itemId: Int
        let status: String?
        let easeFactor: Double?
        let repetitions: Int?
        let intervalDays: Int?
        let nextReviewAt: String?
        let lastReviewedAt: String?
    }
}

struct HangDoiOnTap: Codable {
    let count: Int
    let items: [MucOnTap]
}

/// Mức nhớ người học tự chấm, ánh xạ thẳng sang thang 0-5 của SM-2 mà máy
/// chủ dùng (`recordProgress`). Bốn nút, không phải sáu: sáu mức làm người
/// ta đứng cân nhắc lâu hơn cả thời gian nhớ ra từ.
enum MucNho: Int, CaseIterable {
    case quen = 1, kho = 3, duoc = 4, de = 5

    var nhan: String {
        switch self {
        case .quen: return "Quên rồi"
        case .kho:  return "Khó"
        case .duoc: return "Được"
        case .de:   return "Dễ"
        }
    }

    var mau: UInt32 {
        switch self {
        case .quen: return 0xE5484D
        case .kho:  return 0xD97706
        case .duoc: return 0x2BA84A
        case .de:   return 0x0E93A6
        }
    }

    /// Bao lâu nữa gặp lại. Máy chủ tính bằng SM-2, đây chỉ là con số cho
    /// người dùng thấy trước khi bấm — nói xấp xỉ còn hơn không nói gì.
    var uocLuong: String {
        switch self {
        case .quen: return "1 ngày"
        case .kho:  return "1 ngày"
        case .duoc: return "vài ngày"
        case .de:   return "lâu hơn"
        }
    }
}

// ── Bảng chữ ────────────────────────────────────────────────────

struct NhomChu: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let description: String?
    let order: Int?
    let items: [ChuCai]?

    struct ChuCai: Codable, Identifiable, Hashable {
        let id: Int
        let groupId: Int?
        let character: String
        let romanization: String?
        let note: String?
        let order: Int?
    }

    var chu: [ChuCai] { items ?? [] }
}

// ── Bốn mục nội dung ────────────────────────────────────────────
//
// ⚠️ NGỮ PHÁP TRẢ HÌNH DẠNG KHÁC BA MỤC KIA. Đo thật:
//     grammar      → data = { items: [...], levels: [...] }
//     conversation → data = [...]   , levels nằm ở TẦNG NGOÀI
//     reading, qna → y như conversation
// Khai một model chung cho cả bốn là giải mã hỏng ở đúng một mục, mà mục
// đó lại là mục nhiều nội dung nhất (300 mục mỗi ngôn ngữ).

struct NguPhap: Codable, Identifiable, Hashable {
    let id: Int
    let level: String?
    let title: String
    let structure: String?
    let explanation: String?
    let examples: [ViDu]?
    let commonMistakes: String?
    let comparedWith: String?

    struct ViDu: Codable, Hashable {
        let sentence: String?
        let meaningVi: String?
        let pronunciation: String?
    }
}

/// Vỏ riêng của ngữ pháp — `data` là ĐỐI TƯỢNG, không phải mảng.
struct GoiNguPhap: Codable {
    let items: [NguPhap]
    let levels: [String]?
}

struct HoiThoai: Codable, Identifiable, Hashable {
    let id: Int
    let level: String?
    let question: String
    let answer: String?
    let questionPronunciation: String?
    let answerPronunciation: String?
    let meaningVi: String?
    let note: String?
}

struct BaiDoc: Codable, Identifiable, Hashable {
    let id: Int
    let level: String?
    let title: String
    let type: String?
    let content: String?
    let translation: String?
}

struct HoiDap: Codable, Identifiable, Hashable {
    let id: Int
    let level: String?
    let question: String
    let answer: String?
    let pronunciation: String?
    let meaningVi: String?
}

// ── AI ──────────────────────────────────────────────────────────

struct KetQuaDich: Codable {
    let translation: String?
    let reading: String?
    let literal: String?
    let notes: String?
    let alternatives: [String]?
}

struct KetQuaKiemNguPhap: Codable {
    let corrected: String?
    let score: Int?
    let issues: [Loi]?

    struct Loi: Codable, Identifiable, Hashable {
        let severity: String?
        let original: String?
        let suggestion: String?
        let explanation: String?
        var id: String { (original ?? "") + (suggestion ?? "") + (explanation ?? "") }

        var mauMuc: UInt32 {
            switch (severity ?? "").lowercased() {
            case "error":   return 0xE5484D
            case "warning": return 0xD97706
            default:        return 0x0E93A6
            }
        }
        var tenMuc: String {
            switch (severity ?? "").lowercased() {
            case "error":   return "Sai"
            case "warning": return "Nên sửa"
            default:        return "Văn phong"
            }
        }
    }
}
