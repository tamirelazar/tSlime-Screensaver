#!/bin/bash
#
# Checks that the read-only shared-preference entitlement is what lets the
# extension see the saver settings, by building the same sandboxed probe
# twice and signing one of them without the exception.
#
# This is a negative control, not a smoke test: "the entitled build can read
# the domain" proves nothing on its own, because an unentitled sandboxed
# process reading its *own* domain would look identical. The result that
# matters is the unentitled build seeing zero of the keys that are demonstrably
# there.
#
# ADR 0002 notes that everything behind that entitlement was measured ad-hoc
# signed, in a directly launched .app rather than a pkd-launched .appex. Run
# this again the first time the saver is signed with a real Developer ID and
# notarized: temporary-exception.* is the family Apple is likeliest to tighten,
# and if it has been, this is where it shows up.
#
# usage: scripts/test-settings-entitlement.sh

set -euo pipefail

DOMAIN=net.aerialscreensaver.AppexSaverMinimal
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Keys the probe looks for. Seeded here and removed again, so the script
# leaves the real settings domain exactly as it found it.
KEYS=(brailleSource brailleDotSizeFraction brailleCornerFraction)
SEEDED=()
for key in "${KEYS[@]}"; do
  if ! defaults read "$DOMAIN" "$key" >/dev/null 2>&1; then
    SEEDED+=("$key")
  fi
done
restore () {
  for key in "${SEEDED[@]:-}"; do
    [[ -n "$key" ]] && defaults delete "$DOMAIN" "$key" 2>/dev/null || true
  done
}
trap 'restore; rm -rf "$WORK"' EXIT

defaults write "$DOMAIN" brailleSource -string procedural
defaults write "$DOMAIN" brailleDotSizeFraction -float 0.78
defaults write "$DOMAIN" brailleCornerFraction -float 0.3

cat > "$WORK/probe.swift" <<'SWIFT'
import Foundation
let domain = "net.aerialscreensaver.AppexSaverMinimal"
guard let defaults = UserDefaults(suiteName: domain) else {
    print("0")
    exit(0)
}
let keys = ["brailleSource", "brailleDotSizeFraction", "brailleCornerFraction"]
print(keys.filter { defaults.object(forKey: $0) != nil }.count)
SWIFT
xcrun swiftc -O "$WORK/probe.swift" -o "$WORK/probe"

build_probe () {                      # $1 = variant, $2 = entitlements plist
  local app="$WORK/PrefProbe-$1.app"
  mkdir -p "$app/Contents/MacOS"
  cp "$WORK/probe" "$app/Contents/MacOS/PrefProbe"
  cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>PrefProbe</string>
<key>CFBundleIdentifier</key><string>net.aerialscreensaver.PrefProbe.$1</string>
<key>CFBundleName</key><string>PrefProbe</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
  codesign -f -s - --entitlements "$2" "$app" >/dev/null 2>&1
  "$app/Contents/MacOS/PrefProbe"
}

cat > "$WORK/entitled.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.security.temporary-exception.shared-preference.read-only</key>
<array><string>$DOMAIN</string></array>
</dict></plist>
PLIST
cat > "$WORK/unentitled.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>com.apple.security.app-sandbox</key><true/>
</dict></plist>
PLIST

entitled=$(build_probe entitled "$WORK/entitled.plist")
unentitled=$(build_probe unentitled "$WORK/unentitled.plist")

echo "entitled sandboxed probe:   $entitled/3 keys visible"
echo "unentitled sandboxed probe: $unentitled/3 keys visible"

status=0
if [[ "$entitled" != "3" ]]; then
  echo "FAIL: the entitled probe cannot read the settings domain." >&2
  echo "      The extension will fall back to defaults and ignore every setting." >&2
  status=1
fi
if [[ "$unentitled" != "0" ]]; then
  echo "FAIL: the unentitled probe can read the settings domain too." >&2
  echo "      The entitlement is not what is granting access, so this test proves nothing" >&2
  echo "      about the shipping build. Check for a container plist hijacking the domain." >&2
  status=1
fi

# Also check the shipping extension actually carries the exception; a probe
# passing says the platform still honours it, not that we still ask for it.
APPEX=$(find "$HOME/Library/Developer/Xcode/DerivedData" -type d \
  -path '*/Build/Products/*/AppexSaverMinimal.app/Contents/PlugIns/AppexSaverMinimalExtension.appex' \
  -print -quit 2>/dev/null || true)
if [[ -n "$APPEX" ]]; then
  if codesign -d --entitlements :- "$APPEX" 2>/dev/null | grep -q "shared-preference.read-only"; then
    echo "built extension carries the exception: yes"
  else
    echo "FAIL: the built extension is signed without the shared-preference exception." >&2
    status=1
  fi
else
  echo "note: no built extension found; run scripts/build-saver.sh to check its signature too"
fi

[[ $status -eq 0 ]] && echo "PASS: the entitlement is what grants the read."
exit $status
