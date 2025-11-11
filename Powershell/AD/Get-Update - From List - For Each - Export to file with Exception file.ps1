# Define input and output file paths
$computersFile = "C:\temp\Unreachable-20230302-1130.txt"
$updatesFile = "C:\temp\Updates-20230307-1030.csv"
$unreachableFile = "C:\temp\Unreachable-20230307-1030.csv"

# Read list of computers from input file
$computers = Get-Content $computersFile

# Initialize empty arrays to hold updates and unreachable computers
$updates = @()
$unreachable = @()

# Loop through list of computers and retrieve updates
foreach ($computer in $computers) {
    Write-Host "Retrieving updates for $computer"
    try {
        $computerUpdates = Get-Hotfix -ComputerName $computer | Select-Object -Property "PSComputerName", "HotFixID", "InstalledOn", "Description", "Caption"
        $updates += $computerUpdates
    }
    catch {
        Write-Host "Unable to retrieve updates for $computer"
        $unreachable += [pscustomobject]@{
            ComputerName = $computer
            }
    }
}

# Export list of updates to CSV file
$updates | Export-Csv -Path $updatesFile  -Delimiter "`t" -NoTypeInformation -Append

# Export list of unreachable computers to CSV file
$unreachable | Export-Csv -Path $unreachableFile -NoTypeInformation