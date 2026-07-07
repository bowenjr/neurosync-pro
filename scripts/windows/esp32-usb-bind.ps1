<#
.SYNOPSIS
    Bind a USB device (by BUSID) for WSL passthrough. REQUIRES AN
    ADMINISTRATOR POWERSHELL WINDOW.

.DESCRIPTION
    Does not guess a BUSID — you must identify it yourself from
    esp32-usb-list.ps1 output first and pass it explicitly. Binding is a
    one-time, persistent operation per device/port; it does not attach the
    device to WSL by itself (use esp32-usb-attach.ps1 for that, each time
    the device is (re)connected).

.PARAMETER BusId
    The BUSID string shown by `usbipd list`, e.g. "2-4".

.EXAMPLE
    .\esp32-usb-bind.ps1 -BusId 2-4
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$BusId
)

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run from an Administrator PowerShell window (usbipd bind requires it)."
    exit 1
}

if (-not (Get-Command usbipd -ErrorAction SilentlyContinue)) {
    Write-Error "usbipd not found on PATH. Install it from https://github.com/dorssel/usbipd-win and re-run."
    exit 1
}

Write-Host "=== usbipd list (before bind) ===" -ForegroundColor Cyan
usbipd list

Write-Host "`nBinding BUSID $BusId ..." -ForegroundColor Yellow
usbipd bind --busid $BusId

Write-Host "`n=== usbipd list (after bind) ===" -ForegroundColor Cyan
usbipd list

Write-Host "`nBind complete. Use esp32-usb-attach.ps1 -BusId $BusId to attach it to WSL." -ForegroundColor Green
