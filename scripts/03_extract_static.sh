#!/usr/bin/env bash
# Reproduce the static findings from a jadx output folder. Usage: ./03_extract_static.sh jadx_out
# Needs: ripgrep (rg), python3.
set -euo pipefail
J="${1:-jadx_out}"

echo "== Permissions =="
grep -o 'uses-permission[^>]*android:name="[^"]*"' "$J/resources/AndroidManifest.xml" | sed 's/.*name="//;s/"//' | sort

echo "== Packages the app is allowed to see (<queries>) =="
sed -n '/<queries>/,/<\/queries>/p' "$J/resources/AndroidManifest.xml" | grep -o 'package android:name="[^"]*"' | sed 's/.*name="//;s/"//' | sort | head -80

echo "== Hosts hard-coded in first-party code (count) =="
rg -o -I --no-line-number 'https?://[A-Za-z0-9._-]+\.[a-z]{2,}' "$J/sources/com/astrotalk" | sort | uniq -c | sort -rn | head -40

echo "== Installed-app tracker: size and a sample of the list it matches against =="
python3 - "$J/resources/assets/apppackges.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1],encoding="utf8"))
print(len(d),"entries; first 10:",[x["name"] for x in d[:10]])
PY
echo "-- upload endpoint:"; rg -n -I -B1 -A1 'user/apps/installed' "$J/sources/com/astrotalk/controller/b.java"
echo "-- callers:";          rg -n -I 'u0\.a\(' "$J/sources/com/astrotalk" | head

echo "== Identifiers sent to the first-party API =="
rg -n -I 'gpsAdId=|"hardware_id"|user-device/create' "$J/sources/com/astrotalk" | cut -c1-200 | head -20

echo "== Analytics / attribution SDK initialisation =="
rg -n -I 'Clarity\.initialize|AppsFlyerLib\.getInstance\(\)\.init|setCustomerUserId|Clarity\.setCustomUserId|AdvertisingIdClient' "$J/sources/com/astrotalk/controller/AppController.java" | cut -c1-200

echo "== Cleartext / pinning config =="
cat "$J/resources/res/xml/network_security_config.xml"
rg -c 'CertificatePinner' "$J/sources/com/astrotalk" || echo "no CertificatePinner usage in first-party code"
