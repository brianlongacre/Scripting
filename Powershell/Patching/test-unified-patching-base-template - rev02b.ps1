
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

# Define paths based on app name - rev01c - BCL - 8/19/2025
$Date = Get-Date -Format yyyy_MM_dd
$BasePath = "d:\var\$AppName"
$PCList = "$date-$AppName-cs.txt"
$Computers = Get-Content "$BasePath\PC_Lists\$PCList"
$Source = if ($Version) { "$BasePath\$AppName-$Version" } else { "$BasePath\Software_Patches" }
$PatchPath = "$BasePath\PCs_Patched"
$DestPath = "C$\Source"     #Added $DestPath variable - rev01d - BCL - 8/19/2025
$InstallPath32 = "C$\Program Files (x86)\$InstallFolder"  #Added $InstallPath32 variable - rev01d - BCL - 8/19/2025
$InstallPath64 = "C$\Program Files\$InstallFolder"  #Added $InstallPath64 variable - rev01d - BCL - 8/19/2025
$LogSummary = "$PatchPath\exec_$AppName_$Date.csv"
$DownList = "$BasePath\down_$AppName_$Date.txt"

# Define installer filenames - customize per app - rev01c - BCL - 8/19/2025
switch ($AppName.ToLower()) {
    "vlc" {
        $TheFile32 = "vlc-3.0.21-win64.exe"
        $TheFile64 = "vlc-3.0.21-win64.exe"
        $DestFile32 = Join-path $Dest $Version $TheFile32       #Added Variable as Test-Path does not directly support -Join-Path
        $DestFile64 = Join-path $Dest $Version $TheFile64       #Added Variable as Test-Path does not directly support -Join-Path
        $PE32 = Test-Path -Join-path $Dest $TheFile32 -PathType Leaf     #Added $PE32 variable, check if 32-bit patch exists - rev01d - BCL - 8/19/2025
        $PE64 = Test-Path -Join-Path $Dest $TheFile64 -PathType Leaf     #Added $PE64 variable, check if 64-bit patch exists - rev01d - BCL - 8/19/2025
        $InstallFile32 = Join-path $InstallPath32 $InstalledApp32        #Added Variable as Test-Path does not directly support Join-Path - rev01e - BCL - 8/19/2025
        $InstallFile64 = Join-path $InstallPath64 $InstalledApp64        #Added Variable as Test-Path does not directly support Join-Path - rev01e - BCL - 8/19/2025
        $AE32 = Test-Path Path $InstallFile32 -PathType Leaf    #Added $AE32 variable, check if 32-bit application install exists - rev01d - BCL - 8/19/2025
        $AE64 = Test-Path Path $InstallFile64 -PathType Leaf    #Added $AE64 variable, check if 64-bit application install exists - rev01d - BCL - 8/19/2025
        $InstallCmd = { "C:\source\$TheFile /S" }
        $UninstallCmd = { 'wmic product where "Name=\'VLC media player\'" call uninstall /nointeractive' }
    }
    "chrome" {
        $TheFile32 = "googlechromestandaloneenterprise.msi"
        $TheFile64 = "googlechromestandaloneenterprise64.msi"
        $DestFile32 = Join-path $Dest $Version $TheFile32       #Added Variable as Test-Path does not directly support -Join-Path
        $DestFile64 = Join-path $Dest $Version $TheFile64       #Added Variable as Test-Path does not directly support -Join-Path
        $PE32 = Test-Path -Join-path $Dest $TheFile32 -PathType Leaf     #Added $PE32 variable, check if 32-bit patch exists - rev01d - BCL - 8/19/2025
        $PE64 = Test-Path -Join-Path $Dest $TheFile64 -PathType Leaf     #Added $PE64 variable, check if 64-bit patch exists - rev01d - BCL - 8/19/2025
        $InstallFile32 = Join-path $InstallPath32 $InstalledApp32        #Added Variable as Test-Path does not directly support Join-Path - rev01e - BCL - 8/19/2025
        $InstallFile64 = Join-path $InstallPath64 $InstalledApp64        #Added Variable as Test-Path does not directly support Join-Path - rev01e - BCL - 8/19/2025
        $AE32 = Test-Path Path $InstallFile32 -PathType Leaf    #Added $AE32 variable, check if 32-bit application install exists - rev01d - BCL - 8/19/2025
        $AE64 = Test-Path Path $InstallFile64 -PathType Leaf    #Added $AE64 variable, check if 64-bit application install exists - rev01d - BCL - 8/19/2025
        $InstallCmd = { "msiexec /i C:\source\$TheFile /qn" }
    }
    "crowdstrike" {
        $TheFile32 = "FalconSensor_Windows.exe"
        $TheFile64 = "FalconSensor_Windows.exe"
        if($Version -ne "")
            {
                $DestFile32 = Join-path $Dest $Version $TheFile32       #Added Variable as Test-Path does not directly support Join-Path - rev01e - BCL - 8/19/2025
                $DestFile64 = Join-path $Dest $Version $TheFile64       #Added Variable as Test-Path does not directly support Join-Path - rev01e - BCL - 8/19/2025
                $PE32 = Test-Path -path $DestFile32 -PathType Leaf     #Added $PE32 variable, IF $Version exists, check if 32-bit patch exists - rev01d - BCL - 8/19/2025  #Updated $PE to correct for Test-Path NOT directly supporting Join-Path
                $PE64 = Test-Path -Join-Path $DestFile64 -PathType Leaf     #Added $PE64 variable, IF $Version exists, check if 64-bit patch exists - rev01d - BCL - 8/19/2025    #Updated $PE to correct for Test-Path NOT directly supporting Join-Path
            }
        else
            {
                $DestFile32 = Join-path $Dest $TheFile32       #Added Variable as Test-Path does not directly support Join-Path - rev01e - BCL - 8/19/2025
                $DestFile64 = Join-path $Dest $TheFile64       #Added Variable as Test-Path does not directly support Join-Path - rev01e - BCL - 8/19/2025
                $PE32 = Test-Path -path $DestFile32 -PathType Leaf     #Added $PE32 variable, IF $Version exists, check if 32-bit patch exists - rev01d - BCL - 8/19/2025  #Updated $PE to correct for Test-Path NOT directly supporting Join-Path
                $PE64 = Test-Path -Join-Path $DestFile64 -PathType Leaf     #Added $PE64 variable, IF $Version exists, check if 64-bit patch exists - rev01d - BCL - 8/19/2025    #Updated $PE to correct for Test-Path NOT directly supporting Join-Path
            }
            
        $InstallFile32 = Join-path $InstallPath32 $InstalledApp32        #Added Variable as Test-Path does not directly support Join-Path - rev01e - BCL - 8/19/2025
        $InstallFile64 = Join-path $InstallPath64 $InstalledApp64        #Added Variable as Test-Path does not directly support Join-Path - rev01e - BCL - 8/19/2025
        $AE32 = Test-Path -Path $InstallFile32 -PathType Leaf    #Added $AE32 variable, check if 32-bit application install exists - rev01d - BCL - 8/19/2025
        $AE64 = Test-Path -Path $InstallFile64 -PathType Leaf    #Added $AE64 variable, check if 64-bit application install exists - rev01d - BCL - 8/19/2025
        $CID = "%redacted%"  # Replace with actual CID - rev01c - BCL - 8/19/2025
        $InstallCmd = { "C:\source\$AppName-$Version\$TheFile /install /quiet /norestart CID=$CID" }
    }
    default {
        Write-Error "Unsupported app: $AppName"
        return
    }
}

foreach ($Computer in $Computers) {
    $PC = $Computer.Trim()
    $Dest = "\\$PC\$DestPath\"      #Changed from partial explicit "\\$PC\C$\Source\" updated to utilize $DestPath variable - rev01d - BCL - 8/19/2025
    $LogPath = Join-Path -Path $PatchPath -ChildPath "patch_$AppName_$($PC)_$Date.log"

    # Connectivity check - rev01c - BCL - 8/19/2025
    if (!(Test-Connection -ComputerName $PC -Count 2 -Quiet)) {
        Write-Host "PC $PC is not reachable..."
        Add-Content $DownList -Value $PC
        continue
    }

    Write-Host "PC $PC is Online"

    # Optional uninstall logic - rev01c - BCL - 8/19/2025
    if ($Uninstall.IsPresent -and $UninstallCmd) {
        Write-Host "Uninstalling existing $AppName on $PC..."
        psexec \\$PC -h cmd /c $UninstallCmd.Invoke()
        Start-Sleep -Seconds 10
    }

    # Copy logic - rev01c - BCL - 8/19/2025
    if ($Mode -in @("CopyOnly", "CopyAndExecute")) {
        Write-Host "Copying installer to $PC..."
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
                robocopy $Source $Dest $TheFile /R:0 /W:0 /ETA /Log+:"$BasePath\PCs_Patch_Copied\$PC.txt" /TEE
                Add-Content "$BasePath\PCs_Up\up_$AppName_$Date.txt" -Value $PC
            }
        else 
            {
            Write-Host "No Need to Copy Patch on $Computer"  #Added logic to check if $Copy is set to False, IF set to False THEN display text noting that there is no need to copy the patch to the Computer - rev01d - BCL - 8/19/2025
            }   
    }

    # Execute logic - rev01c - BCL - 8/19/2025
    if ($Mode -in @("ExecuteOnly", "CopyAndExecute")) {
        Write-Host "Executing installer on $PC..."
        psexec \\$PC -h $InstallCmd.Invoke() > $LogPath 2>&1
        $LastExitCode = $LASTEXITCODE
        Write-Host "Completed: $LastExitCode"
        Add-Content $LogSummary -Value "$PC,$LastExitCode"
    }
}
