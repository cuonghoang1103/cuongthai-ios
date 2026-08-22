import Foundation

// MARK: - Từ điển tra cứu
//
// `GET /:code/dictionary` trả **TOÀN BỘ** kho từ của một ngôn ngữ trong một
// lượt: en 13.226 · ja 7.209 · zh 4.730 (đo 22/08/2026, 2,2MB · 1,2MB · 0,6MB).
//
// ⚠️⚠️ **Máy chủ KHÔNG lọc.** `getDictionary(code)` bỏ qua sạch `req.query`,
// nên `?q=` không có tác dụng gì — gửi `q=zzzzzzzz` vẫn nhận đủ 7.209 từ. Cùng
// họ với bẫy `?level=` trên `/vocab`. Vì thế tra cứu BẮT BUỘC làm ở client;
// đổi lại là tra tức thì và không cần mạng sau lần tải đầu.
//
// ⚠️ **KHÔNG dùng lại `TuNgoaiNgu` cho payload này.** `/dictionary` chỉ chọn
// `{type, value}` cho `pronunciations`, còn `/vocab` trả cả `{id, wordId, type,
// value, order}` — mà `TuNgoaiNgu.CachDoc.id` khai bắt buộc. Đo thật: giải mã
// hỏng ngay từ `data[0]`, cả ba thứ tiếng. Build vẫn xanh, chỉ lộ lúc chạy.

struct TuTuDien: Codable, Identifiable, Hashable {
    let id: Int
    let word: String
    let meaningVi: String?
    let pronunciations: [Doc]?

    struct Doc: Codable, Hashable {
        let type: String?
        let value: String?
    }

    var nghia: String { meaningVi ?? "" }

    /// Ưu tiên chữ Latinh — người mới học đọc được romaji/pinyin, chưa đọc
    /// được kana hay chú âm. Cùng thứ tự với `TuNgoaiNgu.phienAm`.
    var phienAm: String? {
        guard let ds = pronunciations, !ds.isEmpty else { return nil }
        for t in ["romaji", "pinyin", "ipa", "romanization"] {
            if let m = ds.first(where: { $0.type?.lowercased() == t }),
               let v = m.value, !v.isEmpty { return v }
        }
        return ds.first?.value
    }

    var phienAmPhu: String? {
        guard let ds = pronunciations else { return nil }
        let chinh = phienAm
        return ds.first { $0.value != chinh && !($0.value ?? "").isEmpty }?.value
    }
}

// MARK: - Chuẩn hoá để tìm

extension String {
    /// Bỏ dấu + thường hoá, để gõ "nuoc" tìm ra "nước".
    ///
    /// ⚠️ `.diacriticInsensitive` **KHÔNG** biến `đ` thành `d` — nó là một chữ
    /// cái riêng trong Unicode chứ không phải `d` cộng dấu. Không thay tay thì
    /// gõ "dong" không bao giờ ra "đồng", mà đó là kiểu gõ tự nhiên nhất của
    /// người Việt khi lười bỏ dấu.
    var chuanHoaTim: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi_VN"))
            .replacingOccurrences(of: "đ", with: "d")
            .replacingOccurrences(of: "Đ", with: "d")
            .lowercased()
    }
}

// MARK: - So khớp trên BYTE

// So trên `[UInt8]` chứ không trên `String`. `String.contains` của Swift duyệt
// theo CỤM KÝ TỰ Unicode nên rất đắt: đo thật trên kho tiếng Anh 13.226 từ,
// một lượt gõ mất **218ms** — trễ thấy rõ ở mỗi phím. Cùng phép tìm đó làm
// trên byte UTF-8 chỉ **2,7ms**, nhanh **80 lần** và lọt dưới một khung hình
// 60fps. Chuẩn hoá đã bỏ hết dấu nên byte thuần là đủ.

@inline(__always)
private func chuaByte(_ h: [UInt8], _ n: [UInt8]) -> Bool {
    if n.isEmpty { return true }
    if n.count > h.count { return false }
    let cuoi = h.count - n.count, dau = n[0]
    var i = 0
    while i <= cuoi {
        if h[i] == dau {
            var j = 1
            while j < n.count && h[i + j] == n[j] { j += 1 }
            if j == n.count { return true }
        }
        i += 1
    }
    return false
}

@inline(__always)
private func dauByte(_ h: [UInt8], _ n: [UInt8]) -> Bool {
    if n.count > h.count { return false }
    for i in 0..<n.count where h[i] != n[i] { return false }
    return true
}

/// Câu người dùng gõ, đã dựng sẵn cả hai dạng byte.
struct TruyVanTuDien {
    let chuan: [UInt8]
    let tho: [UInt8]
    /// Bản bỏ hết dấu cách — xem ghi chú ở `bDocLien`.
    let lien: [UInt8]
    var rong: Bool { tho.isEmpty }

    init(_ q: String) {
        let g = q.trimmingCharacters(in: .whitespacesAndNewlines)
        let c = g.chuanHoaTim
        chuan = Array(c.utf8)
        tho = Array(g.utf8)
        lien = Array(c.replacingOccurrences(of: " ", with: "").utf8)
    }
}

/// Một dòng đã dựng sẵn khoá tìm./// Một dòng đã dựng sẵn khoá tìm.
///
/// Chuẩn hoá MỘT LẦN lúc nạp, không phải mỗi lần gõ: 13.226 từ × 3 chuỗi mà
/// làm lại theo từng phím thì máy phải bỏ dấu 40 nghìn chuỗi cho mỗi ký tự.
/// Đo thật: gọi `chuanHoaTim` nhầm vào TRONG vòng lặp làm một lượt gõ đội từ
/// 218ms lên 362ms.
struct DongTraCuu {
    let tu: TuTuDien
    private let bTho: [UInt8]     // từ gốc, giữ nguyên dấu/chữ Hán
    private let bTu: [UInt8]      // từ đã bỏ dấu
    private let bDoc: [UInt8]     // mọi phiên âm, đã bỏ dấu
    private let bDocLien: [UInt8] // phiên âm bỏ luôn dấu cách
    private let bNghia: [UInt8]   // nghĩa tiếng Việt, đã bỏ dấu

    init(_ t: TuTuDien) {
        tu = t
        bTho = Array(t.word.utf8)
        bTu = Array(t.word.chuanHoaTim.utf8)
        let doc = (t.pronunciations ?? []).compactMap(\.value)
            .joined(separator: " ").chuanHoaTim
        bDoc = Array(doc.utf8)
        // ⚠️ Pinyin và romaji lưu CÓ dấu cách ("ni hao"), còn người ta gõ
        // LIỀN ("nihao"). Đo thật 22/08: thiếu khoá này thì gõ "nihao" không
        // ra 你好 trong khi "ni hao" ra ngay — mà gõ liền mới là cách gõ tự
        // nhiên. Cùng chuyện với "ohayougozaimasu".
        bDocLien = Array(doc.replacingOccurrences(of: " ", with: "").utf8)
        bNghia = Array(t.nghia.chuanHoaTim.utf8)
    }

    /// Điểm khớp; `nil` = không khớp. Càng NHỎ càng sát.
    ///
    /// Xếp hạng để từ gõ đúng nổi lên đầu: gõ "水" mà một từ ghép chứa 水 đứng
    /// trên chính chữ 水 thì tra cứu thành vô dụng.
    @inline(__always)
    func diem(_ q: TruyVanTuDien) -> Int? {
        if bTho == q.tho { return 0 }
        if bTu == q.chuan { return 1 }
        if dauByte(bTho, q.tho) { return 2 }
        if dauByte(bTu, q.chuan) { return 3 }
        if bDoc == q.chuan || bDocLien == q.lien { return 4 }
        if dauByte(bDoc, q.chuan) || dauByte(bDocLien, q.lien) { return 5 }
        if bNghia == q.chuan { return 6 }
        if dauByte(bNghia, q.chuan) { return 7 }
        if chuaByte(bTho, q.tho) { return 8 }
        if chuaByte(bDoc, q.chuan) || chuaByte(bDocLien, q.lien) { return 9 }
        if chuaByte(bNghia, q.chuan) { return 10 }
        return nil
    }
}
