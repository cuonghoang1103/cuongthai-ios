import SwiftUI
import Combine

// MARK: - Bảng tin (danh sách) — dùng cho: My Work › Bảng tin (gộp) · mô-đun dự án · bảng tin không gian · #hashtag
//
// Cột giữa rộng tối đa 680 pt (iPad đọc như LinkedIn/X, không kéo dài chữ hết màn). Kéo để làm mới, cuộn tới gần
// cuối ⇒ tải trang sau (con trỏ), khung xương có ánh lướt lúc tải đầu, thẻ hiện lần lượt ở lần nạp đầu, viên
// "N bài mới" từ socket, chạm lại tab My Work ⇒ cuộn lên đầu. Ô trống có minh hoạ + "Tạo bài viết đầu tiên".

/// Chạm lại tab đang chọn (iPhone) — `KhungTabCTW` phát, màn gốc của tab cuộn lên đầu.
enum ChamLaiTabCTW {
    static let suKien = PassthroughSubject<MucCTW, Never>()
}

struct BangTinCTW: View {
    enum CheDo: Equatable { case gop, duAn, khongGian, hashtag }

    let cheDo: CheDo
    /// Hàng đầu (công tắc Issues · Agenda · Bảng tin của My Work) — nằm trong danh sách để thẳng lề.
    var dau: AnyView? = nil
    /// Nơi đăng mặc định của ô soạn từ màn này.
    var noiMacDinh: NoiDangBangTin? = nil

    @StateObject private var vm: BangTinVM
    @StateObject private var dp = DieuPhoiBaiCTW()
    @ObservedObject private var kho = KhoBangTinCTW.shared
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var hieuUngDau = true
    @State private var mocCuon = UUID()

    init(cheDo: CheDo, loc: LocBangTin, dau: AnyView? = nil, noiMacDinh: NoiDangBangTin? = nil) {
        self.cheDo = cheDo
        self.dau = dau
        self.noiMacDinh = noiMacDinh
        _vm = StateObject(wrappedValue: BangTinVM(loc: loc))
    }

    private var noiDang: NoiDangBangTin? {
        if let noiMacDinh, kho.noiDang.contains(noiMacDinh) { return noiMacDinh }
        if let pid = vm.loc.pid { return kho.noiDang.first { $0.duAn?.id == pid } }
        if let ws = vm.loc.ws { return kho.noiDang.first { $0.ws.id == ws && $0.duAn == nil } ?? kho.noiDang.first { $0.ws.id == ws } }
        return kho.noiDang.first { $0.duAn?.id == app.luaChon?.pid } ?? kho.noiDang.first
    }

    var body: some View {
        ScrollViewReader { cuon in
            ScrollView {
                LazyVStack(spacing: 12) {
                    Color.clear.frame(height: 0).id("dau")
                    if let dau { dau }
                    if cheDo != .hashtag { thanhLoc }
                    if kho.quanTriDuoc, (kho.phamVi?.openReports ?? 0) > 0, cheDo != .hashtag { bangKiemDuyet }
                    if kho.coTheDang && noiDang != nil && cheDo != .hashtag && (vm.loc.kieu == .all || vm.loc.kieu == .mine) { oDang }
                    noiDung
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
                .animation(.snappy(duration: 0.3), value: vm.bai.map(\.id))
            }
            .scrollDismissesKeyboard(.immediately)
            .refreshable {
                await vm.tai()
                await kho.taiPhamVi()
            }
            .overlay(alignment: .top) { vienBaiMoi(cuon) }
            .onReceive(ChamLaiTabCTW.suKien) { m in
                guard m == .viecCuaToi, cheDo == .gop, nganXep.duong.isEmpty else { return }
                withAnimation(.snappy) { cuon.scrollTo("dau", anchor: .top) }
            }
        }
        .overlay(alignment: .bottom) { bangDay }
        .background(AppColors.backgroundPrimary)
        .ctwTamPhuBangTin(dp, vm)
        .task {
            dp.gan(nganXep)
            if !vm.daTai { await vm.tai() }
            if kho.phamVi == nil { await kho.taiPhamVi() }
        }
        .onAppear { vm.hien(true) }
        .onDisappear { vm.hien(false) }
        .onChange(of: vm.daTai) { _, xong in
            guard xong, hieuUngDau else { return }
            Task { @MainActor in try? await Task.sleep(nanoseconds: 1_200_000_000); hieuUngDau = false }
        }
        .onChange(of: kho.yeuCauSoan) { _, b in
            guard b else { return }
            kho.yeuCauSoan = false
            dp.tamPhu = .soan(kho.moSoan ?? noiDang)
            kho.moSoan = nil
        }
        #if DEBUG
        .task { await XemThuBangTin.khiMo(dp: dp, vm: vm) }
        #endif
    }

    // MARK: Nội dung

    @ViewBuilder private var noiDung: some View {
        if !vm.daTai {
            ForEach(0..<3, id: \.self) { i in TheGiuChoBaiCTW(coAnh: i == 1) }
        } else if let loi = vm.loi {
            CTWOLoi(loi: loi) { Task { await vm.tai() } }
        } else if vm.trong {
            oTrong
        } else {
            if !vm.ghim.isEmpty {
                ForEach(vm.ghim) { p in
                    TheBaiCTW(p: p, hienPhamVi: cheDo != .duAn, hd: dp.hanhDong(vm))
                }
            }
            ForEach(Array(vm.bai.enumerated()), id: \.element.id) { i, p in
                TheBaiCTW(p: p, hienPhamVi: cheDo != .duAn, hd: dp.hanhDong(vm))
                    .xuatHienLanLuot(i + 1, bat: hieuUngDau)
                    .onAppear { if i >= vm.bai.count - 4 { Task { await vm.taiThem() } } }
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
            }
            if vm.dangTaiThem {
                TheGiuChoBaiCTW(coAnh: false)
            } else if vm.con == nil && vm.bai.count > 3 {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.circle").font(.ctw(size: 20)).foregroundColor(AppColors.textTertiary)
                    Text("You're all caught up").font(.ctw(size: 13, weight: .medium)).foregroundColor(AppColors.textTertiary)
                }
                .padding(.vertical, 16)
            }
        }
    }

    // MARK: Bộ lọc

    private var thanhLoc: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if cheDo == .gop { menuPhamVi }
                chip(.all, String(localized: "All"), "square.stack")
                chip(.mine, String(localized: "My posts"), "person")
                chip(.media, String(localized: "Photos & videos"), "photo.on.rectangle")
                chip(.saved, String(localized: "Saved"), "bookmark")
                chip(.files, String(localized: "Files"), "paperclip")
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    private func chip(_ k: LocBangTin.Kieu, _ ten: String, _ icon: String) -> some View {
        let chon = vm.loc.kieu == k
        return Button {
            CTWRung.chon()
            var l = vm.loc
            l.kieu = k
            Task { await vm.doiLoc(l) }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.ctw(size: 11, weight: .semibold))
                Text(ten).font(.ctw(size: 13, weight: .semibold))
            }
            .fixedSize()
            .foregroundColor(chon ? AppColors.onPrimary : AppColors.textPrimary)
            .padding(.horizontal, 12).frame(minHeight: 34)
            .background(Capsule().fill(chon ? AppColors.primary : AppColors.backgroundCard))
            .overlay(Capsule().strokeBorder(chon ? Color.clear : AppColors.border, lineWidth: 0.5))
        }
        .buttonStyle(.nhan)
        .accessibilityAddTraits(chon ? .isSelected : [])
        .accessibilityIdentifier("feed.filter.\(k.rawValue)")
    }

    private var tenPhamVi: String {
        if let pid = vm.loc.pid, let d = kho.duAn(pid) { return d.p.name ?? d.p.key ?? "" }
        if let ws = vm.loc.ws, let w = kho.khongGian(ws) { return w.workspace.name ?? "" }
        return String(localized: "Everywhere")
    }

    private var menuPhamVi: some View {
        Menu {
            Button { doiPhamVi(ws: nil, pid: nil) } label: {
                Label("Everywhere", systemImage: vm.loc.ws == nil && vm.loc.pid == nil ? "checkmark" : "globe")
            }
            ForEach(kho.phamVi?.scopes ?? []) { s in
                Section(s.workspace.name ?? "") {
                    Button { doiPhamVi(ws: s.workspace.id, pid: nil) } label: {
                        Label("Whole workspace", systemImage: vm.loc.ws == s.workspace.id && vm.loc.pid == nil ? "checkmark" : "building.2")
                    }
                    ForEach(s.projects ?? []) { p in
                        Button { doiPhamVi(ws: s.workspace.id, pid: p.id) } label: {
                            Label {
                                Text(verbatim: "\(p.name ?? "") · \(p.key ?? "")")
                            } icon: { Image(systemName: vm.loc.pid == p.id ? "checkmark" : "folder") }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "line.3.horizontal.decrease").font(.ctw(size: 11, weight: .bold))
                Text(tenPhamVi).font(.ctw(size: 13, weight: .semibold)).lineLimit(1)
                Image(systemName: "chevron.down").font(.ctw(size: 10, weight: .bold))
            }
            .fixedSize()
            .foregroundColor(AppColors.primary)
            .padding(.horizontal, 12).frame(minHeight: 34)
            .background(Capsule().fill(AppColors.primary.opacity(0.12)))
        }
        .accessibilityLabel(Text("Show posts from: \(tenPhamVi)"))
        .accessibilityIdentifier("feed.filter.scope")
    }

    private func doiPhamVi(ws: Int?, pid: Int?) {
        var l = vm.loc
        l.ws = ws; l.pid = pid
        Task { await vm.doiLoc(l) }
    }

    // MARK: Ô "Đăng bài"

    private var oDang: some View {
        Button { dp.tamPhu = .soan(noiDang) } label: {
            HStack(spacing: 10) {
                CTWAvatar(user: app.currentUser?.nguoiBangTin, size: 38)
                Text("Share an update with your team…")
                    .font(.ctw(size: 15)).foregroundColor(AppColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14).frame(minHeight: 40)
                    .background(Capsule().fill(AppColors.backgroundSecondary))
                Image(systemName: "photo.on.rectangle.angled").font(.ctw(size: 18)).foregroundColor(AppColors.success)
                    .frame(width: 36, height: 40)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .ctwThe(16)
        }
        .buttonStyle(.nhan)
        .accessibilityLabel(Text("Create post"))
        .accessibilityIdentifier("feed.compose")
    }

    private var bangKiemDuyet: some View {
        Button { nganXep.duong.append(RouteBangTinCTW.kiemDuyet) } label: {
            HStack(spacing: 10) {
                Image(systemName: "flag.fill").foregroundColor(AppColors.error)
                let n = kho.phamVi?.openReports ?? 0
                Text(n == 1 ? String(localized: "1 report to review") : String(localized: "\(n) reports to review"))
                    .font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right").font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppColors.error.opacity(0.08)))
        }
        .buttonStyle(.nhan)
        .accessibilityIdentifier("feed.moderation")
    }

    // MARK: Ô trống

    @ViewBuilder private var oTrong: some View {
        VStack(spacing: 10) {
            MinhHoaBangTinTrong().frame(height: 150).padding(.bottom, 6)
            switch vm.loc.kieu {
            case .saved:
                Text("No saved posts").font(.ctw(size: 18, weight: .semibold))
                Text("Save posts from the ••• menu to read them later.").font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
            case .mine:
                Text("You haven't posted yet").font(.ctw(size: 18, weight: .semibold))
                Text("Share progress, demos or questions with your team.").font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
            case .media, .files:
                Text("Nothing here yet").font(.ctw(size: 18, weight: .semibold))
                Text("Posts with photos, videos or files will show up here.").font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
            case .all:
                Text(cheDo == .hashtag ? "No posts with this hashtag" : "No posts yet").font(.ctw(size: 18, weight: .semibold))
                Text("Share wins, sprint demos, photos from the office or a question for the team.")
                    .font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
            }
            if kho.coTheDang && noiDang != nil && cheDo != .hashtag && vm.loc.kieu != .saved {
                Button { dp.tamPhu = .soan(noiDang) } label: {
                    Label("Create the first post", systemImage: "square.and.pencil")
                        .font(.ctw(size: 15, weight: .semibold)).padding(.horizontal, 18).padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 6)
                .accessibilityIdentifier("feed.empty.compose")
            }
        }
        .multilineTextAlignment(.center)
        .foregroundColor(AppColors.textPrimary)
        .padding(.vertical, 28).padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .ctwThe(16)
    }

    // MARK: Viên "N bài mới" + băng đáy

    @ViewBuilder private func vienBaiMoi(_ cuon: ScrollViewProxy) -> some View {
        if vm.soMoi > 0 {
            Button {
                CTWRung.chon()
                withAnimation(.snappy) { cuon.scrollTo("dau", anchor: .top) }
                Task { await vm.tai() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up").font(.ctw(size: 12, weight: .bold))
                    Text(vm.soMoi == 1 ? String(localized: "1 new post") : String(localized: "\(vm.soMoi) new posts"))
                        .font(.ctw(size: 14, weight: .semibold))
                }
                .foregroundColor(AppColors.onPrimary)
                .padding(.horizontal, 16).frame(minHeight: 38)
                .background(Capsule().fill(AppColors.primary).shadow(color: .black.opacity(0.18), radius: 8, y: 3))
            }
            .buttonStyle(.nhan)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityIdentifier("feed.newPosts")
        }
    }

    @ViewBuilder private var bangDay: some View {
        if let b = vm.bang {
            HStack(spacing: 12) {
                Text(b.chu).font(.ctw(size: 14)).foregroundColor(.white).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                if let id = b.hoanTac {
                    Button("Undo") { vm.hoanTacAn(id) }.font(.ctw(size: 14, weight: .bold)).foregroundColor(AppColors.primaryLight)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.85)))
            .padding(.horizontal, 16).padding(.bottom, 12)
            .frame(maxWidth: 560)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: b.id) {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                withAnimation { if vm.bang?.id == b.id { vm.bang = nil } }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Khung xương một bài (ánh lướt)

struct TheGiuChoBaiCTW: View {
    var coAnh = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle().frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4).frame(width: 130, height: 12)
                    RoundedRectangle(cornerRadius: 4).frame(width: 90, height: 10)
                }
            }
            RoundedRectangle(cornerRadius: 4).frame(height: 12)
            RoundedRectangle(cornerRadius: 4).frame(height: 12).padding(.trailing, 60)
            if coAnh { RoundedRectangle(cornerRadius: 10).frame(height: 180) }
            HStack { ForEach(0..<3, id: \.self) { _ in RoundedRectangle(cornerRadius: 4).frame(width: 60, height: 12).frame(maxWidth: .infinity) } }
                .padding(.top, 4)
        }
        .foregroundColor(AppColors.backgroundTertiary)
        .anhLuot()
        .padding(14)
        .ctwThe(16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Loading"))
    }
}

// MARK: - Minh hoạ ô trống (vẽ bằng SwiftUI — sáng/tối theo bảng màu)

struct MinhHoaBangTinTrong: View {
    @Environment(\.accessibilityReduceMotion) private var giam
    @State private var noi = false

    var body: some View {
        ZStack {
            Circle().fill(AppColors.primary.opacity(0.10)).frame(width: 150, height: 150)
            theGia(rong: 118).rotationEffect(.degrees(-9)).offset(x: -34, y: 14)
            theGia(rong: 118).rotationEffect(.degrees(7)).offset(x: 34, y: 8)
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [AppColors.primary, AppColors.primaryLight], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 74, height: 74)
                    .shadow(color: AppColors.primary.opacity(0.35), radius: 12, y: 6)
                Image(systemName: "megaphone.fill").font(.system(size: 32, weight: .semibold)).foregroundColor(.white)
            }
            .offset(y: giam ? -6 : (noi ? -12 : -2))
            Image(systemName: "sparkle").font(.system(size: 18, weight: .bold)).foregroundColor(AppColors.warning)
                .offset(x: 52, y: -50).scaleEffect(noi ? 1.15 : 0.85)
            Image(systemName: "heart.fill").font(.system(size: 14, weight: .bold)).foregroundColor(Color(red: 0.93, green: 0.3, blue: 0.4))
                .offset(x: -58, y: -40)
            Text(verbatim: "👍").font(.system(size: 20)).offset(x: 62, y: 30)
        }
        .accessibilityHidden(true)
        .onAppear {
            guard !giam else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { noi = true }
        }
    }

    private func theGia(rong: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(AppColors.primary.opacity(0.35)).frame(width: 16, height: 16)
                RoundedRectangle(cornerRadius: 3).fill(AppColors.textTertiary.opacity(0.35)).frame(width: 46, height: 7)
            }
            RoundedRectangle(cornerRadius: 3).fill(AppColors.textTertiary.opacity(0.25)).frame(height: 7)
            RoundedRectangle(cornerRadius: 6).fill(AppColors.primary.opacity(0.18)).frame(height: 34)
        }
        .padding(10)
        .frame(width: rong)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppColors.backgroundCard)
            .shadow(color: .black.opacity(0.08), radius: 6, y: 2))
    }
}
