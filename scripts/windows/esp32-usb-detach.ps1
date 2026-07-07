<#
.SYNOPSIS
    Explicitly detach a USB device (by BUSID) from WSL.

.DESCRIPTION
    Does not guess a BUSID — pass it explicitly (see esp32-usb-list.ps1).
    Detaching does not unbind the device; it can be re-attached later with
    esp32-usb-attach.ps1 without re-binding.

.PARAMETER BusId
    The BUSID string shown by `usbipd list`, e.g. "2-4".

.EXAMPLE
    .\esp32-usb-detach.ps1 -BusId 2-4
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$BusId
)

if (-not (Get-Command usbipd -ErrorAction SilentlyContinue)) {
    Write-Error "usbipd not found on PATH. Install it from https://github.com/dorssel/usbipd-win and re-run."
    exit 1
}

Write-Host "=== usbipd list (before detach) ===" -ForegroundColor Cyan
usbipd list

Write-Host "`nDetaching BUSID $BusId ..." -ForegroundColor Yellow
usbipd detach --busid $BusId

Write-Host "`n=== usbipd list (after detach) ===" -ForegroundColor Cyan
usbipd list
