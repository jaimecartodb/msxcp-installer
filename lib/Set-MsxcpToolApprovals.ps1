<#
.SYNOPSIS
    Pre-seed Copilot CLI per-folder tool approvals for the MSXCP engine repo.

.DESCRIPTION
    Edits ~/.copilot/permissions-config.json (the file Copilot CLI uses to
    remember "Yes, and don't ask again for X in this repo") and adds the
    standard MSXCP toolset for the engine repo path, so day-to-day commands
    (python, az, gh, git, common PowerShell cmdlets) run without an approval
    prompt INSIDE that one folder.

    Anywhere outside the engine repo, normal Copilot CLI prompting is unchanged.

    Properties:
      * MERGES with existing config — never overwrites other approvals.
      * IDEMPOTENT — safe to re-run; only adds what's missing.
      * BACKUP — writes permissions-config.json.bak before any change.
      * ATOMIC — writes via .tmp + Move-Item to avoid half-written files.
      * PowerShell 5.1 + 6+ compatible (no -AsHashtable dependency).

.PARAMETER RepoPath
    Absolute path to the MSXCP engine repo. Defaults to
    %USERPROFILE%\Coding\msxcp-engine (the path bootstrap.ps1 uses).

.PARAMETER Quiet
    Suppress all non-error host output (for use inside other scripts).

.EXAMPLE
    . .\lib\Set-MsxcpToolApprovals.ps1
    Set-MsxcpToolApprovals

.EXAMPLE
    Set-MsxcpToolApprovals -RepoPath 'D:\work\msxcp-engine'
#>

function Set-MsxcpToolApprovals {
    [CmdletBinding()]
    param(
        [string]$RepoPath = (Join-Path $env:USERPROFILE 'Coding\msxcp-engine'),
        [switch]$Quiet
    )

    function _Say($msg, $color = 'Gray') {
        if (-not $Quiet) { Write-Host $msg -ForegroundColor $color }
    }

    # Standard MSXCP toolset — the binaries the engine actually shells out to,
    # plus the read-only PowerShell cmdlets the agent uses constantly. Keep
    # this list narrow: every entry here trades a confirmation prompt for an
    # implicit trust grant inside the engine repo.
    $msxcpCommands = @(
        # Language runtimes & package managers
        'python', 'pip', 'node', 'npm',
        # Source control + cloud auth
        'git', 'gh', 'az',
        # PowerShell read / format helpers (no side effects)
        'Get-Content', 'Get-ChildItem', 'Get-Item', 'Get-ItemProperty',
        'Select-Object', 'Select-String', 'Where-Object', 'ForEach-Object',
        'Sort-Object', 'Measure-Object', 'Format-Table', 'Format-List',
        'ConvertFrom-Json', 'ConvertTo-Json',
        # PowerShell write helpers used by the agent for report output
        'Write-Host', 'Write-Output', 'Out-File', 'Out-Null', 'Tee-Object',
        # Open files / launch helper apps for finished reports
        'Invoke-Item', 'Start-Process'
    )

    $configDir  = Join-Path $env:USERPROFILE '.copilot'
    $configPath = Join-Path $configDir 'permissions-config.json'
    $backupPath = "$configPath.bak"

    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    # ---- Load existing config (or start fresh) -----------------------------
    $config = $null
    if (Test-Path $configPath) {
        try {
            Copy-Item -LiteralPath $configPath -Destination $backupPath -Force
            $raw = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
            if ($raw.Trim()) {
                $config = $raw | ConvertFrom-Json
            }
        } catch {
            _Say "    [!] Existing permissions-config.json could not be parsed: $_" 'Yellow'
            _Say "        Backed up to $backupPath; starting fresh." 'Yellow'
            $config = $null
        }
    }
    if (-not $config) {
        $config = [pscustomobject]@{ locations = [pscustomobject]@{} }
    }
    if (-not $config.PSObject.Properties.Match('locations').Count) {
        $config | Add-Member -NotePropertyName 'locations' `
            -NotePropertyValue ([pscustomobject]@{}) -Force
    }
    if ($null -eq $config.locations) {
        $config.locations = [pscustomobject]@{}
    }

    # ---- Get-or-create the location entry ----------------------------------
    # NOTE: location keys in the file are stored as full Windows paths with
    # backslashes. PSCustomObject + Add-Member handles arbitrary key strings
    # correctly; ConvertTo-Json will escape backslashes on write.
    $loc = $null
    foreach ($p in $config.locations.PSObject.Properties) {
        if ($p.Name -eq $RepoPath) { $loc = $p.Value; break }
    }
    if (-not $loc) {
        $loc = [pscustomobject]@{ tool_approvals = @() }
        $config.locations | Add-Member -NotePropertyName $RepoPath `
            -NotePropertyValue $loc -Force
    }
    if (-not $loc.PSObject.Properties.Match('tool_approvals').Count) {
        $loc | Add-Member -NotePropertyName 'tool_approvals' `
            -NotePropertyValue @() -Force
    }

    # ---- Inventory what's already approved ---------------------------------
    $alreadyApproved = New-Object System.Collections.Generic.HashSet[string](
        [System.StringComparer]::OrdinalIgnoreCase)
    $hasWrite  = $false
    $hasMemory = $false
    foreach ($entry in @($loc.tool_approvals)) {
        if ($null -eq $entry) { continue }
        switch ($entry.kind) {
            'commands' {
                foreach ($id in @($entry.commandIdentifiers)) {
                    if ($id) { [void]$alreadyApproved.Add([string]$id) }
                }
            }
            'write'  { $hasWrite  = $true }
            'memory' { $hasMemory = $true }
        }
    }

    # ---- Compute additions -------------------------------------------------
    $missingCommands = @($msxcpCommands | Where-Object {
        -not $alreadyApproved.Contains($_)
    })

    $additions = @()
    if ($missingCommands.Count -gt 0) {
        $additions += [pscustomobject]@{
            kind               = 'commands'
            commandIdentifiers = $missingCommands
        }
    }
    if (-not $hasWrite)  { $additions += [pscustomobject]@{ kind = 'write'  } }
    if (-not $hasMemory) { $additions += [pscustomobject]@{ kind = 'memory' } }

    if ($additions.Count -eq 0) {
        _Say "    [+] MSXCP tool approvals already in place for $RepoPath" 'Green'
        return [pscustomobject]@{
            Path     = $RepoPath
            Added    = @()
            Skipped  = $true
            Backup   = $(if (Test-Path $backupPath) { $backupPath } else { $null })
        }
    }

    $loc.tool_approvals = @($loc.tool_approvals) + $additions

    # ---- Write back atomically ---------------------------------------------
    $tmpPath = "$configPath.tmp"
    try {
        ($config | ConvertTo-Json -Depth 20) |
            Out-File -FilePath $tmpPath -Encoding UTF8 -Force
        Move-Item -LiteralPath $tmpPath -Destination $configPath -Force
    } catch {
        if (Test-Path $tmpPath) { Remove-Item -LiteralPath $tmpPath -Force -ErrorAction SilentlyContinue }
        throw
    }

    _Say "    [+] Seeded MSXCP tool approvals for $RepoPath" 'Green'
    if ($missingCommands.Count -gt 0) {
        _Say "        Added commands: $($missingCommands -join ', ')" 'DarkGray'
    }
    if (-not $hasWrite)  { _Say "        Added approval kind: write"  'DarkGray' }
    if (-not $hasMemory) { _Say "        Added approval kind: memory" 'DarkGray' }
    _Say "        Backup: $backupPath" 'DarkGray'

    return [pscustomobject]@{
        Path    = $RepoPath
        Added   = $missingCommands
        Skipped = $false
        Backup  = $backupPath
    }
}
