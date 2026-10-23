import SwiftUI

// ════════════════════════════════════════════════════════════════
// MỤC LỤC một khoá kiểu sách (Dekiru…): tiến độ + "Tiếp tục", Mở đầu, mục
// tra cứu (Chia động từ, Ôn thẻ, đề luyện, ôn cuối kỳ), rồi từng buổi gập/mở
// với bài con chia nhóm (Bài học · Theo slide lớp · Luyện thêm · Theo sách).
// Màn dạng NỘI DUNG — không mang NavigationStack riêng (đẩy vào stack có sẵn).
// ════════════════════════════════════════════════════════════════

/// Thông tin khoá biết TRƯỚC khi tải (thẻ ở cửa vào, tiêu đề lúc đang tải).
struct KhoaSachHocMoTa: Identifiable, Hashable {
    let id: String          // khoá trong /sach-hoc/<id>/
    let ten: String
    let moTa: String
    let co: String

    static let dekiru = KhoaSachHocMoTa(
        id: "dekiru", ten: "できる日本語 · Bài 0–15",
        moTa: "Học từ con số 0 theo sách trên lớp: kana, ngữ pháp, từ vựng, nói, nghe", co: "🇯🇵")
}

struct MucLucSachHocView: View {
    let moTa: KhoaSachHocMoTa
    @StateObject private var vm: SachHocVM
    @State private var moBuoi: Set<Int> = []
    @State private var dungLuong = 0
    @State private var moHetTraCuu = false
    #if DEBUG
    /// Màn soi: mở sẵn bài này (`CT_XEM_MAN=sachhoc-bai:<id>`).
    var moSan: String? = nil
    var cuonToi: Int? = nil
    @State private var daMoSan = false
    #endif

    init(moTa: KhoaSachHocMoTa, vm: SachHocVM? = nil) {
        self.moTa = moTa
        _vm = StateObject(wrappedValue: vm ?? SachHocVM(khoa: moTa.id))
    }

    #if DEBUG
    init(moTa: KhoaSachHocMoTa, moSan: String?, cuonToi: Int?) {
        self.init(moTa: moTa)
        self.moSan = moSan
        self.cuonToi = cuonToi
    }
    #endif

    var body: some View {
        ScrollViewReader { cuon in
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let khoa = vm.khoa {
                    theDau(khoa)
                    if vm.banLuu {
                        Label("Đang dùng bản đã lưu trên máy — kéo xuống để thử tải lại.", systemImage: "wifi.slash")
                            .font(.system(size: 13)).foregroundColor(AppColors.warning)
                    }
                    hang(.gioiThieu, title: khoa.gioiThieu.title, kind: khoa.gioiThieu.kind, phut: khoa.gioiThieu.minutes, nhom: nil)
                        .theKhoiSH()
                    if !khoa.phu.isEmpty { phanTraCuu(khoa) }
                    Text("CÁC BÀI").font(.system(size: 12, weight: .heavy)).kerning(0.6).foregroundColor(AppColors.textTertiary).padding(.top, 4)
                    ForEach(khoa.buoi) { b in theBuoi(khoa, b).id("buoi-\(b.n)") }
                    chanTrang(khoa)
                } else if let loi = vm.loi {
                    KhungLoiSH(loi: loi) { Task { await vm.nap() } }
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Đang tải \(moTa.ten)…").font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                }
            }
            .padding(16)
            .padding(.bottom, 40)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        #if DEBUG
        .onChange(of: vm.khoa?.phienBan) { _, v in
            if v != nil, moSan == nil, let n = cuonToi {
                moBuoi.insert(n)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { cuon.scrollTo("buoi-\(n)", anchor: .top) }
            }
        }
        #endif
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(moTa.ten)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { ToolbarItem(placement: .primaryAction) { menu } }
        .refreshable { await vm.nap() }
        .task {
            if vm.khoa == nil { await vm.nap() }
            if moBuoi.isEmpty {
                if case .bai(let n, _)? = vm.baiTiepTheo { moBuoi = [n] } else if let n = vm.khoa?.buoi.first?.n { moBuoi = [n] }
            }
            dungLuong = await vm.dungLuongDaLuu()
        }
        #if DEBUG
        .navigationDestination(isPresented: Binding(get: { daMoSan && moSan != nil }, set: { daMoSan = $0 })) {
            if let m = mucTuId(moSan) { BaiSachHocView(vm: vm, muc: m, cuonToi: cuonToi) }
        }
        .onChange(of: vm.khoa?.phienBan) { _, v in if v != nil, moSan != nil, !daMoSan { daMoSan = true } }
        #endif
    }

    #if DEBUG
    private func mucTuId(_ id: String?) -> MucDocSH? {
        guard let id, let khoa = vm.khoa else { return nil }
        if id == khoa.gioiThieu.id { return .gioiThieu }
        if khoa.phu.contains(where: { $0.id == id }) { return .phu(id: id) }
        if let b = khoa.buoi.first(where: { $0.bai.contains { $0.id == id } }) { return .bai(buoi: b.n, id: id) }
        return nil
    }
    #endif

    // MARK: Thẻ đầu

    private func theDau(_ khoa: KhoaSH) -> some View {
        let td = vm.tienDoKhoa
        let pt = td.tong > 0 ? Double(td.xong) / Double(td.tong) : 0
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(khoa.tieuDe).font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                    Text(moTa.moTa).font(.system(size: 14)).foregroundColor(.white.opacity(0.88))
                }
                Spacer(minLength: 8)
                Text(moTa.co).font(.system(size: 34))
            }
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.25))
                        Capsule().fill(Color.white).frame(width: max(6, g.size.width * pt))
                    }
                }
                .frame(height: 8)
                Text("Đã học \(td.xong)/\(td.tong) bài · \(Int((pt * 100).rounded()))%")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.92))
            }
            if let tiep = vm.baiTiepTheo, let m = vm.meta(tiep) {
                NavigationLink { BaiSachHocView(vm: vm, muc: tiep) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill").font(.system(size: 14, weight: .bold))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(td.xong == 0 ? "Bắt đầu học" : "Học tiếp · \(m.nhan)").font(.system(size: 12, weight: .bold)).opacity(0.75)
                            Text(PhanTichChuSH.tron(m.title)).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(AppColors.primaryDark)
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xBE123C), Color(hex: 0x7A45E8)], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
    }

    // MARK: Tra cứu

    private func phanTraCuu(_ khoa: KhoaSH) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TRA CỨU & ÔN TẬP").font(.system(size: 12, weight: .heavy)).kerning(0.6).foregroundColor(AppColors.textTertiary)
            // 11 mục mà bày hết thì đẩy danh sách bài xuống tận màn thứ ba — gập, chỉ hiện 3 mục đầu.
            let ds = moHetTraCuu ? khoa.phu : Array(khoa.phu.prefix(3))
            VStack(spacing: 0) {
                ForEach(Array(ds.enumerated()), id: \.element.id) { i, p in
                    hang(.phu(id: p.id), title: p.title, kind: p.kind, phut: p.minutes, nhom: nil, nhanRieng: p.kind == "review" ? "Ôn tập" : nil)
                    if i < ds.count - 1 { Divider().padding(.leading, 34) }
                }
                if khoa.phu.count > 3 {
                    Divider()
                    Button { withAnimation(.easeInOut(duration: 0.2)) { moHetTraCuu.toggle() } } label: {
                        Label(moHetTraCuu ? "Thu gọn" : "Xem thêm \(khoa.phu.count - 3) mục (đề luyện, ôn cuối kỳ…)",
                              systemImage: moHetTraCuu ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold)).foregroundColor(AppColors.primary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .theKhoiSH()
        }
    }

    // MARK: Một buổi

    private func theBuoi(_ khoa: KhoaSH, _ b: BuoiSH) -> some View {
        let td = vm.tienDo(b)
        let mo = moBuoi.contains(b.n)
        let xongHet = td.tong > 0 && td.xong == td.tong
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) { if mo { moBuoi.remove(b.n) } else { moBuoi.insert(b.n) } }
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(spacing: 0) {
                        Text((khoa.chuHuyHieu ?? khoa.donVi).uppercased()).font(.system(size: 9, weight: .heavy)).kerning(0.4)
                        Text(String(format: "%02d", b.so)).font(.system(size: 22, weight: .heavy).monospacedDigit())
                    }
                    .foregroundColor(xongHet ? .white : AppColors.primary)
                    .frame(width: 54, height: 54)
                    .background(RoundedRectangle(cornerRadius: 14).fill(xongHet ? AppColors.success : AppColors.primary.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tieuDeBuoi(b)).font(.system(size: 16.5, weight: .semibold)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                        Text(tomTat(b)).font(.system(size: 12.5)).foregroundColor(AppColors.textSecondary).lineLimit(2)
                        if td.tong > 0 {
                            HStack(spacing: 6) {
                                ProgressView(value: Double(td.xong), total: Double(td.tong)).tint(AppColors.success).frame(maxWidth: 120)
                                Text("\(td.xong)/\(td.tong)").font(.system(size: 11.5, weight: .semibold).monospacedDigit()).foregroundColor(AppColors.textTertiary)
                                if vm.daLuu.contains(b.n) {
                                    Image(systemName: "arrow.down.circle.fill").font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                                        .accessibilityLabel("Đã lưu để học ngoại tuyến")
                                }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down").font(.system(size: 13, weight: .bold)).foregroundColor(AppColors.textTertiary)
                        .rotationEffect(.degrees(mo ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if mo {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(nhomBai(b).enumerated()), id: \.offset) { _, cap in
                        let (ten, ds) = cap
                        if let ten {
                            Text(ten.uppercased()).font(.system(size: 11, weight: .heavy)).kerning(0.5)
                                .foregroundColor(mauNhom(ten)).padding(.top, 14).padding(.bottom, 2)
                        }
                        ForEach(ds) { l in
                            hang(.bai(buoi: b.n, id: l.id), title: l.title, kind: l.kind, phut: l.minutes, nhom: l.nhom)
                                .disabled(!l.ready).opacity(l.ready ? 1 : 0.45)
                        }
                    }
                }
                .padding(.top, 6)
            }
        }
        .theKhoiSH()
    }

    /// Tên buổi = "Bài N", kèm chủ đề lấy từ bài HỘI THOẠI đầu (nếu có) — web không có tên buổi riêng.
    private func tieuDeBuoi(_ b: BuoiSH) -> String {
        if let hoiThoai = b.bai.first(where: { $0.kind == "conversation" && ($0.nhom ?? "Bài học") == "Bài học" }) {
            let t = PhanTichChuSH.tron(hoiThoai.title)
            if let r = t.range(of: "— ") { return "\(b.ten) · " + t[r.upperBound...] }
        }
        if let dau = b.bai.first, b.bai.allSatisfy({ $0.kind == dau.kind }) { return "\(b.ten) · \(vm.khoa?.nhan(dau.kind) ?? "")" }
        return b.ten
    }

    private func tomTat(_ b: BuoiSH) -> String {
        var p: [String] = ["\(b.bai.filter(\.ready).count) bài"]
        if b.phut > 0 { p.append(b.phut >= 90 ? "~\(Int((Double(b.phut) / 60).rounded())) giờ" : "~\(b.phut) phút") }
        if b.soTu > 0 { p.append("\(b.soTu) từ") }
        let np = b.nguPhap.filter { $0.contains("ポイント") }.count
        if np > 0 { p.append("\(np) ポイント") }
        if !b.baiTap.isEmpty { p.append("\(b.baiTap.count) bài tập") }
        return p.joined(separator: " · ")
    }

    private func nhomBai(_ b: BuoiSH) -> [(String?, [BaiMetaSH])] {
        let coNhom = Set(b.bai.compactMap(\.nhom)).count > 1
        guard coNhom else { return [(nil, b.bai)] }
        var out: [(String?, [BaiMetaSH])] = []
        for l in b.bai {
            let t = l.nhom ?? "Bài học"
            if let i = out.firstIndex(where: { $0.0 == t }) { out[i].1.append(l) } else { out.append((t, [l])) }
        }
        return out
    }

    private func mauNhom(_ t: String) -> Color {
        switch t {
        case "Theo slide lớp": return AppColors.info
        case "Luyện thêm": return AppColors.success
        case "Theo sách": return AppColors.textSecondary
        default: return AppColors.primary
        }
    }

    // MARK: Một hàng bài

    private func hang(_ m: MucDocSH, title: String, kind: String, phut: Int, nhom: String?, nhanRieng: String? = nil) -> some View {
        let xong = vm.daXong.contains(m.id)
        let mau = mauLoaiSH(vm.khoa, kind)
        return NavigationLink { BaiSachHocView(vm: vm, muc: m) } label: {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle().strokeBorder(xong ? AppColors.success : mau.opacity(0.55), lineWidth: 2)
                        .background(Circle().fill(xong ? AppColors.success : Color.clear))
                    if xong { Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundColor(.white) }
                }
                .frame(width: 22, height: 22)
                .padding(.top, 1)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(nhanRieng ?? vm.khoa?.nhan(kind) ?? kind).font(.system(size: 11, weight: .bold)).foregroundColor(mau)
                        if phut > 0 { Text("· ~\(phut) phút").font(.system(size: 11)).foregroundColor(AppColors.textTertiary) }
                    }
                    ChuSH(text: title, co: 15.5, mau: xong ? .phu : .chinh)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary).padding(.top, 4)
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Chân trang + menu

    private func chanTrang(_ khoa: KhoaSH) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Nội dung giống hệt bản web (cuongthai.com\(khoa.duongWeb ?? "")) — cập nhật mỗi lần web phát hành. Bài đã mở được lưu trên máy để học cả khi không có mạng.")
            Text("Phiên bản \(khoa.phienBan.prefix(8)) · đã lưu \(ByteCountFormatter.string(fromByteCount: Int64(dungLuong), countStyle: .file))")
        }
        .font(.system(size: 11.5)).foregroundColor(AppColors.textTertiary)
        .padding(.top, 8)
    }

    private var menu: some View {
        Menu {
            if let t = vm.dangTaiHet {
                Text("Đang tải \(t.xong)/\(t.tong)…")
            } else {
                Button {
                    Task { await vm.taiHet(); dungLuong = await vm.dungLuongDaLuu() }
                } label: { Label("Tải hết để học ngoại tuyến", systemImage: "arrow.down.circle") }
            }
            Button { Task { await vm.nap() } } label: { Label("Kiểm tra bản mới", systemImage: "arrow.clockwise") }
        } label: {
            if vm.dangTaiHet != nil { ProgressView() } else { Image(systemName: "ellipsis.circle") }
        }
    }
}

// MARK: - Thẻ cửa vào (màn Tiếng Nhật)

struct TheKhoaSachHoc: View {
    let moTa: KhoaSachHocMoTa
    var body: some View {
        HStack(spacing: 14) {
            Text("できる").font(.system(size: 15, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.6)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(RoundedRectangle(cornerRadius: 14).fill(LinearGradient(colors: [Color(hex: 0xBE123C), Color(hex: 0x7A45E8)], startPoint: .topLeading, endPoint: .bottomTrailing)))
            VStack(alignment: .leading, spacing: 3) {
                Text(moTa.ten).font(.system(size: 16.5, weight: .bold)).foregroundColor(AppColors.textPrimary)
                Text(moTa.moTa).font(.system(size: 13)).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(AppColors.textTertiary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
        .overlay(RoundedRectangle(cornerRadius: CornerRadius.large).strokeBorder(AppColors.primary.opacity(0.35), lineWidth: 1.2))
    }
}
