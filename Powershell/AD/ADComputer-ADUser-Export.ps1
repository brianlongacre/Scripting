$FileDate = Get-Date -Format "yyyyMMdd"
$startDate = (Get-Date -Year 2000 -Month 1 -Day 1).Date
$endDate   = (Get-Date).Date 

Get-ADComputer -Filter 'whenCreated -gt $startDate -and whenCreated -le $endDate' -Properties  Name, Enabled, LastLogonDate, DistinguishedName, CanonicalName, ms-Mcs-AdmPwd,ms-Mcs-AdmPwdExpirationTime, whenCreated, OperatingSystem, OperatingSystemVersion| Select  Name, Enabled, LastLogonDate, DistinguishedName, CanonicalName, ms-Mcs-AdmPwd,ms-Mcs-AdmPwdExpirationTime, whenCreated, OperatingSystem, OperatingSystemVersion |Export-csv -Delimiter "`t"  -Path "D:\Overflow - One Drive Filling up - Temporary\Projects\Cyber Security\Crowdstrike\PowerBI Test Data\AD - Computers - $Filedate.csv" -NoTypeInformation

Get-ADUser -filter * -Properties DisplayName, GivenName, SurName, samAccountName, EmployeeID, mail, Title, Description, Department, Country, State, City, Office, PostalCode, DistinguishedName, CanonicalName, Manager, UserAccountControl, Enabled, LockedOut, PasswordExpired, PasswordLastSet, LastLogonDate, WhenCreated, ExtensionAttribute1, ExtensionAttribute3 | select * | Export-csv -delimiter "`t"  -Path "D:\Overflow - One Drive Filling up - Temporary\Projects\Cyber Security\Crowdstrike\PowerBI Test Data\AD - Users - $Filedate.csv" -NoTypeInformation

Get-ADGroup -Properties Name, ObjectClass, GroupType, GroupScope, Description, SID, WhenCreated, WhenChanged -Filter * | Select Name, ObjectClass, GroupType, GroupScope, Description, SID, WhenCreated, WhenChanged | Export-csv -delimiter "`t"  -Path "D:\Overflow - One Drive Filling up - Temporary\Projects\Cyber Security\Crowdstrike\PowerBI Test Data\AD - Groups - $Filedate.csv" -NoTypeInformation
