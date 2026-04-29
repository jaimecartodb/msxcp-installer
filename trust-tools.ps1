<#
.SYNOPSIS
    MSXCP — One-shot repair: pre-seed Copilot CLI tool approvals for the engine repo.

.DESCRIPTION
    For users who already installed MSXCP and are tired of approving
    `python`, `az`, `gh`, `git`, etc. on every command. Adds those binaries
    to ~/.copilot/permissions-config.json for the engine repo path so the
    Copilot CLI stops prompting INSIDE that one repo. Anywhere else,
    normal prompting is unchanged.

    Safe to run repeatedly: merges with existing approvals, never
    overwrites, and writes permissions-config.json.bak first.

.EXAMPLE
    # Standard one-liner (assumes engine at %USERPROFILE%\Coding\msxcp-engine):
    irm https://raw.githubusercontent.com/jaimecartodb/msxcp-installer/main/trust-tools.ps1 | iex

.EXAMPLE
    # Custom engine location:
    $env:MSXCP_ENGINE_PATH = 'D:\work\msxcp-engine'
    irm https://raw.githubusercontent.com/jaimecartodb/msxcp-installer/main/trust-tools.ps1 | iex

.NOTES
    This is a no-op for the engine repo's behaviour — it only changes how
    the Copilot CLI gates command execution. You can revert by restoring
    permissions-config.json.bak.
#>

$ErrorActionPreference = 'Stop'

$enginePath = if ($env:MSXCP_ENGINE_PATH) {
    $env:MSXCP_ENGINE_PATH
} else {
    Join-Path $env:USERPROFILE 'Coding\msxcp-engine'
}

Write-Host ''
Write-Host '  MSXCP — trust-tools' -ForegroundColor Cyan
Write-Host '  Pre-seeding Copilot CLI per-repo command approvals' -ForegroundColor DarkGray
Write-Host ''

# Resolve the helper. Two sources, in order of preference:
#  1. A local clone of msxcp-installer (lib/Set-MsxcpToolApprovals.ps1).
#  2. Download from raw.githubusercontent.com — supports `irm | iex`.
$localHelper = $null
$candidates = @(
    (Join-Path $PSScriptRoot 'lib\Set-MsxcpToolApprovals.ps1'),
    (Join-Path $env:USERPROFILE 'Coding\msxcp-installer\lib\Set-MsxcpToolApprovals.ps1')
)
foreach ($c in $candidates) {
    if ($c -and (Test-Path $c)) { $localHelper = $c; break }
}

if ($localHelper) {
    . $localHelper
} else {
    $url = 'https://raw.githubusercontent.com/jaimecartodb/msxcp-installer/main/lib/Set-MsxcpToolApprovals.ps1'
    try {
        $script = Invoke-RestMethod -Uri $url -UseBasicParsing
        Invoke-Expression $script
    } catch {
        Write-Host "  [X] Could not download the helper from $url" -ForegroundColor Red
        Write-Host "      $_" -ForegroundColor Red
        exit 1
    }
}

if (-not (Test-Path $enginePath)) {
    Write-Host "  [!] Engine repo not found at: $enginePath" -ForegroundColor Yellow
    Write-Host "      Approvals will still be written for that path so they take" -ForegroundColor Yellow
    Write-Host "      effect once you clone (or run the bootstrap)." -ForegroundColor Yellow
    Write-Host ''
}

$result = Set-MsxcpToolApprovals -RepoPath $enginePath

Write-Host ''
if ($result.Skipped) {
    Write-Host '  Nothing to do. You are already trusted.' -ForegroundColor Green
} else {
    Write-Host '  Done. Open a new Copilot CLI session in the engine repo to pick up the change.' -ForegroundColor Green
}
Write-Host ''
