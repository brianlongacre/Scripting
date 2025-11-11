$DateTime = Get-Date -format "yyyymmdd-HHmm" 
$ScopePath = "C:\Users\calkan\Documents\Temp\DHCPScopes_$DateTime"
$DHCPServer = "WIN002DHCP"
$LeasePath = "C:\Users\calkan\Documents\Temp\DHCPListOutput_$DateTime"

Get-DhcpServerv4Scope -ComputerName $DHCPServer |select * |export-csv -delimiter "`t" $ScopePath"_full.txt"
Get-DhcpServerv4Scope -ComputerName $DHCPServer |select ScopeID |export-csv -delimiter "`t" -NoTypeInformation $ScopePath".txt"

set-content $ScopePath".txt" ((get-content $ScopePath".txt") -replace '"')
#set-content $ScopePath".txt" ((get-content $ScopePath".txt") -replace 'ScopeID')

$sList = gc $ScopePath".txt"
$leases = @()

foreach ($s in $sList)
    

{
#$s.replace('""','"')
$leases += Get-DhcpServerv4Lease -ComputerName $DHCPServer -ScopeId $s
}

$leases | Select * | Export-csv -Delimiter "`t" $LeasePath".txt"