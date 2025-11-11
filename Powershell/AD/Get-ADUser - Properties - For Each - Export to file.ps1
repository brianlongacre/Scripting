$uList = gc c:\temp\TestList5.txt
$Users = @()


foreach ($u in $uList)
{
$Users += Get-ADUser $U -Properties SAMAccountName, DisplayName, EmailAddress
}

$Users | Select SAMAccountName, DisplayName, EmailAddress | #SAMAccountName DisplayName, EmailAddress | 
Export-csv -delimiter "`t" C:\temp\Output_UserLookupTest5a.txt -NoTypeInformation