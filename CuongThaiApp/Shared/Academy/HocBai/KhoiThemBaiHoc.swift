import SwiftUI

// ════════════════════════════════════════════════════════════════
// CÁC KHỐI PHỤ CỦA MÀN HỌC: Code Lab · Sổ tay · Chứng chỉ · Lộ trình chương
//
// Cùng nguồn dữ liệu với web (LuyenTapCodeLab.tsx, LuuVaoSoTay.tsx,
// CourseRoadmapPanel) — mọi thứ đọc từ API lúc chạy, không đóng gói sẵn.
// ════════════════════════════════════════════════════════════════

// MARK: - Luyện tập trên Code Lab

/// Thẻ "Luyện tập trên Code Lab" ngay dưới video — giọng đọc cuối video chỉ vào đây.
///
/// Web hiện thẻ khi khoá nằm trong chương trình luyện tập (`coBoLuyen`) hoặc bài
/// thật sự có bộ. Bản chép `KHOA_CO_BO_LUYEN` dùng khi API lỗi, để thẻ không
/// biến mất đúng lúc video vừa nói "bấm link ngay dưới".
struct TheLuyenCodeLab: View {
    let courseSlug: String
    let lessonSlug: String?

    @State private var bo: BoLuyenCodeLab?
    @State private var daTai = false
    @State private var moHet = false

    static let khoaCoBo: Set<String> = ["web-foundations", "front-end-web-development-with-react", "fer202"]

    private var hien: Bool {
        guard lessonSlug != nil else { return false }
        if !(bo?.dsBai.isEmpty ?? true) || bo?.coBoLuyen == true { return true }
        return Self.khoaCoBo.contains(courseSlug) && daTai
    }

    var body: some View {
        Group {
            if hien {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: 6) {
                        Image(systemName: "dumbbell.fill").foregroundColor(AppColors.success)
                        Text(T("Luyện tập trên Code Lab")).font(.titleSmall).foregroundColor(AppColors.textPrimary)
                        Spacer(minLength: 0)
                        if let s = bo?.solvedCount, let t = bo?.total, t > 0 {
                            Text(String(format: T("%d/%d đã giải"), s, t))
                                .font(.caption).foregroundColor(AppColors.success)
                        }
                    }
                    if let bo, !bo.dsBai.isEmpty {
                        Text(moTa(bo)).font(.caption).foregroundColor(AppColors.textSecondary)
                        let ds = moHet ? bo.dsBai : Array(bo.dsBai.prefix(4))
                        VStack(spacing: 0) {
                            ForEach(ds, id: \.slug) { b in hangBai(b) }
                        }
                        if bo.dsBai.count > 4 {
                            Button(moHet ? T("Thu gọn") : String(format: T("Xem cả %d bài"), bo.dsBai.count)) {
                                withAnimation(.snappy(duration: 0.2)) { moHet.toggle() }
                            }
                            .font(.buttonSmall).foregroundColor(AppColors.success)
                        }
                    } else {
                        Text(T("Bài luyện cho bài này đang soạn. Luyện tạm các bài gợi ý cùng chủ đề:"))
                            .font(.caption).foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach((bo?.goiY?.items ?? []).prefix(3), id: \.slug) { b in hangBai(b) }
                    }
                }
                .padding(Spacing.md)
                .background(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .fill(AppColors.success.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(AppColors.success.opacity(0.35), lineWidth: 1))
            }
        }
        .task(id: lessonSlug) { await tai() }
    }

    private func moTa(_ b: BoLuyenCodeLab) -> String {
        var p = [String(format: T("%d bài · Dễ → Khó"), b.total ?? b.dsBai.count)]
        if let m = b.estimatedMinutes, m > 0 { p.append(String(format: T("≈%d phút"), m)) }
        if b.scope == "chapter" { p.append(T("cả chương")) }
        return p.joined(separator: " · ")
    }

    private func hangBai(_ b: BaiLuyenCodeLab) -> some View {
        NavigationLink {
            NapBaiTapView(slug: b.slug, ten: b.title)
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: b.solved == true ? "checkmark.circle.fill" : "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 13)).foregroundColor(b.solved == true ? AppColors.success : AppColors.textTertiary)
                    .frame(width: 20)
                Text(b.title).font(.bodyMedium).foregroundColor(AppColors.textPrimary).lineLimit(1)
                Spacer(minLength: 0)
                Text(b.nhanDoKho).font(.caption).foregroundColor(mauDoKho(b.difficulty))
                Image(systemName: "chevron.right").font(.caption2).foregroundColor(AppColors.textTertiary)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func mauDoKho(_ d: String?) -> Color {
        switch d {
        case "EASY": return AppColors.success
        case "MEDIUM": return AppColors.warning
        case "HARD": return AppColors.error
        default: return AppColors.primary
        }
    }

    private func tai() async {
        bo = nil; daTai = false; moHet = false
        guard let lessonSlug, !lessonSlug.isEmpty else { return }
        bo = try? await APIClient.shared.request(.hocBai(.boLuyenCodeLab(courseSlug: courseSlug, lessonSlug: lessonSlug)))
        daTai = true
    }
}

// MARK: - Sổ tay của bài

@MainActor
final class SoTayBaiVM: ObservableObject {
    @Published var doan: [DoanSoTay] = []
    @Published var dangLuu = false
    @Published var thongBao: String?
    private(set) var courseSlug = ""
    private(set) var lessonId = 0

    func tai(courseSlug: String, lessonId: Int) async {
        self.courseSlug = courseSlug
        self.lessonId = lessonId
        doan = []
        guard !courseSlug.isEmpty else { return }
        if let g: GoiDoanSoTay = try? await APIClient.shared.request(.hocBai(.doanSoTayCuaBai(courseSlug: courseSlug, lessonId: lessonId))) {
            doan = g.doan ?? []
        }
    }

    func luu(_ chu: String, laCode: Bool) async -> Bool {
        let t = chu.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !courseSlug.isEmpty, !dangLuu else { return false }
        dangLuu = true
        defer { dangLuu = false }
        do {
            let r: KetQuaLuuSoTay = try await APIClient.shared.request(.hocBai(.luuDoanSoTay(
                courseSlug: courseSlug, lessonId: lessonId, text: t, laCode: laCode)))
            Haptics.xong()
            thongBao = String(format: T("Đã lưu vào %@"), r.subjectName ?? T("Sổ tay"))
            doan.append(DoanSoTay(text: t, laCode: laCode))
            return true
        } catch {
            Haptics.hong()
            thongBao = error.localizedDescription
            return false
        }
    }
}

/// Khối "Sổ tay của bài": các đoạn đã lưu + cách lưu.
struct KhoiSoTayBai: View {
    @ObservedObject var vm: SoTayBaiVM
    @State private var moRong = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "note.text").foregroundColor(AppColors.primary)
                Text(T("Sổ tay của bài")).font(.titleSmall).foregroundColor(AppColors.textPrimary)
                if !vm.doan.isEmpty {
                    Text("\(vm.doan.count)").font(.system(size: 11, weight: .bold)).foregroundColor(AppColors.primary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(AppColors.primary.opacity(0.14)))
                }
                Spacer(minLength: 0)
                if vm.doan.count > 2 {
                    Button(moRong ? T("Thu gọn") : T("Xem hết")) { withAnimation(.snappy(duration: 0.2)) { moRong.toggle() } }
                        .font(.buttonSmall).foregroundColor(AppColors.primary)
                }
            }
            if vm.doan.isEmpty {
                Text(T("Bôi đen một đoạn trong bài (chạm giữ rồi kéo) ⇒ bấm “Lưu vào sổ tay”. Đoạn lưu vào môn tương ứng trong Ghi chú, xem lại trên web và app."))
                    .font(.caption).foregroundColor(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array((moRong ? vm.doan : Array(vm.doan.suffix(2))).enumerated()), id: \.offset) { _, d in
                    Text(d.text)
                        .font(d.laCode == true ? .system(size: 12.5, design: .monospaced) : .bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(moRong ? nil : 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.small).fill(AppColors.backgroundSecondary))
                        .overlay(alignment: .leading) {
                            Rectangle().fill(AppColors.primary.opacity(0.6)).frame(width: 3)
                        }
                }
            }
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous).fill(AppColors.backgroundCard))
    }
}

/// Thanh nổi khi đang bôi đen chữ trong bài: lưu vào sổ tay / hỏi CuongMini.
struct ThanhChonChu: View {
    let chu: String
    let dangLuu: Bool
    let khiLuu: () -> Void
    let khiHoi: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text("“\(chu.prefix(60))\(chu.count > 60 ? "…" : "")”")
                .font(.caption).foregroundColor(AppColors.textSecondary).lineLimit(1)
            Spacer(minLength: 0)
            Button { khiHoi() } label: {
                Label(T("Hỏi"), systemImage: "sparkles").font(.buttonSmall).foregroundColor(AppColors.primary)
            }
            .buttonStyle(.plain)
            Button { khiLuu() } label: {
                HStack(spacing: 5) {
                    if dangLuu { ProgressView().controlSize(.small).tint(AppColors.onPrimary) }
                    else { Image(systemName: "square.and.arrow.down") }
                    Text(T("Lưu vào sổ tay"))
                }
                .font(.buttonSmall).foregroundColor(AppColors.onPrimary)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Capsule().fill(AppColors.primary))
            }
            .buttonStyle(.plain)
            .disabled(dangLuu)
        }
        .padding(.horizontal, Spacing.md).padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}

// MARK: - Chứng chỉ

/// Hiện khi đã xong 100% và máy chủ đã cấp chứng chỉ.
struct TheChungChi: View {
    let chungChi: ChungChiKhoa
    let tenMon: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "rosette")
                .font(.system(size: 28)).foregroundColor(AppColors.onPrimary)
                .frame(width: 52, height: 52)
                .background(Circle().fill(AppColors.brandGradient))
            VStack(alignment: .leading, spacing: 3) {
                Text(T("Bạn đã hoàn thành môn học!")).font(.titleSmall).foregroundColor(AppColors.textPrimary)
                Text(tenMon).font(.caption).foregroundColor(AppColors.textSecondary).lineLimit(2)
                if let so = chungChi.certificateNumber {
                    Text(T("Số chứng chỉ:") + " " + so).font(.system(size: 11, design: .monospaced))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            Spacer(minLength: 0)
            if let so = chungChi.certificateNumber, let u = URL(string: "https://cuongthai.com/certificates/\(so)") {
                ShareLink(item: u) {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                }
                .accessibilityLabel(T("Chia sẻ chứng chỉ"))
            }
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous).fill(AppColors.backgroundCard))
        .overlay(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
            .stroke(AppColors.primary.opacity(0.35), lineWidth: 1))
    }
}

// MARK: - Vòng tiến độ

struct VongTienDo: View {
    let tiLe: Double
    var co: CGFloat = 56
    var net: CGFloat = 6

    var body: some View {
        ZStack {
            Circle().stroke(AppColors.backgroundTertiary, lineWidth: net)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, tiLe)))
                .stroke(AppColors.brandGradient, style: StrokeStyle(lineWidth: net, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((tiLe * 100).rounded()))%")
                .font(.system(size: co * 0.26, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textPrimary)
                .minimumScaleFactor(0.6)
        }
        .frame(width: co, height: co)
        .accessibilityElement()
        .accessibilityLabel(String(format: T("Đã học %d phần trăm"), Int((tiLe * 100).rounded())))
    }
}
