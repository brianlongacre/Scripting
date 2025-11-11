param (
    [string]$RootPath = "C:\Temp",
    [string]$OutputPath = "C:\tmp",
    [string]$OutputFile = "NTFS_Permission_Audit_rev01d12.ndjson"
)

# Summary counters
$TotalFolders = 0
$TotalFiles = 0
$TotalWithIssues = 0
$IssueCounts = @{}


#Modular Explicit Issue Logging Start added rev01d -->
$IssueLogFile = Join-Path $OutputPath "NTFS_Permission_Issues_rev01d12.csv"

# Initialize CSV file with headers (overwrite if it exists)
@"
Path,Identity,IssueType
"@ | Out-File -FilePath $IssueLogFile -Encoding UTF8

function Write-IssueLogEntry {
    param (
        [string]$Path,
        [string]$Identity,
        [string]$IssueType
    )

    "$Path,$Identity,$IssueType" | Out-File -FilePath $IssueLogFile -Encoding UTF8 -Append
}
#Modular Explicit Issue Logging End (outside of function components) added rev01d /-->

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
        # Clean up AccessEntries to only include ACEs that apply to this object added rev01d -->
        $acl.Access | Where-Object {
            -not ($_.PropagationFlags -eq "InheritOnly" -and $_.IsInherited -eq $true)
        } | ForEach-Object {
            $accessList += @{
                Identity = $_.IdentityReference.Value
                Rights = $_.FileSystemRights.ToString()
                AccessControlType = $_.AccessControlType.ToString()
                IsInherited = $_.IsInherited
                InheritanceFlags = $_.InheritanceFlags.ToString()
                PropagationFlags = $_.PropagationFlags.ToString()
            }
        }
        #End cleanup AccessEntries /-->

        $metadata.AccessEntries = $accessList

        # Try to get parent ACL
        # Try to get parent ACL
        $parentPath = Split-Path -Path $Path -Parent
        if ($parentPath -and (Test-Path $parentPath)) {
            $rawParentAcl = Get-Acl -Path $parentPath -ErrorAction SilentlyContinue
            $filteredParentAcl = $rawParentAcl.Access | Where-Object {
                ($_.PropagationFlags -ne "InheritOnly") -and
            ($ObjectType -eq "Folder" -or $_.InheritanceFlags -ne "ContainerInherit")
            }

            $metadata.ParentAcl = @()
            foreach ($pEntry in $filteredParentAcl) {
                $metadata.ParentAcl += @{
                    Identity           = $pEntry.IdentityReference.Value
                    Rights             = $pEntry.FileSystemRights.ToString()
                    AccessControlType  = $pEntry.AccessControlType.ToString()
                    InheritanceFlags   = $pEntry.InheritanceFlags.ToString()
                    PropagationFlags   = $pEntry.PropagationFlags.ToString()
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
                    $IssueType = "MissingInheritedAce" #Modulare Logging component added rev01d
                    $identity = $pAce.Identity #Modulare Logging component added rev01d
                    $issues += $IssueType        
                    Write-IssueLogEntry -Path $Path -Identity $Identity -IssueType $IssueType #Modulare Logging component added rev01d
                    Write-Host "🔸 Logged: $IssueType for $Identity at $Path" #Modulare Logging component added rev01d
                } else {
                    foreach ($m in $match) {
                        Write-Host "🧪 Comparing ACEs:" #sanity check logic - added rev01d
                        Write-Host "   Path: $Path" #sanity check logic - added rev01d
                        Write-Host "   Identity: $($m.Identity)" #sanity check logic - added rev01d
                        Write-Host "   Rights: $($m.Rights) vs $($pAce.Rights)" #sanity check logic - added rev01d
                        Write-Host "   InheritanceFlags: $($m.InheritanceFlags) vs $($pAce.InheritanceFlags)" #sanity check logic - added rev01d
                        Write-Host "   PropagationFlags: $($m.PropagationFlags) vs $($pAce.PropagationFlags)" #sanity check logic - added rev01d
                        if ($m.Rights -ne $pAce.Rights -or
                            ( 
                                $ObjectType -eq "Folder" -and
                                (                             
                                    $m.InheritanceFlags -ne $pAce.InheritanceFlags -or
                                    $m.PropagationFlags -ne $pAce.PropagationFlags) 
                            )
                        ){
                            $IssueType = "MismatchedInheritedAce" #Modulare Logging component added rev01d
                            $identity = $pAce.Identity #Modulare Logging component added rev01d
                            $issues += $IssueType
                            Write-IssueLogEntry -Path $Path -Identity $Identity -IssueType $IssueType #Modulare Logging component added rev01d
                            Write-Host "🔸 Logged: $IssueType for $Identity at $Path" #Modulare Logging component added rev01d
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
                    $IssueType = "UnexpectedInheritedAce" #Modulare Logging component added rev01d
                    $identity = $cAce.Identity #Modulare Logging component added rev01d
                    $issues += $IssueType
                    Write-IssueLogEntry -Path $Path -Identity $Identity -IssueType $IssueType #Modulare Logging component added rev01d
                    Write-Host "🔸 Logged: $IssueType for $Identity at $Path" #Modulare Logging component added rev01d
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
