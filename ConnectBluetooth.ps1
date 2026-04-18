# ConnectBluetooth.ps1
# Reconnects any paired Bluetooth device from phone/other source back to this PC.
# First run: select your device and complete one-time setup (one UAC prompt).
# After setup: double-click ConnectBluetooth.bat to reconnect instantly.

param([switch]$Setup, [switch]$Run)

$taskName  = "ReconnectBluetooth"
$configFile = Join-Path $PSScriptRoot "device.txt"

# ---------- SETUP ----------
if ($Setup) {

    # Elevate if not already admin
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Start-Process PowerShell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`" -Setup" -Wait
        exit
    }

    Write-Host ""
    Write-Host "  Bluetooth Device Reconnect - First-Time Setup" -ForegroundColor Cyan
    Write-Host "  =============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Searching for paired Bluetooth devices..." -ForegroundColor Gray

    $btDevices = Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue |
                 Where-Object { $_.InstanceId -match "BTHENUM\\DEV_" -and $_.FriendlyName } |
                 Select-Object FriendlyName, InstanceId |
                 Sort-Object FriendlyName

    if (-not $btDevices -or $btDevices.Count -eq 0) {
        Write-Host ""
        Write-Host "  No paired Bluetooth devices found." -ForegroundColor Red
        Write-Host "  Make sure your device is paired to this PC first." -ForegroundColor Red
        Write-Host ""
        Read-Host "  Press Enter to exit"
        exit
    }

    Write-Host ""
    Write-Host "  Paired devices found:" -ForegroundColor Green
    Write-Host ""
    for ($i = 0; $i -lt $btDevices.Count; $i++) {
        Write-Host "    [$($i+1)] $($btDevices[$i].FriendlyName)"
    }

    Write-Host ""
    $choice = Read-Host "  Enter the number next to your device (or type part of its name)"

    $selected = $null
    if ($choice -match '^\d+$') {
        $idx = [int]$choice - 1
        if ($idx -ge 0 -and $idx -lt $btDevices.Count) {
            $selected = $btDevices[$idx]
        }
    } else {
        $selected = $btDevices | Where-Object { $_.FriendlyName -like "*$choice*" } | Select-Object -First 1
    }

    if (-not $selected) {
        Write-Host ""
        Write-Host "  Could not find that device. Please try again." -ForegroundColor Red
        Write-Host ""
        Read-Host "  Press Enter to exit"
        exit
    }

    # Extract MAC address from instance ID (e.g. BTHENUM\DEV_40B3FA3161C5\...)
    $mac = [regex]::Match($selected.InstanceId, 'DEV_([A-Fa-f0-9]+)').Groups[1].Value.ToUpper()

    if (-not $mac) {
        Write-Host "  Could not read device address. Please try again." -ForegroundColor Red
        Read-Host "  Press Enter to exit"
        exit
    }

    # Save MAC to config
    $mac | Set-Content $configFile -Encoding UTF8

    Write-Host ""
    Write-Host "  Selected: $($selected.FriendlyName)" -ForegroundColor Green

    # Register scheduled task for UAC-free elevated execution
    $action    = New-ScheduledTaskAction -Execute "powershell.exe" `
                     -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive -File `"$PSCommandPath`" -Run"
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" `
                     -RunLevel Highest -LogonType Interactive
    $settings  = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 1) `
                     -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

    try {
        Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal `
            -Settings $settings -Force -ErrorAction Stop | Out-Null
    } catch {
        Write-Host ""
        Write-Host "  Failed to create scheduled task: $_" -ForegroundColor Red
        Write-Host "  Cleaning up..." -ForegroundColor Red
        Remove-Item $configFile -Force -ErrorAction SilentlyContinue
        Read-Host "  Press Enter to exit"
        exit 1
    }

    Write-Host "  Setup complete! Double-click ConnectBluetooth.bat any time to reconnect." -ForegroundColor Green
    Write-Host ""
    Start-Sleep -Seconds 3
    exit
}

# ---------- RUN ----------
if ($Run) {

    if (-not (Test-Path $configFile)) { exit 1 }
    $mac = (Get-Content $configFile -Encoding UTF8).Trim().ToUpper()
    if (-not $mac) { exit 1 }

    # Validate that the scheduled task still points to this script
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task) {
        $taskPath = $task.Actions[0].Arguments
        if ($taskPath -notlike "*$PSCommandPath*") {
            # Task points to an old/different script location — re-register
            $action    = New-ScheduledTaskAction -Execute "powershell.exe" `
                             -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive -File `"$PSCommandPath`" -Run"
            $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" `
                             -RunLevel Highest -LogonType Interactive
            $settings  = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 1) `
                             -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
            Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal `
                -Settings $settings -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }

    # Find all BTHENUM PnP entries for this device's MAC address
    $ids = Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue |
           Where-Object { $_.InstanceId.ToUpper() -match $mac } |
           Select-Object -ExpandProperty InstanceId

    if (-not $ids -or $ids.Count -eq 0) { exit 1 }

    # Disable all entries in parallel
    $procs = @()
    foreach ($id in $ids) {
        $procs += Start-Process pnputil -ArgumentList "/disable-device `"$id`"" -WindowStyle Hidden -PassThru
    }
    $procs | ForEach-Object { $_.WaitForExit() }

    Start-Sleep -Milliseconds 500

    # Enable all entries in parallel
    $procs = @()
    foreach ($id in $ids) {
        $procs += Start-Process pnputil -ArgumentList "/enable-device `"$id`"" -WindowStyle Hidden -PassThru
    }
    $procs | ForEach-Object { $_.WaitForExit() }
    exit
}
