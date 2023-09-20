[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [String] $ConfigFile = "config.json"
)

function Remove-File()
{
    [CmdletBinding()]
    param($Day, $DirectoryPath, $FileType)
    if (!(Test-Path $DirectoryPath))
    {
        Return
    }
    $CurrentDate = Get-Date;
    $DateToDelete = $CurrentDate.AddDays(-$Day);
    $DirectoryPath = $DirectoryPath + "\*"
    Get-ChildItem $DirectoryPath -Include $FileType | Where-Object { $_.LastWriteTime -lt $DatetoDelete } | Remove-Item
}

function Get-Config
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$ConfigFile  = "config.json"
    ) 
    try
    {
        if (Test-Path -Path $ConfigFile)
        {
            Write-Verbose "Parsing $ConfigFile"
            $config = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json
        }
    }
    catch
    {
        Write-Error "Error Parsing $ConfigFile" 
    }
    Write-Output $config
}

Function New-PoshSession
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$IpAddress,
        [Parameter(Mandatory = $true)]
        [PSCredential]$Credential
    )
    try
    {
        $SessionId = New-SSHSession -ComputerName $IpAddress -Credential $Credential -AcceptKey:$true
        write-output $SessionId
    }
    catch
    {
        Write-Output $null
    }

}

function Invoke-BackupHealthCheckCommand
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$SshSessionId,
        [Parameter(Mandatory = $true)]
        [String]$logFile,
        [Parameter(Mandatory = $true)]
        [String]$command,
        [Switch] $UseSSHStream

    )
    try
    {
        '****************************' |  Out-File -FilePath $logFile -Append
        "Running Command : $command" |  Out-File -FilePath $logFile -Append
        '----------------------------' |  Out-File -FilePath $logFile -Append
        $result = ""
        $result = Invoke-SSHCommand -Command $command -SessionId $SshSessionId -EnsureConnection -TimeOut 300 
        $output = $result.output
        if ($result.error)
        {
         "Error Occured"  | Out-File -FilePath $logFile -Append  
         '============================' |  Out-File -FilePath $logFile -Append  
         $result.error | Out-File -FilePath $logFile -Append  
         '============================' |  Out-File -FilePath $logFile -Append  
        }
        $output | Out-File -FilePath $logFile -Append    
        '----------------------------'  | Out-File -FilePath $logFile -Append
        '****************************'  | Out-File -FilePath $logFile -Append
        Write-Output $output
    }
    catch
    {
        Write-Output $null
    }
}

function Invoke-BackupHealthCheckCommand_Windows
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $ComputerName,
        [Parameter(Mandatory = $true)]
        [String]$logFile,
        #[Parameter(Mandatory = $true)]
        [PSCredential]$Credential,
        [Parameter(Mandatory = $true)]
        [String]$command

    )
    try
    {
        '****************************' |  Out-File -FilePath $logFile -Append
        "Running Command : $command" |  Out-File -FilePath $logFile -Append
        '----------------------------' |  Out-File -FilePath $logFile -Append
        $Result = ""

        <#
        if($config.Backupserver -ne "LocalHost")
        {
            $Result = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {Invoke-Expression $using:Command}
        }
        else
        {
            $Result = Invoke-Expression $Command
        }#>
        $Result = Invoke-Expression $Command
        

        $result | Out-File -FilePath $logFile -Append    
        '----------------------------'  | Out-File -FilePath $logFile -Append
        '****************************'  | Out-File -FilePath $logFile -Append
        Write-Output $result
    }
    catch
    {
        $comment = $_ | fl | Out-String
        Write-Log -Path $Activitylog -Type Exception -Entry $comment -ShowOnConsole
        Write-Output $null
    }
}

function Write-Log
{
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true)] 
        [string] $Path,
        [parameter(Mandatory = $true)] 
        $Entry,
        [parameter(Mandatory = $true)]
        [ValidateSet('Error', 'Warning', 'Information', 'Exception')]
        [string] $Type,
        [switch]
        $ShowOnConsole,
        [switch]
        $OverWrite
    )
  
    if ($Type -eq "Error")
    {
        $logEntry = "[$(Get-Date -Format "dd-MMM-yyyy HH:mm:ss")] - [ERR]  - $Entry"
        if ($ShowOnConsole) { Write-Host "$Entry" -ForegroundColor Red}
    }
    elseif ($Type -eq "Warning")
    { 
        $logEntry = "[$(Get-Date -Format "dd-MMM-yyyy HH:mm:ss")] - [WARN] - $Entry"
        if ($ShowOnConsole) { Write-Host "$Entry" -ForegroundColor Yellow }
    }
    elseif ($Type -eq "Information")
    { 
        $logEntry = "[$(Get-Date -Format "dd-MMM-yyyy HH:mm:ss")] - [INFO] - $Entry"
        if ($ShowOnConsole) {  Write-Host "$Entry" -ForegroundColor Green }
    }
    elseif ($Type -eq "Exception")
    { 
        $logEntry = "[$(Get-Date -Format "dd-MMM-yyyy HH:mm:ss")] - [EXP]  - $Entry"
        if ($ShowOnConsole) {  Write-Host "$Entry" -ForegroundColor Red }
    }
    if($OverWrite)
    {
        $logEntry | Out-File $Path
    }
    else
    {
        $logEntry | Out-File $Path -Append
    }
}


######## DP Functions ########
Function Get-ListOfSessions
{
    [CmdletBinding()]
    Param(
    $InputObject
    )
    $ListOfSessions_converted = $InputObject.replace("`t",",")| Convertfrom-Csv -Header 'Session Type','Specification','Status','Mode','Start Time','Start Time_t','End Time','End Time_t','Queuing', 'Duration','GB Written','Media','Errors','Warnings','Pending DA','Running DA','Failed DA','Completed DA','Object','Files','Success','Session Owner','Session ID'
    $ListOfSessions_Result = $ListOfSessions_converted
    $ListOfSessions_Result
}
$config = Get-Config -ConfigFile $ConfigFile
$Activitylog = "Activity.log"

if($config)
{
    $BkpDevice = $config.BackupServer
    if($BkpDevice -eq "LocalHost")
    {
        $BackupDevice = "$env:computername"
    }
    else
    {
        $BackupDevice = $BkpDevice
    }
    if($BkpDevice -ne "LocalHost")
    {
        Write-Log -Path $Activitylog -Entry "Checking For Credential!" -Type Information -ShowOnConsole
        $CredentialPath = $config.CredentialFile
        if (!(Test-Path -Path $CredentialPath) )
        {
            $Credential = Get-Credential -Message "Enter Credentials"
            $Credential | Export-Clixml $CredentialPath -Force
        }
        try
        {
            $Credential = Import-Clixml $CredentialPath
        }
        catch
        {
            $comment = $_ | Format-List -Force 
            Write-Log -Path $Activitylog -Entry  "Invalid Credential File!" -Type Error -ShowOnConsole
            Write-Log -Path $Activitylog -Entry  $comment -Type Exception 
            Write-Log -Path $Activitylog -Entry  "Recreate Credential File!" -Type Information -ShowOnConsole

            if ($config.SendEmail -eq "yes")
            {  
                $attachment = @()
                $sendMailMessageParameters = @{
                    To          = $config.mail.To.Split(";")
                    from        = $config.mail.From 
                    Subject     = "$($config.mail.Subject) on $BackupDevice at $(Get-Date -Format 'dd-MMM-yyyy - HH:mm:ss')"      
                    BodyAsHtml  = $true
                    SMTPServer  = $config.mail.smtpServer             
                    ErrorAction = 'Stop'
                    port        = $config.mail.port
                } 

                if ($config.mail.Cc) 
                { 
                    $sendMailMessageParameters.Add("CC", $config.mail.Cc.Split(";")) 
                }
                if ($attachment.Count -gt 0)
                {
                    $sendMailMessageParameters.Add("Attachments", $attachment )
                }
                $body = ""
                $body += "<p>Hi, <br><br>&nbsp&nbsp&nbsp&nbspPlease find the healthcheck reports in the attachment.<br><br>Thanks,<br>Automation Team<br></p>"
                $body += "<p style=`"color: red; font-size: 12px`">***This is an auto generated mail. Please do not reply.***</p>"
             
                $sendMailMessageParameters.Add("Body", $body)
                try
                {
                    Send-MailMessage @sendMailMessageParameters
                }
                catch
                {
                    $comment = $_ | Format-List -Force 
                    Write-Log -Path $Activitylog -Entry  "Failed to send the mail" -Type Error -ShowOnConsole
                    Write-Log -Path $Activitylog -Entry  $comment -Type Exception 
                    Write-Log -Path $Activitylog -Entry  "Recreate Credential File!" -Type Information -ShowOnConsole
                
                }
            }        
            exit
        }
    }
    else
    {
        Write-Log -Path $Activitylog -Entry "Running Locally" -Type Information -ShowOnConsole
    }
    Write-Log -Path $Activitylog -Entry "Fethching details from $BackupDevice" -Type Information -ShowOnConsole
    if($BkpDevice -ne "LocalHost")
    {
        $OsType = Get-OperatingSystemType -computername $BackupDevice
    }
    else
    {
        $OsType = "Windows"
    }
    Write-Log -Path $Activitylog -Entry "Operating System : $ostype" -Type Information -ShowOnConsole

    if($OsType)
    {
        $command = "Get-date"
        $CurrentBackupDeviceTime = Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $command -logFile $Activitylog
        $StartDate = ($CurrentBackupDeviceTime).AddMinutes(-15).ToString("yy/MM/dd HH:mm")
        $EndDate = ($CurrentBackupDeviceTime).ToString("yy/MM/dd HH:mm")
        $Command = "omnirpt -report list_sessions -timeframe 24 24 -tab"
        $ListOfSessionsCommandOutput = Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $command -logFile $Activitylog
        $ListOfSessions = @(Get-ListOfSessions -InputObject $ListOfSessionsCommandOutput)

        if(!($ListOfSessions))
        {
            Write-Host "Sending mail"
            #Exit
        }

        ###### Step - 3 ############
        $SessionType_Backup = $ListOfSessions | Where-Object {$_.'Session Type' -eq "Backup"} | Select-Object 'Specification','Status','session id',mode,'End time'

        $Completed_Sessions = $SessionType_Backup | Where-Object {$_.status -eq "Completed"}
        if($Completed_Sessions)
        {
            $completed_Client = @()
            foreach($Completed_Session in $Completed_Sessions)
            {
                $Completed_SessionId = $Completed_Session.'session id'
                $End_Time = $Completed_Session.'End Time'
                $SessionIdObjectReportCommand = "omnidb -session $Completed_Sessionid"
                $SessionIdObjectReportCommandoutput = Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $SessionIdObjectReportCommand -logFile $Activitylog
                $SessionIdObjectReport = $SessionIdObjectReportCommandoutput | select -Skip 2
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
        $completed_Client | Export-Csv 'event.csv' -NoTypeInformation -Append
        ###### Step - 5 ############
        $Failed_Sessions = $SessionType_Backup | Where-Object {($_.status -ne "Completed") -and ($_.status -ne "In Progress")}
        if($Failed_Sessions)
        {
            $Failed_Client = @()
            foreach($Failed_Session in $Failed_Sessions)
            {
                #$Failed_Session.Specification
                $Failed_SessionId = $Failed_Session.'session id'
                Write-Host $Failed_SessionId -BackgroundColor Red
                $End_Time = $Failed_Session.'End Time'
                # omnidb –session FailedBKPSessionID -report
                $Failed_SessionLogCommand = "omnidb -session $Failed_SessionId -report"
                $Failed_SessionLog = Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $Failed_SessionLogCommand -logFile $Activitylog
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
                            else
                            {
                                write-host "No inet issues" -BackgroundColor Red
                            }
                        }
                        $InetHostNames = $InetHostNames | select -Unique
                    }
                    else
                    {
                    Write-Host "No major or critical errors" -BackgroundColor Red
                    }
                    ###### Step - 8 ############
                    # omnidb –session FailedBKPSessionID
                    $SessionIdObjectReportcommand = "omnidb -session $Failed_SessionId"
                    $SessionIdObjectReport = Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $SessionIdObjectReportcommand -logFile $Activitylog
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

                        $Failed_Client | Export-Csv '.\Event.csv' -Append -NoTypeInformation
                        $Failed_Clients_only = $Failed_Client | Where-Object{$_.status -eq "Failed" -and $_.status -eq "Aborted"}
                        $Failed_Clients_only | Export-Csv '.\DP_MON_Detail.csv' -Append -NoTypeInformation

                    }
                    else
                    {
                        Write-Host "end as AutoDiagnose"
                        Write-Host "No SessionIdObjectReport" -BackgroundColor Red
                        #Exit
                    }
                }
                else
                {
                    #send mail
                    Write-Host "No Failed Session Log"
                    #Exit
                }
            }
        }
        else
        {
            #send mail
            Write-Host "No failed Sessions"
            #Exit
        }


        ######## Step - 11 #########
        $EventImport = Import-Csv "C:\Users\achintalapud\OneDrive - DXC Production\Desktop\event.csv"

        $Groups = $EventImport | Group-Object Sepcification,sessionid, mode
        $Ticketlog = @()
        foreach($group in $groups){}
        {
            $count = @(($group.Group | Group-Object hostname).name)
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

        $DP_Mon_Detail = Import-Csv ".\DP_Mon_Detail.csv"
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

        $EventData = Import-Csv ".\Event.csv" | foreach{$i=0}{$_ | Add-Member Index ($i++) -PassThru}

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
        $OmnistatCommand = "omnistat -detail"
        $OmnistatCommandOutput = Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $OmnistatCommand -logFile $Activitylog
        
        if(!("No currently running sessions." -in $OmnistatCommandOutput))
        {
            $Omnistat_Object = Get-BackupStatus -InputObject OmnistatCommandOutput
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
        }
    }


}

#$Failed_Client | sort -Unique client,'session id' | ft

