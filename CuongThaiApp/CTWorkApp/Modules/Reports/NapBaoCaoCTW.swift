import SwiftUI

// MARK: - Nạp một route báo cáo rồi dựng nội dung — dùng cho mỗi tab/widget
//
// `khoa` đổi (sprint, khoảng ngày, kéo làm mới) ⇒ tải lại. Lỗi hiện ngay tại khung
// (không cả màn), để một báo cáo hỏng không che các báo cáo khác.

struct NapBaoCaoCTW<T: Decodable, C: View>: View {
    let khoa: String
    let diemCuoi: () -> APIEndpoint
    var soHang = 3
    @ViewBuilder let noiDung: (T) -> C
    @State private var tt: TaiCTW<T> = .dangTai
    @State private var daNap: String?

    var body: some View {
        Group {
            switch tt {
            case .dangTai:
                CTWKhungTai(soHang: soHang, coAvatar: false).padding(-Spacing.md)
            case .loi(let l):
                VStack(spacing: 8) {
                    CTWErrorBanner(text: l)
                    Button("Try again") { Task { await tai() } }.font(.system(size: 14, weight: .semibold))
                }
            case .xong(let v):
                noiDung(v)
            }
        }
        .task(id: khoa) {
            if daNap != khoa { await tai() }
        }
    }

    private func tai() async {
        if tt.giaTri == nil { tt = .dangTai }
        do {
            let v: T = try await APIClient.shared.request(diemCuoi())
            tt = .xong(v)
            daNap = khoa
        } catch is CancellationError {
        } catch {
            tt = .loi(CTW.loi(error))
        }
    }
}

/// Chip chọn khoảng ngày 14/30/90 dùng chung cho các tab báo cáo.
struct ChonKhoangNgayCTW: View {
    @Binding var ngay: Int
    var lua: [Int] = [14, 30, 90]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(lua, id: \.self) { n in
                let bat = n == ngay
                Button { CTWRung.chon(); ngay = n } label: {
                    Text("\(n)d").font(.system(size: 13, weight: .semibold)).fixedSize()
                        .foregroundColor(bat ? AppColors.onPrimary : AppColors.textPrimary)
                        .padding(.horizontal, 12).frame(minHeight: 32)
                        .background(Capsule().fill(bat ? AppColors.primary : AppColors.backgroundCard))
                        .overlay(Capsule().strokeBorder(bat ? Color.clear : AppColors.border, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Last \(n) days")
                .accessibilityAddTraits(bat ? .isSelected : [])
            }
        }
    }
}

/// Menu chọn sprint (burndown, people vs agents).
struct ChonSprintBaoCaoCTW: View {
    let ds: [CTWSprintDu]
    @Binding var chon: Int?
    var choPhepTatCa = false

    var body: some View {
        Menu {
            if choPhepTatCa { Button("Any sprint (date range)") { chon = nil } }
            ForEach(ds) { s in
                Button { chon = s.id } label: {
                    if s.id == chon { Label(nhan(s), systemImage: "checkmark") } else { Text(nhan(s)) }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "flag.checkered")
                Text(ds.first { $0.id == chon }.map(nhan) ?? (choPhepTatCa ? "Any sprint" : "Choose sprint"))
                    .lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(AppColors.textPrimary)
            .padding(.horizontal, 12).frame(minHeight: 32)
            .background(Capsule().fill(AppColors.backgroundCard))
            .overlay(Capsule().strokeBorder(AppColors.border, lineWidth: 0.5))
        }
        .accessibilityLabel("Sprint")
    }

    private func nhan(_ s: CTWSprintDu) -> String { s.ten + (s.dangChay ? " (active)" : "") }
}
