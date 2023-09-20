Function New-PoshSession
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$IpAddress,
        [Parameter(Mandatory = $true)]
        [PSCredential]$Credential
    )
    try
    {
        $SessionId = New-SSHSession -ComputerName $IpAddress -Credential $Credential -AcceptKey:$true
        write-output $SessionId
    }
    catch
    {
        Write-Output $null
    }

}

function Invoke-BackupHealthCheckCommand
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$SshSessionId,
        [Parameter(Mandatory = $true)]
        [String]$logFile,
        [Parameter(Mandatory = $true)]
        [String]$command,
        [Switch] $UseSSHStream

    )
    try
    {
        '****************************' |  Out-File -FilePath $logFile -Append
        "Running Command : $command" |  Out-File -FilePath $logFile -Append
        '----------------------------' |  Out-File -FilePath $logFile -Append
        $result = ""
        $result = Invoke-SSHCommand -Command $command -SessionId $SshSessionId -EnsureConnection -TimeOut 300 
        $output = $result.output
        if ($result.error)
        {
         "Error Occured"  | Out-File -FilePath $logFile -Append  
         '============================' |  Out-File -FilePath $logFile -Append  
         $result.error | Out-File -FilePath $logFile -Append  
         '============================' |  Out-File -FilePath $logFile -Append  
        }
        <#
        if ($UseSSHStream)
        {
        $ssh = New-SSHShellStream -SessionId $sessionId
        if (Invoke-SSHStreamExpectSecureAction -ShellStream $ssh -Command $command -ExpectString "Enable Password:" -SecureAction $Credential.password)
        {

        
        $ssh.WriteLine($command)
        Start-Sleep -Milliseconds 1000
        do
        {
            $result += $ssh.read()
            Start-Sleep -Milliseconds 500
        }
        While ($ssh.DataAvailable)
        }
        $output =  $result
        #>

        $output | Out-File -FilePath $logFile -Append    
        '----------------------------'  | Out-File -FilePath $logFile -Append
        '****************************'  | Out-File -FilePath $logFile -Append
        Write-Output $output
    }
    catch
    {
        Write-Output $null
    }
}


$Activitylog = "Activity.log"
$Credential = Get-Credential
Import-Module ".\Posh-SSH\Posh-SSH.psd1"
$BackupDevice = "10.15.58.33"
$sshsessionId = New-PoshSession -IpAddress $BackupDevice -Credential  $Credential


$ErrordataCommand = "/usr/openv/netbackup/bin/admincmd/bperror -backstat -s info -hoursago 24"
$Errordata = Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command $ErrordataCommand
$ErrorObject = @()
$pattern = '(?<=\().+?(?=\))'
foreach($line in $Errordata)
{
    $split = $line -split "\s" | where{$_}
    $Description = [regex]::Matches($line, $pattern).Value
    $ErrorObject += [Pscustomobject] @{
    "JobId"      = $split[5]
    "ClientName" = $split[11]
    "Ploicy"     = $split[13]
    "ParentJob"  = $split[6]
    "Schedule"   = $split[15]
    "Status"     = $split[18]
    "MediaServer"= $split[4]
    "Description"= $Description
    }

}


$ErrorObject | export-csv ./report.csv -NoTypeInformation