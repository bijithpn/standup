# BreakMate Windows installer.
#
# Downloads the latest Setup.exe with Invoke-WebRequest (which does not add the
# Mark-of-the-Web, so SmartScreen does not warn) and runs it.
#
# Usage (PowerShell):
#   irm https://github.com/bijithpn/standup/releases/latest/download/install.ps1 | iex
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repo = 'bijithpn/standup'
$release = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest"
$asset = $release.assets | Where-Object { $_.name -like 'BreakMate-Setup-*.exe' } | Select-Object -First 1
if (-not $asset) { throw 'No Windows installer found in the latest release.' }

$dest = Join-Path $env:TEMP $asset.name
Write-Host "Downloading $($asset.name)..."
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $dest
Unblock-File -Path $dest

Write-Host 'Launching installer...'
Start-Process -FilePath $dest -Wait
Remove-Item $dest -Force -ErrorAction SilentlyContinue
