<#
.SYNOPSIS
  Get-DataProtectorHealthCheck.ps1

.DESCRIPTION
  HealthCheck Performed:
    1. DP Service
    2. Failed Backup count
    3. Queuing Backup Count(>30 mins)
    4. Long Running Backup Count (> 12 hours)
    5. Long Running Backup Count > 24 hrs
    6. Disabled Tape Drive Count
    7. Scratch Media Count
    8. IDB BKP Status
    9. Critical Backup Status
   10. Free Disk Space
   11. Library Status
   12. Hung Backup Count
   13. Mount Request Count
   14. Disabled Backup Job Count
    
.INPUTS
  Configfile
  config.json
   
.NOTES
  Script:         Get-DataProtectorHealthCheck.ps1
  Author:         Chintalapudi Anand Vardhan
  Requirements :  Powershell v5.0 , Posh-SSH Module, PLink.exe, Windows 2008 R2 Or Above
  Creation Date:  22/07/2021
  Modified Date:  22/07/2021 
  Remarks      :  

  .History:
        Version Date            Author                       Description        
        0.0     22/07/2021      Veena S Navali               Temaplate Creation
        1.0     22/07/2021      Chintalapudi Anand Vardhan   Initial Release
.EXAMPLE
  Script Usage 

  .\Get-DataProtectorHealthCheck.ps1 -ConfigFile .\config.json
#>

[CmdletBinding()]
param(
    #[Parameter(Mandatory = $true)]
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
        [String]$ConfigFile
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
        $logContent = [System.Text.StringBuilder]::new() 
       
        [void]$logContent.AppendLine( '****************************' )
        [void]$logContent.AppendLine( "Running Command : $command" )
        [void]$logContent.AppendLine( '----------------------------' )
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

        [void]$logContent.AppendLine( $result )      
        [void]$logContent.AppendLine( '----------------------------' )
        [void]$logContent.AppendLine( '****************************' )
        $logContent.ToString() | Out-File -FilePath $logFile -Append
        Write-Output $result
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
        [String]$command

    )
    try
    {
        $logContent = [System.Text.StringBuilder]::new() 
       
        [void]$logContent.AppendLine( '****************************' )
        [void]$logContent.AppendLine( "Running Command : $command" )
        [void]$logContent.AppendLine( '----------------------------' )
        $result = ""
        $ssh.WriteLine($command)
        Start-Sleep -Milliseconds 1000
        do
        {
            $result += $ssh.read()
            Start-Sleep -Milliseconds 500
        }
        While ($ssh.DataAvailable)

        [void]$logContent.AppendLine( $result )      
        [void]$logContent.AppendLine( '----------------------------' )
        [void]$logContent.AppendLine( '****************************' )
        $logContent.ToString() | Out-File -FilePath $logFile -Append
        Write-Output $result
    }
    catch
    {
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
        $ShowOnConsole
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
    
    $logEntry | Out-File $Path -Append
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

            if($ResponseTime -eq 128)
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

#### Data Protector Functions #######

Function Get-DpService
{
    [CmdletBinding()]
    Param(
    [parameter(Mandatory = $true)]
    $InputObject
    )
    #omnisv -status
    $Input = $InputObject | select -Skip 2| select -SkipLast 3
    $Active = $Input | Select-String -Pattern "Active"
    $Total_count = ($Input).Count
    $Active_count = ($active).count
    $percent = [math]::Round(($Active_Count/$Total_count)*100,2)
    If($percent -lt 100)
    {
        $signal = "R"
    }
    else
    {
        $signal = "G"
    }
    $Dpservice_signal = "DP Service Status, $Active_Count/$Total_count, $percent%, $Signal"
    $Dp_Service_Result = $InputObject
    $Dpservice_signal,$Dp_Service_Result
}

Function Get-BackupStatus
{
    [CmdletBinding()]
    Param(
    [parameter(Mandatory = $true)]
    $InputObject
    )
    $current = Get-Date
    ######omnistat -detail
    $Queuing_Object = @()
    $Queuing_Input = $InputObject | select -Skip 1 | select -SkipLast 1 
    for($i=0;$i -le $Queuing_Input.Count;$i+=7)
    {
  
          $obj = New-Object psObject
          $arr =$Queuing_Input[$i] -split ": " 
          $obj | Add-Member NoteProperty "$($arr[0].trim())"  $arr[1].trim()
          $arr =$Queuing_Input[$i+1] -split ": "
          $obj | Add-Member NoteProperty "$($arr[0].trim())"  $arr[1].trim()
          $arr =$Queuing_Input[$i+2] -split ": "
          $obj | Add-Member NoteProperty "$($arr[0].trim())"  $arr[1].trim()
          $arr =$Queuing_Input[$i+3] -split ": "
          $obj | Add-Member NoteProperty "$($arr[0].trim())"  $arr[1].trim()
          $arr =$Queuing_Input[$i+4] -split ": "
          $obj | Add-Member NoteProperty "$($arr[0].trim())"  $arr[1].trim()
          $arr =$Queuing_Input[$i+5] -split ":"
          $obj | Add-Member NoteProperty "$($arr[0].trim())"  $arr[1].trim()

          $file_date = [datetime]$obj.'Session Started'
          $Time_Span = (New-TimeSpan -Start $file_date -End $current).TotalMinutes
          $obj | Add-Member NoteProperty "Time Elapsed"  $Time_Span
          $Queuing_Object += $obj
    }
    $Queuing_Object
}

Function Get-QueuedBackupGreaterThanThirtyMinute
{
    [CmdletBinding()]
    Param(
    [parameter(Mandatory = $true)]
    $InputObject,
    $TotalBackup_Count
    )
    #checking elapsed Greaater than 30 Min
    $Result = $InputObject | Where-Object{$_.'Time Elapsed' -gt 30} | select sessionid,'Session type','Backup Specification'
    $Queuing_Bck_count = $Result.Count
    $percent = [math]::round(($Queuing_Bck_count/$TotalBackup_Count)*100,2)
    If($percent -lt 1)
    {
        $signal = "G"
    }
    elseif(($percent -eq 1) -or ($percent -le 2))
    {
        $signal = "Y"
    }
    else
    {
        $signal = "R"
    }
    $Signal_Report = "Queuing Backup Count(>30 mins), $Queuing_Bck_count/$TotalBackup_Count, $percent%, $signal"
    $Signal_Report,$Result
}

Function Get-QueuedBackupLessThanTwentyFourHour
{
    [CmdletBinding()]
    Param(
    [parameter(Mandatory = $true)]
    $InputObject,
    $TotalBackup_Count
    )
    # ($time_30 -ge 12) -and ($time_30 -lt 24)) Checking elapsed btwe 12 and 24 hr
    $Result = $InputObject | Where-Object{$_.'Time Elapsed' -ge 720 -and $_.'Time Elapsed' -lt 1440} | select sessionid,'Session type','Backup Specification'

    
    $Queuing_Bck_count = $Result.Count
    $percent = [math]::round(($Queuing_Bck_count/$TotalBackup_Count)*100,2)
    If($percent -lt 1)
    {
        $signal = "G"
    }
    elseif(($percent -eq 1) -or ($percent -le 2))
    {
        $signal = "Y"
    }
    else
    {
        $signal = "R"
    }
    $Signal_Report = "Long Running Backup Count(>12 and < 24 Hrs), $Queuing_Bck_count/$TotalBackup_Count, $percent%, $signal"
    $Signal_Report,$Result
}

Function Get-QueuedBackupGreaterThanTwentyFourHour
{
    [CmdletBinding()]
    Param(
    [parameter(Mandatory = $true)]
    $InputObject,
    $TotalBackup_Count
    )
    #Checking elapsed Greater Than 24 hr
    $Result = $InputObject | Where-Object{$_.'Time Elapsed' -ge 1440} | select sessionid,'Session type','Backup Specification'

    
    $Queuing_Bck_count = $Result.Count
    $percent = [math]::round(($Queuing_Bck_count/$TotalBackup_Count)*100,2)
    If($percent -lt 1)
    {
        $signal = "G"
    }
    elseif(($percent -eq 1) -or ($percent -le 2))
    {
        $signal = "Y"
    }
    else
    {
        $signal = "R"
    }
    $Signal_Report = "Long Running Backup Count(>24 Hrs), $Queuing_Bck_count/$TotalBackup_Count, $percent%, $signal"
    $Signal_Report,$Result
}

Function Get-Mount_Request
{
    [CmdletBinding()]
    Param(
    [parameter(Mandatory = $true)]
    $InputObject
    )
    $Mount_Request_Result = $InputObject |? {($_.'Session type' -eq "Backup") -and ($_.'Session Status' -eq "Mount Request")} | select sessionid,'Backup Specifiction'
    $Mount_req_count = $Mount_Request_Result.count
    $Total_Bck_count = $InputObject.Count
    $percent = [math]::Truncate((($Mount_req_count/$Total_Bck_count)*100)*100)/100
    If($percent -lt 1)
    {
        $signal = "G"
    }
    elseif(($percent -eq 1) -or ($percent -le 2))
    {
        $signal = "Y"
    }
    else
    {
        $signal = "R"
    }
    $Mount_req_signal = "Mount Request Count, $Mount_req_count/$Total_Bck_count, $percent%, $signal"
    $Mount_req_signal,$Mount_Request_Result
}

Function Get-DisabledTapeDriveCount
{
    [CmdletBinding()]
    Param(
    [parameter(Mandatory = $true)]
    $InputObject
    )
    #####omnidownload -list_devices -detail
    $Disabled_TapeDrive_input = $InputObject | Out-String
    $Disabled_TapeDrive_Object=@()
    $pattern = '='*169  
    $Disabled_TapeDrive_input.Split($pattern,[System.StringSplitOptions]::RemoveEmptyEntries) | Where-Object {$_ -match '\S'} | ForEach-Object {
    $item = $_ -split "\s+`n" | Where-Object {$_}
    if($item -like "*NAME*" -and $item -like "*Library*" -and $item -like "*-disable*" )
    {
        $line = $item | Select-String -pattern "^Name","Library","-disable"
        $name = $line[0] -split "\s"
        $drive_name = $name[1] -split '"'
        $lib = $line[1] -split "\s"
        $library = $lib[1] -split '"'
        $status = $line[2] -split "-"
        $final = "$library,$drive_name,$status"
        $Disabled_TapeDrive_Object += "$final`n"
    }
    }
    $Total_Tape_count =  ($InputObject | Select-String -pattern "Library").count
    $Disabled_Tape_count = $Disabled_TapeDrive_Object.Count
    $percent = [math]::round(($Disabled_Tape_count/$Total_Tape_count)*100,2)
    If($percent -lt 1)
    {
        $signal = "G"
    }
    elseif(($percent -eq 1) -or ($percent -le 2))
    {
        $signal = "Y"
    }
    else
    {
        $signal = "R"
    }
    $Disabled_TapeDrive_signal = "Disabled Tape Drive Count, $Disabled_Tape_count/$Total_Tape_count, $percent%, $signal"
    $Disabled_TapeDrive_Result = $Disabled_TapeDrive_Object | Convertfrom-Csv -Header 'Library','Drive Name','Status'
    $Disabled_TapeDrive_signal,$Disabled_TapeDrive_Result
}

Function Get-ScratchMediaCount
{
    [CmdletBinding()]
    Param(
    [parameter(Mandatory = $true)]
    $InputObject
    )
    ####omnirpt -report pool_list -tab
    $Scratch_Media_input = $InputObject |select -Skip 3
    $output_scratch = $Scratch_Media_input | ConvertFrom-Csv -Delimiter "`t" -Header 'Pool Name','Pool Description','Type','Full','Appendable','Scratch Media',poor,Fair,Good,'Total Media'
    $Scratch_Media_Result = $output_scratch  | select 'Pool Name','Scratch Media','Total Media'
    $FreeMedia_count = ($Scratch_Media_Result | Measure-Object -Property 'Scratch Media' -Sum).Sum
    $TotalMedia_count = ($Scratch_Media_Result | Measure-Object -Property 'Total Media' -Sum).Sum
    $percent = [math]::Round(($FreeMedia_count/$TotalMedia_count)*100,2)
    If($percent -gt 20)
    {
        $signal = "G"
    }
    elseif(($percent -ge 10) -and ($percent -le 20))
    {
        $signal = "Y"
    }
    else
    {
        $signal = "R"
    }
    $Scratch_Media_signal = "Scratch Media Count, $FreeMedia_count/$TotalMedia_count, $percent%, $signal"
    $Scratch_Media_signal,$Scratch_Media_Result
}




#### Main Function ##########


$config = Get-Config -ConfigFile $ConfigFile
$Reportdate = Get-Date -Format "dd-MMM-yyyy"
$date = Get-Date -Format "ddMMMyyyy"
$Activitylog = "Activity.log"
if ($config)
{
    Write-Log -Path $Activitylog -Entry "Started" -Type Information -ShowOnConsole
    Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole
    Write-Log -Path $Activitylog -Entry "Host: $($env:COMPUTERNAME)" -Type Information -ShowOnConsole
    Write-Log -Path $Activitylog -Entry "User: $($env:USERNAME)" -Type Information -ShowOnConsole
    Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole
    if ($config.deleteFilesOlderThanInDays -gt 0)
    {
        Remove-File -Day $config.deleteFilesOlderThanInDays -DirectoryPath $config.ReportPath -FileType "*.csv"
    }
        
    if (Test-Path -Path $config.InputFile)
    {
        Write-Log -Path $Activitylog -Entry "Reading $($config.InputFile)" -Type Information -ShowOnConsole
        $BackupDevices = Get-Content -Path $config.InputFile
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
            exit
        }
        $SignalReport = @()
        $DetailedReport = @()
        foreach ($BackupDevice in $BackupDevices)
        {
            Write-Log -Path $Activitylog -Entry "Fethching details from $BackupDevice" -Type Information -ShowOnConsole
            ###  To Do
            $OsType = Get-OperatingSystemType -computername $BackupDevice
            if($OsType)
            {
                if($OsType -eq "Windows")
                {
                    #call Invoke-Command
                    $Dp_Service_Output = Invoke-Command -ComputerName $BackupDevice -Credential $Credential -ScriptBlock {$config.ServiceHealthCheckCommand}
                    $Backup_Output = Invoke-Command -ComputerName $BackupDevice -Credential $Credential -ScriptBlock {$config.QueuingBackupHealthCheckCommand}
                    $Disabled_TapeDrive_Output = Invoke-Command -ComputerName $BackupDevice -Credential $Credential -ScriptBlock {$config.DisabledTapeDriveCountCommand}
                    $Scratch_Media_output = Invoke-Command -ComputerName $BackupDevice -Credential $Credential -ScriptBlock {$config.ScratchMediaCountCommand}
                }
                else
                {
                    $Dp_Service_Output = Invoke-PlinkCommand -IpAddress $BackupDevice -Credential $Credential -logFile $Activitylog -PlinkPath $scriptpath -command $config.ServiceHealthCheckCommand -FirstTime
                    $Backup_Output = Invoke-PlinkCommand -IpAddress $BackupDevice -Credential $Credential -logFile $Activitylog -PlinkPath $scriptpath -command $config.QueuingBackupHealthCheckCommand -FirstTime
                    $Disabled_TapeDrive_Output = Invoke-PlinkCommand -IpAddress $BackupDevice -Credential $Credential -logFile $Activitylog -PlinkPath $scriptpath -command $config.DisabledTapeDriveCountCommand -FirstTime
                    $Scratch_Media_output = Invoke-PlinkCommand -IpAddress $BackupDevice -Credential $Credential -logFile $Activitylog -PlinkPath $scriptpath -command $config.ScratchMediaCountCommand -FirstTime


                }
                    $Dpservice_signal,$Dp_Service_Result = Get-DpService -InputObject $Dp_Service_Output
                    $SignalReport += $Dpservice_signal
                    $DetailedReport += $Dp_Service_Result

                    $Backup_Result = Get-BackupStatus -InputObject $Backup_Output
                    $Backup_Count =  $Backup_Result.Count
                    $QueuedBackup_Result = $Backup_Result |? {$_.'session status' -eq "queuing"}

                    $Queuing_gt30_signal,$Queuing_30_Result = Get-QueuedBackupGreaterThanThirtyMinute -InputObject $QueuedBackup_Result -TotalBackup_Count $Backup_Count
                    $SignalReport += $Queuing_gt30_signal
                    $DetailedReport += $Queuing_30_Result

                    $Queuing_lt24_signal,$Queuing_lt24 = Get-QueuedBackupLessThanTwentyFourHour -InputObject $QueuedBackup_Result -TotalBackup_Count $Backup_Count
                    $SignalReport += $Queuing_lt24_signal
                    $DetailedReport += $Queuing_lt24

                    $Queuing_gt24_signal,$Queuing_gt24 = Get-QueuedBackupGreaterThanTwentyFourHour -InputObject $QueuedBackup_Result -TotalBackup_Count $Backup_Count
                    $SignalReport += $Queuing_gt24_signal
                    $DetailedReport += $Queuing_gt24

                    $Mount_req_signal,$Mount_Request_Result = Get-Mount_Request -InputObject $Backup_Result
                    $SignalReport += $Mount_req_signal
                    $DetailedReport += $Mount_Request_Result

                    $Disabled_TapeDrive_signal,$Disabled_TapeDrive_Result = Get-DisabledTapeDriveCount -InputObject $Disabled_TapeDrive_Output
                    $SignalReport += $Disabled_TapeDrive_signal
                    $DetailedReport += $Disabled_TapeDrive_Result

                    $Scratch_Media_signal,$Scratch_Media_Result = Get-ScratchMediaCount -InputObject $Scratch_Media_Output
                    $SignalReport += $Scratch_Media_signal
                    $DetailedReport += $Scratch_Media_Result


            }

        }
        $SignalReportName = $config.Reportpath +"\"+$config.Account + "_" + $config.Technology + "_" + $config.backupType + "_" + "Signal" + "_" + $Reportdate + ".csv"
        $DetailReportName = $config.Reportpath +"\"+$config.Account + "_" + $config.Technology + "_" + $config.backupType + "_" + "Detailed" + "_" + $Reportdate + ".csv"
        $Signalreport | Export-Csv -Path $SignalReportName -NoTypeInformation
        $DetailedReport | Export-Csv -Path $DetailReportName -NoTypeInformation

        if ($config.SendEmail -eq "yes")
        {  
            $attachment = @()
            $attachment += $SignalReportName
            $attachment += $DetailReportName
            $sendMailMessageParameters = @{
                To          = $config.mail.To.Split(";")
                from        = $config.mail.From 
                Subject     = "$($config.mail.Subject) $(Get-Date -Format 'dd-MMM-yyyy - dddd - HH:mm')"      
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
            $body = "Please find the healthcheck reports in the attachment"
            
             
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
        Write-Log -Path $Activitylog -Entry "$($config.InputFile) Not Found!" -Type Error -ShowOnConsole
    }
}
else
{
    Write-Log -Path $Activitylog -Entry "Invalid $ConfigFile" -Type Error -ShowOnConsole
}
Write-Log -Path $Activitylog -Entry "Completed" -Type Information -ShowOnConsole

