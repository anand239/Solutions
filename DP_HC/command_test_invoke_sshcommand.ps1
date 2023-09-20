#$credential = Get-Credential
Import-Module ".\Posh-SSH\Posh-SSH.psd1"

$sshSession = New-SSHSession -ComputerName "204.230.51.241" -Credential $Credential -AcceptKey:$true
$sessionId = $sshSession.SessionId


$command = "/opt/omni/sbin/omnisv -status" 
$Buffer = Invoke-SSHCommand -Command $command -SessionId $sessionId -EnsureConnection
$buffer.Output | Out-File ./services.txt


$command = "/opt/omni/bin/omnirpt -report list_sessions -timeframe 21/09/28 03:00 21/09/29 02:59 -tab -no_copylist -no_verificationlist -no_conslist"
$Buffer = Invoke-SSHCommand -Command $command -SessionId $sessionId -EnsureConnection
$buffer.ExitStatus
$buffer.Error
$buffer.Output



$command = "/opt/omni/bin/omnistat -detail"
$Buffer = Invoke-SSHCommand -Command $command -SessionId $sessionId -EnsureConnection
$buffer.ExitStatus
$buffer.Error
$buffer.Output


$command = "/opt/omni/bin/omnidownload -list_devices -detail"
$Buffer = Invoke-SSHCommand -Command $command -SessionId $sessionId -EnsureConnection
$buffer.ExitStatus
$buffer.Error
$buffer.Output

$command = "/opt/omni/bin/omnirpt -report pool_list -tab"
$Buffer = Invoke-SSHCommand -Command $command -SessionId $sessionId -EnsureConnection
$buffer.ExitStatus
$buffer.Error
$buffer.Output | out-file pool_list.txt

$command = "/opt/omni/bin/omnidb -session 2021/09/28-3 -media"     ####Session Id from failed backup output(step 2)
$Buffer = Invoke-SSHCommand -Command $command -SessionId $sessionId -EnsureConnection
$buffer.ExitStatus
$buffer.Error
$buffer.Output

$command = "bdf" 
$Buffer = Invoke-SSHCommand -Command $command -SessionId $sessionId -EnsureConnection
$buffer.ExitStatus
$buffer.Error
$buffer.Output

$command = "/opt/omni/bin/omnimm -repository_barcode_scan USPLSDP004_STB001_ST6"
$Buffer = Invoke-SSHCommand -Command $command -SessionId $sessionId -EnsureConnection
$buffer.ExitStatus
$buffer.Error
$buffer.Output

$command = "/opt/omni/bin/omnidb -rpt "
$Buffer = Invoke-SSHCommand -Command $command -SessionId $sessionId -EnsureConnection
$buffer.ExitStatus
$buffer.Error
$buffer.Output

$command= "find /etc/opt/omni/server/schedules -type f"
$Buffer = Invoke-SSHCommand -Command $command -SessionId $sessionId -EnsureConnection
$buffer.ExitStatus
$buffer.Error
$buffer.Output

$command = "sudo cat /etc/opt/omni/server/schedules/USPLSDP004_FS_ON"
$Buffer = Invoke-SSHCommand -Command $command -SessionId $sessionId -EnsureConnection
$buffer.ExitStatus
$buffer.Error
$buffer.Output


get-sshsession | Remove-SSHSession