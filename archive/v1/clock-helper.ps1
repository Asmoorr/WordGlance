[CmdletBinding()]
param(
    [ValidateRange(1024,65535)][int]$Port = 18743,
    [datetime]$PreviewTime = [datetime]::MinValue,
    [switch]$Preview
)
$ErrorActionPreference = 'Stop'
$words = @(Import-Csv -LiteralPath (Join-Path $PSScriptRoot 'words.csv') -Encoding UTF8)
if ($words.Count -eq 0) { throw 'words.csv is empty.' }
function Get-ClockData([datetime]$Moment) {
    $days = ($Moment.Date - [datetime]'2026-01-01').Days
    $index = (($days % $words.Count) + $words.Count) % $words.Count
    $entry = $words[$index]
    $hour = $Moment.Hour
    $eyes = if ($hour -lt 6) { '－_－' }
        elseif ($hour -lt 9) { '◔_◔' }
        elseif ($hour -lt 18) { '◉_◉' }
        elseif ($hour -lt 22) { 'ᵔ_ᵔ' }
        else { '－_－' }
    return @{
        '/word' = $entry.word
        '/meaning' = "$($entry.word) — $($entry.translation)"
        '/eyes' = $eyes
        '/combined' = "$eyes · $($entry.word)"
    }
}
if ($Preview) {
    if ($PreviewTime -eq [datetime]::MinValue) { $PreviewTime = Get-Date }
    Get-ClockData $PreviewTime | ConvertTo-Json -Compress
    exit
}
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
try {
    $listener.Start()
    Write-Host "Windhawk helper: http://127.0.0.1:$Port/combined"
    Write-Host 'Minimize this window. Close it to stop the helper.'
    while ($true) {
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
                $path = ($parts[1] -split '\?', 2)[0]
                $data = Get-ClockData (Get-Date)
                $status = '200 OK'
                if ($parts[0] -ne 'GET') {
                    $status = '405 Method Not Allowed'
                    $body = 'GET only'
                } elseif ($data.ContainsKey($path)) {
                    $body = $data[$path]
                } else {
                    $status = '404 Not Found'
                    $body = 'Use /word /eyes /combined /meaning'
                }
                $bytes = [System.Text.Encoding]::UTF8.GetBytes([string]$body)
                $headers = "HTTP/1.1 $status\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: $($bytes.Length)\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n"
                $headers = $headers.Replace('\r\n', "`r`n")
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
    Read-Host 'Press Enter to close'
} finally { $listener.Stop() }

