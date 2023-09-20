<#
.SYNOPSIS
  Temp-Cleanup.ps1
  To cleanup the drive space and recyclebin
    
.NOTES
  Script:         Temp-Cleanup.ps1
  Author:         Chintalapudi Anand Vardhan
  Requirements :  Powershell v3.0
  Creation Date:  03/07/2023
  Modified Date:  03/07/2023 

  .History:
        Version Date            Author                       Description        
        0.0.1     03/07/2023   Chintalapudi Anand Vardhan   Initial Release
.EXAMPLE
  Script Usage 

  .\Temp-Cleanup.ps1 -Paths "C:\temp"
#>



[CmdletBinding()]
Param(
[Parameter(Mandatory = $true)]
[String[]]$Paths
)


if(Test-Path $Paths)
{
    $Paths
    $Delete = Get-ChildItem "$paths\*" -Recurse -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue -Recurse 
}
else
{
    "Path does not exist"
}