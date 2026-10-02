@echo off
rem ------------------------------------------------------------
rem  One-click build + install for the Bubu Workbench app.
rem
rem  This file is ASCII ONLY on purpose: cmd.exe reads batch files
rem  using the console code page, which is UTF-8 on some machines and
rem  GBK on others. Any non-ASCII byte here makes cmd mis-parse whole
rem  lines. All the Chinese messages live in the PowerShell script,
rem  which reads UTF-8-with-BOM reliably.
rem ------------------------------------------------------------
title Bubu Workbench - Build and Install
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\build-and-install.ps1"
echo.
pause
