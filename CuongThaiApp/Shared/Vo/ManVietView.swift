#if os(iOS)
import PencilKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

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
    @AppStorage(CaiDatTroLy.khoaBopBut) private var bopGoiTroLy = true
    /// Tăng một nấc là xin con robot mở khung hỏi (bóp bút gọi).
    @State private var xinMoTroLy = 0
    /// Tăng một nấc = vào thẳng khoanh vùng hỏi AI.
    @State private var xinKhoanh = 0
    /// Đang ở chế độ bút-hỏi-AI: lớp phủ khoanh đang phủ lên trang.
    @State private var dangKhoanhTrang = false
    /// Đang khoanh vùng để LÀM GỌN (cùng lớp khoanh với hỏi AI, khác việc).
    @State private var khoanhDeLamGon = false
    /// Vùng vừa cắt từ màn hình, chờ trợ lý hỏi.
    @State private var vungVuaCat: AnhVungCat?
    @StateObject private var cauNoiVe = CauNoiBangVe()
    /// Tự nối dài trang khi viết tới gần đáy. Cùng khoá với cửa sổ Khổ giấy.
    @AppStorage(CaiDatKhoTrang.khoaTuNoiDai) private var tuNoiDai = true
    /// Tăng một nấc = đưa CẢ trang vào khung (xem toàn cảnh trang dài).
    @State private var lanVuaCaTrang = 0
    /// Nhãn gợi ý của hình AI vừa vẽ lên trang — người học tự viết vào.
    @State private var nhanGoiY: [String] = []
    /// Đang vẽ dần một hình AI — chặn vẽ chồng hình thứ hai lúc chưa xong.
    @State private var dangVeAI = false
    @Environment(\.accessibilityReduceMotion) private var giamChuyenDong


    /// ⚠️ MỘT `.sheet(item:)` cho mọi cửa sổ của màn này. Thêm cửa sổ mới thì
    /// thêm một `case` vào đây, KHÔNG dán thêm `.sheet(isPresented:)` thứ hai
    /// lên cùng một view — hai cái chồng nhau thì cái sau nuốt cái trước và
    /// một trong hai không bao giờ mở được.
    private enum CuaSoViet: Identifiable {
        case doiGiay, datTenChuong, quetTaiLieu, hoiNhapPdf, tomTat, tongQuan, khoGiay
        case chuyenCuon([UUID])
        case xuatPdf([UUID], String)
        /// Làm gọn chữ trang đang mở; kèm vùng khoanh (toạ độ trang) nếu có.
        case lamGon(CGRect?)
        var id: String {
            switch self {
            case .lamGon: return "lamGon"
            case .khoGiay: return "khoGiay"
            case .doiGiay: return "doiGiay"
            case .datTenChuong: return "datTenChuong"
            case .quetTaiLieu: return "quetTaiLieu"
            case .hoiNhapPdf: return "hoiNhapPdf"
            case .tomTat: return "tomTat"
            case .tongQuan: return "tongQuan"
            case .chuyenCuon(let d): return "chuyen-" + d.map(\.uuidString).joined()
            case .xuatPdf(let d, _): return "xuat-" + d.map(\.uuidString).joined()
            }
        }
    }
    /// Trang ĐANG MỞ theo id. `chiSo` là vị trí, mà vị trí đổi mỗi khi sắp
    /// xếp/chèn/xoá — chỉ giữ vị trí thì kéo trang 4 lên đầu là màn viết tự
    /// nhảy sang trang khác dưới tay người dùng.
    @State private var idHienTai: UUID?
    @State private var trangDoiTen: TrangVo?
    @State private var tenDangGo = ""
    @State private var xacNhanXoa: [TrangVo]?
    @State private var baoHoanTac: BaoHoanTac?
    @State private var dangKeoTrang: UUID?
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
                             dangKeo: $dangKeoTrang,
                             themTrang: themTrang,
                             moTongQuan: { cuaSo = .tongQuan },
                             lam: lam,
                             dat: { id, dich in
                                 guard let t = trangs.first(where: { $0.id == id }) else { return }
                                 ThaoTacTrang.datVaoCho(t, choCua: dich, trongCuon: cuon, kho: kho)
                             })
                        .frame(width: 128)
                        .background(AppColors.backgroundSecondary)
                    Divider()
                }
                khungViet
                    // ⚠️ Lớp khoanh gắn vào ĐÚNG khung vẽ, không gắn ở gốc màn.
                    // Ảnh chụp lấy từ `canvas.bounds`; lớp phủ ở gốc thì gốc
                    // toạ độ của nó là đỉnh MÀN HÌNH, lệch đúng chiều cao
                    // thanh trên — khoanh một chữ sẽ cắt trúng thứ nằm cao
                    // hơn nó cả trăm điểm. Gắn đúng chỗ thì hai hệ toạ độ
                    // trùng nhau, không phải bù trừ bằng hằng số đoán.
                    .overlay {
                        if dangKhoanhTrang {
                            LopKhoanhTrenTrang(khiXong: { k in catVung(k) },
                                               khiHuy: { dangKhoanhTrang = false })
                        } else if khoanhDeLamGon {
                            LopKhoanhTrenTrang(loiNhac: T("Khoanh vùng chữ cần làm gọn"),
                                               loiThaTay: T("Thả tay ra để xem trước"),
                                               bieuTuong: "wand.and.stars",
                                               khiXong: { k in khoanhXongLamGon(k) },
                                               khiHuy: { khoanhDeLamGon = false })
                        }
                    }
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
        .overlay(alignment: .bottom) {
            if let b = baoHoanTac {
                DaiHoanTac(bao: b) { hoanTacXoa(b) }
            }
        }
        .animation(AppAnimations.quick, value: baoHoanTac)
        .confirmationDialog(
            xacNhanXoa.map { $0.count == 1 ? T("Xoá trang này?") : "\(T("Xoá")) \($0.count) \(T("trang?"))" } ?? "",
            isPresented: Binding(get: { xacNhanXoa != nil }, set: { if !$0 { xacNhanXoa = nil } }),
            titleVisibility: .visible
        ) {
            Button(T("Xoá"), role: .destructive) {
                if let ds = xacNhanXoa { xoaThat(ds) }
                xacNhanXoa = nil
            }
            Button(T("Huỷ"), role: .cancel) { xacNhanXoa = nil }
        } message: {
            Text(T("Bấm Hoàn tác ngay sau đó để lấy lại. Trên máy chủ trang nằm trong thùng rác 30 ngày."))
        }
        // Trợ lý nằm TRÊN cùng, ngoài `khungViet`, để nó không bị khung vẽ
        // nuốt cử chỉ và không bị cuốn/phóng theo trang giấy.
        .overlay {
            TroLyTrang(trang: trangHienTai, tenCuon: cuon.ten,
                       xinMo: xinMoTroLy, xinKhoanh: xinKhoanh,
                       vungNgoai: $vungVuaCat,
                       chenHinhVe: { veHinhAI($0) })
        }
        // Nhãn gợi ý của hình AI vừa vẽ: người học TỰ viết vào hình.
        .overlay(alignment: .topLeading) {
            if !nhanGoiY.isEmpty {
                TheNhanGoiY(nhan: nhanGoiY) { nhanGoiY = [] }
                    .padding(.top, 64)
                    .padding(.leading, Spacing.md + (hienDaiTrang ? 128 : 0))
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(AppAnimations.quick, value: nhanGoiY)
        // Nút bút AI đứng cạnh bảng công cụ, đúng chỗ người dùng xin.
        .overlay(alignment: .bottomTrailing) {
            if CaiDatTroLy.chayDuoc && hienTroLy && !dangKhoanhTrang {
                NutButAI(dangBat: dangKhoanhTrang) { batKhoanhTrang() }
                    .padding(.trailing, Spacing.lg)
                    .padding(.bottom, 108)
            }
        }
        .ignoresSafeArea(.keyboard)
        .sheet(item: $cuaSo) { cua in
            switch cua {
            case .doiGiay:      DoiGiayView(trang: trangHienTai, cuon: cuon)
            case .khoGiay:
                KhoGiayCuonView(cuon: cuon, trang: trangHienTai,
                                luuTruoc: { cauNoiVe.luuNgay() },
                                bao: { bao($0) })
                .modifier(CoTrangLon())
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
            case .tongQuan:
                TongQuanTrangView(cuon: cuon, idDangMo: trangHienTai?.id, lanLuu: lanLuu) { id in
                    moTheoId(id)
                }
            case .chuyenCuon(let ids):
                ChonCuonView(boQua: cuon.id) { dich in
                    let ds = trangs.filter { ids.contains($0.id) }
                    if ThaoTacTrang.chuyen(ds, sang: dich, kho: kho) {
                        bao("\(T("Đã chuyển sang")) “\(dich.ten)”")
                        Haptics.xong()
                    } else {
                        bao(T("Không chuyển được — vở phải còn ít nhất 1 trang"))
                    }
                }
            case .xuatPdf(let ids, let ten):
                XuatPdfView(trangs: trangs.filter { ids.contains($0.id) }, tenTep: ten)
            case .lamGon(let vung):
                if let t = trangHienTai {
                    LamGonView(idTrang: t.id, goc: banVeDangMo(t), giay: t.giay,
                               khoTrang: t.khoTrang, caoGoc: t.khoGoc.height, vung: vung) { moi in
                        apDungLamGon(moi, cho: t)
                    }
                    .presentationDetents([.large])
                }
            case .tomTat:
                HoiVoAIView(tieuDe: T("Đề cương ôn thi"),
                            trangs: trangs,
                            moTaPhamVi: "\(T("cuốn")) “\(cuon.ten)”",
                            cauTuGui: T("Tóm tắt cuốn vở này thành một bản đề cương ôn thi: các chủ đề chính theo thứ tự, ý cốt lõi của từng chủ đề, công thức/định nghĩa cần thuộc, và cuối cùng 5 câu hỏi tự kiểm. Dẫn số trang cho từng mục."))
            }
        }
        // Cho chọn NHIỀU tệp: một môn học thường có cả thư mục PDF (13 tệp
        // giáo trình JPD123 chẳng hạn). Nhập từng cái là lặp lại 3 thao tác
        // mười ba lần.
        .fileImporter(isPresented: $dangChonPdf, allowedContentTypes: [.pdf],
                      allowsMultipleSelection: true) { ket in
            switch ket {
            case .success(let urls): nhanPdf(urls)
            case .failure(let e):    bao(e.localizedDescription)
            }
        }
        // Thả PDF hoặc ảnh từ Files / Split View thẳng vào trang đang mở.
        // Trên iPad đây là đường tự nhiên hơn hẳn nút nhập → duyệt thư mục,
        // nhất là khi giáo trình đang mở sẵn ở cửa sổ bên cạnh.
        .dropDestination(for: URL.self) { ds, _ in nhanTepTha(ds) }
        .onAppear {
            // Từ tìm kiếm thì vào thẳng trang đó; không thì về trang đang
            // viết dở, không phải trang 1.
            if let moTrang, let i = trangs.firstIndex(where: { $0.id == moTrang }) {
                chiSo = i
            } else {
                chiSo = min(max(0, cuon.trangDangDoc), max(0, trangs.count - 1))
            }
            idHienTai = trangHienTai?.id
        }
        #if DEBUG
        .task { await thuLamGonTuDong() }
        .task { await thuKhoTrangTuDong() }
        #endif
        .onChange(of: chiSo) { _, moi in
            cuon.trangDangDoc = moi
            idHienTai = trangHienTai?.id
        }
        // Thứ tự trang đổi (kéo xếp, chèn, xoá, chuyển đi) ⇒ bám theo ĐÚNG
        // trang đang mở, không bám theo vị trí cũ.
        .onChange(of: trangs.map(\.id)) { _, ds in
            if let id = idHienTai, let i = ds.firstIndex(of: id) {
                if i != chiSo { chiSo = i }
            } else {
                chiSo = min(chiSo, max(0, ds.count - 1))
                idHienTai = trangHienTai?.id
            }
        }
        // Phím tắt bàn phím iPad (Magic Keyboard). Nút ẩn: có mặt trong cây
        // view là phím tắt sống, và hiện trong bảng ⌘ giữ lâu.
        .background {
            Group {
                Button(T("Trang trước")) { lui() }.keyboardShortcut(.leftArrow, modifiers: .command)
                Button(T("Trang sau")) { toi() }.keyboardShortcut(.rightArrow, modifiers: .command)
                Button(T("Thêm trang sau trang này")) { chenSauHienTai() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button(T("Nhân bản trang")) { nhanBanTrang() }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                Button(T("Đổi tên trang")) { if let t = trangHienTai { lam(.doiTen, t) } }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Button(T("Các trang")) { cuaSo = .tongQuan }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                // ⌘Z / ⇧⌘Z KHÔNG đặt ở đây: khung vẽ là first responder và
                // UIKit đã tự nối hai phím đó vào `undoManager` của nó. Đặt
                // thêm là một lần bấm hoàn tác HAI nét.
            }
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// Nhập cả một loạt PDF, mỗi tệp lấy TRỌN các trang.
    ///
    /// Không hỏi khoảng trang nữa: chọn nhiều tệp nghĩa là "đổ hết giáo
    /// trình vào đây", hỏi từng tệp một lại thành mười ba hộp thoại.
    /// Nhận một hoặc nhiều PDF — dùng chung cho nút nhập và cho cú THẢ.
    ///
    /// Tách ra vì hai lối vào phải xử lý y hệt: cùng chép vào kho, cùng đếm
    /// trang, cùng bắt tệp rỗng. Viết hai bản thì sớm muộn một bên thiếu một
    /// bước, và bên thiếu sẽ là bên ít dùng hơn nên lỗi nằm đó rất lâu.
    private func nhanPdf(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        if urls.count == 1, let url = urls.first {
            // Một tệp thì vẫn hỏi khoảng trang như cũ — người dùng hay chỉ
            // cần vài trang giữa cuốn.
            guard let ten = KhoVo.chepVaoKho(tu: url, duoi: "pdf") else {
                bao(T("Không mở được tệp PDF này")); return
            }
            let n = NenTrangView.soTrangPdf(ten: ten)
            guard n > 0 else { bao(T("Tệp PDF rỗng hoặc hỏng")); return }
            pdfVuaChon = (ten, url.lastPathComponent, n)
            cuaSo = .hoiNhapPdf
        } else {
            nhapNhieuPdf(urls)
        }
    }

    /// Xử lý một cú thả: PDF đi đường nhập PDF, ảnh thành trang mới.
    ///
    /// ⚠️ Ảnh phải ĐỌC NGAY trong hàm này. URL của cú thả trỏ vào một bản
    /// tạm mà hệ thống dọn ngay sau khi hàm trả về — giữ URL rồi đọc sau là
    /// nhận về tệp không tồn tại, mà lúc đó không còn gì để lần ra vì sao.
    private func nhanTepTha(_ ds: [URL]) -> Bool {
        let anhDuoi = ["png", "jpg", "jpeg", "heic", "heif", "gif", "tiff", "bmp"]
        let pdfs = ds.filter { $0.pathExtension.lowercased() == "pdf" }
        let anhs = ds.filter { anhDuoi.contains($0.pathExtension.lowercased()) }
        guard !pdfs.isEmpty || !anhs.isEmpty else {
            bao(T("Chỉ thả được tệp PDF hoặc ảnh"))
            return false
        }
        if !pdfs.isEmpty { nhanPdf(pdfs) }
        if !anhs.isEmpty {
            // Giữ nguyên byte gốc, không giải mã ra `UIImage` rồi mã hoá
            // lại: đi vòng đó làm mất chất lượng và xoay ảnh sai theo EXIF.
            let dus: [Data] = anhs.compactMap { u in
                let mo = u.startAccessingSecurityScopedResource()
                defer { if mo { u.stopAccessingSecurityScopedResource() } }
                return try? Data(contentsOf: u)
            }
            if dus.isEmpty { bao(T("Không đọc được ảnh vừa thả")) }
            else { themTrangTuAnh(dus) }
        }
        return true
    }

    private func nhapNhieuPdf(_ urls: [URL]) {
        var soTep = 0, soTrang = 0
        for url in urls {
            guard let ten = KhoVo.chepVaoKho(tu: url, duoi: "pdf") else { continue }
            let n = NenTrangView.soTrangPdf(ten: ten)
            guard n > 0 else { continue }
            themTrangTuPdf(ten: ten, tu: 0, den: n - 1)
            soTep += 1
            soTrang += n
        }
        if soTep == 0 {
            bao(T("Không nhập được tệp nào"))
        } else {
            bao("\(T("Đã nhập")) \(soTep) \(T("tệp")) · \(soTrang) \(T("trang"))")
            Haptics.xong()
        }
    }

    // MARK: Khoanh hỏi AI

    private func batKhoanhTrang() {
        guard !dangKhoanhTrang else { return }
        dangKhoanhTrang = true
        bao(T("Khoanh tròn chỗ cần hỏi"))
        Haptics.cham()
    }

    /// Cắt đúng vùng vừa khoanh RA KHỎI ảnh màn hình đang hiển thị.
    ///
    /// ⚠️ Tắt lớp phủ TRƯỚC khi chụp. Chụp lúc lớp phủ còn trên màn thì vòng
    /// khoanh và thanh nhắc lọt vào ảnh gửi cho AI.
    private func catVung(_ khung: CGRect) {
        dangKhoanhTrang = false
        // Một vòng chạy màn hình để lớp phủ kịp biến mất khỏi cây hiển thị.
        DispatchQueue.main.async {
            guard let anh = cauNoiVe.anhDangNhin() else {
                bao(T("Chưa chụp được vùng này"))
                return
            }
            let ty = anh.scale
            let r = CGRect(x: khung.minX * ty, y: khung.minY * ty,
                           width: khung.width * ty, height: khung.height * ty)
                .intersection(CGRect(origin: .zero, size: CGSize(
                    width: anh.size.width * ty, height: anh.size.height * ty)))
            guard r.width > 8, r.height > 8,
                  let cg = anh.cgImage?.cropping(to: r),
                  let d = UIImage(cgImage: cg, scale: ty, orientation: anh.imageOrientation)
                      .jpegData(compressionQuality: 0.9)
            else {
                bao(T("Vùng khoanh nhỏ quá"))
                return
            }
            #if DEBUG
            // Bằng chứng nhìn được: vùng cắt ghi ra đĩa để đối chiếu với thứ
            // người dùng khoanh. Chỉ bản gỡ lỗi.
            if let thu = FileManager.default.urls(for: .documentDirectory,
                                                  in: .userDomainMask).first?
                .appendingPathComponent("vung-cat-moi-nhat.jpg") {
                try? d.write(to: thu, options: .atomic)
                NhatKy.vo.info("khoanh: cắt \(Int(r.width))×\(Int(r.height))px → \(thu.lastPathComponent)")
            }
            #endif
            vungVuaCat = AnhVungCat(anh: DinhKemAI(
                ten: "vung-\(Int(Date().timeIntervalSince1970)).jpg",
                mime: "image/jpeg", duLieu: d))
        }
    }

    // MARK: Làm gọn chữ

    private func moLamGon(vung: CGRect? = nil) {
        guard trangHienTai?.coNet == true else { bao(T("Trang này chưa có nét nào")); return }
        cuaSo = .lamGon(vung)
    }

    private func batKhoanhLamGon() {
        dangKhoanhTrang = false
        khoanhDeLamGon = true
        bao(T("Khoanh vùng chữ cần làm gọn"))
        Haptics.cham()
    }

    private func khoanhXongLamGon(_ khung: CGRect) {
        khoanhDeLamGon = false
        guard let r = cauNoiVe.sangToaDoTrang(khung) else { return }
        moLamGon(vung: r)
    }

    /// Nét đang HIỆN trên khung (mới hơn bản trên đĩa tới 2 giây). Khung chưa
    /// kịp sang trang này thì đọc đĩa — nhưng khi đó Áp dụng sẽ bị chặn.
    private func banVeDangMo(_ t: TrangVo) -> PKDrawing {
        if cauNoiVe.idTrangDangMo == t.id, let d = cauNoiVe.banVe { return d }
        return KhoVo.nap(t.id)
    }

    /// ⚠️ Chỉ ghi khi khung vẽ ĐANG giữ đúng trang này — lệch là ghi nét của
    /// trang này đè lên trang kia.
    private func apDungLamGon(_ moi: PKDrawing, cho t: TrangVo) -> Bool {
        guard cauNoiVe.idTrangDangMo == t.id else { return false }
        cauNoiVe.datBanVe(moi, tenViec: T("Làm gọn chữ"))
        // Nét CŨ đã đổi nội dung ⇒ đồng bộ không được hợp nhất theo tiền tố.
        t.daVietLaiNet = true
        t.suaLuc = Date()
        try? kho.save()
        bao(T("Đã làm gọn — bấm ↶ để trả lại"))
        return true
    }

    // MARK: AI vẽ lên trang

    /// Đặt hình AI vẽ lên trang đang mở: tìm chỗ trống trong phần trang đang
    /// NHÌN, đổi ra nét bằng bút đang cầm, vẽ DẦN 2–4 giây rồi ghi một lần
    /// (↶ một cái là gỡ cả hình).
    private func veHinhAI(_ h: HinhVeAI) {
        guard let t = trangHienTai, cauNoiVe.idTrangDangMo == t.id else {
            bao(T("Chưa mở được trang để vẽ — thử lại"))
            return
        }
        guard !dangVeAI else { bao(T("Đang vẽ hình trước — đợi chút")); return }
        guard !h.net.isEmpty else { return }
        cauNoiVe.luuNgay()
        let kho = t.khoTrang
        let nhin = cauNoiVe.vungDangNhin ?? CGRect(origin: .zero, size: kho)
        let netCo = (cauNoiVe.banVe ?? KhoVo.nap(t.id)).strokes.map(\.renderBounds)
        let khung = VeLenTrang.timCho(vungNhin: nhin, trang: kho,
                                      tiLe: h.rong / max(h.cao, 1), netCo: netCo)
        let (ink, day) = VeLenTrang.butChoAI(cauNoiVe.butDangChon)
        let ds = VeLenTrang.taoNet(h, vao: khung, ink: ink, doDay: day)
        guard !ds.isEmpty else { return }
        let ten = T("Vẽ bằng AI")
        let nhan = h.nhan
        let xong = {
            dangVeAI = false
            if !nhan.isEmpty { nhanGoiY = nhan }
            bao(T("Đã vẽ lên trang — ↶ để gỡ, dùng lasso để dời/phóng"))
        }
        NhatKy.vo.info("AI vẽ: \(ds.count) nét vào \(Int(khung.minX)),\(Int(khung.minY)) \(Int(khung.width))×\(Int(khung.height)) · nhìn \(Int(nhin.minY))…\(Int(nhin.maxY))")
        if giamChuyenDong {
            cauNoiVe.chenNet(ds, tenViec: ten)
            xong()
        } else {
            dangVeAI = true
            cauNoiVe.veDanRoiChen(ds, tenViec: ten,
                                  thoiGian: VeLenTrang.thoiGianVeDan(soNet: ds.count)) { xong() }
        }
        t.suaLuc = Date()
    }

    /// Nét vừa viết chạm vùng đáy trang ⇒ tự nối dài (nếu người dùng bật).
    private func ganDay(_ t: TrangVo) {
        guard tuNoiDai, t.noiDaiNuaTrang() else { return }
        ThaoTacTrang.danhDauCay(cuon)
        try? kho.save()
        bao(T("Trang tự nối dài thêm ½ trang"))
    }

    #if DEBUG
    /// Bàn thử khổ trang + AI vẽ (CT_XEM_MAN=vo-viet):
    ///   CT_KHO=a5|b5|a4|letter|b4|a3|rong169|bangLon   đổi khổ cả cuốn
    ///   CT_GIAY=oLy|keNgang|…   đổi giấy trang đang mở
    ///   CT_NOIDAI=n             nối dài trang đang mở n lần (+½ trang mỗi lần)
    ///   CT_XEMCA=1              đưa cả trang vào khung
    ///   CT_VEAI=meo|oxy         vẽ hình mẫu lên trang (không gọi mạng)
    ///   CT_VEAI_HOANTAC=1       … xong thì ↶ một lần, đếm nét trước/sau (log)
    ///   CT_XUATPDF=1            xuất trang đang mở ra PDF, in khổ trang PDF (log)
    ///   CT_KHO_MO=1             mở cửa sổ "Khổ giấy của cuốn"
    private func thuKhoTrangTuDong() async {
        let env = ProcessInfo.processInfo.environment
        guard env["CT_KHO"] != nil || env["CT_NOIDAI"] != nil || env["CT_VEAI"] != nil
                || env["CT_XUATPDF"] != nil || env["CT_GIAY"] != nil || env["CT_XEMCA"] != nil
                || env["CT_KHO_MO"] != nil else { return }
        try? await Task.sleep(for: .seconds(1.0))
        if let k = env["CT_KHO"].flatMap(KhoGiay.init(rawValue:)) {
            let tt = DoiKhoGiay.ap(cuon, sang: k, kho: kho)
            NSLog("[THU-KHO] đổi khổ %@: theo=%d nốiDài=%d giữCũ=%d tàiLiệu=%d", k.rawValue,
                  tt.theoCuon, tt.noiDai, tt.giuKhoCu, tt.taiLieu)
        }
        if let g = env["CT_GIAY"].flatMap(LoaiGiay.init(rawValue:)), let t = trangHienTai {
            t.loaiGiay = g.rawValue
        }
        if let n = env["CT_NOIDAI"].flatMap(Int.init), let t = trangHienTai {
            for _ in 0..<n { t.noiDaiNuaTrang() }
        }
        if let t = trangHienTai {
            NSLog("[THU-KHO] trang: khổ %@ · gốc %.0f×%.0f · thật %.0f×%.0f · nối %.0f",
                  t.khoGiayApDung.rawValue, t.khoGoc.width, t.khoGoc.height,
                  t.khoTrang.width, t.khoTrang.height, t.chieuCaoThem)
        }
        try? await Task.sleep(for: .seconds(0.8))
        if env["CT_XEMCA"] == "1" { lanVuaCaTrang += 1 }
        try? await Task.sleep(for: .seconds(0.8))
        if let v = env["CT_VEAI"] {
            let h = v == "oxy" ? HinhVeMau.oxy : HinhVeMau.meo
            let truoc = cauNoiVe.banVe?.strokes.count ?? -1
            veHinhAI(h)
            try? await Task.sleep(for: .seconds(1.2))
            NSLog("[THU-KHO] đang vẽ dần: nét trên trang = %d (trước %d — chưa ghi là đúng)",
                  cauNoiVe.banVe?.strokes.count ?? -1, truoc)
            for _ in 0..<20 where dangVeAI { try? await Task.sleep(for: .seconds(0.5)) }
            let sau = cauNoiVe.banVe?.strokes.count ?? -1
            NSLog("[THU-KHO] vẽ xong: %d → %d nét (+%d, hình có %d nét)", truoc, sau, sau - truoc, h.net.count)
            if env["CT_VEAI_HOANTAC"] == "1" {
                try? await Task.sleep(for: .seconds(2.5))
                cauNoiVe.hoanTac()
                try? await Task.sleep(for: .seconds(0.6))
                NSLog("[THU-KHO] sau MỘT lần ↶: %d nét (%@)", cauNoiVe.banVe?.strokes.count ?? -1,
                      (cauNoiVe.banVe?.strokes.count ?? -1) == truoc ? "gỡ CẢ hình ✅" : "❌")
            }
        }
        if env["CT_KHO_MO"] == "1" { cuaSo = .khoGiay }
        if env["CT_XUATPDF"] == "1", let t = trangHienTai {
            cauNoiVe.luuNgay()
            if let url = XuatPdfVo.taoPdf(trangs: [t], tenTep: "thu-kho"),
               let doc = CGPDFDocument(url as CFURL), let p = doc.page(at: 1) {
                let r = p.getBoxRect(.mediaBox)
                let dich = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("thu-kho.pdf")
                try? FileManager.default.removeItem(at: dich)
                try? FileManager.default.copyItem(at: url, to: dich)
                NSLog("[THU-KHO] PDF: %.0f×%.0f pt (trang %.0f×%.0f) %@", r.width, r.height,
                      t.khoTrang.width, t.khoTrang.height,
                      abs(r.height - t.khoTrang.height) < 1 ? "ĐÚNG ✅" : "SAI ❌")
            }
        }
    }

    /// Bàn thử máy ảo (xem `ThuVoDebug.swift`, CT_XEM_MAN=vo-lamgon): mở cửa
    /// sổ Làm gọn, và nếu xin thì hoàn tác / làm lại rồi đối chiếu TỪNG NÉT.
    private func thuLamGonTuDong() async {
        let env = ProcessInfo.processInfo.environment
        guard env["CT_LAMGON"] != nil else { return }
        try? await Task.sleep(for: .seconds(1.5))
        guard let goc = cauNoiVe.banVe else { NSLog("[THU-LAMGON] ❌ chưa có khung vẽ"); return }
        moLamGon()
        guard env["CT_LAMGON_HOANTAC"] == "1" else { return }
        func giong(_ a: PKDrawing, _ b: PKDrawing) -> Bool {
            a.strokes.count == b.strokes.count && zip(a.strokes, b.strokes).allSatisfy { ThuLamGon.giongHet($0, $1) }
        }
        // Đợi tới khi Áp dụng thật sự đổi khung (máy ảo có lúc rất chậm).
        for _ in 0..<60 {
            try? await Task.sleep(for: .seconds(0.5))
            if let d = cauNoiVe.banVe, !giong(d, goc) { break }
        }
        try? await Task.sleep(for: .seconds(1))
        guard let sau = cauNoiVe.banVe else { return }
        NSLog("[THU-LAMGON] sau Áp dụng: %d nét · khác gốc = %@ · cờ daVietLaiNet = %@ · đĩa khớp khung = %@",
              sau.strokes.count, giong(goc, sau) ? "KHÔNG ❌" : "CÓ ✅",
              trangHienTai?.daVietLaiNet == true ? "true ✅" : "false ❌",
              giong(KhoVo.nap(trangHienTai!.id), sau) ? "có ✅" : "không ❌")
        cauNoiVe.hoanTac()
        try? await Task.sleep(for: .seconds(1.5))
        if let d = cauNoiVe.banVe {
            NSLog("[THU-LAMGON] sau ↶: trùng bản GỐC từng nét = %@", giong(d, goc) ? "CÓ ✅" : "KHÔNG ❌")
        }
        cauNoiVe.lamLai()
        try? await Task.sleep(for: .seconds(1.5))
        if let d = cauNoiVe.banVe {
            NSLog("[THU-LAMGON] sau ↷: trùng bản ĐÃ LÀM GỌN = %@", giong(d, sau) ? "CÓ ✅" : "KHÔNG ❌")
        }
    }
    #endif

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

            // Hoàn tác / làm lại NÉT — luôn thấy, không phụ thuộc bảng công cụ
            // đang ẩn hay hiện (GoodNotes để đúng chỗ này).
            Button { cauNoiVe.hoanTac() } label: { Image(systemName: "arrow.uturn.backward") }
                .accessibilityLabel(T("Hoàn tác"))
            Button { cauNoiVe.lamLai() } label: { Image(systemName: "arrow.uturn.forward") }
                .accessibilityLabel(T("Làm lại"))

            // Chạm vào tên trang = đổi tên ngay tại chỗ.
            Button {
                if let t = trangHienTai { lam(.doiTen, t) }
            } label: {
                VStack(spacing: 1) {
                    Text(cuon.ten)
                        .font(Font.bodyMedium.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                    if let t = trangHienTai {
                        let ten = t.tenHienThi(so: chiSo + 1)
                        let ch = (t.tenChuong ?? "").isEmpty ? "" : " · " + (t.tenChuong ?? "")
                        Text(ten + ch)
                            .font(.caption2)
                            .foregroundStyle(t.coTenRieng ? AppColors.textSecondary : AppColors.textTertiary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityHint(T("Chạm để đổi tên trang"))
            .alert(T("Đổi tên trang"), isPresented: Binding(get: { trangDoiTen != nil },
                                                          set: { if !$0 { trangDoiTen = nil } })) {
                TextField(T("Để trống = “Trang N”"), text: $tenDangGo)
                Button(T("Huỷ"), role: .cancel) { trangDoiTen = nil }
                Button(T("Lưu")) {
                    if let t = trangDoiTen { ThaoTacTrang.doiTen(t, thanh: tenDangGo, kho: kho) }
                    trangDoiTen = nil
                }
            } message: {
                Text(T("Tên hiện ở dải trang, màn Các trang và đồng bộ lên web."))
            }

            // Chuyển trang bằng nút. KHÔNG dùng vuốt ngang: cả bề mặt trang
            // đã thuộc về bút và về cử chỉ cuộn/phóng của khung vẽ, thêm một
            // cú vuốt nữa là lúc viết lúc lật trang.
            HStack(spacing: Spacing.xs) {
                Button { lui() } label: { Image(systemName: "chevron.left.circle") }
                    .disabled(chiSo <= 0)
                // Chạm số trang = mở màn "Các trang" (xem lưới, sắp xếp, nhảy).
                Button { cuaSo = .tongQuan } label: {
                    Text("\(chiSo + 1)/\(max(trangs.count, 1))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(minWidth: 44, minHeight: 30)
                        .background(Capsule().fill(AppColors.backgroundPrimary.opacity(0.7)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(T("Các trang"))
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

            // Khoanh–hỏi phải nằm NGOÀI menu: đây là thao tác giữa giờ học,
            // một chạm rồi khoanh luôn. Bóp Apple Pencil cũng vào đúng đây.
            if CaiDatTroLy.chayDuoc && hienTroLy {
                Button {
                    batKhoanhTrang()
                } label: {
                    Image(systemName: "lasso.badge.sparkles")
                        .foregroundStyle(AppColors.primary)
                }
                .accessibilityLabel(T("Khoanh một vùng để hỏi AI"))
            }

            Menu {
                Section {
                    Button { moLamGon() } label: {
                        Label(T("Làm gọn chữ"), systemImage: "wand.and.stars")
                    }
                    Button { batKhoanhLamGon() } label: {
                        Label(T("Làm gọn một vùng (khoanh)…"), systemImage: "lasso")
                    }
                }
                .disabled(trangHienTai?.coNet != true)

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
                    Button {
                        if let t = trangHienTai {
                            cuaSo = .xuatPdf([t.id], cuon.ten + " — " + t.tenHienThi(so: chiSo + 1))
                        }
                    } label: {
                        Label(T("Xuất trang này ra PDF"), systemImage: "square.and.arrow.up")
                    }
                    Button { cuaSo = .xuatPdf(trangs.map(\.id), cuon.ten) } label: {
                        Label(T("Xuất cả cuốn ra PDF"), systemImage: "square.and.arrow.up.on.square")
                    }
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
                    Button { cuaSo = .khoGiay } label: {
                        Label("\(T("Khổ giấy của cuốn")) · \(cuon.kho.ten)…", systemImage: "rectangle.expand.vertical")
                    }
                    Button {
                        if let t = trangHienTai, t.noiDaiNuaTrang() {
                            ThaoTacTrang.danhDauCay(cuon)
                            try? kho.save()
                            bao(T("Đã nối dài trang thêm ½ trang"))
                        }
                    } label: {
                        Label(trangHienTai?.noiDaiDuoc == false ? T("Nối dài trang (đã tới 4× — tối đa)")
                                                                : T("Nối dài trang này (+½ trang)"),
                              systemImage: "arrow.down.to.line.compact")
                    }
                    .disabled(trangHienTai?.noiDaiDuoc != true)
                    Button { tuNoiDai.toggle() } label: {
                        Label(tuNoiDai ? T("Tự nối dài khi viết gần đáy: BẬT")
                                       : T("Tự nối dài khi viết gần đáy: TẮT"),
                              systemImage: tuNoiDai ? "arrow.down.doc.fill" : "arrow.down.doc")
                    }
                }

                Section {
                    Button { lanVuaKhung += 1 } label: {
                        Label(T("Trang vừa bề ngang"), systemImage: "arrow.left.and.right.square")
                    }
                    Button { lanVuaCaTrang += 1 } label: {
                        Label(T("Xem cả trang"), systemImage: "arrow.up.and.down.square")
                    }
                    Button { hienCongCu.toggle() } label: {
                        Label(hienCongCu ? T("Ẩn bảng công cụ") : T("Hiện bảng công cụ"),
                              systemImage: "pencil.tip.crop.circle")
                    }
                }

                Section {
                    Button { cuaSo = .tongQuan } label: {
                        Label(T("Các trang — sắp xếp, tìm, chọn nhiều"), systemImage: "square.grid.3x3")
                    }
                    Button { if let t = trangHienTai { lam(.doiTen, t) } } label: {
                        Label(T("Đổi tên trang"), systemImage: "character.cursor.ibeam")
                    }
                    Button { themTrang() } label: {
                        Label(T("Thêm trang ở cuối"), systemImage: "plus.rectangle.portrait")
                    }
                    Button { chenSauHienTai() } label: {
                        Label(T("Chèn trang trắng sau trang này"), systemImage: "arrow.down.doc")
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
                   khoGoc: trang.khoGoc,
                   khiGanDay: { ganDay(trang) },
                   lanVuaCaTrang: lanVuaCaTrang,
                   nenPdfTen: trang.nenPdfTen,
                   nenPdfTrang: trang.nenPdfTrang,
                   nenAnhTen: trang.nenAnhTen,
                   // Bảng công cụ là cửa sổ NỔI của hệ thống: nó nằm đè lên cả
                   // cửa sổ đang mở (đo 28/09: che mất công tắc và nút của
                   // "Làm gọn chữ"). Có cửa sổ thì tạm ẩn, đóng lại là hiện.
                   hienCongCu: hienCongCu && cuaSo == nil,
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
                   khiBopGoiTroLy: { batKhoanhTrang() },
                   cauNoi: cauNoiVe)
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

    private var giayMoi: LoaiGiay {
        trangHienTai?.giay ?? LoaiGiay(rawValue: cuon.giayMacDinh) ?? .keNgang
    }
    private var huongMoi: HuongGiay {
        trangHienTai?.huong ?? HuongGiay(rawValue: cuon.huongMacDinh) ?? .doc
    }

    private func moTheoId(_ id: UUID) {
        if let i = trangs.firstIndex(where: { $0.id == id }) { chiSo = i; idHienTai = id }
    }

    private func themTrang() {
        let t = ThaoTacTrang.chenTrangTrang(vao: cuon, viTri: trangs.count,
                                            giay: giayMoi, huong: huongMoi, kho: kho)
        moTheoId(t.id)
    }

    private func chenSauHienTai() {
        let t = ThaoTacTrang.chenTrangTrang(vao: cuon, viTri: chiSo + 1,
                                            giay: giayMoi, huong: huongMoi, kho: kho)
        moTheoId(t.id)
    }

    private func nhanBanTrang() {
        guard let goc = trangHienTai, let t = ThaoTacTrang.nhanBan(goc, kho: kho) else { return }
        moTheoId(t.id)
        bao(T("Đã nhân bản trang"))
    }

    /// Xin xoá trang ở vị trí `i` — hỏi lại trước (một chạm nhầm trên iPad
    /// không được làm mất một buổi học), rồi cho Hoàn tác thêm lần nữa.
    private func xoaTrang(_ i: Int) {
        guard trangs.indices.contains(i), trangs.count > 1 else { return }
        xacNhanXoa = [trangs[i]]
    }

    private func xoaThat(_ ds: [TrangVo]) {
        guard let chup = ThaoTacTrang.xoa(ds, kho: kho) else {
            bao(T("Vở phải còn ít nhất 1 trang"))
            return
        }
        let b = BaoHoanTac(cau: chup.count == 1 ? T("Đã xoá 1 trang")
                                                : "\(T("Đã xoá")) \(chup.count) \(T("trang"))",
                           chup: chup)
        baoHoanTac = b
        Task {
            try? await Task.sleep(for: .seconds(6))
            if baoHoanTac == b { baoHoanTac = nil }
        }
    }

    private func hoanTacXoa(_ b: BaoHoanTac) {
        let moi = ThaoTacTrang.hoanTacXoa(b.chup, vao: cuon, kho: kho)
        baoHoanTac = nil
        if let t = moi.first { moTheoId(t.id) }
        Haptics.xong()
    }

    /// Một việc trên một trang — dùng chung cho dải trang, menu ⋯ và phím tắt.
    private func lam(_ v: ViecTrang, _ t: TrangVo) {
        guard let i = trangs.firstIndex(where: { $0.id == t.id }) else { return }
        switch v {
        case .doiTen:
            tenDangGo = t.tieuDe ?? ""
            trangDoiTen = t
        case .nhanBan:
            if let m = ThaoTacTrang.nhanBan(t, kho: kho) { moTheoId(m.id) }
        case .chenTruoc:
            let m = ThaoTacTrang.chenTrangTrang(vao: cuon, viTri: i, giay: t.giay, huong: t.huong, kho: kho)
            moTheoId(m.id)
        case .chenSau:
            let m = ThaoTacTrang.chenTrangTrang(vao: cuon, viTri: i + 1, giay: t.giay, huong: t.huong, kho: kho)
            moTheoId(m.id)
        case .doiGiay(let g):
            ThaoTacTrang.doiGiay([t], thanh: g, kho: kho)
        case .chuyenCuon:
            cuaSo = .chuyenCuon([t.id])
        case .xuatPdf:
            cuaSo = .xuatPdf([t.id], cuon.ten + " — " + t.tenHienThi(so: i + 1))
        case .xoa:
            xoaTrang(i)
        case .lamGon:
            if t.id == trangHienTai?.id {
                moLamGon()
            } else {
                // Trang khác: mở nó ra trước. Khung vẽ của trang mới dựng ở
                // vòng cập nhật SAU, nên cửa sổ phải đợi một nhịp — mở ngay
                // thì nó đọc nét của trang CŨ (`cauNoiVe.vc` chưa đổi).
                moTheoId(t.id)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { moLamGon() }
            }
        }
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
        ThaoTacTrang.danhDauCay(cuon)
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
        ThaoTacTrang.danhDauCay(cuon)
        try? kho.save()
        chiSo = min((trangHienTai?.thuTu ?? 0) + 1, cuon.trangsTheoThuTu.count - 1)
        bao("\(T("Đã thêm")) \(anhs.count) \(T("trang quét"))")
        DongBoVo.shared.batDau()
    }

    /// Gỡ nền, GIỮ NGUYÊN nét đã viết — nét nằm ở lớp riêng.
    private func goNen() {
        guard let t = trangHienTai else { return }
        t.nenPdfTen = nil
        t.nenAnhTen = nil
        // Nền đã lên mây thì phải gửi LỆNH GỠ (khoá rỗng) — để nguyên khoá
        // cũ là máy chủ giữ nền, và lượt kéo về kế tiếp mang nó sống lại.
        if t.nenKhoaR2 != nil { t.nenKhoaR2 = ""; t.nenLoaiR2 = nil }
        t.suaLuc = Date()
        ThaoTacTrang.danhDauCay(cuon)
        try? kho.save()
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
    @Binding var dangKeo: UUID?
    let themTrang: () -> Void
    let moTongQuan: () -> Void
    let lam: (ViecTrang, TrangVo) -> Void
    let dat: (UUID, TrangVo) -> Void

    var body: some View {
        ScrollViewReader { cuon in
            ScrollView {
                LazyVStack(spacing: Spacing.sm) {
                    Button(action: moTongQuan) {
                        Label(T("Sắp xếp"), systemImage: "square.grid.3x3")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: CornerRadius.small)
                                .fill(AppColors.primary.opacity(0.12)))
                            .foregroundStyle(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(T("Mở màn Các trang để kéo sắp xếp, đổi tên, chọn nhiều"))

                    ForEach(Array(trangs.enumerated()), id: \.element.id) { i, trang in
                        AnhTrangNho(trang: trang, so: i + 1, dangChon: i == chiSo, lanLuu: lanLuu)
                            .opacity(dangKeo == trang.id ? 0.35 : 1)
                            .contentShape(Rectangle())
                            .onTapGesture { chiSo = i }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel(trang.tenHienThi(so: i + 1))
                            .id(trang.id)
                            // ⚠️ Menu giữ-lâu VÀ kéo cùng lúc: giữ yên = menu,
                            // giữ rồi rê đi = nhấc trang lên kéo. Đây là cách
                            // của Tệp/Ảnh trên iPad. Trước 28/09/2026 dải này
                            // chỉ có `contextMenu` với mỗi "Xoá trang", nên
                            // giữ rồi kéo không làm gì cả.
                            .contextMenu {
                                MenuTrang(trang: trang, conXoaDuoc: trangs.count > 1, coLamGon: true) { lam($0, trang) }
                            }
                            .onDrag {
                                dangKeo = trang.id
                                return NSItemProvider(object: trang.id.uuidString as NSString)
                            }
                            .onDrop(of: [UTType.text],
                                    delegate: ThaTrangDeXep(dich: trang, dangKeo: $dangKeo, dat: dat))
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
                guard trangs.indices.contains(moi) else { return }
                withAnimation(AppAnimations.quick) { cuon.scrollTo(trangs[moi].id, anchor: .center) }
            }
        }
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
        ThaoTacTrang.danhDauCay(cuon)
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
                        ThaoTacTrang.danhDauCay(trang?.cuon)
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
