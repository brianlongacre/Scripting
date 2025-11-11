<#
.SYNOPSIS
  Phase 1 - Detection-only remote diagnostic for Microsoft 365 Apps (Click-to-Run) update health.

.DESCRIPTION
  - Inventory only (no changes). Remote fan-out via WinRM/PowerShell remoting.
  - Collects Office C2R config & policy, C2R service, update task status, CDN reachability,
    and WinRM reachability/state (service + TCP + Test-WSMan) per host.
  - Writes per-host JSON + a roll-up CSV with executor/audit metadata.
  - Keeps JSON history tidy with -MaxJsonPerHost (oldest pruned).

.PARAMETER ComputerName
  One or more computers (pipeline or array).

.PARAMETER ComputerList
  Path to a text file with one hostname per line.

.PARAMETER OutDir
  Output folder for summary CSV and per-host subfolders.

.PARAMETER Credential
  PSCredential to use for Invoke-Command (recommended: your automation account).

.PARAMETER UseCurrentCredentials
  Use the current logon token instead of -Credential.

.PARAMETER ThrottleLimit
  Concurrency for remote jobs (default 16).

.PARAMETER AuditTag
  Optional tag (e.g., change ticket) recorded in logs.

.PARAMETER MaxJsonPerHost
  Optional cap for JSON files retained per host (oldest removed). Default 20.

.EXAMPLE
  .\Get-M365AppUpdateHealth.ps1 -ComputerList .\targets.txt -OutDir C:\OfficeDiag -Credential (Get-Credential) -AuditTag "INV-OfficeStuck-2025-10-17"
#>

[CmdletBinding(DefaultParameterSetName='WithCred')]
param(
  [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
  [string[]]$ComputerName,

  [string]$ComputerList,

  [Parameter(Mandatory=$true)]
  [string]$OutDir,

  [int]$ThrottleLimit = 16,

  [Parameter(ParameterSetName='WithCred')]
  [System.Management.Automation.PSCredential]$Credential,

  [Parameter(ParameterSetName='Current')]
  [switch]$UseCurrentCredentials,

  [string]$AuditTag,

  [int]$MaxJsonPerHost = 20
)

begin {
  # Resolve target list
  if ($ComputerList) {
    if (-not (Test-Path $ComputerList)) { throw "ComputerList not found: $ComputerList" }
    $fromFile = Get-Content -Path $ComputerList | Where-Object { $_ -and $_.Trim() -ne '' } | ForEach-Object { $_.Trim() }
    $ComputerName = @($ComputerName) + $fromFile
  }
  $ComputerName = $ComputerName | Sort-Object -Unique
  if (-not $ComputerName -or $ComputerName.Count -eq 0) { throw "No target computers provided." }

  # Output prep
  if (-not (Test-Path $OutDir)) { New-Item -Path $OutDir -ItemType Directory -Force | Out-Null }
  $runId     = [guid]::NewGuid().ToString()
  $tsBase    = Get-Date
  $tsStamp   = $tsBase.ToString("yyyyMMdd_HHmmss")
  $summaryCsv = Join-Path $OutDir ("M365Apps_UpdateHealth_{0}.csv" -f $tsStamp)

  # Executor metadata
  $executor = [ordered]@{
    RunId       = $runId
    Timestamp   = $tsBase.ToString("s")
    Executor    = "$([Environment]::UserDomainName)\$([Environment]::UserName)"
    ExecutorHost= $env:COMPUTERNAME
    AuditTag    = $AuditTag
    ParamSet    = $PSCmdlet.ParameterSetName
  }

  # CSV header
  "RunId,AuditTag,Timestamp,Executor,ExecutorHost,ComputerName,Reachable,WinRM_WsManOK,WinRM_ServiceState,WinRM_StartMode,OS,User,OfficeVersion,Channel,ChannelFriendly,UpdatesEnabled,C2RService,ServiceStartType,TaskPresent,TaskEnabled,TaskLastRun,TaskNextRun,CDNReachable,HealthFlags,Notes" |
    Set-Content -Path $summaryCsv -Encoding UTF8

  # Remote script block (detection-only)
  $collector = {
    param($ChannelHints)

    function Get-WinRMDetect {
      param([string]$Target,[int]$WsTimeoutSec=6)
      $res = [ordered]@{
        Reachable         = $false
        WsManOK           = $false
        ServiceState      = $null
        StartMode         = $null
        Tcp5985           = $null
        Notes             = @()
      }

      try {
        $res.Reachable = [bool](Test-Connection -ComputerName $Target -Count 1 -Quiet -ErrorAction SilentlyContinue)
      } catch {}

      try {
        $wsParams = @{ ComputerName=$Target; ErrorAction='Stop' }
        if (Test-WSMan @wsParams) { $res.WsManOK = $true }
      } catch { $res.Notes += "Test-WSMan: $($_.Exception.Message)" }

      try {
        $tnc = Test-NetConnection -ComputerName $Target -Port 5985 -InformationLevel Detailed -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        if ($tnc) {
          $res.Tcp5985 = [ordered]@{
            TcpTestSucceeded = $tnc.TcpTestSucceeded
            RemoteAddress    = $tnc.RemoteAddress
            RemotePort       = $tnc.RemotePort
          }
        }
      } catch {}

      try {
        $svc = Get-CimInstance -ClassName Win32_Service -Filter "Name='WinRM'" -ComputerName $Target -ErrorAction Stop
        $res.ServiceState = $svc.State
        $res.StartMode    = $svc.StartMode
      } catch { $res.Notes += "Get-Cim WinRM: $($_.Exception.Message)" }

      return $res
    }

    $now = Get-Date

    # Optional: add derived flags to make triage easy
    $flags = @()
        if ($out.UpdatesEnabled -eq 0)            { $flags += 'UpdatesDisabled' }
        if (-not $out.TaskPresent)                { $flags += 'MissingUpdateTask' }
        if ($out.C2RService -ne 'Running')        { $flags += 'C2RServiceNotRunning' }
        if (-not $out.CDNReachable443)            { $flags += 'CDNBlocked' }
        if (-not $out.ChannelFriendly)            { $flags += 'UnknownChannel' }
        $out.Raw.HealthFlags = $flags

    $out = [ordered]@{
      Timestamp            = $now.ToString("s")
      ComputerName         = $env:COMPUTERNAME
      OS                   = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue | ForEach-Object { "$($_.Caption) $($_.Version)" })
      LoggedOnUser         = (whoami 2>$null)
      # WinRM detection (local perspective—target==self inside Invoke-Command)
      WinRM                = $null
      # Office Click-to-Run & policy
      OfficeVersion        = $null
      UpdateChannel        = $null
      ChannelFriendly      = $null
      UpdatesEnabled       = $null
      CDNBaseUrl           = $null
      UpdatePath           = $null
      Gpo_EnableAutoUpd    = $null
      Gpo_HideUpdNotif     = $null
      # Services / Tasks
      C2RService           = $null
      ServiceStartType     = $null
      TaskPresent          = $false
      TaskEnabled          = $null
      TaskLastRunTime      = $null
      TaskNextRunTime      = $null
      # Network reachability to CDN
      CDNReachable443      = $null
      Notes                = @()
      Raw                  = @{}
    }

    try {
      # WinRM detect (target is self when executed remotely)
      $out.WinRM = Get-WinRMDetect -Target $env:COMPUTERNAME

      # C2R config (HKLM)
      $c2rPath = 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'
      if (Test-Path $c2rPath) {
        $c2r = Get-ItemProperty -Path $c2rPath -ErrorAction SilentlyContinue
        $out.OfficeVersion   = $c2r.ClientVersionToReport
        $out.UpdateChannel   = $c2r.UpdateChannel
        $out.CDNBaseUrl      = $c2r.CDNBaseUrl
        $out.UpdatePath      = $c2r.UpdatePath
        $out.UpdatesEnabled  = $c2r.UpdatesEnabled
        $out.Raw.C2R         = $c2r | Select-Object *
      } else {
        $out.Notes += "ClickToRun config not found."
      }

      # Policy
      $policyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common\officeupdate'
      if (Test-Path $policyPath) {
        $pol = Get-ItemProperty -Path $policyPath -ErrorAction SilentlyContinue
        $out.Gpo_EnableAutoUpd = $pol.EnableAutomaticUpdates
        $out.Gpo_HideUpdNotif  = $pol.HideUpdateNotifications
        if ($null -ne $pol.UpdateBranch -and -not $out.UpdateChannel) { $out.UpdateChannel = $pol.UpdateBranch }
        if ($null -ne $pol.UpdatePath) { $out.UpdatePath = $pol.UpdatePath }
        $out.Raw.Policy = $pol | Select-Object *
      }
      
      # Friendly channel resolve (keywords first, then GUID URL)
      $raw = if ($out.UpdateChannel) { $out.UpdateChannel } elseif ($out.CDNBaseUrl) { $out.CDNBaseUrl } else { $null }
      if ($raw) {
        foreach ($k in $ChannelHints.Keys) {
        if ($raw -match [Regex]::Escape($k)) { $out.ChannelFriendly = $ChannelHints[$k]; break }
        }
        if (-not $out.ChannelFriendly) {
    
            # Try GUID in URL: http(s)://.../pr/<GUID> or the raw GUID itself
            if ($raw -match '([0-9a-fA-F-]{36})') {
                $guid = $Matches[1].ToLower()
                $map = $using:ChannelGuidMap
                if ($map[$guid]) {
                    $out.ChannelFriendly = $Map[$guid]
                }
            }
        }
        if (-not $out.ChannelFriendly) { $out.ChannelFriendly = $raw }
        }
      
      # Friendly channel resolve
      $raw = if ($out.UpdateChannel) { $out.UpdateChannel } elseif ($out.CDNBaseUrl) { $out.CDNBaseUrl } else { $null }
      if ($raw) {
        foreach ($k in $ChannelHints.Keys) { if ($raw -match [Regex]::Escape($k)) { $out.ChannelFriendly = $ChannelHints[$k]; break } }
        if (-not $out.ChannelFriendly) { $out.ChannelFriendly = $raw }
      }

      # Service: ClickToRunSvc
      try {
        $svc = Get-CimInstance -ClassName Win32_Service -Filter "Name='ClickToRunSvc'" -ErrorAction Stop
        $out.C2RService      = $svc.State
        $out.ServiceStartType= $svc.StartMode
      } catch { $out.Notes += "ClickToRunSvc not found." }

      # Scheduled Task
      try {
        $task = Get-ScheduledTask -TaskPath "\Microsoft\Office\" -TaskName "Office Automatic Updates 2.0" -ErrorAction Stop
        $info = Get-ScheduledTaskInfo -TaskName "Office Automatic Updates 2.0" -TaskPath "\Microsoft\Office\" -ErrorAction SilentlyContinue
        $out.TaskPresent  = $true
        $out.TaskEnabled  = $task.Settings.Enabled
        $out.TaskLastRunTime = $info.LastRunTime
        $out.TaskNextRunTime = $info.NextRunTime
      } catch { $out.TaskPresent = $false }

      # CDN reachability (port 443)
      $hosts = @('officecdn.microsoft.com','officecdn.microsoft.com.edgesuite.net')
      $ok = $false
      foreach ($h in $hosts) {
        try {
          $probe = Test-NetConnection -ComputerName $h -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
          if ($probe) { $ok = $true; break }
        } catch {}
      }
      $out.CDNReachable443 = $ok

      $out
    }
    catch {
      $out.Notes += "Unhandled: $($_.Exception.Message)"
      $out
    }
  }

  # Hints for channel friendly names
  $ChannelHints = @{
    'MonthlyEnterprise' = 'MonthlyEnterprise'
    'CurrentPreview'    = 'CurrentPreview'
    'Current'           = 'Current'
    'Beta'              = 'Beta'
    'SemiAnnualPreview' = 'SemiAnnualPreview'
    'SemiAnnual'        = 'SemiAnnual'
    'PerpetualVL2019'   = 'PerpetualVL2019'
    'PerpetualVL2021'   = 'PerpetualVL2021'
    'Broad'             = 'MonthlyEnterprise'
    'Targeted'          = 'CurrentPreview'
  }

  # Optional: map known CDN GUID URLs to friendly channel names
  $ChannelGuidMap = @{
  # Fill in with what your tenant uses. Examples below (verify for your environment).
    '7ffbc6bf-bc32-4f92-8982-f9dd17fd3114' = 'Current'             # example
    'b8f9b850-328d-4355-9145-c59439a0c4cf' = 'CurrentPreview'      # example
    '492350f6-3a01-4f97-b9c0-c7c6ddf67d60' = 'MonthlyEnterprise'   # example
  'b58f5d0f-83b9-45e8-9b8a-45d1c2d6f6b3' = 'SemiAnnual'          # example
  '5440b9cb-9e73-4b43-a1e5-1ba7e8b4b8a6' = 'SemiAnnualPreview'   # example
  '5440fd1f-7ecb-4221-8110-145efaa6372f' = 'PerpetualVL2019'     # example
  'd9f5bf3b-7c42-4a82-9e2a-3bcb5f2a2cbe' = 'PerpetualVL2021'     # example
}


# After defining $collector and $ChannelHints (still in begin{}):
Write-Host "collector type: $($collector.GetType().FullName)"        # expect ScriptBlock
Write-Host "ChannelHints type: $($ChannelHints.GetType().FullName)"  # expect Hashtable

}



process {}

end {
  Write-Host ("[{0}] Starting detection on {1} host(s)..." -f (Get-Date).ToString("s"), $ComputerName.Count) -ForegroundColor Cyan

  # Fan-out with Invoke-Command -AsJob (parallel; avoids Start-Job serialization issues)
  $icmParams = @{
    ComputerName = $ComputerName
    ScriptBlock  = $collector
    ArgumentList = @($ChannelHints)
    ThrottleLimit= $ThrottleLimit
    AsJob        = $true
    ErrorAction  = 'SilentlyContinue'
  }
  if ($PSCmdlet.ParameterSetName -eq 'WithCred' -and $Credential) {
    $icmParams.Credential = $Credential
  }

  $job = Invoke-Command @icmParams

  # Wait and receive all results
  Wait-Job $job | Out-Null
  $results = Receive-Job $job -Keep

  # Build quick lookup of errors per target (if any)
  $errorsByComputer = @{}
  foreach ($cj in $job.ChildJobs) {
    $target = $cj.Location
    if ($cj.JobStateInfo.State -eq 'Failed' -or $cj.JobStateInfo.Reason) {
      $msg = ($cj.JobStateInfo.Reason.Message)
      if ($msg) { $errorsByComputer[$target] = $msg }
    }
  }

  foreach ($obj in $results) {
    try {
      $stampNow = (Get-Date).ToString('s')

      # Prefer PSComputerName from remoting; fall back to self-reported ComputerName
      $target = $obj.PSComputerName
      if (-not $target) { $target = $obj.ComputerName }

      # Per-host folder
      $pcDir = Join-Path $OutDir $target
      if (-not (Test-Path $pcDir)) { New-Item -Path $pcDir -ItemType Directory -Force | Out-Null }

      # Compose payload (include executor metadata)
      $payload = [ordered]@{
        RunId        = $runId
        AuditTag     = $executor.AuditTag
        Executor     = $executor.Executor
        ExecutorHost = $executor.ExecutorHost
        Timestamp    = $obj.Timestamp
        Computer     = $target
        Detect       = $obj
      }
      $jsonPath = Join-Path $pcDir ("M365Apps_UpdateHealth_{0:yyyyMMdd_HHmmss}.json" -f (Get-Date))
      $payload | ConvertTo-Json -Depth 8 | Set-Content -Path $jsonPath -Encoding UTF8

      # Prune oldest JSONs (keep newest N)
      if ($MaxJsonPerHost -gt 0) {
        Get-ChildItem -Path $pcDir -Filter 'M365Apps_UpdateHealth_*.json' |
          Sort-Object LastWriteTime -Descending |
          Select-Object -Skip $MaxJsonPerHost |
          Remove-Item -Force -ErrorAction SilentlyContinue
      }


      # Build combined Notes string safely (works in PS 5.1 and 7+)
      $notes  = (@($obj.Notes) + @($errNote)) -join '; '
       
      $health = $null
      if ($obj.PSObject.Properties.Name -contains 'Raw' -and
      $obj.Raw -ne $null -and
      $obj.Raw.PSObject.Properties.Name -contains 'HealthFlags' -and
      $obj.Raw.HealthFlags) {
      $health = ($obj.Raw.HealthFlags -join '|')
      }

      if ($health) {
      $allNotes = "$notes; $health"
      } else {
      $allNotes = $notes
      }
      
      $row = ('{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},"{10}","{11}","{12}","{13}","{14}",{15},"{16}","{17}",{18},{19},"{20}","{21}",{22},"{23}"' -f `
      $runId,
      ($executor.AuditTag -replace '"',''''),
      $stampNow,($executor.Executor -replace '"',''''),
      ($executor.ExecutorHost -replace '"',''''),
      $target,
      [bool]$obj.WinRM.Reachable,
      [bool]$obj.WinRM.WsManOK,
      ($obj.WinRM.ServiceState    -replace '"',''''),
      ($obj.WinRM.StartMode       -replace '"',''''),
      ($obj.OS                    -replace '"',''''),
      ($obj.LoggedOnUser          -replace '"',''''),
      ($obj.OfficeVersion         -replace '"',''''),
      ($obj.UpdateChannel         -replace '"',''''),
      ($obj.ChannelFriendly       -replace '"',''''),
      ($obj.UpdatesEnabled),
      ($obj.C2RService            -replace '"',''''),
      ($obj.ServiceStartType      -replace '"',''''),
      [bool]$obj.TaskPresent,
      ($obj.TaskEnabled),
      ($obj.TaskLastRunTime),
      ($obj.TaskNextRunTime),
      [bool]$obj.CDNReachable443,
      ($allNotes -replace '"','''')
      )
      Add-Content -Path $summaryCsv -Value $row




      # Pull any per-target job error (if remote script failed for that host)
      $errNote = $null
      if ($errorsByComputer.ContainsKey($target)) { $errNote = $errorsByComputer[$target] }

      # Append summary CSV row (defensive null handling)
      $row = ('{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},"{10}","{11}","{12}","{13}","{14}",{15},"{16}","{17}",{18},{19},"{20}","{21}",{22},"{23}"' -f `
        $runId,
        ($executor.AuditTag -replace '"',''''),
        $stampNow,
        ($executor.Executor -replace '"',''''),
        ($executor.ExecutorHost -replace '"',''''),
        $target,
        [bool]$obj.WinRM.Reachable,
        [bool]$obj.WinRM.WsManOK,
        ($obj.WinRM.ServiceState    -replace '"',''''),
        ($obj.WinRM.StartMode       -replace '"',''''),
        ($obj.OS                    -replace '"',''''),
        ($obj.LoggedOnUser          -replace '"',''''),
        ($obj.OfficeVersion         -replace '"',''''),
        ($obj.UpdateChannel         -replace '"',''''),
        ($obj.ChannelFriendly       -replace '"',''''),
        ($obj.UpdatesEnabled),
        ($obj.C2RService            -replace '"',''''),
        ($obj.ServiceStartType      -replace '"',''''),
        [bool]$obj.TaskPresent,
        ($obj.TaskEnabled),
        ($obj.TaskLastRunTime),
        ($obj.TaskNextRunTime),
        [bool]$obj.CDNReachable443,
        ($obj.Raw.HealthFlags -join '|'),
        ((@($obj.Notes) + @($errNote) | Where-Object {$_}) -join '; ' -replace '"','''')
      )
      Add-Content -Path $summaryCsv -Value $row
    }
    catch {
      $err = ($_.Exception.Message -replace '"','''')
      $row = '{0},{1},{2},{3},{4},{5},false,false,,,,,,,,,,,,,,,"{6}"' -f `
        $runId, $executor.AuditTag, (Get-Date).ToString('s'), $executor.Executor, $executor.ExecutorHost, $target, $err
      Add-Content -Path $summaryCsv -Value $row
    }
  }

  Write-Host "Done. Summary CSV: $summaryCsv" -ForegroundColor Green
  Write-Host "Per-host JSON under: $OutDir\<ComputerName>\" -ForegroundColor Green
}

