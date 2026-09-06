import SwiftUI
import UserNotifications

// MARK: - Thông báo

/// Cài đặt thông báo. App có push từ lâu nhưng chưa có chỗ nào để xem/đổi —
/// người dùng lỡ bấm "Không cho phép" là mất mọi thông báo và không có đường
/// nào trong app chỉ họ quay lại.
struct CaiDatThongBaoView: View {
    @State private var trangThai: UNAuthorizationStatus = .notDetermined
    @State private var soNhacHoc = 0
    @State private var soNhacToi = 0
    @State private var gioNhac = Date()

    var body: some View {
        Form {
            Section {
                HStack {
                    Text(T("Trạng thái"))
                    Spacer()
                    Text(nhan)
                        .foregroundColor(mau)
                        .font(.system(size: 15, weight: .semibold))
                }
                if trangThai != .authorized {
                    Button(T("Mở Cài đặt iOS")) { moCaiDat() }
                }
            } header: {
                Text(T("Quyền thông báo"))
            } footer: {
                // iOS KHÔNG cho hỏi lại sau khi người dùng đã từ chối — đường
                // duy nhất là Cài đặt hệ thống. Nói thẳng thay vì để nút "cho
                // phép" bấm mãi không lên gì.
                Text(trangThai == .denied
                     ? T("Bạn đã từ chối thông báo. iOS không cho app hỏi lại — phải bật trong Cài đặt hệ thống.")
                     : T("Cần bật để nhận nhắc đi học, tin nhắn và thông báo mới."))
            }

            // ── Học ở nhà ────────────────────────────────────────────────
            Section {
                Toggle(T("Nhắc học ở nhà"), isOn: Binding(
                    get: { HocONha.bat },
                    set: { v in
                        HocONha.bat = v
                        Task { if v { await ganLai() } else { await HocONha.xoaNhacToi(); await dem() } }
                    }))
                if HocONha.bat {
                    DatePicker(T("Nhắc lúc"), selection: $gioNhac, displayedComponents: .hourAndMinute)
                        .onChange(of: gioNhac) { _, d in
                            let c = Calendar.current
                            HocONha.phutNhac = c.component(.hour, from: d) * 60 + c.component(.minute, from: d)
                            Task { await ganLai() }
                        }
                    HStack {
                        Text(T("Lời nhắc đang đặt"))
                        Spacer()
                        Text("\(soNhacToi)")
                            .font(.system(size: 15, weight: .semibold).monospacedDigit())
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            } header: {
                Text(T("Học ở nhà"))
            } footer: {
                // Nói rõ CƠ CHẾ, vì hai điều dưới đây gây bất ngờ nhất:
                // ngày trống không nhắc, và app phải mở ít nhất một lần sau
                // khi đổi lịch thì lời nhắc mới khớp lịch mới.
                Text(T("Mỗi ngày có lớp, app nhắc một lần vào giờ này và nói rõ hôm nay bạn học môn gì. Ngày không có lớp thì không nhắc. Việc “Ôn <môn> — 20 phút” được tự thêm vào Tổng quan sau khi buổi học kết thúc."))
            }

            Section {
                HStack {
                    Text(T("Nhắc đi học đang đặt"))
                    Spacer()
                    Text("\(soNhacHoc)")
                        .font(.system(size: 15, weight: .semibold).monospacedDigit())
                        .foregroundColor(AppColors.textSecondary)
                }
                Button(role: .destructive) {
                    Task { await NhacHoc.xoaHet(); await dem() }
                } label: {
                    Text(T("Xoá hết lời nhắc đi học"))
                }
                .disabled(soNhacHoc == 0)
            } header: {
                Text(T("Nhắc đi học"))
            } footer: {
                Text(T("Lời nhắc đặt sẵn trong máy, lặp hằng tuần, không cần mạng. Mở lại Thời khoá biểu là chúng được đặt lại."))
            }
        }
        .navigationTitle(T("Thông báo"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await dem() }
    }

    private var nhan: String {
        switch trangThai {
        case .authorized:   return T("Đang bật")
        case .provisional:  return T("Bật im lặng")
        case .denied:       return T("Đã tắt")
        default:            return T("Chưa hỏi")
        }
    }
    private var mau: Color {
        switch trangThai {
        case .authorized, .provisional: return AppColors.success
        case .denied: return AppColors.error
        default: return AppColors.textSecondary
        }
    }

    private func dem() async {
        let tt = UNUserNotificationCenter.current()
        trangThai = await tt.notificationSettings().authorizationStatus
        soNhacHoc = await tt.pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix("buoihoc-") }.count
        soNhacToi = await HocONha.demNhacToi()
        gioNhac = Calendar.current.date(bySettingHour: HocONha.phutNhac / 60,
                                        minute: HocONha.phutNhac % 60,
                                        second: 0, of: Date()) ?? Date()
    }

    /// Đặt lại lời nhắc buổi tối. Cần LỊCH mới biết mỗi thứ học môn gì, nên
    /// phải hỏi máy chủ — không cache được ở màn Cài đặt.
    private func ganLai() async {
        if let d: DapAnLichHoc = try? await APIClient.shared.request(
            .lichHoc(ngay: PhamViViec.today.moc())) {
            await HocONha.datLaiNhacToi(d.items)
        }
        await dem()
    }

    private func moCaiDat() {
        #if os(iOS)
        if let u = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(u)
        }
        #endif
    }
}

// MARK: - Tải dữ liệu của tôi

/// Quyền chủ thể dữ liệu (Nghị định 13/2023) — `GET /profile/export-data` đã
/// chạy trên máy chủ từ lâu mà app chưa bao giờ gọi. Apple cũng nhìn phần này
/// khi duyệt app có thu thập dữ liệu người dùng.
struct TaiDuLieuView: View {
    @State private var dangTai = false
    @State private var tepDaTai: URL?
    @State private var loi: String?

    var body: some View {
        Form {
            Section {
                Text(T("Bạn có quyền lấy một bản sao dữ liệu cá nhân của mình. Bản tải về là một tệp JSON gồm hồ sơ, bài viết, ghi chú, tiến độ học và các dữ liệu khác gắn với tài khoản."))
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
            }

            Section {
                if dangTai {
                    HStack { ProgressView(); Text(T("Đang chuẩn bị…")).padding(.leading, 6) }
                } else if let tep = tepDaTai {
                    ShareLink(item: tep) {
                        Label(T("Lưu hoặc chia sẻ tệp"), systemImage: "square.and.arrow.up")
                    }
                    Button(T("Tải lại")) { Task { await tai() } }
                } else {
                    Button { Task { await tai() } } label: {
                        Label(T("Tải dữ liệu của tôi"), systemImage: "arrow.down.doc")
                    }
                }
                if let loi {
                    Text(loi).font(.system(size: 13)).foregroundColor(AppColors.error)
                }
            }
        }
        .navigationTitle(T("Dữ liệu của tôi"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tai() async {
        dangTai = true; loi = nil
        defer { dangTai = false }
        do {
            // Lấy JSON THÔ: dữ liệu xuất ra có hình dạng tuỳ tài khoản, khai
            // một struct Codable cho nó là tự chuốc lỗi giải mã mỗi lần máy
            // chủ thêm một mục.
            let raw = try await APIClient.shared.requestRaw(.taiDuLieuCuaToi)
            let ten = "cuongthai-du-lieu-\(PhamViViec.dinhDang.string(from: Date())).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(ten)
            try raw.write(to: url, options: .atomic)
            tepDaTai = url
            Haptics.xong()
        } catch {
            loi = error.localizedDescription
        }
    }
}
