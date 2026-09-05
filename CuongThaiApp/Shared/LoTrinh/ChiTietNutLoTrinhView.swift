import SwiftUI

// ════════════════════════════════════════════════════════════════
// MỘT BƯỚC TRONG LỘ TRÌNH NGHỀ — TẤM CHI TIẾT
//
// ⚠️ Vì sao có màn này: bản trước giấu toàn bộ nội dung sau một mũi tên xổ
// rộng 10pt ở mép phải hàng. Chạm vào TÊN bước thì không có gì xảy ra —
// người dùng báo đúng thế: "ấn vào không thấy nội dung gì". Nay chạm bất cứ
// đâu trên hàng là mở tấm này.
//
// ⚠️⚠️ Và chỗ thiếu lớn hơn: `linkType`/`linkRef` CÓ trong model từ đầu
// nhưng KHÔNG nơi nào dùng. Đo thật trên 3 lộ trình (Frontend/Backend/DevOps):
// **56/225 bước (25%) có liên kết** — 41 vào Code Lab, 9 ra tài liệu ngoài,
// 6 sang lộ trình khác. Tức một phần tư lộ trình vốn dẫn được tới chỗ HỌC
// THẬT mà app bỏ không. Web có nút "Học ngay" đó từ đầu.
// ════════════════════════════════════════════════════════════════

struct ChiTietNutLoTrinhView: View {
    let nut: NutLoTrinhNghe
    let mau: Color
    let daXong: Bool
    let doiXong: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var moLink

    /// Ba kiểu liên kết máy chủ dùng. `nil` = bước này chỉ để đọc.
    private enum DiToi {
        case codeLab(slug: String)
        case loTrinhKhac(slug: String)
        case ngoai(URL)
    }

    private var diToi: DiToi? {
        guard let ref = nut.linkRef, !ref.isEmpty else { return nil }
        switch (nut.linkType ?? "").lowercased() {
        case "code-lab": return .codeLab(slug: ref)
        case "roadmap":  return .loTrinhKhac(slug: ref)
        // ⚠️ `external` KHÔNG chắc là URL đầy đủ — web kiểm `/^https?:\/\//`
        // trước khi coi là link ngoài. Không kiểm thì `URL(string:)` nhận cả
        // chuỗi rác và nút mở ra một trang trắng.
        case "external": return URL(string: ref).flatMap { $0.scheme?.hasPrefix("http") == true ? .ngoai($0) : nil }
        default: return nil
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    dauTrang
                    if let d = nut.description, !d.isEmpty {
                        Text(d)
                            .font(.system(size: 14.5))
                            .foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let d = diToi { nutHocNgay(d) }
                    if !nut.cacTaiNguyen.isEmpty { khoiTaiNguyen }
                    nutDanhDau
                }
                .padding(Spacing.md)
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle(T("Bước học"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .accessibilityLabel(T("Đóng"))
                }
            }
        }
    }

    private var dauTrang: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: nut.bieuTuong)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(mau))
            VStack(alignment: .leading, spacing: 4) {
                Text(nut.title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let s = nut.subtitle, !s.isEmpty {
                    Text(s).font(.system(size: 12.5)).foregroundColor(AppColors.textTertiary)
                }
                HStack(spacing: 6) {
                    Text(nut.nhanLoai)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Capsule().fill(mau))
                    if let l = nut.stageLabel, !l.isEmpty {
                        Text(l).font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    // ── Học ngay ────────────────────────────────────────────────
    @ViewBuilder
    private func nutHocNgay(_ d: DiToi) -> some View {
        switch d {
        case .codeLab(let slug):
            NavigationLink {
                // ⚠️ `ChuongTrinhHocView` nhận cả một `LoTrinhCode`, nhưng nó
                // CHỈ dùng `slug` để tự gọi `/code-lab/roadmaps/<slug>` rồi
                // lấy đủ dữ liệu. Nên dựng một bản tối thiểu là đủ — không
                // cần thêm một lời gọi mạng chỉ để có cái tên.
                ChuongTrinhHocView(loTrinh: LoTrinhCode(
                    id: 0, name: nut.title, slug: slug, description: nil,
                    language: nil, level: nil, color: nil,
                    exerciseCount: nil, moduleCount: nil))
            } label: {
                nhanHanhDong(T("Học ngay trong Code Lab"), "play.fill")
            }
            .buttonStyle(.plain)

        case .loTrinhKhac(let slug):
            NavigationLink {
                LoTrinhNgheChiTietView(tom: LoTrinhNgheTom(
                    slug: slug, title: nut.title, type: "role",
                    description: nut.description, icon: nut.icon,
                    color: nil, nodeCount: nil))
            } label: {
                nhanHanhDong(T("Mở lộ trình này"), "map.fill")
            }
            .buttonStyle(.plain)

        case .ngoai(let u):
            Button { moLink(u) } label: {
                nhanHanhDong(T("Mở tài liệu"), "arrow.up.right.square.fill")
            }
            .buttonStyle(.plain)
        }
    }

    private func nhanHanhDong(_ chu: String, _ icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold))
            Text(chu).font(.system(size: 15.5, weight: .semibold))
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).opacity(0.7)
        }
        .foregroundColor(.white)
        .padding(.horizontal, Spacing.md).padding(.vertical, 13)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(mau))
    }

    // ── Tài nguyên ──────────────────────────────────────────────
    private var khoiTaiNguyen: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("\(T("Tài nguyên")) (\(nut.cacTaiNguyen.count))")
                .font(.system(size: 11, weight: .bold)).kerning(0.5)
                .foregroundColor(AppColors.textTertiary)
            ForEach(nut.cacTaiNguyen) { r in
                if let u = URL(string: r.url) {
                    Button { moLink(u) } label: {
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            Image(systemName: r.bieuTuong)
                                .font(.system(size: 13)).foregroundColor(mau)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.title ?? r.url)
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundColor(AppColors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                                // Hiện MIỀN, không hiện cả URL: một đường dẫn
                                // roadmap.sh dài 80 ký tự đẩy hết bố cục.
                                Text(u.host ?? r.url)
                                    .font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .padding(Spacing.sm + 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(AppColors.backgroundCard))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var nutDanhDau: some View {
        Button {
            doiXong()
            Haptics.cham()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: daXong ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17))
                Text(daXong ? T("Đã học xong") : T("Đánh dấu đã học"))
                    .font(.system(size: 15, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundColor(daXong ? mau : AppColors.textSecondary)
            .padding(.horizontal, Spacing.md).padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(daXong ? mau : AppColors.border, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .padding(.top, Spacing.xs)
    }
}
