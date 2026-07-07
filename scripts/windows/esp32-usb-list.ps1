<#
.SYNOPSIS
    Read-only: list USB devices visible to usbipd, so a BUSID can be picked
    for esp32-usb-bind.ps1 / esp32-usb-attach.ps1.

.DESCRIPTION
    Does not bind, attach, or detach anything. Safe to run repeatedly.
    Requires usbipd (https://github.com/dorssel/usbipd-win) installed on
    Windows. This script itself does not install usbipd.
#>

if (-not (Get-Command usbipd -ErrorAction SilentlyContinue)) {
    Write-Error "usbipd not found on PATH. Install it from https://github.com/dorssel/usbipd-win (Windows side, not WSL) and re-run."
    exit 1
}

Write-Host "=== usbipd list ===" -ForegroundColor Cyan
usbipd list
