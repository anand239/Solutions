<#
.SYNOPSIS
  Get-DPHungBackupReport.ps1
    
.NOTES
  Script:         Space-Cleanup_v_0.1.0.ps1
  Author:         Chintalapudi Anand Vardhan
  Requirements :  Powershell v3.0
  Creation Date:  06/02/2023
  Modified Date:  06/02/2023 

  .History:
        Version Date            Author                       Description        
        1.0.0     06/02/2023      Chintalapudi Anand Vardhan   Initial Release
.EXAMPLE
  Script Usage 

  .\Get-DPHungBackupReport.ps1 -configfile "config.json"
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
            Subject     = "$($config.mail.Subject) at on $servername $(Get-Date -Format 'dd-MMM-yyyy - HH:mm:ss')"      
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
    $sendMailMessageParameters.Add("Body", $MailMessage)
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

Function Get-BackupStatus
{
    [CmdletBinding()]
    Param(
    $InputObject
    )
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
            
                $Queuing_Object += $obj
            }
            $Queuing_Object
        }
}

Function Get-HungObject
{
    [CmdletBinding()]
    Param(
    #[parameter(Mandatory = $true)]
    $InputObject
    )
    $InputObject = $InputObject | where{$_}
    $HUNG_Object = @()
    for($i=0;$i -lt $InputObject.Count;$i+=12)
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

$css = @"
<style>
h1, h5, th { font-size: 11px;text-align: center; font-family: Segoe UI; }
table { margin: auto; font-family: Segoe UI; box-shadow: 10px 10px 5px #888; border: thin ridge grey; }
th { background: #5F249F; color: #fff; max-width: 200px; padding: 5px 10px; }
td { border: 1px solid black;font-size: 11px;text-align: center; padding: 5px 20px; color: #000; }
tr:nth-child(even) {background: #dae5f4;}
tr:nth-child(odd) {background: #b8d1f3;}
</style>
"@


$config = Get-Config -ConfigFile $ConfigFile
$Activitylog = "Activity.log"
Write-Log -Path $Activitylog -Entry "Started" -Type Information -ShowOnConsole -OverWrite
Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "Host: $($env:COMPUTERNAME)" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "User: $($env:USERNAME)" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole

if($Config)
{
    $servername = hostname
    $Backup_Output = omnistat -detail

    if($Backup_Output)
    {
        $Backup_Result = @(Get-BackupStatus -InputObject $Backup_Output)
    }
    else
    {
        Write-Log -Path $Activitylog -Entry "Unable to omnistat -detail output" -Type warning -ShowOnConsole 
        exit
    }
    ### Hung Backup First Time #########
    if(!("No currently running sessions." -in $Backup_Result))
    {
        $Hung_input1 = @()
        $Hung_object = $Backup_Result | where-object{($_.'session Type' -eq "Backup") -and ($_.SessionId -notlike "R*")} | where{$_}
        if(!($Hung_object))
        {
            Write-Log -Path $Activitylog -Entry "No backups running with session type as Backup." -Type warning -ShowOnConsole 
            exit
        }
        foreach($line in $Hung_object)
        {
            $session_id = $line.sessionid
            $command = "omnidb -rpt SessionId -detail" -replace "SessionId",$session_id
            $Hung_input1 += Invoke-Expression -Command $command
        }
        $HUNG_Output1 = Get-HungObject -InputObject $Hung_input1
        $FirstTime = Get-Date
    }
    else
    {
        Write-Log -Path $Activitylog -Entry "No currently running sessions." -Type warning -ShowOnConsole 
        exit
    }


    Start-Sleep -Seconds 300

    ##### Hung Backup 2nd Time   #####
    $Hung_input2 = @()
    foreach($line in $Hung_object)
    {
        $session_id = $line.sessionid
        $command = "omnidb -rpt SessionId -detail" -replace "SessionId",$session_id
        $Hung_input2 += Invoke-Expression -Command $command
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
    if($HUNG_Output)
    {
        $body = ""
        $body += "<p>Hi, <br><br>&nbsp&nbsp&nbsp&nbspPlease find DP HungBackup Report.</p>"
        $body += $HUNG_Output | ConvertTo-Html -Head $css
        $body += "<br>Thanks,<br>Automation Team<br>"
        $body += "<p style=`"color: red; font-size: 12px`">***This is an auto generated mail. Please do not reply.***</p>"
        Send-Mail -MailMessage $Body
    }
}
else
{
    Write-Log -Path $Activitylog -Entry "Invalid $ConfigFile" -Type Error -ShowOnConsole
}
Write-Log -Path $Activitylog -Entry "Completed" -Type Information -ShowOnConsole
