import SwiftUI
import UserNotifications

// MARK: - Thông báo

/// Cài đặt thông báo. App có push từ lâu nhưng chưa có chỗ nào để xem/đổi —
/// người dùng lỡ bấm "Không cho phép" là mất mọi thông báo và không có đường
/// nào trong app chỉ họ quay lại.
struct CaiDatThongBaoView: View {
    @State private var trangThai: UNAuthorizationStatus = .notDetermined
    @State private var soNhacHoc = 0

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
