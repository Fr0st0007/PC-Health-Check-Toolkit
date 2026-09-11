@echo off
REM Launch PC Health Check with a one-time ExecutionPolicy Bypass (does not change system policy).
REM Hidden windows avoid a console flash; UAC cancel shows a message instead of failing silently.

powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command ^
  "try { Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0PC-HealthCheck-GUI.ps1\"' -Verb RunAs -ErrorAction Stop } catch { Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Administrator permission was not granted, so PC Health Check Toolkit could not start.', 'PC Health Check Toolkit', 'OK', 'Warning') }"

exit /b
