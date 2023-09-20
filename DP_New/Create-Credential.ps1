<#
.SYNOPSIS
  Create-Credential.ps1

.DESCRIPTION
  Creates multiple credential files.
	
.INPUTS
   
.NOTES
  Script:         Create-Credential
  Author:         Chintalapudi Anand Vardhan  
  Requirements:   Powershell v3.0
  Creation Date:  17-Dec-2021
  Modified Date:  17-Dec-2021 
  Remarks      :  

  .History:
        Version Date                       Author                    Description        
        1.0     17-Dec-2021      Chintalapudi Anand Vardhan        Initial Release

.EXAMPLE
  Script Usage 

  .\Create-Credential.ps1
#>

$Path = Read-Host "Enter the path to save credential files"
while($true)
{
    $Filename = Read-Host "Enter Name of credentialfile"
    $Credential = Get-Credential -Message "Enter your Credential"
    $CredentialPath = $Path + "\" + "$Filename.xml"
    $Credential | Export-Clixml $CredentialPath -Force
    $userinput = Read-Host -Prompt "Add another server Credential [Y/N]"
    if($userinput -ne "Y")
    {
        break
    }
}

