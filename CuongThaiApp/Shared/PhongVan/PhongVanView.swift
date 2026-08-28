import SwiftUI

@MainActor
final class PhongVanVM: ObservableObject {
    @Published var taxonomy: TaxonomyPV?
    @Published var lichSu: [MucLichSuPV] = []
    @Published var dangTai = true
    @Published var loi: String?
    @Published var dangTao = false

    func nap() async {
        dangTai = true; defer { dangTai = false }
        do {
            taxonomy = try await APIClient.shared.request(.pvTaxonomy)
            loi = nil
        } catch {
            // 401 ở đây nghĩa là CHƯA ĐĂNG NHẬP, không phải hỏng — nói rõ ra
            // thay vì ném mã lỗi thô vào mặt người dùng.
            loi = error.localizedDescription.contains("401")
                ? T("Đăng nhập để dùng phòng phỏng vấn.")
                : error.localizedDescription
        }
        lichSu = (try? await APIClient.shared.request(.pvLichSu)) ?? []
    }

    func tao(_ than: [String: Any]) async -> PhienPV? {
        dangTao = true; defer { dangTao = false }
        do { return try await APIClient.shared.request(.pvTaoPhien(than: than)) }
        catch { loi = error.localizedDescription; return nil }
    }
}

struct PhongVanView: View {
    @StateObject private var vm = PhongVanVM()
    @State private var linhVuc: LinhVucPV?
    @State private var viTri: ViTriPV?
    @State private var bac: BacPV = .junior
    @State private var soCau = 5
    @State private var kieu: KieuCongTy?
    @State private var tiengAnh = false
    @State private var phienMoi: PhienPV?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                NeoDauTrang()
                if vm.dangTai {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, Spacing.xl * 2)
                } else if let e = vm.loi, vm.taxonomy == nil {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "person.badge.key").font(.system(size: 40))
                            .foregroundColor(AppColors.textTertiary)
                        Text(e).font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.top, Spacing.xl * 2)
                } else if let t = vm.taxonomy {
                    khoiChon(t)
                    nutBatDau
                    if !vm.lichSu.isEmpty { khoiLichSu }
                }
                Color.clear.frame(height: 72)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(T("Phỏng vấn"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.nap() }
        .navigationDestination(item: $phienMoi) { p in
            PhongPhongVanView(phienBanDau: p)
        }
    }

    // MARK: Chọn cấu hình

    @ViewBuilder private func khoiChon(_ t: TaxonomyPV) -> some View {
        khoi(T("Lĩnh vực")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(t.cacLinhVuc) { d in
                        the(d.ten(tiengAnh), chon: linhVuc?.id == d.id) {
                            linhVuc = d
                            // Đổi lĩnh vực thì vị trí cũ không còn thuộc về nó
                            // nữa — bỏ chọn, đừng để một lựa chọn mồ côi.
                            viTri = nil
                        }
                    }
                }
            }
        }

        if let d = linhVuc ?? t.cacLinhVuc.first {
            khoi(T("Vị trí")) {
                VStack(spacing: Spacing.sm) {
                    ForEach(d.cacViTri) { v in
                        Button { viTri = v } label: {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: viTri?.id == v.id ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(viTri?.id == v.id ? AppColors.primary : AppColors.textTertiary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(v.ten(tiengAnh))
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(AppColors.textPrimary)
                                    // Số câu THẬT trong ngân hàng — chặn người
                                    // dùng chọn một vị trí rỗng rồi mới biết.
                                    Text("\(v.soCau) \(T("câu hỏi")) · \(v.cacChuDe.count) \(T("chủ đề"))")
                                        .font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 4)
                            .opacity(v.soCau == 0 ? 0.4 : 1)
                        }
                        .buttonStyle(.plain)
                        .disabled(v.soCau == 0)
                    }
                }
            }
        }

        khoi(T("Bậc")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(BacPV.allCases) { b in
                        the(b.nhan, chon: bac == b) { bac = b }
                    }
                }
            }
        }

        khoi(T("Số câu")) {
            HStack(spacing: Spacing.sm) {
                ForEach([3, 5, 8, 10, 15], id: \.self) { n in
                    the("\(n)", chon: soCau == n) { soCau = n }
                }
                Spacer(minLength: 0)
            }
        }

        if !t.cacKieu.isEmpty {
            khoi(T("Phong cách công ty")) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        the(T("Không chọn"), chon: kieu == nil) { kieu = nil }
                        ForEach(t.cacKieu) { c in
                            the(c.name, chon: kieu?.id == c.id) { kieu = c }
                        }
                    }
                }
            }
        }

        khoi(T("Ngôn ngữ câu hỏi")) {
            HStack(spacing: Spacing.sm) {
                the("Tiếng Việt", chon: !tiengAnh) { tiengAnh = false }
                the("English", chon: tiengAnh) { tiengAnh = true }
                Spacer(minLength: 0)
            }
        }
    }

    private var nutBatDau: some View {
        Button {
            guard let v = viTri else { return }
            Task {
                var than: [String: Any] = [
                    "trackId": v.id,
                    "level": bac.rawValue,
                    "numQuestions": min(soCau, max(1, v.soCau)),
                    "language": tiengAnh ? "EN" : "VI",
                ]
                if let k = kieu { than["companyProfileId"] = k.id }
                if let p = await vm.tao(than) { phienMoi = p }
            }
        } label: {
            HStack {
                if vm.dangTao { ProgressView().tint(.white) }
                Text(vm.dangTao ? T("Đang tạo đề…") : T("Bắt đầu phỏng vấn"))
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(viTri == nil ? AppColors.textTertiary.opacity(0.35) : AppColors.primary))
        }
        .buttonStyle(.plain)
        .disabled(viTri == nil || vm.dangTao)
    }

    private var khoiLichSu: some View {
        khoi("\(T("Phiên đã làm")) (\(vm.lichSu.count))") {
            VStack(spacing: Spacing.sm) {
                ForEach(vm.lichSu.prefix(10)) { m in
                    NavigationLink { BaoCaoPhongVanView(phienId: m.id, tua: m.track ?? "") } label: {
                        HStack(spacing: Spacing.sm) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(m.track ?? "—")
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary).lineLimit(1)
                                Text([m.level, m.status].compactMap { $0 }.joined(separator: " · "))
                                    .font(.system(size: 10.5)).foregroundColor(AppColors.textTertiary)
                            }
                            Spacer(minLength: 0)
                            if let d = m.overallScore {
                                Text(String(format: "%.0f", d))
                                    .font(.system(size: 15, weight: .heavy).monospacedDigit())
                                    .foregroundColor(diemMau(d))
                            }
                            if let g = m.letterGrade {
                                Text(g).font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Capsule().fill(diemMau(m.overallScore ?? 0)))
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                    .disabled(!m.xong)
                    .opacity(m.xong ? 1 : 0.5)
                }
            }
        }
    }

    // MARK: Mảnh dùng chung

    @ViewBuilder private func khoi<N: View>(_ ten: String, @ViewBuilder _ noi: () -> N) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(ten.uppercased())
                .font(.system(size: 10, weight: .bold)).tracking(0.6)
                .foregroundColor(AppColors.textTertiary)
            noi()
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    private func the(_ nhan: String, chon: Bool, lam: @escaping () -> Void) -> some View {
        Button(action: lam) {
            Text(nhan)
                .font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
                .foregroundColor(chon ? AppColors.onPrimary : AppColors.textSecondary)
                .padding(.horizontal, Spacing.sm + 4).padding(.vertical, 6)
                .background(Capsule().fill(chon ? AppColors.primary : AppColors.backgroundTertiary))
        }
        .buttonStyle(.plain)
    }
}

func diemMau(_ d: Double) -> Color {
    switch d {
    case 80...: return Color(hex: 0x22C55E)
    case 60..<80: return Color(hex: 0x84CC16)
    case 40..<60: return Color(hex: 0xF59E0B)
    default: return Color(hex: 0xEF4444)
    }
}

extension PhienPV: Hashable {
    static func == (a: PhienPV, b: PhienPV) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

// MARK: - Lối vào

struct PhongVanEntryCard: View {
    var body: some View {
        NavigationLink { PhongVanView() } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "person.crop.rectangle.stack.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 46, height: 46)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: 0xDB2777), Color(hex: 0xF472B6)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(T("Phỏng vấn"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text(T("Mô phỏng phỏng vấn · chấm điểm · báo cáo"))
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1).minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(Spacing.md)
            .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
        }
        .buttonStyle(.plain)
    }
}
