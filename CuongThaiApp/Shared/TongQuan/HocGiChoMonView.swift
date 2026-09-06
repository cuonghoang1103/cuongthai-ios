import SwiftUI

/// "Học gì cho <môn>" — biến một việc ôn thành hành động cụ thể.
///
/// Vì sao cần: việc "Ôn SWT301 — 20 phút" nói ĐÚNG thứ phải làm nhưng không
/// nói LÀM Ở ĐÂU. Người dùng bấm vào rồi ngồi nhìn, hoặc mở YouTube. Màn này
/// đưa thẳng ba đường: đề thi của chính môn đó, khoá học Academy của chính môn
/// đó, và hỏi AI.
///
/// ⚠️ Ghép theo MÃ MÔN, không theo tên. Tên khoá học là "Software Testing"
/// còn việc ghi "SWT301" — so tên thì không bao giờ khớp. Mã môn có ở cả hai
/// phía (`DeThi.course.courseCode`, `Course.courseCode`).
struct HocGiChoMonView: View {
    let mon: String
    @Environment(\.dismiss) private var dismiss

    @State private var de: [DeThi] = []
    @State private var khoa: [Course] = []
    @State private var dangTai = true

    /// Rút mã môn từ tiêu đề việc: "Ôn SWT301 — 20 phút" → "SWT301".
    ///
    /// Mã môn FPT là 3 chữ + 3 số, có khi thêm một chữ cuối (ITE302c). Bắt
    /// bằng biểu thức thay vì cắt chuỗi: tiêu đề còn có "Ôn lại", số phút,
    /// dấu gạch — cắt theo vị trí là hỏng ngay khi đổi câu chữ.
    static func maMon(tu tieuDe: String) -> String? {
        let r = try? NSRegularExpression(pattern: #"\b([A-Z]{2,4}\d{3}[a-z]?)\b"#)
        let ns = tieuDe as NSString
        guard let m = r?.firstMatch(in: tieuDe, range: NSRange(location: 0, length: ns.length))
        else { return nil }
        return ns.substring(with: m.range(at: 1))
    }

    var body: some View {
        NavigationStack {
            List {
                if dangTai {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else {
                    if !de.isEmpty {
                        Section {
                            ForEach(de.prefix(8)) { d in
                                NavigationLink { LamBaiView(de: d, coAI: true) } label: { hangDe(d) }
                            }
                        } header: {
                            Text(de.count > 8
                                 ? String(format: T("ĐỀ THI %@ — 8 ĐỀ MỚI NHẤT / %d"), mon, de.count)
                                 : String(format: T("ĐỀ THI %@ (%d)"), mon, de.count))
                        } footer: {
                            Text(T("Làm một đề là cách kiểm nhanh nhất xem mình còn hổng chỗ nào."))
                        }
                    }

                    if !khoa.isEmpty {
                        Section {
                            ForEach(khoa.prefix(5)) { k in
                                NavigationLink { CourseDetailView(slug: k.slug) } label: { hangKhoa(k) }
                            }
                        } header: {
                            Text(T("BÀI HỌC TRONG ACADEMY"))
                        }
                    }

                    if de.isEmpty && khoa.isEmpty {
                        Section {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(String(format: T("Chưa có nội dung nào gắn mã %@."), mon))
                                    .font(.system(size: 14)).foregroundColor(AppColors.textPrimary)
                                Text(T("Vẫn hỏi AI được — nó không cần môn phải có sẵn trong app."))
                                    .font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Section {
                        NavigationLink {
                            AIChatView(cauMoDau: String(
                                format: T("Mình vừa học môn %@ hôm nay. Hỏi mình 5 câu để kiểm tra xem mình nhớ được bao nhiêu, hỏi từng câu một."), mon))
                        } label: {
                            Label(T("Nhờ AI kiểm tra bài"), systemImage: "sparkles")
                        }
                    } footer: {
                        // Tự kiểm tra hiệu quả hơn đọc lại — nói ra để người
                        // dùng biết vì sao nút này đứng đây chứ không phải
                        // "tóm tắt bài giúp mình".
                        Text(T("Tự trả lời câu hỏi ghi nhớ tốt hơn đọc lại. Câu mở đầu đã đặt sẵn theo hướng đó."))
                    }
                }
            }
            .navigationTitle(mon)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Đóng")) { dismiss() } }
            }
            .task { await nap() }
        }
    }

    private func hangDe(_ d: DeThi) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // ⚠️ `d.title` là chuỗi SONG NGỮ ghép bằng "|||". Hiện thẳng thì
            // người dùng đọc thấy ba gạch đứng giữa câu — đo thật, 50 đề đều
            // hiện cả hai thứ tiếng. `ten(_:)` tách đúng theo ngôn ngữ đang xem.
            Text(d.ten(.viet)).font(.system(size: 14.5, weight: .medium))
                .foregroundColor(AppColors.textPrimary).lineLimit(2)
            Text([d.code, d.course?.title].compactMap { $0?.isEmpty == false ? $0 : nil }
                    .joined(separator: " · "))
                .font(.system(size: 11.5)).foregroundColor(AppColors.textTertiary)
        }
        .padding(.vertical, 2)
    }

    private func hangKhoa(_ k: Course) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k.title).font(.system(size: 14.5, weight: .medium))
                .foregroundColor(AppColors.textPrimary).lineLimit(2)
            if let s = k.semesterName, !s.isEmpty {
                Text(s).font(.system(size: 11.5)).foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private func nap() async {
        dangTai = true
        defer { dangTai = false }
        let ma = mon.uppercased()
        // Hai lời gọi song song: chờ tuần tự thì màn đứng im gấp đôi thời gian.
        async let dsDe: [DeThi]? = try? await APIClient.shared.request(.dsDeThi)
        // Lọc bằng chính mã môn ở phía máy chủ — tải cả danh sách khoá học
        // rồi lọc ở client là kéo về hàng trăm bản ghi để giữ lại một.
        async let dsKhoa: DanhSachKhoa? = try? await APIClient.shared.request(
            .getCourses(page: 0, size: 50, keyword: ma))
        // Mới nhất trước: 50 đề trải nhiều kỳ, đề của kỳ gần đây sát chương
        // trình đang học hơn đề từ 2023.
        de = ((await dsDe) ?? [])
            .filter { $0.course?.courseCode?.uppercased() == ma }
            .sorted { $0.id > $1.id }
        khoa = ((await dsKhoa)?.items ?? []).filter { $0.courseCode?.uppercased() == ma }
    }
}

/// Vỏ giải mã danh sách khoá học. `/courses` trả `{ items, total, … }`.
struct DanhSachKhoa: Codable { var items: [Course] }
