# PC Health Check Toolkit

A simple Windows desktop tool with a GUI for checking on your PC's health, cleaning up junk, tidying up startup programs, spotting anything suspicious, and (if you're on a hard drive) giving your system a speed boost.

No installer, no dependencies — just two files. Everything is built from PowerShell and Windows Forms.

## Features

- **Run Diagnostics** — a read-only snapshot of disk space, memory usage, top processes by memory, and recent system errors. Nothing is changed.
- **Scan Junk Files** — checks common clutter spots (user/Windows temp folders, browser caches, Windows Update cache, Recycle Bin) and shows you the size of each. You tick the ones you want gone; nothing is deleted until you confirm.
- **Optimize Startup** — lists your startup programs, tells you which are already disabled, and lets you pick ones to turn off. Disabling only stops auto-launch on next login — it doesn't uninstall anything, and every change can be undone (registry items via Task Manager > Startup, shortcuts get moved to a `Disabled_Startup_Items` folder on your Desktop so you can drag them back).
- **Suspicious Report** — flags things worth a closer look: unsigned executables currently running, non-Microsoft scheduled tasks, unexpected `hosts` file entries, and installed Chrome extensions. This only flags anomalies, it doesn't identify confirmed threats or remove anything.
- **Speed Boost (HDD)** — a set of tweaks aimed at traditional hard drives: analyzes/defragments the C: drive, checks SysMain (Superfetch), Fast Startup, and visual effects settings. Each change asks for confirmation first, and the tool notes when a drive is detected as an SSD (where defrag isn't needed).

Every action shows you what it found before doing anything. Cleanup and disable steps only run on items you've explicitly checked and confirmed.

## How to run

1. Download or clone this repository, and keep `PC-HealthCheck-GUI.ps1` and `Launch_PC_Health_Check.bat` in the same folder — the launcher needs the script alongside it.
2. Double-click `Launch_PC_Health_Check.bat`.
3. Approve the User Account Control (UAC) prompt when it appears — the tool needs administrator rights for things like checking startup items and drive optimization. If you decline the prompt, you'll get a message box instead of a silent failure.
4. Pick an option from the GUI and follow the on-screen prompts.

## Requirements

- Windows 10 or 11
- PowerShell (included with Windows by default)
- Administrator rights (for full functionality — some diagnostics will still run without it, but with reduced detail)

## A note on security warnings

This is an unsigned PowerShell script that requests administrator elevation, so Windows SmartScreen or your antivirus may flag it or ask for confirmation before running. That's expected behavior for any unsigned script requesting elevated permissions, not a sign of malicious content — but as always, only run scripts from sources you trust, and feel free to read through `PC-HealthCheck-GUI.ps1` yourself before running it.

The `.bat` launcher uses a one-time `-ExecutionPolicy Bypass` when starting the script. This only affects that single PowerShell process and does not change your system's execution policy permanently.

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.

## Disclaimer

This tool is provided as-is, with no warranty of any kind. While it's designed to ask for confirmation before making changes, you're responsible for reviewing what it does and deciding what to run on your own system. Back up anything important before making system-level changes.
