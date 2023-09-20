#winrmqc
#Enable-PSRemoting

$credential = Get-Credential
$computername = "*******"


$command = "omnisv -status" 
$Result= Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {Invoke-Expression $using:Command}
$Result

$command = "omnirpt -report list_sessions -timeframe 21/09/28 03:00 21/09/29 02:59 -tab -no_copylist -no_verificationlist -no_conslist"
$Result= Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {Invoke-Expression $using:Command}
$Result

$command = "omnistat -detail"
$Result= Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {Invoke-Expression $using:Command}
$Result

$command = "omnidownload -list_devices -detail"
$Result= Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {Invoke-Expression $using:Command}
$Result

$command = "omnirpt -report pool_list -tab"
$Result= Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {Invoke-Expression $using:Command}
$Result

$command = "omnidb -session 2021/09/28-3 -media"     ####Session Id from failed backup output(step 2)
$Result= Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {Invoke-Expression $using:Command}
$Result

$command = "Get-WmiObject win32_logicaldisk" 
$Result= Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {Invoke-Expression $using:Command}
$Result

$command = "omnimm -repository_barcode_scan USPLSDP004_STB001_ST6"
$Result= Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {Invoke-Expression $using:Command}
$Result

$command = "omnidb -rpt "
$Result= Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {Invoke-Expression $using:Command}
$Result

