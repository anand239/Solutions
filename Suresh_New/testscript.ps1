$RawClients = Get-Content "C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\Suresh_New\datacollection\cell_info" | where{$_}
$Clients = @()
foreach($RawClient in $RawClients)
{
    $Clients += (($RawClient -split "\s")[1] -replace "`"").Split(".")[0]
}

$InitialReport = @()

$RawIpAddress = Get-Content "C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\Suresh_New\datacollection\hosts"
foreach($Client in $Clients)
{
    $found = $RawIpAddress | Select-String -Pattern "$Client"
    if($found)
    {
        $Available = $found | where{$_ -notlike "*#*"}
        if($Available)
        {
            $IpAddress = ($Available -split "\s")[0].Trim()
        }
        else
        {
            $IpAddress = "Commented"
        }
    }
    else
    {
        $IpAddress = "Not Found"
    }
    $InitialReport += [pscustomobject] @{
    "Client Name"   = $Client
    "Ip Address"    = $IpAddress
    }

}