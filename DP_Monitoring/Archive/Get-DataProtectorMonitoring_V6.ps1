cls
Function Get-ListOfSessions
{
    [CmdletBinding()]
    Param(
    #[parameter(Mandatory = $true)]
    $InputObject
    )
    #omnirpt -report list_sessions -timeframe $previous 18:00 $current 17:59 -tab -no_copylist -no_verificationlist -no_conslist

    $ListOfSessions_converted = $InputObject.replace("`t",",")| Convertfrom-Csv -Header 'Session Type','Specification','Status','Mode','Start Time','Start Time_t','End Time','End Time_t','Queuing', 'Duration','GB Written','Media','Errors','Warnings','Pending DA','Running DA','Failed DA','Completed DA','Object','Files','Success','Session Owner','Session ID'
    $ListOfSessions_Result = $ListOfSessions_converted
    $ListOfSessions_Result
}

$Command = Get-Content 'C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\DP\DP_Monitoring\Files\ListOfSession1.txt'
$ListOfSessions = @(Get-ListOfSessions -InputObject $Command)

if(!($ListOfSessions))
{
    #send mail
    Write-Host "Sending mail"
    Exit
}

###### Step - 3 ############
$SessionType_Backup = $ListOfSessions | Where-Object {$_.'Session Type' -eq "Backup"} | Select-Object 'Specification','Status','session id',mode,'End Time'

$Completed_Sessions = $SessionType_Backup | Where-Object {$_.status -eq "Completed"}
if($Completed_Sessions)
{
    $completed_Client = @()
    foreach($Completed_Session in $Completed_Sessions)
    {
        $Completed_SessionId = $Completed_Session.'session id'
        $End_Time = $Completed_Session.'End Time'
        $SessionIdObjectReport = Get-Content 'C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\DP\DP_Monitoring\Files\SessionIDObjectReport.txt' | select -Skip 2
        if($SessionIdObjectReport)
        {
            $pattern = '(?<=\[).+?(?=\])'
            foreach($object in $SessionIdObjectReport)
            {
                $SessionIdObjectReport_Split = $object -split "\s" | where{$_}
                $Host_Name  = ($Object -split ":")[0]
                $MountPoint = [regex]::Matches($SessionIdObjectReport_Split[2], $pattern).Value
                $BkpType    = $SessionIdObjectReport_Split[3]
                $ObjectStatus = $SessionIdObjectReport_Split[4]

                $completed_Client += [pscustomobject] @{
                "Specification"    = $Completed_Session.Specification
                "Session Id"       = $Completed_Session.'Session ID'
                "Mode"             = $Completed_Session.Mode
                "BkpType"          = $BkpType
                "Client"           = "$Host_Name"
                "Mount Point"      = "$MountPoint"
                "Object Status"    = $ObjectStatus
                "End Time"         = $End_Time
                }
            }
        }
    }
}
$completed_Client | Export-Csv 'C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\DP\DP_Monitoring\Files\Event.csv' -NoTypeInformation -Append
###### Step - 5 ############
$Failed_Sessions = $SessionType_Backup | Where-Object {($_.status -ne "Completed") -and ($_.status -ne "In Progress")}
if($Failed_Sessions)
{
    $Failed_Client = @()
    foreach($Failed_Session in $Failed_Sessions)
    {
        #$Failed_Session.Specification
        $Failed_SessionId = $Failed_Session.'session id'
        $End_Time = $Failed_Session.'End Time'
        # omnidb –session FailedBKPSessionID -report
        $Failed_SessionLog = Get-Content 'C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\DP\DP_Monitoring\Files\SessionLog.txt'
        if($Failed_SessionLog)
        {
            $Critical_Major = @()
            $Replace = (($Failed_SessionLog) -replace '^$','#')
            $pattern = '#'*1  
            $content =$Replace | Out-String
            $Logs = $content.Split($pattern,[System.StringSplitOptions]::RemoveEmptyEntries)
            foreach($log in $Logs)
            {
                if($Log -like "*Major*" -or $Log -like "*Critical*")
                {
                    $Critical_Major += $Log
                }
            }
            if($Critical_Major)
            {
                $InetHostNames = @()
                foreach($log in $Critical_Major )
                {
                    if(($log -like "*Could not connect to inet in order to start*") -or ($log -like "*Cannot connect to inet for getting*") -or ($log -like "*Cannot connect to inet for starting*"))
                    {
                        if($log -like "*VBDA*")
                        {
                            $log_split = $log -split "VBDA@"
                            $InetHost = $log_split[1] -split "\s"
                            $InetHostNames += $InetHost[0].Trim()
                        }
                        elseif($log -like "*host*")
                        {
                            $log_split = $log -split "host"
                            $InetHost = $log_split[1] -split '"'
                            $InetHostNames += $InetHost[1].Trim()
                        }
                    }
                }
                $InetHostNames = $InetHostNames | select -Unique
            }
            else
            {
                Write-Host "end as AutoDiagnose"
                Write-Host "No Critical or Major" -BackgroundColor Red
                Exit
            }
            ###### Step - 8 ############
            # omnidb –session FailedBKPSessionID
            $SessionIdObjectReport = Get-Content 'C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\DP\DP_Monitoring\Files\SessionIDObjectReport.txt'
            if($SessionIdObjectReport)
            {
                foreach($InetHostName in $InetHostNames)
                {
                    if($SessionIdObjectReport -notcontains $InetHostName)
                    {
                        $Failed_Client += [pscustomobject] @{
                        "Specification" = $Failed_Session.Specification
                        "Session Id"    = $Failed_Session.'Session ID'
                        "Mode"          = $Failed_Session.Mode
                        "BkpType"       = $BkpType
                        "Client"        = "$InetHostName"
                        "Mount Point"   = "Inet"
                        "Object Status" = "Failed"
                        "End Time"      = $End_Time
                        }
                    }
                }
                
                $FailedObject = $SessionIdObjectReport  #| Select-String -Pattern "Failed"
                if($FailedObject)
                {
                    <#
                    $MountPoint = ""
                    foreach($object in $FailedObject)
                    {
                        $Host_Name  = ($Object -split ":")[0]
                        $MountPoint = ((($object -split "\s+")[2]).Split("[")[1]).split("]")[0] + "," + $MountPoint
                    }
                    #$Host_Name
                    $Failed_Client += [pscustomobject] @{
                    "Client"        = "$Host_Name"
                    "Mount Point"   = "$MountPoint"
                    "Specification" = $Failed_Session.Specification
                    "Session Id"    = $Failed_Session.'Session ID'
                    "Mode"          = $Failed_Session.Mode
                    }
                    #>
                    $MountPoint = ""
                    $pattern = '(?<=\[).+?(?=\])'
                    foreach($object in $FailedObject)
                    {
                        $FailedObject_Split = $object -split "\s" | where{$_}
                        $Host_Name  = ($Object -split ":")[0]
                        $MountPoint = [regex]::Matches($FailedObject_Split[2], $pattern).Value
                        $BkpType    = $FailedObject_Split[3].trim()
                        $ObjectStatus = $FailedObject_Split[4].trim()
                        
                        $Failed_Client += [pscustomobject] @{
                        "Specification" = $Failed_Session.Specification
                        "Session Id"    = $Failed_Session.'Session ID'
                        "Mode"          = $Failed_Session.Mode
                        "BkpType"       = $BkpType
                        "Client"        = "$Host_Name"
                        "Mount Point"   = "$MountPoint"
                        "Object Status" = $ObjectStatus
                        "End Time"      = $End_Time
                        }
                     }
                }

                ######## Step - 9 #########
                $Error_Log = ($Critical_Major.Split([Environment]::NewLine)|where{$_} |select -Skip 1| select -First 1).substring(0,45)

                ######## Step - 10 #########

                $Failed_Client | Export-Csv 'C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\DP\DP_Monitoring\Files\Event.csv' -Append -NoTypeInformation
                $Failed_Clients_only = $Failed_Client | Where-Object{$_.status -eq "Failed" -and $_.status -eq "Aborted"}
                $Failed_Clients_only | Export-Csv 'C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\DP\DP_Monitoring\Files\DP_MON_Detail.csv' -Append -NoTypeInformation

            }
            else
            {
                Write-Host "end as AutoDiagnose"
                Write-Host "No SessionIdObjectReport" -BackgroundColor Red
                Exit
            }
        }
        else
        {
            #send mail
            Write-Host "Sending mail"
            Exit
        }
    }
}
else
{
    #send mail
    Write-Host "Sending mail"
    Exit
}


######## Step - 11 #########
$EventImport = Import-Csv "C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\DP\DP_Monitoring\files\event1.csv"

$Groups = $EventImport | Group-Object Sepcification,sessionid, mode
$Ticketlog = @()
foreach($group in $groups)
{
    $count = @(($group.Group | select-Object hostname).hostname)
    $count = @(($group.Group | group-Object hostname).name)
    if($count.count -gt 1)
    {
        ($group.Group | select -Last 1).hostname = "Multiple"
        $TicketLog += $group.Group  | select -Last 1
    }
    else
    {
        $TicketLog +=  $group.Group  | select -Last 1
    }
}
$Ticketlog | Out-File ./ticket.log

######## Step - 13 #########

$DP_Mon_Detail = Import-Csv "C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\DP\DP_Monitoring\Files\DP_Mon_Detail.csv"
$today = Get-Date
$yesterday = [datetime]"$($today.AddDays(-1).ToString("MM/dd/yyyy")) 18:00"
$DP_Mon_Detail_Validation = @()
foreach($line in $DP_Mon_Detail)
{
    $Filedate = [datetime]$line.'End time'
    $timespan = (New-TimeSpan -Start $Filedate -End $today).TotalDays
    if(-not($timespan -gt 35))
    {
        if($Filedate -lt $yesterday)
        {
            $DP_Mon_Detail_Validation += [pscustomobject] @{
            "Sepcification" = $line.Sepcification
            "Session ID"    = $line.'Session ID'
            "Mode"          = $line.Mode
            "HostName"      = $line.HostName
            "Object Status" = $line.'Object Status'
            "End Time"      = $line.'End Time'
            "Validation"    = "Skip"
            }
        }
        else
        {
            $DP_Mon_Detail_Validation += [pscustomobject] @{
            "Sepcification" = $line.Sepcification
            "Session ID"    = $line.'Session ID'
            "Mode"          = $line.Mode
            "HostName"      = $line.HostName
            "Object Status" = $line.'Object Status'
            "End Time"      = $line.'End Time'
            "Validation"    = ""
            }
        }
    }
}

$NoSkip = $DP_Mon_Detail_Validation | Where-Object {$_.validation -ne "Skip"}
$DP_Mon_Detail_Group = $NoSkip | Group-Object Sepcification,Mode,HostName

$DP_Mon_Detail_NoDuplicate = @()

foreach($DetailGroup in $DP_Mon_Detail_Group)
{
    if($DetailGroup.count -gt 1)
    {
        $DP_Mon_Detail_NoDuplicate += $DetailGroup.group | select -First 1
    }
    else
    {
        $DP_Mon_Detail_NoDuplicate += $DetailGroup.group
    }
}

$EventData = Import-Csv "C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\DP\DP_Monitoring\Files\Event1.csv" | foreach{$i=0}{$_ | Add-Member Index ($i++) -PassThru}

[System.Collections.ArrayList]$DP_Mon_Detail_Unique = $DP_Mon_Detail_NoDuplicate | foreach{$i=0}{$_ | Add-Member Index ($i++) -PassThru}
foreach($uniqueline in $DP_Mon_Detail_Unique)
{
    $linenumber = ($EventData | Where-Object{$_.Sepcification -eq $uniqueline.Sepcification -and $_.SessionId -eq $uniqueline.SessionId -and $_.hostname -eq $uniqueline.hostname}).index
    if($linenumber)
    {
        $DataMatched = $EventData | Where-Object{$_.index -gt $linenumber}
        $UniqueMatched = $DataMatched | Where-Object{$_.Sepcification -eq $uniqueline.Sepcification -and $_.Mode -eq $uniqueline.Mode -and $_.hostname -eq $uniqueline.hostname}
        if($UniqueMatched)
        {
            $DP_Mon_Detail_NoDuplicate.RemoveAt($uniqueline.index)
        }
    }
}



######## Step - 14 #########
$DP_MON_Import = Import-Csv ".\DP_MON_Detail.csv"

$DP_MON_Groups = $DP_MON_Import | Group-Object Sepcification,sessionid,Mode
$DP_MON_Export = @()
foreach($DP_MON_Group in $DP_MON_Groups)
{
    $DP_MON_Count = (@($DP_MON_Group.group | Group-Object hostname).name)
    if($DP_MON_Count -gt 1)
    {
        ($DP_MON_Group.group | select -Last 1).hostname = "Multiple"
        $DP_MON_Export += $DP_MON_Group.Group | select -Last 1
    }
    else
    {
        $DP_MON_Export += $DP_MON_Group.Group | select -Last 1
    }
}
$DP_MON_Export | Add-Member NoteProperty "RunningBKPSessionID" ""
$DP_MON_Export = $DP_MON_Export | select Sepcification,'Session ID',Mode,HostName,'Object Status',RunningBKPSessionID
$DP_MON_Export | Export-Csv ".\DP_MON.csv"

######## Step - 15 #########
$Omnistat = Get-Content "C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\DP\DP_Monitoring\Files\omnistat.txt"
$Omnistat_SKip = $Omnistat | select -Skip 2
$Omnistat_Object = @()
foreach($Omnistat_line in $Omnistat_SKip)
{
    $Omnistat_Split = $Omnistat_line -split "\s+"
    if($Omnistat_Split.Count -eq 5)
    {
        $Omnistat_Status = "$($Omnistat_Split[2])" + " " + "$($Omnistat_Split[3])"
        $Omnistat_User   = $Omnistat_Split[4]
    }
    else
    {
        $Omnistat_Status = $Omnistat_Split[2]
        $Omnistat_User   = $Omnistat_Split[3]
    }
    $Omnistat_Object += [PscustomObject] @{
    "SessionID" = $Omnistat_Split[0]
    "Type"      = $Omnistat_Split[1]
    "Status"    = $Omnistat_Status
    "User"      = $Omnistat_User  
    }
}
$specs = Import-Csv ".\DP_MON.csv"
foreach($spec in $specs)
{
    $specification = $spec.specification
    $found = $Omnistat_Object | Where-Object{$_.Specification -eq $specification}
    if($found)
    {
        $spec.RunningBKPSessionID = $found.SessionID
    }
}




#$Failed_Client | sort -Unique client,'session id' | ft

