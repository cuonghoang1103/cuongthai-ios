import SwiftUI
#if canImport(Kingfisher)
import Kingfisher
#endif

// MARK: - Academy FPT
//
// Chương trình đại học: 9 học kỳ, 50 môn. Để RIÊNG khỏi 5 khoá tự biên soạn
// vì hai thứ khác hẳn nhau về mục đích — một bên là lộ trình bắt buộc theo kỳ,
// một bên là khoá chọn học tuỳ ý. Trộn chung thì "Mathematics for Engineering"
// nằm cạnh "PostgreSQL" và người dùng không hiểu mình đang xem cái gì.
//
// Backend cũng tách sẵn: `/courses` chỉ trả `academyType: "GENERAL"`, môn FPT
// chỉ lấy được qua `/courses/semester/:id`.

@MainActor
final class AcademyViewModel: ObservableObject {
    @Published var hocKy: [Semester] = []
    @Published var monTheoKy: [Int: [Course]] = [:]
    @Published var dangTai = false
    @Published var dangTaiKy: Set<Int> = []
    @Published var loi: String?

    func taiHocKy() async {
        guard hocKy.isEmpty else { return }
        dangTai = true
        defer { dangTai = false }
        do {
            let ds: (items: [Semester], nextCursor: Int?, hasMore: Bool) =
                try await APIClient.shared.requestList(.getSemesters)
            // Máy chủ đã sắp theo `ordinal`, nhưng sắp lại cho chắc: id KHÔNG
            // theo thứ tự kỳ (Kỳ 1 có id=9, Kỳ 3 có id=3).
            hocKy = ds.items.sorted { ($0.ordinal ?? 0) < ($1.ordinal ?? 0) }
        } catch {
            loi = error.localizedDescription
        }
    }

    /// Nạp môn của một kỳ, chỉ khi người dùng mở kỳ đó ra. Nạp sẵn cả 9 kỳ là
    /// 9 lượt gọi mạng cho thứ phần lớn người dùng không xem tới.
    func taiMon(_ kyId: Int) async {
        guard monTheoKy[kyId] == nil, !dangTaiKy.contains(kyId) else { return }
        dangTaiKy.insert(kyId)
        defer { dangTaiKy.remove(kyId) }
        do {
            let ds: (items: [Course], nextCursor: Int?, hasMore: Bool) =
                try await APIClient.shared.requestList(.getCoursesBySemester(semesterId: kyId))
            monTheoKy[kyId] = ds.items
        } catch {
            loi = error.localizedDescription
        }
    }
}

struct AcademyView: View {
    @StateObject private var vm = AcademyViewModel()
    @State private var kyMoRong: Set<Int> = []

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.md) {
                gioiThieu

                if vm.dangTai && vm.hocKy.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, Spacing.xl)
                } else if let loi = vm.loi, vm.hocKy.isEmpty {
                    ErrorStateView(message: loi) { Task { await vm.taiHocKy() } }
                } else {
                    ForEach(vm.hocKy) { ky in
                        theHocKy(ky)
                    }
                }
            }
            .padding(.vertical, Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Academy FPT")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.taiHocKy() }
    }

    private var gioiThieu: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Chương trình đại học FPT")
                .font(.titleMedium)
                .foregroundColor(AppColors.textPrimary)
            Text("\(vm.hocKy.count) học kỳ · môn học theo đúng lộ trình của trường. Chạm một kỳ để xem các môn.")
                .font(.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.xs)
    }

    private func theHocKy(_ ky: Semester) -> some View {
        let mo = kyMoRong.contains(ky.id)
        let mon = vm.monTheoKy[ky.id]

        return VStack(spacing: 0) {
            Button {
                Haptics.cham()
                withAnimation(.snappy(duration: 0.22)) {
                    if mo { kyMoRong.remove(ky.id) } else { kyMoRong.insert(ky.id) }
                }
                Task { await vm.taiMon(ky.id) }
            } label: {
                HStack(spacing: Spacing.md) {
                    // Số kỳ trong ô vuông bo góc — nhìn là biết thứ tự ngay.
                    Text(ky.soKy.map(String.init) ?? "—")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.primary)
                        .frame(width: 38, height: 38)
                        .background(AppColors.primary.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(ky.name)
                            .font(.titleSmall)
                            .foregroundColor(AppColors.textPrimary)
                        if let n = mon?.count {
                            Text("\(n) môn")
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    Spacer()

                    if vm.dangTaiKy.contains(ky.id) {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: mo ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(Spacing.md)
                .background(AppColors.backgroundCard)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if mo, let mon {
                if mon.isEmpty {
                    Text("Kỳ này chưa có môn nào.")
                        .font(.bodySmall)
                        .foregroundColor(AppColors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.md)
                        .background(AppColors.backgroundSecondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(mon) { m in
                            NavigationLink {
                                CourseDetailView(slug: m.slug)
                            } label: {
                                hangMon(m)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .padding(.horizontal, Spacing.md)
    }

    private func hangMon(_ m: Course) -> some View {
        HStack(spacing: Spacing.md) {
            // Mã môn thay cho ảnh bìa: ngắn, nhận ra ngay, và phần lớn môn
            // Academy chưa có ảnh riêng nên hiện ảnh mặc định chỉ tổ rối mắt.
            Text(m.courseCode ?? "—")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(AppColors.secondary)
                .frame(width: 62, height: 30)
                .background(AppColors.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(m.title)
                    .font(.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                HStack(spacing: Spacing.sm) {
                    if let n = m.totalLessons, n > 0 {
                        Text("\(n) bài")
                    } else {
                        Text("chưa có bài")
                    }
                    if m.isEnrolled == true {
                        Text("· Đã ghi danh").foregroundColor(AppColors.success)
                    }
                }
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundSecondary)
        .contentShape(Rectangle())
    }
}

// MARK: - Lối vào từ tab Học

struct AcademyEntryCard: View {
    var body: some View {
        NavigationLink {
            AcademyView()
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 22))
                    .foregroundColor(AppColors.onPrimary)
                    .frame(width: 46, height: 46)
                    .background(AppColors.brandGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Academy FPT")
                        .font(.titleSmall)
                        .foregroundColor(AppColors.textPrimary)
                    Text("Chương trình đại học theo học kỳ")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(Spacing.md)
            .background(AppColors.backgroundCard)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .stroke(AppColors.primary.opacity(0.25), lineWidth: 1),
            )
            .cornerRadius(CornerRadius.medium)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
