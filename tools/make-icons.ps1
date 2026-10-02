# ============================================================
#  生成 www/icons 下的图标（PWA 清单用的那份）
#
#  图案来自工程根目录的 assets\icon-source.jpg（或 .png）。
#  想换图标：替换那张源图，重跑本脚本即可。
#
#  这里只生成 manifest.json / index.html 真正引用的尺寸（144 / 192 / 512）。
#  www/ 会被整个打进 APK，多出来的文件全是白占体积 —— 实测
#  icon-1024、icon-foreground、splash-2732 三个没人引用的文件就占了 2.6MB。
#  安卓启动图标和启动图不在这里生成，在 make-android-assets.ps1 里。
#
#  用法： powershell -ExecutionPolicy Bypass -File tools\make-icons.ps1
#         或  npm run icons
#
#  注意：本文件必须保存为「UTF-8 带 BOM」。
# ============================================================
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'icon-lib.ps1')

$src = Initialize-IconLib -ProjectRoot $root
Write-Host "源图: $src"

$outDir = Join-Path $root 'www\icons'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Save-Icon([int]$size, [string]$name, [string]$mode) {
    $bmp = New-IconBitmap $size $mode
    try {
        $bmp.Save((Join-Path $outDir $name), [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Host ("  {0,-24} {1}px" -f $name, $size)
    } finally {
        $bmp.Dispose()
    }
}

Write-Host '生成图标 ...'
Save-Icon 512 'icon-512.png' 'square'
Save-Icon 192 'icon-192.png' 'square'
Save-Icon 144 'icon-144.png' 'square'

Write-Host ''
Write-Host "完成，输出目录: $outDir"
