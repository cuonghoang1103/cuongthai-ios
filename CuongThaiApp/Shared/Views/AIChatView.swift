import SwiftUI

/// Trò chuyện với AI. Chữ hiện DẦN theo luồng SSE, không đợi cả câu.
struct AIChatView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = AIChatViewModel()
    @State private var cauHoi = ""
    @State private var hienChonModel = false
    @FocusState private var dangGo: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if vm.tin.isEmpty && !vm.dangTraLoi {
                    manChao
                } else {
                    khungTin
                }
                oNhap
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle(vm.bacHienTai.ten)
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Đóng") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Bậc", selection: $vm.bac) {
                            ForEach(BacAI.allCases) { b in
                                Label(b.ten, systemImage: b.bieuTuong).tag(b)
                            }
                        }
                        Divider()
                        Button {
                            vm.hoiMoi()
                        } label: { Label("Cuộc trò chuyện mới", systemImage: "square.and.pencil") }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("AI", isPresented: .constant(vm.loi != nil)) {
                Button("OK") { vm.loi = nil }
            } message: { Text(vm.loi ?? "") }
        }
    }

    // MARK: Màn chào

    private var manChao: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                Image(systemName: "sparkles")
                    .font(.system(size: 44))
                    .foregroundStyle(AppColors.brandGradient)
                    .padding(.top, 60)
                Text("Hỏi CuongMini bất cứ điều gì")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Text(vm.bacHienTai.moTa)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)

                VStack(spacing: 8) {
                    ForEach(Self.goiY, id: \.self) { g in
                        Button {
                            cauHoi = g
                            gui()
                        } label: {
                            HStack {
                                Text(g).font(.system(size: 14))
                                    .foregroundColor(AppColors.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.backgroundSecondary))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)
            }
        }
    }

    private static let goiY = [
        "Giải thích con trỏ trong C cho người mới",
        "Viết hàm Java đảo ngược một chuỗi",
        "Tóm tắt sự khác nhau giữa SQL và NoSQL",
        "Cho tôi 5 câu tiếng Anh dùng khi phỏng vấn",
    ]

    // MARK: Khung tin

    private var khungTin: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.md) {
                    ForEach(vm.tin) { t in
                        BongBongAI(tin: t)
                            .id(t.id)
                    }
                    if vm.dangTraLoi {
                        dangLam
                            .id("dang-lam")
                    }
                    Color.clear.frame(height: 1).id("day")
                }
                .padding(Spacing.md)
            }
            // Cuộn theo chữ đang chảy — không thì người dùng phải tự vuốt
            // suốt lúc AI trả lời.
            .onChange(of: vm.tin.last?.noiDung) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo("day", anchor: .bottom) }
            }
            .onChange(of: vm.tin.count) { _, _ in
                withAnimation { proxy.scrollTo("day", anchor: .bottom) }
            }
        }
    }

    private var dangLam: some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.7)
            Text(vm.buocHienTai ?? "Đang nghĩ…")
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Capsule().fill(AppColors.backgroundSecondary))
    }

    // MARK: Ô nhập

    private var oNhap: some View {
        VStack(spacing: 0) {
            Divider().background(AppColors.divider)
            HStack(alignment: .bottom, spacing: Spacing.sm) {
                TextField("Nhắn cho CuongMini…", text: $cauHoi, axis: .vertical)
                    .font(.bodyMedium)
                    .lineLimit(1...6)
                    .focused($dangGo)
                    .padding(.horizontal, 13).padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 20)
                        .fill(AppColors.backgroundTertiary))

                if vm.dangTraLoi {
                    // Nút DỪNG — câu trả lời dài có thể chạy cả phút, không có
                    // nút này thì người dùng chỉ còn cách thoát màn hình.
                    Button { vm.dung() } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(AppColors.error)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button { gui() } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(coChu ? AppColors.primary : AppColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!coChu)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .background(AppColors.backgroundSecondary)
    }

    private var coChu: Bool { !cauHoi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func gui() {
        let c = cauHoi.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !c.isEmpty else { return }
        cauHoi = ""
        dangGo = false
        Haptics.cham()
        vm.gui(c)
    }
}

// MARK: - Bong bóng

struct BongBongAI: View {
    let tin: TinAI
    @State private var daChep = false
    @State private var hienBaoCao = false

    var body: some View {
        VStack(alignment: tin.cuaNguoi ? .trailing : .leading, spacing: 4) {
            if tin.cuaNguoi {
                Text(tin.noiDung)
                    .font(.bodyMedium)
                    .foregroundColor(AppColors.onPrimary)
                    .padding(.horizontal, 13).padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppColors.primary))
                    .frame(maxWidth: 300, alignment: .trailing)
            } else {
                // Câu trả lời dựng theo ĐÚNG luật của bài viết: tiêu đề, khối
                // mã tô màu, đường kẻ. AI hay trả lời kèm mã, để chữ trơn thì
                // mã dính liền văn xuôi và không đọc được.
                NoiDungBaiViet(noiDung: tin.noiDung)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !tin.dangChay {
                    HStack(spacing: Spacing.md) {
                        Button {
                            #if os(iOS)
                            UIPasteboard.general.string = tin.noiDung
                            #endif
                            Haptics.cham(); daChep = true
                            Task { try? await Task.sleep(nanoseconds: 1_500_000_000); daChep = false }
                        } label: {
                            Label(daChep ? "Đã chép" : "Chép", systemImage: daChep ? "checkmark" : "doc.on.doc")
                        }
                        // App Store 1.2: người dùng phải báo cáo được câu trả
                        // lời không phù hợp. Backend đã có `/ai/feedback`.
                        Button { hienBaoCao = true } label: {
                            Label("Báo cáo", systemImage: "flag")
                        }
                        Spacer()
                        if let m = tin.model {
                            Text(m).font(.system(size: 10)).foregroundColor(AppColors.textTertiary)
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.top, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: tin.cuaNguoi ? .trailing : .leading)
        .alert("Báo cáo câu trả lời", isPresented: $hienBaoCao) {
            Button("Gửi báo cáo", role: .destructive) {
                Task { _ = try? await APIClient.shared.send(.baoCaoTraLoiAI(messageId: tin.messageId)) }
            }
            Button("Huỷ", role: .cancel) { }
        } message: {
            Text("Câu trả lời này sai, gây hiểu lầm, hoặc không phù hợp? Báo cho chúng tôi để cải thiện.")
        }
    }
}
