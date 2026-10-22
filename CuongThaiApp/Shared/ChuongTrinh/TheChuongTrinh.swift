import SwiftUI

/// Lối vào Chương trình đào tạo ở tab Học — thay cho "Khoá tự biên soạn" + lưới khoá cũ (22/10/2026).
///
/// Nửa trên: tên chương trình + số liệu ⇒ mở màn tổng. Nửa dưới: kỳ ĐANG học (hoặc kỳ kế tiếp; chưa
/// đăng nhập ⇒ Kỳ 1) với năm ảnh bìa ⇒ mở màn tổng cuộn thẳng tới kỳ đó. Máy chủ chưa có endpoint
/// (đường lùi danh sách) ⇒ nửa dưới là các chuyên ngành.
struct TheChuongTrinh: View {
    @ObservedObject var vm: ChuongTrinhDaoTaoVM
    @ObservedObject private var nn = QuanLyNgonNguApp.shared
    @ScaledMetric(relativeTo: .title2) private var coTieuDe: CGFloat = 23

    private var anh: Bool { nn.ngonNgu == .anh }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink { ChuongTrinhView(vm: vm) } label: { phanTren }
                .buttonStyle(.plain)

            if let d = vm.duLieu {
                KeMong().padding(.horizontal, Spacing.md)
                if d.coLoTrinh, let h = d.kyHienTai {
                    NavigationLink { ChuongTrinhView(vm: vm, kyMoDau: h.ky.so) } label: {
                        phanKy(h.ky, dangHoc: h.dangHoc, coGhiDanh: d.monHocDuoc.contains(where: \.daGhiDanh))
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink { ChuongTrinhView(vm: vm, cheDo: .chuyenNganh) } label: { phanNganh(d) }
                        .buttonStyle(.plain)
                }
            } else if vm.dangTai {
                VStack(alignment: .leading, spacing: 10) {
                    SkeletonBox(height: 12, width: 120, radius: 2)
                    SkeletonBox(height: 18, width: 220, radius: 2)
                    SkeletonBox(height: 44, radius: 0)
                }
                .padding(Spacing.md)
                .overlay(alignment: .top) { KeMong().padding(.horizontal, Spacing.md) }
            }
        }
        .background(MauCT.the)
        .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium).stroke(MauCT.ke, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    // MARK: Nửa trên

    private var phanTren: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(T("Chương trình đào tạo").uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(0.8)
                    .foregroundColor(MauCT.nhan)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.footnote.weight(.medium))
                    .foregroundColor(MauCT.muc3)
            }
            Text(vm.duLieu?.coLoTrinh == false
                 ? T("Khoá học tự biên soạn, theo chuyên ngành")
                 : T("Bốn năm, mười lăm học kỳ — từ dòng lệnh đầu tiên tới hệ thống chạy thật"))
                .font(.system(size: coTieuDe, weight: .regular, design: .serif))
                .foregroundColor(MauCT.muc)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            if let d = vm.duLieu {
                Text(dongSo(d))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(MauCT.muc3)
                    .padding(.top, 2)
            }
        }
        .padding(Spacing.md)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(T("Mở chương trình đào tạo"))
    }

    private func dongSo(_ d: ChuongTrinhDaoTao) -> String {
        let t = d.tong
        var phan = [ChuCT.khoa(t.khoa, anh)]
        if d.coLoTrinh { phan.insert(anh ? "4 years · \(t.ky) terms" : "4 năm · \(t.ky) kỳ", at: 0) }
        if t.bai > 0 { phan.append(ChuCT.bai(t.bai, anh)) }
        if t.sapRaMat > 0 { phan.append(anh ? "\(t.sapRaMat) coming soon" : "\(t.sapRaMat) sắp ra mắt") }
        return phan.joined(separator: " · ")
    }

    // MARK: Nửa dưới — kỳ đang học / kế tiếp

    private func phanKy(_ k: KyHocCT, dangHoc: Bool, coGhiDanh: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(dangHoc ? T("Bạn đang ở") : (coGhiDanh ? T("Kỳ tiếp theo") : T("Bắt đầu từ")))
                    .foregroundColor(MauCT.muc3)
                Text(ChuCT.hocKy(k.so, anh))
                    .fontWeight(.semibold)
                    .foregroundColor(MauCT.nhan)
                    .monospacedDigit()
            }
            .font(.caption)
            Text(k.tenHien(anh))
                .font(ChuCTFont.serif(.headline))
                .foregroundColor(MauCT.muc)
                .multilineTextAlignment(.leading)
            HStack(alignment: .top, spacing: 6) {
                ForEach(k.mon.prefix(5)) { m in
                    VStack(spacing: 4) {
                        AnhBiaCT(url: m.thumbnailUrl, chuDuPhong: AnhBiaCT.chuCho(m, ten: m.ten(anh)), coChu: 8)
                        ZStack(alignment: .leading) {
                            Rectangle().fill(m.daGhiDanh ? MauCT.ke : Color.clear)
                            if m.daGhiDanh, let p = m.progress {
                                GeometryReader { g in
                                    Rectangle().fill(MauCT.nhan).frame(width: g.size.width * CGFloat(max(4, min(100, p))) / 100)
                                }
                            }
                        }
                        .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                }
                ForEach(0..<max(0, 5 - k.mon.count), id: \.self) { _ in Color.clear.frame(maxWidth: .infinity) }
            }
            HStack(spacing: 4) {
                Text(T("Xem kỳ này")).font(.footnote.weight(.semibold))
                Image(systemName: "arrow.right").font(.caption2.weight(.semibold))
            }
            .foregroundColor(MauCT.nhan)
        }
        .padding(Spacing.md)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(ChuCT.ky(k.so, anh)), \(k.tenHien(anh)), \(ChuCT.khoa(k.mon.count, anh))")
        .accessibilityHint(T("Mở chương trình tại học kỳ này"))
    }

    private func phanNganh(_ d: ChuongTrinhDaoTao) -> some View {
        let ds = d.cacNganh().prefix(6)
        return VStack(alignment: .leading, spacing: 8) {
            Text(T("Chuyên ngành")).font(.caption).foregroundColor(MauCT.muc3)
            FlowRow(spacing: 6) {
                ForEach(Array(ds)) { n in
                    Text("\(n.tenHien) \(n.so)")
                        .font(.footnote)
                        .foregroundColor(MauCT.muc2)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .overlay(Rectangle().stroke(MauCT.ke, lineWidth: 1))
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
