# Quy tắc làm app iOS — CuongThai

**Kho:** `/Users/admin/Downloads/ios-app` · XcodeGen (`project.yml` → `.xcodeproj`)
**Đích:** mọi thay đổi phải qua được vòng duyệt App Store, không chỉ "chạy được".

---

## 0. GIAO KÈO — đọc trước khi gõ dòng mã đầu tiên

Người dùng yêu cầu: **trước khi làm bất cứ việc gì trên app iOS, AI phải nói ra
những quy tắc trong file này mà việc đó chạm tới, rồi chờ duyệt.**

Mẫu bắt buộc:

> **Việc:** \<mô tả ngắn\>
> **Điều khoản chạm tới:** A3 (1.2 UGC), A8 (privacy manifest)
> **Vì sao:** tính năng này nhận nội dung người dùng ⇒ phải có báo cáo + chặn
> **Rủi ro nếu bỏ qua:** bị trả về theo 1.2, mất 1–2 vòng duyệt (~1 tuần)
> **Xin duyệt để làm.**

Không có dòng nào trong file này được "bỏ qua cho nhanh". Một vòng duyệt trượt
tốn **24–48 giờ chờ** cộng thời gian sửa; gộp lại thường đắt hơn làm đúng ngay.

⚠️ **Điều nguy hiểm nhất khi làm app iOS bằng AI:** mã biên dịch xanh, chạy
đúng, nhìn đẹp — và vẫn bị Apple trả về, vì phần lớn luật của Apple **không
phải luật kỹ thuật**. Trình biên dịch không bao giờ báo cho bạn biết là thiếu
nút "Xoá tài khoản".

---

# PHẦN A — LUẬT APPLE

Xếp theo khả năng bị trả về, cao xuống thấp. Trích dẫn lấy từ
`developer.apple.com/app-store/review/guidelines/`.

## A1. 3.1.1 — Mở khoá tính năng thì PHẢI dùng In-App Purchase ⛔⛔

> *"If you want to unlock features or functionality within your app (by way of
> example: subscriptions, in-game currencies, game levels, access to premium
> content, or unlocking a full version), you must use in-app purchase."*

Và điều khoản dành riêng cho app có cả web (3.1.3(b) Multiplatform Services):

> *"Apps that operate across multiple platforms may allow users to access
> content, subscriptions, or features they have acquired … on your web site …
> **provided those items are also available as in-app purchases within the
> app**."*

**Nghĩa với app này:** gói Pro bán trên `cuongthai.com` được phép dùng trong
app — NHƯNG app cũng phải bán chính gói đó bằng IAP. Không có đường vòng.

**Cấm tuyệt đối trong app (ngoài cửa hàng Mỹ):**
- nút/link/QR dẫn sang trang thanh toán ngoài
- câu chữ kiểu "mua trên web rẻ hơn", "liên hệ Zalo để nâng cấp"
- ví điểm, mã nạp, key kích hoạt mua bằng cách khác

> *"…apps and their metadata may not include buttons, external links, or other
> calls to action that direct customers to purchasing mechanisms other than
> in-app purchase."*

**Bắt buộc kèm theo:** nút **Khôi phục giao dịch** (*"make sure you have a
restore mechanism"*), link Điều khoản + Chính sách bảo mật trên màn bán, và
giá hiển thị phải là `product.displayPrice` của StoreKit — KHÔNG phải giá lấy
từ API của mình (Apple quy đổi tiền/thuế theo từng nước; in giá web ra là sai
tiền với người dùng nước khác).

**Máy chủ là nơi phán quyết.** App không được tự mở khoá dựa trên
`Transaction.currentEntitlements`. Luôn hỏi backend.

## A2. 5.1.1(v) — Có đăng ký thì PHẢI xoá được tài khoản trong app ⛔

> *"If your app supports account creation, you must also offer account deletion
> within the app."*

Không phải "gửi email yêu cầu xoá". Phải là một đường đi trong app, xoá thật.
Hiện ở **Cài đặt → Xoá tài khoản** (`Views/AccountViews.swift`).

Kèm: *"If your app doesn't include significant account-based features, let
people use it without a login."* — đừng bắt đăng nhập để xem thứ không cần
tài khoản.

## A3. 1.2 — Có nội dung người dùng thì phải có ĐỦ BỐN thứ ⛔

> *"A method for filtering objectionable material from being posted to the app;
> a mechanism to report offensive content and timely responses to concerns;
> the ability to block abusive users from the service; published contact
> information so users can easily reach you."*

Bốn, không phải ba. Thiếu một là trả về. App này đã có cả bốn
(`Services/ModerationStore.swift`, `Views/ModerationViews.swift`) — **thêm bất
cứ chỗ nào người dùng đăng được nội dung thì phải nối vào đủ bốn cái đó.**

1.2.1 (nội dung do người sáng tạo đăng) còn đòi thêm **chặn theo tuổi**.

## A4. 2.1 — Nộp bản HOÀN CHỈNH ⛔

> *"placeholder text, empty websites, and other temporary content should be
> scrubbed before submission"* · *"include demo account info (and turn on your
> back-end service!)"* · *"If you offer in-app purchases … make sure they are
> complete, up-to-date, **visible to the reviewer** and functional."*

- Không màn "đang phát triển", không nút bấm không làm gì
- Tài khoản demo phải **BẬT SẴN Pro**, nếu không reviewer chỉ thấy màn khoá
- Backend phải sống trong lúc duyệt

## A5. 5.1.2(i) — Gửi dữ liệu cho AI bên thứ ba phải CÔNG BỐ và XIN PHÉP ⛔

> *"You must clearly disclose where personal data will be shared with third
> parties, **including with third-party AI**, and obtain explicit permission
> before doing so."*

"Explicit permission" nghĩa là phải nằm ở chỗ người dùng **bấm đồng ý**, không
chỉ nằm trong trang chính sách. App này để ở màn đồng ý lần đầu
(`Views/LegalViews.swift` → `TermsConsentView`) và một mục riêng trong Chính
sách bảo mật.

⚠️ Viết đúng sự thật. Ví dụ có thật ở app này: nhận giọng nói chạy **trên máy
khi máy làm được**, không làm được thì lùi về dịch vụ của Apple. Ghi "không
gửi đi đâu cả" là khai sai.

**Thêm tính năng AI mới ⇒ phải cập nhật mục công bố này.**

## A6. 2.3 — Không có tính năng ẩn, và phải KHAI trong Notes for Review ⛔

> *"Don't include any hidden, dormant, or undocumented features in your app …
> All new features, functionality, and product changes must be described with
> specificity in the Notes for Review section (generic descriptions will be
> rejected)."*

⚠️ **Áp thẳng vào kho này:** cửa xem màn hình `CT_XEM_MAN`
(`Views/ManXemThu.swift`) là một tính năng ẩn. Nó nằm trọn trong `#if DEBUG`
nên **không vào bản phát hành** — và điều đó phải được **đo lại mỗi lần**:

```bash
R=<đường-dẫn>/Release-iphoneos/CuongThaiApp.app/CuongThaiApp
/usr/bin/grep -a -c "CT_XEM_MAN" "$R"     # phải = 0
/usr/bin/grep -a -c "LƯỢT CHẠY MỚI" "$R"  # nhật ký chẩn đoán, phải = 0
```

Thêm bàn thử mới thì phải đặt **bên trong** `#if DEBUG` — có lần đặt sau
`#endif`, Debug vẫn xanh, Release mới vỡ.

## A7. 4.8 + 5.1.1 — Đăng nhập

Có đăng nhập bằng mạng xã hội của bên thứ ba ⇒ phải có **Sign in with Apple**
(hoặc một lựa chọn riêng tư tương đương). Đã có
(`Auth/AppleSignIn.swift` + entitlement `com.apple.developer.applesignin`).

> *"An app may not store credentials or tokens to social networks off of the
> device."*

Token lưu ở **Keychain**, không phải `UserDefaults` (`Storage/KeychainStore.swift`).

## A8. Privacy manifest — `PrivacyInfo.xcprivacy` ⛔

Không nằm trong Review Guidelines mà nằm ở khâu **nộp binary**: thiếu là bị
chặn ngay lúc upload với `ITMS-91053 / 91055 / 91056`, không đợi tới reviewer.

Bắt buộc từ 01/05/2024: khai `NSPrivacyAccessedAPITypes` cho **năm nhóm API**
nếu app có dùng:

| Nhóm | Dấu hiệu trong mã |
|---|---|
| `…CategoryUserDefaults` | `UserDefaults` |
| `…CategoryFileTimestamp` | `creationDate`, `modificationDate` |
| `…CategorySystemBootTime` | `systemUptime`, `mach_absolute_time` |
| `…CategoryDiskSpace` | `volumeAvailableCapacity`, `systemFreeSize` |
| `…CategoryActiveKeyboards` | `activeInputModes` |

Kiểm nhanh cả năm nhóm (quét cả `Widget/` và `ChiaSe/` — mỗi extension là
một bundle riêng, cần bản khai riêng):
```bash
cd CuongThaiApp
/usr/bin/grep -rlE --include='*.swift' 'creationDate|modificationDate|contentModificationDateKey|attributesOfItem|getattrlist|\bstat\(' .
/usr/bin/grep -rlE --include='*.swift' 'systemUptime|mach_absolute_time' .
/usr/bin/grep -rlE --include='*.swift' 'volumeAvailableCapacity|systemFreeSize' .
/usr/bin/grep -rlE --include='*.swift' 'activeInputModes' .
/usr/bin/grep -rl  --include='*.swift' 'UserDefaults' .
```

Trạng thái hiện tại (soát lại 24/09/2026 — dòng cũ "bốn nhóm kia = 0 file"
đo 14/09 là SAI, lệnh quét cũ không bắt `contentModificationDateKey` và
`attributesOfItem`):

| Bundle | Bản khai | Nhóm API + lý do |
|---|---|---|
| App chính | `Resources/PrivacyInfo.xcprivacy` | UserDefaults `CA92.1` + `1C8F.1` (đọc App Group do Share Extension ghi) · FileTimestamp `C617.1` (`KhoNgoaiTuyen` dọn đệm theo `contentModificationDate`; `ThuVienBoPhan` đọc `attributesOfItem`; `NhatKy` cũng gọi nhưng chỉ trong `#if DEBUG`) |
| `ChiaSeVideo` | `ChiaSe/PrivacyInfo.xcprivacy` | UserDefaults `1C8F.1` (`UserDefaults(suiteName: group…)`) |
| `TienWidget` | `Widget/PrivacyInfo.xcprivacy` | không nhóm nào (chỉ `Data(contentsOf:)` trong App Group) |

SystemBootTime, DiskSpace, ActiveKeyboards = 0 chỗ. `C617.1` = tệp trong
vùng chứa của app; `3B52.1` chỉ dành cho tệp người dùng chọn qua trình chọn
tài liệu — KHÔNG áp dụng ở đây. **Thêm mã mới chạm vào một nhóm nào thì phải
bổ sung đúng bản khai của đúng bundle.** XcodeGen tự đưa `PrivacyInfo.xcprivacy`
nằm trong thư mục nguồn của target vào Copy Bundle Resources.

`NSPrivacyCollectedDataTypes` của app chính (đều Linked, không Tracking,
mục đích App Functionality): EmailAddress, Name, UserID, DeviceID (push
token), PhotosorVideos, AudioData (luyện nói → Groq Whisper, không lưu),
EmailsOrTextMessages (tin nhắn trong app), OtherUserContent,
OtherFinancialInfo (mục Tiền), PreciseLocation (chỉ khi tự bấm chia sẻ vị trí
trong chat). Nhãn App Privacy trên App Store Connect phải khớp danh sách này.

Và phải kiểm nó **thật sự được đóng gói**:
```bash
find <Release>/CuongThaiApp.app -name "PrivacyInfo.xcprivacy"
```
Xcode có lúc không tự thêm vào Copy Bundle Resources — trống là ăn ITMS-91053.

## A9. 5.2 — Sở hữu trí tuệ, và cấm tải nội dung của bên khác ⛔

> *"Apps should not facilitate illegal file sharing or include the ability to
> save, convert, or download media from third-party sources (e.g. Apple Music,
> YouTube, SoundCloud, Vimeo, etc.) without explicit authorization."*

⚠️ Đây là lý do module Nhạc **đã bị gỡ khỏi app iOS** (vẫn còn trên web).
Sticker nhạc trong bài viết chỉ hiện TÊN bài, không phát, không tải.
**Đừng thêm lại dưới bất kỳ hình thức nào.** Nhúng YouTube bằng player chính
thức thì được; rút file về thì không.

## A10. 2.5.2 — Không tải và chạy mã ngoài ⚠️ điều này chạm tới Code Lab / Mô phỏng

> *"[Apps] may not download, install, or execute code which introduces or
> changes features or functionality of the app."*

Ngoại lệ, và app này dựa vào nó:

> *"Educational apps designed to teach, develop, or allow students to test
> executable code may, in limited circumstances, download code provided that
> such code is not used for other purposes. Such apps must make the source code
> provided by the app **completely viewable and editable by the user**."*

**Điều kiện phải giữ:** mã chạy trong `JSContext` (`MoPhong/MayMoPhong.swift`)
phải là **mã học tập, người dùng xem và sửa được**, và không được đổi hành vi
của chính app. Khai rõ trong Notes for Review là app dạy lập trình.

⛔ Không bao giờ dùng `JSContext` (hay bất cứ đường nào) để tải logic điều
khiển app từ máy chủ. Đó là 2.5.2 thẳng, và là lý do bị đuổi khỏi chương trình
lập trình viên nếu cố tình.

## A11. 4.2 — Phải hơn một cái vỏ bọc website ⚠️

> *"Your app should include features, content, and UI that elevate it beyond a
> repackaged website."*

⚠️ Câu "hãy làm trên web" trong app là **dấu hiệu xấu** với reviewer. Hiện còn
một chỗ: câu tự luận trong Phòng thi (`PhongThi/LamBaiView.swift`). Nên cho gõ
được ngay trong app thay vì đẩy người dùng ra ngoài.

`WKWebView` dùng để **dựng nội dung** (công thức, sơ đồ, mã tô màu) thì không
sao. Bọc cả một trang web vào rồi gọi là app thì không qua.

## A12. 4.7 — Chatbot / AI trong app

Nội dung do AI sinh ra vẫn là nội dung app chịu trách nhiệm:

> *"Software offered in apps under this rule must: include a method for
> filtering objectionable material, a mechanism to report content and timely
> responses to concerns, and the ability to block abusive users."*

Và: *"Your app must provide a way for users to identify software that exceeds
the app's age rating."*

⇒ Chỗ nào AI trả lời cho người dùng thì **phải có nút báo cáo câu trả lời**.

## A13. Phân loại độ tuổi (2.3)

> *"Answer the age rating questions in App Store Connect honestly… If your app
> is mis-rated, customers might be surprised by what they get, or it could
> trigger an inquiry from government regulators."*

App này có **nội dung người dùng tạo** + **chat AI** ⇒ khai cả hai. Khai thấp
để dễ bán là con đường ngắn nhất tới bị gỡ app.

## A14. 5.1.5 Vị trí · 5.1.1 chuỗi mục đích

Mỗi quyền phải có chuỗi `NS…UsageDescription` **nói đúng việc app làm với nó**.

> *"Ensure your purpose strings clearly and completely describe your use of the
> data."* · *"Paid functionality must not be dependent on or require a user to
> grant access to this data."*

⛔ Khai quyền mà không dùng = trả về. Từng dính: khai
`NSFaceIDUsageDescription` trong khi không dùng Face ID.
⛔ Thiếu chuỗi mà gọi API = iOS **giết app ngay**, không phải báo lỗi.

## A15. 5.1.1 — Chính sách bảo mật

> *"All apps must include a link to their privacy policy in the App Store
> Connect metadata field **and within the app** in an easily accessible
> manner."*

Hai chỗ, không phải một. Trong app: **Cài đặt → Chính sách bảo mật**.
URL: `https://cuongthai.com/chinh-sach-bao-mat` (kiểm bằng `curl -I`, phải 200
và có nội dung thật — trang 404 đội lốt 200 là bị bắt).

---

# PHẦN B — RIÊNG CHO GAME

Chưa áp dụng cho app này, nhưng hỏi tới thì đây là luật:

**Hộp quà ngẫu nhiên (loot box) — 3.1.1:**
> *"Apps offering 'loot boxes' or other mechanisms that provide randomized
> virtual items for purchase must disclose the odds of receiving each type of
> item to customers prior to purchase."*

Công bố **tỉ lệ từng loại vật phẩm**, **trước khi** mua. Không phải trong EULA.

**Cờ bạc ăn tiền thật — 5.3:**
> *"…must have necessary licensing and permissions in the locations where the
> app is used, must be geo-restricted to those locations, and **must be free on
> the App Store**."*

Ba điều kiện cùng lúc. Việt Nam siết chặt mảng này — đừng đụng nếu không có
giấy phép.

**Tiền trong game:** mua bằng IAP, và *"credits or in-game currencies purchased
via in-app purchase may not expire"* — không được đặt hạn sử dụng.

**Mục Trẻ em (Kids Category):**
- không link ra ngoài, không chỗ mua, trừ khi nấp sau **cổng phụ huynh**
- **không** phân tích của bên thứ ba, **không** quảng cáo của bên thứ ba
- không gửi thông tin định danh hay thông tin thiết bị cho bên thứ ba
- tuân thủ COPPA / GDPR-K

**Thử thách giữa người chơi bằng tiền thật:** phải qua Game Center hoặc cơ chế
được Apple cho phép, không tự làm.

---

# PHẦN C — BẪY CỦA CHÍNH KHO NÀY

Mỗi mục dưới đây đã làm mất thời gian thật ít nhất một lần.

## C1. ⛔⛔ Sản phẩm dựng nằm ở `DerivedData/CuongHoangIOS/`, KHÔNG phải thư mục mặc định

```bash
# ĐÚNG
~/Library/Developer/Xcode/DerivedData/CuongHoangIOS/Products/Debug-iphonesimulator/CuongThaiApp.app
# SAI — thư mục băm mặc định, chứa bản CŨ nhiều tháng
find ~/Library/Developer/Xcode/DerivedData -name "CuongThaiApp.app" | head -1
```

12/09/2026: cài nhầm bản **19/08** năm lượt liền, ảnh chụp lần nào cũng ra màn
đăng nhập, suýt kết luận "cửa `CT_XEM_MAN` hỏng". Luôn `ls -l` nhị phân sắp
cài — ngày giờ phải là vài giây trước.

## C2. ⛔ `BUILD SUCCEEDED` không có nghĩa là màn hình đổi

Luôn **cài rồi nhìn tận mắt**. Đo bằng sản phẩm, không bằng dòng chữ.

## C3. ⛔ `JSONDecoder()` của `APIClient` dùng chiến lược ngày MẶC ĐỊNH

Khai `Date` trong model là **cả lượt giải mã hỏng**, và lỗi giải mã ở app này
**bị nuốt im lặng** — nó hiện ra dạng "hồ sơ trống", không phải dạng lỗi.
⇒ Ngày từ API khai là `String?`, tự đọc bằng `NhacViec.moc(_:)`.

## C4. ⛔ Thuộc tính `let` có giá trị mặc định thì `Codable` BỎ QUA

`let provider: String? = nil` → giải mã `{"provider":"google"}` vẫn ra `nil`,
im lặng. Trường của model API phải là `var`, và phải **optional** (endpoint hồ
sơ người khác không trả trường riêng tư).

## C5. ⛔ Hai `.sheet(isPresented:)` trên cùng một view: chỉ cái cuối chạy

Cái kia bấm im lặng. Nhiều sheet ⇒ dùng **một** `.sheet(item:)` với enum.

## C6. ⛔ `.animation(_:value:)` khoá vào `Color` ĐỘNG làm view trôi khỏi màn hình

Khoá vào giá trị **ổn định** (chuỗi trạng thái), không khoá vào thứ tính lại
mỗi lần dựng.

## C7. ⛔ `.swipeActions` chỉ chạy trong `List`

Gắn vào hàng trong `VStack`: biên dịch xanh, chạy không lỗi, vuốt **không làm
gì**. Dùng `.contextMenu`.

## C8. ⛔ Ký bản phát hành: archive ký DEVELOPMENT là BÌNH THƯỜNG

Bước `-exportArchive` mới ký lại bằng profile phân phối. Kiểm ở **IPA**, đừng
kiểm ở archive:
```bash
codesign -d --entitlements :- Payload/CuongThaiApp.app
# phải thấy: aps-environment = production · get-task-allow = false
```

## C9. ⛔ Số bản dựng đi qua BA chặng, chặng nào cũng đổi được

`project.yml` → archive → IPA. `ExportOptions.plist` **phải** có
`manageAppVersionAndBuildNumber = false` (mặc định của Xcode là `true`, tức nó
tự đổi số của mình). Đọc lại số trong chính file IPA trước khi đẩy:
```bash
unzip -o -q ct.ipa 'Payload/*.app/Info.plist' -d /tmp/ipacheck
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" /tmp/ipacheck/Payload/CuongThaiApp.app/Info.plist
```

## C10. ⚠️ Target macOS (`CuongThaiAppMac`) đang HỎNG từ 10/09/2026

`Call/CuocGoi.swift` cần WebRTC, `TongQuan/QuetAnhLich.swift` cần UIKit — cả
hai chỉ có trên iOS. Không ảnh hưởng App Store (chỉ nộp iOS) nhưng **đừng ghi
"macOS build xanh"** trong ghi chú nộp.

Thêm file vào `Shared/` mà dùng UIKit/WebRTC thì phải bọc `#if os(iOS)`.

## C11. ⛔ File `.swift` mới phải chạy `xcodegen generate`

Không có bước đó thì file không vào target, và lỗi hiện ra dạng "symbol not
found" chứ không phải "file thiếu".

## C12. ⛔ Chỉ iPhone: `TARGETED_DEVICE_FAMILY = "1"`

Cố ý. Khai thêm iPad là reviewer **mở app trên iPad** và thấy giao diện điện
thoại phóng to — trả về theo 4.0/2.1. Muốn hỗ trợ iPad thì phải làm giao diện
iPad thật.

## C13. ⚠️ Cài lại app KHÔNG xoá Keychain

`simctl uninstall` giữ nguyên phiên đăng nhập; `simctl erase` mới xoá. Tiện để
thử màn đồng ý lần đầu mà không mất phiên — và cũng là lý do "đã gỡ app rồi mà
vẫn đăng nhập sẵn".

## C14. ⛔ Đừng tin giá/quyền lấy từ máy khách

`isPro` luôn hỏi máy chủ (`GET /api/v1/profile`). Mọi cổng Pro chặn ở backend
bằng `isProEffective`, app chỉ hiển thị câu máy chủ trả về. Nhờ vậy gói mua
trên web dùng được ngay trong app, và không có gì để lệch.

---

# PHẦN D — CHECKLIST TRƯỚC KHI NỘP

```
LUẬT
[ ] Tính năng mới có khoá sau Pro không? → có IAP chưa? có nút Khôi phục chưa?
[ ] Có chỗ nào người dùng đăng nội dung mới? → đủ 4 thứ của 1.2 chưa?
[ ] Có tính năng AI mới? → đã cập nhật mục công bố AI bên thứ ba chưa?
[ ] Có quyền mới? → chuỗi mục đích viết đúng việc chưa? có thật sự dùng không?
[ ] Có dùng thêm API thuộc 5 nhóm required-reason? → manifest đã bổ sung chưa?
[ ] Có câu nào bảo người dùng "làm trên web" không?
[ ] Có link/nút nào dẫn ra ngoài để thanh toán không?

KỸ THUẬT
[ ] xcodegen generate
[ ] Build Debug + Release đều xanh
[ ] grep CT_XEM_MAN trong nhị phân Release  = 0
[ ] grep "LƯỢT CHẠY MỚI" trong nhị phân Release = 0
[ ] PrivacyInfo.xcprivacy có trong .app
[ ] Tăng CURRENT_PROJECT_VERSION
[ ] CFBundleVersion đọc lại TỪ IPA đúng số
[ ] entitlements trong IPA: aps-environment=production, get-task-allow=false
[ ] Cài lên máy thật/máy ảo và NHÌN, không chỉ build

APP STORE CONNECT
[ ] Mô tả · từ khoá · Support URL (BẮT BUỘC) · Privacy Policy URL
[ ] Ảnh màn hình đủ cỡ bắt buộc
[ ] Khai độ tuổi (có UGC + chat AI)
[ ] App Privacy labels
[ ] Tài khoản demo — ĐÃ BẬT PRO — điền vào App Review Information
[ ] Notes for Review: mô tả CỤ THỂ tính năng mới (mô tả chung chung bị trả về)
[ ] Gắn build vào phiên bản
```

---

# PHẦN E — PHÁT HÀNH

Công thức đầy đủ nằm ở trí nhớ `reference_phat_hanh_ios_testflight.md`.
Khoá API và issuer ID nằm sẵn trong **`phat-hanh.env`** của kho này (đã
gitignore) — **đừng đi hỏi người dùng**.

```bash
# 0) tăng CURRENT_PROJECT_VERSION trong project.yml rồi xcodegen generate
xcodebuild archive -project CuongThaiApp.xcodeproj -scheme CuongThaiApp \
  -destination 'generic/platform=iOS' -archivePath /tmp/ct.xcarchive -allowProvisioningUpdates
xcodebuild -exportArchive -archivePath /tmp/ct.xcarchive \
  -exportOptionsPlist /tmp/ExportOptions.plist -exportPath /tmp/ct-export -allowProvisioningUpdates
xcrun altool --upload-app -f /tmp/ct-export/CuongThaiApp.ipa -t ios \
  --apiKey SW4TM47WHC --apiIssuer e6e9c0a3-e066-41ad-9f64-487397104876
```

⛔ Khoá `SW4TM47WHC` **chỉ đọc**. Đủ quyền `--upload-app`, KHÔNG đủ quyền sửa
metadata (`PATCH` trả 403). Ghi chú duyệt, nhóm thử, link chính sách — làm tay
trên web, hoặc tạo khoá vai trò **App Manager** mới.

**Cài thẳng iPhone (nhanh hơn TestFlight, qua Wi-Fi, không cần cáp):**
⚠️ Hai công cụ gọi cùng một máy bằng **hai mã khác nhau** —
`devicectl` dùng coredevice UUID, `xcodebuild` dùng UDID phần cứng.
Chi tiết: `reference_cai_thang_vao_iphone_dang_cam.md`.

---

## Nguồn

- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)

Luật Apple **đổi**. Trước mỗi đợt nộp, mở lại trang Review Guidelines và đối
chiếu — đừng làm theo trí nhớ, kể cả trí nhớ của file này.
