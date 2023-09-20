##[Ps1 To Exe]
##
##Kd3HDZOFADWE8uO1
##Nc3NCtDXTlaDjuL9x2VLzEjhTFQPVubbkLWoys+1/OWM
##Kd3HFJGZHWLWoLaVvnQnhQ==
##LM/RF4eFHHGZ7/K1
##K8rLFtDXTiW5
##OsHQCZGeTiiZ4NI=
##OcrLFtDXTiW5
##LM/BD5WYTiiZ4tI=
##McvWDJ+OTiiZ4tI=
##OMvOC56PFnzN8u+Vs1Q=
##M9jHFoeYB2Hc8u+Vs1Q=
##PdrWFpmIG2HcofKIo2QX
##OMfRFJyLFzWE8uK1
##KsfMAp/KUzWJ0g==
##OsfOAYaPHGbQvbyVvnQX
##LNzNAIWJGmPcoKHc7Do3uAuO
##LNzNAIWJGnvYv7eVvnQX
##M9zLA5mED3nfu77Q7TV64AuzAgg=
##NcDWAYKED3nfu77Q7TV64AuzAgg=
##OMvRB4KDHmHQvbyVvnQX
##P8HPFJGEFzWE8tI=
##KNzDAJWHD2fS8u+Vgw==
##P8HSHYKDCX3N8u+Vgw==
##LNzLEpGeC3fMu77Ro2k3hQ==
##L97HB5mLAnfMu77Ro2k3hQ==
##P8HPCZWEGmaZ7/K1
##L8/UAdDXTlaDjuL9x2VLzEjhTFQDTfq/uKWvxo697e6ivj3cKQ==
##Kc/BRM3KXhU=
##
##
##fd6a9f26a06ea3bc99616d4851b372ba
<#$
.SYNOPSIS
    Get-BackupHealthCheckConsolidatedReport.ps1

.DESCRIPTION
	Generates consolidated healthcheck summary report for all backup devices
	
.INPUTS
  Configfile
  config.json
  
.OUTPUTS
  HTML

.NOTES
  Script:         Get-BackupHealthCheckConsolidatedReport.ps1
  Author:         Veena S Navali  
  Requirements:   Powershell v3.0, Outlook, Psexcel MOdules
  Creation Date:  26-Nov-2021
  Modified Date:  26-Nov-2021
  Remarks      :  

  .History:
        Version Date            Author                Description        
        1.0     26-Nov-2021      Veena S Navali        Initial Release

.EXAMPLE
  Script Usage 

  .\Get-BackupHealthCheckConsolidatedReport.ps1 -ConfigFile .\config.json 
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [String] $ConfigFile
)

Function Get-Attachment
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $MailBox,
        [Parameter(Mandatory = $true)]
        $OutLookFolder,
        [Parameter(Mandatory = $true)]
        $SenderMailAddressList,
        [Parameter(Mandatory = $true)]
        $DownloadPath
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
            foreach ($senderMailAddress in $SenderMailAddressList)
            {
                $senderMail = $senderMailAddress -split "<"
                $todayReports = $ReportFolder.Items | Where-Object {$_.SentOnBehalfOfName.trim() -eq $senderMail[0].trim() -and $_.UnRead -eq $true}
                #$todayReports = $ReportFolder.Items | Where-Object {$_.SentOnBehalfOfName.trim() -eq $senderMail[0].trim() -and  $_.SentOn.Date -eq (Get-Date).Date -and $_.UnRead -eq $true} 
                foreach ($todayReport in $todayReports)
                {
                    $todayReport.attachments | ForEach-Object {
                        $path = Join-Path $DownloadPath $_.FileName
                        $_.saveasfile(($path))                      
                    }
                    $todayReport.UnRead = $false
                }
            }
        }
        else
        {
            $senderMail = $SenderMailAddressList[0] -split "<"
  		        $todayReports = $ReportFolder.Items | Where-Object {$_.SentOnBehalfOfName.trim() -eq $senderMail[0].trim() -and $_.UnRead -eq $true}
  		        #$todayReports = $ReportFolder.Items | Where-Object {$_.SentOnBehalfOfName.trim() -eq $senderMail[0].trim() -and  $_.SentOn.Date -eq (Get-Date).Date -and $_.UnRead -eq $true} 
  		        foreach ($todayReport in $todayReports)
  		        {
                $todayReport.attachments | ForEach-Object {
                    $path = Join-Path $DownloadPath $_.FileName 
                    $_.saveasfile(($path))
                }
                $todayReport.UnRead = $false
  		        }
        }
  
    }
    else
    {
        Write-Warning "Not received any report files"
    }
    if ($outlookWasAlreadyRunning -eq $false)
    {
        Get-Process "*outlook*" | Stop-Process –Force
    }
}

Function ConvertTo-BreadCrumb
{
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true)] $InputObject)
   
    $breadCrumb = "<ul class='breadcrumb'>"
    $count = $InputObject.count - 1

    for ($i = 0; $i -lt $count; $i++)
    {
        $breadCrumb += "<li><a href='$($InputObject[$i].Path)'>$($InputObject[$i].Name)</a></li>"
    }

    $breadCrumb += "<li>$($InputObject[$count].Name)</li>"
    $breadCrumb += "</ul><HR>"
    $breadCrumb
}

Function Get-SignalReport
{
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true)] $DownloadPath)

    $Signalresult = @()
    $inputList = Get-ChildItem -Path $DownloadPath -Filter "*_Signal_*.csv" -ErrorAction SilentlyContinue
    $Signalresult = $inputList | ForEach-Object { Import-Csv -Path $_.FullName}   
    $Signalresult = $Signalresult | Select-Object -Property *, 
    @{N = "StatusInt"; E = {
            if ($_.Status -eq 'G') { 0 }
            if ($_.Status -eq 'Y') { 1 }
            if ($_.Status -eq 'R') { 2 }
        }
    },
    @{N = "R-Count"; E = {
            if ($_.Status -eq 'G') { 0 }
            if ($_.Status -eq 'Y') { 0 }
            if ($_.Status -eq 'R') { 1 }
        }
    },
    @{N = "G-Count"; E = {
            if ($_.Status -eq 'G') { 1 }
            if ($_.Status -eq 'Y') { 0 }
            if ($_.Status -eq 'R') { 0 }
        }
    },
    @{N = "Y-Count"; E = {
            if ($_.Status -eq 'G') { 0 }
            if ($_.Status -eq 'Y') { 1 }
            if ($_.Status -eq 'R') { 0 }
        }
    }

    $Signalresult | Select-Object -Property ReportDate , BackupApplication, Account, BackupServer, HC_Parameter, HC_ShortName, Value, Percentage, Status, StatusInt , R-count, G-count, Y-count -Unique | Sort-Object -Property ReportDate , BackupApplication, Account, BackupServer, HC_Parameter, HC_ShortName

}

Function Get-SignalSummaryReport
{
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true)] $DownloadPath
    )
    $inputList = Get-ChildItem -Path $DownloadPath -Filter "*_SignalSummary_*.csv"  -ErrorAction SilentlyContinue
    $SignalSummary = $inputList | ForEach-Object { Import-Csv -Path $_.FullName}   
    $SignalSummary | select -Property * -Unique
}

Function New-HomePage
{
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true)] $InputObject
    )
    $StatusCodes = @("All Health Check parameters are green.",
        "One or more Health Check parameters are in warning.", 
        "One or more Health Check parameters are in critical.")
   
    $HomePageResult = $InputObject | Select-Object -Property "Account", "StatusCode" -Unique 
    
    $UniqueEntries = $HomePageResult  | Select-Object -ExpandProperty "Account" -Unique
    $HomePageSummary = @()
    foreach ($UniqueEntry in $UniqueEntries)
    {
        $SubHomePageResult = $HomePageResult | Where-Object { $_.Account -eq $UniqueEntry}
   
        $Status = ($SubHomePageResult | Select-Object StatusCode | Measure-Object  -Maximum "StatusCode").Maximum   
        $LinkPath = "Detail\$($UniqueEntry).html"

        $HomePageSummary += [PSCustomObject] @{
            "Account"        = "<a href='$($LinkPath)'>$UniqueEntry</a>"
            "Account Status" = "<span class='tooltip'>$($StatusCodes[$Status])</span>"
        }
    }
    [XML]$html = $HomePageSummary | ConvertTo-Html -Fragment
    $StatusColumn = 1 
    for ($i = 1; $i -le $html.table.tr.count - 1; $i++) 
    {
        $class = $html.CreateAttribute("class")
        
        if ($html.table.tr[$i].td[$StatusColumn].contains($StatusCodes[0]))
        {
            $class.value = "G tooltipCell"
            $html.table.tr[$i].childnodes[$StatusColumn].Attributes.Append($class) | Out-Null
        }
        elseif ($html.table.tr[$i].td[$StatusColumn].contains($StatusCodes[1]))
        {
            $class.value = "Y tooltipCell"
            $html.table.tr[$i].childnodes[$StatusColumn].Attributes.Append($class) | Out-Null
        }
        elseif ($html.table.tr[$i].td[$StatusColumn].contains($StatusCodes[2]))
        {
            $class.value = "R tooltipCell"
            $html.table.tr[$i].childnodes[$StatusColumn].Attributes.Append($class) | Out-Null
        }
              
    }
    $HomePagefragments = @"
      <header>
        <img src="LOGO.png" alt="logo" />
        <h1>Backup Health Check Dashboard</h1>
      </header>
"@
    $HomePagefragments += "<h2>Dashboard</h2><hr>"
    
    $HomePagefragments += $html.InnerXml
   
    $HomePagefragments = $HomePagefragments.Replace("<th>Account</th>", "<th width='80%'>Account</th>")
    $homePageBody = "<main>" + [System.Web.HttpUtility]::HtmlDecode($HomePagefragments) + "</main>"
    
    $homePageContent = $htmlStart + $head + "<body>" + $divStart + $homePageBody + $divEnd + "</body>" + $htmlEnd
    $homePageContent = $homePageContent -replace "<table>", "<table class='homepage'>"
    $homePageContent | Out-File -FilePath $HomePagePath -Encoding ascii  
}

Function New-AccountPage
{
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true)] $InputObject 
    )
    $Accounts = $InputObject | Select-Object -ExpandProperty Account -Unique
    Foreach ($Account in $Accounts)
    {
        $AccountItems = $InputObject | Where-Object {$_.account -eq $Account }
        $AccountBreadCrumbHash = @( 
            @{ 
                Name = "Dashboard"
                Path = $HomePageLinkPath
            },
          
            @{ 
                Name = $Account
                Path = ""
            })
        $AccountPageBreadCrumb = ConvertTo-BreadCrumb -InputObject  $AccountBreadCrumbHash
        
        $AccountPagePath = "$DetailReportPath\$($Account).html"
        $AccountPageItems = @()

        $BackupServers = $AccountItems | Select-Object -ExpandProperty  BackupServer -Unique
       
        foreach ($BackupServer in $BackupServers)
        {
            $ReportDate = ($AccountItems | Where-Object { $_.BackupServer -eq $BackupServer } | Select-Object -ExpandProperty ReportDate -Unique | Measure-Object -Maximum).Maximum
            $AccountPageItems += $AccountItems | Where-Object { $_.BackupServer -eq $BackupServer -and $_.ReportDate -eq $ReportDate} | 
            Select-Object -Property @{N = "Backup Server"; E = {"<a href='$("$($Account)_$($_.BackupServer).html")'>$($_.BackupServer)</a>" }}, 
            @{N = "Backup Application"; E = { ($config.BackupApplication."$($_.BackupApplication)")}},
            @{N = "Report Date"; E = {$_.ReportDate }}, 
            @{N = "HC-Critical"; E = { $_.'R-Count' }},
            @{N = "HC-Warning"; E = {  $_.'Y-Count' }}, 
            @{N = "HC-Green"; E = {$_.'G-Count'}}
        }
          
        [XML]$html = $AccountPageItems  | ConvertTo-Html -Fragment
         
        for ($i = 1; $i -le $html.table.tr.count - 1; $i++) 
        {
           
            if([int]$html.table.tr[$i].childnodes[3].InnerText -gt 0)
            {
                $rclass = $html.CreateAttribute("class")
                $rclass.value = "R"
                $html.table.tr[$i].childnodes[3].Attributes.Append($rclass) | Out-Null
            }
            else
            {
                $rclass = $html.CreateAttribute("class")
                $rclass.value = "D"
                $html.table.tr[$i].childnodes[3].Attributes.Append($rclass) | Out-Null

            }
            if([int]$html.table.tr[$i].childnodes[4].InnerText -gt 0)
            {
                $yclass = $html.CreateAttribute("class")
                $yclass.value = "Y"
                $html.table.tr[$i].childnodes[4].Attributes.Append($yclass) | Out-Null
            }
            else
            {
                $yclass = $html.CreateAttribute("class")
                $yclass.value = "D"
                $html.table.tr[$i].childnodes[4].Attributes.Append($yclass) | Out-Null
            }
            if([int]$html.table.tr[$i].childnodes[5].InnerText -gt 0)
            {
                $gclass = $html.CreateAttribute("class")
                $gclass.value = "G"
                $html.table.tr[$i].childnodes[5].Attributes.Append($gclass) | Out-Null     
            }    
            else
            {
                $gclass = $html.CreateAttribute("class")
                $gclass.value = "D"
                $html.table.tr[$i].childnodes[5].Attributes.Append($gclass) | Out-Null
            }                 
        }
        $AccountPagefragments = $html.InnerXml
        $AccountPageBody = "<main>" + [System.Web.HttpUtility]::HtmlDecode($AccountPagefragments) + "</main>"
        $AccountPageContent = $htmlStart + $head + "<body>" + $divStart + $CommonPagefragments + $AccountPageBreadCrumb + $AccountPageBody + $divEnd + "</body>" + $htmlEnd
        $AccountPageContent = $AccountPageContent -replace "<table>", "<table class='Account'>"
        $AccountPageContent | Out-File -FilePath $AccountPagePath -Encoding ascii  
    }

}

Function New-BackupServerPage
{
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true)] $InputObject 
    )
    #$InputObject = $SignalReport
    $Accounts = $InputObject | Select-Object -ExpandProperty Account -Unique
    # $Account = $Accounts[0]
    foreach ($Account in $Accounts)
    {
        $AccountItems = $InputObject | Where-Object { $_.Account -eq $Account } 
        $AccountLinkPath = "$($Account).html"
 
        $BackupServers = $AccountItems | Select-Object -ExpandProperty BackupServer -Unique
        foreach ( $BackupServer in  $BackupServers)
        {
            $ReportDate = ($AccountItems | Where-Object {$_.BackupServer -eq $BackupServer } | Select-Object -ExpandProperty ReportDate -Unique | Measure-Object -Maximum).Maximum
            $ReportDateInFile = ([DateTime]$ReportDate).Tostring("ddMMMyy_HHmm",$culture)

            $BackupServerItemList = $AccountItems | Where-Object { $_.BackupServer -eq $BackupServer -and $_.ReportDate -eq $ReportDate}
            $BackupApplication = $BackupServerItemList | Select-Object -ExpandProperty BackupApplication -Unique 
            
            $SourceSignalReportName = Join-Path $config.ReportFolder  "$($BackupApplication)_$($Account)_$($BackupServer)_signal_$($ReportDateInFile).csv"
            $SourceSignalSummaryReportName = Join-Path $config.ReportFolder "$($BackupApplication)_$($Account)_$($BackupServer)_SignalSummary_$($ReportDateInFile).csv"
         
            $DestinationSignalReportName = Join-Path $config.RepositoryFolder "$($BackupApplication)_$($Account)_$($BackupServer)_signal_.csv"
            $DestinationSignalSummaryReportName = Join-Path $config.RepositoryFolder "$($BackupApplication)_$($Account)_$($BackupServer)_SignalSummary_.csv"

            if (Test-Path $SourceSignalReportName)
            {
                Copy-Item -Path $SourceSignalReportName $DestinationSignalReportName -Force 
            }
            if (Test-Path $SourceSignalSummaryReportName)
            {
                Copy-Item -Path $SourceSignalSummaryReportName $DestinationSignalSummaryReportName -Force
            }
            
            $BackupServerPagePath = "$DetailReportPath\$($Account)_$($BackupServer).html"
            $BackupServerItems = $BackupServerItemList |
            Select-Object -Property  @{N = "HC_Parameter"; E = {"<a href='$("$($_.BackupApplication)_$($Account)_$($BackupServer)_$($_.HC_ShortName).html")'>$($_.HC_Parameter)</a>" }}, Value, Percentage, Status 
            [XML]$html = $BackupServerItems  | ConvertTo-Html -Fragment
            $StatusColumn = 3
            for ($i = 1; $i -le $html.table.tr.count - 1; $i++) 
            {
                $class = $html.CreateAttribute("class")
                if ($html.table.tr[$i].td[$StatusColumn] -eq 'G')
                {
                    $class.value = "G"
                    $html.table.tr[$i].childnodes[$StatusColumn].Attributes.Append($class) | Out-Null
                }
                elseif ($html.table.tr[$i].td[$StatusColumn] -eq 'Y')
                {
                    $class.value = "Y"
                    $html.table.tr[$i].childnodes[$StatusColumn].Attributes.Append($class) | Out-Null
                }
                elseif ($html.table.tr[$i].td[$StatusColumn] -eq 'R')
                {
                    $class.value = "R"
                    $html.table.tr[$i].childnodes[$StatusColumn].Attributes.Append($class) | Out-Null
                }
                elseif ($html.table.tr[$i].td[$StatusColumn] -eq 'D')
                {
                    $class.value = "D"
                    $html.table.tr[$i].childnodes[$StatusColumn].Attributes.Append($class) | Out-Null
                }   
            }
            $BackupServerBreadCrumbHash = @( 
                @{ 
                    Name = "Dashboard"
                    Path = $HomePageLinkPath
                },
                @{ 
                    Name = $Account
                    Path = $AccountLinkPath
                },
                @{ 
                    Name = $BackupServer
                    Path = ""
                }
            )
            $BackupServerPageBreadCrumb = ConvertTo-BreadCrumb -InputObject  $BackupServerBreadCrumbHash
            $BackupServerPagefragments = $html.InnerXml
            $BackupServerPageBody = "<main>" + [System.Web.HttpUtility]::HtmlDecode($BackupServerPagefragments) + "</main>"
            $BackupServerPageContent = $htmlStart + $head + "<body>" + $divStart + $CommonPagefragments + $BackupServerPageBreadCrumb + $BackupServerPageBody + $divEnd + "</body>" + $htmlEnd
            $BackupServerPageContent = $BackupServerPageContent -replace "<table>", "<table class='BackupServer'>"
            $BackupServerPageContent | Out-File -FilePath $BackupServerPagePath -Encoding ascii
        }         
    }
}

Function New-DetailPage
{
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true)] $InputObject 
    )
    $DetailReportExcludeProperties = "Technology", "ReportType", "BackupApplication", "ReportDate", "HC_Parameter", "Account", "BackupServer"
    $Accounts = $InputObject | Select-Object -ExpandProperty Account -Unique
    foreach ($Account in $Accounts)
    {
        $AccountItems = $InputObject | Where-Object { $_.Account -eq $Account }
        $AccountLinkPath = "$($Account).html"
   
        $BackupServers = $AccountItems | Select-Object -ExpandProperty BackupServer -Unique
               
        foreach ( $BackupServer in  $BackupServers)
        { 
            $ReportDate = ($AccountItems | Where-Object {$_.BackupServer -eq $BackupServer } | Select-Object -ExpandProperty ReportDate -Unique | Measure-Object -Maximum).Maximum
            $ReportDateInFile = ([DateTime]$ReportDate).Tostring("ddMMMyy_HHmm",$culture)   
            $BackupServerLinkPath = "$($Account)_$($BackupServer).html"
            $BackupServerItems = $AccountItems | Where-Object { $_.BackupServer -eq $BackupServer -and $_.reportDate -eq $ReportDate } 
            foreach ( $BackupServerItem in  $BackupServerItems)
            {                 
                    
                $Detailfile = Get-ChildItem -Path $downloadPath -Filter "$($BackupServerItem.BackupApplication)_$($Account)_$($BackupServer)_$($BackupServerItem.HC_ShortName)_$($ReportDateInFile).csv"
                if ($Detailfile)                                                                                                     
                {
                    Copy-Item -Path $Detailfile.FullName -Destination (Join-Path -Path $config.RepositoryFolder -ChildPath "$($BackupServerItem.BackupApplication)_$($Account)_$($BackupServer)_$($BackupServerItem.HC_ShortName).csv" ) -Force
                    $DetailPageBreadCrumbHash = @( 
                        @{ 
                            Name = "Dashboard"
                            Path = $HomePageLinkPath
                        }
                        ,
                        @{ 
                            Name = $Account
                            Path = $AccountLinkPath
                        },
                        @{ 
                            Name = $BackupServer
                            Path = $BackupServerLinkPath
                        }
                        ,
                        @{ 
                            Name = $BackupServerItem.HC_Parameter
                            Path = ""
                        }
                    )

                    $DetailfileName = $Detailfile.Name -Replace "_$($ReportDateInFile).csv",".html"
                    $DetailPagehtmlfile = "$($DetailReportPath)\$($DetailfileName)"
                    $DetailPageBreadCrumb = ConvertTo-BreadCrumb -InputObject  $DetailPageBreadCrumbHash 
                                   
                    $DetailPagefragments = Import-Csv -Path $Detailfile.FullName | Select-Object -ExcludeProperty $DetailReportExcludeProperties -Property * | ConvertTo-Html -Fragment
                    $DetailPageBody = "<main>" + $DetailPagefragments + "</main>" 
                    $DetailPageContent = $htmlStart + $head + "<body>" + $divStart + $CommonPagefragments + $DetailPageBreadCrumb + $DetailPageBody + $divEnd + "</body>" + $htmlEnd 
                    $DetailPageContent | Out-File -FilePath $DetailPagehtmlfile -Encoding ascii  
                }
                else                                                                                                   
                {
                    $Detailfile = Get-ChildItem -Path $config.RepositoryFolder -Filter "$($BackupServerItem.BackupApplication)_$($Account)_$($BackupServer)_$($BackupServerItem.HC_ShortName).csv"
                    $DetailPageBreadCrumbHash = @( 
                        @{ 
                            Name = "Dashboard"
                            Path = $HomePageLinkPath
                        }
                        ,
                        @{ 
                            Name = $Account
                            Path = $AccountLinkPath
                        },
                        @{ 
                            Name = $BackupServer
                            Path = $BackupServerLinkPath
                        }
                        ,
                        @{ 
                            Name = $BackupServerItem.HC_Parameter
                            Path = ""
                        }
                    )
                    $DetailfileName = $Detailfile.Name -Replace ".csv",".html"
                    $DetailPagehtmlfile = "$($DetailReportPath)\$($DetailfileName)"
                    $DetailPageBreadCrumb = ConvertTo-BreadCrumb -InputObject  $DetailPageBreadCrumbHash 
                                   
                    $DetailPagefragments = Import-Csv -Path $Detailfile.FullName | Select-Object -ExcludeProperty $DetailReportExcludeProperties -Property * | ConvertTo-Html -Fragment
                    $DetailPageBody = "<main>" + $DetailPagefragments + "</main>" 
                    $DetailPageContent = $htmlStart + $head + "<body>" + $divStart + $CommonPagefragments + $DetailPageBreadCrumb + $DetailPageBody + $divEnd + "</body>" + $htmlEnd 
                    $DetailPageContent | Out-File -FilePath $DetailPagehtmlfile -Encoding ascii  
                }
            }
        }
    }
}

function New-DownloadFolder
{
    Param (
        [Parameter(Mandatory = $True)]
        [String]$Path
    )
    $CheckFlag = $True
    try
    {
            
        if ([System.IO.Path]::IsPathRooted($Path))
        {
            $DownloadPath = $Path 
        }
        else
        {
            $ScriptDir = (Get-Location).Path
            #$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
            $DownloadPath = Join-Path $ScriptDir -ChildPath $Path
        }
        
        if (!(Test-Path -Path $DownloadPath))
        { 
            New-Item -ItemType directory -Path $DownloadPath -ErrorAction Stop | Out-Null
        } 
    }
    catch
    {
        Write-Warning $_.Exception.InnerException.Message
        $CheckFlag = $False
    }
    $CheckFlag, $DownloadPath
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

$Activitylog = "Activity.log"
$culture = [CultureInfo]'en-us'

Check-Access

   
#Main Script 
$htmlStart = @"
<!DOCTYPE html>
<html lang="en">
"@
$htmlEnd = @"
</html>
"@
$divStart = @"
    <div class="container">
"@
$divEnd = @"
    </div>
"@ 
$head = @"
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Backup Health Check</title>
    <style>
    $(Get-Content -Path Styles.css)
    </style>
  </head>
"@
$HomePageLinkPath = "../Index.html"

if (Test-Path -Path $ConfigFile )
{
  
    try
    {
        $config = Get-Content -Path $ConfigFile -Raw -ErrorAction Stop | ConvertFrom-Json
    
        if ( $config)
        {
            $HomePagePath = "$($config.DashboardFolder)\Index.html"	
            $DetailReportPath = Join-Path -Path $config.DashboardFolder -ChildPath Detail
            $DownloadPathFlag, $DownloadPath = New-DownloadFolder -Path $config.ReportFolder
            #Anand# $DownloadPathFlag, $DownloadPath = New-DownloadFolder -Path "tmpFiles"
            if ($DownloadPathFlag )
            {
                if ($config.DownloadFromOutLook -eq "yes")
                {
                    Add-Type -AssemblyName System.Web
                    $DownloadAttachmentParameter = @{
                        MailBox           = $config.mailbox
                        OutLookFolder     = $config.mailLocation
                        SenderMailAddress = $config.senderMailAddress
                        DownloadPath      = $DownloadPath
                    }
                    Get-Attachment @DownloadAttachmentParameter
                }
                $inputList = @()
                if (Test-Path  $DownloadPath)
                {
                    $inputList += Get-ChildItem -Path $DownloadPath -Filter "*.csv"
                }
                if ( Test-Path $config.RepositoryFolder)
                {
                    $inputList += Get-ChildItem -Path $config.RepositoryFolder -Filter "*.csv"
                }
                if ($inputList)
                {

                    $SignalReport = Get-SignalReport -DownloadPath $DownloadPath, $config.RepositoryFolder               
                    $SignalSummaryReport = Get-SignalSummaryReport -DownloadPath $DownloadPath, $config.RepositoryFolder
                    $CommonPagefragments = @"
      <header>
        <img src="../LOGO.png" alt="logo" />
        <h1>Backup Health Check Dashboard</h1>
      </header>
"@
                    if ($SignalReport)
                    {
                        if ((Test-Path -Path $config.DashboardFolder))
                        { 
                            Remove-Item -Path $config.DashboardFolder -Recurse
                        }
                        New-Item -ItemType Directory -Path $config.DashboardFolder -ErrorAction SilentlyContinue | Out-Null
                        New-Item -ItemType Directory -Path $DetailReportPath -ErrorAction SilentlyContinue  | Out-Null
                        New-Item -ItemType Directory -Path $config.RepositoryFolder -ErrorAction SilentlyContinue  | Out-Null
                        Copy-Item -Path "Logo.png" -Container $config.DashboardFolder -ErrorAction SilentlyContinue  | Out-Null                                  
                        New-HomePage -InputObject $SignalSummaryReport
                        New-AccountPage -InputObject $SignalSummaryReport
                        New-BackupServerPage -InputObject $SignalReport
                        New-DetailPage -InputObject $SignalReport
                        Invoke-Item -Path $HomePagePath
                        #Remove-Item ($downloadPath + "\*.csv")
                    }               
                }
                else
                {
                    Write-Warning "No report files in $DownloadPath or in $($config.RepositoryFolder)"
                }
            }
            else
            {
                Write-Warning "Error in Download Path"
            }
        }
    }
    catch
    {
        Write-Warning $_
    }
}
else
{
    Write-Warning "Could Not Find Config File $ConfigFile"
}