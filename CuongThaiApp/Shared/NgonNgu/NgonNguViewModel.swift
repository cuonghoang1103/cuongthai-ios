import Foundation
import SwiftUI

@MainActor
final class NgonNguVM: ObservableObject {
    @Published var dsNgonNgu: [NgonNgu] = []
    @Published var dangTai = false
    @Published var loi: String?

    func tai() async {
        dangTai = true; defer { dangTai = false }
        do {
            let ds: [NgonNgu] = try await APIClient.shared.request(.dsNgonNgu)
            // Chỉ giữ ngôn ngữ CÓ nội dung — xem ghi chú `coNoiDung`.
            dsNgonNgu = ds.filter { $0.coNoiDung }
                          .sorted { ($0.order ?? 99) < ($1.order ?? 99) }
            loi = dsNgonNgu.isEmpty ? "Chưa có ngôn ngữ nào sẵn sàng." : nil
        } catch {
            loi = error.localizedDescription
        }
    }
}

@MainActor
final class ChuDeVM: ObservableObject {
    @Published var tatCa: [ChuDeTu] = []
    @Published var cap: String?
    @Published var dangTai = false
    @Published var loi: String?

    /// Các cấp có thật, theo thứ tự học chứ không theo bảng chữ cái.
    ///
    /// ⚠️ Sắp bằng `sorted()` thường thì tiếng Anh ra A1,A2,B1… (may mắn
    /// đúng) nhưng tiếng Nhật ra N1,N2,N3,N4,N5 — tức là **ngược hẳn**:
    /// N5 là vỡ lòng, N1 là cao nhất. Người mới học mở ra thấy N1 đầu bảng.
    var dsCap: [String] {
        let co = Set(tatCa.compactMap { $0.level })
        let thuTu = ["N5","N4","N3","N2","N1",
                     "A1","A2","B1","B2","C1","C2",
                     "HSK1","HSK2","HSK3","HSK4","HSK5","HSK6"]
        var ra = thuTu.filter { co.contains($0) }
        ra.append(contentsOf: co.subtracting(ra).sorted())
        return ra
    }

    var hienThi: [ChuDeTu] {
        let ds = cap == nil ? tatCa : tatCa.filter { $0.level == cap }
        return ds.filter { $0.soTu > 0 }
                 .sorted { ($0.order ?? 0, $0.id) < ($1.order ?? 0, $1.id) }
    }

    func tai(_ code: String) async {
        dangTai = true; defer { dangTai = false }
        do {
            tatCa = try await APIClient.shared.request(.chuDeTu(code: code))
            // Mặc định mở ở cấp THẤP NHẤT. Để trống thì người dùng phải cuộn
            // qua 278 chủ đề trộn lẫn mọi trình độ.
            if cap == nil { cap = dsCap.first }
            loi = nil
        } catch { loi = error.localizedDescription }
    }
}

@MainActor
final class TuNgoaiNguVM: ObservableObject {
    @Published var tu: [TuNgoaiNgu] = []
    @Published var dangTai = false
    @Published var conNua = true
    @Published var loi: String?
    @Published var yeuThich: Set<Int> = []

    private var trang = 1
    private let code: String
    private let categoryId: Int?

    init(code: String, categoryId: Int?) {
        self.code = code
        self.categoryId = categoryId
    }

    func tai(lai: Bool = false) async {
        if dangTai { return }
        if lai { trang = 1; conNua = true; tu = [] }
        guard conNua else { return }
        dangTai = true; defer { dangTai = false }
        do {
            let (ds, _, conTiep): ([TuNgoaiNgu], Int?, Bool) = try await APIClient.shared
                .requestList(.tuVung(code: code, categoryId: categoryId, page: trang, limit: 50))
            tu.append(contentsOf: ds)
            conNua = conTiep
            trang += 1
            loi = nil
        } catch { loi = error.localizedDescription; conNua = false }
    }

    func taiYeuThich() async {
        // Không có thì thôi — trái tim rỗng vẫn dùng được, không đáng báo lỗi
        // chắn ngang màn hình.
        if let ids: [Int] = try? await APIClient.shared.request(.idYeuThich(code: code)) {
            yeuThich = Set(ids)
        }
    }

    func doiYeuThich(_ w: TuNgoaiNgu) async {
        // Đổi giao diện TRƯỚC rồi mới gọi mạng: trái tim phải đỏ ngay lúc
        // chạm. Hỏng thì trả lại như cũ.
        let coTruoc = yeuThich.contains(w.id)
        if coTruoc { yeuThich.remove(w.id) } else { yeuThich.insert(w.id) }
        Haptics.cham()
        do {
            _ = try await APIClient.shared.send(.doiYeuThich(wordId: w.id))
        } catch {
            if coTruoc { yeuThich.insert(w.id) } else { yeuThich.remove(w.id) }
            loi = "Không lưu được vào Yêu thích."
        }
    }
}

@MainActor
final class OnTapVM: ObservableObject {
    @Published var hang: [MucOnTap] = []
    @Published var viTri = 0
    @Published var lat = false
    @Published var dangTai = false
    @Published var loi: String?
    @Published var xong = false
    @Published var daHoc = 0

    let code: String
    init(code: String) { self.code = code }

    var hienTai: MucOnTap? { viTri < hang.count ? hang[viTri] : nil }

    func tai() async {
        dangTai = true; defer { dangTai = false }
        do {
            let hd: HangDoiOnTap = try await APIClient.shared.request(.hangDoiOnTap(code: code))
            // Mục không phải từ vựng (ngữ pháp, hội thoại…) máy chủ trả kèm
            // nhưng `word` là nil — chặng này chưa dựng màn cho chúng, hiện
            // ra sẽ là thẻ trống.
            hang = hd.items.filter { $0.word != nil }
            xong = hang.isEmpty
            loi = nil
        } catch { loi = error.localizedDescription }
    }

    func cham(_ m: MucNho) async {
        guard let muc = hienTai else { return }
        Haptics.cham()
        // Gửi đi KHÔNG chờ: người học đã sang thẻ sau rồi, bắt họ đợi mạng
        // giữa hai thẻ là hỏng nhịp ôn tập.
        Task { _ = try? await APIClient.shared.send(.ghiTienDo(itemId: muc.progress.itemId,
                                                              quality: m.rawValue)) }
        daHoc += 1
        withAnimation(.easeInOut(duration: 0.18)) { lat = false }
        if viTri + 1 < hang.count {
            viTri += 1
        } else {
            xong = true
        }
    }
}
