# NappyCat full setup. Fetched and run elevated by setup.cmd — double-click
# that, not this. Installs the app + desktop-pinned widget, and (best-effort)
# the Win+W board widget package.
$ErrorActionPreference = "Stop"
$base = "https://github.com/EmaadAkhter/NappyCat/raw/builds"
$dir = "$env:LOCALAPPDATA\NappyCat"

Write-Host "Downloading NappyCat..." -ForegroundColor Cyan
New-Item -ItemType Directory "$dir" -Force | Out-Null
Invoke-WebRequest "$base/NappyCat-windows.zip" -OutFile "$env:TEMP\NappyCat-windows.zip"
if (Test-Path "$dir\app") { Remove-Item -Recurse -Force "$dir\app" }
Expand-Archive "$env:TEMP\NappyCat-windows.zip" -DestinationPath "$dir\app"

Write-Host "Creating shortcuts..." -ForegroundColor Cyan
$ws = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath("Desktop")
$exe = "$dir\app\NappyCat.exe"

$s = $ws.CreateShortcut("$desktop\NappyCat.lnk")
$s.TargetPath = $exe; $s.Save()

$w = $ws.CreateShortcut("$desktop\NappyCat Widget.lnk")
$w.TargetPath = $exe; $w.Arguments = "--widget"; $w.Save()

# The widget greets you on every boot, like a real home-screen widget.
$startup = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$b = $ws.CreateShortcut("$startup\NappyCat Widget.lnk")
$b.TargetPath = $exe; $b.Arguments = "--widget"; $b.Save()

Write-Host "Installing the Win+W board widget (optional)..." -ForegroundColor Cyan
try {
  Invoke-WebRequest "$base/NappyCat.msix" -OutFile "$env:TEMP\NappyCat.msix"
  Invoke-WebRequest "$base/NappyCat.cer" -OutFile "$env:TEMP\NappyCat.cer"
  Import-Certificate -FilePath "$env:TEMP\NappyCat.cer" -CertStoreLocation Cert:\LocalMachine\TrustedPeople | Out-Null
  if (-not (Get-AppxPackage -Name "Microsoft.WindowsAppRuntime.1.6*")) {
    Write-Host "  fetching the Windows App SDK runtime..."
    Invoke-WebRequest "https://aka.ms/windowsappsdk/1.6/latest/windowsappruntimeinstall-x64.exe" -OutFile "$env:TEMP\war.exe"
    Start-Process "$env:TEMP\war.exe" -ArgumentList "--quiet" -Wait
  }
  Add-AppxPackage "$env:TEMP\NappyCat.msix"
  Write-Host "  board widget installed - press Win+W, hit '+', add NappyCat."
} catch {
  Write-Warning "Board widget skipped ($($_.Exception.Message)) - the desktop widget still works."
}

Write-Host "Starting the desktop cat..." -ForegroundColor Cyan
Start-Process $exe -ArgumentList "--widget"

Write-Host ""
Write-Host "Done! The cat lives on your desktop (top-right) and returns on every boot." -ForegroundColor Green
Write-Host "Desktop shortcuts: 'NappyCat' (full app) and 'NappyCat Widget'."
