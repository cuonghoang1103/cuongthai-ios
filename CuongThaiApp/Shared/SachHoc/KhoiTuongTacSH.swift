import SwiftUI

// ════════════════════════════════════════════════════════════════
// KHỐI TƯƠNG TÁC — chấm NGAY TẠI MÁY như web (Blocks.tsx · Blocks2.tsx):
// mcq (trắc nghiệm) · quiz (điền/dịch) · build (ghép câu) · dictation (nghe
// chép) · readkanji (đọc chữ Hán không furigana). Làm xong cả khối ⇒ báo điểm
// (%) về tiến độ — cùng `kind: baitap` web dùng.
//
// ĐỢT 2 (chưa native, hiện khung + mở trên web): write (viết tay + AI xem chữ),
// speak (ghi âm + AI chấm nói), essay (viết + AI chấm), phatam (Azure chấm phát
// âm), onthe (ôn thẻ 8 cách), vocabAll (tra cả khoá).
// ════════════════════════════════════════════════════════════════

/// Id bài đang đọc — để khung "đợt 2" mở đúng `?bai=` trên web.
private struct BaiDangDocKey: EnvironmentKey { static let defaultValue = "" }
extension EnvironmentValues {
    var baiDangDocSH: String {
        get { self[BaiDangDocKey.self] }
        set { self[BaiDangDocKey.self] = newValue }
    }
}

struct KhoiTuongTacSHView: View {
    let khoi: KhoiSH

    var body: some View {
        switch khoi {
        case .mcq(let id, let title, let items): TracNghiemSH(id: id, title: title, items: items)
        case .quiz(let id, let title, let kieu, let grammar, let items): DienSH(id: id, title: title, kieu: kieu, grammar: grammar, items: items)
        case .build(let id, let title, let items): GhepCauSH(id: id, title: title, items: items)
        case .dictation(let id, let title, let items): ChepNgheSH(id: id, title: title, items: items)
        case .readkanji(let id, let title, let note, let items): DocHanSH(id: id, title: title, note: note, items: items)
        case .chia: ChiaSH()
        case .hanlop(let bai): HanLopSH(bai: bai)
        case .write(_, let title, let chars, _):
            DotHaiSH(bieuTuong: "pencil.and.scribble", ten: "Tập viết tay", tieuDe: title,
                     moTa: "Ô mẫu chạy thứ tự nét + ô luyện viết bằng ngón tay/Apple Pencil, AI xem chữ — đang làm cho app (đợt 2). Chữ của phần này: " + chars.prefix(14).joined(separator: " ") + (chars.count > 14 ? " …" : ""))
        case .speak(_, let part, let questions):
            DotHaiSH(bieuTuong: "mic.fill", ten: "Luyện nói + AI chấm", tieuDe: "Speaking Part \(part)",
                     moTa: "Ghi âm câu trả lời rồi AI chấm — đợt 2. Câu hỏi: " + questions.prefix(3).map(PhanTichChuSH.tron).joined(separator: " · "))
        case .essay(_, let task, let prompt, let minWords, _):
            DotHaiSH(bieuTuong: "square.and.pencil", ten: "Viết bài + AI chấm", tieuDe: "Writing \(task) · tối thiểu \(minWords) từ",
                     moTa: PhanTichChuSH.tron(prompt))
        case .phatam(_, let title, _, let items):
            DotHaiSH(bieuTuong: "waveform", ten: "Chấm phát âm", tieuDe: title ?? "Luyện phát âm",
                     moTa: "Đọc to từng câu, máy chấm từng âm — đợt 2. \(items.count) câu.")
        case .onthe:
            DotHaiSH(bieuTuong: "rectangle.on.rectangle.angled", ten: "Ôn tập bằng thẻ", tieuDe: "8 cách ôn: thẻ lật · học · trắc nghiệm · gõ · nghe · ghép cặp · kiểm tra · ôn từ sai",
                     moTa: "Bộ thẻ từ vựng, chữ Hán của lớp và mẫu ngữ pháp mọi bài — đang làm bản app (đợt 2).")
        case .vocabAll:
            DotHaiSH(bieuTuong: "magnifyingglass", ten: "Tra từ cả khoá", tieuDe: "Tra cứu toàn bộ từ vựng", moTa: "Tìm, lọc theo buổi, thẻ nhớ — đợt 2.")
        case .chuaBiet(let t):
            DotHaiSH(bieuTuong: "questionmark.square.dashed", ten: "Chưa hỗ trợ", tieuDe: "Khối “\(t)”", moTa: "Bản app này chưa hiểu loại nội dung này — cập nhật app, hoặc mở trên web.")
        case .loi(let t, let chiTiet):
            DotHaiSH(bieuTuong: "exclamationmark.triangle", ten: "Không đọc được", tieuDe: "Khối “\(t)”", moTa: chiTiet)
        default:
            EmptyView()
        }
    }
}

// MARK: - Khung chung

struct KhungBaiTapSH<C: View>: View {
    let bieuTuong: String
    let tieuDe: String
    let huongDan: String
    @ViewBuilder var noiDung: C

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: bieuTuong).font(.system(size: 16, weight: .bold)).foregroundColor(AppColors.primary).padding(.top, 2)
                ChuSH(text: tieuDe, co: 17, dam: true)
            }
            Text(huongDan).font(.system(size: 13.5)).foregroundColor(AppColors.textSecondary)
            noiDung
        }
        .theKhoiSH(vien: AppColors.primary.opacity(0.35))
    }
}

struct SoCauSH: View {
    let n: Int
    var body: some View {
        Text("\(n)").font(.system(size: 13, weight: .bold).monospacedDigit()).foregroundColor(.white)
            .frame(minWidth: 24, minHeight: 24).background(Circle().fill(AppColors.primary))
    }
}

struct NutSH: View {
    let ten: String
    var bieuTuong: String?
    var phu = false
    let hanhDong: () -> Void
    var body: some View {
        Button(action: hanhDong) {
            HStack(spacing: 6) {
                if let bieuTuong { Image(systemName: bieuTuong) }
                Text(ten)
            }
            .font(.system(size: 14.5, weight: .semibold))
            .padding(.horizontal, 14).padding(.vertical, 9)
            .foregroundColor(phu ? AppColors.primary : .white)
            .background(Capsule().fill(phu ? AppColors.primary.opacity(0.12) : AppColors.primary))
        }
        .buttonStyle(.plain)
    }
}

struct PhanHoiSH: View {
    let dung: Bool
    let chu: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: dung ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(dung ? AppColors.success : AppColors.error)
            ChuSH(text: chu, co: 15, mau: dung ? .tot : .chinh)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill((dung ? AppColors.success : AppColors.error).opacity(0.10)))
    }
}

// MARK: - Trắc nghiệm

struct TracNghiemSH: View {
    let id: String
    let title: String
    let items: [CauChonSH]
    @EnvironmentObject private var vm: SachHocVM
    @State private var chon: [Int: Int] = [:]

    var body: some View {
        let soDung = items.indices.filter { chon[$0] == items[$0].correct }.count
        KhungBaiTapSH(bieuTuong: "checklist", tieuDe: title, huongDan: "Chọn một đáp án — thấy ngay đúng sai và lý do.") {
            ForEach(Array(items.enumerated()), id: \.offset) { i, it in
                CauTracNghiemSH(n: i + 1, cau: it, chon: chon[i]) { j in
                    chon[i] = j
                    if chon.count == items.count {
                        let d = items.indices.filter { chon[$0] == items[$0].correct }.count
                        vm.baoDiem(id, Int((Double(d) / Double(items.count) * 100).rounded()))
                    }
                }
            }
            if !chon.isEmpty {
                HStack {
                    Text("Đúng \(soDung)/\(chon.count) câu đã làm").font(.system(size: 14.5, weight: .bold)).foregroundColor(AppColors.textPrimary)
                    Spacer()
                    NutSH(ten: "Làm lại", bieuTuong: "arrow.counterclockwise", phu: true) { chon = [:] }
                }
            }
        }
        #if DEBUG
        // Màn soi (máy ảo không bấm được từ dòng lệnh): `CT_SACHHOC_DIEN=1` ⇒ câu 1 chọn đúng, câu 2 chọn sai.
        .onAppear {
            guard ProcessInfo.processInfo.environment["CT_SACHHOC_DIEN"] == "1", chon.isEmpty, items.count >= 2 else { return }
            chon = [0: items[0].correct, 1: (items[1].correct + 1) % max(1, items[1].options.count)]
        }
        #endif
    }
}

private struct CauTracNghiemSH: View {
    let n: Int
    let cau: CauChonSH
    let chon: Int?
    let bam: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                SoCauSH(n: n)
                ChuSH(text: cau.q, co: 17).frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(Array(cau.options.enumerated()), id: \.offset) { j, o in
                Button { if chon == nil { bam(j) } } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Text(String(UnicodeScalar(97 + j).map(Character.init) ?? "?") + ")")
                            .font(.system(size: 15, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                        ChuSH(text: o, co: 17).frame(maxWidth: .infinity, alignment: .leading)
                        if let chon, j == cau.correct { Image(systemName: "checkmark").foregroundColor(AppColors.success).opacity(chon >= 0 ? 1 : 0) }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(nen(j)))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(vien(j), lineWidth: 1.2))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(chon != nil)
            }
            if let chon {
                PhanHoiSH(dung: chon == cau.correct, chu: (chon == cau.correct ? "**Đúng.** " : "**Chưa đúng.** ") + cau.why)
            }
        }
        .padding(.top, 4)
    }

    private func nen(_ j: Int) -> Color {
        guard let chon else { return AppColors.backgroundTertiary }
        if j == cau.correct { return AppColors.success.opacity(0.14) }
        if j == chon { return AppColors.error.opacity(0.12) }
        return AppColors.backgroundTertiary.opacity(0.6)
    }
    private func vien(_ j: Int) -> Color {
        guard let chon else { return AppColors.border }
        if j == cau.correct { return AppColors.success }
        if j == chon { return AppColors.error }
        return AppColors.border
    }
}

// MARK: - Điền / dịch

/// So đáp án như `isRight` của web: tiếng Nhật/Trung bỏ hết dấu câu + khoảng trắng, NFKC;
/// tiếng Anh: thường hoá, bỏ dấu chấm cuối. Nhận cả dạng chữ Hán lẫn cách đọc của đáp án `{漢字|かな}`.
enum ChamSH {
    private static let ja = try! NSRegularExpression(pattern: "[\\u3040-\\u30ff\\u3400-\\u9fff]")
    static func chuan(_ x: String) -> String {
        let t = x.precomposedStringWithCompatibilityMapping
        if ja.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)) != nil {
            return t.components(separatedBy: CharacterSet(charactersIn: " \t\n　。、，．,.!?！？「」")).joined().lowercased()
        }
        var s = t.lowercased().replacingOccurrences(of: "’", with: "'").replacingOccurrences(of: "‘", with: "'")
        while let l = s.last, ".?!".contains(l) { s.removeLast() }
        return s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
    static func cacDang(_ a: String) -> [String] {
        let goc = PhanTichChuSH.tach(a)
        return [a, goc.map(\.text).joined(), goc.map { $0.ruby ?? $0.text }.joined()]
    }
    static func dung(_ g: String, _ answers: [String]) -> Bool {
        let c = chuan(g)
        guard !c.isEmpty else { return false }
        return answers.contains { cacDang($0).contains { chuan($0) == c } }
    }
}

struct DienSH: View {
    let id: String
    let title: String
    let kieu: String
    let grammar: String?
    let items: [CauDienSH]
    @EnvironmentObject private var vm: SachHocVM
    @State private var gia: [String]
    @State private var daCham = false
    @State private var xemDA: Set<Int> = []
    @State private var goiY: Set<Int> = []

    init(id: String, title: String, kieu: String, grammar: String?, items: [CauDienSH]) {
        self.id = id; self.title = title; self.kieu = kieu; self.grammar = grammar; self.items = items
        _gia = State(initialValue: Array(repeating: "", count: items.count))
    }

    private var tenTieng: String { vm.khoa?.ngonNgu == "ja" ? "Nhật" : vm.khoa?.ngonNgu == "zh" ? "Trung" : "Anh" }

    var body: some View {
        let kq = items.indices.map { ChamSH.dung(gia[$0], items[$0].answers) }
        KhungBaiTapSH(bieuTuong: "character.cursor.ibeam", tieuDe: title,
                      huongDan: kieu == "translate" ? "Gõ câu tiếng \(tenTieng)\(vm.khoa?.ngonNgu == "ja" ? " (kana hoặc kanji đều được)" : "") rồi bấm Kiểm tra." : "Gõ đáp án vào ô trống rồi bấm Kiểm tra.") {
            ForEach(Array(items.enumerated()), id: \.offset) { i, it in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        SoCauSH(n: i + 1)
                        VStack(alignment: .leading, spacing: 4) {
                            ChuSH(text: it.q + (kieu == "fill" && it.hint != nil ? " (\(it.hint!))" : ""), co: 17)
                            if (kieu == "translate" || grammar != nil) && (it.hint != nil || grammar != nil) {
                                Button { if goiY.contains(i) { goiY.remove(i) } else { goiY.insert(i) } } label: {
                                    Label("Gợi ý", systemImage: "lightbulb").font(.system(size: 13, weight: .semibold)).foregroundColor(AppColors.accent)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if goiY.contains(i) {
                        VStack(alignment: .leading, spacing: 4) {
                            if kieu == "translate", let h = it.hint { ChuSH(text: "**Từ vựng:** " + h, co: 14.5, mau: .phu) }
                            if let grammar { ChuSH(text: "**Ngữ pháp:** " + grammar, co: 14.5, mau: .phu) }
                        }
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.accent.opacity(0.09)))
                    }
                    TextField(kieu == "translate" ? "Câu tiếng \(tenTieng) của bạn…" : "Đáp án…", text: $gia[i], axis: .vertical)
                        .font(.system(size: 17))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.backgroundTertiary))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(!daCham || gia[i].isEmpty ? AppColors.border : (kq[i] ? AppColors.success : AppColors.error), lineWidth: 1.2))
                    if daCham, !gia[i].trimmingCharacters(in: .whitespaces).isEmpty {
                        if kq[i] {
                            PhanHoiSH(dung: true, chu: "Đúng")
                        } else if xemDA.contains(i) {
                            PhanHoiSH(dung: false, chu: "Chưa khớp đáp án mẫu. Đáp án: **\(it.answers.first ?? "")**")
                        } else {
                            HStack(spacing: 10) {
                                PhanHoiSH(dung: false, chu: "Chưa khớp đáp án mẫu.")
                                Button("Xem đáp án") { xemDA.insert(i) }.font(.system(size: 14, weight: .semibold))
                            }
                        }
                    }
                }
            }
            HStack {
                if daCham { Text("Đúng \(kq.filter { $0 }.count)/\(items.count)").font(.system(size: 14.5, weight: .bold)) }
                Spacer()
                if daCham {
                    NutSH(ten: "Làm lại", bieuTuong: "arrow.counterclockwise", phu: true) {
                        gia = Array(repeating: "", count: items.count); daCham = false; xemDA = []
                    }
                }
                NutSH(ten: "Kiểm tra", bieuTuong: "checkmark") {
                    daCham = true
                    vm.baoDiem(id, Int((Double(kq.filter { $0 }.count) / Double(max(1, items.count)) * 100).rounded()))
                }
            }
        }
    }
}

// MARK: - Ghép câu

/// Xếp con theo hàng, tự xuống dòng (mảnh ghép, chip).
struct HangCuonSH: Layout {
    var cach: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 600
        var x: CGFloat = 0, y: CGFloat = 0, hang: CGFloat = 0, rongNhat: CGFloat = 0
        for s in subviews {
            let k = s.sizeThatFits(ProposedViewSize(width: w, height: nil))
            if x > 0 && x + k.width > w { x = 0; y += hang + cach; hang = 0 }
            x += k.width + cach; hang = max(hang, k.height); rongNhat = max(rongNhat, x - cach)
        }
        return CGSize(width: proposal.width ?? rongNhat, height: y + hang)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = b.minX, y = b.minY, hang: CGFloat = 0
        for s in subviews {
            let k = s.sizeThatFits(ProposedViewSize(width: b.width, height: nil))
            if x > b.minX && x + k.width > b.maxX { x = b.minX; y += hang + cach; hang = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(k))
            x += k.width + cach; hang = max(hang, k.height)
        }
    }
}

struct GhepCauSH: View {
    let id: String
    let title: String
    let items: [CauGhepSH]
    @EnvironmentObject private var vm: SachHocVM
    @State private var kq: [Int: Bool] = [:]

    var body: some View {
        KhungBaiTapSH(bieuTuong: "puzzlepiece.extension", tieuDe: title, huongDan: "Đọc nghĩa tiếng Việt, bấm các mảnh theo đúng thứ tự để ghép câu. Bấm mảnh đã chọn để gỡ ra.") {
            ForEach(Array(items.enumerated()), id: \.offset) { i, it in
                CauGhepView(n: i + 1, cau: it) { ok in
                    kq[i] = ok
                    if kq.count == items.count {
                        vm.baoDiem(id, Int((Double(kq.values.filter { $0 }.count) / Double(items.count) * 100).rounded()))
                    }
                }
            }
            if !kq.isEmpty {
                Text("Đúng \(kq.values.filter { $0 }.count)/\(kq.count) câu đã làm").font(.system(size: 14.5, weight: .bold))
            }
        }
    }
}

private struct CauGhepView: View {
    let n: Int
    let cau: CauGhepSH
    let xong: (Bool) -> Void
    @State private var da: [Int] = []
    @State private var kq: Bool?
    @AppStorage(CaiDatDocSH.romaji) private var roma = true

    /// Xáo ổn định theo câu — giống `Math.sin((i+1)*(n+3)*7.13)` của web.
    private var thuTu: [Int] {
        cau.chips.indices.sorted { sin(Double($0 + 1) * Double(n + 3) * 7.13) < sin(Double($1 + 1) * Double(n + 3) * 7.13) }
    }
    private func noi(_ a: [String]) -> String { a.joined().filter { !$0.isWhitespace } }

    #if DEBUG
    /// Màn soi: `CT_SACHHOC_DIEN=1` ⇒ câu 1 ghép sẵn ĐÚNG + đã kiểm, câu 2 ghép dở.
    private func dienSan() {
        guard ProcessInfo.processInfo.environment["CT_SACHHOC_DIEN"] == "1", da.isEmpty else { return }
        if n == 1 {
            var con = Array(cau.chips.indices)
            da = cau.answer.compactMap { a in con.firstIndex { cau.chips[$0] == a }.map { con.remove(at: $0) } }
            kq = true
        } else if n == 2 { da = Array(thuTu.prefix(2)) }
    }
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                SoCauSH(n: n)
                ChuSH(text: cau.vi, co: 16.5).frame(maxWidth: .infinity, alignment: .leading)
            }
            // Câu đang ghép
            Group {
                if da.isEmpty {
                    Text("Bấm các mảnh bên dưới theo đúng thứ tự…").font(.system(size: 14)).foregroundColor(AppColors.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                } else {
                    HangCuonSH {
                        ForEach(Array(da.enumerated()), id: \.offset) { k, i in
                            manh(cau.chips[i], dangChon: true) { da.remove(at: k); kq = nil }
                        }
                    }
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.primary.opacity(0.4), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])))
            HangCuonSH {
                ForEach(thuTu, id: \.self) { i in
                    manh(cau.chips[i], dangChon: false) { da.append(i); kq = nil }
                        .opacity(da.contains(i) ? 0.3 : 1)
                        .disabled(da.contains(i))
                }
            }
            HStack(spacing: 8) {
                NutSH(ten: "Kiểm tra", bieuTuong: "checkmark") {
                    let chon = da.map { cau.chips[$0] }
                    let ok = ([cau.answer] + (cau.alt ?? [])).contains { noi($0) == noi(chon) }
                    kq = ok
                    xong(ok)
                    if ok { GiongSachHoc.chung.phat(ClipSH(text: cau.answer.joined()), khoa: "ghep|\(cau.answer.joined())") }
                }
                .disabled(da.isEmpty).opacity(da.isEmpty ? 0.5 : 1)
                NutSH(ten: "Xếp lại", bieuTuong: "arrow.counterclockwise", phu: true) { da = []; kq = nil }
            }
            if let kq {
                VStack(alignment: .leading, spacing: 4) {
                    PhanHoiSH(dung: kq, chu: kq ? "Đúng rồi!" : "Chưa đúng. Câu đúng: **\(cau.answer.joined(separator: " "))**")
                    if roma, let ro = cau.ro { Text(ro).font(.system(size: 13).italic()).foregroundColor(AppColors.textTertiary) }
                }
            }
        }
        .padding(.top, 4)
        #if DEBUG
        .onAppear { dienSan() }
        #endif
    }

    private func manh(_ t: String, dangChon: Bool, bam: @escaping () -> Void) -> some View {
        Button(action: bam) {
            ChuSH(text: t, co: 18)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 10).fill(dangChon ? AppColors.primary.opacity(0.15) : AppColors.backgroundTertiary))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(dangChon ? AppColors.primary : AppColors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Nghe chép

struct ChepNgheSH: View {
    let id: String
    let title: String?
    let items: [ChepSH]
    @EnvironmentObject private var vm: SachHocVM
    @State private var gia: [String]
    @State private var lanNghe: [Int]
    @State private var daCham: Set<Int> = []

    init(id: String, title: String?, items: [ChepSH]) {
        self.id = id; self.title = title; self.items = items
        _gia = State(initialValue: Array(repeating: "", count: items.count))
        _lanNghe = State(initialValue: Array(repeating: 0, count: items.count))
    }

    private func khop(_ a: String, _ c: String) -> Bool {
        a.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ") == c.lowercased()
    }

    var body: some View {
        KhungBaiTapSH(bieuTuong: "ear", tieuDe: title ?? "Nghe và chép lại", huongDan: "Trong phòng thi bạn chỉ được nghe một lần. Hãy cố nghe ít lần nhất.") {
            ForEach(Array(items.enumerated()), id: \.offset) { i, it in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        NutSH(ten: lanNghe[i] > 0 ? "Nghe (\(lanNghe[i]))" : "Nghe", bieuTuong: "speaker.wave.2.fill", phu: true) {
                            lanNghe[i] += 1
                            // Đánh vần: mỗi chữ một câu, như `kieu: 'danhvan'` của web.
                            let clips = it.spell.components(separatedBy: ",").map { ClipSH(text: $0.trimmingCharacters(in: .whitespaces), toc: 0.85) }
                            GiongSachHoc.chung.phat(clips, khoa: "chep|\(id)|\(i)")
                        }
                        Text("\(i + 1). \(it.label)").font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                    }
                    HStack(spacing: 8) {
                        TextField("Gõ lại điều bạn nghe…", text: $gia[i])
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .font(.system(size: 17)).padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.backgroundTertiary))
                            .onSubmit { cham(i) }
                        NutSH(ten: "Chấm") { cham(i) }
                    }
                    if daCham.contains(i) {
                        let ok = khop(gia[i], it.answer)
                        PhanHoiSH(dung: ok, chu: ok ? "Chính xác." : "Chưa đúng. Đáp án: **\(it.answer)**")
                    }
                }
            }
        }
    }

    private func cham(_ i: Int) {
        daCham.insert(i)
        let dung = items.indices.filter { daCham.contains($0) && khop(gia[$0], items[$0].answer) }.count
        vm.baoDiem(id, Int((Double(dung) / Double(items.count) * 100).rounded()))
    }
}

// MARK: - Đọc chữ Hán không furigana

struct DocHanSH: View {
    let id: String
    let title: String
    let note: String?
    let items: [CauDocHanSH]
    @EnvironmentObject private var vm: SachHocVM
    @State private var hang: [Int]
    @State private var hien = false
    @State private var lanDau: [Int: Bool] = [:]

    init(id: String, title: String, note: String?, items: [CauDocHanSH]) {
        self.id = id; self.title = title; self.note = note; self.items = items
        _hang = State(initialValue: Array(items.indices))
    }

    var body: some View {
        KhungBaiTapSH(bieuTuong: "character.ja", tieuDe: title,
                      huongDan: note.map(PhanTichChuSH.tron) ?? "Giống đề thi: chữ Hán KHÔNG có furigana. Đọc to trước, rồi bấm \"Xem cách đọc\" để kiểm tra. Câu chưa đọc được sẽ quay lại cuối lượt.") {
            if let cur = hang.first {
                let it = items[cur]
                VStack(alignment: .leading, spacing: 10) {
                    Text("Còn \(hang.count) câu · câu \(cur + 1)/\(items.count)").font(.system(size: 13)).foregroundColor(AppColors.textTertiary)
                    ChuSH(text: it.text, co: 26, khongFurigana: !hien)
                        .padding(.vertical, 6)
                    if hien {
                        Text(it.ro).font(.system(size: 15).italic()).foregroundColor(AppColors.textTertiary)
                        ChuSH(text: it.vi, co: 15.5, mau: .phu)
                    }
                    HStack(spacing: 8) {
                        if !hien {
                            NutSH(ten: "Xem cách đọc + nghe", bieuTuong: "eye") {
                                hien = true
                                GiongSachHoc.chung.phat(ClipSH(text: it.text), khoa: "dochan|\(it.text)")
                            }
                        } else {
                            NutSH(ten: "Mình đọc được", bieuTuong: "checkmark") { danh(cur, true) }
                            NutSH(ten: "Chưa", bieuTuong: "xmark", phu: true) { danh(cur, false) }
                            NutLoaSH(text: it.text, co: 36)
                        }
                    }
                }
            } else {
                HStack {
                    Text("Lần đầu đọc đúng \(lanDau.values.filter { $0 }.count)/\(items.count) câu").font(.system(size: 15, weight: .bold))
                    Spacer()
                    NutSH(ten: "Làm lại", bieuTuong: "arrow.counterclockwise", phu: true) { hang = Array(items.indices); lanDau = [:] }
                }
            }
        }
    }

    private func danh(_ cur: Int, _ ok: Bool) {
        if lanDau[cur] == nil { lanDau[cur] = ok }
        var con = Array(hang.dropFirst())
        if !ok { con.append(cur) }
        hang = con
        hien = false
        if con.isEmpty { vm.baoDiem(id, Int((Double(lanDau.values.filter { $0 }.count) / Double(items.count) * 100).rounded())) }
    }
}

// MARK: - Khung "đợt 2"

struct DotHaiSH: View {
    let bieuTuong: String
    let ten: String
    let tieuDe: String
    let moTa: String
    @EnvironmentObject private var vm: SachHocVM
    @Environment(\.baiDangDocSH) private var baiId
    @Environment(\.openURL) private var moURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: bieuTuong).font(.system(size: 15, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                Text(ten.uppercased()).font(.system(size: 11, weight: .heavy)).kerning(0.5).foregroundColor(AppColors.textSecondary)
                Spacer()
                Text("Sắp có trên app").font(.system(size: 11, weight: .bold)).foregroundColor(AppColors.accent)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(AppColors.accent.opacity(0.12)))
            }
            ChuSH(text: tieuDe, co: 16, dam: true)
            ChuSH(text: moTa, co: 14.5, mau: .phu)
            if let duong = vm.khoa?.duongWeb, !baiId.isEmpty,
               let url = URL(string: "https://cuongthai.com\(duong)?bai=\(baiId)") {
                Button { moURL(url) } label: {
                    Label("Làm phần này trên web", systemImage: "safari").font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain).foregroundColor(AppColors.primary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.backgroundTertiary.opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AppColors.border, style: StrokeStyle(lineWidth: 1, dash: [6, 4])))
    }
}
