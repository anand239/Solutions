$InputData = Get-Content "C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\Suresh-Priority\prii"

$Backups = Get-Content "C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\Suresh-Priority\Backups.txt" | where{$_}

if($Backups)
{
    foreach($Backup in $Backups)
    {
        $Found = $InputData -match "\b$Backup\b"
        
        if($Found)
        {
            $words = $found -split "\s" | where{$_}
            $words[8]      = "Anand"
            $Updatedline   = $words -join "     "
            $InputData = ($InputData).replace($found,$Updatedline)
        }
        else
        {
            "$Backup not found"
        }
    }
}
else
{
    "File Empty"
}