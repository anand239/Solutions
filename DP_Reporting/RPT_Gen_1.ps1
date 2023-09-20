<#
.SYNOPSIS
  RPT_Gen.ps1
    
.INPUTS
  Configfile
  config.json
   
.NOTES
  Script:         RPT_Gen.ps1
  Author:         Chintalapudi Anand Vardhan
  Requirements :  Powershell v3.0 , Posh-SSH Module, Windows 2008 R2 Or Above
  Creation Date:  22/07/2021
  Modified Date:  22/07/2021 
  Remarks      :  

  .History:
        Version Date            Author                       Description        
        1.0     22/07/2021      Chintalapudi Anand Vardhan   Initial Release
.EXAMPLE
  Script Usage 

  .\RPT_Gen.ps1 -ConfigFile .\config.json
#>

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
    Get-ChildItem $DirectoryPath -Include $FileTypepe | Where-Object { $_.LastWriteTime -lt $DatetoDelete } | Remove-Item
}

function Get-Config
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$ConfigFile # = "config.json"
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

function Send-Mail
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)] 
        $config,
        [string[]]$attachments,
        $body
    )
    $sendMailMessageParameters = @{
        To          = $config.To.Split(";")
        from        = $config.From 
        Subject     = "$($config.Subject) $(Get-Date -Format 'dd-MMM-yyyy - dddd')"
        Body        = $body
        BodyAsHtml  = $true
        SMTPServer  = $config.smtpServer             
        ErrorAction = 'Stop'
    } 

    if ($config.Cc) 
    { 
        $sendMailMessageParameters.Add("CC", $config.Cc.Split(";")) 
    }
    if ($attachments) 
    {
        $sendMailMessageParameters.Add("Attachments", $attachments )
    }
    
    try
    { 
        Send-MailMessage @sendMailMessageParameters
    }
    catch
    { 
        Write-Error "Failed to send email to $To due to error: $_" 
    }
}

function Invoke-PlinkCommand
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$IpAddress,
        [Parameter(Mandatory = $true)]
        [PSCredential]$Credential,
        [Parameter(Mandatory = $true)]
        [String]$logFile,
        [Parameter(Mandatory = $true)]
        [String]$PlinkPath,
        [Parameter(Mandatory = $true)]
        [String]$command,
        [Parameter(Mandatory = $false)]
        [Switch]$FirstTime

    )
    try
    {
        '****************************' |  Out-File -FilePath $logFile -Append
        "Running Command : $command" |  Out-File -FilePath $logFile -Append
        '----------------------------' |  Out-File -FilePath $logFile -Append
        $Result = ""

        $decrypted = $Credential.GetNetworkCredential().password
        $plink = Join-Path $PlinkPath -ChildPath "plink.exe"
        if ($FirstTime -eq $true)
        {
            $result = Write-Output "y" | &$plink -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command 2>&1 | Out-String
        }
        else
        {
            $result = &$plink -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command 2>&1 | Out-String
        }

        $result | Out-File -FilePath $logFile -Append    
        '----------------------------'  | Out-File -FilePath $logFile -Append
        '****************************'  | Out-File -FilePath $logFile -Append
        Write-Output $result
    }
    catch
    {
        Write-Output $null
    }
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

function Invoke-BackupReportingCommand
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

function Invoke-BackupReportingCommand_Windows
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

        if($config.Backupserver -ne "LocalHost")
        {
            $Result = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {Invoke-Expression $using:Command}
        }
        else
        {
            $Result = Invoke-Expression $Command
        }
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

Function Get-OperatingSystemType
{
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true)] 
        $computername 
    )
    try
    {
        $ResponseTime = Test-Connection -ComputerName $computername -Count 1 -ErrorAction Stop | Select-Object -ExpandProperty ResponseTimeToLive
        if($ResponseTime )
        {

            if(($ResponseTime -ge 110) -and ($ResponseTime -le 255))
            {
                $operatingsystemtype = "Windows"
            }
            else
            {
                $operatingsystemtype = "NonWindows"
            }
        }
        else
        {
            $operatingsystemtype = $null
        }
    }

    Catch
    {
        $operatingsystemtype = $null
    }
    Write-Output $operatingsystemtype
}

#######  DP Functions  #######
Function Get-ListOfSessions
{
    [CmdletBinding()]
    Param(
    $InputObject
    )
    #omnirpt -report list_sessions -timeframe $previous 18:00 $current 17:59 -tab -no_copylist -no_verificationlist -no_conslist
    $CellManager = (($InputObject | Select-String -Pattern "Cell Manager") -split ": ")[1].trim()
    $ListOfSessions_converted = $InputObject.replace("`t",",")| Convertfrom-Csv -Header 'Session Type','Specification','Status','Mode','Start Time','Start Time_t','End Time','End Time_t','Queuing', 'Duration','GB Written','Media','Errors','Warnings','Pending DA','Running DA','Failed DA','Completed DA','Object','Files','Success','Session Owner','Session ID'
    $ListOfSessions_Result = $ListOfSessions_converted|select 'Session Type','Specification','Session ID'
    $ListOfSessions_Result,$CellManager
}

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

Function Get-BSRReport
{
    [CmdletBinding()]
    Param(
    $InputObject 
    )
    $AllGroups = $InputObject | Where-Object {$_."Session Type" -eq "Backup"} | Group-Object 'session type',Specification,Client,status,mode
    $BSRReport = @()
    foreach($Group in $AllGroups)
    {
        $ClientGroups = $Group.group | Group-Object Mountpoint
        $MountPoints = @()
        foreach($ClientGroup in $ClientGroups)
        {
            $CompletedMountPointsCount = @($ClientGroup.Group | where{$_.status -eq "Completed"}).count
            #$FailedMountPoints    = ($ClientGroup.Group | where{$_.status -ne "Completed"}).count
            if($CompletedMountPointsCount -gt 0)
            {
                $MountPoints +=($ClientGroup.Group | where{$_.status -eq "Completed"})[0]
            }
            else
            {
                $MountPoints +=($ClientGroup.Group | where{$_.status -ne "Completed"})[0]
            }

        }
        $TotalClientMountPoints = ($MountPoints).Count
        $CompletedClientMountPoints = @($MountPoints| where{$_.status -eq "Completed"}).count
        $Percentage = ($CompletedClientMountPoints / $TotalClientMountPoints)*100
        $Size = [math]::Round(((($MountPoints | Measure-Object "Size (kB)" -Sum).Sum) / 1mb),2)
    
        $Duration = $null
        Foreach($MountPoint in $MountPoints)
        {
            $DurationSplit = $MountPoint."Duration (hh:mm)" -split ":"
            if($DurationSplit[0] -gt 24)
            {
                $Duration += [int](([int]($DurationSplit[0]) * 60) + [int]($DurationSplit[1]))
            }
            else
            {
                $Duration += [timespan]::Parse($MountPoint."Duration (hh:mm)").totalminutes
            }
        }

        $BSRReport         += [pscustomobject] @{
        "Date"              = $MountPoints[0].Date
        "Account"           = $MountPoints[0].Account
        "BkpApp"            = $MountPoints[0].BackupApplication
        "BackupServer"      = $MountPoints[0].BackupServer
        "Clientname"        = $MountPoints[0].client
        "Specification"     = $MountPoints[0].Specification
        "Mode"              = $MountPoints[0].Mode
        "BSR Object"        = "# $CompletedClientMountPoints / $TotalClientMountPoints"
        "Percentage"        = "$Percentage"
        "Size (GB)"         = $Size
        "Duration (min)"    = $Duration
        }
    }
    $BSRReport
}

###############################################

$config = Get-Config -ConfigFile $ConfigFile
$Reportdate = ([system.datetime]::UtcNow).ToString("dd-MMM-yy")
$date = ([system.datetime]::UtcNow).ToString("ddMMMyy")
$Activitylog = "Activity.log"
Write-Log -Path $Activitylog -Entry "Started" -Type Information -ShowOnConsole -OverWrite
Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "Host: $($env:COMPUTERNAME)" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "User: $($env:USERNAME)" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole
if($config)
{
    $BkpDevice = $config.BackupServer
    if($BkpDevice -eq "LocalHost")
    {
        $BackupDevice = $env:computername
    }
    else
    {
        $BackupDevice = $BkpDevice
    }


    #$DPReportName = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "OBJREP" + "_" + "$date" + ".csv"

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
                $body += "<p>Hi, <br><br>&nbsp&nbsp&nbsp&nbspInvalid Credential File!.<br><br>Thanks,<br>Automation Team<br></p>"
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
    $OsType = $config.Ostype #Get-OperatingSystemType -computername $BackupDevice
    Write-Log -Path $Activitylog -Entry "Operating System : $ostype" -Type Information -ShowOnConsole

    #####################################################
    $SessionList = @()
    if($Config.EndDate)
    {
        try
        {
            $ConfigEndDate = [datetime]$Config.EndDate
        }
        catch
        {
            Write-Log -Path $Activitylog -Entry "Please provide EndDate Parameter in config.json file in yyyy-MM-dd format" -Type Warning -ShowOnConsole
            exit
        }
        if($Config.Reportdays)
        {
            $ReportDays = $config.ReportDays
        }
        else
        {
            $ReportDays = 4
        }
    }
    elseif($Config.ReportDays)
    {
        $ReportDays = $Config.ReportDays
    }
    else
    {
        $ReportDays = 4
    }
    ####################################################
    $Attachment = @()
    if($OsType)
    {
        if(!(Test-Path 'OBJ_Reports'))
        {
            try
            {
                New-Item -ItemType directory "OBJ_Reports" -ErrorAction Stop | Out-Null
            }
            catch
            {
                Write-Log -Path $Activitylog -Entry "Unable to create OBJ_Reports Folder" -Type Error -ShowOnConsole
            }
        }
        if(!(Test-Path 'BSR_Reports'))
        {
            try
            {
                New-Item -ItemType directory "BSR_Reports" -ErrorAction Stop | Out-Null
            }
            catch
            {
                Write-Log -Path $Activitylog -Entry "Unable to create BSR_Reports Folder" -Type Error -ShowOnConsole
            }
        }
        if(!((Test-Path 'OBJ_Reports') -and (Test-Path 'BSR_Reports')))
        {
            Write-Log -Path $Activitylog -Entry "Failed to Create BSR_Reports and OBJ_Reports folders in $($config.Reportpath)" -Type Warning -ShowOnConsole
            Write-Log -Path $Activitylog -Entry "Please Create BSR_Reports and OBJ_Reports folders in $($config.Reportpath)" -Type Warning -ShowOnConsole
            exit
        }

        if($OsType -eq "Windows")
        {
            $DpVersionCommand = $config.DPVersionCommand_Windows
            $DpVersionCommandOutput = Invoke-BackupReportingCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $DpVersionCommand -logFile $Activitylog
            if($DpVersionCommandOutput.StartsWith("HPE"))
            {
                [int]$DPVersion = $DpVersionCommandOutput.Substring(21,2)
            }
            else
            {
                [int]$DPVersion = $DpVersionCommandOutput.Substring(29,2)
            }
            if($ConfigEndDate)
            {
                $ServerDate = $ConfigEndDate
            }
            else
            {
                $DateCommand = "get-date"
                $ServerDate = Invoke-BackupReportingCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $DateCommand -logFile $Activitylog
            }

            for($i=1;$i -le $ReportDays ;$i++)
            {
                $SessionList = @()
                $StartDate = ($ServerDate).AddDays(-$i).ToString("yy/MM/dd")
                $EndDate = ($ServerDate).AddDays(-($i-1)).ToString("yy/MM/dd")
                $ReportEndDate = ($ServerDate).AddDays(-($i-1)).ToString("yyyy-MM-dd")
                $DPReportName  = $config.Reportpath  + "\" + "OBJ_Reports" + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "OBJREP" + "_" + "$ReportEndDate" + ".csv"
                $BSRReportName = $config.Reportpath  + "\" + "BSR_Reports" + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "BSR-Size" + "_" + "$ReportEndDate" + ".csv"
                #$Attachment += $DPReportName
                #$attachment += $BSRReportName
                $SessionDetailsCommand = $config.SessionDetailsCommand_Windows -replace "StartDate",$StartDate -replace "EndDate",$EndDate

                $SessionDetailsOutput = Invoke-BackupReportingCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $SessionDetailsCommand -logFile $Activitylog
                if(!("# No sessions matching the search criteria found." -in $SessionDetailsOutput))
                {
                    $ListOfSessions,$CellManager = @(Get-ListOfSessions -InputObject $SessionDetailsOutput)
    
                    foreach($session in $ListOfSessions)
                    {
                        $SessionId = $session.'session id'
                        $SessionList_Command = $config.SessionObjectsCommand_Windows -replace "SessionID", $SessionId
                        $SessionList_CommandOutput = Invoke-BackupReportingCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $SessionList_Command -logFile $Activitylog
                        $SessionList += Get-SessionList -InputObject $SessionList_CommandOutput -CellManager $CellManager -SessionType $session.'Session Type' -Specification $session.Specification -SessionId $SessionId
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
                    }
                    $SessionList | Export-Csv -Path $DPReportName -NoTypeInformation
                    $SessionTypeisBackup = $SessionList | Where-Object {$_."Session Type" -eq "Backup"}
                    if($SessionTypeisBackup)
                    {
                        $BSRReport = Get-BSRReport -InputObject $SessionList
                        $BSRReport | Export-Csv -Path $BSRReportName -NoTypeInformation
                        if ($config.SendEmail -eq "yes")
                        {  
                            $attachment = @()
                            $attachment = $BSRReportName

                            $sendMailMessageParameters = @{
                                To          = $config.mail.To.Split(";")
                                from        = $config.mail.From 
                                Subject     = "$($config.mail.Subject) on $BackupDevice at $(Get-Date -Format 'dd-MMM-yyyy - HH:mm:ss')"      
                                BodyAsHtml  = $true
                                SMTPServer  = $config.mail.smtpServer             
                                ErrorAction = 'Stop'
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
                            $body += "<p>Hi, <br><br>&nbsp&nbsp&nbsp&nbspPlease Check DataProtector Reports.<br><br>Thanks,<br>Automation Team<br></p>"
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
                    }
                }
                else
                {
                    Write-Log -Path $Activitylog -Entry "No Sessions available from $StartDate 18:00 to $EndDate 17:59" -Type Warning -ShowOnConsole
                }    
            }
        }
        else
        {
            Import-Module ".\Posh-SSH\Posh-SSH.psd1"
            $sshsessionId = New-PoshSession -IpAddress $BackupDevice -Credential  $Credential
            if($sshsessionId.connected -eq "True")
            {
                $DpVersionCommand = $config.DPVersionCommand_NonWindows
                $DpVersionCommandOutput = Invoke-BackupReportingCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command $DpVersionCommand
                if($DpVersionCommandOutput.StartsWith("HPE"))
                {
                    [int]$DPVersion = $DpVersionCommandOutput.Substring(21,2)
                }
                else
                {
                    [int]$DPVersion = $DpVersionCommandOutput.Substring(29,2)
                }

                if($ConfigEndDate)
                {
                    $ServerDate = $ConfigEndDate
                }
                else
                {
                    $command = "date +'%D %T'"
                    $CurrentBackupDeviceTimeFromUnix = Invoke-BackupReportingCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command $command
                    $ServerDate = [datetime]$CurrentBackupDeviceTimeFromUnix
                }

                for($i=1;$i -le $ReportDays ;$i++)
                {
                    $SessionList = @()
                    $StartDate = ($ServerDate).AddDays(-$i).ToString("yy/MM/dd")
                    $EndDate = ($ServerDate).AddDays(-($i-1)).ToString("yy/MM/dd")
                    $ReportEndDate = ($ServerDate).AddDays(-($i-1)).ToString("yyyy-MM-dd")
                    $DPReportName = $config.Reportpath   + "\" + "OBJ_Reports"+ "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "OBJREP" + "_" + "$ReportEndDate" + ".csv"
                    $BSRReportName = $config.Reportpath  + "\" + "BSR_Reports"+ "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "BSR-Size" + "_" + "$ReportEndDate" + ".csv"
                    $attachment += $BSRReportName
                    $SessionDetailsCommand = $config.SessionDetailsCommand_NonWindows -replace "StartDate",$StartDate -replace "EndDate",$EndDate

                    $SessionDetailsOutput = Invoke-BackupReportingCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command $SessionDetailsCommand
                    if(!("# No sessions matching the search criteria found." -in $SessionDetailsOutput))
                    {
                        $ListOfSessions,$CellManager = @(Get-ListOfSessions -InputObject $SessionDetailsOutput)
    
                        foreach($session in $ListOfSessions)
                        {
                            $SessionId = $session.'session id'
                            $SessionList_Command = $config.SessionObjectsCommand_NonWindows -replace "SessionID", $SessionId
                            $SessionList_CommandOutput = Invoke-BackupReportingCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command $SessionList_Command
                            $SessionList += Get-SessionList -InputObject $SessionList_CommandOutput -CellManager $CellManager -SessionType $session.'Session Type' -Specification $session.Specification -SessionId $SessionId
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
                        }
                        $SessionList | Export-Csv -Path $DPReportName -NoTypeInformation
                        $SessionTypeisBackup = $SessionList | Where-Object {$_."Session Type" -eq "Backup"}
                        if($SessionTypeisBackup)
                        {
                            $BSRReport = Get-BSRReport -InputObject $SessionList
                            $BSRReport | Export-Csv -Path $BSRReportName -NoTypeInformation
                            if ($config.SendEmail -eq "yes")
                            {  
                                $attachment = @()
                                $attachment = $BSRReportName

                                $sendMailMessageParameters = @{
                                    To          = $config.mail.To.Split(";")
                                    from        = $config.mail.From 
                                    Subject     = "$($config.mail.Subject) on $BackupDevice at $(Get-Date -Format 'dd-MMM-yyyy - HH:mm:ss')"      
                                    BodyAsHtml  = $true
                                    SMTPServer  = $config.mail.smtpServer             
                                    ErrorAction = 'Stop'
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
                                $body += "<p>Hi, <br><br>&nbsp&nbsp&nbsp&nbspPlease Check DataProtector Reports.<br><br>Thanks,<br>Automation Team<br></p>"
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
                        }     
                        else
                        {
                            Write-Log -Path $Activitylog -Entry "No Session Type of Backup.." -Type Information -ShowOnConsole
                        }
                    }
                    else
                    {
                        Write-Log -Path $Activitylog -Entry "No Sessions available from $StartDate 18:00 to $EndDate 17:59" -Type Warning -ShowOnConsole
                    }    
                }
                Remove-SSHSession -SessionId $sshsessionId.sessionId
            }
            else
            {
                Write-Log -Path $Activitylog -Entry "Failed to connect to $BackupDevice" -Type Error -ShowOnConsole
            }
        }

        ######################################
    }
    else
    {
        Write-Log -Path $Activitylog -Entry "Operating System : Failed" -Type Error -ShowOnConsole
    }
}
else
{
    Write-Log -Path $Activitylog -Entry "Invalid $ConfigFile" -Type Error -ShowOnConsole
}
Write-Log -Path $Activitylog -Entry "Completed" -Type Information -ShowOnConsole

#Changes in this version
# 1. Added folder creation part "OBJ_Reports" and "BSR_Reports"