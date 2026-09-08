import SwiftUI

// ════════════════════════════════════════════════════════════════
// TÌM KIẾM
//
// Bản viết lại 09/09/2026. Bản cũ KHÔNG chạy được gì cả:
//   • chỉ gọi `/users/search` — vốn là API cho `@mention`: trần cứng 8 kết
//     quả, LOẠI chính mình, và trả về MẢNG PHẲNG. App lại giải mã
//     `{users: […]}` nên luôn ném lỗi, bắt xong nuốt ⇒ hỏng CÂM.
//   • `posts = []` kèm chú thích "for now, just show empty" — ba tab Bài
//     viết / Khoá học / Nhạc chưa từng có gì phía sau.
//   • dùng `.searchable(…)`: iOS 26 đẩy ô tìm xuống ĐÁY màn, rời hẳn khỏi
//     hàng chip lọc ở trên, nhìn như hai màn ghép lại.
//
// Nay: một lời gọi `/api/v1/tim-kiem` trả cả bốn loại, ô tìm nằm trên đầu
// ngay dưới tiêu đề, và gõ tới đâu tìm tới đó.
// ════════════════════════════════════════════════════════════════

enum LoaiTimKiem: String, CaseIterable, Identifiable {
    case tatCa   = "tat-ca"
    case nguoi   = "nguoi"
    case baiViet = "bai-viet"
    case khoaHoc = "khoa-hoc"
    // ⚠️ KHÔNG có tab Nhạc. Bỏ 09/09/2026: kho nhạc phát nội dung không có
    // quyền phân phối, đưa vào app iOS là rủi ro bị App Store từ chối
    // (Guideline 5.2 — Intellectual Property). Web giữ nguyên.

    var id: String { rawValue }

    var nhan: String {
        switch self {
        case .tatCa:   return T("Tất cả")
        case .nguoi:   return T("Mọi người")
        case .baiViet: return T("Bài viết")
        case .khoaHoc: return T("Khoá học")
        }
    }

    var bieuTuong: String {
        switch self {
        case .tatCa:   return "square.grid.2x2"
        case .nguoi:   return "person.2"
        case .baiViet: return "doc.text"
        case .khoaHoc: return "graduationcap"
        }
    }
}

// MARK: - Mô hình kết quả

struct NguoiTK: Codable, Identifiable {
    let id: Int
    let username: String?
    let displayName: String?
    let fullName: String?
    let avatarUrl: String?
    let bio: String?
    var ten: String { displayName ?? fullName ?? username ?? "—" }
}

/// Bài viết = `TechTrendArticle` phía máy chủ (bảng `Post` cũ chỉ còn 3 dòng
/// tàn dư sau cuộc gộp blog 05/08 — xem chú thích ở `timKiem.routes.ts`).
struct BaiVietTK: Codable, Identifiable {
    let id: Int
    let title: String
    let slug: String
    let summary: String?
    let coverEmoji: String?
    let category: String?
    let viewCount: Int?
}

struct KhoaHocTK: Codable, Identifiable {
    let id: Int
    let title: String
    let slug: String
    let courseCode: String?
    let shortDescription: String?
    let thumbnailUrl: String?
    let level: String?
}

struct KetQuaTimKiem: Codable {
    var nguoi: [NguoiTK] = []
    var baiViet: [BaiVietTK] = []
    var khoaHoc: [KhoaHocTK] = []
    var tong: Int = 0
}

// MARK: - ViewModel

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var tuKhoa = ""
    @Published var loai: LoaiTimKiem = .tatCa
    @Published var ketQua = KetQuaTimKiem()
    @Published var dangTim = false
    @Published var loi: String?
    /// Đã tìm ít nhất một lần với từ khoá hiện tại — để phân biệt "chưa gõ gì"
    /// với "gõ rồi mà không có kết quả".
    @Published var daTim = false

    @Published private(set) var ganDay: [String] = []

    private let khoaGanDay = "tuKhoaGanDay"
    private let toiDaGanDay = 10
    private var viec: Task<Void, Never>?

    init() { ganDay = UserDefaults.standard.stringArray(forKey: khoaGanDay) ?? [] }

    /// Gõ tới đâu tìm tới đó, nhưng CHỜ người dùng ngừng gõ 350ms.
    /// Không chờ thì mỗi ký tự là một lời gọi mạng — gõ "kotlin" là 6 lượt,
    /// và các lượt về không đúng thứ tự sẽ ghi đè kết quả mới bằng kết quả cũ.
    func goPhim() {
        viec?.cancel()
        let q = tuKhoa.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else {
            ketQua = KetQuaTimKiem(); daTim = false; dangTim = false; return
        }
        viec = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await tim(q, luu: false)
        }
    }

    /// Bấm Enter hoặc chọn một từ khoá cũ — tìm NGAY, và ghi vào lịch sử.
    func timNgay() {
        viec?.cancel()
        let q = tuKhoa.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { return }
        viec = Task { await tim(q, luu: true) }
    }

    private func tim(_ q: String, luu: Bool) async {
        dangTim = true
        loi = nil
        defer { dangTim = false }
        do {
            let r: KetQuaTimKiem = try await APIClient.shared.request(
                .timKiem(q: q, loai: loai.rawValue))
            guard !Task.isCancelled else { return }
            ketQua = r
            daTim = true
            if luu { luuGanDay(q) }
        } catch {
            guard !Task.isCancelled else { return }
            // ⚠️ HIỆN lỗi ra. Bản cũ bắt rồi để đó, nên khi hình dạng dữ liệu
            // đổi thì màn chỉ im lặng trống trơn — không ai biết là hỏng.
            loi = (error as NSError).localizedDescription
            ketQua = KetQuaTimKiem()
            daTim = true
        }
    }

    func doiLoai(_ l: LoaiTimKiem) {
        loai = l
        if tuKhoa.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 { timNgay() }
    }

    func chonGanDay(_ q: String) { tuKhoa = q; timNgay() }

    func xoaGanDay() {
        UserDefaults.standard.removeObject(forKey: khoaGanDay)
        ganDay = []
    }

    func xoaMot(_ q: String) {
        ganDay.removeAll { $0 == q }
        UserDefaults.standard.set(ganDay, forKey: khoaGanDay)
    }

    private func luuGanDay(_ q: String) {
        var ds = ganDay
        ds.removeAll { $0.lowercased() == q.lowercased() }
        ds.insert(q, at: 0)
        if ds.count > toiDaGanDay { ds = Array(ds.prefix(toiDaGanDay)) }
        ganDay = ds
        UserDefaults.standard.set(ds, forKey: khoaGanDay)
    }
}

// MARK: - Màn hình

struct SearchView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = SearchViewModel()
    @FocusState private var dangGo: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                oTim
                hangChip
                Divider().overlay(AppColors.divider)
                noiDung
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle(T("Tìm kiếm"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // ── Ô tìm: nằm NGAY dưới tiêu đề ─────────────────────────────
    private var oTim: some View {
        HStack(spacing: Spacing.sm) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
                TextField(T("Tìm người, bài viết, khoá học, nhạc…"), text: $vm.tuKhoa)
                    .font(.system(size: 15))
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .focused($dangGo)
                    .onChange(of: vm.tuKhoa) { _, _ in vm.goPhim() }
                    .onSubmit { dangGo = false; vm.timNgay() }
                if !vm.tuKhoa.isEmpty {
                    Button { vm.tuKhoa = ""; vm.goPhim() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.backgroundTertiary))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(dangGo ? AppColors.primary.opacity(0.55) : AppColors.border,
                              lineWidth: 1))
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    private var hangChip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(LoaiTimKiem.allCases) { l in
                    let chon = vm.loai == l
                    Button { vm.doiLoai(l) } label: {
                        HStack(spacing: 5) {
                            Image(systemName: l.bieuTuong).font(.system(size: 11, weight: .semibold))
                            Text(l.nhan).font(.system(size: 13, weight: .semibold))
                            if let n = soLuong(l), n > 0 {
                                Text("\(n)")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(Capsule().fill(chon ? Color.white.opacity(0.25)
                                                                     : AppColors.primary.opacity(0.16)))
                            }
                        }
                        .foregroundColor(chon ? AppColors.onPrimary : AppColors.textSecondary)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Capsule().fill(chon ? AppColors.primary : AppColors.backgroundTertiary))
                        .overlay(Capsule().strokeBorder(chon ? .clear : AppColors.border, lineWidth: 1))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.md)
        }
        .padding(.bottom, Spacing.sm)
    }

    /// Số kết quả của mỗi loại — chỉ hiện khi đang xem "Tất cả", vì lúc lọc
    /// riêng thì các loại khác không được tải nên con số sẽ là 0 gây hiểu nhầm.
    private func soLuong(_ l: LoaiTimKiem) -> Int? {
        guard vm.loai == .tatCa, vm.daTim else { return nil }
        switch l {
        case .tatCa:   return vm.ketQua.tong
        case .nguoi:   return vm.ketQua.nguoi.count
        case .baiViet: return vm.ketQua.baiViet.count
        case .khoaHoc: return vm.ketQua.khoaHoc.count
        }
    }

    // ── Nội dung ─────────────────────────────────────────────────
    @ViewBuilder
    private var noiDung: some View {
        if let l = vm.loi {
            bangLoi(l)
        } else if vm.tuKhoa.trimmingCharacters(in: .whitespaces).count < 2 {
            manGoiY
        } else if vm.dangTim && vm.ketQua.tong == 0 {
            VStack(spacing: Spacing.md) {
                ProgressView().controlSize(.large)
                Text(T("Đang tìm…")).font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.daTim && vm.ketQua.tong == 0 {
            khongCoGi
        } else {
            danhSach
        }
    }

    private var danhSach: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.sm) {
                if !vm.ketQua.nguoi.isEmpty {
                    tieuDeNhom(T("Mọi người"), vm.ketQua.nguoi.count)
                    ForEach(vm.ketQua.nguoi) { n in HangNguoi(n: n) }
                }
                if !vm.ketQua.baiViet.isEmpty {
                    tieuDeNhom(T("Bài viết"), vm.ketQua.baiViet.count)
                    ForEach(vm.ketQua.baiViet) { b in HangBaiViet(b: b) }
                }
                if !vm.ketQua.khoaHoc.isEmpty {
                    tieuDeNhom(T("Khoá học"), vm.ketQua.khoaHoc.count)
                    ForEach(vm.ketQua.khoaHoc) { k in HangKhoaHoc(k: k) }
                }
                Color.clear.frame(height: 80)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private func tieuDeNhom(_ t: String, _ n: Int) -> some View {
        HStack(spacing: 6) {
            Text(t.uppercased())
                .font(.system(size: 11, weight: .heavy)).tracking(1)
                .foregroundColor(AppColors.textTertiary)
            Text("\(n)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppColors.primary)
            Spacer(minLength: 0)
        }
        .padding(.top, Spacing.sm)
    }

    // ── Màn khi chưa gõ gì ───────────────────────────────────────
    private var manGoiY: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if !vm.ganDay.isEmpty {
                    HStack {
                        Text(T("TÌM GẦN ĐÂY"))
                            .font(.system(size: 11, weight: .heavy)).tracking(1)
                            .foregroundColor(AppColors.textTertiary)
                        Spacer()
                        Button(T("Xoá hết")) { vm.xoaGanDay() }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.primary)
                    }
                    VStack(spacing: 0) {
                        ForEach(vm.ganDay, id: \.self) { q in
                            Button { vm.chonGanDay(q) } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 13))
                                        .foregroundColor(AppColors.textTertiary)
                                    Text(q).font(.system(size: 14))
                                        .foregroundColor(AppColors.textPrimary)
                                    Spacer(minLength: 0)
                                    Button { vm.xoaMot(q) } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(AppColors.textTertiary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 11)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider().overlay(AppColors.divider)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(T("TÌM ĐƯỢC GÌ Ở ĐÂY"))
                        .font(.system(size: 11, weight: .heavy)).tracking(1)
                        .foregroundColor(AppColors.textTertiary)
                    ForEach(LoaiTimKiem.allCases.dropFirst()) { l in
                        HStack(spacing: 10) {
                            Image(systemName: l.bieuTuong)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppColors.primary)
                                .frame(width: 22)
                            Text(l.nhan).font(.system(size: 14))
                                .foregroundColor(AppColors.textSecondary)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 6)
                    }
                    Text(T("Gõ ít nhất 2 ký tự để bắt đầu."))
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.top, 2)
                }
            }
            .padding(Spacing.md)
        }
    }

    private var khongCoGi: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 34)).foregroundColor(AppColors.textTertiary)
            Text(String(format: T("Không tìm thấy gì cho “%@”"), vm.tuKhoa))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
            Text(T("Thử từ khoá ngắn hơn, hoặc đổi sang tab khác."))
                .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func bangLoi(_ l: String) -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 30)).foregroundColor(AppColors.warning)
            Text(T("Không tìm được")).font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            Text(l).font(.system(size: 12.5)).foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            Button(T("Thử lại")) { vm.timNgay() }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.primary)
                .padding(.top, 4)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Các hàng kết quả

private struct HangNguoi: View {
    let n: NguoiTK
    var body: some View {
        NavigationLink(destination: ProfileView(userIdKhac: n.id)) {
            HStack(spacing: Spacing.md) {
                UserAvatarView(url: n.avatarUrl, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(n.ten).font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary).lineLimit(1)
                    if let u = n.username {
                        Text("@\(u)").font(.system(size: 12))
                            .foregroundColor(AppColors.textTertiary).lineLimit(1)
                    }
                    if let b = n.bio, !b.isEmpty {
                        Text(b).font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(Spacing.md)
            .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(AppColors.backgroundCard))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct HangBaiViet: View {
    let b: BaiVietTK
    var body: some View {
        HangKetQua(bieuTuong: "doc.text", mau: AppColors.secondary,
                   tieuDe: b.title, phu: b.summary,
                   duoi: [b.category, b.viewCount.map { String(format: T("%d lượt xem"), $0) }]
                            .compactMap { $0 }.joined(separator: " · "))
    }
}

private struct HangKhoaHoc: View {
    let k: KhoaHocTK
    var body: some View {
        HangKetQua(bieuTuong: "graduationcap.fill", mau: AppColors.primary,
                   // Tiêu đề khoá học là chuỗi song ngữ `EN|||VI`.
                   tieuDe: k.title.songNguTheoMay,
                   phu: k.shortDescription?.songNguTheoMay,
                   duoi: [k.courseCode, k.level].compactMap { $0 }.joined(separator: " · "))
    }
}

/// Khuôn chung cho ba loại kết quả không phải người — cùng một bố cục, chỉ
/// khác biểu tượng và màu. Ba bản sao chép tay là ba chỗ để lệch nhau.
private struct HangKetQua: View {
    let bieuTuong: String
    let mau: Color
    let tieuDe: String
    var phu: String?
    var duoi: String?

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: bieuTuong)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(mau)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(mau.opacity(0.14)))
            VStack(alignment: .leading, spacing: 2) {
                Text(tieuDe).font(.system(size: 14.5, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary).lineLimit(2)
                if let p = phu, !p.isEmpty {
                    Text(p).font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary).lineLimit(1)
                }
                if let d = duoi, !d.isEmpty {
                    Text(d).font(.system(size: 11))
                        .foregroundColor(AppColors.textTertiary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundCard))
    }
}
