import SwiftUI

// MARK: - My Work → Agenda: hôm nay + 14 ngày tới, MỌI dự án (`GET /me/agenda`, một lời gọi)
//
// Hạn thẻ của tôi · họp mời tôi (nút Join) · sprint bắt đầu/kết thúc · phát hành · giai đoạn.
// Tải xong ⇒ ghi ảnh chụp "hôm nay" cho widget (`CTWChiaSeNhom.ghiViecHomNay`).

@MainActor
final class AgendaCuaToiVM: ObservableObject {
    @Published var trangThai: TaiCTW<[CTWAgendaItem]> = .dangTai

    /// Sprint đã bắt đầu TRƯỚC hôm nay ⇒ chỉ đáng hiện ngày KẾT THÚC (máy chủ trả `date` = ngày bắt đầu).
    /// Dùng `event` = "ends"/"starts" cho sprint.
    static func chuanHoa(_ ds: [CTWAgendaItem], homNay: String) -> [CTWAgendaItem] {
        ds.compactMap { i in
            guard i.type == "sprint" else { return i }
            var c = i
            if i.date < homNay {
                guard let e = i.end, e >= homNay else { return nil }
                c.date = e
                c.event = "ends"
            } else {
                c.event = "starts"
            }
            return c
        }
    }

    func tai() async {
        let hn = NgayNhomCTW.ymd()
        let den = NgayCTW.ymd(NgayCTW.cong(NgayCTW.ngay(hn) ?? Date(), ngay: 14))
        do {
            let a: CTWAgenda = try await APIClient.shared.request(CTWAPI.lichCuaToi(tu: hn, den: den))
            trangThai = .xong(Self.chuanHoa(a.items ?? [], homNay: hn))
            let v: CTWMyWork? = try? await APIClient.shared.request(.workViecCuaToi)
            CTWChiaSeNhom.ghiViecHomNay(agenda: a.items ?? [], quaHan: (v?.items ?? []).filter { $0.bucket == "overdue" })
        } catch {
            trangThai = .loi(CTW.loi(error))
        }
    }
}

struct AgendaCuaToiCTW: View {
    @StateObject private var vm = AgendaCuaToiVM()
    @Environment(\.openURL) private var moURL

    var body: some View {
        KhungTaiCTW(trangThai: vm.trangThai, thuLai: { Task { await vm.tai() } }) { ds in
            List {
                if ds.isEmpty {
                    CTWOTrong(bieuTuong: "calendar.badge.checkmark", tieuDe: "Nothing scheduled",
                              moTa: "No due dates, meetings or sprint dates in the next two weeks.")
                        .listRowBackground(Color.clear)
                }
                ForEach(nhom(ds), id: \.0) { ngay, muc in
                    Section {
                        ForEach(muc, id: \.khoa) { i in hang(i) }
                    } header: {
                        Text(tieuDeNgay(ngay))
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .task { await vm.tai() }
        .refreshable { await vm.tai() }
    }

    private func nhom(_ ds: [CTWAgendaItem]) -> [(String, [CTWAgendaItem])] {
        Dictionary(grouping: ds, by: \.date).sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    private func tieuDeNgay(_ ymd: String) -> String {
        let hn = NgayNhomCTW.ymd()
        if ymd == hn { return "Today" }
        if let d = NgayCTW.ngay(hn), ymd == NgayCTW.ymd(NgayCTW.cong(d, ngay: 1)) { return "Tomorrow" }
        return NgayCTW.ngay(ymd).map(NgayCTW.thuNgay) ?? ymd
    }

    @ViewBuilder private func hang(_ i: CTWAgendaItem) -> some View {
        let noiDung = HStack(alignment: .top, spacing: 12) {
            Image(systemName: bieuTuong(i)).font(.system(size: 14, weight: .semibold))
                .foregroundColor(mau(i)).frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(mau(i).opacity(0.13)))
            VStack(alignment: .leading, spacing: 3) {
                Text(tieuDe(i)).font(.system(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                Text(phu(i)).font(.system(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            if i.type == "meeting", let s = i.meetingUrl, let u = URL(string: s), ["https", "http"].contains(u.scheme?.lowercased() ?? "") {
                Button("Join") { moURL(u) }.buttonStyle(.borderedProminent).controlSize(.small)
            }
        }
        .padding(.vertical, 2)
        if let u = i.url {
            Button { DinhTuyenCTW.mo(duongDan: u) } label: { noiDung.contentShape(Rectangle()) }.buttonStyle(.plain)
        } else { noiDung }
    }

    private func tieuDe(_ i: CTWAgendaItem) -> String {
        switch i.type {
        case "sprint": return "\(i.title ?? "Sprint") \(i.event ?? "starts")"
        case "release": return "Release \(i.title ?? "")"
        case "stage": return "Stage \(i.n ?? 0) \(i.event ?? "") · \(i.title ?? "")"
        default: return i.title ?? ""
        }
    }

    private func phu(_ i: CTWAgendaItem) -> String {
        var p: [String] = []
        if i.type == "meeting", let a = NgayCTW.thoiDiem(i.startsAt) {
            p.append(NgayCTW.thoiDiem(i.endsAt).map { "\(NgayCTW.gio(a)) – \(NgayCTW.gio($0))" } ?? NgayCTW.gio(a))
        }
        if let k = i.key { p.append(k) }
        if let s = i.status?.name { p.append(s) }
        if let k = i.project?.key { p.append(k) }
        if let l = i.location, !l.isEmpty { p.append(l) }
        return p.joined(separator: " · ")
    }

    private func bieuTuong(_ i: CTWAgendaItem) -> String {
        switch i.type {
        case "due": return "checklist"
        case "meeting": return "person.2.fill"
        case "sprint": return "flag.fill"
        case "release": return "shippingbox.fill"
        default: return "flag.checkered"
        }
    }

    private func mau(_ i: CTWAgendaItem) -> Color {
        switch i.type {
        case "due": return CTWMauChuoi.mau(0)
        case "meeting": return CTWMauChuoi.mau(2)
        case "sprint": return CTWMauChuoi.mau(6)
        case "release": return CTWMauChuoi.mau(1)
        default: return CTWMauChuoi.mau(4)
        }
    }
}
