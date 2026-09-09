import SwiftUI

// ════════════════════════════════════════════════════════════════
// PHÒNG THI — DANH SÁCH ĐỀ
//
// Đo thật 05/09/2026: **800 đề · 23 môn · 5 kỳ học**. Bản trước đổ tất cả
// thành một danh sách phẳng gom theo tên khoá học — người dùng nói đúng:
// "rất lộn xộn". Ba việc phải làm cùng lúc thì nó mới tra được:
//
//   1. Xếp cây **Kỳ học → Môn → đề**, gập mở được, đúng lối Academy.
//   2. Trong mỗi môn, đề xếp theo **KỲ THI, mới nhất trước** (Spring 2026 →
//      Fall 2022), có dòng ngăn ghi rõ tên kỳ.
//   3. Mỗi **loại đề một màu riêng** (FE/PE/PT/ME/Đọc/Nghe/Nói/Quiz) —
//      xem `PhanLoaiDe.swift` — kèm thanh lọc theo loại.
//
// ⚠️ Cả cây phải dựng LƯỜI. 800 đề × mỗi đề một `NavigationLink` dựng sẵn
// là màn hình đứng vài giây khi mở. Mặc định mọi kỳ ĐÓNG, chỉ kỳ nào bấm mở
// mới dựng nội dung.
// ════════════════════════════════════════════════════════════════

struct PhongThiView: View {
    @State private var de: [DeThi] = []
    @State private var dangTai = true
    @State private var loi: String?
    @State private var tuKhoa: String
    @State private var loaiChon: LoaiDe?
    @State private var kyMo: Set<Int> = []
    @State private var monMo: Set<String> = []
    /// Cây kỳ → môn → đề, nhóm SẴN.
    ///
    /// ⚠️ TRƯỚC ĐÂY LÀ `private var cay: [Ky] { ... }` — computed property,
    /// nên nó nhóm lại 1.300 đề MỖI LẦN body dựng lại, kể cả khi chỉ mở/đóng
    /// một kỳ. Đo thật trên máy ảo 10/09/2026, bấm mở "Kỳ 2":
    ///
    ///     computed  →  947 · 953 · 994 ms
    ///     @State    →   40 ·  46 ·  71 ms      (nhanh ~20 lần)
    ///
    /// Đáng chú ý: đóng cũng tốn đúng ngần ấy, tức chi phí KHÔNG nằm ở nội
    /// dung mới hiện ra mà ở việc dựng lại cả cây rồi bắt SwiftUI so lại.
    /// Một phép đo mô phỏng riêng chỉ ra 3,2ms — nó mô hình hoá dữ liệu quá
    /// đơn giản và đã dẫn tôi đi sai hướng; con số thật phải đo TRONG app.
    @State private var cay: [Ky] = []
    /// ⚠️ Mặc định TIẾNG ANH, khớp `ExamPortalClient` của web.
    @State private var ngonNgu: NgonNguDe = .anh

    /// Mở sẵn với một từ khoá — dùng khi vào từ Academy ("mở đề môn SWR302").
    /// Ô tìm quét cả `maMon`, nên truyền mã môn là lọc đúng môn đó.
    init(tuKhoaBanDau: String = "") {
        _tuKhoa = State(initialValue: tuKhoaBanDau)
    }

    // ── Lọc ─────────────────────────────────────────────────────
    private var hienThi: [DeThi] {
        var ds = de
        if let l = loaiChon { ds = ds.filter { $0.loai == l } }
        let t = tuKhoa.trimmingCharacters(in: .whitespaces).lowercased()
        if !t.isEmpty {
            ds = ds.filter {
                // Tìm trên chuỗi GỐC, tức quét cả nửa Anh lẫn nửa Việt: gõ
                // "thi lại" hay "retake" đều phải ra, bất kể đang xem tiếng
                // nào. Thêm mã môn và tên kỳ thi để gõ "PRF192" hay
                // "spring 2026" cũng tìm được.
                $0.title.lowercased().contains(t)
                || ($0.code ?? "").lowercased().contains(t)
                || $0.tenKhoa.lowercased().contains(t)
                || $0.maMon.lowercased().contains(t)
                || ($0.kyThi?.ten.lowercased().contains(t) ?? false)
            }
        }
        return ds
    }

    /// Những loại đề THỰC SỰ có trong dữ liệu — không hiện nút lọc cho loại
    /// không có đề nào, bấm vào chỉ ra danh sách trống.
    private var loaiCo: [(LoaiDe, Int)] {
        var dem: [LoaiDe: Int] = [:]
        for d in de { dem[d.loai, default: 0] += 1 }
        return dem.map { ($0.key, $0.value) }.sorted { $0.0.thuTu < $1.0.thuTu }
    }

    // ── Cây Kỳ học → Môn → đề ───────────────────────────────────
    private struct Mon: Identifiable {
        let ma: String
        let ten: String
        let de: [DeThi]
        var id: String { ma + "|" + ten }
    }
    private struct Ky: Identifiable {
        /// `semester.ordinal` — dùng để XẾP THỨ TỰ, không phải để hiện ra.
        let so: Int
        let ten: String
        let mon: [Mon]
        var id: Int { so }
        var soDe: Int { mon.reduce(0) { $0 + $1.de.count } }

        /// ⚠️ `ordinal` KHÔNG phải số kỳ: "Kỳ 3" có ordinal = 5, "Kỳ 5" có
        /// ordinal = 7. Lấy ordinal làm huy hiệu là hiện ô số "5" ngay cạnh
        /// dòng chữ "Kỳ 3". Số thật nằm trong `name` — cùng cái bẫy mà
        /// `Semester.soKy` bên Academy đã ghi chú sẵn, và tôi vẫn giẫm vào.
        var soHien: String {
            let d = ten.filter(\.isNumber)
            return d.isEmpty ? "—" : d
        }
    }

    private func dungCay() -> [Ky] {
        Dictionary(grouping: hienThi, by: \.soKyHoc)
            .map { soKy, dsKy in
                let mon = Dictionary(grouping: dsKy, by: \.maMon)
                    .map { ma, ds -> Mon in
                        Mon(ma: ma,
                            ten: ds.first?.tenKhoa ?? ma,
                            // Kỳ thi MỚI nhất trước; cùng kỳ thì theo SỐ đề
                            // (không phải chuỗi mã — xem `DeThi.soDe`), rồi
                            // mới tới mã để thứ tự ổn định giữa các lần dựng.
                            de: ds.sorted {
                                if $0.mocKy != $1.mocKy { return $0.mocKy > $1.mocKy }
                                if $0.soDe != $1.soDe { return $0.soDe < $1.soDe }
                                return ($0.code ?? "") < ($1.code ?? "")
                            })
                    }
                    .sorted { $0.ma < $1.ma }
                return Ky(so: soKy, ten: dsKy.first?.tenKyHoc ?? "Chưa xếp kỳ", mon: mon)
            }
            .sorted { $0.so < $1.so }
    }

    /// Đang tìm kiếm thì mở sẵn mọi nhóm — bắt người dùng gõ xong rồi còn
    /// phải bấm mở từng kỳ mới thấy kết quả là hỏng hẳn việc tìm.
    private var dangTim: Bool {
        !tuKhoa.trimmingCharacters(in: .whitespaces).isEmpty || loaiChon != nil
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.md, pinnedViews: []) {
                oTim
                thanhLoai

                if dangTai && de.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, Spacing.xl)
                } else if hienThi.isEmpty {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "doc.questionmark")
                            .font(.system(size: 36)).foregroundColor(AppColors.textTertiary)
                        Text(loi ?? "Không tìm thấy đề nào.")
                            .font(.body).foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity).padding(.top, Spacing.xl)
                } else {
                    tomTat
                    ForEach(cay) { k in theKy(k) }
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Phòng thi")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { ngonNgu = ngonNgu.doiSang } label: {
                    Text(ngonNgu.nhanNut).font(.system(size: 13, weight: .bold))
                }
                .accessibilityLabel(ngonNgu == .viet ? "Chuyển sang tiếng Anh" : "Chuyển sang tiếng Việt")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink { DaLuuView() } label: {
                    Image(systemName: "bookmark")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink { LichSuThiView() } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
            }
        }
        // Màn chi tiết đề mở ra từ đây phải nói CÙNG thứ tiếng với danh sách.
        .environment(\.ngonNguDe, ngonNgu)
        .navigationBarTitleDisplayMode(.inline)
        .task { if de.isEmpty { await tai() } }
        .onChange(of: de.count) { _, _ in cay = dungCay() }
        .onChange(of: tuKhoa) { _, _ in cay = dungCay() }
        .onChange(of: loaiChon) { _, _ in cay = dungCay() }
        .refreshable { await tai() }
    }

    // ── Ô tìm ───────────────────────────────────────────────────
    private var oTim: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14)).foregroundColor(AppColors.textTertiary)
            TextField("Tìm đề, mã đề, môn, kỳ thi…", text: $tuKhoa)
                .font(.system(size: 15))
                .oKhongTuSua()
            if !tuKhoa.isEmpty {
                Button { tuKhoa = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15)).foregroundColor(AppColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.sm + 2)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundCard))
    }

    // ── Thanh lọc theo LOẠI đề ──────────────────────────────────
    private var thanhLoai: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                nutLoai(nil, "Tất cả", de.count, AppColors.textSecondary)
                ForEach(loaiCo, id: \.0) { l, n in
                    nutLoai(l, l.ma, n, l.mau)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func nutLoai(_ l: LoaiDe?, _ nhan: String, _ soLuong: Int, _ mau: Color) -> some View {
        let chon = loaiChon == l
        return Button {
            withAnimation(.easeOut(duration: 0.15)) { loaiChon = chon ? nil : l }
            Haptics.cham()
        } label: {
            HStack(spacing: 5) {
                if let l { Image(systemName: l.bieuTuong).font(.system(size: 10)) }
                Text(nhan).font(.system(size: 12, weight: .semibold))
                Text("\(soLuong)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(chon ? .white.opacity(0.75) : AppColors.textTertiary)
            }
            .foregroundColor(chon ? .white : mau)
            .lineLimit(1)
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(Capsule()
                .fill(chon ? mau : mau.opacity(0.12))
                .overlay(Capsule().strokeBorder(chon ? .clear : mau.opacity(0.35), lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }

    private var tomTat: some View {
        Text("\(hienThi.count) đề · \(cay.reduce(0) { $0 + $1.mon.count }) môn · \(cay.count) kỳ")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(AppColors.textTertiary).kerning(0.4)
    }

    // ── Thẻ Kỳ học ──────────────────────────────────────────────
    private func theKy(_ k: Ky) -> some View {
        let mo = dangTim || kyMo.contains(k.so)
        return VStack(spacing: 0) {
            Button {
                Haptics.cham()
                withAnimation(.snappy(duration: 0.22)) {
                    if kyMo.contains(k.so) { kyMo.remove(k.so) } else { kyMo.insert(k.so) }
                }
            } label: {
                HStack(spacing: Spacing.md) {
                    Text(k.soHien)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.primary)
                        .frame(width: 38, height: 38)
                        .background(AppColors.primary.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(k.ten)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                        Text("\(k.mon.count) môn · \(k.soDe) đề")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: mo ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(Spacing.md)
                .background(AppColors.backgroundCard)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(dangTim)   // đang tìm thì mọi nhóm mở sẵn, gập lại là mất kết quả

            if mo {
                VStack(spacing: 0) {
                    ForEach(k.mon) { m in theMon(m, soKy: k.so) }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    // ── Thẻ Môn ─────────────────────────────────────────────────
    private func theMon(_ m: Mon, soKy: Int) -> some View {
        let khoa = "\(soKy)|\(m.ma)"
        let mo = dangTim || monMo.contains(khoa)
        return VStack(spacing: 0) {
            Divider().background(AppColors.divider)
            Button {
                Haptics.cham()
                withAnimation(.snappy(duration: 0.2)) {
                    if monMo.contains(khoa) { monMo.remove(khoa) } else { monMo.insert(khoa) }
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    // Mã môn thay cho tên dài: nhận ra ngay và mọi dòng thẳng cột.
                    Text(m.ma)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.secondary)
                        .frame(width: 62, alignment: .leading)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(m.ten.tachSongNgu(ngonNgu))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)
                        Text("\(m.de.count) đề")
                            .font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: mo ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(.horizontal, Spacing.md).padding(.vertical, 11)
                .background(AppColors.backgroundSecondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(dangTim)

            if mo {
                // Dòng ngăn theo KỲ THI, chỉ hiện khi sang kỳ mới — nhìn là
                // thấy ngay "đây là chỗ đề Spring 2026 kết thúc".
                LazyVStack(spacing: 0) {
                ForEach(Array(m.de.enumerated()), id: \.element.id) { i, d in
                    let truoc = i > 0 ? m.de[i - 1].mocKy : Int.min
                    if d.mocKy != truoc { VachKyThi(ky: d.kyThi) }
                    NavigationLink(destination: ChiTietDeView(de: d)) {
                        HangDeThi(de: d, ngonNgu: ngonNgu)
                    }
                    .buttonStyle(.plain)
                }
                }
            }
        }
    }

    private func tai() async {
        dangTai = true; defer { dangTai = false }
        do {
            de = try await APIClient.shared.request(.dsDeThi)
            loi = nil
        } catch { loi = error.localizedDescription }
    }
}

// ── Trước khi vào thi ───────────────────────────────────────────

struct ChiTietDeView: View {
    @Environment(\.ngonNguDe) private var ngonNgu
    let de: DeThi
    /// Dòng "Môn · Kỳ" khi nơi gọi biết rõ hơn chính `de`.
    ///
    /// ⚠️ Mở từ màn ĐÃ LƯU thì `de` là `bookmark.exam`, mà bản đó KHÔNG mang
    /// `course`/`semester` (máy chủ trả chúng thành trường anh em) — để mặc
    /// thì dòng này hiện "Khác". Nơi gọi truyền hộ.
    var moTaMon: String?
    @State private var vaoThi = false
    @State private var vaoOnTap = false
    /// `nil` = chưa biết (đang hỏi máy chủ). Không đoán `false` rồi vẽ nút
    /// rỗng: bấm vào lúc đó là GỠ mất dấu trang người dùng đã lưu từ web.
    @State private var daLuu: Bool?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    // Cùng bộ huy hiệu màu với danh sách — mở một đề ra mà
                    // mất hết dấu nhận biết thì phải cuộn lên đọc chữ mới
                    // biết mình đang xem loại gì.
                    NhanLoaiVaKy(de: de, coChu: 12)
                    Text(de.ten(ngonNgu))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    // Dòng phụ là nửa còn lại — ở màn chi tiết có chỗ, và
                    // thấy cả hai tên giúp đối chiếu với đề giấy.
                    if let phu = de.tenPhu(ngonNgu) {
                        Text(phu)
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                          spacing: Spacing.sm) {
                    o("Số câu", "\(de.soCau)", "list.number")
                    o("Thời gian", "\(de.phut) phút", "clock")
                    o("Tổng điểm", nz(de.totalPoints), "star")
                    o("Điểm đạt", nz(de.passMark), "checkmark.seal")
                }

                let dongMon = moTaMon ?? [de.tenKhoa, de.tenKy]
                    .filter { !$0.isEmpty && $0 != "Khác" }
                    .joined(separator: " · ")
                if !dongMon.isEmpty {
                    Text(dongMon.tachSongNgu(ngonNgu))
                        .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                }

                Text("Đồng hồ chạy từ lúc bạn bấm Bắt đầu. Thoát ra rồi vào lại "
                   + "thì làm tiếp bài đang dở, không mất bài.")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    vaoThi = true
                } label: {
                    Text("Bắt đầu làm bài")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Capsule().fill(AppColors.primary))
                }
                .buttonStyle(.plain)

                // ── Phòng ôn tập cùng CuongMini ──────────────────────
                // Lượt RIÊNG, tách hẳn khỏi lượt thi thật: máy chủ lọc
                // `where: { …, aiAssisted }` nên bấm nút này KHÔNG bao giờ
                // nối nhầm vào bài đang chạy đồng hồ, và ngược lại.
                VStack(spacing: Spacing.sm) {
                    Button {
                        vaoOnTap = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Thi cùng CuongMini")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Capsule().fill(
                            LinearGradient(colors: [AppColors.primary, AppColors.primaryDark],
                                           startPoint: .leading, endPoint: .trailing)))
                    }
                    .buttonStyle(.plain)

                    Text("Phòng ôn tập — KHÔNG tính giờ. Làm từng câu, hỏi AI về "
                       + "đúng câu đang mở, xem đáp án và bình luận thoải mái.")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textTertiary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(de.code ?? "Đề thi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { nutLuu }
        }
        .task { await hoiDaLuu() }
        .fullScreenCover(isPresented: $vaoThi) {
            LamBaiView(de: de)
        }
        .fullScreenCover(isPresented: $vaoOnTap) {
            LamBaiView(de: de, coAI: true)
        }
    }

    // ── Lưu đề ──────────────────────────────────────────────────
    //
    // ⚠️ `POST /exams/:id/bookmark` là LẬT trạng thái, không phải "đặt", nên
    // phải biết trạng thái hiện tại trước khi cho bấm. Máy chủ KHÔNG gửi kèm
    // cờ đó trong `/take`, nên phải hỏi riêng danh sách đã lưu.
    //
    // Trước 05/09/2026 app KHÔNG có nút này ở đâu cả — `danhDauDeThi` đã khai
    // trong `APIEndpoint` nhưng không nơi nào gọi, nên tab "Đề đã lưu" chỉ
    // đầy lên được nếu người dùng lưu bên WEB. Một màn hình chỉ để hiện thứ
    // mà chính nó không tạo ra được.
    @ViewBuilder
    private var nutLuu: some View {
        if let co = daLuu {
            Button {
                Task { await lat(dangCo: co) }
            } label: {
                Image(systemName: co ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(co ? AppColors.accent : AppColors.textSecondary)
            }
            .accessibilityLabel(co ? "Bỏ lưu đề" : "Lưu đề")
        } else {
            ProgressView().controlSize(.small)
        }
    }

    private func hoiDaLuu() async {
        guard daLuu == nil else { return }
        let ds: [DeDaLuu]? = try? await APIClient.shared.request(.dsDeDaLuu)
        // Hỏi hỏng thì coi như CHƯA lưu — vẫn bấm được, và cú bấm đầu tiên
        // trả về trạng thái thật từ máy chủ nên nó tự sửa mình.
        daLuu = ds?.contains { $0.examId == de.id } ?? false
    }

    private func lat(dangCo: Bool) async {
        struct R: Codable { let bookmarked: Bool }
        daLuu = !dangCo                        // đổi ngay cho tay bấm thấy phản hồi
        Haptics.cham()
        do {
            let r: R = try await APIClient.shared.request(.danhDauDeThi(examId: de.id))
            daLuu = r.bookmarked               // máy chủ mới là nguồn sự thật
        } catch {
            daLuu = dangCo                     // hỏng thì trả lại như cũ
        }
    }

    private func nz(_ v: Double?) -> String {
        guard let v else { return "—" }
        return v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }

    private func o(_ ten: String, _ giaTri: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11)).foregroundColor(AppColors.primary)
                Text(ten).font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
            }
            Text(giaTri)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundCard))
    }
}
