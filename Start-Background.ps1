[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$helperPath = Join-Path $PSScriptRoot 'clock-helper.ps1'
$existing = @(Get-NetTCPConnection -LocalPort 18743 -State Listen -ErrorAction SilentlyContinue)
if ($existing.Count -gt 0) {
    foreach ($connection in $existing) {
        $processInfo = Get-CimInstance Win32_Process -Filter ("ProcessId=" + $connection.OwningProcess)
        if ($processInfo.CommandLine -and $processInfo.CommandLine.IndexOf($helperPath, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            exit 0
        }
    }
    throw 'Port 18743 is occupied by another application.'
}
$logFolder = Join-Path $PSScriptRoot 'logs'
New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
try {
    Start-Transcript -LiteralPath (Join-Path $logFolder 'background.log') -Append | Out-Null
    & $helperPath -Background
} finally {
    Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
}

