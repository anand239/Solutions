<#
.SYNOPSIS
  RPT_OBJDashboard.ps1
    
.INPUTS
  Configfile
  config.json
   
.NOTES
  Script:         RPT_OBJDashboard.ps1
  Author:         Chintalapudi Anand Vardhan
  Requirements :  Powershell v5.1 , PswriteHTML Module
  Creation Date:  28/01/2021
  Modified Date:  28/01/2021 

  .History:
        Version Date            Author                       Description        
        1.0     28/01/2021      Chintalapudi Anand Vardhan   Initial Release
.EXAMPLE
  Script Usage 

  .\RPT_OBJDashboard.ps1 -ConfigFile .\config.json
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

Function Send-Mail
{
    [CmdletBinding()]
    Param(
    $attachments
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
    }
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
$Activitylog = "Activity.log"
Write-Log -Path $Activitylog -Entry "Started"                             -Type Information -ShowOnConsole -OverWrite
Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "Host: $($env:COMPUTERNAME)"          -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "User: $($env:USERNAME)"              -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole

Check-Access

$Major = $PSVersionTable.PSVersion.Major
$Minor = $PSVersionTable.PSVersion.Minor

if(!((($Major -eq 5) -and ($Minor -ge 1)) -or (($Major -gt 5) -and ($Minor -ge 0))))
{
    Write-Log -Path $Activitylog -Entry "Unable to proceed as powershell version is lessthan 5.1" -Type Warning -ShowOnConsole
    exit
}
try
{
    Import-Module ".\PsWriteHTML\0.0.164\PSWriteHTML.psd1"
}
catch
{
    Write-Log -Path $Activitylog -Entry "Failed to import PSWriteHTML module" -Type Error -ShowOnConsole
    exit
}

if($config)
{
    if(!(Test-Path $($config.reportpath + "\Reports")))
    {
        try
        {
            New-Item -ItemType directory "$($config.reportpath + "\Reports")" -ErrorAction Stop | Out-Null
        }
        catch
        {
            Write-Log -Path $Activitylog -Entry "Unable to create Reports Folder" -Type Error -ShowOnConsole
            exit
        }
    }
    $OBJRepFiles = @()
    $OBJFilePaths = $config.OBJFilePath -split ";"
    foreach($OBJFilePath in $OBJFilePaths)
    {
        $OBJRepFiles += Get-ChildItem -Path "$OBJFilePath" -Filter "*.csv" | Where-Object{$_.Name -like "*_OBJREP_*"}
    }
    if($OBJRepFiles)
    {
        $OBJRepFilePaths = @()
        foreach($OBJRepFile in $OBJRepFiles)
        {
            $FileName = $OBJRepFile.Name -split "_"
            $FileDate = [datetime]($FileName.GetValue($FileName.Count - 1).split("."))[0]
            $OBJRepFilePaths += [pscustomobject] @{
            "Date"            = $FileDate
            "Month"           = $FileDate.ToString("MM")
            "Year"            = $FileDate.ToString("yyyy")
            "YearMonth"       = $FileDate.ToString("yyyy_MM")
            "FilePath"        = $OBJRepFile.FullName
            }
        }
        <#
        if ($config.deleteFilesOlderThanInDays -gt 0)
        {
            $DeleteDays = (Get-Date).AddDays($config.deleteFilesOlderThanInDays)
            ($OBJRepFilePaths | where{$_.date -lt $DeleteDays}).filepath | Remove-Item
        }#>
        if($config.Reportdays)
        {
            $RequiredDate = $config.Reportdays
            if(($config.Reportdays).Trim() -eq "ALL")
            {
                $ReportFiles = $OBJRepFilePaths
            }
            else
            {
                $ReportFiles = $OBJRepFilePaths | where{$_.YearMonth -eq $config.Reportdays}
            }
        }
        else
        {
            $RequiredDate = (Get-Date).AddDays(-1).ToString("yyyy_MM")
            $ReportFiles = $BSRRepFilePaths | where{$_.YearMonth -eq $RequiredDate}
        }

        $ConsolidatedOBJRep = @()

        foreach($ReportFile in $ReportFiles)
        {
            $ConsolidatedOBJRep += Import-Csv -Path $ReportFile.FilePath    
        }

        if($ConsolidatedOBJRep)
        {
            $ConsolidatedOBJReportName = $config.ReportPath + "\" + "Reports" + "\" + "Consolidated-BCR_Rep" + "_" + "$RequiredDate" + ".csv"
            $ConsolidatedOBJRep | Export-Csv -Path $ConsolidatedOBJReportName -NoTypeInformation
            $Consolidated_OBJReportName      = $config.ReportPath + "\" + "Reports" + "\" + "Consolidated-BCR_Report" + "_" + "$RequiredDate" + ".html"
        
            #$Uniquedates = ($ConsolidatedOBJRep| Sort-Object date -Descending | Select-Object date -Unique).date
            New-HTML -TitleText 'Reporting' -FilePath $Consolidated_OBJReportName  {
                New-htmllogo -LeftLogoString "data:image/png;base64,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"
                New-HTMLTabOptions -SlimTabs -SelectorColor "#5F249F"
                New-HTMLTab -Name 'Consolidated Report'{
                    New-HTMLContent -HeaderText 'OBJ Consolidated Report' -HeaderBackGroundColor "#5F249F"{
                        New-HTMLTable -ArrayOfObjects $ConsolidatedOBJRep -HideFooter  -DisableNewLine{
                        } -DisableSelect -DisableStateSave -ScrollX -PagingLength 10 -ScrollSizeY 300 -Buttons copyHtml5, excelHtml5, csvHtml5, pageLength, searchBuilder
                    }           
                }
            }
        }
        else
        {
            Write-Log -Path $Activitylog -Entry "Failed to import the data from csv files" -Type Warning -ShowOnConsole
        }
    }
    else
    {
        Write-Log -Path $Activitylog -Entry "No report files" -Type Warning -ShowOnConsole
    }
}
else
{
    Write-Log -Path $Activitylog -Entry "Invalid $ConfigFile" -Type Error -ShowOnConsole
}
Write-Log -Path $Activitylog -Entry "Completed" -Type Information -ShowOnConsole
