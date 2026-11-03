[CmdletBinding()]
param([switch]$CheckRegistration)
$ErrorActionPreference = 'Stop'
$logFolder = Join-Path $PSScriptRoot 'logs'
New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
try {
    Add-Type -Path (Join-Path $PSScriptRoot 'WindowsHotkey.cs')
    if ($CheckRegistration) {
        [WordGlanceWindowsHotkey]::Run($logFolder, $true)
        Write-Output 'Ctrl+Alt+Win+W registration succeeded and was released.'
        exit 0
    }
    $mutex = New-Object Threading.Mutex($false, 'Local\WordGlance.Cambridge.Hotkey')
    $owned = $false
    try {
        try { $owned = $mutex.WaitOne(0) }
        catch [Threading.AbandonedMutexException] { $owned = $true }
        if (-not $owned) { exit 0 }
        [WordGlanceWindowsHotkey]::Run($logFolder, $false)
    } finally {
        if ($owned) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
} catch {
    Add-Content -LiteralPath (Join-Path $logFolder 'hotkey.log') -Value ((Get-Date -Format o) + ' ERROR ' + $_.Exception.Message) -Encoding UTF8
    Write-Error $_
    exit 1
}
