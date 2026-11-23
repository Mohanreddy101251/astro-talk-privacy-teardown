# Decompile base.apk with jadx (static analysis only, nothing is executed).
# Prereq: JDK 17+, jadx (winget install Skylot.jadx; the winget package ships only the GUI fat-jar,
# so we call the CLI main class from that jar).
param(
  [string]$Apk = ".\apk\base.apk",
  [string]$Out = ".\jadx_out",
  [string]$JadxJar = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Skylot.jadx_Microsoft.Winget.Source_8wekyb3d8bbwe\lib\jadx-gui-1.5.7-all.jar"
)
$java = (Get-Command java -ErrorAction Stop).Source
& $java -Xmx6g -cp $JadxJar jadx.cli.JadxCLI -j 4 --no-debug-info -d $Out $Apk

# Optional: a method jadx fails to decompile can still be read in fallback mode, e.g. the weekly gating logic:
#   java -cp $JadxJar jadx.cli.JadxCLI --single-class com.astrotalk.utils.u0 `
#        --single-class-output u0_fallback.java --decompilation-mode fallback .\apk\base.apk
