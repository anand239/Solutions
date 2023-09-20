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

if($config)
{
    $mail1 = Import-Csv $config.InputSheetPath
    $mail2 = Import-Csv $config.MailSheetPath

    $Mail1_Failures = $mail1 | Where-Object {$_.status -eq "Failed"}
    foreach($failure in $Mail1_Failures)
    {
        $Failed_Client = (($failure.Client).Substring(0,8)).trim()
        $res = $mail2 | Where-Object {($_.client -like "$Failed_Client*") -and ($_.schedule -eq $failure.Schedule) -and ($_.job -eq $failure.Job)}
        if($res)
        {
        
            if($failure.status -ne $res.status -or $failure.'Error Code' -ne $res.'Error Code')
            {
                ($mail1 | Where-Object {($_.client -like "$Failed_Client*") -and ($_.schedule -eq $failure.Schedule) -and ($_.job -eq $failure.Job)}).status = $res.Status
                ($mail1 | Where-Object {($_.client -like "$Failed_Client*") -and ($_.schedule -eq $failure.Schedule) -and ($_.job -eq $failure.Job)}).'Error Code' = $res.'Error Code'
                ($mail1 | Where-Object {($_.client -like "$Failed_Client*") -and ($_.schedule -eq $failure.Schedule) -and ($_.job -eq $failure.Job)}).'Error Code Summary' = $res.'Error Code Summary'
                ($mail1 | Where-Object {($_.client -like "$Failed_Client*") -and ($_.schedule -eq $failure.Schedule) -and ($_.job -eq $failure.Job)}).'Status Code' = $res.'Status Code'
                ($mail1 | Where-Object {($_.client -like "$Failed_Client*") -and ($_.schedule -eq $failure.Schedule) -and ($_.job -eq $failure.Job)}).'Status Code Summary' = $res.'Status Code Summary'
            }
        }
    }

    $mail1 |export-csv $config.InputSheetPath -NoTypeInformation



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
}
else
{
    Write-Host "Invalid $ConfigFile" -BackgroundColor Red
}
