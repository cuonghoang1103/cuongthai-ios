#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# PHÁT HÀNH app CT WORK (com.cuongthai.ctwork) lên TestFlight — 18/10/2026
#
#   bash scripts/phat-hanh-ctwork.sh              # tăng số dựng → archive → export → KIỂM → upload
#   bash scripts/phat-hanh-ctwork.sh --khong-day  # như trên nhưng KHÔNG upload (giữ IPA ở /tmp/ctwork-export)
#   bash scripts/phat-hanh-ctwork.sh --khong-tang # không tăng CURRENT_PROJECT_VERSION (dựng lại cùng số)
#   bash scripts/phat-hanh-ctwork.sh --thu        # archive KHÔNG KÝ (CODE_SIGNING_ALLOWED=NO) chỉ để kiểm Release
#                                                 #   biên dịch + kiểm nhị phân; không export, không upload
#
# Bám cách app chính (CLAUDE.md PHẦN E + C8/C9): xcodegen → archive → -exportArchive (ký lại bằng profile
# phân phối) → kiểm Ở IPA (không ở archive) → altool. Khoá ASC đọc từ `phat-hanh.env` (gitignore) — script
# KHÔNG in giá trị của nó.
#
# Số phiên bản: MỘT chỗ — `CuongThaiApp/CTWorkApp/PhienBanCTW.xcconfig` (app + widget + Share Extension cùng
# nạp, ITMS-90473 nếu lệch). Script tự tăng CURRENT_PROJECT_VERSION ở đó.
# ════════════════════════════════════════════════════════════════
set -euo pipefail

GOC="$(cd "$(dirname "$0")/.." && pwd)"
cd "$GOC"

DAY=1; TANG=1; THU=0
for a in "$@"; do
  case "$a" in
    --khong-day) DAY=0 ;;
    --khong-tang) TANG=0 ;;
    --thu) THU=1; DAY=0; TANG=0 ;;
    *) echo "Tham số lạ: $a" >&2; exit 2 ;;
  esac
done

XCC="CuongThaiApp/CTWorkApp/PhienBanCTW.xcconfig"
ARCHIVE=/tmp/ctwork.xcarchive
XUAT=/tmp/ctwork-export
APP_TEN="CTWork"   # PRODUCT_NAME của target CTWorkApp

phien_ban() { /usr/bin/sed -nE "s/^$1 *= *([^ ]+).*/\1/p" "$XCC"; }

if [ "$TANG" = 1 ]; then
  CU=$(phien_ban CURRENT_PROJECT_VERSION)
  MOI=$((CU + 1))
  # Ghi đè TẠI CHỖ (không mv): tệp nhỏ, git thấy diff rõ.
  /usr/bin/sed -i '' -E "s/^CURRENT_PROJECT_VERSION *= *[0-9]+/CURRENT_PROJECT_VERSION = $MOI/" "$XCC"
  echo "▶ Số dựng: $CU → $MOI"
fi
BAN=$(phien_ban MARKETING_VERSION); SO=$(phien_ban CURRENT_PROJECT_VERSION)
echo "▶ CT Work $BAN ($SO)"

xcodegen generate >/dev/null

rm -rf "$ARCHIVE"
if [ "$THU" = 1 ]; then
  xcodebuild archive -project CuongThaiApp.xcodeproj -scheme CTWorkApp -configuration Release \
    -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" CODE_SIGNING_ALLOWED=NO -quiet
else
  xcodebuild archive -project CuongThaiApp.xcodeproj -scheme CTWorkApp -configuration Release \
    -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" -allowProvisioningUpdates -quiet
fi

APP="$ARCHIVE/Products/Applications/$APP_TEN.app"
[ -d "$APP" ] || { echo "✗ Không thấy $APP" >&2; exit 1; }

# ── Kiểm (chung cho archive thử và IPA) ─────────────────────────
kiem_goi() {
  local A="$1" LOI=0
  local SO_APP; SO_APP=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$A/Info.plist")
  local BAN_APP; BAN_APP=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$A/Info.plist")
  echo "  app: $BAN_APP ($SO_APP)"
  [ "$SO_APP" = "$SO" ] || { echo "  ✗ CFBundleVersion app = $SO_APP, mong $SO (C9)"; LOI=1; }
  for X in CTWorkWidget CTWorkShare; do
    local E="$A/PlugIns/$X.appex"
    if [ ! -d "$E" ]; then echo "  ✗ thiếu $X.appex trong PlugIns"; LOI=1; continue; fi
    local S B; S=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$E/Info.plist"); B=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$E/Info.plist")
    [ "$S" = "$SO_APP" ] && [ "$B" = "$BAN_APP" ] || { echo "  ✗ $X mang $B ($S) ≠ app (ITMS-90473)"; LOI=1; }
    [ -f "$E/PrivacyInfo.xcprivacy" ] || { echo "  ✗ $X thiếu PrivacyInfo.xcprivacy (ITMS-91053)"; LOI=1; }
  done
  [ -f "$A/PrivacyInfo.xcprivacy" ] || { echo "  ✗ app thiếu PrivacyInfo.xcprivacy (ITMS-91053)"; LOI=1; }
  local N; N=$(/usr/bin/grep -a -c "CT_XEM_MAN" "$A/$APP_TEN" || true)
  [ "$N" = "0" ] || { echo "  ✗ nhị phân Release còn CT_XEM_MAN ($N) — cửa xem màn lọt khỏi #if DEBUG (A6)"; LOI=1; }
  N=$(/usr/bin/grep -a -c "LƯỢT CHẠY MỚI" "$A/$APP_TEN" || true)
  [ "$N" = "0" ] || { echo "  ✗ nhị phân Release còn nhật ký chẩn đoán (A6)"; LOI=1; }
  return $LOI
}

echo "▶ Kiểm archive"
kiem_goi "$APP"

if [ "$THU" = 1 ]; then
  echo "✓ Archive thử (không ký) xanh: $ARCHIVE"
  exit 0
fi

rm -rf "$XUAT"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist ExportOptions.plist \
  -exportPath "$XUAT" -allowProvisioningUpdates -quiet
IPA="$XUAT/$APP_TEN.ipa"
[ -f "$IPA" ] || { echo "✗ Không thấy $IPA" >&2; exit 1; }

# ── Kiểm Ở IPA (C8): entitlement phân phối thật ────────────────
echo "▶ Kiểm IPA"
TAM=$(mktemp -d)
/usr/bin/unzip -o -q "$IPA" -d "$TAM"
A="$TAM/Payload/$APP_TEN.app"
kiem_goi "$A"
QUYEN=$(codesign -d --entitlements :- "$A" 2>/dev/null)
echo "$QUYEN" | /usr/bin/grep -A1 "aps-environment" | /usr/bin/grep -q "production" || { echo "  ✗ aps-environment không phải production"; exit 1; }
echo "$QUYEN" | /usr/bin/grep -A1 "get-task-allow" | /usr/bin/grep -q "false" || { echo "  ✗ get-task-allow phải false"; exit 1; }
echo "$QUYEN" | /usr/bin/grep -q "group.com.cuongthai.ctwork" || { echo "  ✗ app thiếu App Group group.com.cuongthai.ctwork"; exit 1; }
for X in CTWorkWidget CTWorkShare; do
  codesign -d --entitlements :- "$A/PlugIns/$X.appex" 2>/dev/null | /usr/bin/grep -q "group.com.cuongthai.ctwork" \
    || { echo "  ✗ $X thiếu App Group"; exit 1; }
done
rm -rf "$TAM"
echo "✓ IPA hợp lệ: $IPA"

if [ "$DAY" = 0 ]; then
  echo "↷ --khong-day: không upload."
  exit 0
fi

[ -f phat-hanh.env ] || { echo "✗ Thiếu phat-hanh.env (khoá App Store Connect)" >&2; exit 1; }
# shellcheck disable=SC1091
set +x; set -a; . ./phat-hanh.env; set +a
: "${ASC_KEY_ID:?thiếu ASC_KEY_ID trong phat-hanh.env}"; : "${ASC_ISSUER_ID:?thiếu ASC_ISSUER_ID trong phat-hanh.env}"
echo "▶ Upload lên App Store Connect (TestFlight)…"
xcrun altool --upload-app -f "$IPA" -t ios --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
echo "✓ Đã gửi CT Work $BAN ($SO). Chờ Apple xử lý (~10–30 phút) rồi thêm vào nhóm thử trên TestFlight."
