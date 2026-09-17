import SwiftUI

// ════════════════════════════════════════════════════════════════
// LUYỆN TẬP BẢNG CHỮ CÁI — mô hình và các hàm THUẦN
//
// Bản iOS của màn `/language/ja/alphabet/practice` trên web: 9 chặng luyện
// trên đúng bộ chữ người dùng chọn. Không có endpoint riêng — tất cả dựng
// từ `GET /my-language/:code/alphabet`, cùng nguồn với màn Bảng chữ.
//
// File này KHÔNG có View và KHÔNG gọi mạng, để còn kiểm được bằng `swiftc`
// mà không phải dựng cả app: bộ sinh câu hỏi mà lệch thì người học ngồi gõ
// một đáp án không bao giờ đúng, và đó là loại lỗi ảnh chụp không thấy.
// ════════════════════════════════════════════════════════════════

// MARK: - Chữ và nhóm

struct ChuLuyen: Identifiable, Hashable {
    let id: Int
    let kana: String
    let romaji: String

    /// Mọi cách đọc chấp nhận được, đã chuẩn hoá.
    ///
    /// ⚠️ Máy chủ để HAI âm đọc trong một ô, ngăn bằng `/`: 人 = "hito / jin".
    /// Đo thật 18/09/2026 trên production: 5/220 mục thuộc dạng này, tất cả
    /// đều là kanji. Web ghép cả chuỗi lại thành một đáp án duy nhất nên
    /// người học phải gõ đúng "hito/jin" mới qua — gõ "hito" (đúng) bị báo
    /// sai. Ở đây gõ cách nào cũng đúng.
    var cacCachDoc: [String] {
        romaji.split(separator: "/")
            .map { Self.chuanRomaji(String($0)) }
            .filter { !$0.isEmpty }
    }

    /// Gõ được không.
    ///
    /// ⚠️ `(sokuon)` / `(chōonpu)` là TÊN GỌI của ký hiệu っ và ー, không
    /// phải âm đọc của nó — bắt người học gõ cả dấu ngoặc là vô nghĩa. Đo
    /// thật: 3/220 mục. Những mục này vẫn vào được chặng trắc nghiệm, tìm
    /// cặp và tập viết; chỉ các chặng GÕ mới loại chúng ra.
    var goDuoc: Bool {
        let r = romaji.trimmingCharacters(in: .whitespaces)
        guard !r.isEmpty, r.contains(where: { $0.isLetter }) else { return false }
        return r.allSatisfy { $0.isLetter || $0 == " " || $0 == "/" || $0 == "-" }
    }

    /// Khoá so sánh: bỏ hoa/thường và mọi khoảng trắng.
    static func chuanRomaji(_ s: String) -> String {
        s.lowercased().filter { !$0.isWhitespace }
    }

    /// Người học gõ `nhap` có khớp không.
    func dung(_ nhap: String) -> Bool {
        let k = Self.chuanRomaji(nhap)
        guard !k.isEmpty else { return false }
        return cacCachDoc.contains(k)
    }
}

struct NhomLuyen: Identifiable, Hashable {
    let id: Int
    let ten: String
    let chu: [ChuLuyen]
}

/// Đổi dữ liệu máy chủ → dữ liệu luyện tập, bỏ mục thiếu phiên âm.
func nhomLuyen(tu nhom: [NhomChu]) -> [NhomLuyen] {
    nhom.compactMap { n in
        let chu = n.chu.compactMap { c -> ChuLuyen? in
            let r = (c.romanization ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let k = c.character.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !r.isEmpty, !k.isEmpty else { return nil }
            return ChuLuyen(id: c.id, kana: k, romaji: r)
        }
        return chu.isEmpty ? nil : NhomLuyen(id: n.id, ten: n.name, chu: chu)
    }
}

// MARK: - Chín chặng

enum ChangLuyen: String, CaseIterable, Codable, Identifiable {
    case tracNghiem, tracNghiemDao, timCap, vietDapAn, vietTu, vietDoan, nghe, tapViet, veChu

    var id: String { rawValue }

    var so: Int { (Self.allCases.firstIndex(of: self) ?? 0) + 1 }

    var ten: String {
        switch self {
        case .tracNghiem:    return "Trắc nghiệm"
        case .tracNghiemDao: return "Trắc nghiệm đảo"
        case .timCap:        return "Tìm cặp"
        case .vietDapAn:     return "Viết đáp án"
        case .vietTu:        return "Viết từ"
        case .vietDoan:      return "Viết đoạn"
        case .nghe:          return "Nghe"
        case .tapViet:       return "Tập viết"
        case .veChu:         return "Vẽ chữ"
        }
    }

    var mota: String {
        switch self {
        case .tracNghiem:    return "Nhìn chữ, chọn phiên âm"
        case .tracNghiemDao: return "Nhìn phiên âm, chọn chữ"
        case .timCap:        return "Ghép chữ với phiên âm"
        case .vietDapAn:     return "Gõ phiên âm của chữ"
        case .vietTu:        return "Gõ phiên âm chuỗi ngắn"
        case .vietDoan:      return "Gõ phiên âm chuỗi dài"
        case .nghe:          return "Nghe rồi gõ phiên âm"
        case .tapViet:       return "Viết theo đúng thứ tự nét"
        case .veChu:         return "Nhớ & vẽ lại chữ"
        }
    }

    var bieuTuong: String {
        switch self {
        case .tracNghiem:    return "checklist"
        case .tracNghiemDao: return "shuffle"
        case .timCap:        return "square.grid.2x2"
        case .vietDapAn:     return "keyboard"
        case .vietTu:        return "textformat"
        case .vietDoan:      return "text.alignleft"
        case .nghe:          return "ear"
        case .tapViet:       return "pencil.line"
        case .veChu:         return "paintbrush.pointed"
        }
    }

    var mau: Color {
        switch self {
        case .tracNghiem, .vietDoan: return AppColors.primary
        case .tracNghiemDao, .nghe:  return AppColors.secondary
        case .timCap, .tapViet:      return AppColors.success
        case .vietDapAn, .veChu:     return AppColors.accent
        case .vietTu:                return AppColors.brandPink
        }
    }

    /// Chặng này bắt người học GÕ phiên âm — mục không gõ được phải loại ra.
    var phaiGo: Bool {
        switch self {
        case .vietDapAn, .vietTu, .vietDoan, .nghe: return true
        default: return false
        }
    }

    /// Chặng dùng một CHUỖI chữ chứ không phải một chữ đơn.
    var doDaiChuoi: ClosedRange<Int>? {
        switch self {
        case .vietTu:   return 2...3
        case .vietDoan: return 4...6
        default:        return nil
        }
    }
}

// MARK: - Cài đặt

struct CaiDatLuyenChu: Codable, Equatable {
    var nhomIds: [Int]
    var changs: [ChangLuyen]
    /// Số câu. `0` = tất cả (một câu mỗi chữ, tối thiểu 10).
    var soCau: Int

    static let soCauChon = [10, 20, 40, 0]

    static func macDinh(_ nhom: [NhomLuyen]) -> CaiDatLuyenChu {
        // Mặc định là Hiragana nếu có — người mới bắt đầu từ đó, và chọn sẵn
        // cả 220 chữ thì bài đầu tiên đã lẫn katakana lẫn kanji.
        let hira = nhom.filter { $0.ten.range(of: "hiragana", options: .caseInsensitive) != nil }
        let chon = hira.isEmpty ? nhom : hira
        return CaiDatLuyenChu(nhomIds: chon.map(\.id),
                              changs: ChangLuyen.allCases,
                              soCau: 20)
    }

    /// Bỏ nhóm/chặng không còn tồn tại; rỗng thì trả về mặc định.
    func loc(theo nhom: [NhomLuyen]) -> CaiDatLuyenChu {
        let coThat = nhomIds.filter { id in nhom.contains { $0.id == id } }
        let mac = Self.macDinh(nhom)
        return CaiDatLuyenChu(
            nhomIds: coThat.isEmpty ? mac.nhomIds : coThat,
            changs: changs.isEmpty ? mac.changs : changs,
            soCau: Self.soCauChon.contains(soCau) ? soCau : mac.soCau,
        )
    }
}

/// Nhớ cài đặt giữa các lần mở. Tách khoá theo mã ngôn ngữ để sau này mở
/// cho tiếng khác thì không giẫm lên lựa chọn của tiếng Nhật.
enum KhoCaiDatLuyenChu {
    private static func khoa(_ code: String) -> String { "luyen-bang-chu.\(code)" }

    static func doc(_ code: String, nhom: [NhomLuyen]) -> CaiDatLuyenChu {
        guard let d = UserDefaults.standard.data(forKey: khoa(code)),
              let c = try? JSONDecoder().decode(CaiDatLuyenChu.self, from: d)
        else { return .macDinh(nhom) }
        return c.loc(theo: nhom)
    }

    static func ghi(_ c: CaiDatLuyenChu, code: String) {
        guard let d = try? JSONEncoder().encode(c) else { return }
        UserDefaults.standard.set(d, forKey: khoa(code))
    }
}

// MARK: - Câu hỏi

struct CauHoiChu: Identifiable {
    let id: String
    let chang: ChangLuyen
    /// Chuỗi chữ của câu. Chặng chữ đơn thì đúng một phần tử.
    let chuoi: [ChuLuyen]

    var moc: ChuLuyen { chuoi[0] }
    var kanaGhep: String { chuoi.map(\.kana).joined() }
    var romajiGhep: String { chuoi.map(\.romaji).joined() }

    func dungChuoi(_ nhap: String) -> Bool {
        // Mỗi mắt xích có thể có nhiều cách đọc ⇒ so theo từng khả năng.
        // Làm tổ hợp đầy đủ thì 6 mắt × 2 cách = 64 chuỗi, vẫn rẻ, nhưng
        // chuỗi chỉ dựng từ kana (một cách đọc) nên thực tế luôn là 1.
        let k = ChuLuyen.chuanRomaji(nhap)
        var kha: Set<String> = [""]
        for c in chuoi {
            let cach = c.cacCachDoc.isEmpty ? [ChuLuyen.chuanRomaji(c.romaji)] : c.cacCachDoc
            kha = Set(kha.flatMap { dau in cach.map { dau + $0 } })
            if kha.count > 256 { return k == ChuLuyen.chuanRomaji(romajiGhep) }
        }
        return kha.contains(k)
    }
}

struct KetQuaCau {
    let chang: ChangLuyen
    let dung: Bool
}

// MARK: - Dựng bộ câu hỏi

enum BoCauHoi {
    /// Trộn bài — cùng một bộ chữ mỗi lần mở ra một thứ tự khác.
    static func tron<T>(_ ds: [T]) -> [T] { ds.shuffled() }

    /// Đáp án nhiễu: phiên âm KHÁC nhau lấy từ đúng bộ chữ đang luyện.
    /// Lấy từ ngoài bộ thì câu hỏi dễ đoán — nhiễu trông "lạ" là loại ngay.
    static func nhieuRomaji(_ bo: [ChuLuyen], dung: String, so: Int) -> [String] {
        var daCo: Set<String> = [ChuLuyen.chuanRomaji(dung)]
        var ra: [String] = []
        for c in bo.shuffled() {
            let k = ChuLuyen.chuanRomaji(c.romaji)
            if daCo.contains(k) { continue }
            daCo.insert(k); ra.append(c.romaji)
            if ra.count >= so { break }
        }
        return ra
    }

    static func nhieuKana(_ bo: [ChuLuyen], dung: String, so: Int) -> [String] {
        var daCo: Set<String> = [dung]
        var ra: [String] = []
        for c in bo.shuffled() {
            if daCo.contains(c.kana) { continue }
            daCo.insert(c.kana); ra.append(c.kana)
            if ra.count >= so { break }
        }
        return ra
    }

    /// Dựng hàng đợi câu hỏi, luân phiên đều các chặng đã bật.
    ///
    /// ⚠️ Chặng GÕ chỉ nhận chữ `goDuoc`. Nếu người dùng chỉ chọn nhóm "Ký
    /// hiệu đặc biệt" (cả 4 chữ đều không gõ được) thì các chặng gõ bị bỏ
    /// qua hoàn toàn thay vì sinh ra câu không thể trả lời đúng.
    static func dung(nhom: [NhomLuyen], changs: [ChangLuyen], soCau: Int) -> [CauHoiChu] {
        let bo = nhom.flatMap(\.chu)
        guard !bo.isEmpty, !changs.isEmpty else { return [] }

        let boGo = bo.filter(\.goDuoc)
        let changDung = changs.filter { !$0.phaiGo || !boGo.isEmpty }
        guard !changDung.isEmpty else { return [] }

        let tong = soCau > 0 ? soCau : max(bo.count, 10)

        func layChuoi(_ khoang: ClosedRange<Int>, chiGoDuoc: Bool) -> [ChuLuyen] {
            // Chuỗi lấy LIỀN NHAU trong cùng một nhóm: あいう đọc được thành
            // tiếng, còn ghép ngẫu nhiên khắp bảng thì ra chuỗi vô nghĩa và
            // khó nhớ hơn hẳn.
            let ungVien = nhom.compactMap { n -> [ChuLuyen]? in
                let ds = chiGoDuoc ? n.chu.filter(\.goDuoc) : n.chu
                return ds.isEmpty ? nil : ds
            }
            guard let ds = ungVien.randomElement() else { return [] }
            let k = min(ds.count, Int.random(in: khoang))
            guard k > 0 else { return [] }
            let dau = Int.random(in: 0...(ds.count - k))
            return Array(ds[dau..<(dau + k)])
        }

        var thuTu = changDung.shuffled()
        var ra: [CauHoiChu] = []
        for i in 0..<tong {
            if i > 0, i % thuTu.count == 0 { thuTu = changDung.shuffled() }
            let chang = thuTu[i % thuTu.count]
            let chuoi: [ChuLuyen]
            if let khoang = chang.doDaiChuoi {
                chuoi = layChuoi(khoang, chiGoDuoc: chang.phaiGo)
            } else {
                let nguon = chang.phaiGo ? boGo : bo
                chuoi = nguon.randomElement().map { [$0] } ?? []
            }
            guard !chuoi.isEmpty else { continue }
            ra.append(CauHoiChu(id: "c\(i)", chang: chang, chuoi: chuoi))
        }
        return ra
    }
}
