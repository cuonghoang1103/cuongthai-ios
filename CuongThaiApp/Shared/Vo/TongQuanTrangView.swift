#if os(iOS)
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Việc làm được với MỘT trang (menu giữ lâu dùng chung)

/// Mọi mục của menu giữ-lâu trên một trang. Dải trang và màn "Các trang"
/// dựng CÙNG một menu từ enum này — hai menu viết tay riêng thì sớm muộn
/// lệch nhau (đúng chuyện dải trang từng chỉ có mỗi "Xoá trang").
enum ViecTrang {
    case doiTen, nhanBan, chenTruoc, chenSau
    case doiGiay(LoaiGiay)
    case chuyenCuon, xuatPdf, xoa
    /// Chỉ màn viết làm được (cần khung vẽ đang mở) — xem `MenuTrang.coLamGon`.
    case lamGon
}

/// Menu giữ-lâu của một trang.
///
/// ⚠️ Mỗi nhóm bọc trong `Section`: `contextMenu` cũng là ViewBuilder, quá
/// 10 con trực tiếp là SwiftUI lặng lẽ vứt phần thừa (đã dính ở menu ⋯).
struct MenuTrang: View {
    let trang: TrangVo
    let conXoaDuoc: Bool
    /// Hiện "Làm gọn chữ". Chỉ dải trang của màn viết bật: làm gọn cần khung
    /// vẽ đang mở (xem trước + hoàn tác đi qua bộ hoàn tác của nó), màn "Các
    /// trang" không có khung vẽ nào.
    var coLamGon = false
    let lam: (ViecTrang) -> Void

    var body: some View {
        if coLamGon && trang.coNet {
            Section {
                Button { lam(.lamGon) } label: { Label(T("Làm gọn chữ"), systemImage: "wand.and.stars") }
            }
        }
        Section {
            Button { lam(.doiTen) } label: { Label(T("Đổi tên trang"), systemImage: "character.cursor.ibeam") }
            Button { lam(.nhanBan) } label: { Label(T("Nhân bản"), systemImage: "plus.square.on.square") }
        }
        Section {
            Button { lam(.chenTruoc) } label: { Label(T("Chèn trang trắng TRƯỚC"), systemImage: "arrow.up.doc") }
            Button { lam(.chenSau) } label: { Label(T("Chèn trang trắng SAU"), systemImage: "arrow.down.doc") }
        }
        Section {
            Menu {
                ForEach(LoaiGiay.allCases) { g in
                    Button { lam(.doiGiay(g)) } label: {
                        if trang.giay == g { Label(g.ten, systemImage: "checkmark") } else { Text(g.ten) }
                    }
                }
            } label: { Label(T("Đổi loại giấy"), systemImage: "doc.plaintext") }
            Button { lam(.chuyenCuon) } label: { Label(T("Di chuyển sang cuốn khác…"), systemImage: "folder") }
            Button { lam(.xuatPdf) } label: { Label(T("Xuất trang này ra PDF"), systemImage: "square.and.arrow.up") }
        }
        Section {
            // ⚠️ `disabled` + nhãn nói LÝ DO — chặn im lặng là người dùng báo
            // "nút hỏng" (xem feedback_bay_pencilkit_va_swiftdata, mục 9).
            Button(role: .destructive) { lam(.xoa) } label: {
                Label(conXoaDuoc ? T("Xoá trang…") : T("Xoá trang (vở phải còn ít nhất 1 trang)"),
                      systemImage: "trash")
            }
            .disabled(!conXoaDuoc)
        }
    }
}

// MARK: - Ảnh nhỏ một trang

struct AnhTrangNho: View {
    let trang: TrangVo
    let so: Int
    let dangChon: Bool
    /// Tăng mỗi lần lưu để nạp lại ảnh.
    let lanLuu: Int
    var hienTen = true

    @State private var anh: UIImage?

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.small).fill(Color.white)
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
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(4)
                }
                if let ch = trang.tenChuong, !ch.isEmpty {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(AppColors.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(4)
                }
            }
            .aspectRatio(trang.khoTrang.width / trang.khoTrang.height, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .strokeBorder(dangChon ? AppColors.primary : AppColors.border,
                                  lineWidth: dangChon ? 2 : 1)
            )
            if hienTen {
                Text(trang.coTenRieng ? "\(so) · \(trang.tenHienThi(so: so))" : "\(so)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(dangChon ? AppColors.primary : AppColors.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        // Đọc ảnh nhỏ từ ĐĨA, không dựng lại từ `PKDrawing`: chục trang một
        // lúc mà dựng lại từng cái là khựng ngay khi cuộn.
        .task(id: "\(trang.id.uuidString)#\(lanLuu)") { anh = KhoVo.anhNho(trang.id) }
    }
}

// MARK: - Kéo–thả để sắp xếp

/// Sắp xếp TRỰC TIẾP khi kéo: rê trang qua ô nào là nó nhảy vào chỗ ô đó
/// ngay, không đợi thả tay — thấy trước kết quả thì không ai thả nhầm chỗ.
///
/// ⚠️ Chỉ nhận món kéo CÓ `dangKeo` (trang của chính màn này). Tệp PDF/ảnh
/// kéo từ app khác vào cũng đi qua đây; nhận nhầm là nó xáo trang.
struct ThaTrangDeXep: DropDelegate {
    let dich: TrangVo
    @Binding var dangKeo: UUID?
    let dat: (UUID, TrangVo) -> Void

    func validateDrop(info: DropInfo) -> Bool { dangKeo != nil }

    func dropEntered(info: DropInfo) {
        guard let id = dangKeo, id != dich.id else { return }
        withAnimation(AppAnimations.quick) { dat(id, dich) }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        let co = dangKeo != nil
        dangKeo = nil
        if co { Haptics.cham() }
        return co
    }
}

// MARK: - Chọn cuốn đích

struct ChonCuonView: View {
    /// Cuốn đang chứa trang — không liệt kê (chuyển vào chính nó là vô nghĩa).
    let boQua: UUID?
    let chon: (CuonVo) -> Void
    @Environment(\.dismiss) private var dong
    @Query(sort: [SortDescriptor(\MonVo.thuTu)]) private var mons: [MonVo]

    var body: some View {
        NavigationStack {
            List {
                ForEach(mons) { mon in
                    let ds = mon.cuonsTheoThuTu.filter { $0.id != boQua }
                    if !ds.isEmpty {
                        Section(mon.emoji + " " + mon.ten) {
                            ForEach(ds) { c in
                                Button {
                                    chon(c)
                                    dong()
                                } label: {
                                    HStack {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color(hex: UInt32(c.mauBiaHex)))
                                            .frame(width: 14, height: 20)
                                        Text(c.ten).foregroundStyle(AppColors.textPrimary)
                                        Spacer()
                                        Text("\(c.soTrang) " + T("trang"))
                                            .font(.caption).foregroundStyle(AppColors.textTertiary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .overlay {
                if mons.allSatisfy({ $0.cuonsTheoThuTu.allSatisfy { $0.id == boQua } }) {
                    Text(T("Chưa có cuốn vở nào khác — lập thêm một cuốn trước đã."))
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .navigationTitle(T("Chuyển sang cuốn"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button(T("Huỷ")) { dong() } }
            }
        }
    }
}

// MARK: - Dải báo hoàn tác

struct BaoHoanTac: Equatable {
    let cau: String
    let chup: [TrangDaXoa]
    let lan: UUID = UUID()
    static func == (a: BaoHoanTac, b: BaoHoanTac) -> Bool { a.lan == b.lan }
}

struct DaiHoanTac: View {
    let bao: BaoHoanTac
    let hoanTac: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "trash").foregroundStyle(AppColors.onPrimary.opacity(0.85))
            Text(bao.cau)
                .font(Font.bodyMedium.weight(.semibold))
                .foregroundStyle(AppColors.onPrimary)
            Button(T("Hoàn tác"), action: hoanTac)
                .font(Font.bodyMedium.weight(.bold))
                .foregroundStyle(AppColors.onPrimary)
                .buttonStyle(.plain)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.22)))
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Capsule().fill(Color.black.opacity(0.82)))
        .padding(.bottom, Spacing.xl)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Màn "Các trang"

/// Toàn bộ trang của một cuốn: lưới ảnh nhỏ (kéo–thả để xếp, chọn nhiều) và
/// danh sách có TAY NẮM kéo (cách xếp chắc ăn nhất trên cảm ứng lẫn bút).
///
/// Người dùng báo 28/09/2026: "giữ trang 4 kéo lên cạnh trang 1 mà không kéo
/// được, giữ lâu chỉ ra Xoá trang". Hai đường ở đây: lưới cho thao tác nhanh,
/// danh sách `EditMode` + `onMove` cho thao tác chính xác — đó là đường của
/// chính hệ thống (Nhắc nhở, Tệp), không phụ thuộc cử chỉ tự chế.
struct TongQuanTrangView: View {
    @Bindable var cuon: CuonVo
    let idDangMo: UUID?
    let lanLuu: Int
    /// Mở một trang rồi đóng màn này.
    let moTrang: (UUID) -> Void

    @Environment(\.dismiss) private var dong
    @Environment(\.modelContext) private var kho
    @Environment(\.horizontalSizeClass) private var beRong

    private enum CheDo: String, CaseIterable, Identifiable {
        case luoi, danhSach
        var id: String { rawValue }
        var ten: String { self == .luoi ? T("Lưới") : T("Sắp xếp") }
    }
    private enum Loc: String, CaseIterable, Identifiable {
        case tatCa, mucLuc, danhDau
        var id: String { rawValue }
        var ten: String {
            switch self {
            case .tatCa: return T("Tất cả trang")
            case .mucLuc: return T("Mục lục (trang có chương)")
            case .danhDau: return T("Trang đánh dấu")
            }
        }
    }

    @AppStorage("vo.tongquan.chedo") private var cheDoLuu = CheDo.luoi.rawValue
    @State private var loc: Loc = .tatCa
    @State private var tuKhoa = ""
    @State private var dangChonNhieu = false
    @State private var daChon: Set<UUID> = []
    @State private var dangKeo: UUID?
    @State private var xacNhanXoa: [TrangVo]?
    @State private var baoHoanTac: BaoHoanTac?
    @State private var trangDoiTen: TrangVo?
    @State private var tenDangGo = ""
    @State private var cuaSo: CuaSo?
    /// Câu báo ngắn (chặn một thao tác thì phải NÓI ra vì sao).
    @State private var baoNgan: String?

    private enum CuaSo: Identifiable {
        case chuyen([UUID])
        case xuat([UUID])
        var id: String {
            switch self {
            case .chuyen(let d): return "c" + d.map(\.uuidString).joined()
            case .xuat(let d): return "x" + d.map(\.uuidString).joined()
            }
        }
    }

    private var cheDo: CheDo { CheDo(rawValue: cheDoLuu) ?? .luoi }
    private var tatCa: [TrangVo] { cuon.trangsTheoThuTu }
    private var dangLoc: Bool { !tuKhoa.isEmpty || loc != .tatCa }

    /// (số trang thật, trang) — số giữ theo vị trí trong CẢ cuốn, không theo
    /// danh sách đã lọc: tìm ra "Trang 37" thì phải hiện 37, không phải 1.
    private var hienThi: [(so: Int, trang: TrangVo)] {
        let k = tuKhoa.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return tatCa.enumerated().compactMap { i, t in
            switch loc {
            case .tatCa: break
            case .mucLuc: if (t.tenChuong ?? "").isEmpty { return nil }
            case .danhDau: if !t.danhDau { return nil }
            }
            if !k.isEmpty {
                let khop = t.tenHienThi(so: i + 1).lowercased().contains(k)
                    || (t.tenChuong?.lowercased().contains(k) ?? false)
                    || (t.chuNhanDang?.lowercased().contains(k) ?? false)
                    || "\(i + 1)" == k
                if !khop { return nil }
            }
            return (i + 1, t)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if cheDo == .luoi { luoi } else { danhSach }
            }
            .alert(T("Đổi tên trang"), isPresented: Binding(get: { trangDoiTen != nil },
                                                          set: { if !$0 { trangDoiTen = nil } })) {
                TextField(T("Để trống = “Trang N”"), text: $tenDangGo)
                Button(T("Huỷ"), role: .cancel) { trangDoiTen = nil }
                Button(T("Lưu")) {
                    if let t = trangDoiTen { ThaoTacTrang.doiTen(t, thanh: tenDangGo, kho: kho) }
                    trangDoiTen = nil
                }
            }
            .overlay(alignment: .top) {
                if let baoNgan {
                    Text(baoNgan)
                        .font(Font.bodyMedium.weight(.semibold))
                        .foregroundStyle(AppColors.onPrimary)
                        .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm)
                        .background(Capsule().fill(AppColors.primary.opacity(0.92)))
                        .padding(.top, Spacing.sm)
                        .allowsHitTesting(false)
                }
            }
            .background(AppColors.backgroundPrimary)
            .searchable(text: $tuKhoa, prompt: T("Tìm tên trang, chương, chữ viết tay…"))
            .navigationTitle(cuon.ten + " · \(tatCa.count) " + T("trang"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { thanhCongCu }
            .safeAreaInset(edge: .bottom) {
                if dangChonNhieu && cheDo == .luoi { thanhChon }
            }
            .overlay(alignment: .bottom) {
                if let b = baoHoanTac, !dangChonNhieu {
                    DaiHoanTac(bao: b) { hoanTac(b) }
                }
            }
            .animation(AppAnimations.quick, value: baoHoanTac)
            .confirmationDialog(
                xacNhanXoa.map { $0.count == 1 ? T("Xoá trang này?") : "\(T("Xoá")) \($0.count) \(T("trang?"))" } ?? "",
                isPresented: Binding(get: { xacNhanXoa != nil }, set: { if !$0 { xacNhanXoa = nil } }),
                titleVisibility: .visible
            ) {
                Button(T("Xoá"), role: .destructive) {
                    if let ds = xacNhanXoa { xoa(ds) }
                    xacNhanXoa = nil
                }
                Button(T("Huỷ"), role: .cancel) { xacNhanXoa = nil }
            } message: {
                Text(T("Bấm Hoàn tác ngay sau đó để lấy lại. Trên máy chủ trang nằm trong thùng rác 30 ngày."))
            }
            .sheet(item: $cuaSo) { c in
                switch c {
                case .chuyen(let ids):
                    ChonCuonView(boQua: cuon.id) { dich in chuyen(ids, sang: dich) }
                case .xuat(let ids):
                    XuatPdfView(trangs: tatCa.filter { ids.contains($0.id) },
                                tenTep: ids.count == 1
                                    ? cuon.ten + " — " + (tatCa.firstIndex { $0.id == ids[0] }
                                        .map { tatCa[$0].tenHienThi(so: $0 + 1) } ?? "")
                                    : cuon.ten)
                }
            }
        }
    }

    // MARK: Thanh công cụ

    @ToolbarContentBuilder
    private var thanhCongCu: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(T("Xong")) { dong() }.fontWeight(.semibold)
        }
        ToolbarItem(placement: .principal) {
            Picker("", selection: $cheDoLuu) {
                ForEach(CheDo.allCases) { Text($0.ten).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
        }
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Menu {
                Picker(T("Lọc"), selection: $loc) {
                    ForEach(Loc.allCases) { Text($0.ten).tag($0) }
                }
            } label: {
                Image(systemName: loc == .tatCa ? "line.3.horizontal.decrease.circle"
                                                : "line.3.horizontal.decrease.circle.fill")
            }
            .accessibilityLabel(T("Lọc trang"))
            if cheDo == .luoi {
                Button(dangChonNhieu ? T("Xong chọn") : T("Chọn")) {
                    dangChonNhieu.toggle()
                    daChon = []
                }
            }
        }
    }

    // MARK: Lưới

    private var soCot: Int { beRong == .regular ? 5 : 3 }

    private var luoi: some View {
        ScrollView {
            if dangLoc {
                Text(T("Đang lọc — tắt lọc để kéo sắp xếp"))
                    .font(.caption).foregroundStyle(AppColors.textTertiary)
                    .padding(.top, Spacing.sm)
            } else if !dangChonNhieu {
                Text(T("Giữ một trang rồi kéo tới chỗ mới để sắp xếp · giữ để mở menu"))
                    .font(.caption).foregroundStyle(AppColors.textTertiary)
                    .padding(.top, Spacing.sm)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.md), count: soCot),
                      spacing: Spacing.md) {
                ForEach(hienThi, id: \.trang.id) { muc in
                    oLuoi(muc.trang, so: muc.so)
                }
            }
            .padding(Spacing.md)
        }
    }

    @ViewBuilder
    private func oLuoi(_ t: TrangVo, so: Int) -> some View {
        let chon = dangChonNhieu ? daChon.contains(t.id) : t.id == idDangMo
        let o = AnhTrangNho(trang: t, so: so, dangChon: chon, lanLuu: lanLuu)
            .overlay(alignment: .bottomTrailing) {
                if dangChonNhieu {
                    Image(systemName: daChon.contains(t.id) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(daChon.contains(t.id) ? AppColors.primary : AppColors.textTertiary)
                        .background(Circle().fill(Color.white))
                        .padding(.bottom, 22).padding(.trailing, 4)
                }
            }
            .opacity(dangKeo == t.id ? 0.35 : 1)
            .contentShape(Rectangle())
            .onTapGesture {
                if dangChonNhieu {
                    if daChon.contains(t.id) { daChon.remove(t.id) } else { daChon.insert(t.id) }
                } else {
                    moTrang(t.id)
                    dong()
                }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(t.tenHienThi(so: so))

        if dangChonNhieu {
            o
        } else if dangLoc {
            o.contextMenu { MenuTrang(trang: t, conXoaDuoc: tatCa.count > 1) { lam($0, t) } }
        } else {
            o.contextMenu { MenuTrang(trang: t, conXoaDuoc: tatCa.count > 1) { lam($0, t) } }
                .onDrag {
                    dangKeo = t.id
                    return NSItemProvider(object: t.id.uuidString as NSString)
                }
                .onDrop(of: [UTType.text], delegate: ThaTrangDeXep(dich: t, dangKeo: $dangKeo) { id, dich in
                    guard let tr = tatCa.first(where: { $0.id == id }) else { return }
                    ThaoTacTrang.datVaoCho(tr, choCua: dich, trongCuon: cuon, kho: kho)
                })
        }
    }

    // MARK: Danh sách có tay nắm

    private var danhSach: some View {
        List {
            Section {
                ForEach(hienThi, id: \.trang.id) { muc in
                    DongTrang(trang: muc.trang, so: muc.so, lanLuu: lanLuu,
                              dangMo: muc.trang.id == idDangMo) { ten in
                        ThaoTacTrang.doiTen(muc.trang, thanh: ten, kho: kho)
                    } mo: {
                        moTrang(muc.trang.id)
                        dong()
                    }
                    .contextMenu {
                        MenuTrang(trang: muc.trang, conXoaDuoc: tatCa.count > 1) { lam($0, muc.trang) }
                    }
                }
                .onMove { tu, toi in
                    guard !dangLoc else { return }
                    withAnimation { ThaoTacTrang.diChuyen(trongCuon: cuon, tu: tu, toi: toi, kho: kho) }
                    Haptics.cham()
                }
                .moveDisabled(dangLoc)
                .deleteDisabled(true)
            } footer: {
                Text(dangLoc ? T("Đang lọc — tắt lọc để kéo sắp xếp.")
                             : T("Kéo tay nắm ≡ bên phải để đổi chỗ. Chạm vào tên để đổi tên."))
            }
        }
        .listStyle(.insetGrouped)
        // Luôn ở chế độ sửa: tay nắm hiện sẵn, không bắt người dùng đi tìm
        // nút "Sửa" trước khi kéo được.
        .environment(\.editMode, .constant(.active))
    }

    // MARK: Thanh chọn nhiều

    private var thanhChon: some View {
        let ds = tatCa.filter { daChon.contains($0.id) }
        let coChon = !ds.isEmpty
        return HStack(spacing: Spacing.lg) {
            Button(daChon.count == hienThi.count ? T("Bỏ chọn") : T("Chọn hết")) {
                daChon = daChon.count == hienThi.count ? [] : Set(hienThi.map(\.trang.id))
            }
            Text("\(daChon.count) " + T("đã chọn"))
                .font(.caption).foregroundStyle(AppColors.textSecondary)
            Spacer()
            Button { nhanBan(ds) } label: { Image(systemName: "plus.square.on.square") }
                .disabled(!coChon).accessibilityLabel(T("Nhân bản"))
            Menu {
                ForEach(LoaiGiay.allCases) { g in
                    Button(g.ten) { ThaoTacTrang.doiGiay(ds, thanh: g, kho: kho) }
                }
            } label: { Image(systemName: "doc.plaintext") }
                .disabled(!coChon).accessibilityLabel(T("Đổi loại giấy"))
            Button { cuaSo = .chuyen(ds.map(\.id)) } label: { Image(systemName: "folder") }
                .disabled(!coChon).accessibilityLabel(T("Chuyển sang cuốn khác"))
            Button { cuaSo = .xuat(ds.map(\.id)) } label: { Image(systemName: "square.and.arrow.up") }
                .disabled(!coChon).accessibilityLabel(T("Xuất PDF"))
            Button(role: .destructive) { xacNhanXoa = ds } label: { Image(systemName: "trash") }
                // Chọn hết mà xoá là cuốn rỗng — chặn và nói ra.
                .disabled(!coChon || ds.count >= tatCa.count)
                .accessibilityLabel(ds.count >= tatCa.count && coChon
                                    ? T("Không xoá được hết — vở phải còn ít nhất 1 trang")
                                    : T("Xoá"))
        }
        .font(.system(size: 18))
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(.bar)
    }

    // MARK: Việc

    private func lam(_ v: ViecTrang, _ t: TrangVo) {
        guard let i = tatCa.firstIndex(where: { $0.id == t.id }) else { return }
        switch v {
        case .doiTen:
            tenDangGo = t.tieuDe ?? ""
            trangDoiTen = t
        case .nhanBan:
            ThaoTacTrang.nhanBan(t, kho: kho)
        case .chenTruoc:
            ThaoTacTrang.chenTrangTrang(vao: cuon, viTri: i, giay: t.giay, huong: t.huong, kho: kho)
        case .chenSau:
            ThaoTacTrang.chenTrangTrang(vao: cuon, viTri: i + 1, giay: t.giay, huong: t.huong, kho: kho)
        case .doiGiay(let g):
            ThaoTacTrang.doiGiay([t], thanh: g, kho: kho)
        case .chuyenCuon:
            cuaSo = .chuyen([t.id])
        case .xuatPdf:
            cuaSo = .xuat([t.id])
        case .xoa:
            xacNhanXoa = [t]
        case .lamGon:
            break   // không hiện ở màn này
        }
        Haptics.cham()
    }

    private func nhanBan(_ ds: [TrangVo]) {
        // Nhân bản từ trang CUỐI ngược lên: mỗi bản sao chèn ngay sau gốc,
        // làm từ đầu xuống thì vị trí các trang sau bị đẩy lệch.
        for t in ds.sorted(by: { $0.thuTu > $1.thuTu }) { ThaoTacTrang.nhanBan(t, kho: kho) }
        daChon = []
        Haptics.xong()
    }

    private func chuyen(_ ids: [UUID], sang dich: CuonVo) {
        let ds = tatCa.filter { ids.contains($0.id) }
        if ThaoTacTrang.chuyen(ds, sang: dich, kho: kho) {
            daChon = []
            Haptics.xong()
        } else {
            bao(T("Không chuyển hết được — cuốn này phải còn ít nhất 1 trang"))
        }
    }

    private func bao(_ s: String) {
        baoNgan = s
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            if baoNgan == s { baoNgan = nil }
        }
    }

    private func xoa(_ ds: [TrangVo]) {
        guard let chup = ThaoTacTrang.xoa(ds, kho: kho) else { return }
        daChon = []
        dangChonNhieu = false
        let b = BaoHoanTac(cau: chup.count == 1 ? T("Đã xoá 1 trang") : "\(T("Đã xoá")) \(chup.count) \(T("trang"))",
                           chup: chup)
        baoHoanTac = b
        Task {
            try? await Task.sleep(for: .seconds(6))
            if baoHoanTac == b { baoHoanTac = nil }
        }
    }

    private func hoanTac(_ b: BaoHoanTac) {
        ThaoTacTrang.hoanTacXoa(b.chup, vao: cuon, kho: kho)
        baoHoanTac = nil
        Haptics.xong()
    }
}

/// Một dòng của danh sách sắp xếp: ảnh nhỏ · số · tên sửa tại chỗ.
private struct DongTrang: View {
    let trang: TrangVo
    let so: Int
    let lanLuu: Int
    let dangMo: Bool
    let doiTen: (String) -> Void
    let mo: () -> Void

    @State private var ten = ""
    @FocusState private var dangGo: Bool

    var body: some View {
        HStack(spacing: Spacing.md) {
            AnhTrangNho(trang: trang, so: so, dangChon: dangMo, lanLuu: lanLuu, hienTen: false)
                .frame(width: 44)
                .onTapGesture(perform: mo)
            Text("\(so)")
                .font(.body.monospacedDigit())
                .foregroundStyle(AppColors.textTertiary)
                .frame(minWidth: 28, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                TextField(T("Trang") + " \(so)", text: $ten)
                    .focused($dangGo)
                    .submitLabel(.done)
                    .onSubmit { doiTen(ten) }
                    .onChange(of: dangGo) { _, go in if !go { doiTen(ten) } }
                if let ch = trang.tenChuong, !ch.isEmpty {
                    Label(ch, systemImage: "bookmark.fill")
                        .font(.caption)
                        .foregroundStyle(AppColors.primary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Button(action: mo) {
                Image(systemName: "arrow.up.forward.square")
                    .foregroundStyle(AppColors.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(T("Mở trang"))
        }
        .padding(.vertical, 2)
        .onAppear { ten = trang.tieuDe ?? "" }
        .onChange(of: trang.tieuDe) { _, moi in if !dangGo { ten = moi ?? "" } }
    }
}
#endif
