# NappyCat uninstall — run from ANY PowerShell with:
#   irm https://github.com/EmaadAkhter/NappyCat/raw/builds/uninstall.ps1 | iex
# Removes the app, widgets, shortcuts, board package, and the build cert.
# KEEPS the account/pairing file, so a reinstall picks the same identity
# back up. To wipe that too:
#   & ([scriptblock]::Create((irm .../uninstall.ps1))) -Everything
param([switch]$Everything)
$ErrorActionPreference = "SilentlyContinue"

$identity = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $identity.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host "Asking for administrator rights..." -ForegroundColor Cyan
  $flag = if ($Everything) { " -Everything" } else { "" }
  Start-Process powershell -Verb RunAs -ArgumentList `
    "-NoProfile -ExecutionPolicy Bypass -Command `"& ([scriptblock]::Create((irm https://github.com/EmaadAkhter/NappyCat/raw/builds/uninstall.ps1)))$flag; pause`""
  return
}

Write-Host "Stopping NappyCat..." -ForegroundColor Cyan
Stop-Process -Name NappyCat -Force

Write-Host "Removing shortcuts..." -ForegroundColor Cyan
$desktop = [Environment]::GetFolderPath("Desktop")
Remove-Item "$desktop\NappyCat.lnk", "$desktop\NappyCat Widget.lnk" -Force
Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\NappyCat Widget.lnk" -Force

Write-Host "Removing the app..." -ForegroundColor Cyan
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\NappyCat"

Write-Host "Removing the Win+W board package + build cert..." -ForegroundColor Cyan
Get-AppxPackage -Name "NappyCat.Desktop" | Remove-AppxPackage
Get-ChildItem Cert:\LocalMachine\TrustedPeople |
  Where-Object Subject -eq "CN=NappyCat" | Remove-Item -Force

if ($Everything) {
  Write-Host "Removing the account/pairing data too..." -ForegroundColor Yellow
  Remove-Item -Recurse -Force "$env:APPDATA\com.mypeblo"
}

Write-Host ""
if ($Everything) {
  Write-Host "NappyCat is fully gone, account included." -ForegroundColor Green
} else {
  Write-Host "NappyCat removed. Pairing/account kept - reinstalling brings the same cat back." -ForegroundColor Green
}
