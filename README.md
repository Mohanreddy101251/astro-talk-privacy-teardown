# What does a popular astrology app send from your phone?
### A static + network-metadata teardown of AstroTalk (Android, v1.1.545)

An independent privacy analysis of the **AstroTalk** Android app (`com.astrotalk`, versionCode 545), done on the author's **own phone, own install, own account**. Nothing was cracked, rooted, repackaged or run through a TLS-breaking proxy, and no other user's data was touched.

> **Read this first:** these are findings from reading the app's code and from watching *which servers* it connects to. They show what the app is **built to do** and **who it talks to**. They do **not** prove what was inside any encrypted request, what AstroTalk does with data on its servers, or anything about its intent. See [DISCLAIMER.md](DISCLAIMER.md).

## TL;DR

| # | Finding | How we know |
|---|---|---|
| 1 | The app lists installed apps, matches them against a **hard-coded list of 787 apps** (OTT, fantasy/gambling, dating, trading/banking, loans, AI chatbots, **competitor astrology apps**) and uploads the matches to AstroTalk's API (`POST user/apps/installed`). It runs on first launch / after login, then at least **every 7 days**. The gating method contains no consent check. | Code, incl. gating logic read in fallback decompile. The upload itself was **not** observed on the wire. |
| 2 | **Android ID** and **Advertising ID** are sent to AstroTalk's own servers (`gpsAdId=` next to user ID and push token). | Code |
| 3 | The AstroTalk user ID is handed to **Microsoft Clarity** and **AppsFlyer**. | Code (Clarity not seen in our capture window) |
| 4 | Within ~2 s of launch, before any tap, the app contacted AppsFlyer (8 hosts), Meta, Firebase/Crashlytics, Google Analytics, OTPLESS and RudderStack; repeated on every restart. | **Observed** |
| 5 | Largest upload (~120 KB in 3.4 min) went to AstroTalk's own event-tracking server. | **Observed** |
| 6 | 18 flows / ~6.6 MB were **plain HTTP (port 80)** to `aws.astrotalk.com`. | **Observed** |
| 7 | Not requested: contacts, SMS, call log. No first-party GPS calls found (location inferred from IP). | Manifest + code |
| 8 | An AI persona ("Meera", labelled "Powered by AI") and automated chat messages exist. Whether a paid answer is human can't be determined from the app. | Code + strings |

Full detail: [REPORT.md](REPORT.md). Plain-language protection advice: [docs/SAFETY_GUIDE.md](docs/SAFETY_GUIDE.md). Tools and phone-connection steps: [docs/METHODOLOGY.md](docs/METHODOLOGY.md).

## Evidence
- [`evidence/pcapdroid_capture.csv`](evidence/pcapdroid_capture.csv): PCAPdroid export (metadata only; 139 flows, ~3.4 min, 2026-11-23). Local VPN addresses are redacted.
- [`evidence/tracked_apps_787_names.txt`](evidence/tracked_apps_787_names.txt): names in the app's installed-app watch-list.
- [`evidence/u0_gating_fallback_decompile.txt`](evidence/u0_gating_fallback_decompile.txt): listing showing the 604,800,000 ms (7-day) check.
- Source references (class/method/file) are in [REPORT.md §12](REPORT.md). The decompiled app is **not** redistributed (copyright); reproduce it from your own install.

## Reproduce
```powershell
# Phone: Developer options -> USB debugging ON, authorise the PC. Install the app from Play Store.
.\scripts\01_pull_apk.ps1 -Adb "C:\path\to\adb.exe"   # pulls base + split APKs, prints SHA-256
.\scripts\02_decompile.ps1                              # jadx -> .\jadx_out
bash scripts/03_extract_static.sh jadx_out              # permissions, hosts, trackers, identifiers
# Phone: PCAPdroid (TLS decryption OFF), target = the app, use it ~3 min, export CSV
python -I scripts/04_analyze_capture.py evidence/pcapdroid_capture.csv
```

## Scope and ethics
Own device, own account; no circumvention of certificate trust or pinning; no third-party data; SDK keys seen in the code are deliberately **not** reproduced. Findings are version-specific (1.1.545) and dated.

## Licence
Text: CC BY 4.0. Scripts: MIT. See [LICENSE](LICENSE).
