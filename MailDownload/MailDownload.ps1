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
            $ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
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

$config = Get-Config -ConfigFile $ConfigFile

if($config)
{

    $DownloadPathFlag, $DownloadPath = New-DownloadFolder -Path "tmpFiles"
    if($DownloadPathFlag)
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
    }
    else
    {
        Write-Warning "Error in Download Path"
    }

}
else
{
    Write-Warning "Could Not Find Config File $ConfigFile"
}