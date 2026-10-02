# ============================================================
#  图标绘制共用库
#  被 make-icons.ps1（生成 www/icons）和 make-android-assets.ps1
#  （写入安卓 res）点源引用，避免两边画法不一致。
#
#  注意：本文件必须保存为「UTF-8 带 BOM」。
# ============================================================
Add-Type -AssemblyName System.Drawing

$Script:IconSourceFile = $null
$Script:IconSource     = $null

# 源图的背景不是纯色，而是从上到下的蓝色渐变。
# 实测：上边沿约 #2D7EE3，下边沿约 #388FEE。
#
# 这两色必须和源图匹配，否则源图贴上去时四边会露出一圈颜色不同的方块边界。
# 换图标时记得重新采样（tools 目录里没有现成工具，用取色器看一眼四边即可）。
$Script:IconBgTop    = '#2D7EE3'
$Script:IconBgBottom = '#388FEE'

# 启动页底色，跟网页 body 一致
$Script:SplashBgHex = '#FFF0F6'

# 主体在图标中的宽度占比。
#
# 源图里仓鼠本身占画布 81%，而安卓自适应图标只保证中间 66% 可见
# （外侧会被圆形或方形遮罩切掉）。所以：
#   普通图标   0.86 -> 主体占 0.86 * 0.865 = 74%，完整方框可见，放得下
#   自适应前景 0.77 -> 主体占 0.77 * 0.865 = 67%，正好落在安全区内，耳朵和脚不会被切
$Script:IconFitNormal   = 0.86
$Script:IconFitAdaptive = 0.77

function Initialize-IconLib {
    param([Parameter(Mandatory = $true)][string]$ProjectRoot)

    foreach ($rel in @('assets\icon-source.png', 'assets\icon-source.jpg', 'assets\icon-source.jpeg')) {
        $p = Join-Path $ProjectRoot $rel
        if (Test-Path $p) { $Script:IconSourceFile = $p; break }
    }
    if (-not $Script:IconSourceFile) {
        throw "找不到图标源图。请把图片放到 $ProjectRoot\assets\icon-source.png（或 .jpg）"
    }
    $Script:IconSource = [System.Drawing.Image]::FromFile($Script:IconSourceFile)
    return $Script:IconSourceFile
}

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

function New-IconCanvas([int]$w, [int]$h) {
    $bmp = [System.Drawing.Bitmap]::new($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    # 必须用 Bilinear 而不是 Bicubic：bicubic 有负瓣，在源图矩形边界会产生
    # 一圈亮的过冲像素（实测 #3490FD 这类），贴在同色背景上反而看出接缝。
    $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBilinear
    $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    return @{ Bmp = $bmp; G = $g }
}

# 源图在 size x size 画布上、按 fit 比例居中绘制时所占的矩形
function Get-IconSubjectRect([single]$size, [single]$fit) {
    if (-not $Script:IconSource) { throw '请先调用 Initialize-IconLib' }
    $s  = $Script:IconSource
    $dw = [single]($size * $fit)
    $dh = [single]($dw * $s.Height / $s.Width)
    return [System.Drawing.RectangleF]::new(
        [single](($size - $dw) / 2), [single](($size - $dh) / 2), $dw, $dh)
}

# 填充背景。
#
# $gradRect 传源图将要占据的范围：渐变只在这一段内铺开，速率就和源图自身的
# 背景渐变一致，源图边界两侧颜色才对得上，看不出方块接缝。
# $gradRect 上下两侧用端点纯色补满。
#
# 为什么分三段而不是给画刷设 WrapMode=Clamp：GDI+ 的 LinearGradientBrush
# 不接受 Clamp（会抛 "Parameter is not valid"），默认是 Tile，会重复铺开。
function Fill-IconBg([System.Drawing.Graphics]$g, [System.Drawing.RectangleF]$canvas, [System.Drawing.RectangleF]$gradRect) {
    $cTop = [System.Drawing.ColorTranslator]::FromHtml($Script:IconBgTop)
    $cBot = [System.Drawing.ColorTranslator]::FromHtml($Script:IconBgBottom)

    $bTop = New-Object System.Drawing.SolidBrush $cTop
    $bBot = New-Object System.Drawing.SolidBrush $cBot

    # 渐变带要横跨整幅画布（否则图片左右两侧会留空），
    # 但纵向范围取 gradRect 的，这样渐变速率才和源图自身的背景一致。
    $band  = [System.Drawing.RectangleF]::new($canvas.Left, $gradRect.Top, $canvas.Width, $gradRect.Height)
    $bGrad = [System.Drawing.Drawing2D.LinearGradientBrush]::new($band, $cTop, $cBot, [single]90)

    $topH = [single][Math]::Max(0, $gradRect.Top - $canvas.Top)
    if ($topH -gt 0) { $g.FillRectangle($bTop, $canvas.Left, $canvas.Top, $canvas.Width, $topH) }

    $g.FillRectangle($bGrad, $band)

    $botY = $gradRect.Bottom
    $botH = [single][Math]::Max(0, $canvas.Bottom - $botY)
    if ($botH -gt 0) { $g.FillRectangle($bBot, $canvas.Left, $botY, $canvas.Width, $botH) }

    $bTop.Dispose(); $bBot.Dispose(); $bGrad.Dispose()
}

function Draw-IconSubject([System.Drawing.Graphics]$g, [single]$size, [single]$fit) {
    $g.DrawImage($Script:IconSource, (Get-IconSubjectRect $size $fit))
}

# 生成一张图标位图
#   mode = square      圆角方块 + 渐变底 + 主体
#          round       圆形 + 渐变底 + 主体
#          foreground  透明底，只画主体（安卓自适应图标前景层）
#          background  渐变底铺满（自适应图标背景层，和前景层的 0.77 配套）
function New-IconBitmap([int]$size, [string]$mode) {
    $c = New-IconCanvas $size $size
    $g = $c.G; $bmp = $c.Bmp

    $full = [System.Drawing.RectangleF]::new(0, 0, [single]$size, [single]$size)

    switch ($mode) {
        'background' {
            Fill-IconBg $g $full (Get-IconSubjectRect $size $Script:IconFitAdaptive)
        }
        'square' {
            $pad  = [single]($size * 0.05)
            $side = [single]($size - 2 * $pad)
            $path = New-RoundedPath $pad $pad $side $side ([single]($size * 0.22))
            $g.SetClip($path)
            Fill-IconBg $g $full (Get-IconSubjectRect $size $Script:IconFitNormal)
            Draw-IconSubject $g ([single]$size) ([single]$Script:IconFitNormal)
            $g.ResetClip()
            $path.Dispose()
        }
        'round' {
            $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
            $path.AddEllipse($full)
            $g.SetClip($path)
            Fill-IconBg $g $full (Get-IconSubjectRect $size $Script:IconFitNormal)
            Draw-IconSubject $g ([single]$size) ([single]$Script:IconFitNormal)
            $g.ResetClip()
            $path.Dispose()
        }
        'foreground' {
            Draw-IconSubject $g ([single]$size) ([single]$Script:IconFitAdaptive)
        }
        default { throw "未知 mode: $mode" }
    }

    $g.Dispose()
    return $bmp
}

# 启动图：纯色底 + 居中的圆角图标块
function New-SplashBitmap([int]$w, [int]$h) {
    $c = New-IconCanvas $w $h
    $g = $c.G; $bmp = $c.Bmp

    $g.Clear([System.Drawing.ColorTranslator]::FromHtml($Script:SplashBgHex))

    $base = [single]([Math]::Min($w, $h))
    $side = [single]($base * 0.30)
    $x = [single](($w - $side) / 2)
    $y = [single](($h - $side) / 2)
    $radius = [single]($side * 0.22)

    # 源图在方块内的位置，渐变要按这个范围算
    $s = $Script:IconSource
    $dw = [single]($side * $Script:IconFitNormal)
    $dh = [single]($dw * $s.Height / $s.Width)
    $rect = [System.Drawing.RectangleF]::new(
        [single]($x + ($side - $dw) / 2), [single]($y + ($side - $dh) / 2), $dw, $dh)

    $path = New-RoundedPath $x $y $side $side $radius
    $g.SetClip($path)
    Fill-IconBg $g ([System.Drawing.RectangleF]::new(0, 0, [single]$w, [single]$h)) $rect
    $g.DrawImage($s, $rect)
    $g.ResetClip()
    $path.Dispose()
    $g.Dispose()
    return $bmp
}
