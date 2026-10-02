# ============================================================
#  卜卜迷你工作台 —— 一键出 APK
#
#  这个脚本自带「便携工具链」：JDK 21 和 Android SDK 都装在工程目录下的
#  .toolchain\ 里，不动系统环境变量、不装 Android Studio，删掉目录即恢复干净。
#
#  用法：
#    powershell -ExecutionPolicy Bypass -File tools\build-apk.ps1
#    powershell -ExecutionPolicy Bypass -File tools\build-apk.ps1 -Variant release
#    powershell -ExecutionPolicy Bypass -File tools\build-apk.ps1 -ToolchainOnly
#
#  产物：
#    debug   → android\app\build\outputs\apk\debug\app-debug.apk
#    release → android\app\build\outputs\apk\release\app-release-unsigned.apk
#
#  注意：本文件必须保存为「UTF-8 带 BOM」。
# ============================================================
param(
  [ValidateSet('debug', 'release')]
  [string]$Variant = 'debug',
  [switch]$ToolchainOnly
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# Windows PowerShell 5.1 默认只协商 TLS 1.0，
# 而 Adoptium / Google 都要求 TLS 1.2 以上，不设会直接「基础连接已关闭」
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root      = Split-Path -Parent $PSScriptRoot
$toolDir   = Join-Path $root '.toolchain'
$jdkDir    = Join-Path $toolDir 'jdk21'
$sdkDir    = Join-Path $toolDir 'android-sdk'
$dlDir     = Join-Path $toolDir 'downloads'

# 想换版本只改这三行
$JDK_URL    = 'https://api.adoptium.net/v3/binary/latest/21/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk'
$SDK_MIRROR = 'https://mirrors.cloud.tencent.com/AndroidSDK'

# 刻意不用 sdkmanager：它的包源是 dl.google.com，国内实际下载速度为 0。
# 改成从腾讯镜像直接取 zip。
#
# 文件名注意：镜像上 build-tools 35 以后用的是下划线（build-tools_r35_windows.zip），
# 34 及以前是连字符（build-tools_r34-windows.zip），探测时容易搞错。
# 下面钉的是 34.0.0，和 android/app/build.gradle 里的 buildToolsVersion 对应；
# 要升到 35 就改这两处。
$SDK_PARTS = @(
  @{ File = 'platform-35_r02.zip';                Dest = 'platforms';   As = 'android-35'     },
  @{ File = 'build-tools_r34-windows.zip';        Dest = 'build-tools'; As = '34.0.0'         },
  @{ File = 'platform-tools_r35.0.0-windows.zip'; Dest = '.';           As = 'platform-tools' }
)

Add-Type -AssemblyName System.IO.Compression.FileSystem

function Write-Step([string]$text) {
  Write-Host ''
  Write-Host "==> $text" -ForegroundColor Cyan
}

function Get-File([string]$url, [string]$outFile) {
  # 只认「够大」的文件，避免上次下载中断留下的半截文件被当成完成
  if ((Test-Path $outFile) -and ((Get-Item $outFile).Length -gt 1MB)) {
    $mb = [Math]::Round((Get-Item $outFile).Length / 1MB, 1)
    Write-Host "    已存在，跳过下载：$(Split-Path -Leaf $outFile)（$mb MB）"
    return
  }
  if (Test-Path $outFile) { Remove-Item -Force $outFile }

  Write-Host "    下载中：$url"
  $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
  if ($curl) {
    # 用系统自带的 curl：它走 Schannel，TLS 协商比 PowerShell 5.1 的 .NET 栈可靠得多
    & $curl.Source -L --fail --retry 3 --retry-delay 3 -# -o $outFile $url
    if ($LASTEXITCODE -ne 0) {
      if (Test-Path $outFile) { Remove-Item -Force $outFile }
      throw "下载失败：$url（curl 退出码 $LASTEXITCODE）"
    }
  } else {
    Invoke-WebRequest -Uri $url -OutFile $outFile -TimeoutSec 1800 -UseBasicParsing
  }
  $mb = [Math]::Round((Get-Item $outFile).Length / 1MB, 1)
  Write-Host "    完成，$mb MB"
}

function Expand-Zip([string]$zip, [string]$dest) {
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $dest)
}

# ------------------------------------------------------------
#  1. JDK 21
# ------------------------------------------------------------
if (-not (Test-Path $jdkDir)) {
  Write-Step '准备 JDK 21'
  New-Item -ItemType Directory -Force -Path $dlDir | Out-Null
  $zip = Join-Path $dlDir 'jdk21.zip'
  Get-File $JDK_URL $zip

  $tmp = Join-Path $dlDir 'jdk21-extract'
  if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
  Write-Host '    解压中 ...'
  Expand-Zip $zip $tmp

  # Adoptium 的压缩包里通常只有一个 jdk-xx 顶层目录
  $inner = Get-ChildItem $tmp -Directory | Select-Object -First 1
  if (-not $inner) { throw "JDK 解压结果异常：$tmp" }
  Move-Item $inner.FullName $jdkDir
  Remove-Item -Recurse -Force $tmp
  Write-Host "    JDK 就位：$jdkDir"
}
$env:JAVA_HOME = $jdkDir
$env:PATH = (Join-Path $jdkDir 'bin') + ';' + $env:PATH
Write-Host "JAVA_HOME = $jdkDir"

# ------------------------------------------------------------
#  2. Android SDK 组件
# ------------------------------------------------------------
$env:ANDROID_HOME     = $sdkDir
$env:ANDROID_SDK_ROOT = $sdkDir

$missing = @($SDK_PARTS | Where-Object {
  -not (Test-Path (Join-Path $sdkDir (Join-Path $_.Dest $_.As)))
})

if ($missing.Count -gt 0) {
  Write-Step '准备 Android SDK 组件（约 120MB）'
  New-Item -ItemType Directory -Force -Path $dlDir | Out-Null

  foreach ($p in $missing) {
    $target = Join-Path $sdkDir (Join-Path $p.Dest $p.As)
    $zip    = Join-Path $dlDir $p.File
    Get-File "$SDK_MIRROR/$($p.File)" $zip

    Write-Host "    解压 $($p.As) ..."
    $tmp = Join-Path $dlDir ("extract_" + $p.As)
    if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
    Expand-Zip $zip $tmp

    # 官方 zip 的内层目录名各不相同（build-tools r34 解出来叫 android-14），
    # 这里统一改成 Gradle 期望的目录名
    $inner = @(Get-ChildItem $tmp -Directory)
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    if ($inner.Count -eq 1) {
      Move-Item $inner[0].FullName $target
      Remove-Item -Recurse -Force $tmp
    } else {
      Move-Item $tmp $target
    }
  }
}

foreach ($p in $SDK_PARTS) {
  $target = Join-Path $sdkDir (Join-Path $p.Dest $p.As)
  if (-not (Test-Path $target)) { throw "SDK 组件缺失：$($p.As)" }
}
Write-Host "ANDROID_HOME = $sdkDir"

if ($ToolchainOnly) {
  Write-Host ''
  Write-Host '工具链已就绪（-ToolchainOnly，未执行编译）' -ForegroundColor Green
  return
}

# ------------------------------------------------------------
#  3. 编译
# ------------------------------------------------------------
$androidDir = Join-Path $root 'android'
if (-not (Test-Path (Join-Path $androidDir 'gradlew.bat'))) {
  throw "找不到 android\gradlew.bat，请先执行：npx cap add android"
}

# 告诉 AGP 去哪找 SDK。用正斜杠，省得处理 java properties 的反斜杠转义。
# 这个文件在 .gitignore 里，属于本机生成物。
$localProps = Join-Path $androidDir 'local.properties'
$sdkForward = $sdkDir -replace '\\', '/'
"sdk.dir=$sdkForward" | Set-Content -Path $localProps -Encoding ASCII

Write-Step '同步网页资源'
Push-Location $root
& npx cap sync android
Pop-Location

# Gradle 缓存也放在工程里，保证「删目录即净」
$env:GRADLE_USER_HOME = Join-Path $toolDir 'gradle-home'

# release 同时出两个产物：APK 用来直接装手机，AAB 用来上架 Google Play
# 注意 [string[]] 强转不能省：PowerShell 会把「只有一个元素的数组」拆成字符串，
# 那样下面 @gradleArgs 展开时会按字符逐个传参，Gradle 收到一堆单字母任务名，
# 报 "Task 's' is ambiguous"。debug 分支只有一个任务，必须靠强转保住数组类型。
[string[]]$tasks = if ($Variant -eq 'release') { @('assembleRelease', 'bundleRelease') } else { @('assembleDebug') }
$gradleArgs = $tasks + '--no-daemon'
Write-Step "编译 $Variant（$($tasks -join ' + ')），首次会下载 Gradle 和依赖，约 500MB，耐心等"

Push-Location $androidDir
try {
  & .\gradlew.bat @gradleArgs
  if ($LASTEXITCODE -ne 0) { throw "Gradle 编译失败，退出码 $LASTEXITCODE" }
} finally {
  Pop-Location
}

# ------------------------------------------------------------
#  4. 汇报产物
# ------------------------------------------------------------
Write-Step '产物'
$outRoot = Join-Path $androidDir 'app\build\outputs'
Get-ChildItem $outRoot -Recurse -File -Include *.apk, *.aab -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending |
  ForEach-Object {
    $mb = [Math]::Round($_.Length / 1MB, 2)
    Write-Host ("    {0}  ({1} MB)" -f $_.FullName, $mb) -ForegroundColor Green
  }

Write-Host ''
Write-Host '装机：手机连电脑后执行  adb install -r <上面的 apk 路径>'
Write-Host '或者把 apk 拷进手机直接点开安装。'
