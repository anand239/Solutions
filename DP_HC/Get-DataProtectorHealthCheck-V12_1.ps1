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
        if ($FirstTime -eq $true)
        {
            $result = Write-Output "y" | &$plink -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command 2>&1 | Out-String
        }
        else
        {
            $result = &$plink -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command 2>&1 | Out-String
        }

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
        [Parameter(Mandatory = $true)]
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

        $Result= Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {Invoke-Expression $using:Command}
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
Function New-SignalObject
{  
   param(
    $Technology,
    $ReportType,
    $BackupApplication,
    $Account,
    $BackupServer,
    $ReportDate,       
    $HC_Parameter,
    $HC_ShortName
    )
    
    [PSCUSTOMObject] @{
    "Technology" = $Technology
    "ReportType" = $ReportType
    "BackupApplication" = $BackupApplication
    "Account" = $Account
    "BackupServer" = $Backupdevice
    "ReportDate" = $Reportdate          
    "HC_Parameter"= $HC_Parameter
    "HC_ShortName" = $HC_ShortName     
    "Value"= "0/0"
    "Percentage" = "0%"
    "Status" = "R"
    }
}

Function Get-DpService
{
    [CmdletBinding()]
    Param(
    #[parameter(Mandatory = $true)]
    $InputObject 
    )
    #omnisv -status
  
    $Service_Input = $InputObject | Select-String -Pattern ": " | Select-String -Pattern "Status:" -NotMatch
    $Dp_Service_Result = @()
    for($i=0;$i -lt $Service_Input.count;$i++)
    {
        $array = $Service_Input[$i] -split ":"
        $Dp_Service_Result = [PSCUSTOMObject] @{
        "Technology" = $config.Technology
        "ReportType" = $config.ReportType
        "BackupApplication" = $config.BackupApplication
        "Account" = $config.Account
        "BackupServer" = $Backupdevice
        "ReportDate" = $Reportdate
        "HC_Parameter" = "DP Service Status"
        "ServiceName" =$array[0].trim()
        "ServiceStatus"= $array[1].trim()
         }
    }
    
    $Total_count = ($Dp_Service_Result).Count
    $Active_count = ($Dp_Service_Result | Where-Object{$_.'Status [PID]' -like "*Active*"}).count
    $percent = [math]::Round(($Active_Count/$Total_count)*100,2)
    If($percent -lt 100)
    {
        $signal = "R"
    }
    else
    {
        $signal = "G"
    }
    $Dpservice_signal = [PSCUSTOMObject] @{
    "Technology" = $config.Technology
    "ReportType" = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account" = $config.Account
    "BackupServer" = $Backupdevice
    "ReportDate" = $Reportdate
    'HC_Parameter'= "DP Service Status"
    "HC_ShortName" = "SS"
    "Value"= "$Active_Count/$Total_count"
    'Percentage' = "$percent%"
    'Status' = "$Signal"
    }
    $Dpservice_signal,$Dp_Service_Result
}

Function Get-BackupStatus
{
    [CmdletBinding()]
    Param(
    #[parameter(Mandatory = $true)]
    $InputObject 
    )
    $current = Get-Date
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

              $file_date = [datetime]$obj.'Session Started'
              $Time_Span = (New-TimeSpan -Start $file_date -End $current).TotalMinutes
              $obj | Add-Member NoteProperty "Time Elapsed"  $Time_Span
              $Queuing_Object += $obj
        }
        $Queuing_Object
    }
}

Function Get-QueuedBackupGreaterThanThirtyMinute
{
    [CmdletBinding()]
    Param(
    #[parameter(Mandatory = $true)]
    $InputObject
    )
    $Signal_Report = [PSCUSTOMObject] @{
    "Technology" = $config.Technology
    "ReportType" = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account" = $config.Account
    "BackupServer" = $Backupdevice
    "ReportDate" = $Reportdate   
    'HC_Parameter'= "Queuing Backup Count(>30 min)"
    "HC_ShortName" = "WQB"
    "Value"= "No Sessions"
    'Percentage' = "0%"
    'Status' = "G"
    }
    if ("No currently running sessions." -in $InputObject)
    {
        $Queuing30_Result = [PSCUSTOMObject] @{
        "Technology" = $config.Technology
        "ReportType" = $config.ReportType
        "BackupApplication" = $config.BackupApplication
        "Account" = $config.Account
        "BackupServer" = $Backupdevice
        "ReportDate" = $Reportdate   
        'HC_Parameter'= "Queuing Backup Count(>30 min)"
        "SessionId" = "No Sessions"
        "Session Type" = "No Sessions"
        "Backup Specification" = "No Sessions"
        }
        $Signal_Report,$Queuing30_Result
    }
    else
    {
        #checking elapsed Greaater than 30 Min
        $Result = $InputObject | Where-Object{$_.'Time Elapsed' -gt 30 -and $_.'session status' -eq "queuing"} | select sessionid,'Session type','Backup Specification'
        $Queuing_Bck_count = @($Result).Count
        $TotalBackup_Count = @($InputObject).Count
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
        $Queuing30_Result = @()
        foreach($line in $Result)
        {
            $Queuing30_Result += [PSCUSTOMObject] @{
            "Technology" = $config.Technology
            "ReportType" = $config.ReportType
            "BackupApplication" = $config.BackupApplication
            "Account" = $config.Account
            "BackupServer" = $Backupdevice
            "ReportDate" = $Reportdate   
            'HC_Parameter'= "Queuing Backup Count(>30 min)"
            "SessionId" = $line.sessionid
            "Session Type" = $line.'Session type'
            "Backup Specification" = $line.'Backup Specification'
            }
        }
        $Signal_Report.Value= "$Queuing_Bck_count/$TotalBackup_Count"
        $Signal_Report.Percentage = "$percent%"
        $Signal_Report.Status = $signal
        $Signal_Report,$Queuing30_Result
    }
}

Function Get-QueuedBackupLessThanTwentyFourHour
{
    [CmdletBinding()]
    Param(
    #[parameter(Mandatory = $true)]
    $InputObject
    )
    $Signal_Report = [PSCUSTOMObject] @{
    "Technology" = $config.Technology
    "ReportType" = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account" = $config.Account
    "BackupServer" = $Backupdevice
    "ReportDate" = $Reportdate   
    'HC_Parameter'= "Long Running Backup Count(>12 Hr and <24 Hr)"
    "HC_ShortName" = "LB_12"
    "Value"= "No Sessions"
    'Percentage' = "0%"
    'Status' = "G"
    }
    if ("No currently running sessions." -in $InputObject)
    {
        $Queuing12_Result = [PSCUSTOMObject] @{
        "Technology" = $config.Technology
        "ReportType" = $config.ReportType
        "BackupApplication" = $config.BackupApplication
        "Account" = $config.Account
        "BackupServer" = $Backupdevice
        "ReportDate" = $Reportdate   
        'HC_Parameter'= "Long Running Backup Count(>12 Hr and <24 Hr)"
        "SessionId" = "No Sessions"
        "Session Type" = "No Sessions"
        "Backup Specification" = "No Sessions"
        }
        $Signal_Report,$Queuing12_Result
    }
    else
    {
        # ($time_30 -ge 12) -and ($time_30 -lt 24)) Checking elapsed btwe 12 and 24 hr
        $Result = $InputObject | Where-Object{$_.'Time Elapsed' -ge 720 -and $_.'Time Elapsed' -lt 1440} | select sessionid,'Session type','Backup Specification'
        $Queuing_Bck_count = @($Result).Count
        $TotalBackup_Count = @($InputObject).count
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
        $Queuing12_Result = @()
        foreach($line in $Result)
        {
            $Queuing12_Result += [PSCUSTOMObject] @{
            "Technology" = $config.Technology
            "ReportType" = $config.ReportType
            "BackupApplication" = $config.BackupApplication
            "Account" = $config.Account
            "BackupServer" = $Backupdevice
            "ReportDate" = $Reportdate     
            'HC_Parameter'= "Long Running Backup Count(>12 Hr and <24 Hr)"
            "SessionId" = $line.sessionid
            "Session Type" = $line.'Session type'
            "Backup Specification" = $line.'Backup Specification'
            }
        }
        $Signal_Report += [PSCUSTOMObject] @{
        "Technology" = $config.Technology
        "ReportType" = $config.ReportType
        "BackupApplication" = $config.BackupApplication
        "Account" = $config.Account
        "BackupServer" = $Backupdevice
        "ReportDate" = $Reportdate     
        'HC_Parameter'= "Long Running Backup Count(>12 Hr and <24 Hr)"
        "HC_ShortName" = "LB_12"
        "Value"= "$Queuing_Bck_count/$TotalBackup_Count"
        'Percentage' = "$percent%"
        'Status' = $signal
        }
        $Signal_Report,$Queuing12_Result
    }
}

Function Get-QueuedBackupGreaterThanTwentyFourHour
{
    [CmdletBinding()]
    Param(
    #[parameter(Mandatory = $true)]
    $InputObject
    )
    $Signal_Report = [PSCUSTOMObject] @{
    "Technology" = $config.Technology
    "ReportType" = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account" = $config.Account
    "BackupServer" = $Backupdevice
    "ReportDate" = $Reportdate   
    'HC_Parameter'= "Long Running Backup Count(>24 Hr)"
    "HC_ShortName" = "LB_24"
    "Value"= "No Sessions"
    'Percentage' = "0%"
    'Status' = "G"
    }
    if ("No currently running sessions." -in $InputObject)
    {
        $Queuing12_Result = [PSCUSTOMObject] @{
        "Technology" = $config.Technology
        "ReportType" = $config.ReportType
        "BackupApplication" = $config.BackupApplication
        "Account" = $config.Account
        "BackupServer" = $Backupdevice
        "ReportDate" = $Reportdate   
        'HC_Parameter'= "Long Running Backup Count(>24 Hr)"
        "SessionId" = "No Sessions"
        "Session Type" = "No Sessions"
        "Backup Specification" = "No Sessions"
        }
        $Signal_Report,$Queuing12_Result
    }
    else
    {
        #Checking elapsed Greater Than 24 hr
        $Result = $InputObject | Where-Object{$_.'Time Elapsed' -ge 1440} | select sessionid,'Session type','Backup Specification'
        $Queuing_Bck_count = @($Result).count
        $TotalBackup_Count = @($InputObject).count
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
        $Queuing24_Result = @()
        foreach($line in $Result)
        {
            $Queuing24_Result += [PSCUSTOMObject] @{
            "Technology" = $config.Technology
            "ReportType" = $config.ReportType
            "BackupApplication" = $config.BackupApplication
            "Account" = $config.Account
            "BackupServer" = $Backupdevice
            "ReportDate" = $Reportdate     
            'HC_Parameter'= "Long Running Backup Count(>24 Hr)"
            "SessionId" = $line.sessionid
            "Session Type" = $line.'Session type'
            "Backup Specification" = $line.'Backup Specification'
            }
        }
        $Signal_Report += [PSCUSTOMObject] @{
        "Technology" = $config.Technology
        "ReportType" = $config.ReportType
        "BackupApplication" = $config.BackupApplication
        "Account" = $config.Account
        "BackupServer" = $Backupdevice
        "ReportDate" = $Reportdate     
        'HC_Parameter'= "Long Running Backup Count(>24 Hr)"
        "HC_ShortName" = "LB_24"
        "Value"= "$Queuing_Bck_count/$TotalBackup_Count"
        'Percentage' = "$percent%"
        'Status' = $signal
        }
        $Signal_Report,$Queuing24_Result
    }
}

Function Get-Mount_Request
{
    [CmdletBinding()]
    Param(
    #[parameter(Mandatory = $true)]
    $InputObject
    )
    $Signal_Report = [PSCUSTOMObject] @{
    "Technology" = $config.Technology
    "ReportType" = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account" = $config.Account
    "BackupServer" = $Backupdevice
    "ReportDate" = $Reportdate   
    'HC_Parameter'= "Mount Request"
    "HC_ShortName" = "MR"
    "Value"= "No Sessions"
    'Percentage' = "0%"
    'Status' = "G"
    }
    if ("No currently running sessions." -in $InputObject)
    {
        $Queuing12_Result = [PSCUSTOMObject] @{
        "Technology" = $config.Technology
        "ReportType" = $config.ReportType
        "BackupApplication" = $config.BackupApplication
        "Account" = $config.Account
        "BackupServer" = $Backupdevice
        "ReportDate" = $Reportdate   
        'HC_Parameter'= "Long Running Backup Count(>24 Hr)"
        "SessionId" = "No Sessions"
        "Session Type" = "No Sessions"
        "Backup Specification" = "No Sessions"
        }
        $Signal_Report,$Queuing12_Result
    }
    else
    {
        $Mount_Request_Result = $InputObject |? {($_.'Session type' -eq "Backup") -and ($_.'Session Status' -eq "Mount Request")} | select sessionid,'Backup Specification'
        $Mount_req_count = @($Mount_Request_Result).count
        $Total_Bck_count = @($InputObject).Count
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
        $MountRequest_Result = @()
        foreach($line in $Mount_Request_Result)
        {
            $MountRequest_Result += [PSCUSTOMObject] @{
            "Technology" = $config.Technology
            "ReportType" = $config.ReportType
            "BackupApplication" = $config.BackupApplication
            "Account" = $config.Account
            "BackupServer" = $Backupdevice
            "ReportDate" = $Reportdate     
            'HC_Parameter'= "Mount Request"
            "SessionId" = $line.sessionid
            "Backup Specification" = $line.'Backup Specification'
            }
        }
        $Mount_req_signal += [PSCUSTOMObject] @{
        "Technology" = $config.Technology
        "ReportType" = $config.ReportType
        "BackupApplication" = $config.BackupApplication
        "Account" = $config.Account
        "BackupServer" = $Backupdevice
        "ReportDate" = $Reportdate     
        'HC_Parameter'= "Mount Request"
        "HC_ShortName" = "MR"
        "Value"= "$Mount_req_count/$Total_Bck_count"
        'Percentage' = "$percent%"
        'Status' = $signal
        }
        $Mount_req_signal,$MountRequest_Result
    }
}

Function Get-Disabled_TapeDrive_count
{
    [CmdletBinding()]
    Param(
    #[parameter(Mandatory = $true)]
    $InputObject
    )
    #####omnidownload -list_devices -detail
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
    $DisabledTapeDrive_Result = @()
    foreach($line in $Disabled_TapeDrive_Result)
    {
        $DisabledTapeDrive_Result += [PSCUSTOMObject] @{
        "Technology" = $config.Technology
        "ReportType" = $config.ReportType
        "BackupApplication" = $config.BackupApplication
        "Account" = $config.Account
        "BackupServer" = $Backupdevice
        "ReportDate" = $Reportdate     
        'HC_Parameter'= "Disabled Tape Drive Count"
        "Library" = $line.Library
        "Drive Name" = $line.'Drive Name'
        "Status" = $line.'Status'
        }
    }
    $Disabled_TapeDrive_signal = [PSCUSTOMObject] @{
    "Technology" = $config.Technology
    "ReportType" = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account" = $config.Account
    "BackupServer" = $Backupdevice
    "ReportDate" = $Reportdate     
    'HC_Parameter'= "Disabled Tape Drive Count"
    "HC_ShortName" = "DTD"
    "Value"= "$Disabled_Tape_count/$Total_Tape_count"
    'Percentage' = "$percent%"
    'Status' = $Signal
    }

    $Disabled_TapeDrive_signal,$DisabledTapeDrive_Result
}

Function Get-Scratch_Media_Count
{
    [CmdletBinding()]
    Param(
    #[parameter(Mandatory = $true)]
    $InputObject
    )
    ####omnirpt -report pool_list -tab
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
    $ScratchMedia_Result = @()
    foreach($line in $Scratch_Media_Result)
    {
        $ScratchMedia_Result += [PSCUSTOMObject] @{
        "Technology" = $config.Technology
        "ReportType" = $config.ReportType
        "BackupApplication" = $config.BackupApplication
        "Account" = $config.Account
        "BackupServer" = $Backupdevice
        "ReportDate" = $Reportdate     
        'HC_Parameter'= "Scratch Media Count"
        "Pool Name" = $line.'Pool Name'
        "Scratch Media" = $line.'Scratch Media'
        "Total Media" = $line.'Total Media'
        }
    }
    $Scratch_Media_signal = [PSCUSTOMObject] @{
    "Technology" = $config.Technology
    "ReportType" = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account" = $config.Account
    "BackupServer" = $Backupdevice
    "ReportDate" = $Reportdate     
    'HC_Parameter'= "Scratch Media Count"
    "HC_ShortName" = "SM"
    "Value"= "$FreeMedia_count/$TotalMedia_count"
    'Percentage' = "$percent%"
    'Status' = $Signal
    }
    $Scratch_Media_signal,$ScratchMedia_Result
}

Function Get-FailedBackup
{
    [CmdletBinding()]
    Param(
    #[parameter(Mandatory = $true)]
    $InputObject
    )
    #omnirpt -report list_sessions -timeframe $previous 18:00 $current 17:59 -tab -no_copylist -no_verificationlist -no_conslist
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
    #[parameter(Mandatory = $true)]
    $InputObject
    )
    $Failed_bck_signal = [PSCUSTOMObject] @{
    "Technology" = $config.Technology
    "ReportType" = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account" = $config.Account
    "BackupServer" = $Backupdevice
    "ReportDate" = $Reportdate     
    'HC_Parameter'= "Failed Backup Count"
    "HC_ShortName" = "FB"
    "Value"= "No Sessions Found"
    'Percentage' = "0%"
    'Status' = "G"
    }
    if("No Sessions matching" -in $InputObject)
    {
        $FailedBackup_result= [PSCUSTOMObject] @{
        "Technology"        = $config.Technology
        "ReportType"        = $config.ReportType
        "BackupApplication" = $config.BackupApplication
        "Account"           = $config.Account
        "BackupServer"      = $Backupdevice
        "ReportDate"        = $Reportdate
        "HC_Parameter"      = "Failed Backup Count"
        "Specification"     = "No Sessions Found"
        "Status"            = "No Sessions Found"
        "SessionId"         = "No Sessions Found"
        "Mode"              = "No Sessions Found"
        }
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
        $FailedBackup_result = @()
        foreach($line in $Failed_Bck_result)
        {
            $FailedBackup_result += [PSCUSTOMObject] @{
            "Technology" = $config.Technology
            "ReportType" = $config.ReportType
            "BackupApplication" = $config.BackupApplication
            "Account" = $config.Account
            "BackupServer" = $Backupdevice
            "ReportDate" = $Reportdate
            "HC_Parameter" = "Failed Backup Count"
            "Specification" = $line.'Specification'
            "Status" = $line.'Status'
            "SessionId" = $line.'session id'
            "Mode" = $line.'mode'
            }
        }
        $Failed_bck_signal.Value= "$Failed_Backup_count/$Total_Backup_count"
        $Failed_bck_signal.Percentage = "$percent%"
        $Failed_bck_signal.Status = $Signal
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
    $obj = New-Object psObject
    $obj | Add-Member NoteProperty "Technology" $config.Technology
    $obj | Add-Member NoteProperty "ReportType" $config.ReportType
    $obj | Add-Member NoteProperty "BackupApplication" $config.BackupApplication
    $obj | Add-Member NoteProperty "Account" $config.Account
    $obj | Add-Member NoteProperty "BackupServer" $Backupdevice
    $obj | Add-Member NoteProperty "ReportDate" $Reportdate
    $obj | Add-Member NoteProperty "HC_Parameter" "IDB Backup Status"
    $obj | Add-Member NoteProperty "Specification"  $IDBBackUp.Specification
    $obj | Add-Member NoteProperty "SessionId"      $IDBBackUp.'Session id'
    $obj | Add-Member NoteProperty "Start Time"     $IDBBackUp.'Start time'
    $obj | Add-Member NoteProperty "Status"         $IDBBackUp.'Status'
    if($InputObject -eq $null)
    {
        $obj | Add-Member NoteProperty "Medium Label"  "-"
    }
    else
    {
        $media = ($InputObject | select -Skip 2) -split '\s\s+'
        $obj | Add-Member NoteProperty "Medium Label"  $media[0]
    }
    $IDB_Backup_Result += $obj
    $IDB_Backup_Result
}

Function Get-CriticalBackupStatus
{
    [CmdletBinding()]
    Param(
    #[parameter(Mandatory = $true)]
    $InputObject,$CriticalBackupServersInputFile
    )
    $Critical_Backup_signal = [PSCUSTOMObject] @{
    "Technology" = $config.Technology
    "ReportType" = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account" = $config.Account
    "BackupServer" = $Backupdevice
    "ReportDate" = $Reportdate          
    'HC_Parameter'= "Critical Backup Status"
    "HC_ShortName" = "CB"     
    "Value"= "No Sessions Found"
    'Percentage' = "0%"
    'Status' = "G"
    }
    if("No Sessions matching" -in $InputObject)
    {
        $CriticalBackup_result = [PSCUSTOMObject] @{
        "Technology"        = $config.Technology
        "ReportType"        = $config.ReportType
        "BackupApplication" = $config.BackupApplication
        "Account"           = $config.Account
        "BackupServer"      = $Backupdevice
        "ReportDate"        = $Reportdate          
        'HC_Parameter'      = "Critical Backup Status"
        "Specification"     = "No Sessions Found"
        "Status"            = "No Sessions Found"
        "SessionId"         = "No Sessions Found"
        "Mode"              = "No Sessions Found"
        }
        $Critical_Backup_signal,$CriticalBackup_result
    }
    else
    {
        $Critical_Bck_output = @()
        $CriticalBackupServers = get-content $CriticalBackupServersInputFile | select -Skip 1
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
                if($out -eq $null)
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
            foreach($line in $Critical_Bck_result)
            {
                $CriticalBackup_result += [PSCUSTOMObject] @{
                "Technology" = $config.Technology
                "ReportType" = $config.ReportType
                "BackupApplication" = $config.BackupApplication
                "Account" = $config.Account
                "BackupServer" = $Backupdevice
                "ReportDate" = $Reportdate          
                'HC_Parameter'= "Critical Backup Status"
                "Specification" = $line.'Specification'
                "Status" = $line.'Status'
                "SessionId" = $line.'session id'
                "Mode" = $line.'mode'
                }
            }
            $Critical_Backup_signal.Value      = "$completed_Critical_count/$Total_Critical_count"
            $Critical_Backup_signal.Percentage = "$percent%"
            $Critical_Backup_signal.Status     = "$Signal"
            $Critical_Backup_signal,$CriticalBackup_result
        }
    }
}

Function Get-RemoteLibraryStatus
{
    [CmdletBinding()]
    Param(
    #[parameter(Mandatory = $true)]
    $InputObject
    )
    $notok = 0
    $Library_Status_output = @()
    foreach($line in $InputObject)
    {
        $obj = New-Object psobject
        $Lnput_Lib = $line -split ','
        $ip = $Lnput_Lib[1]
        $username = $Lnput_Lib[2]
        $password = ConvertTo-SecureString $Lnput_Lib[3] -AsPlainText -Force
        $Cred = New-Object System.Management.Automation.PSCredential -ArgumentList ($username, $password)
        $session = New-SSHSession -ComputerName "$ip" -Credential $Cred -AcceptKey:$true -ErrorAction Stop
        $output = $(Invoke-sshCommand -SessionId $Session.sessionid -Command "hardware show status" -EnsureConnection -TimeOut 300).output
        $ssh_out = $output | select -Skip 2
        foreach($status in $ssh_out)
        {
            if($status -notlike "*ok*")
            {
                $notok++
            }
        }
        if($notok -eq 0)
        {
            $obj | Add-Member NoteProperty "Library Name/IP" $ip
            $obj | Add-Member NoteProperty "Status" 'Active'
            $Library_Status_output += $obj
        }
        else
        {
            $obj | Add-Member NoteProperty "Library Name/IP" $ip
            $obj | Add-Member NoteProperty "Status" 'Not-Active'
            $Library_Status_output += $obj
        }
        Remove-SSHSession -SessionId $session.sessionid
    
    }
    $Library_Status_output
}

Function Get-HungObject
{
    [CmdletBinding()]
    Param(
    #[parameter(Mandatory = $true)]
    $InputObject
    )
    $HUNG_Object = @()
    for($i=0;$i -lt $InputObject.Count;$i+=13)
    {
            $obj = New-Object psObject
            $arr =$InputObject[$i] -split ": " 
            $obj | Add-Member NoteProperty "$($arr[0].trim())"  $arr[1].trim()
            $arr =$InputObject[$i+1] -split ": "
            $obj | Add-Member NoteProperty "$($arr[0].trim())"  $arr[1].trim()
            $arr =$InputObject[$i+11] -split ": "
            $obj | Add-Member NoteProperty "$($arr[0].trim())"  $arr[1].trim()
            $HUNG_Object += $obj

    }
    $HUNG_Object
}

Function Get-FreeDiskSpaceHPUX
{
    [CmdletBinding()]
    Param(
    #[parameter(Mandatory = $true)]
    $InputObject
    )
    $FreeDiskSpace_Input = $InputObject | select -Skip 1
    $FreeDiskSpace_Object = @()
    for($i=0; $i -lt $FreeDiskSpace_Input.Count ;$i++)
    {
        $obj = New-Object psobject
        $array = $FreeDiskSpace_Input[$i] -split '\s+'
        if($array.count -eq 6)
        {
            $Total_Size = [math]::Round(($array[1] / 1mb),2)
            $Free_Space = [math]::Round(($array[3] / 1mb),2)
            $obj | Add-Member NoteProperty "Technology" $config.Technology
            $obj | Add-Member NoteProperty "ReportType" $config.ReportType
            $obj | Add-Member NoteProperty "BackupApplication" $config.BackupApplication
            $obj | Add-Member NoteProperty "Account" $config.Account
            $obj | Add-Member NoteProperty "BackupServer" $Backupdevice
            $obj | Add-Member NoteProperty "ReportDate" $Reportdate
            $obj | Add-Member NoteProperty "HC_Parameter" "Free Disk Space"
            $obj | Add-Member NoteProperty "Mount Point" $array[5]
            $obj | Add-Member NoteProperty "Total Size(GB)" $Total_Size
            $obj | Add-Member NoteProperty "Free Space(GB)" $Free_Space
            $FreeDiskSpace_Object += $obj
        }

    }
    $FreeDiskSpace_Result = $FreeDiskSpace_Object | select 'Mount Point','Total Size(GB)','Free Space(GB)' 
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
    $FreeDiskSpace_signal = [PSCUSTOMObject] @{
    "Technology" = $config.Technology
    "ReportType" = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account" = $config.Account
    "BackupServer" = $Backupdevice
    "ReportDate" = $Reportdate     
    'HC_Parameter'= "Free Disk Space"
    "HC_ShortName" = "FDS"
    "Value"= $FreeDiskSpace/$TotalDiskSpace
    'Percentage' = $percent
    'Status' = $Signal
    }
    $FreeDiskSpace_signal,$FreeDiskSpace_Result
}

Function Get-FreeDiskSpaceUnix
{
    [CmdletBinding()]
    Param(
    #[parameter(Mandatory = $true)]
    $InputObject
    )
    $FreeDiskSpace_Input = $InputObject | select -Skip 1
    $FreeDiskSpace_Result = @()
    for($i=0; $i -lt $FreeDiskSpace_Input.Count ;$i++)
    {
        $obj = New-Object psobject
        $array = $FreeDiskSpace_Input[$i] -split '\s+'
        if($array.count -eq 6)
        {
            $obj | Add-Member NoteProperty "Technology" $config.Technology
            $obj | Add-Member NoteProperty "ReportType" $config.ReportType
            $obj | Add-Member NoteProperty "BackupApplication" $config.BackupApplication
            $obj | Add-Member NoteProperty "Account" $config.Account
            $obj | Add-Member NoteProperty "BackupServer" $Backupdevice
            $obj | Add-Member NoteProperty "ReportDate" $Reportdate
            $obj | Add-Member NoteProperty "HC_Parameter" "Free Disk Space"
            $obj | Add-Member NoteProperty "Mount Point" $array[5]
            $obj | Add-Member NoteProperty "Total Size" $array[1]
            $obj | Add-Member NoteProperty "Free Space" $array[3]
            $FreeDiskSpace_Result += $obj
        }

    }
    [float]$TotalDiskSpace = 0
    [float]$FreeDiskSpace = 0
    foreach($line in $FreeDiskSpace_Result)
    {
        if($line.'Total Size' -like "*G")
        {
            $Size_gb = $line.'Total Size' -split 'G'
            $TotalDiskSpace += [float]$Size_gb[0]
        }
        elseif($line.'Total Size' -like "*M")
        {
            $Size_mb = $line.'Total Size' -split 'M'
            $TotalDiskSpace += [float]$Size_mb[0]/1024
        }
        elseif($line.'Total Size' -like "*K")
        {
            $Size_kb = $line.'Total Size' -split 'K'
            $TotalDiskSpace += [float]($Size_kb[0]/1024)/1024
        }
        if($line.'Free Space' -like "*G")
        {
            $Size_gb = $line.'Free Space' -split 'G'
            $FreeDiskSpace += [float]$Size_gb[0]
        }
        elseif($line.'Free Space' -like "*M")
        {
            $Size_mb = $line.'Free Space' -split 'M'
            $FreeDiskSpace += [float]$Size_mb[0]/1024
        }
        elseif($line.'Free Space' -like "*K")
        {
            $Size_kb = $line.'Free Space' -split 'K'
            $FreeDiskSpace += [float]($Size_kb[0]/1024)/1024
        }
    }
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
    $FreeDiskSpace_signal = [PSCUSTOMObject] @{
    "Technology" = $config.Technology
    "ReportType" = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account" = $config.Account
    "BackupServer" = $Backupdevice
    "ReportDate" = $Reportdate          
    'HC_Parameter'= "Free Disk Space"
    "HC_ShortName" = "FDS"
    "Value"= $FreeDiskSpace/$TotalDiskSpace
    'Percentage' = $percent
    'Status' = $Signal
    }
    $FreeDiskSpace_signal,$FreeDiskSpace_Result
}

Function Get-FreeDiskSpaceWindows
{
    [CmdletBinding()]
    Param(
    #[parameter(Mandatory = $true)]
    $InputObject 
    )
    $FreeDiskSpace_Input = $InputObject | where-object {$_.DriveType -eq 3}
    $FreeDiskSpace_Result = @()
    foreach($disk in $FreeDiskSpace_Input)
    {
        $drive = $disk.DeviceId
        $free = [math]::Round(($disk.'freespace' / 1gb),2)
        $TotalSize = [math]::Round(($disk.'size'/1gb),2)
        $obj = New-Object psObject
        $obj | Add-Member NoteProperty "Technology" $config.Technology
        $obj | Add-Member NoteProperty "ReportType" $config.ReportType
        $obj | Add-Member NoteProperty "BackupApplication" $config.BackupApplication
        $obj | Add-Member NoteProperty "Account" $config.Account
        $obj | Add-Member NoteProperty "BackupServer" $Backupdevice
        $obj | Add-Member NoteProperty "ReportDate" $Reportdate
        $obj | Add-Member NoteProperty "HC_Parameter" "Free Disk Space"
        $obj | Add-Member NoteProperty "Drive"  $drive
        $obj | Add-Member NoteProperty "Free Space(GB)"  $free
        $obj | Add-Member NoteProperty "Total Size(GB)"  $TotalSize
        $FreeDiskSpace_Result += $obj
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
    $FreeDiskSpace_signal = [PSCUSTOMObject] @{
    "Technology" = $config.Technology
    "ReportType" = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account" = $config.Account
    "BackupServer" = $Backupdevice
    "ReportDate" = $Reportdate          
    'HC_Parameter'= "Free Disk Space"
    "HC_ShortName" = "FDS"
    "Value"= "$FreeDiskSpace/$TotalDiskSpace"
    'Percentage' = "$percent%"
    'Status' = $Signal
    }
    $FreeDiskSpace_signal,$FreeDiskSpace_Result
}

########  Error Functions  ########

Function Get-DpServiceError
{
    [CmdletBinding()]
    Param(
    $ErrorMessage
    )
    $Dp_Service_Result  = [PSCUSTOMObject] @{
    "Technology"        = $config.Technology
    "ReportType"        = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account"           = $config.Account
    "BackupServer"      = $Backupdevice
    "ReportDate"        = $Reportdate
    "HC_Parameter"      = "Service Status"
    "ServiceName"       = "$ErrorMessage"
    "ServiceStatus"     = "$ErrorMessage"
    }
    $Dpservice_signal    = [PSCUSTOMObject] @{
    "Technology"         = $config.Technology
    "ReportType"         = $config.ReportType
    "BackupApplication"  = $config.BackupApplication
    "Account"            = $config.Account
    "BackupServer"       = $Backupdevice
    "ReportDate"         = $Reportdate
    'HC_Parameter'       = "DP Service Status"
    "HC_ShortName"       = "SS"
    "Value"              = "$ErrorMessage"
    'Percentage'         = "0%"
    'Status'             = "R"
    }
    $Dpservice_signal,$Dp_Service_Result
}

Function Get-BackupSessionError
{
    [CmdletBinding()]
    Param(
    $ErrorMessage,
    $HCParameter,
    $HCShortName
    )
    $Queuing_Result = [PSCUSTOMObject] @{
    "Technology"        = $config.Technology
    "ReportType"        = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account"           = $config.Account
    "BackupServer"      = $Backupdevice
    "ReportDate"        = $Reportdate
    "HC_Parameter"      = $HCParameter
    "SessionId"         = "$ErrorMessage"
    "Session Type"      = "$ErrorMessage"
    "Backup Specification" = "$ErrorMessage"
    }
    $Signal_Report = [PSCUSTOMObject] @{
    "Technology"         = $config.Technology
    "ReportType"         = $config.ReportType
    "BackupApplication"  = $config.BackupApplication
    "Account"            = $config.Account
    "BackupServer"       = $Backupdevice
    "ReportDate"         = $Reportdate
    'HC_Parameter'       = $HCParameter
    "HC_ShortName"       = $HCShortName
    "Value"              = "$ErrorMessage"
    'Percentage'         = "0%"
    'Status'             = "R"
    }
    $Signal_Report,$Queuing_Result
}

Function Get-DisabledTapeDriveError
{
    [CmdletBinding()]
    Param(
    $ErrorMessage
    )
    $DisabledTapeDrive_Result  = [PSCUSTOMObject] @{
    "Technology"        = $config.Technology
    "ReportType"        = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account"           = $config.Account
    "BackupServer"      = $Backupdevice
    "ReportDate"        = $Reportdate
    "HC_Parameter"      = "Disabled Tape Drive Count"
    "Library"           = $ErrorMessage
    "Drive Name"        = $ErrorMessage
    "Status"            = $ErrorMessage
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
    "Value"              = "$ErrorMessage"
    'Percentage'         = "0%"
    'Status'             = "R"
    }
    $Disabled_TapeDrive_signal,$DisabledTapeDrive_Result
}

Function Get-ScratchMediaError
{
    [CmdletBinding()]
    Param(
    $ErrorMessage
    )
    $ScratchMedia_Result= [PSCUSTOMObject] @{
    "Technology"        = $config.Technology
    "ReportType"        = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account"           = $config.Account
    "BackupServer"      = $Backupdevice
    "ReportDate"        = $Reportdate
    "HC_Parameter"      = "Scratch Media Count"
    "Pool Name"         = $ErrorMessage
    "Scratch Media"     = $ErrorMessage
    "Total Media"       = $ErrorMessage
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
    "Value"              = "$ErrorMessage"
    'Percentage'         = "0%"
    'Status'             = "R"
    }
    $Scratch_Media_signal,$ScratchMedia_Result
}

Function Get-FailedBackupError
{
    [CmdletBinding()]
    Param(
    $ErrorMessage,
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
    "Specification"     = "$ErrorMessage"
    "Status"            = "$ErrorMessage"
    "SessionId"         = "$ErrorMessage"
    "Mode"              = "$ErrorMessage"
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
    "Value"              = "$ErrorMessage"
    'Percentage'         = "0%"
    'Status'             = "R"
    }
    $Failed_bck_signal,$FailedBackup_result
}

Function Get-FreeDiskSpaceError
{
    [CmdletBinding()]
    Param(
    $ErrorMessage
    )
    $FreeDiskSpace_Result= [PSCUSTOMObject] @{
    "Technology"         = $config.Technology
    "ReportType"         = $config.ReportType
    "BackupApplication"  = $config.BackupApplication
    "Account"            = $config.Account
    "BackupServer"       = $Backupdevice
    "ReportDate"         = $Reportdate
    "HC_Parameter"       = "Free Disk Space"
    "Drive/MountPoint"   = $ErrorMessage
    "Free Space"         = $ErrorMessage
    "Total Size"         = $ErrorMessage
    }
    $FreeDiskSpace_signal= [PSCUSTOMObject] @{
    "Technology"         = $config.Technology
    "ReportType"         = $config.ReportType
    "BackupApplication"  = $config.BackupApplication
    "Account"            = $config.Account
    "BackupServer"       = $Backupdevice
    "ReportDate"         = $Reportdate
    'HC_Parameter'       = "Free Disk Space"
    "HC_ShortName"       = "FDS"
    "Value"              = "$ErrorMessage"
    'Percentage'         = "0%"
    'Status'             = "R"
    }
    $FreeDiskSpace_signal,$FreeDiskSpace_Result
}

Function Get-IDBError
{
    [CmdletBinding()]
    Param(
    $ErrorMessage
    )
    $IDB_Backup_Result   = [PSCUSTOMObject] @{
    "Technology"         = $config.Technology
    "ReportType"         = $config.ReportType
    "BackupApplication"  = $config.BackupApplication
    "Account"            = $config.Account
    "BackupServer"       = $Backupdevice
    "ReportDate"         = $Reportdate
    "HC_Parameter"       = "IDB Backup Status"
    "Specification"      = $ErrorMessage
    "SessionId"          = $ErrorMessage
    "Start Time"         = $ErrorMessage
    "Status"             = $ErrorMessage
    }
    $IDBBackup_Signal    = [PSCUSTOMObject] @{
    "Technology"         = $config.Technology
    "ReportType"         = $config.ReportType
    "BackupApplication"  = $config.BackupApplication
    "Account"            = $config.Account
    "BackupServer"       = $Backupdevice
    "ReportDate"         = $Reportdate
    'HC_Parameter'       = "IDB Backup Status"
    "HC_ShortName"       = "IDB"
    "Value"              = "$ErrorMessage"
    'Percentage'         = "0%"
    'Status'             = "R"
    }
    $IDBBackup_Signal,$IDB_Backup_Result
}

Function Get-LibraryError
{
    [CmdletBinding()]
    Param(
    $ErrorMessage
    )
    $LibraryStatus_Result = [PSCUSTOMObject] @{
    "Technology"          = $config.Technology
    "ReportType"          = $config.ReportType
    "BackupApplication"   = $config.BackupApplication
    "Account"             = $config.Account
    "BackupServer"        = $Backupdevice
    "ReportDate"          = $Reportdate
    "HC_Parameter"        = "Library Status"
    "Library Name/IP"     = $ErrorMessage
    "Status"              = $ErrorMessage
    }
    $Library_Status_signal= [PSCUSTOMObject] @{
    "Technology"          = $config.Technology
    "ReportType"          = $config.ReportType
    "BackupApplication"   = $config.BackupApplication
    "Account"             = $config.Account
    "BackupServer"        = $Backupdevice
    "ReportDate"          = $Reportdate          
    'HC_Parameter'        = "Library Status"
    "HC_ShortName"        = "LS"
    "Value"               = $ErrorMessage
    'Percentage'          = "0%"
    'Status'              = "R"
    }
    $Library_Status_signal,$LibraryStatus_Result
}

Function Get-DisabledJobError
{
    [CmdletBinding()]
    Param(
    $ErrorMessage
    )
    $DisabledBackupJob_Result = [PSCUSTOMObject] @{
    "Technology"              = $config.Technology
    "ReportType"              = $config.ReportType
    "BackupApplication"       = $config.BackupApplication
    "Account"                 = $config.Account
    "BackupServer"            = $Backupdevice
    "ReportDate"              = $Reportdate
    "HC_Parameter"            = "Disabled Backup Job Count"
    "Specification"           = "$ErrorMessage"
    "Status"                  = "$ErrorMessage"
    }
    $DisabledBackupJob_Signal = [PSCUSTOMObject] @{
    "Technology"              = $config.Technology
    "ReportType"              = $config.ReportType
    "BackupApplication"       = $config.BackupApplication
    "Account"                 = $config.Account
    "BackupServer"            = $Backupdevice
    "ReportDate"              = $Reportdate          
    'HC_Parameter'            = "Disabled Backup Job Count"
    "HC_ShortName"            = "DB"
    "Value"                   = "$ErrorMessage"
    'Percentage'              = "0%"
    'Status'                  = "R"
    }
    $DisabledBackupJob_Signal,$DisabledBackupJob_Result
}


#### Main Function ##########


$config = Get-Config -ConfigFile $ConfigFile
$Reportdate = ([system.datetime]::UtcNow).ToString("dd-MMM-yyy")
$date = Get-Date -Format "ddMMMyy"
$Activitylog = "Activity.log"
if ($config)
{
    Write-Log -Path $Activitylog -Entry "Started" -Type Information -ShowOnConsole
    Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole
    Write-Log -Path $Activitylog -Entry "Host: $($env:COMPUTERNAME)" -Type Information -ShowOnConsole
    Write-Log -Path $Activitylog -Entry "User: $($env:USERNAME)" -Type Information -ShowOnConsole
    Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole
    <#
    if ($config.deleteFilesOlderThanInDays -gt 0)
    {
        Remove-File -Day $config.deleteFilesOlderThanInDays -DirectoryPath $config.ReportPath -FileType "*.csv"
    }
    #>
        
    #if (Test-Path -Path $config.InputFile)
    #{
        #Write-Log -Path $Activitylog -Entry "Reading $($config.InputFile)" -Type Information -ShowOnConsole
        #$BackupDevices = Get-Content -Path $config.InputFile
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

            #to do
            exit
        }
        #foreach ($BackupDevice in $BackupDevices)
        #{
        $BackupDevice = $config.BackupServer
        $library = Get-Content $config.LibraryDetailsInputFile
        $sshLines = $library | Select-String -Pattern "^ssh"
        $LocalLines = $library | Select-String -Pattern "^Local"
        $Library_Status_output = @()

            Write-Log -Path $Activitylog -Entry "Fethching details from $BackupDevice" -Type Information -ShowOnConsole
            $SignalReport = @()
            $DetailedReport = @()

            ###  To Do

            $OsType = Get-OperatingSystemType -computername $BackupDevice
            Write-Log -Path $Activitylog -Entry "Operating System : $ostype" -Type Information -ShowOnConsole
            if($OsType)
            {
                $StartDate = (get-date).AddDays(-1).ToString("yy/MM/dd")
                $EndDate = (get-date).ToString("yy/MM/dd")
                $failedBackupCommand  = $config.FailedBackupCount -replace "StartDate",$StartDate
                $failedBackupCommand  = $failedBackupCommand -replace "EndDate",$EndDate

                if($OsType -eq "Windows")
                {
                    #call Invoke-Command
                    $Dp_Service_Output = Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $config.ServiceHealthCheckCommand       -logFile $Activitylog
                    $Backup_Output     = Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $config.QueuingBackupHealthCheckCommand -logFile $Activitylog

                    if($Backup_Output)
                    {
                        $Backup_Result = @(Get-BackupStatus -InputObject $Backup_Output)
                    }
                    else
                    {
                        $Backup_Result = $null
                    }
                    ### Hung Backup First Time #########
                    if($Backup_Result)
                    {
                        if(!("No currently running sessions." -in $Backup_Result))
                        {
                            $Hung_input1 = @()
                            $Hung_object = $Backup_Result | where-object{$_.'session Type' -eq "Backup"}
                            foreach($line in $Hung_object)
                            {
                                $session_id = $line.sessionid
                                $command = $config.HungBackupCountCommand -replace "SessionId",$session_id
                                $Hung_input1 += Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $command -logFile $Activitylog
                            }
                            $HUNG_Output1 = Get-HungObject -InputObject $Hung_input1
                            $FirstTime = Get-Date
                        }
                    }


                    $Disabled_TapeDrive_Output = Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $config.DisabledTapeDriveCountCommand -logFile $Activitylog
                    $Scratch_Media_output      = Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $config.ScratchMediaCountCommand      -logFile $Activitylog
                    $failedBackup_Output       = Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $failedBackupCommand                  -logFile $Activitylog

                    ####### IDB Backup Status ##########
                    if($failedBackup_Output)
                    {
                        if("No Sessions matching" -in $failedBackup_Output)
                        {
                            $IDB_Backup_Result =  "No Sessions matching"
                        }
                        else
                        {
                            $IDBBackUp = Get-FailedBackup -InputObject $failedBackup_Output | Where-Object{$_.specification -like "IDB *"} | select -Last 1
                            $IDB_Backup_Result = @()      
                            if($IDBBackUp.Status -eq "completed")
                            {
                                $IDBSessionId = $IDBBackUp.'Session Id'
                                $command_IDB = $config.IDBBackupCommand -replace "SessionId",$IDBSessionId 
                                $CommandOutput_IDB = Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $command_IDB -logFile $Activitylog
                                $IDB_Backup_Result = Get-IDBBackup -InputObject $CommandOutput_IDB -IDBBackUp $IDBBackUp
                                $IDBSuccess_Count = 1
                            }
                            else
                            {
                                $CommandOutput_IDB = $null
                                $IDB_Backup_Result = Get-IDBBackup -InputObject $CommandOutput_IDB -IDBBackUp $IDBBackUp
                                $IDBSuccess_Count = 0
                            }
                        }
                    }
                    else
                    {
                        $IDB_Backup_Result = $null
                    }


                    #####  Library Status  ######
                    if($LocalLines)
                    {
                        Foreach($line in $LocalLines)
                        {
                            $obj = New-Object psobject
                            $Lnput_Lib = $line -split ','
                            $library_name = $Lnput_Lib[1].trim()
                            $Command = $config.LibraryStatusLocalCommand -replace "TapeLibraryName",$library_name
                            $Output = Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $Command -logFile $Activitylog
                            if($output -like "*Completed*")
                            {
                                $obj | Add-Member NoteProperty "Library Name/IP" $library_name 
                                $obj | Add-Member NoteProperty "Status" 'Active' 
                                $Library_Status_output += $obj
                            }
                            else
                            {
                                $obj | Add-Member NoteProperty "Library Name/IP" $library_name 
                                $obj | Add-Member NoteProperty "Status" 'Not-Active' 
                                $Library_Status_output += $obj
                            }   
                        }
                    }
                    else
                    {
                        $Library_Status_output = $null
                    }

                    
                    #####  Disabled Backup Job Count  ######
                    $command_path = "REG QUERY hklm\software\hewlett-packard\OpenView\OmniBackII\Common\ /v DataDir|findstr DataDir"
                    $CommandOutput = Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $command_path -logFile $Activitylog
                    $InitialPath = "$CommandOutput" -split '\s+'
                    $BarschedulesPath = $InitialPath[3] +"Config\Server\"+"Barschedules"
                    $SchedulesPath = $InitialPath[3] +"Config\Server\"+"Schedules"

                    $command_files = "Get-ChildItem -Recurse '$BarschedulesPath','$SchedulesPath' -File"
                    $Files = Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $command_files -logFile $Activitylog
                    if($files)
                    {
                        $DisabledBackupJobResult = @()
                        foreach($file in $Files)
                        {
                            $filename = $file.FullName
                            $command_content = "Get-content $filename"
                            $content = Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $command_content -logFile $Activitylog
                            $firstline = $content | select -First 1
                            if($firstline -like "-disabled*")
                            {
                                $Basename = $file.BaseName
                                if(($basename -notlike "*adhoc*") -and ($basename -notlike "*test*"))
                                {
                                    $obj = New-Object psobject
                                    $obj | Add-Member NoteProperty "Specification" "$basename"
                                    $obj | Add-Member NoteProperty "Status" "Disable"
                                    $DisabledBackupJobResult += $obj
                                }
        
                            }
        
                        }
                    }
                    else
                    {
                        $DisabledBackupJobResult = $null
                    }
                    
                    
                    ####   Free Disk Space  ####
                    $DiskspaceCommand = "Get-WmiObject win32_logicaldisk"
                    $FreeDiskSpaceOutput = Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $DiskspaceCommand -logFile $Activitylog
                    if($FreeDiskSpaceOutput)
                    {
                        $FreeDiskSpace_signal,$FreeDiskSpace_Result = Get-FreeDiskSpaceWindows -InputObject $FreeDiskSpaceOutput
                    }
                    else
                    {
                        $FreeDiskSpace_signal,$FreeDiskSpace_Result = Get-FreeDiskSpaceError -ErrorMessage "Failed to run Command"
                    }



                    ##### Hung Backup 2nd Time   #####
                    if($Backup_Result)
                    {
                        if("No currently running sessions." -in $Backup_Result)
                        {
                            $HUNG_Output = "No currently running sessions."
                        }
                        else
                        {
                            $SecondTime = Get-Date
                            $Timespan = (New-TimeSpan -Start $FirstTime -End $SecondTime).TotalMinutes
                            if($Timespan -gt 5)
                            {
                    
                                $Hung_input2 = @()
                                foreach($line in $Hung_object)
                                {
                                    $session_id = $line.sessionid
                                    $command = $config.HungBackupCountCommand -replace "SessionId",$session_id
                                    $Hung_input2 += Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $command -logFile $Activitylog
                                }
                                $HUNG_Output2 = Get-HungObject -InputObject $Hung_input2
                                $HUNG_Output = @()
                                for($i = 0; $i -lt $HUNG_Output2.count ;$i++)
                                {
                                    $before = $HUNG_Output1[$i].'Session data size [kB]' -split '\s'
                                    $after = $HUNG_Output2[$i].'Session data size [kB]' -split '\s'
                                    if($before[0] -eq $after[0])
                                    {
                                        $HUNG_Output += $HUNG_Output1[$i]
                                    }
                                }
                            }
                            else
                            {
                                $WaitTime = 300-($Timespan*60)
                                Start-Sleep -Seconds $WaitTime
                                ##### Hung Backup 2nd Time   #####
                                $Hung_input2 = @()
                                foreach($line in $Hung_object)
                                {
                                    $session_id = $line.sessionid
                                    $command = $config.HungBackupCountCommand -replace "SessionId",$session_id
                                    $Hung_input2 += Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $command -logFile $Activitylog
                                }
                                $HUNG_Output2 = Get-HungObject -InputObject $Hung_input2
                                $HUNG_Output = @()
                                for($i = 0; $i -lt $HUNG_Output2.count ;$i++)
                                {
                                    $before = $HUNG_Output1[$i].'Session data size [kB]' -split '\s'
                                    $after = $HUNG_Output2[$i].'Session data size [kB]' -split '\s'
                                    if($before[0] -eq $after[0])
                                    {
                                        $HUNG_Output += $HUNG_Output1[$i]
                                    }
                                }
                            }
                        }
                    }
                    else
                    {
                        $HUNG_Output = $null
                    }
                }
                
                else
                {
                    if($config.UsePlink -eq "yes")
                    {
                        $Dp_Service_Output = Invoke-PlinkCommand -PlinkPath $config.plinkpath -IpAddress $BackupDevice -Credential $Credential -logFile $Activitylog -command $config.ServiceHealthCheckCommand 
                        $Backup_Output = Invoke-PlinkCommand -PlinkPath $config.plinkpath -IpAddress $BackupDevice -Credential $Credential -logFile $Activitylog -command $config.QueuingBackupHealthCheckCommand

                        if($Backup_Output)
                        {
                            $Backup_Result = @(Get-BackupStatus -InputObject $Backup_Output)
                        }
                        else
                        {
                            $Backup_Result = $null
                        }
                        ### Hung Backup First Time #########
                        if($Backup_Result)
                        {
                            if(!("No currently running sessions." -in $Backup_Result))
                            {
                                $Hung_input1 = @()
                                $Hung_object = $Backup_Result | where-object{$_.'session Type' -eq "Backup"}
                                foreach($line in $Hung_object)
                                {
                                    $session_id = $line.sessionid
                                    $command = $config.HungBackupCountCommand -replace "SessionId",$session_id
                                    $Hung_input1 += Invoke-PlinkCommand -PlinkPath $config.plinkpath -IpAddress $BackupDevice -Credential $Credential -logFile $Activitylog -command $command
                                }
                                $HUNG_Output1 = Get-HungObject -InputObject $Hung_input1
                                $FirstTime = Get-Date
                            }
                        }


                        $Disabled_TapeDrive_Output = Invoke-PlinkCommand -PlinkPath $config.plinkpath -IpAddress $BackupDevice -Credential $Credential -logFile $Activitylog -command $config.DisabledTapeDriveCountCommand
                        $Scratch_Media_output = Invoke-PlinkCommand -PlinkPath $config.plinkpath -IpAddress $BackupDevice -Credential $Credential -logFile $Activitylog -command $config.ScratchMediaCountCommand
                        $failedBackup_Output = Invoke-PlinkCommand -PlinkPath $config.plinkpath -IpAddress $BackupDevice -Credential $Credential -logFile $Activitylog -command $FailedBackupCommand

                        ####### IDB Backup Status ##########
                        if($failedBackup_Output)
                        {
                            if("No Sessions matching" -in $failedBackup_Output)
                            {
                                $IDB_Backup_Result =  "No Sessions matching"
                            }
                            else
                            {
                                $IDBBackUp = Get-FailedBackup -InputObject $failedBackup_Output | Where-Object{$_.specification -like "IDB *"} | select -Last 1
                                $IDB_Backup_Result = @()      
                                if($IDBBackUp.Status -eq "completed")
                                {
                                    $IDBSessionId = $IDBBackUp.'Session Id'
                                    $command_IDB = $config.IDBBackupCommand -replace "SessionId",$IDBSessionId 
                                    $CommandOutput_IDB = Invoke-PlinkCommand -PlinkPath $config.plinkpath -IpAddress $BackupDevice -Credential $Credential -logFile $Activitylog -command $command_IDB
                                    $IDB_Backup_Result = Get-IDBBackup -InputObject $CommandOutput_IDB -IDBBackUp $IDBBackUp
                                    $IDBSuccess_Count = 1
                                }
                                else
                                {
                                    $CommandOutput_IDB = $null
                                    $IDB_Backup_Result = Get-IDBBackup -InputObject $CommandOutput_IDB -IDBBackUp $IDBBackUp
                                    $IDBSuccess_Count = 0
                                }
                            }
                        }
                        else
                        {
                            $IDB_Backup_Result = $null
                        }


                        #####  Library Status  ######
                        if($LocalLines)
                        {
                            Foreach($line in $LocalLines)
                            {
                                $obj = New-Object psobject
                                $Lnput_Lib = $line -split ','
                                $library_name = $Lnput_Lib[1].trim()
                                $Command = $config.LibraryStatusLocalCommand -replace "TapeLibraryName",$library_name
                                $Output = Invoke-PlinkCommand -PlinkPath $config.plinkpath -IpAddress $BackupDevice -Credential $Credential -logFile $Activitylog -command $command
                                if($output -like "*Completed*")
                                {
                                    $obj | Add-Member NoteProperty "Library Name/IP" $library_name 
                                    $obj | Add-Member NoteProperty "Status" 'Active' 
                                    $Library_Status_output += $obj
                                }
                                else
                                {
                                    $obj | Add-Member NoteProperty "Library Name/IP" $library_name 
                                    $obj | Add-Member NoteProperty "Status" 'Not-Active' 
                                    $Library_Status_output += $obj
                                }
                            }
                        }
                        else
                        {
                            $Library_Status_output = $null
                        }

                        #### Disabled Backup Job Count #### 
                        $command_Barschedules = "find /etc/opt/omni/server/barschedules -type f"
                        $command_Schedules = "find /etc/opt/omni/server/schedules -type f"
                        $files = @()
                        $files += Invoke-PlinkCommand -PlinkPath $config.plinkpath -IpAddress $BackupDevice -Credential $Credential -logFile $Activitylog -command $command_Barschedules
                        $files += Invoke-PlinkCommand -PlinkPath $config.plinkpath -IpAddress $BackupDevice -Credential $Credential -logFile $Activitylog -command $command_Schedules
                        if($Files)
                        {
                            $DisabledBackupJobResult = @()
                            Foreach($file in $files)
                            {
                                $command_cat = "cat '$file'"
                                $content = Invoke-PlinkCommand -PlinkPath $config.plinkpath -IpAddress $BackupDevice -Credential $Credential -logFile $Activitylog -command $command_cat
                                $firstline = $content | select -First 1
                                if($firstline -like "-disabled*")
                                {
                                    $split = $file.Split("/")
                                    $basename = $split.GetValue(($split.Count - 1))
                                    if(($basename -notlike "*adhoc*") -and ($basename -notlike "*test*"))
                                    {
                                        $obj = New-Object psobject
                                        $obj | Add-Member NoteProperty "Specification" "$basename"
                                        $obj | Add-Member NoteProperty "Status" "Disable"
                                        $DisabledBackupJobResult += $obj
                                    }
        
                                }
    
                            }
                        }
                        else
                        {
                            $DisabledBackupJobResult = $null
                        }


                        ####  Hung Backup 2nd Time  ####
                        if($Backup_Result)
                        {
                            if("No currently running sessions." -in $Backup_Result)
                            {
                                $HUNG_Output = "No currently running sessions."
                            }
                            else
                            {
                                $SecondTime = Get-Date
                                $Timespan = (New-TimeSpan -Start $FirstTime -End $SecondTime).TotalMinutes
                                if($Timespan -gt 5)
                                {
                    
                                    $Hung_input2 = @()
                                    foreach($line in $Hung_object)
                                    {
                                        $session_id = $line.sessionid
                                        $command = $config.HungBackupCountCommand -replace "SessionId",$session_id
                                        $Hung_input2 += Invoke-PlinkCommand -PlinkPath $config.plinkpath -IpAddress $BackupDevice -Credential $Credential -logFile $Activitylog -command $command
                                    }
                                    $HUNG_Output2 = Get-HungObject -InputObject $Hung_input2
                                    $HUNG_Output = @()
                                    for($i = 0; $i -lt $HUNG_Output2.count ;$i++)
                                    {
                                        $before = $HUNG_Output1[$i].'Session data size [kB]' -split '\s'
                                        $after = $HUNG_Output2[$i].'Session data size [kB]' -split '\s'
                                        if($before[0] -eq $after[0])
                                        {
                                            $HUNG_Output += $HUNG_Output1[$i]
                                        }
                                    }
                                }
                                else
                                {
                                    $WaitTime = 300-($Timespan*60)
                                    Start-Sleep -Seconds $WaitTime
                                    ##### Hung Backup 2nd Time   #####
                                    $Hung_input2 = @()
                                    foreach($line in $Hung_object)
                                    {
                                        $session_id = $line.sessionid
                                        $command = $config.HungBackupCountCommand -replace "SessionId",$session_id
                                        $Hung_input2 += Invoke-PlinkCommand -PlinkPath $config.plinkpath -IpAddress $BackupDevice -Credential $Credential -logFile $Activitylog -command $command
                                    }
                                    $HUNG_Output2 = Get-HungObject -InputObject $Hung_input2
                                    $HUNG_Output = @()
                                    for($i = 0; $i -lt $HUNG_Output2.count ;$i++)
                                    {
                                        $before = $HUNG_Output1[$i].'Session data size [kB]' -split '\s'
                                        $after = $HUNG_Output2[$i].'Session data size [kB]' -split '\s'
                                        if($before[0] -eq $after[0])
                                        {
                                            $HUNG_Output += $HUNG_Output1[$i]
                                        }
                                    }
                                }
                            }
                        }
                        else
                        {
                            $HUNG_Output = $null
                        }

                        ####  Free Disk Space   ####
                    
                        $command_uname = "uname -a"
                        $uname = Invoke-PlinkCommand -PlinkPath $config.plinkpath -IpAddress $BackupDevice -Credential $Credential -logFile $Activitylog -command $command_uname
                        if($uname -like "HP-UX*")
                        {
                            $DiskspaceCommand = "bdf"
                            $FreeDiskSpaceOutput = Invoke-PlinkCommand -PlinkPath $config.plinkpath -IpAddress $BackupDevice -Credential $Credential -logFile $Activitylog -command $DiskspaceCommand
                            if($FreeDiskSpaceOutput)
                            {
                                $FreeDiskSpace_signal,$FreeDiskSpace_Result = Get-FreeDiskSpaceHPUX -InputObject $FreeDiskSpaceOutput
                            }
                            else
                            {
                                $FreeDiskSpace_signal,$FreeDiskSpace_Result = Get-FreeDiskSpaceError -ErrorMessage "Failed to Run Command"
                            }

                        }
                        else
                        {
                            $DiskspaceCommand = "df -h"
                            $FreeDiskSpaceOutput = Invoke-PlinkCommand -PlinkPath $config.plinkpath -IpAddress $BackupDevice -Credential $Credential -logFile $Activitylog -command $DiskspaceCommand
                            if($FreeDiskSpaceOutput)
                            {
                                $FreeDiskSpace_signal,$FreeDiskSpace_Result = Get-FreeDiskSpaceUnix -InputObject $FreeDiskSpaceOutput
                            }
                            else
                            {
                                $FreeDiskSpace_signal,$FreeDiskSpace_Result = Get-FreeDiskSpaceError -ErrorMessage "Failed to Run Command"
                            }

                        }
                    }
                    else
                    {
                        Import-Module ".\Posh-SSH\Posh-SSH.psm1"
                        $sshsessionId = New-PoshSession -IpAddress $BackupDevice -Credential  $Credential
                        $Dp_Service_Output = Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command $config.ServiceHealthCheckCommand 
                        $Backup_Output = Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command $config.QueuingBackupHealthCheckCommand

                        if($Backup_Output)
                        {
                            $Backup_Result = @(Get-BackupStatus -InputObject $Backup_Output)
                        }
                        else
                        {
                            $Backup_Result = $null
                        }
                        ### Hung Backup First Time #########
                        if($Backup_Result)
                        {
                            if(!("No currently running sessions." -in $Backup_Result))
                            {
                                $Hung_input1 = @()
                                $Hung_object = $Backup_Result | where-object{$_.'session Type' -eq "Backup"}
                                foreach($line in $Hung_object)
                                {
                                    $session_id = $line.sessionid
                                    $command = $config.HungBackupCountCommand -replace "SessionId",$session_id
                                    $Hung_input1 += Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command $command
                                }
                                $HUNG_Output1 = Get-HungObject -InputObject $Hung_input1
                                $FirstTime = Get-Date
                            }
                        }


                        $Disabled_TapeDrive_Output = Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command $config.DisabledTapeDriveCountCommand
                        $Scratch_Media_output = Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command $config.ScratchMediaCountCommand
                        $failedBackup_Output = Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command $FailedBackupCommand

                        ####### IDB Backup Status ##########
                        if($failedBackup_Output)
                        {
                            if("No Sessions matching" -in $failedBackup_Output)
                            {
                                $IDB_Backup_Result =  "No Sessions matching"
                            }
                            else
                            {
                                $IDBBackUp = Get-FailedBackup -InputObject $failedBackup_Output | Where-Object{$_.specification -like "IDB *"} | select -Last 1
                                $IDB_Backup_Result = @()      
                                if($IDBBackUp.Status -eq "completed")
                                {
                                    $IDBSessionId = $IDBBackUp.'Session Id'
                                    $command_IDB = $config.IDBBackupCommand -replace "SessionId",$IDBSessionId 
                                    $CommandOutput_IDB = Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command $command_IDB
                                    $IDB_Backup_Result = Get-IDBBackup -InputObject $CommandOutput_IDB -IDBBackUp $IDBBackUp
                                    $IDBSuccess_Count = 1
                                }
                                else
                                {
                                    $CommandOutput_IDB = $null
                                    $IDB_Backup_Result = Get-IDBBackup -InputObject $CommandOutput_IDB -IDBBackUp $IDBBackUp
                                    $IDBSuccess_Count = 0
                                }
                            }
                        }
                        else
                        {
                            $IDB_Backup_Result = $null
                        }


                        #####  Library Status  ######
                        if($LocalLines)
                        {
                            Foreach($line in $LocalLines)
                            {
                                $obj = New-Object psobject
                                $Lnput_Lib = $line -split ','
                                $library_name = $Lnput_Lib[1].trim()
                                $Command = $config.LibraryStatusLocalCommand -replace "TapeLibraryName",$library_name
                                $Output = Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command $command
                                if($output -like "*Completed*")
                                {
                                    $obj | Add-Member NoteProperty "Library Name/IP" $library_name 
                                    $obj | Add-Member NoteProperty "Status" 'Active' 
                                    $Library_Status_output += $obj
                                }
                                else
                                {
                                    $obj | Add-Member NoteProperty "Library Name/IP" $library_name 
                                    $obj | Add-Member NoteProperty "Status" 'Not-Active' 
                                    $Library_Status_output += $obj
                                }
                            }
                        }
                        else
                        {
                            $Library_Status_output = $null
                        }

                        #### Disabled Backup Job Count #### 
                        $command_Barschedules = "find /etc/opt/omni/server/barschedules -type f"
                        $command_Schedules = "find /etc/opt/omni/server/schedules -type f"
                        $files = @()
                        $files += Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command $command_Barschedules
                        $files += Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command $command_Schedules
                        if($Files)
                        {
                            $DisabledBackupJobResult = @()
                            Foreach($file in $files)
                            {
                                $command_cat = "cat '$file'"
                                $content = Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command $command_cat
                                $firstline = $content | select -First 1
                                if($firstline -like "-disabled*")
                                {
                                    $split = $file.Split("/")
                                    $basename = $split.GetValue(($split.Count - 1))
                                    if(($basename -notlike "*adhoc*") -and ($basename -notlike "*test*"))
                                    {
                                        $obj = New-Object psobject
                                        $obj | Add-Member NoteProperty "Specification" "$basename"
                                        $obj | Add-Member NoteProperty "Status" "Disable"
                                        $DisabledBackupJobResult += $obj
                                    }
        
                                }
    
                            }
                        }
                        else
                        {
                            $DisabledBackupJobResult = $null
                        }


                        ####  Hung Backup 2nd Time  ####
                        if($Backup_Result)
                        {
                            if("No currently running sessions." -in $Backup_Result)
                            {
                                $HUNG_Output = "No currently running sessions."
                            }
                            else
                            {
                                $SecondTime = Get-Date
                                $Timespan = (New-TimeSpan -Start $FirstTime -End $SecondTime).TotalMinutes
                                if($Timespan -gt 5)
                                {
                    
                                    $Hung_input2 = @()
                                    foreach($line in $Hung_object)
                                    {
                                        $session_id = $line.sessionid
                                        $command = $config.HungBackupCountCommand -replace "SessionId",$session_id
                                        $Hung_input2 += Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command $command
                                    }
                                    $HUNG_Output2 = Get-HungObject -InputObject $Hung_input2
                                    $HUNG_Output = @()
                                    for($i = 0; $i -lt $HUNG_Output2.count ;$i++)
                                    {
                                        $before = $HUNG_Output1[$i].'Session data size [kB]' -split '\s'
                                        $after = $HUNG_Output2[$i].'Session data size [kB]' -split '\s'
                                        if($before[0] -eq $after[0])
                                        {
                                            $HUNG_Output += $HUNG_Output1[$i]
                                        }
                                    }
                                }
                                else
                                {
                                    $WaitTime = 300-($Timespan*60)
                                    Start-Sleep -Seconds $WaitTime
                                    ##### Hung Backup 2nd Time   #####
                                    $Hung_input2 = @()
                                    foreach($line in $Hung_object)
                                    {
                                        $session_id = $line.sessionid
                                        $command = $config.HungBackupCountCommand -replace "SessionId",$session_id
                                        $Hung_input2 += Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command $command
                                    }
                                    $HUNG_Output2 = Get-HungObject -InputObject $Hung_input2
                                    $HUNG_Output = @()
                                    for($i = 0; $i -lt $HUNG_Output2.count ;$i++)
                                    {
                                        $before = $HUNG_Output1[$i].'Session data size [kB]' -split '\s'
                                        $after = $HUNG_Output2[$i].'Session data size [kB]' -split '\s'
                                        if($before[0] -eq $after[0])
                                        {
                                            $HUNG_Output += $HUNG_Output1[$i]
                                        }
                                    }
                                }
                            }
                        }
                        else
                        {
                            $HUNG_Output = $null
                        }

                        ####  Free Disk Space   ####
                    
                        $command_uname = "uname -a"
                        $uname = Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command $command_uname
                        if($uname -like "HP-UX*")
                        {
                            $DiskspaceCommand = "bdf"
                            $FreeDiskSpaceOutput = Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command $DiskspaceCommand
                            if($FreeDiskSpaceOutput)
                            {
                                $FreeDiskSpace_signal,$FreeDiskSpace_Result = Get-FreeDiskSpaceHPUX -InputObject $FreeDiskSpaceOutput
                            }
                            else
                            {
                                $FreeDiskSpace_signal,$FreeDiskSpace_Result = Get-FreeDiskSpaceError -ErrorMessage "Failed to run command"
                            }
                        }
                        else
                        {
                            $DiskspaceCommand = "df -h"
                            $FreeDiskSpaceOutput = Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command $DiskspaceCommand
                            if($FreeDiskSpaceOutput)
                            {
                                $FreeDiskSpace_signal,$FreeDiskSpace_Result = Get-FreeDiskSpaceUnix -InputObject $FreeDiskSpaceOutput
                            }
                            else
                            {
                                $FreeDiskSpace_signal,$FreeDiskSpace_Result = Get-FreeDiskSpaceError -ErrorMessage "Failed to run command"
                            }
                        }
                    }

                }
                    
                    ############   Calling the Functions   #################
                    if($Dp_Service_Output)
                    {
                        $Dpservice_signal,$Dp_Service_Result = Get-DpService -InputObject $Dp_Service_Output
                    }
                    else
                    {
                        $Dpservice_signal,$Dp_Service_Result = Get-DpServiceError -ErrorMessage "Failed To Run Command"
                    }
                    $SignalReport += $Dpservice_signal

                    if($Backup_Result)
                    {
                        $Queuing_gt30_signal,$Queuing_30_Result   = Get-QueuedBackupGreaterThanThirtyMinute -InputObject $Backup_Result
                        $Queuing_lt24_signal,$Queuing_lt24_Result = Get-QueuedBackupLessThanTwentyFourHour -InputObject $Backup_Result
                        $Queuing_gt24_signal,$Queuing_gt24_Result = Get-QueuedBackupGreaterThanTwentyFourHour -InputObject $Backup_Result
                        $Mount_req_signal,$Mount_Request_Result   = Get-Mount_Request -InputObject $Backup_Result
                    }
                    else
                    {
                        $Queuing_gt30_signal,$Queuing_30_Result   = Get-BackupSessionError -ErrorMessage "Failed To Run Command" -HCParameter "Queuing Backup Count(>30 min)" -HCShortName "WQB"
                        $Queuing_lt24_signal,$Queuing_lt24_Result = Get-BackupSessionError -ErrorMessage "Failed To Run Command" -HCParameter "Long Running Backup Count(>12 Hr and <24 Hr)" -HCShortName "LB_12"
                        $Queuing_gt24_signal,$Queuing_gt24_Result = Get-BackupSessionError -ErrorMessage "Failed To Run Command" -HCParameter "Long Running Backup Count(>24 Hr)" -HCShortName "LB_24"
                        $Mount_req_signal,$Mount_Request_Result   = Get-BackupSessionError -ErrorMessage "Failed To Run Command" -HCParameter "Mount Request" -HCShortName "MR"
                    }
                    $SignalReport += $Queuing_gt30_signal
                    $SignalReport += $Queuing_lt24_signal
                    $SignalReport += $Queuing_gt24_signal
                    $SignalReport += $Mount_req_signal

                    if($Disabled_TapeDrive_Output)
                    {
                        $Disabled_TapeDrive_signal,$Disabled_TapeDrive_Result = Get-Disabled_TapeDrive_count -InputObject $Disabled_TapeDrive_Output
                    }
                    else
                    {
                        $Disabled_TapeDrive_signal,$Disabled_TapeDrive_Result = Get-DisabledTapeDriveError -ErrorMessage "Failed To Run Command"
                    }
                    $SignalReport += $Disabled_TapeDrive_signal

                    if($Scratch_Media_Output)
                    {
                        $Scratch_Media_signal,$Scratch_Media_Result = Get-Scratch_Media_Count -InputObject $Scratch_Media_Output
                    }
                    else
                    {
                        $Scratch_Media_signal,$Scratch_Media_Result = Get-ScratchMediaError -ErrorMessage "Failed To Run Command"
                    }
                    $SignalReport += $Scratch_Media_signal

                    if($failedBackup_Output)
                    {
                        $FailedBackupCommand_Result = Get-FailedBackup -InputObject $failedBackup_Output
                        $Failed_bck_signal,$Failed_Bck_result = Get-FailedBackupCount -InputObject $FailedBackupCommand_Result
                        $Critical_Backup_signal,$Critical_Bck_result = Get-CriticalBackupStatus -InputObject $FailedBackupCommand_Result -CriticalBackupServersInputFile $config.CriticalBackupServersInputFile
                    }
                    else
                    {
                        $Failed_bck_signal,$Failed_Bck_result        = Get-FailedBackupError -ErrorMessage "Failed To Run Command" -HCParameter "Failed Backup Count"    -HCShortName "FB"
                        $Critical_Backup_signal,$Critical_Bck_result = Get-FailedBackupError -ErrorMessage "Failed To Run Command" -HCParameter "Critical Backup Status" -HCShortName "CB"
                    }
                    $SignalReport += $Failed_bck_signal
                    $SignalReport += $Critical_Backup_signal

                    ####### IDB Backup ######
                    if($IDB_Backup_Result -eq $null)
                    {
                        $IDBBackup_Signal,$IDB_Backup_Result = Get-IDBError -ErrorMessage "Failed To Run Command"
                    }
                    else
                    {
                        if("No Sessions matching" -in $IDB_Backup_Result)
                        {
                        $IDBBackup_Signal,$IDB_Backup_Result = Get-IDBError -ErrorMessage "No Sessions Matching"
                        }
                        else
                        {
                            $TotalIDB_Count = 1
                            $percent = [math]::round(($IDBSuccess_Count/$TotalIDB_Count)*100,2)
                            If($IDBBackUp.Status -eq "completed")
                            {
                                $signal = "G"
                            }
                            Elseif($IDBBackUp.Status -eq "In Progress")
                            {
                                $signal = "Y"
                            }
                            Else
                            {
                                $signal = "R"
                            }
                            $IDBBackup_Signal = [PSCUSTOMObject] @{
                            "Technology" = $config.Technology
                            "ReportType" = $config.ReportType
                            "BackupApplication" = $config.BackupApplication
                            "Account" = $config.Account
                            "BackupServer" = $Backupdevice
                            "ReportDate" = $Reportdate          
                            'HC_Parameter'= "IDB Backup Status"
                            "HC_ShortName" = "IDB"
                            "Value"= "$IDBSuccess_Count/$TotalIDB_Count"
                            'Percentage' = "$percent%"
                            'Status' = $Signal
                        }
                        }
                    }
                    $SignalReport += $IDBBackup_Signal

                    
                    ####### Library Status ######
                    if($sshLines)
                    {
                        $Library_Status_output += get-RemoteLibraryStatus -InputObject $sshLines
                    }
                    if(!($Library_Status_output))
                    {
                        $Library_Status_signal,$LibraryStatus_Result = Get-LibraryError -ErrorMessage "Invalid Librarydetails.txt"
                    }
                    else
                    {
                        $Total_library_count = @($Library_Status_output).count
                        $Active_library_count = @(($Library_Status_output |?{$_.status -eq "Active"})).count
                        $percent = [math]::Round(($Active_library_count/$Total_library_count)*100,2)
                        If($percent -eq 100)
                        {
                            $signal = "G"
                        }
                        else
                        {
                            $signal = "R"
                        }
                        $LibraryStatus_Result = @()
                        foreach($line in $Library_Status_output)
                        {
                            $LibraryStatus_Result += [PSCUSTOMObject] @{
                            "Technology" = $config.Technology
                            "ReportType" = $config.ReportType
                            "BackupApplication" = $config.BackupApplication
                            "Account" = $config.Account
                            "BackupServer" = $Backupdevice
                            "ReportDate" = $Reportdate
                            "HC_Parameter" = "Library Status"
                            "Library Name/IP" = $line.'Library Name/IP'
                            "Status" = $line.'Status'
                            }
                        }
                        $Library_Status_signal = [PSCUSTOMObject] @{
                        "Technology" = $config.Technology
                        "ReportType" = $config.ReportType
                        "BackupApplication" = $config.BackupApplication
                        "Account" = $config.Account
                        "BackupServer" = $Backupdevice
                        "ReportDate" = $Reportdate          
                        'HC_Parameter'= "Library Status"
                        "HC_ShortName" = "LS"
                        "Value"= "$Active_library_count/$Total_library_count"
                        'Percentage' = "$percent%"
                        'Status' = $Signal
                        }
                    }
                    $SignalReport += $Library_Status_signal

                    ####### Hung Backup ######
                    if($HUNG_Output -eq $null)
                    {
                        $Hung_Bck_signal,$HungBackup_Result = Get-BackupSessionError -ErrorMessage "Failed To Run Command" -HCParameter "Hung Backup Count" -HCShortName "HB"
                    }
                    else
                    {
                        if("No currently running sessions." -in "HUNG_Output")
                        {
                            $Hung_Bck_signal,$HungBackup_Result = Get-BackupSessionError -ErrorMessage "No Sessions" -HCParameter "Hung Backup Count" -HCShortName "HB"
                        }
                        else
                        {
                            $Total_Bck_count_hung = $Backup_Result.count
                            $HUNG_Bck_count = $HUNG_Output.Count
                            $percent = [math]::Round(($HUNG_Bck_count/$Total_Bck_count_hung)*100,2)
                            If($percent -eq  0)
                            {
                                $signal = "G"
                            }
                            else
                            {
                                $signal = "R"
                            }
                            $Hung_Result = $HUNG_Output | select sessionid,'Backup Specification'
                            $HungBackup_Result = @()
                            if($Hung_Result)
                            {
                                foreach($line in $Hung_Result)
                                {
                                    $HungBackup_Result += [PSCUSTOMObject] @{
                                    "Technology" = $config.Technology
                                    "ReportType" = $config.ReportType
                                    "BackupApplication" = $config.BackupApplication
                                    "Account" = $config.Account
                                    "BackupServer" = $Backupdevice
                                    "ReportDate" = $Reportdate 
                                    "HC_Parameter" = "Hung Backup Count"
                                    "SessionID" = $line.'SessionID'
                                    "Backup Specification" = $line.'Backup Specification'
                                    "Session data size [kB]" = $line.'Session data size [kB]'
                                    }
                                }
                            }
                            else
                            {
                                $HungBackup_Result       = [PSCUSTOMObject] @{
                                "Technology"             = $config.Technology
                                "ReportType"             = $config.ReportType
                                "BackupApplication"      = $config.BackupApplication
                                "Account"                = $config.Account
                                "BackupServer"           = $Backupdevice
                                "ReportDate"             = $Reportdate 
                                "HC_Parameter"           = "Hung Backup Count"
                                "SessionID"              = "No Hung Sessions"
                                "Backup Specification"   = "No Hung Sessions"
                                "Session data size [kB]" = "No Hung Sessions"
                                }
                            }
                            $Hung_Bck_signal = [PSCUSTOMObject] @{
                            "Technology" = $config.Technology
                            "ReportType" = $config.ReportType
                            "BackupApplication" = $config.BackupApplication
                            "Account" = $config.Account
                            "BackupServer" = $Backupdevice
                            "ReportDate" = $Reportdate          
                            'HC_Parameter'= "Hung Backup Count"
                            "HC_ShortName" = "HB"
                            "Value"= "$HUNG_Bck_count/$Total_Bck_count"
                            'Percentage' = "$percent%"
                            'Status' = $Signal
                            }
                        }
                    }
                    $SignalReport += $Hung_Bck_signal

                    ######  Disabled BackupJob Count ######
                    if($DisabledBackupJobResult -eq $null)
                    {
                        $DisabledBackupJob_Signal,$DisabledBackupJob_Result = Get-DisabledJobError -ErrorMessage "No Disabled Jobs"
                    }
                    else
                    {
                        $TotalBackupCount_Disabled  = $files.Count
                        $DisabledBackup_Count = $DisabledBackupJobResult.Count
                        $Percent = [math]::Round(($DisabledBackup_Count/$TotalBackupCount_Disabled)*100,2)
                        if($Percent -eq 0)
                        {
                            $signal = "G"
                        }
                        elseif($Percent -gt 0 -and $Percent -le 5)
                        {
                            $signal = "Y"
                        }
                        else
                        {
                            $signal = "R"
                        }
                        $DisabledBackupJob_Result = @()
                        foreach($line in $DisabledBackupJobResult)
                        {
                            $DisabledBackupJob_Result += [PSCUSTOMObject] @{
                            "Technology" = $config.Technology
                            "ReportType" = $config.ReportType
                            "BackupApplication" = $config.BackupApplication
                            "Account" = $config.Account
                            "BackupServer" = $Backupdevice
                            "ReportDate" = $Reportdate
                            "HC_Parameter" = "Disabled Backup Job Count"
                            "Specification" = $line.'Specification'
                            "Status" = $line.'Status'
                            }
                        }
                        $DisabledBackupJob_Signal = [PSCUSTOMObject] @{
                        "Technology" = $config.Technology
                        "ReportType" = $config.ReportType
                        "BackupApplication" = $config.BackupApplication
                        "Account" = $config.Account
                        "BackupServer" = $Backupdevice
                        "ReportDate" = $Reportdate          
                        'HC_Parameter'= "Disabled Backup Job Count"
                        "HC_ShortName" = "DB"
                        "Value"= "$DisabledBackup_Count/$TotalBackupCount_Disabled"
                        'Percentage' = "$percent%"
                        'Status' = $Signal
                        }
                    }
                    $SignalReport += $DisabledBackupJob_Signal

                    
                    $SignalReport += $FreeDiskSpace_signal


                    $SignalReportName             = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "Signal" + "_" + $date + ".csv"
                                                                                                                                                                                         
                    $DpService_ReportName         = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "SS"     + "_" + $date + ".csv"
                    $Queuing30_ReportName         = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "WQB"    + "_" + $date + ".csv"
                    $Queuing_lt24_ReportName      = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "LB_12"  + "_" + $date + ".csv"
                    $Queuing_gt24_ReportName      = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "LB_24"  + "_" + $date + ".csv"
                    $MountRequest_ReportName      = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "MR"     + "_" + $date + ".csv"
                    $DisabledTapeDrive_ReportName = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "DTD"    + "_" + $date + ".csv"
                    $ScratchMedia_ReportName      = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "SM"     + "_" + $date + ".csv"
                    $FailedBackup_ReportName      = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "FB"     + "_" + $date + ".csv"
                    $IDBBackup_ReportName         = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "IDB"    + "_" + $date + ".csv"
                    $CriticalBackup_ReportName    = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "CB"     + "_" + $date + ".csv"
                    $LibraryStatus_ReportName     = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "LS"     + "_" + $date + ".csv"
                    $HungBackup_ReportName        = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "HB"     + "_" + $date + ".csv"
                    $DisabledBackupJob_ReportName = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "DB"     + "_" + $date + ".csv"
                    $FreeDiskSpace_ReportName     = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "FDS"    + "_" + $date+ ".csv"


                    $SignalReport             | Export-Csv -Path $SignalReportName             -NoTypeInformation
                    $Dp_Service_Result        | Export-Csv -Path $DpService_ReportName         -NoTypeInformation
                    $Queuing_30_Result        | Export-Csv -Path $Queuing30_ReportName         -NoTypeInformation
                    $Queuing_lt24_Result      | Export-Csv -Path $Queuing_lt24_ReportName      -NoTypeInformation
                    $Queuing_gt24_Result      | Export-Csv -Path $Queuing_gt24_ReportName      -NoTypeInformation
                    $Mount_Request_Result     | Export-Csv -Path $MountRequest_ReportName      -NoTypeInformation
                    $Disabled_TapeDrive_Result| Export-Csv -Path $DisabledTapeDrive_ReportName -NoTypeInformation
                    $Scratch_Media_Result     | Export-Csv -Path $ScratchMedia_ReportName      -NoTypeInformation
                    $Failed_Bck_result        | Export-Csv -Path $FailedBackup_ReportName      -NoTypeInformation
                    $IDB_Backup_Result        | Export-Csv -Path $IDBBackup_ReportName         -NoTypeInformation
                    $Critical_Bck_result      | Export-Csv -Path $CriticalBackup_ReportName    -NoTypeInformation
                    $LibraryStatus_Result     | Export-Csv -Path $LibraryStatus_ReportName     -NoTypeInformation
                    $HungBackup_Result        | Export-Csv -Path $HungBackup_ReportName        -NoTypeInformation
                    $DisabledBackupJob_Result | Export-Csv -Path $DisabledBackupJob_ReportName -NoTypeInformation
                    $FreeDiskSpace_Result     | Export-Csv -Path $FreeDiskSpace_ReportName     -NoTypeInformation
            }

            else
            {
                Write-Log -Path $Activitylog -Entry "Operating System : Failed" -Type Error -ShowOnConsole
            }

        #}

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


