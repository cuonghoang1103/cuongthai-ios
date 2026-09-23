import SwiftUI
#if canImport(Kingfisher)
import Kingfisher
#endif

// MARK: - Academy FPT
//
// Chương trình đại học theo học kỳ. Để RIÊNG khỏi các khoá tự biên soạn vì hai
// thứ khác hẳn nhau về mục đích — một bên là lộ trình bắt buộc theo kỳ, một bên
// là khoá chọn học tuỳ ý.
//
// Backend cũng tách sẵn: `/courses` chỉ trả `academyType: "GENERAL"`, môn FPT
// chỉ lấy được qua `/courses/semester/:id`.
//
// Từ 23/09/2026 màn này đi theo luồng của web: lần đầu vào thì hỏi ngành
// (`ChonNganhView`), chọn tới ngành hẹp thì CHỈ hiện môn của ngành đó, xếp theo
// kỳ trong khung ngành (`LocTheoNganh.xepTheoKhung`) — không đổ hết môn của mọi
// ngành ra nữa.

@MainActor
final class AcademyViewModel: ObservableObject {
    @Published var hocKy: [Semester] = []
    @Published var monTheoKy: [Int: [Course]] = [:]
    @Published var dangTai = false
    @Published var loi: String?

    /// Mọi môn Academy, không trùng — để lọc theo khung ngành và tìm theo mã.
    var tatCaMon: [Course] {
        var daCo = Set<Int>()
        var kq: [Course] = []
        for k in hocKy { for c in monTheoKy[k.id] ?? [] where daCo.insert(c.id).inserted { kq.append(c) } }
        return kq
    }

    /// Nạp CẢ 9 kỳ song song.
    ///
    /// ⚠️ Trước đây chỉ nạp kỳ nào người dùng mở ra. Giờ không được nữa: lọc
    /// theo ngành xếp môn theo khung NGÀNH, mà một môn trong khung có thể nằm ở
    /// bất kỳ kỳ nào của bảng `semesters` (SSG105 là Kỳ 5 của SE nhưng DB ghi
    /// Kỳ 4). Thiếu một kỳ là thiếu môn, và thiếu kiểu đó không báo lỗi.
    func taiHet(ep: Bool = false) async {
        if !ep, !hocKy.isEmpty, monTheoKy.count == hocKy.count { return }
        dangTai = true
        loi = nil
        defer { dangTai = false }
        do {
            let ds: (items: [Semester], nextCursor: Int?, hasMore: Bool) =
                try await APIClient.shared.requestList(.getSemesters)
            // id KHÔNG theo thứ tự kỳ (Kỳ 1 có id=9, Kỳ 3 có id=3) — sắp theo ordinal.
            let ky = ds.items.sorted { ($0.ordinal ?? 0) < ($1.ordinal ?? 0) }
            let mon = try await withThrowingTaskGroup(of: (Int, [Course]).self) { nhom in
                for k in ky {
                    nhom.addTask {
                        let r: (items: [Course], nextCursor: Int?, hasMore: Bool) =
                            try await APIClient.shared.requestList(.getCoursesBySemester(semesterId: k.id))
                        return (k.id, r.items)
                    }
                }
                var m: [Int: [Course]] = [:]
                for try await (id, ds) in nhom { m[id] = ds }
                return m
            }
            hocKy = ky
            monTheoKy = mon
        } catch {
            loi = error.localizedDescription
        }
    }
}

struct AcademyView: View {
    @StateObject private var vm = AcademyViewModel()
    @ObservedObject private var hoSoStore = HoSoAcademy.shared
    @Environment(\.dismiss) private var dismiss

    @State private var moRong: Set<Int> = []
    @State private var timKiem = ""
    @State private var bangMo: BangAcademy?
    @State private var dichDen: DichDenAcademy?
    /// Đóng màn hỏi mà không trả lời thì KHÔNG hỏi lại trong lần vào này.
    @State private var daHoi = false

    enum BangAcademy: Identifiable {
        case chonNganh(BuocChonNganh, khoi: String?, nganh: String?)
        var id: String {
            switch self { case let .chonNganh(b, k, n): "\(b)-\(k ?? "")-\(n ?? "")" }
        }
    }

    enum DichDenAcademy: Hashable {
        case tuVan(khoi: String, nganh: String?)
        case soDo
    }

    private var hoSo: HoSoNganh { hoSoStore.hoSo }
    private var dm: DanhMucNganh { .shared }
    private var coLoc: Bool { LocTheoNganh.coLoc(hoSo) }

    private var nhomKy: [NhomKy] {
        if let theoKhung = LocTheoNganh.xepTheoKhung(vm.tatCaMon, hoSo: hoSo) {
            return theoKhung.filter { !$0.mon.isEmpty }
        }
        return vm.hocKy.map { k in
            NhomKy(id: k.id, ten: k.name, moTa: k.description,
                   mon: (vm.monTheoKy[k.id] ?? []).map {
                       MonHien(course: $0, laMaCu: false, laProject: LocTheoNganh.laProject($0))
                   })
        }
    }

    private var soMonHien: Int { nhomKy.reduce(0) { $0 + $1.mon.count } }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.md) {
                gioiThieu
                if hoSo.isStudent == true, dm.nganh(hoSo.faculty, hoSo.major) != nil {
                    theNganhCuaBan
                } else {
                    moiChonNganh
                }

                if !timKiem.trimmingCharacters(in: .whitespaces).isEmpty {
                    ketQuaTim
                } else if vm.dangTai && vm.hocKy.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, Spacing.xl)
                } else if let loi = vm.loi, vm.hocKy.isEmpty {
                    ErrorStateView(message: loi) { Task { await vm.taiHet(ep: true) } }
                } else if coLoc && soMonHien == 0 {
                    chuaCoMon
                } else {
                    ForEach(nhomKy) { theHocKy($0) }
                }
            }
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Academy")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $timKiem, prompt: "Tìm theo mã môn (CEA203, PRO192…)")
        .refreshable { await vm.taiHet(ep: true) }
        .task {
            await vm.taiHet()
            await hoSoStore.keoTuMayChu()
            if hoSoStore.canHoi && !daHoi {
                daHoi = true
                bangMo = .chonNganh(.hoi, khoi: nil, nganh: nil)
            }
        }
        .onChange(of: nhomKy.map(\.id), initial: true) { _, ids in
            // Tự mở hai kỳ đầu mỗi khi bộ kỳ đổi (vừa tải xong, vừa đổi ngành).
            if moRong.isDisjoint(with: ids) { moRong = Set(ids.prefix(2)) }
        }
        .sheet(item: $bangMo) { bang in
            switch bang {
            case let .chonNganh(buoc, khoi, nganh):
                ChonNganhView(
                    batDau: buoc, khoiSan: khoi, nganhSan: nganh,
                    khiKhongPhaiSV: { dismiss() },
                    khiCanTuVan: { k, n in dichDen = .tuVan(khoi: k, nganh: n) },
                    khiXemSoDo: { dichDen = .soDo }
                )
            }
        }
        .navigationDestination(item: $dichDen) { dich in
            switch dich {
            case let .tuVan(khoi, nganh):
                TuVanNganhView(khoiId: khoi, nganhId: nganh) {
                    // "Quay lại chọn ngành hẹp" — mở thẳng bước ngành hẹp với khối/ngành đã biết.
                    dichDen = nil
                    Task {
                        try? await Task.sleep(for: .milliseconds(450))
                        bangMo = .chonNganh(.nganhHep, khoi: khoi, nganh: nganh)
                    }
                }
            case .soDo:
                SoDoMonHocView(hoSo: hoSo, tatCaMon: vm.tatCaMon)
            }
        }
    }

    // MARK: Đầu trang

    private var gioiThieu: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Lộ trình học theo 9 kỳ FPT")
                .font(.titleLarge)
                .foregroundColor(AppColors.textPrimary)
            Text(coLoc
                 ? "\(soMonHien) môn của ngành bạn · xếp theo đúng khung chương trình."
                 : "\(vm.hocKy.count) học kỳ · \(vm.tatCaMon.count) môn. Chạm một kỳ để xem các môn.")
                .font(.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Spacing.md)
    }

    private var theNganhCuaBan: some View {
        let nganh = dm.nganh(hoSo.faculty, hoSo.major)!
        let hep = dm.nganhHep(hoSo.faculty, hoSo.major, hoSo.combo)
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            dongNganh(nganh, hep)
            if coLoc {
                Label("Đang lọc \(soMonHien) môn của ngành", systemImage: "line.3.horizontal.decrease.circle")
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(AppColors.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }
            // Ngành có ngành hẹp mà chưa chọn → gợi ý vào Phòng tư vấn.
            if hep == nil, !nganh.combos.isEmpty {
                Button {
                    Haptics.cham()
                    dichDen = .tuVan(khoi: hoSo.faculty ?? "", nganh: nganh.id)
                } label: {
                    Label("Chưa chọn ngành hẹp? Hỏi Phòng tư vấn", systemImage: "sparkles")
                        .font(.buttonSmall)
                        .foregroundColor(AppColors.primary)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: Spacing.sm) {
                nutVien("🗺️ Sơ đồ môn học", mau: AppColors.secondary) { dichDen = .soDo }
                nutVien("Đổi ngành", he: "arrow.triangle.2.circlepath", mau: AppColors.textPrimary) {
                    bangMo = .chonNganh(.khoi, khoi: nil, nganh: nil)
                }
            }
            nguonKhung(nganh)
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .overlay(RoundedRectangle(cornerRadius: CornerRadius.large).stroke(AppColors.primary.opacity(0.3), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .padding(.horizontal, Spacing.md)
    }

    private func dongNganh(_ nganh: Nganh, _ hep: NganhHep?) -> some View {
        let tenKhoi = dm.khoi(hoSo.faculty)?.nameVi.uppercased()
        let nhan: String = tenKhoi.map { "NGÀNH CỦA BẠN · \($0)" } ?? "NGÀNH CỦA BẠN"
        let ten: String = hep?.nameVi ?? nganh.nameVi
        let phu: String = hep.map { "\(nganh.nameVi) · \($0.name)" } ?? nganh.name
        let icon: String = hep?.icon ?? nganh.icon
        return HStack(alignment: .top, spacing: Spacing.md) {
            Text(icon).font(.system(size: 32))
            VStack(alignment: .leading, spacing: 2) {
                Text(nhan).font(.captionBold).foregroundColor(AppColors.textTertiary)
                Text(ten).font(.titleMedium).foregroundColor(AppColors.textPrimary)
                Text(phu).font(.caption).foregroundColor(AppColors.textTertiary)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private func nguonKhung(_ nganh: Nganh) -> some View {
        if let note = nganh.comboNote {
            Text(note).font(.caption).foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        if let ma = nganh.curriculumCode {
            let tin: String = nganh.credits.map { " · \($0) tín chỉ" } ?? ""
            let cur: String = nganh.curriculumId.map { " (curid \($0))" } ?? ""
            Text("Khung \(ma)\(tin) · nguồn: FLM\(cur)")
                .font(.caption).foregroundColor(AppColors.textTertiary)
        }
    }

    /// Chưa trả lời, hoặc đã nói "không phải SV FPTU": một lối nhỏ để chọn ngành.
    private var moiChonNganh: some View {
        Button {
            Haptics.cham()
            bangMo = .chonNganh(hoSo.isStudent == nil ? .hoi : .khoi, khoi: nil, nganh: nil)
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.onPrimary)
                    .frame(width: 42, height: 42)
                    .background(AppColors.brandGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sinh viên FPTU? Chọn ngành của bạn")
                        .font(.titleSmall).foregroundColor(AppColors.textPrimary)
                    Text("Chỉ hiện đúng môn của ngành hẹp bạn học, thay vì môn của mọi ngành.")
                        .font(.caption).foregroundColor(AppColors.textSecondary)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption).foregroundColor(AppColors.textTertiary)
            }
            .padding(Spacing.md)
            .background(AppColors.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.md)
    }

    private var chuaCoMon: some View {
        let ten = dm.nganhHep(hoSo.faculty, hoSo.major, hoSo.combo)?.nameVi
            ?? dm.nganh(hoSo.faculty, hoSo.major)?.nameVi ?? ""
        return VStack(spacing: Spacing.sm) {
            Image(systemName: "tray").font(.system(size: 30)).foregroundColor(AppColors.textTertiary)
            Text("Ngành hẹp **\(ten)** chưa có môn nào được dựng trong Academy.")
                .multilineTextAlignment(.center)
            Button("Đổi ngành") { bangMo = .chonNganh(.khoi, khoi: nil, nganh: nil) }
                .buttonStyle(.borderedProminent).tint(AppColors.primary)
        }
        .font(.bodyMedium)
        .foregroundColor(AppColors.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
        .overlay(RoundedRectangle(cornerRadius: CornerRadius.large).strokeBorder(AppColors.border, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
        .padding(.horizontal, Spacing.md)
    }

    // MARK: Tìm kiếm

    /// Tìm trên MỌI môn Academy, không chỉ môn của ngành — tìm theo mã là việc
    /// người dùng biết chính xác mình cần gì. Khớp đúng mã thì lên đầu.
    private var ketQuaTim: some View {
        let q = timKiem.trimmingCharacters(in: .whitespaces).lowercased()
        let kq = vm.tatCaMon
            .filter { ($0.courseCode ?? "").lowercased().contains(q) || $0.title.lowercased().contains(q) }
            .sorted {
                let a = ($0.courseCode ?? "").lowercased(), b = ($1.courseCode ?? "").lowercased()
                if (a == q) != (b == q) { return a == q }
                return a < b
            }
            .prefix(30)
        return VStack(spacing: 0) {
            if kq.isEmpty {
                Text("Không tìm thấy môn học khớp “\(timKiem)”.")
                    .font(.bodyMedium).foregroundColor(AppColors.textTertiary)
                    .frame(maxWidth: .infinity).padding(Spacing.lg)
            } else {
                ForEach(Array(kq)) { c in
                    NavigationLink { CourseDetailView(slug: c.slug) } label: {
                        hangMon(MonHien(course: c, laMaCu: false, laProject: LocTheoNganh.laProject(c)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .padding(.horizontal, Spacing.md)
    }

    // MARK: Kỳ + môn

    private func theHocKy(_ ky: NhomKy) -> some View {
        let mo = moRong.contains(ky.id)
        return VStack(spacing: 0) {
            Button {
                Haptics.cham()
                withAnimation(.snappy(duration: 0.22)) {
                    if mo { moRong.remove(ky.id) } else { moRong.insert(ky.id) }
                }
            } label: {
                HStack(spacing: Spacing.md) {
                    Text(soKy(ky.ten))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.primary)
                        .frame(width: 38, height: 38)
                        .background(AppColors.primary.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(ky.ten).font(.titleSmall).foregroundColor(AppColors.textPrimary)
                        Text("\(ky.mon.count) môn").font(.caption).foregroundColor(AppColors.textTertiary)
                    }
                    Spacer()
                    Image(systemName: mo ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundColor(AppColors.textSecondary)
                }
                .padding(Spacing.md)
                .background(AppColors.backgroundCard)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if mo {
                if ky.mon.isEmpty {
                    Text("Kỳ này chưa có môn nào.")
                        .font(.bodySmall).foregroundColor(AppColors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.md)
                        .background(AppColors.backgroundSecondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(ky.mon) { m in
                            NavigationLink { CourseDetailView(slug: m.course.slug) } label: { hangMon(m) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .padding(.horizontal, Spacing.md)
    }

    /// "Kỳ 3" → "3", "Kỳ chuẩn bị" → "0", "Project gợi ý" → 🚀.
    private func soKy(_ ten: String) -> String {
        if ten.hasPrefix("Project") { return "🚀" }
        if ten == "Kỳ chuẩn bị" { return "0" }
        return ten.split(separator: " ").last.map(String.init).flatMap { Int($0) }.map(String.init) ?? "—"
    }

    private func hangMon(_ m: MonHien) -> some View {
        let c = m.course
        let mau = m.laProject ? AppColors.success : m.laMaCu ? AppColors.warning : AppColors.secondary
        return HStack(spacing: Spacing.md) {
            // Mã môn thay cho ảnh bìa: ngắn, nhận ra ngay, phần lớn môn chưa có ảnh riêng.
            Text(c.courseCode ?? "—")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(mau)
                .frame(width: 66, height: 30)
                .background(mau.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(c.title.songNguTheoMay)
                    .font(.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    if m.laProject { nhan("🚀 PROJECT", mau: AppColors.success) }
                    if m.laMaCu { nhan("MÃ CŨ", mau: AppColors.warning) }
                    if let n = c.totalLessons, n > 0 { Text("\(n) bài") } else { Text("chưa có bài") }
                    if c.isEnrolled == true { Text("· Đã ghi danh").foregroundColor(AppColors.success) }
                }
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption).foregroundColor(AppColors.textTertiary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundSecondary)
        .contentShape(Rectangle())
    }

    private func nhan(_ s: String, mau: Color) -> some View {
        Text(s)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(mau)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(mau.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func nutVien(_ nhan: String, he: String? = nil, mau: Color, bam: @escaping () -> Void) -> some View {
        Button {
            Haptics.cham()
            bam()
        } label: {
            HStack(spacing: 6) {
                if let he { Image(systemName: he) }
                Text(nhan)
            }
            .font(.buttonSmall)
            .foregroundColor(mau)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(AppColors.backgroundSecondary)
            .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium).stroke(mau.opacity(0.35), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Lối vào từ tab Học

struct AcademyEntryCard: View {
    @ObservedObject private var hoSo = HoSoAcademy.shared

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
                    Text("Academy")
                        .font(.titleSmall)
                        .foregroundColor(AppColors.textPrimary)
                    Text(phuDe)
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

    /// Đã chọn ngành thì nói luôn ngành — nhìn là biết Academy đang lọc theo gì.
    private var phuDe: String {
        let h = hoSo.hoSo
        let dm = DanhMucNganh.shared
        if h.isStudent == true, let n = dm.nganh(h.faculty, h.major) {
            return dm.nganhHep(h.faculty, h.major, h.combo)?.nameVi ?? n.nameVi
        }
        return "Chương trình đại học theo học kỳ"
    }
}
