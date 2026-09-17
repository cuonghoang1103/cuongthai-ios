#if os(iOS)
import PencilKit
import SwiftData
import SwiftUI

/// Màn viết — mở toàn màn hình, không thanh tab, không thanh điều hướng của
/// app. Một cuốn vở mở ra thì cả màn hình là trang giấy.
struct ManVietView: View {
    @Bindable var cuon: CuonVo

    @Environment(\.dismiss) private var dong
    @Environment(\.modelContext) private var kho
    @Environment(\.horizontalSizeClass) private var beRong

    @State private var chiSo = 0
    @State private var hienDaiTrang = false
    @State private var hienCongCu = true
    @State private var cuaSo: CuaSoViet?
    /// Tăng mỗi lần lưu xong để dải trang vẽ lại ảnh thu nhỏ.
    @State private var lanLuu = 0

    private enum CuaSoViet: String, Identifiable {
        case doiGiay, datTenChuong
        var id: String { rawValue }
    }

    private var trangs: [TrangVo] { cuon.trangsTheoThuTu }
    private var trangHienTai: TrangVo? {
        guard trangs.indices.contains(chiSo) else { return trangs.first }
        return trangs[chiSo]
    }

    var body: some View {
        VStack(spacing: 0) {
            thanhTren
            Divider()
            HStack(spacing: 0) {
                if hienDaiTrang {
                    DaiTrang(trangs: trangs, chiSo: $chiSo, lanLuu: lanLuu,
                             themTrang: themTrang, xoaTrang: xoaTrang)
                        .frame(width: 128)
                        .background(AppColors.backgroundSecondary)
                    Divider()
                }
                khungViet
            }
        }
        .background(AppColors.backgroundPrimary)
        .ignoresSafeArea(.keyboard)
        .sheet(item: $cuaSo) { cua in
            switch cua {
            case .doiGiay:      DoiGiayView(trang: trangHienTai, cuon: cuon)
            case .datTenChuong: DatTenChuongView(trang: trangHienTai)
            }
        }
        .onAppear {
            // Mở lại cuốn vở là về đúng trang đang viết dở, không phải trang 1.
            chiSo = min(max(0, cuon.trangDangDoc), max(0, trangs.count - 1))
        }
        .onChange(of: chiSo) { _, moi in
            cuon.trangDangDoc = moi
        }
    }

    // MARK: Thanh trên

    private var thanhTren: some View {
        HStack(spacing: Spacing.md) {
            Button {
                // Đẩy TRƯỚC khi đóng: người dùng gập máy ngay sau khi bấm
                // Xong là chuyện thường, và vòng đồng bộ nền có thể không
                // kịp chạy.
                DongBoVo.shared.batDau()
                dong()
            } label: {
                Label(T("Xong"), systemImage: "chevron.left")
                    .labelStyle(.titleAndIcon)
            }
            .fontWeight(.semibold)

            HuyHieuDongBo()

            Button {
                withAnimation(AppAnimations.quick) { hienDaiTrang.toggle() }
            } label: {
                Image(systemName: hienDaiTrang ? "sidebar.left" : "sidebar.squares.left")
            }
            .accessibilityLabel(T("Dải trang"))

            VStack(spacing: 1) {
                Text(cuon.ten)
                    .font(Font.bodyMedium.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                if let t = trangHienTai, let ch = t.tenChuong, !ch.isEmpty {
                    Text(ch).font(.caption2).foregroundStyle(AppColors.textTertiary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)

            // Chuyển trang bằng nút. KHÔNG dùng vuốt ngang: cả bề mặt trang
            // đã thuộc về bút và về cử chỉ cuộn/phóng của khung vẽ, thêm một
            // cú vuốt nữa là lúc viết lúc lật trang.
            HStack(spacing: Spacing.xs) {
                Button { lui() } label: { Image(systemName: "chevron.left.circle") }
                    .disabled(chiSo <= 0)
                Text("\(chiSo + 1)/\(max(trangs.count, 1))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(minWidth: 44)
                Button { toi() } label: { Image(systemName: "chevron.right.circle") }
                    .disabled(chiSo >= trangs.count - 1)
            }

            Menu {
                Button { cuaSo = .doiGiay } label: {
                    Label(T("Đổi giấy trang này"), systemImage: "doc.plaintext")
                }
                Button { cuaSo = .datTenChuong } label: {
                    Label(T("Đặt tên chương"), systemImage: "bookmark")
                }
                Button { danhDau() } label: {
                    Label(trangHienTai?.danhDau == true ? T("Bỏ đánh dấu") : T("Đánh dấu trang"),
                          systemImage: trangHienTai?.danhDau == true ? "flag.slash" : "flag")
                }
                Divider()
                Button { hienCongCu.toggle() } label: {
                    Label(hienCongCu ? T("Ẩn bảng công cụ") : T("Hiện bảng công cụ"),
                          systemImage: "pencil.tip.crop.circle")
                }
                Divider()
                Button { themTrang() } label: {
                    Label(T("Thêm trang"), systemImage: "plus.rectangle.portrait")
                }
                Button { nhanBanTrang() } label: {
                    Label(T("Nhân bản trang"), systemImage: "doc.on.doc")
                }
                Button(role: .destructive) { xoaTrang(chiSo) } label: {
                    Label(T("Xoá trang"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .font(.system(size: 17))
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(AppColors.backgroundSecondary)
    }

    // MARK: Khung viết

    @ViewBuilder
    private var khungViet: some View {
        if let trang = trangHienTai {
            BangVe(idTrang: trang.id,
                   giay: trang.giay,
                   khoTrang: trang.khoTrang,
                   hienCongCu: hienCongCu,
                   khiLuu: { drawing in
                       trang.coNet = !drawing.strokes.isEmpty
                       trang.suaLuc = Date()
                       cuon.suaLuc = Date()
                       // Đánh dấu BẨN ở đây, không đẩy ngay: đẩy mỗi 2 giây
                       // là hàng trăm lượt ghi R2 một buổi học, mà hạn ghi
                       // miễn phí tính theo LƯỢT chứ không theo dung lượng.
                       // Lượt đẩy thật chạy lúc rời vở và lúc app xuống nền.
                       DongBoVo.danhDauBan(trang)
                       lanLuu += 1
                   })
            // ⚠️ `.id` BẮT BUỘC. Thiếu nó thì SwiftUI dùng lại đúng một bộ
            // điều khiển cho mọi trang, và sang trang 2 vẫn thấy nét của
            // trang 1 — cùng họ với lỗi TipTap không có `key` ở web.
            .id(trang.id)
        } else {
            VStack(spacing: Spacing.md) {
                Text(T("Cuốn vở này chưa có trang nào"))
                    .foregroundStyle(AppColors.textSecondary)
                Button(T("Thêm trang")) { themTrang() }.primaryButtonStyle()
                    .frame(maxWidth: 240)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Thao tác

    private func lui() { if chiSo > 0 { chiSo -= 1 } }
    private func toi() { if chiSo < trangs.count - 1 { chiSo += 1 } }

    private func themTrang() {
        let sau = trangs.count
        let t = TrangVo(cuon: cuon,
                        thuTu: sau,
                        giay: trangHienTai?.giay ?? LoaiGiay(rawValue: cuon.giayMacDinh) ?? .keNgang,
                        huong: trangHienTai?.huong ?? HuongGiay(rawValue: cuon.huongMacDinh) ?? .doc)
        kho.insert(t)
        cuon.suaLuc = Date()
        try? kho.save()
        chiSo = sau
    }

    private func nhanBanTrang() {
        guard let goc = trangHienTai else { return }
        let t = TrangVo(cuon: cuon, thuTu: goc.thuTu + 1, giay: goc.giay, huong: goc.huong)
        t.tenChuong = goc.tenChuong
        kho.insert(t)
        // Dồn thứ tự các trang phía sau LÊN trước khi chèn, nếu không hai
        // trang cùng `thuTu` và thứ tự hiện ra tuỳ lúc.
        for khac in trangs where khac.thuTu > goc.thuTu && khac.id != t.id {
            khac.thuTu += 1
        }
        try? kho.save()
        KhoVo.nhanBan(tu: goc.id, sang: t.id)
        t.coNet = goc.coNet
        chiSo = min(goc.thuTu + 1, cuon.trangsTheoThuTu.count - 1)
    }

    private func xoaTrang(_ i: Int) {
        let ds = trangs
        guard ds.indices.contains(i) else { return }
        // Cuốn vở phải luôn còn ít nhất một trang: xoá trang cuối cùng rồi để
        // lại cuốn vở rỗng là một trạng thái không lối ra trên màn viết.
        guard ds.count > 1 else { return }
        let t = ds[i]
        let id = t.id
        DongBoVo.ghiNhanXoa(kho: kho, maDoiTuong: id.uuidString, loai: "trang")
        kho.delete(t)
        for khac in ds where khac.thuTu > t.thuTu { khac.thuTu -= 1 }
        try? kho.save()
        KhoVo.xoa(id)
        chiSo = min(i, cuon.trangsTheoThuTu.count - 1)
        // Báo máy chủ NGAY, đừng đợi tới lúc rời vở: người dùng xoá xong có
        // thể đóng app luôn, và hàng đợi tuy bền nhưng không có lý do gì để
        // trang đã xoá còn nằm trên máy chủ thêm một phiên nữa.
        DongBoVo.shared.batDau()
    }

    private func danhDau() {
        guard let t = trangHienTai else { return }
        t.danhDau.toggle()
        t.suaLuc = Date()
    }
}

// MARK: - Dải trang bên trái

private struct DaiTrang: View {
    let trangs: [TrangVo]
    @Binding var chiSo: Int
    let lanLuu: Int
    let themTrang: () -> Void
    let xoaTrang: (Int) -> Void

    var body: some View {
        ScrollViewReader { cuon in
            ScrollView {
                LazyVStack(spacing: Spacing.sm) {
                    ForEach(Array(trangs.enumerated()), id: \.element.id) { i, trang in
                        Button { chiSo = i } label: {
                            OTrangNho(trang: trang, thuTu: i + 1,
                                      dangChon: i == chiSo, lanLuu: lanLuu)
                        }
                        .buttonStyle(.plain)
                        .id(i)
                        .contextMenu {
                            Button(role: .destructive) { xoaTrang(i) } label: {
                                Label(T("Xoá trang"), systemImage: "trash")
                            }
                        }
                    }
                    Button(action: themTrang) {
                        VStack(spacing: Spacing.xs) {
                            Image(systemName: "plus")
                            Text(T("Thêm")).font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .foregroundStyle(AppColors.textSecondary)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.small)
                                .strokeBorder(AppColors.border, style: StrokeStyle(lineWidth: 1, dash: [4]))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(Spacing.sm)
            }
            .onChange(of: chiSo) { _, moi in
                withAnimation(AppAnimations.quick) { cuon.scrollTo(moi, anchor: .center) }
            }
        }
    }
}

private struct OTrangNho: View {
    let trang: TrangVo
    let thuTu: Int
    let dangChon: Bool
    let lanLuu: Int

    @State private var anh: UIImage?

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(Color.white)
                if let anh {
                    Image(uiImage: anh)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                }
                if trang.danhDau {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(AppColors.warning)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .topTrailing)
                        .padding(4)
                }
            }
            .aspectRatio(trang.khoTrang.width / trang.khoTrang.height, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .strokeBorder(dangChon ? AppColors.primary : AppColors.border,
                                  lineWidth: dangChon ? 2 : 1)
            )
            Text("\(thuTu)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(dangChon ? AppColors.primary : AppColors.textTertiary)
        }
        .task(id: lanLuu) { napAnh() }
    }

    private func napAnh() {
        // Đọc ảnh thu nhỏ từ đĩa, KHÔNG dựng lại từ `PKDrawing`: dải trang
        // hiện chục trang một lúc, dựng lại từng cái là khựng ngay khi cuộn.
        anh = KhoVo.anhNho(trang.id)
    }
}

// MARK: - Đổi giấy

private struct DoiGiayView: View {
    let trang: TrangVo?
    let cuon: CuonVo
    @Environment(\.dismiss) private var dong
    @State private var apCaCuon = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(LoaiGiay.allCases) { g in
                        Button { chon(g) } label: {
                            HStack(spacing: Spacing.md) {
                                Image(systemName: g.bieuTuong).frame(width: 26)
                                    .foregroundStyle(trang?.giay == g ? AppColors.primary
                                                                      : AppColors.textSecondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(g.ten).foregroundStyle(AppColors.textPrimary)
                                    Text(g.moTa).font(.caption)
                                        .foregroundStyle(AppColors.textTertiary)
                                }
                                Spacer()
                                if trang?.giay == g {
                                    Image(systemName: "checkmark").foregroundStyle(AppColors.primary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Section {
                    Toggle(T("Áp cho cả cuốn vở"), isOn: $apCaCuon)
                } footer: {
                    Text(T("Đổi giấy KHÔNG xoá nét đã viết — chỉ đổi phần nền phía dưới."))
                }
            }
            .navigationTitle(T("Giấy"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Xong")) { dong() }.fontWeight(.semibold)
                }
            }
        }
    }

    private func chon(_ g: LoaiGiay) {
        if apCaCuon {
            cuon.giayMacDinh = g.rawValue
            for t in cuon.trangsTheoThuTu { t.loaiGiay = g.rawValue }
        } else {
            trang?.loaiGiay = g.rawValue
        }
        trang?.suaLuc = Date()
    }
}

// MARK: - Đặt tên chương

private struct DatTenChuongView: View {
    let trang: TrangVo?
    @Environment(\.dismiss) private var dong
    @State private var ten = ""
    @FocusState private var dangGo: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(T("Ví dụ: Chương 2 — Tích phân"), text: $ten)
                        .focused($dangGo)
                } footer: {
                    Text(T("Trang có tên chương sẽ hiện trong mục lục của cuốn vở. Để trống là bỏ đánh dấu chương."))
                }
            }
            .navigationTitle(T("Tên chương"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Huỷ")) { dong() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Lưu")) {
                        let t = ten.trimmingCharacters(in: .whitespacesAndNewlines)
                        trang?.tenChuong = t.isEmpty ? nil : t
                        trang?.suaLuc = Date()
                        dong()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                ten = trang?.tenChuong ?? ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { dangGo = true }
            }
        }
    }
}
#endif
