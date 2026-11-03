[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
function Assert-Hotkey($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    Write-Output "PASS: $Message"
}
$status = Get-Content -Raw -LiteralPath (Join-Path $root 'logs\hotkey-status.json') | ConvertFrom-Json
Assert-Hotkey ($status.combination -eq 'Ctrl+Alt+Win+W') 'New combination registered'
Assert-Hotkey ($status.modifiers -eq 0x400B -and $status.key -eq 0x57) 'Ctrl, Alt, Win, no Shift, W, no-repeat'
$process = Get-CimInstance Win32_Process -Filter ("ProcessId=" + $status.pid)
Assert-Hotkey ($process -and $process.CommandLine -like ('*' + (Join-Path $root 'Hotkey-Listener.ps1') + '*')) 'Registered listener process still alive'
$task = Get-ScheduledTask -TaskName 'WordGlance — горячая клавиша Cambridge' -TaskPath '\'
Assert-Hotkey ($task.State.ToString() -eq 'Running') 'Hotkey task running'
Assert-Hotkey (@($task.Actions | Where-Object Arguments -Like '*Hotkey-Listener.ps1*').Count -eq 1) 'Autostart points at persistent listener'
$shell = New-Object -ComObject WScript.Shell
foreach ($folder in @([Environment]::GetFolderPath('Desktop'), $PSScriptRoot)) {
    $shortcutPath = Join-Path $folder 'WordGlance Cambridge.lnk'
    if (Test-Path -LiteralPath $shortcutPath) {
        $shortcut = $shell.CreateShortcut($shortcutPath)
        Assert-Hotkey ([string]::IsNullOrEmpty($shortcut.Hotkey)) "Old shortcut key removed: $folder"
    }
}
$page = Invoke-WebRequest -Uri 'http://127.0.0.1:18743/' -UseBasicParsing -TimeoutSec 5
Assert-Hotkey ($page.StatusCode -eq 200 -and $page.Content.Contains('Ctrl+Alt+Win+W')) 'Served page shows new combination'
foreach ($file in @('README.md','AGENTS.md','index.html','Enable-Hotkey.ps1','Register-Autostart.ps1')) {
    $text = Get-Content -Raw -LiteralPath (Join-Path $root $file)
    Assert-Hotkey ($text -notmatch 'Ctrl\+Alt\+W\b|CTRL\+ALT\+W\b|Alt\+Ctrl\+W\b') "No obsolete combination in $file"
}
Write-Output 'Native RegisterHotKey success verified through live listener state; key press is a separate UI check.'


