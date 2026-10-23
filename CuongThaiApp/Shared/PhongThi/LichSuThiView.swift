import SwiftUI
import Charts

// MARK: - Lượt thi của tôi
//
// `GET /exams/attempts/mine` (tuỳ chọn `?examId=`) — 200 lượt gần nhất, đã nộp
// hoặc hết giờ. Thêm so với bản cũ: biểu đồ xu hướng điểm (theo % để đề thang
// 10 và thang 100 so được với nhau), lọc theo môn, và XOÁ lượt (đúng như web:
// `DELETE /attempts/:id`, có hỏi lại).

struct LichSuThiView: View {
    /// Chỉ lịch sử của MỘT đề (mở từ màn chi tiết đề).
    var examId: Int?
    var tieuDe: String?

    @State private var ds: [LuotDaLam] = []
    /// Mặc định TIẾNG ANH, giống Phòng thi và màn làm bài.
    @State private var ngonNgu: NgonNguDe = .anh
    @State private var dangTai = true
    @State private var loi: String?
    @State private var monLoc: String?
    @State private var canXoa: LuotDaLam?

    private var hien: [LuotDaLam] {
        guard let m = monLoc else { return ds }
        return ds.filter { $0.exam?.maMon == m }
    }
    private var dsMon: [String] {
        Array(Set(ds.compactMap { $0.exam?.course?.courseCode })).sorted()
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                if dangTai && ds.isEmpty {
                    // Một VStack: ô xương id 0…n nằm thẳng trong LazyVStack trùng id phần tử thật ⇒ ô trống (xem PhongThiView).
                    VStack(spacing: Spacing.sm) {
                        ForEach(0..<5, id: \.self) { _ in SkeletonBox(height: 70, radius: CornerRadius.large) }
                    }
                } else if let l = loi, ds.isEmpty {
                    ErrorStateView(message: l) { Task { await tai() } }
                } else if ds.isEmpty {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40)).foregroundColor(AppColors.textTertiary)
                        Text(examId == nil ? T("Bạn chưa làm bài thi nào.") : T("Bạn chưa làm đề này lần nào."))
                            .font(.subheadline).foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.top, Spacing.xxl)
                } else {
                    if hien.filter({ $0.score != nil }).count >= 2 { theXuHuong }
                    if examId == nil && dsMon.count > 1 { thanhMon }
                    ForEach(hien) { l in
                        NavigationLink { NapXemLaiView(attemptId: l.id, tieuDe: l.exam?.title ?? T("Đề thi")) } label: { hang(l) }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) { canXoa = l } label: {
                                    Label(T("Xoá khỏi lịch sử"), systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(tieuDe ?? T("Lượt thi của tôi"))
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
        .confirmationDialog(T("Xoá lượt thi này khỏi lịch sử?"), isPresented: Binding(
            get: { canXoa != nil }, set: { if !$0 { canXoa = nil } }), titleVisibility: .visible) {
            Button(T("Xoá"), role: .destructive) {
                if let l = canXoa { Task { await xoa(l) } }
            }
            Button(T("Huỷ"), role: .cancel) { }
        } message: {
            Text(T("Điểm và bài làm của lượt này sẽ mất hẳn, không khôi phục được."))
        }
        .task { await tai() }
        .refreshable { await tai() }
    }

    private func tai() async {
        dangTai = true; defer { dangTai = false }
        do {
            ds = try await APIClient.shared.request(examId.map { .luotThiCuaDe(examId: $0) } ?? .luotThiCuaToi)
            loi = nil
        } catch { loi = error.localizedDescription }
    }

    private func xoa(_ l: LuotDaLam) async {
        let truoc = ds
        withAnimation { ds.removeAll { $0.id == l.id } }
        do {
            try await APIClient.shared.send(.xoaLuotThi(attemptId: l.id))
            KhoLuotDangDo.chung.xoa(attemptId: l.id)
            Haptics.xong()
        } catch {
            ds = truoc
            loi = error.localizedDescription
            Haptics.hong()
        }
    }

    // ── Xu hướng điểm ───────────────────────────────────────────
    private struct Diem: Identifiable {
        let id: Int; let thuTu: Int; let phanTram: Double; let dat: Bool
    }

    private var theXuHuong: some View {
        // Cũ → mới, tối đa 20 lượt gần nhất có điểm.
        let co = Array(hien.filter { $0.score != nil }.prefix(20).reversed())
        let diem = co.enumerated().map { i, l in
            Diem(id: l.id, thuTu: i + 1,
                 phanTram: (l.score ?? 0) / max(0.01, l.maxScore ?? 10) * 100,
                 dat: l.passed == true)
        }
        let tb = diem.map(\.phanTram).reduce(0, +) / Double(max(1, diem.count))
        let soDat = diem.filter(\.dat).count
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(T("Xu hướng điểm")).font(.footnote.weight(.semibold)).foregroundColor(AppColors.textSecondary)
                Spacer()
                Text(String(format: T("TB %d%% · đạt %d/%d"), Int(tb.rounded()), soDat, diem.count))
                    .font(.caption.monospacedDigit()).foregroundColor(AppColors.textTertiary)
            }
            Chart(diem) { d in
                AreaMark(x: .value(T("Lượt"), d.thuTu), y: .value("%", d.phanTram))
                    .foregroundStyle(AppColors.primary.opacity(0.12))
                    .interpolationMethod(.monotone)
                LineMark(x: .value(T("Lượt"), d.thuTu), y: .value("%", d.phanTram))
                    .foregroundStyle(AppColors.primary)
                    .interpolationMethod(.monotone)
                PointMark(x: .value(T("Lượt"), d.thuTu), y: .value("%", d.phanTram))
                    .foregroundStyle(d.dat ? AppColors.success : AppColors.warning)
                    .symbolSize(30)
            }
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis { AxisMarks(values: [0, 50, 100]) }
            .frame(height: 120)
            .accessibilityLabel(String(format: T("Biểu đồ điểm %d lượt gần nhất, trung bình %d phần trăm"), diem.count, Int(tb.rounded())))
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    private var thanhMon: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(nil, T("Tất cả môn"))
                ForEach(dsMon, id: \.self) { chip($0, $0) }
            }
        }
    }

    private func chip(_ m: String?, _ nhan: String) -> some View {
        let chon = monLoc == m
        return Button { withAnimation { monLoc = m } } label: {
            Text(nhan).font(.caption.weight(.semibold))
                .foregroundColor(chon ? .white : AppColors.textSecondary)
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(Capsule().fill(chon ? AppColors.primary : AppColors.backgroundCard))
        }
        .buttonStyle(.plain)
    }

    private func hang(_ l: LuotDaLam) -> some View {
        let mau: Color = l.hetGio ? AppColors.textTertiary : (l.passed == true ? AppColors.success : AppColors.warning)
        return HStack(spacing: Spacing.md) {
            VStack(spacing: 1) {
                Text(l.score.map(DinhDangSo.gon) ?? "—")
                    .font(.system(.title3, design: .rounded).weight(.black))
                    .foregroundColor(mau)
                Text("/" + DinhDangSo.gon(l.maxScore ?? l.exam?.totalPoints ?? 10))
                    .font(.caption2).foregroundColor(AppColors.textTertiary)
            }
            .frame(width: 54)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    if let e = l.exam {
                        Text(e.loai.ma).font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().fill(e.loai.mau))
                        if let m = e.course?.courseCode { Text(m).font(.caption2.monospaced()).foregroundColor(AppColors.textTertiary) }
                    }
                }
                Text(l.exam?.ten(ngonNgu) ?? T("Đề thi"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: Spacing.xs) {
                    Text(l.hetGio ? T("Hết giờ") : (l.passed == true ? T("Đạt") : T("Chưa đạt")))
                        .font(.caption2.weight(.bold)).foregroundColor(mau)
                    if let d = l.feedback?.correctCount, let t = l.feedback?.total, t > 0 {
                        Text("· " + String(format: T("đúng %d/%d"), d, t)).font(.caption2).foregroundColor(AppColors.textTertiary)
                    }
                    if (l.timeSpentSeconds ?? 0) > 0 {
                        Text("· \(l.phut)′\(String(format: "%02d", l.giay))″").font(.caption2).foregroundColor(AppColors.textTertiary)
                    }
                    if let s = l.submittedAt {
                        Text("· " + TimeFormatter.formatTimeAgo(s)).font(.caption2).foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
        .contentShape(Rectangle())
        .accessibilityHint(T("Nhấn giữ để xoá khỏi lịch sử"))
    }
}

// MARK: - Nạp bản xem lại của một lượt cũ

/// Lượt vừa nộp thì bản xem lại đã có sẵn trong phản hồi; lượt CŨ thì phải gọi
/// `GET /exams/attempts/:id` để lấy lại đáp án và lời giải.
struct NapXemLaiView: View {
    let attemptId: Int
    let tieuDe: String
    @State private var xemLai: XemLaiBaiThi?
    @State private var loi: String?

    init(attemptId: Int, tieuDe: String) { self.attemptId = attemptId; self.tieuDe = tieuDe }
    init(luot: LuotDaLam) { self.init(attemptId: luot.id, tieuDe: luot.exam?.title ?? T("Đề thi")) }

    var body: some View {
        Group {
            if let x = xemLai {
                XemLaiView(xemLai: x, tenDe: tieuDe)
            } else if let l = loi {
                ErrorStateView(message: l) { Task { await tai() } }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.backgroundPrimary)
            } else {
                VStack(spacing: Spacing.md) {
                    SkeletonBox(height: 130, radius: CornerRadius.large)
                    ForEach(0..<3, id: \.self) { _ in SkeletonBox(height: 160, radius: CornerRadius.large) }
                    Spacer()
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.backgroundPrimary)
            }
        }
        .task { if xemLai == nil { await tai() } }
    }

    private func tai() async {
        loi = nil
        do { xemLai = try await APIClient.shared.request(.xemLaiLuotThi(attemptId: attemptId)) }
        catch { loi = error.localizedDescription }
    }
}
