
Import-Module .\Posh-SSH\Posh-SSH.psm1
Import-Module .\ImportExcel\ImportExcel.psm1

$Credential = Get-Credential

$Servers = Import-csv "Servers.csv"

$Commands = "purearray list","purearray monitor","purevol list","purevol list","purehgroup list","purehost list","purehw list","purenetwork list"

Foreach($Server in $Servers)
{
    $Filename = "$($Server.ServerName)" + ".xlsx"
    $IP = $Server.IP
    $SSHSession = New-SSHSession -ComputerName $Ip -Credential $Credential -AcceptKey:$true
    if($SSHSession.Connected -eq "True")
    {
        foreach($Command in $commands)
        {
            $CommandOutput = Invoke-SSHCommand -SessionId $SSHSession.Sessionid -Command $Command
            if($CommandOutput.output)
            {
                $ConvertedOutput = $CommandOutput| ConvertFrom-Csv
            }
            else
            {
                $ConvertedOutput = [pscustomobject] @{
                command = $Command
                Status  = "Unable to get command output"
                }
            }
            $ConvertedOutput | Export-Excel -Path $Filename -WorksheetName "$Command"
        }
    }
}