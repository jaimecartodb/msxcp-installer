<#
.SYNOPSIS
    MSXCP — One-shot repair: register MSXCP with Copilot CLI (MCP + tool approvals).

.DESCRIPTION
    For users who already installed MSXCP and are tired of approving
    `python`, `az`, `gh`, `git`, etc. on every command — and/or whose
    Copilot CLI doesn't yet route natural-language prompts to MSXCP.

    Preferred path: invokes the canonical engine installer
    `python -m msxcp install copilot-cli --force`, which registers the
    MSXCP MCP server in ~/.copilot/mcp.json AND seeds the auto-approvals.

    Fallback (only if the engine isn't cloned, or Python is missing):
    seeds the auto-approvals via the bundled PowerShell helper. That fixes
    the prompts but does NOT register the MCP server.

    Both modes are idempotent and back up existing config before changing it.

.EXAMPLE
    # Standard one-liner (assumes engine at %USERPROFILE%\Coding\msxcp-engine):
    irm https://raw.githubusercontent.com/jaimecartodb/msxcp-installer/main/trust-tools.ps1 | iex

.EXAMPLE
    # Custom engine location:
    $env:MSXCP_ENGINE_PATH = 'D:\work\msxcp-engine'
    irm https://raw.githubusercontent.com/jaimecartodb/msxcp-installer/main/trust-tools.ps1 | iex

.NOTES
    This is a no-op for the engine repo's behaviour — it only changes how
    the Copilot CLI gates command execution and which MCP servers are
    registered. You can revert by restoring permissions-config.json.bak
    and mcp.json.bak.
#>

$ErrorActionPreference = 'Stop'

$enginePath = if ($env:MSXCP_ENGINE_PATH) {
    $env:MSXCP_ENGINE_PATH
} else {
    Join-Path $env:USERPROFILE 'Coding\msxcp-engine'
}

Write-Host ''
Write-Host '  MSXCP — trust-tools' -ForegroundColor Cyan
Write-Host '  Registering MSXCP with Copilot CLI (MCP + auto-approvals)' -ForegroundColor DarkGray
Write-Host ''

# Preferred path: hand off to the canonical engine installer. Covers MCP
# registration AND auto-approvals in one shot, and stays the single source
# of truth as the toolset evolves.
$haveEngine = (Test-Path $enginePath) -and (Test-Path (Join-Path $enginePath 'msxcp\install.py'))
$havePython = $null -ne (Get-Command python -ErrorAction SilentlyContinue)

if ($haveEngine -and $havePython) {
    Write-Host "  Using engine installer: python -m msxcp install copilot-cli --force" -ForegroundColor DarkGray
    Push-Location $enginePath
    try {
        $env:MSXCP_ROOT = $enginePath
        python -m msxcp install copilot-cli --force
        $code = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    if ($code -eq 0) {
        Write-Host ''
        Write-Host '  Done. Open a new Copilot CLI session in the engine repo to pick up the change.' -ForegroundColor Green
        Write-Host ''
        exit 0
    }
    Write-Host ''
    Write-Host "  [!] Engine installer failed (exit $code). Falling back to PowerShell shim..." -ForegroundColor Yellow
    Write-Host ''
}

if (-not $haveEngine) {
    Write-Host "  [!] Engine repo not found at: $enginePath" -ForegroundColor Yellow
    Write-Host "      Falling back to PowerShell shim — this seeds auto-approvals" -ForegroundColor Yellow
    Write-Host "      for that path so they take effect once you clone (or run bootstrap)." -ForegroundColor Yellow
    Write-Host "      You will still need 'msxcp install copilot-cli' afterwards to register MCP." -ForegroundColor Yellow
    Write-Host ''
}

# Fallback: bundled PowerShell helper (auto-approvals only, no MCP registration).
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

$result = Set-MsxcpToolApprovals -RepoPath $enginePath

Write-Host ''
if ($result.Skipped) {
    Write-Host '  Auto-approvals already in place. (MCP registration not attempted in fallback mode.)' -ForegroundColor Green
} else {
    Write-Host '  Auto-approvals seeded. Open a new Copilot CLI session in the engine repo to pick up the change.' -ForegroundColor Green
}
Write-Host ''
