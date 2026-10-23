import SwiftUI

// ════════════════════════════════════════════════════════════════
// ĐỀ THI CỦA MỘT MÔN — `GET /exams/course/:slug`
//
// Khác danh sách toàn bộ (`GET /exams`): đường này trả đủ `source`,
// `description`, tệp "Given", và `my` của CHÍNH người xem (lần thi, điểm cao
// nhất, lượt đang dở). Nên đây là chỗ cho biết "môn này tôi đã luyện tới đâu".
//
// Mở được từ: màn chi tiết đề ("Các đề khác của môn"), nhóm môn ở Phòng thi.
// Academy muốn nối vào thì chỉ cần `DeThiTheoMonView(khoaHoc: slug)`.
// ════════════════════════════════════════════════════════════════

struct DeThiTheoMonView: View {
    let khoaHoc: String
    var ten: String?
    var maMon: String?

    @State private var ds: [DeThi] = []
    @State private var dangTai = true
    @State private var loi: String?
    @State private var loai: LoaiDe?
    @State private var ngonNgu: NgonNguDe = .anh

    private var hien: [DeThi] {
        let x = loai.map { l in ds.filter { $0.loai == l } } ?? ds
        return x.sorted {
            if $0.mocKy != $1.mocKy { return $0.mocKy > $1.mocKy }
            if $0.soDe != $1.soDe { return $0.soDe < $1.soDe }
            return $0.id < $1.id
        }
    }

    private var daLam: Int { ds.filter { ($0.my?.soLan ?? 0) > 0 }.count }
    private var daDat: Int { ds.filter { $0.my?.daDat == true }.count }
    private var dangDo: [DeThi] { ds.filter { $0.my?.inProgressId != nil || $0.my?.aiInProgressId != nil } }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.md) {
                if dangTai && ds.isEmpty {
                    SkeletonBox(height: 110, radius: CornerRadius.large)
                    // Một VStack: ô xương id 0…n nằm thẳng trong LazyVStack trùng id phần tử thật ⇒ ô trống (xem PhongThiView).
                    VStack(spacing: Spacing.md) {
                        ForEach(0..<6, id: \.self) { _ in SkeletonBox(height: 64, radius: CornerRadius.medium) }
                    }
                } else if let l = loi, ds.isEmpty {
                    ErrorStateView(message: l) { Task { await tai() } }
                } else if ds.isEmpty {
                    Text(T("Môn này chưa có đề thi nào.")).font(.subheadline).foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity).padding(.top, Spacing.xl)
                } else {
                    tongQuan
                    if !dangDo.isEmpty {
                        Text(T("Đang làm dở")).font(.footnote.weight(.semibold)).foregroundColor(AppColors.textSecondary)
                        ForEach(dangDo) { d in dong(d) }
                    }
                    thanhLoai
                    LazyVStack(spacing: 0) {
                        ForEach(Array(hien.enumerated()), id: \.element.id) { i, d in
                            let truoc = i > 0 ? hien[i - 1].mocKy : Int.min
                            if d.mocKy != truoc { VachKyThi(ky: d.kyThi) }
                            dong(d)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(maMon ?? T("Đề theo môn"))
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
        .task { await tai() }
        .refreshable { await tai() }
    }

    private var tongQuan: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let t = ten { Text(t.tachSongNgu(ngonNgu)).font(.headline).foregroundColor(AppColors.textPrimary) }
            HStack(spacing: Spacing.sm) {
                o("\(ds.count)", T("đề"), AppColors.primary)
                o("\(daLam)", T("đã làm"), AppColors.info)
                o("\(daDat)", T("đã đạt"), AppColors.success)
            }
            ProgressView(value: ds.isEmpty ? 0 : Double(daLam) / Double(ds.count))
                .tint(AppColors.primary)
                .accessibilityLabel(String(format: T("Đã làm %d trên %d đề"), daLam, ds.count))
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    private func o(_ so: String, _ nhan: String, _ mau: Color) -> some View {
        VStack(spacing: 2) {
            Text(so).font(.system(.title2, design: .rounded).weight(.bold)).foregroundColor(mau)
            Text(nhan).font(.caption2).foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: CornerRadius.small).fill(mau.opacity(0.08)))
    }

    private var thanhLoai: some View {
        let co = Dictionary(grouping: ds, by: \.loai).map { ($0.key, $0.value.count) }.sorted { $0.0.thuTu < $1.0.thuTu }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(nil, T("Tất cả"), ds.count, AppColors.textSecondary)
                ForEach(co, id: \.0) { l, n in chip(l, l.ma, n, l.mau) }
            }
        }
    }

    private func chip(_ l: LoaiDe?, _ nhan: String, _ n: Int, _ mau: Color) -> some View {
        let chon = loai == l
        return Button { withAnimation(.easeOut(duration: 0.15)) { loai = chon ? nil : l } } label: {
            HStack(spacing: 4) {
                Text(nhan).font(.caption.weight(.semibold))
                Text("\(n)").font(.caption2).opacity(0.7)
            }
            .foregroundColor(chon ? .white : mau)
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(Capsule().fill(chon ? mau : mau.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    private func dong(_ d: DeThi) -> some View {
        NavigationLink {
            ChiTietDeView(de: d)
        } label: {
            HangDeThi(de: d, ngonNgu: ngonNgu, phu: phu(d))
                .overlay(alignment: .trailing) { huyHieu(d).padding(.trailing, 30) }
        }
        .buttonStyle(.plain)
    }

    private func phu(_ d: DeThi) -> String {
        var s = String(format: T("%d câu · %d phút"), d.soCau, d.phut)
        if let m = d.my, m.soLan > 0 {
            s += " · " + String(format: T("%d lần"), m.soLan)
            if let b = m.bestScore { s += " · " + T("cao nhất") + " " + DinhDangSo.gon(b) }
        }
        return s
    }

    @ViewBuilder private func huyHieu(_ d: DeThi) -> some View {
        if d.my?.inProgressId != nil {
            Label(T("Dở"), systemImage: "play.circle.fill").labelStyle(.iconOnly)
                .foregroundColor(AppColors.warning).font(.system(size: 18))
                .accessibilityLabel(T("Đang làm dở"))
        } else if d.my?.daDat == true {
            Image(systemName: "checkmark.seal.fill").foregroundColor(AppColors.success).font(.system(size: 17))
                .accessibilityLabel(T("Đã đạt"))
        } else if (d.my?.soLan ?? 0) > 0 {
            Image(systemName: "circle.dashed").foregroundColor(AppColors.textTertiary).font(.system(size: 16))
                .accessibilityLabel(T("Đã làm, chưa đạt"))
        }
    }

    private func tai() async {
        dangTai = true; defer { dangTai = false }
        do {
            var x: [DeThi] = try await APIClient.shared.request(.dsDeThiTheoMon(khoaHoc: khoaHoc))
            // Đường theo môn KHÔNG trả `course`/`semester`/`questionCount`
            // trong cùng hình dạng — gắn lại tên môn để huy hiệu và dòng phụ đúng.
            if let ma = maMon {
                x = x.map { $0.ganMon(ma: ma, ten: ten, slug: khoaHoc) }
            }
            ds = x
            loi = nil
        } catch { loi = error.localizedDescription }
    }
}

extension DeThi {
    /// Bản sao có `course` (đường `/exams/course/:slug` không trả trường này).
    func ganMon(ma: String, ten: String?, slug: String) -> DeThi {
        guard course == nil else { return self }
        return DeThi(id: id, courseId: courseId, kind: kind, peType: peType, title: title, code: code,
                     durationMinutes: durationMinutes, totalPoints: totalPoints, passMark: passMark,
                     questionCount: questionCount, course: KhoaHoc(title: ten, slug: slug, courseCode: ma),
                     semester: semester, source: source, description: description,
                     attachmentUrl: attachmentUrl, attachmentName: attachmentName, my: my)
    }
}
