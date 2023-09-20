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
$BackupDevice = ""
$Credential = Get-Credential

Import-Module ".\Posh-SSH\Posh-SSH.psd1"
$sshsessionId = New-PoshSession -IpAddress $BackupDevice -Credential  $Credential

if($sshsessionId.connected -eq "True")
{
    $ErrordataCommand = "/usr/openv/netbackup/bin/admincmd/bperror -backstat -s info -hoursago 24"
    $Errordata = Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command $command
    if($Errordata)
    {
        $ErrorObject = @()
        $pattern = '(?<=\().+?(?=\))'
        foreach($line in $Errordata)
        {
            $split = $line -split "\s" | where{$_}
            $Description = [regex]::Matches($data, $pattern).Value
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

        if($ErrorObject)
        {
            $filtered = $ErrorObject | where{$_.status -ne "0" -and $_.status -ne "1" -and $_.status -ne "191" -and $_.status -ne "50" -and $_.status -ne "150" -and $_.ClientName -ne "None"}

            $Groups = $filtered | Group-Object -Property Clientname,status

            $Finaldata = @()

            Foreach($Group in $Groups)
            {
                if($Group.count -ge 50)
                {
                    $one = $Group.group | select -First 1
                    $one | Add-Member NoteProperty "Priority" "P2"
                    $Finaldata += $one
                }
                else
                {
                    $one = $Group.group | select -First 1
                    $one | Add-Member NoteProperty "Priority" "P4"
                    $Finaldata += $one
                }
            }
        }
        else
        {
            Write-Host "No error logs available"
        }
    }
    else
    {
        Write-Host "No error logs available"
    }
}
else
{
    Write-Host "Failed to connect to $BackupDevice "
}