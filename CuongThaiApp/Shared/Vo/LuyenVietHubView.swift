#if os(iOS)
import SwiftData
import SwiftUI

/// Tab "Luyện viết" trong Vở — bảng chữ tiếng Nhật và chữ Hán.
///
/// Kana lấy từ máy chủ (`/my-language/:code/alphabet`, 220 mục đủ cả dakuten
/// và yōon, kèm phiên âm). Kanji lấy từ danh sách trong app: bảng chữ trên
/// máy chủ chỉ có 8 chữ Hán, trong khi kho NÉT phủ mọi kanji — nên chỉ cần
/// biết chữ nào cần học là đủ.
struct LuyenVietHubView: View {
    @Environment(\.modelContext) private var kho
    @Environment(\.horizontalSizeClass) private var beRong
    @Query private var tienDo: [TienDoChu]

    @State private var nhomKana: [NhomChu] = []
    @State private var dangTai = true
    @State private var loi: String?
    @State private var dangMo: ChuDangMo?

    private struct ChuDangMo: Identifiable {
        let chu: String
        let phienAm: String?
        var id: String { chu }
    }

    private var soCot: Int { beRong == .regular ? 10 : 6 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                tomTat

                if dangTai {
                    HStack { Spacer(); ProgressView(); Spacer() }.padding(.top, 40)
                } else if let loi {
                    Text(loi).font(Font.bodyMedium)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity).padding(.top, 40)
                }

                // Kana — từ máy chủ
                ForEach(nhomKana) { nhom in
                    if !nhom.chu.isEmpty {
                        khoiChu(ten: nhom.name,
                                moTa: nhom.description,
                                chu: nhom.chu.map { ($0.character, $0.romanization) })
                    }
                }

                // Kanji — từ danh sách trong app
                ForEach(KanjiTheoCap.tatCa) { bo in
                    khoiChu(ten: bo.ten, moTa: bo.moTa,
                            chu: bo.chu.map { ($0, nil) })
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .task { await taiKana() }
        .fullScreenCover(item: $dangMo) { m in
            LuyenVietPencil(chu: m.chu, phienAm: m.phienAm, lang: "ja") {
                ghiNhanDung(m.chu)
            }
        }
    }

    // MARK: Tóm tắt

    private var tomTat: some View {
        let thuoc = tienDo.filter(\.daThuoc).count
        let daThu = tienDo.count
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(T("Luyện viết"))
                .font(Font.displaySmall)
                .foregroundStyle(AppColors.textPrimary)
            Text(thuoc > 0
                 ? "\(thuoc) " + T("chữ đã thuộc") + " · \(daThu) " + T("chữ đã tập")
                 : T("Chạm một chữ để tập viết từng nét bằng Apple Pencil"))
                .font(Font.bodyMedium)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    // MARK: Khối chữ

    private func khoiChu(ten: String, moTa: String?, chu: [(String, String?)]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(ten).font(Font.titleSmall).foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text("\(soThuoc(chu.map(\.0)))/\(chu.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppColors.textTertiary)
            }
            if let moTa, !moTa.isEmpty {
                Text(moTa).font(.caption).foregroundStyle(AppColors.textTertiary)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.sm),
                                     count: soCot),
                      spacing: Spacing.sm) {
                ForEach(chu, id: \.0) { c, am in
                    Button { dangMo = ChuDangMo(chu: c, phienAm: am) } label: {
                        OChu(chu: c, phienAm: am, thuoc: laThuoc(c))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private struct OChu: View {
        let chu: String
        let phienAm: String?
        let thuoc: Bool
        var body: some View {
            VStack(spacing: 1) {
                Text(chu)
                    .font(.system(size: 26))
                    .foregroundStyle(AppColors.textPrimary)
                if let phienAm, !phienAm.isEmpty {
                    Text(phienAm).font(.system(size: 9))
                        .foregroundStyle(AppColors.textTertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(thuoc ? AppColors.success.opacity(0.14) : AppColors.backgroundCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .strokeBorder(thuoc ? AppColors.success.opacity(0.5) : AppColors.border,
                                  lineWidth: 1)
            )
        }
    }

    // MARK: Tiến độ

    private func laThuoc(_ c: String) -> Bool {
        tienDo.first { $0.chu == c }?.daThuoc ?? false
    }

    private func soThuoc(_ ds: [String]) -> Int {
        let bo = Set(tienDo.filter(\.daThuoc).map(\.chu))
        return ds.filter(bo.contains).count
    }

    private func ghiNhanDung(_ c: String) {
        if let co = tienDo.first(where: { $0.chu == c }) {
            co.soLanDung += 1
            co.soLanThu += 1
            co.lanCuoi = Date()
        } else {
            let m = TienDoChu(chu: c, lang: "ja")
            m.soLanDung = 1
            m.soLanThu = 1
            m.lanCuoi = Date()
            kho.insert(m)
        }
        try? kho.save()
    }

    // MARK: Tải kana

    private func taiKana() async {
        guard nhomKana.isEmpty else { return }
        dangTai = true
        defer { dangTai = false }
        do {
            nhomKana = try await APIClient.shared.request(.bangChu(code: "ja"))
        } catch {
            // Mất mạng thì phần KANJI vẫn dùng được (danh sách nằm trong app)
            // — chỉ kana là thiếu. Nói đúng chuyện đó thay vì để màn trống.
            loi = T("Chưa tải được bảng kana (cần mạng). Phần chữ Hán bên dưới vẫn tập được.")
        }
    }
}
#endif
