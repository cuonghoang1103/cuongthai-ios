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
    /// Lọc theo KỲ HỌC (`semester.ordinal`) và theo MÔN (`courseCode`).
    @State private var kyChon: Int?
    @State private var monChon: String?
    @State private var ganDay: [LuotDaLam] = []
    @ObservedObject private var dangDo = KhoLuotDangDo.chung
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
        if let k = kyChon { ds = ds.filter { $0.soKyHoc == k } }
        if let m = monChon { ds = ds.filter { $0.maMon == m } }
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
        !tuKhoa.trimmingCharacters(in: .whitespaces).isEmpty || loaiChon != nil || kyChon != nil || monChon != nil
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.md, pinnedViews: []) {
                if tuKhoa.isEmpty && !dangTim { phanDau }
                oTim
                thanhLoai
                thanhKyMon

                if dangTai && de.isEmpty {
                    ForEach(0..<5, id: \.self) { _ in SkeletonBox(height: 62, radius: CornerRadius.medium) }
                } else if let l = loi, de.isEmpty {
                    ErrorStateView(message: l) { Task { await tai() } }
                } else if hienThi.isEmpty {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "doc.questionmark")
                            .font(.system(size: 36)).foregroundColor(AppColors.textTertiary)
                        Text(T("Không có đề nào khớp. Thử bỏ bớt bộ lọc."))
                            .font(.body).foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity).padding(.top, Spacing.xl)
                } else {
                    tomTat
                    ForEach(cay) { k in theKy(k) }
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity)
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
        .onChange(of: kyChon) { _, _ in cay = dungCay() }
        .onChange(of: monChon) { _, _ in cay = dungCay() }
        .task { await taiGanDay() }
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
                if let slug = m.de.first?.course?.slug, !slug.isEmpty {
                    NavigationLink {
                        DeThiTheoMonView(khoaHoc: slug, ten: m.ten, maMon: m.ma)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chart.bar.doc.horizontal").font(.caption)
                            Text(T("Tiến độ của bạn ở môn này")).font(.caption.weight(.semibold))
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption2.weight(.semibold))
                        }
                        .foregroundColor(AppColors.primary)
                        .padding(.horizontal, Spacing.md).padding(.vertical, 9)
                        .background(AppColors.primary.opacity(0.06))
                    }
                    .buttonStyle(.plain)
                }
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

    // ── Đầu trang: đang làm dở + kết quả gần đây ───────────────
    @ViewBuilder private var phanDau: some View {
        let dsDo = dangDo.conHieuLuc
        if !dsDo.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label(T("Đang làm dở"), systemImage: "play.circle.fill")
                    .font(.footnote.weight(.semibold)).foregroundColor(AppColors.warning)
                ForEach(dsDo.prefix(3)) { l in
                    NavigationLink {
                        ChiTietDeView(de: l.de ?? de.first { $0.id == l.examId } ?? DeThi.toiGian(id: l.examId, title: l.tieuDe, code: l.maDe))
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: l.coAI ? "sparkles" : "timer")
                                .foregroundColor(l.coAI ? AppColors.primary : AppColors.warning)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l.tieuDe.tachSongNgu(ngonNgu)).font(.subheadline.weight(.medium))
                                    .foregroundColor(AppColors.textPrimary).lineLimit(1)
                                Text(l.coAI ? T("Ôn tập cùng CuongMini · không tính giờ")
                                     : String(format: T("Còn khoảng %d phút"), (l.conLaiGiay ?? 0) / 60))
                                    .font(.caption).foregroundColor(AppColors.textTertiary)
                            }
                            Spacer(minLength: 0)
                            Text(T("Tiếp tục")).font(.caption.weight(.bold)).foregroundColor(AppColors.primary)
                        }
                        .padding(Spacing.sm + 2)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.backgroundCard))
                    }
                    .buttonStyle(.nhan)
                }
            }
        }
        if !ganDay.isEmpty {
            NavigationLink { LichSuThiView() } label: {
                HStack(spacing: Spacing.md) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(T("Kết quả gần đây")).font(.footnote.weight(.semibold)).foregroundColor(AppColors.textSecondary)
                        let dat = ganDay.prefix(10).filter { $0.passed == true }.count
                        Text(String(format: T("%d lượt · đạt %d/%d lượt gần nhất"), ganDay.count, dat, min(10, ganDay.count)))
                            .font(.caption).foregroundColor(AppColors.textTertiary)
                    }
                    Spacer(minLength: 0)
                    // Mười cột nhỏ = mười lượt gần nhất, cao theo % điểm.
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(Array(ganDay.prefix(10).reversed())) { l in
                            let pt = (l.score ?? 0) / max(0.01, l.maxScore ?? 10)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(l.passed == true ? AppColors.success : AppColors.warning)
                                .frame(width: 6, height: max(3, 30 * pt))
                        }
                    }
                    .frame(height: 30)
                    .accessibilityHidden(true)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundColor(AppColors.textTertiary)
                }
                .padding(Spacing.md)
                .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.backgroundCard))
            }
            .buttonStyle(.nhan)
        }
    }

    // ── Lọc theo kỳ học + môn ───────────────────────────────────
    private var thanhKyMon: some View {
        let dsKy = Dictionary(grouping: de, by: \.soKyHoc).map { ($0.key, $0.value.first?.tenKyHoc ?? "") }.sorted { $0.0 < $1.0 }
        let goc = kyChon.map { k in de.filter { $0.soKyHoc == k } } ?? de
        let dsMon = Dictionary(grouping: goc, by: \.maMon).map { ($0.key, $0.value.first?.tenKhoa ?? "") }.sorted { $0.0 < $1.0 }
        return HStack(spacing: Spacing.sm) {
            Menu {
                Button(T("Mọi kỳ học")) { kyChon = nil }
                ForEach(dsKy, id: \.0) { k, ten in Button(ten) { kyChon = k; monChon = nil } }
            } label: {
                nhanMenu(kyChon.flatMap { k in dsKy.first { $0.0 == k }?.1 } ?? T("Kỳ học"), dangChon: kyChon != nil)
            }
            Menu {
                Button(T("Mọi môn")) { monChon = nil }
                ForEach(dsMon, id: \.0) { m, ten in Button("\(m) · \(ten.tachSongNgu(ngonNgu))") { monChon = m } }
            } label: {
                nhanMenu(monChon ?? T("Môn"), dangChon: monChon != nil)
            }
            if kyChon != nil || monChon != nil {
                Button(T("Bỏ lọc")) { kyChon = nil; monChon = nil }
                    .font(.caption.weight(.semibold))
            }
            Spacer(minLength: 0)
        }
    }

    private func nhanMenu(_ chu: String, dangChon: Bool) -> some View {
        HStack(spacing: 4) {
            Text(chu).font(.caption.weight(.semibold)).lineLimit(1)
            Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
        }
        .foregroundColor(dangChon ? .white : AppColors.textSecondary)
        .padding(.horizontal, 11).padding(.vertical, 6)
        .background(Capsule().fill(dangChon ? AppColors.primary : AppColors.backgroundCard))
    }

    private func taiGanDay() async {
        // Không chặn màn hình: hỏng (chưa đăng nhập, mất mạng) thì chỉ không hiện khối này.
        ganDay = (try? await APIClient.shared.request(.luotThiCuaToi)) ?? []
    }

    private func tai() async {
        dangTai = true; defer { dangTai = false }
        do {
            de = try await APIClient.shared.request(.dsDeThi)
            loi = nil
        } catch { loi = error.localizedDescription }
    }
}

extension DeThi {
    /// Đề tối giản khi chỉ còn id + tên (mục "đang làm dở" cũ không lưu đủ đề).
    static func toiGian(id: Int, title: String, code: String?) -> DeThi {
        DeThi(id: id, courseId: nil, kind: nil, peType: nil, title: title, code: code,
              durationMinutes: nil, totalPoints: nil, passMark: nil, questionCount: nil,
              course: nil, semester: nil, source: nil, description: nil,
              attachmentUrl: nil, attachmentName: nil, my: nil)
    }
}
