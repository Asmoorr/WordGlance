[CmdletBinding()]
param(
    [ValidateRange(1024,65535)][int]$Port = 18743,
    [datetime]$PreviewTime = [datetime]::MinValue,
    [switch]$Preview,
    [switch]$RenderHtml,
    [switch]$Background
)
$ErrorActionPreference = 'Stop'
$words = @(Import-Csv -LiteralPath (Join-Path $PSScriptRoot 'words.csv') -Encoding UTF8)
if ($words.Count -eq 0) { throw 'words.csv is empty.' }
function Get-ClockData([datetime]$Moment) {
    $slot = [long][math]::Floor(($Moment - [datetime]'2026-01-01').TotalHours / 4)
    $index = (($slot % $words.Count) + $words.Count) % $words.Count
    $entry = $words[$index]
    $hour = $Moment.Hour
    $eyes = if ($hour -lt 6) { '－_－' }
        elseif ($hour -lt 9) { '◔_◔' }
        elseif ($hour -lt 18) { '◉_◉' }
        elseif ($hour -lt 22) { 'ᵔ_ᵔ' }
        else { '－_－' }
    $next = $Moment.Date.AddHours(([math]::Floor($hour / 4) + 1) * 4)
    $url = 'https://dictionary.cambridge.org/search/english/direct/?q=' + [uri]::EscapeDataString($entry.word)
    return @{
        '/word' = $entry.word
        '/meaning' = "$($entry.word) — $($entry.translation) [$($entry.level)]"
        '/eyes' = $eyes
        '/combined' = "$eyes · $($entry.word)"
        '/level' = $entry.level
        '/translation' = $entry.translation
        '/pos' = $entry.pos
        '/next' = $next.ToString('HH:mm')
        '/details' = "$($entry.word) — $($entry.translation) [$($entry.level), $($entry.pos)]. Next: $($next.ToString('HH:mm')). Cambridge: Open-Cambridge.cmd"
        '/cambridge-url' = $url
    }
}
function Get-Page([datetime]$Moment) {
    $data = Get-ClockData $Moment
    $tokens = @{
        WORD = $data['/word']; TRANSLATION = $data['/translation']
        LEVEL = $data['/level']; POS = $data['/pos']; EYES = $data['/eyes']
        COMBINED = $data['/combined']; MEANING = $data['/meaning']
        CAMBRIDGE = $data['/cambridge-url']; NEXT = $data['/next']
        COUNT = [string]$words.Count; CLOCK = $Moment.ToString('M dd HH:mm')
        LOCAL_URL = "http://127.0.0.1:$Port/"
    }
    foreach ($key in @($tokens.Keys)) {
        $tokens[$key] = [System.Net.WebUtility]::HtmlEncode([string]$tokens[$key])
    }
    $slotNow = [int][math]::Floor($Moment.Hour / 4)
    $segments = for ($i = 0; $i -lt 6; $i++) {
        if ($i -eq $slotNow) { '<span class="slot active"></span>' }
        else { '<span class="slot"></span>' }
    }
    $tokens['SLOTS'] = $segments -join ''
    $template = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'index.html') -Encoding UTF8
    return [regex]::Replace($template, '\{\{([A-Z_]+)\}\}', {
        param($match)
        $tokens[$match.Groups[1].Value]
    })
}
if ($Preview) {
    if ($PreviewTime -eq [datetime]::MinValue) { $PreviewTime = Get-Date }
    if ($RenderHtml) { Get-Page $PreviewTime }
    else { Get-ClockData $PreviewTime | ConvertTo-Json -Compress }
    exit
}
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
try {
    $listener.Start()
    Write-Host "WordGlance: http://127.0.0.1:$Port/"
    Write-Host "$($words.Count) words. New word every 4 hours (00, 04, 08, 12, 16, 20)."
    Write-Host 'Open-Cambridge.cmd opens the current word in Cambridge Dictionary.'
    Write-Host 'Minimize this window. Close it to stop the helper.'
    while ($true) {
        if (-not $listener.Pending()) {
            Start-Sleep -Milliseconds 100
            continue
        }
        $client = $listener.AcceptTcpClient()
        try {
            $client.ReceiveTimeout = 2500
            $client.SendTimeout = 2500
            $stream = $client.GetStream()
            $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::ASCII, $false, 1024, $true)
            try {
                $requestLine = $reader.ReadLine()
                if ([string]::IsNullOrEmpty($requestLine)) { continue }
                $headerSize = $requestLine.Length
                do {
                    $header = $reader.ReadLine()
                    if ($null -eq $header) { break }
                    $headerSize += $header.Length
                    if ($headerSize -gt 16384) { throw 'Request headers too large.' }
                } while ($header.Length -gt 0)
                $parts = $requestLine.Split(' ')
                if ($parts.Count -lt 2) { continue }
                $path = ($parts[1] -split '\?', 2)[0]
                $data = Get-ClockData (Get-Date)
                $status = '200 OK'
                $extraHeaders = ''
                $contentType = 'text/plain; charset=utf-8'
                if ($parts[0] -ne 'GET') {
                    $status = '405 Method Not Allowed'
                    $body = 'GET only'
                } elseif ($path -in @('/', '/index.html')) {
                    $contentType = 'text/html; charset=utf-8'
                    $body = Get-Page (Get-Date)
                } elseif ($path -eq '/cambridge') {
                    $status = '302 Found'
                    $extraHeaders = "Location: $($data['/cambridge-url'])`r`n"
                    $body = 'Opening Cambridge Dictionary'
                } elseif ($data.ContainsKey($path)) {
                    $body = $data[$path]
                } else {
                    $status = '404 Not Found'
                    $body = 'Use / /word /eyes /combined /meaning /details /level /cambridge'
                }
                $bytes = [System.Text.Encoding]::UTF8.GetBytes([string]$body)
                $headers = "HTTP/1.1 $status`r`nContent-Type: $contentType`r`nContent-Length: $($bytes.Length)`r`nCache-Control: no-store`r`n" + $extraHeaders + "Connection: close`r`n`r`n"
                $headBytes = [System.Text.Encoding]::ASCII.GetBytes($headers)
                $stream.Write($headBytes, 0, $headBytes.Length)
                $stream.Write($bytes, 0, $bytes.Length)
                $stream.Flush()
            } finally { $reader.Dispose() }
        } catch {
            Write-Warning $_.Exception.Message
        } finally { $client.Close() }
    }
} catch {
    Write-Host "Could not start the helper: $($_.Exception.Message)" -ForegroundColor Red
    if ($Background) { throw }
    Read-Host 'Press Enter to close'
} finally {
    $listener.Stop()
}


