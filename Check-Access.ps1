Function Check-Access
{
    [cmdletbinding()]
    Param(
    $Key
    )
    if(Test-Path "key.exe")
    {
        try
        {
            $Scriptarg = "DXC_$((Get-Date).ToString("yyyyMMdd"))"
            $outkey = .\Key.ps1 $Scriptarg
        }
        catch
        {
            Write-Log -Path $Activitylog -Entry "Unable to Run Key File." -Type warning -ShowOnConsole
            Write-Log -Path $Activitylog -Entry "Please run again or Please Unblock the file." -Type warning -ShowOnConsole
            exit
        }
        if($outkey)
        {
            $Split = $outkey -split ","
            $KeyDomain = $Split[0].Trim()
            $KeyYear   = $Split[1].Trim()
            $KeyMonth  = $Split[2].Trim()
            $Alloweddate = ([datetime]"$keyyear, $KeyMonth").ToString("yyyyMM")
            $Scriptdate = (Get-Date).ToString("yyyyMM")
            $Whoami = systeminfo | findstr /B "Domain"
            $ScriptDomain = ($Whoami -split ":")[1].Trim()
            if($KeyDomain -and $KeyYear -and $KeyMonth -and $Alloweddate -and $ScriptDomain)
            {
                if($ScriptDomain -eq $KeyDomain)
                {
                    if($Scriptdate -le $Alloweddate)
                    {
                        Write-Log -Path $Activitylog -Entry "Permission granted, Running the script" -Type Information -ShowOnConsole
                    }
                    else
                    {
                        Write-Log -Path $Activitylog -Entry "Your key got Expired, please contact Automation team!" -Type warning -ShowOnConsole
                        exit
                    }
                }
                else
                {
                    Write-Log -Path $Activitylog -Entry "You do not have permission to run the script" -Type warning -ShowOnConsole
                    Write-Log -Path $Activitylog -Entry "Please contact Automation team for the key!" -Type warning -ShowOnConsole
                    exit
                }
            }
            else
            {
                Write-Log -Path $Activitylog -Entry "Something went wrong, please try again!" -Type warning -ShowOnConsole
                exit
            }
        }
        else
        {
            Write-Log -Path $Activitylog -Entry "Failed to Run Key File." -Type warning -ShowOnConsole
            Write-Log -Path $Activitylog -Entry "Please try again." -Type warning -ShowOnConsole
            exit
        }
    }
    else
    {
        Write-Log -Path $Activitylog -Entry "Unable to find Key File." -Type warning -ShowOnConsole
        exit
    }
}

Check-Access