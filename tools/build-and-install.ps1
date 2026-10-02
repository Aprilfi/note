# ============================================================
#  编译正式包并装到设备（一键流程）
#
#  用法：双击工程根目录的「一键编译并安装.bat」
#        或 powershell -ExecutionPolicy Bypass -File tools\build-and-install.ps1
#
#  为什么中文写在这里而不是 .bat 里：cmd.exe 读批处理文件用的是控制台代码页，
#  在 UTF-8 / GBK 之间不一致时会整行解析错乱。PowerShell 读 UTF-8 带 BOM
#  的脚本则是稳定的，所以 .bat 只做纯 ASCII 的入口。
#
#  注意：本文件必须保存为「UTF-8 带 BOM」。
# ============================================================
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

Write-Host ''
Write-Host '================================================' -ForegroundColor Cyan
Write-Host '   卜卜工作台   编译正式包并装到设备' -ForegroundColor Cyan
Write-Host '================================================' -ForegroundColor Cyan

Push-Location $root
try {
    Write-Host ''
    Write-Host '[1/2] 正在编译，约 40 秒，第一次会更久一点...' -ForegroundColor White
    Write-Host ''
    & npm run build:release
    if ($LASTEXITCODE -ne 0) {
        Write-Host ''
        Write-Host '------------------------------------------------' -ForegroundColor Red
        Write-Host ' 编译失败了。把上面的错误信息发给我看看。' -ForegroundColor Red
        Write-Host '------------------------------------------------' -ForegroundColor Red
        exit 1
    }

    Write-Host ''
    Write-Host '[2/2] 正在装到设备上...' -ForegroundColor White
    Write-Host ''
    & npm run install:release
    if ($LASTEXITCODE -ne 0) {
        Write-Host ''
        Write-Host '------------------------------------------------' -ForegroundColor Yellow
        Write-Host ' 装不上去，检查两件事：' -ForegroundColor Yellow
        Write-Host ''
        Write-Host '   1. 模拟器开着吗？桌面上那个「启动模拟器.bat」可以拉起来。'
        Write-Host ''
        Write-Host '   2. 用真机的话：USB 线插好了吗？手机「开发者选项」里的'
        Write-Host '      USB 调试打开了吗？插上后手机会弹一个「允许调试吗」，'
        Write-Host '      要点允许。'
        Write-Host '------------------------------------------------' -ForegroundColor Yellow
        exit 1
    }

    Write-Host ''
    Write-Host '================================================' -ForegroundColor Green
    Write-Host '   全部完成，可以去手机上打开看看了' -ForegroundColor Green
    Write-Host '================================================' -ForegroundColor Green
    Write-Host ''
}
finally {
    Pop-Location
}
