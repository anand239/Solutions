$savesetdetailsRaw = Get-Content "C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\Ravi\saveset_output.txt"

if($savesetdetailsRaw)
{
    $savesetdetails = $savesetdetailsRaw | select -Skip 1 | where{$_}


    $SaveSetNameLineNumbers = ($savesetdetails | Select-String "name").LineNumber
    if($SaveSetNameLineNumbers)
    {
        $FinalReport = @()
        for($i=0;$i -lt $SaveSetNameLineNumbers.Count;$i++)
        {
            $d = $SaveSetNameLineNumbers[$i]
            $g = $SaveSetNameLineNumbers[$i+1]
            $SaveSetname = (($savesetdetails[$d-1] -split ":")[1] -split ";")[0].trim()
            $Saveset = ""
            for($j=$d; $j -lt ($g-1);$j++)
            {
                $Saveset += $savesetdetails[$j]
            }
            $savesets = (($Saveset -split ": ")[1] -split ",").trim() -join ";"

            $FinalReport += [pscustomobject]@{
            Name = $SaveSetname
            'Save Set' = $savesets
            }
        }

        $NotAll = $FinalReport | where{$_.'Save Set' -ne "All;"}
        if($NotAll)
        {
            $NotAll | Export-Csv "Report.csv" -NoTypeInformation
        }
        else
        {
            Write-Host "There is no client where SaveSet is ALL" -ForegroundColor Red
        }
    }
    else
    {
        Write-Host "Unable to get the SaveSet names" -ForegroundColor Red
    }
}
else
{
    Write-Host "Unable to get the SaveSet data" -ForegroundColor Red
}