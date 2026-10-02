# ============================================================
#  把编译好的 APK 装到设备上
#
#  存在的意义：本机没把 adb 加进 PATH，直接敲 `adb` 会找不到命令。
#  这里自动去几个已知位置找 adb，并把对应的 APK 装上。
#
#  用法：
#    npm run install:release        装 release 包
#    npm run install:debug          装 debug 包
#    powershell -ExecutionPolicy Bypass -File tools\install-apk.ps1 -Variant release
#
#  想给 `adb` 加进 PATH 的话：
#    [Environment]::SetEnvironmentVariable('PATH',
#      [Environment]::GetEnvironmentVariable('PATH','User') + ';D:\05Software\04tools\Android\SDK\platform-tools',
#      'User')
#
#  注意：本文件必须保存为「UTF-8 带 BOM」。
# ============================================================
param(
  [ValidateSet('release', 'debug')]
  [string]$Variant = 'release'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

# ---- 找 adb ----
$candidates = @()
if ($env:ANDROID_SDK_ROOT) { $candidates += (Join-Path $env:ANDROID_SDK_ROOT 'platform-tools\adb.exe') }
if ($env:ANDROID_HOME)     { $candidates += (Join-Path $env:ANDROID_HOME     'platform-tools\adb.exe') }
$candidates += (Join-Path $root '.toolchain\android-sdk\platform-tools\adb.exe')
$candidates += 'D:\05Software\04tools\Android\SDK\platform-tools\adb.exe'

$adb = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $adb) {
  $onPath = Get-Command adb -ErrorAction SilentlyContinue
  if ($onPath) { $adb = $onPath.Source }
}
if (-not $adb) {
  throw "找不到 adb。找过这些位置：`n  $($candidates -join "`n  ")`n请装 Android SDK 的 platform-tools，或把它的路径加进 PATH。"
}

# ---- 找 APK ----
$apkName = if ($Variant -eq 'release') { 'app-release.apk' } else { 'app-debug.apk' }
$apk = Join-Path $root "android\app\build\outputs\apk\$Variant\$apkName"
if (-not (Test-Path $apk)) {
  throw "还没编译出 $Variant 包：$apk`n请先执行 npm run build:$Variant"
}

Write-Host "adb : $adb"
Write-Host "APK : $apk"
Write-Host ''

$devices = & $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '\sdevice$' }
if (-not $devices) {
  Write-Host '没有检测到设备。检查：' -ForegroundColor Yellow
  Write-Host '  - 模拟器启动了吗'
  Write-Host '  - 真机连上了吗，USB 调试开了吗'
  exit 1
}
Write-Host "检测到 $($devices.Count) 台设备："
$devices | ForEach-Object { "  $_" }
Write-Host ''

Write-Host '正在安装 ...'
& $adb install -r $apk
if ($LASTEXITCODE -ne 0) {
  Write-Host ''
  Write-Host '安装失败。如果提示 INSTALL_FAILED_UPDATE_INCOMPATIBLE，' -ForegroundColor Yellow
  Write-Host '说明设备上装的是另一种签名的包（debug 与 release 互不兼容）。' -ForegroundColor Yellow
  Write-Host '需要先卸载再装，注意这会清掉应用内的数据：' -ForegroundColor Yellow
  Write-Host "  & '$adb' uninstall com.bubu.workbench" -ForegroundColor Yellow
  exit 1
}

Write-Host ''
Write-Host '安装完成。' -ForegroundColor Green
