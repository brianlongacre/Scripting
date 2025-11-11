param (
    [string]$RootPath = "C:\Temp",
    [string]$OutputPath = "C:\tmp",
    [string]$OutputFile = "NTFS_Permission_Audit_rev01c1.ndjson"
)

# Summary counters
$TotalFolders = 0
$TotalFiles = 0
$TotalWithIssues = 0
$IssueCounts = @{}

function Get-AclData {
    param ($Path)

    try {
        $item = Get-Item -Path $Path -Force -ErrorAction Stop
        $acl = Get-Acl -Path $Path -ErrorAction Stop

        # Object type
        $isFolder = $item.PSIsContainer
        if ($isFolder) { $Global:TotalFolders++ } else { $Global:TotalFiles++ }

        # Basic metadata
        $attributes = $item.Attributes
        $isHidden = ($attributes -band [IO.FileAttributes]::Hidden) -ne 0
        $isSystem = ($attributes -band [IO.FileAttributes]::System) -ne 0

        $metadata = @{
            Path = $Path
            ObjectType = if ($isFolder) { "Folder" } else { "File" }
            InheritanceEnabled = -not $acl.AreAccessRulesProtected
            Owner = $acl.Owner
            CreationTime = $item.CreationTimeUtc
            LastWriteTime = $item.LastWriteTimeUtc
            SizeBytes = if ($isFolder) { $null } else { $item.Length }
            IsHidden = $isHidden
            IsSystem = $isSystem
        }

        # Access Entries
        $accessList = @()
        foreach ($entry in $acl.Access) {
            $accessList += @{
                Identity = $entry.IdentityReference.Value
                Rights = $entry.FileSystemRights.ToString()
                AccessControlType = $entry.AccessControlType.ToString()
                IsInherited = $entry.IsInherited
                InheritanceFlags = $entry.InheritanceFlags.ToString()
                PropagationFlags = $entry.PropagationFlags.ToString()
            }
        }
        $metadata.AccessEntries = $accessList

        # Try to get parent ACL
        $parentPath = Split-Path -Path $Path -Parent
        if ($parentPath -and (Test-Path $parentPath)) {
            $parentAcl = Get-Acl -Path $parentPath -ErrorAction SilentlyContinue
            $metadata.ParentAcl = @()
            foreach ($pEntry in $parentAcl.Access) {
                $metadata.ParentAcl += @{
                    Identity = $pEntry.IdentityReference.Value
                    Rights = $pEntry.FileSystemRights.ToString()
                    AccessControlType = $pEntry.AccessControlType.ToString()
                    InheritanceFlags = $pEntry.InheritanceFlags.ToString()
                    PropagationFlags = $pEntry.PropagationFlags.ToString()
                }
            }
        } else {
            $metadata.ParentAcl = @()
        }

        # Audit inheritance if enabled
        $issues = @()
        if ($metadata.InheritanceEnabled -eq $true -and $metadata.ParentAcl.Count -gt 0) {
            $parentACEs = $metadata.ParentAcl

            # Create lookup for parent ACEs
            foreach ($pAce in $parentACEs) {
                $match = $accessList | Where-Object {
                    $_.IsInherited -eq $true -and
                    $_.Identity -eq $pAce.Identity -and
                    $_.AccessControlType -eq $pAce.AccessControlType
                }

                if (-not $match) {
                    $issues += "MissingInheritedAce"
                } else {
                    foreach ($m in $match) {
                        if ($m.Rights -ne $pAce.Rights -or
                            ( 
                                $ObjectType -eq "Folder" -and
                                (                             
                                    $m.InheritanceFlags -ne $pAce.InheritanceFlags -or
                                    $m.PropagationFlags -ne $pAce.PropagationFlags) 
                            )
                        ){
                            $issues += "MismatchedInheritedAce"
                        }
                    }
                }
            }

            # Extra inherited ACEs on child that don't exist on parent
            foreach ($cAce in $accessList | Where-Object { $_.IsInherited -eq $true }) {
                $found = $parentACEs | Where-Object {
                    $_.Identity -eq $cAce.Identity -and
                    $_.AccessControlType -eq $cAce.AccessControlType
                }
                if (-not $found) {
                    $issues += "UnexpectedInheritedAce"
                }
            }
        }

        if ($issues.Count -gt 0) {
            $metadata.Issues = $issues
            $Global:TotalWithIssues++
            foreach ($i in $issues) {
                if ($IssueCounts.ContainsKey($i)) {
                    $IssueCounts[$i]++
                } else {
                    $IssueCounts[$i] = 1
                }
            }
        }

        return $metadata
    }
    catch {
        return @{
            Path = $Path
            ObjectType = "Unknown"
            Error = $_.Exception.Message
        }
    }
}

# Prepare output file
$outputFullPath = Join-Path $OutputPath $OutputFile
if (Test-Path $outputFullPath) { Remove-Item $outputFullPath }

# Scan and process
$items = Get-ChildItem -Path $RootPath -Recurse -Force -ErrorAction SilentlyContinue
$items = @((Get-Item $RootPath -Force)) + $items

foreach ($item in $items) {
    $result = Get-AclData -Path $item.FullName
    $result | ConvertTo-Json -Depth 6 -Compress | Out-File -FilePath $outputFullPath -Encoding UTF8 -Append
}

# Output summary
Write-Host ""
Write-Host "✅ Audit Complete!"
Write-Host "📁 Folders scanned:`t$TotalFolders"
Write-Host "📄 Files scanned:`t$TotalFiles"
Write-Host "⚠️ Objects with inheritance issues:`t$TotalWithIssues"
if ($IssueCounts.Keys.Count -gt 0) {
    Write-Host "🔍 Breakdown of issues:"
    foreach ($key in $IssueCounts.Keys) {
        Write-Host "   - ${key}`:`t$($IssueCounts[$key])"
    }
}

Write-Host "`n📄 Output saved to: $outputFullPath"
