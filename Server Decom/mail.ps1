$InventoryData = Import-Excel "C:\Users\achintalapud\Downloads\V3\BUR_HC_DP_Test-ACC_WIN-HN3S1C28UTD_Signal.xlsx"
$Host_Name = Read-Host "Enter the Host Name"
$mail = (($InventoryData |Where-Object{$_.HOSTNAME -eq "$Host_Name"}).'Business Owner').split(";")
$mail



$sendMailMessageParameters = @{
To = $mail
from = "a.chintalapudi@dxc.com"
Subject = "Last 24 Hours SCC_BackupReport"
SMTPServer = "smtp.svcs.hpe.com"
ErrorAction = 'Stop'
}
$body = "Hi $mail
The server is being decomissioned"
$sendMailMessageParameters.Add("Body", $body)
Send-MailMessage @sendMailMessageParameters