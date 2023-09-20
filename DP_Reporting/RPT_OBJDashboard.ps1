$x = Get-ChildItem -Path "C:\Users\achintalapud\Downloads\OBJ_Reports\OBJ_Reports" -Filter "*.csv"
$ConsolidatedObjRep = @()
foreach($l in $x)
{
    $ConsolidatedObjRep += import-csv -Path $l.fullname
}

$groups = $ConsolidatedObjRep | select Account, BackupApplication,BackupServer,Client,'session type' -Unique
$Uniquedates = ($ConsolidatedObjRep| Sort-Object date -Descending | Select-Object date -Unique).date
foreach($Uniquedate in $Uniquedates)
{
    $groups |  Add-Member NoteProperty "$Uniquedate" ""
}
foreach($Uniquedate in $Uniquedates)
{
    $Uniquedate
    Get-Date
    echo "*************************"
    foreach($group in $groups)
    {
        $Value = $ConsolidatedObjRep | Where-Object{$_.Account -eq $group.Account -and $_.BackupApplication -eq $group.BackupApplication -and $_.ClientName -eq $group.Clientname -and $_.BackupServer -eq $group.BackupServer -and $_.'session type' -eq $group.'Session Type' -and $_.Date -eq $Uniquedate }
        if($Value)
        {
            $group."$Uniquedate" = ($Value | Measure-Object -Property "size (KB)" -Sum).Sum
        }
        else
        {
            $group."$Uniquedate" = $null
        }
    }
}