$End_time = (get-date).ToString("yy/MM/dd HH:mm")
$Start_time = (get-date).AddMinutes(-15).ToString("yy/MM/dd HH:mm")

$session = omnirpt -report list_sessions -timeframe $Start_time $End_time -tab
$Backup_failure = $session | ? {$_.status -eq "Failed" -or $_.status -eq “Completed/Failures”}

foreach($session_id in $Backup_failure)
{
$Backup_Log = omnidb –session $session_id.'Session ID' -report


}