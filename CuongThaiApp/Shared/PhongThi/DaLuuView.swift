import SwiftUI

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

    /// Nhóm theo MÔN. Người ôn thi nghĩ theo môn, không theo thứ tự lưu.
    private var theoMon: [(String, [CauHoiDaLuu])] {
        Dictionary(grouping: cau, by: \.tenMon)
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value) }
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
                ScrollView {
                    LazyVStack(spacing: Spacing.sm) {
                        if tab == .cau { khungCau } else { khungDe }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.xl)
                }
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Đã lưu")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Ghi chú riêng", isPresented: Binding(
            get: { suaGhiChu != nil },
            set: { if !$0 { suaGhiChu = nil } })) {
            TextField("Vì sao câu này khó?", text: $chuGhiChu)
            Button("Huỷ", role: .cancel) { suaGhiChu = nil }
            Button("Lưu") { Task { await luuGhiChu() } }
        }
        .task { await tai() }
    }

    // MARK: Câu đã lưu

    @ViewBuilder
    private var khungCau: some View {
        if cau.isEmpty {
            trong("bookmark", loi ?? "Chưa có câu nào được lưu.\nTrong màn xem lại bài thi, bấm dấu trang ở câu bạn muốn ôn lại.")
        } else {
            ForEach(theoMon, id: \.0) { mon, ds in
                Text("\(mon.uppercased()) · \(ds.count)")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(0.5)
                    .foregroundColor(AppColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Spacing.sm)
                ForEach(ds) { c in theCau(c) }
            }
        }
    }

    private func theCau(_ c: CauHoiDaLuu) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top) {
                Text(c.exam.code ?? c.exam.ten)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppColors.primary)
                Spacer()
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

            Text(c.question.prompt)
                .font(.system(size: 15))
                .foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            // CHỈ hiện đáp án đúng, không hiện cả 4 phương án: đây là chỗ ôn
            // lại, người ta cần nhớ ĐÁP ÁN chứ không phải làm lại bài.
            if let ds = c.question.options, !c.question.dapAnDung.isEmpty {
                ForEach(c.question.dapAnDung, id: \.self) { i in
                    if i < ds.count {
                        HStack(alignment: .top, spacing: Spacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.success)
                            Text(ds[i].text)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.success)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if let gt = c.question.explanation, !gt.isEmpty {
                Text(gt)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
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
            ForEach(de) { d in
                NavigationLink { LamBaiView(de: d.exam) } label: {
                    HStack(spacing: Spacing.md) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(d.exam.ten)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(2).multilineTextAlignment(.leading)
                            Text("\(d.course?.title ?? "") · \(d.exam.soCau) câu · \(d.exam.phut)′")
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.textTertiary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(Spacing.md)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                        .fill(AppColors.backgroundCard))
                }
                .buttonStyle(.plain)
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
