### Authored & edited by BCL with GPT-5 assistance - initial 8/19/2025, rev02g ###

param (
    [string]$AppName,                      # Application name (e.g., 'vlc', 'chrome') - rev01c - BCL - 8/19/2025
    [ValidateSet("CopyOnly", "ExecuteOnly", "CopyAndExecute")]
    [string]$Mode = "CopyAndExecute",      # Operation mode - rev01c - BCL - 8/19/2025
    [string]$Version = "",                 # Optional version (used for apps like Crowdstrike) - rev01c - BCL - 8/19/2025 - Typically most applications would have $Version = "", anything different would be the exception
    [string]$InstallFolder = "",           # Define Application Specific Folder Path (independent from C:\Program Files or C:\Program Files (x86) - the portion AFTER) - rev01d - BCL - 8/19/2025
    [string]$InstalledApp32 ="AcroRead.exe", # Define Target Installed App name/image name for Installed Application Check - rev01d - BCL - 8/19/2025
    [string]$InstalledApp64 ="AcroRead.exe", # Define Target Installed App name/image name for Installed Application Check - rev01d - BCL - 8/19/2025
    [switch]$Uninstall                     # Optional uninstall flag - rev01c - BCL - 8/19/2025
    )


# Define global paths based on app name - rev02a - BCL - 8/19/2025
$Date = Get-Date -Format yyyy_MM_dd
$BasePath = "d:\var\$AppName"
$PCList = "$Date-$AppName-cs.txt"       #Updated variable definition from use of $date to $Date - rev02g - BCL - 8/19/2025
$Computers = Get-Content "$BasePath\PC_Lists\$PCList"
$Source = if ($Version) { "$BasePath\$AppName-$Version" } else { "$BasePath\Software_Patches" }
$PatchPath = "$BasePath\PCs_Patched"
$InstallPath32 = "Program Files (x86)\$InstallFolder"  #Added $InstallPath32 variable - rev01d - BCL - 8/19/2025
$InstallPath64 = "Program Files\$InstallFolder"  #Added $InstallPath64 variable - rev01d - BCL - 8/19/2025
$LogSummary = "$PatchPath\exec_$AppName_$Date.csv"
$DownList = "$BasePath\down_$AppName_$Date.txt"
$UpListFile    = Join-Path $BasePath "PCs_Up\up_${AppName}_$Date.txt"       #Relocated to Global Variable block, previously in Foreach loop - rev02f - BCL - 8/19/2025


# Ensure log folders exist 
$null = New-Item -ItemType Directory -Force -Path $PatchPath, (Join-Path $BasePath 'PCs_Up'), (Join-Path $BasePath 'PCs_Patch_Copied')      #Added to ensure that Log folders are created if they are initially missing - rev02c - BCL - 8/19/2025


# CSV header (create once)
if (-not (Test-Path $LogSummary)) {     #Added to Ensure that Log file is created with first row headers - rev02c - BCL - 8/19/2025
    "Computer,ExitCode" | Out-File -FilePath $LogSummary -Encoding utf8     #Added to Ensure that Log file is created with first row headers - rev02c - BCL - 8/19/2025
}

# --- per-app metadata only: filenames + install/uninstall commands
switch ($AppName.ToLower()) {
    "vlc" {
        $TheFile32   = "vlc-3.0.21-win32.exe"   # set properly if you actually ship 32-bit; else delete
        $TheFile64   = "vlc-3.0.21-win64.exe"
        $InstallCmd  = { param($file) "cmd /c `"`"C:\Source\$file`"` /S" }
        $UninstallCmd= { 'cmd /c "msiexec /x {VLC-PRODUCT-CODE} /qn /norestart"' } # TODO replace with real code or registry lookup
    }
    "chrome" {
        $TheFile32   = "googlechromestandaloneenterprise.msi"
        $TheFile64   = "googlechromestandaloneenterprise64.msi"
        $InstallCmd  = { param($file) "cmd /c `"msiexec /i `"`"C:\Source\$file`"` /qn /norestart ALLUSERS=1" }
        $UninstallCmd= { 'cmd /c "msiexec /x {CHROME-PRODUCT-CODE} /qn /norestart"' } # TODO replace via registry lookup
    }
    "crowdstrike" {
        $TheFile32   = "FalconSensor_Windows.exe"
        $TheFile64   = "FalconSensor_Windows.exe"
        $CID         = "%redacted%"   # replace at runtime; don’t log
        $InstallCmd  = { param($file,$cid) "cmd /c `"`"C:\Source\$file`"` /install /quiet /norestart CID=$cid" }
        $UninstallCmd= { 'cmd /c "sc stop CSAgent & sc delete CSAgent"' } # or vendor-supported uninstall
    }
    default {
        Write-Error "Unsupported app: $AppName"
        return
    }
}

# ---- Sanity-check source payload (global, once) ----                                                      #Addech Sanity Check block - rev02d - BCL - 8/19/2025
$srcCandidate32 = Join-Path $Source $TheFile32                                                              #Addech Sanity Check block - rev02d - BCL - 8/19/2025
$srcCandidate64 = Join-Path $Source $TheFile64                                                              #Addech Sanity Check block - rev02d - BCL - 8/19/2025
if (-not (Test-Path $srcCandidate32) -and -not (Test-Path $srcCandidate64)) {                               #Addech Sanity Check block - rev02d - BCL - 8/19/2025
    Write-Warning "Source files for $AppName not found in $Source (checked $TheFile32 and $TheFile64)."     #Addech Sanity Check block - rev02d - BCL - 8/19/2025
    # You can 'return' to abort whole run, or just warn and continue per your preference:
    # return
}

foreach ($Computer in $Computers) {
      
    Try {   $PC = $Computer.Trim()      #Added Try Catch operation for future error handling - rev02d - BCL - 8/19/2025

        # build per-PC paths
        $RootC     = "\\$PC\C$"
        $Dest      = Join-Path $RootC 'Source'
        $LogPath   = Join-Path $PatchPath "patch_${AppName}_${PC}_$Date.log"
        $CopyLogFile   = Join-Path $BasePath "PCs_Patch_Copied\$PC.txt"

        # reset per-PC flags
        $Copy   = $false
        $TheFile= $null

        # Connectivity (ICMP + admin$)
        if (!(Test-Connection -ComputerName $PC -Count 1 -Quiet)) {
            Write-Host "PC $PC is not reachable..."
            Add-Content $DownList -Value $PC
            continue
        }
    
        Write-Host "PC $PC is Online"


        if (-not (Test-Path "\\$PC\admin$")) 
            {
                Write-Host "PC $PC admin$ not accessible..."
                Add-Content $DownList -Value $PC
                continue
            }

        # Ensure C:\Source exists (safe to run always)
        psexec \\$PC -h cmd /c "if not exist C:\Source mkdir C:\Source" | Out-Null      #Added check for C:\Source and create if missing - rev02b - BCL - 8/19/2025

        # Decide bitness by checking Program Files folders (or rely on OS later)
        $InstallPath32Root = Join-Path $RootC $InstallPath32
        $InstallPath64Root = Join-Path $RootC $InstallPath64
        $InstallFile32 = Join-path $InstallPath32Root $InstalledApp32        #Added Variable as Test-Path does not directly support Join-Path - rev01e - BCL - 8/19/2025
        $InstallFile64 = Join-path $InstallPath64Root $InstalledApp64        #Added Variable as Test-Path does not directly support Join-Path - rev01e - BCL - 8/19/2025
        $AE32 = if ($InstallFolder) { Test-Path -Path $InstallFile32 -PathType Leaf } else { $false }
        $AE64 = if ($InstallFolder) { Test-Path -Path $InstallFile64 -PathType Leaf } else { $false }
    
        # Determine if destination file exists
        $PatchFile32 = Join-path $Dest $TheFile32        #Added Variable as Test-Path does not directly support Join-Path - rev01e - BCL - 8/19/2025
        $PatchFile64 = Join-path $Dest $TheFile64        #Added Variable as Test-Path does not directly support Join-Path - rev01e - BCL - 8/19/2025
        $PE32 = Test-Path -Path $PatchFile32 -PathType Leaf
        $PE64 = Test-Path -Path $PatchFile64 -PathType Leaf

    
        # Pick installer
        if     ($AE64) { $TheFile = $TheFile64 }
        elseif ($AE32) { $TheFile = $TheFile32 }
        else {
            # fallback to OS bitness
            $archStr = (psexec \\$PC -h cmd /c "wmic os get osarchitecture /value" 2>&1) -join ''
            $is64    = $archStr -match '64'
            $TheFile = if ($is64) { $TheFile64 } else { $TheFile32 }
        }

        # Copy logic - rev01c - BCL - 8/19/2025
        if ($Mode -in @("CopyOnly", "CopyAndExecute")) {
            if($AE32 -eq $true)                             #Added logic to check IF 32-bit installed application exists on Computer - rev01d - BCL - 8/19/2025
                {
            
                    if($PE32 -eq $false)                    #Added logic to check IF 32-bit patch installer exists on Computer - rev01d - BCL - 8/19/2025
                        {
                            $TheFile = $TheFile32           #Added logic set $TheFile to equal the 32-bit patch installer IF the 32-bit application IS installed and the 32-bit Patch is NOT present - rev01d - BCL - 8/19/2025
                            $Copy = $true                   #Added logic set $Copy equal True IF the 32-bit application IS installed and the 32-bit Patch is NOT present - rev01d - BCL - 8/19/2025
                        }
                }
            Elseif($AE64 -eq $true)                         #Added logic to check IF 32-bit installed application exists on Computer - rev01d - BCL - 8/19/2025
                {
                    if($PE64 -eq $false)                    #Added logic to check IF 64-bit patch installer exists on Computer - rev01d - BCL - 8/19/2025
                        {   
                            $TheFile = $TheFile64           #Added logic set $TheFile to equal the 64-bit patch installer IF the 64-bit application IS installed and the 64-bit Patch is NOT present - rev01d - BCL - 8/19/2025
                            $Copy = $true                   #Added logic set $Copy equal True IF the 64-bit application IS installed and the 64-bit Patch is NOT present - rev01d - BCL - 8/19/2025
                        }
                }
            if($Copy -eq $true)                               #Added logic to check if $Copy is set to True, IF set to True THEN execute the robocopy command, and update the log for PCs_Up - rev01d - BCL - 8/19/2025
                {
                    # ---- Verify chosen source file exists (per PC) ----                               #Added Sanity Check block - rev02d - BCL - 8/19/2025
                    $srcChosen = Join-Path $Source $TheFile                                             #Added Sanity Check block - rev02d - BCL - 8/19/2025
                    if (-not (Test-Path $srcChosen))                                                    #Added Sanity Check block - rev02d - BCL - 8/19/2025
                        {                                                                               #Added Sanity Check block - rev02d - BCL - 8/19/2025
                            Write-Warning "Source file missing for ${PC}: $srcChosen. Skipping host."   #Added Sanity Check block - rev02d - BCL - 8/19/2025
                            Add-Content $DownList -Value "$PC (missing source file)"                    #Added Sanity Check block - rev02d - BCL - 8/19/2025
                            continue                                                                    #Added Sanity Check block - rev02d - BCL - 8/19/2025
                        }                                                                               #Added Sanity Check block - rev02d - BCL - 8/19/2025
                    Write-Host "Copying installer to $PC..."
                    robocopy $Source $Dest $TheFile /R:0 /W:0 /ETA /Log+:"$CopyLogFile" /TEE
                    Add-Content "$UpListFile" -Value $PC
                }
            else 
                {
                Write-Host "No Need to Copy Patch on $PC"  #Added logic to check if $Copy is set to False, IF set to False THEN display text noting that there is no need to copy the patch to the Computer - rev01d - BCL - 8/19/2025
                }   
        }

        # Optional uninstall
        if ($Uninstall.IsPresent -and $UninstallCmd) {
            Write-Host "Uninstalling existing $AppName on $PC..."
            psexec \\$PC -h (& $UninstallCmd) *> $LogPath
            Start-Sleep -Seconds 10
        }

        # Execute
        if ($Mode -in @("ExecuteOnly","CopyAndExecute")) {
            Write-Host "Executing installer on $PC..."
            if ($AppName.ToLower() -eq 'crowdstrike') {
                $cmd = & $InstallCmd $TheFile $CID
            } else {
                $cmd = & $InstallCmd $TheFile
            }
            psexec \\$PC -h $cmd *> $LogPath
            $LastExitCode = $LASTEXITCODE
            Write-Host "Completed: $LastExitCode"
            Add-Content $LogSummary -Value "$PC,$LastExitCode"
        }
    
    }
    catch       #Added Try Catch operation for future error handling - rev02d - BCL - 8/19/2025
        {
            Write-Warning "Error on ${Computer}: $($_.Exception.Message)"     #Added Try Catch operation for future error handling - rev02d - BCL - 8/19/2025
            Add-Content $DownList -Value "$Computer (exception: $($_.Exception.Message))"       #Added Try Catch operation for future error handling - rev02d - BCL - 8/19/2025
            continue        #Added Try Catch operation for future error handling - rev02d - BCL - 8/19/2025
        }
    }


