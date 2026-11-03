[CmdletBinding()]
param([string]$ShortcutDirectory = [Environment]::GetFolderPath('Desktop'), [switch]$SkipStart)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $ShortcutDirectory -PathType Container)) {
    throw 'Shortcut folder does not exist.'
}
$linkPath = Join-Path $ShortcutDirectory 'WordGlance Cambridge.lnk'
$shell = New-Object -ComObject WScript.Shell
$link = $shell.CreateShortcut($linkPath)
$expectedTarget = Join-Path $env:WINDIR 'explorer.exe'
$expectedArguments = 'http://127.0.0.1:18743/cambridge'
if (Test-Path -LiteralPath $linkPath) {
    if ($link.TargetPath -ine $expectedTarget -or $link.Arguments -ne $expectedArguments) {
        throw "A different shortcut already exists: $linkPath"
    }
} else {
    $link.TargetPath = $expectedTarget
    $link.Arguments = $expectedArguments
    $link.Description = 'Открыть текущее слово WordGlance в Cambridge Dictionary'
    $link.WorkingDirectory = $PSScriptRoot
}
# A .lnk shortcut cannot express Win. Keep it as a manual launcher only.
$link.Hotkey = ''
$link.Save()
Write-Host 'Manual shortcut configured without a shortcut hotkey.'
if (-not $SkipStart) {
    $task = Get-ScheduledTask -TaskName 'WordGlance — горячая клавиша Cambridge' -TaskPath '\' -ErrorAction Stop
    if (-not (@($task.Actions | Where-Object Arguments -Like '*Hotkey-Listener.ps1*').Count)) {
        throw 'Run Register-Autostart.ps1 to update the hotkey task first.'
    }
    Start-ScheduledTask -InputObject $task
    Write-Host 'Ctrl+Alt+Win+W listener task started.'
}

