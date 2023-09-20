Function Get-DumpmaintObject
{
    [cmdletbinding()]
    Param(
    $date,$SkippedHashes,$MbRecovered,$Passes,$ElapsedTime
    )
    
    $DumpOutput           = [pscustomobject] @{
    Date                  = $date
    'Skipped-hashes'      = $SkippedHashes
    'Megabytes-Recovered' = $MbRecovered
    Passes                = $Passes
    'Elapsed Time'        = $ElapsedTime
    }
    $DumpOutput
}



$Dumpmaintlogs = Get-Content "C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\Rahul\passes.txt"

$capacity = Get-Content "C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\Rahul\capacity.txt"

$pattern = '(?<=\").+?(?=\")'
#$pass = $Dumpmaintlogs[0]

$DumpOutput = @()
foreach($Dumpmaintlog in $Dumpmaintlogs)
{
    $split = $Dumpmaintlog -split "\s" | where{$_}

    $date          = $split[0]
    $SkippedHashes = [regex]::Matches($Split[1], $pattern).Value
    $MbRecovered   = [regex]::Matches($Split[2], $pattern).Value
    $Passes        = [regex]::Matches($Split[3], $pattern).Value
    $ElapsedTime   = [regex]::Matches($Split[4], $pattern).Value
    
    $DumpOutput += Get-DumpmaintObject -date $date -SkippedHashes $SkippedHashes -MbRecovered $MbRecovered -Passes $Passes -ElapsedTime $ElapsedTime

}

$Reportpath = "DD" + "_" + "Anand" + "_" + "Anand1" + "_" + "Signal" + "_"  + "31May22_0847"+ ".csv"
$DumpOutput | export-csv -Path $Reportpath -NoTypeInformation

$DumpOutput | ConvertTo-Html -Head $css | Out-File "dump.html"

$final = @()

#$final += $DumpOutput | ConvertTo-Html -Head $css

$final += "<b> $capacity </b>"
$final | Out-File "C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\Rahul\ava.html"