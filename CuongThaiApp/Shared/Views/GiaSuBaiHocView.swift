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

// MARK: - ViewModel

@MainActor
final class GiaSuBaiVM: ObservableObject {
    @Published var luot: [LuotGiaSu] = []
    @Published var dangHoi = false
    @Published var loi: String?

    let lessonId: Int
    private var viec: Task<Void, Never>?

    init(lessonId: Int) { self.lessonId = lessonId }

    /// - Parameters:
    ///   - hienCauHoi: `false` khi bấm "Bản tiếng Anh"/"Hỏi lại mới" — hỏi lại
    ///     đúng câu cũ mà KHÔNG thêm một bong bóng câu hỏi trùng lặp.
    /// - Parameter boLichSu: hỏi lại ĐÚNG câu cũ (bản tiếng Anh / hỏi lại
    ///   mới) thì gửi lịch sử RỖNG. Xem ghi chú ở `xinTiengAnh`.
    func hoi(_ cau: String,
             khoaCache: String? = nil,
             tiengAnh: Bool = false,
             hienCauHoi: Bool = true,
             boLichSu: Bool = false) {
        let q = cau.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !dangHoi else { return }

        // Lịch sử = những lượt ĐÃ XONG. Lượt đang chạy chưa có nội dung, gửi
        // lên là thêm một dòng assistant RỖNG vào ngữ cảnh.
        let lichSu = boLichSu ? [] : luot.filter { !$0.dangChay }.map(\.goiTin)
        if hienCauHoi { luot.append(LuotGiaSu(cuaToi: true, noiDung: q)) }
        luot.append(LuotGiaSu(cuaToi: false, noiDung: "", dangChay: true,
                              laTiengAnh: tiengAnh,
                              cauGoc: tiengAnh ? nil : q, khoaCache: khoaCache))
        let viTri = luot.count - 1
        dangHoi = true
        loi = nil
        Haptics.cham()

        viec = Task { [weak self] in
            guard let self else { return }
            var coChu = false
            for await sk in LuongGiaSuBai.hoi(lessonId: lessonId, cauHoi: q,
                                              lichSu: lichSu, tiengAnh: tiengAnh,
                                              khoaCache: khoaCache) {
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
                                  hienCauHoi: hienCauHoi, loiSSE: m)
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
                     hienCauHoi: Bool, loiSSE: String) async {
        // Cùng cách nhắc như đường SSE — hai đường mà nhắc khác nhau thì
        // cùng một nút trả về hai thứ tiếng tuỳ hôm nào SSE hỏng.
        var than: [String: Any] = ["question": tiengAnh
            ? "[Answer entirely in English, regardless of the language of this question.]\n\n" + cau
            : cau]
        if !lichSu.isEmpty { than["history"] = lichSu }
        if tiengAnh { than["english"] = true }
        if let khoaCache { than["cacheKey"] = khoaCache }
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

    /// Bỏ cache, sinh câu trả lời tươi. KHÔNG gửi `cacheKey` — đó chính là
    /// cách bỏ qua cache (máy chủ chỉ tra cache khi có khoá). Cũng bỏ lịch sử,
    /// cùng lý do như `xinTiengAnh`: hỏi lại đúng câu vừa hỏi mà còn kèm lịch
    /// sử thì model chỉ nói "đã trả lời ở trên rồi".
    func hoiLaiMoi(_ i: Int) {
        guard i < luot.count, let cau = luot[i].cauGoc, !dangHoi else { return }
        hoi(cau, khoaCache: nil, tiengAnh: luot[i].laTiengAnh,
            hienCauHoi: false, boLichSu: true)
    }

    func dung() { viec?.cancel(); viec = nil; dangHoi = false }
}

// MARK: - Màn hình

struct GiaSuBaiHocView: View {
    let tenBai: String
    let tenMon: String?
    @StateObject private var vm: GiaSuBaiVM
    @Environment(\.dismiss) private var dismiss

    @State private var chu = ""
    @FocusState private var dangGo: Bool

    init(lessonId: Int, tenBai: String, tenMon: String?) {
        self.tenBai = tenBai
        self.tenMon = tenMon
        _vm = StateObject(wrappedValue: GiaSuBaiVM(lessonId: lessonId))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                khungChat
                if let l = vm.loi { bangLoi(l) }
                khungGo
            }
            .background(AppColors.backgroundPrimary)
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
                    Color.clear.frame(height: 1).id("cuoi")
                }
                .padding(Spacing.md)
            }
            .onChange(of: vm.luot.count) { _, _ in
                withAnimation { cuon.scrollTo("cuoi", anchor: .bottom) }
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
                Text(l.noiDung)
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
        let coMoi = l.coSan && l.cauGoc != nil
        if l.coSan || coAnh {
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
                    khoaCache: String?) -> AsyncStream<SuKienHoiDap> {
        // ⚠️⚠️ Nhắc lại yêu cầu tiếng Anh NGAY TRONG câu hỏi, không chỉ dựa
        // vào cờ `english`.
        //
        // Máy chủ có nhận cờ đó và có đổi system prompt sang
        // `LANGUAGE — Answer ENTIRELY in English` (đo được: nó tạo mục cache
        // riêng dưới `lang='en'`). Nhưng đo thật 05/09/2026, model VẪN trả lời
        // TIẾNG VIỆT: câu hỏi tiếng Việt + nội dung bài tiếng Việt lấn át một
        // dòng lệnh nằm cuối một system prompt dài — xem
        // [[feedback_fewshot_language_beats_instruction]].
        //
        // Lệnh đặt ngay đầu lượt NGƯỜI DÙNG thì gần chỗ sinh chữ nhất và
        // model nghe. Web KHÔNG có dòng này, nên nút "Bản tiếng Anh" bên đó
        // cũng đang trả về tiếng Việt.
        let cauGui = tiengAnh
            ? "[Answer entirely in English, regardless of the language of this question.]\n\n" + cauHoi
            : cauHoi
        var than: [String: Any] = ["question": cauGui]
        if !lichSu.isEmpty { than["history"] = lichSu }
        if tiengAnh { than["english"] = true }
        if let khoaCache { than["cacheKey"] = khoaCache }

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
