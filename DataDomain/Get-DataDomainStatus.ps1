<#
.SYNOPSIS
  Get-DataDomainStatus.ps1
    
.INPUTS
  config.json
  credentialfile.csv

   
.NOTES
  Script:         Get-DataDomainStatus.ps1
  Author:         Chintalapudi Anand Vardhan
  Requirements :  Powershell v3.0 , Posh-SSH Module, Windows 2008 R2 Or Above
  Creation Date:  06/07/2022
  Modified Date:  06/07/2022
  Remarks      :  

  .History:
        Version Date            Author                       Description        
        1.0     06/07/2022      Chintalapudi Anand Vardhan   Initial Release
.EXAMPLE
  Script Usage 

  .\Get-DataDomainStatus.ps1 -ConfigFile .\config.json
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [String] $ConfigFile = "config.json"
)

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

Function Send-Mail
{
    [CmdletBinding()]
    Param(
    $attachments,
    $MailMessage
    )

    $sendMailMessageParameters = @{
            To          = $config.mail.To.Split(";")
            from        = $config.mail.From 
            Subject     = "$($config.mail.Subject) at $(Get-Date -Format 'dd-MMM-yyyy - HH:mm:ss')"      
            BodyAsHtml  = $true
            SMTPServer  = $config.mail.smtpServer             
            ErrorAction = 'Stop'
        } 

    if ($config.mail.Cc) 
    { 
        $sendMailMessageParameters.Add("CC", $config.mail.Cc.Split(";")) 
    }
    if ($attachments.Count -gt 0)
    {
        $sendMailMessageParameters.Add("Attachments", $attachments )
    }
    $body = ""
    $body += "<p>Hi, <br><br>&nbsp&nbsp&nbsp&nbsp$MailMessage<br><br>Thanks,<br>Automation Team<br></p>"
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

function Invoke-DDCommand
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

Function Get-DDVersion
{
    [CmdletBinding()]
    Param(
    $InputObject
    )
    try
    {
        $Version = ($InputObject -split "\s" | where{$_})[3]
        $signal  = "G"
        $Value   = "Success"
        $Percentage = "100 %"
    }
    catch
    {
        $Version = "Parse Error"
        $signal  = "R"
        $Value   = "Parse Error"
        $Percentage = "0 %"
    }
    $DDVersion          = [PSCUSTOMObject] @{
    "Technology"        = $config.Technology
    "ReportType"        = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account"           = $config.Account
    "BackupServer"      = $Backupdevice
    "ReportDate"        = $Reportdate
    "HC_Parameter"      = "DD Version"
    "Parameter"         = "DD Version"
    "Status"            = $Version
    }

    $DDVersion_signal   = [PSCUSTOMObject] @{
    "Technology"        = $config.Technology
    "ReportType"        = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account"           = $config.Account
    "BackupServer"      = $Backupdevice
    "ReportDate"        = $Reportdate
    'HC_Parameter'      = "DD Version"
    "HC_ShortName"      = "DDV"
    "Value"             = "$Value"
    'Percentage'        = "$Percentage"
    'Status'            = "$Signal"
    }
    $DDVersion,$DDVersion_signal
}

Function Get-SerialNumber
{
    [CmdletBinding()]
    Param(
    $InputObject 
    )

    try
    {
        $Serial = ($InputObject -split ":" | where{$_})[1]
        $signal = "G"
        $Value   = "Success"
        $Percentage = "100 %"
    }
    catch
    {
        $Serial = "Parse Error"
        $signal = "R"
        $Value   = "Parse Error"
        $Percentage = "0 %"
    }
    $DDSerial           = [PSCUSTOMObject] @{
    "Technology"        = $config.Technology
    "ReportType"        = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account"           = $config.Account
    "BackupServer"      = $Backupdevice
    "ReportDate"        = $Reportdate
    "HC_Parameter"      = "Serial Number"
    "Parameter"         = "Serial Number"
    "Status"            = $Serial.Trim()
    }

    $DDSerial_signal   = [PSCUSTOMObject] @{
    "Technology"        = $config.Technology
    "ReportType"        = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account"           = $config.Account
    "BackupServer"      = $Backupdevice
    "ReportDate"        = $Reportdate
    'HC_Parameter'      = "Serial Number"
    "HC_ShortName"      = "SN"
    "Value"             = "$Value"
    'Percentage'        = "$Percentage"
    'Status'            = "$Signal"
    }
    $DDSerial,$DDSerial_signal
}

Function Get-CapacityStatus
{
    [CmdletBinding()]
    Param(
    $InputObject
    )

    $CapacityStatus =@()
    try{
        $CapacityStatus_updated = $InputObject | Select-String "post" | where{$_} | select -First 1
        #foreach($DF_h in $DF_h_updated)
        #{
            $CapacityStatus_Split = $CapacityStatus_updated -split "\s\s+" | where{$_}
            $CapacityStatus      += [pscustomobject] @{
            "Technology"          = $config.Technology
            "ReportType"          = $config.ReportType
            "BackupApplication"   = $config.BackupApplication
            "Account"             = $config.Account
            "BackupServer"        = $Backupdevice
            "ReportDate"          = $Reportdate
            "HC_Parameter"        = "Capacity Status"
            Resource              = $CapacityStatus_Split[0]
            'Size GiB'            = $CapacityStatus_Split[1]
            'Used GiB'            = $CapacityStatus_Split[2]
            'Avail GiB'           = $CapacityStatus_Split[3]
            'Use %'               = $CapacityStatus_Split[4]
            'Cleanable GiB'       = $CapacityStatus_Split[5]
            }
        #}
        $Total = $CapacityStatus.'Size GiB'
        $Used =  $CapacityStatus.'Used GiB'   
        $Value = " $Used (GB) / $Total (GB)"
        $Percent = $CapacityStatus.'Use %' -replace "%"
        if($Percent -gt 90)
        {
            $signal = "R"
        }
        elseif(($percent -ge 85) -and ($percent -le 90))
        {
            $signal = "Y"
        }
        else
        {
            $signal = "G"
        }
        $CapacityStatus_signal = [PSCUSTOMObject] @{
        "Technology"           = $config.Technology
        "ReportType"           = $config.ReportType
        "BackupApplication"    = $config.BackupApplication
        "Account"              = $config.Account
        "BackupServer"         = $Backupdevice
        "ReportDate"           = $Reportdate
        'HC_Parameter'         = "Capacity Status"
        "HC_ShortName"         = "CapS"
        "Value"                = "$Value"
        'Percentage'           = "$Percent %"
        'Status'               = "$Signal"
        }
    }
    catch
    {
        $CapacityStatus,$CapacityStatus_signal = Get-FailedObject -HCParameter "Capacity Status" -HCShortName "CapS" -Message "Parse Error"
    }
    $CapacityStatus,$CapacityStatus_signal 
}

Function Get-CleaningStatus
{
    [CmdletBinding()]
    Param(
    $InputObject
    )

    $FilesysStatus_updated  = $InputObject | where{$_}
    if(($FilesysStatus_updated -like "*Started*") -or ($FilesysStatus_updated -like "*Running*") -or ($FilesysStatus_updated -like "*Finished*"))
    {
        $signal = "G"
        $Percent = "100 %"
        $Value = "Success"
    }
    else
    {
        $signal = "R"
        $Percent = "0 %"
        $Value = "Failure"
    }

    $CleaningStatus     = [pscustomobject] @{
    "Technology"        = $config.Technology
    "ReportType"        = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account"           = $config.Account
    "BackupServer"      = $Backupdevice
    "ReportDate"        = $Reportdate
    "HC_Parameter"      = "Cleaning Status"
    Parameter           = "Clean Status"
    Status              = $FilesysStatus_updated
    }
    $CleaningStatus_Signal = [PSCUSTOMObject] @{
    "Technology"           = $config.Technology
    "ReportType"           = $config.ReportType
    "BackupApplication"    = $config.BackupApplication
    "Account"              = $config.Account
    "BackupServer"         = $Backupdevice
    "ReportDate"           = $Reportdate
    'HC_Parameter'         = "Cleaning Status"
    "HC_ShortName"         = "CS"
    "Value"                = "$Value"
    'Percentage'           = "$Percent"
    'Status'               = "$Signal"
    }
    $CleaningStatus,$CleaningStatus_Signal
}

Function Get-CleaningSchedule
{
    [CmdletBinding()]
    Param(
    $InputObject
    )

    $FilesysSched_Updated   = $InputObject | where{$_}

    $CleaningSchedule   = [pscustomobject] @{
    "Technology"        = $config.Technology
    "ReportType"        = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account"           = $config.Account
    "BackupServer"      = $Backupdevice
    "ReportDate"        = $Reportdate
    "HC_Parameter"      = "Cleaning Schedule"
    Parameter           = "Cleaning Schedule"
    Status              = $FilesysSched_Updated
    }
    $CleaningSchedule_Signal = [PSCUSTOMObject] @{
    "Technology"           = $config.Technology
    "ReportType"           = $config.ReportType
    "BackupApplication"    = $config.BackupApplication
    "Account"              = $config.Account
    "BackupServer"         = $Backupdevice
    "ReportDate"           = $Reportdate
    'HC_Parameter'         = "Cleaning Schedule"
    "HC_ShortName"         = "CSch"
    "Value"                = "Success"
    'Percentage'           = "100 %"
    'Status'               = "G"
    }
    $CleaningSchedule,$CleaningSchedule_Signal
}

Function Get-DiskStatus
{
    [CmdletBinding()]
    Param(
    $InputObject
    )

    $DiskStatus = @()
    try
    {
        $Legendlinenumber   = ($InputObject | Select-String -Pattern "Legend").LineNumber
        $DiskStatus_updated = $InputObject | select -Skip ($Legendlinenumber+1) | where{$_} | select -SkipLast 2
        foreach($DiskStatusLine in $DiskStatus_updated)
        {
            $DiskStatus_Split   = $DiskStatusLine -split "\s\s+" | where{$_}
            $DiskStatus   += [pscustomobject] @{
            "Technology"        = $config.Technology
            "ReportType"        = $config.ReportType
            "BackupApplication" = $config.BackupApplication
            "Account"           = $config.Account
            "BackupServer"      = $Backupdevice
            "ReportDate"        = $Reportdate
            "HC_Parameter"      = "Disk Status"
            Legend              = $DiskStatus_Split[0].trim()
            State               = $DiskStatus_Split[1].trim()
            Count               = $DiskStatus_Split[2].trim()
            }
        }
        $FailedDisks_Count = @($DiskStatus | where{$_.Legend -eq "F"}).count
        $TotalDisks_Count  = ($DiskStatus | Measure-Object -Property Count -Sum).Sum
        if($FailedDisks_Count > 1)
        {
            $Signal  = "R"
            $Percent = "0 %"
        }
        else
        {
            $Signal  = "G"
            $Percent = "100 %"
        }
        $Value = "$FailedDisks_Count / $TotalDisks_Count"
        $DiskStatus_Signal  = [PSCUSTOMObject] @{
        "Technology"        = $config.Technology
        "ReportType"        = $config.ReportType
        "BackupApplication" = $config.BackupApplication
        "Account"           = $config.Account
        "BackupServer"      = $Backupdevice
        "ReportDate"        = $Reportdate
        'HC_Parameter'      = "Disk Status"
        "HC_ShortName"      = "DS"
        "Value"             = "$Value"
        'Percentage'        = "$Percent"
        'Status'            = "$Signal"
        }
    }
    catch
    {
        $DiskStatus,$DiskStatus_Signal = Get-FailedObject -HCParameter "Disk Status" -HCShortName "DS" -Message "Parse Error"
    }
    $DiskStatus,$DiskStatus_Signal
}

Function Get-AlertStatus
{
    [CmdletBinding()]
    Param(
    $InputObject
    )

    $AlertsShow_Status   = @()
    $AlertsShow_updated  = $InputObject | select -Skip 2 | select -SkipLast 2
    $AlertsShow_Status  = [pscustomobject] @{
    "Technology"        = $config.Technology
    "ReportType"        = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account"           = $config.Account
    "BackupServer"      = $Backupdevice
    "ReportDate"        = $Reportdate
    "HC_Parameter"      = "Data Domain Alert"
    "Parameter"         = "DD Alerts"
    "Status"            = $AlertsShow_Raw | out-string

    }    
    $Value   = @($AlertsShow_updated).count
    <#
    try
    {
        $AlertsShow_Status   = @()
        $AlertsShow_updated  = $InputObject | select -Skip 2 | select -SkipLast 2
        foreach($AlertsShowLine in $AlertsShow_updated)
        {
            $AlertsShow_Split   = $AlertsShowLine -split "\s\s+" | where{$_}
            if($AlertsShow_Split.count -eq 7)
            {
                $Id       = $AlertsShow_Split[0]
                $PostTime = $AlertsShow_Split[1] + " " + $AlertsShow_Split[2]
                $Severity = $AlertsShow_Split[3]
                $Class    = $AlertsShow_Split[4]
                $Object   = $AlertsShow_Split[5]
                $Message  = $AlertsShow_Split[6]
            }
            elseif($AlertsShow_Split.count -eq 5)
            {
                $Id       = $AlertsShow_Split[0]
                $PostTime = $AlertsShow_Split[1]
                $Severity = $AlertsShow_Split[2]
                $Class    = $AlertsShow_Split[3]
                $Object   = ""
                $Message  = $AlertsShow_Split[4]
            }
            elseif($AlertsShow_Split.count -eq 6)
            {
                $Id       = $AlertsShow_Split[0]
                if($AlertsShow_Split[0].trim() -match "\D\D\D \D\D\D\s")
                {
                    $PostTime = $AlertsShow_Split[1]
                    $Severity = $AlertsShow_Split[2]
                    $Class    = $AlertsShow_Split[3]
                    $Object   = $AlertsShow_Split[4]
                    $Message  = $AlertsShow_Split[5]
                }
                else
                {
                    $PostTime = $AlertsShow_Split[1] + " " + $AlertsShow_Split[2]
                    $Severity = $AlertsShow_Split[3]
                    $Class    = $AlertsShow_Split[4]
                    $Object   = " "
                    $Message  = $AlertsShow_Split[5]
                }
            }
            else
            {
                $Id       = $AlertsShow_Split[0]
                $PostTime = $AlertsShow_Split[1]
                $Severity = $AlertsShow_Split[2]
                $Class    = $AlertsShow_Split[3]
                $Object   = $AlertsShow_Split[4]
                $Message  = $AlertsShow_Split[5]
            }
            $AlertsShow_Status += [pscustomobject] @{
            "Technology"        = $config.Technology
            "ReportType"        = $config.ReportType
            "Application"       = $config.BackupApplication
            "Account"           = $config.Account
            "BackupServer"      = $Backupdevice
            "ReportDate"        = $Reportdate
            "HC_Parameter"      = "Data Domain Alert"
            Id                  = $Id      
            'Post Time'         = $PostTime
            Severity            = $Severity
            Class               = $Class   
            Object              = $Object  
            Message             = $Message 
            }    
        }
        $Value   = @($AlertsShow_updated).count
        #$Percent = "100 %"
    }
    catch
    {
        $AlertsShow_Status += [pscustomobject] @{
        "Technology"        = $config.Technology
        "ReportType"        = $config.ReportType
        "Application"       = $config.BackupApplication
        "Account"           = $config.Account
        "BackupServer"      = $Backupdevice
        "ReportDate"        = $Reportdate
        "HC_Parameter"      = "Data Domain Alert"
        Id                  = "Parse Error"
        'Post Time'         = "Parse Error"
        Severity            = "Parse Error"
        Class               = "Parse Error"
        Object              = "Parse Error"
        Message             = "Parse Error"
        }
        $Value   = "Parse Error"
        #$Percent = "100 %"
    }
    #>
    $AlertsShow_Signal  = [PSCUSTOMObject] @{
    "Technology"        = $config.Technology
    "ReportType"        = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account"           = $config.Account
    "BackupServer"      = $Backupdevice
    "ReportDate"        = $Reportdate
    'HC_Parameter'      = "Data Domain Alert"
    "HC_ShortName"      = "AS"
    "Value"             = "$Value"
    'Percentage'        = "0 %"
    'Status'            = "R"
    }
    $AlertsShow_Status,$AlertsShow_Signal
}

Function Get-FailedObject
{
    [CmdletBinding()]
    param(
    $HCParameter,$HCShortName,$Message
    )
    $FailedObject = [Pscustomobject] @{
    "Technology"        = $config.Technology
    "ReportType"        = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account"           = $config.Account
    "BackupServer"      = $Backupdevice
    "ReportDate"        = $Reportdate
    "HC_Parameter"      = $HCParameter
    Parameter           = $HCParameter
    Status              = $Message
    }
    $FailedObject_Signal = [PSCUSTOMObject] @{
    "Technology"           = $config.Technology
    "ReportType"           = $config.ReportType
    "BackupApplication"    = $config.BackupApplication
    "Account"              = $config.Account
    "BackupServer"         = $Backupdevice
    "ReportDate"           = $Reportdate
    'HC_Parameter'         = "$HCParameter"
    "HC_ShortName"         = "$HCShortName"
    "Value"                = "$Message"
    'Percentage'           = "0 %"
    'Status'               = "R"
    }
    $FailedObject,$FailedObject_Signal
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

Function Export-DDFiles
{
    $SignalReport        | Export-Csv -path $SignalReportName            -NoTypeInformation
    $DDVersion           | Export-Csv -path $DDVersion_ReportName        -NoTypeInformation
    $DDSerial            | Export-Csv -path $SerialNumber_ReportName     -NoTypeInformation
    $CapacityStatus      | Export-Csv -path $CapacityStatus_ReportName   -NoTypeInformation
    $CleaningStatus      | Export-Csv -path $CleaningStatus_ReportName   -NoTypeInformation
    $CleaningSchedule    | Export-Csv -path $CleaningSchedule_ReportName -NoTypeInformation
    $DiskStatus          | Export-Csv -path $DiskStatus_ReportName       -NoTypeInformation
    $AlertShowStatus     | Export-Csv -path $AlertStatus_ReportName      -NoTypeInformation
    $SignalSummaryResult | Export-Csv -Path $SignalSummaryReportName     -NoTypeInformation
}

Function Check-Access
{
    [cmdletbinding()]
    Param(
    $Key
    )
    if(Test-Path "key.exe")
    {
        try
        {
            $Scriptarg = "DXC_$((Get-Date).ToString("yyyyMMdd"))"
            $outkey = .\Key.exe $Scriptarg
        }
        catch
        {
            Write-Log -Path $Activitylog -Entry "Unable to Run Key File." -Type warning -ShowOnConsole
            Write-Log -Path $Activitylog -Entry "Please run again or Please Unblock the file." -Type warning -ShowOnConsole
            exit
        }
        if($outkey)
        {
            $Split = $outkey -split ","
            $KeyDomain = $Split[0].Trim()
            $KeyYear   = $Split[1].Trim()
            $KeyMonth  = $Split[2].Trim()
            $Alloweddate = ([datetime]"$keyyear, $KeyMonth").ToString("yyyyMM")
            $Scriptdate = (Get-Date).ToString("yyyyMM")
            $Whoami = systeminfo | findstr /B "Domain"
            $ScriptDomain = ($Whoami -split ":")[1].Trim()
            if($KeyDomain -and $KeyYear -and $KeyMonth -and $Alloweddate -and $ScriptDomain)
            {
                if($ScriptDomain -eq $KeyDomain)
                {
                    if($Scriptdate -le $Alloweddate)
                    {
                        Write-Log -Path $Activitylog -Entry "Permission granted, Running the script" -Type Information -ShowOnConsole
                    }
                    else
                    {
                        Write-Log -Path $Activitylog -Entry "Your key got Expired, please contact Automation team!" -Type warning -ShowOnConsole
                        exit
                    }
                }
                else
                {
                    Write-Log -Path $Activitylog -Entry "You do not have permission to run the script" -Type warning -ShowOnConsole
                    Write-Log -Path $Activitylog -Entry "Please contact Automation team for the key!" -Type warning -ShowOnConsole
                    exit
                }
            }
            else
            {
                Write-Log -Path $Activitylog -Entry "Something went wrong, please try again!" -Type warning -ShowOnConsole
                exit
            }
        }
        else
        {
            Write-Log -Path $Activitylog -Entry "Failed to Run Key File." -Type warning -ShowOnConsole
            Write-Log -Path $Activitylog -Entry "Please try again." -Type warning -ShowOnConsole
            exit
        }
    }
    else
    {
        Write-Log -Path $Activitylog -Entry "Unable to find Key File." -Type warning -ShowOnConsole
        exit
    }
}



$config = Get-Config -ConfigFile $ConfigFile
$culture = [CultureInfo]'en-us'
$Reportdate = ([system.datetime]::UtcNow).ToString("dd-MMM-yy HH:mm", $culture)
$date = ([system.datetime]::UtcNow).ToString("ddMMMyy_HHmm", $culture)
$Activitylog = "Activity.log"
Write-Log -Path $Activitylog -Entry "Started" -Type Information -ShowOnConsole -OverWrite
Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "Host: $($env:COMPUTERNAME)" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "User: $($env:USERNAME)" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole

Check-Access

if($config)
{
    try
    {
        Import-Module ".\Posh-SSH\Posh-SSH.psd1"
    }
    catch
    {
        Write-Log -Path $Activitylog -Entry "Failed to import Posh-SSH module" -Type warning -ShowOnConsole
        exit
    }
    
    if ($config.deleteFilesOlderThanInDays -gt 0)
    {
        Remove-File -Day $config.deleteFilesOlderThanInDays -DirectoryPath $config.ReportPath -FileType "*.csv"
    }
    $SignalReport = @()
    $BackupDevice = $config.BackupServer

    $SignalReportName            = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "Signal"        + "_"  + $date+ ".csv"
    $DDVersion_ReportName        = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "DDV"           + "_"  + $date+ ".csv"
    $SerialNumber_ReportName     = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "SN"            + "_"  + $date+ ".csv"
    $CapacityStatus_ReportName   = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "CapS"          + "_"  + $date+ ".csv"
    $CleaningStatus_ReportName   = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "CS"            + "_"  + $date+ ".csv"
    $CleaningSchedule_ReportName = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "CSch"          + "_"  + $date+ ".csv"
    $DiskStatus_ReportName       = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "DS"            + "_"  + $date+ ".csv"
    $AlertStatus_ReportName      = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "AS"            + "_"  + $date+ ".csv"
    $SignalSummaryReportName     = $config.Reportpath + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "SignalSummary" + "_"  + $date+ ".csv"

    Write-Log -Path $Activitylog -Entry "Checking For Credential for $BackupDevice!" -Type Information -ShowOnConsole
    $CredentialPath = "cred.xml"
    if (!(Test-Path -Path $CredentialPath) )
    {
        $Credential = Get-Credential -Message "Enter Credentials for $BackupDevice"
        $Credential | Export-Clixml $CredentialPath -Force
    }
    try
    {
        $Credential = Import-Clixml $CredentialPath
    }
    catch
    {
        $comment = $_ | Format-List -Force 
        Write-Log -Path $Activitylog -Entry  "Invalid Credential File for $BackupDevice!" -Type Error -ShowOnConsole
        Write-Log -Path $Activitylog -Entry  $comment -Type Exception 
        Write-Log -Path $Activitylog -Entry  "Recreate Credential File!" -Type Information -ShowOnConsole
        
        $Message = "Failed to get Credential"
        $DDVersion,$DDVersion_signal               = Get-FailedObject -HCParameter "DD Version"        -HCShortName "DDV"  -Message $Message
        $DDSerial,$DDSerial_signal                 = Get-FailedObject -HCParameter "Serial Number"     -HCShortName "SN"   -Message $Message
        $CapacityStatus,$CapacityStatus_signal     = Get-FailedObject -HCParameter "Capacity Status"   -HCShortName "CapS" -Message $Message
        $CleaningStatus,$CleaningStatus_Signal     = Get-FailedObject -HCParameter "Cleaning Status"   -HCShortName "CS"   -Message $Message
        $CleaningSchedule,$CleaningSchedule_Signal = Get-FailedObject -HCParameter "Cleaning Schedule" -HCShortName "CSch" -Message $Message
        $DiskStatus,$DiskStatus_Signal             = Get-FailedObject -HCParameter "Disk Status"       -HCShortName "DS"   -Message $Message
        $AlertsShow_Status,$AlertsShow_Signal      = Get-FailedObject -HCParameter "Data Domain Alert" -HCShortName "AS"   -Message $Message

        $SignalReport += $DDVersion_signal
        $SignalReport += $DDSerial_signal
        $SignalReport += $CapacityStatus_signal
        $SignalReport += $CleaningStatus_Signal
        $SignalReport += $CleaningSchedule_Signal
        $SignalReport += $DiskStatus_Signal
        $SignalReport += $AlertsShow_Signal

        $SignalSummaryResult = Get-SignalSummary -Inputobject $SignalReport
        Export-DDFiles
        if($config.SendMail -eq "Yes")
        {
            $attachment = @()
            $attachment += $SignalReportName           
            $attachment += $DDVersion_ReportName       
            $attachment += $SerialNumber_ReportName    
            $attachment += $CapacityStatus_ReportName  
            $attachment += $CleaningStatus_ReportName  
            $attachment += $CleaningSchedule_ReportName
            $attachment += $DiskStatus_ReportName      
            $attachment += $AlertStatus_ReportName     
            $attachment += $SignalSummaryReportName    

            Send-Mail -attachments $attachment
        }
        exit
    }

    $SSHSession = New-PoshSession -IpAddress $BackupDevice -Credential $Credential

    if($SSHSession.connected -eq "true")
    {
        Write-Log -Path $Activitylog -Entry "Connected to $BackupDevice!" -Type Information -ShowOnConsole
        if($Config.OSVersion -eq "Enabled")
        {
            $DDVersion_Raw = Invoke-DDCommand -SshSessionId $sshsession.sessionId -logFile $Activitylog -command $Config.VersionCommand
            if($DDVersion_Raw)
            {
                $DDVersion,$DDVersion_signal = Get-DDVersion -InputObject $DDVersion_Raw       
            }
            else
            {
                $DDVersion,$DDVersion_signal = Get-FailedObject -HCParameter "DD Version" -HCShortName "DDV" -Message "Failed To Run Command"
            }
        }
        else
        {
            $DDVersion,$DDVersion_signal = Get-FailedObject -HCParameter "DD Version" -HCShortName "DDV" -Message "Disabled"
            $DDVersion_signal.Status = "D"
        }

        if($Config.SerialNumber -eq "Enabled")
        {
            $SerialNumber_Raw = Invoke-DDCommand -SshSessionId $sshsession.sessionId -logFile $Activitylog -command $Config.SerialNumberCommand
            if($SerialNumber_Raw)
            {
                $DDSerial,$DDSerial_signal = Get-SerialNumber -InputObject $SerialNumber_Raw       
            }
            else
            {
                $DDSerial,$DDSerial_signal = Get-FailedObject -HCParameter "Serial Number" -HCShortName "SN" -Message "Failed To Run Command"
            }
        }
        else
        {
            $DDSerial,$DDSerial_signal = Get-FailedObject -HCParameter "Serial Number" -HCShortName "SN" -Message "Disabled"
            $DDSerial_signal.Status = "D"
        }

        if($Config.CapacityStatus -eq "Enabled")
        {
            $CapacityStatus_Raw = Invoke-DDCommand -SshSessionId $sshsession.sessionId -logFile $Activitylog -command $config.CapacityStatuscommand
            if($CapacityStatus_Raw)
            {
                $CapacityStatus,$CapacityStatus_signal  = Get-CapacityStatus -InputObject $CapacityStatus_Raw
            }
            else
            {
                $CapacityStatus,$CapacityStatus_signal  = Get-FailedObject -HCParameter "Capacity Status" -HCShortName "CapS" -Message "Failed To Run Command"
            }
        }
        else
        {
            $CapacityStatus,$CapacityStatus_signal  = Get-FailedObject -HCParameter "Capacity Status" -HCShortName "CapS" -Message "Disabled"
            $CapacityStatus_signal.Status = "D"
        }

        if($Config.CleaningSTatus -eq "Enabled")
        {
            $CleanStatus_Raw = Invoke-DDCommand -SshSessionId $sshsession.sessionId -logFile $Activitylog -command $config.CleanStatusCommand
            if($CleanStatus_Raw)
            {
                $CleaningStatus,$CleaningStatus_Signal  = Get-CleaningStatus -InputObject $CleanStatus_Raw
            }
            else
            {
                $CleaningStatus,$CleaningStatus_Signal = Get-FailedObject -HCParameter "Cleaning Status" -HCShortName "CS" -Message "Failed To Run Command"
            }
        }
        else
        {
            $CleaningStatus,$CleaningStatus_Signal = Get-FailedObject -HCParameter "Cleaning Status" -HCShortName "CS" -Message "Disabled"
            $CleaningStatus_Signal.Status = "D"
        }
        
        if($Config.CleaningSchedule -eq "Enabled")
        {
            $CleaningSchedule_Raw  = Invoke-DDCommand -SshSessionId $sshsession.sessionId -logFile $Activitylog -command $config.CleanScheduleCommand
            if($CleaningSchedule_Raw)
            {
                $CleaningSchedule,$CleaningSchedule_Signal = Get-CleaningSchedule -InputObject $CleaningSchedule_Raw
            }
            else
            {
                $CleaningSchedule,$CleaningSchedule_Signal = Get-FailedObject -HCParameter "Cleaning Schedule" -HCShortName "CSch" -Message "Failed To Run Command"
            }
        }
        else
        {
            $CleaningSchedule,$CleaningSchedule_Signal = Get-FailedObject -HCParameter "Cleaning Schedule" -HCShortName "CSch" -Message "Disabled"
            $CleaningSchedule_Signal.Status = "D"
        }

        if($Config.DiskStatus -eq "Enabled")
        {
            $DiskStatus_Raw = Invoke-DDCommand -SshSessionId $sshsession.sessionId -logFile $Activitylog -command $config.DiskStatusCommand
            if($DiskStatus_Raw)
            {
                $DiskStatus,$DiskStatus_Signal = Get-DiskStatus -InputObject $DiskStatus_Raw
            }
            else
            {
                $DiskStatus,$DiskStatus_Signal = Get-FailedObject -HCParameter "Disk Status" -HCShortName "DS" -Message "Failed To Run Command"
            }
        }
        else
        {
            $DiskStatus,$DiskStatus_Signal = Get-FailedObject -HCParameter "Disk Status" -HCShortName "DS" -Message "Disabled"
            $DiskStatus_Signal.Status = "D"
        }

        if($Config.AlertStatus -eq "Enabled")
        {
        $AlertsShow_Raw = Invoke-DDCommand -SshSessionId $sshsession.sessionId -logFile $Activitylog -command $config.AlertStatusCommand
        if($AlertsShow_Raw)
        {
            if($AlertsShow_Raw -eq "No active alerts.")
            {
                $AlertShowStatus,$AlertsShow_Signal = Get-FailedObject -HCParameter "Data Domain Alert" -HCShortName "AS" -Message "No Alerts"
                $AlertsShow_Signal.Status = "G"     
                $AlertsShow_Signal.Percentage = "100 %"
            }
            else
            {
                $AlertShowStatus,$AlertsShow_Signal = Get-AlertStatus -InputObject $AlertsShow_Raw
            }
        }
        else
        {
            $AlertShowStatus,$AlertsShow_Signal = Get-FailedObject -HCParameter "Data Domain Alert" -HCShortName "AS" -Message "Failed To Run Command"
        }
        }
        else
        {
            $AlertShowStatus,$AlertsShow_Signal = Get-FailedObject -HCParameter "Data Domain Alert" -HCShortName "AS" -Message "Disabled"
            $AlertsShow_Signal.Status = "D"
        }

        Remove-SSHSession -SessionId $sshsession.sessionId

        $SignalReport += $DDVersion_signal
        $SignalReport += $DDSerial_signal
        $SignalReport += $CapacityStatus_signal
        $SignalReport += $CleaningStatus_Signal
        $SignalReport += $CleaningSchedule_Signal
        $SignalReport += $DiskStatus_Signal
        $SignalReport += $AlertsShow_Signal

        $SignalSummaryResult = Get-SignalSummary -Inputobject $SignalReport
        Export-DDFiles
        if($config.SendMail -eq "Yes")
        {
            $attachment = @()
            $attachment += $SignalReportName           
            $attachment += $DDVersion_ReportName       
            $attachment += $SerialNumber_ReportName    
            $attachment += $CapacityStatus_ReportName  
            $attachment += $CleaningStatus_ReportName  
            $attachment += $CleaningSchedule_ReportName
            $attachment += $DiskStatus_ReportName      
            $attachment += $AlertStatus_ReportName     
            $attachment += $SignalSummaryReportName    

            Send-Mail -attachments $attachment
        }
    }
    else
    {
        $Message = "Failed to connect to $BackupDevice"
        $DDVersion,$DDVersion_signal               = Get-FailedObject -HCParameter "DD Version"        -HCShortName "DDV"  -Message $Message
        $DDSerial,$DDSerial_signal                 = Get-FailedObject -HCParameter "Serial Number"     -HCShortName "SN"   -Message $Message
        $CapacityStatus,$CapacityStatus_signal     = Get-FailedObject -HCParameter "Capacity Status"   -HCShortName "CapS" -Message $Message
        $CleaningStatus,$CleaningStatus_Signal     = Get-FailedObject -HCParameter "Cleaning Status"   -HCShortName "CS"   -Message $Message
        $CleaningSchedule,$CleaningSchedule_Signal = Get-FailedObject -HCParameter "Cleaning Schedule" -HCShortName "CSch" -Message $Message
        $DiskStatus,$DiskStatus_Signal             = Get-FailedObject -HCParameter "Disk Status"       -HCShortName "DS"   -Message $Message
        $AlertsShow_Status,$AlertsShow_Signal      = Get-FailedObject -HCParameter "Data Domain Alert" -HCShortName "AS"   -Message $Message

        $SignalReport += $DDVersion_signal
        $SignalReport += $DDSerial_signal
        $SignalReport += $CapacityStatus_signal
        $SignalReport += $CleaningStatus_Signal
        $SignalReport += $CleaningSchedule_Signal
        $SignalReport += $DiskStatus_Signal
        $SignalReport += $AlertsShow_Signal

        $SignalSummaryResult = Get-SignalSummary -Inputobject $SignalReport
        Export-DDFiles
        if($config.SendMail -eq "Yes")
        {
            $attachment = @()
            $attachment += $SignalReportName           
            $attachment += $DDVersion_ReportName       
            $attachment += $SerialNumber_ReportName    
            $attachment += $CapacityStatus_ReportName  
            $attachment += $CleaningStatus_ReportName  
            $attachment += $CleaningSchedule_ReportName
            $attachment += $DiskStatus_ReportName      
            $attachment += $AlertStatus_ReportName     
            $attachment += $SignalSummaryReportName    

            Send-Mail -attachments $attachment
        }
        Write-Log -Path $Activitylog -Entry "Failed to connect to $BackupDevice" -Type Error -ShowOnConsole
    }
}
else
{
    Write-Log -Path $Activitylog -Entry "Invalid $ConfigFile" -Type Error -ShowOnConsole
}
Write-Log -Path $Activitylog -Entry "Completed" -Type Information -ShowOnConsole
