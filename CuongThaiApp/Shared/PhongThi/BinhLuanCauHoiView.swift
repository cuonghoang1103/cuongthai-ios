import SwiftUI
import Kingfisher

// ════════════════════════════════════════════════════════════════
// BÌNH LUẬN THEO CÂU HỎI
//
// Bản iOS của `ExamQuestionComments.tsx`. Mở cho MỌI tài khoản — không cần
// Pro, khác hẳn khung chat CuongMini.
//
// ⚠️ Chỉ hiện trong phòng CuongMini (`aiAssisted`), KHÔNG hiện trong lượt thi
// thật. Web cũng vậy (`{exam.kind === 'FE' && aiAssisted && …}`): phòng ôn
// tập thì bàn bạc thoải mái, còn lượt thi tính điểm mà mở sẵn lời giải của
// người khác ngay dưới câu hỏi thì không còn là thi nữa.
//
// Bình luận `isAi = true` là câu CuongMini tự đăng lại sau khi trả lời trong
// khung chat — nó BỀN qua mọi lần deploy, nên người vào sau đọc được lời giải
// mà không tốn thêm một lượt gọi AI nào.
// ════════════════════════════════════════════════════════════════

@MainActor
final class BinhLuanVM: ObservableObject {
    @Published var ds: [BinhLuanCauHoi] = []
    @Published var dangTai = false
    @Published var dangGui = false
    @Published var loi: String?
    @Published var daMo = false

    let questionId: Int
    private var daNap = false

    init(questionId: Int) { self.questionId = questionId }

    var tong: Int { BinhLuanCauHoi.dem(ds) }

    /// Chỉ gọi mạng khi người dùng MỞ khung ra — đúng như web. Một đề 60 câu
    /// mà câu nào cũng tự tải bình luận là 60 lời gọi cho thứ phần lớn không
    /// ai mở.
    func nap(batBuoc: Bool = false) async {
        if daNap && !batBuoc { return }
        daNap = true
        dangTai = true; defer { dangTai = false }
        do {
            ds = try await APIClient.shared.request(.dsBinhLuanCauHoi(questionId: questionId))
            loi = nil
        } catch {
            loi = error.localizedDescription
        }
    }

    func gui(_ chu: String, traLoiId: Int? = nil) async -> Bool {
        let t = chu.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !dangGui else { return false }
        dangGui = true; defer { dangGui = false }
        do {
            _ = try await APIClient.shared.send(
                .themBinhLuanCauHoi(questionId: questionId, noiDung: t, traLoiId: traLoiId))
            // Nạp lại thay vì tự chèn: máy chủ mới biết `id` thật, thứ tự
            // thật và bình luận người khác vừa gửi.
            await nap(batBuoc: true)
            Haptics.xong()
            return true
        } catch {
            loi = error.localizedDescription
            return false
        }
    }

    func sua(_ id: Int, _ chu: String) async {
        let t = chu.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        do {
            _ = try await APIClient.shared.send(.suaBinhLuanCauHoi(id: id, noiDung: t))
            await nap(batBuoc: true)
        } catch { loi = error.localizedDescription }
    }

    func xoa(_ id: Int) async {
        do {
            _ = try await APIClient.shared.send(.xoaBinhLuanCauHoi(id: id))
            await nap(batBuoc: true)
        } catch { loi = error.localizedDescription }
    }
}

struct BinhLuanCauHoiView: View {
    @StateObject private var vm: BinhLuanVM
    @State private var nhap = ""
    @State private var traLoiCho: BinhLuanCauHoi?
    @State private var suaCho: BinhLuanCauHoi?
    @State private var chuSua = ""
    @FocusState private var dangGo: Bool

    /// Id người đang đăng nhập — để biết bình luận nào sửa/xoá được.
    let toiLa: Int?

    init(questionId: Int, toiLa: Int?) {
        self.toiLa = toiLa
        _vm = StateObject(wrappedValue: BinhLuanVM(questionId: questionId))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                vm.daMo.toggle()
                if vm.daMo { Task { await vm.nap() } }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 13))
                    Text(vm.daMo ? "Bình luận" : "Bình luận\(vm.tong > 0 ? " (\(vm.tong))" : "")")
                        .font(.system(size: 13.5, weight: .semibold))
                    Spacer()
                    Image(systemName: vm.daMo ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(AppColors.textSecondary)
                .padding(Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if vm.daMo {
                Divider().background(AppColors.divider)
                VStack(alignment: .leading, spacing: Spacing.md) {
                    oGo
                    if let l = vm.loi {
                        Text(l).font(.system(size: 12.5)).foregroundColor(AppColors.error)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if vm.dangTai && vm.ds.isEmpty {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if vm.ds.isEmpty {
                        Text("Chưa có bình luận nào cho câu này. Hãy là người đầu tiên!")
                            .font(.system(size: 13)).foregroundColor(AppColors.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        ForEach(vm.ds) { c in
                            moi(c, cap: 0)
                            ForEach(c.traLoi) { r in moi(r, cap: 1) }
                        }
                    }
                }
                .padding(Spacing.md)
            }
        }
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundCard)
            .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(AppColors.border, lineWidth: 1)))
        .alert("Sửa bình luận", isPresented: Binding(
            get: { suaCho != nil },
            set: { if !$0 { suaCho = nil } })) {
            TextField("Nội dung", text: $chuSua)
            Button("Huỷ", role: .cancel) { suaCho = nil }
            Button("Lưu") {
                if let c = suaCho { Task { await vm.sua(c.id, chuSua) } }
                suaCho = nil
            }
        }
    }

    // ── Ô gõ ────────────────────────────────────────────────────
    private var oGo: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let t = traLoiCho {
                HStack(spacing: 6) {
                    Image(systemName: "arrowshape.turn.up.left")
                        .font(.system(size: 10)).foregroundColor(AppColors.primary)
                    Text("Trả lời \(t.author?.ten ?? "bình luận")")
                        .font(.system(size: 11.5)).foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Button { traLoiCho = nil } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            HStack(alignment: .bottom, spacing: Spacing.sm) {
                TextField("Hỏi hoặc chia sẻ cách hiểu của bạn về câu này…",
                          text: $nhap, axis: .vertical)
                    .font(.system(size: 14))
                    .lineLimit(1...4)
                    .focused($dangGo)
                    .padding(.horizontal, Spacing.sm).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(AppColors.backgroundTertiary))
                Button {
                    let t = nhap
                    let cha = traLoiCho?.id
                    nhap = ""; traLoiCho = nil; dangGo = false
                    Task { if await vm.gui(t, traLoiId: cha) == false { nhap = t } }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(
                            nhap.trimmingCharacters(in: .whitespaces).isEmpty
                            ? AppColors.textTertiary : AppColors.primary))
                }
                .buttonStyle(.plain)
                .disabled(vm.dangGui || nhap.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Gửi bình luận")
            }
        }
    }

    // ── Một bình luận ───────────────────────────────────────────
    private func moi(_ c: BinhLuanCauHoi, cap: Int) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            anhDaiDien(c)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(c.laAI ? "CuongMini" : (c.author?.ten ?? "Người dùng"))
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(c.laAI ? AppColors.primary : AppColors.textPrimary)
                    if c.laAI {
                        Text("AI")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5).padding(.vertical, 1.5)
                            .background(Capsule().fill(AppColors.primary))
                    }
                    Text(c.luc)
                        .font(.system(size: 10.5)).foregroundColor(AppColors.textTertiary)
                    if c.daSua {
                        Text("· đã sửa")
                            .font(.system(size: 10.5)).foregroundColor(AppColors.textTertiary)
                    }
                    Spacer(minLength: 0)
                }

                // Bình luận của CuongMini là markdown (có công thức, có mã);
                // bình luận người thật thường là chữ thuần — nhưng cùng một
                // bộ dựng thì cả hai đều đúng, và người thật cũng gõ được
                // `**đậm**` hay khối mã.
                NoiDungMarkdown(noiDung: c.content)

                HStack(spacing: Spacing.md) {
                    if cap == 0 {
                        Button {
                            traLoiCho = c; dangGo = true
                        } label: {
                            Text("Trả lời")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    if let me = toiLa, c.author?.id == me {
                        Button {
                            chuSua = c.content; suaCho = c
                        } label: {
                            Text("Sửa").font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Button {
                            Task { await vm.xoa(c.id) }
                        } label: {
                            Text("Xoá").font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(AppColors.error)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.leading, cap == 1 ? Spacing.lg : 0)
    }

    private func anhDaiDien(_ c: BinhLuanCauHoi) -> some View {
        Group {
            if c.laAI {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(AppColors.primary))
            } else if let u = c.author?.avatarUrl, !u.isEmpty,
                      let url = URL(string: u.hasPrefix("http") ? u : APIClient.diaChiGoc + u) {
                KFImage(url).resizable().scaledToFill()
                    .frame(width: 30, height: 30).clipShape(Circle())
            } else {
                Text(String((c.author?.ten ?? "?").prefix(1)).uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(AppColors.textTertiary))
            }
        }
    }
}
