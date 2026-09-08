import SwiftUI
import AVFoundation

// ════════════════════════════════════════════════════════════════
// CHỌN GIỌNG ĐỌC — cho từng ngôn ngữ
//
// Danh sách được LIỆT KÊ LÚC CHẠY từ những gói giọng người dùng đã tải, chứ
// không ghi cứng: mỗi máy một khác, và người dùng có thể tải thêm bất cứ lúc
// nào trong Cài đặt → Trợ năng → Nội dung đọc → Giọng nói.
// ════════════════════════════════════════════════════════════════

struct ChonGiongView: View {
    /// Mã ngôn ngữ của máy chủ: "en" · "ja" · "zh"…
    let code: String
    let tenNgonNgu: String

    @ObservedObject private var caiDat = CaiDatGiong.shared
    @ObservedObject private var doc = DocTu.shared
    @Environment(\.dismiss) private var dismiss

    /// Câu nghe thử — chọn câu CÓ NGHĨA trong chính ngôn ngữ đó, không phải
    /// "test test": nghe một câu thật mới biết giọng đọc có tự nhiên không.
    private var cauThu: String {
        switch code {
        case "ja": return "こんにちは。今日は日本語を勉強しましょう。"
        case "zh": return "你好，今天我们一起学习中文。"
        case "en": return "Hello! Let's learn something new today."
        case "fr": return "Bonjour ! Apprenons quelque chose de nouveau."
        default:   return "Hello"
        }
    }

    private var danhSach: [LuaChonGiong] { CaiDatGiong.danhSach(code) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    tocDo
                } header: { Text(T("TỐC ĐỘ ĐỌC")) }

                Section {
                    hangMacDinh
                    ForEach(danhSach) { g in hang(g) }
                } header: {
                    Text(String(format: T("GIỌNG CHO %@"), tenNgonNgu.uppercased()))
                } footer: {
                    if !CaiDatGiong.coGiongTot(code) {
                        goiYTaiThem
                    }
                }
            }
            .navigationTitle(T("Giọng đọc"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(T("Xong")) { doc.dung(); dismiss() }
                }
            }
            .onDisappear { doc.dung() }
        }
    }

    private var tocDo: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "tortoise").foregroundColor(AppColors.textTertiary)
                Slider(value: $caiDat.tocDo, in: 0.25...0.60)
                Image(systemName: "hare").foregroundColor(AppColors.textTertiary)
            }
            Text(String(format: T("Đang đặt: %.2f — mặc định của Apple là 0,50"), caiDat.tocDo))
                .font(.system(size: 11.5))
                .foregroundColor(AppColors.textTertiary)
        }
    }

    private var hangMacDinh: some View {
        Button { caiDat.chon(nil, cho: code); nghe(nil) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(T("Mặc định của máy")).foregroundColor(AppColors.textPrimary)
                    Text(T("Hệ thống tự chọn")).font(.system(size: 11.5))
                        .foregroundColor(AppColors.textTertiary)
                }
                Spacer()
                if caiDat.idDaChon(code) == nil {
                    Image(systemName: "checkmark").foregroundColor(AppColors.primary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func hang(_ g: LuaChonGiong) -> some View {
        let dangChon = caiDat.idDaChon(code) == g.id
        return Button { caiDat.chon(g.id, cho: code); nghe(g) } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(g.ten).foregroundColor(AppColors.textPrimary).lineLimit(1)
                        if g.laMayNha {
                            Image(systemName: "wifi").font(.system(size: 10))
                                .foregroundColor(AppColors.secondary)
                        }
                    }
                    Text(g.chatLuong)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(mauChatLuong(g.chatLuong))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(mauChatLuong(g.chatLuong).opacity(0.14)))
                }
                Spacer(minLength: 0)
                if dangChon && doc.dangCho {
                    ProgressView().controlSize(.small)
                } else if dangChon {
                    Image(systemName: "checkmark").foregroundColor(AppColors.primary)
                }
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func mauChatLuong(_ c: String) -> Color {
        switch c {
        case "Premium":  return AppColors.success
        case "Enhanced": return AppColors.primary
        case "Máy nhà":  return AppColors.secondary
        default:         return AppColors.textTertiary
        }
    }

    /// Nghe thử NGAY khi chọn — không bắt bấm thêm một nút nữa. Chọn giọng mà
    /// không nghe được ngay thì phải thoát ra, thử, rồi vào lại để đổi.
    private func nghe(_ g: LuaChonGiong?) {
        doc.doc(cauThu, code: code, id: -1)
    }

    private var goiYTaiThem: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(T("Máy bạn mới có giọng bản Compact — đó là bản nghe máy móc nhất."))
            Text(T("Tải bản Enhanced/Premium (miễn phí) ở: Cài đặt → Trợ năng → Nội dung đọc → Giọng nói. Tải xong quay lại đây là thấy ngay."))
            #if os(iOS)
            Button(T("Mở Cài đặt")) {
                if let u = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(u)
                }
            }
            .font(.system(size: 12.5, weight: .semibold))
            .padding(.top, 2)
            #endif
        }
        .font(.system(size: 12))
    }
}
