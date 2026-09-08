import SwiftUI

// ════════════════════════════════════════════════════════════════
// ĐỀ LUYỆN CUỐI CHƯƠNG
//
// Câu hỏi THẬT từ đề FE/PE/PT của trường, đã được gán về đúng chương
// (`ExamQuestion.sectionId`). Học xong chương thì làm luôn để tự kiểm — chấm
// ngay, có giải thích, hỏi được gia sư.
//
// Bám bản web (`ChapterQuiz.tsx`):
//   • hai lối vào: 10 câu ngẫu nhiên (làm nhanh) hoặc làm tất cả
//   • dựng đề/đáp án/giải thích bằng CÙNG bộ của phòng thi (`NoiDungThi`) —
//     đề có KaTeX, sơ đồ, HTML; đổ ra `Text` là người học đọc nguyên thẻ
//   • chấm bằng khớp TẬP HỢP, hiện đúng/sai + giải thích từng câu
//   • kèm phần bài THỰC HÀNH (PE) của chương — không tự chấm được, nên hiện
//     đề + giấu lời giải mẫu sau một nút để tự làm trước
//
// Khác web: hỏi gia sư ngay tại câu sai (web có ô chat chung ở dưới, phải tự
// gõ "câu 3…"), và nút mở nguyên đề chương đó trong Phòng Thi của app.
// ════════════════════════════════════════════════════════════════

struct LuyenChuongView: View {
    let sectionId: Int
    let tenChuong: String
    let soCau: Int
    /// Bài học đầu chương — gia sư AI gắn theo BÀI, không theo chương.
    let lessonId: Int?
    let tenMon: String?

    @Environment(\.dismiss) private var dismiss

    @State private var cau: [CauLuyen] = []
    @State private var thucHanh: [CauThucHanh] = []
    @State private var dangTai = false
    @State private var dangTaiThucHanh = false
    @State private var loi: String?
    @State private var loiThucHanh: String?

    @State private var chon: [Int: Set<Int>] = [:]
    @State private var daNop = false
    @State private var moThucHanh = false
    @State private var ngonNgu: NgonNguDe = .viet
    @State private var hoiAI: HoiVeCau?
    /// Câu nào đang mở danh sách "Hỏi AI".
    @State private var moHoi: Set<Int> = []

    private var soDung: Int {
        cau.filter { (chon[$0.id] ?? []) == $0.dapAnDung && !$0.dapAnDung.isEmpty }.count
    }
    private var daLam: Int { cau.filter { !(chon[$0.id] ?? []).isEmpty }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                // ⛔ LazyVStack, KHÔNG phải VStack. Chương này có 148 câu, và
                // đề thi là HTML nên mỗi câu dựng bằng MỘT WKWebView
                // (`NoiDungThi`). `VStack` dựng hết một lượt ⇒ 148 web view
                // cùng lúc ⇒ đề bài hiện ra là những khối TRỐNG cao ngồng. Đo
                // thật 07/09/2026: mở "làm tất cả" thì không câu nào có chữ.
                LazyVStack(alignment: .leading, spacing: Spacing.md) {
                    if cau.isEmpty { moDau } else { phanLamBai }
                    phanThucHanh
                    duongSangPhongThi
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xxl)
            }
            .background(AppColors.backgroundPrimary)
            .environment(\.ngonNguDe, ngonNgu)
            .navigationTitle(T("Luyện cuối chương"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Đóng")) { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { ngonNgu = ngonNgu == .viet ? .anh : .viet } label: {
                        Text(ngonNgu == .viet ? "VI" : "EN")
                            .font(.system(size: 12, weight: .bold))
                    }
                }
            }
            .sheet(item: $hoiAI) { h in
                if let l = lessonId {
                    GiaSuBaiHocView(lessonId: l, tenBai: tenChuong, tenMon: tenMon,
                                    quizContext: h.boiCanh, cauHoiSan: h.cauMoDau)
                        .presentationDetents([.fraction(0.68), .large])
                        .presentationDragIndicator(.visible)
                }
            }
        }
    }

    // MARK: Màn mở đầu — chọn cách làm

    private var moDau: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                Text(tenChuong.tachSongNgu(ngonNgu))
                    .font(.system(size: 17, weight: .bold)).foregroundColor(AppColors.textPrimary)
                Text(String(format: T("%d câu hỏi THẬT lấy từ đề FE/PE/PT của trường, đã gán đúng phần kiến thức chương này. Chấm ngay, có giải thích, hỏi được gia sư từng câu."), soCau))
                    .font(.system(size: 13.5)).foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, Spacing.sm)

            if dangTai {
                HStack { Spacer(); ProgressView(); Spacer() }.padding(.vertical, Spacing.lg)
            } else {
                // 10 câu để trước: người vừa học xong một chương cần một lượt
                // ngắn để biết mình hổng chỗ nào, không cần 193 câu.
                Button { Task { await nap(ngauNhien: true, gioiHan: 10) } } label: {
                    nhanTo(T("10 câu ngẫu nhiên"), "shuffle", chinh: true)
                }
                .buttonStyle(.plain)
                Button { Task { await nap(ngauNhien: false, gioiHan: 0) } } label: {
                    nhanTo(String(format: T("Làm tất cả %d câu"), soCau), "list.number", chinh: false)
                }
                .buttonStyle(.plain)
            }

            if let e = loi {
                Label(e, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13)).foregroundColor(AppColors.error)
            }
        }
    }

    private func nhanTo(_ chu: String, _ bieuTuong: String, chinh: Bool) -> some View {
        Label(chu, systemImage: bieuTuong)
            .font(.system(size: 15, weight: .semibold))
            .frame(maxWidth: .infinity).padding(.vertical, 13)
            .background(chinh ? AppColors.primary : AppColors.backgroundTertiary)
            .foregroundColor(chinh ? AppColors.onPrimary : AppColors.textPrimary)
            .cornerRadius(CornerRadius.medium)
    }

    // MARK: Làm bài

    private var phanLamBai: some View {
        LazyVStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text(String(format: T("%d câu · %d đã làm"), cau.count, daLam))
                    .font(.system(size: 12.5)).foregroundColor(AppColors.textTertiary)
                Spacer()
                Button {
                    cau = []; chon = [:]; daNop = false; loi = nil
                } label: {
                    Label(T("Đổi bộ câu"), systemImage: "arrow.counterclockwise")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, Spacing.sm)

            ForEach(Array(cau.enumerated()), id: \.element.id) { i, c in
                theCau(c, thuTu: i + 1)
            }

            if daNop {
                VStack(spacing: Spacing.sm) {
                    Text(String(format: T("%d/%d câu đúng"), soDung, cau.count))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(soDung * 2 >= cau.count ? AppColors.success : AppColors.error)
                    Button { chon = [:]; daNop = false } label: {
                        Label(T("Làm lại bộ này"), systemImage: "arrow.counterclockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                            .background(AppColors.backgroundTertiary)
                            .foregroundColor(AppColors.textPrimary)
                            .cornerRadius(CornerRadius.medium)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
            } else {
                Button { daNop = true } label: {
                    Text(String(format: T("Nộp bài · %d/%d đã làm"), daLam, cau.count))
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(AppColors.primary).foregroundColor(AppColors.onPrimary)
                        .cornerRadius(CornerRadius.medium)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func theCau(_ c: CauLuyen, thuTu: Int) -> some View {
        let dung = (chon[c.id] ?? []) == c.dapAnDung && !c.dapAnDung.isEmpty
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Text(String(format: T("Câu %d"), thuTu))
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(AppColors.primary.opacity(0.15))
                    .foregroundColor(AppColors.primary).clipShape(Capsule())
                if let k = c.examKind, !k.isEmpty {
                    Text(k).font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(AppColors.backgroundTertiary)
                        .foregroundColor(AppColors.textTertiary).clipShape(Capsule())
                }
                if c.dapAnDung.count > 1 {
                    Text(T("Chọn nhiều")).font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(AppColors.warning.opacity(0.15))
                        .foregroundColor(AppColors.warning).clipShape(Capsule())
                }
                Spacer()
                if daNop {
                    Image(systemName: dung ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(dung ? AppColors.success : AppColors.error)
                }
            }

            NoiDungThi(chu: c.prompt, coChu: 15, laDeBai: true)
            if let a = c.imageUrl, !a.isEmpty { AnhCauHoi(duong: a) }

            ForEach(Array(c.luaChon.enumerated()), id: \.offset) { i, chu in
                hangChon(c, i, chu, dung: dung)
            }

            if daNop {
                if let g = c.explanation, !g.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 11)).foregroundColor(AppColors.warning)
                        NoiDungThi(chu: g, coChu: 13.5, mauChu: AppColors.textSecondary)
                    }
                }
                // Hỏi gia sư về ĐÚNG câu này — bảy việc giống hệt CuongMini
                // ở Phòng thi và bộ chip bên web.
                //
                // Trước 08/09/2026 chỗ này chỉ có MỘT nút, và chỉ hiện với câu
                // SAI. Nay hiện với mọi câu đã nộp: câu đoán mò mà đúng cũng
                // đáng hỏi, và phần giải thích trong đề thường rất ngắn.
                //
                // Gấp lại theo mặc định — bảy con chip mở sẵn dưới mỗi câu thì
                // một đề 164 câu thành một bức tường nút.
                if lessonId != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            if moHoi.contains(c.id) { moHoi.remove(c.id) } else { moHoi.insert(c.id) }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles").font(.system(size: 12))
                            Text(T("Hỏi AI về câu này")).font(.system(size: 12.5, weight: .semibold))
                            Spacer(minLength: 0)
                            Image(systemName: moHoi.contains(c.id) ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(AppColors.primary)
                        .padding(.vertical, 9).padding(.horizontal, 10)
                        .frame(maxWidth: .infinity)
                        .background(AppColors.primary.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if moHoi.contains(c.id) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(ViecHoiAI.allCases) { v in
                                Button {
                                    hoiAI = HoiVeCau(cau: c, thuTu: thuTu,
                                                     daChon: chon[c.id] ?? [], viec: v)
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(v.nhan)
                                            .font(.system(size: 12))
                                            .foregroundColor(AppColors.textSecondary)
                                            .multilineTextAlignment(.leading)
                                        Spacer(minLength: 0)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundColor(AppColors.textTertiary)
                                    }
                                    .padding(.vertical, 7).padding(.horizontal, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(AppColors.backgroundTertiary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    // Nút chỉ có chữ thì vùng bấm bám sát từng
                                    // chữ — mở ra cả hàng.
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundTertiary.opacity(0.55))
        .cornerRadius(CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(daNop ? (dung ? AppColors.success : AppColors.error).opacity(0.5) : AppColors.divider,
                        lineWidth: 1)
        )
    }

    private func hangChon(_ c: CauLuyen, _ i: Int, _ chu: String, dung: Bool) -> some View {
        let daChon = (chon[c.id] ?? []).contains(i)
        let laDung = c.dapAnDung.contains(i)
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
                Text(String(UnicodeScalar(65 + min(max(i, 0), 25))!) + ". ")
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(mau)
                + Text(chu.tachSongNgu(ngonNgu))
                    .font(.system(size: 14)).foregroundColor(AppColors.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 7).padding(.horizontal, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(mau.opacity(daNop && laDung ? 0.12 : daChon ? 0.10 : 0))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(mau.opacity(0.6), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(daNop)
    }

    // MARK: Bài thực hành (PE)

    @ViewBuilder
    private var phanThucHanh: some View {
        Divider().background(AppColors.divider).padding(.vertical, Spacing.sm)
        if !moThucHanh {
            Button { moThucHanh = true; Task { await napThucHanh() } } label: {
                Label(T("Bài thực hành (PE) của chương này"), systemImage: "pencil.and.outline")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(AppColors.backgroundTertiary)
                    .foregroundColor(AppColors.textPrimary)
                    .cornerRadius(CornerRadius.medium)
            }
            .buttonStyle(.plain)
        } else if dangTaiThucHanh {
            HStack { Spacer(); ProgressView(); Spacer() }.padding(.vertical, Spacing.lg)
        } else if let e = loiThucHanh {
            Label(e, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 13)).foregroundColor(AppColors.error)
        } else {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(String(format: T("%d bài thực hành lấy từ đề PE thật. KHÔNG chấm tự động — tự làm rồi mở lời giải mẫu để đối chiếu."), thucHanh.count))
                    .font(.system(size: 12.5)).foregroundColor(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(Array(thucHanh.enumerated()), id: \.element.id) { i, b in
                    theThucHanh(b, thuTu: i + 1)
                }
            }
        }
    }

    private func theThucHanh(_ b: CauThucHanh, thuTu: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Text("\(T("Bài")) \(thuTu) · \(b.kind ?? "PE")")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(AppColors.primary.opacity(0.15))
                    .foregroundColor(AppColors.primary).clipShape(Capsule())
                if let m = b.examCode, !m.isEmpty {
                    Text(String(format: T("từ đề %@"), m))
                        .font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                }
                Spacer()
                if let d = b.points, d > 0 {
                    Text(String(format: T("%@ điểm"), d == d.rounded() ? String(Int(d)) : String(format: "%.1f", d)))
                        .font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                }
            }
            NoiDungThi(chu: b.prompt, coChu: 14.5, laDeBai: true)
            if let a = b.imageUrl, !a.isEmpty { AnhCauHoi(duong: a) }
            if let m = b.starterCode, !m.isEmpty {
                KhoiMaView(ma: m.boThoatDong, ngonNgu: b.language)
            }
            // Lời giải giấu sau một nút: thấy ngay lời giải thì không ai làm.
            DisclosureGroup(T("Xem lời giải mẫu")) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    if let m = b.sampleSolution, !m.isEmpty {
                        KhoiMaView(ma: m.boThoatDong, ngonNgu: b.language)
                    }
                    if let k = b.expectedOutput, !k.isEmpty {
                        Text(T("Kết quả mong đợi"))
                            .font(.system(size: 11, weight: .bold)).foregroundColor(AppColors.textSecondary)
                        KhoiMaView(ma: k.boThoatDong, ngonNgu: nil)
                    }
                    if let g = b.explanation, !g.isEmpty {
                        NoiDungThi(chu: g, coChu: 13.5, mauChu: AppColors.textSecondary)
                    }
                }
                .padding(.top, 6)
            }
            .font(.system(size: 13, weight: .semibold))
            .tint(AppColors.primary)
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundTertiary.opacity(0.55))
        .cornerRadius(CornerRadius.medium)
    }

    // MARK: Sang Phòng Thi

    /// Mở Phòng Thi lọc sẵn theo MÔN.
    ///
    /// ⚠️ Nói đúng phạm vi. Web ghi "Mở đề CHƯƠNG NÀY trên Phòng Thi" và trỏ
    /// tới `/exam?course=…&section=…`, nhưng `ExamPortalClient` chỉ đọc
    /// `?course=` và `?kind=` — **`section` bị bỏ qua hoàn toàn**. Tức nút đó
    /// vẫn mở đề của cả môn. Ở đây gọi đúng tên: lọc theo môn, và nói thẳng
    /// phần luyện theo chương nằm ngay bên trên.
    @ViewBuilder
    private var duongSangPhongThi: some View {
        if let ma = tenMon, !ma.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Divider().background(AppColors.divider).padding(.vertical, Spacing.sm)
                NavigationLink {
                    PhongThiView(tuKhoaBanDau: ma)
                        .navigationTitle(String(format: T("Đề thi %@"), ma))
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 15)).foregroundColor(AppColors.primary)
                        Text(String(format: T("Mở đề thi môn %@ trong Phòng Thi"), ma))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.backgroundTertiary)
                    .cornerRadius(CornerRadius.medium)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Text(T("Đề ĐẦY ĐỦ của cả môn, có bấm giờ và lưu kết quả. Luyện riêng chương này thì dùng phần ở trên."))
                    .font(.system(size: 11.5)).foregroundColor(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Mạng

    private func nap(ngauNhien: Bool, gioiHan: Int) async {
        dangTai = true
        defer { dangTai = false }
        loi = nil
        do {
            let ds: [CauLuyen] = try await APIClient.shared.request(
                .luyenChuong(sectionId: sectionId, ngauNhien: ngauNhien, gioiHan: gioiHan))
            if ds.isEmpty {
                loi = T("Chương này chưa có câu luyện nào.")
            } else {
                cau = ds; chon = [:]; daNop = false
            }
        } catch {
            // Hiện lỗi THẬT. `try?` ở đây cho ra một màn hình trống trông y hệt
            // "chương này chưa có câu nào" — một câu SAI mà người dùng sẽ tin.
            loi = error.localizedDescription
        }
    }

    private func napThucHanh() async {
        dangTaiThucHanh = true
        defer { dangTaiThucHanh = false }
        loiThucHanh = nil
        do {
            let ds: [CauThucHanh] = try await APIClient.shared.request(
                .luyenChuongThucHanh(sectionId: sectionId))
            thucHanh = ds
            if ds.isEmpty { loiThucHanh = T("Chương này chưa có bài thực hành từ đề PE.") }
        } catch {
            loiThucHanh = error.localizedDescription
        }
    }
}
