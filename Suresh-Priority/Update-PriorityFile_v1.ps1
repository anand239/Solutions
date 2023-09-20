$cred = Get-Credential
$session = New-SSHSession -ComputerName "192.168.247.143" -Credential $cred -AcceptKey:$true

$configpath = "/home/cvardhan/suresh_priority/priority"
$ConfigPath1 = $configpath + "1"

$command = "cat $configpath"
$out = Invoke-SSHCommand -SSHSession $session -Command $command

$DaystobeAdded = "20"
$data = $out.Output
$Todaydate = Get-Date

$array = @()
foreach($line in $data)
{
    if(!($line.StartsWith("#") -or ($line.Length -eq 0)))
    {        
        if($line -like "*_Monthly*" -or $line -like "*_Yearly*" -or $line -like "*_Adhoc*")
        {
            $words = $line -split "\s" | where{$_}
            $Linedate = $words[8]            
            if($Linedate -eq 0)
            {
                $words[8] = $Todaydate.AddDays($DaystobeAdded).tostring("dd.MM.yy")
                $Updatedline = $words -join "     "
                $array += $Updatedline                
            }
            else
            {                                
                $UpdatedDate = $Todaydate.AddDays($DaystobeAdded).tostring("dd.MM.yy") #(([datetime]::parseexact($Linedate, 'dd.MM.yy', $Null)).adddays($DaystobeAdded)).tostring("dd.MM.yy")
                $words[8] = $UpdatedDate
                $Updatedline = $words -join "     "
                $array += $Updatedline
            }
        }
        else
        {
            $array += $line
        }              
    }
    else
    {
        $array += $line
    }
}

foreach($i in $array)
{
    $command = "echo `"$i`" >> $ConfigPath1"
    $out = Invoke-SSHCommand -SSHSession $session -Command $command
}

$array | Out-File "priority1"


Set-SCPItem -ComputerName "192.168.247.145" -Credential $cred -Path "passes.txt" -Destination "/home/cvardhan/suresh_priority"