import SwiftUI
import Kingfisher

// ════════════════════════════════════════════════════════════════
// LÀM BÀI
//
// Một câu một màn, vuốt/bấm để sang câu. Không dồn 50 câu vào một trang
// cuộn dài như web: trên điện thoại thì cuộn tìm câu 37 là cực hình, và
// người ta hay bấm nhầm đáp án của câu bên cạnh.
// ════════════════════════════════════════════════════════════════

@MainActor
final class LamBaiVM: ObservableObject {
    @Published var de: DeDangLam?
    @Published var luot: LuotThi?
    @Published var dangTai = true
    @Published var loi: String?
    @Published var viTri = 0
    /// Đáp án đã chọn: id câu → các chỉ số đáp án.
    @Published var chon: [Int: Set<Int>] = [:]
    @Published var conLai: Int = 0
    @Published var ketQua: XemLaiBaiThi?
    @Published var dangNop = false

    private let examId: Int
    /// Phòng ôn tập CuongMini: KHÔNG tính giờ, có khung hỏi AI và bình luận.
    let coAI: Bool
    private var dongHo: Timer?
    private var batDauLuc = Date()

    init(examId: Int, coAI: Bool) { self.examId = examId; self.coAI = coAI }

    var cauHoi: [CauHoiThi] { de?.questions ?? [] }
    var hienTai: CauHoiThi? { viTri < cauHoi.count ? cauHoi[viTri] : nil }
    var daLam: Int { chon.values.filter { !$0.isEmpty }.count }

    func batDau() async {
        dangTai = true; defer { dangTai = false }
        do {
            // Bắt đầu lượt TRƯỚC rồi mới lấy đề: máy chủ tự nối lại lượt
            // đang dở nếu có, nên thoát ra vào lại là làm tiếp, không mất bài.
            luot = try await APIClient.shared.request(.batDauLuotThi(examId: examId, coAI: coAI))
            de = try await APIClient.shared.request(.deDangLam(examId: examId))
            batDauLuc = Date()
            batDongHo()
            loi = nil
        } catch { loi = error.localizedDescription }
    }

    private func batDongHo() {
        // ⚠️ Phòng CuongMini KHÔNG tính giờ — máy chủ trả `expiresAt = null`
        // cho lượt `aiAssisted`. Không chặn ở đây thì nhánh `else` bên dưới
        // thấy `expiresAt` rỗng và tự đặt đồng hồ đủ `durationMinutes`, rồi
        // hết giờ là TỰ NỘP một bài ôn tập người ta đang làm dở.
        guard !coAI else { conLai = 0; return }
        let phut = de?.durationMinutes ?? 0
        guard phut > 0 else { return }
        // Nối lại lượt cũ thì đồng hồ phải tính từ `expiresAt` của máy chủ,
        // không phải từ lúc mở màn — không thì thoát ra vào lại là được
        // thêm nguyên một lượt thời gian.
        if let het = luot?.expiresAt, let moc = Date.tuChuoiISO(het) {
            conLai = max(0, Int(moc.timeIntervalSinceNow))
        } else {
            conLai = phut * 60
        }
        dongHo?.invalidate()
        dongHo = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.conLai > 0 {
                    self.conLai -= 1
                } else {
                    self.dongHo?.invalidate()
                    await self.nop()   // hết giờ thì nộp luôn, không hỏi
                }
            }
        }
    }

    func danhDau(_ cau: CauHoiThi, _ i: Int) {
        var s = chon[cau.id] ?? []
        if cau.chonNhieu {
            if s.contains(i) { s.remove(i) } else { s.insert(i) }
        } else {
            s = s.contains(i) ? [] : [i]
        }
        chon[cau.id] = s
        Haptics.cham()

        // Chọn xong câu MỘT đáp án thì tự sang câu sau — bớt một cú bấm cho
        // mỗi câu, mà bài 50 câu thì đó là 50 cú bấm.
        if !cau.chonNhieu, !s.isEmpty, viTri + 1 < cauHoi.count {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(220))
                withAnimation(.easeOut(duration: 0.2)) { self.viTri += 1 }
            }
        }
    }

    func nop() async {
        guard let l = luot, !dangNop else { return }
        dangNop = true; defer { dangNop = false }
        dongHo?.invalidate()
        let dapAn = chon.reduce(into: [String: [Int]]()) { m, kv in
            if !kv.value.isEmpty { m[String(kv.key)] = Array(kv.value).sorted() }
        }
        let giay = Int(Date().timeIntervalSince(batDauLuc))
        do {
            ketQua = try await APIClient.shared.request(
                .nopBaiTracNghiem(attemptId: l.attemptId, dapAn: dapAn, giay: giay))
        } catch { loi = error.localizedDescription }
    }

    func dung() { dongHo?.invalidate(); dongHo = nil }
}

struct LamBaiView: View {
    let de: DeThi
    /// `true` → "Bắt đầu thi với CuongMini": không đồng hồ, có nút hỏi AI và
    /// bình luận dưới mỗi câu.
    let coAI: Bool
    /// ⚠️ Mặc định TIẾNG ANH — đề gốc là tiếng Anh, bản Việt là bản dịch kèm
    /// theo. Đúng như web (`useState<'en'|'vi'>('en')`).
    @State private var ngonNgu: NgonNguDe = .anh
    @StateObject private var vm: LamBaiVM
    @Environment(\.dismiss) private var dismiss
    @State private var hoiThoat = false
    @State private var hoiNop = false
    @State private var hienLuoi = false
    @State private var hienMini = false

    init(de: DeThi, coAI: Bool = false) {
        self.de = de
        self.coAI = coAI
        _vm = StateObject(wrappedValue: LamBaiVM(examId: de.id, coAI: coAI))
    }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            if let kq = vm.ketQua {
                KetQuaView(kq: kq, de: de) { dismiss() }
            } else if vm.dangTai {
                ProgressView()
            } else if let l = vm.loi, vm.de == nil {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36)).foregroundColor(AppColors.warning)
                    Text(l).font(.body).foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Đóng") { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, Spacing.lg).padding(.vertical, 10)
                        .background(Capsule().fill(AppColors.primary))
                }
                .padding(Spacing.lg)
            } else {
                VStack(spacing: 0) {
                    thanhDau
                    if let c = vm.hienTai { khungCau(c) } else { Spacer() }
                    thanhDuoi
                }
                // Nút nổi, đúng chỗ web đặt (góc phải dưới). Nằm TRÊN nội
                // dung chứ không chen vào thanh đáy: thanh đáy đã kín chỗ
                // với Trước/Sau/Nộp bài, thêm nút thứ tư là cái nào cũng
                // nhỏ tới mức bấm trượt.
                if coAI, vm.luot != nil, vm.hienTai != nil {
                    nutMini
                }
            }
        }
        .task { if vm.de == nil { await vm.batDau() } }
        .onDisappear { vm.dung() }
        .alert("Thoát khỏi bài thi?", isPresented: $hoiThoat) {
            Button("Ở lại", role: .cancel) { }
            Button("Thoát", role: .destructive) { vm.dung(); dismiss() }
        } message: {
            // Phòng ôn tập KHÔNG có đồng hồ — dọa "đồng hồ vẫn chạy" ở đó là
            // nói sai, và người ta sẽ vội vàng vì một sức ép không có thật.
            Text(coAI
                 ? "Bài ôn tập được giữ lại. Vào lại đề này là làm tiếp từ đúng chỗ đang dở."
                 : "Bài đang làm được giữ lại. Vào lại đề này là làm tiếp, "
                 + "nhưng ĐỒNG HỒ VẪN CHẠY.")
        }
        .alert("Nộp bài?", isPresented: $hoiNop) {
            Button("Xem lại", role: .cancel) { }
            Button("Nộp") { Task { await vm.nop() } }
        } message: {
            Text("Bạn đã làm \(vm.daLam)/\(vm.cauHoi.count) câu."
                 + (vm.daLam < vm.cauHoi.count ? " Những câu chưa làm sẽ tính 0 điểm." : ""))
        }
        .sheet(isPresented: $hienLuoi) { luoiCau }
        .sheet(isPresented: $hienMini) {
            if let l = vm.luot, let c = vm.hienTai {
                CuongMiniView(examId: de.id, attemptId: l.attemptId,
                              questionId: c.id, nhanCau: "Câu \(vm.viTri + 1)")
                    // ⚠️ `id` phải đổi theo CÂU: `sheet` giữ nguyên view khi
                    // nội dung bên dưới đổi, nên không có dòng này thì mở
                    // CuongMini ở câu 6 vẫn thấy cuộc hỏi của câu 5 — đúng
                    // cái web né bằng `key={questionId}`.
                    .id(c.id)
                    .presentationDetents([.fraction(0.62), .large])
                    .presentationDragIndicator(.visible)
            }
        }
        // Cả màn dùng CHUNG một ngôn ngữ: bấm nút là đề bài và mọi đáp án đổi
        // cùng lúc, không có chuyện đề tiếng Anh mà đáp án tiếng Việt.
        .environment(\.ngonNguDe, ngonNgu)
    }

    // ── Nút nổi mở CuongMini ────────────────────────────────────
    private var nutMini: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    hienMini = true
                    Haptics.cham()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Hỏi CuongMini")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Capsule().fill(
                        LinearGradient(colors: [AppColors.primary, AppColors.primaryDark],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .shadow(color: AppColors.primary.opacity(0.35), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.trailing, Spacing.md)
                .padding(.bottom, 78)   // trên thanh Trước/Sau/Nộp bài
            }
        }
        .allowsHitTesting(true)
    }

    // ── Thanh trên ──────────────────────────────────────────────
    private var thanhDau: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Button { hoiThoat = true } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 38, height: 38).contentShape(Rectangle())
                }
                .accessibilityLabel("Thoát")

                Spacer()
                if coAI {
                    // Chỗ của đồng hồ, nhưng nói ngược lại: KHÔNG có đồng hồ.
                    // Để trống thì người quen phòng thi thật sẽ tưởng đồng hồ
                    // chưa kịp chạy và vẫn làm bài trong tâm thế bị đuổi.
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                        Text("Ôn tập · không tính giờ")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(AppColors.primary)
                } else if vm.conLai > 0 {
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text(dinhDang(vm.conLai))
                            .font(.system(size: 15, weight: .semibold))
                            .monospacedDigit()
                    }
                    // Năm phút cuối đổi màu — đủ để giục mà chưa tới mức doạ.
                    .foregroundColor(vm.conLai < 300 ? AppColors.error : AppColors.textPrimary)
                }
                Spacer()

                // Nút đổi ngôn ngữ, đúng chỗ web đặt. Nhãn là ngôn ngữ SẮP
                // chuyển sang, không phải ngôn ngữ đang xem.
                Button { ngonNgu = ngonNgu.doiSang } label: {
                    Text(ngonNgu.nhanNut)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(AppColors.border, lineWidth: 1))
                }
                .accessibilityLabel(ngonNgu == .viet ? "Chuyển sang tiếng Anh" : "Chuyển sang tiếng Việt")

                Button { hienLuoi = true } label: {
                    Image(systemName: "square.grid.3x3")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 38, height: 38).contentShape(Rectangle())
                }
                .accessibilityLabel("Danh sách câu hỏi")
            }

            HStack(spacing: 3) {
                ForEach(Array(vm.cauHoi.enumerated()), id: \.offset) { i, c in
                    Capsule()
                        .fill(i == vm.viTri ? AppColors.primary
                              : (vm.chon[c.id]?.isEmpty == false)
                                ? AppColors.success.opacity(0.65)
                                : AppColors.backgroundTertiary)
                        .frame(height: 3)
                }
            }
            .padding(.horizontal, Spacing.md)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.top, Spacing.sm)
    }

    // ── Câu hỏi ─────────────────────────────────────────────────
    private func khungCau(_ c: CauHoiThi) -> some View {
        ScrollViewReader { cuon in
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                NeoDauTrang()
                HStack(spacing: Spacing.sm) {
                    Text("Câu \(vm.viTri + 1)/\(vm.cauHoi.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                    if c.chonNhieu {
                        Text("Chọn \(c.soDapAn) đáp án")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Capsule().fill(AppColors.accent))
                    }
                    Spacer()
                    Text("\(nz(c.diem)) điểm")
                        .font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                }

                // Đề bài đi qua `NoiDungThi`: tách `|||`, dựng công thức
                // KaTeX, sơ đồ mermaid, bảng, ảnh và mã đã tô màu — đúng bộ
                // mà web dựng (`ExamRichContent.tsx`).
                NoiDungThi(chu: c.prompt, coChu: 17, laDeBai: true)

                // Ảnh đề bài (sơ đồ, đoạn mã chụp màn hình…). Qua
                // `getMediaUrl` vì máy chủ trả về KHOÁ R2 trần, không phải
                // URL đầy đủ.
                if let m = c.imageUrl, !m.isEmpty, let u = URL(string: duongAnh(m)) {
                    KFImage(u)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                }

                if let sc = c.starterCode, !sc.isEmpty {
                    KhoiMaNguon(ma: sc, ngonNgu: c.language, tieuDe: nil, choChep: false)
                }

                if let ds = c.options, !ds.isEmpty {
                    VStack(spacing: Spacing.sm) {
                        ForEach(Array(ds.enumerated()), id: \.offset) { i, o in
                            oDapAn(c, i, o.text)
                        }
                    }
                } else {
                    // Câu tự luận / lập trình: chưa làm được trên iOS, nói
                    // thẳng ra thay vì hiện một câu hỏi không có chỗ trả lời.
                    Text("Câu này cần gõ mã hoặc viết bài — hãy làm trên web. "
                       + "Trên app bạn vẫn nộp được phần trắc nghiệm.")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.warning)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(Spacing.md)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(AppColors.warning.opacity(0.12)))
                }

                // Bình luận theo câu — CHỈ trong phòng CuongMini, đúng như
                // web. Trong lượt thi tính điểm mà mở sẵn lời giải của người
                // khác ngay dưới đề thì không còn là thi nữa.
                //
                // ⚠️ Đặt NGOÀI nhánh `options`: câu lập trình cũng phải có
                // bình luận (web gate trên `kind === 'FE' && aiAssisted`, chứ
                // không phải trên "câu này có đáp án trắc nghiệm không").
                if coAI {
                    BinhLuanCauHoiView(questionId: c.id,
                                       toiLa: AppState.shared.currentUser?.id)
                        .id(c.id)
                    // Chỗ trống cho nút nổi CuongMini khỏi che mất nút "Gửi"
                    // của bình luận cuối cùng.
                    Color.clear.frame(height: 64)
                }
            }
            .padding(Spacing.md)
        }
        // Ba đường cùng đổi câu mà KHÔNG rời màn: nút "Câu tiếp" ở thanh đáy
        // cố định, lưới câu trong sheet, và cú tự nhảy sau khi chọn đáp án
        // câu một-lựa-chọn (`danhDau`). Câu dài thì cả ba đều mở câu mới ra
        // ngay giữa trang.
        .onChange(of: vm.viTri) { _, _ in cuon.veDauTrang() }
        }
    }

    private func oDapAn(_ c: CauHoiThi, _ i: Int, _ chu: String) -> some View {
        let chon = vm.chon[c.id]?.contains(i) ?? false
        return Button {
            vm.danhDau(c, i)
        } label: {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: c.chonNhieu
                      ? (chon ? "checkmark.square.fill" : "square")
                      : (chon ? "largecircle.fill.circle" : "circle"))
                    .font(.system(size: 19))
                    .foregroundColor(chon ? AppColors.primary : AppColors.textTertiary)
                // Đáp án cũng có thể mang `|||`, công thức hay mã — dùng
                // chung một bộ dựng với đề bài. `NoiDungThi` tự chọn: chuỗi
                // thường thì vẽ bằng `Text`, chỉ khi có thẻ/công thức mới
                // dựng WebView, nên 60 câu × 4 đáp án không thành 240 WebView.
                NoiDungThi(chu: chu, coChu: 15)
                Spacer(minLength: 0)
            }
            .padding(Spacing.md)
            .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(chon ? AppColors.primary.opacity(0.10) : AppColors.backgroundCard)
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .strokeBorder(chon ? AppColors.primary : Color.clear, lineWidth: 1.5)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // ── Thanh dưới ──────────────────────────────────────────────
    private var thanhDuoi: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) { vm.viTri = max(0, vm.viTri - 1) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(vm.viTri > 0 ? AppColors.textPrimary : AppColors.textTertiary)
                    .frame(width: 50, height: 46)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(AppColors.backgroundTertiary))
            }
            .disabled(vm.viTri == 0)
            .buttonStyle(.plain)

            if vm.viTri + 1 < vm.cauHoi.count {
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { vm.viTri += 1 }
                } label: {
                    Text("Câu tiếp")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 46)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(AppColors.primary))
                }
                .buttonStyle(.plain)
            } else {
                Button { hoiNop = true } label: {
                    HStack(spacing: Spacing.sm) {
                        if vm.dangNop { ProgressView().tint(.white) }
                        Text("Nộp bài").font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(AppColors.success))
                }
                .disabled(vm.dangNop)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.md)
    }

    // ── Lưới câu hỏi ────────────────────────────────────────────
    private var luoiCau: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6),
                          spacing: 8) {
                    ForEach(Array(vm.cauHoi.enumerated()), id: \.offset) { i, c in
                        Button {
                            vm.viTri = i
                            hienLuoi = false
                        } label: {
                            Text("\(i + 1)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor((vm.chon[c.id]?.isEmpty == false)
                                                 ? .white : AppColors.textPrimary)
                                .frame(maxWidth: .infinity).frame(height: 42)
                                .background(RoundedRectangle(cornerRadius: 10)
                                    .fill((vm.chon[c.id]?.isEmpty == false)
                                          ? AppColors.success : AppColors.backgroundCard))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(i == vm.viTri ? AppColors.primary : .clear,
                                                  lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Spacing.md)
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Đã làm \(vm.daLam)/\(vm.cauHoi.count)")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    /// Khoá R2 trần thì phải ghép tiền tố CDN; `http`/`blob`/`data` thì để
    /// nguyên — cùng bẫy đã làm vỡ ảnh xem trước hồi 02/07.
    private func duongAnh(_ s: String) -> String {
        if s.hasPrefix("http") || s.hasPrefix("data:") || s.hasPrefix("blob:") { return s }
        return APIClient.diaChiGoc + (s.hasPrefix("/") ? s : "/" + s)
    }

    private func dinhDang(_ g: Int) -> String {
        String(format: "%d:%02d", g / 60, g % 60)
    }
    private func nz(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.2g", v)
    }
}

// ── Kết quả ─────────────────────────────────────────────────────

struct KetQuaView: View {
    let kq: XemLaiBaiThi
    let de: DeThi
    let dong: () -> Void
    // Nằm trong cây của LamBaiView nên nhận thẳng ngôn ngữ đang chọn.
    @Environment(\.ngonNguDe) private var ngonNgu

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Text(kq.dat ? "🎉" : "📘").font(.system(size: 60))
            Text(kq.dat ? "Đạt!" : "Chưa đạt")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(kq.dat ? AppColors.success : AppColors.warning)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(String(format: "%.2g", kq.diem))
                    .font(.system(size: 46, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Text("/ \(String(format: "%.2g", kq.tongDiem))")
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.textTertiary)
            }

            if let dung = kq.soDung, let tong = kq.soCau {
                Text("Đúng \(dung)/\(tong) câu")
                    .font(.system(size: 15)).foregroundColor(AppColors.textSecondary)
            }

            Text(de.ten(ngonNgu))
                .font(.system(size: 13))
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            Spacer()

            // Đáp án đúng + lời giải của TỪNG câu đã nằm sẵn trong phản hồi
            // nộp bài, nên nút này không tốn thêm lời gọi mạng nào.
            NavigationLink {
                XemLaiView(xemLai: kq, tenDe: de.title)
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                    Text("Xem lại từng câu")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(AppColors.primary)
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(Capsule().strokeBorder(AppColors.primary.opacity(0.5), lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.lg)

            Button(action: dong) {
                Text("Xong")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Capsule().fill(AppColors.primary))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
    }
}
