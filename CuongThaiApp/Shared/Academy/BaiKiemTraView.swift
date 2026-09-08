import SwiftUI

// ════════════════════════════════════════════════════════════════
// BÀI KIỂM TRA TRONG BÀI HỌC — làm NGAY TRONG APP
//
// Trước 07/09/2026 màn này chỉ có một câu "Phần kiểm tra hiện làm trên
// website" kèm nút mở Safari, với chú thích trong mã nói "backend chưa có
// đường trả nội dung quiz". Chú thích đó SAI: `course.routes.ts` trả
// `quizData` trong `GET /courses/:id/lessons/:id` từ 11/07/2026. Một lần grep
// sót đã khoá tính năng gần hai tháng — xem
// `feedback_grep_khong_thay_khong_nghia_la_khong_co`.
//
// Bám ĐÚNG hành vi của `LessonQuizPlayer.tsx` để hai bên không lệch nhau:
//   • đếm ngược `timeLimitSeconds`, hết giờ TỰ NỘP
//   • câu trắc nghiệm chọn kiểu ô đánh dấu (một HOẶC nhiều đáp án đúng), chấm
//     bằng so KHỚP TẬP HỢP — nên chọn thừa cũng là sai
//   • câu tự luận KHÔNG chấm máy: hiện đáp án mẫu để tự đối chiếu
//   • điểm chỉ tính trên phần trắc nghiệm, và nói thẳng điều đó ra
//   • làm lại thoải mái, không lưu gì lên máy chủ
//
// Khác web đúng một chỗ, cố ý: có nút **hỏi gia sư AI ngay tại câu đang sai**,
// và câu hỏi mang theo cả đề + đáp án đúng + đáp án mình chọn. Trên web muốn
// vậy phải tự gõ lại đề vào ô chat.
// ════════════════════════════════════════════════════════════════

struct BaiKiemTraView: View {
    let de: QuizBai
    let lessonId: Int
    let tenBai: String
    let tenMon: String?
    /// Mở gia sư AI cho một câu.
    ///
    /// ⛔ Việc mở sheet phải do MÀN CHA làm, không làm ở đây. Đo thật
    /// 07/09/2026: đặt `.sheet(item:)` ngay trong màn này thì bấm nút không ra
    /// gì — im lặng, không lỗi. Màn bài học đã có hai `.sheet` (gia sư, mục
    /// lục) ở tầng trên, và một sheet thứ ba gắn vào view nằm bên trong
    /// `ScrollView` của nó thì không được trình bày. Đẩy ra ngoài bằng closure
    /// là hết, mà lại dùng chung đúng một sheet gia sư có sẵn.
    var khiHoiAI: (HoiVeCau) -> Void = { _ in }
    /// Gọi khi nộp bài lần đầu — web đánh dấu hoàn thành ngay lúc nộp.
    var khiNop: () -> Void = {}

    @State private var chon: [String: Set<Int>] = [:]
    @State private var tuLuan: [String: String] = [:]
    @State private var daNop = false
    @State private var conLai = 0
    @State private var batDauDem = false
    /// ⚠️ Mặc định của `\.ngonNguDe` là **tiếng Anh** — hợp cho phòng thi
    /// (đề FPTU gốc tiếng Anh) nhưng sai cho chỗ này: người học mở bài kiểm
    /// tra trong bài giảng tiếng Việt. Đặt `.viet` và cho đổi tại chỗ.
    @State private var ngonNgu: NgonNguDe = .viet

    private let dongHo = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var cauHoi: [QuizCauHoi] { de.cauHoi }
    private var cauTracNghiem: [QuizCauHoi] { cauHoi.filter { !$0.laTuLuan } }
    private var soTuLuan: Int { cauHoi.count - cauTracNghiem.count }
    private var tongDiem: Double { cauTracNghiem.reduce(0) { $0 + $1.diem } }

    private func dung(_ c: QuizCauHoi) -> Bool {
        !c.laTuLuan && (chon[c.id] ?? []) == c.dapAnDung && !c.dapAnDung.isEmpty
    }
    private var soDung: Int { cauTracNghiem.filter(dung).count }
    private var diemDat: Double { cauTracNghiem.filter(dung).reduce(0) { $0 + $1.diem } }
    private var daLam: Int {
        cauTracNghiem.filter { !(chon[$0.id] ?? []).isEmpty }.count
        + cauHoi.filter { $0.laTuLuan && !(tuLuan[$0.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if cauHoi.isEmpty {
                Text(T("Bài kiểm tra này chưa có câu hỏi."))
                    .font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Spacing.lg)
            } else {
                dauTrang
                ForEach(Array(cauHoi.enumerated()), id: \.element.id) { i, c in
                    theCauHoi(c, thuTu: i + 1)
                }
                chanTrang
            }
        }
        // Đặt cho CẢ cây: `NoiDungThi` (đề, giải thích, đáp án mẫu) đọc trường
        // này; nếu chỉ đổi ở chỗ lựa chọn thì đề và lựa chọn nói hai thứ tiếng
        // khác nhau.
        .environment(\.ngonNguDe, ngonNgu)
        .onAppear {
            if !batDauDem { conLai = de.giay; batDauDem = true }
        }
        .onReceive(dongHo) { _ in
            guard batDauDem, !daNop, de.giay > 0 else { return }
            if conLai <= 1 { conLai = 0; nop() } else { conLai -= 1 }
        }
    }

    // MARK: Đầu trang — đồng hồ

    private var dauTrang: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(T("Bài kiểm tra"))
                    .font(.system(size: 17, weight: .bold)).foregroundColor(AppColors.textPrimary)
                Text(motTa)
                    .font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
            }
            Spacer()
            Button {
                ngonNgu = ngonNgu == .viet ? .anh : .viet
            } label: {
                Label(ngonNgu == .viet ? "VI" : "EN", systemImage: "character.bubble")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(AppColors.backgroundTertiary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            if de.giay > 0 && !daNop {
                VStack(spacing: 2) {
                    Text(gioChu)
                        .font(.system(size: 20, weight: .bold).monospacedDigit())
                        // Hai phút cuối đổi màu: người làm bài không nhìn đồng
                        // hồ liên tục, nhưng một mảng màu đổi thì thấy ngay.
                        .foregroundColor(conLai <= 120 ? AppColors.error : AppColors.textPrimary)
                    Text(T("còn lại")).font(.system(size: 10)).foregroundColor(AppColors.textTertiary)
                }
            }
        }
    }

    private var motTa: String {
        var p = [String(format: T("%d câu · %d đã làm"), cauHoi.count, daLam)]
        if soTuLuan > 0 { p.append(String(format: T("%d câu tự luận"), soTuLuan)) }
        if de.giay > 0 { p.append(String(format: T("%d phút"), max(1, de.giay / 60))) }
        return p.joined(separator: " · ")
    }

    private var gioChu: String {
        let h = conLai / 3600, m = (conLai % 3600) / 60, s = conLai % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    // MARK: Một câu hỏi

    @ViewBuilder
    private func theCauHoi(_ c: QuizCauHoi, thuTu: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Text(String(format: T("Câu %d"), thuTu))
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(AppColors.primary.opacity(0.15))
                    .foregroundColor(AppColors.primary)
                    .clipShape(Capsule())
                if c.laTuLuan {
                    nhan(T("Tự luận"), AppColors.secondary)
                } else if c.dapAnDung.count > 1 {
                    // Nói TRƯỚC khi nộp. Chấm bằng khớp tập hợp, nên người
                    // tưởng chọn một đáp án sẽ sai mà không hiểu vì sao.
                    nhan(T("Chọn nhiều"), AppColors.warning)
                }
                Spacer()
                if daNop && !c.laTuLuan {
                    Image(systemName: dung(c) ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(dung(c) ? AppColors.success : AppColors.error)
                }
                if c.diem > 0 {
                    Text(String(format: T("%@ điểm"), soGon(c.diem)))
                        .font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                }
            }

            NoiDungThi(chu: c.question, coChu: 15, laDeBai: true)

            if let ma = c.code, !ma.isEmpty {
                KhoiMaView(ma: ma.boThoatDong, ngonNgu: c.codeLang)
            }

            if c.laTuLuan {
                oTuLuan(c)
            } else {
                ForEach(Array(c.luaChon.enumerated()), id: \.offset) { i, chuLuaChon in
                    hangLuaChon(c, i, chuLuaChon)
                }
            }

            if daNop { phanGiaiThich(c, thuTu: thuTu) }
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundTertiary.opacity(0.55))
        .cornerRadius(CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(vienCau(c), lineWidth: 1)
        )
    }

    private func vienCau(_ c: QuizCauHoi) -> Color {
        guard daNop, !c.laTuLuan else { return AppColors.divider }
        return (dung(c) ? AppColors.success : AppColors.error).opacity(0.5)
    }

    private func nhan(_ t: String, _ mau: Color) -> some View {
        Text(t).font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(mau.opacity(0.15)).foregroundColor(mau)
            .clipShape(Capsule())
    }

    private func hangLuaChon(_ c: QuizCauHoi, _ i: Int, _ chu: String) -> some View {
        let daChon = (chon[c.id] ?? []).contains(i)
        let laDung = c.dapAnDung.contains(i)
        // Sau khi nộp: tô XANH mọi đáp án đúng (kể cả cái bỏ sót) và tô ĐỎ cái
        // chọn nhầm. Chỉ tô cái mình chọn thì người sai không biết đúng là gì.
        let mau: Color = !daNop ? (daChon ? AppColors.primary : AppColors.divider)
            : laDung ? AppColors.success : (daChon ? AppColors.error : AppColors.divider)

        return Button {
            guard !daNop else { return }
            var t = chon[c.id] ?? []
            if t.contains(i) { t.remove(i) } else { t.insert(i) }
            chon[c.id] = t
        } label: {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: daChon ? "checkmark.square.fill" : "square")
                    .font(.system(size: 17)).foregroundColor(mau)
                Text(chuCai(i) + ". ")
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(mau)
                + Text(chu.boThoatDong.tachSongNgu(ngonNgu))
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 7).padding(.horizontal, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(mau.opacity(daNop && laDung ? 0.12 : daChon ? 0.10 : 0))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(mau.opacity(0.6), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .disabled(daNop)
    }

    private func oTuLuan(_ c: QuizCauHoi) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(T("Câu trả lời của bạn…"),
                      text: Binding(get: { tuLuan[c.id] ?? "" }, set: { tuLuan[c.id] = $0 }),
                      axis: .vertical)
                .lineLimit(3...10)
                .font(.system(size: 14))
                .padding(9)
                .background(AppColors.backgroundTertiary)
                .cornerRadius(9)
                .disabled(daNop)
            if daNop, let mau = c.sampleAnswer, !mau.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(T("ĐÁP ÁN MẪU — tự đối chiếu"))
                        .font(.system(size: 10, weight: .bold)).foregroundColor(AppColors.secondary)
                    NoiDungThi(chu: mau, coChu: 14, mauChu: AppColors.textSecondary)
                }
                .padding(9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.secondary.opacity(0.10))
                .cornerRadius(9)
            }
        }
    }

    @ViewBuilder
    private func phanGiaiThich(_ c: QuizCauHoi, thuTu: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let g = c.explanation, !g.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 11)).foregroundColor(AppColors.warning)
                    NoiDungThi(chu: g, coChu: 13.5, mauChu: AppColors.textSecondary)
                }
            }
            // Nút hỏi AI chỉ hiện ở câu SAI hoặc câu tự luận — câu đã đúng mà
            // mời hỏi thêm thì chỉ làm danh sách dài ra.
            if c.laTuLuan || !dung(c) {
                Button {
                    khiHoiAI(HoiVeCau(cau: c, thuTu: thuTu, daChon: chon[c.id] ?? []))
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles").font(.system(size: 12))
                        Text(c.laTuLuan ? T("Nhờ AI chấm câu này") : T("Hỏi AI vì sao sai"))
                            .font(.system(size: 12.5, weight: .semibold))
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(AppColors.primary)
                    .padding(.vertical, 9).padding(.horizontal, 10)
                    .frame(maxWidth: .infinity)
                    .background(AppColors.primary.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    // Nhãn chữ trần chỉ ăn chạm ĐÚNG trên nét chữ. Trên điện
                    // thoại đó là một dải cao ~15pt — hụt là chuyện thường.
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 2)
    }

    // MARK: Chân trang — nộp / kết quả

    @ViewBuilder
    private var chanTrang: some View {
        if daNop {
            VStack(spacing: Spacing.sm) {
                if !cauTracNghiem.isEmpty {
                    Text(String(format: T("%d/%d câu đúng"), soDung, cauTracNghiem.count))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(soDung * 2 >= cauTracNghiem.count ? AppColors.success : AppColors.error)
                    Text(String(format: T("%@/%@ điểm"), soGon(diemDat), soGon(tongDiem)))
                        .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                }
                if soTuLuan > 0 {
                    // Nói thẳng: điểm KHÔNG gồm phần tự luận. Không nói thì
                    // người học tưởng mình được chấm đủ.
                    Text(String(format: T("%d câu tự luận không tính vào điểm — đối chiếu với đáp án mẫu, hoặc nhờ AI chấm."), soTuLuan))
                        .font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
                        .multilineTextAlignment(.center)
                }
                Button {
                    chon = [:]; tuLuan = [:]; daNop = false; conLai = de.giay
                } label: {
                    Label(T("Làm lại"), systemImage: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(AppColors.backgroundTertiary)
                        .foregroundColor(AppColors.textPrimary)
                        .cornerRadius(CornerRadius.medium)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
        } else {
            Button(action: nop) {
                Text(daLam == 0 ? T("Nộp bài") : String(format: T("Nộp bài · %d/%d đã làm"), daLam, cauHoi.count))
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(AppColors.primary).foregroundColor(AppColors.onPrimary)
                    .cornerRadius(CornerRadius.medium)
            }
            .buttonStyle(.plain)
        }
    }

    private func nop() {
        guard !daNop else { return }
        daNop = true
        khiNop()
    }

    private func chuCai(_ i: Int) -> String {
        String(UnicodeScalar(65 + min(max(i, 0), 25))!)
    }
    private func soGon(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(format: "%.1f", d)
    }
}

// ── Câu muốn hỏi AI ─────────────────────────────────────────────

/// Gói MỘT câu (quiz trong bài, hoặc câu luyện cuối chương) thành ngữ cảnh cho
/// gia sư.
///
/// Giữ TRƯỜNG THUẦN chứ không giữ nguyên kiểu câu hỏi, để hai nguồn khác nhau
/// (`QuizCauHoi` của bài kiểm tra, `CauLuyen` của đề luyện chương) dùng chung
/// đúng một đường sang AI.
/// Bảy việc học viên hay cần hỏi về MỘT câu.
///
/// Chép đúng bộ `QUICK` của CuongMini trong Phòng thi (và bộ `VIEC_HOI` bên
/// web) — người học đã quen bộ này ở Phòng thi; hai chỗ hỏi cùng một loại câu
/// mà nhãn khác nhau thì họ phải học lại giao diện, và câu trả lời cũng lệch
/// nhau vì lời nhắc khác.
///
/// ⚠️ Câu gửi lên PHẢI mở đầu bằng "Câu N" — gia sư tra `quizContext` theo số
/// thứ tự người dùng thấy. Bỏ số đi là nó không biết đang hỏi câu nào.
enum ViecHoiAI: String, CaseIterable, Identifiable {
    case vaoDe, viSaoSai, kienThuc, ghiNho, loiHayGap, viDu, quyTac

    var id: String { rawValue }

    var nhan: String {
        switch self {
        case .vaoDe:     return T("Câu này làm như nào?")
        case .viSaoSai:  return T("Vì sao các đáp án khác sai?")
        case .kienThuc:  return T("Kiến thức của câu này là gì?")
        case .ghiNho:    return T("Nhớ như nào cho lâu?")
        case .loiHayGap: return T("Lỗi hay gặp ở câu này?")
        case .viDu:      return T("Cho ví dụ tương tự để luyện")
        case .quyTac:    return T("Tóm tắt quy tắc liên quan")
        }
    }

    func cauHoi(thuTu n: Int) -> String {
        switch self {
        case .vaoDe:
            return String(format: T("Câu %d: hướng dẫn tôi cách làm câu này từng bước, đừng chỉ đưa đáp án."), n)
        case .viSaoSai:
            return String(format: T("Câu %d: vì sao đáp án đúng là đúng, và MỖI đáp án còn lại sai ở chỗ nào?"), n)
        case .kienThuc:
            return String(format: T("Câu %d: câu này kiểm tra kiến thức gì? Giảng lại phần lý thuyết đó cho tôi."), n)
        case .ghiNho:
            return String(format: T("Câu %d: cho tôi một cách ghi nhớ dễ thuộc cho phần kiến thức của câu này."), n)
        case .loiHayGap:
            return String(format: T("Câu %d: người học hay sai ở chỗ nào khi làm dạng câu này? Làm sao tránh?"), n)
        case .viDu:
            return String(format: T("Câu %d: cho tôi 2 câu tương tự để luyện thêm, kèm đáp án và giải thích."), n)
        case .quyTac:
            return String(format: T("Câu %d: tóm tắt công thức/quy tắc liên quan thành vài gạch đầu dòng dễ tra lại."), n)
        }
    }
}

struct HoiVeCau: Identifiable {
    let id: String
    let thuTu: Int
    let deBai: String
    let luaChon: [String]
    let dapAnDung: [Int]
    let giaiThich: String?
    let daChon: [Int]
    let laTuLuan: Bool
    /// Người dùng bấm con chip nào. `nil` = mở thẳng (giữ hành vi cũ: câu sai
    /// thì hỏi "sai ở đâu").
    var viec: ViecHoiAI?

    init(cau: QuizCauHoi, thuTu: Int, daChon: Set<Int>, viec: ViecHoiAI? = nil) {
        self.viec = viec
        // Máy chủ KHÔNG đọc `sampleAnswer`. Gộp vào `explanation` để câu tự
        // luận vẫn có gì đó cho AI đối chiếu.
        var g = cau.explanation ?? ""
        if let s = cau.sampleAnswer, !s.isEmpty {
            g = g.isEmpty ? T("Đáp án mẫu: ") + s : g + "\n" + T("Đáp án mẫu: ") + s
        }
        self.id = cau.id
        self.thuTu = thuTu
        self.deBai = cau.question
        self.luaChon = cau.luaChon
        self.dapAnDung = cau.dapAnDung.sorted()
        self.giaiThich = g.isEmpty ? nil : g
        self.daChon = daChon.sorted()
        self.laTuLuan = cau.laTuLuan
    }

    init(cau: CauLuyen, thuTu: Int, daChon: Set<Int>, viec: ViecHoiAI? = nil) {
        self.viec = viec
        self.id = "luyen-\(cau.id)"
        self.thuTu = thuTu
        self.deBai = cau.prompt
        self.luaChon = cau.luaChon
        self.dapAnDung = cau.dapAnDung.sorted()
        self.giaiThich = cau.explanation
        self.daChon = daChon.sorted()
        self.laTuLuan = false
    }

    /// ⚠️ Tên trường phải KHỚP `TutorAskOpts.quizContext` ở
    /// `courseTutor.service.ts:239`: {n, prompt, options, correctIndexes,
    /// explanation}. Gửi "correct" thay vì "correctIndexes" thì máy chủ im
    /// lặng bỏ qua, AI mất phần đáp án và trả lời đoán mò — hỏng kiểu không có
    /// lỗi nào hiện ra.
    var boiCanh: [[String: Any]] {
        var m: [String: Any] = ["n": thuTu, "prompt": deBai]
        m["options"] = luaChon
        m["correctIndexes"] = dapAnDung
        if let g = giaiThich, !g.isEmpty { m["explanation"] = g }
        return [m]
    }

    var cauMoDau: String {
        // Bấm một con chip cụ thể thì hỏi đúng việc đó.
        if let v = viec { return v.cauHoi(thuTu: thuTu) }
        if laTuLuan {
            return String(format: T("Chấm giúp tôi câu %d: tôi trả lời còn thiếu gì so với đáp án mẫu?"), thuTu)
        }
        let toi = daChon.map { String(UnicodeScalar(65 + $0)!) }.joined(separator: ", ")
        return toi.isEmpty
            ? String(format: T("Câu %d tôi bỏ trống. Giải thích giúp tôi đáp án đúng và cách suy ra nó."), thuTu)
            : String(format: T("Câu %d tôi chọn %@ và sai. Sai ở đâu, và vì sao đáp án kia đúng?"), thuTu, toi)
    }
}


extension String {
    /// Nội dung quiz cũ lưu "\\n" dạng hai ký tự — hiện ra là xuống dòng thật.
    /// (Web làm y hệt trong `unescapeText`.)
    var boThoatDong: String {
        guard contains("\\") else { return self }
        return replacingOccurrences(of: "\\r\\n", with: "\n")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\t", with: "  ")
    }
}
