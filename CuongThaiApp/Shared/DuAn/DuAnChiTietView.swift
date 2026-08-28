import SwiftUI

/// Chi tiết dự án.
///
/// ⚠️ KHÔNG gọi API lần nữa. Endpoint danh sách đã trả về nguyên cả `bodyHtml`,
/// `milestones`, `features`, `resources`, `listItems` — tải lại là trả tiền
/// hai lần cho cùng một thứ (~70 KB mỗi dự án).
struct DuAnChiTietView: View {
    let duAn: DuAn
    @Binding var tiengAnh: Bool
    @State private var muc = 0
    @State private var vuaChep = false

    private var mau: Color { duAn.mauDanhMuc }

    private var cacMuc: [(String, Int)] {
        var m: [(String, Int)] = [(T("Tổng quan"), 0)]
        if !duAn.cacMoc.isEmpty { m.append((T("Lộ trình làm"), 1)) }
        if !duAn.cacTinhNang.isEmpty { m.append((T("Tính năng"), 2)) }
        if duAn.schema(tiengAnh) != nil { m.append(("Schema", 3)) }
        if !duAn.cacTaiNguyen.isEmpty { m.append((T("Tài nguyên"), 4)) }
        return m
    }

    var body: some View {
        ScrollViewReader { cuon in
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                NeoDauTrang()
                anhBia
                dauTrang
                if cacMuc.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.sm) {
                            ForEach(cacMuc, id: \.1) { m in
                                Button { withAnimation(.easeInOut(duration: 0.15)) { muc = m.1 }
                                         cuon.veDauTrang() } label: {
                                    Text(m.0)
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundColor(muc == m.1 ? AppColors.onPrimary : AppColors.textSecondary)
                                        .padding(.horizontal, Spacing.sm + 4).padding(.vertical, 6)
                                        .background(Capsule().fill(muc == m.1 ? mau : AppColors.backgroundTertiary))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                noiDung
                Color.clear.frame(height: 72)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
        }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(duAn.tua(tiengAnh))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { tiengAnh.toggle() } label: {
                    Text(tiengAnh ? "EN" : "VI").font(.system(size: 13, weight: .bold))
                }
            }
        }
    }

    // MARK: Ảnh bìa

    @ViewBuilder private var anhBia: some View {
        if let u = duAn.thumbnailUrl, let url = URL(string: u) {
            AsyncImage(url: url) { pha in
                switch pha {
                case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                case .failure: Rectangle().fill(mau.opacity(0.15))
                default: ZStack { Rectangle().fill(mau.opacity(0.10)); ProgressView() }
                }
            }
            .frame(height: 180)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        }
    }

    // MARK: Đầu trang

    private var dauTrang: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 5) {
                Label(duAn.category ?? "—", systemImage: duAn.bieuTuongDanhMuc)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(mau)
                    .padding(.horizontal, 7).padding(.vertical, 2.5)
                    .background(Capsule().fill(mau.opacity(0.15)))
                if let k = duAn.nhanDoKho {
                    Text(k)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(duAn.mauDoKho)
                        .padding(.horizontal, 7).padding(.vertical, 2.5)
                        .background(Capsule().fill(duAn.mauDoKho.opacity(0.15)))
                }
                Spacer(minLength: 0)
            }
            Text(duAn.tua(tiengAnh))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let m = duAn.moTa(tiengAnh), !m.isEmpty {
                Text(m)
                    .font(.system(size: 13.5))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: Spacing.md) {
                if let r = duAn.vaiTro(tiengAnh), !r.isEmpty { oNho("person", T("Vai trò"), r) }
                if let t = duAn.thoiLuong(tiengAnh), !t.isEmpty { oNho("clock", T("Thời lượng"), t) }
            }
            if !duAn.cacCongNghe.isEmpty {
                FlowChips(items: duAn.cacCongNghe, mau: mau)
            }
            HStack(spacing: Spacing.sm) {
                if let u = duAn.githubUrl, let url = URL(string: u) { nutLink("GitHub", "chevron.left.forwardslash.chevron.right", url) }
                if let u = duAn.projectUrl, let url = URL(string: u) { nutLink(T("Xem thật"), "arrow.up.right.square", url) }
                if let u = duAn.videoUrl, let url = URL(string: u) { nutLink("Video", "play.rectangle", url) }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    private func oNho(_ hinh: String, _ nhan: String, _ giaTri: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Label(nhan, systemImage: hinh)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
            Text(giaTri)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(2).multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func nutLink(_ nhan: String, _ hinh: String, _ url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 5) {
                Image(systemName: hinh).font(.system(size: 11))
                Text(nhan).font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(mau)
            .padding(.horizontal, Spacing.sm + 2).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 9).fill(mau.opacity(0.13)))
        }
    }

    // MARK: Nội dung theo mục

    @ViewBuilder private var noiDung: some View {
        switch muc {
        case 1: danhSachMoc
        case 2: danhSachTinhNang
        case 3: khoiSchema
        case 4: danhSachTaiNguyen
        default: tongQuan
        }
    }

    @ViewBuilder private var tongQuan: some View {
        // Ba nhóm `listItems` là phần "học được gì" — 786 mục trên 41 dự án.
        nhomMuc("CORE_KNOWLEDGE", T("Kiến thức cốt lõi"), "brain.head.profile")
        nhomMuc("COMPLETION_OUTCOME", T("Làm xong thì được gì"), "checkmark.seal")
        nhomMuc("PORTFOLIO_BONUS", T("Điểm cộng hồ sơ"), "sparkles")
        if let h = duAn.than(tiengAnh), !h.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                nhanMuc(T("Mô tả đầy đủ"), "doc.text")
                // `RichContent` tự đo chiều cao qua cầu JS; gọi thẳng
                // `RichContentView` thì phải tự giữ `@Binding chieuCao`.
                RichContent(html: h)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
        }
    }

    @ViewBuilder private func nhomMuc(_ loai: String, _ ten: String, _ hinh: String) -> some View {
        let ds = duAn.muc(loai)
        if !ds.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                nhanMuc("\(ten) (\(ds.count))", hinh)
                ForEach(ds) { m in
                    HStack(alignment: .top, spacing: 7) {
                        Circle().fill(mau).frame(width: 5, height: 5).padding(.top, 6)
                        Text(m.chu(tiengAnh))
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
        }
    }

    private var danhSachMoc: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(Array(duAn.cacMoc.enumerated()), id: \.element.id) { i, m in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text("\(i + 1)")
                            .font(.system(size: 10, weight: .heavy).monospacedDigit())
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(mau))
                        if let p = m.phase, !p.isEmpty {
                            Text(p)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(mau)
                                .padding(.horizontal, 5).padding(.vertical, 1.5)
                                .background(Capsule().fill(mau.opacity(0.15)))
                        }
                        Spacer(minLength: 0)
                    }
                    Text(m.tua(tiengAnh))
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let d = m.moTa(tiengAnh), !d.isEmpty {
                        Text(d)
                            .font(.system(size: 12.5))
                            .foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let c = m.codeBlock, !c.isEmpty { khoiMa(c, ten: m.codeLang) }
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
            }
        }
    }

    private var danhSachTinhNang: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(duAn.cacTinhNang) { f in
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16)).foregroundColor(mau)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.tua(tiengAnh))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let d = f.moTa(tiengAnh), !d.isEmpty {
                            Text(d)
                                .font(.system(size: 12.5))
                                .foregroundColor(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
            }
        }
    }

    @ViewBuilder private var khoiSchema: some View {
        if let c = duAn.schema(tiengAnh), !c.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                nhanMuc("Schema \(duAn.schemaLang?.uppercased() ?? "SQL")", "cylinder.split.1x2")
                khoiMa(c, ten: duAn.schemaLang)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
        }
    }

    private var danhSachTaiNguyen: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(duAn.cacTaiNguyen) { r in
                if let u = r.url, let url = URL(string: u) {
                    Link(destination: url) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: r.bieuTuong).font(.system(size: 14)).foregroundColor(mau)
                            Text(r.tua(tiengAnh))
                                .font(.system(size: 13.5))
                                .foregroundColor(AppColors.textPrimary)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .padding(Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
                    }
                }
            }
        }
    }

    // MARK: Mảnh dùng chung

    private func nhanMuc(_ ten: String, _ hinh: String) -> some View {
        Label(ten, systemImage: hinh)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(AppColors.textTertiary)
            .padding(.bottom, 2)
    }

    private func khoiMa(_ ma: String, ten: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let t = ten, !t.isEmpty {
                    Text(t.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.textTertiary)
                }
                Spacer()
                Button {
                    UIPasteboard.general.string = ma
                    vuaChep = true
                    Task { try? await Task.sleep(nanoseconds: 1_400_000_000); vuaChep = false }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: vuaChep ? "checkmark" : "doc.on.doc")
                        Text(vuaChep ? T("Đã chép") : T("Chép"))
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(vuaChep ? AppColors.success : mau)
                }
                .buttonStyle(.plain)
            }
            // ⚠️ `.fixedSize(horizontal: true, …)` là BẮT BUỘC — thiếu nó thì
            // `Text` tự cắt cụt dòng dài và vùng cuộn chẳng có gì để cuộn tới.
            ScrollView(.horizontal, showsIndicators: true) {
                Text(ma)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundColor(AppColors.textPrimary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.trailing, Spacing.sm)
            }
            .padding(Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(AppColors.backgroundTertiary.opacity(0.7)))
        }
    }
}

/// Hàng thẻ tự xuống dòng — danh sách công nghệ có dự án tới 15 mục, nhét vào
/// một `HStack` là tràn ra ngoài màn hình.
struct FlowChips: View {
    let items: [String]
    let mau: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(hang().enumerated()), id: \.offset) { _, h in
                HStack(spacing: 4) {
                    ForEach(h, id: \.self) { t in
                        Text(t)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.backgroundTertiary))
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    /// Chia hàng theo ước lượng bề rộng ký tự. Không cần chính xác tuyệt đối —
    /// chỉ cần không để một hàng dài quá màn hình.
    private func hang() -> [[String]] {
        var ra: [[String]] = [[]]
        var rong = 0.0
        for t in items {
            let w = Double(t.count) * 6.2 + 18
            if rong + w > 320, !ra[ra.count - 1].isEmpty { ra.append([]); rong = 0 }
            ra[ra.count - 1].append(t); rong += w + 4
        }
        return ra.filter { !$0.isEmpty }
    }
}
