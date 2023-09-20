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
   11. Free Disk Space DataDisk
   12. Library Status
   13. Hung Backup Count
   14. Mount Request Count
   15. Disabled Backup Job Count
    
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
        #$logContent = [System.Text.StringBuilder]::new() 
       
        #[void]$logContent.AppendLine( '****************************' )
        #[void]$logContent.AppendLine( "Running Command : $command" )
        #[void]$logContent.AppendLine( '----------------------------' )
        '****************************' |  Out-File -FilePath $logFile -Append
        "Running Command : $command" |  Out-File -FilePath $logFile -Append
        '----------------------------' |  Out-File -FilePath $logFile -Append
        $Result = ""

        $decrypted = $Credential.GetNetworkCredential().password
        $plink = Join-Path $PlinkPath -ChildPath "plink.exe"
        $OriginalErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "SilentlyContinue"

        if ($FirstTime -eq $true)
        {
            $result = Write-Output "y" | &$plink -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command #2>&1 #| Out-String
        }
        else
        {
            $result = echo y | &$plink -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command #2>&1 | Out-String
        }
        $ErrorActionPreference = $OriginalErrorActionPreference
        #[void]$logContent.AppendLine( $result )      
        #[void]$logContent.AppendLine( '----------------------------' )
        #[void]$logContent.AppendLine( '****************************' )
        #$logContent.ToString() | Out-File -FilePath $logFile -Append
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
        #$logContent = [System.Text.StringBuilder]::new() 
       
        #[void]$logContent.AppendLine( '****************************' )
        #[void]$logContent.AppendLine( "Running Command : $command" )
        #[void]$logContent.AppendLine( '----------------------------' )
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
        <#
        if ($UseSSHStream)
        {
        $ssh = New-SSHShellStream -SessionId $sessionId
        if (Invoke-SSHStreamExpectSecureAction -ShellStream $ssh -Command $command -ExpectString "Enable Password:" -SecureAction $Credential.password)
        {

        
        $ssh.WriteLine($command)
        Start-Sleep -Milliseconds 1000
        do
        {
            $result += $ssh.read()
            Start-Sleep -Milliseconds 500
        }
        While ($ssh.DataAvailable)
        }
        $output =  $result
        #>

        #[void]$logContent.AppendLine( $result )      
        #[void]$logContent.AppendLine( '----------------------------' )
        #[void]$logContent.AppendLine( '****************************' )
        #$logContent.ToString() | Out-File -FilePath $logFile -Append
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
        #$logContent = [System.Text.StringBuilder]::new() 
        
        #$logcontent = New-Object -TypeName "System.Text.StringBuilder"
        #[void]$logContent.AppendLine( '****************************' )
        #[void]$logContent.AppendLine( "Running Command : $command" )
        #[void]$logContent.AppendLine( '----------------------------' )
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
        #[void]$logContent.AppendLine( $result )  
        $result | Out-File -FilePath $logFile -Append    
        #[void]$logContent.AppendLine( '----------------------------' )
        #[void]$logContent.AppendLine( '****************************' )
        '----------------------------'  | Out-File -FilePath $logFile -Append
        '****************************'  | Out-File -FilePath $logFile -Append
        #$logContent.ToString() | Out-File -FilePath $logFile -Append
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
             $operatingsystemtype = "Windows"
            if(($ResponseTime -le 64) -or ($ResponseTime -in $config.NonWindowsResponseTimeToLive))
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

Function AddMember
{
    param(
    $InputObject,
    $HCParamater
    )
    $inputobject | Add-Member NoteProperty "Technology"        $config.Technology
    $inputobject | Add-Member NoteProperty "ReportType"        $config.ReportType
    $inputobject | Add-Member NoteProperty "BackupApplication" $config.BackupApplication
    $inputobject | Add-Member NoteProperty "Account"           $config.Account
    $inputobject | Add-Member NoteProperty "BackupServer"      $Backupdevice
    $inputobject | Add-Member NoteProperty "ReportDate"        $Reportdate
    $inputobject | Add-Member NoteProperty "HC_Parameter"      $HCParamater
    $inputobject
}


Function Get-DpService
{
    [CmdletBinding()]
    Param(
    $InputObject 
    )
    try
    {
        $Service_Input = $InputObject | Select-String -Pattern ": " | Select-String -Pattern "Status:" -NotMatch
        $Dp_Service_Result = @()
        for($i=0;$i -lt $Service_Input.count;$i++)
        {
            $array = $Service_Input[$i] -split ":"
            $Dp_Service_Result += [PSCUSTOMObject] @{
            "Technology"        = $config.Technology
            "ReportType"        = $config.ReportType
            "BackupApplication" = $config.BackupApplication
            "Account"           = $config.Account
            "BackupServer"      = $Backupdevice
            "ReportDate"        = $Reportdate
            "HC_Parameter"      = "DP Service Status"
            "ServiceName"       = $array[0].trim()
            "ServiceStatus"     = $array[1].trim()
             }
        }
    
        $Total_count = ($Dp_Service_Result).Count
        $Active_count = ($Dp_Service_Result | Where-Object{$_.'ServiceStatus' -like "*Active*"}).count
        $percent = [math]::Round(($Active_Count/$Total_count)*100,2)
        If($percent -lt 100)
        {
            $signal = "R"
        }
        else
        {
            $signal = "G"
        }
        $Dpservice_signal   = [PSCUSTOMObject] @{
        "Technology"        = $config.Technology
        "ReportType"        = $config.ReportType
        "BackupApplication" = $config.BackupApplication
        "Account"           = $config.Account
        "BackupServer"      = $Backupdevice
        "ReportDate"        = $Reportdate
        'HC_Parameter'      = "DP Service Status"
        "HC_ShortName"      = "SS"
        "Value"             = "$Active_Count / $Total_count"
        'Percentage'        = "$percent % "
        'Status'            = "$Signal"
        }
        $Dpservice_signal,$Dp_Service_Result
    }
    catch
    {
        $Dpservice_signal,$Dp_Service_Result = Get-DpServiceMessage -Message "Parsing Error" #$_.Exception.Message
        $Dpservice_signal,$Dp_Service_Result
    }
}

Function Get-BackupStatus
{
    [CmdletBinding()]
    Param(
    $InputObject,$CurrentBackupDeviceTime
    )
    try
    {
        $current   = [datetime]$($CurrentBackupDeviceTime)
        $Queuing_Object = @()
        $Queuing_Input = $InputObject | Where {$_}
        if( "No currently running sessions." -in $Queuing_Input)
        {
            $result = "No currently running sessions."
            $result
        }
        else
        {
            for($i=0;$i -lt $Queuing_Input.Count;$i+=6)
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
            
                if($obj.'Session Started' -match '\D\D\D \D\D\D \d\d \d\d:\d\d:\d\d \d\d\d\d')
                {
                    $file_date = [datetime]::parseexact($obj.'Session Started','ddd MMM dd HH:mm:ss yyyy',$null)
                }
                elseif($obj.'Session Started' -match '\D\D\D \D\D\D  \d \d\d:\d\d:\d\d \d\d\d\d')
                {
                    $file_date = [datetime]::parseexact($obj.'Session Started','ddd MMM  d HH:mm:ss yyyy',$null)
                }
                elseif($obj.'Session Started' -like "*$timezone*")
                {
                    $Timezonedate = $obj.'Session Started'
                    $file_date = [datetime]$Timezonedate.Replace("$timezone","").Trim()
                }
                else
                {
                    $file_date = [datetime]$obj.'Session Started'
                }
                $Time_Span = (New-TimeSpan -Start $file_date -End $current).TotalMinutes
                $obj | Add-Member NoteProperty "Time Elapsed"  $Time_Span
                $Queuing_Object += $obj
            }
            $Queuing_Object
        }
    }
    catch
    {
        Write-Output $_.exception.message
    }
}

Function Get-QueuedBackupGreaterThanThirtyMinute
{
    [CmdletBinding()]
    Param(
    $InputObject
    )
    try
    {
        $Signal_Report,$Queuing30_Result = Get-BackupSessionMessage -Message "No Sessions" -HCParameter "Queuing Backup Count(>30 min)" -HCShortName "WQB"
        if ("No currently running sessions." -in $InputObject)
        {
            $Signal_Report.Value = "No Sessions"
            $Signal_Report.Status = "G"
            $Signal_Report,$Queuing30_Result
        }
        else
        {
            $Result = $InputObject | Where-Object{$_.'Time Elapsed' -gt 30 -and $_.'session status' -eq "queuing"} | select sessionid,'Session type','Backup Specification'
            $Queuing_Bck_count = @($Result).Count
            if($InputObject.GetType().name -eq "String")
            {
                $TotalBackup_Count = 0
            }
            else
            {
                $TotalBackup_Count = @($InputObject).Count
            }
            $percent = [math]::round(($Queuing_Bck_count/$TotalBackup_Count)*100,2)
            If($percent -lt 1)
            {
                $signal = "G"
            }
            elseif(($percent -ge 1) -and ($percent -le 2))
            {
                $signal = "Y"
            }
            else
            {
                $signal = "R"
            }
            if($Result)
            {
                $Queuing30_Result = AddMember -InputObject $Result -HCParamater "Queuing Backup Count(>30 min)" | select `
                                    Technology,ReportType,
                                    Account,BackupServer,
                                    ReportDate,HC_Parameter,
                                    SessionId,'Session Type','Backup Specification'
            }
            else
            {
                $Queuing30_Result.SessionId              = "No Queuing Sessions"
                $Queuing30_Result.'Session Type'         = "No Queuing Sessions"
                $Queuing30_Result.'Backup Specification' = "No Queuing Sessions"
            }
            $Signal_Report.Value      = "$Queuing_Bck_count / $TotalBackup_Count"
            $Signal_Report.Percentage = "$percent % "
            $Signal_Report.Status     = $signal
            $Signal_Report,$Queuing30_Result
        }
    }
    catch
    {
        $Signal_Report,$Queuing30_Result = Get-BackupSessionMessage -Message "Parsing Error" -HCParameter "Queuing Backup Count(>30 min)" -HCShortName "WQB"
        $Signal_Report,$Queuing30_Result
    }
}

Function Get-QueuedBackupLessThanTwentyFourHour
{
    [CmdletBinding()]
    Param(
    $InputObject
    )
    try
    {
        $Signal_Report,$Queuing12_Result = Get-BackupSessionMessage -Message "No Sessions" -HCParameter "Long Running Backup Count(>12 Hr and <24 Hr)" -HCShortName "LB_12"
        if ("No currently running sessions." -in $InputObject)
        {
            $Signal_Report.Value = "No Sessions"
            $Signal_Report.Status = "G"
            $Signal_Report,$Queuing12_Result
        }
        else
        {
            $Result = $InputObject | Where-Object{$_.'Time Elapsed' -ge 720 -and $_.'Time Elapsed' -lt 1440} | select sessionid,'Session type','Backup Specification'
            $Queuing_Bck_count = @($Result).Count
            if($InputObject.GetType().name -eq "String")
            {
                $TotalBackup_Count = 0
            }
            else
            {
                $TotalBackup_Count = @($InputObject).Count
            }
            $percent = [math]::round(($Queuing_Bck_count/$TotalBackup_Count)*100,2)
            If($percent -lt 1)
            {
                $signal = "G"
            }
            elseif(($percent -ge 1) -and ($percent -le 2))
            {
                $signal = "Y"
            }
            else
            {
                $signal = "R"
            }
            if($Result)
            {
                $Queuing12_Result = AddMember -InputObject $Result -HCParamater "Long Running Backup Count(>12 Hr and <24 Hr)" | select `
                                    Technology,ReportType,
                                    Account,BackupServer,
                                    ReportDate,HC_Parameter,
                                    SessionId,'Session Type','Backup Specification'
            }
            else
            {
                $Queuing12_Result.SessionId              = "No Long Running Sessions"
                $Queuing12_Result.'Session Type'         = "No Long Running Sessions"
                $Queuing12_Result.'Backup Specification' = "No Long Running Sessions"
            }
            $Signal_Report.Value      = "$Queuing_Bck_count / $TotalBackup_Count"
            $Signal_Report.Percentage = "$percent % "
            $Signal_Report.Status     = $signal
            $Signal_Report,$Queuing12_Result
        }
    }
    catch
    {
        $Signal_Report,$Queuing30_Result = Get-BackupSessionMessage -Message "Parsing Error" -HCParameter "Long Running Backup Count(>12 Hr and <24 Hr)" -HCShortName "LB_12"
        $Signal_Report,$Queuing30_Result
    }
}

Function Get-QueuedBackupGreaterThanTwentyFourHour
{
    [CmdletBinding()]
    Param(
    $InputObject
    )
    try
    {
        $Signal_Report,$Queuing24_Result = Get-BackupSessionMessage -Message "No Sessions" -HCParameter "Long Running Backup Count(>24 Hr)" -HCShortName "LB_24"
        if ("No currently running sessions." -in $InputObject)
        {
            $Signal_Report.Value = "No Sessions"
            $Signal_Report.Status = "G"
            $Signal_Report,$Queuing24_Result
        }
        else
        {
            $Result = $InputObject | Where-Object{$_.'Time Elapsed' -ge 1440} | select sessionid,'Session type','Backup Specification'
            $Queuing_Bck_count = @($Result).count
            if($InputObject.GetType().name -eq "String")
            {
                $TotalBackup_Count = 0
            }
            else
            {
                $TotalBackup_Count = @($InputObject).Count
            }
            $percent = [math]::round(($Queuing_Bck_count/$TotalBackup_Count)*100,2)
            If($percent -lt 1)
            {
                $signal = "G"
            }
            elseif(($percent -ge 1) -and ($percent -le 2))
            {
                $signal = "Y"
            }
            else
            {
                $signal = "R"
            }
            if($Result)
            {
                $Queuing24_Result = AddMember -InputObject $Result -HCParamater "Long Running Backup Count(>24 Hr)" | select `
                                    Technology,ReportType,
                                    Account,BackupServer,
                                    ReportDate,HC_Parameter,
                                    SessionId,'Session Type','Backup Specification'
            }
            else
            {
                $Queuing24_Result.SessionId              = "No Long Running Sessions"
                $Queuing24_Result.'Session Type'         = "No Long Running Sessions"
                $Queuing24_Result.'Backup Specification' = "No Long Running Sessions"
            }
            $Signal_Report.Value      = "$Queuing_Bck_count / $TotalBackup_Count"
            $Signal_Report.Percentage = "$percent % "
            $Signal_Report.Status     = $signal
            $Signal_Report,$Queuing24_Result
        }
    }
    catch
    {
        $Signal_Report,$Queuing30_Result = Get-BackupSessionMessage -Message "Parsing Error" -HCParameter "Long Running Backup Count(>24 Hr)" -HCShortName "LB_24"
        $Signal_Report,$Queuing30_Result
    }
}

Function Get-Mount_Request
{
    [CmdletBinding()]
    Param(
    $InputObject
    )
    try
    {
        $Mount_req_signal,$MountRequest_Result = Get-BackupSessionMessage -Message "No Sessions" -HCParameter "Mount Request" -HCShortName "MR"
        if ("No currently running sessions." -in $InputObject)
        {
            $Mount_req_signal.Value  = "No Sessions"
            $Mount_req_signal.Status = "G"
            $Mount_req_signal,$MountRequest_Result
        }
        else
        {
            $Mount_Request_Result = $InputObject |? {($_.'Session type' -eq "Backup") -and ($_.'Session Status' -eq "Mount Request")} | select sessionid,'Backup Specification'
            $Mount_req_count = @($Mount_Request_Result).count
            if($InputObject.GetType().name -eq "String")
            {
                $Total_Bck_count = 0
            }
            else
            {
                $Total_Bck_count = @($InputObject).Count
            }
            $percent = [math]::round(($Mount_req_count/$Total_Bck_count)*100,2)
            If($percent -lt 1)
            {
                $signal = "G"
            }
            elseif(($percent -ge 1) -and ($percent -le 2))
            {
                $signal = "Y"
            }
            else
            {
                $signal = "R"
            }
            if($Mount_Request_Result)
            {
                $MountRequest_Result = AddMember -InputObject $Mount_Request_Result -HCParamater "Mount Request" | select `
                                       Technology,ReportType,
                                       Account,BackupServer,
                                       ReportDate,HC_Parameter,
                                       SessionId,'Backup Specification'
            }
            else
            {
                $MountRequest_Result.SessionId              = "No Mount Request Sessions"
                $MountRequest_Result.'Session Type'         = "No Mount Request Sessions"
                $MountRequest_Result.'Backup Specification' = "No Mount Request Sessions"
            }
            $Mount_req_signal.Value      = "$Mount_req_count / $Total_Bck_count"
            $Mount_req_signal.Percentage = "$percent % "
            $Mount_req_signal.Status     = $signal
            $Mount_req_signal,$MountRequest_Result
        }
    }
    catch
    {
        $Signal_Report,$Queuing30_Result = Get-BackupSessionMessage -Message "Parsing Error" -HCParameter "Mount Request" -HCShortName "MR"
        $Signal_Report,$Queuing30_Result
    }
}

Function Get-Disabled_TapeDrive_count
{
    [CmdletBinding()]
    Param(
    $InputObject
    )
    try
    {
        $InputObj = $InputObject | where{$_}
        $Disabled_TapeDrive_input = $InputObj | Out-String
        $Disabled_TapeDrive_Object=@()
        $pattern = '='*169  
        $Disabled_TapeDrive_input.Split($pattern,[System.StringSplitOptions]::RemoveEmptyEntries) | Where-Object {$_ -match '\S'} | ForEach-Object {
        $item = $_ -split "\s+`n" | Where-Object {$_}
        if($item -like "*NAME*" -and $item -like "*-disable*" )
        {
            $line = $item | Select-String -pattern "^Name","Library","-disable"
            $name = $line[0] -split "\s"
            $drive_name = $name[1] -split '"'
            $line = $item | Select-String -pattern "Library"
            if($line -eq $null)
            {
                $library = ""
            }
            else
            {
                $lib = $line -split "\s"
                $library = $lib[1] -split '"'
            }
            $final = "$library,$drive_name,Disable"
            $Disabled_TapeDrive_Object += "$final`n"
               
        }
        }
        $Total_Tape_count =  ($InputObject | Select-String -pattern "^Name").count
        $Disabled_Tape_count = $Disabled_TapeDrive_Object.Count
        $percent = [math]::round(($Disabled_Tape_count/$Total_Tape_count)*100,2)
        If($percent -lt 1)
        {
            $signal = "G"
        }
        elseif(($percent -ge 1) -and ($percent -le 2))
        {
            $signal = "Y"
        }
        else
        {
            $signal = "R"
        }
        $Disabled_TapeDrive_Result = $Disabled_TapeDrive_Object | Convertfrom-Csv -Header 'Library','Drive Name','Status'
        if($Disabled_TapeDrive_Result)
        {
            $DisabledTapeDrive_Result = AddMember -InputObject $Disabled_TapeDrive_Result -HCParamater "Disabled Tape Drive Count" | select `
                                        Technology,ReportType,
                                        Account,BackupServer,
                                        ReportDate,HC_Parameter,
                                        Library,'Drive Name',Status
        }
        else
        {
            $DisabledTapeDrive_Result  = [PSCUSTOMObject] @{
            "Technology"               = $config.Technology
            "ReportType"               = $config.ReportType
            "BackupApplication"        = $config.BackupApplication
            "Account"                  = $config.Account
            "BackupServer"             = $Backupdevice
            "ReportDate"               = $Reportdate     
            'HC_Parameter'             = "Disabled Tape Drive Count"
            "Library"                  = "No Disabled Tape Drives"
            "Drive Name"               = "No Disabled Tape Drives"
            "Status"                   = "No Disabled Tape Drives"
            }
        }
        $Disabled_TapeDrive_signal = [PSCUSTOMObject] @{
        "Technology"               = $config.Technology
        "ReportType"               = $config.ReportType
        "BackupApplication"        = $config.BackupApplication
        "Account"                  = $config.Account
        "BackupServer"             = $Backupdevice
        "ReportDate"               = $Reportdate     
        'HC_Parameter'             = "Disabled Tape Drive Count"
        "HC_ShortName"             = "DTD"
        "Value"                    = "$Disabled_Tape_count / $Total_Tape_count"
        'Percentage'               = "$percent % "
        'Status'                   = $Signal
        }
        $Disabled_TapeDrive_signal,$DisabledTapeDrive_Result
    }
    catch
    {
        $Disabled_TapeDrive_signal,$DisabledTapeDrive_Result = Get-DisabledTapeDriveMessage -Message "Parsing Error"
        $Disabled_TapeDrive_signal,$DisabledTapeDrive_Result
    }
}

Function Get-Scratch_Media_Count
{
    [CmdletBinding()]
    Param(
    $InputObject
    )
    try
    {
        $InputObj = $InputObject | where{$_}
        $Scratch_Media_input = $InputObj |select -Skip 3
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
        $ScratchMedia_Result = AddMember -InputObject $Scratch_Media_Result -HCParamater "Scratch Media Count" | select `
                               Technology,ReportType,
                               Account,BackupServer,
                               ReportDate,HC_Parameter,
                               'Pool Name','Scratch Media','Total Media'
        $Scratch_Media_signal = [PSCUSTOMObject] @{
        "Technology"          = $config.Technology
        "ReportType"          = $config.ReportType
        "BackupApplication"   = $config.BackupApplication
        "Account"             = $config.Account
        "BackupServer"        = $Backupdevice
        "ReportDate"          = $Reportdate     
        'HC_Parameter'        = "Scratch Media Count"
        "HC_ShortName"        = "SM"
        "Value"               = "$FreeMedia_count / $TotalMedia_count"
        'Percentage'          = "$percent % "
        'Status'              = $Signal
        }
        $Scratch_Media_signal,$ScratchMedia_Result
    }
    catch
    {
        $Scratch_Media_signal,$ScratchMedia_Result = Get-ScratchMediaMessage -Message "Parsing Error"
        $Scratch_Media_signal,$ScratchMedia_Result
    }
}

Function Get-FailedBackup
{
    [CmdletBinding()]
    Param(
    $InputObject
    )
    if( "# No sessions matching the search criteria found." -in $InputObject)
    {
        $FailedBackupCommand_Result = "No Sessions matching"
        $FailedBackupCommand_Result
    }
    else
    {
        $Inputobj = $InputObject | where{$_}
        $Failed_Bck_converted = $Inputobj.replace("`t",",")| Convertfrom-Csv -Header 'Session Type','Specification','Status','Mode','Start Time','Start Time_t','End Time','End Time_t','Queuing', 'Duration','GB Written','Media','Errors','Warnings','Pending DA','Running DA','Failed DA','Completed DA','Object','Files','Success','Session Owner','Session ID'
        $FailedBackupCommand_Result = $Failed_Bck_converted| Select-Object 'Specification','Status','session id',mode,'Start Time'
        $FailedBackupCommand_Result
    }
}

Function Get-FailedBackupCount
{
    [CmdletBinding()]
    Param(
    $InputObject
    )
    $Failed_bck_signal,$FailedBackup_result = Get-FailedBackupMessage -Message "No Sessions Found" -HCParameter "Failed Backup Count" -HCShortName "FB"
    if("No Sessions matching" -in $InputObject)
    {
        $Failed_bck_signal.Status = "G"
        $Failed_bck_signal,$FailedBackup_result
    }
    else
    {
        $Failed_Bck_output = @()
        $Failed_Bck_output = $InputObject|?{$_.status -ne "In progress"}
        foreach($line in $Failed_Bck_output)
        {
            if($line.status -ne "Completed")
            {
                $line.status = "Failed"
            }
        }

        $Failed_Bck_result = @()
        foreach($y in $Failed_Bck_output)
        {
            $z = $Failed_Bck_output| ?{($_.Specification -eq $y.specification) -and ($_.mode -eq $y.mode)}
            $q = $z.count
            if($q -eq $null)
            {
                $Failed_Bck_result += $z
            }

            else
            {
                $m = $Failed_Bck_result.specification | Out-String -Stream
                if($m -notcontains $y.Specification)
                {
                    $Failed_Bck_result += $z | select -Last 1
                }
            }
        }

        $Failed_Backup_count = @($Failed_Bck_result | ? {$_.status -eq "Failed"}).count
        $Total_Backup_count = @($InputObject).Count

        $percent = [math]::Round(($Failed_Backup_count/$Total_Backup_count)*100,2)
        If($percent -lt 1)
        {
            $signal = "G"
        }
        elseif(($percent -ge 1) -and ($percent -le 2))
        {
            $signal = "Y"
        }
        else
        {
            $signal = "R"
        }
        $FailedBackup_result = AddMember -InputObject $Failed_Bck_result -HCParamater "Failed Backup Count" | select `
                               Technology,ReportType,
                               Account,BackupServer,
                               ReportDate,HC_Parameter,
                               'Specification','Status','session id','mode'
        $Failed_bck_signal.Value      = "$Failed_Backup_count / $Total_Backup_count"
        $Failed_bck_signal.Percentage = "$percent % "
        $Failed_bck_signal.Status     = $Signal
        $Failed_bck_signal,$FailedBackup_result
    }
}

Function Get-IDBBackup
{
    [CmdletBinding()]
    Param(
    #[parameter(Mandatory = $true)]
    $InputObject,$IDBBackUp
    )
    $IDB_Backup_Result = @()
    if($InputObject)
    {
        $InputObject = $InputObject | select -Skip 2
        foreach($line in $InputObject)
        {
            $obj = New-Object psObject
            $obj | Add-Member NoteProperty "Technology"        $config.Technology
            $obj | Add-Member NoteProperty "ReportType"        $config.ReportType
            $obj | Add-Member NoteProperty "BackupApplication" $config.BackupApplication
            $obj | Add-Member NoteProperty "Account"           $config.Account
            $obj | Add-Member NoteProperty "BackupServer"      $Backupdevice
            $obj | Add-Member NoteProperty "ReportDate"        $Reportdate
            $obj | Add-Member NoteProperty "HC_Parameter"      "IDB Backup Status"
            $obj | Add-Member NoteProperty "Specification"     $IDBBackUp.Specification
            $obj | Add-Member NoteProperty "SessionId"         $IDBBackUp.'Session id'
            $obj | Add-Member NoteProperty "Start Time"        $IDBBackUp.'Start time'
            $obj | Add-Member NoteProperty "Status"            $IDBBackUp.'Status'
            $media = $line -split '\s\s+'
            $obj | Add-Member NoteProperty "Medium Label"  $media[0]
            $IDB_Backup_Result += $obj
        }
    }
    else
    {
            $obj = New-Object psObject
            $obj | Add-Member NoteProperty "Technology"        $config.Technology
            $obj | Add-Member NoteProperty "ReportType"        $config.ReportType
            $obj | Add-Member NoteProperty "BackupApplication" $config.BackupApplication
            $obj | Add-Member NoteProperty "Account"           $config.Account
            $obj | Add-Member NoteProperty "BackupServer"      $Backupdevice
            $obj | Add-Member NoteProperty "ReportDate"        $Reportdate
            $obj | Add-Member NoteProperty "HC_Parameter"      "IDB Backup Status"
            $obj | Add-Member NoteProperty "Specification"     $IDBBackUp.Specification
            $obj | Add-Member NoteProperty "SessionId"         $IDBBackUp.'Session id'
            $obj | Add-Member NoteProperty "Start Time"        $IDBBackUp.'Start time'
            $obj | Add-Member NoteProperty "Status"            $IDBBackUp.'Status'
            $obj | Add-Member NoteProperty "Medium Label"  "-"
            $IDB_Backup_Result += $obj
    }
    $IDB_Backup_Result
}

Function Get-CriticalBackupStatus
{
    [CmdletBinding()]
    Param(
    #[parameter(Mandatory = $true)]
    $InputObject,$CriticalBackupServersInputFile
    )
    $Critical_Backup_signal,$CriticalBackup_result = Get-FailedBackupMessage -Message "No Sessions Found" -HCParameter "Critical Backup Status" -HCShortName "CB"
    if("No Sessions matching" -in $InputObject)
    {
        $Critical_Backup_signal,$CriticalBackup_result
    }
    else
    {
        $Critical_Bck_output = @()
        if(Test-Path -Path $CriticalBackupServersInputFile)
        {
            $CriticalBackupServers = get-content $CriticalBackupServersInputFile | select -Skip 1
        }
        else
        {
            $CriticalBackupServers = $null
        }
        if($CriticalBackupServers -eq $null)
        {
            $Critical_Backup_signal.Value        = "Invalid CriticalBackup.txt"
            $CriticalBackup_result.Specification = "Invalid CriticalBackup.txt"
            $CriticalBackup_result.Status        = "Invalid CriticalBackup.txt"
            $CriticalBackup_result.SessionId     = "Invalid CriticalBackup.txt"
            $CriticalBackup_result.Mode          = "Invalid CriticalBackup.txt"
            $Critical_Backup_signal,$CriticalBackup_result
        }
        else
        {
            foreach ($CriticalBackupServer in $CriticalBackupServers)
            {
                $CriticalBackupServer = $CriticalBackupServer.Trim()
                $out = $InputObject |?{$_.specification -like "*$($CriticalBackupServer)"}| select specification,status,'session id',mode
                if(!($out))
                {
                    $Critical_Bck_output += New-Object -TypeName PSobject -Property @{
                    Specification = "$CriticalBackupServer"
                    Status = "Did not Ran"
                    'Session id' = "-"
                    mode = "-"
                    }
                }
                else
                {
                    $Critical_Bck_output += $out |Where-Object{$_.status -ne "In progress"}

                }
            }
            #$Critical_Bck_output contains the critical backups fetched from failed backup(input object) 

            #Changing the status as Failed where status is other than completed and didn't ran
            foreach($i in $Critical_Bck_output)
            {
                if($i.status -notcontains "Completed")
                {
                    if($i.Status -ne "Did not Ran")
                    {
                        $i.status = "Failed"
                    }
                }
            }

            $Critical_Bck_result = @()
            foreach($Spec in $Critical_Bck_output)
            {
                $z = $Critical_Bck_output| ?{$_.Specification -eq $Spec.specification}
                $Count = $z.count
                if($Count -eq $null)
                {
                    $Critical_Bck_result += $z
                }

                else
                {
                    $m = $Critical_Bck_result.specification | Out-String -Stream
                    if($m -notcontains $Spec.Specification)
                    {
                        $Critical_Bck_result += $z | select -Last 1
                    }
                }
            }
            $Total_Critical_count = $CriticalBackupServers.Count
            $completed_Critical_count = @(($Critical_Bck_result|?{$_.status -eq "completed"})).count
            $percent = [math]::Round(($completed_Critical_count/$Total_Critical_count)*100,2)
            If($percent -eq  100)
            {
                $signal = "G"
            }
            else
            {
                $signal = "R"
            }
            $CriticalBackup_result = @()
            $CriticalBackup_result = AddMember -InputObject $Critical_Bck_result -HCParamater "Critical Backup Status" | select `
                                     Technology,ReportType,
                                     Account,BackupServer,
                                     ReportDate,HC_Parameter,
                                     'Specification','Status','session id','mode'
            $Critical_Backup_signal.Value      = "$completed_Critical_count / $Total_Critical_count"
            $Critical_Backup_signal.Percentage = "$percent % "
            $Critical_Backup_signal.Status     = "$Signal"
            $Critical_Backup_signal,$CriticalBackup_result
        }
    }
}

Function Get-FreeDiskSpaceUNIX
{
    [CmdletBinding()]
    Param(
    $InputObject,
    $DataDisks
    )
    try
    {
        $FreeDiskSpace_Input = $InputObject | select -Skip 1
        $FreeDiskSpace_Result = @()
        for($i=0; $i -lt $FreeDiskSpace_Input.Count ;$i++)
        {
            $obj = New-Object psobject
            $array = $FreeDiskSpace_Input[$i] -split '\s'| where{$_}
            if($array.count -eq 6)
            {
                $Total_Size = [math]::Round(($array[1] / 1mb),2)
                $Free_Space = [math]::Round(($array[3] / 1mb),2)
                $obj | Add-Member NoteProperty "Technology"        $config.Technology
                $obj | Add-Member NoteProperty "ReportType"        $config.ReportType
                $obj | Add-Member NoteProperty "BackupApplication" $config.BackupApplication
                $obj | Add-Member NoteProperty "Account"           $config.Account
                $obj | Add-Member NoteProperty "BackupServer"      $Backupdevice
                $obj | Add-Member NoteProperty "ReportDate"        $Reportdate
                $obj | Add-Member NoteProperty "HC_Parameter"      "Free Disk Space"
                $obj | Add-Member NoteProperty "Mount Point"  $array[5].trim()
                $obj | Add-Member NoteProperty "Total Size(GB)"    $Total_Size
                $obj | Add-Member NoteProperty "Free Space(GB)"    $Free_Space
                $FreeDiskSpace_Result += $obj
            }
            elseif($array.count -eq 5)
            {
                $Total_Size = [math]::Round(($array[0] / 1mb),2)
                $Free_Space = [math]::Round(($array[2] / 1mb),2)
                $obj | Add-Member NoteProperty "Technology"        $config.Technology
                $obj | Add-Member NoteProperty "ReportType"        $config.ReportType
                $obj | Add-Member NoteProperty "BackupApplication" $config.BackupApplication
                $obj | Add-Member NoteProperty "Account"           $config.Account
                $obj | Add-Member NoteProperty "BackupServer"      $Backupdevice
                $obj | Add-Member NoteProperty "ReportDate"        $Reportdate
                $obj | Add-Member NoteProperty "HC_Parameter"      "Free Disk Space"
                $obj | Add-Member NoteProperty "Mount Point"  $array[4].trim()
                $obj | Add-Member NoteProperty "Total Size(GB)"    $Total_Size
                $obj | Add-Member NoteProperty "Free Space(GB)"    $Free_Space
                $FreeDiskSpace_Result += $obj
            }
        }
        $TotalDiskSpace = ($FreeDiskSpace_Result | Measure-Object -Property 'Total Size(GB)' -Sum).Sum
        $FreeDiskSpace = ($FreeDiskSpace_Result | Measure-Object -Property 'Free Space(GB)' -Sum).Sum

        $percent = [math]::Round((($FreeDiskSpace/$TotalDiskSpace)*100),2)
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
        $FreeDiskSpace_signal  = [PSCUSTOMObject] @{
        "Technology"           = $config.Technology
        "ReportType"           = $config.ReportType
        "BackupApplication"    = $config.BackupApplication
        "Account"              = $config.Account
        "BackupServer"         = $Backupdevice
        "ReportDate"           = $Reportdate     
        'HC_Parameter'         = "Free Disk Space"
        "HC_ShortName"         = "FDS"
        "Value"                = "$FreeDiskSpace (GB) / $TotalDiskSpace (GB)"
        'Percentage'           = "$percent % "
        'Status'               = $Signal
        }
    }
    catch
    {
        $FreeDiskSpace_signal,$FreeDiskSpace_Result = Get-FreeDiskSpaceMessage -Message "Parsing Error" -HCParameter "Free Disk Space" -HCShortName "FDS"
    }
    ############################################################################################
    try
    {
        $DataDisk = $DataDisks -split ";"
        $FreeDiskSpaceDataDisk_Result = @()
        $TotalDiskSpaceDataDisk = @()
        $FreeDiskSpaceDataDisk = @()
        foreach($Drive in $DataDisk)
        {
            $FreeDiskSpaceDataDisk_Result += $FreeDiskSpace_Result | Where-Object{$_.'Mount Point' -eq "$Drive"} 
        }
        if($FreeDiskSpaceDataDisk_Result)
        {
            $TotalDiskSpaceDataDisk = ($FreeDiskSpaceDataDisk_Result | Measure-Object -Property 'Total Size(GB)' -Sum).Sum
            $FreeDiskSpaceDataDisk = ($FreeDiskSpaceDataDisk_Result  | Measure-Object -Property 'Free Space(GB)' -Sum).Sum
            $percent = [math]::Round((($FreeDiskSpaceDataDisk/$TotalDiskSpaceDataDisk)*100),2)
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
            $FreeDiskSpaceDataDisk_signal = [PSCUSTOMObject] @{
            "Technology"          = $config.Technology
            "ReportType"          = $config.ReportType
            "BackupApplication"   = $config.BackupApplication
            "Account"             = $config.Account
            "BackupServer"        = $Backupdevice
            "ReportDate"          = $Reportdate          
            'HC_Parameter'        = "Free Disk Space Data Disk"
            "HC_ShortName"        = "FDS_DS"
            "Value"               = "$FreeDiskSpaceDataDisk (GB) / $TotalDiskSpaceDataDisk (GB)"
            'Percentage'          = "$percent % "
            'Status'              = $Signal
            }
        }
        else
        {
            $FreeDiskSpaceDataDisk_signal,$FreeDiskSpaceDataDisk_Result = Get-FreeDiskSpaceMessage -Message "MountPoint not available" -HCParameter "Free Disk Space Data Disk" -HCShortName "FDS_DS"
        }
    }
    catch
    {
        $FreeDiskSpaceDataDisk_signal,$FreeDiskSpaceDataDisk_Result = Get-FreeDiskSpaceMessage -Message "Parsing Error" -HCParameter "Free Disk Space Data Disk" -HCShortName "FDS_DS"
    }
    $FreeDiskSpace_signal,$FreeDiskSpace_Result,$FreeDiskSpaceDataDisk_signal,$FreeDiskSpaceDataDisk_Result

}


########  Error Functions  ########

Function Get-DpServiceMessage
{
    [CmdletBinding()]
    Param(
    $Message
    )
    $Dp_Service_Result  = [PSCUSTOMObject] @{
    "Technology"        = $config.Technology
    "ReportType"        = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account"           = $config.Account
    "BackupServer"      = $Backupdevice
    "ReportDate"        = $Reportdate
    "HC_Parameter"      = "Service Status"
    "ServiceName"       = "$Message"
    "ServiceStatus"     = "$Message"
    }
    $Dpservice_signal   = [PSCUSTOMObject] @{
    "Technology"        = $config.Technology
    "ReportType"        = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account"           = $config.Account
    "BackupServer"      = $Backupdevice
    "ReportDate"        = $Reportdate
    'HC_Parameter'      = "DP Service Status"
    "HC_ShortName"      = "SS"
    "Value"             = "$Message"
    'Percentage'        = "0 % "
    'Status'            = "R"
    }
    $Dpservice_signal,$Dp_Service_Result
}

Function Get-BackupSessionMessage
{
    [CmdletBinding()]
    Param(
    $Message,
    $HCParameter,
    $HCShortName
    )
    $Queuing_Result        = [PSCUSTOMObject] @{
    "Technology"           = $config.Technology
    "ReportType"           = $config.ReportType
    "BackupApplication"    = $config.BackupApplication
    "Account"              = $config.Account
    "BackupServer"         = $Backupdevice
    "ReportDate"           = $Reportdate
    "HC_Parameter"         = $HCParameter
    "SessionId"            = "$Message"
    "Session Type"         = "$Message"
    "Backup Specification" = "$Message"
    }
    $Signal_Report       = [PSCUSTOMObject] @{
    "Technology"         = $config.Technology
    "ReportType"         = $config.ReportType
    "BackupApplication"  = $config.BackupApplication
    "Account"            = $config.Account
    "BackupServer"       = $Backupdevice
    "ReportDate"         = $Reportdate
    'HC_Parameter'       = $HCParameter
    "HC_ShortName"       = $HCShortName
    "Value"              = "$Message"
    'Percentage'         = "0 % "
    'Status'             = "R"
    }
    $Signal_Report,$Queuing_Result
}

Function Get-DisabledTapeDriveMessage
{
    [CmdletBinding()]
    Param(
    $Message
    )
    $DisabledTapeDrive_Result  = [PSCUSTOMObject] @{
    "Technology"        = $config.Technology
    "ReportType"        = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account"           = $config.Account
    "BackupServer"      = $Backupdevice
    "ReportDate"        = $Reportdate
    "HC_Parameter"      = "Disabled Tape Drive Count"
    "Library"           = $Message
    "Drive Name"        = $Message
    "Status"            = $Message
    }
    $Disabled_TapeDrive_signal    = [PSCUSTOMObject] @{
    "Technology"         = $config.Technology
    "ReportType"         = $config.ReportType
    "BackupApplication"  = $config.BackupApplication
    "Account"            = $config.Account
    "BackupServer"       = $Backupdevice
    "ReportDate"         = $Reportdate
    'HC_Parameter'       = "Disabled Tape Drive Count"
    "HC_ShortName"       = "DTD"
    "Value"              = "$Message"
    'Percentage'         = "0 % "
    'Status'             = "R"
    }
    $Disabled_TapeDrive_signal,$DisabledTapeDrive_Result
}

Function Get-ScratchMediaMessage
{
    [CmdletBinding()]
    Param(
    $Message
    )
    $ScratchMedia_Result= [PSCUSTOMObject] @{
    "Technology"        = $config.Technology
    "ReportType"        = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account"           = $config.Account
    "BackupServer"      = $Backupdevice
    "ReportDate"        = $Reportdate
    "HC_Parameter"      = "Scratch Media Count"
    "Pool Name"         = $Message
    "Scratch Media"     = $Message
    "Total Media"       = $Message
    }
    $Scratch_Media_signal= [PSCUSTOMObject] @{
    "Technology"         = $config.Technology
    "ReportType"         = $config.ReportType
    "BackupApplication"  = $config.BackupApplication
    "Account"            = $config.Account
    "BackupServer"       = $Backupdevice
    "ReportDate"         = $Reportdate
    'HC_Parameter'       = "Scratch Media Count"
    "HC_ShortName"       = "SM"
    "Value"              = "$Message"
    'Percentage'         = "0 % "
    'Status'             = "R"
    }
    $Scratch_Media_signal,$ScratchMedia_Result
}

Function Get-FailedBackupMessage
{
    [CmdletBinding()]
    Param(
    $Message,
    $HCParameter,
    $HCShortName
    )
    $FailedBackup_result= [PSCUSTOMObject] @{
    "Technology"        = $config.Technology
    "ReportType"        = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account"           = $config.Account
    "BackupServer"      = $Backupdevice
    "ReportDate"        = $Reportdate
    "HC_Parameter"      = $HCParameter
    "Specification"     = "$Message"
    "Status"            = "$Message"
    "SessionId"         = "$Message"
    "Mode"              = "$Message"
    }
    $Failed_bck_signal   = [PSCUSTOMObject] @{
    "Technology"         = $config.Technology
    "ReportType"         = $config.ReportType
    "BackupApplication"  = $config.BackupApplication
    "Account"            = $config.Account
    "BackupServer"       = $Backupdevice
    "ReportDate"         = $Reportdate
    'HC_Parameter'       = $HCParameter
    "HC_ShortName"       = $HCShortName
    "Value"              = "$Message"
    'Percentage'         = "0 % "
    'Status'             = "R"
    }
    $Failed_bck_signal,$FailedBackup_result
}

Function Get-FreeDiskSpaceMessage
{
    [CmdletBinding()]
    Param(
    $Message,
    $HCParameter,
    $HCShortName
    )
    $FreeDiskSpace_Result= [PSCUSTOMObject] @{
    "Technology"         = $config.Technology
    "ReportType"         = $config.ReportType
    "BackupApplication"  = $config.BackupApplication
    "Account"            = $config.Account
    "BackupServer"       = $Backupdevice
    "ReportDate"         = $Reportdate
    "HC_Parameter"       = $HCParameter
    "Drive/MountPoint"   = "$Message"
    "Free Space"         = "$Message"
    "Total Size"         = "$Message"
    }
    $FreeDiskSpace_signal= [PSCUSTOMObject] @{
    "Technology"         = $config.Technology
    "ReportType"         = $config.ReportType
    "BackupApplication"  = $config.BackupApplication
    "Account"            = $config.Account
    "BackupServer"       = $Backupdevice
    "ReportDate"         = $Reportdate
    'HC_Parameter'       = $HCParameter
    "HC_ShortName"       = $HCShortName
    "Value"              = "$Message"
    'Percentage'         = "0 % "
    'Status'             = "R"
    }
    $FreeDiskSpace_signal,$FreeDiskSpace_Result
}

Function Get-SignalSummary
{
    [CmdletBinding()]
    Param(
    $Inputobject
    )
    $Red       = @($Inputobject | Where-Object{$_.Status -eq "R"}).Count
    $Yellow    = @($Inputobject | Where-Object{$_.Status -eq "Y"}).Count
    $Green     = @($Inputobject | Where-Object{$_.Status -eq "G"}).Count
    $Disabled  = @($Inputobject | Where-Object{$_.Status -eq "D"}).Count


    $StatusCode        =  0
    $OverallStatus     = "G"
    if($red)
    {
        $OverallStatus = "R"
        $StatusCode    =  2
    }
    elseif($Yellow)
    {
        $OverallStatus = "Y"
        $StatusCode    =  1
    }

    $SignalSummary        = [pscustomobject] @{
    "Technology"          = $config.Technology
    "ReportType"          = $config.ReportType
    "BackupApplication"   = $config.BackupApplication
    "Account"             = $config.Account
    "BackupServer"        = $Backupdevice
    "ReportDate"          = $Reportdate          
    "R-Count"             = $red
    "Y-Count"             = $Yellow
    "G-Count"             = $Green
    "D-Count"             = $Disabled
    "Status"              = $OverallStatus
    "StatusCode"          = $StatusCode
    }
    $SignalSummary
}

Function Export-DPFiles
{
    $SignalReport                 | Export-Csv -Path $SignalReportName                 -NoTypeInformation
    $Dp_Service_Result            | Export-Csv -Path $DpService_ReportName             -NoTypeInformation
    $Queuing_30_Result            | Export-Csv -Path $Queuing30_ReportName             -NoTypeInformation
    $Queuing_lt24_Result          | Export-Csv -Path $Queuing_lt24_ReportName          -NoTypeInformation
    $Queuing_gt24_Result          | Export-Csv -Path $Queuing_gt24_ReportName          -NoTypeInformation
    $Mount_Request_Result         | Export-Csv -Path $MountRequest_ReportName          -NoTypeInformation
    $Disabled_TapeDrive_Result    | Export-Csv -Path $DisabledTapeDrive_ReportName     -NoTypeInformation
    $Scratch_Media_Result         | Export-Csv -Path $ScratchMedia_ReportName          -NoTypeInformation
    $Failed_Bck_result            | Export-Csv -Path $FailedBackup_ReportName          -NoTypeInformation
    $IDB_Backup_Result            | Export-Csv -Path $IDBBackup_ReportName             -NoTypeInformation
    $Critical_Bck_result          | Export-Csv -Path $CriticalBackup_ReportName        -NoTypeInformation
    $LibraryStatus_Result         | Export-Csv -Path $LibraryStatus_ReportName         -NoTypeInformation
    $HungBackup_Result            | Export-Csv -Path $HungBackup_ReportName            -NoTypeInformation
    $DisabledBackupJob_Result     | Export-Csv -Path $DisabledBackupJob_ReportName     -NoTypeInformation
    $FreeDiskSpace_Result         | Export-Csv -Path $FreeDiskSpace_ReportName         -NoTypeInformation
    $FreeDiskSpaceDataDisk_Result | Export-Csv -Path $FreeDiskSpaceDataDisk_ReportName -NoTypeInformation
    $SignalSummaryResult          | Export-Csv -Path $SignalSummaryReportName          -NoTypeInformation
}
#### Main Function ##########


$config = Get-Config -ConfigFile $ConfigFile
$culture = [CultureInfo]'en-us'
$Reportdate = ([system.datetime]::UtcNow).ToString("dd-MMM-yy HH:mm", $culture)
$date = ([system.datetime]::UtcNow).ToString("ddMMMyy_HHmm", $culture)
$Activitylog = "Activity.log"
if ($config)
{
    Write-Log -Path $Activitylog -Entry "Started" -Type Information -ShowOnConsole -OverWrite
    Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole
    Write-Log -Path $Activitylog -Entry "Host: $($env:COMPUTERNAME)" -Type Information -ShowOnConsole
    Write-Log -Path $Activitylog -Entry "User: $($env:USERNAME)" -Type Information -ShowOnConsole
    Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole
    
    if ($config.deleteFilesOlderThanInDays -gt 0)
    {
        Remove-File -Day $config.deleteFilesOlderThanInDays -DirectoryPath $config.ReportPath -FileType "*.csv"
    }
    
        
    #if (Test-Path -Path $config.InputFile)
    #{
        #Write-Log -Path $Activitylog -Entry "Reading $($config.InputFile)" -Type Information -ShowOnConsole
        #$BackupDevices = Get-Content -Path $config.InputFile

        ###########################################################################################################3
        $SignalReport = @()
        $BackupDevice = $config.BackupServer

        $SignalReportName                 = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "Signal"        + "_"  + $date+ ".csv"
        $DpService_ReportName             = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "SS"            + "_"  + $date+ ".csv"
        $Queuing30_ReportName             = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "WQB"           + "_"  + $date+ ".csv"
        $Queuing_lt24_ReportName          = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "LB_12"         + "_"  + $date+ ".csv"
        $Queuing_gt24_ReportName          = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "LB_24"         + "_"  + $date+ ".csv"
        $MountRequest_ReportName          = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "MR"            + "_"  + $date+ ".csv"
        $DisabledTapeDrive_ReportName     = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "DTD"           + "_"  + $date+ ".csv"
        $ScratchMedia_ReportName          = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "SM"            + "_"  + $date+ ".csv"
        $FailedBackup_ReportName          = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "FB"            + "_"  + $date+ ".csv"
        $IDBBackup_ReportName             = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "IDB"           + "_"  + $date+ ".csv"
        $CriticalBackup_ReportName        = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "CB"            + "_"  + $date+ ".csv"
        $LibraryStatus_ReportName         = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "LS"            + "_"  + $date+ ".csv"
        $HungBackup_ReportName            = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "HB"            + "_"  + $date+ ".csv"
        $DisabledBackupJob_ReportName     = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "DB"            + "_"  + $date+ ".csv"
        $FreeDiskSpace_ReportName         = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "FDS"           + "_"  + $date+ ".csv"
        $FreeDiskSpaceDataDisk_ReportName = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "FDS_DS"        + "_"  + $date+ ".csv"
        $SignalSummaryReportName          = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "SignalSummary" + "_"  + $date+ ".csv"
        ###########################################################################################################3

        Write-Log -Path $Activitylog -Entry "Fethching details from $BackupDevice" -Type Information -ShowOnConsole

        $TimeZone = Get-Content $config.TimezoneFile
        $CurrentBackupDeviceTime = Get-Content $config.CurrentBackupDeviceTimeFile

        if($config.ServiceHealthCheck -eq "Enabled")
        {
            $Dp_Service_Output = Get-Content $config.ServicesFile
            if($Dp_Service_Output)
            {
                $Dpservice_signal,$Dp_Service_Result = Get-DpService -InputObject $Dp_Service_Output
            }
            else
            {
                $Dpservice_signal,$Dp_Service_Result = Get-DpServiceMessage -Message "No Data Found"
            }
        }
        else
        {
                $Dpservice_signal,$Dp_Service_Result = Get-DpServiceMessage -Message "Disabled"
                $Dpservice_signal.status = "D"
        }
        $SignalReport += $Dpservice_signal

        if($config.Queuing -eq "Enabled")
        {
            $Backup_Result = Get-Content $config.QueuingFile
            if($Backup_Result)
            {
                $Queuing_gt30_signal,$Queuing_30_Result   = Get-QueuedBackupGreaterThanThirtyMinute -InputObject $Backup_Result
                $Queuing_lt24_signal,$Queuing_lt24_Result = Get-QueuedBackupLessThanTwentyFourHour -InputObject $Backup_Result
                $Queuing_gt24_signal,$Queuing_gt24_Result = Get-QueuedBackupGreaterThanTwentyFourHour -InputObject $Backup_Result
                $Mount_req_signal,$Mount_Request_Result   = Get-Mount_Request -InputObject $Backup_Result
            }
            else
            {
                $Queuing_gt30_signal,$Queuing_30_Result   = Get-BackupSessionMessage -Message "No Data Found" -HCParameter "Queuing Backup Count(>30 min)" -HCShortName "WQB"
                $Queuing_lt24_signal,$Queuing_lt24_Result = Get-BackupSessionMessage -Message "No Data Found" -HCParameter "Long Running Backup Count(>12 Hr and <24 Hr)" -HCShortName "LB_12"
                $Queuing_gt24_signal,$Queuing_gt24_Result = Get-BackupSessionMessage -Message "No Data Found" -HCParameter "Long Running Backup Count(>24 Hr)" -HCShortName "LB_24"
                $Mount_req_signal,$Mount_Request_Result   = Get-BackupSessionMessage -Message "No Data Found" -HCParameter "Mount Request" -HCShortName "MR"
            }
        }
        else
        {
                $Queuing_gt30_signal,$Queuing_30_Result   = Get-BackupSessionMessage -Message "Disabled" -HCParameter "Queuing Backup Count(>30 min)" -HCShortName "WQB"
                $Queuing_lt24_signal,$Queuing_lt24_Result = Get-BackupSessionMessage -Message "Disabled" -HCParameter "Long Running Backup Count(>12 Hr and <24 Hr)" -HCShortName "LB_12"
                $Queuing_gt24_signal,$Queuing_gt24_Result = Get-BackupSessionMessage -Message "Disabled" -HCParameter "Long Running Backup Count(>24 Hr)" -HCShortName "LB_24"
                $Mount_req_signal,$Mount_Request_Result   = Get-BackupSessionMessage -Message "Disabled" -HCParameter "Mount Request" -HCShortName "MR"
                            
                $Queuing_gt30_signal.status = "D"
                $Queuing_lt24_signal.status = "D"
                $Queuing_gt24_signal.status = "D"
                $Mount_req_signal.status    = "D"
        }
        $SignalReport += $Queuing_gt30_signal
        $SignalReport += $Queuing_lt24_signal
        $SignalReport += $Queuing_gt24_signal
        $SignalReport += $Mount_req_signal

        if($config.DisabledTapeDriveCount -eq "Enabled")
        {
            $Disabled_TapeDrive_Output = Get-Content $config.DisabledTapeDriveFile
            if($Disabled_TapeDrive_Output)
            {
                $Disabled_TapeDrive_signal,$Disabled_TapeDrive_Result = Get-Disabled_TapeDrive_count -InputObject $Disabled_TapeDrive_Output
            }
            else
            {
                $Disabled_TapeDrive_signal,$Disabled_TapeDrive_Result = Get-DisabledTapeDriveMessage -Message "No Data Found"
            }
        }
        else
        {
                $Disabled_TapeDrive_signal,$Disabled_TapeDrive_Result = Get-DisabledTapeDriveMessage -Message "Disabled"
                $Disabled_TapeDrive_signal.status = "D"
        }
        $SignalReport += $Disabled_TapeDrive_signal

        if($config.ScratchMediaCount -eq "Enabled")
        {
            $Scratch_Media_Output = Get-Content $config.ScratchMediaFile
            if($Scratch_Media_Output)
            {
                $Scratch_Media_signal,$Scratch_Media_Result = Get-Scratch_Media_Count -InputObject $Scratch_Media_Output
            }
            else
            {
                $Scratch_Media_signal,$Scratch_Media_Result = Get-ScratchMediaMessage -Message "Failed To Run Command"
            }
        }
        else
        {
                $Scratch_Media_signal,$Scratch_Media_Result = Get-ScratchMediaMessage -Message "Disabled"
                $Scratch_Media_signal.status = "D"
        }
        $SignalReport += $Scratch_Media_signal

        if($config.FailedBackupCount -eq "Enabled")
        {
            $failedBackup_Output = Get-Content $config.FailedBackupFile
            if($failedBackup_Output)
            {
                $FailedBackupCommand_Result = Get-FailedBackup -InputObject $failedBackup_Output
                $Failed_bck_signal,$Failed_Bck_result = Get-FailedBackupCount -InputObject $FailedBackupCommand_Result
                $Critical_Backup_signal,$Critical_Bck_result = Get-CriticalBackupStatus -InputObject $FailedBackupCommand_Result -CriticalBackupServersInputFile $config.CriticalBackupServersInputFile
            }
            else
            {
                $Failed_bck_signal,$Failed_Bck_result        = Get-FailedBackupMessage -Message "Failed To Run Command" -HCParameter "Failed Backup Count"    -HCShortName "FB"
                $Critical_Backup_signal,$Critical_Bck_result = Get-FailedBackupMessage -Message "Failed To Run Command" -HCParameter "Critical Backup Status" -HCShortName "CB"
            }
        }
        else
        {
                $Failed_bck_signal,$Failed_Bck_result        = Get-FailedBackupMessage -Message "Disabled" -HCParameter "Failed Backup Count"    -HCShortName "FB"
                $Critical_Backup_signal,$Critical_Bck_result = Get-FailedBackupMessage -Message "Disabled" -HCParameter "Critical Backup Status" -HCShortName "CB"
                $Failed_bck_signal.status      = "D"
                $Critical_Backup_signal.status = "D"
        }
        $SignalReport += $Failed_bck_signal
        $SignalReport += $Critical_Backup_signal

        ####   Free Disk Space  ####
        if($config.FreeDiskSpace -eq "Enabled")
        {
            $DiskspaceCommand = "Get-WmiObject win32_logicaldisk"
            $DataDisks = $config.DataDisks
            $FreeDiskSpaceOutput = Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $DiskspaceCommand -logFile $Activitylog
            if($FreeDiskSpaceOutput)
            {
                $FreeDiskSpace_signal,$FreeDiskSpace_Result,$FreeDiskSpaceDataDisk_signal,$FreeDiskSpaceDataDisk_Result = Get-FreeDiskSpaceWindows -InputObject $FreeDiskSpaceOutput -DataDisks $DataDisks
            }
            else
            {
                $FreeDiskSpace_signal,$FreeDiskSpace_Result                 = Get-FreeDiskSpaceMessage     -Message "Failed to Run Command" -HCParameter "Free Disk Space" -HCShortName "FDS"
                $FreeDiskSpaceDataDisk_signal,$FreeDiskSpaceDataDisk_Result = Get-FreeDiskSpaceMessage     -Message "Failed to Run Command" -HCParameter "Free Disk Space Data Disk" -HCShortName "FDS_DS"
            }
        }
        else
        {
                $FreeDiskSpace_signal,$FreeDiskSpace_Result                 = Get-FreeDiskSpaceMessage     -Message "Disabled" -HCParameter "Free Disk Space" -HCShortName "FDS"
                $FreeDiskSpaceDataDisk_signal,$FreeDiskSpaceDataDisk_Result = Get-FreeDiskSpaceMessage     -Message "Disabled" -HCParameter "Free Disk Space Data Disk" -HCShortName "FDS_DS"
                $FreeDiskSpace_signal.status = "D"
                $FreeDiskSpaceDataDisk_signal.status = "D"
        }


                                    

                    
        $SignalReport += $FreeDiskSpace_signal
        $SignalReport += $FreeDiskSpaceDataDisk_signal

        $SignalSummaryResult = Get-SignalSummary -Inputobject $SignalReport

        $SignalReport                 | Export-Csv -Path $SignalReportName                 -NoTypeInformation
        $Dp_Service_Result            | Export-Csv -Path $DpService_ReportName             -NoTypeInformation
        $Queuing_30_Result            | Export-Csv -Path $Queuing30_ReportName             -NoTypeInformation
        $Queuing_lt24_Result          | Export-Csv -Path $Queuing_lt24_ReportName          -NoTypeInformation
        $Queuing_gt24_Result          | Export-Csv -Path $Queuing_gt24_ReportName          -NoTypeInformation
        $Mount_Request_Result         | Export-Csv -Path $MountRequest_ReportName          -NoTypeInformation
        $Disabled_TapeDrive_Result    | Export-Csv -Path $DisabledTapeDrive_ReportName     -NoTypeInformation
        $Scratch_Media_Result         | Export-Csv -Path $ScratchMedia_ReportName          -NoTypeInformation
        $Failed_Bck_result            | Export-Csv -Path $FailedBackup_ReportName          -NoTypeInformation
        $IDB_Backup_Result            | Export-Csv -Path $IDBBackup_ReportName             -NoTypeInformation
        $Critical_Bck_result          | Export-Csv -Path $CriticalBackup_ReportName        -NoTypeInformation
        $LibraryStatus_Result         | Export-Csv -Path $LibraryStatus_ReportName         -NoTypeInformation
        $HungBackup_Result            | Export-Csv -Path $HungBackup_ReportName            -NoTypeInformation
        $DisabledBackupJob_Result     | Export-Csv -Path $DisabledBackupJob_ReportName     -NoTypeInformation
        $FreeDiskSpace_Result         | Export-Csv -Path $FreeDiskSpace_ReportName         -NoTypeInformation
        $FreeDiskSpaceDataDisk_Result | Export-Csv -Path $FreeDiskSpaceDataDisk_ReportName -NoTypeInformation
        $SignalSummaryResult          | Export-Csv -Path $SignalSummaryReportName          -NoTypeInformation
            
        if ($config.SendEmail -eq "yes")
        {  
            $attachment = @()
            $attachment += $SignalReportName
            $attachment += $DpService_ReportName        
            $attachment += $Queuing30_ReportName        
            $attachment += $Queuing_lt24_ReportName     
            $attachment += $Queuing_gt24_ReportName     
            $attachment += $MountRequest_ReportName     
            $attachment += $DisabledTapeDrive_ReportName
            $attachment += $ScratchMedia_ReportName     
            $attachment += $FailedBackup_ReportName     
            $attachment += $IDBBackup_ReportName        
            $attachment += $CriticalBackup_ReportName   
            $attachment += $LibraryStatus_ReportName    
            $attachment += $HungBackup_ReportName       
            $attachment += $DisabledBackupJob_ReportName
            $attachment += $FreeDiskSpace_ReportName 
            $attachment += $FreeDiskSpaceDataDisk_ReportName
            $attachment += $SignalSummaryReportName

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
            }
        }        
    #}

    #else
    #{
    #    Write-Log -Path $Activitylog -Entry "$($config.InputFile) Not Found!" -Type Error -ShowOnConsole
    #}
}
else
{
    Write-Log -Path $Activitylog -Entry "Invalid $ConfigFile" -Type Error -ShowOnConsole
}
Write-Log -Path $Activitylog -Entry "Completed" -Type Information -ShowOnConsole


