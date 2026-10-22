import SwiftUI
import PhotosUI
import Kingfisher

// MARK: - Hồ sơ của tôi (22/10/2026 — bản 1.1)
//
// Lối vào: đầu tab Account (chạm thẻ tên) · chạm avatar của chính mình ở bất cứ đâu.
// Đổi ảnh đại diện / ảnh bìa NGAY trong app: thư viện (PhotosPicker) hoặc máy ảnh ⇒ cắt (vuông / ngang) ⇒
// `POST /files/upload` (category avatars|covers) ⇒ `PUT /profile {avatarUrl|coverPhotoUrl}` — ĐÚNG hai đường web
// (/settings/profile) và app CuongThai (Chỉnh sửa hồ sơ) dùng ⇒ đổi ở đâu cũng hiện ở mọi nơi (web, hai app, CT Work).
// Sửa tên hiển thị + giới thiệu (`PUT /profile {displayName, bio}`). Công tắc trạng thái hoạt động = cùng công tắc ở
// Account › Quyền riêng tư (CongTacTrangThaiHoatDongCTW). Không gian / dự án của tôi, lối tắt.

@MainActor
final class DoiAnhHoSoVM: ObservableObject {
    enum Loai { case daiDien, bia
        var tiLe: CGFloat { self == .daiDien ? 1 : 3 }
    }
    @Published var dangTai = false
    @Published var loi: String?

    /// Tải ảnh đã cắt lên rồi ghi vào hồ sơ. Trả url mới.
    @discardableResult
    func luu(_ jpeg: Data, loai: Loai) async -> String? {
        dangTai = true; loi = nil
        defer { dangTai = false }
        do {
            let thuMuc = loai == .daiDien ? HoSoAPICTW.thuMucAnhDaiDien : HoSoAPICTW.thuMucAnhBia
            let tep = try await APIClient.shared.upload(data: jpeg, fileName: "\(thuMuc)-\(UUID().uuidString).jpg",
                                                       mimeType: "image/jpeg", category: thuMuc)
            let than = loai == .daiDien ? HoSoAPICTW.thanAnhDaiDien(tep.url) : HoSoAPICTW.thanAnhBia(tep.url)
            try await APIClient.shared.send(.updateProfile(than))
            await AppState.shared.fetchProfile()
            CTWRung.thanhCong()
            return tep.url
        } catch {
            loi = CTW.loi(error)
            CTWRung.loi()
            return nil
        }
    }

    func xoaBia() async {
        dangTai = true; loi = nil
        defer { dangTai = false }
        do {
            try await APIClient.shared.send(.updateProfile(HoSoAPICTW.thanAnhBia(nil)))
            await AppState.shared.fetchProfile()
        } catch { loi = CTW.loi(error) }
    }
}

struct HoSoCuaToiCTW: View {
    var laTamPhu = false
    @EnvironmentObject private var app: AppState
    @ObservedObject private var bangTin = KhoBangTinCTW.shared
    @StateObject private var anh = DoiAnhHoSoVM()
    @StateObject private var duAn = ChonDuAnVM()
    @Environment(\.dismiss) private var dong
    @State private var chonAnh: PhotosPickerItem?
    @State private var moThuVien = false
    @State private var loaiDangDoi: DoiAnhHoSoVM.Loai = .daiDien
    @State private var tamPhu: TamPhu?
    @State private var daChep = false

    enum TamPhu: Identifiable {
        case sua, mayAnh, cat(UIImage, DoiAnhHoSoVM.Loai)
        var id: String {
            switch self { case .sua: return "sua"; case .mayAnh: return "may"; case .cat(_, let l): return "cat\(l == .daiDien ? 1 : 2)" }
        }
    }

    private var u: User? { app.currentUser }
    private var toi: CTWUser {
        CTWUser(id: u?.id ?? 0, username: u?.username, fullName: u?.fullName, displayName: u?.displayName, avatarUrl: u?.avatarUrl)
    }
    private var ten: String { u?.displayName ?? u?.fullName ?? u?.username ?? "—" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DauHoSoCTW(user: toi, anhBia: u?.coverPhotoUrl) {
                    menuAnh(.daiDien) {
                        Image(systemName: "camera.fill")
                            .font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(AppColors.backgroundSecondary))
                            .overlay(Circle().strokeBorder(AppColors.backgroundPrimary, lineWidth: 3))
                    }
                    .accessibilityLabel("Change profile photo")
                    .accessibilityIdentifier("profile.changePhoto")
                } nutBia: {
                    menuAnh(.bia) {
                        Label("Edit cover", systemImage: "camera")
                            .font(.ctw(size: 13, weight: .semibold)).foregroundColor(.white)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Capsule().fill(.black.opacity(0.45)))
                    }
                    .accessibilityIdentifier("profile.changeCover")
                }
                .overlay { if anh.dangTai { ProgressView().controlSize(.large).padding(18).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14)) } }

                VStack(alignment: .leading, spacing: 16) {
                    tieuDe
                    HStack(spacing: 10) {
                        Button { tamPhu = .sua } label: {
                            Label("Edit profile", systemImage: "pencil").font(.ctw(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("profile.edit")
                        Button {
                            if let id = u?.id { UIPasteboard.general.url = HoSoAPICTW.linkHoSo(id); daChep = true; CTWRung.chon() }
                        } label: {
                            Label(daChep ? String(localized: "Copied") : String(localized: "Copy link"), systemImage: daChep ? "checkmark" : "link")
                                .font(.ctw(size: 15, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                    }
                    if let l = anh.loi { CTWErrorBanner(text: l) { anh.loi = nil } }
                    KhoiHoSoCTW(tieuDe: String(localized: "Active status"), bieuTuong: "circlebadge") {
                        CongTacTrangThaiHoatDongCTW()
                    }
                    loiTat
                    khoiKhongGian
                }
                .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 28)
            }
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { if laTamPhu { ToolbarItem(placement: .cancellationAction) { Button("Close") { dong() } } } }
        .task { await app.fetchProfile(); if !duAn.daTai { await duAn.tai() } }
        .photosPicker(isPresented: $moThuVien, selection: $chonAnh, matching: .images)
        .onChange(of: chonAnh) { _, it in
            guard let it else { return }
            Task {
                if let d = try? await it.loadTransferable(type: Data.self), let i = UIImage(data: d) { tamPhu = .cat(i, loaiDangDoi) }
                chonAnh = nil
            }
        }
        .sheet(item: $tamPhu) { t in
            switch t {
            case .sua: SuaHoSoCTW()
            case .mayAnh:
                MayAnh { d in if let i = UIImage(data: d) { Task { try? await Task.sleep(for: .milliseconds(450)); tamPhu = .cat(i, loaiDangDoi) } } }
                    .ignoresSafeArea()
            case .cat(let i, let l):
                CatAnhView(anh: i, tiLe: l.tiLe, tron: l == .daiDien) { jpeg in Task { await anh.luu(jpeg, loai: l) } }
            }
        }
        .onChange(of: daChep) { _, c in if c { Task { try? await Task.sleep(for: .seconds(2)); daChep = false } } }
    }

    private func menuAnh<Nhan: View>(_ l: DoiAnhHoSoVM.Loai, @ViewBuilder nhan: () -> Nhan) -> some View {
        Menu {
            Button { loaiDangDoi = l; chonThuVien() } label: { Label("Choose photo", systemImage: "photo.on.rectangle") }
            if MayAnh.coMayAnh { Button { loaiDangDoi = l; tamPhu = .mayAnh } label: { Label("Take photo", systemImage: "camera") } }
            if l == .bia, u?.coverPhotoUrl != nil {
                Button(role: .destructive) { Task { await anh.xoaBia() } } label: { Label("Remove cover photo", systemImage: "trash") }
            }
        } label: { nhan() }
        .disabled(anh.dangTai)
    }

    private func chonThuVien() {
        #if DEBUG
        // UI test / chụp màn không lái được bảng chọn ảnh của hệ thống ⇒ ảnh mẫu vẽ sẵn.
        if ProcessInfo.processInfo.environment["CT_XEM_ANH_MAU"] == "1" { tamPhu = .cat(Self.anhMau(), loaiDangDoi); return }
        #endif
        moThuVien = true
    }

    #if DEBUG
    static func anhMau() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 900, height: 700)).image { c in
            UIColor(red: 0.31, green: 0.36, blue: 0.84, alpha: 1).setFill(); c.fill(CGRect(x: 0, y: 0, width: 900, height: 700))
            UIColor(red: 0.98, green: 0.75, blue: 0.36, alpha: 1).setFill()
            c.cgContext.fillEllipse(in: CGRect(x: 300, y: 180, width: 300, height: 300))
        }
    }
    #endif

    private var tieuDe: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: ten).font(.ctw(size: 24, weight: .bold)).foregroundColor(AppColors.textPrimary).accessibilityAddTraits(.isHeader)
            if let n = u?.username { Text(verbatim: "@\(n)").font(.ctw(size: 15)).foregroundColor(AppColors.textSecondary) }
            if let b = u?.bio?.trimmingCharacters(in: .whitespacesAndNewlines), !b.isEmpty {
                Text(verbatim: b).font(.ctw(size: 15)).foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 4)
                    .accessibilityIdentifier("profile.bio")
            } else {
                Button { tamPhu = .sua } label: { Label("Add a short bio", systemImage: "plus") .font(.ctw(size: 14, weight: .medium)) }
                    .padding(.top, 2)
            }
        }
    }

    private var loiTat: some View {
        KhoiHoSoCTW(tieuDe: String(localized: "Shortcuts"), bieuTuong: "bolt") {
            hangTat("My Work", "checklist") { if laTamPhu { dong() }; app.muc = .viecCuaToi }
            Divider()
            hangTat("Messages", "bubble.left.and.text.bubble.right") { if laTamPhu { dong() }; KhoTinNhanCTW.shared.moMoDun("tin-nhan") }
            Divider()
            hangTat("Members", "person.2") { if laTamPhu { dong() }; KhoTinNhanCTW.shared.moMoDun("thanh-vien") }
            if bangTin.hien && !laTamPhu {
                Divider()
                NavigationLink {
                    BangTinCTW(cheDo: .hashtag, loc: LocBangTin(kieu: .saved)).navigationTitle("Saved posts")
                } label: { nhanTat("Saved posts", "bookmark") }
                .buttonStyle(.plain)
            }
        }
    }

    private func hangTat(_ chu: LocalizedStringKey, _ bt: String, _ f: @escaping () -> Void) -> some View {
        Button(action: f) { nhanTat(chu, bt) }.buttonStyle(.plain)
    }

    private func nhanTat(_ chu: LocalizedStringKey, _ bt: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: bt).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.primary).frame(width: 26)
            Text(chu).font(.ctw(size: 15)).foregroundColor(AppColors.textPrimary)
            Spacer()
            Image(systemName: "chevron.right").font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary)
        }
        .frame(minHeight: 44).contentShape(Rectangle())
    }

    @ViewBuilder private var khoiKhongGian: some View {
        KhoiHoSoCTW(tieuDe: String(localized: "My workspaces & projects"), bieuTuong: "building.2") {
            if !duAn.daTai { HStack { Spacer(); ProgressView(); Spacer() }.padding(.vertical, 6) }
            ForEach(Array(duAn.nhom.enumerated()), id: \.offset) { i, g in
                if i > 0 { Divider().padding(.vertical, 4) }
                Text(verbatim: g.ws.name).font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                if g.duAn.isEmpty {
                    Text("No projects yet").font(.ctw(size: 13)).foregroundColor(AppColors.textTertiary)
                }
                ForEach(g.duAn.prefix(8), id: \.id) { p in
                    Button {
                        app.luaChon = LuaChonCTW(slug: g.ws.slug, tenKhongGian: g.ws.name, pid: p.id, maDuAn: p.key, tenDuAn: p.name)
                        if laTamPhu { dong() }
                        app.muc = .duAn
                    } label: {
                        HStack(spacing: 10) {
                            CTWProjectMark(ma: p.key, co: 26)
                            Text(verbatim: p.name).font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                            Spacer(minLength: 0)
                            if app.luaChon?.pid == p.id { Text("Current").font(.ctw(size: 11, weight: .semibold)).foregroundColor(AppColors.primary) }
                        }
                        .frame(minHeight: 38).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Sửa hồ sơ (tên hiển thị + giới thiệu)

struct SuaHoSoCTW: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dong
    @State private var ten = ""
    @State private var gioiThieu = ""
    @State private var dangLuu = false
    @State private var loi: String?
    static let tranTen = 100
    static let tranGioiThieu = 300

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Display name", text: $ten).textContentType(.name).accessibilityIdentifier("profile.edit.name")
                } header: { Text("Name") } footer: {
                    Text("Shown to your teammates in CT Work and on cuongthai.com. Your username @\(app.currentUser?.username ?? "") stays the same.")
                }
                Section {
                    TextField("Tell your team what you work on", text: $gioiThieu, axis: .vertical).lineLimit(3...6)
                        .accessibilityIdentifier("profile.edit.bio")
                } header: { Text("Bio") } footer: {
                    Text("\(gioiThieu.count)/\(Self.tranGioiThieu)").foregroundColor(gioiThieu.count > Self.tranGioiThieu ? AppColors.error : AppColors.textTertiary)
                }
                if let loi { Section { CTWErrorBanner(text: loi) } }
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    if dangLuu { ProgressView() } else {
                        Button("Save") { Task { await luu() } }
                            .disabled(ten.count > Self.tranTen || gioiThieu.count > Self.tranGioiThieu)
                            .accessibilityIdentifier("profile.edit.save")
                    }
                }
            }
            .onAppear {
                ten = app.currentUser?.displayName ?? app.currentUser?.fullName ?? ""
                gioiThieu = app.currentUser?.bio ?? ""
            }
        }
    }

    private func luu() async {
        dangLuu = true; loi = nil
        defer { dangLuu = false }
        do {
            try await APIClient.shared.send(.updateProfile(HoSoAPICTW.thanSua(ten: ten, gioiThieu: gioiThieu)))
            await app.fetchProfile()
            CTWRung.thanhCong()
            dong()
        } catch { loi = CTW.loi(error) }
    }
}

// MARK: - Cắt ảnh (kéo + chụm), khung tròn cho ảnh đại diện, khung ngang cho ảnh bìa

struct CatAnhView: View {
    let anh: UIImage
    /// rộng ÷ cao của khung cắt.
    let tiLe: CGFloat
    var tron = true
    let xong: (Data) -> Void
    @Environment(\.dismiss) private var dong
    @State private var phong: CGFloat = 1
    @State private var phongGoc: CGFloat = 1
    @State private var lech: CGSize = .zero
    @State private var lechGoc: CGSize = .zero

    /// Ảnh đã xoay đúng chiều, theo ĐIỂM ẢNH (scale 1) ⇒ toạ độ cắt khớp `cgImage`.
    private var goc: UIImage {
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        let s = CGSize(width: anh.size.width * anh.scale, height: anh.size.height * anh.scale)
        return UIGraphicsImageRenderer(size: s, format: f).image { _ in anh.draw(in: CGRect(origin: .zero, size: s)) }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { g in
                let rong = min(g.size.width - 32, 560)
                let khung = CGSize(width: rong, height: rong / tiLe)
                let co = CGSize(width: anh.size.width, height: anh.size.height)
                let tl = CatAnhCTW.tiLePhu(anh: co, khung: khung) * phong
                ZStack {
                    Color.black
                    Image(uiImage: anh).resizable().scaledToFill()
                        .frame(width: co.width * tl, height: co.height * tl)
                        .offset(lech)
                    LopCatCTW(khung: khung, tron: tron).allowsHitTesting(false)
                }
                .frame(width: g.size.width, height: g.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { v in
                            lech = CatAnhCTW.gioiHan(lech: CGSize(width: lechGoc.width + v.translation.width, height: lechGoc.height + v.translation.height),
                                                     anh: co, tiLe: tl, khung: khung)
                        }
                        .onEnded { _ in lechGoc = lech }
                        .simultaneously(with: MagnifyGesture()
                            .onChanged { v in phong = min(5, max(1, phongGoc * v.magnification)) }
                            .onEnded { _ in
                                phongGoc = phong
                                let t2 = CatAnhCTW.tiLePhu(anh: co, khung: khung) * phong
                                lech = CatAnhCTW.gioiHan(lech: lech, anh: co, tiLe: t2, khung: khung); lechGoc = lech
                            })
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Use photo") { cat(khung: khung, tiLeHien: tl) }.accessibilityIdentifier("crop.use")
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(tron ? "Move and scale" : "Adjust cover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .overlay(alignment: .bottom) {
                Text("Pinch to zoom, drag to move").font(.ctw(size: 13)).foregroundColor(.white.opacity(0.8)).padding(.bottom, 30)
            }
        }
        .interactiveDismissDisabled()
    }

    private func cat(khung: CGSize, tiLeHien: CGFloat) {
        let g = goc
        // Ảnh hiển thị theo điểm (anh.size); ảnh gốc theo điểm ảnh ⇒ đổi tỉ lệ một lần.
        let heSo = anh.scale
        let vung = CatAnhCTW.vungCat(anh: g.size, tiLe: tiLeHien / heSo, lech: lech, khung: khung)
        guard let cg = g.cgImage?.cropping(to: vung) else { dong(); return }
        let ra = CatAnhCTW.coXuat(tiLeKhung: tiLe)
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        let anhRa = UIGraphicsImageRenderer(size: ra, format: f).image { _ in UIImage(cgImage: cg).draw(in: CGRect(origin: .zero, size: ra)) }
        if let d = anhRa.jpegData(compressionQuality: 0.86) { xong(d) }
        dong()
    }
}

/// Lớp tối bên ngoài khung cắt (khoét tròn / chữ nhật bo).
private struct LopCatCTW: View {
    let khung: CGSize
    let tron: Bool
    var body: some View {
        GeometryReader { g in
            let r = CGRect(x: (g.size.width - khung.width) / 2, y: (g.size.height - khung.height) / 2, width: khung.width, height: khung.height)
            Path { p in
                p.addRect(CGRect(origin: .zero, size: g.size))
                if tron { p.addEllipse(in: r) } else { p.addRoundedRect(in: r, cornerSize: CGSize(width: 12, height: 12)) }
            }
            .fill(Color.black.opacity(0.6), style: FillStyle(eoFill: true))
            Group {
                if tron { Circle().strokeBorder(.white.opacity(0.85), lineWidth: 1.5) }
                else { RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.85), lineWidth: 1.5) }
            }
            .frame(width: r.width, height: r.height).position(x: r.midX, y: r.midY)
        }
    }
}
