<#===================================================================================================================
	SUMMARY
	-----------
        StoreOnce Hardware Status (SoHS) Check

	DESCRIPTION
	-----------
	    This script allows you to execute command in storeonce to collect hardware status.
	
    PREREQUISITES
	------------

    System Requirements
        Windows 2008 above
        Windows Management Framework 5.0
        PowerShell
        Posh-SSH Module

	Input File(s)
	    SoHS Config File
        SecureKey File
        SecurePass File

	Output File(s)
        Activity Log (per device)
        Session Log
        StoreOnce Hardware Status File
	
	
	VERSION DETAILS
	---------------
	VERSION:         1.0 
    AUTHOR:          Arnaldo N. Egos
    DATE CREATED:    June 21, 2018                 
    NOTES:           Initial Version

#===================================================================================================================#>

### Variables ########################################################################################################
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$date = Get-Date -UFormat "%m%d%Y"

$rptdir = "$dir\Report"
$sohsconfig ="$dir\SoHS_Config.cfg"
$sessionlog = "$dir\SessionLog.txt"

### Validate if file exist ###########################################################################################
$chkrptdir = Test-Path ("$rptdir")
$chksohsconfig = Test-Path ("$dir\SoHS_Config.cfg")
$chksessionlog = Test-Path ("$dir\SessionLog.txt")
$chksecurekey = Test-Path ("$dir\Secure.key")
$chksecurepass = Test-Path ("$dir\SecurePass.txt")

    if ($chksohsconfig -eq $false) {
        Write-Host " Error: StoreOnce Config file does not exist, unable to run the script" -ForegroundColor Yellow
        Start-Sleep -s 3 
        Exit }
   
    if ($chksecurekey -eq $false) {
        Write-Host " Error: SecureKey file does not exist, unable to run the script." -ForegroundColor Yellow
        Start-Sleep -s 3 
        Exit }
    
    if ($chksecurepass -eq $false) {
        Write-Host " Error: SecurePass file does not exist, unable to run the script." -ForegroundColor Yellow
        Start-Sleep -s 3 
        Exit }

    if ($chkrptdir -eq $false) {
        New-Item -Path $dir\Report -ItemType directory
        }

    if ($chksessionlog -eq $false) {
     New-Item  -Path "$dir\SessionLog.txt" -ItemType File
        "Timestamp            SessionId  Host                                                        Connected" | Out-File $dir\SessionLog.txt -Append
        "-------------------- ---------  ---------                                                   ---------" | Out-File $dir\SessionLog.txt -Append
        }

    if (Test-Path $rptdir\*.*){
	    Remove-Item $rptdir\*.*
        }

### Command execution wait time #####################################################################################
#Hardware Show Status
$HSSWTid = Get-Content  $sohsconfig | Where-Object {$_ -like '*HSSWT*'}
$HSSWTval =$HSSWTid.Remove(0,6)
$HSSWT = $HSSWTval

#ServiceSet Show Status
$SSSWTid = Get-Content  $sohsconfig | Where-Object {$_ -like '*SSSWT*'}
$SSSWT =$SSSWTid.Remove(0,6)

#System Show Performance
$SSPWTid = Get-Content  $sohsconfig | Where-Object {$_ -like '*SSPWT*'}
$SSPWT =$SSPWTid.Remove(0,6)

#System Show Packages
$SSVWTid = Get-Content  $sohsconfig | Where-Object {$_ -like '*SSCWT*'}
$SSVWT =$SSVWTid.Remove(0,6)

#System Show Config
$SSCWTid = Get-Content  $sohsconfig | Where-Object {$_ -like '*SSCWT*'}
$SSCWT =$SSCWTid.Remove(0,6)

#Hardware Show Problem
$HSPWTid = Get-Content  $sohsconfig | Where-Object {$_ -like '*HSPWT*'}
$HSPWT =$HSPWTid.Remove(0,6)

    if ($HSSWT -eq '' -or $HSSWT -eq 0) {
        Write-Host " Error: Hardware Show Status command wait time is null, invalid wait time" -ForegroundColor Yellow
        Start-Sleep -s 3 
        exit  
     } 
       
    if ($SSSWT -eq '' -or $SSSWT -eq 0) {
        Write-Host " Error: Serviceset Show Status command wait time is null, invalid wait time" -ForegroundColor Yellow
        Start-Sleep -s 3 
        exit  
     } 

     if ($SSPWT -eq '' -or $SSPWT -eq 0) {
        Write-Host " Error: System Show Performance command wait time is null, invalid wait time" -ForegroundColor Yellow
        Start-Sleep -s 3 
        exit  
     } 

     if ($SSVWT -eq '' -or $SSVWT -eq 0) {
        Write-Host " Error: System Show Packages command wait time is null, invalid wait time" -ForegroundColor Yellow
        Start-Sleep -s 3 
        exit  
     } 
     
     if ($SSCWT -eq '' -or $SSCWT -eq 0) {
        Write-Host " Error: System Show Config command wait time is null, invalid wait time" -ForegroundColor Yellow
        Start-Sleep -s 3 
        exit  
     } 

      if ($HSPWT -eq '' -or $HSPWT -eq 0) {
        Write-Host " Error: Hardware Show Problems command wait time is null, invalid wait time" -ForegroundColor Yellow
        Start-Sleep -s 3 
        exit  
     } 

### Authentication ##################################################################################################
$userid = Get-Content  $sohsconfig | Where-Object {$_ -like '*UID*'}
$username =$userid.Remove(0,4)

$secureKey = "$dir\Secure.key"
$securePass = "$dir\SecurePass.txt"
$key = Get-Content $SecureKey

$credential = New-Object -TypeName System.Management.Automation.PSCredential `
-ArgumentList $username, (Get-Content $SecurePass | ConvertTo-SecureString -Key $key)


### Get StoreOnce IP Address List ###################################################################################  
$soiparray = (Select-String -Path $sohsconfig -Pattern "^\d{1,3}(\.\d{1,3}){3}" | %{$_.line.split(";")}) -match "^\d{1,3}(\.\d{1,3}){3}"
$soiparray = $soiparray | Sort-Object -Unique

### Creating SSH session ############################################################################################
 ForEach ($_ in $soiparray){
    
    $SoIP = $_
    try
    {
        New-SSHSession -ComputerName $SoIP -Credential ($credential) -Port 22 -AcceptKey -ErrorAction Stop | ft -HideTableHeaders | Out-String | Out-File $dir\tmpsession.txt -Append
    }
    catch
    {   
        $ErrorMessage = $_.Exception.Message
                        
        if ($ErrorMessage -eq "Connection failed to establish within 10000 milliseconds.") {
            "           $SoIP connection timeout, unable to connect.       False" | Out-File $dir\tmpsession.txt -Append
            New-Item  -Path "$rptdir\$SoIP.txt" -ItemType File
            Start-Sleep -s 3 }

        elseif ($ErrorMessage -eq "No such host is known") {
            "           $SoIP Unknown host.                                False" | Out-File $dir\tmpsession.txt -Append
            New-Item  -Path "$rptdir\$SoIP.txt" -ItemType File
            Start-Sleep -s 3 }
                
        elseif ($ErrorMessage -eq "Key exchange negotiation failed.") {
            "           $SoIP Key exchange negotiation failed.             False" | Out-File $dir\tmpsession.txt -Append
            New-Item  -Path "$rptdir\$SoIP.txt" -ItemType File
            Start-Sleep -s 3 }

        elseif ($ErrorMessage -eq "Permission denied (password).") {
            "           $SoIP access denied, unable to connect.            False" | Out-File $dir\tmpsession.txt -Append
            New-Item  -Path "$rptdir\$SoIP.txt" -ItemType File
            Start-Sleep -s 3 }

        elseif ($ErrorMessage -eq "A parameter cannot be found that matches parameter name 'ComputerName1'.") {
            "           $SoIP IP address is invalid.                       False" | Out-File $dir\tmpsession.txt -Append
            New-Item  -Path "$rptdir\$SoIP.txt" -ItemType File
            Start-Sleep -s 3 }

        elseif ($ErrorMessage -eq "A socket operation was attempted to an unreachable network") {
            "           $SoIP IP address belongs to unreachable network.   False" | Out-File $dir\tmpsession.txt -Append
            New-Item  -Path "$rptdir\$SoIP.txt" -ItemType File
            Start-Sleep -s 3 }

        elseif ($ErrorMessage -eq "IPv4 address 0.0.0.0 and IPv6 address ::0 are unspecified addresses that cannot be used as a target address.") {
            "           $SoIP IP address is not a valid target address.    False" | Out-File $dir\tmpsession.txt -Append
            New-Item  -Path "$rptdir\$SoIP.txt" -ItemType File
            Start-Sleep -s 3 } 
        else {
        }     
    }
 } 

### Get Index, Session ID & Host IP Address ###########################################################################
$activeconarray = Get-SSHSession | foreach {$_.Host} 

### Run series of StoreOnce command ###################################################################################
 foreach ($_ in $activeconarray) {
  
  $hostip = $_
  $idx = [array]::IndexOf($activeconarray,"$hostip")  
    
    $SSHStream = New-SSHShellStream -Index $idx
    Start-Sleep -Seconds 5
    $SSHStream.read() | Out-File $rptdir\$hostip.txt
    "#" | Out-File $rptdir\$hostip.txt -Append
    $SSHStream.WriteLine("hardware show status")
    Start-Sleep -s $HSSWT
    $SSHStream.read() | Out-File $rptdir\$hostip.txt -Append
    "#" | Out-File $rptdir\$hostip.txt -Append
    $SSHStream.WriteLine("serviceset show status")
    Start-Sleep -s $SSSWT
    $SSHStream.read() | Out-File $rptdir\$hostip.txt -Append
    "#" | Out-File $rptdir\$hostip.txt -Append
    $SSHStream.WriteLine("system show performance")
    Start-Sleep -s $SSPWT
    $SSHStream.read() | Out-File $rptdir\$hostip.txt -Append
    "#" | Out-File $rptdir\$hostip.txt -Append
 } 

### Validate legacy StoreOnce #######################################################################################  
$rptitms = @(Get-ChildItem $rptdir\*.txt)
$legacySo = @()

 Foreach ($_ in $rptitms) {

    $hcrslt = Get-Content $_ | Out-String

    if ($hcrslt -eq $null -or $hcrslt.Length -eq 0) {  
    } 
        else {
            $fwver =  (Select-String -Pattern "\d.\d\d\.\d-\d\d\d\d.\d" -InputObject $hcrslt | %{$_.line.split("")}) -match "\d.\d\d\.\d-\d\d\d\d.\d"
        }         
            if ($fwver -eq $null -or $fwver.Length -eq 0 ) {
                $legacyhostip = $_.basename
                $legacySo += $legacyhostip
            }           
 }      
     
### Run StoreOnce show configuration command ######################################################################
 foreach ($_ in $legacySo) {
  
  $legacyhostip = $_
  $idx = [array]::IndexOf($activeconarray,"$legacyhostip")  
    
    $SSHStream = New-SSHShellStream -Index $idx
    Start-Sleep -Seconds 5
    $SSHStream.read() | Out-File $rptdir\$legacyhostip.txt -Append
    "#" | Out-File $rptdir\$legacyhostip.txt -Append
    $SSHStream.WriteLine("system show packages")
    Start-Sleep -s $SSVWT
    $SSHStream.read() | Out-File $rptdir\$legacyhostip.txt -Append 
    "#" | Out-File $rptdir\$legacyhostip.txt -Append
    $SSHStream.WriteLine("system show config")
    Start-Sleep -s $SSCWT
    $SSHStream.read() | Out-File $rptdir\$legacyhostip.txt -Append   
    "#" | Out-File $rptdir\$legacyhostip.txt -Append
  } 
  
### Validate NOK StoreOnce #########################################################################################  
$rptitms = @(Get-ChildItem $rptdir\*.txt)
$nokSo = @()

 Foreach ($_ in $rptitms) {

    $hcrslt = Get-Content $_ | Out-String

    if ($hcrslt -eq $null -or $hcrslt.Length -eq 0) {  
    } 
        else {
            $nok =  (Select-String -Pattern "DEGRADED|DOWN" -InputObject $hcrslt -AllMatches | %{$_.line.split("")}) -match "DEGRADED|DOWN"
        }         
            if ($nok -ne $null) {
                $nokhostip = $_.basename
                $nokSo += $nokhostip
            }           
 }      

### Run StoreOnce show problem command ##################################################################################
 foreach ($_ in $nokSo) {
  
  $nokhostip = $_
  $idx = [array]::IndexOf($activeconarray,"$nokhostip")  
    
    $SSHStream = New-SSHShellStream -Index $idx
    Start-Sleep -Seconds 5
    $SSHStream.read() | Out-File $rptdir\$nokhostip.txt -Append
    "#" | Out-File $rptdir\$nokhostip.txt -Append
    $SSHStream.WriteLine("hardware show problems")
    Start-Sleep -s $HSPWT
    $SSHStream.read() | Out-File $rptdir\$nokhostip.txt -Append    
    "#" | Out-File $rptdir\$nokhostip.txt -Append
  } 

### Report Clean-up ##################################################################################################
 Get-ChildItem $rptdir | ForEach-Object {
    $fname = $_.BaseName
    (Get-Content $rptdir\$fname.txt) | ? {$_.trim() -ne "" } | set-content $rptdir\$fname.txt
 }

### Log Clean-up #####################################################################################################
(Get-Content $dir\tmpsession.txt) | ? {$_.trim() -ne "" } | set-content $dir\tmpsession.txt

filter timestamp {"$(Get-Date -Format G) $_"}
 Get-Content $dir\tmpsession.txt | foreach {

  $_ | timestamp  | Out-File $dir\SessionLog.txt -Append 
 }  

Remove-Item $dir\tmpsession.txt