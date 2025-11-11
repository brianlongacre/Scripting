# Define input and output file paths
$computersFile = "C:\temp\systems-20230301.txt"
$ComputersADFile = "C:\temp\Computers_From_AD_20230303-1110.csv"
$ComputersNotInADFile = "C:\temp\Computers_Not_In_AD_20230303-1110.csv"

# Read list of computers from input file
$computers = Get-Content $computersFile

# Initialize empty arrays to hold updates and unreachable computers
$adcomputer = @()
$computersnotinad = @()

# Loop through list of computers and retrieve updates
foreach ($computer in $computers) {
    Write-Host "Retrieving AD info for $computer"
    try {
        $adcomputers = Get-ADComputer -Identity $computer -Properties "Name","DNSHostName","Enabled","LastLogonDate","OperatingSystem","OperatingSystemHotfix","OperatingSystemServicePack","OperatingSystemVersion","whenCreated" | Select-Object -Property "Name","DNSHostName","Enabled","LastLogonDate","OperatingSystem","OperatingSystemHotfix","OperatingSystemServicePack","OperatingSystemVersion","whenCreated"
        $adcomputer += $adcomputers
    }
    catch {
        Write-Host "Unable to retrieve updates for $computer"
        $ComputersNotInAD += [pscustomobject]@{
            ComputerName = $computer
            }
    }
}

# Export list of updates to CSV file
$adcomputer | Export-Csv -Path $ComputersADFile  -Delimiter "`t" -NoTypeInformation -Append

# Export list of unreachable computers to CSV file
$computersnotinad | Export-Csv -Path $ComputersNotInADFile -NoTypeInformation