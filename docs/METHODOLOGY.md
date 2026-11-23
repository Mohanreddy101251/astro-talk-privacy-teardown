# Methodology: tools and how the phone was connected

## Tools
| Purpose | Tool |
|---|---|
| Talk to the phone | Android platform-tools (`adb`) over USB |
| Get the app | `adb shell pm path com.astrotalk` + `adb pull` (base APK + `split_config.arm64_v8a` + `split_config.xxhdpi`) |
| Decompile | JDK 17 (Microsoft OpenJDK) + **jadx 1.5.7** (CLI main class `jadx.cli.JadxCLI` from the winget fat-jar) |
| Search code | ripgrep, grep, Python 3 (`-I` isolated mode) |
| Network observation | **PCAPdroid** on the phone (local VPN, per-app filter, **TLS decryption off**, no payload capture) |

## How the phone was connected
1. Phone: Settings -> About -> tap *Build number* 7x -> Developer options -> **USB debugging ON**; USB mode *File transfer*; accept the "Allow USB debugging?" prompt.
2. PC: `adb devices -l` must show the device as `device` (not `unauthorized`).
3. Package: `adb shell pm path com.astrotalk` lists three APKs; each pulled with `adb pull`.
4. Version recorded from `dumpsys package` (1.1.545, versionCode 545, installer `com.android.vending`, targetSdk 36).
5. After the APK was pulled, static analysis needed no phone connection.

## Static analysis
- Decompile `base.apk` with jadx; read `AndroidManifest.xml`, `res/values/strings.xml`, `assets/`, and Java sources.
- Retrofit interfaces (`@GET/@POST`) and `https://api...` literals give the API surface; DTO classes give request/response fields.
- jadx could not decompile one method (`utils/u0.b`); it was read with `--decompilation-mode fallback`.
- Code is R8-obfuscated (`u0`, `b`...), so conclusions rely on strings, annotations, Kotlin class names and call sites.

## Network observation
PCAPdroid records, per connection: destination host (DNS/TLS SNI), port, protocol, bytes up/down, timestamps and app UID. It does **not** reveal request contents here. Android apps targeting recent SDKs trust only system certificates, so reading HTTPS bodies would have needed repackaging or root. That was deliberately **not** done.

## What counts as proof
- **Code proves** a behaviour exists; it doesn't prove it ran on a given device.
- **Capture proves** a connection happened and its size/time; it doesn't prove contents.
- **Neither proves** server-side behaviour or intent. Such items are labelled Unknown.
