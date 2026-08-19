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
        case "PENDING": return "Đang chờ xử lý"
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
            Text("Sau khi xử lý, tài khoản và dữ liệu cá nhân của bạn sẽ bị xoá và KHÔNG thể khôi phục.")
        }
    }

    // MARK: Sections

    @ViewBuilder
    private func pendingSections(_ request: DeletionRequest) -> some View {
        Section {
            Label("Yêu cầu xoá đang chờ xử lý", systemImage: "clock.fill")
                .foregroundColor(AppColors.warning)
            if let reason = request.reason, !reason.isEmpty {
                Text("Lý do bạn ghi: \(reason)")
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
            }
        } footer: {
            Text("Tài khoản sẽ bị xoá sau khi yêu cầu được xử lý. Trong thời gian này bạn vẫn dùng ứng dụng bình thường và có thể rút lại yêu cầu.")
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

struct EditProfileView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var fullName = ""
    @State private var displayName = ""
    @State private var bio = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didSave = false

    var body: some View {
        Form {
            Section("Tên hiển thị") {
                TextField("Tên hiển thị", text: $displayName)
                TextField("Họ và tên", text: $fullName)
            }

            Section("Giới thiệu") {
                TextField("Vài dòng về bạn", text: $bio, axis: .vertical)
                    .lineLimit(3...6)
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundColor(AppColors.error) }
            }

            if didSave {
                Section {
                    Label("Đã lưu", systemImage: "checkmark.circle.fill")
                        .foregroundColor(AppColors.success)
                }
            }

            Section {
                Button {
                    Task { await save() }
                } label: {
                    HStack {
                        Spacer()
                        if isSaving { ProgressView() } else { Text("Lưu thay đổi") }
                        Spacer()
                    }
                }
                .disabled(isSaving)
            }
        }
        .navigationTitle("Chỉnh sửa hồ sơ")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard let user = appState.currentUser else { return }
            fullName = user.fullName ?? ""
            displayName = user.displayName ?? ""
            bio = user.bio ?? ""
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        didSave = false
        var payload: [String: Any] = [:]
        if !fullName.isEmpty { payload["fullName"] = fullName }
        if !displayName.isEmpty { payload["displayName"] = displayName }
        payload["bio"] = bio
        do {
            try await APIClient.shared.send(.updateProfile(payload))
            await appState.fetchProfile()
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

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
