import SwiftUI

// MARK: - Lớp học (Google-Classroom kiểu FPT) — danh sách lớp + tổng quan giảng dạy
//
// Không gắn với dự án đang chọn: lớp sống ở cấp tài khoản (`/work/classes`). Sinh viên
// thấy lớp mình học (bảng tin, bài tập, nộp bài); giảng viên thấy thêm "Teaching" =
// sức khoẻ từng nhóm đồ án (đỏ/vàng/xanh).

enum RouteLopCTW: Hashable {
    case lop(id: Int, ten: String)
    case baiTap(lop: Int, aid: Int, ten: String)
    case nhom(CTWNhomGiangDay)

    @MainActor @ViewBuilder
    var man: some View {
        switch self {
        case .lop(let id, let ten): LopCTW(id: id, ten: ten)
        case .baiTap(let lop, let aid, let ten): BaiTapCTW(lop: lop, aid: aid, ten: ten)
        case .nhom(let n): NhomGiangDayCTW(n: n)
        }
    }
}

struct LopHocCTW: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var tab = 0
    @State private var ds: CTWDsLop?
    @State private var giangDay = false
    @State private var loi: String?

    var body: some View {
        VStack(spacing: 0) {
            if giangDay {
                Picker("View", selection: $tab) {
                    Text("Classes").tag(0)
                    Text("Teaching").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.md).padding(.vertical, 8)
                .dvBeRong(560)
            }
            if tab == 1 && giangDay {
                GiangDayCTW()
            } else {
                dsLop
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Classes")
        .navigationBarTitleDisplayMode(.inline)
        .task { if ds == nil { await tai() } }
        #if DEBUG
        .task {
            if XemThuCTW.conCua("classes") == "assignment", nganXep.duong.count <= 1 {
                nganXep.duong.append(RouteLopCTW.baiTap(lop: 4, aid: 12, ten: "Lab 3 – ERD"))
            } else if XemThuCTW.conCua("classes") == "class", nganXep.duong.count <= 1 {
                nganXep.duong.append(RouteLopCTW.lop(id: 4, ten: "SWP391 · SE1801"))
            } else if XemThuCTW.conCua("classes") == "teaching" { tab = 1 }
        }
        #endif
    }

    private var dsLop: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }
                if let ds {
                    if (ds.teaching ?? []).isEmpty && (ds.enrolled ?? []).isEmpty {
                        CTWOTrong(bieuTuong: "graduationcap", tieuDe: "No classes yet",
                                  moTa: "Join a class with the code your teacher gives you on cuongthai.com/work/classes.")
                    }
                    if let t = ds.teaching, !t.isEmpty { khoi("Teaching", "person.crop.rectangle", t) }
                    if let e = ds.enrolled, !e.isEmpty { khoi("Enrolled", "graduationcap", e) }
                } else if loi == nil {
                    CTWKhungTai(soHang: 4, coAvatar: false).padding(.horizontal, -Spacing.md)
                }
            }
            .padding(Spacing.md)
            .dvBeRong()
        }
        .refreshable { await tai() }
    }

    private func tai() async {
        do {
            async let a: CTWDsLop = APIClient.shared.request(CTWAPI.dsLop())
            async let b: CTWQuyenGiangDay? = try? APIClient.shared.request(CTWAPI.quyenGiangDay())
            let (x, y) = try await (a, b)
            ds = x
            giangDay = y?.teaching == true || !(x.teaching ?? []).isEmpty
            loi = nil
        } catch { loi = DichVuLoi.cau(error) }
    }

    private func khoi(_ ten: String, _ icon: String, _ ds: [CTWLop]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CTWSectionHeader(icon, ten, count: "\(ds.count)")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 10)], spacing: 10) {
                ForEach(ds) { l in
                    NavigationLink(value: RouteLopCTW.lop(id: l.id, ten: l.name)) { theLop(l) }.buttonStyle(.plain)
                }
            }
        }
    }

    private func theLop(_ l: CTWLop) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(l.subject ?? "Class").font(.ctw(size: 11, weight: .heavy).monospaced())
                    .foregroundColor(AppColors.onPrimary)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(LinearGradient(colors: [AppColors.primaryLight, AppColors.primary],
                                                              startPoint: .leading, endPoint: .trailing)))
                if l.archivedAt != nil { CTWNhanNho(chu: "Archived", bieuTuong: "archivebox") }
                Spacer(minLength: 0)
                CTWNhanNho(chu: CTWMauTrangThai.nhan(l.role))
            }
            Text(l.name).font(.ctw(size: 16, weight: .semibold)).foregroundColor(AppColors.textPrimary).lineLimit(2)
            Text([l.classCode, l.term].compactMap { $0 }.joined(separator: " · "))
                .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
            HStack(spacing: 12) {
                if let g = l.groups { Label("\(g) groups", systemImage: "person.3") }
                if let s = l.students { Label("\(s) students", systemImage: "person") }
                if let my = l.group?.name { Label(my, systemImage: "person.3.fill") }
            }
            .font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ctwThe(14)
        .contentShape(Rectangle())
    }
}

// MARK: - Một lớp: Bảng tin · Bài tập · Nhóm

struct LopCTW: View {
    let id: Int
    let ten: String
    @EnvironmentObject private var app: AppState
    @State private var tab = 0
    @State private var lop: CTWLopChiTiet?
    @State private var baiTap: CTWDsBaiTap?
    @State private var tin: CTWBangTinLop?
    @State private var dangTaiThem = false
    @State private var loi: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }
                if let l = lop { dau(l) }
                Picker("Section", selection: $tab) {
                    Text("Stream").tag(0)
                    Text("Classwork").tag(1)
                    Text("Groups").tag(2)
                }
                .pickerStyle(.segmented)
                switch tab {
                case 0: bangTin
                case 1: dsBaiTap
                default: dsNhom
                }
            }
            .padding(Spacing.md)
            .dvBeRong()
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(lop?.name ?? ten)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await tai() }
        .task { if lop == nil { await tai() } }
    }

    private func tai() async {
        do {
            async let a: CTWLopChiTiet = APIClient.shared.request(CTWAPI.lop(id))
            async let b: CTWDsBaiTap = APIClient.shared.request(CTWAPI.baiTapLop(id))
            async let c: CTWBangTinLop = APIClient.shared.request(CTWAPI.bangTinLop(id, truoc: nil))
            let (x, y, z) = try await (a, b, c)
            lop = x; baiTap = y; tin = z
            loi = nil
        } catch { loi = DichVuLoi.cau(error) }
    }

    private func dau(_ l: CTWLopChiTiet) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                CTWNhanNho(chu: l.subject ?? "Class", mau: AppColors.primary)
                if let c = l.classCode { CTWNhanNho(chu: c) }
                if let t = l.term { CTWNhanNho(chu: t) }
                if l.archivedAt != nil { CTWNhanNho(chu: "Archived", bieuTuong: "archivebox", mau: AppColors.warning) }
            }
            HStack(spacing: 8) {
                CTWAvatar(user: l.teacher ?? l.owner, size: 24)
                Text("Teacher: \((l.teacher ?? l.owner)?.ten ?? "—")").font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
            }
            if l.manage == true, let code = l.joinCodeDisplay {
                Text("Join code: \(code)").font(.ctw(size: 13, weight: .semibold).monospaced()).foregroundColor(AppColors.textPrimary)
                    .textSelection(.enabled)
            }
        }
    }

    @ViewBuilder
    private var bangTin: some View {
        if let ps = tin?.posts {
            if ps.isEmpty { CTWOTrong(bieuTuong: "megaphone", tieuDe: "No posts yet", moTa: "Announcements and new classwork appear here.") }
            ForEach(ps) { p in
                BaiDangLopCTW(lop: id, p: p, quanLy: tin?.manage == true) { moi in
                    if let i = tin?.posts?.firstIndex(where: { $0.id == moi.id }) { tin?.posts?[i] = moi }
                }
            }
            if let truoc = tin?.nextBefore {
                Button {
                    dangTaiThem = true
                    Task {
                        if let r: CTWBangTinLop = try? await APIClient.shared.request(CTWAPI.bangTinLop(id, truoc: truoc)) {
                            tin?.posts = (tin?.posts ?? []) + (r.posts ?? [])
                            tin?.nextBefore = r.nextBefore
                        }
                        dangTaiThem = false
                    }
                } label: {
                    if dangTaiThem { ProgressView() } else { Text("Load older posts") }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
        } else if loi == nil {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 30)
        }
    }

    @ViewBuilder
    private var dsBaiTap: some View {
        if let ds = baiTap?.assignments {
            if ds.isEmpty { CTWOTrong(bieuTuong: "doc.text", tieuDe: "No classwork yet") }
            ForEach(ds) { a in
                NavigationLink(value: RouteLopCTW.baiTap(lop: id, aid: a.id, ten: a.title)) { hangBaiTap(a, quanLy: baiTap?.manage == true) }
                    .buttonStyle(.plain)
            }
        } else if loi == nil {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 30)
        }
    }

    private func hangBaiTap(_ a: CTWBaiTap, quanLy: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: a.kind == "GROUP" ? "person.3.fill" : "doc.text.fill")
                .font(.ctw(size: 15)).foregroundColor(AppColors.primary)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColors.primary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 4) {
                Text(a.title).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                HStack(spacing: 6) {
                    if let d = a.dueAt {
                        Text("Due \(CTW.thoiDiem(d))").font(.ctw(size: 12))
                            .foregroundColor(DichVuLoi.daQua(d) && a.my?.state == "ASSIGNED" ? AppColors.error : AppColors.textSecondary)
                    } else { Text("No due date").font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary) }
                    if let p = a.maxPoints { Text("· \(CTWLopNhan.diem(p)) pts").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary) }
                }
                if quanLy, let c = a.counts {
                    Text("\(c.turnedIn ?? 0) turned in · \(c.late ?? 0) late · \(c.missing ?? 0) missing · \(c.returned ?? 0) returned")
                        .font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                }
            }
            Spacer(minLength: 0)
            if let my = a.my {
                VStack(alignment: .trailing, spacing: 4) {
                    CTWChipChu(chu: CTWLopNhan.trangThaiNop(my.state), mau: CTWMauTrangThai.mau(CTWLopNhan.mauNop(my.state)))
                    if let g = my.grade?.points {
                        Text("\(CTWLopNhan.diem(g))/\(CTWLopNhan.diem(a.maxPoints))").font(.ctw(size: 13, weight: .bold).monospacedDigit())
                            .foregroundColor(AppColors.success)
                    }
                }
            }
        }
        .padding(14).ctwThe(14).contentShape(Rectangle())
    }

    @ViewBuilder
    private var dsNhom: some View {
        if let gs = lop?.groups {
            if gs.isEmpty { CTWOTrong(bieuTuong: "person.3", tieuDe: "No groups yet") }
            ForEach(gs) { g in
                HStack(spacing: 12) {
                    Text("\(g.number ?? 0)").font(.ctw(size: 14, weight: .bold).monospacedDigit())
                        .foregroundColor(AppColors.primary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(AppColors.primary.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(g.name).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                            if lop?.me?.groupId == g.id { CTWNhanNho(chu: "Your group", mau: AppColors.success) }
                        }
                        Text("\(g.members ?? 0) members" + (g.project?.key.map { " · project \($0)" } ?? ""))
                            .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                    }
                    Spacer(minLength: 0)
                    if let href = g.project?.href {
                        Button { DinhTuyenCTW.mo(duongDan: href) } label: {
                            Text("Open").font(.ctw(size: 13, weight: .semibold)).padding(.horizontal, 12).frame(minHeight: 36)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Open project \(g.project?.key ?? "")")
                    }
                }
                .padding(12).ctwThe(14)
            }
        }
    }
}

// MARK: - Một bài đăng trên bảng tin lớp

struct BaiDangLopCTW: View {
    let lop: Int
    let p: CTWBaiDangLop
    let quanLy: Bool
    let capNhat: (CTWBaiDangLop) -> Void
    @State private var moBinhLuan = false
    @State private var loi: String?

    private var bieuTuong: String {
        switch p.kind {
        case "ASSIGNMENT": return "doc.text.fill"
        case "QUIZ": return "questionmark.square.fill"
        case "MATERIAL": return "book.closed.fill"
        default: return "megaphone.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: bieuTuong).font(.ctw(size: 14)).foregroundColor(AppColors.onPrimary)
                    .frame(width: 32, height: 32).background(Circle().fill(AppColors.primary))
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(p.author?.ten ?? "Teacher").font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                        if p.author?.laAgent == true { CTWNhanAI() }
                    }
                    Text(CTW.thoiDiem(p.publishAt ?? p.createdAt)).font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                }
                Spacer(minLength: 0)
                if p.pinned == true { Image(systemName: "pin.fill").foregroundColor(AppColors.warning).accessibilityLabel("Pinned") }
            }
            if let t = p.title, !t.isEmpty {
                Text(t).font(.ctw(size: 16, weight: .semibold)).foregroundColor(AppColors.textPrimary)
            }
            if let b = p.bodyJson { CTWTipTapView(doc: b, coChu: 14.5) }
            ForEach(Array((p.links ?? []).enumerated()), id: \.offset) { _, l in
                if let u = URL(string: l.url) {
                    Link(destination: u) {
                        Label(l.title ?? l.url, systemImage: "link").font(.ctw(size: 13)).lineLimit(1)
                    }
                }
            }
            if let f = p.files, !f.isEmpty {
                ForEach(f) { t in TepLopDong(lop: lop, t: t) }
            }
            if let l = loi { Text(l).font(.ctw(size: 12)).foregroundColor(AppColors.error) }
            Divider()
            Button { withAnimation { moBinhLuan.toggle() } } label: {
                Label("\(p.commentCount ?? p.comments?.count ?? 0) class comments", systemImage: "bubble.left.and.bubble.right")
                    .font(.ctw(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundColor(AppColors.textSecondary)
            if moBinhLuan {
                ForEach(p.comments ?? []) { c in
                    if c.hidden == true && !quanLy { EmptyView() } else { dongBinhLuan(c) }
                }
                if p.canComment == true && p.commentsOff != true {
                    CTWHopSoan(goiY: "Add a class comment…", nutGui: "Post comment") { chu in
                        do {
                            let c: CTWBaiDangLop.BinhLuan = try await APIClient.shared.request(CTWAPI.binhLuanBangTin(lop, post: p.id, chu: chu))
                            var moi = p
                            moi.comments = (p.comments ?? []) + [c]
                            moi.commentCount = (p.commentCount ?? 0) + 1
                            capNhat(moi)
                            return true
                        } catch { loi = DichVuLoi.cau(error); return false }
                    }
                } else if p.commentsOff == true {
                    Text("Comments are turned off for this post.").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .padding(14)
        .ctwThe(14)
    }

    private func dongBinhLuan(_ c: CTWBaiDangLop.BinhLuan) -> some View {
        CTWBinhLuanDong(
            khoa: "class-comment-\(c.id)", tacGia: c.author, noiDung: c.body ?? "", thoiDiem: c.createdAt,
            nhanPhu: c.hidden == true ? "Hidden" : nil, nguCanh: "Class #\(lop) post #\(p.id)",
            themMuc: AnyView(Group {
                if quanLy {
                    Button { Task { await an(c, an: !(c.hidden ?? false)) } } label: {
                        Label(c.hidden == true ? "Unhide" : "Hide from students", systemImage: c.hidden == true ? "eye" : "eye.slash")
                    }
                }
                if c.canDelete == true || c.mine == true {
                    Button(role: .destructive) { Task { await xoa(c) } } label: { Label("Delete", systemImage: "trash") }
                }
            }),
            dich: CTWDichBaoCao("class_comment", c.id))
    }

    private func an(_ c: CTWBaiDangLop.BinhLuan, an: Bool) async {
        do {
            try await APIClient.shared.send(CTWAPI.anBinhLuanBangTin(lop, cid: c.id, an: an))
            var moi = p
            if let i = moi.comments?.firstIndex(where: { $0.id == c.id }) { moi.comments?[i].hidden = an }
            capNhat(moi)
            CTWRung.thanhCong()
        } catch { loi = DichVuLoi.cau(error) }
    }

    private func xoa(_ c: CTWBaiDangLop.BinhLuan) async {
        do {
            try await APIClient.shared.send(CTWAPI.xoaBinhLuanBangTin(lop, cid: c.id))
            var moi = p
            moi.comments?.removeAll { $0.id == c.id }
            moi.commentCount = max(0, (p.commentCount ?? 1) - 1)
            capNhat(moi)
            CTWRung.thanhCong()
        } catch { loi = DichVuLoi.cau(error) }
    }
}

/// Một tệp của lớp: chạm ⇒ xin url ký sẵn (5 phút) ⇒ tải về ⇒ Xem nhanh.
struct TepLopDong: View {
    let lop: Int
    let t: CTWTepLop
    var xoa: (() -> Void)?
    @State private var dangMo = false
    @State private var xem: URL?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: (t.mime ?? "").hasPrefix("image/") ? "photo" : ((t.mime ?? "").contains("pdf") ? "doc.richtext" : "doc"))
                .foregroundColor(AppColors.primary).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(t.fileName ?? "File").font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                if let s = t.size {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(s), countStyle: .file))
                        .font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                }
            }
            Spacer(minLength: 0)
            if dangMo { ProgressView() }
            if let xoa {
                Button(role: .destructive, action: xoa) { Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textTertiary) }
                    .buttonStyle(.plain).frame(width: 36, height: 36)
                    .accessibilityLabel("Remove \(t.fileName ?? "file")")
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColors.backgroundTertiary))
        .contentShape(Rectangle())
        .onTapGesture { mo() }
        .ctwXemTep($xem)
        .accessibilityAddTraits(.isButton)
    }

    private func mo() {
        guard !dangMo else { return }
        dangMo = true
        Task {
            defer { dangMo = false }
            do {
                let r: CTWUrlTep = try await APIClient.shared.request(CTWAPI.urlTepLop(lop, fid: t.id))
                guard let u = URL(string: r.url) else { return }
                xem = try await CTWXemTep.taiVe(url: u, ten: r.fileName ?? t.fileName ?? "file", khoa: "lop-\(t.id)")
            } catch { CTWRung.loi() }
        }
    }
}
