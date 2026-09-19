import SwiftUI

// ════════════════════════════════════════════════════════════════
// TẢI MỘT MÔN VỀ ĐỂ HỌC NGOẠI TUYẾN
//
// Gọi đúng những endpoint mà màn học sẽ gọi, rồi GHIM kết quả. Nhờ vậy khi
// mất mạng, màn học đi đường bình thường và tầng `perform` lặng lẽ trả bản
// đã lưu — không màn nào cần biết chuyện gì đang xảy ra.
//
// ⚠️ Phải tải ĐÚNG endpoint màn học dùng, kể cả query. Tải `/curriculum`
// rồi tưởng là xong thì mở ngoại tuyến vẫn trắng, vì màn bài học gọi
// `/courses/:id/lessons/:id` — một khoá khác hẳn.
// ════════════════════════════════════════════════════════════════

@MainActor
final class TaiVeHoc: ObservableObject {
    static let chung = TaiVeHoc()

    @Published var dangTai: Int?          // id khoá đang tải
    @Published var xong = 0
    @Published var tong = 0
    @Published var loi: String?

    var tiLe: Double { tong > 0 ? Double(xong) / Double(tong) : 0 }

    func taiKhoa(id: Int, slug: String, ten: String) async {
        guard dangTai == nil else { return }
        dangTai = id; xong = 0; tong = 1; loi = nil
        defer { dangTai = nil }

        do {
            // 1. Chi tiết khoá + giáo trình.
            _ = try await ghim(.getCourseDetail(slug: slug), mon: ten)
            let ctData = try await ghim(.getCurriculum(courseId: id), mon: ten)
            xong = 1

            // 2. Mọi bài trong giáo trình.
            let baiIds = docIdBai(ctData)
            tong = 2 + baiIds.count
            xong = 2
            for b in baiIds {
                _ = try? await ghim(.getLesson(courseId: id, lessonId: b), mon: ten)
                xong += 1
            }
            xong = tong
        } catch {
            loi = error.localizedDescription
        }
    }

    @discardableResult
    private func ghim(_ e: APIEndpoint, mon: String) async throws -> Data {
        let d = try await APIClient.shared.requestRaw(e)
        var khoa = e.path
        if let q = e.queryParams, !q.isEmpty {
            khoa += "?" + q.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "&")
        }
        await KhoNgoaiTuyen.chung.ghi(d, khoa: khoa, ghim: true, mon: mon)
        return d
    }

    /// Bới id bài ra khỏi JSON giáo trình mà KHÔNG khai một struct.
    ///
    /// Hình dạng giáo trình đổi theo loại khoá (chương→bài, hoặc phẳng), và
    /// một struct cứng là thứ sẽ vỡ im lặng vào ngày backend thêm một tầng.
    /// Ở đây chỉ cần đúng một thứ: danh sách id.
    private func docIdBai(_ d: Data) -> [Int] {
        guard let o = try? JSONSerialization.jsonObject(with: d) else { return [] }
        var ids: [Int] = []
        func di(_ x: Any, trongBai: Bool) {
            if let m = x as? [String: Any] {
                if trongBai, let i = m["id"] as? Int { ids.append(i) }
                for (k, v) in m { di(v, trongBai: k == "lessons") }
            } else if let a = x as? [Any] {
                for v in a { di(v, trongBai: trongBai) }
            }
        }
        di(o, trongBai: false)
        return Array(Set(ids))
    }
}

// MARK: - Nút tải về

struct NutTaiVeHoc: View {
    let id: Int
    let slug: String
    let ten: String

    @ObservedObject private var tai = TaiVeHoc.chung
    @State private var daTai = false

    private var dangTaiCaiNay: Bool { tai.dangTai == id }

    var body: some View {
        Button {
            Task {
                if daTai {
                    await KhoNgoaiTuyen.chung.xoaMon(ten)
                    daTai = false
                } else {
                    await tai.taiKhoa(id: id, slug: slug, ten: ten)
                    daTai = await KhoNgoaiTuyen.chung.monDaTai()[ten] != nil
                }
            }
        } label: {
            if dangTaiCaiNay {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.7)
                    Text("\(tai.xong)/\(max(tai.tong, 1))")
                        .font(.caption).monospacedDigit()
                }
            } else {
                Image(systemName: daTai ? "checkmark.circle.fill" : "arrow.down.circle")
                    .foregroundStyle(daTai ? AppColors.success : AppColors.primary)
            }
        }
        .disabled(tai.dangTai != nil && !dangTaiCaiNay)
        .accessibilityLabel(daTai ? T("Xoá bản tải về") : T("Tải về để học khi mất mạng"))
        .task { daTai = await KhoNgoaiTuyen.chung.monDaTai()[ten] != nil }
    }
}

// MARK: - Dải báo đang dùng bản đã lưu

/// ⚠️ Phải NÓI RA. Hiện nội dung cũ mà im lặng là kiểu làm người dùng tin
/// vào một con số đã lỗi thời — tệ hơn hẳn màn trắng, vì màn trắng thì họ
/// biết là đang hỏng.
struct DaiNgoaiTuyen: View {
    @ObservedObject private var mang = TrangThaiMang.chung

    var body: some View {
        if mang.dangDungBanLuu {
            HStack(spacing: 6) {
                Image(systemName: "wifi.slash").font(.caption)
                Text(T("Đang xem bản đã tải — không có mạng"))
                    .font(.caption)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 6)
            .background(AppColors.warning.opacity(0.15))
            .foregroundStyle(AppColors.warning)
        }
    }
}
