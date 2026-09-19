#if os(iOS)
import SwiftUI

// ════════════════════════════════════════════════════════════════
// KHO TỪ VỰNG cho IELTS — lấy từ My Language, KHÔNG dựng kho thứ hai.
//
// Người dùng nhận ra hai chỗ trùng nhau: IELTS và "Tiếng Anh" trong My
// Language. Đo thật 19/09/2026 thì chúng KHÔNG phải bản sao — chúng là hai
// giáo trình khác nhau cho cùng một ngôn ngữ, và mỗi bên mạnh một kiểu:
//
//   My Language EN : 13.226 TỪ / 346 nhóm (đã gắn cấp A1…C2 và chủ đề
//                    nghề), 300 điểm ngữ pháp — nhưng không có bài tập,
//                    không có chấm, không có lộ trình thi
//   IELTS          : 597 mục có cấu trúc, 200 bài tập/chặng, chấm viết và
//                    nói, phòng thi — nhưng từ vựng chỉ vài nhóm
//
// ⇒ Gộp đúng cách không phải chép nội dung, mà là để IELTS làm VỎ và kho
// từ kia làm NGUỒN. Màn này chỉ là cây cầu; nó dùng lại `TuNgoaiNguView`
// và `TheGhiNhoView` vốn đã có sẵn, không viết lại bộ duyệt từ thứ hai.
// ════════════════════════════════════════════════════════════════

struct KhoTuVungView: View {
    @ObservedObject private var kho = TiengAnhCuaToi.chung

    @State private var chuDe: [ChuDeTu] = []
    @State private var dangTai = true
    @State private var loi: String?
    @State private var tim = ""
    @State private var capDangChon: String?

    /// Cấp có thật trong dữ liệu, xếp theo thứ tự CEFR chứ không theo bảng
    /// chữ cái — "C1" đứng trước "A1" thì nhìn là biết sai.
    private var cacCap: [String] {
        let thuTu = ["A1", "A2", "B1", "B2", "C1", "C2"]
        let co = Set(chuDe.compactMap(\.level).filter { !$0.isEmpty })
        return thuTu.filter { co.contains($0) } + co.subtracting(thuTu).sorted()
    }

    private var loc: [ChuDeTu] {
        var ds = chuDe
        if let c = capDangChon { ds = ds.filter { $0.level == c } }
        let t = tim.trimmingCharacters(in: .whitespaces).lowercased()
        if !t.isEmpty { ds = ds.filter { $0.name.lowercased().contains(t) } }
        // Nhóm rỗng thì giấu: mở ra không có từ nào là thứ phá lòng tin.
        return ds.filter { $0.soTu > 0 }
    }

    private var tongTu: Int { chuDe.reduce(0) { $0 + $1.soTu } }

    var body: some View {
        Group {
            if dangTai { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
            else if let l = loi {
                KhungTrongTien(bieuTuong: "wifi.slash", tieuDe: T("Không tải được"), moTa: l)
            } else { danhSach }
        }
        .navigationTitle(T("Kho từ vựng"))
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $tim, prompt: T("Tìm chủ đề"))
        .task { await nap() }
    }

    private var danhSach: some View {
        List {
            Section {
                Text(String(format: T("%d từ tiếng Anh trong %d chủ đề, có câu ví dụ và phát âm."),
                            tongTu, loc.count))
                    .font(.bodySmall).foregroundStyle(AppColors.textSecondary)
                thanhCap
            }
            .listRowBackground(Color.clear)

            ForEach(loc) { c in
                if let n = kho.tiengAnh {
                    NavigationLink { TuNgoaiNguView(ngonNgu: n, chuDe: c) } label: { hang(c) }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var thanhCap: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                nutCap(nil, T("Tất cả"))
                ForEach(cacCap, id: \.self) { c in nutCap(c, c) }
            }
        }
    }

    private func nutCap(_ c: String?, _ ten: String) -> some View {
        let chon = capDangChon == c
        return Button { capDangChon = chon && c != nil ? nil : c } label: {
            Text(ten).font(.captionBold)
                .padding(.horizontal, Spacing.md).padding(.vertical, 6)
                .background(Capsule().fill(chon ? AppColors.primary : AppColors.backgroundTertiary))
                .foregroundStyle(chon ? Color.white : AppColors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private func hang(_ c: ChuDeTu) -> some View {
        HStack(spacing: Spacing.md) {
            Text(c.icon ?? "📘").font(.title3).frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(c.tenGon).font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)
                Text("\(c.soTu) \(T("từ"))")
                    .font(.caption).foregroundStyle(AppColors.textTertiary)
            }
            Spacer(minLength: 0)
            if let l = c.level, !l.isEmpty {
                Text(l).font(.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(AppColors.primary.opacity(0.14)))
                    .foregroundStyle(AppColors.primary)
            }
        }
        .padding(.vertical, 2)
    }

    private func nap() async {
        dangTai = true
        defer { dangTai = false }
        await kho.nap()
        guard let n = kho.tiengAnh else {
            loi = T("Chưa xác định được ngôn ngữ tiếng Anh trên máy chủ.")
            return
        }
        do { chuDe = try await APIClient.shared.request(.chuDeTu(code: n.code)) }
        catch { loi = error.localizedDescription }
    }
}
#endif
