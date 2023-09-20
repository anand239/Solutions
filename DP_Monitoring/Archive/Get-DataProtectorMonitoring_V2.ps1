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
$SessionType_Backup = $ListOfSessions | Where-Object {$_.'Session Type' -eq "Backup"} | Select-Object 'Specification','Status','session id',mode

$Completed_Sessions = $SessionType_Backup | Where-Object {$_.status -eq "Completed"}
if($Completed_Sessions)
{
    $completed_Client = @()
    foreach($Completed_Session in $Completed_Sessions)
    {
        $Completed_SessionId = $Completed_Session.'session id'
        $SessionIdObjectReport = Get-Content 'C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\DP\DP_Monitoring\Files\SessionIDObjectReport.txt' | select -Skip 2
        if($SessionIdObjectReport)
        {
            foreach($object in $SessionIdObjectReport)
            {
                $Host_Name = ($Object -split ":")[0]
                $MountPoint = ((($object -split "\s+")[2]).Split("[")[1]).split("]")[0]
                $completed_Client += [pscustomobject] @{
                "Client" = "$Host_Name"
                "Mount Point" = "$MountPoint"
                "Specification" = $Completed_Session.Specification
                "Session Id" = $Completed_Session.'Session ID'
                "Mode" = $Completed_Session.Mode
                }
            }
        }
    }
}
$completed_Client | ft
###### Step - 5 ############
$Failed_Sessions = $SessionType_Backup | Where-Object {$_.status -ne "Completed"}
if($Failed_Sessions)
{
    $Failed_Client = @()
    foreach($Failed_Session in $Failed_Sessions)
    {
        #$Failed_Session.Specification
        $Failed_SessionId = $Failed_Session.'session id'
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
                            $InetHostNames += $InetHost[0]
                        }
                        elseif($log -like "*host*")
                        {
                            $log_split = $log -split "host"
                            $InetHost = $log_split[1] -split '"'
                            $InetHostNames += $InetHost[1]
                        }
                    }
                }
            }
            else
            {
                Write-Host "end as AutoDiagnose"
                Write-Host "No Critical or Major" -BackgroundColor Red
                Exit
            }
            ###### Step - 8 ############
            $SessionIdObjectReport = Get-Content 'C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\DP\DP_Monitoring\Files\SessionIDObjectReport.txt'
            if($SessionIdObjectReport)
            {
                foreach($InetHostName in $InetHostNames)
                {
                    if($SessionIdObjectReport.Contains($InetHostName))
                    {
                        $Failed_Client += [pscustomobject] @{
                        "Client" = "$Host_Name"
                        "Mount Point" = "Inet"
                        "Specification" = $Failed_Session.Specification
                        "Session Id" = $Failed_Session.'Session ID'
                        "Mode" = $Failed_Session.Mode
                        }
                    }
                    else
                    {
                        $FailedObject = $SessionIdObjectReport | Select-String -Pattern "Failed"
                        if($FailedObject)
                        {
                            $MountPoint = ""
                            foreach($object in $FailedObject)
                            {
                                $Host_Name = ($Object -split ":")[0]
                                $MountPoint = ((($object -split "\s+")[2]).Split("[")[1]).split("]")[0] + "," + $MountPoint
                            }
                            #$Host_Name
                            $Failed_Client += [pscustomobject] @{
                            "Client" = "$Host_Name"
                            "Mount Point" = "$MountPoint"
                            "Specification" = $Failed_Session.Specification
                            "Session Id" = $Failed_Session.'Session ID'
                            "Mode" = $Failed_Session.Mode
                            }
                        }
                    }
                }
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



$Failed_Client | sort -Unique client,'session id' | ft
