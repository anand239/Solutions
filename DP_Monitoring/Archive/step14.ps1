Function Get-BackupStatus
{
    [CmdletBinding()]
    Param(
    $InputObject
    )
    $Backup_Object = @()
    $Backup_Input = $InputObject | Where {$_}
    if( "No currently running sessions." -in $Backup_Input)
    {
        $result = "No currently running sessions."
        $result
    }
    else
    {
        for($i=0;$i -lt $Backup_Input.Count;$i+=6)
        {
  
            $obj = New-Object psObject
            $arr =$Backup_Input[$i] -split ": " 
            $obj | Add-Member NoteProperty "SessionID"  $arr[1].trim()
            $arr =$Backup_Input[$i+1] -split ": "
            $obj | Add-Member NoteProperty "Type"  $arr[1].trim()
            $arr =$Backup_Input[$i+2] -split ": "
            $obj | Add-Member NoteProperty "Status"  $arr[1].trim()
            $arr =$Backup_Input[$i+3] -split ": "
            $obj | Add-Member NoteProperty "User"  $arr[1].trim()
            $arr =$Backup_Input[$i+5] -split ":"
            $obj | Add-Member NoteProperty "Specification"  $arr[1].trim()
            $Backup_Object += $obj
        }
        $Backup_Object
    }
}


$Omnistat_Object = Get-BackupStatus -InputObject 