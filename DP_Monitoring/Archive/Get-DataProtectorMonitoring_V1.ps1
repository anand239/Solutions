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
    $ListOfSessions_Result = $ListOfSessions_converted| Select-Object 'Specification','Status','session id',mode
    $ListOfSessions_Result
}

$Command = Get-Content 'C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\DP\DP_Monitoring\Files\ListOfSession.txt'
$ListOfSessions = @(Get-ListOfSessions -InputObject $Command)

if(!($ListOfSessions))
{
    $Command1 = Get-Content 'C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\DP\DP_Monitoring\Files\ListOfSession1.txt'
    $ListOfSessions = @(Get-ListOfSessions -InputObject $Command1)
    if(!($ListOfSessions))
    {
        #send mail
        Write-Host "Sending mail"
        Exit
    }

}

###### Step - 2 ############
$Failed_Sessions = $ListOfSessions | Where-Object {$_.status -eq "Failed" -or $_.status -eq "Completed\Failure"}

###### Step - 3 ############
foreach($Session in $Failed_Sessions)
{
    $SessionId = $Session.'session id'
    $SessionLog = Get-Content 'C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\DP\DP_Monitoring\Files\SessionLog.txt'
    if($SessionLog)
    {
        $Critical_Major = @()
        $Replace = (($SessionLog) -replace '^$','#')
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
            $InetHostName = @()
            foreach($log in $Critical_Major )
            {
                if(($log -like "*Could not connect to inet in order to start*") -or ($log -like "*Cannot connect to inet for getting*") -or ($log -like "*Cannot connect to inet for starting*"))
                {
                    if($log -like "*VBDA*")
                    {
                        $log_split = $log -split "VBDA@"
                        $InetHost = $log_split[1] -split "\s"
                        $InetHostName += $InetHost[0]
                    }
                    elseif($log -like "*host*")
                    {
                        $log_split = $log -split "host"
                        $InetHost = $log_split[1] -split '"'
                        $InetHostName += $InetHost[1]
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
        ###### Step - 5 ############
        $SessionIdObjectReport = Get-Content 'C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\DP\DP_Monitoring\Files\SessionIDObjectReport.txt'
        if($SessionIdObjectReport)
        {
            $FailedObject = $SessionIdObjectReport | Select-String -Pattern "Failed"
            if($FailedObject)
            {
                $Failed_Client = @()
                foreach($object in $FailedObject)
                {
                    $Host_Name = ($Object -split ":")[0]
                    $MountPoint = ((($object -split "\s+")[2]).Split("[")[1]).split("]")[0]
                    $Failed_Client += [pscustomobject] @{
                    "Client" = "$Host_Name"
                    "Mount Point" = "$MountPoint"
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
        ###### Step - 6 ############
        $Error_logs = @()
        foreach($CriticalLog in $Critical_Major)
        {
            $Error_log = $CriticalLog.Split([Environment]::NewLine)|where{$_} |select -Skip 1| select -First 1
            $Error_logs += $Error_log.Substring(0,45)
        }
    }
    else
    {
        Write-Host "end as AutoDiagnose"
        Write-Host "No logs" -BackgroundColor Red
        Exit
        
    }
}

$Failed_Client
Write-Output "-------------------------------------------------"
$Error_logs

