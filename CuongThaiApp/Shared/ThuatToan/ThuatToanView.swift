import SwiftUI

struct ThuatToanView: View {
    @State private var tim = ""
    @State private var nhom: String?

    private var ds: [ThuatToan] {
        let k = tim.trimmingCharacters(in: .whitespaces).chuanHoaTim
        return KhoThuatToan.tatCa.filter { t in
            (nhom == nil || t.nhom == nhom)
            && (k.isEmpty || t.ten.chuanHoaTim.contains(k) || t.moTa.chuanHoaTim.contains(k))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass").foregroundColor(AppColors.textTertiary)
                TextField(T("Tìm thuật toán…"), text: $tim)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                if !tim.isEmpty {
                    Button { tim = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textTertiary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(Spacing.sm + 2)
            .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.backgroundCard))
            .padding(.horizontal, Spacing.md).padding(.top, Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    the(T("Tất cả"), chon: nhom == nil) { nhom = nil }
                    ForEach(KhoThuatToan.nhom, id: \.self) { n in
                        the(n, chon: nhom == n) { nhom = nhom == n ? nil : n }
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
            .padding(.vertical, Spacing.sm)

            ScrollViewReader { cuon in
            ScrollView {
                LazyVStack(spacing: Spacing.sm) {
                    NeoDauTrang()
                    ForEach(ds) { t in
                        NavigationLink { ChayThuatToanView(tt: t) } label: { hang(t) }
                            .buttonStyle(.plain)
                    }
                    if ds.isEmpty {
                        Text(T("Không có thuật toán nào khớp."))
                            .font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                            .padding(.top, Spacing.xl * 2)
                    }
                    Color.clear.frame(height: 72)
                }
                .padding(.horizontal, Spacing.md)
            }
            .onChange(of: nhom) { _, _ in cuon.veDauTrang() }
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("\(T("Thuật toán")) (\(KhoThuatToan.tatCa.count))")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func the(_ n: String, chon: Bool, lam: @escaping () -> Void) -> some View {
        Button(action: lam) {
            Text(n).font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
                .foregroundColor(chon ? AppColors.onPrimary : AppColors.textSecondary)
                .padding(.horizontal, Spacing.sm + 4).padding(.vertical, 6)
                .background(Capsule().fill(chon ? AppColors.primary : AppColors.backgroundTertiary))
        }
        .buttonStyle(.plain)
    }

    private func hang(_ t: ThuatToan) -> some View {
        HStack(spacing: Spacing.sm + 2) {
            Image(systemName: bieuTuong(t.nhom))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(mauNhom(t.nhom))
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(mauNhom(t.nhom).opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text(t.nhom.uppercased())
                    .font(.system(size: 9, weight: .bold)).tracking(0.5)
                    .foregroundColor(AppColors.textTertiary)
                Text(t.ten)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Text(t.moTa)
                    .font(.system(size: 11.5))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2).multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Image(systemName: "play.circle.fill")
                .font(.system(size: 18)).foregroundColor(mauNhom(t.nhom).opacity(0.8))
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }
}

func mauNhom(_ n: String) -> Color {
    switch n {
    case "Sorting": return Color(hex: 0x3B82F6)
    case "Searching": return Color(hex: 0x06B6D4)
    case "Graph": return Color(hex: 0xA855F7)
    case "Pathfinding": return Color(hex: 0xEC4899)
    case "Dynamic Programming": return Color(hex: 0xF59E0B)
    case "Trees": return Color(hex: 0x22C55E)
    case "Backtracking": return Color(hex: 0xEF4444)
    case "String": return Color(hex: 0x14B8A6)
    case "Math": return Color(hex: 0x8B5CF6)
    case "Greedy": return Color(hex: 0x84CC16)
    case "Bit Manipulation": return Color(hex: 0xF97316)
    case "Two Pointers": return Color(hex: 0x0EA5E9)
    default: return Color(hex: 0x64748B)
    }
}

func bieuTuong(_ n: String) -> String {
    switch n {
    case "Sorting": return "arrow.up.arrow.down"
    case "Searching": return "magnifyingglass"
    case "Graph": return "point.3.connected.trianglepath.dotted"
    case "Pathfinding": return "map"
    case "Dynamic Programming": return "square.grid.3x3"
    case "Trees": return "arrow.triangle.branch"
    case "Backtracking": return "arrow.uturn.backward"
    case "String": return "textformat"
    case "Math": return "function"
    case "Greedy": return "hare"
    case "Bit Manipulation": return "01.square"
    case "Two Pointers": return "arrow.left.and.right"
    default: return "chevron.left.forwardslash.chevron.right"
    }
}

// MARK: - Lối vào

struct ThuatToanEntryCard: View {
    var body: some View {
        NavigationLink { ThuatToanView() } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 21))
                    .foregroundColor(.white)
                    .frame(width: 46, height: 46)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: 0x0891B2), Color(hex: 0x22D3EE)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(T("Thuật toán"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("80 \(T("thuật toán")) · \(T("chạy từng bước")) · \(T("sửa mã được"))")
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
