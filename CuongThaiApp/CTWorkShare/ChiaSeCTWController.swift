import UIKit
import SwiftUI
import UniformTypeIdentifiers

// ════════════════════════════════════════════════════════════════
// SHARE EXTENSION — "Share → CT Work": ảnh / link / chữ ⇒ TẠO THẺ hoặc BÌNH LUẬN vào thẻ (mảng D)
//
// Khác Share Extension của app chính (chỉ ghi link rồi đánh thức app), extension này TỰ gọi API, vì
// "tạo thẻ" phải xong ngay trong khay chia sẻ (mở app giữa chừng là mất ngữ cảnh). Nó lấy:
//   · token từ Keychain CHIA SẺ (`TokenNhomCTW` — app chép vào mỗi lần ra tiền cảnh/đăng nhập);
//   · danh sách dự án + thẻ đã xem gần đây từ App Group (`AnhDuAnCTW`, `TheGanDayCTW`).
// Không có token ⇒ nói thẳng "Open CT Work and sign in first", không gửi gì.
// ⚠️ KHÔNG kéo `Shared/` vào target này (giới hạn bộ nhớ extension ~120 MB) — mạng tự viết gọn ở dưới.
// 1.2: nội dung tạo ra là thẻ/bình luận bình thường — có báo cáo/chặn trong app như mọi nội dung khác.
// ════════════════════════════════════════════════════════════════

final class ChiaSeCTWController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // Ngôn ngữ app chọn (đọc từ App Group) — trước khi dựng view nào.
        NgonNguCTW.caiDatBundle()
        let mh = NoiDungChiaSeVM(context: extensionContext)
        let goc = UIHostingController(rootView: ChiaSeCTWView(vm: mh, dong: { [weak self] daGui in
            if daGui { self?.extensionContext?.completeRequest(returningItems: nil) }
            else { self?.extensionContext?.cancelRequest(withError: NSError(domain: "CTWorkShare", code: 0)) }
        }))
        addChild(goc)
        goc.view.frame = view.bounds
        goc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(goc.view)
        goc.didMove(toParent: self)
        Task { await mh.napNoiDung() }
    }
}

// MARK: - Nội dung chia sẻ + gửi

@MainActor
final class NoiDungChiaSeVM: ObservableObject {
    enum CheDo: String, CaseIterable {
        case theMoi = "New issue", binhLuan = "Comment"
        var ten: String { self == .theMoi ? String(localized: "New issue") : String(localized: "Comment") }
    }

    @Published var cheDo: CheDo = .theMoi
    @Published var tieuDe = ""
    @Published var ghiChu = ""
    @Published var lien: URL?
    @Published var anh: [(ten: String, du: Data, xem: UIImage)] = []
    @Published var duAn: [AnhDuAnCTW.DuAn] = []
    @Published var duAnChon: Int?
    @Published var theChon: String?
    @Published var dangGui = false
    @Published var loi: String?
    @Published var daNap = false
    let coToken: Bool

    private weak var context: NSExtensionContext?

    init(context: NSExtensionContext?) {
        self.context = context
        coToken = TokenNhomCTW.doc() != nil
        let a = AnhDuAnCTW.doc()
        duAn = a?.duAn ?? []
        duAnChon = a?.macDinh ?? duAn.first?.id
    }

    var theGanDay: [TheGanDayCTW] { TheGanDayCTW.ds().filter { duAnChon == nil || $0.pid == duAnChon } }

    var guiDuoc: Bool {
        guard coToken, !dangGui, duAnChon != nil else { return false }
        switch cheDo {
        case .theMoi: return !tieuDe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .binhLuan: return theChon != nil && (!ghiChu.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || lien != nil || !anh.isEmpty)
        }
    }

    func napNoiDung() async {
        defer { daNap = true }
        var chu: [String] = []
        for item in (context?.inputItems as? [NSExtensionItem]) ?? [] {
            if let t = item.attributedContentText?.string, !t.isEmpty { chu.append(t) }
            for d in item.attachments ?? [] {
                if d.hasItemConformingToTypeIdentifier(UTType.image.identifier), anh.count < 4 {
                    if let du = await taiAnh(d) { anh.append(du) }
                } else if d.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                          let u = try? await d.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL, !u.isFileURL {
                    lien = lien ?? u
                } else if d.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                          let s = try? await d.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
                    chu.append(s)
                }
            }
        }
        let toanBo = chu.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if lien == nil, let u = Self.timLien(toanBo) { lien = u }
        let dong = toanBo.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && $0 != lien?.absoluteString }
        tieuDe = String((dong.first ?? lien?.host ?? (anh.isEmpty ? "" : String(localized: "Photo from \(Date().formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(NgonNguCTW.locale)))"))).prefix(200))
        ghiChu = dong.dropFirst().joined(separator: "\n")
        if dong.count <= 1 && cheDo == .binhLuan { ghiChu = toanBo }
    }

    private func taiAnh(_ d: NSItemProvider) async -> (ten: String, du: Data, xem: UIImage)? {
        let goc: UIImage? = await withCheckedContinuation { tiep in
            _ = d.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { du, _ in
                tiep.resume(returning: du.flatMap(UIImage.init(data:)))
            }
        }
        guard let goc else { return nil }
        // JPEG cạnh dài ≤ 2400 px (HEIC/ảnh 48MP gốc vừa nặng vừa có thể vượt trần 25 MB).
        let canh = max(goc.size.width, goc.size.height)
        let tl = canh > 2400 ? 2400 / canh : 1
        let co = CGSize(width: floor(goc.size.width * tl), height: floor(goc.size.height * tl))
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        let nho = UIGraphicsImageRenderer(size: co, format: f).image { _ in goc.draw(in: CGRect(origin: .zero, size: co)) }
        guard let jpg = nho.jpegData(compressionQuality: 0.82) else { return nil }
        return ("Shared photo \(anh.count + 1).jpg", jpg, nho)
    }

    static func timLien(_ s: String) -> URL? {
        guard let d = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let r = d.firstMatch(in: s, range: NSRange(s.startIndex..., in: s))
        guard let u = r?.url, ["http", "https"].contains(u.scheme?.lowercased() ?? "") else { return nil }
        return u
    }

    /// Thân TipTap: các đoạn chữ + đoạn link (mark `link`).
    static func docTipTap(chu: String, lien: URL?) -> [String: Any] {
        var doan: [[String: Any]] = chu.split(separator: "\n", omittingEmptySubsequences: true).map {
            ["type": "paragraph", "content": [["type": "text", "text": String($0)]]]
        }
        if let lien {
            doan.append(["type": "paragraph", "content": [["type": "text", "text": lien.absoluteString,
                                                           "marks": [["type": "link", "attrs": ["href": lien.absoluteString]]]]]])
        }
        if doan.isEmpty { doan = [["type": "paragraph"]] }
        return ["type": "doc", "content": doan]
    }

    func gui() async -> Bool {
        guard guiDuoc, let pid = duAnChon else { return false }
        dangGui = true
        defer { dangGui = false }
        do {
            let so: Int
            switch cheDo {
            case .theMoi:
                var than: [String: Any] = ["title": String(tieuDe.trimmingCharacters(in: .whitespacesAndNewlines).prefix(255)), "typeKey": "TASK"]
                if !ghiChu.isEmpty || lien != nil { than["descriptionJson"] = Self.docTipTap(chu: ghiChu, lien: lien) }
                let r = try await MangChiaSe.goi("/projects/\(pid)/issues", than: than)
                guard let n = r["number"] as? Int else { throw MangChiaSe.Loi.thongDiep(String(localized: "The issue was created but the reply was unexpected.")) }
                so = n
            case .binhLuan:
                guard let ma = theChon, let t = TheGanDayCTW.ds().first(where: { $0.ma == ma }) else { return false }
                so = t.so
                if !ghiChu.isEmpty || lien != nil {
                    _ = try await MangChiaSe.goi("/projects/\(pid)/issues/\(so)/comments", than: ["bodyJson": Self.docTipTap(chu: ghiChu, lien: lien)])
                }
            }
            for a in anh { try await MangChiaSe.dinhKem(pid: pid, so: so, ten: a.ten, du: a.du) }
            return true
        } catch {
            loi = (error as? LocalizedError)?.errorDescription ?? String(localized: "Couldn't send. Check your connection and try again.")
            return false
        }
    }
}

// MARK: - Mạng tối giản (không kéo `Shared/Network` vào extension)

enum MangChiaSe {
    static let goc = "https://cuongthai.com/api/v1/work"

    enum Loi: LocalizedError {
        case chuaDangNhap, thongDiep(String)
        var errorDescription: String? {
            switch self {
            case .chuaDangNhap: return String(localized: "Open CT Work and sign in again, then share once more.")
            case .thongDiep(let s): return s
            }
        }
    }

    private static func yeuCau(_ duong: String, phuongThuc: String = "POST", than: [String: Any]) throws -> URLRequest {
        guard let t = TokenNhomCTW.doc() else { throw Loi.chuaDangNhap }
        guard let u = URL(string: goc + duong) else { throw Loi.thongDiep(String(localized: "Bad address.")) }
        var r = URLRequest(url: u)
        r.httpMethod = phuongThuc
        r.timeoutInterval = 30
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        r.setValue("ios", forHTTPHeaderField: "X-Client-Platform")
        r.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        r.httpBody = try JSONSerialization.data(withJSONObject: than)
        return r
    }

    /// Gọi một route CT Work, trả `data` của phong bì.
    static func goi(_ duong: String, than: [String: Any]) async throws -> [String: Any] {
        let (d, res) = try await URLSession.shared.data(for: yeuCau(duong, than: than))
        let ma = (res as? HTTPURLResponse)?.statusCode ?? 0
        let goi = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any]
        if ma == 401 { throw Loi.chuaDangNhap }
        guard (200..<300).contains(ma) else {
            throw Loi.thongDiep((goi?["message"] as? String) ?? String(localized: "Couldn't send (\(ma)). Please try again."))
        }
        return (goi?["data"] as? [String: Any]) ?? [:]
    }

    /// Ba bước như app: presign ⇒ PUT thẳng lên R2 (url đã ký, KHÔNG gắn token) ⇒ complete.
    static func dinhKem(pid: Int, so: Int, ten: String, du: Data) async throws {
        let ps = try await goi("/projects/\(pid)/issues/\(so)/attachments/presign",
                               than: ["fileName": ten, "contentType": "image/jpeg", "size": du.count])
        guard let s = ps["uploadUrl"] as? String, let url = URL(string: s), let key = ps["key"] as? String else {
            throw Loi.thongDiep(String(localized: "Upload failed. Please try again."))
        }
        var r = URLRequest(url: url)
        r.httpMethod = "PUT"
        let dau = (ps["headers"] as? [String: String]) ?? ["Content-Type": "image/jpeg"]
        for (k, v) in dau { r.setValue(v, forHTTPHeaderField: k) }
        if dau["Content-Type"] == nil { r.setValue("image/jpeg", forHTTPHeaderField: "Content-Type") }
        let (_, res) = try await URLSession.shared.upload(for: r, from: du)
        guard (200..<300).contains((res as? HTTPURLResponse)?.statusCode ?? 0) else { throw Loi.thongDiep(String(localized: "Upload failed. Please try again.")) }
        _ = try await goi("/projects/\(pid)/issues/\(so)/attachments/complete", than: ["key": key, "fileName": ten])
    }
}

// MARK: - Giao diện

struct ChiaSeCTWView: View {
    @ObservedObject var vm: NoiDungChiaSeVM
    let dong: (Bool) -> Void

    var body: some View {
        NavigationStack {
            Form {
                if !vm.coToken {
                    Section {
                        Label("Open CT Work and sign in first. Then you can share photos, links and text into your projects.",
                              systemImage: "person.crop.circle.badge.exclamationmark")
                    }
                } else if vm.duAn.isEmpty {
                    Section { Label("Open CT Work and pick a project once, then share again.", systemImage: "rectangle.3.group") }
                } else {
                    Section {
                        Picker("Add as", selection: $vm.cheDo) {
                            ForEach(NoiDungChiaSeVM.CheDo.allCases, id: \.self) { Text($0.ten).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Picker("Project", selection: $vm.duAnChon) {
                            ForEach(vm.duAn) { p in Text("\(p.ma) · \(p.ten)").tag(Optional(p.id)) }
                        }
                    }
                    if vm.cheDo == .theMoi {
                        Section("Issue") {
                            TextField("Title", text: $vm.tieuDe, axis: .vertical).lineLimit(1...3)
                            TextField("Description (optional)", text: $vm.ghiChu, axis: .vertical).lineLimit(2...6)
                        }
                    } else {
                        Section {
                            if vm.theGanDay.isEmpty {
                                Text("Issues you opened recently in CT Work appear here.").foregroundStyle(.secondary)
                            }
                            Picker("Issue", selection: $vm.theChon) {
                                Text("Choose…").tag(String?.none)
                                ForEach(vm.theGanDay) { t in Text("\(t.ma) · \(t.tieuDe)").tag(Optional(t.ma)) }
                            }
                            TextField("Comment", text: $vm.ghiChu, axis: .vertical).lineLimit(2...6)
                        } header: { Text("Comment on") }
                    }
                    if vm.lien != nil || !vm.anh.isEmpty {
                        Section("Attached") {
                            if let l = vm.lien { Label(l.absoluteString, systemImage: "link").lineLimit(1) }
                            if !vm.anh.isEmpty {
                                ScrollView(.horizontal) {
                                    HStack {
                                        ForEach(Array(vm.anh.enumerated()), id: \.offset) { _, a in
                                            Image(uiImage: a.xem).resizable().scaledToFill().frame(width: 64, height: 64)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if let l = vm.loi { Section { Text(l).foregroundStyle(.red) } }
                }
            }
            .navigationTitle("CT Work")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong(false) } }
                ToolbarItem(placement: .confirmationAction) {
                    if vm.dangGui { ProgressView() } else {
                        Button(vm.cheDo == .theMoi ? "Create" : "Post") {
                            Task { if await vm.gui() { dong(true) } }
                        }
                        .bold()
                        .disabled(!vm.guiDuoc)
                    }
                }
            }
            .overlay { if !vm.daNap { ProgressView() } }
        }
    }
}
