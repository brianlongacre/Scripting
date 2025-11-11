Connect-AzureAD
Get-AzureADUser -All $True | ? {$_.ObjectType -eq "User"}  | select * |  Export-csv -delimiter "`t" C:\temp\4012025-Azure-output.csv -NoTypeInformation