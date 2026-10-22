import SwiftUI

// ════════════════════════════════════════════════════════════════
// TRƯỚC KHI VÀO THI — bản iOS của màn "intro" trong `ExamRoomClient.tsx`
//
// Gọi `GET /exams/:id/take` NGAY ở đây (web cũng vậy) để có: loại đề (FE/PE),
// hướng dẫn, tệp "Given", và `my` (lần trước, cao nhất, lượt đang dở). Đề tải
// xong được chuyển thẳng vào màn làm bài — không tải hai lần.
// ════════════════════════════════════════════════════════════════

struct ChiTietDeView: View {
    @Environment(\.ngonNguDe) private var ngonNgu
    let de: DeThi
    /// Dòng "Môn · Kỳ" khi nơi gọi biết rõ hơn chính `de`.
    ///
    /// ⚠️ Mở từ màn ĐÃ LƯU thì `de` là `bookmark.exam`, mà bản đó KHÔNG mang
    /// `course`/`semester` — để mặc thì dòng này hiện "Khác". Nơi gọi truyền hộ.
    var moTaMon: String?

    @State private var chiTiet: DeDangLam?
    @State private var dangTai = false
    @State private var loi: String?
    @State private var vao: CheDoVao?
    /// `nil` = chưa biết (đang hỏi máy chủ). Không đoán `false` rồi vẽ nút
    /// rỗng: bấm vào lúc đó là GỠ mất dấu trang người dùng đã lưu từ web.
    @State private var daLuu: Bool?
    @State private var moHuongDan = false

    enum CheDoVao: String, Identifiable { case thi, onTap; var id: String { rawValue } }

    private var my: ThongKeDeCuaToi? { chiTiet?.my ?? de.my }
    private var laPE: Bool { chiTiet?.laPE ?? de.laPE }
    private var loaiPE: String? { chiTiet?.loaiPE ?? de.loaiPE }
    private var soCau: Int { chiTiet?.questions.count ?? de.soCau }
    private var nguon: String { (chiTiet?.source ?? de.source ?? "").uppercased() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                dau
                luoiSo
                if let m = my, m.soLan > 0 || m.inProgressId != nil || m.aiInProgressId != nil { theCuaToi(m) }
                giaiThich
                if let u = chiTiet?.attachmentUrl ?? de.attachmentUrl, !u.isEmpty {
                    TepDinhKemDe(duong: u, ten: chiTiet?.attachmentName ?? de.attachmentName)
                }
                if let h = chiTiet?.instructions, !h.isEmpty { huongDan(h) }
                if let l = loi { Label(l, systemImage: "exclamationmark.triangle").font(.footnote).foregroundColor(AppColors.warning) }
                nutVao
                if let slug = de.course?.slug, !slug.isEmpty {
                    NavigationLink {
                        DeThiTheoMonView(khoaHoc: slug, ten: de.course?.title ?? de.tenKhoa, maMon: de.course?.courseCode)
                    } label: {
                        Label(T("Các đề khác của môn") + " " + (de.course?.courseCode ?? ""), systemImage: "square.stack.3d.up")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Spacing.md)
                            .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.backgroundCard))
                    }
                    .buttonStyle(.nhan)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(de.code ?? T("Đề thi"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { nutLuu } }
        .task { await taiChiTiet(); await hoiDaLuu() }
        .refreshable { await taiChiTiet() }
        .fullScreenCover(item: $vao, onDismiss: { Task { await taiChiTiet() } }) { v in
            LamBaiView(de: de, coAI: v == .onTap, deSan: chiTiet)
        }
    }

    // ── Đầu trang ───────────────────────────────────────────────
    private var dau: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                NhanLoaiVaKy(de: de, coChu: 12)
            }
            HStack(spacing: 6) {
                if laPE, let p = loaiPE {
                    the(nhanLoaiPE(p), AppColors.accent)
                }
                if nguon == "REAL" { the(T("Đề thật"), AppColors.success) }
                else if nguon == "SAMPLE" { the(T("Đề mẫu"), AppColors.textTertiary) }
                else if !nguon.isEmpty { the(chiTiet?.source ?? de.source ?? "", AppColors.info) }
            }
            Text(de.ten(ngonNgu))
                .font(.title3.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            // Dòng phụ là nửa còn lại — thấy cả hai tên giúp đối chiếu với đề giấy.
            if let phu = de.tenPhu(ngonNgu) {
                Text(phu).font(.footnote).foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            let dongMon = moTaMon ?? [de.tenKhoa, de.tenKy].filter { !$0.isEmpty && $0 != "Khác" }.joined(separator: " · ")
            if !dongMon.isEmpty {
                Text(dongMon.tachSongNgu(ngonNgu)).font(.footnote).foregroundColor(AppColors.textTertiary)
            }
            if let m = chiTiet?.description ?? de.description, !m.isEmpty {
                Text(m.tachSongNgu(ngonNgu)).font(.subheadline).foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func the(_ chu: String, _ mau: Color) -> some View {
        Text(chu).font(.caption2.weight(.bold)).foregroundColor(mau)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(mau.opacity(0.12)))
    }

    private func nhanLoaiPE(_ p: String) -> String {
        switch p {
        case "CODE": return T("PE · Lập trình")
        case "WRITE": return T("PE · Tự luận")
        case "SPEAK": return T("PE · Vấn đáp")
        default: return "PE · \(p)"
        }
    }

    private var luoiSo: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
            o(T("Số câu"), dangTai && chiTiet == nil ? "…" : "\(soCau)", "list.number")
            o(T("Thời gian"), String(format: T("%d phút"), chiTiet?.durationMinutes ?? de.phut), "clock")
            o(T("Tổng điểm"), nz(chiTiet?.totalPoints ?? de.totalPoints), "star")
            o(T("Điểm đạt"), "≥ " + nz(chiTiet?.passMark ?? de.passMark), "checkmark.seal")
        }
    }

    private func theCuaToi(_ m: ThongKeDeCuaToi) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(T("Kết quả của bạn")).font(.footnote.weight(.semibold)).foregroundColor(AppColors.textSecondary)
            HStack(spacing: Spacing.md) {
                soNho("\(m.soLan)", T("lần thi"))
                soNho(m.bestScore.map(DinhDangSo.gon) ?? "—", T("cao nhất"))
                soNho(m.lastScore.map(DinhDangSo.gon) ?? "—", T("gần nhất"))
                if m.daDat {
                    Label(T("Đã đạt"), systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.bold)).foregroundColor(AppColors.success)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: Spacing.md) {
                if let a = m.lastAttemptId {
                    NavigationLink { NapXemLaiView(attemptId: a, tieuDe: de.title) } label: {
                        Label(T("Xem lại lần gần nhất"), systemImage: "list.bullet.rectangle.portrait")
                            .font(.footnote.weight(.semibold))
                    }
                }
                NavigationLink { LichSuThiView(examId: de.id, tieuDe: de.ten(ngonNgu)) } label: {
                    Label(T("Lịch sử đề này"), systemImage: "clock.arrow.circlepath")
                        .font(.footnote.weight(.semibold))
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.backgroundCard))
    }

    private func soNho(_ so: String, _ nhan: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(so).font(.system(.title3, design: .rounded).weight(.bold)).foregroundColor(AppColors.textPrimary)
            Text(nhan).font(.caption2).foregroundColor(AppColors.textTertiary)
        }
    }

    private var giaiThich: some View {
        Label {
            Text(cauGiaiThich).font(.footnote).foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "info.circle").foregroundColor(AppColors.primary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.primary.opacity(0.07)))
    }

    /// Đúng các câu giải thích của web, theo loại đề.
    private var cauGiaiThich: String {
        if !laPE {
            if chiTiet?.toanCode == true {
                return T("Đề gồm toàn câu lập trình. Bạn gõ code ngay trong phòng thi cho từng câu, AI chấm theo tiêu chí. Đồng hồ chạy ngay khi bắt đầu và tự nộp khi hết giờ.")
            }
            if chiTiet?.coCauCode == true {
                return T("Đề gồm câu trắc nghiệm và câu lập trình. Câu trắc nghiệm chấm tự động, câu lập trình bạn gõ code ngay trong phòng thi và AI chấm theo tiêu chí. Đồng hồ chạy ngay khi bắt đầu và tự nộp khi hết giờ.")
            }
            return T("Chọn đáp án cho từng câu. Có câu chọn nhiều đáp án. Đồng hồ chạy ngay khi bắt đầu và tự nộp khi hết giờ. Thoát ra vào lại vẫn làm tiếp được.")
        }
        switch loaiPE {
        case "CODE": return T("Gõ code cho từng câu ngay trong app (tự đóng gói Q1, Q2… thành .zip), hoặc làm ở máy tính rồi nộp một tệp .zip. AI chấm từng câu theo đề và đáp án mẫu.")
        case "WRITE": return T("Viết câu trả lời bằng TIẾNG ANH ngay trong phòng thi; câu vẽ sơ đồ thì chụp/chọn ảnh sơ đồ. AI chấm theo tiêu chí.")
        case "SPEAK": return T("Đề nói: thu âm câu trả lời cho từng câu hỏi. AI nghe, chấm nội dung và phát âm.")
        default: return T("Đọc kỹ hướng dẫn trước khi bắt đầu.")
        }
    }

    private func huongDan(_ h: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { moHuongDan.toggle() } } label: {
                HStack {
                    Label(T("Hướng dẫn làm bài"), systemImage: "doc.text")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: moHuongDan ? "chevron.up" : "chevron.down").font(.caption.weight(.semibold))
                }
                .foregroundColor(AppColors.textPrimary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if moHuongDan {
                NoiDungThi(chu: h, coChu: 15)
            }
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.backgroundCard))
        .onAppear { if laPE { moHuongDan = true } }
    }

    private var nutVao: some View {
        VStack(spacing: Spacing.sm) {
            Button { vao = .thi } label: {
                Label(my?.inProgressId != nil ? T("Tiếp tục bài thi") : T("Bắt đầu làm bài"),
                      systemImage: my?.inProgressId != nil ? "play.fill" : "timer")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Capsule().fill(AppColors.primary))
            }
            .buttonStyle(.nhan)

            // Lượt RIÊNG, tách hẳn khỏi lượt thi thật: máy chủ lọc
            // `where: { …, aiAssisted }` nên KHÔNG nối nhầm vào bài đang chạy đồng hồ.
            Button { vao = .onTap } label: {
                Label(my?.aiInProgressId != nil ? T("Tiếp tục ôn tập với CuongMini")
                      : (laPE ? T("Luyện không tính giờ") : T("Thi cùng CuongMini")),
                      systemImage: "sparkles")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Capsule().fill(
                        LinearGradient(colors: [AppColors.primary, AppColors.primaryDark],
                                       startPoint: .leading, endPoint: .trailing)))
            }
            .buttonStyle(.nhan)

            Text(laPE
                 ? T("Phòng luyện — KHÔNG tính giờ, không ảnh hưởng điểm thi thật.")
                 : T("Phòng ôn tập — KHÔNG tính giờ. Làm từng câu, hỏi AI về đúng câu đang mở, xem đáp án và bình luận thoải mái."))
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
    }

    // ── Mạng ────────────────────────────────────────────────────
    private func taiChiTiet() async {
        dangTai = true; defer { dangTai = false }
        do {
            chiTiet = try await APIClient.shared.request(.deDangLam(examId: de.id))
            loi = nil
        } catch {
            // Không chặn nút vào thi: màn làm bài tự tải lại và báo lỗi thật.
            if chiTiet == nil { loi = error.localizedDescription }
        }
    }

    // ⚠️ `POST /exams/:id/bookmark` là LẬT trạng thái, không phải "đặt", nên
    // phải biết trạng thái hiện tại trước khi cho bấm.
    @ViewBuilder
    private var nutLuu: some View {
        if let co = daLuu {
            Button { Task { await lat(dangCo: co) } } label: {
                Image(systemName: co ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(co ? AppColors.accent : AppColors.textSecondary)
            }
            .accessibilityLabel(co ? T("Bỏ lưu đề") : T("Lưu đề"))
        } else {
            ProgressView().controlSize(.small)
        }
    }

    private func hoiDaLuu() async {
        guard daLuu == nil else { return }
        let ds: [DeDaLuu]? = try? await APIClient.shared.request(.dsDeDaLuu)
        daLuu = ds?.contains { $0.examId == de.id } ?? false
    }

    private func lat(dangCo: Bool) async {
        struct R: Codable { let bookmarked: Bool }
        daLuu = !dangCo
        Haptics.cham()
        do {
            let r: R = try await APIClient.shared.request(.danhDauDeThi(examId: de.id))
            daLuu = r.bookmarked
        } catch { daLuu = dangCo }
    }

    private func nz(_ v: Double?) -> String { v.map(DinhDangSo.gon) ?? "—" }

    private func o(_ ten: String, _ giaTri: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.caption2).foregroundColor(AppColors.primary)
                Text(ten).font(.caption2).foregroundColor(AppColors.textTertiary)
            }
            Text(giaTri).font(.headline).foregroundColor(AppColors.textPrimary).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.backgroundCard))
        .accessibilityElement(children: .combine)
    }
}
