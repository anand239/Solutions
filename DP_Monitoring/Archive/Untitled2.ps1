<#

$a = Import-Csv "C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\DP\DP_Monitoring\event.csv"
$a.Count


$first = $a|select -First 1

$same = $a | ?{$_.Sepcification -eq $first.Sepcification -and $_.SessionID -eq $first.SessionID -and $_.Mode -eq $first.Mode}

$count = $same | ?{$_.hostname -eq ($same.hostname|select -First 1)}

if($count -gt 1)
{

$hostnme = "Multiple"
}
#>

#$x = Compare-Object -ReferenceObject $a -DifferenceObject $same
#$x.inputobject

$EventImport = Import-Csv "C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\DP\DP_Monitoring\event.csv"

$Groups = $EventImport | Group-Object Sepcification,sessionid, mode

foreach($group in $groups)
{
        $count = (@($group.Group | Group-Object hostname).name)
        echo "*******************"
        if($count.count -gt 1)
        {
            ($group.Group | select -Last 1).hostname = "Multiple"
            $group.Group  | select -Last 1
        }
        else
        {
            $group.Group  | select -Last 1
        }
}
