$credential = Get-Credential
$IpAddress = "192.168.223.184"
$PlinkPath = "C:\Users\achintalapud\Downloads" 
$decrypted = $Credential.GetNetworkCredential().password
$plink = Join-Path $PlinkPath -ChildPath "plink.exe"


$command = "uname"
$resultcommand = "echo y | $plink -ssh $IpAddress -l $($Credential.UserName) -pw $($decrypted) $command 2>&1"
Invoke-Expression $resultcommand -ErrorAction SilentlyContinue | Out-Null

$array = "ls","df -k"
$command = "df -k"
 &$plink -batch -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command #2>&1
