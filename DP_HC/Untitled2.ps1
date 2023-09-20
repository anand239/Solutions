Function Get-SessionList
{
    [CmdletBinding()]
    Param(
    $InputObject, 
    $CellManager,
    $SessionType,
    $Specification,
    $SessionId
    )
    $SessionList_converted = $InputObject.replace("`t",",")| Convertfrom-Csv -Header 'Object Type','Client','Mountpoint','Description','Object Name','Status',Mode,'Start Time','Start Time_t','End Time','End Time_t','Duration (hh:mm)','Size (kB)','Files','Performance (MB/min)','Protection','Errors',Warnings,Device
    $SessionList_Output = $SessionList_converted | select 'Object Type','Client','Mountpoint','Status',Mode,'Start Time','End Time','Duration (hh:mm)','Size (kB)','Performance (MB/min)','Protection',Device
    $SessionList_Result = @()
    foreach($line in $SessionList_Output)
    {
        $SessionList_Result   += [PSCustomObject] @{
        "Account"              = $config.account
        "BackupApplication"    = $config.BackupApplication
        "BackupServer"         = $BackupDevice
        "Date"                 = $ReportEndDate
        "Cell Manager"         = $CellManager
        "Session Type"         = $SessionType
        "Specification"        = $Specification
        "SessionId"            = $SessionId
        'Object Type'          = $line.'Object Type'
        'Client'               = $line.Client
        'Mountpoint'           = $line.Mountpoint
        'Status'               = $line.Status
        "Mode"                 = $line.Mode
        'Start Time'           = $line.'Start Time'
        'End Time'             = $line.'End Time'
        'Duration (hh:mm)'     = $line.'Duration (hh:mm)'
        'Size (kB)'            = $line.'Size (kB)'
        'Performance (MB/min)' = $line.'Performance (MB/min)'
        'Protection'           = $line.Protection
        "Device"               = $line.Device
        }
    }
    $SessionList_Result
}

Function Get-ObjectAddition
{
    [CmdletBinding()]
    Param(
    $InputObject
    )
    $Unique = $InputObject[0]
    $Size = ($InputObject | Measure-Object -Property "size (KB)" -Sum).Sum
    $Unique.'Size (kB)' = [math]::Round($Size,2)
    $Unique
} 
                    foreach($session in $ListOfSessions)
                    {
                        $SessionId = $session.'session id'
                        $SessionList_Command = $config.SessionObjectsCommand_Windows -replace "SessionID", $SessionId
                        $SessionList_CommandOutput = Invoke-BackupReportingCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $SessionList_Command -logFile $Activitylog
                        $SessionList_Fun_Output = Get-SessionList -InputObject $SessionList_CommandOutput -CellManager $CellManager -SessionType $session.'Session Type' -Specification $session.Specification -SessionId $SessionId
                        if($SessionList_Fun_Output)
                        {
                            $BCRs += Get-ObjectAddition -InputObject $SessionList_Fun_Output
                            $SessionList += $SessionList_Fun_Output
                        }
                    }                
                    if($DPVersion -le 7)
                    {
                        foreach($line in $SessionList)
                        {
                            if($line.Description -contains "VEagent")
                            {
                                $Client = ($line.Description -split "%")[4].Remove(0,1)
                                $line.Client = $Client
                            }
                        }
                        foreach($BCR in $BCRs)
                        {
                            if($BCR.Description -contains "VEagent")
                            {
                                $BCRClient = ($BCR.Description -split "%")[4].Remove(0,1)
                                $line.Client = $BCRClient
                            }
                        }
                    }
