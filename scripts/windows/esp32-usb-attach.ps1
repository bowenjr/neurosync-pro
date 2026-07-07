<#
.SYNOPSIS
    Attach an already-bound USB device (by BUSID) to WSL.

.DESCRIPTION
    Does not guess a BUSID — pass it explicitly (see esp32-usb-list.ps1).
    The device must already be bound (esp32-usb-bind.ps1) before it can be
    attached. Re-run this after every physical reconnect/replug or WSL
    restart — attachment does not persist across those events.

.PARAMETER BusId
    The BUSID string shown by `usbipd list`, e.g. "2-4".

.EXAMPLE
    .\esp32-usb-attach.ps1 -BusId 2-4
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$BusId
)

if (-not (Get-Command usbipd -ErrorAction SilentlyContinue)) {
    Write-Error "usbipd not found on PATH. Install it from https://github.com/dorssel/usbipd-win and re-run."
    exit 1
}

Write-Host "=== usbipd list (before attach) ===" -ForegroundColor Cyan
usbipd list

Write-Host "`nAttaching BUSID $BusId to WSL ..." -ForegroundColor Yellow
usbipd attach --wsl --busid $BusId

Write-Host "`n=== usbipd list (after attach) ===" -ForegroundColor Cyan
usbipd list

Write-Host "`nAttach requested. In WSL, check with: scripts/esp32/detect.sh" -ForegroundColor Green
