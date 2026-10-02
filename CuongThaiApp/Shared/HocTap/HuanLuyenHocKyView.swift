import SwiftUI
import PhotosUI

/// Huấn luyện học kỳ — bản iOS/iPad của /hoc-tap. Cùng dữ liệu với web và app
/// desktop (`/api/v1/hoc-tap`). Soạn kế hoạch AI làm trên web (mất vài phút);
/// ở đây: xem tỷ lệ trượt, bấm giờ, nộp bằng chứng (chữ, ẢNH chụp), xem điểm.
/// KHÔNG có nút tự tích — chỉ AI/Claude chấm (yêu cầu của người dùng 02/10/2026).
@MainActor
final class HuanLuyenHocKyVM: ObservableObject {
    @Published var tq: TongQuanHT?
    @Published var loi: String?
    @Published var dangTai = false
    @Published var nhanXet: String?
    @Published var dangNhanXet = false

    func nap() async {
        dangTai = true; defer { dangTai = false }
        do { tq = try await APIClient.shared.request(.hocTapTongQuan); loi = nil }
        catch { loi = error.localizedDescription }
    }

    func xinNhanXet() async {
        dangNhanXet = true; defer { dangNhanXet = false }
        do { let r: NhanXetHT = try await APIClient.shared.request(.hocTapNhanXet); nhanXet = r.loi }
        catch { nhanXet = "⚠️ " + error.localizedDescription }
    }
}

struct DongHoRuiRoHT: View {
    let tyLe: Int
    let mucDo: String
    var nho = false
    @State private var hien: Double = 0

    var body: some View {
        let m = HT.mau(mucDo)
        ZStack {
            Circle().trim(from: 0.5, to: 1).stroke(AppColors.border, style: StrokeStyle(lineWidth: nho ? 7 : 13, lineCap: .round))
            Circle().trim(from: 0.5, to: 0.5 + 0.5 * hien / 100)
                .stroke(m, style: StrokeStyle(lineWidth: nho ? 7 : 13, lineCap: .round))
            VStack(spacing: 0) {
                Text("\(tyLe)%").font(.system(size: nho ? 18 : 34, weight: .black, design: .rounded)).foregroundColor(m)
                if !nho { Text(HT.nhanMuc(mucDo)).font(.system(size: 10, weight: .heavy)).foregroundColor(m) }
            }
            .offset(y: nho ? -8 : -16)
        }
        .frame(width: nho ? 76 : 150, height: nho ? 76 : 150)
        .frame(height: nho ? 46 : 92, alignment: .top)
        .onAppear { withAnimation(.easeOut(duration: 0.9)) { hien = Double(tyLe) } }
        .onChange(of: tyLe) { _, v in withAnimation(.easeOut(duration: 0.6)) { hien = Double(v) } }
        .accessibilityLabel(String(format: T("Tỷ lệ trượt %d phần trăm"), tyLe))
    }
}

struct ThanhTienDoHT: View {
    let tienDo: Int
    let kyVong: Int
    var mau: Color = AppColors.primary
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(AppColors.border)
                Capsule().fill(mau).frame(width: g.size.width * CGFloat(min(100, tienDo)) / 100)
                if kyVong > 0 {
                    Rectangle().fill(AppColors.textPrimary.opacity(0.7)).frame(width: 2)
                        .offset(x: g.size.width * CGFloat(min(100, kyVong)) / 100)
                }
            }
        }
        .frame(height: 8)
    }
}

struct DongViecHT: View {
    let v: ViecGonHT
    var body: some View {
        let (han, tre) = HT.conLai(v.hanChot)
        let (tt, mauTT) = HT.tenTrangThai(v.trangThai)
        HStack(spacing: Spacing.sm) {
            Text(HT.bieuTuong(v.loai)).font(.system(size: 20))
            VStack(alignment: .leading, spacing: 2) {
                Text(v.tieuDe).font(.system(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                HStack(spacing: 6) {
                    Text(v.maMon).font(.system(size: 11, weight: .bold)).foregroundColor(HT.mauMon(v.mau))
                    Text("⏱ \(v.thoiLuongPhut)′").font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                    Text(han).font(.system(size: 11, weight: tre ? .bold : .regular)).foregroundColor(tre ? AppColors.error : AppColors.textTertiary)
                }
            }
            Spacer(minLength: 0)
            Text(tt).font(.system(size: 10, weight: .bold)).foregroundColor(mauTT)
                .padding(.horizontal, 7).padding(.vertical, 3).background(Capsule().fill(mauTT.opacity(0.13)))
        }
        .padding(Spacing.sm)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.backgroundCard))
        .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 2).fill(HT.mauMon(v.mau)).frame(width: 4).padding(.vertical, 6) }
    }
}

struct HuanLuyenHocKyView: View {
    @StateObject private var vm = HuanLuyenHocKyVM()
    @State private var moViec: Int?
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let tq = vm.tq {
                    if tq.hocKy == nil { chuaCoKy } else { noiDung(tq) }
                } else if let loi = vm.loi {
                    Text(loi).foregroundColor(AppColors.error).font(.system(size: 14))
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary.ignoresSafeArea())
        .navigationTitle(T("Huấn luyện học kỳ"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await vm.nap() }
        .task { await vm.nap() }
        .sheet(item: Binding(get: { moViec.map { IDHT(id: $0) } }, set: { moViec = $0?.id })) { x in
            NavigationStack { ViecHTView(viecId: x.id) { Task { await vm.nap() } } }
        }
    }

    private var chuaCoKy: some View {
        VStack(spacing: Spacing.md) {
            Text("🎯").font(.system(size: 50))
            Text(T("Chưa thiết lập kỳ học")).font(.system(size: 18, weight: .bold))
            Text(T("Tạo kỳ học, thêm môn và cho AI soạn kế hoạch trên web — xong là app hiện tiến độ, tỷ lệ trượt và việc hôm nay."))
                .font(.system(size: 14)).foregroundColor(AppColors.textSecondary).multilineTextAlignment(.center)
            Button(T("Mở trên web")) { if let u = URL(string: "https://cuongthai.com/hoc-tap") { openURL(u) } }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity).padding(.top, 40)
    }

    @ViewBuilder
    private func noiDung(_ tq: TongQuanHT) -> some View {
        let m = HT.mau(tq.ruiRoKy.mucDo)
        // Đầu: tuần + đồng hồ
        VStack(spacing: Spacing.sm) {
            Text("\(tq.hocKy?.ten ?? "") · " + String(format: T("Tuần %d/%d"), tq.tuan, tq.hocKy?.soTuan ?? 10))
                .font(.system(size: 13, weight: .semibold)).foregroundColor(AppColors.textSecondary)
            DongHoRuiRoHT(tyLe: tq.ruiRoKy.tyLe, mucDo: tq.ruiRoKy.mucDo)
            Text(T("TỶ LỆ TRƯỢT CẢ KỲ")).font(.system(size: 12, weight: .black)).foregroundColor(m)
            VStack(alignment: .leading, spacing: 4) {
                HStack { Text(T("Tiến độ đã được AI tích")).font(.system(size: 11)); Spacer(); Text("\(tq.tienDoKy ?? 0)%").font(.system(size: 11, weight: .bold)) }
                    .foregroundColor(AppColors.textSecondary)
                ThanhTienDoHT(tienDo: tq.tienDoKy ?? 0, kyVong: 0, mau: m)
            }
            HStack(spacing: 8) {
                chip("\(tq.quaHan.count) " + T("quá hạn"), AppColors.error)
                chip("\(tq.choCham.count) " + T("đang chấm"), Color(hex: 0xA855F7))
                chip("\(tq.homNay.count) " + T("hôm nay"), AppColors.secondary)
            }
            Button {
                Task { await vm.xinNhanXet() }
            } label: {
                Label(vm.dangNhanXet ? T("AI đang xem…") : T("AI huấn luyện viên nhận xét"), systemImage: "sparkles")
                    .font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered).disabled(vm.dangNhanXet || tq.mon.isEmpty)
            if let nx = vm.nhanXet { NoiDungMarkdown(noiDung: nx).frame(maxWidth: .infinity, alignment: .leading) }
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: 20).fill(LinearGradient(colors: [m.opacity(0.14), AppColors.backgroundCard], startPoint: .topLeading, endPoint: .bottomTrailing)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(m.opacity(0.45), lineWidth: tq.ruiRoKy.mucDo == "do" ? 2 : 1))

        if !tq.quaHan.isEmpty {
            tieuDe("⚠️ " + T("Quá hạn"), AppColors.error)
            ForEach(tq.quaHan.prefix(8)) { v in Button { moViec = v.id } label: { DongViecHT(v: v) }.buttonStyle(.plain) }
        }
        tieuDe("📌 " + T("Làm hôm nay"), AppColors.textPrimary)
        if tq.homNay.isEmpty { Text(T("Không có việc nào — soạn kế hoạch trên web.")).font(.system(size: 13)).foregroundColor(AppColors.textTertiary) }
        ForEach(tq.homNay) { v in Button { moViec = v.id } label: { DongViecHT(v: v) }.buttonStyle(.plain) }
        if !tq.choCham.isEmpty {
            tieuDe("⏳ " + T("Đang chấm"), Color(hex: 0xA855F7))
            ForEach(tq.choCham) { v in Button { moViec = v.id } label: { DongViecHT(v: v) }.buttonStyle(.plain) }
        }

        tieuDe(T("Môn học"), AppColors.textPrimary)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: Spacing.sm)], spacing: Spacing.sm) {
            ForEach(tq.mon) { mon in
                NavigationLink { MonHTView(monId: mon.id) } label: { theMon(mon) }.buttonStyle(.plain)
            }
        }
    }

    private func theMon(_ mon: MonHT) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(mon.maMon).font(.system(size: 18, weight: .black)).foregroundColor(HT.mauMon(mon.mau))
                    Text(mon.ten).font(.system(size: 12)).foregroundColor(AppColors.textTertiary).lineLimit(1)
                }
                Spacer()
                DongHoRuiRoHT(tyLe: mon.ruiRo.tyLe, mucDo: mon.ruiRo.mucDo, nho: true)
            }
            HStack {
                Text(String(format: T("%d/%d việc đạt"), mon.datViec, mon.tongViec)).font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                Spacer()
                Text("\(mon.ruiRo.tienDo)% · " + String(format: T("cần %d%%"), mon.ruiRo.kyVong)).font(.system(size: 11, weight: .bold)).foregroundColor(HT.mau(mon.ruiRo.mucDo))
            }
            ThanhTienDoHT(tienDo: mon.ruiRo.tienDo, kyVong: mon.ruiRo.kyVong, mau: HT.mauMon(mon.mau))
            if let t = mon.thiSapToi {
                Label(String(format: T("Thi %@ còn %d ngày"), t.loai, t.conNgay), systemImage: "calendar.badge.clock")
                    .font(.system(size: 11, weight: .semibold)).foregroundColor(t.conNgay <= 7 ? AppColors.error : AppColors.textSecondary)
            }
            if let k = mon.viecKeTiep {
                Text("▶ " + k.tieuDe).font(.system(size: 12)).foregroundColor(AppColors.textPrimary).lineLimit(1)
            }
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.backgroundCard))
        .overlay(alignment: .top) { Rectangle().fill(HT.mauMon(mon.mau)).frame(height: 4).clipShape(RoundedRectangle(cornerRadius: 2)) }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func tieuDe(_ s: String, _ c: Color) -> some View {
        Text(s).font(.system(size: 16, weight: .bold)).foregroundColor(c).padding(.top, 4)
    }

    private func chip(_ s: String, _ c: Color) -> some View {
        Text(s).font(.system(size: 11, weight: .bold)).foregroundColor(c)
            .padding(.horizontal, 9).padding(.vertical, 4).background(Capsule().fill(c.opacity(0.12)))
    }
}

struct IDHT: Identifiable { let id: Int }

// MARK: - Một môn

struct MonHTView: View {
    let monId: Int
    @State private var d: ChiTietMonHT?
    @State private var loi: String?
    @State private var moViec: Int?

    var body: some View {
        List {
            if let d {
                Section {
                    HStack(spacing: Spacing.md) {
                        DongHoRuiRoHT(tyLe: d.ruiRo.tyLe, mucDo: d.ruiRo.mucDo, nho: true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(d.mon.ten).font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                            ThanhTienDoHT(tienDo: d.ruiRo.tienDo, kyVong: d.ruiRo.kyVong, mau: HT.mauMon(d.mon.mau))
                            Text("\(d.ruiRo.tienDo)% / " + String(format: T("cần %d%%"), d.ruiRo.kyVong)).font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                        }
                    }
                    ForEach(d.ruiRo.lyDo, id: \.self) { l in Text("• " + l).font(.system(size: 12)).foregroundColor(HT.mau(d.ruiRo.mucDo)) }
                }
                ForEach(Dictionary(grouping: d.viec, by: \.tuan).keys.sorted(), id: \.self) { tuan in
                    Section(String(format: T("Tuần %d"), tuan) + (tuan == d.tuan ? " · " + T("tuần này") : "")) {
                        ForEach(d.viec.filter { $0.tuan == tuan }) { v in
                            Button { moViec = v.id } label: {
                                DongViecHT(v: ViecGonHT(id: v.id, monId: monId, maMon: d.mon.maMon, mau: d.mon.mau, tieuDe: v.tieuDe, loai: v.loai,
                                                        hanChot: v.hanChot, thoiLuongPhut: v.thoiLuongPhut, trangThai: v.trangThai,
                                                        batDauLuc: v.batDauLuc, diem: v.diem, tuan: v.tuan))
                            }
                            .buttonStyle(.plain).listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                        }
                    }
                }
            } else if let loi {
                Text(loi).foregroundColor(AppColors.error)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(d?.mon.maMon ?? "…")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await nap() }
        .task { await nap() }
        .sheet(item: Binding(get: { moViec.map { IDHT(id: $0) } }, set: { moViec = $0?.id })) { x in
            NavigationStack { ViecHTView(viecId: x.id) { Task { await nap() } } }
        }
    }

    private func nap() async {
        do { d = try await APIClient.shared.request(.hocTapMon(id: monId)); loi = nil }
        catch { loi = error.localizedDescription }
    }
}

// MARK: - Một việc: bấm giờ, nộp, xem điểm

struct ViecHTView: View {
    let viecId: Int
    let onDoi: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var v: ViecHT?
    @State private var loi: String?
    @State private var noiDung = ""
    @State private var link = ""
    @State private var anh: [PhotosPickerItem] = []
    @State private var anhDaTai: [[String: String]] = []
    @State private var dangTai = false
    @State private var dangNop = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let v { noiDungViec(v) } else if let loi { Text(loi).foregroundColor(AppColors.error) } else { ProgressView() }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary.ignoresSafeArea())
        .navigationTitle(v.map { HT.bieuTuong($0.loai) + " " + $0.tieuDe } ?? "…")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(T("Đóng")) { dismiss() } } }
        .task { await nap() }
        .task(id: v?.trangThai) {
            // Đang chấm ⇒ hỏi lại mỗi 4 giây.
            guard v?.trangThai == "CHO_CHAM" else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                await nap()
                if v?.trangThai != "CHO_CHAM" { onDoi(); break }
            }
        }
        .onChange(of: anh) { _, ds in Task { await taiAnh(ds) } }
    }

    @ViewBuilder
    private func noiDungViec(_ v: ViecHT) -> some View {
        let (han, tre) = HT.conLai(v.hanChot)
        let (tt, mauTT) = HT.tenTrangThai(v.trangThai)
        HStack(spacing: 6) {
            Text(v.mon?.maMon ?? "").font(.system(size: 12, weight: .bold)).foregroundColor(HT.mauMon(v.mon?.mau))
            Text(String(format: T("Tuần %d · ⏱ %d phút"), v.tuan, v.thoiLuongPhut)).font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
            Text(han).font(.system(size: 12, weight: tre ? .bold : .regular)).foregroundColor(tre ? AppColors.error : AppColors.textSecondary)
            Spacer()
            Text(tt).font(.system(size: 11, weight: .bold)).foregroundColor(mauTT)
        }
        if let l = v.lienKet, let u = URL(string: l.hasPrefix("http") ? l : "https://cuongthai.com" + l) {
            Link(destination: u) { Label(T("Mở bài học"), systemImage: "arrow.up.right.square") }.font(.system(size: 14, weight: .semibold))
        }
        if let hd = v.huongDan, !hd.isEmpty {
            NoiDungMarkdown(noiDung: hd).padding(Spacing.sm).background(RoundedRectangle(cornerRadius: 14).fill(AppColors.backgroundCard))
        }
        if let yc = v.yeuCauBangChung, !yc.isEmpty {
            Text("📎 " + T("Phải nộp: ") + yc).font(.system(size: 13)).padding(Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.warning.opacity(0.13)))
        }

        if let diem = v.diem, v.chamLuc != nil {
            let dat = v.trangThai == "DAT"
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(dat ? "✅ " + T("ĐẠT") : "↻ " + T("CHƯA ĐẠT — sửa rồi nộp lại")).font(.system(size: 14, weight: .bold))
                    Spacer()
                    Text(String(format: "%.1f/10", diem)).font(.system(size: 26, weight: .black, design: .rounded)).foregroundColor(dat ? AppColors.success : Color(hex: 0xF97316))
                }
                Text(T("Chấm bởi ") + (v.nguoiCham == "CLAUDE" ? "Claude" : "AI (gpt-6-sol)")).font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                if let nx = v.nhanXet { NoiDungMarkdown(noiDung: nx) }
                danhSach("💪 " + T("Làm tốt"), v.loiCanSua?.diemManh, AppColors.success)
                danhSach("❌ " + T("Lỗi cần sửa"), v.loiCanSua?.loi, AppColors.error)
                danhSach("📈 " + T("Cần cải thiện"), v.loiCanSua?.canCaiThien, AppColors.warning)
            }
            .padding(Spacing.md)
            .background(RoundedRectangle(cornerRadius: 16).fill((dat ? AppColors.success : Color(hex: 0xF97316)).opacity(0.1)))
        }

        if v.trangThai == "CHO_CHAM" {
            HStack(spacing: 10) {
                ProgressView()
                Text(v.nhanXet?.hasPrefix("AI chưa chấm") == true ? (v.nhanXet ?? "") : T("AI đang đọc bằng chứng và chấm… (20–60 giây)")).font(.system(size: 13))
            }
            if v.nhanXet?.hasPrefix("AI chưa chấm") == true, let bc = v.bangChung.first {
                Button(T("Chấm lại")) { Task { try? await APIClient.shared.send(.hocTapChamLai(bangChungId: bc.id)); await nap() } }
            }
        }

        if v.trangThai != "DAT" && v.trangThai != "CHO_CHAM" {
            if let bd = v.batDauLuc.flatMap(HT.ngay) {
                DongHoBamGioHT(batDau: bd, phut: v.thoiLuongPhut)
            } else {
                Button {
                    Task { _ = try? await APIClient.shared.send(.hocTapBatDau(id: v.id)); await nap(); onDoi() }
                } label: {
                    Label(String(format: T("Bắt đầu — bấm giờ %d phút"), v.thoiLuongPhut), systemImage: "play.fill")
                        .font(.system(size: 16, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(T("Nộp bằng chứng")).font(.system(size: 15, weight: .bold))
                TextField(T("Kết quả, câu trả lời, đoạn code…"), text: $noiDung, axis: .vertical)
                    .lineLimit(4...12).textFieldStyle(.roundedBorder)
                TextField(T("Link GitHub (tuỳ chọn)"), text: $link).textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never).keyboardType(.URL)
                HStack {
                    PhotosPicker(selection: $anh, maxSelectionCount: 6, matching: .images) {
                        Label(dangTai ? T("Đang tải ảnh…") : String(format: T("Ảnh (%d)"), anhDaTai.count), systemImage: "photo.on.rectangle")
                    }
                    .disabled(dangTai)
                    Spacer()
                    Button {
                        Task { await nop(v) }
                    } label: {
                        Label(dangNop ? T("Đang nộp…") : T("Nộp cho AI chấm"), systemImage: "paperplane.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(dangNop || dangTai || (noiDung.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && link.isEmpty && anhDaTai.isEmpty))
                }
                Text(T("AI chỉ tích khi bằng chứng đủ.")).font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
            }
            .padding(Spacing.md)
            .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.backgroundCard))
        }
        if let loi { Text(loi).font(.system(size: 13)).foregroundColor(AppColors.error) }

        if !v.bangChung.isEmpty {
            DisclosureGroup(String(format: T("Lịch sử nộp (%d)"), v.bangChung.count)) {
                ForEach(v.bangChung) { b in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(String(format: T("Lần %d"), b.lanNop) + (b.nopTre ? " · ⏰ " + T("trễ") : ""))
                            Spacer()
                            Text(b.diem.map { String(format: "%.1f/10", $0) } ?? T("đang chấm")).bold()
                        }
                        .font(.system(size: 12))
                        if let n = b.noiDung { Text(n).font(.system(size: 11, design: .monospaced)).lineLimit(6).foregroundColor(AppColors.textSecondary) }
                    }
                    .padding(.vertical, 4)
                }
            }
            .font(.system(size: 14, weight: .semibold))
        }
    }

    private func danhSach(_ tieuDe: String, _ ds: [String]?, _ mau: Color) -> some View {
        Group {
            if let ds, !ds.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tieuDe).font(.system(size: 12, weight: .bold)).foregroundColor(mau)
                    ForEach(ds, id: \.self) { Text("• " + $0).font(.system(size: 13)) }
                }
            }
        }
    }

    private func nap() async {
        do { v = try await APIClient.shared.request(.hocTapViec(id: viecId)); loi = nil }
        catch { loi = error.localizedDescription }
    }

    private func taiAnh(_ ds: [PhotosPickerItem]) async {
        guard !ds.isEmpty else { return }
        dangTai = true; defer { dangTai = false; anh = [] }
        for item in ds {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let img = UIImage(data: data), let jpg = img.jpegData(compressionQuality: 0.85) else { continue }
            do {
                let f = try await APIClient.shared.upload(data: jpg, fileName: "bang-chung-\(Int(Date().timeIntervalSince1970)).jpg", mimeType: "image/jpeg", category: "images")
                anhDaTai.append(["url": f.url, "ten": "ảnh", "loai": "image/jpeg"])
            } catch { loi = error.localizedDescription }
        }
    }

    private func nop(_ v: ViecHT) async {
        dangNop = true; defer { dangNop = false }
        var body: [String: Any] = [:]
        let nd = noiDung.trimmingCharacters(in: .whitespacesAndNewlines)
        if !nd.isEmpty { body["noiDung"] = nd }
        if link.hasPrefix("http") { body["lienKet"] = [link] }
        if !anhDaTai.isEmpty { body["tep"] = anhDaTai }
        do {
            try await APIClient.shared.send(.hocTapNop(id: v.id, body))
            noiDung = ""; link = ""; anhDaTai = []
            await nap(); onDoi()
        } catch { loi = error.localizedDescription }
    }
}

struct DongHoBamGioHT: View {
    let batDau: Date
    let phut: Int
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let con = batDau.addingTimeInterval(Double(phut) * 60).timeIntervalSince(ctx.date)
            let qua = con < 0
            let a = Int(abs(con))
            HStack {
                Text(qua ? "⏰ " + T("QUÁ GIỜ ĐÃ HẸN") : "⏱ " + T("Đang bấm giờ")).font(.system(size: 12, weight: .semibold))
                Spacer()
                Text((qua ? "+" : "") + String(format: "%02d:%02d", a / 60, a % 60))
                    .font(.system(size: 26, weight: .black, design: .monospaced))
                    .foregroundColor(qua ? AppColors.error : AppColors.secondary)
            }
            .padding(Spacing.sm)
            .background(RoundedRectangle(cornerRadius: 14).fill((qua ? AppColors.error : AppColors.secondary).opacity(0.1)))
        }
    }
}
