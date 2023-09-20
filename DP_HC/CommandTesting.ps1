$credential = Get-Credential
$sshSession = New-SSHSession -ComputerName "*********" -Credential $Credential -AcceptKey
$sessionId = $sshSession.SessionId
$ssh = New-SSHShellStream -SessionId $sessionId

$command = "omnisv -status" 
$ssh.WriteLine($command)
Start-Sleep -Milliseconds 5000
$Buffer=""
do
{
$Buffer += $ssh.read()
}
While ($ssh.DataAvailable)
$Buffer|out-file .\Services.log


#######################################################

$command = "omnirpt -report list_sessions -timeframe 21/09/21 18:00 21/09/22 17:59 -tab -no_copylist -no_verificationlist -no_conslist"
$ssh.WriteLine($command)
Start-Sleep -Milliseconds 5000
$Buffer=""
do
{
$Buffer += $ssh.read()
}
While ($ssh.DataAvailable)
$Buffer|out-file .\Backup.log

#######################################################

$command = "omnistat -detail"
$ssh.WriteLine($command)
Start-Sleep -Milliseconds 5000
$Buffer=""
do
{
$Buffer += $ssh.read()
}
While ($ssh.DataAvailable)
$Buffer|out-file .\Queuing.log

#######################################################

$command = "omnidownload -list_devices -detail"
$ssh.WriteLine($command)
Start-Sleep -Milliseconds 5000
$Buffer=""
do
{
$Buffer += $ssh.read()
}
While ($ssh.DataAvailable)
$Buffer|out-file .\Disabledtapedrive.log

#######################################################

$command = "omnirpt -report pool_list -tab"
$ssh.WriteLine($command)
Start-Sleep -Milliseconds 5000
$Buffer=""
do
{
$Buffer += $ssh.read()
}
While ($ssh.DataAvailable)
$Buffer|out-file .\Scratch.log

#######################################################

$command = "omnidb -session Session ID -media"     ####Session Id from failed backup output(step 2)
$ssh.WriteLine($command)
Start-Sleep -Milliseconds 5000
$Buffer=""
do
{
$Buffer += $ssh.read()
}
While ($ssh.DataAvailable)
$Buffer|out-file .\IDB.log

#######################################################

$command = "df -h"                                ### uname -a #### HP-UX -- bdf ### Linux -- df -h
$ssh.WriteLine($command)
Start-Sleep -Milliseconds 5000
$Buffer=""
do
{
$Buffer += $ssh.read()
}
While ($ssh.DataAvailable)
$Buffer|out-file .\Freedisk.log

#######################################################

$command = "omnimm -repository_barcode_scan TapeLibrary Name"
$ssh.WriteLine($command)
Start-Sleep -Milliseconds 5000
$Buffer=""
do
{
$Buffer += $ssh.read()
}
While ($ssh.DataAvailable)
$Buffer|out-file .\Library.log

#######################################################

$command = "omnirpt -session SESSIONID -details"
$ssh.WriteLine($command)
Start-Sleep -Milliseconds 5000
$Buffer=""
do
{
$Buffer += $ssh.read()
}
While ($ssh.DataAvailable)
$Buffer|out-file .\Hung.log

#######################################################

