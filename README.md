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

## ⚠️ Security Warning — Read Before Running

**This is an unsigned PowerShell script. It is NOT malware, a virus, or a trojan.** It is open source — every line is visible in [`PC-HealthCheck-GUI.ps1`](PC-HealthCheck-GUI.ps1) in this repository. If you have any doubt about what it does, **read the source code yourself before running it.** Do not take anyone's word for it, including mine — verify it.

Be aware of the following, and do not report this project or open issues/reviews claiming it is malicious without first reading this section in full:

- **It requests administrator elevation.** This is required to inspect and modify startup items, run disk optimization, and check certain system settings. Requesting elevation is normal for a system-maintenance tool and is not, by itself, evidence of malicious behavior.
- **Windows SmartScreen, Defender, or third-party antivirus may flag or warn about this script.** This is expected and standard for *any* unsigned script that requests elevation — signing certificates cost money and this is a free, independently-published tool. A SmartScreen warning is not a virus detection; it is a generic "unknown publisher" notice.
- **The `.bat` launcher uses `-ExecutionPolicy Bypass`.** This affects only the single PowerShell process it starts — it does **not** alter your system's execution policy permanently, does **not** disable your antivirus, and does **not** persist after the script closes.
- **You are choosing to run this software.** Nobody is forcing you. If you are uncomfortable running unsigned scripts, or you don't understand PowerShell, **do not run this tool.**

If you still believe you've found genuinely malicious behavior after reading the source, open an Issue with the specific line number(s) in question. Vague claims of "this is a virus" without evidence will be closed.

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.

## Disclaimer — No Warranty, Use At Your Own Risk

**THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED**, including but not limited to warranties of merchantability, fitness for a particular purpose, and non-infringement. This is a free hobby project, not a commercial product, and no support or maintenance is guaranteed.

By downloading, reading, or running any file in this repository, **you agree to the following:**

- **You are solely responsible for what you run on your own machine.** Reviewing the source code before execution is your responsibility, not the author's.
- **The author is not liable for any damage, data loss, system instability, downtime, or any other direct, indirect, incidental, or consequential harm** resulting from the use, misuse, or inability to use this software — including but not limited to changes made to startup programs, deleted files, registry edits, or drive optimization operations.
- **Back up your system and any important files before running this tool.** System-level changes (startup items, registry values, disk defragmentation) carry inherent risk, even when a tool asks for confirmation first.
- **This tool is provided for personal, informational, and maintenance purposes only.** It is not a substitute for professional IT support, a licensed antivirus/anti-malware product, or a qualified technician, and the "Suspicious Report" feature does not constitute a malware scan or security guarantee of any kind.
- **No refunds, no guarantees, no exceptions.** This software is free. You are not owed compensation, support, or an apology for how it performs on your specific system.

If none of the above is acceptable to you, **do not download, run, or use this software.**
