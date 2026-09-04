import SwiftUI

// ════════════════════════════════════════════════════════════════
// CUONGMINI — KHUNG HỎI ĐÁP TRONG PHÒNG THI
//
// Bản iOS của `CuongMiniPanel.tsx`. Web là panel trượt từ phải; trên điện
// thoại đó là một tấm che gần hết màn mà vẫn để hở một dải vô dụng bên
// trái — dùng `sheet` với mốc kéo (`detent`) đúng thói quen iOS hơn: kéo
// lên đọc câu trả lời dài, kéo xuống nhìn lại đề bài mà KHÔNG mất cuộc hỏi.
//
// ⚠️ Cuộc hỏi đặt lại theo TỪNG CÂU (web dùng `key={questionId}` ở component
// cha). Giữ nguyên lịch sử khi sang câu khác là lượt sau mang theo ngữ cảnh
// của câu trước, và model trả lời câu 6 bằng dữ kiện của câu 5.
// ════════════════════════════════════════════════════════════════

@MainActor
final class CuongMiniVM: ObservableObject {
    @Published var luot: [LuotHoiMini] = []
    @Published var dangHoi = false
    @Published var dapAn: DapAnHien?
    @Published var baiHoc: BaiHocLienQuan?
    @Published var daTraBaiHoc = false
    @Published var nhaCungCap: NhaCungCapAI = .tuDong
    @Published var loi: String?

    let attemptId: Int
    let questionId: Int
    private var viec: Task<Void, Never>?

    init(attemptId: Int, questionId: Int) {
        self.attemptId = attemptId
        self.questionId = questionId
    }

    /// Tra bài học liên quan đúng MỘT lần cho mỗi câu.
    ///
    /// ⚠️ Máy chủ trả `data: null` cho câu chưa được gán chương, mà
    /// `APIClient.request` coi `data == nil` là lỗi. Nuốt lỗi ở đây là ĐÚNG —
    /// "chưa gán chương" không phải hỏng hóc, và web cũng làm y hệt
    /// (`.catch(() => setRelatedLesson(null))`).
    func napBaiHoc() async {
        guard !daTraBaiHoc else { return }
        daTraBaiHoc = true
        baiHoc = try? await APIClient.shared.request(
            .baiHocLienQuan(attemptId: attemptId, questionId: questionId))
    }

    func hienDapAn() async {
        do {
            dapAn = try await APIClient.shared.request(
                .hienDapAn(attemptId: attemptId, questionId: questionId))
            Haptics.xong()
        } catch {
            loi = error.localizedDescription
        }
    }

    func hoi(_ cheDo: CheDoHoi, chu: String = "") {
        guard !dangHoi else { return }
        let cau = chu.trimmingCharacters(in: .whitespacesAndNewlines)
        if cheDo == .hoiTuDo && cau.isEmpty { return }

        // Lịch sử = những lượt ĐÃ XONG. Lượt đang chạy chưa có nội dung, gửi
        // lên là thêm một dòng assistant RỖNG vào ngữ cảnh.
        let lichSu = luot.filter { !$0.dangChay }.map(\.goiTin)
        if cheDo == .hoiTuDo { luot.append(.nguoi(cau)) }
        luot.append(.may())
        let viTri = luot.count - 1
        dangHoi = true
        loi = nil
        Haptics.cham()

        viec = Task { [weak self] in
            guard let self else { return }
            var coChu = false
            for await sk in LuongCuongMini.hoi(
                attemptId: attemptId, questionId: questionId,
                cheDo: cheDo, cauHoi: cheDo == .hoiTuDo ? cau : nil,
                lichSu: lichSu, nhaCungCap: nhaCungCap.ma
            ) {
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
                        // Đã có chữ rồi thì giữ lại phần đọc được, chỉ ghi
                        // chú là bị đứt — xoá hết là người dùng mất luôn
                        // đoạn giải thích vừa đọc dở.
                        if viTri < luot.count { luot[viTri].dangChay = false }
                        loi = m
                    } else {
                        await lui(cheDo, cau, lichSu, viTri, loiSSE: m)
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

    /// Đường lùi: SSE hỏng mà chưa nhả chữ nào thì gọi `/ai/ask` một cục.
    /// Đúng như web — nó cũng `try { stream } catch { aiAsk }`.
    private func lui(_ cheDo: CheDoHoi, _ cau: String,
                     _ lichSu: [[String: String]], _ viTri: Int, loiSSE: String) async {
        var than: [String: Any] = ["questionId": questionId, "mode": cheDo.rawValue]
        if !cau.isEmpty { than["question"] = cau }
        if !lichSu.isEmpty { than["history"] = lichSu }
        if let p = nhaCungCap.ma { than["provider"] = p }
        do {
            let r: TraLoiCuongMini = try await APIClient.shared.request(
                .hoiCuongMini(attemptId: attemptId, than: than))
            guard viTri < luot.count else { return }
            luot[viTri].noiDung = r.answer
            luot[viTri].dangChay = false
            luot[viTri].coSan = r.cached ?? false
        } catch {
            if viTri < luot.count { luot.remove(at: viTri) }
            // Bỏ luôn lượt người dùng vừa thêm, để họ bấm gửi lại được ngay.
            if cheDo == .hoiTuDo, let cuoi = luot.last, cuoi.cuaToi { luot.removeLast() }
            // ⚠️ Ưu tiên câu của ĐƯỜNG LÙI: `perform` rút thẳng `message`
            // máy chủ gửi kèm (403 → "Hỏi CuongMini là tính năng Pro.",
            // 400 → "Bài thi đã nộp…"), sát thực tế hơn hẳn.
            // Trừ đúng một trường hợp: `decodingError` chỉ nói "sai định
            // dạng" — chẳng giúp gì, lúc đó lỗi gốc của SSE nói đúng hơn.
            if case .decodingError = (error as? APIError) ?? .unknown {
                loi = loiSSE
            } else {
                loi = error.localizedDescription
            }
        }
    }

    func dung() { viec?.cancel(); viec = nil; dangHoi = false }
}

// MARK: - Màn hình

struct CuongMiniView: View {
    let examId: Int
    let nhanCau: String
    @StateObject private var vm: CuongMiniVM
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var moLink

    @State private var chu = ""
    @State private var chacChan = false
    @FocusState private var dangGo: Bool

    init(examId: Int, attemptId: Int, questionId: Int, nhanCau: String) {
        self.examId = examId
        self.nhanCau = nhanCau
        _vm = StateObject(wrappedValue: CuongMiniVM(attemptId: attemptId, questionId: questionId))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                thanhModel
                if let b = vm.baiHoc { theBaiHoc(b) }
                Divider().background(AppColors.divider)
                khungChat
                if let l = vm.loi { bangLoi(l) }
                khungGo
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("CuongMini · \(nhanCau)")
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
        .task { await vm.napBaiHoc() }
        .onDisappear { vm.dung() }
    }

    // ── Chọn model ──────────────────────────────────────────────
    private var thanhModel: some View {
        HStack(spacing: 6) {
            Text("Model")
                .font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
            ForEach(NhaCungCapAI.allCases) { p in
                let chon = vm.nhaCungCap == p
                Button { vm.nhaCungCap = p; Haptics.cham() } label: {
                    Text(p.nhan)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(chon ? AppColors.primary : AppColors.textSecondary)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Capsule()
                            .fill(chon ? AppColors.primary.opacity(0.12) : Color.clear)
                            .overlay(Capsule().strokeBorder(
                                chon ? AppColors.primary : AppColors.border, lineWidth: 1)))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    // ── Bài học liên quan ───────────────────────────────────────
    private func theBaiHoc(_ b: BaiHocLienQuan) -> some View {
        Button {
            if let u = b.diaChi(examId: examId) { moLink(u) }
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "book.fill")
                    .font(.system(size: 12)).foregroundColor(AppColors.primary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Bài học liên quan")
                        .font(.system(size: 10)).foregroundColor(AppColors.textTertiary)
                    Text(b.lessonTitle.tachSongNgu(.viet))
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    Text(b.sectionTitle.tachSongNgu(.viet) + " · " + b.courseTitle.tachSongNgu(.viet))
                        .font(.system(size: 10.5)).foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 13)).foregroundColor(AppColors.primary)
            }
            .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm)
            .background(AppColors.primary.opacity(0.07))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // ── Khung hội thoại ─────────────────────────────────────────
    private var khungChat: some View {
        ScrollViewReader { cuon in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    if vm.luot.isEmpty && vm.dapAn == nil { loiChao }
                    ForEach(vm.luot) { l in bongBong(l) }
                    if let d = vm.dapAn { theDapAn(d) }
                    Color.clear.frame(height: 1).id("cuoi")
                }
                .padding(Spacing.md)
            }
            .onChange(of: vm.luot.count) { _, _ in
                withAnimation { cuon.scrollTo("cuoi", anchor: .bottom) }
            }
            .onChange(of: vm.dapAn?.kind) { _, _ in
                withAnimation { cuon.scrollTo("cuoi", anchor: .bottom) }
            }
        }
    }

    private var loiChao: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14)).foregroundColor(AppColors.primary)
                Text("Hỏi CuongMini về câu đang làm")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
            }
            Text("Cách làm, cách nhớ, kiến thức nền — hoặc gõ câu hỏi riêng của bạn. "
               + "CuongMini nhìn thấy ĐÚNG câu bạn đang mở, không cần chép đề vào.")
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundCard))
    }

    private func bongBong(_ l: LuotHoiMini) -> some View {
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
                // Đang chảy thì dựng bằng bộ markdown thuần Swift — rẻ, chạy
                // lại được sau MỖI mẩu chữ. Xong mới dựng công thức, đúng
                // như web (`renderMath={!t.streaming}`): công thức về một
                // nửa mà đem dựng thì nó nhảy loạn suốt lúc model đang gõ.
                TraLoiMini(chu: l.noiDung, xong: !l.dangChay)
                if l.coSan {
                    Label("Có sẵn — từng hỏi trước đó", systemImage: "bolt.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(AppColors.primary.opacity(0.12)))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(l.cuaToi ? AppColors.backgroundTertiary : AppColors.primary.opacity(0.07)))
    }

    // ── Thẻ đáp án ──────────────────────────────────────────────
    private func theDapAn(_ d: DapAnHien) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if d.laTracNghiem {
                Text("Đáp án đúng: \(d.chuCaiDapAn.isEmpty ? "—" : d.chuCaiDapAn)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppColors.warning)
            }
            if let r = d.rubric, !r.isEmpty {
                Text("Tiêu chí chấm")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                ForEach(Array(r.enumerated()), id: \.offset) { _, t in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").foregroundColor(AppColors.textTertiary)
                        Text((t.criterion ?? "").tachSongNgu(.viet)
                             + (t.diem.map { " — \($0)" } ?? ""))
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if let s = d.sampleSolution, !s.isEmpty {
                Text("Lời giải mẫu")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                KhoiMaNguon(ma: s, ngonNgu: nil, tieuDe: nil, choChep: true)
            }
            if let e = d.expectedOutput, !e.isEmpty {
                Text("Kết quả mong đợi")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                KhoiMaNguon(ma: e, ngonNgu: nil, tieuDe: nil, choChep: true)
            }
            if let g = d.explanation, !g.isEmpty {
                NoiDungThi(chu: g, coChu: 14)
            }
            if d.trongTron && !d.laTracNghiem {
                Text("Câu này chưa có đáp án mẫu — hỏi CuongMini để được gợi ý.")
                    .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.warning.opacity(0.10))
            .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(AppColors.warning.opacity(0.55), lineWidth: 1)))
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

    // ── Ô gõ + gợi ý + hiện đáp án ──────────────────────────────
    private var khungGo: some View {
        VStack(spacing: Spacing.sm) {
            if vm.luot.isEmpty { goiY }

            HStack(alignment: .bottom, spacing: Spacing.sm) {
                TextField("Hỏi CuongMini về câu này…", text: $chu, axis: .vertical)
                    .font(.system(size: 14.5))
                    .lineLimit(1...4)
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
                        vm.hoi(.hoiTuDo, chu: t)
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
                    .accessibilityLabel("Gửi")
                }
            }

            if vm.dapAn == nil { nutHienDapAn }
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundSecondary)
    }

    private var goiY: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(CheDoHoi.goiY) { m in
                    Button {
                        dangGo = false
                        vm.hoi(m)
                    } label: {
                        Label(m.nhan, systemImage: m.bieuTuong)
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

    /// Hai nhịp như web: bấm lần đầu là "Chắc chắn?", lần hai mới hiện.
    /// Hiện đáp án xong là mất hẳn ý nghĩa của việc tự làm — đừng để nó lỡ
    /// tay chạm trúng.
    private var nutHienDapAn: some View {
        Button {
            if chacChan {
                Task { await vm.hienDapAn() }
            } else {
                chacChan = true
                Haptics.cham()
            }
        } label: {
            Label(chacChan ? "Chắc chắn? Bấm lần nữa để hiện" : "Hiện đáp án",
                  systemImage: chacChan ? "exclamationmark.triangle" : "eye")
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(chacChan ? AppColors.warning : AppColors.textSecondary)
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .strokeBorder(chacChan ? AppColors.warning : AppColors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dựng câu trả lời

/// Markdown lúc đang chảy, markdown + công thức khi xong.
///
/// ⚠️ Đừng dựng WebView trong lúc chữ còn chảy: mỗi mẩu chữ là một lần nạp
/// lại cả trang, và công thức mới về một nửa (`$x =`) thì KaTeX dựng ra một
/// khối đỏ nhấp nháy. Web tránh đúng chỗ này bằng `renderMath={!t.streaming}`.
private struct TraLoiMini: View {
    let chu: String
    let xong: Bool
    @State private var cao: CGFloat = 40

    private var coCongThuc: Bool {
        chu.contains("$") || chu.contains("\\(") || chu.contains("\\[")
    }

    var body: some View {
        #if os(iOS)
        if xong && coCongThuc {
            NoiDungThiWeb(html: chu, chieuCao: $cao, laMarkdown: true)
                .frame(height: cao)
        } else {
            NoiDungMarkdown(noiDung: chu)
        }
        #else
        NoiDungMarkdown(noiDung: chu)
        #endif
    }
}
