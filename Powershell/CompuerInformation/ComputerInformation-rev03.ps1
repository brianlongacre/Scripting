$SidInfoFilteredFilePath = "$mainpath\FilteredSids"
$IPAddress = @{Name="IPAddress";expression={$_.IPAddress}}
$DefaultIPGateway = @{Name="DefaultIPGateway";expression={$_.DefaultIPGateway}}
$IPSubnet = @{Name="IPSubnet";expression={$_.IPSubnet}}
$DNSServerSearchOrder = @{Name="DNSServerSearchOrder";expression={$_.DNSServerSearchOrder}}
$mainpath = "c:\temp\"
$comps = get-content $mainpath\servers.txt

Find-Module -Name NTFSSecurity | Save-module -Path C:\Windows\System32\WindowsPowershell\v1.0\Modules | Install-module 
Unblock-File C:\Scripts\Get-RemoteProgram.ps1
Unblock-File C:\Scripts\Get-LocalGroup.ps1
Unblock-File C:\Scripts\Get-SchTasks.ps1
Unblock-File C:\Scripts\get-localusers.ps1

Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser

. C:\Scripts\Get-RemoteProgram.ps1
. C:\Scripts\Get-LocalGroup.ps1
. C:\Scripts\Get-SchTasks.ps1
. C:\scripts\get-localusers.ps1

#Start Network Share Collection

$compshares = @()

foreach($comp in $comps){
    try{
    $shares = gwmi win32_Share -cn $comp | select pscomputername, name, path
    $compshares += $shares
    } catch{
    Write-Error "Failed to Connect"
    }
}

$counter = $compshares.Count
$i=0
$sharepath = @()

foreach($share in $compshares){
    if($i -lt $counter){
       $hash = New-Object PSObject
       $hash | Add-Member -MemberType NoteProperty -Name "Path" -Value $path
       $hash | Add-Member -MemberType NoteProperty -Name "CompName" -Value $CompName
       
       $path = "\\"+$compshares[$i].PSComputerName+"\"+$compshares[$i].name
       $compname = $compshares[$i].PSComputerName

       $sharepath += $hash
      
    }
    $i++
}

$i=0

# End Network Share Collection

# Start Volume Share Information

$fshares = @()

foreach($comp in $comps){
    try{
    $shares = gwmi win32_Volume -cn $comp | select SystemName, Caption
    $fshares += $shares
    } catch{
    Write-Error "Failed to Connect"
    }
}

$counter = $fshares.Count
$i=0
$fpath = @()

foreach($fshare in $fshares){
    if($i -lt $counter){
       $hash = New-Object PSObject
       $hash | Add-Member -MemberType NoteProperty -Name "Path" -Value $path
       $hash | Add-Member -MemberType NoteProperty -Name "CompName" -Value $CompName
       $hash | Add-Member -MemberType NoteProperty -name "DriveLetter" -Value $dl
       
       $path = $fshares[$i].Caption
       $compname = $fshares[$i].SystemName
       $dl = $fshares[$i].Caption.Substring(0,$fshares[$i].Caption.IndexOf(":"))
       $fpath += $hash
      
    }
    $i++
}

$hash= @()
$i=0

$fpathcounter = $fpath.Count
$Fullnetworkpath = @()

foreach($path in $fpath){
    if($i -lt $fpathcounter){
        $len = $fpath[$i].Path.Length
        #write-host "Len Var is " $len
        $len1 = $len -3
        #write-host "Len1 var is "$len1
        $lpath = $fpath[$i].Path.Substring($fpath[$i].path.IndexOf(":\")+2,$len1-1)
        #write-host "Lpath var is "$lpath

        #write-host "CompName var is "$fpath[$i].CompName
        #write-host "Drive Letter var is "$fpath[$i].DriveLetter
        #write-host "Path var is "$fpath[$i].Path

        $hash = New-Object PSObject
        $hash | Add-Member -MemberType NoteProperty -Name "NetPath" -Value $NetPath
        $hash | Add-Member -MemberType NoteProperty -Name "CompName" -Value $CompName
        #$hash | Add-Member -MemberType NoteProperty -Name "FullName" -Value $FullCompName
        
        $NetPath = "\\"+$fpath[$i].CompName+"\"+$fpath[$i].DriveLetter+"$\"+$lpath
        #$compgwmi = gwmi win32_computersystem -ComputerName $fpath[$i].CompName
        #$Fullcompname = $compgwmi.name+"."+$compname.Domain
        $compname = $fpath[$i].CompName

        }
        $i++
        $len = 0
        $len1 = 0
        $lpath = ""

        $Fullnetworkpath += $hash
}

$i=0

# End Volume Collection

foreach($comp in $comps){
$shortname = $comp.Substring(0,$comp.IndexOf('.'))
write-output '---------------------------------' | out-file -append $mainpath\$shortname.txt
write-output $shortname | out-file -append $mainpath\$shortname.txt
write-output '---------------------------------' | out-file -append $mainpath\$shortname.txt

Write-Output '---------------------------------' | out-file -append $mainpath\$shortname.txt
Write-Output 'Domain Name' | out-file -append $mainpath\$shortname.txt
gwmi win32_computersystem -ComputerName $comp | select Domain | out-file -append $mainpath\$shortname.txt
write-output '---------------------------------' | out-file -append $mainpath\$shortname.txt

Write-Output 'Services ran by Non Default Accounts' | out-file -Append $mainpath\$shortname.txt
get-wmiobject win32_service -ComputerName $comp | where {($_.startname -notlike "LocalSystem") -and ($_.startname -notlike "NT AUTHORITY\LocalService") -and ($_.startname -notlike "NT AUTHORITY\NetworkService") -and ($_.startname -notlike "")} | ft name, startname, pscomputername | out-file -append $mainpath\$shortname.txt
write-output '---------------------------------' | out-file -append $mainpath\$shortname.txt

write-output '---------------------------------' | out-file -append $mainpath\$shortname.txt
Write-Output 'Shares Originating from Computer' | Out-File -Append $mainpath\$shortname.txt
Get-WmiObject Win32_Share -ComputerName $comp | sort name | ft name, path, description, type, status | out-file -append $mainpath\$shortname.txt
write-output '---------------------------------' | out-file -append $mainpath\$shortname.txt

write-output '---------------------------------' | out-file -append $mainpath\$shortname.txt
Write-Output 'HardDrives mounted within FileSystem' | Out-File -Append $mainpath\$shortname.txt
Get-WmiObject Win32_Volume -ComputerName $comp | sort name | ft name, path, description, type, status | out-file -append $mainpath\$shortname.txt
write-output '---------------------------------' | out-file -append $mainpath\$shortname.txt

Write-Output '---------------------------------' | out-file -append $mainpath\$shortname.txt
Write-Output 'Installed Programs' | out-file -append $mainpath\$shortname.txt
Get-RemoteProgram -computername $comp | Sort ProgramName | out-file -append $mainpath\$shortname.txt
write-output '---------------------------------' | out-file -append $mainpath\$shortname.txt

Write-Output '---------------------------------' | out-file -append $mainpath\$shortname.txt
Write-Output 'Scheduled Tasks' | out-file -append $mainpath\$shortname.txt
get-schtasks -computername $comp | sort Task | select Task, RunAsAccount, Location, ID | Out-File -Append $mainpath\$shortname.txt -Width 20000
write-output '---------------------------------' | out-file -append $mainpath\$shortname.txt

Write-Output '---------------------------------' | out-file -append $mainpath\$shortname.txt
Write-Output 'Local Groups' | out-file -append $mainpath\$shortname.txt
Get-LocalGroup -Computername $comp | out-file -append $mainpath\$shortname.txt
write-output '---------------------------------' | out-file -append $mainpath\$shortname.txt

Write-Output '---------------------------------' | out-file -append $mainpath\$shortname.txt
Write-Output 'Local Users' | out-file -append $mainpath\$shortname.txt
get-localusers -Computername $comp| ft | out-file -append $mainpath\$shortname.txt
write-output '---------------------------------' | out-file -append $mainpath\$shortname.txt

Write-Output '---------------------------------' | out-file -append $mainpath\$shortname.txt
Write-Output 'Network Adaper Config' | out-file -append $mainpath\$shortname.txt
Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $comp -Filter IPEnabled=TRUE | Select-Object DNSHostName, Caption, $IPAddress, $DefaultIPGateway, $IPSubnet, DHCPServer, $DNSServerSearchOrder | out-file -append $mainpath\$shortname.txt
write-output '---------------------------------' | out-file -append $mainpath\$shortname.txt

Write-Output '---------------------------------' | out-file -append $mainpath\$shortname.txt
Write-Output 'NTFS Permissions for Shares from Computer' | out-file -append $mainpath\$shortname.txt
write-output '---------------------------------' | out-file -append $mainpath\$shortname.txt
} 


$nshare = @()
foreach($path in $sharepath){
$share = $path.Path
$nshare += $share
}

$nvolume = @()
foreach($networkpath in $Fullnetworkpath){
$volume = $networkpath.netpath
$nvolume += $volume
}








foreach($netshare in $sharepath){
    $compname = $netshare.CompName
    Get-NTFSAccess -path $netshare.path | ft -AutoSize #| Out-File -Append $mainpath\$compname.txt
}

foreach($netpath in $Fullnetworkpath){
$compname = $NetPath.CompName
$NetPath.NetPath | Get-NTFSAccess | ft -AutoSize #| Out-File -Append $mainpath\$compname.txt
}