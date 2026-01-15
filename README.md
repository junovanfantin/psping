# psping – TCP Ping em PowerShell

![PSPING](./PSPING.png)

Em ambientes corporativos, especialmente em cenários com **firewalls, balanceadores, proxies e aplicações distribuídas**, o ICMP tradicional (`ping`) nem sempre reflete a real disponibilidade de um serviço. Nesses casos, testar **conectividade TCP por porta** é fundamental.

Ferramentas como **tcping** e **paping** resolvem esse problema, mas nem sempre estão disponíveis ou permitidas em ambientes restritos. Pensando nisso, desenvolvi o **psping**, uma implementação **100% PowerShell**, sem dependências externas, que replica o comportamento dessas ferramentas clássicas.

---

## O que é o psping?

O **psping** é um script PowerShell que executa testes de conectividade **TCP real**, medindo:

- Latência por tentativa
- Número de conexões bem-sucedidas
- Packet loss
- Estatísticas de tempo mínimo, médio e máximo

Tudo isso utilizando apenas recursos nativos do PowerShell, compatível com **PowerShell 5.x e 7+**.

---

## Principais características

- Conexão TCP real (porta específica)
- Parâmetros **posicionais** (IP e porta)
- Modo contínuo (`-t`), igual ao tcping/paping
- Execução padrão com **5 tentativas**
- Estatísticas exibidas ao final
- Encerramento limpo com `Ctrl+C`
- Sem dependências externas
- Ideal para ambientes corporativos restritos

---

## Sintaxe de uso

### Execução padrão (5 tentativas)

```powershell
.\psping.ps1 8.8.8.8 443
```
```Execução contínua (modo -t)
.\psping.ps1 8.8.8.8 443 -t
```

```Ajustando timeout e intervalo entre probes
.\psping.ps1 8.8.8.8 443 -t -TimeoutMs 3000 -IntervalMs 500
```

```Script completo – psping.ps1
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
```

Quando usar o psping?

O psping é útil em cenários como:

Validação de portas TCP em firewalls

* Troubleshooting de aplicações HTTP/HTTPS
* Testes de conectividade em ambientes sem ICMP
* Diagnóstico de latência em serviços específicos
* Ambientes corporativos sem permissão para binários externos

Conclusão
O psping oferece uma alternativa leve, transparente e auditável às ferramentas tradicionais de TCP ping. Por ser escrito em PowerShell puro, ele se encaixa perfeitamente em ambientes corporativos, automações e rotinas de troubleshooting avançado.

