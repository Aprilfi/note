# ============================================================
#  卜卜迷你工作台 —— 生成并写入安卓原生资源
#  覆盖：启动图标（各密度）、自适应图标分层、启动图
#
#  用法：powershell -ExecutionPolicy Bypass -File tools\make-android-assets.ps1
#  前提：已经执行过 npx cap add android
#
#  注意：本文件必须保存为「UTF-8 带 BOM」。
# ============================================================
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'
$root   = Split-Path -Parent $PSScriptRoot
$resDir = Join-Path $root 'android\app\src\main\res'

if (-not (Test-Path $resDir)) {
  throw "找不到 $resDir，请先执行：npx cap add android"
}

$FONT_FILE = 'C:\Windows\Fonts\msyhbd.ttc'
$GLYPH     = '卜'
$C_BG_TOP  = '#FFB6D5'
$C_BG_BOT  = '#E8689E'
$C_APP_BG  = '#FFF0F6'   # 启动图底色，和网页 body 一致

# 各密度下的资源尺寸
#   launcher   传统启动图标（API < 26 用）
#   adaptive   自适应图标画布（108dp），实际可见区域只有中间约 2/3
$DENSITIES = @(
  @{ Name = 'mdpi';    Launcher = 48;  Adaptive = 108 },
  @{ Name = 'hdpi';    Launcher = 72;  Adaptive = 162 },
  @{ Name = 'xhdpi';   Launcher = 96;  Adaptive = 216 },
  @{ Name = 'xxhdpi';  Launcher = 144; Adaptive = 324 },
  @{ Name = 'xxxhdpi'; Launcher = 192; Adaptive = 432 }
)

# 启动图尺寸（与 Capacitor 模板保持一致，覆盖时不能改错）
$SPLASHES = @(
  @{ Dir = 'drawable';                 W = 480;  H = 320  },
  @{ Dir = 'drawable-land-mdpi';       W = 480;  H = 320  },
  @{ Dir = 'drawable-land-hdpi';       W = 800;  H = 480  },
  @{ Dir = 'drawable-land-xhdpi';      W = 1280; H = 720  },
  @{ Dir = 'drawable-land-xxhdpi';     W = 1600; H = 960  },
  @{ Dir = 'drawable-land-xxxhdpi';    W = 1920; H = 1280 },
  @{ Dir = 'drawable-port-mdpi';       W = 320;  H = 480  },
  @{ Dir = 'drawable-port-hdpi';       W = 480;  H = 800  },
  @{ Dir = 'drawable-port-xhdpi';      W = 720;  H = 1280 },
  @{ Dir = 'drawable-port-xxhdpi';     W = 960;  H = 1600 },
  @{ Dir = 'drawable-port-xxxhdpi';    W = 1280; H = 1920 }
)

# ---------- 基础工具 ----------
function New-RoundedPath([single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
  $p = [System.Drawing.Drawing2D.GraphicsPath]::new()
  $d = $r * 2
  $p.AddArc($x,             $y,             $d, $d, 180, 90)
  $p.AddArc(($x + $w - $d), $y,             $d, $d, 270, 90)
  $p.AddArc(($x + $w - $d), ($y + $h - $d), $d, $d,   0, 90)
  $p.AddArc($x,             ($y + $h - $d), $d, $d,  90, 90)
  $p.CloseFigure()
  return $p
}

function New-Canvas([int]$w, [int]$h) {
  $bmp = [System.Drawing.Bitmap]::new($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  return @{ Bmp = $bmp; G = $g }
}

function Get-GradientBrush([System.Drawing.RectangleF]$rect) {
  return [System.Drawing.Drawing2D.LinearGradientBrush]::new(
    $rect,
    [System.Drawing.ColorTranslator]::FromHtml($C_BG_TOP),
    [System.Drawing.ColorTranslator]::FromHtml($C_BG_BOT),
    [single]60)
}

function Draw-Glyph([System.Drawing.Graphics]$g, [single]$size, [single]$ratio, [single]$dy) {
  $font = [System.Drawing.Font]::new('Microsoft YaHei', [single]($size * $ratio),
      [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
  $sf = [System.Drawing.StringFormat]::new()
  $sf.Alignment     = [System.Drawing.StringAlignment]::Center
  $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
  $rect = [System.Drawing.RectangleF]::new(0, $dy, $size, $size)
  $white = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
  $g.DrawString($GLYPH, $font, $white, $rect, $sf)
  $white.Dispose(); $font.Dispose(); $sf.Dispose()
}

function Draw-Halo([System.Drawing.Graphics]$g, [single]$size, [single]$ratio) {
  $d = $size * $ratio
  $o = ($size - $d) / 2
  $p = [System.Drawing.Drawing2D.GraphicsPath]::new()
  $p.AddEllipse($o, $o, $d, $d)
  $b = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(38, 255, 255, 255))
  $g.FillPath($b, $p)
  $b.Dispose(); $p.Dispose()
}

# ---------- 图标绘制 ----------
#  mode: square / round / foreground / background
function New-IconPng([int]$size, [string]$path, [string]$mode) {
  $c = New-Canvas $size $size
  $g = $c.G; $bmp = $c.Bmp
  try {
    $full = [System.Drawing.RectangleF]::new(0, 0, [single]$size, [single]$size)

    if ($mode -eq 'background') {
      $brush = Get-GradientBrush $full
      $g.FillRectangle($brush, $full)
      $brush.Dispose()
    }
    elseif ($mode -eq 'square') {
      $pad  = [single]($size * 0.06)
      $side = [single]($size - 2 * $pad)
      $p = New-RoundedPath $pad $pad $side $side ([single]($size * 0.22))
      $g.SetClip($p)
      $brush = Get-GradientBrush $full
      $g.FillRectangle($brush, $full)
      $brush.Dispose(); $p.Dispose()
    }
    elseif ($mode -eq 'round') {
      $p = [System.Drawing.Drawing2D.GraphicsPath]::new()
      $p.AddEllipse($full)
      $g.SetClip($p)
      $brush = Get-GradientBrush $full
      $g.FillRectangle($brush, $full)
      $brush.Dispose(); $p.Dispose()
    }
    # foreground 模式刻意不画底色，保持透明

    if ($mode -eq 'foreground') {
      # 自适应图标可见区只有中间约 2/3，所以字号和柔光都要相应收小
      Draw-Halo $g ([single]$size) ([single]0.50)
      Draw-Glyph $g ([single]$size) ([single]0.44) ([single](-$size * 0.018))
    } elseif ($mode -ne 'background') {
      Draw-Halo $g ([single]$size) ([single]0.60)
      Draw-Glyph $g ([single]$size) ([single]0.50) ([single](-$size * 0.02))
    }

    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  } finally {
    $g.Dispose(); $bmp.Dispose()
  }
}

# ---------- 启动图 ----------
function New-SplashPng([int]$w, [int]$h, [string]$path) {
  $c = New-Canvas $w $h
  $g = $c.G; $bmp = $c.Bmp
  try {
    $g.Clear([System.Drawing.ColorTranslator]::FromHtml($C_APP_BG))

    # 竖屏按宽度取基准，横屏按高度取基准，保证两种方向下比例一致
    $base = [single]([Math]::Min($w, $h))
    $logo = [single]($base * 0.30)
    $x = [single](($w - $logo) / 2)
    $y = [single](($h - $logo) / 2)

    $rect = [System.Drawing.RectangleF]::new($x, $y, $logo, $logo)
    $p = New-RoundedPath $x $y $logo $logo ([single]($logo * 0.22))
    $brush = Get-GradientBrush $rect
    $g.FillPath($brush, $p)
    $brush.Dispose(); $p.Dispose()

    # 启动图上的字形单独画（坐标系带偏移，不能直接用 Draw-Glyph）
    $font = [System.Drawing.Font]::new('Microsoft YaHei', [single]($logo * 0.50),
        [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $sf = [System.Drawing.StringFormat]::new()
    $sf.Alignment     = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $tr = [System.Drawing.RectangleF]::new($x, [single]($y - $logo * 0.02), $logo, $logo)
    $white = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
    $g.DrawString($GLYPH, $font, $white, $tr, $sf)
    $white.Dispose(); $font.Dispose(); $sf.Dispose()

    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  } finally {
    $g.Dispose(); $bmp.Dispose()
  }
}

# ============================================================
if (-not (Test-Path $FONT_FILE)) {
  throw "找不到字体 $FONT_FILE，请确认系统已安装微软雅黑"
}

Write-Host '写入启动图标 ...'
foreach ($d in $DENSITIES) {
  $dir = Join-Path $resDir ("mipmap-" + $d.Name)
  New-Item -ItemType Directory -Force -Path $dir | Out-Null

  New-IconPng $d.Launcher (Join-Path $dir 'ic_launcher.png')          'square'
  New-IconPng $d.Launcher (Join-Path $dir 'ic_launcher_round.png')    'round'
  New-IconPng $d.Adaptive (Join-Path $dir 'ic_launcher_foreground.png') 'foreground'
  New-IconPng $d.Adaptive (Join-Path $dir 'ic_launcher_background.png') 'background'

  Write-Host ("  mipmap-{0,-9} 图标 {1}px / 自适应 {2}px" -f $d.Name, $d.Launcher, $d.Adaptive)
}

Write-Host '写入启动图 ...'
foreach ($s in $SPLASHES) {
  $dir = Join-Path $resDir $s.Dir
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  New-SplashPng $s.W $s.H (Join-Path $dir 'splash.png')
  Write-Host ("  {0,-24} {1}x{2}" -f $s.Dir, $s.W, $s.H)
}

Write-Host ''
Write-Host '完成。改了配色记得重跑本脚本，再执行 npx cap sync android'
