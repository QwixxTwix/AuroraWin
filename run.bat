@echo off
setlocal EnableExtensions
title AuroraWin

powershell -NoProfile -ExecutionPolicy Bypass -Command "$p = Join-Path '%~dp0' 'AuroraWin.ps1'; if (Test-Path -LiteralPath $p) { $raw = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8); $enc = New-Object System.Text.UTF8Encoding $true; [System.IO.File]::WriteAllText($p, $raw, $enc) }"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0AuroraWin.ps1"
set EXITCODE=%errorlevel%

if not "%EXITCODE%"=="0" (
    echo.
    echo AuroraWin exited with code %EXITCODE%. See logs folder for details.
    pause
)

endlocal