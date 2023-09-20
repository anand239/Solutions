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

$config = Get-Config -ConfigFile $ConfigFile


$mail1 = Import-Csv $config.InputSheetPath
$mail2 = Import-Csv $config.MailSheetPath
$err = $mail2 | ? {$_.'Error code' -ne "0" -and $_.'Error code' -ne "" } | sort 'client','Schedule','Job' -Unique
Write-Host "*****Started*****" -ForegroundColor Green
foreach($line in $err)
{   
    $x = (($line.Client).Substring(0,8)).trim()
    $out = $mail1 | Where-Object {($_.client -like "$x*") -and ($_.schedule -eq $line.Schedule) -and ($_.job -eq $line.Job)}
    if($out)
    {
    ($mail1 | Where-Object {($_.client -like "$x*") -and ($_.schedule -eq $line.Schedule) -and ($_.job -eq $line.Job)}).status = $line.Status
    ($mail1 | Where-Object {($_.client -like "$x*") -and ($_.schedule -eq $line.Schedule) -and ($_.job -eq $line.Job)}).'Error Code' = $line.'Error Code'
    ($mail1 | Where-Object {($_.client -like "$x*") -and ($_.schedule -eq $line.Schedule) -and ($_.job -eq $line.Job)}).'Error Code Summary' = $line.'Error Code Summary'
    ($mail1 | Where-Object {($_.client -like "$x*") -and ($_.schedule -eq $line.Schedule) -and ($_.job -eq $line.Job)}).'Status Code' = $line.'Status Code'
    ($mail1 | Where-Object {($_.client -like "$x*") -and ($_.schedule -eq $line.Schedule) -and ($_.job -eq $line.Job)}).'Status Code Summary' = $line.'Status Code Summary'
    }
}

$mail1 |export-csv $config.InputSheetPath -NoTypeInformation

Write-Host "*****Completed*****" -ForegroundColor Green
