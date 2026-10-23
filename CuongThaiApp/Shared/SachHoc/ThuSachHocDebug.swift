#if DEBUG
import SwiftUI

/// Bàn soi khoá kiểu sách — chỉ bản DEBUG, không cần đăng nhập.
///
///     SIMCTL_CHILD_CT_SACHHOC_NGUON=~/Downloads/api-backend/frontend/public/sach-hoc \
///     SIMCTL_CHILD_CT_XEM_MAN=sachhoc-bai:b0-hiragana \
///     SIMCTL_CHILD_CT_SACHHOC_CUON=6 \
///     xcrun simctl launch <udid> com.cuongthai.app
///
/// `CT_SACHHOC_NGUON`: thư mục do `npm run sach-hoc:xuat` sinh (chưa deploy thì cuongthai.com chưa có).
/// Màn: `sachhoc` (mục lục) · `sachhoc-bai:<id bài>` (mở thẳng một bài; id = `?bai=` của web) ·
/// `sachhoc-viet` (màn Luyện viết; `CT_SACHHOC_CUON=<n>` cuộn tới Bài n) · `sachhoc-viet:<id khối write>` (một khối viết) ·
/// `sachhoc-nhat` (màn Tiếng Nhật có thẻ cửa vào) · `sachhoc-ielts` (màn IELTS có thẻ IELTS nền tảng).
/// `CT_SACHHOC_KHOA`: dekiru (mặc định) | ielts | jp | ch.
/// Đợt 2: `CT_SACHHOC_HAN=学` (mở thẻ chữ Hán) · `CT_SACHHOC_TRATU=1` (ô tra từ) · `CT_SACHHOC_ONTHE=<chế độ>`
/// (lat hoc tn go nghe ghep kt sai) · `CT_SACHHOC_DIEN=1` (điền sẵn bài tập / kết quả phát âm mẫu).
/// `CT_SACHHOC_CUON=<n>`: cuộn tới nhóm khối thứ n của bài.
/// Đo độ mượt: `CT_SACHHOC_DO=<pt/giây>` tự cuộn đều cả bài 3 lượt, ghi hitch vào `Documents/do-cuon.txt`
/// (DoCuonSH.swift) · `CT_SACHHOC_CHI=table,write` chỉ giữ các loại khối đó (quy hitch về từng loại).
struct ThuSachHocView: View {
    let man: String
    private var env: [String: String] { ProcessInfo.processInfo.environment }

    private var moTa: KhoaSachHocMoTa { .theoId(env["CT_SACHHOC_KHOA"] ?? "dekiru") }

    var body: some View {
        if man == "sachhoc-ielts" {
            IeltsView(coNganXepRieng: false)
        } else if man == "sachhoc-nhat" {
            NgonNguHomeView(ngonNgu: NgonNgu(id: 2, name: "Tiếng Nhật", nameEn: "Japanese", code: "ja",
                                            flagEmoji: "🇯🇵", order: 2, isActive: true, counts: nil))
        } else if man == "sachhoc-viet" {
            MucLucSachHocView(moTa: moTa, moSan: "viet", cuonToi: Int(env["CT_SACHHOC_CUON"] ?? ""))
        } else if man.hasPrefix("sachhoc-viet:") {
            MucLucSachHocView(moTa: moTa, moSan: "viet:" + man.dropFirst("sachhoc-viet:".count), cuonToi: nil)
        } else if man.hasPrefix("sachhoc-bai:") {
            MucLucSachHocView(moTa: moTa, moSan: String(man.dropFirst("sachhoc-bai:".count)), cuonToi: Int(env["CT_SACHHOC_CUON"] ?? ""))
        } else {
            MucLucSachHocView(moTa: moTa, moSan: nil, cuonToi: Int(env["CT_SACHHOC_CUON"] ?? ""))
        }
    }
}
#endif
