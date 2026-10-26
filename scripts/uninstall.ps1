# BreakMate Windows uninstaller: runs the Inno Setup uninstaller.
#
# Usage (PowerShell):
#   irm https://github.com/bijithpn/standup/releases/latest/download/uninstall.ps1 | iex
$ErrorActionPreference = 'Stop'

Get-Process -Name 'BreakMateApp' -ErrorAction SilentlyContinue | Stop-Process -Force

$keys = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
$entry = Get-ItemProperty $keys -ErrorAction SilentlyContinue |
  Where-Object { $_.DisplayName -eq 'BreakMate' } | Select-Object -First 1

if (-not $entry -or -not $entry.UninstallString) { throw 'BreakMate is not installed.' }

Write-Host 'Uninstalling BreakMate...'
Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', "`"$($entry.UninstallString)`" /SILENT" -Wait
Write-Host 'BreakMate uninstalled.'
