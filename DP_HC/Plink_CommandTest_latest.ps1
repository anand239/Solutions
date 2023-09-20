$OriginalErrorActionPreference = $ErrorActionPreference
$credential = Get-Credential
$IpAddress = "192.168.223.184"
$PlinkPath = "."
$decrypted = $Credential.GetNetworkCredential().password
$plink = Join-Path $PlinkPath -ChildPath "plink.exe"


$ErrorActionPreference = "SilentlyContinue"


$command = "uname"
$resultcommand = "echo y | $plink -ssh $IpAddress -l $($Credential.UserName) -pw $($decrypted) $command 2>&1"
Invoke-Expression $resultcommand -ErrorAction SilentlyContinue | Out-Null

$command = "/opt/omni/sbin/omnisv -status" 
$result = &$plink -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command 2>&1
$result |out-file .\With_WithRedirection_BatchServices.log

$command = "/opt/omni/sbin/omnisv -status" 
$result = &$plink -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command #2>&1
$result |out-file .\WithoutBatchServices.log

$command = "/opt/omni/sbin/omnisv -status" 
$result = echo y | &$plink -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command #2>&1
$result |out-file .\WithoutBatch_WithoEcho_Services.log

$command = "/opt/omni/sbin/omnisv -status" 
$result = echo y | &$plink -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command 2>&1
$result |out-file .\WithoutBatch_WithoEcho_WithRedirection_Services.log

$command = "/opt/omni/sbin/omnisv -status" 
$result = &$plink -batch -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command #2>&1
$result |out-file .\WithBbatchServices.log

$command = "/opt/omni/sbin/omnisv -status" 
$result = echo y | &$plink -batch -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command 2>&1
$result |out-file .\WithBatch_WithoEcho_WithRedirection_Services.log



$command = "/opt/omni/sbin/omnisv -status" 
$result = &$plink -batch -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command #2>&1
$result |out-file .\Services.log

#################################

$command = "/opt/omni/bin/omnirpt -report list_sessions -timeframe 21/09/23 03:00 21/09/24 02:59 -tab -no_copylist -no_verificationlist -no_conslist"
$result = &$plink -batch -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command #2>&1
$result |out-file .\Backup.log

#################################

$command = "/opt/omni/bin/omnistat -detail"
$result = &$plink -batch -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command #2>&1
$result |out-file .\Queuing.log

#################################

$command = "/opt/omni/bin/omnidownload -list_devices -detail"
$result = &$plink -batch -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command #2>&1
$result |out-file .\Disabledtapedrive.log

#################################

$command = "/opt/omni/bin/omnirpt -report pool_list -tab"
$result = &$plink -batch -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command #2>&1
$result |out-file .\scratch.log

#################################

$command = "/opt/omni/bin/omnidb -session 2021/09/23-3 -media"     ####Session Id from failed backup output(step 2)
$result = &$plink -batch -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command #2>&1
$result |out-file .\IDB.log

#################################

$command = "bdf"                                ### uname -a #### HP-UX -- bdf ### Linux -- df -k
$result = &$plink -batch -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command #2>&1
$result |out-file .\freediskspace.log

#################################

$command = "/opt/omni/bin/omnimm -repository_barcode_scan USPLSDP004_STB001_ST6"
$result = &$plink -batch -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command #2>&1
$result |out-file .\Library.log

#################################

$command= "find /etc/opt/omni/server/schedules -type f"
$result = &$plink -batch -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command #2>&1
$result |out-file .\schedules.log

#################################

$command = "sudo cat /etc/opt/omni/server/schedules/USPLSDP004_FS_ON"
$result = &$plink -batch -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command #2>&1
$result |out-file .\scheduleout.log



$ErrorActionPreference = $OriginalErrorActionPreference

