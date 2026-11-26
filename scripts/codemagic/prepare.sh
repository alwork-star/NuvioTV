#!/bin/bash
# Codemagic prep for this fork: re-points the NuvioTV app and its Top Shelf extension at our own
# bundle ids and team, so Codemagic can sign them for TestFlight. Runs on a fresh clone only.
#
# First build is deliberately conservative: the App Group entitlement is removed from both targets,
# because App Groups cannot be created through the App Store Connect API. The app already handles a
# missing group (TopShelfSnapshot returns nil), so Top Shelf just stays empty. To turn it on later:
# register group.com.adamle.nuviotv in the developer portal, assign it to both bundle ids, and set
# KEEP_APP_GROUP=1 in the Codemagic group.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SUB="$ROOT/NuvioMobile"
PBX="$SUB/iosApp/iosApp.xcodeproj/project.pbxproj"
APP_ID="${APP_BUNDLE_ID:?APP_BUNDLE_ID not set}"
TEAM="${APPLE_TEAM_ID:?APPLE_TEAM_ID not set}"

# Bundle ids: the extension id must start with the app id. Replace the longer id first.
sed -i '' \
  -e "s/com\.nuvio\.media\.NuvioTV\.NuvioTopShelf/${APP_ID}.topshelf/g" \
  -e "s/PRODUCT_BUNDLE_IDENTIFIER = com\.nuvio\.media\.NuvioTV;/PRODUCT_BUNDLE_IDENTIFIER = ${APP_ID};/g" \
  -e "s/DEVELOPMENT_TEAM = [A-Z0-9]*;/DEVELOPMENT_TEAM = ${TEAM};/g" \
  "$PBX"
grep -q "PRODUCT_BUNDLE_IDENTIFIER = ${APP_ID};" "$PBX" || { echo "app bundle id was not replaced" >&2; exit 1; }
grep -q "PRODUCT_BUNDLE_IDENTIFIER = ${APP_ID}.topshelf;" "$PBX" || { echo "Top Shelf bundle id was not replaced" >&2; exit 1; }

EMPTY='<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>'
if [ "${KEEP_APP_GROUP:-0}" = "1" ]; then
  for f in NuvioTV/NuvioTV.entitlements NuvioTopShelf/NuvioTopShelf.entitlements; do
    sed -i '' "s/group\.com\.nuvio\.media\.NuvioTV/group.${APP_ID}/" "$SUB/iosApp/$f"
  done
  grep -rl 'group\.com\.nuvio\.media\.NuvioTV' "$SUB/iosApp" --include=*.swift | while read -r f; do
    sed -i '' "s/group\.com\.nuvio\.media\.NuvioTV/group.${APP_ID}/g" "$f"
  done
  echo "App Group kept as group.${APP_ID}"
else
  printf '%s\n' "$EMPTY" > "$SUB/iosApp/NuvioTV/NuvioTV.entitlements"
  printf '%s\n' "$EMPTY" > "$SUB/iosApp/NuvioTopShelf/NuvioTopShelf.entitlements"
  echo "App Group removed for this build (Top Shelf stays empty)"
fi

# No export-compliance question on every TestFlight build: the app only uses standard HTTPS.
/usr/libexec/PlistBuddy -c "Add :ITSAppUsesNonExemptEncryption bool false" "$SUB/iosApp/NuvioTV/Info.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Set :ITSAppUsesNonExemptEncryption false" "$SUB/iosApp/NuvioTV/Info.plist"

# Build number for TestFlight (the caller passes the next free number).
if [ -n "${NEXT_BUILD_NUMBER:-}" ]; then
  sed -i '' "s/^CURRENT_PROJECT_VERSION=.*/CURRENT_PROJECT_VERSION=${NEXT_BUILD_NUMBER}/" "$SUB/iosApp/Configuration/Version.xcconfig"
fi

# local.properties: Nuvio's public backend values (from the upstream README), plus optional keys from
# the Codemagic group. Missing optional keys only leave those features empty.
{
  echo "SUPABASE_URL=https://api.nuvio.tv"
  echo "SUPABASE_ANON_KEY=sb_publishable_1Clq8rlTVACkdcZuqr6_AD__xUUC_EN"
  for k in TMDB_API_KEY TRAKT_CLIENT_ID TRAKT_CLIENT_SECRET SIMKL_CLIENT_ID MDBLIST_CLIENT_ID; do
    v="${!k:-}"; [ -n "$v" ] && echo "$k=$v"
  done
} > "$SUB/local.properties"
echo "local.properties written ($(wc -l < "$SUB/local.properties" | tr -d ' ') keys)"
