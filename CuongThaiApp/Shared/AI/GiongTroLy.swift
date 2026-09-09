import SwiftUI

// ════════════════════════════════════════════════════════════════
// GIỌNG CHO TRỢ LÝ — chọn giọng AI đọc câu trả lời
//
// Khác `CaiDatGiong` ở mục Ngoại ngữ: bên kia chọn giọng MÁY (AVSpeech) theo
// từng ngôn ngữ học. Bên này chọn giọng của MÁY CHỦ (`/voice-mini`) cho trợ
// lý nói tiếng Việt. Hai việc khác nhau, hai kho khác nhau — gộp lại là chọn
// giọng học tiếng Nhật xong thì trợ lý cũng đổi giọng theo.
// ════════════════════════════════════════════════════════════════

struct GiongMayChu: Decodable, Identifiable, Hashable {
    let id: String
    let label: String
}

@MainActor
final class GiongTroLy: ObservableObject {
    static let shared = GiongTroLy()

    private static let KHOA = "giong-tro-ly-id"

    /// `nil` = để máy chủ tự chọn giọng mặc định.
    @Published var idDaChon: String? {
        didSet {
            if let idDaChon { UserDefaults.standard.set(idDaChon, forKey: Self.KHOA) }
            else { UserDefaults.standard.removeObject(forKey: Self.KHOA) }
        }
    }
    @Published private(set) var danhSach: [GiongMayChu] = []
    @Published private(set) var dangTai = false
    @Published var loi: String?

    private init() {
        idDaChon = UserDefaults.standard.string(forKey: Self.KHOA)
    }

    var tenDangChon: String {
        guard let idDaChon else { return "Giọng mặc định" }
        return danhSach.first { $0.id == idDaChon }?.label ?? idDaChon
    }

    /// Nạp một lần rồi thôi. Danh sách giọng gần như không đổi, mà mỗi lần gọi
    /// là một lượt đi tới máy đọc — thứ vốn đã bận.
    func tai(batBuoc: Bool = false) async {
        if !batBuoc && !danhSach.isEmpty { return }
        dangTai = true
        defer { dangTai = false }
        do {
            struct Vo: Decodable { let voices: [GiongMayChu]? }
            let v: Vo = try await APIClient.shared.request(.dsGiongMayChu)
            danhSach = v.voices ?? []
            // Giọng đã chọn không còn trên máy chủ (bị xoá) thì về mặc định,
            // không thì mỗi lượt đọc đều lỗi mà không rõ vì sao.
            if let id = idDaChon, !danhSach.contains(where: { $0.id == id }) {
                idDaChon = nil
            }
        } catch {
            loi = "Chưa lấy được danh sách giọng."
        }
    }
}

struct ChonGiongTroLyView: View {
    @ObservedObject private var kho = GiongTroLy.shared
    @Environment(\.dismiss) private var dong

    var body: some View {
        List {
            Section {
                Button {
                    kho.idDaChon = nil
                } label: {
                    HStack {
                        Text(T("Giọng mặc định")).foregroundColor(AppColors.textPrimary)
                        Spacer()
                        if kho.idDaChon == nil {
                            Image(systemName: "checkmark").foregroundColor(AppColors.primary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            Section {
                if kho.dangTai && kho.danhSach.isEmpty {
                    HStack { ProgressView().controlSize(.small); Text(T("Đang tải giọng…")) }
                } else if kho.danhSach.isEmpty {
                    Text(kho.loi ?? T("Không có giọng nào."))
                        .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                }
                ForEach(kho.danhSach) { g in
                    Button {
                        kho.idDaChon = g.id
                    } label: {
                        HStack {
                            Text(g.label).foregroundColor(AppColors.textPrimary)
                            Spacer()
                            if kho.idDaChon == g.id {
                                Image(systemName: "checkmark").foregroundColor(AppColors.primary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text(T("Giọng máy chủ"))
            } footer: {
                Text(T("Giọng dùng cho trợ lý đọc câu trả lời. Đổi giọng không làm chậm hơn — máy đọc vẫn sinh theo từng mẩu như cũ."))
                    .font(.system(size: 12))
            }
        }
        .navigationTitle(T("Giọng trợ lý"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(T("Xong")) { dong() }
            }
        }
        .task { await kho.tai() }
    }
}
