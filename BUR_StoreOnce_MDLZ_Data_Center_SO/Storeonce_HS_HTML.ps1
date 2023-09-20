<#===================================================================================================================
	SUMMARY
	-----------
        StoreOnce Hardware Status (SoHS) Check Html Report

	DESCRIPTION
	-----------
	    This script allows you to convert storeonce hardware status report text file to Html format.
	
    PREREQUISITES
	------------

    System Requirements
        Windows 2008 above
        PowerShell
        

	Input File(s)
	    SoHS_Check.txt File

	Output File(s)
        SoHS_Check_Html File
	
	
#===================================================================================================================#>

### Variables ########################################################################################################
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$date = Get-Date -UFormat "%m%d%Y"
$timestamp = Get-Date -Format HHmmss
$datetime = $date + $timestamp

$rptdir = "$dir\Report"

### Get raw data from config file ####################################################################################
$soraw = Get-Content $dir\SoHS_Config.cfg | Where-Object {$_ -match '^\d'}
$sorawarray = @()

 foreach ($_ in $soraw)   {
    $rdata = $_ -split (';')

    $rawitm = New-Object System.Object    
    $rawitm | Add-Member -type NoteProperty -name 'Ipadd' -Value $rdata[0]
    $rawitm | Add-Member -type NoteProperty -name 'Fqdn' -Value $rdata[1]
    $rawitm | Add-Member -type NoteProperty -name 'Site' -Value $rdata[2]
    $rawitm | Add-Member -type NoteProperty -name 'Mdl' -Value $rdata[3]
    $rawitm | Add-Member -type NoteProperty -name 'Fw' -Value $rdata[4]
    $rawitm | Add-Member -type NoteProperty -name 'Desc' -Value $rdata[5]
    
    $sorawarray += $rawitm
 }

### Healthcheck Report ###############################################################################################
$rptitems = @(Get-ChildItem $rptdir\*.txt)

# Convert ">" to "#" of healthcheck raw file
 Foreach  ($_ in $rptitems) {
    $rawhc = $_
    (Get-content $rawhc) | foreach-object {$_ -replace '^(>)' , '#'} | set-content $rawhc
    (Get-content $rawhc) | foreach-object {$_ -replace '^(.>)' , '#'} | set-content $rawhc     
 }

$hcarray = @()

 Foreach ($_ in $rptitems) {

    Write-Host $rptitems."Name".IndexOf($_.Name)
    $items = $rptitems."Name".IndexOf($_.Name) + 1

    ($hcresult, $hcsection, $hcresultarray, $hc1, $hc2, $hc3, $hc4, $hc5, $hc6, $hc7, $hc8) =''
    ($fname, $sofqdn, $sosite, $sostatus, $model,$somodel, $fwversion, $hsstmp, $hss, $ssstmp, $sss, $ssptmp, $ssp, $hsptmp, $hsp, $hcobject) = ''
    ($current, $cur, $maximum, $max, $caparray) = ''

    $fname = $_.BaseName
    $hcresult = Get-Content $_ | Out-String
    $hcsection = ($hcresult | Select-String "#" -AllMatches).Matches.Index

    try
     {  
        $hc1 = $hcresult.substring($hcsection[0], ($hcsection[1] - $hcsection[0]))
        $hc2 = $hcresult.substring($hcsection[1], ($hcsection[2] - $hcsection[1]))
        $hc3 = $hcresult.substring($hcsection[2], ($hcsection[3] - $hcsection[2]))
        $hc4 = $hcresult.substring($hcsection[3], ($hcsection[4] - $hcsection[3]))
        $hc5 = $hcresult.substring($hcsection[4], ($hcsection[5] - $hcsection[4]))
        $hc6 = $hcresult.substring($hcsection[5], ($hcsection[6] - $hcsection[5]))
        $hc7 = $hcresult.substring($hcsection[6], ($hcsection[7] - $hcsection[6]))
        $hc8 = $hcresult.substring($hcsection[7], ($hcsection[8] - $hcsection[7]))
      }
    catch { } 

    # Check device status
    if ($hcresult) { 
            $sostatus = 'Online' } else  { $sostatus = 'Offline' }

    # Extract firmware version
    #$fwversion =  (Select-String -Pattern "\d.\d\d\.\d-\d\d\d\d.\d" -InputObject $hcresult | %{$_.line.split("")}) -match "\d.\d\d\.\d-\d\d\d\d.\d" | Select-Object -First 1
    
    $fwversion = ((Get-Content $_  | where{$_ -like "*Software ver*"} | select -First 1) -split ":") | select -last 1
    
    # Extract product class 
    try{            
        $model =  Get-Content $_  | Where-Object {$_ -like '*Product class*'}
        $model = $model | Sort-Object -Unique
        $somodel =$model.TrimStart('Product Class  :  ') }
    Catch{ }  
     
    # Extract device fqdn from raw data
    $fqdnidx = [array]::IndexOf($sorawarray.Ipadd,"$fname") 
    if ($fqdnidx -eq -1) {
        $sofqdn = ''
    } else {$sofqdn = $sorawarray.Fqdn[$fqdnidx]}

    # Extract site name from raw data
    $siteidx = [array]::IndexOf($sorawarray.Ipadd,"$fname") 
    if ($siteidx -eq -1) {
        $sosite = ''
    } else {$sosite = $sorawarray.Site[$siteidx]}
    
        # Creating healthcheck array    
    $hcresultarray  = @($sostatus, $somodel, $fwversion, $hc1, $hc2, $hc3, $hc4, $hc5, $hc6, $hc7, $hc8)              
    foreach ($_ in $hcresultarray ) {  
    
    if ($_ -match "hardware show status") {         
        $hsstmp = $_                     
            If ($hsstmp | Select-String -Pattern "DEGRADED" -Quiet) {                        
                $hss = "NOK = " }
                                    
                elseif ($hsstmp | Select-String -Pattern "DOWN" -Quiet) {
                    $hss = "NOK = " } 
                
                elseif ($hsstmp | Select-String -Pattern "OK" -Quiet) {
                $hss = "OK" }

                elseif ($hsstmp | Select-String -Pattern "UP" -Quiet) {
                $hss = "OK" }                                                                                                                   
    }

        elseif ($_ -match "serviceset show status") {                         
            $ssstmp = $_
                        
                If ($ssstmp | Select-String -Pattern "STOPPED" -Quiet) {                        
                    $sss = "Stopped" } 
                                                                        
                    elseif ($ssstmp | Select-String -Pattern "INITIALIZING" -Quiet) { 
                        $sss = "Initializing"} else {$sss = "Running"}                                    
        }

        elseif ($_ -match "system show performance") {

            $_ | Out-File $rptdir\ssptmp.txt                                 
            $ssptmp  = Get-Content $rptdir\ssptmp.txt | Where-Object {$_ -like '*Service Set*'}                       
            $current = Get-Content $rptdir\ssptmp.txt  | Where-Object {$_ -like '*Current:*'}
            $maximum = Get-Content $rptdir\ssptmp.txt  | Where-Object {$_ -like '*Maximum:*'}
            #$cur = (Select-String -Pattern "\d.\d" -InputObject $current -AllMatches | %{$_.line.split("")}) -match "\d.\d"
            #$max = (Select-String -Pattern "\d.\d" -InputObject $maximum -AllMatches | %{$_.line.split("")}) -match "\d.\d"
            $cur = $current -split ":" | select -Last 1  
            $max = $maximum -split ":" | select -Last 1 
                # Capacity Utilization
                $caparray = @()

                    foreach ($_ in $ssptmp ){
                        $capidx = [array]::IndexOf($ssptmp, $_)
                        $util = ($cur[$capidx] / $max[$capidx]) * 100
                        #$cap = $_ + " = " + "{0:N2}" -f $util + "% | "
                        $cap = $_ + " C =$cur , M =$max"  + "`n"                                                      
                        $caparray += $cap
                    }
                        $ssp = $caparray
                        Remove-Item $rptdir\ssptmp.txt 
        }    
                         
        elseif ($_ -match "hardware show problems") {                         
            $hsptmp = $_   
                                     
                $hsp = (Select-String -Pattern "BATTERY|CONTROLLER|COUPLET|CPU|DISK_ENCLOSURE|DRIVE|DRIVE_ENCLOSURE|FAN|HBA|HBA_PORT|IO_CACHE_MODULE|ILO_MODULE|LOGICAL_DISK|MANAGEMENT_PROCESSOR| `
                                                MEMORY_DIMM|NETWORK_BOND|NETWORK_MODULE|PHYSICAL_DISK|POOl|PORT|POWER_MANAGEMENT_CONTROLLER|POWER_SUPPLY|RAID_SET|SERVER|SERVER_STORAGE| `
                                                STORAGE_ARRAY|STORAGE_CLUSTER|STORAGE_CONTROLLER|SUPER_CAPACITOR|TEMPERATURE_SENSOR|VIF|VOLUME" `
                -InputObject $hsptmp -AllMatches | %{$_.line.split("")}) -match ` 
                                               "BATTERY|CONTROLLER|COUPLET|CPU|DISK_ENCLOSURE|DRIVE|DRIVE_ENCLOSURE|\bFAN\b|HBA|HBA_PORT|IO_CACHE_MODULE|ILO_MODULE|LOGICAL_DISK|MANAGEMENT_PROCESSOR| `
                                                MEMORY_DIMM|NETWORK_BOND|NETWORK_MODULE|PHYSICAL_DISK|POOl|PORT|POWER_MANAGEMENT_CONTROLLER|POWER_SUPPLY|RAID_SET|SERVER|SERVER_STORAGE| `
                                                STORAGE_ARRAY|STORAGE_CLUSTER|STORAGE_CONTROLLER|SUPER_CAPACITOR|TEMPERATURE_SENSOR|VIF|VOLUME"  
                                                  
                $hsp = ($hsp | Sort-Object -Unique) -join "; "                        
        } 
    }

    # Creating object in array
    $hcobject = New-Object System.Object    
    $hcobject | Add-Member -type NoteProperty -name 'Items' -Value $items
    $hcobject | Add-Member -type NoteProperty -name 'IP Address' -Value $fname
    $hcobject | Add-Member -type NoteProperty -name 'Device Name' -Value $sofqdn
    $hcobject | Add-Member -type NoteProperty -name 'Site' -Value $sosite
    $hcobject | Add-Member -type NoteProperty -name 'Status' -Value $sostatus
    $hcobject | Add-Member -type NoteProperty -name 'Model' -Value $somodel
    $hcobject | Add-Member -type NoteProperty -name 'Firmware Version' -Value $fwversion
    $hcobject | Add-Member -type NoteProperty -name 'Hardware Status' -Value "$hss $hsp"
    $hcobject | Add-Member -type NoteProperty -name 'Service Set Status' -Value $sss
    $hcobject | Add-Member -type NoteProperty -name 'Capacity Utilization' -Value $ssp

    $hcarray += $hcobject   
        
    }   
    
### Table name #######################################################################################################
$tabName = “StoreOnce Hardware Status Report”
 
### Create Table object ##############################################################################################
$table = New-Object system.Data.DataTable “$tabName”
 
### Define Columns ###################################################################################################
$col1 = New-Object system.Data.DataColumn "Items",([string])
$col2 = New-Object system.Data.DataColumn "IP Address",([string])
$col3 = New-Object system.Data.DataColumn "Device Name",([string])
$col4 = New-Object system.Data.DataColumn "Site",([string])
$col5 = New-Object system.Data.DataColumn "Status",([string])
$col6 = New-Object system.Data.DataColumn "Model",([string])
$col7 = New-Object system.Data.DataColumn "Firmware Version",([string])
$col8 = New-Object system.Data.DataColumn "Hardware Status",([string])
$col9 = New-Object system.Data.DataColumn "Service Set Status",([string])
$col10 = New-Object system.Data.DataColumn "Capacity Utilization",([string])
 
### Add the Columns ##################################################################################################
$table.columns.add($col1)
$table.columns.add($col2)
$table.columns.add($col3)
$table.columns.add($col4)
$table.columns.add($col5)
$table.columns.add($col6)    
$table.columns.add($col7)  
$table.columns.add($col8) 
$table.columns.add($col9)  
$table.columns.add($col10) 


$hciparray = $hcarray | foreach {$_."IP Address"} 

 ForEach ($_ in $hciparray ) {
  $idx = [array]::IndexOf($hciparray,"$_")
  $myarray1 = $hcarray[$idx] | Select-Object "Items","IP Address", "Device Name", "Site", "Status", "Model", "Firmware Version", "Hardware Status", "Service Set Status", "Capacity Utilization"
 
    #Create a row
       $row = $table.NewRow()
         
    #Enter data in the row
       $row.'Items' = ($myarray1.'Items') | Out-String
       $row.'IP Address' = ($myarray1.'IP Address') | Out-String
       $row.'Device Name' = ($myarray1.'Device Name') | Out-String
       $row.'Site' = ($myarray1.'Site') | Out-String
       $row.'Status' = ($myarray1.'Status') | Out-String
       $row.'Model' = ($myarray1.'Model') | Out-String
       $row.'Firmware Version' = ($myarray1.'Firmware Version') | Out-String
       $row.'Hardware Status'= ($myarray1.'Hardware Status') | Out-String
       $row.'Service Set Status'= ($myarray1.'Service Set Status') | Out-String
       $row.'Capacity Utilization' = ($myarray1.'Capacity Utilization') | Out-String
 
     #Add the row to the table
       $table.Rows.Add($row)           
}        

### Conditional formatting Html Report ##############################################################################
$fragments = @()

$logopath = "$dir\dxc_logo_black.png"
$logobits =  [Convert]::ToBase64String((Get-Content $logopath -Encoding Byte))
$logofile = Get-Item $logopath
$logotype = $logofile.Extension.Substring(1) #strip off the leading 
$logotag = "<Img src='data:image/$logotype;base64,$($logobits)' Alt='$($logofile.Name)' style='left' width='326' height='57' hspace=10>"	

[xml]$html = $table | select -Property "Items", "IP Address", "Device Name", "Site", "Status", "Model", "Firmware Version", "Hardware Status", "Service Set Status", "Capacity Utilization" | sort -Property "IP Address" | convertto-html -Fragment
 
for ($i=1;$i -le $html.table.tr.count-1;$i++) {

  if ($html.table.tr[$i].td[4] -match 'Offline' ) {
    $class = $html.CreateAttribute("class")
    $class.value = 'red'
    $html.table.tr[$i].childnodes[4].attributes.append($class) | out-null } 
    
    else  {
        $class = $html.CreateAttribute("class")
        $class.value = 'green'
        $html.table.tr[$i].childnodes[4].attributes.append($class) | out-null  
    }
}

for ($i=1;$i -le $html.table.tr.count-1;$i++) {

  if ($html.table.tr[$i].td[7] -match 'NOK' ) {
    $class = $html.CreateAttribute("class")
    $class.value = 'red'
    $html.table.tr[$i].childnodes[7].attributes.append($class) | out-null } 

        elseif ($html.table.tr[$i].td[7] -match 'OK' ) {
            $class = $html.CreateAttribute("class")
            $class.value = 'green'
            $html.table.tr[$i].childnodes[7].attributes.append($class) | out-null }
    }

for ($i=1;$i -le $html.table.tr.count-1;$i++) {

  if ($html.table.tr[$i].td[8] -match 'Stopped' ) {
    $class = $html.CreateAttribute("class")
    $class.value = 'red'
    $html.table.tr[$i].childnodes[8].attributes.append($class) | out-null }

        elseif ($html.table.tr[$i].td[8] -match 'Initializing' ) {
            $class = $html.CreateAttribute("class")
            $class.value = 'amber'
            $html.table.tr[$i].childnodes[8].attributes.append($class) | out-null }

        elseif ($html.table.tr[$i].td[8] -match 'Running' ) {
            $class = $html.CreateAttribute("class")
            $class.value = 'green'
            $html.table.tr[$i].childnodes[8].attributes.append($class) | out-null }
  }
  <#
  for ($i=1;$i -le $html.table.tr.count-1;$i++) {

  if ($html.table.tr[$i].td[9] -match '10\d.\d') {
    $class = $html.CreateAttribute("class")
    $class.value = 'red'
    $html.table.tr[$i].childnodes[9].attributes.append($class) | out-null }

        elseif ($html.table.tr[$i].td[9] -match '9[0-9].\d' ) {
            $class = $html.CreateAttribute("class")
            $class.value = 'red'
            $html.table.tr[$i].childnodes[9].attributes.append($class) | out-null }
        
        elseif ($html.table.tr[$i].td[9] -match '8[5-9].\d' ) {
            $class = $html.CreateAttribute("class")
            $class.value = 'red'
            $html.table.tr[$i].childnodes[9].attributes.append($class) | out-null }

        elseif ($html.table.tr[$i].td[9] -match '8[0-4].\d' ) {
            $class = $html.CreateAttribute("class")
            $class.value = 'amber'
            $html.table.tr[$i].childnodes[9].attributes.append($class) | out-null }
 }#>
   
$fragments+= $html.InnerXml
$fragments+= "<p class='footer'>$(get-date)</p>"

### HTML Report Format ###############################################################################################
$convertParams = @{ 

  head = @"

  <title> SoHS Check Report </title>
 <style>

  body {
    font-family: "Arial"; 
    font-size: 10pt; 
    color: black;
    }

  th, td { 
    border: 1px solid #5F6A6A; 
    border-collapse: collapse; 
    padding: 5px; 
    } 
  
  th {
    font-size: 1.5em; text-align: left; 
    background-color: #000000; 
    color: #ffffff;
    }  
  tr:nth-child(even) {
    background-color: #f2f2f2;
  }

  .amber {
    color: #FFBF00; 
    }  
  .green {
    color: green; 
    } 
  .red {
    color: red; 
    }  
  .footer { 
    color:black; 
    margin-left:10px; 
    font-family:Tahoma;
    font-size:10pt;
    font-style:italic;
    }       

</style>

<body> 
     <h1>$logotag</h1>
     <font color=`"black`">
     <h2>StoreOnce Hardware Status Report</h2>
     </font>         
</body  

"@
 body = $fragments
}

### Convert report to Html format ####################################################################################
convertto-html @convertParams | out-file $rptdir\SoHS_Check_$datetime.html
#Remove-Item $rptdir\*.txt
#Invoke-Item $rptdir\SoHS_Check_$datetime.html

### Email Html Report ################################################################################################
$acctval = Get-Content  $dir\SoHS_Config.cfg | Where-Object {$_ -match '^Account'}
$acct =$acctval.Remove(0,8)

$smtpval = Get-Content  $dir\SoHS_Config.cfg | Where-Object {$_ -match '^SMTP_Server'}
$smtp =$smtpval.Remove(0,12)

$fromval = Get-Content  $dir\SoHS_Config.cfg | Where-Object {$_ -match '^From'}
$from =$fromval.Remove(0,5)
$secpwd = ConvertTo-SecureString " " -AsPlainText -Force

$toval = Get-Content  $dir\SoHS_Config.cfg | Where-Object {$_ -match '^To'}
$to =$toval.Remove(0,3)
$to = $to -split (';')

$subject = "$acct - Mondelez DataCenter Storeonce devices health check summary "
$body = Get-Content $rptdir\SoHS_Check_$datetime.html -Raw

start-sleep -s 2

 if ($smtp -eq $null -or $smtp.Length -eq 0) {  
    } 
        elseif ($from -eq $null -or $from.Length -eq 0) {            
        }
        elseif ($to -eq $null -or $to.Length -eq 0) {            
        } 
            else {

                $emailcreds = New-Object System.Management.Automation.PSCredential ($from, $secpwd)

                foreach ($_ in $to) {  
                                  
                    Send-MailMessage -To $_ -From $from -Subject $subject -BodyAsHtml $body -SmtpServer $smtp -Credential $emailcreds -Port 25 -Attachments $rptdir\SoHS_Check_$datetime.html -DeliveryNotificationOption Never -ErrorAction SilentlyContinue     
                }        
            } 