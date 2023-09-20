$fourthparam = "2"
Function Get-ListOfSessions
{
    [CmdletBinding()]
    Param(
    $InputObject
    )
    #omnirpt -report list_sessions -timeframe $previous 18:00 $current 17:59 -tab -no_copylist -no_verificationlist -no_conslist
    $CellManager = (($InputObject | Select-String -Pattern "Cell Manager") -split ":")[1].trim()
    $ListOfSessions_converted = $InputObject.replace("`t",",")| Convertfrom-Csv -Header 'Session Type','Specification','Status','Mode','Start Time','Start Time_t','End Time','End Time_t','Queuing', 'Duration','GB Written','Media','Errors','Warnings','Pending DA','Running DA','Failed DA','Completed DA','Object','Files','Success','Session Owner','Session ID'
    $ListOfSessions_Result = $ListOfSessions_converted|select 'Session Type','Specification','Session ID'
    $ListOfSessions_Result,$CellManager
}

Function Get-SessionList
{
    [CmdletBinding()]
    Param(
    $InputObject, # = Get-Content "C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\DP\DP_Reporting\Files\SessionObjectReplication.txt"
    $CellManager,
    $SessionType,
    $Specification,
    $SessionId
    )
    $SessionList_converted = $InputObject.replace("`t",",")| Convertfrom-Csv -Header 'Object Type','Client','Mountpoint','Description','Object Name','Status',Mode,'Start Time','Start Time_t','End Time','End Time_t','Duration [hh:mm]','Size [kB]','Files','Performance [MB/min]','Protection','Errors',Warnings,Device
    $SessionList_Output = $SessionList_converted | select 'Object Type','Client','Mountpoint','Status',Mode,'Start Time','End Time','Duration [hh:mm]','Size [kB]','Performance [MB/min]','Protection',Device
    $SessionList_Result = @()
    foreach($line in $SessionList_Output)
    {
        $SessionList_Result   += [PSCustomObject] @{
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
        'Duration [hh:mm]'     = $line.'Duration [hh:mm]'
        'Size [kB]'            = $line.'Size [kB]'
        'Performance [MB/min]' = $line.'Performance [MB/min]'
        'Protection'           = $line.Protection
        "Device"               = $line.Device
        }
    }
    $SessionList_Result
}


$SessionList = @()
for($i=1;$i -le $fourthparam ;$i++)
{
    $StartDate = (get-date).AddDays(-$i).ToString("yy/MM/dd")
    $EndDate = (get-date).AddDays(-($i-1)).ToString("yy/MM/dd")
    "$startdate 18:00 - $EndDate 18:00"
    
    #omnirpt -report list_sessions -timeframe $StartDate 18:00 $EndDate 18:00 -tab
    $Command = Get-Content 'C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\DP\DP_Monitoring\Files\ListOfSession1.txt'
    $ListOfSessions,$CellManager = @(Get-ListOfSessions -InputObject $Command)
    
    $DpVersionCommand = "HPE Data Protector A.09.08: OMNICHECK, internal build 113, built on Tuesday, January 24, 2017, 4:04 PM"
    [int]$DPVersion = $DpVersionCommand.Substring(21,2)
    if($DPVersion -le 7)
    {
        foreach($session in $ListOfSessions)
        {
            $SessionId = $session.'session id'
            $SessionList_Command = Get-Content "C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\DP\DP_Reporting\Files\SessionObjectReplication.txt"
            $SessionList += Get-SessionList -InputObject $SessionList_Command -CellManager $CellManager -SessionType $session.'Session Type' -Specification $session.Specification -SessionId $SessionId
            foreach($line in $SessionList)
            {
                if($line.Description -contains "VEagent")
                {
                    $Client = ($line.Description -split "%")[4].Remove(0,1)
                    $line.Client = $Client
                }
            }
        }
    }
    else
    {
        foreach($session in $ListOfSessions)
        {
            $SessionId = $ListOfSessions.'session id'
            $SessionList_Command = Get-Content "C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\DP\DP_Reporting\Files\SessionObjectReplication.txt"
            $SessionList += Get-SessionList -InputObject $SessionList_Command -CellManager $CellManager -SessionType $session.'Session Type' -Specification $session.Specification -SessionId $SessionId
        }
    }
}