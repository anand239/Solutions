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
        $failurejob = ($failure.job -split "-")[0]
        $Failed_Client = (($failure.Client).Substring(0,8)).trim()
        $res = $mail2 | Where-Object {($_.client -like "$Failed_Client*") -and ($_.schedule -eq $failure.Schedule) -and ($_.job -like "$failurejob*")}
        if($res)
        {
        
            if($failure.status -ne $res.status -or $failure.'Error Code' -ne $res.'Error Code')
            {
                ($mail1 | Where-Object {($_.client -like "$Failed_Client*") -and ($_.schedule -eq $failure.Schedule) -and ($_.job -like "$failurejob*")}).status = $res.Status
                ($mail1 | Where-Object {($_.client -like "$Failed_Client*") -and ($_.schedule -eq $failure.Schedule) -and ($_.job -like "$failurejob*")}).'Error Code' = $res.'Error Code'
                ($mail1 | Where-Object {($_.client -like "$Failed_Client*") -and ($_.schedule -eq $failure.Schedule) -and ($_.job -like "$failurejob*")}).'Error Code Summary' = $res.'Error Code Summary'
                ($mail1 | Where-Object {($_.client -like "$Failed_Client*") -and ($_.schedule -eq $failure.Schedule) -and ($_.job -like "$failurejob*")}).'Status Code' = $res.'Status Code'
                ($mail1 | Where-Object {($_.client -like "$Failed_Client*") -and ($_.schedule -eq $failure.Schedule) -and ($_.job -like "$failurejob*")}).'Status Code Summary' = $res.'Status Code Summary'
            }
        }
    }

    $mail1 |export-csv $config.InputSheetPath -NoTypeInformation



    $err = $mail2 | ? {$_.'Error code' -ne "0" -and $_.'Error code' -ne "" } | sort 'client','Schedule','Job' -Unique
    Write-Host "*****Started*****" -ForegroundColor Green
    foreach($line in $err)
    {   
        $failurejob2 = ($line.job -split "-")[0]
        $x = (($line.Client).Substring(0,8)).trim()
        $out = $mail1 | Where-Object {($_.client -like "$x*") -and ($_.schedule -eq $line.Schedule) -and ($_.job -like "$failurejob2*")}
        if($out)
        {
            ($mail1 | Where-Object {($_.client -like "$x*") -and ($_.schedule -eq $line.Schedule) -and ($_.job -like "$failurejob2*")}).status = $line.Status
            ($mail1 | Where-Object {($_.client -like "$x*") -and ($_.schedule -eq $line.Schedule) -and ($_.job -like "$failurejob2*")}).'Error Code' = $line.'Error Code'
            ($mail1 | Where-Object {($_.client -like "$x*") -and ($_.schedule -eq $line.Schedule) -and ($_.job -like "$failurejob2*")}).'Error Code Summary' = $line.'Error Code Summary'
            ($mail1 | Where-Object {($_.client -like "$x*") -and ($_.schedule -eq $line.Schedule) -and ($_.job -like "$failurejob2*")}).'Status Code' = $line.'Status Code'
            ($mail1 | Where-Object {($_.client -like "$x*") -and ($_.schedule -eq $line.Schedule) -and ($_.job -like "$failurejob2*")}).'Status Code Summary' = $line.'Status Code Summary'
        }
    }

    $mail1 |export-csv $config.InputSheetPath -NoTypeInformation

    Write-Host "*****Completed*****" -ForegroundColor Green
}
else
{
    Write-Host "Invalid $ConfigFile" -BackgroundColor Red
}
