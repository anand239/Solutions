﻿<#
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
        [String]$command

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
        $ssh.WriteLine($command)
        Start-Sleep -Milliseconds 1000
        do
        {
            $result += $ssh.read()
            Start-Sleep -Milliseconds 500
        }
        While ($ssh.DataAvailable)

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
  
    $InputObject = $InputObject | Select-String -Pattern ": " | Select-String -Pattern "Status:" -NotMatch

    
    $Active = $InputObject | Select-String -Pattern "Active"
    $Total_count = ($InputObject).Count
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
    #[parameter(Mandatory = $true)]
    $InputObject 
    )
    $current = Get-Date
    ######omnistat -detail
    $Queuing_Object = @()
    $Queuing_Input = $InputObject | Where {$_}
    Write-Host ( "No currently running sessions." -in $Queuing_Input)
    if( "No currently running sessions." -in $Queuing_Input)
    {
        Write-Output $null
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
    $InputObject,
    $TotalBackup_Count
    )
    if ($InputObject -eq $null -and $TotalBackup_Count -gt 0)
    {
        #IF Zero Sessions then greeeeeeeeen
        $signal = "G"
        $Signal_Report = "Queuing Backup Count(>30 min), 0/$TotalBackup_Count,0%, $signal"
        $Signal_Report,$null
    }
    else
    {
        #checking elapsed Greaater than 30 Min
        $Result = $InputObject | Where-Object{$_.'Time Elapsed' -gt 30} | select sessionid,'Session type','Backup Specification'
        $Queuing_Bck_count = $Result.Count
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
        $Signal_Report = "Queuing Backup Count(>30 mins), $Queuing_Bck_count/$TotalBackup_Count, $percent%, $signal"
        $Signal_Report,$Result
    }
}

Function Get-QueuedBackupLessThanTwentyFourHour
{
    [CmdletBinding()]
    Param(
    #[parameter(Mandatory = $true)]
    $InputObject,
    $TotalBackup_Count
    )
    if ($InputObject -eq $null -and $TotalBackup_Count -gt 0)
    {
        #IF Zero Sessions then greeen
        $signal = "G"
        $Signal_Report = "Long Running Backup Count(>12 and < 24 Hrs), 0/$TotalBackup_Count,0%, $signal"
        $Signal_Report,$null
    }
    else
    {
        # ($time_30 -ge 12) -and ($time_30 -lt 24)) Checking elapsed btwe 12 and 24 hr
        $Result = $InputObject | Where-Object{$_.'Time Elapsed' -ge 720 -and $_.'Time Elapsed' -lt 1440} | select sessionid,'Session type','Backup Specification'

    
        $Queuing_Bck_count = $Result.Count
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
        $Signal_Report = "Long Running Backup Count(>12 and < 24 Hrs), $Queuing_Bck_count/$TotalBackup_Count, $percent%, $signal"
        $Signal_Report,$Result
    }
}

Function Get-QueuedBackupGreaterThanTwentyFourHour
{
    [CmdletBinding()]
    Param(
    #[parameter(Mandatory = $true)]
    $InputObject,
    $TotalBackup_Count
    )
    if ($InputObject -eq $null -and $TotalBackup_Count -gt 0)
    {
        #IF Zero Sessions then green
        $signal = "G"
        $Signal_Report = "Long Running Backup Count(>24 Hrs), 0/$TotalBackup_Count,0%, $signal"
        $Signal_Report,$null
    }
    else
    {
        #Checking elapsed Greater Than 24 hr
        $Result = $InputObject | Where-Object{$_.'Time Elapsed' -ge 1440} | select sessionid,'Session type','Backup Specification'
        $Queuing_Bck_count = $Result.Count
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
        $Signal_Report = "Long Running Backup Count(>24 Hrs), $Queuing_Bck_count/$TotalBackup_Count, $percent%, $signal"
        $Signal_Report,$Result
    }
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
    elseif(($percent -ge 1) -and ($percent -le 2))
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

Function Get-Disabled_TapeDrive_count
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
    #if($item -like "*NAME*" -and $item -like "*Library*" -and $item -like "*-disable*" )
    if($item -like "*NAME*" -and $item -like "*-disable*" )
    {
        $line = $item | Select-String -pattern "^Name","Library","-disable"
        #$line = $item | Select-String -pattern "^Name","-disable"
        $name = $line[0] -split "\s"
        $drive_name = $name[1] -split '"'
        #$status = $line[1] -split "-"
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
    $Disabled_TapeDrive_signal = "Disabled Tape Drive Count, $Disabled_Tape_count/$Total_Tape_count, $percent%, $signal"
    $Disabled_TapeDrive_Result = $Disabled_TapeDrive_Object | Convertfrom-Csv -Header 'Library','Drive Name','Status'
    $Disabled_TapeDrive_signal,$Disabled_TapeDrive_Result
}

Function Get-Scratch_Media_Count
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

Function Get-FailedBackup
{
    [CmdletBinding()]
    Param(
    #[parameter(Mandatory = $true)]
    $InputObject
    )
    #omnirpt -report list_sessions -timeframe $previous 18:00 $current 17:59 -tab -no_copylist -no_verificationlist -no_conslist

    $Failed_Bck_converted = $InputObject.replace("`t",",")| Convertfrom-Csv -Header 'Session Type','Specification','Status','Mode','Start Time','Start Time_t','End Time','End Time_t','Queuing', 'Duration','GB Written','Media','Errors','Warnings','Pending DA','Running DA','Failed DA','Completed DA','Object','Files','Success','Session Owner','Session ID'
    $FailedBackupCommand_Result = $Failed_Bck_converted| Select-Object 'Specification','Status','session id',mode
    $FailedBackupCommand_Result
}

Function Get-FailedBackupCount
{
    [CmdletBinding()]
    Param(
    #[parameter(Mandatory = $true)]
    $InputObject
    )
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

    $Failed_Backup_count = ($Failed_Bck_result | ? {$_.status -eq "Failed"}).count
    $Total_Backup_count = ($InputObject).Count


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
    $Failed_bck_signal = "Failed Backup Count, $Failed_Backup_count/$Total_Backup_count, $percent%, $signal"
    $Failed_bck_signal,$Failed_Bck_result
}

Function Get-CriticalBackupStatus
{
    [CmdletBinding()]
    Param(
    #[parameter(Mandatory = $true)]
    $InputObject,$CriticalBackupServersInputFile
    )
    $Critical_Bck_output = @()
    $CriticalBackupServers = get-content $CriticalBackupServersInputFile | select -Skip 1
    foreach ($CriticalBackupServer in $CriticalBackupServers)
    {
        $CriticalBackupServer = $CriticalBackupServer.Trim()
        $out = $InputObject |?{$_.specification -like "*$($CriticalBackupServer)"}| select specification,status,'session id',mode
        if($out -eq $null)
        {
            $Critical_Bck_output += New-Object -TypeName PSobject -Property @{
            Specification = "$critical_spec"
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
            if($i.Status -ne "Didnt Ran")
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
    $completed_Critical_count = ($Critical_Bck_result|?{$_.status -eq "completed"}).count
    $percent = [math]::Round(($completed_Critical_count/$Total_Critical_count)*100,2)
    If($percent -eq  100)
    {
        $signal = "G"
    }
    else
    {
        $signal = "R"
    }
    $Critical_Backup_signal = "Critical Backup Status, $completed_Critical_count/$Total_Critical_count, $percent%, $signal"
    $Critical_Backup_signal,$Critical_Bck_result
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
            $input = $line -split ','
            $ip = $input[1]
            $username = $input[2]
            $password = ConvertTo-SecureString $input[3] -AsPlainText -Force
            $Cred = New-Object System.Management.Automation.PSCredential -ArgumentList ($username, $password)
            $session = New-SSHSession -ComputerName "$ip" -Credential $Cred -AcceptKey:$true -ErrorAction Stop
            $output = $(Invoke-sshCommand -SessionId $Session -Command "hardware show status").output
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
    
    }
    $Library_Status_output
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
            $obj | Add-Member NoteProperty "Total Size(GB)" $Total_Size
            $obj | Add-Member NoteProperty "Free Space(GB)" $Free_Space
            $obj | Add-Member NoteProperty "Mount Point" $array[5]
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
    $FreeDiskSpace_signal = "Free Disk Space, $FreeDiskSpace/$TotalDiskSpace, $percent%, $signal"
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
            $Size_gb = $line.'Total Size' -split 'M'
            $TotalDiskSpace += [float]$Size_gb[0]/1024
        }
        if($line.'Free Space' -like "*G")
        {
            $Size_mb = $line.'Free Space' -split 'G'
            $FreeDiskSpace += [float]$Size_mb[0]
        }
        elseif($line.'Free Space' -like "*M")
        {
            $Size_mb = $line.'Free Space' -split 'M'
            $FreeDiskSpace += [float]$Size_mb[0]/1024
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
    $FreeDiskSpace_signal = "Free Disk Space, $FreeDiskSpace/$TotalDiskSpace, $percent%, $signal"
    $FreeDiskSpace_signal,$FreeDiskSpace_Result
}

Function Get-FreeDiskSpaceWindows
{
    [CmdletBinding()]
    Param(
    #[parameter(Mandatory = $true)]
    $InputObject
    )
    $FreeDiskSpace_Input = $InputObject 
    $FreeDiskSpace_Result = @()
    foreach($disk in $FreeDiskSpace_Input)
    {
        $drive = $disk.DeviceId
        $free = [math]::Round(($disk.'freespace' / 1gb),2)
        $TotalSize = [math]::Round(($disk.'size'/1gb),2)
        $obj = New-Object psObject
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
    $FreeDiskSpace_signal = "Free Disk Space, $FreeDiskSpace/$TotalDiskSpace, $percent%, $signal"
    $FreeDiskSpace_signal,$FreeDiskSpace_Result
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
                    $Dp_Service_Output = Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $config.ServiceHealthCheckCommand -logFile $Activitylog
                    $Backup_Output = Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $config.QueuingBackupHealthCheckCommand -logFile $Activitylog

                    $Backup_Result = @(Get-BackupStatus -InputObject $Backup_Output)
                    ### Hung Backup First Time #########
                    $Hung_input1 = @()
                    $Hung_object = $Backup_Result | ?{$_.'session Type' -eq "Backup"}
                    foreach($line in $Hung_object)
                    {
                    $session_id = $line.sessionid
                    $command = "omnidb -rpt $session_id -details"
                    $Hung_input1 += Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $command -logFile $Activitylog
                    }
                    $HUNG_Output1= @()
                    for($i=0;$i -le $Hung_input1.Count;$i+=13)
                    {
                          $obj = New-Object psObject
                          $arr =$Hung_input1[$i] -split ": " 
                          $obj | Add-Member NoteProperty "$($arr[0].trim())"  $arr[1].trim()
                          $arr =$Hung_input1[$i+1] -split ": "
                          $obj | Add-Member NoteProperty "$($arr[0].trim())"  $arr[1].trim()
                          $arr =$Hung_input1[$i+11] -split ": "
                          $obj | Add-Member NoteProperty "$($arr[0].trim())"  $arr[1].trim()
                          $HUNG_Output1 += $obj

                    }
                    $FirstTime = Get-Date



                    $Disabled_TapeDrive_Output = Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $config.DisabledTapeDriveCountCommand -logFile $Activitylog
                    $Scratch_Media_output = Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $config.ScratchMediaCountCommand -logFile $Activitylog
                    $failedBackup_Output = Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $failedBackupCommand -logFile $Activitylog

                    ####### IDB Backup Status ##########
                    $IDBBackUp = Get-FailedBackup -InputObject $failedBackup_Output | Where-Object{$_.specification -like "IDB *"} | select -Last 1
                    $IDB_Backup_Result = @()      
                    if($IDBBackUp.Status -eq "completed")
                    {
                        $command = "omnidb -session $($IDBBackUp.'Session Id') -media"
                        $CommandOutput = Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $command -logFile $Activitylog
                        $media = ($CommandOutput | select -Skip 2) -split '\s\s+'
                        $obj = New-Object psObject
                        $obj | Add-Member NoteProperty "Specification"  $IDBBackUp.Specification
                        $obj | Add-Member NoteProperty "Session Id"  $IDBBackUp.'Session id'
                        $obj | Add-Member NoteProperty "Start Time"  $IDBBackUp.'Start time'
                        $obj | Add-Member NoteProperty "Medium Label"  $media[0]
                        $IDB_Backup_Result += $obj
                        $IDBSuccess_Count = 1

                    }
                    else
                    {
                        $media = 'NA'
                        $obj = New-Object psObject
                        $obj | Add-Member NoteProperty "Specification"  $IDBBackUp.Specification
                        $obj | Add-Member NoteProperty "Session Id"  $IDBBackUp.'Session id'
                        $obj | Add-Member NoteProperty "Start Time"  $IDBBackUp.'Start time'
                        $obj | Add-Member NoteProperty "Medium Label"  $media
                        $IDB_Backup_Result += $obj
                        $IDBSuccess_Count = 0
                    }


                    #####  Library Status  ######
                    Foreach($line in $LocalLines)
                    {
                            $obj = New-Object psobject
                            $input = $line -split ','
                            $library_name = $input[1].trim()
                            $Command = "omnimm -repository_barcode_scan $library_name"
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

                    
                    #####  Disabled Backup Job Count  ######
                    $command_path = "REG QUERY hklm\software\hewlett-packard\OpenView\OmniBackII\Common\ /v DataDir|findstr DataDir"
                    $CommandOutput = Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $command_path -logFile $Activitylog
                    $InitialPath = "$CommandOutput" -split '\s+'
                    $BarschedulesPath = $InitialPath[2] +"\Config\Server\"+"Barschedules"
                    $SchedulesPath = $InitialPath[2] +"\Config\Server\"+"Schedules"

                    $command_files = "Get-ChildItem -Recurse '$BarschedulesPath','$SchedulesPath' -File"
                    $Files = Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $command_files -logFile $Activitylog

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
                    
                    
                    ####   Free Disk Space  ####
                    $DiskspaceCommand = "Get-WmiObject win32_logicaldisk"
                    $FreeDiskSpaceOutput = Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $DiskspaceCommand -logFile $Activitylog
                    $FreeDiskSpace_signal,$FreeDiskSpace_Result = Get-FreeDiskSpaceWindows -InputObject $FreeDiskSpaceOutput



                    ##### Hung Backup 2nd Time   #####
                    $SecondTime = Get-Date
                    $Timespan = (New-TimeSpan -Start $FirstTime -End $SecondTime).TotalMinutes
                    if($Timespan -gt 5)
                    {
                    
                        $Hung_input2 = @()
                        foreach($line in $Hung_object)
                        {
                            $session_id = $line.sessionid
                            $command = "omnidb -rpt $session_id -details"
                            $Hung_input2 += Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $command -logFile $Activitylog
                        }
                        $HUNG_Output2= @()
                        for($i=0;$i -le $Hung_input2.Count;$i+=13)
                        {
                              $obj1 = New-Object psObject
                              $arr =$Hung_input2[$i] -split ": " 
                              $obj1 | Add-Member NoteProperty "$($arr[0].trim())"  $arr[1].trim()
                              $arr =$Hung_input2[$i+1] -split ": "
                              $obj1 | Add-Member NoteProperty "$($arr[0].trim())"  $arr[1].trim()
                              $arr =$Hung_input2[$i+11] -split ": "
                              $obj1 | Add-Member NoteProperty "$($arr[0].trim())"  $arr[1].trim()
                              $HUNG_Output2 += $obj1

                        }

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
                            $command = "omnidb -rpt $session_id -details"
                            $Hung_input2 += Invoke-BackupHealthCheckCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $command -logFile $Activitylog
                        }
                        $HUNG_Output2= @()
                        for($i=0;$i -le $Hung_input2.Count;$i+=13)
                        {
                              $obj1 = New-Object psObject
                              $arr =$Hung_input2[$i] -split ": " 
                              $obj1 | Add-Member NoteProperty "$($arr[0].trim())"  $arr[1].trim()
                              $arr =$Hung_input2[$i+1] -split ": "
                              $obj1 | Add-Member NoteProperty "$($arr[0].trim())"  $arr[1].trim()
                              $arr =$Hung_input2[$i+11] -split ": "
                              $obj1 | Add-Member NoteProperty "$($arr[0].trim())"  $arr[1].trim()
                              $HUNG_Output2 += $obj1

                        }

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


                
                else
                {
                    $sshsessionId = New-PoshSession -IpAddress $BackupDevice -Credential  $Credential
                    $Dp_Service_Output = Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId -logFile $Activitylog -command $config.ServiceHealthCheckCommand 
                    $Backup_Output = Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId -logFile $Activitylog -command $config.QueuingBackupHealthCheckCommand

                    $Backup_Result = @(Get-BackupStatus -InputObject $Backup_Output)

                    ### Hung Backup First Time #########
                    $Hung_input1 = @()
                    $Hung_object = $Backup_Result | ?{$_.'session Type' -eq "Backup"}
                    foreach($line in $Hung_object)
                    {
                    $session_id = $line.sessionid
                    $command = "omnidb -rpt $session_id -details"
                    $Hung_input1 += Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId -logFile $Activitylog -command $command
                    }
                    $HUNG_Output1= @()
                    for($i=0;$i -le $Hung_input1.Count;$i+=13)
                    {
                          $obj = New-Object psObject
                          $arr =$Hung_input1[$i] -split ": " 
                          $obj | Add-Member NoteProperty "$($arr[0].trim())"  $arr[1].trim()
                          $arr =$Hung_input1[$i+1] -split ": "
                          $obj | Add-Member NoteProperty "$($arr[0].trim())"  $arr[1].trim()
                          $arr =$Hung_input1[$i+11] -split ": "
                          $obj | Add-Member NoteProperty "$($arr[0].trim())"  $arr[1].trim()
                          $HUNG_Output1 += $obj

                    }
                    $FirstTime = Get-Date


                    $Disabled_TapeDrive_Output = Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId -logFile $Activitylog -command $config.DisabledTapeDriveCountCommand
                    $Scratch_Media_output = Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId -logFile $Activitylog -command $config.ScratchMediaCountCommand
                    $failedBackup_Output = Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId -logFile $Activitylog -command $FailedBackupCommand

                    ####### IDB Backup Status ##########
                    $IDBBackUp = Get-FailedBackup -InputObject $failedBackup_Output | Where-Object{$_.specification -like "IDB *"} | select -Last 1
                    $IDB_Backup_Result = @()      
                    if($IDBBackUp.Status -eq "completed")
                    {
                        $command = "omnidb -session $($IDBBackUp.'Session Id') -media"
                        $CommandOutput = Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId -logFile $Activitylog -command $command
                        $media = ($CommandOutput | select -Skip 2) -split '\s\s+'
                        $obj = New-Object psObject
                        $obj | Add-Member NoteProperty "Specification"  $IDBBackUp.Specification
                        $obj | Add-Member NoteProperty "Session Id"  $IDBBackUp.'Session id'
                        $obj | Add-Member NoteProperty "Start Time"  $IDBBackUp.'Start time'
                        $obj | Add-Member NoteProperty "Medium Label"  $media[0]
                        $IDB_Backup_Result += $obj
                        $IDBSuccess_Count = 1

                    }
                    else
                    {
                        $media = 'NA'
                        $obj = New-Object psObject
                        $obj | Add-Member NoteProperty "Specification"  $IDBBackUp.Specification
                        $obj | Add-Member NoteProperty "Session Id"  $IDBBackUp.'Session id'
                        $obj | Add-Member NoteProperty "Start Time"  $IDBBackUp.'Start time'
                        $obj | Add-Member NoteProperty "Medium Label"  $media
                        $IDB_Backup_Result += $obj
                        $IDBSuccess_Count = 0
                    }


                    #####  Library Status  ######
                    Foreach($line in $LocalLines)
                    {
                            $obj = New-Object psobject
                            $input = $line -split ','
                            $library_name = $input[1].trim()
                            $Command = "omnimm -repository_barcode_scan $library_name"
                            $Output = Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId -logFile $Activitylog -command $command
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

                    #### Disabled Backup Job Count #### 
                    $command_Barschedules = "find /etc/opt/omni/server/Barschedules -type f"
                    $command_Schedules = "find /etc/opt/omni/server/Schedules -type f"
                    $files = @()
                    $files += Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId -logFile $Activitylog -command $command_Barschedules
                    $files += Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId -logFile $Activitylog -command $command_Schedules
                    $DisabledBackupJobResult = @()
                    Foreach($file in $files)
                    {
                        $command_cat = "cat '$file'"
                        $content = Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId -logFile $Activitylog -command $command_cat
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


                    ####  Hung Backup 2nd Time  ####
                    $SecondTime = Get-Date
                    $Timespan = (New-TimeSpan -Start $FirstTime -End $SecondTime).TotalMinutes
                    if($Timespan -gt 5)
                    {
                        
                        $Hung_input2 = @()
                        foreach($line in $Hung_object)
                        {
                            $session_id = $line.sessionid
                            $command = "omnidb -rpt $session_id -details"
                            $Hung_input2 += Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId -logFile $Activitylog -command $command
                        }
                        $HUNG_Output2= @()
                        for($i=0;$i -le $Hung_input2.Count;$i+=13)
                        {
                              $obj1 = New-Object psObject
                              $arr =$Hung_input2[$i] -split ": " 
                              $obj1 | Add-Member NoteProperty "$($arr[0].trim())"  $arr[1].trim()
                              $arr =$Hung_input2[$i+1] -split ": "
                              $obj1 | Add-Member NoteProperty "$($arr[0].trim())"  $arr[1].trim()
                              $arr =$Hung_input2[$i+11] -split ": "
                              $obj1 | Add-Member NoteProperty "$($arr[0].trim())"  $arr[1].trim()
                              $HUNG_Output2 += $obj1

                        }

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
                        ####  Hung Backup 2nd Time  ####
                        $Hung_input2 = @()
                        foreach($line in $Hung_object)
                        {
                            $session_id = $line.sessionid
                            $command = "omnidb -rpt $session_id -details"
                            $Hung_input2 += Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId -logFile $Activitylog -command $command
                        }
                        $HUNG_Output2= @()
                        for($i=0;$i -le $Hung_input2.Count;$i+=13)
                        {
                              $obj1 = New-Object psObject
                              $arr =$Hung_input2[$i] -split ": " 
                              $obj1 | Add-Member NoteProperty "$($arr[0].trim())"  $arr[1].trim()
                              $arr =$Hung_input2[$i+1] -split ": "
                              $obj1 | Add-Member NoteProperty "$($arr[0].trim())"  $arr[1].trim()
                              $arr =$Hung_input2[$i+11] -split ": "
                              $obj1 | Add-Member NoteProperty "$($arr[0].trim())"  $arr[1].trim()
                              $HUNG_Output2 += $obj1

                        }

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

                    ####  Free Disk Space   ####
                    
                    $command_uname = "uname -a"
                    $uname = Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId -logFile $Activitylog -command $command_uname
                    if($uname -like "HP-UX*")
                    {
                        $DiskspaceCommand = "bdf"
                        $FreeDiskSpaceOutput = Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId -logFile $Activitylog -command $DiskspaceCommand
                        $FreeDiskSpace_signal,$FreeDiskSpace_Result = Get-FreeDiskSpaceHPUX -InputObject $FreeDiskSpaceOutput

                    }
                    else
                    {
                        $DiskspaceCommand = "df -h"
                        $FreeDiskSpaceOutput = Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId -logFile $Activitylog -command $DiskspaceCommand
                        $FreeDiskSpace_signal,$FreeDiskSpace_Result = Get-FreeDiskSpaceUnix -InputObject $FreeDiskSpaceOutput

                    }
                    







                }
                    
                    
                    $Dpservice_signal,$Dp_Service_Result = Get-DpService -InputObject $Dp_Service_Output
                    $SignalReport += $Dpservice_signal
                    $DetailedReport += "DP Service Status"
                    $DetailedReport += "-------------------"
                    $DetailedReport += $Dp_Service_Result | Out-String

                    
                    $Backup_Count =  $Backup_Result.Count
                    if($Backup_Count -gt 0)
                    {
                        $QueuedBackup_Result = $Backup_Result |? {$_.'session status' -eq "queuing"}
                    }
                    else
                    {
                        $QueuedBackup_Result = $null
                    }
                    $Queuing_gt30_signal,$Queuing_30_Result = Get-QueuedBackupGreaterThanThirtyMinute -InputObject $QueuedBackup_Result -TotalBackup_Count $Backup_Count
                    $SignalReport += $Queuing_gt30_signal
                    $DetailedReport += "Queuing Greater than 30 Min"
                    $DetailedReport += "-------------------"
                    $DetailedReport += $Queuing_30_Result| Out-String

                    
                    $Queuing_lt24_signal,$Queuing_lt24 = Get-QueuedBackupLessThanTwentyFourHour -InputObject $QueuedBackup_Result -TotalBackup_Count $Backup_Count
                    $SignalReport += $Queuing_lt24_signal
                    $DetailedReport += "Long Running Backup (>12 Hrs and <24 Hrs)"
                    $DetailedReport += "-------------------"
                    $DetailedReport += $Queuing_lt24 | Out-String

                    
                    $Queuing_gt24_signal,$Queuing_gt24 = Get-QueuedBackupGreaterThanTwentyFourHour -InputObject $QueuedBackup_Result -TotalBackup_Count $Backup_Count
                    $SignalReport += $Queuing_gt24_signal
                    $DetailedReport += "Long Running Backup (>24 Hrs)"
                    $DetailedReport += "-------------------"
                    $DetailedReport += $Queuing_gt24 | Out-String

                    
                    $Mount_req_signal,$Mount_Request_Result = Get-Mount_Request -InputObject $Backup_Result
                    $SignalReport += $Mount_req_signal
                    $DetailedReport += "Mount Request"
                    $DetailedReport += "-------------------"
                    $DetailedReport += $Mount_Request_Result | Out-String

                    
                    $Disabled_TapeDrive_signal,$Disabled_TapeDrive_Result = Get-Disabled_TapeDrive_count -InputObject $Disabled_TapeDrive_Output
                    $SignalReport += $Disabled_TapeDrive_signal
                    $DetailedReport += "Disabled Tape Drive Count"
                    $DetailedReport += "-------------------"
                    $DetailedReport += $Disabled_TapeDrive_Result | Out-String

                    
                    $Scratch_Media_signal,$Scratch_Media_Result = Get-Scratch_Media_Count -InputObject $Scratch_Media_Output
                    $SignalReport += $Scratch_Media_signal
                    $DetailedReport += "Scratch Media Count"
                    $DetailedReport += "-------------------"
                    $DetailedReport += $Scratch_Media_Result | Out-String

                    $FailedBackupCommand_Result = Get-FailedBackup -InputObject $failedBackup_Output

                    $Failed_bck_signal,$Failed_Bck_result = Get-FailedBackupCount -InputObject $FailedBackupCommand_Result
                    $SignalReport += $Failed_bck_signal
                    $DetailedReport += "Failed Backup Count"
                    $DetailedReport += "-------------------"
                    $DetailedReport += $Failed_Bck_result | Out-String

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
                    $IDBBackup_Signal = "IDB Backup Status,$IDBSuccess_Count/$TotalIDB_Count,$percent%,$signal"
                    $SignalReport += $IDBBackup_Signal
                    $DetailedReport += "IDB Bakup Status"
                    $DetailedReport += "-------------------"
                    $DetailedReport += $IDB_Backup_Result | Out-String

                    
                    $Critical_Backup_signal,$Critical_Bck_result = Get-CriticalBackupStatus -InputObject $FailedBackupCommand_Result -CriticalBackupServersInputFile $config.CriticalBackupServersInputFile
                    $SignalReport += $Critical_Backup_signal
                    $DetailedReport += "Critical Backup Status"
                    $DetailedReport += "-------------------"
                    $DetailedReport += $Critical_Bck_result | Out-String

                    
                    $Library_Status_output += get-RemoteLibraryStatus -InputObject $sshLines
                    $Total_library_count = $Library_Status_output.count
                    $Active_library_count = ($Library_Status_output |?{$_.status -eq "Active"}).count
                    $percent = [math]::Round(($Active_library_count/$Total_library_count)*100,2)
                    If($percent -eq 100)
                    {
                        $signal = "G"
                    }
                    else
                    {
                        $signal = "R"
                    }
                    $Library_Status_signal = "Library Status, $Active_library_count/$Total_library_count, $percent%, $signal"
                    $SignalReport += $Library_Status_signal
                    $DetailedReport += "Library Status"
                    $DetailedReport += "-------------------"
                    $DetailedReport += $Library_Status_output | Out-String

                    
                    $Total_Bck_count = $FailedBackupCommand_Result.count
                    $HUNG_Bck_count = $HUNG_Output.Count
                    $percent = [math]::Round(($HUNG_Bck_count/$Total_Bck_count)*100,2)
                    If($percent -eq  0)
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
                    $Hung_Bck_signal = "Hung Backup Count, $HUNG_Bck_count/$Total_Bck_count, $percent%, $signal"
                    $Hung_Result = $HUNG_Output | select sessionid,'Backup Specification'
                    $SignalReport += $Hung_Bck_signal
                    $DetailedReport += "Hung Backup Count"
                    $DetailedReport += "-------------------"
                    $DetailedReport += $Hung_Result | Out-String


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
                    $DisabledBackupJob_Signal = "Disabled Backup Job Count, $DisabledBackup_Count/$TotalBackupCount_Disabled, $percent%, $signal"
                    $SignalReport += $DisabledBackupJob_Signal
                    $DetailedReport += "Disabled Backup Job Count"
                    $DetailedReport += "-------------------"
                    $DetailedReport += $DisabledBackupJobResult | Out-String

                    
                    $SignalReport += $FreeDiskSpace_signal
                    $DetailedReport += "Free Disk Space"
                    $DetailedReport += "-------------------"
                    $DetailedReport += $FreeDiskSpace_Result | Out-String


                    $SignalReportName = $config.Reportpath +"\"+ $config.Technology + "_"+$config.ReportType+"_"+ $config.backupType+"_" +$config.Account +"_"+$Backupdevice+ "_" + "Signal"  + ".csv"

                    $DpService_ReportName = $config.Reportpath +"\"+ $config.Technology + "_"+$config.ReportType+"_"+ $config.backupType +"_"+$config.Account +"_"+$Backupdevice +"_" + "DpService_Report" +".txt"
                    $Queuing30_ReportName = $config.Reportpath +"\"+ $config.Technology + "_"+$config.ReportType+"_"+ $config.backupType +"_"+$config.Account +"_"+ $Backupdevice + "_" + "Queuing30_Report" + ".txt"
                    $Queuing_lt24_ReportName = $config.Reportpath +"\"+ $config.Technology + "_"+$config.ReportType+"_"+ $config.backupType +"_"+$config.Account +"_"+ $Backupdevice + "_" + "Queuing_lt24_Report" + ".txt"
                    $Queuing_gt24_ReportName = $config.Reportpath +"\"+ $config.Technology + "_"+$config.ReportType+"_"+ $config.backupType +"_"+$config.Account +"_"+ $Backupdevice + "_" + "Queuing_gt24_Report" + ".txt"
                    $MountRequest_ReportName = $config.Reportpath +"\"+ $config.Technology + "_"+$config.ReportType+"_"+ $config.backupType +"_"+$config.Account +"_"+ $Backupdevice + "_" + "MountRequest_Report" + ".txt"
                    $DisabledTapeDrive_ReportName = $config.Reportpath +"\"+ $config.Technology + "_"+$config.ReportType+"_"+ $config.backupType +"_"+$config.Account +"_"+ $Backupdevice + "_" + "DisabledTapeDrive_Report" +".txt"
                    $ScratchMedia_ReportName = $config.Reportpath +"\"+ $config.Technology + "_"+$config.ReportType+"_"+ $config.backupType +"_"+$config.Account +"_"+ $Backupdevice + "_" + "ScratchMedia_Report" + ".txt"
                    $FailedBackup_ReportName = $config.Reportpath +"\"+ $config.Technology + "_"+$config.ReportType+"_"+ $config.backupType +"_"+$config.Account +"_"+$Backupdevice +"_" + "FailedBackup_Report" +".txt"
                    $IDBBackup_ReportName = $config.Reportpath +"\"+ $config.Technology + "_"+$config.ReportType+"_"+ $config.backupType +"_"+$config.Account +"_"+ $Backupdevice + "_" + "IDBBackup_Report" + ".txt"
                    $CriticalBackup_ReportName = $config.Reportpath +"\"+ $config.Technology + "_"+$config.ReportType+"_"+ $config.backupType +"_"+$config.Account +"_"+ $Backupdevice + "_" + "CriticalBackup_Report" + ".txt"
                    $LibraryStatus_ReportName = $config.Reportpath +"\"+ $config.Technology + "_"+$config.ReportType+"_"+ $config.backupType +"_"+$config.Account +"_"+ $Backupdevice + "_" + "LibraryStatus_Report" + ".txt"
                    $HungBackup_ReportName = $config.Reportpath +"\"+ $config.Technology + "_"+$config.ReportType+"_"+ $config.backupType +"_"+$config.Account +"_"+ $Backupdevice + "_" + "HungBackup_Report" + ".txt"
                    $DisabledBackupJob_ReportName = $config.Reportpath +"\"+ $config.Technology + "_"+$config.ReportType+"_"+ $config.backupType +"_"+$config.Account +"_"+ $Backupdevice + "_" + "DisabledBackupJob_Report" +".txt"
                    $FreeDiskSpace_ReportName = $config.Reportpath +"\"+ $config.Technology + "_"+$config.ReportType+"_"+ $config.backupType +"_"+$config.Account +"_"+ $Backupdevice + "_" + "FreeDiskSpace_Report" + ".txt"




                    #$SignalReport| Export-Csv -Path $SignalReportName -NoTypeInformation
                    #$SignalReport| Out-File $SignalReportName
                    $signalreport | ConvertFrom-Csv -Header 'HealthCheckName','HealthCheckValue','HealthCheckValue(Percentage)','HealthCheckStatus' |Export-Csv -Path $SignalReportName -NoTypeInformation
                    
                    $DpService_Report | Out-File -Path $DpService_ReportName 
                    $Queuing30_Report | Out-File -Path $Queuing30_ReportName 
                    $Queuing_lt24_Report | Out-File -Path $Queuing_lt24_ReportName 
                    $Queuing_gt24_Report | Out-File -Path $Queuing_gt24_ReportName 
                    $MountRequest_Report | Out-File -Path $MountRequest_ReportName 
                    $DisabledTapeDrive_Report | Out-File -Path $DisabledTapeDrive_ReportName 
                    $ScratchMedia_Report | Out-File -Path $ScratchMedia_ReportName 
                    $FailedBackup_Report | Out-File -Path $FailedBackup_ReportName 
                    $IDBBackup_Report | Out-File -Path $IDBBackup_ReportName 
                    $CriticalBackup_Report | Out-File -Path $CriticalBackup_ReportName 
                    $LibraryStatus_Report | Out-File -Path $LibraryStatus_ReportName 
                    $HungBackup_Report | Out-File -Path $HungBackup_ReportName 
                    $DisabledBackupJob_Report | Out-File -Path $DisabledBackupJob_ReportName 
                    $FreeDiskSpace_Report | Out-File -Path $FreeDiskSpace_ReportName 

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
