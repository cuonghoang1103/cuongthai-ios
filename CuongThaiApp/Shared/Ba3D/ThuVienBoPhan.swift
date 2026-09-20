#if os(iOS)
import SwiftUI

// ════════════════════════════════════════════════════════════════
// THƯ VIỆN BỘ PHẬN — robot, nhân vật, thành phố, đạo cụ
//
// Mỗi bộ phận là một CÔNG THỨC GHÉP KHỐI chứ không phải tệp lưới. Người
// dùng lo tốn dung lượng iPad nên muốn tải lẻ từng phần; hoá ra không cần:
// cả thư viện 26 bộ phận chỉ **17,9 KB**, nhỏ hơn một cái ảnh thu nhỏ.
//
// Và công thức ghép khối hơn hẳn tệp lưới ở chỗ quan trọng nhất: kéo ra
// rồi VẪN SỬA ĐƯỢC từng khối — đổi tỉ lệ, đổi màu, khoét bằng Boolean. Tệp
// `.usdz` tải về là một cục chết, muốn sửa phải ra máy tính.
// ════════════════════════════════════════════════════════════════

struct NhomBoPhan: Codable, Identifiable, Hashable {
    let ma: String
    let ten: String
    var id: String { ma }
}

/// Không khai `Hashable`: nó chứa `[KhoiBa]`, mà `KhoiBa` chỉ `Equatable`.
/// `ForEach` chỉ cần `Identifiable`, nên không mất gì.
struct BoPhan3D: Codable, Identifiable {
    let id: String
    let ten: String
    let nhom: String
    let icon: String
    let moTa: String
    let khoi: [KhoiBa]
    var soKhoi: Int?

    /// Số khối thật, dùng `soKhoi` của máy chủ nếu có.
    var demKhoi: Int { soKhoi ?? khoi.count }
}

struct ThuVien3D: Codable {
    var phienBan: Int = 0
    var nhom: [NhomBoPhan] = []
    var boPhan: [BoPhan3D] = []

    static let rong = ThuVien3D()

    private enum CodingKeys: String, CodingKey { case phienBan, nhom, boPhan }

    init() {}

    /// ⚠️ Tự viết: `Decodable` tự sinh đòi ĐỦ MỌI khoá kể cả khi thuộc tính
    /// có giá trị mặc định, nên thêm một trường ở máy chủ là cả gói hỏng và
    /// app hiện "thư viện rỗng" mà không ai biết vì sao.
    init(from bo: Decoder) throws {
        let c = try bo.container(keyedBy: CodingKeys.self)
        phienBan = try c.decodeIfPresent(Int.self, forKey: .phienBan) ?? 0
        nhom = try c.decodeIfPresent([NhomBoPhan].self, forKey: .nhom) ?? []
        boPhan = try c.decodeIfPresent([BoPhan3D].self, forKey: .boPhan) ?? []
    }
}

@MainActor
final class KhoBoPhan: ObservableObject {
    static let chung = KhoBoPhan()

    @Published private(set) var thuVien = ThuVien3D.rong
    @Published private(set) var dangTai = false
    @Published private(set) var loi: String?

    private init() { napTuMay() }

    private static var tepCat: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("bo-phan-3d.json")
    }

    /// Bản đã cất ở máy — dùng NGAY khi mở, kể cả khi mất mạng.
    private func napTuMay() {
        guard let d = try? Data(contentsOf: Self.tepCat),
              let t = try? JSONDecoder().decode(ThuVien3D.self, from: d) else { return }
        thuVien = t
    }

    var coSan: Bool { !thuVien.boPhan.isEmpty }

    /// Kích thước bản đã cất, để màn quản lý nói được con số thật.
    var coCat: Int {
        (try? FileManager.default.attributesOfItem(atPath: Self.tepCat.path)[.size] as? Int) ?? 0
    }

    func tai(batBuoc: Bool = false) async {
        if coSan && !batBuoc { return }
        dangTai = true
        defer { dangTai = false }
        do {
            let t: ThuVien3D = try await APIClient.shared.request(.xuong3dBoPhan)
            thuVien = t
            loi = nil
            if let d = try? JSONEncoder().encode(t) { try? d.write(to: Self.tepCat) }
        } catch {
            // Có bản cũ thì cứ dùng, đừng xoá nó đi vì một lần mất mạng.
            if !coSan { loi = error.localizedDescription }
        }
    }

    func xoaBanCat() {
        try? FileManager.default.removeItem(at: Self.tepCat)
        thuVien = .rong
    }

    func theoNhom(_ ma: String) -> [BoPhan3D] {
        thuVien.boPhan.filter { $0.nhom == ma }
    }
}

// MARK: - Màn duyệt

struct ThuVienBoPhanView: View {
    /// Trả về các khối đã gán id MỚI để chèn vào cảnh.
    let chen: ([KhoiBa]) -> Void

    @StateObject private var kho = KhoBoPhan.chung
    @Environment(\.dismiss) private var dong
    @State private var nhomChon: String?
    @State private var tim = ""

    private var loc: [BoPhan3D] {
        let t = tim.trimmingCharacters(in: .whitespaces).lowercased()
        var ds = nhomChon.map { kho.theoNhom($0) } ?? kho.thuVien.boPhan
        if !t.isEmpty {
            ds = ds.filter { $0.ten.lowercased().contains(t) || $0.moTa.lowercased().contains(t) }
        }
        return ds
    }

    var body: some View {
        NavigationStack {
            Group {
                if kho.dangTai && !kho.coSan {
                    ProgressView(T("Đang tải thư viện…"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !kho.coSan {
                    KhungTrongTien(bieuTuong: "shippingbox",
                                   tieuDe: T("Chưa tải được thư viện"),
                                   moTa: kho.loi ?? T("Kiểm tra kết nối rồi thử lại."))
                } else {
                    noiDung
                }
            }
            .navigationTitle(T("Thư viện bộ phận"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $tim, prompt: T("Tìm bộ phận"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(T("Đóng")) { dong() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { Task { await kho.tai(batBuoc: true) } } label: {
                            Label(T("Tải lại thư viện"), systemImage: "arrow.clockwise")
                        }
                        Button(role: .destructive) { kho.xoaBanCat() } label: {
                            Label(String(format: T("Xoá bản đã tải (%d KB)"), kho.coCat / 1024),
                                  systemImage: "trash")
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .task { await kho.tai() }
        }
    }

    private var noiDung: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        chip(T("Tất cả"), nil, kho.thuVien.boPhan.count)
                        ForEach(kho.thuVien.nhom) { n in
                            chip(n.ten, n.ma, kho.theoNhom(n.ma).count)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Spacing.md)],
                          spacing: Spacing.md) {
                    ForEach(loc) { b in the(b) }
                }
                .padding(.horizontal, Spacing.md)

                Text(String(format: T("%d bộ phận · cả thư viện %d KB — kéo ra rồi vẫn sửa được từng khối"),
                            kho.thuVien.boPhan.count, max(1, kho.coCat / 1024)))
                    .font(.caption2).foregroundStyle(AppColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
            }
            .padding(.vertical, Spacing.sm)
        }
    }

    private func chip(_ ten: String, _ ma: String?, _ so: Int) -> some View {
        Button { nhomChon = ma } label: {
            HStack(spacing: 5) {
                Text(ten).font(.subheadline.weight(nhomChon == ma ? .semibold : .regular))
                Text("\(so)").font(.caption2)
                    .foregroundStyle(nhomChon == ma ? AppColors.onPrimary.opacity(0.75)
                                                    : AppColors.textTertiary)
            }
            .foregroundStyle(nhomChon == ma ? AppColors.onPrimary : AppColors.textSecondary)
            .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm)
            .background(Capsule().fill(nhomChon == ma ? AppColors.primary : AppColors.backgroundCard))
            .overlay(Capsule().stroke(nhomChon == ma ? .clear : AppColors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func the(_ b: BoPhan3D) -> some View {
        Button {
            // ⚠️ Gán id MỚI cho từng khối. Dùng lại id trong thư viện thì
            // kéo ra hai lần là hai cụm mang CÙNG id — chọn một cái, cái kia
            // cũng sáng viền, và xoá một cái là mất cả hai.
            let n = MauDungSan.maNhom(b.id)
            chen(b.khoi.map { k in
                var m = k
                m.id = UUID()
                m.nhom = n
                return m
            })
            dong()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(AppColors.primary.opacity(0.10))
                    Image(systemName: b.icon)
                        .font(.system(size: 30))
                        .foregroundStyle(AppColors.primary)
                }
                .frame(height: 80)

                Text(b.ten).font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary).lineLimit(1)
                Text(b.moTa).font(.caption2)
                    .foregroundStyle(AppColors.textSecondary).lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(String(format: T("%d khối"), b.demKhoi))
                    .font(.caption2).foregroundStyle(AppColors.textTertiary)
            }
            .padding(Spacing.sm)
            .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(AppColors.backgroundCard))
            .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(AppColors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
#endif
