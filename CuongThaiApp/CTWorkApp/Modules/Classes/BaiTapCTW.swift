import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

// MARK: - Lớp học — MỘT BÀI TẬP
//
// Sinh viên: đọc đề, tải tệp đề, soạn bài nộp (chữ + liên kết + tệp) rồi "Turn in";
// nộp rồi muốn sửa thì "Unsubmit" (máy chủ chặn sửa khi đang ở trạng thái đã nộp).
// Điểm chỉ hiện khi giảng viên đã TRẢ bài (máy chủ không bao giờ lộ điểm nháp).
// Giảng viên: xem tình trạng nộp của từng sinh viên/nhóm (chấm điểm theo rubric làm trên web).

@MainActor
final class BaiTapVM: ObservableObject {
    let lop: Int
    let aid: Int
    @Published var ct: CTWBaiTapChiTiet?
    @Published var dsNop: [CTWDsBaiNop.Hang]?
    @Published var chu = ""
    @Published var lienKet: [CTWLienKetNop] = []
    @Published var loi: String?
    @Published var dangLam = false

    init(lop: Int, aid: Int) { self.lop = lop; self.aid = aid }

    var nop: CTWBaiNop? { ct?.submission }
    var daNop: Bool { nop?.status == "TURNED_IN" }
    var daSuaNhap: Bool { chu != (nop?.text ?? "") || lienKet != (nop?.links ?? []) }

    func tai() async {
        do {
            let c: CTWBaiTapChiTiet = try await APIClient.shared.request(CTWAPI.baiTap(lop, aid))
            nhan(c)
            if c.manage == true {
                let d: CTWDsBaiNop = try await APIClient.shared.request(CTWAPI.dsBaiNop(lop, aid))
                dsNop = d.rows ?? []
            }
            loi = nil
        } catch { loi = DichVuLoi.cau(error) }
    }

    private func nhan(_ c: CTWBaiTapChiTiet) {
        ct = c
        chu = c.submission?.text ?? ""
        lienKet = c.submission?.links ?? []
    }

    private func lam(_ viec: () async throws -> CTWBaiTapChiTiet?) async -> Bool {
        dangLam = true
        defer { dangLam = false }
        do {
            if let c = try await viec() { nhan(c) }
            CTWRung.thanhCong()
            return true
        } catch { loi = DichVuLoi.cau(error); CTWRung.loi(); return false }
    }

    func luuNhap() async -> Bool {
        await lam { try await APIClient.shared.request(CTWAPI.luuBaiNop(lop, aid, chu: chu, lienKet: lienKet)) }
    }

    func nopBai() async -> Bool {
        if daSuaNhap { guard await luuNhap() else { return false } }
        return await lam { try await APIClient.shared.request(CTWAPI.nopBai(lop, aid)) }
    }

    func rutBai() async -> Bool { await lam { try await APIClient.shared.request(CTWAPI.rutBai(lop, aid)) } }

    func taiTep(du: Data, ten: String) async {
        if daSuaNhap { _ = await luuNhap() }
        _ = await lam {
            _ = try await CTWTaiTepLop.taiLen(lop: lop, bai: aid, du: du, ten: ten)
            return try await APIClient.shared.request(CTWAPI.baiTap(lop, aid))
        }
    }

    func xoaTep(_ t: CTWTepLop) async {
        _ = await lam {
            try await APIClient.shared.send(CTWAPI.xoaTepNop(lop, aid, fid: t.id))
            return try await APIClient.shared.request(CTWAPI.baiTap(lop, aid))
        }
    }

    func binhLuan(_ s: String) async -> Bool {
        do {
            try await APIClient.shared.send(CTWAPI.binhLuanRieng(lop, aid: aid, chu: s))
            let c: CTWBaiTapChiTiet = try await APIClient.shared.request(CTWAPI.baiTap(lop, aid))
            ct?.submission?.comments = c.submission?.comments
            return true
        } catch { loi = DichVuLoi.cau(error); return false }
    }
}

struct BaiTapCTW: View {
    let lop: Int
    let aid: Int
    let ten: String
    @StateObject private var vm: BaiTapVM
    @State private var chonTep = false
    @State private var chonAnh: PhotosPickerItem?
    @State private var themLK = false
    @State private var lkUrl = "https://"
    @State private var hoiRut = false

    init(lop: Int, aid: Int, ten: String) {
        self.lop = lop; self.aid = aid; self.ten = ten
        _vm = StateObject(wrappedValue: BaiTapVM(lop: lop, aid: aid))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let l = vm.loi { CTWErrorBanner(text: l) { vm.loi = nil } }
                if let c = vm.ct {
                    dau(c)
                    if let d = c.description, !d.chuTron.isEmpty { CTWTipTapView(doc: d, coChu: 15).padding(14).ctwThe(12) }
                    else if let t = c.descriptionText, !t.isEmpty { Text(t).font(.system(size: 15)).padding(14).frame(maxWidth: .infinity, alignment: .leading).ctwThe(12) }
                    if let f = c.files, !f.isEmpty {
                        CTWSectionHeader("paperclip", "Materials", count: "\(f.count)")
                        ForEach(f) { t in TepLopDong(lop: lop, t: t) }
                    }
                    if c.manage == true { tinhTrangNop } else if let n = c.submission { baiCuaToi(c, n) }
                } else if vm.loi == nil {
                    CTWKhungTai(soHang: 4, coAvatar: false).padding(.horizontal, -Spacing.md)
                }
            }
            .padding(Spacing.md)
            .dvBeRong()
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(vm.ct?.title ?? ten)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) { if vm.dangLam { ProgressView().padding(8) } }
        .refreshable { await vm.tai() }
        .task { if vm.ct == nil { await vm.tai() } }
        .fileImporter(isPresented: $chonTep, allowedContentTypes: [.item], allowsMultipleSelection: false) { kq in
            guard case .success(let ds) = kq, let u = ds.first else { return }
            let mo = u.startAccessingSecurityScopedResource()
            defer { if mo { u.stopAccessingSecurityScopedResource() } }
            guard let du = try? Data(contentsOf: u) else { vm.loi = "Couldn't read that file."; return }
            Task { await vm.taiTep(du: du, ten: u.lastPathComponent) }
        }
        .onChange(of: chonAnh) { _, muc in
            guard let muc else { return }
            Task {
                if let du = try? await muc.loadTransferable(type: Data.self) {
                    let jpg = UIImage(data: du)?.jpegData(compressionQuality: 0.85) ?? du
                    await vm.taiTep(du: jpg, ten: "Photo \(CTW.tenTepTheoGio()).jpg")
                }
                chonAnh = nil
            }
        }
        .alert("Add a link", isPresented: $themLK) {
            TextField("https://…", text: $lkUrl).keyboardType(.URL).textInputAutocapitalization(.never)
            Button("Add") {
                let u = lkUrl.trimmingCharacters(in: .whitespaces)
                if u.hasPrefix("http"), URL(string: u) != nil { vm.lienKet.append(CTWLienKetNop(url: u, label: nil)) }
                lkUrl = "https://"
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Unsubmit this work?", isPresented: $hoiRut, titleVisibility: .visible) {
            Button("Unsubmit", role: .destructive) { Task { _ = await vm.rutBai() } }
        } message: { Text("You can edit and turn it in again. If the due date has passed, it may be marked late.") }
    }

    private func dau(_ c: CTWBaiTapChiTiet) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                CTWNhanNho(chu: c.kind == "GROUP" ? "Group" : "Individual", bieuTuong: c.kind == "GROUP" ? "person.3" : "person", mau: AppColors.primary)
                if let cat = c.category, !cat.isEmpty { CTWNhanNho(chu: cat) }
                if let t = c.topic, !t.isEmpty { CTWNhanNho(chu: t) }
            }
            Text(c.title).font(.system(size: 22, weight: .bold)).foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            CTWKhoiTruong {
                CTWHangTruong("Due", c.dueAt.map { CTW.thoiDiem($0) } ?? "No due date", bieuTuong: "calendar")
                Divider()
                CTWHangTruong("Points", c.maxPoints.map { CTWLopNhan.diem($0) }, bieuTuong: "star")
                if c.allowLate == true, let p = c.latePenaltyPct, p > 0 {
                    Divider()
                    CTWHangTruong("Late penalty", "\(CTWLopNhan.diem(p))%" + (c.latePenaltyMaxPct.map { " (max \(CTWLopNhan.diem($0))%)" } ?? ""), bieuTuong: "clock.badge.exclamationmark")
                } else if c.allowLate == false {
                    Divider()
                    CTWHangTruong("Late work", "Not accepted", bieuTuong: "clock.badge.xmark")
                }
                if let a = c.author { Divider(); CTWHangTruong("Posted by", a.ten, bieuTuong: "person") }
            }
        }
    }

    private func baiCuaToi(_ c: CTWBaiTapChiTiet, _ n: CTWBaiNop) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                CTWSectionHeader("tray.and.arrow.up", "Your work")
                CTWChipChu(chu: CTWLopNhan.trangThaiNop(n.state), mau: CTWMauTrangThai.mau(CTWLopNhan.mauNop(n.state)))
            }
            if let g = n.grade, g.points != nil {
                HStack(spacing: 10) {
                    Image(systemName: "rosette").font(.system(size: 22)).foregroundColor(AppColors.success)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(CTWLopNhan.diem(g.points))/\(CTWLopNhan.diem(c.maxPoints))")
                            .font(.system(size: 22, weight: .bold).monospacedDigit()).foregroundColor(AppColors.textPrimary)
                        if let p = g.penaltyPct, p > 0 {
                            Text("Includes a \(CTWLopNhan.diem(p))% late penalty (raw \(CTWLopNhan.diem(g.rawPoints)))")
                                .font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.success.opacity(0.10)))
            }
            if n.needsGroup == true {
                Label("This is a group assignment. Join a group in the class first.", systemImage: "person.3")
                    .font(.system(size: 13)).foregroundColor(AppColors.warning)
            }
            if let s = n.submittedAt { Text("Turned in \(CTW.thoiDiem(s))\(n.late == true ? " · late" : "")").font(.system(size: 12)).foregroundColor(AppColors.textSecondary) }

            // Soạn bài: chỉ khi CHƯA nộp (đã nộp phải rút lại — luật máy chủ).
            VStack(alignment: .leading, spacing: 8) {
                TextField("Write your answer or a note to your teacher…", text: $vm.chu, axis: .vertical)
                    .lineLimit(3...12).font(.system(size: 15)).padding(12).ctwThe(10)
                    .disabled(vm.daNop)
                ForEach(Array(vm.lienKet.enumerated()), id: \.offset) { i, l in
                    HStack(spacing: 8) {
                        Image(systemName: "link").foregroundColor(AppColors.primary)
                        Text(l.label?.isEmpty == false ? l.label! : l.url).font(.system(size: 13)).lineLimit(1)
                        Spacer(minLength: 0)
                        if !vm.daNop {
                            Button { vm.lienKet.remove(at: i) } label: { Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textTertiary) }
                                .buttonStyle(.plain).frame(width: 36, height: 36).accessibilityLabel("Remove link")
                        }
                    }
                    .padding(.horizontal, 10).background(RoundedRectangle(cornerRadius: 10).fill(AppColors.backgroundTertiary))
                }
                ForEach(n.files ?? []) { t in
                    TepLopDong(lop: lop, t: t, xoa: vm.daNop ? nil : { Task { await vm.xoaTep(t) } })
                }
                if !vm.daNop {
                    HStack(spacing: 8) {
                        Menu {
                            Button { chonTep = true } label: { Label("File", systemImage: "doc") }
                            PhotosPicker(selection: $chonAnh, matching: .images) { Label("Photo", systemImage: "photo") }
                            Button { themLK = true } label: { Label("Link", systemImage: "link") }
                        } label: {
                            Label("Add", systemImage: "plus").font(.system(size: 14, weight: .semibold)).frame(minHeight: 44).padding(.horizontal, 14)
                        }
                        .buttonStyle(.bordered)
                        if vm.daSuaNhap {
                            Button { Task { _ = await vm.luuNhap() } } label: { Text("Save draft").frame(minHeight: 44).padding(.horizontal, 6) }
                                .buttonStyle(.bordered)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            if vm.daNop {
                Button { hoiRut = true } label: { Text("Unsubmit").frame(maxWidth: .infinity, minHeight: 46) }
                    .buttonStyle(.bordered).disabled(vm.dangLam)
            } else {
                let tamTinh = CTWBaiNop(needsGroup: n.needsGroup, canTurnIn: n.canTurnIn, status: n.status,
                                        text: vm.chu, links: vm.lienKet, files: n.files)
                Button { Task { _ = await vm.nopBai() } } label: {
                    Text(n.lateIfNow == true ? "Turn in late" : "Turn in").bold().frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.dangLam || !CTWLopNhan.nopDuoc(tamTinh))
                if n.lateIfNow == true, let p = n.penaltyIfNow, p > 0 {
                    Text("Turning in now applies a \(CTWLopNhan.diem(p))% late penalty.").font(.system(size: 12)).foregroundColor(AppColors.warning)
                }
            }
            CTWSectionHeader("lock.fill", "Private comments", count: "\(n.comments?.count ?? 0)").padding(.top, 6)
            Text("Only you and your teachers see these.").font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
            ForEach(n.comments ?? []) { c in
                CTWBinhLuanDong(khoa: "submission-comment-\(c.id)", tacGia: c.author, noiDung: c.body ?? "", thoiDiem: c.createdAt,
                                nguCanh: "Class #\(lop) assignment #\(aid)")
            }
            CTWHopSoan(goiY: "Add a private comment…", nutGui: "Send") { s in await vm.binhLuan(s) }
        }
    }

    @ViewBuilder
    private var tinhTrangNop: some View {
        CTWSectionHeader("person.2.badge.gearshape", "Submissions", count: vm.dsNop.map { "\($0.count)" })
        if let ds = vm.dsNop {
            let dem = Dictionary(grouping: ds, by: { $0.state ?? "ASSIGNED" }).mapValues(\.count)
            HStack(spacing: 8) {
                CTWODem(so: "\((dem["TURNED_IN"] ?? 0) + (dem["LATE"] ?? 0))", nhan: "Turned in", bieuTuong: "tray.and.arrow.up", mau: AppColors.success)
                CTWODem(so: "\(dem["MISSING"] ?? 0)", nhan: "Missing", bieuTuong: "exclamationmark.circle", mau: AppColors.error)
                CTWODem(so: "\(dem["RETURNED"] ?? 0)", nhan: "Returned", bieuTuong: "checkmark.circle", mau: AppColors.primary)
            }
            VStack(spacing: 0) {
                ForEach(ds) { r in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.group?.name ?? r.members?.first?.name ?? r.ownerKey).font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary).lineLimit(1)
                            Text([r.members?.compactMap(\.studentCode).joined(separator: ", "),
                                  r.submittedAt.map { "Turned in \(CTW.ngayNgan($0) ?? "")" }]
                                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.system(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if let p = r.returnedPoints ?? r.points {
                            Text(CTWLopNhan.diem(p)).font(.system(size: 13, weight: .bold).monospacedDigit()).foregroundColor(AppColors.textPrimary)
                        }
                        CTWChipChu(chu: CTWLopNhan.trangThaiNop(r.state), mau: CTWMauTrangThai.mau(CTWLopNhan.mauNop(r.state)))
                    }
                    .padding(.vertical, 10)
                    if r.id != ds.last?.id { Divider() }
                }
            }
            .padding(.horizontal, 12).ctwThe(14)
        }
    }
}
