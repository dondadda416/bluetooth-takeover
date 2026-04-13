# Bluetooth Takeover

Skip the Bluetooth settings menu. One double-click and your PC forces your AirPods (or any Bluetooth headphones) to connect — just like your laptop does automatically when it first boots up.

---

## The Problem

You're listening to music on your phone. You sit down at your PC and want your headphones there instead. What Windows makes you do:

1. Open Settings
2. Go to Bluetooth & devices
3. Scroll to find your headphones in the list
4. Click Connect
5. Wait

Every time. It's tedious for something that should be instant.

---

## The Solution

Drop two files on your desktop. Double-click one. Your PC forces your Bluetooth device to connect — wherever it's currently connected.

---

## Setup (one time only)

1. Make sure your Bluetooth device is already **paired to your PC** (done once through Windows Bluetooth settings)
2. Put `ConnectBluetooth.bat` and `ConnectBluetooth.ps1` in the same folder
3. Double-click `ConnectBluetooth.bat`
4. A window will appear listing your paired Bluetooth devices — pick yours
5. Accept the one UAC (admin) prompt that appears

That's it. Setup never runs again.

---

## Usage

Double-click `ConnectBluetooth.bat` to force your Bluetooth device to connect to your PC — wherever it's currently connected.

The window will flash briefly and disappear. Your device will connect within a few seconds — no further interaction needed.

---

## How It Works

Windows registers every Bluetooth device as a set of PnP entries in the device tree. When another device (like your phone) holds the connection, Windows sees those entries as inactive.

This script finds all the PnP entries for your device and rapidly disables then re-enables them in parallel using `pnputil` — Windows' own built-in device management tool. This kicks the Bluetooth stack into re-establishing the connection, exactly the same way a fresh boot does automatically.

The whole cycle takes about 3–4 seconds.

---

## Requirements

- Windows 10 or 11
- Any Bluetooth device that pairs to Windows
- PowerShell (included with Windows — no install needed)
- Your device must have been **paired to your PC at least once** before using this script. This is a one-time step done through Windows Bluetooth settings. After that, this script handles all future reconnections for you.

---

## Files

| File | Purpose |
|---|---|
| `ConnectBluetooth.bat` | Double-click this to run |
| `ConnectBluetooth.ps1` | The script (keep it in the same folder as the BAT) |
| `device.txt` | Created on first run — stores your device identifier |

> `device.txt` is specific to your machine and is excluded from this repo. Running setup generates your own automatically.

---

## Works With

Tested with AirPods Pro. Should work with any Bluetooth headphones, earbuds, or speakers that pair to Windows.
