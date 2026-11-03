[CmdletBinding()]
param([int]$Port = 18744)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$helper = Join-Path $projectRoot 'clock-helper.ps1'
function Assert-Check($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    Write-Output "PASS: $Message"
}
function Preview-Data([string]$At) {
    $raw = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $helper -Preview -PreviewTime $At
    if ($LASTEXITCODE -ne 0) { throw "Preview failed: $At" }
    $raw | ConvertFrom-Json
}
function Extract-Fragment([string]$Html, [string]$Start, [string]$End) {
    # Same literal substring boundaries as ExtractWebContent in the Windhawk mod.
    $position = $Html.IndexOf($Start, [StringComparison]::Ordinal)
    if ($position -lt 0) { throw "Missing start: $Start" }
    $position += $Start.Length
    $endAt = $Html.IndexOf($End, $position, [StringComparison]::Ordinal)
    if ($endAt -lt 0) { throw "Missing end: $End" }
    [Net.WebUtility]::HtmlDecode($Html.Substring($position, $endAt - $position))
}
$words = @(Import-Csv -LiteralPath (Join-Path $projectRoot 'words.csv') -Encoding UTF8)
Assert-Check ($words.Count -eq 3052) '3052 downloaded and filtered words'
Assert-Check (@($words | Where-Object { $_.level -notin @('B1','B2','C1') }).Count -eq 0) 'Only B1, B2 and C1'
Assert-Check (@($words | Where-Object { [string]::IsNullOrWhiteSpace($_.translation) }).Count -eq 0) 'Every word has a translation'
Assert-Check (@($words | Group-Object word | Where-Object Count -GT 1).Count -eq 0) 'No repeated headwords'
$a = Preview-Data '2026-11-03T00:00:00'
$b = Preview-Data '2026-11-03T03:59:59'
$c = Preview-Data '2026-11-03T04:00:00'
$day = Preview-Data '2026-11-03T12:00:00'
$night = Preview-Data '2026-11-03T23:59:59'
$midnight = Preview-Data '2026-11-04T00:00:00'
Assert-Check ($a.'/word' -eq $b.'/word') 'Same word throughout the four-hour slot'
Assert-Check ($b.'/word' -ne $c.'/word') 'Word changes at 04:00'
Assert-Check ($night.'/word' -ne $midnight.'/word') 'Word changes at midnight'
Assert-Check ($day.'/eyes' -eq '◉_◉' -and $night.'/eyes' -eq '－_－') 'Day and night eyes'
$baseUrl = "http://127.0.0.1:$Port"
$reply = Invoke-WebRequest -Uri ($baseUrl + '/') -UserAgent 'WindhawkMod' -UseBasicParsing -TimeoutSec 5
Assert-Check ($reply.StatusCode -eq 200 -and $reply.Headers['Content-Type'] -like 'text/html*') 'HTML served to WindhawkMod user agent'
Assert-Check ($reply.Content -notmatch '\{\{[A-Z_]+\}\}') 'No unresolved HTML placeholders'
$word = Extract-Fragment $reply.Content '<clock-word>' '</clock-word>'
$combined = Extract-Fragment $reply.Content '<clock-combined>' '</clock-combined>'
$meaning = Extract-Fragment $reply.Content '<clock-meaning>' '</clock-meaning>'
Assert-Check ($word.Length -gt 0 -and $combined.EndsWith($word)) 'Word and eyes extracted from literal HTML'
Assert-Check ($meaning.StartsWith($word + ' — ') -and $meaning -match '\[(B1|B2|C1)\]$') 'Russian meaning and CEFR extracted from literal HTML'
foreach ($path in @('/word','/meaning','/eyes','/combined')) {
    $response = Invoke-WebRequest -Uri ($baseUrl + $path) -UseBasicParsing -TimeoutSec 5
    Assert-Check ($response.StatusCode -eq 200 -and $response.Content.Length -gt 0) "Legacy route $path"
}
$request = [Net.HttpWebRequest]::Create($baseUrl + '/cambridge')
$request.AllowAutoRedirect = $false
$response = $request.GetResponse()
try {
    Assert-Check ([int]$response.StatusCode -eq 302) 'Cambridge returns a redirect'
    $destination = $response.Headers['Location']
    Assert-Check ($destination.StartsWith('https://dictionary.cambridge.org/search/english/direct/?q=')) 'Redirect points only to Cambridge Dictionary'
} finally { $response.Close() }
Write-Output ("Extracted: " + $combined + ' | ' + $meaning)
Write-Output 'NOTE: Actual Windhawk UI configuration and global shortcut activation are not tested here.'

