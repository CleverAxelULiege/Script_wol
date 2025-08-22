
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
    Write-Host $Broadcast
}

$Broadcast = "192.168.0.255"

$MacAddresses = @(
    'Mac address 1',
    'Mac address 2',
    'Mac address 3',
    'Mac address 4'
)

# Send-WakeOnLan -MacAddress "30-5A-3A-55-FA-E6" -Broadcast $broadcast

$MacAddresses | ForEach-Object {
    Send-WakeOnLan -MacAddress $_ -Broadcast $broadcast
}
