import SwiftUI
import PhotosUI

/// Màn "Chỉnh sửa hồ sơ" — đầy đủ mọi trường backend nhận, kiểm ngay tại máy
/// bằng ĐÚNG luật của máy chủ.
///
/// ⚠️ Bản cũ chỉ có 3 ô (tên hiển thị / họ tên / giới thiệu) trong khi
/// `authService.updateProfile` nhận tới 11 trường, và nó mang một lỗi thật:
///
/// ```swift
/// if !fullName.isEmpty { payload["fullName"] = fullName }
/// ```
///
/// Ô nào bị xoá trắng thì KHÔNG được gửi đi, mà backend chỉ ghi đè khi khoá
/// CÓ MẶT (`if data.fullName !== undefined`). Nên **xoá tên rồi bấm Lưu thì
/// tên cũ vẫn nguyên** — người dùng không có cách nào bỏ trống một trường.
/// Ở đây trường rỗng gửi `NSNull()`, đúng nghĩa "xoá đi".
struct ChinhSuaHoSoView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // ── Trường ────────────────────────────────────────────────────────────
    @State private var tenHienThi = ""
    @State private var hoTen = ""
    @State private var gioiThieu = ""
    @State private var email = ""
    @State private var gioiTinh: String? = nil
    @State private var namSinh = ""
    @State private var dienThoai = ""
    @State private var lienKet: [String: String] = [:]
    @State private var choNguoiLaNhanTin = true
    @State private var hienTrangThaiHoatDong = true

    // ── Trạng thái ────────────────────────────────────────────────────────
    @State private var goc: [String: String] = [:]
    @State private var dangLuu = false
    @State private var loi: String?
    @State private var hoiThoat = false
    @State private var anhDaiDien: PhotosPickerItem?
    @State private var anhBia: PhotosPickerItem?
    @State private var dangTaiAnh = false
    @State private var urlAvatar: String?
    @State private var urlBia: String?

    private let GIOI_HAN_TEN = 100
    private let GIOI_HAN_BIO = 500
    /// Đúng danh sách trắng của backend, đúng thứ tự hiển thị.
    private let MANG: [(khoa: String, ten: String, bieuTuong: String, goiY: String)] = [
        ("github",   "GitHub",   "chevron.left.forwardslash.chevron.right", "https://github.com/…"),
        ("linkedin", "LinkedIn", "briefcase",                               "https://linkedin.com/in/…"),
        ("facebook", "Facebook", "person.2",                                "https://facebook.com/…"),
        ("youtube",  "YouTube",  "play.rectangle",                          "https://youtube.com/@…"),
        ("twitter",  "X",        "at",                                      "https://x.com/…"),
        ("website",  "Website",  "globe",                                   "https://…"),
    ]

    var body: some View {
        Form {
            phanAnh
            phanTen
            phanGioiThieu
            phanCaNhan
            phanLienKet
            phanRiengTu
            if let loi {
                Section {
                    Label(loi, systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(AppColors.error)
                        .font(.system(size: 13))
                }
            }
        }
        .navigationTitle(T("Chỉnh sửa hồ sơ"))
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(coThayDoi)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(T("Huỷ")) { if coThayDoi { hoiThoat = true } else { dismiss() } }
            }
            ToolbarItem(placement: .confirmationAction) {
                if dangLuu {
                    ProgressView()
                } else {
                    Button(T("Lưu")) { Task { await luu() } }
                        .font(.system(size: 16, weight: .semibold))
                        .disabled(!coThayDoi || loiDauTien != nil)
                }
            }
        }
        .confirmationDialog(T("Bỏ thay đổi?"), isPresented: $hoiThoat, titleVisibility: .visible) {
            Button(T("Bỏ thay đổi"), role: .destructive) { dismiss() }
            Button(T("Tiếp tục sửa"), role: .cancel) { }
        } message: {
            Text(T("Những gì bạn vừa sửa sẽ không được lưu."))
        }
        .onChange(of: anhDaiDien) { _, v in if let v { Task { await taiAnh(v, khoa: "avatarUrl") } } }
        .onChange(of: anhBia) { _, v in if let v { Task { await taiAnh(v, khoa: "coverPhotoUrl") } } }
        .onAppear(perform: nap)
    }

    // MARK: Ảnh

    private var phanAnh: some View {
        Section {
            HStack(spacing: Spacing.md) {
                ZStack(alignment: .bottomTrailing) {
                    UserAvatarView(url: urlAvatar ?? appState.currentUser?.avatarUrl, size: 68)
                    if dangTaiAnh {
                        ProgressView().scaleEffect(0.7)
                            .frame(width: 68, height: 68)
                            .background(Color.black.opacity(0.35)).clipShape(Circle())
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(T("Ảnh đại diện")).font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                    Text(T("Ảnh vuông cho kết quả đẹp nhất."))
                        .font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
                }
                Spacer(minLength: 0)
                PhotosPicker(selection: $anhDaiDien, matching: .images) {
                    Text(T("Đổi")).font(.system(size: 14, weight: .semibold))
                }
                .disabled(dangTaiAnh)
            }
            .padding(.vertical, 4)

            HStack(spacing: Spacing.md) {
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(LinearGradient(colors: [AppColors.primary, AppColors.primaryDark],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 68, height: 40)
                    .overlay {
                        if let u = urlBia ?? appState.currentUser?.coverPhotoUrl, let url = URL(string: u) {
                            AsyncImage(url: url) { $0.resizable().aspectRatio(contentMode: .fill) }
                                placeholder: { Color.clear }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                Text(T("Ảnh bìa")).font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                Spacer(minLength: 0)
                PhotosPicker(selection: $anhBia, matching: .images) {
                    Text(T("Đổi")).font(.system(size: 14, weight: .semibold))
                }
                .disabled(dangTaiAnh)
            }
            .padding(.vertical, 4)
        } header: {
            Text(T("Ảnh"))
        } footer: {
            // Ảnh lưu NGAY, không chờ nút Lưu — người dùng chọn ảnh là đã
            // quyết định rồi, và giữ ảnh trong bộ nhớ chờ "Lưu" thì thoát
            // giữa chừng là mất công tải lên.
            Text(T("Ảnh được lưu ngay khi bạn chọn."))
        }
    }

    // MARK: Tên

    private var phanTen: some View {
        Section {
            oChu(T("Tên hiển thị"), text: $tenHienThi, gioiHan: GIOI_HAN_TEN)
            oChu(T("Họ và tên"), text: $hoTen, gioiHan: GIOI_HAN_TEN)
        } header: {
            Text(T("Tên"))
        } footer: {
            Text(T("Tên hiển thị là tên người khác nhìn thấy. Bỏ trống thì hệ thống dùng họ tên, rồi tới tên đăng nhập."))
        }
    }

    private var phanGioiThieu: some View {
        Section {
            TextField(T("Vài dòng về bạn"), text: $gioiThieu, axis: .vertical)
                .lineLimit(3...8)
            HStack {
                Spacer()
                Text("\(gioiThieu.count)/\(GIOI_HAN_BIO)")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundColor(gioiThieu.count > GIOI_HAN_BIO ? AppColors.error : AppColors.textTertiary)
            }
        } header: {
            Text(T("Giới thiệu"))
        }
    }

    // MARK: Cá nhân

    private var phanCaNhan: some View {
        Section {
            Picker(T("Giới tính"), selection: $gioiTinh) {
                Text(T("Không nói")).tag(String?.none)
                Text(T("Nam")).tag(String?("MALE"))
                Text(T("Nữ")).tag(String?("FEMALE"))
                Text(T("Khác")).tag(String?("OTHER"))
            }

            HStack {
                Text(T("Năm sinh"))
                Spacer()
                TextField("2000", text: $namSinh)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 84)
                    .foregroundColor(loiNamSinh == nil ? AppColors.textPrimary : AppColors.error)
            }
            if let e = loiNamSinh { ghiChuLoi(e) }

            HStack {
                Text(T("Điện thoại"))
                Spacer()
                TextField("0912 345 678", text: $dienThoai)
                    .keyboardType(.phonePad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(loiDienThoai == nil ? AppColors.textPrimary : AppColors.error)
            }
            if let e = loiDienThoai { ghiChuLoi(e) }

            HStack {
                Text(T("Email"))
                Spacer()
                TextField("ban@vidu.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(loiEmail == nil ? AppColors.textPrimary : AppColors.error)
            }
            if let e = loiEmail { ghiChuLoi(e) }
        } header: {
            Text(T("Thông tin cá nhân"))
        } footer: {
            Text(T("Điện thoại và năm sinh chỉ mình bạn thấy."))
        }
    }

    // MARK: Liên kết

    private var phanLienKet: some View {
        Section {
            ForEach(MANG, id: \.khoa) { m in
                HStack(spacing: Spacing.sm) {
                    Image(systemName: m.bieuTuong)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 22)
                    TextField(m.goiY, text: Binding(
                        get: { lienKet[m.khoa] ?? "" },
                        set: { lienKet[m.khoa] = $0 }
                    ))
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundColor(hopLeURL(lienKet[m.khoa]) ? AppColors.textPrimary : AppColors.error)
                }
            }
        } header: {
            Text(T("Liên kết"))
        } footer: {
            // Backend `new URL(trimmed)` NÉM nếu thiếu scheme, và lỗi đó làm
            // hỏng cả lượt lưu chứ không riêng một ô.
            Text(T("Phải là địa chỉ đầy đủ, bắt đầu bằng https://"))
        }
    }

    private var phanRiengTu: some View {
        Section {
            Toggle(T("Cho người lạ nhắn tin"), isOn: $choNguoiLaNhanTin)
            Toggle(T("Hiện trạng thái hoạt động"), isOn: $hienTrangThaiHoatDong)
        } header: {
            Text(T("Riêng tư"))
        } footer: {
            // Nói rõ CẢ HAI CHIỀU. Messenger của Facebook cũng đánh đổi đúng
            // như vậy, và người dùng cần biết trước khi tắt — không thì họ
            // tắt xong lại tưởng app hỏng vì bạn bè bỗng "mất" chấm xanh.
            Text(T("Cho người lạ nhắn tin: tắt thì chỉ người bạn từng nhắn mới mở được cuộc trò chuyện mới.\n\nHiện trạng thái hoạt động: tắt thì không ai thấy bạn đang hoạt động hay hoạt động lúc nào — và bạn cũng không thấy của họ."))
        }
    }

    // MARK: Ô chữ có bộ đếm

    private func oChu(_ nhan: String, text: Binding<String>, gioiHan: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            TextField(nhan, text: text)
            if text.wrappedValue.count > gioiHan * 4 / 5 {
                HStack {
                    Spacer()
                    Text("\(text.wrappedValue.count)/\(gioiHan)")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundColor(text.wrappedValue.count > gioiHan ? AppColors.error : AppColors.textTertiary)
                }
            }
        }
    }

    private func ghiChuLoi(_ s: String) -> some View {
        Text(s).font(.system(size: 12)).foregroundColor(AppColors.error)
    }

    // MARK: Kiểm — ĐÚNG luật của máy chủ, kiểm ngay tại máy

    private var loiNamSinh: String? {
        guard !namSinh.isEmpty else { return nil }
        guard let n = Int(namSinh) else { return T("Năm sinh phải là số.") }
        let nay = Calendar.current.component(.year, from: Date())
        return (n < 1900 || n > nay) ? String(format: T("Năm sinh phải từ 1900 đến %d."), nay) : nil
    }

    private var loiDienThoai: String? {
        guard !dienThoai.isEmpty else { return nil }
        // Đúng biểu thức của backend: ^[\d+\-\s()]{10,20}$
        let ok = dienThoai.range(of: #"^[\d+\-\s()]{10,20}$"#, options: .regularExpression) != nil
        return ok ? nil : T("Số điện thoại phải 10–20 ký tự, chỉ gồm chữ số, +, -, khoảng trắng và ngoặc.")
    }

    private var loiEmail: String? {
        guard !email.isEmpty else { return T("Email không được để trống.") }
        let ok = email.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
        return ok ? nil : T("Email không hợp lệ.")
    }

    private func hopLeURL(_ s: String?) -> Bool {
        guard let s, !s.trimmingCharacters(in: .whitespaces).isEmpty else { return true }
        guard let u = URL(string: s.trimmingCharacters(in: .whitespaces)), let sc = u.scheme else { return false }
        return (sc == "https" || sc == "http") && u.host != nil
    }

    private var loiDauTien: String? {
        if tenHienThi.count > GIOI_HAN_TEN { return T("Tên hiển thị quá dài.") }
        if hoTen.count > GIOI_HAN_TEN { return T("Họ và tên quá dài.") }
        if gioiThieu.count > GIOI_HAN_BIO { return T("Giới thiệu quá dài.") }
        if let e = loiNamSinh { return e }
        if let e = loiDienThoai { return e }
        if let e = loiEmail { return e }
        if MANG.contains(where: { !hopLeURL(lienKet[$0.khoa]) }) { return T("Có liên kết chưa đúng địa chỉ.") }
        return nil
    }

    // MARK: Nạp / so sánh / lưu

    private var anhChup: [String: String] {
        var d: [String: String] = [
            "tenHienThi": tenHienThi, "hoTen": hoTen, "gioiThieu": gioiThieu,
            "email": email, "gioiTinh": gioiTinh ?? "", "namSinh": namSinh,
            "dienThoai": dienThoai, "dm": choNguoiLaNhanTin ? "1" : "0",
            "tthd": hienTrangThaiHoatDong ? "1" : "0",
        ]
        for m in MANG { d["lk_" + m.khoa] = lienKet[m.khoa] ?? "" }
        return d
    }

    /// Nút Lưu chỉ sáng khi thật sự có gì đó đổi — bấm Lưu mà không đổi gì thì
    /// vẫn gọi mạng, và tệ hơn là người dùng không biết mình đã đổi những gì.
    private var coThayDoi: Bool { anhChup != goc }

    private func nap() {
        guard let u = appState.currentUser else { return }
        tenHienThi = u.displayName ?? ""
        hoTen = u.fullName ?? ""
        gioiThieu = u.bio ?? ""
        email = u.email ?? ""
        gioiTinh = u.gender
        namSinh = u.birthYear.map(String.init) ?? ""
        dienThoai = u.phone ?? ""
        lienKet = u.socialLinks ?? [:]
        choNguoiLaNhanTin = u.allowMessagesFromStrangers ?? true
        // `nil` = máy chủ bản cũ chưa trả trường này ⇒ coi như BẬT, đúng mặc
        // định phía máy chủ. Mặc định `false` sẽ làm người dùng bản cũ bỗng
        // thành ẩn mà không ai bấm gì.
        hienTrangThaiHoatDong = u.showActiveStatus ?? true
        goc = anhChup
    }

    private func taiAnh(_ item: PhotosPickerItem, khoa: String) async {
        dangTaiAnh = true
        defer { dangTaiAnh = false; anhDaiDien = nil; anhBia = nil }
        loi = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let anh = PlatformImage(data: data),
                  let jpeg = anh.jpegDataForUpload() else {
                loi = T("Không đọc được ảnh vừa chọn."); return
            }
            let thuMuc = khoa == "avatarUrl" ? "avatars" : "covers"
            let file = try await APIClient.shared.upload(
                data: jpeg, fileName: "\(thuMuc)-\(UUID().uuidString).jpg",
                mimeType: "image/jpeg", category: thuMuc)
            try await APIClient.shared.send(.updateProfile([khoa: file.url]))
            await appState.fetchProfile()
            if khoa == "avatarUrl" { urlAvatar = file.url } else { urlBia = file.url }
            Haptics.xong()
        } catch {
            loi = error.localizedDescription
        }
    }

    private func luu() async {
        if let e = loiDauTien { loi = e; return }
        dangLuu = true
        loi = nil
        defer { dangLuu = false }

        func chu(_ s: String) -> Any {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? NSNull() : t          // rỗng = XOÁ, không phải "bỏ qua"
        }

        var p: [String: Any] = [
            "displayName": chu(tenHienThi),
            "fullName": chu(hoTen),
            "bio": chu(gioiThieu),
            "gender": gioiTinh ?? NSNull(),
            "phone": chu(dienThoai),
            "allowMessagesFromStrangers": choNguoiLaNhanTin,
            "showActiveStatus": hienTrangThaiHoatDong,
        ]
        p["email"] = email.trimmingCharacters(in: .whitespaces).lowercased()
        p["birthYear"] = namSinh.isEmpty ? NSNull() : (Int(namSinh) ?? NSNull())

        var lk: [String: String] = [:]
        for m in MANG {
            let v = (lienKet[m.khoa] ?? "").trimmingCharacters(in: .whitespaces)
            if !v.isEmpty { lk[m.khoa] = v }
        }
        p["socialLinks"] = lk.isEmpty ? NSNull() : lk

        do {
            try await APIClient.shared.send(.updateProfile(p))
            await appState.fetchProfile()
            Haptics.xong()
            dismiss()
        } catch {
            loi = error.localizedDescription
        }
    }
}
