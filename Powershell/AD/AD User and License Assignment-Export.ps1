# Connect to Microsoft Graph
#Connect-MgGraph -Scopes "User.Read.All", "Directory.Read.All"

# Get all users in the tenant
$users = Get-MgUser -All

# Create an array to store the results
$results = @()

foreach ($user in $users) {
    # Get the licenses assigned to the user
    $licenses = Get-MgUserLicenseDetail -UserId $user.Id

    # Join the SkuId GUIDs with a semicolon delimiter
    $licenseString = $licenses.SkuId -join "; "

    # Create an object with the user details and assigned licenses
    $userDetails = [PSCustomObject]@{
        UserPrincipalName = $user.UserPrincipalName
        DisplayName       = $user.DisplayName
        Licenses          = $licenseString
    }

    # Add the result to the array
    $results += $userDetails
}

# Output the results
$results | Format-Table -AutoSize

# Optionally, export the results to a CSV file
$results | Export-Csv -Path "C:\Temp\EntraUsersAndLicenses_20241018.csv" -NoTypeInformation
