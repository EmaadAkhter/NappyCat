@echo off
:: NappyCat one-click setup. Double-click me; accept the admin prompt.
net session >nul 2>&1 || (powershell -Command "Start-Process '%~f0' -Verb RunAs" & exit /b)
curl -sL https://github.com/EmaadAkhter/NappyCat/raw/builds/setup.ps1 -o "%TEMP%\nappycat-setup.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\nappycat-setup.ps1"
echo.
pause
