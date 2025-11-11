$rundate = $endDate.ToString("yyyyMMdd")
$startDate = (Get-Date -Year 2000 -Month 1 -Day 1).Date
$endDate   = (Get-Date).Date 


Get-ADComputer -Filter 'whenCreated -gt $startDate -and whenCreated -le $endDate' -Properties  Name, Enabled, LastLogonDate, DistinguishedName, CanonicalName, ms-Mcs-AdmPwd,ms-Mcs-AdmPwdExpirationTime, whenCreated, OperatingSystem, OperatingSystemVersion| Select  Name, Enabled, LastLogonDate, DistinguishedName, CanonicalName, ms-Mcs-AdmPwd,ms-Mcs-AdmPwdExpirationTime, whenCreated, OperatingSystem, OperatingSystemVersion |Export-csv -Delimiter "`t"  -Path "D:\Overflow - One Drive Filling up - Temporary\Projects\Cyber Security\Crowdstrike\PowerBI Test Data\AD - Computers - $rund.csv" -NoTypeInformation