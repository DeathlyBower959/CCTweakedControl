Add-Type -AssemblyName System.Net.WebSockets.Client
Add-Type -AssemblyName System.Text.Encoding

$reconnectInterval = 1
$global:exitFlag = $false

function Connect-WebSocket {
    param (
        [string]$uri
    )

    $websocket = [System.Net.WebSockets.ClientWebSocket]::new()
    $uri = [Uri]$uri

    while (-not $global:exitFlag) {
        try {
            $websocket.ConnectAsync($uri, [System.Threading.CancellationToken]::None).Wait()
            Write-Host "Connected to $uri"

            while ($websocket.State -eq [System.Net.WebSockets.WebSocketState]::Open -and -not $global:exitFlag) {
                Receive-WebSocketMessage -websocket $websocket
            }
        } catch {
            if (-not $global:exitFlag) {
                Write-Host "Connection lost. Reconnecting in $reconnectInterval second(s)..."
                Start-Sleep -Seconds $reconnectInterval
                $websocket.Dispose()
                $websocket = [System.Net.WebSockets.ClientWebSocket]::new()
            }
        }
    }
}

function Receive-WebSocketMessage {
    param (
        [System.Net.WebSockets.ClientWebSocket]$websocket
    )

    $buffer = New-Object 'byte[]' 1024
    $segment = [System.ArraySegment[byte]]$buffer

    try {
        $result = $websocket.ReceiveAsync($segment, [System.Threading.CancellationToken]::None).Result
        if ($result.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) {
            $websocket.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "Closing", [System.Threading.CancellationToken]::None).Wait()
            Write-Host "WebSocket closed"
        } else {
            $message = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $result.Count)
            Write-Host "$message"
            Write-Host ""
        }
    } catch {
        Write-Host "Error receiving message: $_"
    }
}

$uri = "ws://localhost:2828"

# Register event handler for Ctrl+C
Register-ObjectEvent -InputObject ([console]::CancelKeyPress) -EventName 'CancelKeyPress' -Action {
    $global:exitFlag = $true
    Write-Host "Exiting..."
    $websocket.Dispose()
    Stop-Job -Name Receive-WebSocketMessage -ErrorAction SilentlyContinue
    [System.Environment]::Exit(0)
}

Connect-WebSocket -uri $uri
