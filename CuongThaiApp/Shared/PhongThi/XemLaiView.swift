import SwiftUI

// MARK: - Xem lại từng câu
//
// Bản iOS của `ExamReviewClient.tsx`:
//   FE  → từng phương án đúng / sai / bỏ sót + lời giải song ngữ
//   PE  → bài chấm của AI (kết luận, điểm từng tiêu chí, nhận xét, gợi ý,
//         bản ghi giọng nói) + đáp án mẫu / kết quả mong đợi
// Thêm so với web: lọc câu sai / bỏ trống / đã lưu, thanh nhảy câu, và "Hỏi
// CuongMini" ngay trên từng câu (đường LUYỆN — lượt đã nộp thì đường theo
// lượt thi trả 400).

struct XemLaiView: View {
    let xemLai: XemLaiBaiThi
    /// Chuỗi GỐC còn nguyên `|||` — tách tại chỗ hiện, để nút EN/VI đổi luôn
    /// cả tiêu đề chứ không chỉ nội dung câu hỏi.
    let tenDe: String
    /// Bài viết / mã người dùng vừa nộp (bản xem lại của máy chủ không trả bài
    /// viết PE theo từng câu). Lượt cũ mở từ lịch sử thì để trống.
    var baiDaNop: [Int: String] = [:]

    enum Loc: String, CaseIterable, Identifiable {
        case tatCa, sai, boTrong, daLuu
        var id: String { rawValue }
        var nhan: String {
            switch self {
            case .tatCa: return T("Tất cả")
            case .sai: return T("Sai")
            case .boTrong: return T("Bỏ trống")
            case .daLuu: return T("Đã lưu")
            }
        }
    }

    @State private var loc: Loc = .tatCa
    /// Mặc định TIẾNG ANH, như web.
    @State private var ngonNgu: NgonNguDe = .anh
    @State private var daDanhDau: Set<Int> = []
    @State private var ghiChu: [Int: String] = [:]
    @State private var hoiMini: CauMini?
    @State private var moBinhLuan: Set<Int> = []

    struct CauMini: Identifiable { let id: Int; let so: Int; let daLam: Bool }

    private var tatCa: [CauHoiXemLai] {
        xemLai.questions.sorted { ($0.sortOrder ?? 0, $0.id) < ($1.sortOrder ?? 0, $1.id) }
    }
    private var cau: [(Int, CauHoiXemLai)] {
        Array(tatCa.enumerated()).filter { _, c in
            switch loc {
            case .tatCa: return true
            case .sai: return trangThai(c) == .sai
            case .boTrong: return c.boTrong && c.laMCQ
            case .daLuu: return daDanhDau.contains(c.id)
            }
        }
    }

    enum TrangThai { case dung, sai, boTrong, cham, chuaCham }

    private func trangThai(_ c: CauHoiXemLai) -> TrangThai {
        if c.laMCQ {
            if c.boTrong { return .boTrong }
            return c.lamDung ? .dung : .sai
        }
        guard let g = xemLai.cham(c.id)?.grade else { return .chuaCham }
        let nguong = (xemLai.exam?.passMark ?? 5) / max(1, xemLai.exam?.totalPoints ?? 10) * 100
        return g.percent >= nguong ? .dung : .sai
    }

    private func mau(_ t: TrangThai) -> Color {
        switch t {
        case .dung: return AppColors.success
        case .sai: return AppColors.error
        case .boTrong: return AppColors.warning
        case .cham, .chuaCham: return AppColors.textTertiary
        }
    }

    var body: some View {
        ScrollViewReader { cuon in
            ScrollView {
                LazyVStack(spacing: Spacing.md) {
                    tomTat
                    thanhNhay(cuon)
                    ForEach(cau, id: \.1.id) { i, c in
                        theCau(c, so: i + 1).id(c.id)
                    }
                    if cau.isEmpty {
                        VStack(spacing: Spacing.sm) {
                            Image(systemName: loc == .sai ? "checkmark.seal" : "tray")
                                .font(.system(size: 34)).foregroundColor(AppColors.textTertiary)
                            Text(loc == .sai ? T("Không có câu nào sai. Trọn vẹn!") : T("Không có câu nào ở mục này."))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(loc == .sai ? AppColors.success : AppColors.textSecondary)
                        }
                        .padding(.top, Spacing.xl)
                    }
                }
                .padding(Spacing.md)
                .frame(maxWidth: 860)
                .frame(maxWidth: .infinity)
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(T("Xem lại"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { ngonNgu = ngonNgu.doiSang } label: {
                    Text(ngonNgu.nhanNut).font(.system(size: 13, weight: .bold))
                }
                .accessibilityLabel(ngonNgu == .viet ? T("Chuyển sang tiếng Anh") : T("Chuyển sang tiếng Việt"))
            }
        }
        .environment(\.ngonNguDe, ngonNgu)
        .sheet(item: $hoiMini) { h in
            CuongMiniView(luyenCau: h.id, nhanCau: T("Câu") + " \(h.so)", daLam: h.daLam)
                .presentationDetents([.fraction(0.62), .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            daDanhDau = Set(xemLai.questions.filter { $0.bookmarked == true }.map(\.id))
            for q in xemLai.questions { if let n = q.bookmarkNote { ghiChu[q.id] = n } }
        }
    }

    // ── Tóm tắt ─────────────────────────────────────────────────
    private var tomTat: some View {
        let dsTT = tatCa.map(trangThai)
        let soDung = dsTT.filter { $0 == .dung }.count
        let soSai = dsTT.filter { $0 == .sai }.count
        let soTrong = dsTT.filter { $0 == .boTrong }.count
        return VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle().stroke(AppColors.backgroundTertiary, lineWidth: 7)
                    Circle().trim(from: 0, to: xemLai.tongDiem > 0 ? xemLai.diem / xemLai.tongDiem : 0)
                        .stroke(xemLai.dat ? AppColors.success : AppColors.warning,
                                style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: -2) {
                        Text(DinhDangSo.gon(xemLai.diem)).font(.system(.title3, design: .rounded).weight(.bold))
                        Text("/" + DinhDangSo.gon(xemLai.tongDiem)).font(.caption2).foregroundColor(AppColors.textTertiary)
                    }
                }
                .frame(width: 70, height: 70)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(format: T("Điểm %@ trên %@"), DinhDangSo.gon(xemLai.diem), DinhDangSo.gon(xemLai.tongDiem)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(tenDe.tachSongNgu(ngonNgu))
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        Text(xemLai.dat ? T("ĐẠT") : T("CHƯA ĐẠT"))
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Capsule().fill(xemLai.dat ? AppColors.success : AppColors.error))
                        if let s = xemLai.attempt.timeSpentSeconds, s > 0 {
                            Label(String(format: "%d:%02d", s / 60, s % 60), systemImage: "clock")
                                .font(.caption2).foregroundColor(AppColors.textTertiary)
                        }
                        if let p = xemLai.exam?.passMark {
                            Text(T("Đạt từ") + " " + DinhDangSo.gon(p))
                                .font(.caption2).foregroundColor(AppColors.textTertiary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: Spacing.sm) {
                o("\(soDung)", T("đúng"), AppColors.success)
                o("\(soSai)", T("sai"), AppColors.error)
                if soTrong > 0 { o("\(soTrong)", T("bỏ trống"), AppColors.warning) }
            }
            // Lọc câu sai là việc người ta muốn làm ngay sau khi thi xong.
            Picker(T("Lọc"), selection: $loc) {
                ForEach(Loc.allCases) { Text($0.nhan).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    private func o(_ so: String, _ nhan: String, _ mau: Color) -> some View {
        VStack(spacing: 2) {
            Text(so).font(.system(.title3, design: .rounded).weight(.heavy)).foregroundColor(mau)
            Text(nhan).font(.caption2).foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: CornerRadius.small).fill(mau.opacity(0.08)))
    }

    /// Hàng ô số câu, tô màu theo đúng/sai — bấm là cuộn tới câu đó.
    private func thanhNhay(_ cuon: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(tatCa.enumerated()), id: \.element.id) { i, c in
                    let t = trangThai(c)
                    Button {
                        if !cau.contains(where: { $0.1.id == c.id }) { loc = .tatCa }
                        withAnimation { cuon.scrollTo(c.id, anchor: .top) }
                    } label: {
                        Text("\(i + 1)")
                            .font(.caption.weight(.bold)).monospacedDigit()
                            .foregroundColor(t == .chuaCham ? AppColors.textSecondary : .white)
                            .frame(minWidth: 30, minHeight: 30)
                            .background(RoundedRectangle(cornerRadius: 8).fill(t == .chuaCham ? AppColors.backgroundTertiary : mau(t)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(T("Tới câu") + " \(i + 1)")
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // ── Một câu ─────────────────────────────────────────────────
    private func theCau(_ c: CauHoiXemLai, so: Int) -> some View {
        let t = trangThai(c)
        let cham = xemLai.cham(c.id)
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .center, spacing: Spacing.sm) {
                Text(T("Câu") + " \(so)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(AppColors.onPrimary)
                    .padding(.horizontal, Spacing.sm).padding(.vertical, 3)
                    .background(Capsule().fill(t == .chuaCham ? AppColors.textTertiary : mau(t)))
                switch t {
                case .boTrong: Text(T("bỏ trống")).font(.caption.weight(.semibold)).foregroundColor(AppColors.warning)
                case .sai where c.laMCQ: Text(T("chọn sai")).font(.caption.weight(.semibold)).foregroundColor(AppColors.error)
                default: EmptyView()
                }
                if let p = c.points, p > 0 {
                    Text(DinhDangSo.gon(p) + "đ").font(.caption2).foregroundColor(AppColors.textTertiary)
                }
                Spacer()
                Button { Task { await lat(c) } } label: {
                    Image(systemName: daDanhDau.contains(c.id) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 15))
                        .foregroundColor(daDanhDau.contains(c.id) ? AppColors.accent : AppColors.textTertiary)
                        .frame(width: 34, height: 30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(daDanhDau.contains(c.id) ? T("Bỏ lưu câu") : T("Lưu câu vào sổ tay"))
            }

            NoiDungThi(chu: c.prompt, coChu: 15, laDeBai: true)
            if let a = c.imageUrl, !a.isEmpty { AnhDeGocGap(duong: a) }

            if c.laMCQ, let ds = c.options, !ds.isEmpty {
                VStack(spacing: Spacing.xs) {
                    ForEach(Array(ds.enumerated()), id: \.offset) { i, lc in
                        hangLuaChon(lc.text, i: i, c: c)
                    }
                }
            } else if !c.laMCQ {
                phanPE(c, cham: cham)
            }

            if let gt = c.explanation, !gt.isEmpty {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.accent)
                    // Lời giải cũng song ngữ và cũng có thể mang công thức.
                    NoiDungThi(chu: gt, coChu: 13.5, mauChu: AppColors.textSecondary)
                }
                .padding(Spacing.sm + 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(AppColors.accent.opacity(0.10)))
            }

            if daDanhDau.contains(c.id) { oGhiChu(c) }

            HStack(spacing: Spacing.sm) {
                Button {
                    hoiMini = CauMini(id: c.id, so: so, daLam: !c.boTrong)
                } label: {
                    Label(T("Hỏi CuongMini"), systemImage: "sparkles")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(AppColors.primary)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Capsule().fill(AppColors.primary.opacity(0.10)))
                }
                .buttonStyle(.nhan)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if moBinhLuan.contains(c.id) { moBinhLuan.remove(c.id) } else { moBinhLuan.insert(c.id) }
                    }
                } label: {
                    Label(moBinhLuan.contains(c.id) ? T("Ẩn bình luận") : T("Bình luận"),
                          systemImage: "bubble.left.and.bubble.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Capsule().fill(AppColors.backgroundTertiary))
                }
                .buttonStyle(.nhan)
                Spacer(minLength: 0)
            }
            if moBinhLuan.contains(c.id) {
                BinhLuanCauHoiView(questionId: c.id, toiLa: AppState.shared.currentUser?.id)
                    .id(c.id)
            }
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(t == .chuaCham ? .clear : mau(t)).frame(width: 3)
                .padding(.vertical, Spacing.md)
        }
    }

    // ── Phần PE: bài chấm AI ────────────────────────────────────
    @ViewBuilder
    private func phanPE(_ c: CauHoiXemLai, cham: ChamCau?) -> some View {
        let baiCuaToi = baiDaNop[c.id] ?? c.myAnswer?.chu
        if let g = cham?.grade {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: 6) {
                    Text(DinhDangSo.gon(g.score) + "/" + DinhDangSo.gon(g.maxScore))
                        .font(.subheadline.weight(.bold)).monospacedDigit()
                    Text(g.nhanKetLuan)
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Capsule().fill(trangThai(c) == .dung ? AppColors.success : AppColors.error))
                    Spacer()
                    Text(T("AI chấm")).font(.caption2).foregroundColor(AppColors.textTertiary)
                }
                if !g.summary.isEmpty {
                    Text(g.summary.tachSongNgu(ngonNgu))
                        .font(.subheadline).foregroundColor(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(g.criteria, id: \.self) { tc in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(tc.name.tachSongNgu(ngonNgu)).font(.footnote.weight(.semibold))
                            Spacer()
                            Text(DinhDangSo.gon(tc.score) + "/" + DinhDangSo.gon(tc.maxScore))
                                .font(.footnote.monospacedDigit()).foregroundColor(AppColors.textSecondary)
                        }
                        ProgressView(value: tc.maxScore > 0 ? min(1, max(0, tc.score / tc.maxScore)) : 0)
                            .tint(tc.maxScore > 0 && tc.score / tc.maxScore >= 0.5 ? AppColors.success : AppColors.warning)
                        if !tc.comment.isEmpty {
                            Text(tc.comment.tachSongNgu(ngonNgu))
                                .font(.caption).foregroundColor(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if !g.suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(T("Gợi ý cải thiện")).font(.footnote.weight(.semibold)).foregroundColor(AppColors.primary)
                        ForEach(Array(g.suggestions.enumerated()), id: \.offset) { _, s in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•")
                                Text(s.tachSongNgu(ngonNgu)).fixedSize(horizontal: false, vertical: true)
                            }
                            .font(.caption).foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .padding(Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.small).fill(AppColors.primary.opacity(0.07)))
                }
                if let tr = g.transcript, !tr.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(T("Bản ghi giọng nói")).font(.caption2).foregroundColor(AppColors.textTertiary)
                        Text("“\(tr)”").font(.footnote.italic()).foregroundColor(AppColors.textSecondary)
                    }
                }
                HStack {
                    Spacer()
                    // Nhận xét do AI viết ⇒ phải báo cáo được (4.7).
                    NutBaoCaoTraLoiAI(nguon: "AI · Chấm bài PE Phòng thi",
                                      cauHoi: "Đề \(xemLai.attempt.examId) · câu #\(c.id)",
                                      traLoi: g.summary)
                }
            }
            .padding(Spacing.sm + 2)
            .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.backgroundSecondary))
        } else {
            Text(cham?.khongCham == true
                 ? T("AI không chấm được câu này lúc bạn nộp, nên câu này KHÔNG bị tính vào điểm (không trừ điểm của bạn). Thi lại để được chấm.")
                 : T("Chưa có bài chấm cho câu này."))
                .font(.footnote).foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        if let b = baiCuaToi, !b.isEmpty {
            DisclosureGroup(T("Bài làm của bạn")) {
                if (c.kind ?? "").uppercased() == "WRITE" {
                    Text(b).font(.footnote).foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                } else {
                    KhoiMaNguon(ma: b, ngonNgu: c.language, tieuDe: nil, choChep: true)
                }
            }
            .font(.footnote.weight(.semibold))
        }
        if let s = c.sampleSolution, !s.isEmpty {
            DisclosureGroup(T("Xem đáp án mẫu")) {
                if (c.kind ?? "").uppercased() == "CODE" {
                    KhoiMaNguon(ma: s, ngonNgu: c.language, tieuDe: nil, choChep: true)
                } else {
                    NoiDungThi(chu: s, coChu: 13.5, mauChu: AppColors.textSecondary)
                }
            }
            .font(.footnote.weight(.semibold))
            .tint(AppColors.primary)
        }
        if let e = c.expectedOutput, !e.isEmpty {
            DisclosureGroup(T("Kết quả mong đợi")) {
                KhoiMaNguon(ma: e, ngonNgu: nil, tieuDe: nil, choChep: false)
            }
            .font(.footnote.weight(.semibold))
        }
    }

    /// Đáp án ĐÚNG luôn sáng lên, kể cả khi người ta chọn sai — không thấy
    /// đáp án đúng thì xem lại chẳng học được gì.
    private func hangLuaChon(_ chu: String, i: Int, c: CauHoiXemLai) -> some View {
        let dung = c.dapAnDung.contains(i)
        let daChon = c.daChon.contains(i)
        let mau: Color = dung ? AppColors.success : (daChon ? AppColors.error : AppColors.border)
        let nen: Color = dung ? AppColors.success.opacity(0.12)
            : (daChon ? AppColors.error.opacity(0.12) : Color.clear)

        return HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: dung ? "checkmark.circle.fill"
                  : (daChon ? "xmark.circle.fill" : "circle"))
                .font(.system(size: 15))
                .foregroundColor(dung ? AppColors.success
                                 : (daChon ? AppColors.error : AppColors.textTertiary))
            NoiDungThi(chu: chu, coChu: 14)
            Spacer(minLength: 0)
            if daChon && !dung {
                Text(T("bạn chọn")).font(.caption2.weight(.semibold)).foregroundColor(AppColors.error)
            } else if dung && !daChon {
                Text(T("đáp án đúng")).font(.caption2.weight(.semibold)).foregroundColor(AppColors.success)
            }
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.small).fill(nen))
        .overlay(RoundedRectangle(cornerRadius: CornerRadius.small)
            .strokeBorder(mau.opacity(dung || daChon ? 0.7 : 0), lineWidth: 1.5))
        .accessibilityElement(children: .combine)
    }

    private func oGhiChu(_ c: CauHoiXemLai) -> some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            TextField(T("Ghi chú ôn tập (vì sao câu này khó…)"), text: Binding(
                get: { ghiChu[c.id] ?? "" }, set: { ghiChu[c.id] = $0 }), axis: .vertical)
                .font(.footnote)
                .lineLimit(1...4)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: CornerRadius.small).fill(AppColors.backgroundTertiary))
            if (ghiChu[c.id] ?? "") != (c.bookmarkNote ?? "") {
                Button(T("Lưu")) {
                    Task { _ = try? await APIClient.shared.send(.ghiChuCauHoi(questionId: c.id, ghiChu: ghiChu[c.id] ?? "")); Haptics.xong() }
                }
                .font(.footnote.weight(.semibold))
            }
        }
    }

    private func lat(_ c: CauHoiXemLai) async {
        struct R: Codable { let bookmarked: Bool }
        let truoc = daDanhDau
        if daDanhDau.contains(c.id) { daDanhDau.remove(c.id) } else { daDanhDau.insert(c.id) }
        Haptics.cham()
        do {
            let r: R = try await APIClient.shared.request(.danhDauCauHoi(questionId: c.id))
            if r.bookmarked { daDanhDau.insert(c.id) } else { daDanhDau.remove(c.id) }
        } catch {
            daDanhDau = truoc
        }
    }
}

/// Ảnh đề gốc (bản chụp) — GẬP mặc định như web: phần chữ phía trên đã chép
/// đủ, hiện cả hai cùng lúc chỉ làm rối.
struct AnhDeGocGap: View {
    let duong: String
    @State private var mo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { withAnimation { mo.toggle() } } label: {
                Label(mo ? T("Ẩn ảnh đề gốc") : T("Xem ảnh đề gốc"), systemImage: mo ? "eye.slash" : "eye")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().strokeBorder(AppColors.border))
            }
            .buttonStyle(.plain)
            if mo { AnhCauHoi(duong: DuongDanThi.day(duong)?.absoluteString ?? duong) }
        }
    }
}
