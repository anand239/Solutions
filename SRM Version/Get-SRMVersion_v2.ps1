﻿<#
.SYNOPSIS
  Get-SRMVersion.ps1
    
.INPUTS
  Configfile
  config.json
   
.NOTES
  Script:         Get-SRMVersion.ps1
  Author:         Chintalapudi Anand Vardhan
  Requirements :  Powershell v3.0
  Creation Date:  28/07/2023
  Modified Date:  28/07/2023 

  .History:
        Version Date            Author                       Description        
        1.0     28/07/2023      Chintalapudi Anand Vardhan   Initial Release
.EXAMPLE
  Script Usage 

  .\Get-SRMVersion -ConfigFile .\config.json
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

Function Get-Reports
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $MailBox,
        [Parameter(Mandatory = $true)]
        $OutLookFolder,
        [Parameter(Mandatory = $true)]
        $SenderMailAddressList
    )
    Add-Type -assembly "Microsoft.Office.Interop.Outlook"
    Add-Type -assembly "System.Runtime.Interopservices"
    try
    {
        $outlook = [Runtime.Interopservices.Marshal]::GetActiveObject('Outlook.Application')
        $outlookWasAlreadyRunning = $true
    }
    catch
    {
        try
        {
            $Outlook = New-Object -ComObject Outlook.Application
            $outlookWasAlreadyRunning = $false
        }
        catch
        {
            Write-Host "You must exit Outlook first."
            exit
        }
    }
    $namespace = $Outlook.GetNameSpace("MAPI")
    $ReportFolderPath = $OutLookFolder -split "\\"
    try
    {
        $ReportFolder = $namespace.Folders.Item($MailBox)
        if ($ReportFolder)
        {
            foreach ($ReportFolderName in $ReportFolderPath)
            {
                $SubFolders = $ReportFolder.Folders
                $ReportFolder = $SubFolders.item($ReportFolderName)
            }
        }  
    }
    catch
    {
        $ReportFolder = $null
    }
    if ($ReportFolder)
    {
        
        if ($SenderMailAddressList.Count -gt 1)
        {
            foreach ($senderMailAddress in $SenderMailAddressList){}
            {
                $senderMail = $senderMailAddress -split "<"
                $todayReports = $ReportFolder.Items | Where-Object {$_.SentOnBehalfOfName.trim() -eq $senderMail[0].trim() -and $_.UnRead -eq $true}
                #$todayReports = $ReportFolder.Items | Where-Object {$_.SentOnBehalfOfName.trim() -eq $senderMail[0].trim() -and  $_.SentOn.Date -eq (Get-Date).Date -and $_.UnRead -eq $true} 
                $Unread = $todayReports | ForEach-Object{$_.unread = $false}
                $todayReports
            }
        }
        else
        {
            $senderMail = $SenderMailAddressList[0] -split "<"
  		        $todayReports = $ReportFolder.Items | Where-Object {$_.SentOnBehalfOfName.trim() -eq $senderMail[0].trim() -and $_.UnRead -eq $true}
  		        #$todayReports = $ReportFolder.Items | Where-Object {$_.SentOnBehalfOfName.trim() -eq $senderMail[0].trim() -and  $_.SentOn.Date -eq (Get-Date).Date -and $_.UnRead -eq $true} 
                $Unread = $todayReports | ForEach-Object{$_.unread = $false}
                $todayReports
        }
    }
    else
    {
        Write-Warning "Not received any reports"
    }
    if ($outlookWasAlreadyRunning -eq $false)
    {
        Get-Process "*outlook*" | Stop-Process –Force
    }
}

$config = Get-Config -ConfigFile $ConfigFile

if($config)
{
    Add-Type -AssemblyName System.Web
    $DownloadAttachmentParameter = @{
        MailBox           = $config.mailbox
        OutLookFolder     = $config.mailLocation
        SenderMailAddressList = $config.senderMailAddress
    }
    $Reports = Get-Reports @DownloadAttachmentParameter

    if($Reports)
    {

        $tableData = @()
        foreach($Report in $Reports)
        {
            $html = $Report.htmlbody

            $pattern = '(?s)<table[^>]*>.*?<\/table>'
            $matches = [regex]::Matches($html, $pattern)

            $MailDate = $Report.ReceivedTime
            $Subject = ((([regex]::Matches($matches[0].Value, '(?s)<b[^>]*>.*?<\/b>')).groups[0].value | Select-String -Pattern '<b[^>]*>(.*?)<\/b>' -AllMatches |  ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value })  -split "for")[1].trim()
        
            $secondTableHtml = $matches[2].Value -replace "Instances</b></th>","Instances</b></th></tr>"


            $rowPattern = '(?s)<tr[^>]*>(.*?)<\/tr>'
            $rowMatches = [regex]::Matches($secondTableHtml, $rowPattern) | select -Skip 1

            foreach($rowMatch in $rowMatches)
            {
                $rowHtml = $rowMatch.Groups[1].Value
                $rowCells = [regex]::Matches($rowHtml, '(?s)<td[^>]*>.*?<\/td>')
                $pattern = '<td[^>]*>(.*?)<\/td>'
                $colorpattern = 'tr bgcolor="(#(?:[0-9a-fA-F]{3}){1,2})"'
                $colormatch = [regex]::Match($rowMatch.Groups[0].Value, $colorpattern)

                $Colour = $colormatch.Groups[1].Value

                $Version         =  $rowCells[0].Value | Select-String -Pattern $pattern -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value }  | select -First 1
                $friendlyversion =  $rowCells[1].Value | Select-String -Pattern $pattern -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value }  | select -First 1
                $expiration      =  $rowCells[2].Value | Select-String -Pattern $pattern -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value }  | select -First 1
                $extended        =  $rowCells[3].Value | Select-String -Pattern $pattern -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value }  | select -First 1
                $instances       =  $rowCells[4].Value | Select-String -Pattern '<a[^>]*>(.*?)<\/a>' -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value }  | select -First 1
    
                $tableData += [pscustomobject]@{
                Solution           = $Subject
                Version            = $Version
                "Friendly Version" = $friendlyversion
                "Expiration Date"  = $expiration
                "Extended Support Date" = $extended
                "Instances"        = $instances
                Date               = $MailDate
                color = $Colour
                }
            }
        }
        $tabledata | where{$_.color -eq "#FF4D4D"} | select * -ExcludeProperty color | Export-Csv "SRMVersion.csv" -NoTypeInformation
    }
    else
    {
        Write-Host "No Reports Available to process" -ForegroundColor Red
    }
}
else
{
    Write-Host "Invalid $ConfigFile" -ForegroundColor Red
}