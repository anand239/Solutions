$vCenterServer = ""
$credential = Get-Credential
Connect-VIServer -Server $vCenterServer -credentail $credential


$vm = Get-VM -Name ""
$driveLetter = "<DriveLetter>"
$hardDisk = Get-HardDisk -VM $vm | Where-Object { $_.ExtensionData.Backing.FileName -like "*$driveLetter.vmdk" }
Set-HardDisk -HardDisk $hardDisk -CapacityGB "<NewSize>"

$vm = Get-VM -Name ""
$driveLetter = "<DriveLetter>"
$hardDiskNumber = (Get-VMGuest -VM $vm).Disk | Where-Object { $_.Drive -eq $driveLetter } | Select-Object -ExpandProperty Key



$datastore = Get-VMHost -VM $vm | Get-Datastore | Sort-Object -Property FreeSpaceGB -Descending | Select-Object -First 1
$disk = Get-HardDisk -VM $vm
$expansionSize = "<ExpansionSize>"
$requiredSize = $disk.CapacityGB + $expansionSize



$diskName = "<DiskName>"
$disk = Get-HardDisk -VM $vm | Where-Object { $_.Name -eq $diskName }
$datastore = Get-Datastore -Id $disk.ExtensionData.Backing.Datastore.Value



$diskNumber = "<DiskNumber>"
$disk = Get-ScsiLun -VM $vm | Where-Object { $_.CanonicalName -match "naa.$diskNumber" }
$datastore = Get-Datastore -Id $disk.ExtensionData.ScsiLun.Vmfs.UniqueId


