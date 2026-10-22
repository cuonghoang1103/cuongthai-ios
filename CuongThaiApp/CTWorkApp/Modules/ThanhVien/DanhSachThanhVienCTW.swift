import SwiftUI

// MARK: - Thành viên — mọi người cùng không gian CT Work, kiểu "Mọi người" của Messenger
//
// Đang hoạt động lên đầu (hàng avatar cuộn ngang + danh sách), ô tìm ở trên, chạm ⇒ hồ sơ (Nhắn tin · thẻ được giao ·
// Chặn · Báo cáo). Dữ liệu: `GET /work/me/people` (đã áp luật riêng tư ở máy chủ) + socket `presence:update`.
// Tự làm mới 30 s một lần khi màn đang hiện (socket không phát trạng thái của đồng nghiệp chưa từng nhắn tin).

struct DanhSachThanhVienCTW: View {
    @ObservedObject private var kho = KhoTinNhanCTW.shared
    @EnvironmentObject private var nganXep: NganXepCTW
    @ObservedObject private var kd = ModerationStore.shared
    @State private var tim = ""
    @State private var hoSo: CTWThanhVien?
    @State private var bayGio = Date()

    var body: some View {
        let ds = kho.danhBaDaSap(tim: tim, bayGio: bayGio)
        let dangHD = ds.filter { kho.moc($0.id, bayGio: bayGio) == .dangHoatDong }
        List {
            if !kho.toiHienTrangThai {
                Section {
                    Label("Your active status is off, so you can't see when others are active either.", systemImage: "eye.slash")
                        .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                }
            }
            if tim.isEmpty, !dangHD.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(dangHD) { n in
                                Button { hoSo = n } label: {
                                    VStack(spacing: 5) {
                                        AvatarHoatDongCTW(user: n.nguoi, size: 54, moc: .dangHoatDong)
                                        Text(verbatim: TenNguoi.tenNgan(n.ten))
                                            .font(.ctw(size: 12)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                                            .fixedSize()
                                    }
                                    .frame(minWidth: 60)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                } header: { Text("Active now") }
            }
            Section {
                ForEach(ds) { n in
                    Button { hoSo = n } label: { HangThanhVienCTW(n: n, moc: kho.moc(n.id, bayGio: bayGio)) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("member.\(n.id)")
                }
            } header: {
                Text(ds.count == 1 ? String(localized: "1 member") : String(localized: "\(ds.count) members"))
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if !kho.daTaiDanhBa && kho.danhBa.isEmpty {
                CTWKhungTai()
            } else if let l = kho.loiDanhBa, kho.danhBa.isEmpty {
                CTWOLoi(loi: l) { Task { await kho.taiDanhBa() } }
            } else if kho.danhBa.isEmpty {
                CTWOTrong(bieuTuong: "person.2", tieuDe: String(localized: "No teammates yet"),
                          moTa: String(localized: "People who share a workspace with you appear here."))
            } else if ds.isEmpty {
                CTWOTrong(bieuTuong: "magnifyingglass", tieuDe: String(localized: "No matches"), moTa: String(localized: "Try another name."))
            }
        }
        .searchable(text: $tim, prompt: "Search members")
        .navigationTitle("Members")
        .refreshable { await kho.taiDanhBa() }
        .task {
            // Làm mới định kỳ khi màn đang hiện (Task tự huỷ khi rời màn).
            while !Task.isCancelled {
                await kho.taiDanhBa()
                bayGio = Date()
                try? await Task.sleep(for: .seconds(30))
            }
        }
        #if DEBUG
        .task(id: kho.danhBa.count) {
            if XemThuCTW.conCua("thanh-vien") == "hoso", hoSo == nil, let n = kho.danhBa.first { hoSo = n }
        }
        #endif
        // Hồ sơ cần mở từ màn Tìm mọi thứ (gõ tên người) ⇒ về gốc ngăn xếp rồi mở tấm phủ hồ sơ; xoá cờ ở CUỐI (mục 6).
        .task(id: kho.hoSoCanMo) {
            guard let id = kho.hoSoCanMo else { return }
            defer { kho.hoSoCanMo = nil }
            nganXep.veDau()
            if kho.thanhVien(id) == nil { await kho.taiDanhBa() }
            try? await Task.sleep(for: .milliseconds(150))
            if let n = kho.thanhVien(id) { hoSo = n }
        }
        .sheet(item: $hoSo) { n in
            NavigationStack { HoSoThanhVienCTW(userId: n.id, laTamPhu: true) }
                .presentationDetents([.large])
        }
    }
}

struct HangThanhVienCTW: View {
    let n: CTWThanhVien
    let moc: TrangThaiHoatDongCTW.Moc

    var body: some View {
        HStack(spacing: 12) {
            AvatarHoatDongCTW(user: n.nguoi, size: 44, moc: moc)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(n.ten).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                    if n.laAgent { CTWNhanAI() }
                    if n.blocked == true {
                        Text("Blocked").font(.ctw(size: 11, weight: .semibold)).foregroundColor(AppColors.error)
                    }
                }
                let chu = TrangThaiHoatDongCTW.chu(moc)
                if !chu.isEmpty {
                    Text(chu).font(.ctw(size: 12, weight: moc == .dangHoatDong ? .semibold : .regular))
                        .foregroundColor(moc == .dangHoatDong ? AppColors.success : AppColors.textSecondary)
                }
                if !n.dongPhu.isEmpty {
                    Text(n.dongPhu).font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

// Hồ sơ thành viên: HoSoNguoiCTW.swift (1.1 — ảnh bìa, vai, Nhắn tin · Xem việc, menu an toàn).

// MARK: - Báo cáo người dùng / hội thoại (App Store 1.2)

struct BaoCaoNguoiCTW: View {
    let ten: String
    let userId: Int
    var threadId: Int?
    /// Báo cáo MỘT tin (nhấn giữ › Báo cáo, build 7 — R4): gửi `messageId`, tin ẩn với tôi ngay khi gửi xong.
    var tin: Message?
    /// Gọi sau khi máy chủ nhận báo cáo một tin (id tin) — màn chat bỏ tin khỏi danh sách.
    var daBaoCaoTin: (Int) -> Void = { _ in }
    @ObservedObject private var kho = KhoTinNhanCTW.shared
    @Environment(\.dismiss) private var dong
    @State private var loai = "harassment"
    @State private var chiTiet = ""
    @State private var dangGui = false
    @State private var loi: String?
    @State private var chanLuon = false

    private var cacLoai: [(String, String)] { [
        ("spam", String(localized: "Spam or advertising")),
        ("harassment", String(localized: "Harassment or bullying")),
        ("hate", String(localized: "Hate speech")),
        ("impersonation", String(localized: "Pretending to be someone else")),
        ("other", String(localized: "Something else")),
    ] }

    var body: some View {
        NavigationStack {
            Form {
                if let tin {
                    Section("Message") {
                        Text(verbatim: TomTatTinCTW.chu(tin))
                            .font(.ctw(size: 15)).foregroundColor(AppColors.textPrimary)
                            .lineLimit(4)
                            .accessibilityIdentifier("dm.report.preview")
                    }
                }
                Section {
                    Picker("Reason", selection: $loai) { ForEach(cacLoai, id: \.0) { Text($0.1).tag($0.0) } }
                        .pickerStyle(.inline).labelsHidden()
                } header: {
                    Text(tin != nil ? String(localized: "Why are you reporting this message from \(ten)?") : String(localized: "Why are you reporting \(ten)?"))
                }
                Section("Details (optional)") {
                    TextField("What happened?", text: $chiTiet, axis: .vertical).lineLimit(3...6)
                }
                Section {
                    Toggle("Also block \(ten)", isOn: $chanLuon)
                } footer: {
                    Text(tin != nil
                         ? String(localized: "The message will be hidden for you. Reports go to the CT Work moderation team, who review them within 24 hours. The person isn't told who reported them.")
                         : String(localized: "Reports go to the CT Work moderation team, who review them within 24 hours. The person isn't told who reported them."))
                }
                if let loi { Section { CTWErrorBanner(text: loi) } }
            }
            .navigationTitle(tin != nil ? String(localized: "Report message") : String(localized: "Report"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { Task { await gui() } }.disabled(dangGui)
                }
            }
        }
    }

    private func gui() async {
        dangGui = true; loi = nil
        defer { dangGui = false }
        let nhan = cacLoai.first { $0.0 == loai }?.1 ?? loai
        let lyDo = chiTiet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nhan : "\(nhan): \(chiTiet)"
        do {
            if let threadId {
                try await APIClient.shared.send(TinNhanAPI.baoCao(threadId: threadId, lyDo: lyDo, loai: loai, tinId: tin?.id))
                if let id = tin?.id {
                    AnNoiDungChungCTW.shared.an(TinNhanAPI.khoaAnTin(id))
                    daBaoCaoTin(id)
                }
            } else {
                // Chưa có hội thoại ⇒ đường báo cáo chung (hàng chờ kiểm duyệt của quản trị).
                try await ModerationStore.shared.baoCaoNoiDung(nhan: "Người dùng", noiDung: "@\(ten) (id \(userId))",
                                                                 ngucanh: "CT Work › Thành viên", lyDo: .harassment, chiTiet: lyDo)
            }
            if chanLuon { try? await ModerationStore.shared.block(userId: userId, reason: loai); await kho.taiDanhBa() }
            CTWRung.thanhCong()
            dong()
        } catch { loi = CTW.loi(error) }
    }
}
