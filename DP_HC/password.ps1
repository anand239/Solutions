if($BkpDevice -ne "LocalHost")
{
    Write-Log -Path $Activitylog -Entry "Checking For Credential!" -Type Information -ShowOnConsole
    $CredentialPath = $config.CredentialFile

    if (!(Test-Path -Path $CredentialPath) )
    {
        if($config.UsePasswordFile -eq "Yes")
        {
            if(Test-Path -Path $config.Passwordfile)
            {
                $PasswordFileData = Import-Csv -Path $config.Passwordfile | where{$_}
                $CurrentServerCredentials = @($PasswordFileData | where{$_.Server -eq $BackupDevice})
                if($CurrentServerCredentials)
                {
                    if($CurrentServerCredentials.Count -eq 1)
                    {
                        if($CurrentServerCredentials.Username -and $CurrentServerCredentials.password)
                        {
                            try
                            {
                                $CurrentServerUsername = $CurrentServerCredentials.Username
                                $CurrentServerPassword = ConvertTo-SecureString $CurrentServerCredentials.password -AsPlainText -Force
                                $Credential = New-Object System.Management.Automation.PSCredential -ArgumentList ($CurrentServerUsername, $CurrentServerPassword)
                            }
                            catch
                            {
                                Write-Log -Path $Activitylog -Entry  "Please verify password file" -Type Error -ShowOnConsole
                                exit
                            }
                        }
                        else
                        {
                            Write-Log -Path $Activitylog -Entry  "Username or Password not available for $BackupDevice, Please verify" -Type Error -ShowOnConsole
                            exit
                        }
                    }
                    else
                    {
                        Write-Log -Path $Activitylog -Entry  "Multiple Credentials found for $BackupDevice, Please verify" -Type Error -ShowOnConsole
                        exit
                    }
                }
                else
                {
                    Write-Log -Path $Activitylog -Entry  "Credentials not found for $backupdevice" -Type Error -ShowOnConsole
                    exit
                }
            }
            else
            {
                Write-Log -Path $Activitylog -Entry  "Password File not available" -Type Error -ShowOnConsole
                exit
            }
        }
        else
        {
            $Credential = Get-Credential -Message "Enter Credentials"
        }
        $Credential | Export-Clixml $CredentialPath -Force
    }
    try
    {
        $Credential = Import-Clixml $CredentialPath
    }
    catch
    {
        $comment = $_ | Format-List -Force 
        Write-Log -Path $Activitylog -Entry  "Invalid Credential File!" -Type Error -ShowOnConsole
        Write-Log -Path $Activitylog -Entry  $comment -Type Exception 
        Write-Log -Path $Activitylog -Entry  "Recreate Credential File!" -Type Information -ShowOnConsole

        $Dpservice_signal,$Dp_Service_Result                        = Get-DpServiceMessage         -Message "Invalid Credential File!"
        $Queuing_gt30_signal,$Queuing_30_Result                     = Get-BackupSessionMessage     -Message "Invalid Credential File!" -HCParameter "Queuing Backup Count(>30 min)" -HCShortName "WQB"
        $Queuing_lt24_signal,$Queuing_lt24_Result                   = Get-BackupSessionMessage     -Message "Invalid Credential File!" -HCParameter "Long Running Backup Count(>12 Hr and <24 Hr)" -HCShortName "LB_12"
        $Queuing_gt24_signal,$Queuing_gt24_Result                   = Get-BackupSessionMessage     -Message "Invalid Credential File!" -HCParameter "Long Running Backup Count(>24 Hr)" -HCShortName "LB_24"
        $Mount_req_signal,$Mount_Request_Result                     = Get-BackupSessionMessage     -Message "Invalid Credential File!" -HCParameter "Mount Request" -HCShortName "MR"
        $Disabled_TapeDrive_signal,$Disabled_TapeDrive_Result       = Get-DisabledTapeDriveMessage -Message "Invalid Credential File!"
        $Scratch_Media_signal,$Scratch_Media_Result                 = Get-ScratchMediaMessage      -Message "Invalid Credential File!"
        $Failed_bck_signal,$Failed_Bck_result                       = Get-FailedBackupMessage      -Message "Invalid Credential File!" -HCParameter "Failed Backup Count"    -HCShortName "FB"
        $Critical_Backup_signal,$Critical_Bck_result                = Get-FailedBackupMessage      -Message "Invalid Credential File!" -HCParameter "Critical Backup Status" -HCShortName "CB"
        $IDBBackup_Signal,$IDB_Backup_Result                        = Get-IDBMessage               -Message "Invalid Credential File!"
        $Hung_Bck_signal,$HungBackup_Result                         = Get-BackupSessionMessage     -Message "Invalid Credential File!" -HCParameter "Hung Backup Count" -HCShortName "HB"
        $DisabledBackupJob_Signal,$DisabledBackupJob_Result         = Get-DisabledJobMessage       -Message "Invalid Credential File!"
        $FreeDiskSpace_signal,$FreeDiskSpace_Result                 = Get-FreeDiskSpaceMessage     -Message "Invalid Credential File!" -HCParameter "Free Disk Space" -HCShortName "FDS"
        $FreeDiskSpaceDataDisk_signal,$FreeDiskSpaceDataDisk_Result = Get-FreeDiskSpaceMessage     -Message "Invalid Credential File!" -HCParameter "Free Disk Space Data Disk" -HCShortName "FDS_DS"
        $Library_Status_signal,$LibraryStatus_Result                = Get-LibraryMessage           -Message "Invalid Credential File!"
            
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

        $SignalSummaryResult = Get-SignalSummary -Inputobject $SignalReport
        Export-DPFiles
        if ($config.SendEmail -eq "yes")
        {  
            $attachment = @()
            $attachment += $SignalReportName
            $attachment += $DpService_ReportName        
            $attachment += $Queuing30_ReportName        
            $attachment += $Queuing_lt24_ReportName     
            $attachment += $Queuing_gt24_ReportName     
            $attachment += $MountRequest_ReportName     
            $attachment += $DisabledTapeDrive_ReportName
            $attachment += $ScratchMedia_ReportName     
            $attachment += $FailedBackup_ReportName     
            $attachment += $IDBBackup_ReportName        
            $attachment += $CriticalBackup_ReportName   
            $attachment += $LibraryStatus_ReportName    
            $attachment += $HungBackup_ReportName       
            $attachment += $DisabledBackupJob_ReportName
            $attachment += $FreeDiskSpace_ReportName 
            $attachment += $FreeDiskSpaceDataDisk_ReportName
            $attachment += $SignalSummaryReportName

            $sendMailMessageParameters = @{
                To          = $config.mail.To.Split(";")
                from        = $config.mail.From 
                Subject     = "$($config.mail.Subject) on $BackupDevice at $(Get-Date -Format 'dd-MMM-yyyy - HH:mm:ss')"      
                BodyAsHtml  = $true
                SMTPServer  = $config.mail.smtpServer             
                ErrorAction = 'Stop'
                port        = $config.mail.port
            } 

            if ($config.mail.Cc) 
            { 
                $sendMailMessageParameters.Add("CC", $config.mail.Cc.Split(";")) 
            }
            if ($attachment.Count -gt 0)
            {
                $sendMailMessageParameters.Add("Attachments", $attachment )
            }
            $body = ""
            $body += "<p>Hi, <br><br>&nbsp&nbsp&nbsp&nbspPlease find the healthcheck reports in the attachment.<br><br>Thanks,<br>Automation Team<br></p>"
            $body += "<p style=`"color: red; font-size: 12px`">***This is an auto generated mail. Please do not reply.***</p>"
             
            $sendMailMessageParameters.Add("Body", $body)
            try
            {
                Send-MailMessage @sendMailMessageParameters
            }
            catch
            {
                $comment = $_ | Format-List -Force 
                Write-Log -Path $Activitylog -Entry  "Failed to send the mail" -Type Error -ShowOnConsole
                Write-Log -Path $Activitylog -Entry  $comment -Type Exception 
                Write-Log -Path $Activitylog -Entry  "Recreate Credential File!" -Type Information -ShowOnConsole
                
            }
        }        
        exit
    }
}
else
{
    Write-Log -Path $Activitylog -Entry "Running Locally" -Type Information -ShowOnConsole
}
