cls
$a = Get-Service
if ($? -eq $null)
{
Write-Host "success"
}
elseif($? -ne $false)
{
Write-Host "failure"
}