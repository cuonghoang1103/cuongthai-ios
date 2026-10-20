import SwiftUI

// MARK: - CT Work — MÔ TẢ thẻ: đọc (tick ô việc ngay tại chỗ) + soạn (markdown ⇄ TipTap)
//
// Như web (`IssueDetail.tsx → Description`): bấm "Edit" mở trình soạn, Save ⇒ PATCH `descriptionJson`
// kèm `version`. Tick ô việc ở chế độ đọc ⇒ sửa đúng `attrs.checked` trong JSON THÔ rồi PATCH (không đi qua
// markdown ⇒ không mất định dạng nào). 409 (có người sửa chen) ⇒ giữ bản nháp, báo, cho lưu lại.

struct CTWIssueMoTaView: View {
    @ObservedObject var vm: CTWIssueVM
    let coTheSua: Bool
    @State private var dangSoan = false
    @State private var lyDo: String?

    var body: some View {
        let khoi = CTWTipTap.khoi(vm.the?.descriptionJson)
        let khongSua = CTWMoTaThe.lyDoKhongSua(vm.them?.descriptionJson)
        VStack(alignment: .leading, spacing: 8) {
            CTWSectionHeader("text.alignleft", String(localized: "Description"), trailing: coTheSua ? AnyView(
                Button {
                    if let khongSua { lyDo = khongSua } else { dangSoan = true }
                } label: {
                    Label("Edit", systemImage: "pencil").font(.ctw(size: 13, weight: .semibold))
                        .frame(minWidth: 44, minHeight: 32)
                }
                .accessibilityIdentifier("ctw.moTa.sua")
            ) : nil)
            Group {
                if khoi.isEmpty {
                    if coTheSua {
                        Button { dangSoan = true } label: {
                            Text("Add a description…")
                                .font(.ctw(size: 14)).foregroundColor(AppColors.textTertiary)
                                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("No description.")
                            .font(.ctw(size: 14)).foregroundColor(AppColors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    noiDung(khoi)
                }
            }
            .padding(14)
            .ctwThe(12)
        }
        .alert("Can't edit here", isPresented: Binding(get: { lyDo != nil }, set: { if !$0 { lyDo = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(lyDo ?? "")
        }
        .sheet(isPresented: $dangSoan) {
            CTWSuaMoTaView(banDau: CTWMoTaThe.markdown(vm.them?.descriptionJson)) { md in await vm.luuMoTa(md) }
        }
        #if DEBUG
        .task {
            let man = ProcessInfo.processInfo.environment["CT_XEM_MAN"]?.lowercased()
            if man == "the:suamota" {
                try? await Task.sleep(nanoseconds: 700_000_000)
                dangSoan = true
            } else if man == "the:tick" {
                // Chụp màn: tick ô việc thứ 3 ("Works when the app was force-quit") như người dùng bấm.
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await vm.doiViec(2)
            }
        }
        #endif
    }

    /// Khối mô tả; ô việc cấp ngoài cùng bấm được (khi số ô khớp với JSON thô — lệch thì chỉ đọc, không đoán).
    @ViewBuilder
    private func noiDung(_ khoi: [CTWKhoi]) -> some View {
        let soViecHien = khoi.filter { if case .viec = $0 { return true }; return false }.count
        let tickDuoc = coTheSua && soViecHien > 0 && soViecHien == CTWMoTaThe.soViec(vm.them?.descriptionJson)
        if !tickDuoc {
            CTWKhoiView(khoi: khoi, coChu: 14.5)
        } else {
            let chiSo = Self.chiSoViec(khoi)
            VStack(alignment: .leading, spacing: 9) {
                ForEach(Array(khoi.enumerated()), id: \.offset) { i, k in
                    if case .viec(let a, let xong, let cap) = k, let n = chiSo[i] {
                        Button { Task { await vm.doiViec(n) } } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: xong ? "checkmark.square.fill" : "square")
                                    .font(.ctw(size: 17))
                                    .foregroundColor(xong ? AppColors.success : AppColors.textTertiary)
                                Text(a).font(.ctw(size: 14.5))
                                    .foregroundColor(xong ? AppColors.textSecondary : AppColors.textPrimary)
                                    .strikethrough(xong)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .padding(.leading, CGFloat(cap) * 16)
                            .frame(minHeight: 32)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.dangGui)
                        .accessibilityAddTraits(.isToggle)
                        .accessibilityValue(xong ? Text("Done") : Text("Not done"))
                        .accessibilityHint(Text("Double-tap to tick or untick"))
                    } else {
                        CTWKhoiView(khoi: [k], coChu: 14.5)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Vị trí khối ⇒ thứ tự ô việc (0, 1, 2…).
    static func chiSoViec(_ khoi: [CTWKhoi]) -> [Int: Int] {
        var d: [Int: Int] = [:]
        var n = 0
        for (i, k) in khoi.enumerated() { if case .viec = k { d[i] = n; n += 1 } }
        return d
    }
}

// MARK: - Màn soạn mô tả

struct CTWSuaMoTaView: View {
    let banDau: String
    /// Trả `nil` khi lưu xong; khác ⇒ câu lỗi (giữ bản nháp).
    let luu: (String) async -> String?
    @Environment(\.dismiss) private var dong
    @StateObject private var boSoan = CTWBoSoan()
    @State private var chu = ""
    @State private var daNap = false
    @State private var xemTruoc = false
    @State private var dangLuu = false
    @State private var loi: String?
    @State private var hoiBo = false

    private var daSua: Bool { CTWMoTaThe.chuan(chu) != CTWMoTaThe.chuan(banDau) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let loi {
                    CTWErrorBanner(text: loi) { self.loi = nil }.padding(.horizontal, 12).padding(.top, 8)
                }
                Picker("Mode", selection: $xemTruoc) {
                    Text("Write").tag(false)
                    Text("Preview").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 12).padding(.vertical, 8)
                if xemTruoc {
                    ScrollView {
                        let k = CTWTipTap.khoi(CTWMoTaThe.doc(chu).nut)
                        Group {
                            if k.isEmpty {
                                Text("Nothing to preview").font(.ctw(size: 14)).foregroundColor(AppColors.textTertiary)
                            } else {
                                CTWKhoiView(khoi: k, coChu: 15)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    #if os(iOS)
                    CTWOSoanTaiLieu(chu: $chu, boSoan: boSoan, coChu: 16)
                        .accessibilityLabel(Text("Description (Markdown)"))
                    CTWThanhDinhDang(boSoan: boSoan)
                    #else
                    TextEditor(text: $chu).font(.body).padding(8)
                    #endif
                }
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Edit description")
            .ctwTieuDeNho()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if daSua { hoiBo = true } else { dong() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if dangLuu { ProgressView() } else {
                        Button("Save") {
                            Task {
                                dangLuu = true
                                if let l = await luu(chu) { loi = l } else { dong() }
                                dangLuu = false
                            }
                        }
                        .fontWeight(.semibold)
                        .disabled(!daSua && loi == nil)
                    }
                }
            }
            .confirmationDialog("Discard your changes?", isPresented: $hoiBo, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { dong() }
                Button("Keep editing", role: .cancel) {}
            }
            .onAppear { if !daNap { chu = banDau; daNap = true } }
        }
        .interactiveDismissDisabled(daSua)
    }
}

extension CTWMoTaThe {
    /// So "đã sửa chưa" bỏ qua khoảng trắng cuối dòng/cuối tệp.
    static func chuan(_ s: String) -> String {
        s.replacingOccurrences(of: "\r", with: "")
            .components(separatedBy: "\n").map { $0.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression) }
            .joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
