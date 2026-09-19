import SwiftUI

// ════════════════════════════════════════════════════════════════
// GIA SƯ AI CHO TỪNG BÀI HỌC ACADEMY
//
// Bản iOS của `CourseTutor.tsx`. Ngữ cảnh bài học được máy chủ TỰ GHÉP từ
// `lessonId` (nội dung bài + tên môn), nên client chỉ gửi câu hỏi + lịch sử —
// không phải chép nội dung bài vào câu hỏi.
//
//   POST /api/v1/courses/lessons/:id/ai/ask-stream   (đường chính, SSE)
//   POST /api/v1/courses/lessons/:id/ai/ask          (đường lùi, một cục)
//
// ⚠️ CHỈ dành cho tài khoản Pro — `assertPro()` chặn ở CẢ route lẫn service.
// ⚠️ Máy chủ KHÔNG lưu hội thoại; `history` phải gửi kèm mỗi lượt.
// ════════════════════════════════════════════════════════════════

// MARK: - Gợi ý mở màn

/// Bốn việc học viên cần nhất, đúng danh sách `QUICK` của web.
///
/// ⚠️ `khoa` là **khoá cache dùng chung**: ai bấm cùng một chip trên cùng một
/// bài đều nhận lại đúng câu trả lời đó, tức thì và KHÔNG tốn thêm một lượt
/// gọi AI nào. Đổi chuỗi này là mất sạch cache đã tích được, và người sau
/// phải trả tiền sinh lại.
enum GoiYGiaSu: String, CaseIterable, Identifiable {
    case batDau = "start"
    case baiTap = "exercises"
    case nenTang = "prereq"
    case phanKho = "hard"

    var id: String { rawValue }

    /// Câu hỏi gửi lên — phải khớp TỪNG CHỮ với web, vì cache tra theo
    /// `(lessonId, cacheKey, lang)` và câu chữ khác nhau thì hai bên sinh ra
    /// hai câu trả lời khác nhau dưới cùng một khoá.
    var cauHoi: String {
        switch self {
        case .batDau:  return "Bài này học gì? Tôi nên bắt đầu từ đâu?"
        case .baiTap:  return "Cho tôi 3 bài tập luyện + đáp án để tự kiểm tra."
        case .nenTang: return "Kiến thức nền nào cần có trước khi học bài này?"
        case .phanKho: return "Giảng lại phần khó nhất của bài một cách dễ hiểu."
        }
    }

    /// Nhãn ngắn cho nút — câu đầy đủ dài quá cho một con chip trên điện thoại.
    var nhan: String {
        switch self {
        case .batDau:  return "Bắt đầu từ đâu?"
        case .baiTap:  return "3 bài tập + đáp án"
        case .nenTang: return "Kiến thức nền"
        case .phanKho: return "Giảng phần khó nhất"
        }
    }

    var bieuTuong: String {
        switch self {
        case .batDau:  return "flag"
        case .baiTap:  return "pencil.and.list.clipboard"
        case .nenTang: return "square.stack.3d.up"
        case .phanKho: return "lightbulb"
        }
    }
}

// MARK: - Một lượt

struct LuotGiaSu: Identifiable, Equatable {
    let id = UUID()
    var cuaToi: Bool
    var noiDung: String
    var dangChay = false
    /// Câu trả lời lấy từ cache của máy chủ (chip gợi ý) — không tốn lượt gọi.
    var coSan = false
    /// Chính lượt này LÀ bản tiếng Anh (không mời dịch nó nữa).
    var laTiengAnh = false
    /// Câu hỏi đã sinh ra lượt này — để bấm "Bản tiếng Anh" / "Hỏi lại mới".
    var cauGoc: String?
    var khoaCache: String?
    /// Đã xin bản tiếng Anh cho lượt này rồi.
    var daXinAnh = false

    var goiTin: [String: String] { ["role": cuaToi ? "user" : "assistant", "content": noiDung] }
}

// MARK: - Câu hỏi thường gặp (đã lưu trên máy chủ)

/// Một lượt hỏi–đáp đã được lưu cho bài này, của bất kỳ ai.
///
/// ⚠️ `answer` là NGUYÊN VĂN, không cắt — máy chủ cố ý trả đủ. Cắt ở client
/// thì mục này mất hẳn ý nghĩa: người đọc lại vẫn phải hỏi AI một lượt nữa
/// để có phần đuôi, tức là vẫn tốn tiền đúng như chưa có mục này.
struct CauHoiLuu: Codable, Identifiable, Equatable {
    let id: Int
    let question: String
    let answer: String
    let lang: String?
    let nguoiHoi: String?
    let cuaToi: Bool?

    var laTiengAnh: Bool { (lang ?? "vi").lowercased().hasPrefix("en") }
}

private struct GoiCauHoiLuu: Codable { let items: [CauHoiLuu] }

// MARK: - ViewModel

@MainActor
final class GiaSuBaiVM: ObservableObject {
    @Published var luot: [LuotGiaSu] = []
    @Published var dangHoi = false
    @Published var loi: String?

    /// Câu hỏi thường gặp của bài — của mọi người, không riêng mình.
    @Published var thuongGap: [CauHoiLuu] = []
    @Published var dangTaiThuongGap = false
    /// Lượt nào đang mở xem đầy đủ.
    @Published var dangMo: Set<Int> = []

    let lessonId: Int
    /// Các câu quiz học viên đang làm — gửi kèm mỗi lượt hỏi để "câu 3" tra ra
    /// đúng câu. Hình dạng phải khớp `TutorAskOpts.quizContext` của
    /// `courseTutor.service.ts`: {n, prompt, options, correctIndexes, explanation}.
    var quizContext: [[String: Any]] = []
    private var viec: Task<Void, Never>?

    init(lessonId: Int, quizContext: [[String: Any]] = []) {
        self.lessonId = lessonId
        self.quizContext = quizContext
    }

    /// - Parameters:
    ///   - hienCauHoi: `false` khi bấm "Bản tiếng Anh"/"Hỏi lại mới" — hỏi lại
    ///     đúng câu cũ mà KHÔNG thêm một bong bóng câu hỏi trùng lặp.
    /// - Parameter boLichSu: hỏi lại ĐÚNG câu cũ (bản tiếng Anh / hỏi lại
    ///   mới) thì gửi lịch sử RỖNG. Xem ghi chú ở `xinTiengAnh`.
    func hoi(_ cau: String,
             khoaCache: String? = nil,
             tiengAnh: Bool = false,
             hienCauHoi: Bool = true,
             boLichSu: Bool = false,
             lamMoi: Bool = false) {
        let q = cau.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !dangHoi else { return }

        // Lịch sử = những lượt ĐÃ XONG. Lượt đang chạy chưa có nội dung, gửi
        // lên là thêm một dòng assistant RỖNG vào ngữ cảnh.
        let lichSu = boLichSu ? [] : luot.filter { !$0.dangChay }.map(\.goiTin)
        if hienCauHoi { luot.append(LuotGiaSu(cuaToi: true, noiDung: q)) }
        luot.append(LuotGiaSu(cuaToi: false, noiDung: "", dangChay: true,
                              laTiengAnh: tiengAnh,
                              // ⚠️ GIỮ `cauGoc` cả cho lượt tiếng Anh. Bản đầu để
                              // `nil`, và hậu quả là nút "Hỏi lại mới" KHÔNG hiện
                              // trên chính lượt tiếng Anh — tức đúng cái lượt đang
                              // giữ mục cache hỏng thì lại không sinh lại được.
                              // Việc "có mời dịch sang tiếng Anh không" đã do
                              // `laTiengAnh` quyết, không cần mượn `cauGoc`.
                              cauGoc: q, khoaCache: khoaCache))
        let viTri = luot.count - 1
        dangHoi = true
        loi = nil
        Haptics.cham()

        viec = Task { [weak self] in
            guard let self else { return }
            var coChu = false
            for await sk in LuongGiaSuBai.hoi(lessonId: lessonId, cauHoi: q,
                                              lichSu: lichSu, tiengAnh: tiengAnh,
                                              khoaCache: khoaCache, lamMoi: lamMoi,
                                              quizContext: quizContext) {
                if Task.isCancelled { break }
                switch sk {
                case .mau(let t):
                    coChu = true
                    if viTri < luot.count { luot[viTri].noiDung += t }
                case .xong(let day, let coSan):
                    if viTri < luot.count {
                        // THAY chứ không nối: `done` mang bản ĐẦY ĐỦ.
                        luot[viTri].noiDung = day
                        luot[viTri].dangChay = false
                        luot[viTri].coSan = coSan
                    }
                    coChu = true
                case .hong(let m):
                    if coChu {
                        // Đã đọc được một đoạn thì giữ lại, chỉ ghi chú bị đứt.
                        if viTri < luot.count { luot[viTri].dangChay = false }
                        loi = m
                    } else {
                        await lui(q, khoaCache, tiengAnh, lichSu, viTri,
                                  hienCauHoi: hienCauHoi, lamMoi: lamMoi, loiSSE: m)
                    }
                }
            }
            if viTri < luot.count, luot[viTri].dangChay {
                luot[viTri].dangChay = false
                if luot[viTri].noiDung.isEmpty { luot.remove(at: viTri) }
            }
            dangHoi = false
        }
    }

    /// SSE hỏng mà chưa nhả chữ nào → gọi `/ai/ask` một cục, đúng như web.
    private func lui(_ cau: String, _ khoaCache: String?, _ tiengAnh: Bool,
                     _ lichSu: [[String: String]], _ viTri: Int,
                     hienCauHoi: Bool, lamMoi: Bool, loiSSE: String) async {
        var than: [String: Any] = ["question": cau]
        if !lichSu.isEmpty { than["history"] = lichSu }
        if tiengAnh { than["english"] = true }
        if let khoaCache { than["cacheKey"] = khoaCache }
        if lamMoi { than["refresh"] = true }
        if !quizContext.isEmpty { than["quizContext"] = quizContext }
        do {
            let r: TraLoiGiaSu = try await APIClient.shared.request(
                .hoiGiaSuBai(lessonId: lessonId, than: than))
            guard viTri < luot.count else { return }
            luot[viTri].noiDung = r.answer
            luot[viTri].dangChay = false
            luot[viTri].coSan = r.cached ?? false
        } catch {
            if viTri < luot.count { luot.remove(at: viTri) }
            if hienCauHoi, let cuoi = luot.last, cuoi.cuaToi { luot.removeLast() }
            // Ưu tiên câu của đường lùi: `perform` rút thẳng `message` máy chủ
            // gửi kèm (403 → "Hỏi AI là tính năng Pro."), sát thực tế hơn hẳn.
            // Trừ `decodingError` — nó chỉ nói "sai định dạng", lúc đó lỗi gốc
            // của SSE nói đúng hơn.
            if case .decodingError = (error as? APIError) ?? .unknown {
                loi = loiSSE
            } else {
                loi = error.localizedDescription
            }
        }
    }

    /// Xin lại đúng câu đó bằng tiếng Anh. Dùng lại `khoaCache` để bản tiếng
    /// Anh cũng được cache dưới `lang='en'`.
    ///
    /// ⚠️⚠️ **GỬI LỊCH SỬ RỖNG.** Đo thật 05/09/2026: gửi kèm lịch sử thì
    /// model trả lời **bằng TIẾNG VIỆT** kèm câu "Bạn vừa hỏi lại câu này —
    /// tôi đã trả lời ở trên rồi nhé!" — dù system prompt của máy chủ đã ghi
    /// rõ `Answer ENTIRELY in English`.
    ///
    /// Hai thứ cùng đè lên cái lệnh đó:
    ///   • **Ngôn ngữ của few-shot thắng lệnh.** Cả đoạn hội thoại trước bằng
    ///     tiếng Việt, model bắt chước nó — xem
    ///     [[feedback_fewshot_language_beats_instruction]].
    ///   • Câu hỏi y HỆT vừa nằm trong lịch sử ⇒ model đọc ra là "hỏi trùng"
    ///     và đi trả lời chuyện đó thay vì trả lời câu hỏi.
    ///
    /// Mà đây vốn KHÔNG phải một lượt hội thoại tiếp theo — nó là DỰNG LẠI
    /// một câu trả lời bằng thứ tiếng khác. Không có lịch sử mới là đúng, và
    /// còn rẻ hơn (bớt cả nghìn token vào).
    func xinTiengAnh(_ i: Int) {
        guard i < luot.count, let cau = luot[i].cauGoc, !dangHoi else { return }
        luot[i].daXinAnh = true
        hoi(cau, khoaCache: luot[i].khoaCache, tiengAnh: true,
            hienCauHoi: false, boLichSu: true)
    }

    /// Sinh câu trả lời tươi VÀ ghi đè cache cho người sau.
    ///
    /// ⚠️ GIỮ `khoaCache` và gửi kèm `refresh: true`. Bản đầu bỏ luôn khoá để
    /// né bước ĐỌC cache — nhưng máy chủ cũng chỉ GHI khi có khoá, nên nó vừa
    /// không đọc vừa không ghi đè, và một mục cache hỏng nằm lại đó VĨNH VIỄN
    /// cho mọi người (cache này dùng chung, không phải của riêng ai). Cờ
    /// `refresh` thêm ở máy chủ 05/09/2026 là đường DUY NHẤT gỡ được.
    ///
    /// Cũng bỏ lịch sử, cùng lý do như `xinTiengAnh`.
    func hoiLaiMoi(_ i: Int) {
        guard i < luot.count, let cau = luot[i].cauGoc, !dangHoi else { return }
        hoi(cau, khoaCache: luot[i].khoaCache, tiengAnh: luot[i].laTiengAnh,
            hienCauHoi: false, boLichSu: true, lamMoi: true)
    }

    func dung() { viec?.cancel(); viec = nil; dangHoi = false }

    /// Nạp "câu hỏi thường gặp". Im lặng khi hỏng: đây là phần THÊM, hỏng nó
    /// không được làm hỏng màn hỏi đáp — người dùng vẫn hỏi được như thường.
    func taiThuongGap() async {
        guard !dangTaiThuongGap else { return }
        dangTaiThuongGap = true
        defer { dangTaiThuongGap = false }
        do {
            let goi: GoiCauHoiLuu = try await APIClient.shared.request(.cauHoiThuongGap(lessonId: lessonId))
            thuongGap = goi.items
        } catch {
            // Không đặt `loi`: bảng lỗi đó nói về việc HỎI, không phải về mục này.
        }
    }

    /// Xoá một lượt đã lưu. Máy chủ mới là nơi quyết định quyền (người hỏi
    /// hoặc admin); ở đây chỉ gỡ khỏi danh sách khi máy chủ đã đồng ý.
    func xoaThuongGap(_ id: Int) async {
        do {
            let _: EmptyResponse = try await APIClient.shared.request(
                .xoaCauHoiThuongGap(lessonId: lessonId, askId: id))
            thuongGap.removeAll { $0.id == id }
            dangMo.remove(id)
        } catch {
            loi = "Không xoá được câu hỏi này."
        }
    }

    /// Hỏi lại đúng một câu đã lưu — nhưng KHÔNG gọi AI: nhét thẳng câu trả
    /// lời cũ vào hội thoại. Đó là toàn bộ lý do mục này tồn tại.
    func dungLaiCauTraLoi(_ c: CauHoiLuu) {
        luot.append(LuotGiaSu(cuaToi: true, noiDung: c.question))
        var l = LuotGiaSu(cuaToi: false, noiDung: c.answer)
        l.coSan = true
        l.laTiengAnh = c.laTiengAnh
        luot.append(l)
    }
}

// MARK: - Màn hình

struct GiaSuBaiHocView: View {
    let tenBai: String
    let tenMon: String?
    @StateObject private var vm: GiaSuBaiVM
    @Environment(\.dismiss) private var dismiss

    @State private var chu = ""
    @FocusState private var dangGo: Bool

    /// Câu hỏi bắn đi NGAY khi mở, dùng khi vào từ một câu quiz sai. Người
    /// dùng bấm "Hỏi AI vì sao sai" là muốn câu trả lời, không phải muốn một ô
    /// trống để tự gõ lại đề.
    private let cauHoiSan: String?

    init(lessonId: Int,
         tenBai: String,
         tenMon: String?,
         quizContext: [[String: Any]] = [],
         cauHoiSan: String? = nil) {
        self.tenBai = tenBai
        self.tenMon = tenMon
        self.cauHoiSan = cauHoiSan
        _vm = StateObject(wrappedValue: GiaSuBaiVM(lessonId: lessonId, quizContext: quizContext))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                khungChat
                if let l = vm.loi { bangLoi(l) }
                khungGo
            }
            .background(AppColors.backgroundPrimary)
            // Vào từ một câu quiz sai thì HỎI LUÔN. `.task` chứ không
            // `.onAppear`: onAppear chạy lại mỗi lần màn quay lại tiền cảnh,
            // và sẽ hỏi lại câu cũ thêm một lượt nữa (tính tiền thêm một lượt).
            .task {
                if let c = cauHoiSan, vm.luot.isEmpty { vm.hoi(c) }
                await vm.taiThuongGap()
            }
            // Hỏi xong thì lượt vừa rồi đã được máy chủ lưu — nạp lại để nó
            // xuất hiện ngay trong mục dưới, không phải đóng mở lại màn hình.
            .onChange(of: vm.dangHoi) { cu, moi in
                if cu && !moi { Task { await vm.taiThuongGap() } }
            }
            .navigationTitle(tenMon.map { "Hỏi AI · \($0)" } ?? "Hỏi AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { vm.dung(); dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .accessibilityLabel("Đóng")
                }
            }
        }
        .onDisappear { vm.dung() }
    }

    // ── Hội thoại ───────────────────────────────────────────────
    private var khungChat: some View {
        ScrollViewReader { cuon in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    if vm.luot.isEmpty { loiChao }
                    ForEach(Array(vm.luot.enumerated()), id: \.element.id) { i, l in
                        bongBong(l, i)
                    }
                    // Mốc NGAY SAU tin cuối, TRƯỚC khối "Câu hỏi thường gặp".
                    Color.clear.frame(height: 1).id("sauTinCuoi")
                    if !vm.thuongGap.isEmpty { mucThuongGap }
                    Color.clear.frame(height: 1).id("cuoi")
                }
                .padding(Spacing.md)
            }
            // ⚠️ CUỘN TỚI SAU TIN CUỐI, KHÔNG PHẢI TỚI ĐÁY TRANG.
            //
            // Bản cũ cuộn tới mốc "cuoi", mà mốc đó nằm DƯỚI CẢ khối "Câu hỏi
            // thường gặp". Nên gửi câu mới xong là màn hình nhảy xuống dưới
            // khối FAQ, đẩy chính câu vừa hỏi LÊN TRÊN khỏi màn hình — người
            // dùng phải tự lướt ngược lên mò trong đống câu cũ. Báo lại
            // 10/09/2026: "nó nhảy thẳng lên đầu", "có khi nằm ở giữa".
            .onChange(of: vm.luot.count) { _, _ in
                withAnimation { cuon.scrollTo("sauTinCuoi", anchor: .bottom) }
            }
            // Và bám theo trong lúc chữ còn chảy: `count` không đổi khi câu
            // trả lời dài ra, nên chỉ nghe `count` là đứng im giữa chừng.
            .onChange(of: vm.luot.last?.noiDung) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    cuon.scrollTo("sauTinCuoi", anchor: .bottom)
                }
            }
        }

    }

    private var loiChao: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14)).foregroundColor(AppColors.primary)
                Text("Gia sư riêng cho bài này")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
            }
            Text(tenBai)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Hỏi bất cứ điều gì về bài đang học — bắt đầu từ đâu, chỗ chưa hiểu, "
               + "kiến thức nền còn thiếu, xin bài tập luyện, hoặc dán bài của bạn nhờ chữa. "
               + "Gia sư đã đọc sẵn nội dung bài, bạn không cần chép lại.")
                .font(.system(size: 13))
                .foregroundColor(AppColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundCard))
    }

    private func bongBong(_ l: LuotGiaSu, _ i: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if l.cuaToi {
                NoiDungMarkdown(noiDung: l.noiDung)
                    .font(.system(size: 14.5))
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if l.dangChay && l.noiDung.isEmpty {
                HStack(spacing: 7) {
                    ProgressView().controlSize(.small)
                    Text("Đang soạn…")
                        .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                }
            } else {
                // Markdown lúc chữ đang chảy, thêm công thức khi xong — đúng
                // như web (`renderMath={!t.streaming}`). Dùng lại đúng bộ dựng
                // của CuongMini để hai chỗ không hiện khác nhau.
                TraLoiAI(chu: l.noiDung, xong: !l.dangChay)
                if !l.dangChay { hangHanhDong(l, i) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(l.cuaToi ? AppColors.backgroundTertiary : AppColors.primary.opacity(0.07)))
    }

    @ViewBuilder
    private func hangHanhDong(_ l: LuotGiaSu, _ i: Int) -> some View {
        let coAnh = !l.laTiengAnh && l.cauGoc != nil && !l.daXinAnh
        // Hiện cho MỌI câu trả lời có nguồn, không chỉ câu lấy từ cache: một
        // câu tươi mà dở thì cũng vừa bị GHI vào cache dùng chung rồi.
        let coMoi = l.cauGoc != nil && l.khoaCache != nil
        if l.coSan || coAnh || coMoi {
            HStack(spacing: Spacing.md) {
                if l.coSan {
                    Label("Trả lời có sẵn", systemImage: "bolt.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(AppColors.primary.opacity(0.12)))
                }
                if coAnh {
                    Button { vm.xinTiengAnh(i) } label: {
                        Label("Bản tiếng Anh", systemImage: "character.bubble")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .disabled(vm.dangHoi)
                }
                if coMoi {
                    Button { vm.hoiLaiMoi(i) } label: {
                        Label("Hỏi lại mới", systemImage: "arrow.clockwise")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .disabled(vm.dangHoi)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // ── Câu hỏi thường gặp ──────────────────────────────────────
    //
    // Vì sao có mục này: mỗi lượt hỏi AI là một lần tính tiền, mà phần lớn
    // câu hỏi trên một bài học là TRÙNG NHAU. Người thứ hai gặp đúng chỗ khó
    // ấy chỉ cần mở ra đọc — nguyên văn câu trả lời cũ, tức thì, không tốn
    // thêm lượt nào. Web đã có; đây là bản iOS của đúng mục đó.
    private var mucThuongGap: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 12)).foregroundColor(AppColors.primary)
                Text("Câu hỏi thường gặp")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Text("\(vm.thuongGap.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.primary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(AppColors.primary.opacity(0.14)))
                Spacer(minLength: 0)
            }
            Text("Người học khác đã hỏi ở bài này. Mở ra đọc là xong — không tốn thêm lượt hỏi AI nào.")
                .font(.system(size: 11.5))
                .foregroundColor(AppColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(vm.thuongGap) { c in dongThuongGap(c) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundCard))
        .padding(.top, Spacing.sm)
    }

    @ViewBuilder
    private func dongThuongGap(_ c: CauHoiLuu) -> some View {
        let mo = vm.dangMo.contains(c.id)
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    if mo { vm.dangMo.remove(c.id) } else { vm.dangMo.insert(c.id) }
                }
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: mo ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(c.question)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(mo ? nil : 2)
                            .fixedSize(horizontal: false, vertical: mo)
                        HStack(spacing: 6) {
                            if let n = c.nguoiHoi {
                                Text(n).font(.system(size: 10.5))
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            if c.laTiengAnh {
                                Text("EN").font(.system(size: 9, weight: .bold))
                                    .foregroundColor(AppColors.textTertiary)
                                    .padding(.horizontal, 4).padding(.vertical, 1)
                                    .background(Capsule().fill(AppColors.backgroundTertiary))
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                // Nút chỉ có chữ thì vùng bấm bám sát từng chữ — bấm vào
                // khoảng trống bên phải không ăn. `.contentShape` mở vùng
                // bấm ra cả hàng.
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if mo {
                // Đúng bộ dựng của bong bóng trả lời, để hai chỗ không hiện
                // khác nhau. `xong: true` — câu này đã lưu, không còn chảy.
                TraLoiAI(chu: c.answer, xong: true)
                HStack(spacing: Spacing.md) {
                    Button { vm.dungLaiCauTraLoi(c) } label: {
                        Label("Đưa vào hội thoại", systemImage: "arrow.down.message")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                    if c.cuaToi == true {
                        Button(role: .destructive) {
                            Task { await vm.xoaThuongGap(c.id) }
                        } label: {
                            Label("Xoá", systemImage: "trash")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .top) {
            Rectangle().fill(AppColors.border).frame(height: 0.5)
        }
    }

    private func bangLoi(_ l: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12)).foregroundColor(AppColors.warning)
            Text(l).font(.system(size: 12.5)).foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button { vm.loi = nil } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm)
        .background(AppColors.warning.opacity(0.10))
    }

    // ── Ô gõ + gợi ý ────────────────────────────────────────────
    private var khungGo: some View {
        VStack(spacing: Spacing.sm) {
            if vm.luot.isEmpty { goiY }
            HStack(alignment: .bottom, spacing: Spacing.sm) {
                TextField("Hỏi về bài này — hoặc dán bài làm của bạn nhờ chữa…",
                          text: $chu, axis: .vertical)
                    .font(.system(size: 14.5))
                    // ⚠️ TẮT tự sửa. Đo thật 05/09/2026: gõ "phân biệt
                    // architecture và organization" bị bàn phím sửa thành
                    // "phân biệt ả chiết tử va ọganization" — câu hỏi kỹ
                    // thuật đầy từ tiếng Anh và mã nguồn, tự sửa chỉ phá.
                    // KHÔNG dùng `oKhongTuSua()`: nó tắt luôn viết hoa đầu
                    // câu, mà đây là ô gõ văn xuôi.
                    .autocorrectionDisabled()
                    .lineLimit(1...5)
                    .focused($dangGo)
                    .padding(.horizontal, Spacing.sm).padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(AppColors.backgroundTertiary))

                if vm.dangHoi {
                    Button { vm.dung() } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(AppColors.error))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dừng")
                } else {
                    Button {
                        let t = chu; chu = ""; dangGo = false
                        vm.hoi(t)
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(
                                chu.trimmingCharacters(in: .whitespaces).isEmpty
                                ? AppColors.textTertiary : AppColors.primary))
                    }
                    .buttonStyle(.plain)
                    .disabled(chu.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Hỏi")
                }
            }
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundSecondary)
    }

    private var goiY: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(GoiYGiaSu.allCases) { g in
                    Button {
                        dangGo = false
                        vm.hoi(g.cauHoi, khoaCache: g.rawValue)
                    } label: {
                        Label(g.nhan, systemImage: g.bieuTuong)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)
                            .padding(.horizontal, 11).padding(.vertical, 7)
                            .background(Capsule()
                                .fill(AppColors.backgroundTertiary)
                                .overlay(Capsule().strokeBorder(AppColors.border, lineWidth: 1)))
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.dangHoi)
                    .opacity(vm.dangHoi ? 0.4 : 1)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

// MARK: - Mạng

struct TraLoiGiaSu: Codable {
    let answer: String
    let cached: Bool?
}

enum LuongGiaSuBai {
    static func hoi(lessonId: Int,
                    cauHoi: String,
                    lichSu: [[String: String]],
                    tiengAnh: Bool,
                    khoaCache: String?,
                    lamMoi: Bool,
                    quizContext: [[String: Any]] = []) -> AsyncStream<SuKienHoiDap> {
        // ⚠️ KHÔNG tự chèn lệnh ép tiếng Anh vào câu hỏi nữa. Bản đầu của app
        // phải tự nhắc vì máy chủ chỉ ghi lệnh đó ở CUỐI system prompt và model
        // bỏ qua (lượt mồi của trợ lý bằng tiếng Việt lấn át — xem
        // [[feedback_fewshot_language_beats_instruction]]). Từ 05/09/2026 máy
        // chủ ép ở BA chỗ: lượt mồi trợ lý · nhãn ngữ cảnh · đầu lượt người
        // dùng. Nhắc thêm ở đây chỉ tổ lệnh hiện hai lần trong cùng một lượt.
        var than: [String: Any] = ["question": cauHoi]
        if !lichSu.isEmpty { than["history"] = lichSu }
        if tiengAnh { than["english"] = true }
        if let khoaCache { than["cacheKey"] = khoaCache }
        if lamMoi { than["refresh"] = true }
        if !quizContext.isEmpty { than["quizContext"] = quizContext }

        return LuongHoiDap.doc(
            duong: "/api/v1/courses/lessons/\(lessonId)/ai/ask-stream",
            than: than,
            loiTheoMa: { ma in
                switch ma {
                case 401: return "Phiên đăng nhập đã hết hạn."
                case 403: return "Hỏi AI là tính năng Pro."
                case 404: return "Không tìm thấy bài học này."
                // ⚠️ 400 ở đây KHÔNG phải "gửi sai": `assertAiReady()` dùng
                // chung mã đó cho cầu dao AI đang mở, hết hạn mức token/ngày,
                // và máy chủ tắt AI. Máy chủ gửi kèm câu giải thích — nhưng
                // luồng SSE trả lỗi trong THÂN chứ không ở mã HTTP, nên câu
                // dưới đây chỉ dùng khi chính lời gọi bị chặn trước đó.
                case 400: return "AI đang không dùng được (hết hạn mức hôm nay, hoặc đang tạm nghỉ)."
                default:  return "Máy chủ trả lỗi \(ma)"
                }
            })
    }
}
