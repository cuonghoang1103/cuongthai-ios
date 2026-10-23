import SwiftUI

// ════════════════════════════════════════════════════════════════
// KHỐI `onthe` — "Ôn tập bằng thẻ" của Dekiru, bản native của nhat/OnTapThe.tsx:
// 8 cách ôn kiểu Quizlet trên từ vựng, chữ Hán của lớp và mẫu ngữ pháp Bài 1–15:
//   1 Thẻ lật · 2 Học (mỗi thẻ đúng 2 lần: chọn rồi gõ) · 3 Trắc nghiệm 4 đáp án ·
//   4 Gõ đáp án · 5 Nghe (chọn / chép) · 6 Ghép cặp bấm giờ · 7 Kiểm tra 20 câu ·
//   8 Ôn từ sai (Leitner 5 hộp).
// Dữ liệu: on-the.json — thẻ dựng SẴN lúc build web, đáp án chấp nhận (ansJp/ansVi)
// đã fold bằng chính hàm của web; app chỉ fold câu người học gõ (`GapOnThe`) rồi so.
// Trạng thái (thuộc / hộp ôn / kỷ lục) lưu trên máy như web (localStorage ↔ UserDefaults).
// Romaji ẩn tới khi lật/trả lời (thấy romaji là đọc được ngay — đo nhầm thành "đã thuộc").
// ════════════════════════════════════════════════════════════════

typealias TheOT = BoTheSH.The
typealias CauOT = BoTheSH.Cau

// MARK: - So đáp án (onThe.ts)

enum GapOnThe {
    private static func thay(_ s: String, _ mau: String, _ bang: String) -> String {
        guard let re = try? NSRegularExpression(pattern: mau) else { return s }
        return re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: bang)
    }

    static func toHira(_ t: String) -> String {
        String(String.UnicodeScalarView(t.unicodeScalars.map { (0x30A1...0x30F6).contains($0.value) ? Unicode.Scalar($0.value - 0x60)! : $0 }))
    }

    /// Romaji (Hepburn, cả kiểu gõ bàn phím) → hiragana — `romajiToKana` của nhat/chia.ts.
    static func romajiToKana(_ input: String) -> String {
        let T: [String: String] = [
            "kya": "きゃ", "kyu": "きゅ", "kyo": "きょ", "gya": "ぎゃ", "gyu": "ぎゅ", "gyo": "ぎょ", "sha": "しゃ", "shu": "しゅ", "sho": "しょ", "shi": "し",
            "sya": "しゃ", "syu": "しゅ", "syo": "しょ", "ja": "じゃ", "ju": "じゅ", "jo": "じょ", "ji": "じ", "jya": "じゃ", "jyu": "じゅ", "jyo": "じょ",
            "cha": "ちゃ", "chu": "ちゅ", "cho": "ちょ", "chi": "ち", "tya": "ちゃ", "tyu": "ちゅ", "tyo": "ちょ", "tsu": "つ", "nya": "にゃ", "nyu": "にゅ", "nyo": "にょ",
            "hya": "ひゃ", "hyu": "ひゅ", "hyo": "ひょ", "bya": "びゃ", "byu": "びゅ", "byo": "びょ", "pya": "ぴゃ", "pyu": "ぴゅ", "pyo": "ぴょ",
            "mya": "みゃ", "myu": "みゅ", "myo": "みょ", "rya": "りゃ", "ryu": "りゅ", "ryo": "りょ", "fu": "ふ", "dzu": "づ",
            "ka": "か", "ki": "き", "ku": "く", "ke": "け", "ko": "こ", "ga": "が", "gi": "ぎ", "gu": "ぐ", "ge": "げ", "go": "ご",
            "sa": "さ", "si": "し", "su": "す", "se": "せ", "so": "そ", "za": "ざ", "zi": "じ", "zu": "ず", "ze": "ぜ", "zo": "ぞ",
            "ta": "た", "ti": "ち", "tu": "つ", "te": "て", "to": "と", "da": "だ", "di": "ぢ", "du": "づ", "de": "で", "do": "ど",
            "na": "な", "ni": "に", "nu": "ぬ", "ne": "ね", "no": "の", "ha": "は", "hi": "ひ", "hu": "ふ", "he": "へ", "ho": "ほ",
            "ba": "ば", "bi": "び", "bu": "ぶ", "be": "べ", "bo": "ぼ", "pa": "ぱ", "pi": "ぴ", "pu": "ぷ", "pe": "ぺ", "po": "ぽ",
            "ma": "ま", "mi": "み", "mu": "む", "me": "め", "mo": "も", "ya": "や", "yu": "ゆ", "yo": "よ",
            "ra": "ら", "ri": "り", "ru": "る", "re": "れ", "ro": "ろ", "wa": "わ", "wo": "を", "a": "あ", "i": "い", "u": "う", "e": "え", "o": "お",
        ]
        // Bỏ dấu, trừ dấu ngang dài (ā) ⇒ nguyên âm đôi.
        var s = ""
        for u in input.lowercased().decomposedStringWithCanonicalMapping.unicodeScalars {
            if u.value == 0x0304 { s.append("~") } else if (0x0300...0x036F).contains(u.value) { continue } else { s.unicodeScalars.append(u) }
        }
        s = thay(s, "([aiueo])~", "$1$1")
        s = thay(s, "[\\s'-]", "'")
        var c = Array(s)
        var out = ""
        let phuAm = Set("bcdfghjkmpqrstvwxyz")
        while !c.isEmpty {
            if c[0] == "'" { c.removeFirst(); continue }
            if c.count > 1, c[0] == c[1], phuAm.contains(c[0]) { out += "っ"; c.removeFirst(); continue }
            if c.starts(with: Array("tch")) { out += "っ"; c.removeFirst(); continue }
            if c[0] == "n" && (c.count == 1 || !"aiueoy".contains(c[1])) { out += "ん"; c.removeFirst(c.count > 1 && c[1] == "n" ? 2 : 1); continue }
            var trung = false
            for n in [3, 2, 1] where c.count >= n {
                if let k = T[String(c.prefix(n))] { out += k; c.removeFirst(n); trung = true; break }
            }
            if !trung { out.append(c.removeFirst()) }
        }
        return out
    }

    /// So lỏng tiếng Nhật: hiragana, bỏ dấu câu/khoảng trắng, gộp trường âm — `foldJp`.
    static func foldJp(_ t: String) -> String {
        var x = toHira(t.precomposedStringWithCompatibilityMapping).lowercased()
        if x.range(of: "[a-z]", options: .regularExpression) != nil { x = romajiToKana(x) }
        x = thay(x, "[\\s・。、，,.!?！？～~（）()「」『』［］\\[\\]'\"\\-:：0-9]", "").replacingOccurrences(of: "ー", with: "")
        x = thay(x, "([おこそとのほもよろごぞどぼぽょ])[うお]", "$1")
        x = thay(x, "([うくすつぬふむゆるぐずづぶぷゅ])う", "$1")
        x = thay(x, "([あかさたなはまやらわがざだばぱゃ])あ", "$1")
        x = thay(x, "([いきしちにひみりぎじびぴ])い", "$1")
        x = thay(x, "([えけせてねへめれげぜでべぺ])[えい]", "$1")
        return x
    }

    static func foldVi(_ t: String) -> String {
        var s = t.replacingOccurrences(of: "đ", with: "d").replacingOccurrences(of: "Đ", with: "D")
        s = s.folding(options: [.diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")).lowercased()
        s = thay(s, "\\([^)]*\\)|（[^）]*）", " ")
        s = thay(s, "[^a-z0-9 ]", " ")
        return thay(s, "\\s+", " ").trimmingCharacters(in: .whitespaces)
    }

    static func khopVi(_ g: String, _ ans: [String]) -> Bool {
        let x = foldVi(g)
        guard !x.isEmpty else { return false }
        return ans.contains { a in a == x || (a.contains(x) && Double(x.count) >= max(3, Double(a.count) * 0.6)) || (x.contains(a) && a.count >= 3) }
    }

    static func khopJp(_ g: String, _ ans: [String]) -> Bool {
        let x = foldJp(g)
        return !x.isEmpty && ans.contains(x)
    }
}

// MARK: - Kho trạng thái (trên máy)

@MainActor
final class KhoOnTheSH: ObservableObject {
    struct TrangThai: Codable {
        var thuoc: [String: Int] = [:]
        /// id → [hộp 1–5, hạn ôn (ms)].
        var srs: [String: [Double]] = [:]
        var best: [String: Double] = [:]
    }
    @Published private(set) var st: TrangThai
    private static let KHOA = "dekiru-onthe-v1"
    /// Hộp 1–5 → số ngày tới lần ôn sau.
    static let HOP_NGAY = [0, 0, 1, 3, 7, 14]

    init() {
        st = UserDefaults.standard.data(forKey: Self.KHOA).flatMap { try? JSONDecoder().decode(TrangThai.self, from: $0) } ?? TrangThai()
    }

    func capNhat(_ f: (inout TrangThai) -> Void) {
        f(&st)
        if let d = try? JSONEncoder().encode(st) { UserDefaults.standard.set(d, forKey: Self.KHOA) }
    }
    static var bayGio: Double { Date().timeIntervalSince1970 * 1000 }
    /// Sai ở bất kỳ chế độ nào ⇒ vào hộp 1, đến hạn ngay.
    func sai(_ id: String) { capNhat { $0.thuoc[id] = nil; $0.srs[id] = [1, Self.bayGio] } }
    func thuoc(_ id: String) { capNhat { $0.thuoc[id] = 1 } }
}

struct TuyChonOnThe: Codable, Equatable {
    var bai: [Int] = [4, 5]
    var loai: [String] = ["tu", "han", "np"]
    var dir: String = "jv"        // jv Nhật → Việt · vj Việt → Nhật
    var mode: String = "lat"
}

// MARK: - Dựng câu

enum OnTheTienIch {
    static let LOAI_TEN = ["tu": "Từ vựng", "han": "Chữ Hán", "np": "Ngữ pháp"]

    /// Chữ Hán trông giống (có cả chữ "giả" hay gặp trong đề của lớp) — đáp án nhiễu (bảng `LOOK` của OnTapThe.tsx).
    static let GIONG: [String: String] = [
        "先": "冼牛生", "生": "主牛星", "休": "体伏佑", "見": "貝具兒", "買": "罝貢員", "物": "牣牛勿", "名": "各多夕", "前": "煎剪首", "国": "玉団匤",
        "食": "飲倉飼", "飲": "飯欽食", "午": "牛干年", "後": "役徒待", "行": "待往何", "週": "遇周過", "毎": "海母梅", "来": "米未束", "人": "入八大",
        "日": "目白旧", "本": "木体末", "大": "犬太天", "学": "字覚宇", "会": "合今全", "何": "可河伺", "天": "夫天太", "右": "石左若", "左": "右在佐",
        "土": "士上工", "千": "干午十", "万": "方力刀", "円": "丹月同", "東": "車束柬", "西": "酉四面", "北": "比此化", "南": "幸商帝", "山": "出凶岳",
        "川": "州小三", "小": "少水川", "上": "止土下", "下": "不卞上", "中": "申虫史", "雨": "両兩電", "間": "問聞開", "聞": "間問閉", "話": "語読詁",
        "語": "話詰誤", "読": "続説話", "書": "昼晝害", "時": "持詩待", "今": "令会合", "年": "午牛平", "月": "用円肉", "火": "人炎灰", "水": "氷永木",
        "木": "本未禾", "金": "全針釜", "女": "安好如", "男": "田勇町", "子": "字了予", "父": "交文爻", "母": "毎海舟", "友": "反左支", "私": "仏秒科",
        "長": "張帳髪", "白": "百日自", "百": "白万首", "外": "多夕処", "半": "羊平伴", "分": "公兮今", "入": "人八込", "出": "山凸缶", "立": "位拉辛",
        "電": "雷雲雪", "車": "東軍専", "駅": "馬験験", "店": "庄点占", "新": "親薪斤", "古": "吉占右", "高": "亭京商", "安": "女案宴",
    ]

    /// Bản gọn để in trên nút/ô ghép: bỏ ［thể từ điển］ và số nhóm động từ.
    static func gon(_ w: String) -> String {
        var s = w
        if let re = try? NSRegularExpression(pattern: #"［[^］]*］|\s*\d+\s*$"#) {
            s = re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
        }
        return s.trimmingCharacters(in: .whitespaces)
    }
    static func chu(_ x: TheOT, _ dir: String) -> String { dir == "jv" ? x.vi : gon(x.jp) }

    /// 3 đáp án nhiễu: cùng nhóm → cùng bài → cùng loại; chữ Hán chiều vj thêm chữ trông giống.
    static func nhieu(_ the: TheOT, _ pool: [TheOT], _ tat: [TheOT], _ dir: String, k: Int = 3) -> [String] {
        let cung = pool.filter { $0.loai == the.loai && $0.id != the.id }
        let tang = [cung.filter { $0.n == the.n && $0.nhom == the.nhom }.shuffled(),
                    cung.filter { $0.n == the.n && $0.nhom != the.nhom }.shuffled(),
                    cung.filter { $0.n != the.n }.shuffled(),
                    tat.filter { $0.loai == the.loai && $0.id != the.id }.shuffled()]
        var seen: Set<String> = [chu(the, dir)]
        var out: [String] = []
        if the.loai == "han", dir == "vj" {
            for c in (GIONG[the.jp] ?? "").map(String.init).shuffled().prefix(2) where !seen.contains(c) { seen.insert(c); out.append(c) }
        }
        for t in tang { for x in t {
            if out.count >= k { return out }
            let tx = chu(x, dir)
            if seen.contains(tx) { continue }
            seen.insert(tx); out.append(tx)
        } }
        return out
    }

    @MainActor static func noi(_ c: TheOT) {
        let t = c.loai == "np" ? (c.ex?.en ?? "") : (c.kana.isEmpty ? PhanTichChuSH.tach(c.jp).map { $0.ruby ?? $0.text }.joined() : c.kana)
        if !t.isEmpty { GiongSachHoc.chung.phat(ClipSH(text: t, giong: "ja-nu"), khoa: "ot|\(c.id)") }
    }

    /// Chèn lại thẻ sai vào sau 3–5 thẻ.
    static func chenLai<T>(_ q: [T], _ x: T) -> [T] { var n = q; n.insert(x, at: min(n.count, 3 + Int.random(in: 0...2))); return n }
}

struct CauHoiOT: Identifiable {
    enum De { case the(TheOT, String), chu(String), nghe(TheOT) }
    let id: String
    let tag: String
    let de: De
    let opts: [(text: String, dung: Bool)]
    var why: String?
    var sau: (TheOT, String)?

    static func tuThe(_ c: TheOT, _ pool: [TheOT], _ tat: [TheOT], _ dir: String) -> CauHoiOT {
        let ds = OnTheTienIch.nhieu(c, pool, tat, dir)
        let tag = "\(OnTheTienIch.LOAI_TEN[c.loai] ?? "") · Bài \(c.n)" + (!c.nhom.isEmpty && c.loai == "tu" ? " · \(c.nhom)" : "")
        return CauHoiOT(id: c.id + dir + UUID().uuidString, tag: tag, de: .the(c, dir),
                        opts: ([(OnTheTienIch.chu(c, dir), true)] + ds.map { ($0, false) }).shuffled(), sau: (c, dir))
    }
    static func tuCau(_ q: CauOT) -> CauHoiOT {
        CauHoiOT(id: q.id + UUID().uuidString, tag: "\(q.loai == "han" ? "Chữ Hán" : "Ngữ pháp") · Bài \(q.n) · \(q.title)", de: .chu(q.q),
                 opts: q.opts.enumerated().map { ($0.element, $0.offset == q.correct) }.shuffled(), why: q.why.isEmpty ? nil : q.why)
    }
}

// MARK: - Mặt thẻ

private struct MatTruocOT: View {
    let c: TheOT
    let dir: String
    var body: some View {
        Group {
            if dir == "vj" { ChuSH(text: c.vi, co: 21, dam: true, giua: true) }
            else if c.loai == "np" { ChuSH(text: c.jp, co: 19, dam: true, giua: true) }
            else { ChuSH(text: OnTheTienIch.gon(c.jp), co: 34, dam: true, giua: true) }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MatSauOT: View {
    let c: TheOT
    let dir: String
    var body: some View {
        VStack(spacing: 6) {
            if dir == "jv" { ChuSH(text: c.vi, co: 19, dam: true, mau: .nhan, giua: true) }
            else { ChuSH(text: c.jp, co: c.loai == "np" ? 18 : 28, dam: true, giua: true) }
            if !c.ro.isEmpty { Text(c.ro).font(.system(size: 14).italic()).foregroundColor(AppColors.textTertiary) }
            if !c.meta.isEmpty, c.loai != "np" { Text(c.meta).font(.system(size: 12.5)).foregroundColor(AppColors.textSecondary).multilineTextAlignment(.center) }
            if let ex = c.ex {
                VStack(spacing: 2) {
                    ChuSH(text: ex.en, co: 16, giua: true)
                    if let ro = ex.ro, !ro.isEmpty { Text(ro).font(.system(size: 12.5).italic()).foregroundColor(AppColors.textTertiary) }
                    if let vi = ex.vi { Text(vi).font(.system(size: 13.5)).foregroundColor(AppColors.textSecondary) }
                }
                .padding(8).frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.backgroundTertiary))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ThanhTienOT: View {
    let xong: Int
    let tong: Int
    let chu: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(chu).font(.system(size: 12.5)).foregroundColor(AppColors.textSecondary)
            ProgressView(value: Double(min(xong, max(tong, 1))), total: Double(max(tong, 1))).tint(AppColors.primary)
        }
    }
}

private struct TrongOT: View {
    let chu: String
    var nut: (String, () -> Void)?
    var body: some View {
        VStack(spacing: 12) {
            ChuSH(text: chu, co: 16, mau: .phu, giua: true)
            if let nut { NutSH(ten: nut.0, hanhDong: nut.1) }
        }
        .padding(24).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.backgroundTertiary.opacity(0.6)))
    }
}

private func khungTheOT<C: View>(@ViewBuilder _ c: () -> C) -> some View {
    VStack(spacing: 10) { c() }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 190)
        .background(RoundedRectangle(cornerRadius: 18).fill(AppColors.backgroundCard))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(AppColors.primary.opacity(0.35), lineWidth: 1.5))
}

// MARK: - Một câu trắc nghiệm

private struct CauTNOT: View {
    let cau: CauHoiOT
    var tuChuyen = true
    let xong: (Bool) -> Void
    @State private var chon: Int?

    var body: some View {
        let dung = chon.map { cau.opts[$0].dung } ?? false
        VStack(alignment: .leading, spacing: 10) {
            Text(cau.tag).font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary)
            khungTheOT {
                switch cau.de {
                case .the(let c, let dir): MatTruocOT(c: c, dir: dir)
                case .chu(let q): ChuSH(text: q, co: 18, giua: true)
                case .nghe(let c): NutSH(ten: "Nghe lại", bieuTuong: "speaker.wave.2.fill") { OnTheTienIch.noi(c) }
                }
            }
            ForEach(Array(cau.opts.enumerated()), id: \.offset) { i, o in
                Button { if chon == nil { chon = i; if !o.dung { Haptics.hong() } } } label: {
                    ChuSH(text: o.text, co: 17)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(nen(i)))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(vien(i), lineWidth: 1.3))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(chon != nil)
            }
            if chon != nil {
                if let w = cau.why { ChuSH(text: "💡 " + w, co: 14.5, mau: .phu) }
                if !dung, let (c, dir) = cau.sau { MatSauOT(c: c, dir: dir).padding(.vertical, 4) }
                HStack { Spacer(); NutSH(ten: "Tiếp", bieuTuong: "arrow.right") { xong(dung) } }
            }
        }
        .task(id: chon) {
            guard let chon, cau.opts[chon].dung, tuChuyen else { return }
            try? await Task.sleep(nanoseconds: 900_000_000)
            if !Task.isCancelled { xong(true) }
        }
    }

    private func nen(_ i: Int) -> Color {
        guard let chon else { return AppColors.backgroundTertiary }
        if cau.opts[i].dung { return AppColors.success.opacity(0.14) }
        if i == chon { return AppColors.error.opacity(0.12) }
        return AppColors.backgroundTertiary.opacity(0.6)
    }
    private func vien(_ i: Int) -> Color {
        guard let chon else { return AppColors.border }
        if cau.opts[i].dung { return AppColors.success }
        if i == chon { return AppColors.error }
        return AppColors.border
    }
}

// MARK: - Câu gõ

private struct CauGoOT: View {
    let c: TheOT
    let dir: String
    var nghe = false
    let xong: (Bool) -> Void
    @State private var go = ""
    @State private var kq: Bool?
    @FocusState private var dangGo: Bool

    private var muonJp: Bool { nghe || dir == "vj" }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(OnTheTienIch.LOAI_TEN[c.loai] ?? "") · Bài \(c.n) · " + (nghe ? "nghe rồi gõ lại bằng kana hoặc romaji" : muonJp ? "gõ tiếng Nhật (kana, romaji hoặc chữ Hán)" : "gõ nghĩa tiếng Việt (không dấu cũng được)"))
                .font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary)
            khungTheOT {
                if nghe { NutSH(ten: "Nghe lại", bieuTuong: "speaker.wave.2.fill") { OnTheTienIch.noi(c) } }
                else { MatTruocOT(c: c, dir: dir) }
            }
            HStack(spacing: 8) {
                TextField(muonJp ? "vd: kita hoặc きた" : "vd: phía bắc", text: $go)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .font(.system(size: 18)).padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.backgroundTertiary))
                    .focused($dangGo)
                    .disabled(kq != nil)
                    .onSubmit { if kq == nil { kiem() } else { xong(kq!) } }
                if kq == nil { NutSH(ten: "Kiểm tra") { kiem() } }
            }
            if let kq {
                Text(kq ? "✓ Đúng!" : "✗ Chưa đúng — đáp án:").font(.system(size: 15, weight: .bold)).foregroundColor(kq ? AppColors.success : AppColors.error)
                MatSauOT(c: c, dir: muonJp ? "vj" : "jv")
                HStack {
                    if !kq { NutSH(ten: "Tôi đúng (gõ khác cách)", phu: true) { xong(true) } }
                    Spacer()
                    NutSH(ten: "Tiếp", bieuTuong: "arrow.right") { xong(kq) }
                }
            }
        }
        .onAppear { if nghe { OnTheTienIch.noi(c) } }
    }

    private func kiem() {
        guard !go.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        kq = muonJp ? GapOnThe.khopJp(go, c.ansJp) : GapOnThe.khopVi(go, c.ansVi)
        if kq == false { Haptics.hong() }
    }
}

// MARK: - Khối

struct OnTheSH: View {
    @EnvironmentObject private var vm: SachHocVM
    @StateObject private var kho = KhoOnTheSH()
    @State private var opt: TuyChonOnThe = {
        UserDefaults.standard.data(forKey: "dekiru-onthe-opt-v1").flatMap { try? JSONDecoder().decode(TuyChonOnThe.self, from: $0) } ?? TuyChonOnThe()
    }()
    @AppStorage(CaiDatDocSH.furigana) private var furi = true

    static let CHE_DO: [(id: String, icon: String, ten: String, mo: String)] = [
        ("lat", "🃏", "Thẻ lật", "lật & tự chấm"), ("hoc", "🎯", "Học", "chọn rồi gõ"), ("tn", "🔘", "Trắc nghiệm", "4 đáp án"),
        ("go", "⌨️", "Gõ", "tự viết ra"), ("nghe", "🎧", "Nghe", "chọn / chép"), ("ghep", "🧩", "Ghép cặp", "bấm giờ"),
        ("kt", "📝", "Kiểm tra", "20 câu"), ("sai", "🔁", "Ôn từ sai", "5 hộp"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let bo = vm.boThe {
                noiDung(bo)
            } else if vm.khoa != nil && vm.khoa?.onThe == nil {
                // Máy chủ chưa có bản xuất mới (on-the.json) — app mới hơn web đang chạy.
                Text("Bộ thẻ chưa có trên máy chủ — kéo mục lục xuống để tải lại sau khi web cập nhật.").font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
            } else if let l = vm.loiNap {
                KhungLoiSH(loi: l) { Task { await vm.napBoThe() } }
            } else {
                HStack(spacing: 8) { ProgressView(); Text("Đang tải bộ thẻ…").foregroundColor(AppColors.textSecondary) }
                    .frame(maxWidth: .infinity, minHeight: 100)
            }
        }
        .task { await vm.napBoThe() }
        .onChange(of: opt) { _, o in if let d = try? JSONEncoder().encode(o) { UserDefaults.standard.set(d, forKey: "dekiru-onthe-opt-v1") } }
        #if DEBUG
        .onAppear { if let m = ProcessInfo.processInfo.environment["CT_SACHHOC_ONTHE"], Self.CHE_DO.contains(where: { $0.id == m }) { opt.mode = m } }
        #endif
    }

    @ViewBuilder
    private func noiDung(_ bo: BoTheSH) -> some View {
        let tatBai = Array(Set(bo.the.map(\.n))).sorted()
        let pool = bo.the.filter { opt.bai.contains($0.n) && opt.loai.contains($0.loai) }
        let caus = bo.cau.filter { opt.bai.contains($0.n) && opt.loai.contains($0.loai) }
        let thuoc = pool.filter { kho.st.thuoc[$0.id] != nil }.count
        VStack(alignment: .leading, spacing: 8) {
            hangLoc("Bài") {
                ForEach(tatBai, id: \.self) { n in
                    chip("B\(n)", phu: "\(bo.the.filter { $0.n == n && opt.loai.contains($0.loai) }.count)", opt.bai.contains(n)) { opt.bai = bat(opt.bai, n) }
                }
                chip("Tất cả", phu: nil, false) { opt.bai = tatBai }
            }
            hangLoc("Loại") {
                ForEach(["tu", "han", "np"], id: \.self) { l in chip(OnTheTienIch.LOAI_TEN[l] ?? l, phu: nil, opt.loai.contains(l)) { opt.loai = bat(opt.loai, l) } }
            }
            hangLoc("Chiều") {
                chip("Nhật → Việt", phu: nil, opt.dir == "jv") { opt.dir = "jv" }
                chip("Việt → Nhật", phu: nil, opt.dir == "vj") { opt.dir = "vj" }
                chip(furi ? "Furigana: hiện" : "Furigana: ẩn", phu: nil, furi) { furi.toggle() }
            }
            Text("\(pool.count) thẻ\(caus.isEmpty ? "" : " + \(caus.count) câu trắc nghiệm của sách") · đã thuộc \(thuoc) · romaji luôn ẩn tới khi lật")
                .font(.system(size: 12.5)).foregroundColor(AppColors.textSecondary)
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
            ForEach(Self.CHE_DO, id: \.id) { m in
                Button { opt.mode = m.id } label: {
                    VStack(spacing: 2) {
                        Text(m.icon).font(.system(size: 20))
                        Text(m.ten).font(.system(size: 13.5, weight: .bold))
                        Text(m.mo).font(.system(size: 11)).opacity(0.75)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(opt.mode == m.id ? AppColors.primary : AppColors.backgroundTertiary))
                    .foregroundColor(opt.mode == m.id ? .white : AppColors.textPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        Group {
            switch opt.mode {
            case "hoc": HocOT(pool: pool, tat: bo.the, dir: opt.dir, kho: kho)
            case "tn": TracNghiemOT(pool: pool, caus: caus, tat: bo.the, dir: opt.dir, kho: kho)
            case "go": GoOT(pool: pool, dir: opt.dir, kho: kho)
            case "nghe": NgheOT(pool: pool, tat: bo.the, kho: kho)
            case "ghep": GhepCapOT(pool: pool, kho: kho, khoaKyLuc: "\(opt.bai.sorted().map(String.init).joined(separator: ","))|\(opt.loai.sorted().joined(separator: ","))")
            case "kt": KiemTraOT(pool: pool, caus: caus, tat: bo.the, dir: opt.dir, kho: kho)
            case "sai": OnTuSaiOT(bo: bo, dir: opt.dir, kho: kho, bai: opt.bai)
            default: TheLatOT(pool: pool, dir: opt.dir, kho: kho)
            }
        }
        .id("\(opt.mode)|\(opt.bai.sorted())|\(opt.loai.sorted())|\(opt.dir)")
        .environment(\.moChuHanSH, nil)
    }

    private func bat<T: Equatable>(_ a: [T], _ v: T) -> [T] { a.contains(v) ? (a.count > 1 ? a.filter { $0 != v } : a) : a + [v] }

    private func hangLoc<C: View>(_ nhan: String, @ViewBuilder _ c: () -> C) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(nhan).font(.system(size: 12, weight: .heavy)).foregroundColor(AppColors.textTertiary).frame(width: 42, alignment: .leading)
            ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 6) { c() } }
        }
    }

    private func chip(_ t: String, phu: String?, _ bat: Bool, _ lam: @escaping () -> Void) -> some View {
        Button(action: lam) {
            HStack(spacing: 3) {
                Text(t).font(.system(size: 13, weight: .semibold))
                if let phu { Text(phu).font(.system(size: 10.5)).opacity(0.7) }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(bat ? AppColors.primary : AppColors.backgroundTertiary))
            .foregroundColor(bat ? .white : AppColors.textPrimary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 1. Thẻ lật

private struct TheLatOT: View {
    let pool: [TheOT]
    let dir: String
    @ObservedObject var kho: KhoOnTheSH
    @State private var boQua = true
    @State private var q: [TheOT] = []
    @State private var lat = false
    @State private var nho = 0
    @State private var tong = 0

    var body: some View {
        let daThuoc = pool.filter { kho.st.thuoc[$0.id] != nil }.count
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Toggle("Bỏ qua thẻ đã thuộc (\(daThuoc))", isOn: $boQua).toggleStyle(.button).font(.system(size: 13))
                NutSH(ten: "Trộn lại", bieuTuong: "shuffle", phu: true) { batDau() }
            }
            ThanhTienOT(xong: nho, tong: tong, chu: "Nhớ \(nho)/\(tong) · còn \(q.count) thẻ")
            if let c = q.first {
                Button { if !lat { lat = true; OnTheTienIch.noi(c) } } label: {
                    khungTheOT {
                        Text("\(OnTheTienIch.LOAI_TEN[c.loai] ?? "") · Bài \(c.n)" + (!c.nhom.isEmpty && c.loai != "np" ? " · \(c.nhom)" : ""))
                            .font(.system(size: 11.5, weight: .semibold)).foregroundColor(AppColors.textTertiary).multilineTextAlignment(.center)
                        if lat { MatSauOT(c: c, dir: dir) } else {
                            MatTruocOT(c: c, dir: dir)
                            Text("Nhớ trong đầu (nói to càng tốt) rồi chạm để lật").font(.system(size: 12.5)).foregroundColor(AppColors.textTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
                if lat {
                    HStack {
                        NutSH(ten: "✗ Chưa nhớ", phu: true) { kho.sai(c.id); q = OnTheTienIch.chenLai(Array(q.dropFirst()), c); lat = false }
                        Spacer()
                        NutSH(ten: "Nghe", bieuTuong: "speaker.wave.2.fill", phu: true) { OnTheTienIch.noi(c) }
                        Spacer()
                        NutSH(ten: "✓ Nhớ rồi") { kho.thuoc(c.id); nho += 1; q.removeFirst(); lat = false }
                    }
                }
            } else {
                TrongOT(chu: tong > 0 ? "🎉 Xong lượt này — bạn đã nhớ hết \(tong) thẻ." : "Mọi thẻ trong lựa chọn này đã thuộc. Tắt “Bỏ qua thẻ đã thuộc” để lật lại.",
                        nut: ("Lật lại từ đầu", batDau))
            }
        }
        .onAppear { if q.isEmpty && tong == 0 { batDau() } }
        .onChange(of: boQua) { _, _ in batDau() }
    }

    private func batDau() {
        let bo = boQua ? pool.filter { kho.st.thuoc[$0.id] == nil } : pool
        q = bo.shuffled(); tong = bo.count; nho = 0; lat = false
    }
}

// MARK: - 2. Học

private struct HocOT: View {
    let pool: [TheOT]
    let tat: [TheOT]
    let dir: String
    @ObservedObject var kho: KhoOnTheSH
    @State private var luot = 0
    @State private var bo: [TheOT] = []
    @State private var q: [(c: TheOT, buoc: Int)] = []
    @State private var diem: [String: Int] = [:]
    @State private var nhip = 0

    var body: some View {
        let tong = bo.count * 2
        let xong = diem.values.reduce(0, +)
        VStack(alignment: .leading, spacing: 10) {
            if bo.isEmpty {
                TrongOT(chu: "Chưa có thẻ nào trong lựa chọn này.")
            } else {
                ThanhTienOT(xong: xong, tong: tong, chu: "Lượt \(luot + 1) · \(bo.count) thẻ · mỗi thẻ phải đúng 2 lần (chọn, rồi gõ) · \(tong > 0 ? xong * 100 / tong : 0)%")
                if let cur = q.first {
                    if cur.buoc == 1 && cur.c.loai != "np" {
                        CauGoOT(c: cur.c, dir: dir) { tra($0) }.id(nhip)
                    } else {
                        CauTNOT(cau: .tuThe(cur.c, pool, tat, cur.buoc == 1 ? (dir == "jv" ? "vj" : "jv") : dir)) { tra($0) }.id(nhip)
                    }
                } else {
                    TrongOT(chu: "🎉 Thuộc cả \(bo.count) thẻ của lượt này.", nut: ("Học 20 thẻ tiếp", { luot += 1; batDau() }))
                }
            }
        }
        .onAppear { if bo.isEmpty { batDau() } }
    }

    private func batDau() {
        let chua = pool.filter { kho.st.thuoc[$0.id] == nil }
        bo = Array((chua.isEmpty ? pool : chua).shuffled().prefix(20))
        q = bo.map { ($0, 0) }; diem = [:]
    }

    private func tra(_ ok: Bool) {
        guard let cur = q.first else { return }
        nhip += 1
        var con = Array(q.dropFirst())
        if ok {
            let b = cur.buoc + 1
            diem[cur.c.id] = b
            if b >= 2 { kho.thuoc(cur.c.id) } else { con = OnTheTienIch.chenLai(con, (cur.c, b)) }
        } else {
            kho.sai(cur.c.id)
            con = OnTheTienIch.chenLai(con, cur)
        }
        q = con
    }
}

// MARK: - 3. Trắc nghiệm

private struct TracNghiemOT: View {
    let pool: [TheOT]
    let caus: [CauOT]
    let tat: [TheOT]
    let dir: String
    @ObservedObject var kho: KhoOnTheSH
    @State private var ds: [CauHoiOT] = []
    @State private var maCau: [String] = []
    @State private var i = 0
    @State private var dung = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if ds.isEmpty && pool.isEmpty && caus.isEmpty {
                TrongOT(chu: "Chưa có thẻ nào trong lựa chọn này.")
            } else if i < ds.count {
                ThanhTienOT(xong: i, tong: ds.count, chu: "Câu \(i + 1)/\(ds.count) · đúng \(dung) · câu sai tự vào hộp “Ôn từ sai”")
                CauTNOT(cau: ds[i]) { ok in
                    if ok { dung += 1 } else { kho.sai(maCau[i]) }
                    i += 1
                }
                .id(i)
            } else if !ds.isEmpty {
                TrongOT(chu: "**\(dung)/\(ds.count)** — xong cả bộ.", nut: ("Làm lại (trộn mới)", batDau))
            }
        }
        .onAppear { if ds.isEmpty { batDau() } }
    }

    private func batDau() {
        let cap: [(CauHoiOT, String)] = (pool.map { (CauHoiOT.tuThe($0, pool, tat, dir), $0.id) } + caus.map { (CauHoiOT.tuCau($0), $0.id) }).shuffled()
        ds = cap.map(\.0); maCau = cap.map(\.1); i = 0; dung = 0
    }
}

// MARK: - 4. Gõ

private struct GoOT: View {
    let pool: [TheOT]
    let dir: String
    @ObservedObject var kho: KhoOnTheSH
    @State private var q: [TheOT] = []
    @State private var dung = 0
    @State private var nhip = 0
    private var bo: [TheOT] { pool.filter { $0.loai != "np" } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if bo.isEmpty {
                TrongOT(chu: "Chế độ gõ dùng cho **Từ vựng** và **Chữ Hán** — hãy chọn thêm một trong hai loại đó.")
            } else {
                ThanhTienOT(xong: dung, tong: bo.count, chu: "Đúng \(dung)/\(bo.count) · còn \(q.count) · câu sai quay lại sau vài câu")
                if let c = q.first {
                    CauGoOT(c: c, dir: dir) { ok in
                        nhip += 1
                        if ok { dung += 1; q.removeFirst() } else { kho.sai(c.id); q = OnTheTienIch.chenLai(Array(q.dropFirst()), c) }
                    }
                    .id(nhip)
                } else {
                    TrongOT(chu: "🎉 Gõ đúng cả \(bo.count) thẻ.", nut: ("Làm lại", { q = bo.shuffled(); dung = 0 }))
                }
            }
        }
        .onAppear { if q.isEmpty && dung == 0 { q = bo.shuffled() } }
    }
}

// MARK: - 5. Nghe

private struct NgheOT: View {
    let pool: [TheOT]
    let tat: [TheOT]
    @ObservedObject var kho: KhoOnTheSH
    @State private var chep = false
    @State private var thuTu: [TheOT] = []
    @State private var i = 0
    @State private var dung = 0
    private var bo: [TheOT] { pool.filter { $0.loai == "tu" && !$0.kana.isEmpty } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if bo.isEmpty {
                TrongOT(chu: "Chế độ nghe dùng thẻ **Từ vựng** — hãy chọn loại Từ vựng.")
            } else {
                Picker("Kiểu nghe", selection: $chep) {
                    Text("Nghe chọn").tag(false)
                    Text("Nghe chép (gõ lại)").tag(true)
                }
                .pickerStyle(.segmented)
                .onChange(of: chep) { _, _ in batDau() }
                ThanhTienOT(xong: i, tong: thuTu.count, chu: "Câu \(min(i + 1, thuTu.count))/\(thuTu.count) · đúng \(dung)")
                if i < thuTu.count {
                    let c = thuTu[i]
                    Group {
                        if chep {
                            CauGoOT(c: c, dir: "vj", nghe: true) { tra($0, c) }
                        } else {
                            CauTNOT(cau: CauHoiOT(id: c.id + "nghe", tag: "Nghe · Bài \(c.n) — chọn từ bạn vừa nghe",
                                                  de: .nghe(c), opts: ([(OnTheTienIch.gon(c.jp), true)] + OnTheTienIch.nhieu(c, bo, tat, "vj").map { ($0, false) }).shuffled(),
                                                  sau: (c, "jv"))) { tra($0, c) }
                                .onAppear { OnTheTienIch.noi(c) }
                        }
                    }
                    .id("\(i)|\(chep)")
                } else if !thuTu.isEmpty {
                    TrongOT(chu: "**\(dung)/\(thuTu.count)**", nut: ("Làm lại", batDau))
                }
            }
        }
        .onAppear { if thuTu.isEmpty { batDau() } }
    }

    private func batDau() { thuTu = bo.shuffled(); i = 0; dung = 0 }
    private func tra(_ ok: Bool, _ c: TheOT) { if ok { dung += 1 } else { kho.sai(c.id) }; i += 1 }
}

// MARK: - 6. Ghép cặp

private struct GhepCapOT: View {
    let pool: [TheOT]
    @ObservedObject var kho: KhoOnTheSH
    let khoaKyLuc: String
    @State private var o: [(id: String, jp: Bool, c: TheOT)] = []
    @State private var soCap = 0
    @State private var mat: Set<String> = []
    @State private var chon: Int?
    @State private var sai: [Int] = []
    @State private var batDauLuc = Date()
    @State private var phat: Double = 0
    @State private var ketThuc: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if soCap < 3 && !o.isEmpty || (o.isEmpty && pool.count < 3) {
                TrongOT(chu: "Cần ít nhất 3 thẻ để ghép cặp — hãy chọn thêm bài.")
            } else {
                HStack {
                    TimelineView(.periodic(from: .now, by: 0.1)) { tl in
                        Text(String(format: "%.1fs", (ketThuc ?? (tl.date.timeIntervalSince(batDauLuc) * 1000 + phat)) / 1000))
                            .font(.system(size: 22, weight: .heavy).monospacedDigit()).foregroundColor(AppColors.primary)
                    }
                    Text(kho.st.best[khoaKyLuc].map { String(format: "Kỷ lục: %.1fs", $0 / 1000) } ?? "Chưa có kỷ lục").font(.system(size: 12.5)).foregroundColor(AppColors.textSecondary)
                    Text("· ghép sai +1s").font(.system(size: 12.5)).foregroundColor(AppColors.textTertiary)
                    Spacer()
                    NutSH(ten: "Bộ mới", bieuTuong: "arrow.clockwise", phu: true) { batDau() }
                }
                if let kt = ketThuc {
                    let best = kho.st.best[khoaKyLuc]
                    TrongOT(chu: String(format: "**%.1fs** — ", kt / 1000) + (best == nil || kt <= best! ? "🏆 Kỷ lục mới!" : String(format: "kỷ lục vẫn là %.1fs", best! / 1000)),
                            nut: ("Chơi bộ mới", batDau))
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                        ForEach(Array(o.enumerated()), id: \.offset) { i, x in
                            Button { bam(i) } label: {
                                ChuSH(text: x.jp ? OnTheTienIch.gon(x.c.jp) : x.c.vi, co: x.jp ? 19 : 14.5, giua: true)
                                    .frame(maxWidth: .infinity, minHeight: 64).padding(6)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(sai.contains(i) ? AppColors.error.opacity(0.18) : chon == i ? AppColors.primary.opacity(0.18) : AppColors.backgroundTertiary))
                                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(chon == i ? AppColors.primary : Color.clear, lineWidth: 1.5))
                            }
                            .buttonStyle(.plain)
                            .opacity(mat.contains(x.id) ? 0 : 1)
                            .disabled(mat.contains(x.id))
                        }
                    }
                }
            }
        }
        .onAppear { if o.isEmpty { batDau() } }
    }

    private func batDau() {
        var seen = Set<String>()
        let ngan = pool.filter { $0.loai != "np" }
        let cards = (ngan.count >= 3 ? ngan : pool).shuffled().filter { x in
            if seen.contains(x.vi) || seen.contains(x.jp) { return false }
            seen.insert(x.vi); seen.insert(x.jp); return true
        }.prefix(6)
        soCap = cards.count
        o = cards.flatMap { [($0.id, true, $0), ($0.id, false, $0)] }.shuffled()
        mat = []; chon = nil; sai = []; phat = 0; ketThuc = nil; batDauLuc = Date()
    }

    private func bam(_ i: Int) {
        let t = o[i]
        guard !mat.contains(t.id) else { return }
        guard let s = chon else { chon = i; return }
        if s == i { chon = nil; return }
        let a = o[s]
        if a.id == t.id && a.jp != t.jp {
            mat.insert(t.id); chon = nil
            if t.c.loai != "np" { OnTheTienIch.noi(t.c) }
            if mat.count == soCap {
                let ms = Date().timeIntervalSince(batDauLuc) * 1000 + phat
                ketThuc = ms
                if let b = kho.st.best[khoaKyLuc], b <= ms {} else { kho.capNhat { $0.best[khoaKyLuc] = ms } }
            }
        } else {
            sai = [s, i]; phat += 1000; chon = nil
            kho.sai(a.jp ? a.id : t.id)
            Haptics.hong()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { sai = [] }
        }
    }
}

// MARK: - 7. Kiểm tra

private struct KiemTraOT: View {
    let pool: [TheOT]
    let caus: [CauOT]
    let tat: [TheOT]
    let dir: String
    @ObservedObject var kho: KhoOnTheSH
    @EnvironmentObject private var vm: SachHocVM

    private enum Cau { case tn(CauHoiOT, id: String, dung: String), go(TheOT, String), ds(TheOT, hien: String, that: Bool) }
    @State private var de: [Cau] = []
    @State private var i = 0
    @State private var kq: [(cau: Cau, ok: Bool, tl: String)] = []
    @State private var go = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if de.isEmpty && pool.isEmpty {
                TrongOT(chu: "Chưa có thẻ nào trong lựa chọn này.")
            } else if !de.isEmpty && i >= de.count {
                ketQua
            } else if i < de.count {
                ThanhTienOT(xong: i, tong: de.count, chu: "Câu \(i + 1)/\(de.count) · chấm điểm khi nộp cuối bài")
                cauHien(de[i]).id(i)
            }
        }
        .onAppear { if de.isEmpty { batDau() } }
    }

    @ViewBuilder
    private func cauHien(_ c: Cau) -> some View {
        switch c {
        case .tn(let q, _, _):
            VStack(alignment: .leading, spacing: 10) {
                Text(q.tag).font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                khungTheOT {
                    switch q.de {
                    case .the(let t, let d): MatTruocOT(c: t, dir: d)
                    case .chu(let s): ChuSH(text: s, co: 18, giua: true)
                    case .nghe(let t): NutSH(ten: "Nghe lại", bieuTuong: "speaker.wave.2.fill") { OnTheTienIch.noi(t) }
                    }
                }
                ForEach(Array(q.opts.enumerated()), id: \.offset) { _, o in
                    Button { ghi(o.dung, "") } label: {
                        ChuSH(text: o.text, co: 17).frame(maxWidth: .infinity, alignment: .leading).padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.backgroundTertiary)).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        case .ds(let t, let hien, let that):
            VStack(spacing: 10) {
                Text("Đúng hay sai? · Bài \(t.n)").font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                khungTheOT {
                    ChuSH(text: OnTheTienIch.gon(t.jp), co: 28, dam: true, giua: true)
                    ChuSH(text: "= " + hien, co: 17, mau: .nhan, giua: true)
                }
                HStack {
                    NutSH(ten: "Đúng", bieuTuong: "checkmark") { ghi(that, "Đúng") }
                    Spacer()
                    NutSH(ten: "Sai", bieuTuong: "xmark", phu: true) { ghi(!that, "Sai") }
                }
            }
        case .go(let t, let d):
            VStack(alignment: .leading, spacing: 10) {
                Text((d == "vj" ? "Gõ tiếng Nhật (kana / romaji / chữ Hán)" : "Gõ nghĩa tiếng Việt") + " · Bài \(t.n)")
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                khungTheOT { MatTruocOT(c: t, dir: d) }
                HStack(spacing: 8) {
                    TextField("Câu trả lời…", text: $go).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .font(.system(size: 18)).padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.backgroundTertiary))
                        .onSubmit { traGo(t, d) }
                    NutSH(ten: "Trả lời") { traGo(t, d) }
                }
            }
        }
    }

    private func traGo(_ t: TheOT, _ d: String) { ghi(d == "vj" ? GapOnThe.khopJp(go, t.ansJp) : GapOnThe.khopVi(go, t.ansVi), go) }

    private func ghi(_ ok: Bool, _ tl: String) {
        kq.append((de[i], ok, tl)); i += 1; go = ""
        if i >= de.count {
            for x in kq where !x.ok { kho.sai(maCua(x.cau)) }
            vm.baoDiem("dekiru-on-tap-the-kiem-tra", Int((Double(kq.filter(\.ok).count) / Double(max(1, kq.count)) * 100).rounded()))
        }
    }

    private func maCua(_ c: Cau) -> String {
        switch c { case .tn(_, let id, _): return id; case .go(let t, _): return t.id; case .ds(let t, _, _): return t.id }
    }

    @ViewBuilder
    private var ketQua: some View {
        let dung = kq.filter(\.ok).count
        let tl = Double(dung) / Double(max(1, kq.count))
        VStack(alignment: .leading, spacing: 10) {
            Text("\(dung)/\(kq.count)").font(.system(size: 34, weight: .heavy)).foregroundColor(AppColors.primary).frame(maxWidth: .infinity)
            Text(tl >= 0.85 ? "🎉 Rất chắc rồi!" : tl >= 0.6 ? "Khá ổn — ôn lại các câu sai bên dưới." : "Cần ôn thêm — vào “Ôn từ sai” để luyện lại các câu này.")
                .font(.system(size: 15)).frame(maxWidth: .infinity)
            ForEach(Array(kq.enumerated().filter { !$0.element.ok }), id: \.offset) { _, x in
                VStack(alignment: .leading, spacing: 3) {
                    switch x.cau {
                    case .tn(let q, _, let d):
                        Text(q.tag).font(.system(size: 11.5)).foregroundColor(AppColors.textTertiary)
                        if case .chu(let s) = q.de { ChuSH(text: s, co: 15) }
                        if case .the(let t, let dd) = q.de { ChuSH(text: dd == "vj" ? t.vi : t.jp, co: 15) }
                        ChuSH(text: "Đáp án: **\(d)**", co: 15, mau: .tot)
                    case .go(let t, _):
                        ChuSH(text: "\(t.jp) = **\(t.vi)** (\(t.ro))", co: 15)
                        Text("Bạn gõ: \(x.tl.isEmpty ? "(trống)" : x.tl)").font(.system(size: 12.5)).foregroundColor(AppColors.textSecondary)
                    case .ds(let t, let hien, let that):
                        ChuSH(text: "\(t.jp) = **\(t.vi)**", co: 15)
                        ChuSH(text: "Câu đúng/sai: “\(hien)” là \(that ? "ĐÚNG" : "SAI")", co: 12.5, mau: .phu)
                    }
                }
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.error.opacity(0.06)))
            }
            HStack { Spacer(); NutSH(ten: "Làm đề mới", bieuTuong: "arrow.clockwise") { batDau() } }
        }
    }

    private func batDau() {
        var out: [Cau] = []
        let goPool = pool.filter { $0.loai != "np" }.shuffled()
        for t in goPool.prefix(6) { out.append(.go(t, Bool.random() ? "jv" : "vj")) }
        for t in pool.shuffled().prefix(6) {
            let that = Bool.random()
            let sai = OnTheTienIch.nhieu(t, pool, tat, "jv", k: 1).first
            out.append(.ds(t, hien: that || sai == nil ? t.vi : sai!, that: that || sai == nil))
        }
        let dung = Set(out.map(maCua))
        var con: [Cau] = pool.filter { !dung.contains($0.id) }.map { .tn(.tuThe($0, pool, tat, dir), id: $0.id, dung: OnTheTienIch.chu($0, dir)) }
            + caus.map { .tn(.tuCau($0), id: $0.id, dung: $0.opts[$0.correct]) }
        con.shuffle()
        out += con.prefix(max(0, 20 - out.count))
        de = out.shuffled(); i = 0; kq = []; go = ""
    }
}

// MARK: - 8. Ôn từ sai (Leitner)

private struct OnTuSaiOT: View {
    let bo: BoTheSH
    let dir: String
    @ObservedObject var kho: KhoOnTheSH
    let bai: [Int]
    @State private var chiBaiChon = false
    @State private var q: [String] = []
    @State private var lat = false
    @State private var nhip = 0

    var body: some View {
        let theTheo = Dictionary(bo.the.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let cauTheo = Dictionary(bo.cau.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let muc = kho.st.srs.filter { id, _ in
            guard let n = theTheo[id]?.n ?? cauTheo[id]?.n else { return false }
            return !chiBaiChon || bai.contains(n)
        }
        let now = KhoOnTheSH.bayGio
        let denHan = muc.filter { ($0.value.last ?? 0) <= now }.count
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { b in
                    VStack(spacing: 1) {
                        Text("\(muc.filter { Int($0.value.first ?? 1) == b }.count)").font(.system(size: 18, weight: .heavy))
                        Text("Hộp \(b)").font(.system(size: 11, weight: .semibold))
                        Text(b == 1 ? "ôn ngay" : "+\(KhoOnTheSH.HOP_NGAY[b]) ngày").font(.system(size: 10)).foregroundColor(AppColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.backgroundTertiary))
                }
            }
            Toggle("Chỉ bài đang chọn", isOn: $chiBaiChon).toggleStyle(.button).font(.system(size: 13))
            Text("Đến hạn hôm nay: \(denHan) · tổng trong hộp: \(muc.count)").font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
            if let id = q.first {
                if let c = theTheo[id] {
                    Button { if !lat { lat = true; OnTheTienIch.noi(c) } } label: {
                        khungTheOT {
                            Text("Hộp \(Int(kho.st.srs[id]?.first ?? 1)) · \(OnTheTienIch.LOAI_TEN[c.loai] ?? "") · Bài \(c.n) · còn \(q.count)")
                                .font(.system(size: 11.5, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                            if lat { MatSauOT(c: c, dir: dir) } else { MatTruocOT(c: c, dir: dir); Text("Nhớ ra rồi chạm để lật").font(.system(size: 12.5)).foregroundColor(AppColors.textTertiary) }
                        }
                    }
                    .buttonStyle(.plain)
                    if lat {
                        HStack {
                            NutSH(ten: "✗ Chưa nhớ", phu: true) { cham(id, false) }
                            Spacer()
                            NutSH(ten: "✓ Nhớ") { cham(id, true) }
                        }
                    }
                } else if let cau = cauTheo[id] {
                    CauTNOT(cau: .tuCau(cau), tuChuyen: false) { cham(id, $0) }.id(nhip)
                }
            } else {
                TrongOT(chu: muc.isEmpty ? "Chưa có thẻ nào bị sai. Thẻ bạn sai ở bất kỳ cách ôn nào sẽ tự vào đây (hộp 1). Đúng thì lên hộp, sai thì về hộp 1; qua hộp 5 là thuộc hẳn."
                        : denHan > 0 ? "Có **\(denHan)** thẻ đến hạn." : "Hôm nay hết thẻ đến hạn — quay lại vào ngày mai nhé.",
                        nut: denHan > 0 ? ("Ôn \(denHan) thẻ đến hạn", { q = muc.filter { ($0.value.last ?? 0) <= KhoOnTheSH.bayGio }.map(\.key).shuffled(); lat = false }) : nil)
            }
        }
    }

    private func cham(_ id: String, _ ok: Bool) {
        kho.capNhat { st in
            let b = Int(st.srs[id]?.first ?? 1)
            if !ok { st.srs[id] = [1, KhoOnTheSH.bayGio] }
            else if b >= 5 { st.srs[id] = nil; st.thuoc[id] = 1 }
            else { st.srs[id] = [Double(b + 1), KhoOnTheSH.bayGio + Double(KhoOnTheSH.HOP_NGAY[b + 1]) * 86_400_000] }
        }
        q = ok ? Array(q.dropFirst()) : OnTheTienIch.chenLai(Array(q.dropFirst()), id)
        lat = false; nhip += 1
    }
}
