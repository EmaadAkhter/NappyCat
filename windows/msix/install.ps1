# NappyCat widget install — run in an ADMIN PowerShell from this folder:
#   powershell -ExecutionPolicy Bypass -File .\install.ps1
#
# What it does, and why each step exists:
#   1. Trusts the build's self-signed certificate (no paid signing cert).
#   2. Installs the Windows App SDK runtime the widget provider needs.
#   3. Installs NappyCat.msix.
# Then: Win+W (or the Widgets button) -> "+" -> add NappyCat.
$ErrorActionPreference = "Stop"

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Error "Run this from an ADMIN PowerShell (right-click -> Run as administrator)."
}

Write-Host "Trusting the NappyCat build certificate..."
Import-Certificate -FilePath "$PSScriptRoot\NappyCat.cer" -CertStoreLocation Cert:\LocalMachine\TrustedPeople | Out-Null

if (-not (Get-AppxPackage -Name "Microsoft.WindowsAppRuntime.1.6*")) {
  Write-Host "Installing the Windows App SDK runtime..."
  $installer = "$env:TEMP\windowsappruntimeinstall-x64.exe"
  Invoke-WebRequest "https://aka.ms/windowsappsdk/1.6/latest/windowsappruntimeinstall-x64.exe" -OutFile $installer
  Start-Process $installer -ArgumentList "--quiet" -Wait
}

Write-Host "Installing NappyCat..."
Add-AppxPackage "$PSScriptRoot\NappyCat.msix"

Write-Host ""
Write-Host "Done! Press Win+W, hit '+', and add the NappyCat widget." -ForegroundColor Green
