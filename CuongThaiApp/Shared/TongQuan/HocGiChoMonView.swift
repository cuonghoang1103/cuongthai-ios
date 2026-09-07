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
    @ObservedObject var vm: TongQuanVM
    @Environment(\.dismiss) private var dismiss

    @State private var de: [DeThi] = []
    @State private var khoa: [Course] = []
    /// Giáo trình của khoá đầu tiên khớp mã môn — dùng cho cả gia sư AI theo
    /// bài lẫn kế hoạch học trước.
    @State private var chuong: [CourseSection] = []
    @State private var dangTai = true
    /// Hỏng khi nạp. Phải HIỆN RA: `try?` nuốt lỗi thì màn trống trông y hệt
    /// "môn này không có nội dung", và người dùng tin vào một câu sai.
    @State private var loiNap: String?

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

    /// Mọi bài học của khoá, phẳng theo đúng thứ tự chương → bài.
    private var baiHoc: [CourseLesson] {
        chuong.sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
              .flatMap { ($0.lessons ?? []).sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) } }
    }

    var body: some View {
        NavigationStack {
            List {
                if dangTai {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else {
                    if !baiHoc.isEmpty {
                        Section {
                            NavigationLink {
                                KeHoachHocTruocView(mon: mon, khoa: khoa.first, bai: baiHoc, vm: vm)
                            } label: {
                                Label(T("Lập kế hoạch học trước"), systemImage: "calendar.badge.clock")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                        } footer: {
                            Text(String(format: T("Trên lớp môn này dạy 2 buổi/tuần trong 10 tuần. Học trước là nén %d bài của Academy vào ít tuần hơn để lên lớp đã biết trước."), baiHoc.count))
                        }
                    }

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

                    if let e = loiNap {
                        Section {
                            Label(e, systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 13)).foregroundColor(AppColors.error)
                        } header: {
                            Text(T("KHÔNG TẢI ĐƯỢC"))
                        }
                    }

                    if de.isEmpty && khoa.isEmpty && loiNap == nil {
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

                    // ⛔⛔ KHÔNG đẩy sang chat AI chung để "kiểm tra bài".
                    //
                    // Đo thật: hỏi "kiểm tra mình về JPD123" thì chat chung
                    // ĐOÁN BỪA — nó hỏi "định nghĩa của biến là gì?" cho một
                    // môn TIẾNG NHẬT, rồi lượt sau thú nhận không biết môn đó
                    // là gì và kèm mấy đường dẫn luật (law.justia.com) do tìm
                    // web vớ vẩn. Chat chung không có nội dung bài; bắt nó
                    // kiểm tra là mời nó bịa.
                    //
                    // App đã có GIA SƯ THEO BÀI (`GiaSuBaiHocView` +
                    // `courseTutor.service.ts`) đọc đúng nội dung bài học.
                    // Đường đúng là chọn BÀI rồi hỏi, nên phần này chỉ hiện
                    // khi thật sự có giáo trình.
                    if !baiHoc.isEmpty {
                        Section {
                            ForEach(baiHoc.prefix(12)) { b in
                                NavigationLink {
                                    GiaSuBaiHocView(lessonId: b.id, tenBai: b.title, tenMon: mon)
                                } label: {
                                    HStack(spacing: Spacing.sm) {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 12)).foregroundColor(AppColors.primary)
                                        Text(b.title).font(.system(size: 14)).lineLimit(2)
                                            .foregroundColor(AppColors.textPrimary)
                                    }
                                }
                            }
                        } header: {
                            Text(T("HỎI AI THEO TỪNG BÀI"))
                        } footer: {
                            Text(T("Gia sư đọc đúng nội dung bài đó rồi mới hỏi. Tự trả lời ghi nhớ tốt hơn đọc lại."))
                        }
                    } else if loiNap == nil {
                        Section {
                            Label(T("Chưa có bài học nào trong Academy cho môn này"),
                                  systemImage: "questionmark.circle")
                                .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                        } footer: {
                            // Nói THẲNG vì sao không có nút hỏi AI ở đây, thay
                            // vì lặng lẽ giấu đi.
                            Text(T("Gia sư AI cần nội dung bài để hỏi đúng trọng tâm. Không có bài thì chat chung sẽ đoán bừa — nên ở đây không mở đường đó."))
                        }
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
        // HAI cái bẫy chồng nhau, cùng cho ra một màn hình trống trông rất
        // thuyết phục:
        //
        // 1. `page: 1`, KHÔNG phải 0 — máy chủ tính `skip = (page-1)*size`,
        //    nên `page: 0` ra skip ÂM ⇒ Prisma ném ⇒ HTTP 500.
        // 2. Phải là `getCoursesAcademy`, KHÔNG phải `getCourses` — máy chủ
        //    đặt `where.semesterId = academy ? { not: null } : null`, tức
        //    không truyền cờ thì nó trả về đúng những khoá KHÔNG thuộc
        //    Academy. Môn theo học kỳ nằm hết ở rổ kia.
        //
        // Cả hai lần đều ra "Chưa có bài học nào trong Academy cho môn này" —
        // một câu SAI mà tôi còn viết chú thích tự tin cho nó. Người dùng phải
        // chỉ ra "trên web có rồi mà" thì mới lộ.
        // ⚠️ Giải mã thẳng thành MẢNG. `/courses` trả `data` là mảng khoá
        // học, KHÔNG phải `{ items: [...] }` — khai một vỏ có `items` thì
        // JSONDecoder ném, `try?` nuốt, và ta lại được một màn hình trống.
        async let dsKhoa: [Course]? = try? await APIClient.shared.request(
            .getCoursesAcademy(page: 1, size: 50, keyword: ma))
        // Mới nhất trước: 50 đề trải nhiều kỳ, đề của kỳ gần đây sát chương
        // trình đang học hơn đề từ 2023.
        de = ((await dsDe) ?? [])
            .filter { $0.course?.courseCode?.uppercased() == ma }
            .sorted { $0.id > $1.id }
        // Máy chủ đã lọc theo từ khoá (khớp title/mô tả/mã). Ưu tiên khớp
        // ĐÚNG mã; không có thì nhận cả kết quả máy chủ trả về — thà thừa một
        // khoá gần đúng còn hơn màn hình trống.
        let ds = (await dsKhoa) ?? []
        let dungMa = ds.filter { $0.courseCode?.uppercased() == ma }
        khoa = dungMa.isEmpty ? ds : dungMa
        // Giáo trình của khoá khớp đầu tiên. Cần nó để hỏi AI ĐÚNG BÀI.
        // `requestList` trả bộ ba (items, nextCursor, hasMore) chứ không trả
        // thẳng mảng — lấy đúng phần `items`.
        if let k = khoa.first {
            do {
                let ds: (items: [CourseSection], nextCursor: Int?, hasMore: Bool) =
                    try await APIClient.shared.requestList(.getCurriculum(courseId: k.id))
                chuong = ds.items
            } catch {
                loiNap = error.localizedDescription
            }
        }
    }
}

