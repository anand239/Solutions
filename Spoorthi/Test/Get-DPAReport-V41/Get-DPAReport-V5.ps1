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
    Write-Host "*****Started*****" -ForegroundColor Green
    $MailSheets = $config.MailSheetPath -split ";"
    $InputSheet = Import-Csv $config.InputSheetPath
    foreach($sheet in $MailSheets)
    {
        if(Test-Path -Path $sheet)
        {
            $mail = Import-Csv $sheet
        }
        else
        {
            Write-Host "$sheet not found!"
            exit
        }
        Write-Host "Fetching data from $(Split-Path $sheet -Leaf)"
        #$InputSheet_Failures = $InputSheet | Where-Object {$_.status -eq "Failed"}
        $InputSheet_Failures = $InputSheet | ? {$_.'Error code' -ne "0" -and $_.'Error code' -ne "" } | sort 'client','Schedule','Job' -Unique
        foreach($failure in $InputSheet_Failures)
        {
            $failurejob = ($failure.job -split "-")[0]
            $Failed_Client = (($failure.Client).split("."))[0]
            #$res = $mail | Where-Object {($_.client -like "$Failed_Client*") -and ($_.schedule -eq $failure.Schedule) -and ($_.job -like "$failurejob*")}
            $res = $mail | Where-Object {($_.client -like "$Failed_Client*") -and ($_.schedule -eq $failure.Schedule) -and ($_.job -like "$failurejob*")} | select -First 1
            if($res)
            {
                if($failure.status -ne $res.status -or $failure.'Error Code' -ne $res.'Error Code')
                {
                    $InputSheet | Where-Object {($_.client -like "$Failed_Client*") -and ($_.schedule -eq $failure.Schedule) -and ($_.job -like "$failurejob*")} | ForEach-Object{
                    $_.status = $res.Status
                    $_.'Error Code' = $res.'Error Code'
                    $_.'Error Code Summary' = $res.'Error Code Summary'
                    $_.'Status Code' = $res.'Status Code'
                    $_.'Status Code Summary' = $res.'Status Code Summary'
                    }
                }
            }
        }

        $InputSheet |export-csv $config.InputSheetPath -NoTypeInformation


        $err = $mail | ? {$_.'Error code' -ne "0" -and $_.'Error code' -ne "" } | sort 'client','Schedule','Job' -Unique
        foreach($line in $err)
        {   
            $failurejob2 = ($line.job -split "-")[0]
            $x = (($line.Client).split("."))[0]
            $out = $InputSheet | Where-Object {($_.client -like "$x*") -and ($_.schedule -eq $line.Schedule) -and ($_.job -like "$failurejob2*")}
            if($out)
            {
                $InputSheet | Where-Object {($_.client -like "$Failed_Client*") -and ($_.schedule -eq $failure.Schedule) -and ($_.job -like "$failurejob*")} | ForEach-Object{
                $_.status = $res.Status
                $_.'Error Code' = $res.'Error Code'
                $_.'Error Code Summary' = $res.'Error Code Summary'
                $_.'Status Code' = $res.'Status Code'
                $_.'Status Code Summary' = $res.'Status Code Summary'
                }
            }
        }

        $InputSheet |export-csv $config.InputSheetPath -NoTypeInformation
    }
    Write-Host "*****Completed*****" -ForegroundColor Green
}
else
{
    Write-Host "Invalid $ConfigFile" -BackgroundColor Red
}
