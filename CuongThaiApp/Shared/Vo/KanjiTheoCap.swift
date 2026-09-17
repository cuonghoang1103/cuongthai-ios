#if os(iOS)
import Foundation

/// Danh sách chữ để luyện viết, xếp theo cấp.
///
/// ⚠️ Vì sao danh sách nằm TRONG APP chứ không lấy từ máy chủ: bảng chữ của
/// `/my-language/ja/alphabet` chỉ có **8 chữ Hán** (đo trên production
/// 17/09/2026), trong khi kho NÉT (`/hanzi-stroke/:char`) phủ mọi kanji —
/// đo thật: 日 4 nét · 語 14 · 曜 18 · 議 20. Nên chỉ cần biết CHỮ NÀO cần
/// học, còn nét thì hỏi máy chủ từng chữ một.
///
/// Kana thì ngược lại: lấy từ `/alphabet` vì ở đó có sẵn phiên âm và cách
/// đọc, 220 mục đủ cả dakuten lẫn yōon.
enum KanjiTheoCap {

    struct Bo: Identifiable, Hashable {
        let id: String
        let ten: String
        let moTa: String
        /// Danh sách đã LỌC TRÙNG khi dựng — xem `init`.
        let chu: [String]
        var so: Int { chu.count }

        /// ⚠️ Lọc trùng ngay lúc dựng bộ.
        ///
        /// Danh sách kanji gõ tay dài hàng trăm chữ thì trùng là chuyện sẽ
        /// xảy ra, và một chữ lặp nghĩa là người học viết lại đúng chữ đó
        /// hai lần rồi tưởng mình còn thiếu. Đo 17/09/2026: bản gõ tay đầu
        /// tiên có `右` lặp ở N5 và `服` lặp ở N4.
        init(id: String, ten: String, moTa: String, chu: [String]) {
            self.id = id
            self.ten = ten
            self.moTa = moTa
            var thay = Set<String>()
            self.chu = chu.filter { thay.insert($0).inserted }
        }
    }

    /// JLPT N5 — 80 chữ, bộ tối thiểu để đọc được biển báo và câu đơn.
    static let n5 = Bo(
        id: "n5", ten: "Kanji N5", moTa: "80 chữ đầu tiên — số, ngày tháng, người, nơi chốn",
        chu: [
            "日","一","国","人","年","大","十","二","本","中",
            "長","出","三","時","行","見","月","後","前","生",
            "五","間","上","東","四","今","金","九","入","学",
            "高","円","子","外","八","六","下","来","気","小",
            "七","山","話","女","北","午","百","書","先","名",
            "川","千","水","半","男","西","電","校","語","土",
            "天","右","左","母","父","友","車","休","毎","週",
            "食","飲","何","雨","白","会","社","店","読","聞",
        ]
    )

    /// JLPT N4 — thêm ~170 chữ, đủ đọc hội thoại đời thường.
    static let n4 = Bo(
        id: "n4", ten: "Kanji N4", moTa: "~170 chữ — động từ, tính từ, đời sống",
        chu: [
            "会","同","事","自","社","発","者","地","業","方",
            "新","場","員","立","開","手","力","問","代","明",
            "動","京","目","通","言","理","体","田","主","題",
            "意","不","作","用","度","強","公","持","野","以",
            "思","家","世","多","正","安","院","心","界","教",
            "文","元","重","近","考","画","海","売","知","道",
            "集","別","物","使","品","計","死","特","私","始",
            "朝","運","終","台","広","住","真","有","口","少",
            "町","料","工","建","空","急","止","送","切","転",
            "研","足","究","楽","起","着","店","病","質","待",
            "試","族","銀","早","映","親","験","英","医","仕",
            "去","味","写","字","答","夜","音","注","帰","古",
            "歌","買","悪","図","週","室","歩","風","紙","黒",
            "花","春","赤","青","館","屋","色","走","秋","夏",
            "習","駅","洋","旅","服","夕","借","曜","飲","肉",
            "堂","鳥","飯","勉","冬","昼","茶","歯","牛","米",
            "魚","犬","漢","荷","昔","低","太","寺","門","森",
        ]
    )

    /// Chữ Hán theo CHỦ ĐỀ — học theo cụm nhớ lâu hơn học theo bảng.
    static let theoChuDe: [Bo] = [
        Bo(id: "so", ten: "Số đếm", moTa: "Số, ngày, tháng, tiền",
           chu: ["一","二","三","四","五","六","七","八","九","十","百","千","万","円","年","月","日","時","分","半"]),
        Bo(id: "thiennhien", ten: "Thiên nhiên", moTa: "Trời đất, thời tiết, cây cỏ",
           chu: ["山","川","田","天","気","雨","雪","風","花","草","木","林","森","石","土","水","火","空","海","星"]),
        Bo(id: "nguoi", ten: "Con người & gia đình", moTa: "Người thân, cơ thể",
           chu: ["人","男","女","子","父","母","兄","弟","姉","妹","友","目","口","耳","手","足","体","顔","心","名"]),
        Bo(id: "dichuyen", ten: "Đi lại & nơi chốn", moTa: "Giao thông, địa điểm",
           chu: ["行","来","帰","出","入","車","駅","道","町","国","店","家","校","室","館","社","院","屋","場","橋"]),
        Bo(id: "hoctap", ten: "Học tập", moTa: "Trường lớp, sách vở",
           chu: ["学","校","生","先","本","書","読","文","字","語","話","聞","見","教","習","答","問","題","考","知"]),
    ]

    static var tatCa: [Bo] { [n5, n4] + theoChuDe }
}
#endif
