<#===================================================================================================================
	SUMMARY
	-----------
        Secure Key and Secure Password Generator (SKP_Generator)

	DESCRIPTION
	-----------
	    This script allows you to encrypt password using 32bit AES Key
	
    PREREQUISITES
	------------

    System Requirements
        Windows 2008 above
        PowerShell
        
	Input File(s)
	  
	Output File(s)
        Secure Key
        Secure Password
	
	
	VERSION DETAILS
	---------------
	VERSION:         1.0 
    AUTHOR:          Arnaldo N. Egos
    DATE CREATED:    ApriL 8, 2018                 
    NOTES:           Initial Version

#===================================================================================================================#>

#--- Variables --------------------------------------------------------------
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$Time=Get-Date

#--- 32bit AES Key Generator ------------------------------------------------ 
$KeyFile = "$dir\Secure.key"
$Key = New-Object Byte[] 32
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)
$Key | out-file $KeyFile

#--- Password encryption using 32bit AES -----------------------------------
$PW = Read-Host 'Enter password to encrypt'
$SecurePassFile = "$dir\SecurePass.txt"
$KeyFile = "$dir\Secure.key"
$Key = Get-Content $KeyFile
$SecurePass = $PW | ConvertTo-SecureString -AsPlainText -Force
$SecurePass | ConvertFrom-SecureString -key $Key | Out-File $SecurePassFile

#----------------------------------------------------------------------------

