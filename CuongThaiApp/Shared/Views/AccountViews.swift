import SwiftUI

// MARK: - Models for the deletion flow

struct DeletionRequest: Codable, Identifiable {
    let id: Int
    let status: String
    let reason: String?
    let createdAt: String?

    var isOpen: Bool { status == "PENDING" }

    var statusLabel: String {
        switch status {
        case "PENDING": return "Đang chờ xoá (72 giờ)"
        case "APPROVED": return "Đã xoá"
        case "REJECTED": return "Bị từ chối"
        case "CANCELLED": return "Đã rút lại"
        default: return status
        }
    }
}

private struct DeletionRequestEnvelope: Codable { let request: DeletionRequest? }
private struct DeletionRequestResult: Codable { let request: DeletionRequest; let created: Bool? }

// MARK: - Delete account (App Store Guideline 5.1.1(v))
//
// Apple requires account deletion to be startable from inside the app, with a
// clear description of what happens. The backend runs a reviewed erasure
// (services/accountDeletion.service.ts): filing the request starts a 72h
// window, after which the account is anonymised — password cleared, e-mail and
// username rotated, every session invalidated. The copy below states that
// plainly, and the user can withdraw the request while it is still open.

struct DeleteAccountView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var existing: DeletionRequest?
    @State private var reason = ""
    @State private var isLoading = true
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var showConfirm = false

    var body: some View {
        List {
            if isLoading {
                Section { HStack { Spacer(); ProgressView(); Spacer() } }
            } else if let existing, existing.isOpen {
                pendingSections(existing)
            } else {
                requestSections
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundColor(AppColors.error) }
            }
        }
        .navigationTitle("Xoá tài khoản")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("Xoá tài khoản vĩnh viễn?", isPresented: $showConfirm) {
            Button("Huỷ", role: .cancel) { }
            Button("Gửi yêu cầu xoá", role: .destructive) {
                Task { await submit() }
            }
        } message: {
            Text("72 giờ sau khi gửi yêu cầu, tài khoản và dữ liệu cá nhân của bạn sẽ tự động bị xoá và KHÔNG thể khôi phục. Bạn có thể rút lại yêu cầu trong 72 giờ đó.")
        }
    }

    // MARK: Sections

    /// "lúc 14:05 ngày 27/09" — mốc máy chủ tự xoá (`HAN_TU_XOA_GIO` = 72 trong
    /// `accountDeletion.service.ts`). Không đọc được mốc thì nói chung chung.
    private func hanXoa(_ request: DeletionRequest) -> String {
        guard let iso = request.createdAt else { return "sau 72 giờ" }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let goc = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let goc else { return "sau 72 giờ" }
        let d = DateFormatter()
        d.locale = Locale(identifier: "vi_VN")
        d.dateFormat = "HH:mm 'ngày' dd/MM"
        return "lúc " + d.string(from: goc.addingTimeInterval(72 * 3600))
    }

    @ViewBuilder
    private func pendingSections(_ request: DeletionRequest) -> some View {
        Section {
            Label("Tài khoản sẽ bị xoá \(hanXoa(request))", systemImage: "clock.fill")
                .foregroundColor(AppColors.warning)
            if let reason = request.reason, !reason.isEmpty {
                Text("Lý do bạn ghi: \(reason)")
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
            }
        } footer: {
            Text("Tài khoản và dữ liệu cá nhân sẽ TỰ ĐỘNG bị xoá vĩnh viễn 72 giờ sau khi gửi yêu cầu. Trong 72 giờ này bạn vẫn dùng ứng dụng bình thường và có thể rút lại yêu cầu.")
        }

        Section {
            Button {
                Task { await cancel() }
            } label: {
                HStack {
                    Spacer()
                    if isWorking { ProgressView() } else { Text("Rút lại yêu cầu") }
                    Spacer()
                }
            }
            .disabled(isWorking)
        }
    }

    @ViewBuilder
    private var requestSections: some View {
        Section {
            LegalBullet("Hồ sơ, bài viết, bình luận và tin nhắn của bạn sẽ bị gỡ khỏi dịch vụ")
            LegalBullet("Email và tên đăng nhập được vô hiệu hoá, không ai dùng lại được")
            LegalBullet("Mọi phiên đăng nhập trên web và ứng dụng bị đăng xuất")
            LegalBullet("Thao tác này KHÔNG THỂ hoàn tác")
        } header: {
            Text("Điều gì sẽ xảy ra")
        }

        Section("Lý do (không bắt buộc)") {
            TextField("Vì sao bạn muốn rời đi?", text: $reason, axis: .vertical)
                .lineLimit(2...5)
        }

        Section {
            Button(role: .destructive) {
                showConfirm = true
            } label: {
                HStack {
                    Spacer()
                    if isWorking { ProgressView() } else { Text("Xoá tài khoản của tôi") }
                    Spacer()
                }
            }
            .disabled(isWorking)
        } footer: {
            Text("Cần trợ giúp thay vì xoá? Liên hệ \(SupportContact.email)")
        }
    }

    // MARK: Actions

    private func load() async {
        isLoading = true
        do {
            let envelope: DeletionRequestEnvelope = try await APIClient.shared.request(.getDeletionRequest)
            existing = envelope.request
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func submit() async {
        isWorking = true
        errorMessage = nil
        do {
            let result: DeletionRequestResult = try await APIClient.shared.request(
                .requestDeletion(reason: reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : reason)
            )
            existing = result.request
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }

    private func cancel() async {
        isWorking = true
        errorMessage = nil
        do {
            let envelope: DeletionRequestEnvelope = try await APIClient.shared.request(.cancelDeletionRequest)
            existing = envelope.request?.isOpen == true ? envelope.request : nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }
}

// MARK: - Edit profile

// `EditProfileView` cũ đã GỠ 06/09/2026 — thay bằng
// `Profile/ChinhSuaHoSoView.swift`. Bản cũ chỉ sửa được 3 trong 11 trường
// backend nhận, và mang lỗi `if !fullName.isEmpty` khiến xoá trắng một ô rồi
// Lưu thì giá trị cũ vẫn nguyên.

// MARK: - Change password

struct ChangePasswordView: View {
    @EnvironmentObject private var appState: AppState

    @State private var current = ""
    @State private var newPassword = ""
    @State private var confirm = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        !current.isEmpty && newPassword.count >= 12 && newPassword == confirm
    }

    var body: some View {
        Form {
            Section("Mật khẩu hiện tại") {
                SecureField("Mật khẩu hiện tại", text: $current)
            }
            Section {
                SecureField("Mật khẩu mới", text: $newPassword)
                SecureField("Nhập lại mật khẩu mới", text: $confirm)
            } header: {
                Text("Mật khẩu mới")
            } footer: {
                Text("Tối thiểu 12 ký tự. Sau khi đổi, bạn sẽ được đăng xuất khỏi mọi thiết bị.")
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundColor(AppColors.error) }
            }

            Section {
                Button {
                    Task { await save() }
                } label: {
                    HStack {
                        Spacer()
                        if isSaving { ProgressView() } else { Text("Đổi mật khẩu") }
                        Spacer()
                    }
                }
                .disabled(!isValid || isSaving)
            }
        }
        .navigationTitle("Đổi mật khẩu")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        do {
            try await APIClient.shared.send(.changePassword(current: current, new: newPassword))
            // The backend invalidates the session on success.
            appState.logout()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
