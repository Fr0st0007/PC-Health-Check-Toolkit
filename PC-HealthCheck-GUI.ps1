<#
.SYNOPSIS
    PC Health Check Toolkit - GUI.
    Diagnose, clean junk, optimize startup, and flag suspicious items.
    Destructive steps only run after you check items and confirm.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Media

try { [System.Windows.Forms.Application]::EnableVisualStyles() } catch {}
try { [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false) } catch {}
try { [System.Windows.Forms.Application]::SetHighDpiMode([System.Windows.Forms.HighDpiMode]::PerMonitorV2) | Out-Null } catch {}

# Custom rounded button with anti-aliased paint and hover animation.
# Falls back to a standard Button if this type cannot be compiled.
try {
Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace SmoothUI
{
    public class GlowButton : Button
    {
        public Color BaseColor;
        public Color HoverColor;
        public Color PressColor;
        public Color BackdropColor = Color.FromArgb(16, 18, 36);
        public int CornerRadius = 14;

        private Color currentColor;
        private Color targetColor;
        private bool hasCurrent = false;
        private bool isPressed = false;
        private Timer animTimer;

        public GlowButton()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
            FlatStyle = FlatStyle.Flat;
            FlatAppearance.BorderSize = 0;
            ForeColor = Color.White;
            Cursor = Cursors.Hand;
            animTimer = new Timer();
            animTimer.Interval = 15;
            animTimer.Tick += AnimTimer_Tick;
        }

        public void SetPalette(Color baseColor, Color hoverColor, Color pressColor)
        {
            BaseColor = baseColor;
            HoverColor = hoverColor;
            PressColor = pressColor;
            currentColor = baseColor;
            hasCurrent = true;
            Invalidate();
        }

        protected override void OnMouseEnter(EventArgs e)
        {
            base.OnMouseEnter(e);
            targetColor = HoverColor;
            animTimer.Start();
        }

        protected override void OnMouseLeave(EventArgs e)
        {
            base.OnMouseLeave(e);
            isPressed = false;
            targetColor = BaseColor;
            animTimer.Start();
            Invalidate();
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            base.OnMouseDown(e);
            isPressed = true;
            targetColor = PressColor;
            animTimer.Start();
            Invalidate();
        }

        protected override void OnMouseUp(MouseEventArgs e)
        {
            base.OnMouseUp(e);
            isPressed = false;
            bool inside = ClientRectangle.Contains(e.Location);
            targetColor = inside ? HoverColor : BaseColor;
            animTimer.Start();
            Invalidate();
        }

        private void AnimTimer_Tick(object sender, EventArgs e)
        {
            if (!hasCurrent) { currentColor = BaseColor; hasCurrent = true; }
            int r = StepChannel(currentColor.R, targetColor.R);
            int g = StepChannel(currentColor.G, targetColor.G);
            int b = StepChannel(currentColor.B, targetColor.B);
            currentColor = Color.FromArgb(r, g, b);
            Invalidate();
            if (r == targetColor.R && g == targetColor.G && b == targetColor.B)
            {
                animTimer.Stop();
            }
        }

        private int StepChannel(int from, int to)
        {
            int diff = to - from;
            if (diff == 0) return to;
            if (Math.Abs(diff) <= 3) return to;
            return from + (int)(diff * 0.35);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            if (Width <= 0 || Height <= 0) return;
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.Clear(BackdropColor);

            Rectangle rect = new Rectangle(1, 1, Width - 3, Height - 3);
            if (isPressed)
            {
                rect.Inflate(-1, -1);
                rect.Offset(0, 1);
            }
            if (rect.Width < 2 || rect.Height < 2) return;

            Color fill = hasCurrent ? currentColor : BaseColor;

            using (GraphicsPath path = RoundedPath(rect, CornerRadius))
            {
                using (SolidBrush brush = new SolidBrush(fill))
                {
                    g.FillPath(brush, path);
                }

                Rectangle topHalf = new Rectangle(rect.X, rect.Y, rect.Width, Math.Max(1, rect.Height / 2));
                using (LinearGradientBrush glow = new LinearGradientBrush(topHalf, Color.FromArgb(65, 255, 255, 255), Color.FromArgb(0, 255, 255, 255), LinearGradientMode.Vertical))
                {
                    Region oldClip = g.Clip;
                    g.SetClip(path, CombineMode.Replace);
                    g.FillRectangle(glow, rect);
                    g.Clip = oldClip;
                }

                using (Pen edge = new Pen(Color.FromArgb(50, 255, 255, 255), 1f))
                {
                    g.DrawPath(edge, path);
                }
            }

            TextRenderer.DrawText(g, Text, Font, rect, ForeColor, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
        }

        private GraphicsPath RoundedPath(Rectangle r, int radius)
        {
            int d = radius * 2;
            if (d > r.Width) d = Math.Max(2, r.Width);
            if (d > r.Height) d = Math.Max(2, r.Height);
            GraphicsPath path = new GraphicsPath();
            path.AddArc(r.X, r.Y, d, d, 180, 90);
            path.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            path.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
            path.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            path.CloseFigure();
            return path;
        }
    }
}
"@
} catch {}

Add-Type -Name Window -Namespace ConsoleHider -MemberDefinition '
[System.Runtime.InteropServices.DllImport("kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'
try {
    $consolePtr = [ConsoleHider.Window]::GetConsoleWindow()
    if ($consolePtr -ne [IntPtr]::Zero) { [ConsoleHider.Window]::ShowWindow($consolePtr, 0) | Out-Null }
} catch {}

# Synthesize short WAV clicks in memory (non-blocking; no audio files).
function New-ClickSound {
    param(
        [double[]]$Tones,
        [int]$SegMs = 30,
        [int]$GapMs = 18,
        [double]$NoiseMix = 0.10,
        [double]$Decay = 20.0,
        [double]$AttackMs = 1.5,
        [double]$PitchDrop = 0.35,
        [double]$Gain = 0.55,
        [double]$BodyFreq = 0,
        [double]$BodyMix = 0.4,
        [double]$BodyDecay = 10.0,
        [double]$ReleaseMs = 4.0
    )
    $sampleRate = 22050
    $segSamples = [int]($sampleRate * $SegMs / 1000.0)
    $gapSamples = [int]($sampleRate * $GapMs / 1000.0)
    $attackSamples = [Math]::Max(1, [int]($sampleRate * $AttackMs / 1000.0))
    $releaseSamples = [Math]::Max(1, [int]($sampleRate * $ReleaseMs / 1000.0))
    $rand = New-Object System.Random(42)
    $prevNoise = 0.0

    $data = New-Object System.Collections.Generic.List[byte]
    for ($t = 0; $t -lt $Tones.Count; $t++) {
        $freq = $Tones[$t]
        $bodyFreqCur = if ($BodyFreq -gt 0) { $BodyFreq } else { $freq * 0.5 }
        $phase = 0.0
        $bodyPhase = 0.0
        for ($i = 0; $i -lt $segSamples; $i++) {
            $time = $i / $sampleRate
            $env = [Math]::Exp(-$Decay * $time)
            $bodyEnv = [Math]::Exp(-$BodyDecay * $time)
            $attackEnv = if ($i -lt $attackSamples) { $i / [double]$attackSamples } else { 1.0 }
            $samplesLeft = $segSamples - $i
            $releaseEnv = if ($samplesLeft -le $releaseSamples) { [double]$samplesLeft / $releaseSamples } else { 1.0 }

            $curFreq = $freq * (1 + $PitchDrop * $env)
            $phase += 2 * [Math]::PI * $curFreq / $sampleRate
            $tone = [Math]::Sin($phase)
            $noiseRaw = ($rand.NextDouble() * 2 - 1)
            $noise = ($noiseRaw * 0.3) + ($prevNoise * 0.7)
            $prevNoise = $noise
            $tap = (($tone * (1 - $NoiseMix)) + ($noise * $NoiseMix)) * $env

            $bodyPhase += 2 * [Math]::PI * $bodyFreqCur / $sampleRate
            $body = [Math]::Sin($bodyPhase) * $bodyEnv

            $sample = (($tap * (1 - $BodyMix)) + ($body * $BodyMix)) * $attackEnv * $releaseEnv * $Gain
            if ($sample -gt 1.0) { $sample = 1.0 }
            if ($sample -lt -1.0) { $sample = -1.0 }
            $intSample = [int16]($sample * 32000)
            $bytes = [BitConverter]::GetBytes($intSample)
            $data.Add($bytes[0]) | Out-Null
            $data.Add($bytes[1]) | Out-Null
        }
        if ($t -lt $Tones.Count - 1) {
            for ($gI = 0; $gI -lt $gapSamples; $gI++) { $data.Add(0) | Out-Null; $data.Add(0) | Out-Null }
        }
    }

    $pcm = $data.ToArray()
    $byteRate = $sampleRate * 2
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF"))
    $bw.Write([int](36 + $pcm.Length))
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("WAVE"))
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("fmt "))
    $bw.Write([int]16)
    $bw.Write([int16]1)
    $bw.Write([int16]1)
    $bw.Write([int]$sampleRate)
    $bw.Write([int]$byteRate)
    $bw.Write([int16]2)
    $bw.Write([int16]16)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("data"))
    $bw.Write([int]$pcm.Length)
    $bw.Write($pcm)
    $bw.Flush()
    $ms.Position = 0

    $player = New-Object System.Media.SoundPlayer
    $player.Stream = $ms
    try { $player.Load() } catch {}
    return $player
}

$script:sndBlip    = New-ClickSound -Tones @(260)       -SegMs 12 -Decay 55 -NoiseMix 0.06 -PitchDrop 0.15 -AttackMs 0.8 -Gain 0.30 -BodyFreq 150 -BodyMix 0.22 -BodyDecay 26
$script:sndSuccess = New-ClickSound -Tones @(240, 300)  -SegMs 14 -GapMs 10 -Decay 45 -NoiseMix 0.05 -PitchDrop 0.12 -AttackMs 0.8 -Gain 0.32 -BodyFreq 160 -BodyMix 0.20 -BodyDecay 22
$script:sndWarning = New-ClickSound -Tones @(220)       -SegMs 28 -Decay 26 -NoiseMix 0.07 -PitchDrop 0.10 -AttackMs 1.2 -Gain 0.30 -BodyFreq 135 -BodyMix 0.28 -BodyDecay 15
$script:sndError   = New-ClickSound -Tones @(210, 170)  -SegMs 26 -GapMs 9  -Decay 26 -NoiseMix 0.07 -PitchDrop 0.10 -AttackMs 1.2 -Gain 0.34 -BodyFreq 120 -BodyMix 0.30 -BodyDecay 15

function Play-Blip    { try { $script:sndBlip.Play() } catch {} }
function Play-Success { try { $script:sndSuccess.Play() } catch {} }
function Play-Warning { try { $script:sndWarning.Play() } catch {} }
function Play-Error   { try { $script:sndError.Play() } catch {} }

function Format-Bytes($bytes) {
    if ($bytes -ge 1GB) { return "{0:N2} GB" -f ($bytes / 1GB) }
    elseif ($bytes -ge 1MB) { return "{0:N2} MB" -f ($bytes / 1MB) }
    elseif ($bytes -ge 1KB) { return "{0:N2} KB" -f ($bytes / 1KB) }
    else { return "$bytes B" }
}

function Get-FolderSize($path) {
    if (Test-Path $path) {
        $size = (Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        return [long]($size)
    }
    return 0
}

function Test-IsAdmin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$script:StartupKnowledge = @{
    "onedrivesetup"      = "Microsoft OneDrive's first-run setup helper. Safe to disable - your existing OneDrive sync (if any) is a separate process and won't be affected."
    "jagex"              = "Launcher for Jagex games (RuneScape/Old School RuneScape). Only needed if you play those games."
    "blitz"              = "Blitz.gg - overlay/coaching app for games like League of Legends. Purely optional, launches on demand otherwise."
    "epicgameslauncher"  = "Epic Games Store launcher. Only needed automatically if you play Epic games right after logging in."
    "player2"            = "A game-related helper/launcher process tied to a specific game or mod tool."
    "curseforge"         = "CurseForge - mod manager for Minecraft and other games. Only needed when you're about to mod/launch a game."
    "lghub"              = "Logitech G HUB - manages Logitech mice/keyboards/lighting. If you use a Logitech gaming mouse/keyboard, keep this one - some lighting/DPI settings depend on it running."
    "proton vpn"         = "Proton VPN client. Keep if you want VPN protection active as soon as you log in; disable if you only turn the VPN on when needed."
    "riotclient"         = "Riot Games client (League of Legends, Valorant). Only needed automatically if you play right after boot."
    "robloxplayerbeta"   = "Roblox launcher helper. Safe to disable - Roblox will still open fine when you click it."
    "crosshairx"         = "Third-party crosshair overlay tool for shooters. Purely optional."
    "mapping engine"     = "reWASD - remaps controller/keyboard inputs. Keep if you use custom controller mappings; otherwise safe to disable."
    "battle.net"         = "Blizzard's Battle.net launcher (WoW, Overwatch, Diablo, etc). Only needed automatically if you play right after boot."
    "microsoftedgeautolaunch" = "Pre-loads Microsoft Edge in the background so it opens faster. Purely a convenience/speed feature - safe to disable if you rarely use Edge."
    "teams"              = "Microsoft Teams. Keep if you need to receive calls/messages immediately on login (e.g. for work); otherwise safe to disable."
    "discord"            = "Discord chat app. Keep if you want to appear online / receive calls immediately; otherwise safe to disable and open manually."
    "onedrive"           = "Microsoft OneDrive sync client itself (different from OneDriveSetup above). Disabling stops automatic file sync until you open it manually."
    "fxsound"            = "FxSound - audio enhancer for better sound quality. Purely optional, a preference feature."
    "securityhealth"     = "Windows Security (Defender) tray icon and protection status. This is your built-in antivirus - do NOT disable this."
    "cloudflarewarp"     = "Cloudflare WARP - a VPN/DNS privacy tool. Keep if you want it active as soon as you log in; otherwise safe to disable."
}

function Get-StartupDescription($name) {
    $lower = $name.ToLower()
    foreach ($key in $script:StartupKnowledge.Keys) {
        if ($lower -match [regex]::Escape($key)) { return $script:StartupKnowledge[$key] }
    }
    return "No specific info on this one - if you don't recognize the name or the program it belongs to, it's worth a quick web search of the exact name before deciding."
}

# Disable matches Task Manager: set StartupApproved, do not delete Run keys.
function Get-StartupApprovedPath($runKeyPath) {
    if ($runKeyPath -match 'WOW6432Node') {
        return ($runKeyPath -replace 'SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Run', 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32')
    } else {
        return ($runKeyPath -replace 'SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run', 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run')
    }
}

function Set-RegistryStartupState($item, $disable) {
    $runPaths = @(
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    )

    foreach ($runPath in $runPaths) {
        if (-not (Test-Path $runPath)) { continue }
        $props = Get-ItemProperty -Path $runPath -ErrorAction SilentlyContinue
        if (-not $props) { continue }

        $matchName = $null
        foreach ($prop in $props.PSObject.Properties) {
            if ($prop.Name -match '^PS') { continue }
            if ($prop.Name -eq $item.Name) { $matchName = $prop.Name; break }
            if ($item.Command -and $prop.Value -and ($prop.Value.Trim() -eq $item.Command.Trim())) { $matchName = $prop.Name; break }
        }

        if ($matchName) {
            if ($runPath -match 'RunOnce') {
                if ($disable) {
                    Remove-ItemProperty -Path $runPath -Name $matchName -ErrorAction SilentlyContinue
                    return @{ Success = $true; Method = "RunOnce entry removed (it was only ever going to run one more time anyway)" }
                }
            } else {
                try {
                    $approvedPath = Get-StartupApprovedPath $runPath
                    if (-not (Test-Path $approvedPath)) { New-Item -Path $approvedPath -Force | Out-Null }
                    $existing = (Get-ItemProperty -Path $approvedPath -Name $matchName -ErrorAction SilentlyContinue).$matchName
                    $bytes = if ($existing -and $existing.Length -ge 12) { [byte[]]$existing.Clone() } else { New-Object byte[] 12 }
                    $bytes[0] = if ($disable) { 0x03 } else { 0x02 }
                    Set-ItemProperty -Path $approvedPath -Name $matchName -Value $bytes -Type Binary
                    return @{ Success = $true; Method = "Registry (Task Manager style)" }
                } catch {
                    return @{ Success = $false; Method = $null }
                }
            }
        }
    }

    $shortName = ($item.Name -split '[\s._]')[0]
    $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match [regex]::Escape($shortName) }
    if ($tasks) {
        foreach ($t in $tasks) {
            try {
                if ($disable) { Disable-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction Stop | Out-Null }
                else { Enable-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction Stop | Out-Null }
            } catch { return @{ Success = $false; Method = $null } }
        }
        return @{ Success = $true; Method = "Scheduled Task '$($tasks[0].TaskName)' (re-enable via Task Scheduler, or run this tool again)" }
    }

    return @{ Success = $false; Method = $null }
}

function Test-StartupItemDisabled($item) {
    if ($item.Location -match "Startup") {
        $originalPaths = @(
            "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\$($item.Name).lnk",
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\$($item.Name).lnk"
        )
        foreach ($p in $originalPaths) {
            if (Test-Path $p) { return $false }
        }
        $backupPath = "$env:USERPROFILE\Desktop\Disabled_Startup_Items\$($item.Name).lnk"
        return (Test-Path $backupPath)
    }

    $runPaths = @(
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
    )
    foreach ($runPath in $runPaths) {
        if (-not (Test-Path $runPath)) { continue }
        $props = Get-ItemProperty -Path $runPath -ErrorAction SilentlyContinue
        if (-not $props) { continue }
        foreach ($prop in $props.PSObject.Properties) {
            if ($prop.Name -match '^PS') { continue }
            $isMatch = ($prop.Name -eq $item.Name) -or ($item.Command -and $prop.Value -and ($prop.Value.Trim() -eq $item.Command.Trim()))
            if (-not $isMatch) { continue }
            try {
                $approvedPath = Get-StartupApprovedPath $runPath
                $val = (Get-ItemProperty -Path $approvedPath -Name $prop.Name -ErrorAction SilentlyContinue).$($prop.Name)
                return ($val -and $val.Length -ge 1 -and $val[0] -eq 0x03)
            } catch { return $false }
        }
    }

    $shortName = ($item.Name -split '[\s._]')[0]
    $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match [regex]::Escape($shortName) }
    if ($tasks) {
        return -not ($tasks | Where-Object { $_.State -ne 'Disabled' })
    }

    return $false
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "PC Health Check Toolkit"
$form.Size = New-Object System.Drawing.Size(900, 700)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(12, 12, 22)
$form.Opacity = 0

$script:snowParticles = 1..45 | ForEach-Object {
    [PSCustomObject]@{
        X     = Get-Random -Minimum 0 -Maximum 900
        Y     = Get-Random -Minimum 0 -Maximum 700
        Size  = Get-Random -Minimum 2 -Maximum 4
        Speed = (Get-Random -Minimum 40 -Maximum 110) / 100.0
        Alpha = Get-Random -Minimum 60 -Maximum 140
    }
}

$bgPanel = New-Object System.Windows.Forms.Panel
$bgPanel.Dock = "Fill"
$bgPanel.GetType().InvokeMember("DoubleBuffered", ([System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::SetProperty), $null, $bgPanel, @($true)) | Out-Null

$bgPanel.Add_Paint({
    param($sender, $e)
    try {
        $rect = $sender.ClientRectangle
        if ($rect.Width -le 0 -or $rect.Height -le 0) { return }
        $g = $e.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, [System.Drawing.Color]::FromArgb(20, 22, 45), [System.Drawing.Color]::FromArgb(8, 8, 16), [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
        $g.FillRectangle($grad, $rect)
        $grad.Dispose()
        foreach ($p in $script:snowParticles) {
            $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int]$p.Alpha, 255, 255, 255))
            $g.FillEllipse($brush, [float]$p.X, [float]$p.Y, [float]$p.Size, [float]$p.Size)
            $brush.Dispose()
        }
    } catch {}
})

$form.Controls.Add($bgPanel)

$snowTimer = New-Object System.Windows.Forms.Timer
$snowTimer.Interval = 55
$snowTimer.Add_Tick({
    try {
        if ($bgPanel.Width -le 0 -or $bgPanel.Height -le 0) { return }
        foreach ($p in $script:snowParticles) {
            $p.Y += $p.Speed
            $p.X += [math]::Sin($p.Y / 25) * 0.4
            if ($p.Y -gt $bgPanel.Height) {
                $p.Y = -5
                $p.X = Get-Random -Minimum 0 -Maximum $bgPanel.Width
            }
        }
        $bgPanel.Invalidate()
    } catch {}
})
$snowTimer.Start()

function Set-RoundedRegion($ctrl, $radius) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $radius * 2
    $rect = New-Object System.Drawing.Rectangle(0, 0, $ctrl.Width, $ctrl.Height)
    $path.AddArc($rect.X, $rect.Y, $d, $d, 180, 90)
    $path.AddArc($rect.Right - $d, $rect.Y, $d, $d, 270, 90)
    $path.AddArc($rect.Right - $d, $rect.Bottom - $d, $d, $d, 0, 90)
    $path.AddArc($rect.X, $rect.Bottom - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    $ctrl.Region = New-Object System.Drawing.Region($path)
}

function Add-HoverGlow($btn, $baseColor, $hoverColor) {
    $btn.Add_MouseEnter({ param($s, $e) $s.BackColor = $s.Tag.Hover })
    $btn.Add_MouseLeave({ param($s, $e) $s.BackColor = $s.Tag.Base })
    $btn.Tag = [PSCustomObject]@{ Base = $baseColor; Hover = $hoverColor }
}

function Suspend-BackgroundTimers {
    try { $snowTimer.Stop() } catch {}
    try { $glowTimer.Stop() } catch {}
}

function Resume-BackgroundTimers {
    try { $snowTimer.Start() } catch {}
    try { $glowTimer.Start() } catch {}
}

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = [char]0x2744 + " PC Health Check Toolkit " + [char]0x2744
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(210, 225, 255)
$titleLabel.AutoSize = $true
$titleLabel.BackColor = [System.Drawing.Color]::Transparent
$titleLabel.Location = New-Object System.Drawing.Point(20, 15)
$form.Controls.Add($titleLabel)

$subLabel = New-Object System.Windows.Forms.Label
$subLabel.Text = "Diagnose. Clean. Optimize. Nothing happens without your say-so."
$subLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
$subLabel.ForeColor = [System.Drawing.Color]::FromArgb(150, 160, 190)
$subLabel.AutoSize = $true
$subLabel.BackColor = [System.Drawing.Color]::Transparent
$subLabel.Location = New-Object System.Drawing.Point(24, 50)
$form.Controls.Add($subLabel)

$script:titleHue = 210
$glowTimer = New-Object System.Windows.Forms.Timer
$glowTimer.Interval = 90
$glowTimer.Add_Tick({
    try {
        $script:titleHue += 0.4
        if ($script:titleHue -gt 260) { $script:titleHue = 200 }
        $h = $script:titleHue / 360.0
        $color = [System.Drawing.Color]::FromArgb(
            [int](180 + 40 * [math]::Sin($h * 6.28)),
            [int](200 + 30 * [math]::Sin($h * 6.28 + 2)),
            255
        )
        $titleLabel.ForeColor = $color
    } catch {}
})
$glowTimer.Start()

$isAdmin = Test-IsAdmin
$adminLabel = New-Object System.Windows.Forms.Label
$adminLabel.Text = if ($isAdmin) { [char]0x2713 + " Running as Administrator" } else { "NOT running as Administrator - some checks will be limited. Re-launch as admin for full results." }
$adminLabel.ForeColor = if ($isAdmin) { [System.Drawing.Color]::LightGreen } else { [System.Drawing.Color]::Orange }
$adminLabel.AutoSize = $true
$adminLabel.BackColor = [System.Drawing.Color]::Transparent
$adminLabel.Location = New-Object System.Drawing.Point(20, 78)
$form.Controls.Add($adminLabel)

$outputBox = New-Object System.Windows.Forms.RichTextBox
$outputBox.Location = New-Object System.Drawing.Point(20, 270)
$outputBox.Size = New-Object System.Drawing.Size(845, 375)
$outputBox.ReadOnly = $true
$outputBox.BackColor = [System.Drawing.Color]::FromArgb(6, 6, 12)
$outputBox.ForeColor = [System.Drawing.Color]::LightGray
$outputBox.BorderStyle = "FixedSingle"
$outputBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($outputBox)
Set-RoundedRegion $outputBox 6

function Write-Log($text, $color = "LightGray") {
    $outputBox.SelectionStart = $outputBox.TextLength
    $outputBox.SelectionColor = [System.Drawing.Color]::$color
    $outputBox.AppendText("$text`r`n")
    $outputBox.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function Write-LogRaw($text) { Write-Log $text "LightGray" }

function Run-Diagnostics {
    $outputBox.Clear()
    Write-Log "=== SYSTEM DIAGNOSTICS (read-only) ===" "Cyan"

    Write-Log "`n-- Disk Space --" "Yellow"
    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
        $freePct = [math]::Round(($_.FreeSpace / $_.Size) * 100, 1)
        Write-LogRaw ("{0}  Total: {1}  Free: {2} ({3}%)" -f $_.DeviceID, (Format-Bytes $_.Size), (Format-Bytes $_.FreeSpace), $freePct)
    }

    Write-Log "`n-- Memory --" "Yellow"
    $os = Get-CimInstance Win32_OperatingSystem
    $usedMemPct = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 1)
    Write-LogRaw ("Total: {0} | In use: {1}%" -f (Format-Bytes ($os.TotalVisibleMemorySize * 1KB)), $usedMemPct)

    Write-Log "`n-- Top 10 processes by memory --" "Yellow"
    Get-Process | Sort-Object WS -Descending | Select-Object -First 10 | ForEach-Object {
        Write-LogRaw ("{0,-30} {1,10}" -f $_.ProcessName, (Format-Bytes $_.WS))
    }

    Write-Log "`n-- Recent System Errors (last 24h, top 10) --" "Yellow"
    try {
        Get-WinEvent -FilterHashtable @{LogName='System'; Level=2; StartTime=(Get-Date).AddDays(-1)} -MaxEvents 10 -ErrorAction Stop | ForEach-Object {
            Write-LogRaw ("{0}  [{1}] {2}" -f $_.TimeCreated, $_.ProviderName, $_.Message.Substring(0,[Math]::Min(80,$_.Message.Length)))
        }
    } catch {
        Write-LogRaw "No recent error events found (or insufficient permissions)."
    }

    Write-Log "`nDiagnostics complete. Nothing was changed." "LightGreen"
}

function Show-CheckListDialog($title, $items, $confirmVerb) {
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = $title
    $dlg.Size = New-Object System.Drawing.Size(650, 500)
    $dlg.StartPosition = "CenterParent"
    $dlg.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)

    $info = New-Object System.Windows.Forms.Label
    $info.Text = "Check the items you want to $confirmVerb. Nothing happens until you click the button below."
    $info.ForeColor = [System.Drawing.Color]::White
    $info.AutoSize = $true
    $info.Location = New-Object System.Drawing.Point(15, 10)
    $dlg.Controls.Add($info)

    $clb = New-Object System.Windows.Forms.CheckedListBox
    $clb.Location = New-Object System.Drawing.Point(15, 40)
    $clb.Size = New-Object System.Drawing.Size(605, 350)
    $clb.CheckOnClick = $true
    $clb.BackColor = [System.Drawing.Color]::FromArgb(20,20,20)
    $clb.ForeColor = [System.Drawing.Color]::White
    $clb.Font = New-Object System.Drawing.Font("Consolas", 9)
    foreach ($item in $items) { $clb.Items.Add($item.Label) | Out-Null }
    $dlg.Controls.Add($clb)

    $okBtn = New-Object System.Windows.Forms.Button
    $okBtn.Text = "$confirmVerb Selected"
    $okBtn.Location = New-Object System.Drawing.Point(15, 405)
    $okBtn.Size = New-Object System.Drawing.Size(150, 35)
    $okBtn.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $dlg.Controls.Add($okBtn)

    $cancelBtn = New-Object System.Windows.Forms.Button
    $cancelBtn.Text = "Cancel"
    $cancelBtn.Location = New-Object System.Drawing.Point(180, 405)
    $cancelBtn.Size = New-Object System.Drawing.Size(100, 35)
    $cancelBtn.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $dlg.Controls.Add($cancelBtn)

    $dlg.AcceptButton = $okBtn
    Suspend-BackgroundTimers
    try {
        $result = $dlg.ShowDialog()
    } finally {
        Resume-BackgroundTimers
    }

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $checkedIndices = [int[]]$clb.CheckedIndices
        return $items[$checkedIndices]
    }
    return @()
}

function Run-JunkScan {
    $outputBox.Clear()
    Write-Log "=== JUNK FILE SCAN ===" "Cyan"
    Write-LogRaw "Scanning categories (this can take a minute)..."

    $targets = [ordered]@{
        "User Temp Files"        = "$env:LOCALAPPDATA\Temp"
        "Windows Temp Files"     = "$env:WINDIR\Temp"
        "Chrome Cache"           = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
        "Edge Cache"             = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
        "Windows Update Cache"   = "$env:WINDIR\SoftwareDistribution\Download"
    }

    $items = @()
    foreach ($key in $targets.Keys) {
        $size = Get-FolderSize $targets[$key]
        if ($size -gt 0) {
            $items += [PSCustomObject]@{ Name = $key; Path = $targets[$key]; Label = ("{0,-25} {1}" -f $key, (Format-Bytes $size)) }
        }
    }

    try {
        $shell = New-Object -ComObject Shell.Application
        $recycleBin = $shell.Namespace(10)
        $rbSize = 0
        $recycleBin.Items() | ForEach-Object { $rbSize += $_.Size }
        if ($rbSize -gt 0) {
            $items += [PSCustomObject]@{ Name = "Recycle Bin"; Path = $null; Label = ("{0,-25} {1}" -f "Recycle Bin", (Format-Bytes $rbSize)) }
        }
    } catch {}

    if ($items.Count -eq 0) {
        Write-Log "Nothing significant found. You're clean!" "LightGreen"
        return
    }

    foreach ($i in $items) { Write-LogRaw $i.Label }

    $selected = Show-CheckListDialog "Select Junk To Clean" $items "Clean"

    if ($selected.Count -eq 0) {
        Write-Log "`nNo items selected. Nothing was deleted." "Gray"
        return
    }

    Write-Log "`nCleaning selected items..." "Yellow"
    foreach ($item in $selected) {
        if ($item.Name -eq "Recycle Bin") {
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue
            Write-Log "  Recycle Bin emptied." "LightGreen"
        } else {
            try {
                Get-ChildItem -Path $item.Path -Recurse -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
                Write-Log "  Cleared $($item.Name)." "LightGreen"
            } catch {
                Write-Log "  Could not fully clear $($item.Name) (some files may be in use)." "Orange"
            }
        }
    }
    Write-Log "`nCleanup complete." "LightGreen"
}

function Show-StartupItemsDialog($items) {
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "Select Startup Items To Disable"
    $dlg.Size = New-Object System.Drawing.Size(1000, 640)
    $dlg.StartPosition = "CenterParent"
    $dlg.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)

    $info = New-Object System.Windows.Forms.Label
    $info.Text = "HOW THIS WORKS: `r`n" +
                 "  WHAT 'disable' does: stops the program from auto-launching. It does NOT uninstall or delete the program itself.`r`n" +
                 "  WHEN it takes effect: from your NEXT login/restart onward. If the program is already running now, it keeps running until you close it.`r`n" +
                 "  HOW LONG: permanent until you re-enable it yourself - there's no time limit or auto-revert.`r`n" +
                 "  HOW to undo: shortcuts move to Desktop\Disabled_Startup_Items (drag back to re-enable). Registry items are flagged disabled the same way Task Manager does it - re-enable anytime via Task Manager > Startup tab."
    $info.ForeColor = [System.Drawing.Color]::White
    $info.AutoSize = $false
    $info.Size = New-Object System.Drawing.Size(950, 90)
    $info.Location = New-Object System.Drawing.Point(15, 10)
    $dlg.Controls.Add($info)

    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Location = New-Object System.Drawing.Point(15, 105)
    $grid.Size = New-Object System.Drawing.Size(955, 445)
    $grid.BackgroundColor = [System.Drawing.Color]::FromArgb(20,20,20)
    $grid.ForeColor = [System.Drawing.Color]::Black
    $grid.AllowUserToAddRows = $false
    $grid.AllowUserToResizeRows = $false
    $grid.RowHeadersVisible = $false
    $grid.AutoSizeColumnsMode = "Fill"
    $grid.ColumnHeadersHeightSizeMode = "AutoSize"
    $grid.SelectionMode = "FullRowSelect"
    $grid.DefaultCellStyle.WrapMode = "True"
    $grid.RowTemplate.Height = 60

    $colCheck = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
    $colCheck.Name = "Disable"
    $colCheck.HeaderText = "Disable?"
    $colCheck.Width = 60
    $colCheck.FillWeight = 8
    $grid.Columns.Add($colCheck) | Out-Null

    $colName = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colName.Name = "Name"
    $colName.HeaderText = "Item"
    $colName.FillWeight = 15
    $grid.Columns.Add($colName) | Out-Null

    $colDesc = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colDesc.Name = "Description"
    $colDesc.HeaderText = "What it is / recommendation"
    $colDesc.FillWeight = 45
    $grid.Columns.Add($colDesc) | Out-Null

    $colCmd = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colCmd.Name = "Command"
    $colCmd.HeaderText = "Launch command (for reference)"
    $colCmd.FillWeight = 32
    $grid.Columns.Add($colCmd) | Out-Null

    foreach ($item in $items) {
        $rowIndex = $grid.Rows.Add($false, $item.Name, $item.Description, $item.Command)
        if ($item.Name -match "SecurityHealth") {
            $grid.Rows[$rowIndex].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(255, 210, 210)
        }
    }
    $dlg.Controls.Add($grid)

    $okBtn = New-Object System.Windows.Forms.Button
    $okBtn.Text = "Disable Checked Items"
    $okBtn.Location = New-Object System.Drawing.Point(15, 560)
    $okBtn.Size = New-Object System.Drawing.Size(180, 35)
    $okBtn.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $dlg.Controls.Add($okBtn)

    $cancelBtn = New-Object System.Windows.Forms.Button
    $cancelBtn.Text = "Cancel"
    $cancelBtn.Location = New-Object System.Drawing.Point(205, 560)
    $cancelBtn.Size = New-Object System.Drawing.Size(100, 35)
    $cancelBtn.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $dlg.Controls.Add($cancelBtn)

    $dlg.AcceptButton = $okBtn
    Suspend-BackgroundTimers
    try {
        $result = $dlg.ShowDialog()
    } finally {
        Resume-BackgroundTimers
    }

    $selected = @()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        foreach ($row in $grid.Rows) {
            if ($row.Cells["Disable"].Value -eq $true) {
                $idx = $row.Index
                $selected += $items[$idx]
            }
        }
    }
    return $selected
}

function Run-Optimization {
    $outputBox.Clear()
    Write-Log "=== OPTIMIZATION: STARTUP PROGRAMS ===" "Cyan"

    $startupItems = @(Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue | Select-Object Name, Command, Location, User)
    if ($startupItems.Count -eq 0) {
        Write-LogRaw "No startup items found."
        return
    }

    $items = @()
    foreach ($s in $startupItems) {
        $items += [PSCustomObject]@{ Name = $s.Name; Command = $s.Command; Location = $s.Location; Description = (Get-StartupDescription $s.Name) }
    }

    Write-LogRaw "Checking which items are already disabled..."
    $alreadyDisabled = @()
    $stillEnabled = @()
    foreach ($item in $items) {
        if (Test-StartupItemDisabled $item) { $alreadyDisabled += $item } else { $stillEnabled += $item }
    }

    if ($alreadyDisabled.Count -gt 0) {
        Write-Log "`nAlready disabled (no action needed):" "Gray"
        foreach ($item in $alreadyDisabled) { Write-LogRaw "  $($item.Name)" }
    }

    if ($stillEnabled.Count -eq 0) {
        Write-Log "`nEverything here is already disabled - nothing left to do." "LightGreen"
        return
    }

    Write-Log "`nStill enabled:" "Yellow"
    foreach ($s in $stillEnabled) { Write-LogRaw ("{0,-25} {1}" -f $s.Name, $s.Command) }

    Write-Log "`nOpening the startup items panel - each one now shows what it does and what disabling means..." "Gray"

    $selected = Show-StartupItemsDialog $stillEnabled

    if ($selected.Count -eq 0) {
        Write-Log "`nNo items selected. Nothing was changed." "Gray"
        return
    }

    Write-Log "`nDisabling selected startup items..." "Yellow"
    foreach ($item in $selected) {
        try {
            if ($item.Location -match "Startup") {
                $backupDir = "$env:USERPROFILE\Desktop\Disabled_Startup_Items"
                if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir | Out-Null }
                $possiblePaths = @(
                    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\$($item.Name).lnk",
                    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\$($item.Name).lnk"
                )
                $moved = $false
                foreach ($p in $possiblePaths) {
                    if (Test-Path $p) {
                        Move-Item $p -Destination $backupDir -Force
                        $moved = $true
                    }
                }
                if ($moved) {
                    Write-Log "  Moved '$($item.Name)' shortcut to Desktop\Disabled_Startup_Items (drag it back to re-enable)." "LightGreen"
                } else {
                    Write-Log "  Could not locate the shortcut file for '$($item.Name)' automatically - disable it via Task Manager > Startup instead." "Orange"
                }
            } else {
                $result = Set-RegistryStartupState $item $true
                if ($result.Success) {
                    Write-Log "  Disabled '$($item.Name)' via $($result.Method) - it won't auto-launch from your next login." "LightGreen"
                } else {
                    Write-Log "  Could not find/modify a startup entry for '$($item.Name)' automatically - disable it via Task Manager > Startup tab instead (right-click the app there and choose Disable)." "Orange"
                }
            }
        } catch {
            Write-Log "  Error handling '$($item.Name)': $_" "Red"
        }
    }
    Write-Log "`nDone." "LightGreen"
}

function Run-SuspiciousScan {
    $outputBox.Clear()
    Write-Log "=== SUSPICIOUS ITEM REPORT (flags only - nothing is changed) ===" "Cyan"

    Write-Log "`n-- Unsigned executables currently running --" "Yellow"
    Write-LogRaw "Checking signatures on every running process - this can take a few seconds..."
    $foundUnsigned = $false
    $procCounter = 0
    Get-Process | ForEach-Object {
        $procCounter++
        if ($procCounter % 10 -eq 0) {
            try { [System.Windows.Forms.Application]::DoEvents() } catch {}
        }
        $procPath = $null
        try { $procPath = $_.Path } catch {}
        if (-not $procPath) { return }
        try {
            $sig = Get-AuthenticodeSignature $procPath -ErrorAction SilentlyContinue
            if ($sig.Status -ne 'Valid') {
                Write-LogRaw ("{0,-25} {1}  [{2}]" -f $_.ProcessName, $procPath, $sig.Status)
                $foundUnsigned = $true
            }
        } catch {}
    }
    if (-not $foundUnsigned) { Write-LogRaw "None found." }

    Write-Log "`n-- Non-Microsoft Scheduled Tasks --" "Yellow"
    $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.Author -and $_.Author -notmatch 'Microsoft' }
    if ($tasks) {
        $tasks | ForEach-Object { Write-LogRaw ("{0,-40} {1,-25} {2}" -f $_.TaskName, $_.Author, $_.State) }
    } else { Write-LogRaw "None found." }

    Write-Log "`n-- Hosts file entries (should normally be empty) --" "Yellow"
    $hostsLines = Get-Content "$env:WINDIR\System32\drivers\etc\hosts" -ErrorAction SilentlyContinue | Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() -ne '' }
    if ($hostsLines) { $hostsLines | ForEach-Object { Write-LogRaw $_ } } else { Write-LogRaw "Default / empty - looks fine." }

    Write-Log "`n-- Chrome Extensions installed --" "Yellow"
    $chromeExtPath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Extensions"
    if (Test-Path $chromeExtPath) {
        Get-ChildItem $chromeExtPath -Directory | ForEach-Object { Write-LogRaw $_.Name }
        Write-LogRaw "(Cross-check unfamiliar IDs at chrome://extensions or search the ID online.)"
    }

    Write-Log "`n------------------------------------------------------------" "Cyan"
    Write-Log "This flags anomalies, not confirmed threats. Nothing was changed." "Yellow"
    Write-Log "For anything unfamiliar: look it up, then run Windows Defender or Malwarebytes before removing it." "Yellow"
}

function Confirm-Dialog($message, $title) {
    Play-Blip
    Suspend-BackgroundTimers
    try {
        return ([System.Windows.Forms.MessageBox]::Show($message, $title, "YesNo", "Question") -eq "Yes")
    } finally {
        Resume-BackgroundTimers
    }
}

function Run-SpeedBoost {
    $outputBox.Clear()
    Write-Log "=== SPEED BOOST (tuned for hard disk drives) ===" "Cyan"

    Write-Log "`n-- Drive type --" "Yellow"
    $isHDD = $true
    try {
        $disks = Get-PhysicalDisk -ErrorAction Stop
        foreach ($d in $disks) { Write-LogRaw ("{0}  MediaType: {1}" -f $d.FriendlyName, $d.MediaType) }
        if ($disks | Where-Object { $_.MediaType -eq 'SSD' }) { $isHDD = $false }
    } catch {
        Write-LogRaw "Could not auto-detect drive type on this Windows build - proceeding with HDD-oriented checks anyway."
    }

    Write-Log "`n-- Disk Fragmentation --" "Yellow"
    Write-LogRaw "Checking how fragmented your C: drive is (this is the single biggest HDD slowdown cause)..."
    try {
        $frag = Optimize-Volume -DriveLetter C -Analyze -Verbose 4>&1 | Out-String
        Write-LogRaw $frag.Trim()
    } catch {
        Write-LogRaw "Could not analyze fragmentation - re-run this tool as Administrator for this check."
    }
    if (Confirm-Dialog "Defragment the C: drive now? On a hard drive this can meaningfully speed up file loading and boot time, but depending on how full/fragmented it is, it can take anywhere from several minutes to a few hours. It runs in the background, but your drive will be busy and everything will feel sluggish while it works." "Defragment Drive") {
        Write-Log "Starting defragmentation in the background - this can take a while, feel free to keep using the PC (just expect it to feel slower until it finishes)." "Yellow"
        Start-Job -ScriptBlock { Optimize-Volume -DriveLetter C -Defrag -ErrorAction SilentlyContinue } | Out-Null
        Write-Log "Defrag job started." "LightGreen"
    } else {
        Write-Log "Skipped defrag." "Gray"
    }

    Write-Log "`n-- SysMain (Superfetch) --" "Yellow"
    $sysmain = Get-Service -Name SysMain -ErrorAction SilentlyContinue
    if ($sysmain) {
        Write-LogRaw "Status: $($sysmain.Status)  |  Startup type: $($sysmain.StartType)"
        if ($sysmain.Status -ne 'Running') {
            if (Confirm-Dialog "SysMain (Superfetch) pre-loads your frequently-used apps into memory before you open them. It's usually recommended OFF for SSDs, but ON for hard drives like yours - it's currently off. Turn it on?" "Enable SysMain") {
                Set-Service -Name SysMain -StartupType Automatic
                Start-Service -Name SysMain -ErrorAction SilentlyContinue
                Write-Log "SysMain enabled and started." "LightGreen"
            } else { Write-Log "Left SysMain off." "Gray" }
        } else {
            Write-LogRaw "Already running - this is the right state for a hard drive."
        }
    } else {
        Write-LogRaw "SysMain service not found on this system."
    }

    Write-Log "`n-- Fast Startup --" "Yellow"
    $hiberPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
    $hiberVal = (Get-ItemProperty -Path $hiberPath -Name HiberbootEnabled -ErrorAction SilentlyContinue).HiberbootEnabled
    if ($hiberVal -eq 1) {
        Write-LogRaw "Already ON - good, this is one of the bigger boot-time wins on a hard drive."
    } else {
        Write-LogRaw "Currently OFF."
        if (Confirm-Dialog "Fast Startup saves part of the system state to disk on shutdown so the next boot is quicker - it's a solid win on a hard drive. Turn it on? (Note: after this, 'Shut Down' behaves a bit like a partial hibernate for the OS kernel - a full Restart always does a completely clean boot if you ever need one.)" "Enable Fast Startup") {
            Set-ItemProperty -Path $hiberPath -Name HiberbootEnabled -Value 1
            Write-Log "Fast Startup enabled - takes effect from your next shutdown/boot cycle." "LightGreen"
        } else { Write-Log "Left Fast Startup off." "Gray" }
    }

    Write-Log "`n-- Visual Effects --" "Yellow"
    if (Confirm-Dialog "Animations, shadows, and transparency all cost a little drawing/disk time, which is more noticeable on a hard drive than an SSD. Switch to Windows' 'Best Performance' visual mode? This turns off the eye-candy but keeps menus and windows feeling snappier. Fully reversible anytime in Settings > System > About > Advanced system settings > Performance." "Reduce Visual Effects") {
        $vfxPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
        if (-not (Test-Path $vfxPath)) { New-Item -Path $vfxPath -Force | Out-Null }
        Set-ItemProperty -Path $vfxPath -Name VisualFXSetting -Value 2
        $transPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        if (Test-Path $transPath) { Set-ItemProperty -Path $transPath -Name EnableTransparency -Value 0 -ErrorAction SilentlyContinue }
        Write-Log "Switched to best-performance visuals. Sign out and back in (or restart) for it to fully apply everywhere." "LightGreen"
    } else {
        Write-Log "Kept current visual effects." "Gray"
    }

    Write-Log "`n-- One more thing --" "Yellow"
    Write-LogRaw "Trimming startup programs is one of the biggest wins for HDD boot time - each extra program at login costs more on a hard drive than an SSD. Use the 'Optimize Startup' button for that if you haven't already."

    if (-not $isHDD) {
        Write-Log "`nNote: at least one of your drives reported as SSD - defrag isn't needed on that drive (Windows automatically runs TRIM instead), but the other tweaks here still help." "Orange"
    }

    Write-Log "`nSpeed boost pass complete." "LightGreen"
}

function New-ActionButton($text, $x, $y, $w, $h, $baseColor, $hoverColor, $fontSize) {
    $useGlow = [bool]("SmoothUI.GlowButton" -as [type])
    if ($useGlow) {
        $btn = New-Object SmoothUI.GlowButton
        $pressColor = [System.Drawing.Color]::FromArgb(
            [Math]::Max(0, $hoverColor.R - 35),
            [Math]::Max(0, $hoverColor.G - 35),
            [Math]::Max(0, $hoverColor.B - 35))
        $btn.SetPalette($baseColor, $hoverColor, $pressColor)
    } else {
        $btn = New-Object System.Windows.Forms.Button
        $btn.BackColor = $baseColor
        $btn.ForeColor = [System.Drawing.Color]::White
        $btn.FlatStyle = "Flat"
        $btn.FlatAppearance.BorderSize = 0
        Add-HoverGlow $btn $baseColor $hoverColor
    }
    $btn.Text = $text
    $btn.Location = New-Object System.Drawing.Point($x, $y)
    $btn.Size = New-Object System.Drawing.Size($w, $h)
    $btn.ForeColor = [System.Drawing.Color]::White
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", $fontSize, [System.Drawing.FontStyle]::Bold)
    if (-not $useGlow) { Set-RoundedRegion $btn 10 }
    return $btn
}

function Invoke-ActionWithCursor($action, $successSound) {
    Play-Blip
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    try {
        & $action
        & $successSound
    } catch {
        Play-Error
        [System.Windows.Forms.MessageBox]::Show("Error: $_", "Oops")
    } finally {
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
}

$btnDiag = New-ActionButton "Run Diagnostics" 20 108 190 45 `
    ([System.Drawing.Color]::FromArgb(0,120,180)) ([System.Drawing.Color]::FromArgb(30,155,220)) 9.5
$btnDiag.Add_Click({
    Invoke-ActionWithCursor { Run-Diagnostics } { Play-Success }
})
$form.Controls.Add($btnDiag)

$btnJunk = New-ActionButton "Scan Junk Files" 225 108 190 45 `
    ([System.Drawing.Color]::FromArgb(0,150,90)) ([System.Drawing.Color]::FromArgb(20,190,120)) 9.5
$btnJunk.Add_Click({
    Invoke-ActionWithCursor { Run-JunkScan } { Play-Success }
})
$form.Controls.Add($btnJunk)

$btnOpt = New-ActionButton "Optimize Startup" 430 108 190 45 `
    ([System.Drawing.Color]::FromArgb(180,130,0)) ([System.Drawing.Color]::FromArgb(220,165,20)) 9.5
$btnOpt.Add_Click({
    Invoke-ActionWithCursor { Run-Optimization } { Play-Success }
})
$form.Controls.Add($btnOpt)

$btnSus = New-ActionButton "Suspicious Report" 635 108 190 45 `
    ([System.Drawing.Color]::FromArgb(170,40,40)) ([System.Drawing.Color]::FromArgb(210,65,65)) 9.5
$btnSus.Add_Click({
    Invoke-ActionWithCursor { Run-SuspiciousScan } { Play-Warning }
})
$form.Controls.Add($btnSus)

$btnSpeed = New-ActionButton ([char]0x2744 + "  Speed Boost (HDD)  " + [char]0x2744) 20 163 805 45 `
    ([System.Drawing.Color]::FromArgb(120,60,180)) ([System.Drawing.Color]::FromArgb(155,85,225)) 10
$btnSpeed.Add_Click({
    Invoke-ActionWithCursor { Run-SpeedBoost } { Play-Success }
})
$form.Controls.Add($btnSpeed)

$noteLabel = New-Object System.Windows.Forms.Label
$noteLabel.Text = "Every action shows you what it found first. Cleanup/disable steps only run on items you check and confirm."
$noteLabel.ForeColor = [System.Drawing.Color]::FromArgb(150,155,170)
$noteLabel.BackColor = [System.Drawing.Color]::Transparent
$noteLabel.AutoSize = $true
$noteLabel.Location = New-Object System.Drawing.Point(20, 222)
$form.Controls.Add($noteLabel)

Write-Log "Welcome. Choose an option above to begin." "White"

$bgPanel.SendToBack()

$form.Add_Shown({
    $fadeTimer = New-Object System.Windows.Forms.Timer
    $fadeTimer.Interval = 20
    $fadeTimer.Add_Tick({
        if ($form.Opacity -lt 1) { $form.Opacity += 0.06 } else { $fadeTimer.Stop() }
    })
    $fadeTimer.Start()
})

$script:hiccupCount = 0
$script:hiccupLastLoggedAt = Get-Date "2000-01-01"
try { [System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::CatchException) } catch {}
[System.Windows.Forms.Application]::add_ThreadException({
    param($excSender, $excArgs)
    try {
        $script:hiccupCount++
        $sinceLast = (Get-Date) - $script:hiccupLastLoggedAt
        if ($script:hiccupCount -le 3) {
            Write-Log "`n(Minor background hiccup, safely ignored: $($excArgs.Exception.Message))" "Orange"
            $script:hiccupLastLoggedAt = Get-Date
        } elseif ($sinceLast.TotalSeconds -ge 2) {
            Write-Log "`n(Minor background hiccups continuing quietly in the background - $($script:hiccupCount) so far this session.)" "Orange"
            $script:hiccupLastLoggedAt = Get-Date
        }
    } catch {}
})

[void]$form.ShowDialog()
