#if os(iOS)
import PencilKit
import SwiftData
import SwiftUI

/// Màn viết — mở toàn màn hình, không thanh tab, không thanh điều hướng của
/// app. Một cuốn vở mở ra thì cả màn hình là trang giấy.
struct ManVietView: View {
    @Bindable var cuon: CuonVo
    /// Mở thẳng vào một trang cụ thể (từ kết quả tìm kiếm).
    var moTrang: UUID? = nil

    @Environment(\.dismiss) private var dong
    @Environment(\.modelContext) private var kho
    @Environment(\.horizontalSizeClass) private var beRong

    @State private var chiSo = 0
    @State private var hienDaiTrang = false
    @State private var hienCongCu = true
    @State private var cuaSo: CuaSoViet?
    /// Tăng mỗi lần lưu xong để dải trang vẽ lại ảnh thu nhỏ.
    @State private var lanLuu = 0
    /// Tăng mỗi lần người dùng xin đưa trang về vừa bề ngang khung.
    @State private var lanVuaKhung = 0
    /// Câu ngắn hiện thoáng qua giữa màn khi bóp bút.
    @State private var baoBut: String?
    @ObservedObject private var tieng = GhiAmBuoiHoc.shared
    @State private var chamDeTua = false
    /// Ngón tay để CUỘN thay vì vẽ. Nhớ giữa các lần mở vở.
    @AppStorage("vo.ngontay.cuon") private var nganTayCuon = false
    /// Cùng một khoá với `TroLyTrang` — bật/tắt ở menu thì con robot biết.
    @AppStorage(CaiDatTroLy.khoaHien) private var hienTroLy = true
    @AppStorage(CaiDatTroLy.khoaBopBut) private var bopGoiTroLy = false
    /// Tăng một nấc là xin con robot mở khung hỏi (bóp bút gọi).
    @State private var xinMoTroLy = 0


    /// ⚠️ MỘT `.sheet(item:)` cho mọi cửa sổ của màn này. Thêm cửa sổ mới thì
    /// thêm một `case` vào đây, KHÔNG dán thêm `.sheet(isPresented:)` thứ hai
    /// lên cùng một view — hai cái chồng nhau thì cái sau nuốt cái trước và
    /// một trong hai không bao giờ mở được.
    private enum CuaSoViet: String, Identifiable {
        case doiGiay, datTenChuong, quetTaiLieu, hoiNhapPdf, tomTat
        var id: String { rawValue }
    }
    @State private var dangChonPdf = false
    /// `ten` là tên tệp TRONG KHO (UUID), `tenHienThi` là tên gốc người dùng
    /// nhìn thấy — hiện UUID lên màn thì không ai biết mình vừa chọn tệp nào.
    @State private var pdfVuaChon: (ten: String, tenHienThi: String, soTrang: Int)?

    private var trangs: [TrangVo] { cuon.trangsTheoThuTu }
    private var trangHienTai: TrangVo? {
        guard trangs.indices.contains(chiSo) else { return trangs.first }
        return trangs[chiSo]
    }

    var body: some View {
        VStack(spacing: 0) {
            thanhTren
            if tieng.dangGhi || tieng.dangPhat || trangHienTai?.ghiAmTen != nil {
                thanhTieng
            }
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
        .overlay(alignment: .top) {
            if let baoBut {
                Text(baoBut)
                    .font(Font.bodyMedium.weight(.semibold))
                    .foregroundStyle(AppColors.onPrimary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(Capsule().fill(AppColors.primary.opacity(0.92)))
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(AppAnimations.quick, value: baoBut)
        // Trợ lý nằm TRÊN cùng, ngoài `khungViet`, để nó không bị khung vẽ
        // nuốt cử chỉ và không bị cuốn/phóng theo trang giấy.
        .overlay { TroLyTrang(trang: trangHienTai, tenCuon: cuon.ten, xinMo: xinMoTroLy) }
        .ignoresSafeArea(.keyboard)
        .sheet(item: $cuaSo) { cua in
            switch cua {
            case .doiGiay:      DoiGiayView(trang: trangHienTai, cuon: cuon)
            case .datTenChuong: DatTenChuongView(trang: trangHienTai)
            case .quetTaiLieu:
                MayQuetTaiLieu { anhs in themTrangTuAnh(anhs) }
                    .ignoresSafeArea()
            case .hoiNhapPdf:
                if let p = pdfVuaChon {
                    HoiNhapPdfView(tenTep: p.tenHienThi, soTrang: p.soTrang) { tu, den in
                        themTrangTuPdf(ten: p.ten, tu: tu, den: den)
                    }
                }
            case .tomTat:
                HoiVoAIView(tieuDe: T("Đề cương ôn thi"),
                            trangs: trangs,
                            moTaPhamVi: "\(T("cuốn")) “\(cuon.ten)”",
                            cauTuGui: T("Tóm tắt cuốn vở này thành một bản đề cương ôn thi: các chủ đề chính theo thứ tự, ý cốt lõi của từng chủ đề, công thức/định nghĩa cần thuộc, và cuối cùng 5 câu hỏi tự kiểm. Dẫn số trang cho từng mục."))
            }
        }
        .fileImporter(isPresented: $dangChonPdf, allowedContentTypes: [.pdf]) { ket in
            switch ket {
            case .success(let url):
                guard let ten = KhoVo.chepVaoKho(tu: url, duoi: "pdf") else {
                    bao(T("Không mở được tệp PDF này"))
                    return
                }
                let n = NenTrangView.soTrangPdf(ten: ten)
                guard n > 0 else { bao(T("Tệp PDF rỗng hoặc hỏng")); return }
                pdfVuaChon = (ten, url.lastPathComponent, n)
                cuaSo = .hoiNhapPdf
            case .failure(let e):
                bao(e.localizedDescription)
            }
        }
        .onAppear {
            // Từ tìm kiếm thì vào thẳng trang đó; không thì về trang đang
            // viết dở, không phải trang 1.
            if let moTrang, let i = trangs.firstIndex(where: { $0.id == moTrang }) {
                chiSo = i
            } else {
                chiSo = min(max(0, cuon.trangDangDoc), max(0, trangs.count - 1))
            }
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

            // ⚠️ MỌI mục phải nằm trong `Section`. `Menu { }` là một
            // ViewBuilder, mà ViewBuilder chỉ nhận TỐI ĐA 10 phần tử con trực
            // tiếp — dư ra thì trình biên dịch KHÔNG báo gì và SwiftUI lặng lẽ
            // vứt phần thừa lúc vẽ. Menu này từng có 19 con: nó dựng xanh,
            // chạy được, và cụt ngay sau "Ẩn bảng công cụ" — mất trắng "Thêm
            // trang", "Nhân bản trang", "Xoá trang" và cả hai mục trợ lý.
            //
            // Đây chính là thứ người dùng báo 18/09/2026 ("bóp bút không thấy
            // gì" — vì không bật được) và, nhìn lại, cũng là một nửa của báo
            // cáo cũ "các nút xoá trang không thấy hoạt động": nút không phải
            // bấm-không-ăn, nút KHÔNG CÓ Ở ĐÓ.
            //
            // Mỗi `Section` là MỘT con, và còn tự kẻ vạch ngăn nên bỏ được
            // đống `Divider()` thủ công. Thêm mục mới thì thêm vào một
            // Section, đừng thêm thẳng vào `Menu`.
            // ⚠️ Nút này phải NẰM NGOÀI, không nhét vào menu ⋯.
            //
            // Người dùng 18/09/2026: nhập PDF vào, trang dài hơn màn hình,
            // vuốt một ngón để đọc tiếp thì nó VẼ một vệt mực, trang đứng im
            // — tưởng app treo. Hai ngón vẫn cuộn được ở mọi chế độ, nhưng
            // không ai đoán ra. Một cái nút thấy ngay giải quyết cả hai:
            // nói cho người dùng biết là CÓ hai chế độ, và đổi trong một chạm.
            Button {
                nganTayCuon.toggle()
                bao(nganTayCuon ? T("Ngón tay: CUỘN trang — chỉ bút mới viết")
                                : T("Ngón tay: VIẾT — hai ngón để cuộn"))
                Haptics.cham()
            } label: {
                Image(systemName: nganTayCuon ? "hand.draw" : "pencil.and.scribble")
                    .foregroundStyle(nganTayCuon ? AppColors.primary : AppColors.textPrimary)
            }
            .accessibilityLabel(nganTayCuon ? T("Ngón tay đang cuộn trang")
                                            : T("Ngón tay đang viết"))

            Menu {
                Section {
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
                    if tieng.dangGhi {
                        Button { dungGhi() } label: {
                            Label(T("Dừng ghi âm"), systemImage: "stop.circle")
                        }
                    } else {
                        Button { batGhi() } label: {
                            Label(T("Ghi âm buổi học"), systemImage: "mic.circle")
                        }
                    }
                }

                Section {
                    Button { cuaSo = .tomTat } label: {
                        Label(T("Tóm tắt cuốn này thành đề cương"), systemImage: "list.bullet.rectangle")
                    }
                    // Chỉ iPad mới có trợ lý nổi — trên iPhone khung hỏi che
                    // gần hết trang giấy. Ẩn luôn nút để không hứa thứ không có.
                    if CaiDatTroLy.chayDuoc {
                        Button { hienTroLy.toggle() } label: {
                            Label(hienTroLy ? T("Ẩn trợ lý trang") : T("Hiện trợ lý trang"),
                                  systemImage: hienTroLy ? "sparkles.slash" : "sparkles")
                        }
                        // Mặc định TẮT. Bóp bút vốn đang là việc hệ thống gán
                        // (bảng công cụ / tẩy), cướp nó mà không hỏi là lấy
                        // mất một thao tác người dùng đang dùng hằng ngày.
                        Button { bopGoiTroLy.toggle() } label: {
                            Label(bopGoiTroLy ? T("Bóp bút: trả về việc hệ thống")
                                              : T("Bóp bút để gọi trợ lý"),
                                  systemImage: "hand.pinch")
                        }
                        .disabled(!hienTroLy)
                    }
                }

                Section {
                    Button { dangChonPdf = true } label: {
                        Label(T("Nhập PDF để viết đè"), systemImage: "doc.badge.plus")
                    }
                    Button { cuaSo = .quetTaiLieu } label: {
                        Label(T("Quét trang sách bằng camera"), systemImage: "doc.viewfinder")
                    }
                    if trangHienTai?.nenPdfTen != nil || trangHienTai?.nenAnhTen != nil {
                        Button(role: .destructive) { goNen() } label: {
                            Label(T("Gỡ nền tài liệu của trang này"), systemImage: "rectangle.slash")
                        }
                    }
                }

                Section {
                    Button { lanVuaKhung += 1 } label: {
                        Label(T("Trang vừa bề ngang"), systemImage: "arrow.left.and.right.square")
                    }
                    Button { hienCongCu.toggle() } label: {
                        Label(hienCongCu ? T("Ẩn bảng công cụ") : T("Hiện bảng công cụ"),
                              systemImage: "pencil.tip.crop.circle")
                    }
                }

                Section {
                    Button { themTrang() } label: {
                        Label(T("Thêm trang"), systemImage: "plus.rectangle.portrait")
                    }
                    Button { nhanBanTrang() } label: {
                        Label(T("Nhân bản trang"), systemImage: "doc.on.doc")
                    }
                    // ⚠️ `disabled` + nhãn nói LÝ DO. Bản trước chặn xoá trang
                    // cuối bằng một `guard ... else { return }` im lặng: người
                    // dùng bấm, không có gì xảy ra, không có lời giải thích.
                    Button(role: .destructive) { xoaTrang(chiSo) } label: {
                        Label(trangs.count > 1 ? T("Xoá trang")
                                               : T("Xoá trang (vở phải còn ít nhất 1 trang)"),
                              systemImage: "trash")
                    }
                    .disabled(trangs.count <= 1)
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

    // MARK: Thanh ghi âm

    @ViewBuilder
    private var thanhTieng: some View {
        HStack(spacing: Spacing.md) {
            if tieng.dangGhi {
                Circle().fill(AppColors.error).frame(width: 10, height: 10)
                    .opacity(0.9)
                Text("\(T("Đang ghi")) \(GhiAmBuoiHoc.doDaiChu(tieng.giay))")
                    .font(Font.bodyMedium.monospacedDigit())
                    .foregroundStyle(AppColors.error)
                Spacer()
                Button { dungGhi() } label: {
                    Label(T("Dừng"), systemImage: "stop.circle.fill")
                }
                .fontWeight(.semibold)
            } else if let t = trangHienTai, let _ = t.ghiAmTen {
                Image(systemName: tieng.dangPhat ? "waveform" : "waveform.circle")
                    .foregroundStyle(AppColors.primary)
                Text(tieng.dangPhat
                     ? GhiAmBuoiHoc.doDaiChu(tieng.giay)
                     : "\(T("Bản ghi")) \(GhiAmBuoiHoc.doDaiChu(t.ghiAmDai))")
                    .font(Font.bodyMedium.monospacedDigit())
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                Toggle(isOn: $chamDeTua) {
                    Label(T("Chạm chữ để nghe"), systemImage: "hand.tap")
                }
                .toggleStyle(.button)
                .font(Font.bodyMedium)
                if tieng.dangPhat {
                    Button { tieng.dungPhat() } label: {
                        Image(systemName: "stop.circle")
                    }
                } else {
                    Button { tieng.phat(ten: t.ghiAmTen!) } label: {
                        Image(systemName: "play.circle")
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(AppColors.backgroundSecondary)
    }

    private func batGhi() {
        guard let t = trangHienTai else { return }
        Task {
            let (ten, loi) = await tieng.batDau(choTrang: t.id)
            if let loi { bao(loi); return }
            guard let ten else { return }
            t.ghiAmTen = ten
            // Nét đã có trước khi bấm ghi thì không có mốc — đánh dấu -1 để
            // chạm vào chúng nói "viết lúc chưa ghi âm" thay vì tua về 0:00.
            t.mocNet = Array(repeating: -1, count: soNetHienCo(t))
            bao(T("Bắt đầu ghi âm buổi học"))
        }
    }

    private func dungGhi() {
        guard let ket = tieng.dung(), let t = trangHienTai else { return }
        t.ghiAmTen = ket.ten
        t.ghiAmDai = ket.dai
        t.suaLuc = Date()
        try? kho.save()
        bao("\(T("Đã ghi")) \(GhiAmBuoiHoc.doDaiChu(ket.dai))")
        DongBoVo.shared.batDau()
    }

    private func soNetHienCo(_ t: TrangVo) -> Int {
        KhoVo.nap(t.id).strokes.count
    }

    // MARK: Khung viết

    @ViewBuilder
    private var khungViet: some View {
        if let trang = trangHienTai {
            BangVe(idTrang: trang.id,
                   giay: trang.giay,
                   khoTrang: trang.khoTrang,
                   nenPdfTen: trang.nenPdfTen,
                   nenPdfTrang: trang.nenPdfTrang,
                   nenAnhTen: trang.nenAnhTen,
                   hienCongCu: hienCongCu,
                   lanVuaKhung: lanVuaKhung,
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
                   },
                   khiThemNet: { soNet in
                       // Gắn mốc cho nét VỪA viết, chỉ khi đang ghi âm đúng
                       // trang này. Mảng mốc đi song song với mảng nét nên
                       // phải bù cho đủ dài khi có nét vẽ lúc chưa ghi âm.
                       guard tieng.dangGhi, tieng.idTrangDangGhi == trang.id else { return }
                       var m = trang.mocNet
                       while m.count < soNet - 1 { m.append(-1) }
                       m.append(tieng.giayHienTai)
                       trang.mocNet = m
                   },
                   khiChamNet: { i in
                       guard let ten = trang.ghiAmTen else { return }
                       let moc = trang.mocNet.indices.contains(i) ? trang.mocNet[i] : -1
                       guard moc >= 0 else {
                           bao(T("Nét này viết lúc chưa ghi âm"))
                           return
                       }
                       // Lùi 2 giây: câu giảng thường bắt đầu TRƯỚC lúc tay
                       // bắt đầu viết, nhảy đúng mốc là vào giữa câu.
                       tieng.phat(ten: ten, tuGiay: max(0, moc - 2))
                       bao("▶︎ " + GhiAmBuoiHoc.doDaiChu(max(0, moc - 2)))
                   },
                   chamDeTua: chamDeTua,
                   nganTayCuon: nganTayCuon,
                   khiBaoBut: { cau in
                       baoBut = cau
                       // Tự tắt sau 1,2 giây — lời xác nhận thoáng qua, không
                       // phải thông báo bắt người dùng bấm mới mất.
                       Task {
                           try? await Task.sleep(for: .seconds(1.2))
                           if baoBut == cau { baoBut = nil }
                       }
                   },
                   bopGoiTroLy: {
                       NhatKy.vo.info("vở: dựng BangVe · hienTroLy=\(hienTroLy) bopGoiTroLy=\(bopGoiTroLy)")
                       return hienTroLy && bopGoiTroLy
                   }(),
                   khiBopGoiTroLy: { xinMoTroLy += 1 })
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

    /// Mỗi trang PDF thành MỘT trang vở, chèn ngay sau trang hiện tại.
    private func themTrangTuPdf(ten: String, tu: Int, den: Int) {
        // Khổ trang lấy theo PDF gốc: ép slide 16:9 vào A4 dọc thì chữ bé
        // tí và thừa hai mảng trắng hai bên.
        // ⚠️ KHÔNG đặt tên biến này là `kho`: đã có `@Environment(\.modelContext)
        // var kho`, và biến cục bộ che nó đi làm `kho.insert` gọi vào CGSize.
        let khoGiay = NenTrangView.khoTrangPdf(ten: ten, trang: tu - 1)
        let huong: HuongGiay = (khoGiay.map { $0.width > $0.height } ?? false) ? .ngang : .doc
        var sau = (trangHienTai?.thuTu ?? -1) + 1
        let daCo = trangs
        for i in tu...den {
            let t = TrangVo(cuon: cuon, thuTu: sau, giay: .trang, huong: huong)
            t.nenPdfTen = ten
            t.nenPdfTrang = i - 1
            kho.insert(t)
            for khac in daCo where khac.thuTu >= sau { khac.thuTu += 1 }
            sau += 1
        }
        cuon.suaLuc = Date()
        try? kho.save()
        chiSo = min((trangHienTai?.thuTu ?? 0) + 1, cuon.trangsTheoThuTu.count - 1)
        bao("\(T("Đã nhập")) \(den - tu + 1) \(T("trang"))")
        DongBoVo.shared.batDau()
    }

    private func themTrangTuAnh(_ anhs: [Data]) {
        guard !anhs.isEmpty else { return }
        var sau = (trangHienTai?.thuTu ?? -1) + 1
        let daCo = trangs
        for d in anhs {
            guard let ten = KhoVo.luuAnhNen(d) else { continue }
            let t = TrangVo(cuon: cuon, thuTu: sau, giay: .trang, huong: .doc)
            t.nenAnhTen = ten
            kho.insert(t)
            for khac in daCo where khac.thuTu >= sau { khac.thuTu += 1 }
            sau += 1
        }
        cuon.suaLuc = Date()
        try? kho.save()
        chiSo = min((trangHienTai?.thuTu ?? 0) + 1, cuon.trangsTheoThuTu.count - 1)
        bao("\(T("Đã thêm")) \(anhs.count) \(T("trang quét"))")
        DongBoVo.shared.batDau()
    }

    /// Gỡ nền, GIỮ NGUYÊN nét đã viết — nét nằm ở lớp riêng.
    private func goNen() {
        trangHienTai?.nenPdfTen = nil
        trangHienTai?.nenAnhTen = nil
        trangHienTai?.suaLuc = Date()
        bao(T("Đã gỡ nền — nét viết vẫn còn"))
    }

    private func bao(_ s: String) {
        baoBut = s
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            if baoBut == s { baoBut = nil }
        }
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
