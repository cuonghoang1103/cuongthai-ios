import SwiftUI

// ════════════════════════════════════════════════════════════════
// SƠ ĐỒ MÔN HỌC — bản iOS của `app/academy/so-do-mon-hoc/page.tsx`
//
// Timeline 9 kỳ của đúng ngành / ngành hẹp đã chọn. Mục đích: học xong ra
// trường làm gì, mỗi môn đóng góp gì cho nghề — để học SÂU, không chỉ qua môn.
// ════════════════════════════════════════════════════════════════

struct SoDoMonHocView: View {
    let hoSo: HoSoNganh
    let tatCaMon: [Course]

    @State private var monChon: MonSoDo?
    private let dm = DanhMucNganh.shared

    struct MonSoDo: Identifiable {
        let ma: String
        let ky: Int
        var id: String { ma }
    }

    /// Tầng của tháp: nền tảng ở ĐÁY (rộng nhất) → chuyên sâu ở ĐỈNH.
    private let thap: [(khoa: String, nhan: String, ky: [Int], mau: Color, rong: CGFloat)] = [
        ("advanced", "Chuyên sâu & Đồ án", [7, 8, 9], Color(hex: 0xA3E635), 0.48),
        ("ojt", "Thực tập (OJT)", [6], Color(hex: 0xF59E0B), 0.66),
        ("core", "Cốt lõi chuyên ngành", [3, 4, 5], Color(hex: 0x8B5CF6), 0.84),
        ("foundation", "Nền tảng", [1, 2], Color(hex: 0x22D3EE), 1.0),
    ]

    private var monTheoMa: [String: Course] {
        var m: [String: Course] = [:]
        for c in tatCaMon {
            let k = LocTheoNganh.maCua(c)
            if !k.isEmpty, m[k] == nil { m[k] = c }
        }
        return m
    }

    private var plan: [KyTrongKhung] {
        dm.khung(hoSo.faculty, hoSo.major, hoSo.combo).filter { $0.ky >= 1 && !$0.ma.isEmpty }
    }

    /// Project OJT (INT6xx) — CHỈ cho SE + Node.JS/C#.
    private var maProject: [String] {
        LocTheoNganh.hienProject(hoSo)
            ? monTheoMa.keys.filter { $0.range(of: #"^INT6\d\d$"#, options: .regularExpression) != nil }.sorted()
            : []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                tieuDe
                ngheNghiep
                if plan.isEmpty {
                    Text("Chưa có khung lộ trình cho lựa chọn này. Hãy chọn ngành hẹp cụ thể rồi quay lại.")
                        .font(.bodyMedium).foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity).padding(Spacing.lg)
                        .overlay(RoundedRectangle(cornerRadius: CornerRadius.large)
                            .strokeBorder(AppColors.border, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                } else {
                    thapMonHoc
                    dongThoiGian
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Sơ đồ môn học")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $monChon) { m in
            ChiTietMonSoDo(ma: m.ma, ky: m.ky, course: monTheoMa[m.ma.uppercased()])
                .presentationDetents([.medium, .large])
        }
    }

    private var tieuDe: some View {
        let parts = [dm.khoi(hoSo.faculty)?.nameVi,
                     dm.nganh(hoSo.faculty, hoSo.major)?.nameVi,
                     dm.nganhHep(hoSo.faculty, hoSo.major, hoSo.combo)?.nameVi].compactMap { $0 }
        return Text(parts.joined(separator: " · "))
            .font(.bodySmall)
            .foregroundColor(AppColors.textTertiary)
    }

    @ViewBuilder private var ngheNghiep: some View {
        if let n = dm.ngheNghiep(hoSo.faculty, hoSo.major, hoSo.combo) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label("Học xong ra trường bạn làm được gì?", systemImage: "briefcase.fill")
                    .font(.titleSmall).foregroundColor(AppColors.textPrimary)
                Text(n.summary).font(.bodyMedium).foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                LuoiChip(khoangCach: 6) {
                    ForEach(n.roles, id: \.self) { r in
                        Text(r).font(.caption)
                            .foregroundColor(AppColors.secondary)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(AppColors.secondary.opacity(0.12))
                            .overlay(Capsule().stroke(AppColors.secondary.opacity(0.35), lineWidth: 1))
                            .clipShape(Capsule())
                    }
                }
                Label("Chạm từng môn để xem môn đó cho bạn kỹ năng gì — học để dùng được, không chỉ để qua môn.",
                      systemImage: "lightbulb.fill")
                    .font(.caption).foregroundColor(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.md)
            .background(LinearGradient(colors: [AppColors.primary.opacity(0.14), AppColors.backgroundCard],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(RoundedRectangle(cornerRadius: CornerRadius.xl).stroke(AppColors.primary.opacity(0.3), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl))
        }
    }

    private var thapMonHoc: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("🔺 Tháp môn học").font(.titleSmall).foregroundColor(AppColors.textPrimary)
            Text("Nền tảng ở đáy (rộng nhất — học chắc, đỡ cả chương trình) → chuyên sâu & đồ án ở đỉnh.")
                .font(.caption).foregroundColor(AppColors.textTertiary)
            VStack(spacing: 8) {
                ForEach(Array(thap.enumerated()), id: \.offset) { i, tang in
                    let duyNhat = maCuaTang(tang.ky, coOJT: tang.khoa == "ojt")
                    VStack(spacing: 6) {
                        Text(tang.nhan.uppercased()).font(.system(size: 10, weight: .bold)).foregroundColor(tang.mau)
                        LuoiChip(khoangCach: 5, canGiua: true) {
                            if duyNhat.isEmpty { Text("—").font(.caption).foregroundColor(AppColors.textTertiary) }
                            ForEach(duyNhat, id: \.self) { m in
                                Button {
                                    Haptics.cham()
                                    monChon = MonSoDo(ma: m, ky: kyCua(m))
                                } label: {
                                    Text((laProject(m) ? "🚀 " : "") + m)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundColor(laProject(m) ? AppColors.success : AppColors.textPrimary)
                                        .padding(.horizontal, 7).padding(.vertical, 4)
                                        .background(AppColors.backgroundPrimary.opacity(0.6))
                                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(AppColors.border, lineWidth: 1))
                                        .clipShape(RoundedRectangle(cornerRadius: 7))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(LinearGradient(colors: [tang.mau.opacity(0.18), tang.mau.opacity(0.06)], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: CornerRadius.large).stroke(tang.mau.opacity(0.4), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                    // Thụt vào dần từ đáy lên đỉnh — hình tháp mà không cần đo bề rộng.
                    .padding(.horizontal, CGFloat(thap.count - 1 - i) * 16)
                }
            }
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl))
    }

    /// Mã môn của một tầng tháp, không trùng, giữ thứ tự khung. Tầng OJT kèm project.
    private func maCuaTang(_ ky: [Int], coOJT: Bool) -> [String] {
        var ma = plan.filter { ky.contains($0.ky) }.flatMap(\.ma)
        if coOJT { ma += maProject }
        return ma.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
    }

    private var dongThoiGian: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            ForEach(plan, id: \.ky) { k in
                let gd = GiaiDoan.cua(ky: k.ky)
                let ma = k.ma + (k.ky == 6 ? maProject : [])
                HStack(alignment: .top, spacing: Spacing.md) {
                    VStack(spacing: 0) {
                        Circle().fill(gd.mau).frame(width: 14, height: 14)
                        Rectangle().fill(gd.mau.opacity(0.35)).frame(width: 2)
                    }
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack(spacing: 8) {
                            Text("Kỳ \(k.ky)").font(.titleMedium).foregroundColor(AppColors.textPrimary)
                            Text(gd.nhan).font(.captionBold).foregroundColor(gd.mau)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(gd.mau.opacity(0.14)).clipShape(Capsule())
                        }
                        Text(gd.moTa).font(.caption).foregroundColor(AppColors.textTertiary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], spacing: 8) {
                            ForEach(ma, id: \.self) { m in theMon(m, ky: k.ky, mau: gd.mau) }
                        }
                    }
                }
            }
        }
    }

    private func theMon(_ m: String, ky: Int, mau: Color) -> some View {
        let c = monTheoMa[m.uppercased()]
        let pj = laProject(m)
        return Button {
            Haptics.cham()
            monChon = MonSoDo(ma: m, ky: ky)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text((pj ? "🚀 " : "") + m)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(pj ? AppColors.success : mau)
                    Spacer()
                    Text(pj ? "PROJECT" : c != nil ? "có bài" : "khung")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(pj || c != nil ? AppColors.success : AppColors.textTertiary)
                }
                Text(c?.title.songNguTheoMay ?? dm.tenMon(m) ?? m)
                    .font(.bodyMedium).foregroundColor(AppColors.textPrimary)
                    .lineLimit(2).multilineTextAlignment(.leading)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.backgroundCard)
            .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium).stroke((pj ? AppColors.success : mau).opacity(0.35), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
        .buttonStyle(.plain)
    }

    private func laProject(_ m: String) -> Bool { maProject.contains(m.uppercased()) }
    private func kyCua(_ m: String) -> Int {
        plan.first { $0.ma.contains(m) }?.ky ?? (laProject(m) ? 6 : 0)
    }
}

// MARK: - Chi tiết một môn

struct ChiTietMonSoDo: View {
    let ma: String
    let ky: Int
    let course: Course?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let gd = GiaiDoan.cua(ky: ky)
        let dm = DanhMucNganh.shared
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("\(ma) · \(gd.nhan)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(gd.mau)
                    Text(course?.title.songNguTheoMay ?? dm.tenMon(ma) ?? ma)
                        .font(.titleLarge).foregroundColor(AppColors.textPrimary)

                    VStack(alignment: .leading, spacing: 6) {
                        Label("Đóng góp cho nghề nghiệp", systemImage: "briefcase.fill")
                            .font(.titleSmall).foregroundColor(AppColors.primary)
                        Text(dm.goiYMon[ma.uppercased()] ?? gd.moTa)
                            .font(.bodyMedium).foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.primary.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: CornerRadius.large).stroke(AppColors.primary.opacity(0.25), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))

                    if let mo = course?.shortDescription, !mo.isEmpty {
                        Label("Môn học về gì", systemImage: "book.fill")
                            .font(.titleSmall).foregroundColor(AppColors.textPrimary)
                        Text(mo.songNguTheoMay).font(.bodyMedium).foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let course {
                        NavigationLink { CourseDetailView(slug: course.slug) } label: {
                            Label("Vào học môn này", systemImage: "graduationcap.fill")
                                .font(.buttonText).foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(AppColors.brandGradient)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("Môn này Academy chưa dựng bài — sẽ bổ sung.")
                            .font(.bodyMedium).foregroundColor(AppColors.textTertiary)
                            .frame(maxWidth: .infinity).padding(Spacing.md)
                            .overlay(RoundedRectangle(cornerRadius: CornerRadius.large)
                                .strokeBorder(AppColors.border, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                    }
                }
                .padding(Spacing.md)
            }
            .background(AppColors.backgroundPrimary)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
    }
}

// MARK: - Lưới chip tự xuống dòng

/// Xếp chip thành hàng, hết chỗ thì xuống dòng.
struct LuoiChip: Layout {
    var khoangCach: CGFloat = 6
    var canGiua = false

    init(khoangCach: CGFloat = 6, canGiua: Bool = false) {
        self.khoangCach = khoangCach
        self.canGiua = canGiua
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let hang = xep(rong: proposal.width ?? .infinity, subviews: subviews)
        let cao = hang.reduce(0) { $0 + $1.cao } + khoangCach * CGFloat(max(hang.count - 1, 0))
        let rong = hang.map(\.rong).max() ?? 0
        return CGSize(width: proposal.width ?? rong, height: cao)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for h in xep(rong: bounds.width, subviews: subviews) {
            var x = canGiua ? bounds.minX + (bounds.width - h.rong) / 2 : bounds.minX
            for i in h.chiSo {
                let s = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
                x += s.width + khoangCach
            }
            y += h.cao + khoangCach
        }
    }

    private struct Hang { var chiSo: [Int] = []; var rong: CGFloat = 0; var cao: CGFloat = 0 }

    private func xep(rong: CGFloat, subviews: Subviews) -> [Hang] {
        var kq: [Hang] = []
        var h = Hang()
        for (i, v) in subviews.enumerated() {
            let s = v.sizeThatFits(.unspecified)
            let them = h.chiSo.isEmpty ? s.width : h.rong + khoangCach + s.width
            if !h.chiSo.isEmpty && them > rong {
                kq.append(h)
                h = Hang()
            }
            h.rong = h.chiSo.isEmpty ? s.width : h.rong + khoangCach + s.width
            h.cao = max(h.cao, s.height)
            h.chiSo.append(i)
        }
        if !h.chiSo.isEmpty { kq.append(h) }
        return kq
    }
}
