import SwiftUI

// MARK: - Đăng ký mô-đun "Bảng tin" (Feed) + các màn con
//
// Hai cấp: không gian + dự án (hợp đồng api-backend `docs/ctw-feed-hop-dong-api.md`).
//   · My Work › phân đoạn "Bảng tin" — GỘP mọi không gian/dự án (`ViecCuaToiCTW`).
//   · Mô-đun dự án `feed` (trang dự án › More có thẻ nổi bật; iPad thanh bên; More tools; ⌘K).
//   · Bảng tin không gian — từ bảng chọn dự án (mỗi không gian một dòng "Bảng tin") và từ Portfolio & workload.
// Ẩn: vai CLIENT (máy chủ không bao giờ cho khách thấy) · máy chủ cũ chưa có tuyến (`KhoBangTinCTW.hien`).

extension CTWModule {
    static let feed = CTWModule(
        id: "feed", ten: "Feed", bieuTuong: "newspaper", nhom: .giaoTiep,
        moTa: "Team updates, photos, files and polls", thuTu: 5, doanWeb: "feed",
        hien: { cfg in cfg?.role != "CLIENT" && KhoBangTinCTW.shared.hien },
        man: { c in AnyView(BangTinDuAnCTW(nguCanh: c)) },
        dichDen: { v in
            AnyView(v.navigationDestination(for: RouteBangTinCTW.self) { r in
                switch r {
                case .bai(let id, let bl): ChiTietBaiCTW(postId: id, binhLuan: bl)
                case .khongGian(let ws, let ten): BangTinKhongGianCTW(ws: ws, ten: ten)
                case .hashtag(let t, let l):
                    BangTinCTW(cheDo: .hashtag, loc: l)
                        .navigationTitle(Text(verbatim: "#\(t)"))
                        .navigationBarTitleDisplayMode(.inline)
                case .kiemDuyet: KiemDuyetBangTinCTW()
                }
            })
        })
}

// MARK: - Bảng tin dự án (màn của mô-đun)

struct BangTinDuAnCTW: View {
    let nguCanh: CTWNguCanh
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @ObservedObject private var kho = KhoBangTinCTW.shared

    private var noi: NoiDangBangTin? { kho.noiDang.first { $0.duAn?.id == nguCanh.pid } }

    var body: some View {
        BangTinCTW(cheDo: .duAn, loc: .duAn(nguCanh.pid), noiMacDinh: noi)
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let noi {
                    ToolbarItem(placement: .primaryAction) {
                        Button { kho.moSoan = noi; kho.yeuCauSoan = true } label: { Image(systemName: "square.and.pencil") }
                            .accessibilityLabel(Text("Create post"))
                            .accessibilityIdentifier("feed.toolbar.compose")
                    }
                }
            }
            // Đường dẫn sâu `/work/<ws>/<KEY>/feed?post=<id>` ⇒ mở bài (xoá cờ ở CUỐI — KIEN_TRUC mục 6).
            .task(id: app.dichCho) {
                guard let d = app.dichCho, d.moDun == "feed" else { return }
                defer { app.dichCho = nil }
                if let post = d.duongDan.tham["post"].flatMap(Int.init) {
                    nganXep.duong.append(RouteBangTinCTW.bai(id: post, binhLuan: d.duongDan.tham["comment"].flatMap(Int.init)))
                }
            }
            #if DEBUG
            // `mod:feed/bai` ⇒ mở thẳng một bài, cuộn tới bình luận (như chạm thông báo).
            .task { if XemThuCTW.conCua("feed") == "bai", nganXep.duong.count <= 1 { nganXep.duong.append(RouteBangTinCTW.bai(id: 2, binhLuan: 112)) } }
            #endif
    }
}

// MARK: - Bảng tin không gian

struct BangTinKhongGianCTW: View {
    let ws: Int
    let ten: String
    @ObservedObject private var kho = KhoBangTinCTW.shared

    private var noi: NoiDangBangTin? { kho.noiDang.first { $0.ws.id == ws && $0.duAn == nil } }

    var body: some View {
        BangTinCTW(cheDo: .khongGian, loc: .khongGian(ws), noiMacDinh: noi)
            .navigationTitle(Text(verbatim: ten.isEmpty ? (kho.khongGian(ws)?.workspace.name ?? "") : ten))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if noi != nil || !kho.noiDang.filter({ $0.ws.id == ws }).isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button { kho.moSoan = noi ?? kho.noiDang.first { $0.ws.id == ws }; kho.yeuCauSoan = true } label: {
                            Image(systemName: "square.and.pencil")
                        }
                        .accessibilityLabel(Text("Create post"))
                    }
                }
            }
    }
}

// MARK: - Chi tiết một bài (thông báo đẩy, đường dẫn sâu, "Xem bài")

struct ChiTietBaiCTW: View {
    let postId: Int
    var binhLuan: Int?

    @StateObject private var vm = BangTinVM(loc: .gop)
    @StateObject private var blvm: BinhLuanVM
    @StateObject private var dp = DieuPhoiBaiCTW()
    @EnvironmentObject private var nganXep: NganXepCTW
    @Environment(\.dismiss) private var dong
    @State private var khongCo = false
    @State private var daMo = false

    init(postId: Int, binhLuan: Int?) {
        self.postId = postId
        self.binhLuan = binhLuan
        _blvm = StateObject(wrappedValue: BinhLuanVM(postId: postId, bai: nil))
    }

    var body: some View {
        Group {
            if let p = vm.baiTheoId(postId) {
                KhungBinhLuanCTW(vm: blvm, nhung: true,
                                 dau: AnyView(TheBaiCTW(p: p, chiTiet: true, hd: dp.hanhDong(vm)).padding(.bottom, 4)),
                                 cuonToi: binhLuan, moURL: dp.moURL)
            } else if khongCo {
                CTWOTrong(bieuTuong: "eye.slash", tieuDe: String(localized: "This post is no longer available"),
                          moTa: String(localized: "It may have been deleted, or you no longer have access to it."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView { TheGiuChoBaiCTW(coAnh: true).padding(16).frame(maxWidth: 680).frame(maxWidth: .infinity) }
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .ctwTamPhuBangTin(dp, vm)
        .task {
            dp.gan(nganXep)
            guard !daMo else { return }
            daMo = true
            do {
                let p: CTWFeedPost = try await APIClient.shared.request(CTWAPI.bai(postId))
                vm.datMot(p)
                blvm.bai = p
            } catch { khongCo = true }
        }
        .onReceive(blvm.$bai.compactMap { $0 }) { p in if vm.baiTheoId(p.id) != nil { vm.thay(p) } }
        .onChange(of: vm.bai.isEmpty) { _, het in
            // Bài vừa bị xoá / ẩn / báo cáo từ màn này ⇒ quay lại.
            if het && daMo && !khongCo { dong() }
        }
    }
}

// MARK: - Thẻ nổi bật "Bảng tin dự án" (trang dự án › More)

struct TheBangTinDuAnCTW: View {
    let pid: Int
    var body: some View {
        NavigationLink(value: RouteMoDunCTW(id: "feed")) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(LinearGradient(colors: [AppColors.primary, AppColors.primaryLight], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "newspaper.fill").font(.ctw(size: 17, weight: .semibold)).foregroundColor(.white)
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Project feed").font(.ctw(size: 16, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    Text("Updates, demos, photos and polls from the team").font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.ctw(size: 13, weight: .semibold)).foregroundColor(AppColors.textTertiary)
            }
            .padding(12)
            .ctwThe(14)
        }
        .buttonStyle(.nhan)
        .accessibilityIdentifier("project.feed")
    }
}
