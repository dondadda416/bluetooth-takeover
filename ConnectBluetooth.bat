@echo off
if not exist "%~dp0device.txt" (
    echo First-time setup: pick your Bluetooth device. You will see one UAC prompt.
    echo This only happens once.
    echo.
    powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0ConnectBluetooth.ps1" -Setup
)
schtasks /query /tn "ReconnectBluetooth" >nul 2>&1
if %errorlevel% neq 0 (
    powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0ConnectBluetooth.ps1" -Setup
) else (
    schtasks /run /tn "ReconnectBluetooth" >nul 2>&1
)
