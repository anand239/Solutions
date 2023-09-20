$credential = Get-Credential
$IpAddress = "192.168.223.184"
$PlinkPath = "C:\Program Files\PuTTY"  
$decrypted = $Credential.GetNetworkCredential().password
$plink = Join-Path $PlinkPath -ChildPath "plink.exe"


$command = "omnisv -status" 
$result = &$plink -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command 2>&1
$result |out-file .\Services.log

#################################

$command = "omnirpt -report list_sessions -timeframe 21/09/23 03:00 21/09/24 02:59 -tab -no_copylist -no_verificationlist -no_conslist"
$result = &$plink -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command 2>&1
$result |out-file .\Backup.log

#################################

$command = "omnistat -detail"
$result = &$plink -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command 2>&1
$result |out-file .\Queuing.log

#################################

$command = "omnidownload -list_devices -detail"
$result = &$plink -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command 2>&1
$result |out-file .\Disabledtapedrive.log

#################################

$command = "omnirpt -report pool_list -tab"
$result = &$plink -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command 2>&1
$result |out-file .\scratch.log

#################################

$command = "omnidb -session 2021/09/23-3 -media"     ####Session Id from failed backup output(step 2)
$result = &$plink -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command 2>&1
$result |out-file .\IDB.log

#################################

$command = "bdf"                                ### uname -a #### HP-UX -- bdf ### Linux -- df -h
$result = &$plink -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command 2>&1
$result |out-file .\freediskspace.log

#################################

$command = "omnimm -repository_barcode_scan USPLSDP004_STB001_ST6"
$result = &$plink -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command 2>&1
$result |out-file .\Library.log

#################################
