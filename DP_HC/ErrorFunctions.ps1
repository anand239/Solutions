Function Get-DpServiceError
{
    [CmdletBinding()]
    Param(
    $ErrorMessage
    )
    $Dp_Service_Result  = [PSCUSTOMObject] @{
    "Technology"        = $config.Technology
    "ReportType"        = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account"           = $config.Account
    "BackupServer"      = $Backupdevice
    "ReportDate"        = $Reportdate
    "HC_Parameter"      = "Service Status"
    "ServiceName"       = "$ErrorMessage"
    "ServiceStatus"     = "$ErrorMessage"
    }
    $Dpservice_signal    = [PSCUSTOMObject] @{
    "Technology"         = $config.Technology
    "ReportType"         = $config.ReportType
    "BackupApplication"  = $config.BackupApplication
    "Account"            = $config.Account
    "BackupServer"       = $Backupdevice
    "ReportDate"         = $Reportdate
    'HC_Parameter'       = "DP Service Status"
    "HC_ShortName"       = "SS"
    "Value"              = "$ErrorMessage"
    'Percentage'         = "0%"
    'Status'             = "R"
    }
    $Dpservice_signal,$Dp_Service_Result
}

Function Get-BackupSessionError
{
    [CmdletBinding()]
    Param(
    $ErrorMessage,
    $HCParameter,
    $HCShortName
    )
    $Queuing_Result = [PSCUSTOMObject] @{
    "Technology"        = $config.Technology
    "ReportType"        = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account"           = $config.Account
    "BackupServer"      = $Backupdevice
    "ReportDate"        = $Reportdate
    "HC_Parameter"      = $HCParameter
    "SessionId"         = "$ErrorMessage"
    "Session Type"      = "$ErrorMessage"
    "Backup Specification" = "$ErrorMessage"
    }
    $Signal_Report = [PSCUSTOMObject] @{
    "Technology"         = $config.Technology
    "ReportType"         = $config.ReportType
    "BackupApplication"  = $config.BackupApplication
    "Account"            = $config.Account
    "BackupServer"       = $Backupdevice
    "ReportDate"         = $Reportdate
    'HC_Parameter'       = $HCParameter
    "HC_ShortName"       = $HCShortName
    "Value"              = "$ErrorMessage"
    'Percentage'         = "0%"
    'Status'             = "R"
    }
    $Signal_Report,$Queuing_Result
}

Function Get-DisabledTapeDriveError
{
    [CmdletBinding()]
    Param(
    $ErrorMessage
    )
    $DisabledTapeDrive_Result  = [PSCUSTOMObject] @{
    "Technology"        = $config.Technology
    "ReportType"        = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account"           = $config.Account
    "BackupServer"      = $Backupdevice
    "ReportDate"        = $Reportdate
    "HC_Parameter"      = "Disabled Tape Drive Count"
    "Library"           = $ErrorMessage
    "Drive Name"        = $ErrorMessage
    "Status"            = $ErrorMessage
    }
    $Disabled_TapeDrive_signal    = [PSCUSTOMObject] @{
    "Technology"         = $config.Technology
    "ReportType"         = $config.ReportType
    "BackupApplication"  = $config.BackupApplication
    "Account"            = $config.Account
    "BackupServer"       = $Backupdevice
    "ReportDate"         = $Reportdate
    'HC_Parameter'       = "Disabled Tape Drive Count"
    "HC_ShortName"       = "DTD"
    "Value"              = "$ErrorMessage"
    'Percentage'         = "0%"
    'Status'             = "R"
    }
    $Disabled_TapeDrive_signal,$DisabledTapeDrive_Result
}

Function Get-ScratchMediaError
{
    [CmdletBinding()]
    Param(
    $ErrorMessage
    )
    $ScratchMedia_Result= [PSCUSTOMObject] @{
    "Technology"        = $config.Technology
    "ReportType"        = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account"           = $config.Account
    "BackupServer"      = $Backupdevice
    "ReportDate"        = $Reportdate
    "HC_Parameter"      = "Scratch Media Count"
    "Pool Name"         = $ErrorMessage
    "Scratch Media"     = $ErrorMessage
    "Total Media"       = $ErrorMessage
    }
    $Scratch_Media_signal= [PSCUSTOMObject] @{
    "Technology"         = $config.Technology
    "ReportType"         = $config.ReportType
    "BackupApplication"  = $config.BackupApplication
    "Account"            = $config.Account
    "BackupServer"       = $Backupdevice
    "ReportDate"         = $Reportdate
    'HC_Parameter'       = "Scratch Media Count"
    "HC_ShortName"       = "SM"
    "Value"              = "$ErrorMessage"
    'Percentage'         = "0%"
    'Status'             = "R"
    }
    $Scratch_Media_signal,$ScratchMedia_Result
}

Function Get-FailedBackupError
{
    [CmdletBinding()]
    Param(
    $ErrorMessage,
    $HCParameter,
    $HCShortName
    )
    $FailedBackup_result= [PSCUSTOMObject] @{
    "Technology"        = $config.Technology
    "ReportType"        = $config.ReportType
    "BackupApplication" = $config.BackupApplication
    "Account"           = $config.Account
    "BackupServer"      = $Backupdevice
    "ReportDate"        = $Reportdate
    "HC_Parameter"      = $HCParameter
    "Specification"     = "$ErrorMessage"
    "Status"            = "$ErrorMessage"
    "SessionId"         = "$ErrorMessage"
    "Mode"              = "$ErrorMessage"
    }
    $Failed_bck_signal   = [PSCUSTOMObject] @{
    "Technology"         = $config.Technology
    "ReportType"         = $config.ReportType
    "BackupApplication"  = $config.BackupApplication
    "Account"            = $config.Account
    "BackupServer"       = $Backupdevice
    "ReportDate"         = $Reportdate
    'HC_Parameter'       = $HCParameter
    "HC_ShortName"       = $HCShortName
    "Value"              = "$ErrorMessage"
    'Percentage'         = "0%"
    'Status'             = "R"
    }
    $Failed_bck_signal,$FailedBackup_result
}

Function Get-FreeDiskSpaceError
{
    [CmdletBinding()]
    Param(
    $ErrorMessage
    )
    $FreeDiskSpace_Result= [PSCUSTOMObject] @{
    "Technology"         = $config.Technology
    "ReportType"         = $config.ReportType
    "BackupApplication"  = $config.BackupApplication
    "Account"            = $config.Account
    "BackupServer"       = $Backupdevice
    "ReportDate"         = $Reportdate
    "HC_Parameter"       = "Free Disk Space"
    "Drive/MountPoint"   = $ErrorMessage
    "Free Space"         = $ErrorMessage
    "Total Size"         = $ErrorMessage
    }
    $FreeDiskSpace_signal= [PSCUSTOMObject] @{
    "Technology"         = $config.Technology
    "ReportType"         = $config.ReportType
    "BackupApplication"  = $config.BackupApplication
    "Account"            = $config.Account
    "BackupServer"       = $Backupdevice
    "ReportDate"         = $Reportdate
    'HC_Parameter'       = "Free Disk Space"
    "HC_ShortName"       = "FDS"
    "Value"              = "$ErrorMessage"
    'Percentage'         = "0%"
    'Status'             = "R"
    }
    $FreeDiskSpace_signal,$FreeDiskSpace_Result
}

Function Get-IDBError
{
    [CmdletBinding()]
    Param(
    $ErrorMessage
    )
    $IDB_Backup_Result   = [PSCUSTOMObject] @{
    "Technology"         = $config.Technology
    "ReportType"         = $config.ReportType
    "BackupApplication"  = $config.BackupApplication
    "Account"            = $config.Account
    "BackupServer"       = $Backupdevice
    "ReportDate"         = $Reportdate
    "HC_Parameter"       = "IDB Backup Status"
    "Specification"      = $ErrorMessage
    "SessionId"          = $ErrorMessage
    "Start Time"         = $ErrorMessage
    "Status"             = $ErrorMessage
    }
    $IDBBackup_Signal    = [PSCUSTOMObject] @{
    "Technology"         = $config.Technology
    "ReportType"         = $config.ReportType
    "BackupApplication"  = $config.BackupApplication
    "Account"            = $config.Account
    "BackupServer"       = $Backupdevice
    "ReportDate"         = $Reportdate
    'HC_Parameter'       = "IDB Backup Status"
    "HC_ShortName"       = "IDB"
    "Value"              = "$ErrorMessage"
    'Percentage'         = "0%"
    'Status'             = "R"
    }
    $IDBBackup_Signal,$IDB_Backup_Result
}

Function Get-LibraryError
{
    [CmdletBinding()]
    Param(
    $ErrorMessage
    )
    $LibraryStatus_Result = [PSCUSTOMObject] @{
    "Technology"          = $config.Technology
    "ReportType"          = $config.ReportType
    "BackupApplication"   = $config.BackupApplication
    "Account"             = $config.Account
    "BackupServer"        = $Backupdevice
    "ReportDate"          = $Reportdate
    "HC_Parameter"        = "Library Status"
    "Library Name/IP"     = $ErrorMessage
    "Status"              = $ErrorMessage
    }
    $Library_Status_signal= [PSCUSTOMObject] @{
    "Technology"          = $config.Technology
    "ReportType"          = $config.ReportType
    "BackupApplication"   = $config.BackupApplication
    "Account"             = $config.Account
    "BackupServer"        = $Backupdevice
    "ReportDate"          = $Reportdate          
    'HC_Parameter'        = "Library Status"
    "HC_ShortName"        = "LS"
    "Value"               = $ErrorMessage
    'Percentage'          = "0%"
    'Status'              = "R"
    }
    $Library_Status_signal,$LibraryStatus_Result
}

Function Get-DisabledJobError
{
    $DisabledBackupJob_Result = [PSCUSTOMObject] @{
    "Technology"              = $config.Technology
    "ReportType"              = $config.ReportType
    "BackupApplication"       = $config.BackupApplication
    "Account"                 = $config.Account
    "BackupServer"            = $Backupdevice
    "ReportDate"              = $Reportdate
    "HC_Parameter"            = "Disabled Backup Job Count"
    "Specification"           = "$ErrorMessage"
    "Status"                  = "$ErrorMessage"
    }
    $DisabledBackupJob_Signal = [PSCUSTOMObject] @{
    "Technology"              = $config.Technology
    "ReportType"              = $config.ReportType
    "BackupApplication"       = $config.BackupApplication
    "Account"                 = $config.Account
    "BackupServer"            = $Backupdevice
    "ReportDate"              = $Reportdate          
    'HC_Parameter'            = "Disabled Backup Job Count"
    "HC_ShortName"            = "DB"
    "Value"                   = "$ErrorMessage"
    'Percentage'              = "0%"
    'Status'                  = "R"
    }
    $DisabledBackupJob_Signal,$DisabledBackupJob_Result
}



$Dpservice_signal,$Dp_Service_Result                  = Get-DpServiceError         -ErrorMessage "Failed To Run Command"
$Queuing_gt30_signal,$Queuing_30_Result               = Get-BackupSessionError     -ErrorMessage "Failed To Run Command" -HCParameter "Queuing Backup Count(>30 min)" -HCShortName "WQB"
$Queuing_lt24_signal,$Queuing_lt24_Result             = Get-BackupSessionError     -ErrorMessage "Failed To Run Command" -HCParameter "Long Running Backup Count(>12 Hr and <24 Hr)" -HCShortName "LB_12"
$Queuing_gt24_signal,$Queuing_gt24_Result             = Get-BackupSessionError     -ErrorMessage "Failed To Run Command" -HCParameter "Long Running Backup Count(>24 Hr)" -HCShortName "LB_24"
$Mount_req_signal,$Mount_Request_Result               = Get-BackupSessionError     -ErrorMessage "Failed To Run Command" -HCParameter "Mount Request" -HCShortName "MR"
$Disabled_TapeDrive_signal,$Disabled_TapeDrive_Result = Get-DisabledTapeDriveError -ErrorMessage "Failed To Run Command"
$Scratch_Media_signal,$Scratch_Media_Result           = Get-ScratchMediaError      -ErrorMessage "Failed To Run Command"
$Failed_bck_signal,$Failed_Bck_result                 = Get-FailedBackupError      -ErrorMessage "Failed To Run Command" -HCParameter "Failed Backup Count"    -HCShortName "FB"
$Critical_Backup_signal,$Critical_Bck_result          = Get-FailedBackupError      -ErrorMessage "Failed To Run Command" -HCParameter "Critical Backup Status" -HCShortName "CB"
$IDBBackup_Signal,$IDB_Backup_Result                  = Get-IDBError               -ErrorMessage "Failed To Run Command"
$Hung_Bck_signal,$HungBackup_Result                   = Get-BackupSessionError     -ErrorMessage "Failed To Run Command" -HCParameter "Hung Backup Count" -HCShortName "HB"
$DisabledBackupJob_Signal,$DisabledBackupJob_Result   = Get-DisabledJobError       -ErrorMessage "No Disabled Jobs"
$FreeDiskSpace_signal,$FreeDiskSpace_Result           = Get-FreeDiskSpaceError     -ErrorMessage "Failed to Run Command"
$Library_Status_signal,$LibraryStatus_Result          = Get-LibraryError           -ErrorMessage "Invalid Librarydetails.txt"




Function Export-DPFiles
{
    $SignalReport             | Export-Csv -Path $SignalReportName             -NoTypeInformation
    $Dp_Service_Result        | Export-Csv -Path $DpService_ReportName         -NoTypeInformation
    $Queuing_30_Result        | Export-Csv -Path $Queuing30_ReportName         -NoTypeInformation
    $Queuing_lt24_Result      | Export-Csv -Path $Queuing_lt24_ReportName      -NoTypeInformation
    $Queuing_gt24_Result      | Export-Csv -Path $Queuing_gt24_ReportName      -NoTypeInformation
    $Mount_Request_Result     | Export-Csv -Path $MountRequest_ReportName      -NoTypeInformation
    $Disabled_TapeDrive_Result| Export-Csv -Path $DisabledTapeDrive_ReportName -NoTypeInformation
    $Scratch_Media_Result     | Export-Csv -Path $ScratchMedia_ReportName      -NoTypeInformation
    $Failed_Bck_result        | Export-Csv -Path $FailedBackup_ReportName      -NoTypeInformation
    $IDB_Backup_Result        | Export-Csv -Path $IDBBackup_ReportName         -NoTypeInformation
    $Critical_Bck_result      | Export-Csv -Path $CriticalBackup_ReportName    -NoTypeInformation
    $LibraryStatus_Result     | Export-Csv -Path $LibraryStatus_ReportName     -NoTypeInformation
    $HungBackup_Result        | Export-Csv -Path $HungBackup_ReportName        -NoTypeInformation
    $DisabledBackupJob_Result | Export-Csv -Path $DisabledBackupJob_ReportName -NoTypeInformation
    $FreeDiskSpace_Result     | Export-Csv -Path $FreeDiskSpace_ReportName     -NoTypeInformation
}


$SignalReport += $Dpservice_signal
$SignalReport += $Queuing_gt30_signal
$SignalReport += $Queuing_lt24_signal
$SignalReport += $Queuing_gt24_signal
$SignalReport += $Mount_req_signal
$SignalReport += $Disabled_TapeDrive_signal
$SignalReport += $Scratch_Media_signal
$SignalReport += $Failed_bck_signal
$SignalReport += $Critical_Backup_signal
$SignalReport += $IDBBackup_Signal
$SignalReport += $Library_Status_signal
$SignalReport += $Hung_Bck_signal
$SignalReport += $DisabledBackupJob_Signal
$SignalReport += $FreeDiskSpace_signal
$SignalReport += $FreeDiskSpaceDataDisk_signal