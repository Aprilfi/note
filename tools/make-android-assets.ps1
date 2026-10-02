# ============================================================
#  生成并写入安卓原生资源：启动图标（各密度）、自适应图标分层、启动图
#
#  图案来自工程根目录的 assets\icon-source.jpg（或 .png）。
#  想换图标：替换那张源图，重跑本脚本 + make-icons.ps1 即可。
#
#  用法： powershell -ExecutionPolicy Bypass -File tools\make-android-assets.ps1
#         或  npm run android-assets
#  前提：已经执行过 npx cap add android
#
#  注意：本文件必须保存为「UTF-8 带 BOM」。
# ============================================================
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'icon-lib.ps1')

$resDir = Join-Path $root 'android\app\src\main\res'
if (-not (Test-Path $resDir)) {
    throw "找不到 $resDir，请先执行：npx cap add android"
}

$src = Initialize-IconLib -ProjectRoot $root
Write-Host "源图: $src"

# 各密度下的资源尺寸
#   Launcher  传统启动图标（API 26 以下用），完整方框可见
#   Adaptive  自适应图标画布（108dp），外侧会被遮罩切掉，只有中间 66% 保证可见
$DENSITIES = @(
    @{ Name = 'mdpi';    Launcher = 48;  Adaptive = 108 },
    @{ Name = 'hdpi';    Launcher = 72;  Adaptive = 162 },
    @{ Name = 'xhdpi';   Launcher = 96;  Adaptive = 216 },
    @{ Name = 'xxhdpi';  Launcher = 144; Adaptive = 324 },
    @{ Name = 'xxxhdpi'; Launcher = 192; Adaptive = 432 }
)

# 启动图尺寸，必须和 Capacitor 模板一致，覆盖时不能改错
$SPLASHES = @(
    @{ Dir = 'drawable';              W = 480;  H = 320  },
    @{ Dir = 'drawable-land-mdpi';    W = 480;  H = 320  },
    @{ Dir = 'drawable-land-hdpi';    W = 800;  H = 480  },
    @{ Dir = 'drawable-land-xhdpi';   W = 1280; H = 720  },
    @{ Dir = 'drawable-land-xxhdpi';  W = 1600; H = 960  },
    @{ Dir = 'drawable-land-xxxhdpi'; W = 1920; H = 1280 },
    @{ Dir = 'drawable-port-mdpi';    W = 320;  H = 480  },
    @{ Dir = 'drawable-port-hdpi';    W = 480;  H = 800  },
    @{ Dir = 'drawable-port-xhdpi';   W = 720;  H = 1280 },
    @{ Dir = 'drawable-port-xxhdpi';  W = 960;  H = 1600 },
    @{ Dir = 'drawable-port-xxxhdpi'; W = 1280; H = 1920 }
)

function Save-IconPng([int]$size, [string]$path, [string]$mode) {
    $bmp = New-IconBitmap $size $mode
    try {
        $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $bmp.Dispose()
    }
}

Write-Host '写入启动图标 ...'
foreach ($d in $DENSITIES) {
    $dir = Join-Path $resDir ("mipmap-" + $d.Name)
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    Save-IconPng $d.Launcher (Join-Path $dir 'ic_launcher.png')            'square'
    Save-IconPng $d.Launcher (Join-Path $dir 'ic_launcher_round.png')      'round'
    Save-IconPng $d.Adaptive (Join-Path $dir 'ic_launcher_foreground.png') 'foreground'
    Save-IconPng $d.Adaptive (Join-Path $dir 'ic_launcher_background.png') 'background'

    Write-Host ("  mipmap-{0,-9} 图标 {1}px / 自适应 {2}px" -f $d.Name, $d.Launcher, $d.Adaptive)
}

Write-Host '写入启动图 ...'
foreach ($s in $SPLASHES) {
    $dir = Join-Path $resDir $s.Dir
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $bmp = New-SplashBitmap $s.W $s.H
    try {
        $bmp.Save((Join-Path $dir 'splash.png'), [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $bmp.Dispose()
    }
    Write-Host ("  {0,-24} {1}x{2}" -f $s.Dir, $s.W, $s.H)
}

Write-Host ''
Write-Host '完成。改了源图记得重跑本脚本，再执行 npx cap sync android'
