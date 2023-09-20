<#
.SYNOPSIS
  Reset-PoorMedia.ps1

.DESCRIPTION
  Starts the Opsware Service for the given servers.
	
.INPUTS
  Configfile - config.json
  InputFile.txt
   
.NOTES
  Script:         Reset-PoorMedia.ps1
  Author:         Chintalapudi Anand Vardhan  
  Requirements:   Powershell v3.0
  Creation Date:  06-Jan-2022
  Modified Date:  06-Jan-2022 
  Remarks      :  

  .History:
        Version Date                       Author                    Description        
        1.0     06-Jan-2022      Chintalapudi Anand Vardhan        Initial Release

.EXAMPLE
  Script Usage 

  .\Reset-PoorMedia.ps1 -ConfigFile .\config.json
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

function Invoke-DPCommandNonWindows
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

function Invoke-DPCommandWindows
{
    [CmdletBinding()]
    param(
        #[Parameter(Mandatory = $true)]
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

Function Get-DeatiledPools
{
    [CmdletBinding()]
    Param(
    $InputObject 
    )
    $Pools = $InputObject | Select-String -Pattern "Pool name :","Poor media","Fair media"
    $AllPools = @()
    for($i=0; $i -lt $Pools.Count; $i+=3)
    {
        $PoolName = ($Pools[$i] -split ": ")[1].trim()
        $Poor     = ($Pools[$i+1] -split ": ")[1].trim()
        $Fair     = ($Pools[$i+2] -split ": ")[1].trim()
        $AllPools += [Pscustomobject] @{
        "Pool Name"  = "$PoolName"
        "Poor Media" = "$Poor"
        "Fair Media" = "$Fair"
        }
    }
    $PoorandFairPools = $AllPools | where{$_.'Poor Media' -ne 0 -or $_.'Fair Media' -ne 0}
    $PoorandFairPools
}

$config = Get-Config -ConfigFile $ConfigFile
$Activitylog = "Activity.log"
Write-Log -Path $Activitylog -Entry "Started" -Type Information -ShowOnConsole -OverWrite
Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "Host: $($env:COMPUTERNAME)" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "User: $($env:USERNAME)" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole
$ReportDate = (Get-Date).ToString("dd-MM-yyyy")
if($config)
{
    if(Test-Path -Path $config.InputPoolFile)
    {
        $InputPools = Get-Content $config.InputPoolFile | where{$_}
    }
    else
    {
        Write-Log -Path $Activitylog -Entry "Invalid InputPoolFile!" -Type Error -ShowOnConsole
        Write-Log -Path $Activitylog -Entry  "Recreate InputPoolFile!" -Type Information -ShowOnConsole
        exit
    }
    $PoorMediaReport = @()
    $PoorMediaReportName = $config.ReportPath + "\" + $config.Account + "_" + $($config.BackupServer) + "_" + "ResetPoorMedia" + "_" + $ReportDate + ".csv"
    $OSType = $config.OsType
    $BackupDevice = $config.BackupServer -split ";"
    Write-Log -Path $Activitylog -Entry "Operating System : $OSType" -Type Information -ShowOnConsole
    if($OSType)
    {
        if($OSType -eq "Windows")
        {
            $DetailPoolCommand = $config.Command3Windows
            $DetailPoolCommandOutput = Invoke-DPCommandWindows -command "$DetailPoolCommand" -logFile $Activitylog
            $Pools = Get-DeatiledPools -InputObject $DetailPoolCommandOutput
            $Pools = @()
            foreach($InputPool in $InputPools)
            {
                $Pools += $TotalPools | Where-Object{$_.'Pool Name' -eq "$InputPool"}
            }
            if($Pools)
            {
                Write-Log -Path $Activitylog -Entry "Below are the list of Poor and Fair Pools`n" -Type Information -ShowOnConsole
                Write-Log -Path $Activitylog -Entry "$($Pools|out-string)" -Type Information -ShowOnConsole
                foreach($Pool in $Pools)
                {
                    $ListPoolCommand = $config.Command1Windows -replace "PoolName","$($Pool."Pool Name")"
                    $PoolsCommandOutput = Invoke-DPCommandWindows -command "$ListPoolCommand" -logFile $Activitylog 
                    $PoorPools = $PoolsCommandOutput | Select-String "Poor","Fair" 
                    if($PoorPools)
                    {
                        $PoorLabels = @()
                        foreach($PoorPool in $PoorPools)
                        {
                            $PoorLabelSplit = $PoorPool -split "\s" | where{$_}
                            if($PoorLabelSplit.count -eq 4)
                            {
                                $PoorLabel   = $PoorLabelSplit[1]
                                $PoorLabels += $PoorLabel
                            }
                            else
                            {
                                $PoorLabel   = $PoorLabelSplit[2]
                                $PoorLabels += $PoorLabel
                            }
                            $ResetCommand = $config.Command2Windows -replace "Label","$PoorLabel"
                            $Reset = Invoke-DPCommandWindows -command "$ResetCommand" -logFile $Activitylog
                        }
                        $PoolsCommandOutput = Invoke-DPCommandWindows -command "$ListPoolCommand" -logFile $Activitylog
                        foreach($PoorLabel in $PoorLabels)
                        {
                            $PoorPoolAfterReset  = $PoolsCommandOutput | Select-String "$PoorLabel"
                            $SplitAfterReset     = $PoorPoolAfterReset -split "\s" | where{$_}

                            $PoorMediaReport    += [PsCustomobject] @{
                            "Date"               = (Get-Date).ToString("dd-MM-yyyy hh:mm")
                            "BackupServer"       = "$($config.BackupServer)"
                            "PoolName"           = $Pool."Pool Name"
                            "Medium Label"       = $PoorLabel
                            "Status After Reset" = $SplitAfterReset[0]
                            }
                        }
                    }
                    else
                    {
                        Write-Log -Path $Activitylog -Entry "No Poor Labels available for $Pool" -Type Information -ShowOnConsole
                        $PoorMediaReport    += [PsCustomobject] @{
                        "Date"               = (Get-Date).ToString("dd-MM-yyyy hh:mm")
                        "BackupServer"       = $($config.BackupServer)
                        "PoolName"           = $Pool."Pool Name"
                        "Medium Label"       = "No Poor Labels"
                        "Status After Reset" = "No Poor Labels"
                        }
                    }
                }
            }
            else
            {
                Write-Log -Path $Activitylog -Entry "No Poor and Fair Pools available" -Type Information -ShowOnConsole
            }
        }
        else
        {
            $PoorMediaReportName = $config.ReportPath + "\" + $config.Account + "_" + $BackupDevice[1] + "_" + "ResetPoorMedia" + "_" + $ReportDate + ".csv"
            Import-Module ".\Posh-Ssh\Posh-SSH.psd1"
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
            $Session = New-PoshSession -IpAddress $BackupDevice[0] -Credential $Credential
            if($Session.connected -eq "True")
            {
                $DetailPoolCommand = $config.Command3NonWindows
                $DetailPoolCommandOutput = Invoke-DPCommandNonWindows -SshSessionId $Session.SessionId -command "$DetailPoolCommand" -logFile $Activitylog 
                $TotalPools = Get-DeatiledPools -InputObject $DetailPoolCommandOutput
                $Pools = @()
                foreach($InputPool in $InputPools)
                {
                    $Pools += $TotalPools | Where-Object{$_.'Pool Name' -eq "$InputPool"}
                }
                if($Pools)
                {
                    Write-Log -Path $Activitylog -Entry "Below are the list of Poor and Fair Pools`n" -Type Information -ShowOnConsole
                    Write-Log -Path $Activitylog -Entry "$($Pools|out-string)" -Type Information -ShowOnConsole
                    foreach($Pool in $Pools)
                    {
                        $ListPoolCommand = $config.Command1NonWindows -replace "PoolName","$($Pool."Pool Name")"
                        $PoolsCommandOutput = Invoke-DPCommandNonWindows -SshSessionId $Session.SessionId -command "$ListPoolCommand" -logFile $Activitylog 
                        $PoorPools = $PoolsCommandOutput | Select-String "Poor","Fair" 
                        if($PoorPools)
                        {
                            $PoorLabels = @()
                            foreach($PoorPool in $PoorPools)
                            {
                                $PoorLabelSplit = $PoorPool -split "\s" | where{$_}
                                if($PoorLabelSplit.count -eq 4)
                                {
                                    $PoorLabel   = $PoorLabelSplit[1]
                                    $PoorLabels += $PoorLabel
                                }
                                else
                                {
                                    $PoorLabel   = $PoorLabelSplit[2]
                                    $PoorLabels += $PoorLabel
                                }
                                $ResetCommand = $config.Command2NonWindows -replace "Label","$PoorLabel"
                                $Reset = Invoke-DPCommandNonWindows -SshSessionId $Session.SessionId -command "$ResetCommand" -logFile $Activitylog  
                            }
                            $PoolsCommandOutput = Invoke-DPCommandNonWindows -SshSessionId $Session.SessionId -command "$ListPoolCommand" -logFile $Activitylog   
                            foreach($PoorLabel in $PoorLabels)
                            {
                                $PoorPoolAfterReset  = $PoolsCommandOutput | Select-String "$PoorLabel"
                                $SplitAfterReset     = $PoorPoolAfterReset -split "\s" | where{$_}

                                $PoorMediaReport    += [PsCustomobject] @{
                                "Date"               = (Get-Date).ToString("dd-MM-yyyy hh:mm")
                                "BackupServer"       = $BackupDevice[1]
                                "PoolName"           = $Pool."Pool Name"
                                "Medium Label"       = $PoorLabel
                                "Status After Reset" = $SplitAfterReset[0]
                                }
                            }
                        }
                        else
                        {
                            Write-Log -Path $Activitylog -Entry "No Poor Labels available for $Pool.." -Type Information -ShowOnConsole
                            $PoorMediaReport    += [PsCustomobject] @{
                            "Date"               = (Get-Date).ToString("dd-MM-yyyy hh:mm")
                            "BackupServer"       = $BackupDevice[1]
                            "PoolName"           = $Pool."Pool Name"
                            "Medium Label"       = "No Poor Labels"
                            "Status After Reset" = "No Poor Labels"
                            }
                        }
                    }
                }
                else
                {
                    Write-Log -Path $Activitylog -Entry "No Poor and Fair Pools available" -Type Information -ShowOnConsole
                }
            }
            else
            {
                Write-Log -Path $Activitylog -Entry "Failed to Connect to $($BackupDevice[1])" -Type Error -ShowOnConsole
            }
        }
    }
    else
    {
        Write-Log -Path $Activitylog -Entry "Invalid OSType!" -Type Error -ShowOnConsole
    }
    $PoorMediaReport | Export-Csv -Path $PoorMediaReportName -NoTypeInformation
    if($config.SendEmail -eq "Yes")
    {
        $attachment = @()
        $attachment += $PoorMediaReportName
        $sendMailMessageParameters = @{
            To          = $config.mail.To.Split(";")
            from        = $config.mail.From 
            Subject     = "$($config.mail.Subject)"    
            BodyAsHtml  = $true
            SMTPServer  = $config.mail.smtpServer             
            ErrorAction = 'Stop'
            Port        = $config.mail.port
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
        $body += "<p>Hi, <br><br>&nbsp&nbsp&nbsp&nbspPlease find the Report.</p>"
        #$body += $PoorMediaReport | ConvertTo-Html -Head $css
        $body += "<br>Thanks,<br>Automation Team<br>"
        $body += "<p style=`"color: red; font-size: 12px`">***This is an auto generated mail. Please do not reply.***</p>"
        $sendMailMessageParameters.Add("Body", $Body)
        try
        {
            Write-Log -Path $Activitylog -Entry "Sending Email, Please wait..." -Type Information -ShowOnConsole
            Send-MailMessage @sendMailMessageParameters
            Write-Log -Path $Activitylog -Entry "Email Sent!" -Type Information -ShowOnConsole
        }
        catch
        {
            $comment = $_ | Format-List -Force 
            Write-Log -Path $Activitylog -Entry  "Failed to send the mail" -Type Error -ShowOnConsole
            Write-Log -Path $Activitylog -Entry  $comment -Type Exception 
        }
    }
}
else
{
    Write-Log -Path $Activitylog -Entry "Invalid $ConfigFile!" -Type Error -ShowOnConsole
}
Write-Log -Path $Activitylog -Entry "Completed" -Type Information -ShowOnConsole