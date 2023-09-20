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

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [String] $ConfigFile = "config.json"
)

Function Get-Config
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$ConfigFile  = "config.json"
    ) 
    try
    {
        if (Test-Path -Path $ConfigFile)
        {
            Write-Verbose "Parsing $ConfigFile"
            $config = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json
        }
    }
    catch
    {
        Write-Error "Error Parsing $ConfigFile" 
    }
    Write-Output $config
}

$config = Get-Config -ConfigFile $ConfigFile
Write-Host "Started" -ForegroundColor Green
Write-Host "-----------------------------------" -ForegroundColor Green
Write-Host "Host: $($env:COMPUTERNAME)" -ForegroundColor Green
Write-Host "User: $($env:USERNAME)" -ForegroundColor Green
Write-Host "-----------------------------------" -ForegroundColor Green

if($config)
{
    if(Test-Path -Path $config.CredentialFile)
    {
        $CredentialData = import-csv "Credential.csv"
    }
    else
    {
        Write-Host "Invalid $($config.InputFile)!" -ForegroundColor Red
        exit
    }
    foreach($Cred in $CredentialData)
    {
        if(Test-Path $Cred.CredentialPath)
        {
            $CredFile = $Cred.CredentialPath + "\" + "Cred.xml"
            $CredentialPath = $Cred.CredentialPath
            $Username       = $Cred.Username
            $Password       = ConvertTo-SecureString $Cred.password -AsPlainText -Force
            $Credential     = New-Object System.Management.Automation.PSCredential -ArgumentList ($Username, $Password)
            $Credential | Export-Clixml $CredFile -Force
        }
        else
        {
            Write-Host "Invalid $($Cred.CredentialPath)" -ForegroundColor Red
        }
    }
    $CredentialData | ForEach-Object{$_.password = $null}
    $CredentialData | Export-Csv "Credential.csv" -NoTypeInformation
}
else
{
    Write-Host "Invalid $ConfigFile" -ForegroundColor Red
}
Write-Host "Completed" -ForegroundColor Green
