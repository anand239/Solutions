$date = Get-Date
$OutputFile = "Start_status.txt"
$ErrorFile  = "ErrorComputers.txt"

"$date" | Out-File $OutputFile -Encoding ASCII
"$date" | Out-File $ErrorFile  -Encoding ASCII

$Services = "tws_cpa_agent_metnet_at825112","tws_maestro_metnet_at825112","tws_cpa_ssm_agent_METNET_at825112","tws_netman_metnet_at825112","tws_ssm_agent_METNET_at825112","tws_tokensrv_METNET_at825112"
foreach($Service in $services)
{
    $ServiceStatus = (Get-Service -Name winrm).Status           
    if ($ServiceStatus -like "running")
    { 
        $result = Stop-Service -Name $Service
        write-host "$Computer -> $Service stopped succesfully"
        "$Computer -> $Service stopped succesfully" | Out-File $OutputFile -Encoding ASCII -Append
    }
    elseif($ServiceStatus -like "stopped")
    { 
        write-host "$Computer -> $Service already in stopped state"
        "$Computer -> $Service already in stopped state" | Out-File $OutputFile -Encoding ASCII -Append 
    }
    else
    {
        write-host "$Computer -> $Service not found"
        "$Computer -> $Service not found" | Out-File $OutputFile -Encoding ASCII -Append
    }
}
