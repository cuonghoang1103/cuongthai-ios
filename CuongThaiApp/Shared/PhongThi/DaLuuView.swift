import SwiftUI

// ════════════════════════════════════════════════════════════════
// ĐÃ LƯU — câu đã lưu + đề đã lưu
//
// Nói CÙNG một thứ tiếng hình ảnh với màn Phòng thi (05/09/2026): gom theo
// MÔN, trong mỗi môn xếp theo KỲ THI mới nhất trước, và mỗi loại đề một màu
// riêng — dùng chung `HangDeThi` / `VachKyThi` / `NhanLoaiVaKy` ở
// `PhanLoaiDe.swift` chứ KHÔNG chép lại, để hai màn không trôi khỏi nhau.
//
// ⚠️ Ở đây `exam` KHÔNG mang `course`/`semester` (máy chủ trả chúng thành
// trường anh em ở tầng ngoài) — luôn đọc `maMon` / `soKyHoc` của CHÍNH mục
// đã lưu, đừng đọc qua `exam`.
// ════════════════════════════════════════════════════════════════

// MARK: - Màn hình

struct DaLuuView: View {
    private enum Tab: String, CaseIterable { case cau = "Câu đã lưu", de = "Đề đã lưu" }

    @State private var tab: Tab = .cau
    @State private var cau: [CauHoiDaLuu] = []
    @State private var de: [DeDaLuu] = []
    @State private var dangTai = true
    @State private var loi: String?
    @State private var suaGhiChu: CauHoiDaLuu?
    @State private var chuGhiChu = ""
    @State private var ngonNgu: NgonNguDe = .anh

    /// Nhóm theo MÔN. Người ôn thi nghĩ theo môn, không theo thứ tự lưu.
    ///
    /// Khoá nhóm là chuỗi GỐC còn `|||` (ổn định, không đổi theo nút EN/VI);
    /// xếp thì theo kỳ học rồi mã môn, đúng thứ tự màn Phòng thi.
    private var cauTheoMon: [(khoa: String, ma: String, ky: String, ds: [CauHoiDaLuu])] {
        Dictionary(grouping: cau, by: \.khoaMon)
            .map { (khoa: $0.key, ma: $0.value.first?.maMon ?? "—",
                    ky: $0.value.first?.tenKyHoc ?? "",
                    ds: $0.value) }
            .sorted {
                let a = $0.ds.first?.soKyHoc ?? 99, b = $1.ds.first?.soKyHoc ?? 99
                return a != b ? a < b : $0.ma < $1.ma
            }
    }

    /// Đề đã lưu: cùng cách gom, và trong mỗi môn xếp theo KỲ THI mới nhất
    /// trước — y hệt màn Phòng thi.
    private var deTheoMon: [(khoa: String, ma: String, ky: String, ds: [DeDaLuu])] {
        Dictionary(grouping: de, by: \.tenMon)
            .map { khoa, ds in
                (khoa: khoa, ma: ds.first?.maMon ?? "—", ky: ds.first?.tenKyHoc ?? "",
                 ds: ds.sorted {
                     if $0.exam.mocKy != $1.exam.mocKy { return $0.exam.mocKy > $1.exam.mocKy }
                     if $0.exam.soDe != $1.exam.soDe { return $0.exam.soDe < $1.exam.soDe }
                     return ($0.exam.code ?? "") < ($1.exam.code ?? "")
                 })
            }
            .sorted {
                let a = $0.ds.first?.soKyHoc ?? 99, b = $1.ds.first?.soKyHoc ?? 99
                return a != b ? a < b : $0.ma < $1.ma
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases, id: \.rawValue) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(Spacing.md)

            if dangTai {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { cuon in
                ScrollView {
                    LazyVStack(spacing: Spacing.sm) {
                        NeoDauTrang()
                        if tab == .cau { khungCau } else { khungDe }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.xl)
                }
                // Picker phân đoạn GHIM trên vùng cuộn: đổi tab lúc đang cuộn
                // sâu là danh sách bên kia mở ra ở giữa chừng.
                .onChange(of: tab) { _, _ in cuon.veDauTrang() }
                }
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Đã lưu")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { ngonNgu = ngonNgu.doiSang } label: {
                    Text(ngonNgu.nhanNut).font(.system(size: 13, weight: .bold))
                }
            }
        }
        .environment(\.ngonNguDe, ngonNgu)
        .alert("Ghi chú riêng", isPresented: Binding(
            get: { suaGhiChu != nil },
            set: { if !$0 { suaGhiChu = nil } })) {
            TextField("Vì sao câu này khó?", text: $chuGhiChu)
            Button("Huỷ", role: .cancel) { suaGhiChu = nil }
            Button("Lưu") { Task { await luuGhiChu() } }
        }
        .task { await tai() }
    }

    /// Tiêu đề một nhóm môn — cùng khuôn cho cả hai tab.
    private func tieuDeMon(_ ma: String, _ ten: String, _ ky: String, _ soLuong: Int) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(ma)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(AppColors.secondary)
            Text(ten.tachSongNgu(ngonNgu))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
            if !ky.isEmpty {
                Text("· \(ky)")
                    .font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
            }
            Spacer(minLength: 0)
            Text("\(soLuong)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Spacing.sm)
    }

    // MARK: Câu đã lưu

    @ViewBuilder
    private var khungCau: some View {
        if cau.isEmpty {
            trong("bookmark", loi ?? "Chưa có câu nào được lưu.\nTrong màn xem lại bài thi, bấm dấu trang ở câu bạn muốn ôn lại.")
        } else {
            ForEach(cauTheoMon, id: \.khoa) { n in
                tieuDeMon(n.ma, n.khoa, n.ky, n.ds.count)
                ForEach(n.ds) { c in theCau(c) }
            }
        }
    }

    private func theCau(_ c: CauHoiDaLuu) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top) {
                // Huy hiệu loại + mã đề + kỳ thi, cùng bộ màu với Phòng thi:
                // câu lưu từ một đề PE và câu lưu từ một bài Nghe phải nhìn
                // ra được sự khác nhau ngay, không cần mở lên đọc.
                NhanLoaiVaKy(de: c.exam, coChu: 10)
                Spacer(minLength: Spacing.sm)
                Button {
                    chuGhiChu = c.note ?? ""
                    suaGhiChu = c
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textTertiary)
                }
                .buttonStyle(.plain)
                Button { Task { await boLuu(c) } } label: {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: 0xF59E0B))
                }
                .buttonStyle(.plain)
            }

            NoiDungThi(chu: c.question.prompt, coChu: 15, laDeBai: true)

            // CHỈ hiện đáp án đúng, không hiện cả 4 phương án: đây là chỗ ôn
            // lại, người ta cần nhớ ĐÁP ÁN chứ không phải làm lại bài.
            if let ds = c.question.options, !c.question.dapAnDung.isEmpty {
                ForEach(c.question.dapAnDung, id: \.self) { i in
                    if i < ds.count {
                        HStack(alignment: .top, spacing: Spacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.success)
                            // Đáp án đúng cũng là nội dung đề — cũng phải
                            // tách `|||` và dựng công thức nếu có.
                            NoiDungThi(chu: ds[i].text, coChu: 14, mauChu: AppColors.success)
                        }
                    }
                }
            }

            if let gt = c.question.explanation, !gt.isEmpty {
                NoiDungThi(chu: gt, coChu: 12, mauChu: AppColors.textSecondary)
            }

            if let n = c.note, !n.isEmpty {
                HStack(alignment: .top, spacing: Spacing.xs) {
                    Image(systemName: "pencil.line").font(.system(size: 11))
                    Text(n).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                }
                .foregroundColor(Color(hex: 0xD97706))
                .padding(Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(Color(hex: 0xD97706).opacity(0.10)))
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large)
            .fill(AppColors.backgroundCard))
    }

    // MARK: Đề đã lưu

    @ViewBuilder
    private var khungDe: some View {
        if de.isEmpty {
            trong("doc.text", "Chưa có đề nào được lưu.")
        } else {
            ForEach(deTheoMon, id: \.khoa) { n in
                tieuDeMon(n.ma, n.khoa, n.ky, n.ds.count)
                VStack(spacing: 0) {
                    ForEach(Array(n.ds.enumerated()), id: \.element.id) { i, d in
                        let truoc = i > 0 ? n.ds[i - 1].exam.mocKy : Int.min
                        if d.exam.mocKy != truoc {
                            VachKyThi(ky: d.exam.kyThi, nen: AppColors.backgroundPrimary)
                        }
                        // ⚠️ Mở màn CHI TIẾT, không lao thẳng vào `LamBaiView`.
                        // Vào thẳng là đồng hồ chạy ngay và mất luôn đường vào
                        // phòng ôn tập CuongMini — một cú chạm nhầm ở màn dấu
                        // trang thành một lượt thi tính giờ.
                        NavigationLink {
                            // Truyền hộ dòng "Môn · Kỳ": `d.exam` không mang
                            // `course`/`semester` nên tự nó chỉ hiện "Khác".
                            ChiTietDeView(de: d.exam, moTaMon: [n.khoa, n.ky]
                                .filter { !$0.isEmpty }.joined(separator: " · "))
                        } label: {
                            HangDeThi(de: d.exam, ngonNgu: ngonNgu)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            }
        }
    }

    private func trong(_ icon: String, _ chu: String) -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: icon).font(.system(size: 40))
                .foregroundColor(AppColors.textTertiary)
            Text(chu)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Spacing.xxl)
    }

    // MARK: Mạng

    private func tai() async {
        dangTai = true; defer { dangTai = false }
        async let a: [CauHoiDaLuu] = APIClient.shared.request(.dsCauHoiDaLuu)
        async let b: [DeDaLuu] = APIClient.shared.request(.dsDeDaLuu)
        do { cau = try await a; de = try await b; loi = nil }
        catch { loi = error.localizedDescription }
    }

    private func boLuu(_ c: CauHoiDaLuu) async {
        struct R: Codable { let bookmarked: Bool }
        let truoc = cau
        cau.removeAll { $0.id == c.id }
        do { _ = try await APIClient.shared.request(.danhDauCauHoi(questionId: c.questionId)) as R }
        catch { cau = truoc }
    }

    private func luuGhiChu() async {
        guard let c = suaGhiChu else { return }
        let g = chuGhiChu
        suaGhiChu = nil
        struct R: Codable { let updated: Bool? }
        do {
            _ = try await APIClient.shared.request(.ghiChuCauHoi(questionId: c.questionId, ghiChu: g)) as R
            await tai()
        } catch { }
    }
}
