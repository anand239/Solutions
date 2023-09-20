$credential = Get-Credential
Import-Module ".\Posh-SSH\Posh-SSH.psd1"
$sshSession = New-SSHSession -ComputerName "204.230.51.241" -Credential $Credential -AcceptKey:$true
$sessionId = $sshSession.SessionId
$ssh = New-SSHShellStream -SessionId $sessionId

$command = "omnisv -status" 
$ssh.WriteLine($command)
Start-Sleep -Seconds 5
$Buffer=""
do
{
$Buffer += $ssh.read()
Start-Sleep -Milliseconds 3000
}
While ($ssh.DataAvailable)
$Buffer|out-file .\Services.log
$ssh.Dispose()

#######################################################

$ssh = New-SSHShellStream -SessionId $sessionId
$command = "omnirpt -report list_sessions -timeframe 21/09/23 03:00 21/09/24 02:59 -tab -no_copylist -no_verificationlist -no_conslist"
$ssh.WriteLine($command)
Start-Sleep -Seconds 5
$Buffer=""
do
{
$Buffer += $ssh.read()
Start-Sleep -Milliseconds 3000
}
While ($ssh.DataAvailable)
$Buffer|out-file .\Backup.log
$ssh.Dispose()

#######################################################
$ssh = New-SSHShellStream -SessionId $sessionId
$command = "omnistat -detail"
$ssh.WriteLine($command)
Start-Sleep -Seconds 5
$Buffer=""
do
{
$Buffer += $ssh.read()
Start-Sleep -Milliseconds 3000
}
While ($ssh.DataAvailable)
$Buffer|out-file .\Queuing.log
$ssh.Dispose()

#######################################################
$ssh = New-SSHShellStream -SessionId $sessionId
$command = "omnidownload -list_devices -detail"
$ssh.WriteLine($command)
Start-Sleep -Seconds 5
$Buffer=""
do
{
$Buffer += $ssh.read()
Start-Sleep -Milliseconds 3000
}
While ($ssh.DataAvailable)
$Buffer|out-file .\Disabledtapedrive.log
$ssh.Dispose()

#######################################################
$ssh = New-SSHShellStream -SessionId $sessionId
$command = "omnirpt -report pool_list -tab"
$ssh.WriteLine($command)
Start-Sleep -Seconds 5
$Buffer=""
do
{
$Buffer += $ssh.read()
Start-Sleep -Milliseconds 3000
}
While ($ssh.DataAvailable)
$Buffer|out-file .\Scratch.log
$ssh.Dispose()

#######################################################
$ssh = New-SSHShellStream -SessionId $sessionId
$command = "omnidb -session 2021/09/23-3 -media"     ####Session Id from failed backup output(step 2)
$ssh.WriteLine($command)
Start-Sleep -Seconds 5
$Buffer=""
do
{
$Buffer += $ssh.read()
Start-Sleep -Milliseconds 3000
}
While ($ssh.DataAvailable)
$Buffer|out-file .\IDB.log
$ssh.Dispose()

#######################################################
$ssh = New-SSHShellStream -SessionId $sessionId
$command = "bdf"                                ### uname -a #### HP-UX -- bdf ### Linux -- df -h
$ssh.WriteLine($command)
Start-Sleep -Seconds 5
$Buffer=""
do
{
$Buffer += $ssh.read()
Start-Sleep -Milliseconds 3000
}
While ($ssh.DataAvailable)
$Buffer|out-file .\Freedisk.log
$ssh.Dispose()

#######################################################
$ssh = New-SSHShellStream -SessionId $sessionId
$command = "omnimm -repository_barcode_scan USPLSDP004_STB001_ST6"
$ssh.WriteLine($command)
Start-Sleep -Seconds 5
$Buffer=""
do
{
$Buffer += $ssh.read()
Start-Sleep -Milliseconds 4000
}
While ($ssh.DataAvailable)
$Buffer|out-file .\Library.log
$ssh.Dispose()

#######################################################

<#
$command = "omnirpt -session SESSIONID -details"
$ssh.WriteLine($command)
Start-Sleep -Milliseconds 5000
$Buffer=""
do
{
$Buffer += $ssh.read()
}
While ($ssh.DataAvailable)
$Buffer|out-file .\Hung.log#>

#######################################################


get-sshsession | Remove-SSHSession