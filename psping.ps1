param(
    [Parameter(Position = 0, Mandatory = $true)]
    [string]$TargetIP,

    [Parameter(Position = 1, Mandatory = $true)]
    [int]$Port,

    [Parameter()]
    [switch]$t,

    [Parameter()]
    [int]$Count = 5,

    [Parameter()]
    [int]$TimeoutMs = 2000,

    [Parameter()]
    [int]$IntervalMs = 1000
)

if ($t) {
    $Count = [int]::MaxValue
}

Write-Host "TCPING ${TargetIP}:${Port}"
if ($t) {
    Write-Host "Mode: Continuous (-t)"
} else {
    Write-Host "Mode: $Count probes"
}
Write-Host "----------------------------------------------"

$latencies = @()
$sent = 0
$received = 0

try {
    for ($i = 1; $i -le $Count; $i++) {

        $sent++
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        try {
            $async = $tcpClient.BeginConnect($TargetIP, $Port, $null, $null)

            if (-not $async.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) {
                throw "Timeout"
            }

            $tcpClient.EndConnect($async)
            $sw.Stop()

            $latency = $sw.ElapsedMilliseconds
            $latencies += $latency
            $received++

            Write-Host "Connected to ${TargetIP}:${Port} - time=${latency}ms"
        }
        catch {
            Write-Host "Connection to ${TargetIP}:${Port} failed (timeout)"
        }
        finally {
            $tcpClient.Close()
        }

        Start-Sleep -Milliseconds $IntervalMs
    }
}
catch [System.Management.Automation.StopException] {
    # Ctrl+C
}
finally {
    Write-Host "`n--- ${TargetIP}:${Port} tcping statistics ---"

    $loss = if ($sent -gt 0) {
        [math]::Round((($sent - $received) / $sent) * 100, 2)
    } else {
        0
    }

    if ($latencies.Count -gt 0) {
        $min = ($latencies | Measure-Object -Minimum).Minimum
        $max = ($latencies | Measure-Object -Maximum).Maximum
        $avg = [math]::Round(($latencies | Measure-Object -Average).Average, 2)

        Write-Host "Packets: Sent = $sent, Received = $received, Lost = $($sent - $received) ($loss% loss)"
        Write-Host "Approximate round trip times in milli-seconds:"
        Write-Host "Minimum = ${min}ms, Maximum = ${max}ms, Average = ${avg}ms"
    }
    else {
        Write-Host "Packets: Sent = $sent, Received = 0, Lost = $sent (100% loss)"
    }
}
