param (
    [string]$RootPath = "C:\Temp",
    [string]$OutputPath = "C:tmp",
    [string]$OutputFile = "NTFS_Permission_Audit.ndjson"
)

function Get-AclData {
    param ($Path)

    try {
        $acl = Get-Acl -Path $Path
        # Define ObjectType before building the hashtable
        try {
            $itemObj = Get-Item -Path $Path -ErrorAction Stop
            $objType = if ($itemObj.PSIsContainer) { "Folder" } else { "File" }
        } catch {
            $objType = "Unknown"
        }

        # Then return the hashtable
        return @{
            Path = $Path
            ObjectType = $objType
            InheritanceEnabled = -not $acl.AreAccessRulesProtected
            AccessEntries = @(
                foreach ($entry in $acl.Access) {
                    @{
                        Identity = $entry.IdentityReference.Value
                        Rights = $entry.FileSystemRights.ToString()
                        AccessControlType = $entry.AccessControlType.ToString()
                        IsInherited = $entry.IsInherited
                        InheritanceFlags = $entry.InheritanceFlags.ToString()
                        PropagationFlags = $entry.PropagationFlags.ToString()
                    }
                }
            )
        }
    } catch {
        return @{
            Path = $Path
            Error = $_.Exception.Message
        }
    }
}

# Ensure output is clean
if (Test-Path $OutputFile) { Remove-Item $OutputFile }

# Get all child items including folders and files
$AllItems = Get-ChildItem -Path $RootPath -Recurse -Force -ErrorAction SilentlyContinue

# Add the root folder itself
$AllItems = @((Get-Item $RootPath)) + $AllItems

foreach ($item in $AllItems) {
    $thisData = Get-AclData -Path $item.FullName

    # Try to get parent ACL for later inheritance comparison
    $parentPath = Split-Path -Path $item.FullName -Parent
    if ($parentPath -and (Test-Path $parentPath)) {
        $thisData.ParentAcl = (Get-AclData -Path $parentPath).AccessEntries
    } else {
        $thisData.ParentAcl = @()
    }

    # Convert to JSON (1 line) and append to file
    $thisData | ConvertTo-Json -Depth 6 -Compress | Out-File -FilePath $OutputFile -Encoding UTF8 -Append
}

Write-Host "Audit complete. NDJSON saved to: $OutputPath\$OutputFile"