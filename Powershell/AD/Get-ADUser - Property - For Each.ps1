ForEach ($User in (Get-Content c:\temp\TestList5.csv | ConvertFrom-CSV -Header First,Last))
{   $Filter = "givenName -like ""*$($User.First)*"" -and sn -like ""$($User.Last)"""
    Get-ADUser -Filter $Filter | Select SAMAccountName
}