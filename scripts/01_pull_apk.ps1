# Pull the installed APK (base + splits) from YOUR OWN phone over adb.
# Prereq: USB debugging on, phone authorised ("adb devices" shows "device").
param(
  [string]$Adb = "adb",
  [string]$Package = "com.astrotalk",
  [string]$Out = ".\apk"
)
New-Item -ItemType Directory -Force $Out | Out-Null
& $Adb devices -l
& $Adb shell dumpsys package $Package | Select-String "versionName|versionCode|installerPackageName" | Select-Object -First 3
(& $Adb shell pm path $Package) | ForEach-Object {
  $p = ($_ -replace '^package:', '').Trim()
  & $Adb pull $p $Out
}
Get-FileHash "$Out\*.apk" -Algorithm SHA256 | Format-Table Hash, Path   # record hashes for the evidence log
