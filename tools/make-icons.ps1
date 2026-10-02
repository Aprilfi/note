# ============================================================
#  卜卜迷你工作台 —— 图标 / 启动图生成
#  依赖：Windows 自带 .NET (System.Drawing)，无需安装任何东西
#  用法：powershell -ExecutionPolicy Bypass -File tools\make-icons.ps1
#
#  注意：本文件必须保存为「UTF-8 带 BOM」。否则 Windows PowerShell 5.1
#        会按 GBK 解析中文，直接报语法错误。
# ============================================================
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'
$root   = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root 'www\icons'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$FONT_FILE = 'C:\Windows\Fonts\msyhbd.ttc'   # 微软雅黑 Bold
$GLYPH     = '卜'
$C_BG_TOP  = '#FFB6D5'
$C_BG_BOT  = '#E8689E'

# ---------- 小工具 ----------
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

function New-Canvas([int]$size) {
  $bmp = [System.Drawing.Bitmap]::new($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  return @{ Bmp = $bmp; G = $g }
}

function Get-GlyphFont([single]$px) {
  # GraphicsUnit::Pixel —— 按像素给字号，结果不随 DPI 变化
  return [System.Drawing.Font]::new('Microsoft YaHei', $px,
      [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
}

function New-CenterFormat {
  $sf = [System.Drawing.StringFormat]::new()
  $sf.Alignment     = [System.Drawing.StringAlignment]::Center
  $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
  return $sf
}

function Get-GradientBrush([System.Drawing.RectangleF]$rect) {
  return [System.Drawing.Drawing2D.LinearGradientBrush]::new(
    $rect,
    [System.Drawing.ColorTranslator]::FromHtml($C_BG_TOP),
    [System.Drawing.ColorTranslator]::FromHtml($C_BG_BOT),
    [single]60)
}

# ------------------------------------------------------------
#  1. 主图标：粉色圆角方块 + 白色「卜」
#     $transparentBg = $true 时只画字形，用作安卓自适应图标前景层
# ------------------------------------------------------------
function New-Icon([int]$size, [string]$path, [bool]$transparentBg) {
  $c = New-Canvas $size
  $g = $c.G; $bmp = $c.Bmp
  try {
    $pad  = [single]($size * 0.06)
    $side = [single]($size - 2 * $pad)
    $rect = [System.Drawing.RectangleF]::new($pad, $pad, $side, $side)

    if (-not $transparentBg) {
      $radius = [single]($size * 0.22)
      $p = New-RoundedPath $rect.X $rect.Y $rect.Width $rect.Height $radius
      $brush = Get-GradientBrush $rect
      $g.FillPath($brush, $p)
      $brush.Dispose(); $p.Dispose()
    }

    # 中央柔光，让字形浮起来
    $haloD = [single]($size * 0.60)
    $haloX = [single](($size - $haloD) / 2)
    $halo  = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $halo.AddEllipse($haloX, $haloX, $haloD, $haloD)
    $haloBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(38, 255, 255, 255))
    $g.FillPath($haloBrush, $halo)
    $haloBrush.Dispose(); $halo.Dispose()

    # 字形（CJK 字形基线偏下，整体略微上移做视觉居中）
    $font = Get-GlyphFont ([single]($size * 0.50))
    $sf   = New-CenterFormat
    $tr   = [System.Drawing.RectangleF]::new(0, [single](-$size * 0.02), [single]$size, [single]$size)
    $white = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
    $g.DrawString($GLYPH, $font, $white, $tr, $sf)
    $white.Dispose(); $font.Dispose(); $sf.Dispose()

    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host ("  {0}  ({1}px)" -f (Split-Path -Leaf $path), $size)
  } finally {
    $g.Dispose(); $bmp.Dispose()
  }
}

# ------------------------------------------------------------
#  2. 纯色背景层（安卓自适应图标要求单独一层，必须铺满无留白）
# ------------------------------------------------------------
function New-BgLayer([int]$size, [string]$path) {
  $c = New-Canvas $size
  $g = $c.G; $bmp = $c.Bmp
  try {
    $rect = [System.Drawing.RectangleF]::new(0, 0, [single]$size, [single]$size)
    $brush = Get-GradientBrush $rect
    $g.FillRectangle($brush, $rect)
    $brush.Dispose()
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host ("  {0}  ({1}px)" -f (Split-Path -Leaf $path), $size)
  } finally {
    $g.Dispose(); $bmp.Dispose()
  }
}

# ------------------------------------------------------------
#  3. 启动图：底色 + 居中圆角图标
# ------------------------------------------------------------
function New-Splash([int]$size, [string]$path) {
  $c = New-Canvas $size
  $g = $c.G; $bmp = $c.Bmp
  try {
    $g.Clear([System.Drawing.ColorTranslator]::FromHtml('#FFF0F6'))

    $logo = [single]($size * 0.30)
    $x = [single](($size - $logo) / 2)
    $y = $x

    $rect = [System.Drawing.RectangleF]::new($x, $y, $logo, $logo)
    $p = New-RoundedPath $x $y $logo $logo ([single]($logo * 0.22))
    $brush = Get-GradientBrush $rect
    $g.FillPath($brush, $p)
    $brush.Dispose(); $p.Dispose()

    $font = Get-GlyphFont ([single]($logo * 0.50))
    $sf   = New-CenterFormat
    $tr   = [System.Drawing.RectangleF]::new($x, [single]($y - $logo * 0.02), $logo, $logo)
    $white = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
    $g.DrawString($GLYPH, $font, $white, $tr, $sf)
    $white.Dispose(); $font.Dispose(); $sf.Dispose()

    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host ("  {0}  ({1}px)" -f (Split-Path -Leaf $path), $size)
  } finally {
    $g.Dispose(); $bmp.Dispose()
  }
}

# ============================================================
if (-not (Test-Path $FONT_FILE)) {
  throw "找不到字体 $FONT_FILE，请确认系统已安装微软雅黑"
}

Write-Host '生成图标 ...'
New-Icon 1024 (Join-Path $outDir 'icon-1024.png') $false
New-Icon  512 (Join-Path $outDir 'icon-512.png')  $false
New-Icon  192 (Join-Path $outDir 'icon-192.png')  $false
New-Icon  144 (Join-Path $outDir 'icon-144.png')  $false

Write-Host '生成安卓自适应图标分层 ...'
New-Icon 1024 (Join-Path $outDir 'icon-foreground.png') $true
New-BgLayer 1024 (Join-Path $outDir 'icon-background.png')

Write-Host '生成启动图 ...'
New-Splash 2732 (Join-Path $outDir 'splash-2732.png')
New-Splash  512 (Join-Path $outDir 'splash-512.png')

Write-Host ''
Write-Host ("完成，输出目录：$outDir")
