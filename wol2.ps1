function Send-WakeOnLan {
    param(
        [Parameter(Mandatory=$true)]
        [string]$MacAddress,
        [string]$Broadcast = "192.168.0.255",
        [int]$Port = 9
    )
    # Clean up MAC (remove separators)
    $mac = $MacAddress -replace "[:\-\.]", ""
    if ($mac.Length -ne 12) {
        throw "Invalid MAC address format"
    }
    # Convert MAC string to byte array
    $macBytes = for ($i=0; $i -lt 12; $i+=2) {
        [byte]::Parse($mac.Substring($i,2), "HexNumber")
    }
    # Build magic packet
    $packet = (,[byte]0xFF * 6) + ($macBytes * 16)
    # Create UDP client and send
    $udp = New-Object System.Net.Sockets.UdpClient
    $udp.EnableBroadcast = $true
    $udp.Connect($Broadcast, $Port)
    $udp.Send($packet, $packet.Length) | Out-Null
    $udp.Close()
    Write-Host "Magic packet sent to $MacAddress via $Broadcast"
}

$Broadcast = "192.168.0.255"
$Machines = @(
    @{ MacAddress = "30-5A-3A-55-FA-E6"; Name = "Piaget 1" }
)

Write-Host "Clearing ARP table..." -ForegroundColor Yellow
try {
    netsh interface ip delete arpcache | Out-Null
    Write-Host "ARP table cleared successfully" -ForegroundColor Green
} catch {
    Write-Host "Warning: Could not clear ARP table - $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "Sending Wake-on-LAN packets..." -ForegroundColor Yellow
$Machines | ForEach-Object {
    Write-Host "Waking up $($_.Name) ($($_.MacAddress))..." -ForegroundColor Cyan
    Send-WakeOnLan -MacAddress $_.MacAddress -Broadcast $Broadcast
}

Write-Host "`nMonitoring for boot status..." -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop monitoring`n" -ForegroundColor Gray

$BootedMachines = @()
$TimeoutSeconds = 300
$StartTime = Get-Date
$ResendInterval = 30  # Resend WoL packets every 30 seconds
$LastResendTime = $StartTime

while ($true) {
    $ElapsedTime = (Get-Date) - $StartTime
    if ($ElapsedTime.TotalSeconds -ge $TimeoutSeconds) {
        Write-Host "`n`nTimeout reached (300 seconds)!" -ForegroundColor Red
        
        $UnbootedMachines = $Machines | Where-Object { $_.MacAddress -notin $BootedMachines }
        if ($UnbootedMachines.Count -gt 0) {
            Write-Host "The following machines did not boot:" -ForegroundColor Red
            $UnbootedMachines | ForEach-Object {
                Write-Host "$($_.Name) ($($_.MacAddress))" -ForegroundColor Red
            }
        }
        break
    }

    $TimeSinceLastResend = (Get-Date) - $LastResendTime
    if ($TimeSinceLastResend.TotalSeconds -ge $ResendInterval) {
        $UnbootedMachines = $Machines | Where-Object { $_.MacAddress -notin $BootedMachines }
        if ($UnbootedMachines.Count -gt 0) {
            Write-Host "`n[Resending WoL packets to unbooted machines...]" -ForegroundColor Yellow
            $UnbootedMachines | ForEach-Object {
                Write-Host "  Resending to $($_.Name)..." -ForegroundColor Cyan
                Send-WakeOnLan -MacAddress $_.MacAddress -Broadcast $Broadcast
            }
            $LastResendTime = Get-Date
        }
    }
    
    $neighbors = Get-NetNeighbor -AddressFamily IPv4 -ErrorAction SilentlyContinue
    
    foreach ($machine in $Machines) {
        if ($machine.MacAddress -in $BootedMachines) {
            continue
        }
        
        $cleanMac = $machine.MacAddress -replace "[:\-\.]", ""
        
        $foundNeighbor = $neighbors | Where-Object { 
            ($_.LinkLayerAddress -replace "[:\-\.]", "") -eq $cleanMac 
        }
        
        if ($foundNeighbor) {
            Write-Host "$($machine.Name) is now online! IP: $($foundNeighbor.IPAddress)" -ForegroundColor Green
            $BootedMachines += $machine.MacAddress
        }
    }
    
    if ($BootedMachines.Count -eq $Machines.Count) {
        Write-Host "`nAll machines are now online!" -ForegroundColor Green
        break
    }
    
    Start-Sleep -Seconds 5
    
    Write-Host "." -NoNewline -ForegroundColor Gray

}