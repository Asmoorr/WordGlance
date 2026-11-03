[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$account = [Security.Principal.WindowsIdentity]::GetCurrent()
$userSid = $account.User.Value
$engine = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$principal = New-ScheduledTaskPrincipal -UserId $userSid -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
$definitions = @(
    @{
        Name = 'WordGlance — слова и глазки в фоне'
        File = 'Start-Background.ps1'
        Delay = 'PT5S'
        Description = 'Запускает WordGlance скрыто при входе Artem в Windows. Отдаёт локальную HTML-страницу для Windhawk, меняет слово каждые 4 часа и глазки по времени суток. Без браузера и консольного окна. Журнал: C:\Programming\2026\WordGlance\logs\background.log.'
    },
    @{
        Name = 'WordGlance — горячая клавиша Cambridge'
        File = 'Hotkey-Listener.ps1'
        Delay = 'PT20S'
        Description = 'Запускает скрытый постоянный обработчик Ctrl+Alt+Win+W в сеансе пользователя. По нажатию открывает текущее слово WordGlance в Cambridge Dictionary. Журнал: logs/hotkey.log.'
    }
)
foreach ($definition in $definitions) {
    $path = Join-Path $projectRoot $definition.File
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $userSid
    $trigger.Delay = $definition.Delay
    $arguments = '-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $path + '"'
    $action = New-ScheduledTaskAction -Execute $engine -Argument $arguments -WorkingDirectory $projectRoot
    $existingTask = Get-ScheduledTask -TaskName $definition.Name -TaskPath '\' -ErrorAction SilentlyContinue
    if ($existingTask) {
        if (-not (@($existingTask.Actions | Where-Object { ($_.Arguments -like ('*' + $path + '*')) -or ($definition.File -eq 'Hotkey-Listener.ps1' -and $_.Arguments -like ('*' + (Join-Path $projectRoot 'Enable-Hotkey.ps1') + '*')) }).Count)) {
            throw "A different task already exists: $($definition.Name)"
        }
        Set-ScheduledTask -TaskName $definition.Name -TaskPath '\' -Action $action -Trigger $trigger -Settings $settings -Principal $principal | Out-Null
        $updatedTask = Get-ScheduledTask -TaskName $definition.Name -TaskPath '\'
        $updatedTask.Description = $definition.Description
        Set-ScheduledTask -InputObject $updatedTask | Out-Null
    } else {
        Register-ScheduledTask -TaskName $definition.Name -TaskPath '\' -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description $definition.Description | Out-Null
    }
    Export-ScheduledTask -TaskName $definition.Name -TaskPath '\' | Set-Content -LiteralPath (Join-Path $projectRoot ($definition.File + '.task.xml')) -Encoding Unicode
    Write-Host "Configured: $($definition.Name)"
}


& (Join-Path $projectRoot 'Enable-Hotkey.ps1') -SkipStart


