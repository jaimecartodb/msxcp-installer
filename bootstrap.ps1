<#
.SYNOPSIS
    MSXCP Bootstrap — One-command setup for the EMEA DN Governance Report system.

.DESCRIPTION
    Run this script once to set up everything needed to generate governance reports.
    It checks prerequisites, authenticates with GitHub (your Microsoft EMU account),
    clones the MCAPS-internal working repo, installs dependencies, and runs setup.

.PARAMETER Owner
    GitHub org that owns the working repo. Defaults to the MSXCP_REPO_OWNER
    environment variable, then falls back to 'mcaps-microsoft'.

.PARAMETER Check
    Run prerequisite + access checks only — no clone, no install, no setup.
    Useful for diagnosing "why won't it install" before a full run.

.EXAMPLE
    # From any directory (recommended one-liner):
    irm https://raw.githubusercontent.com/jaimecartodb/msxcp-installer/main/bootstrap.ps1 | iex

.EXAMPLE
    # Check prereqs without installing anything:
    $env:MSXCP_BOOTSTRAP_CHECK = "1"
    irm https://raw.githubusercontent.com/jaimecartodb/msxcp-installer/main/bootstrap.ps1 | iex

.EXAMPLE
    # Point at an alternate fork or test org:
    .\bootstrap.ps1 -Owner mcaps-microsoft

.NOTES
    Prerequisites: a Windows machine with `winget` (Windows 10 1809+ or Windows 11),
    and a Microsoft GitHub EMU account (e.g. <alias>_microsoft). MSXCP is a
    MCAPS-internal tool — all access is governed by membership of the
    `mcaps-microsoft` GitHub org (Internal-visibility repo).

    Everything else — Git, GitHub CLI, Node.js, Python, Azure CLI — is auto-installed
    by this script if missing. GlobalProtect VPN still has to be installed from your
    IT portal separately.

    If you don't yet have a Microsoft GitHub EMU account, or aren't a member of
    `mcaps-microsoft`, the bootstrap prints a friendly link to the StartRight
    onboarding portal (https://aka.ms/startright) and exits cleanly.
#>
param(
    [string]$Owner = $(if ($env:MSXCP_REPO_OWNER) { $env:MSXCP_REPO_OWNER } else { 'mcaps-microsoft' }),
    [switch]$Check
)

$ErrorActionPreference = "Stop"
$WorkDir    = Join-Path $env:USERPROFILE "Coding"
$LogPath    = Join-Path $WorkDir "msxcp-bootstrap.log"
$WorkRepo   = "msxcp-engine"
$AccessUrl  = "https://github.com/jaimecartodb/msxcp-installer/blob/main/docs/REQUEST-ACCESS.md"
$StartRight = "https://aka.ms/startright"

# Honour env var as alternate way to trigger -Check (works through `irm | iex`).
if ($env:MSXCP_BOOTSTRAP_CHECK -eq "1") { $Check = $true }

# ── Transcript ─────────────────────────────────────────────────
if (-not (Test-Path $WorkDir)) {
    New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
}
try { Start-Transcript -Path $LogPath -Append -ErrorAction SilentlyContinue | Out-Null } catch {}

Write-Host ""
Write-Host "  ============================================================" -ForegroundColor Cyan
Write-Host "  MSXCP — First-Time Setup" -ForegroundColor Cyan
Write-Host "  The AI-powered governance report engine for EMEA DN" -ForegroundColor Cyan
Write-Host "  ============================================================" -ForegroundColor Cyan
if ($Check) {
    Write-Host "  [CHECK MODE] Prereq + access checks only — nothing will be installed." -ForegroundColor Yellow
}
Write-Host ""

# ── Step 1: Check / auto-install prerequisites ────────────────
Write-Host "  [1/6] Checking prerequisites..." -ForegroundColor Yellow
Write-Host ""

# winget itself is required to auto-install anything else.
$haveWinget = $false
try { winget --version 2>&1 | Out-Null; if ($LASTEXITCODE -eq 0) { $haveWinget = $true } } catch {}
if (-not $haveWinget) {
    Write-Host "    [X] winget not available. Update Windows or install 'App Installer' from the Store, then retry." -ForegroundColor Red
    if (-not $Check) { try { Stop-Transcript } catch {}; exit 1 }
}

$prereqs = @(
    @{ Name = "Git";        Cmd = "git --version";    Pkg = "Git.Git" },
    @{ Name = "GitHub CLI"; Cmd = "gh --version";     Pkg = "GitHub.cli" },
    @{ Name = "Node.js";    Cmd = "node --version";   Pkg = "OpenJS.NodeJS.LTS" },
    @{ Name = "Python";     Cmd = "python --version"; Pkg = "Python.Python.3.11" },
    @{ Name = "Azure CLI";  Cmd = "az --version";     Pkg = "Microsoft.AzureCLI" }
)

$installedAny = $false
foreach ($p in $prereqs) {
    $found = $false
    try {
        $result = Invoke-Expression $p.Cmd 2>&1 | Select-Object -First 1
        if ($LASTEXITCODE -eq 0 -or $result) {
            Write-Host "    [+] $($p.Name): $result" -ForegroundColor Green
            $found = $true
        }
    } catch {}

    if (-not $found) {
        if ($Check) {
            Write-Host "    [X] $($p.Name): NOT FOUND (would install $($p.Pkg))" -ForegroundColor Red
            continue
        }
        Write-Host "    [>] $($p.Name): not found — installing via winget ($($p.Pkg))..." -ForegroundColor Yellow
        winget install --id $p.Pkg --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "        Installed. (You may need to close + reopen this shell so PATH picks it up.)" -ForegroundColor Green
            $installedAny = $true
        } else {
            Write-Host "    [X] winget install failed for $($p.Name). Install it manually and re-run." -ForegroundColor Red
            try { Stop-Transcript } catch {}
            exit 1
        }
    }
}

if ($installedAny) {
    Write-Host ""
    Write-Host "  Some tools were just installed. Refreshing PATH for this session." -ForegroundColor Yellow
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

Write-Host ""

# ── Step 2: GitHub authentication ──────────────────────────────
Write-Host "  [2/6] Authenticating with GitHub..." -ForegroundColor Yellow
$ghAuthed = $false
try {
    gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { $ghAuthed = $true }
} catch {}

if (-not $ghAuthed) {
    if ($Check) {
        Write-Host "    [X] Not authenticated with GitHub (would run 'gh auth login -w')" -ForegroundColor Red
    } else {
        Write-Host "    Not signed in. Opening browser for GitHub login..." -ForegroundColor Gray
        gh auth login -h github.com -w
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    [X] gh auth login failed. Re-run bootstrap after signing in manually." -ForegroundColor Red
            try { Stop-Transcript } catch {}
            exit 1
        }
    }
} else {
    $ghUser = (gh api user --jq .login 2>$null)
    Write-Host "    [+] Signed in as: $ghUser" -ForegroundColor Green
}

# Some org SAML setups need an org-read token scope. Skip the refresh if we
# already have it — `gh auth refresh` always opens an OAuth flow, which hangs
# silently when invoked via `irm | iex` (no TTY for the device-code prompt).
if (-not $Check) {
    $hasOrgScope = $false
    try {
        $scopesLine = (gh auth status -t 2>&1 | Select-String 'Token scopes' | Select-Object -First 1).ToString()
        if ($scopesLine -match 'read:org') { $hasOrgScope = $true }
    } catch {}
    if (-not $hasOrgScope) {
        Write-Host "    Granting read:org scope (browser will open briefly)..." -ForegroundColor Gray
        try { gh auth refresh -h github.com -s read:org } catch {}
    }
}

# ── Step 2.5: Verify access to the private working repo ───────
Write-Host ""
Write-Host "  [2.5/6] Verifying access to $Owner/$WorkRepo..." -ForegroundColor Yellow
$hasAccess = $false
try {
    gh api "repos/$Owner/$WorkRepo" --jq .full_name 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { $hasAccess = $true }
} catch {}

if (-not $hasAccess) {
    $ghUserNow = (gh api user --jq .login 2>$null)
    Write-Host ""
    Write-Host "  [X] Your GitHub account ($ghUserNow) can't see $Owner/$WorkRepo." -ForegroundColor Red
    Write-Host ""
    if ($ghUserNow -notmatch "_microsoft$") {
        Write-Host "      You appear to be signed in with a personal GitHub account." -ForegroundColor Gray
        Write-Host "      MSXCP is a MCAPS-internal tool — access requires your Microsoft" -ForegroundColor Gray
        Write-Host "      GitHub EMU account (looks like <alias>_microsoft)." -ForegroundColor Gray
        Write-Host ""
        Write-Host "      Fix: gh auth logout, then re-run this bootstrap and pick your" -ForegroundColor Cyan
        Write-Host "           Microsoft account when the browser opens." -ForegroundColor Cyan
    } else {
        Write-Host "      You're signed in with your Microsoft EMU account, but you're not" -ForegroundColor Gray
        Write-Host "      yet a member of the 'mcaps-microsoft' GitHub org (which the repo" -ForegroundColor Gray
        Write-Host "      lives in)." -ForegroundColor Gray
        Write-Host ""
        Write-Host "      Join the org via StartRight (one-time, takes ~5 min):" -ForegroundColor Cyan
        Write-Host "        $StartRight" -ForegroundColor Cyan
        Write-Host "        -> 'Join organization' -> search 'mcaps-microsoft' -> submit" -ForegroundColor Cyan
    }
    Write-Host ""
    Write-Host "      More info: $AccessUrl" -ForegroundColor Gray
    Write-Host "      Once you have access, re-run this bootstrap." -ForegroundColor Gray
    Write-Host ""
    try { Stop-Transcript } catch {}
    exit 1
} else {
    Write-Host "    [+] Access confirmed." -ForegroundColor Green
}

if ($Check) {
    Write-Host ""
    Write-Host "  [CHECK MODE] All checks complete. Re-run without -Check to install." -ForegroundColor Cyan
    try { Stop-Transcript } catch {}
    exit 0
}

# ── Step 3: Clone working repo ────────────────────────────────
Write-Host ""
Write-Host "  [3/6] Cloning $WorkRepo..." -ForegroundColor Yellow
$repoPath = Join-Path $WorkDir $WorkRepo
if (Test-Path $repoPath) {
    Write-Host "    Already cloned at $repoPath — pulling latest..."
    Push-Location $repoPath
    git pull --quiet 2>&1 | Out-Null
    Pop-Location
} else {
    Write-Host "    Cloning to $repoPath..."
    gh repo clone "$Owner/$WorkRepo" $repoPath -- --quiet 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    [X] Clone failed. Check network/VPN and re-run." -ForegroundColor Red
        try { Stop-Transcript } catch {}
        exit 1
    }
}

# ── Step 4: Install dependencies ──────────────────────────────
Write-Host ""
Write-Host "  [4/6] Installing dependencies..." -ForegroundColor Yellow

$mcpDir = Join-Path $repoPath "vendor\msx-copilot-mcp"
if (Test-Path $mcpDir) {
    Write-Host "    npm install (vendor/msx-copilot-mcp)..."
    Push-Location $mcpDir
    $npmOut = npm install --no-progress 2>&1
    if ($LASTEXITCODE -ne 0) {
        Pop-Location
        Write-Host ""
        Write-Host "  npm install failed:" -ForegroundColor Red
        Write-Host ($npmOut | Select-Object -Last 10 | Out-String)
        Write-Host "  Check your network/proxy and retry bootstrap." -ForegroundColor Red
        try { Stop-Transcript } catch {}
        exit 1
    }
    Pop-Location
}

Write-Host "    pip install (governance report)..."
Push-Location $repoPath
$pipOut = pip install -r requirements.txt 2>&1
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    Write-Host ""
    Write-Host "  pip install failed:" -ForegroundColor Red
    Write-Host ($pipOut | Select-Object -Last 10 | Out-String)
    Write-Host "  Check your network/proxy and retry bootstrap." -ForegroundColor Red
    try { Stop-Transcript } catch {}
    exit 1
}

if (Test-Path ".githooks") {
    git config core.hooksPath .githooks 2>&1 | Out-Null
    Write-Host "    Git hooks enabled (.githooks)"
}
Pop-Location

Write-Host "    Dependencies installed"

# ── Step 4.5: VPN connectivity check ─────────────────────────
Write-Host ""
Write-Host "  [4.5/6] Checking VPN connectivity..." -ForegroundColor Yellow
$vpnOk = $false
try {
    $test = Test-NetConnection microsoftsales.crm.dynamics.com -Port 443 -WarningAction SilentlyContinue -InformationLevel Quiet -ErrorAction Stop
    if ($test) { $vpnOk = $true }
} catch { $vpnOk = $false }

if ($vpnOk) {
    Write-Host "    VPN reachable — MSX CRM accessible" -ForegroundColor Green
} else {
    Write-Host "    WARNING: cannot reach MSX CRM (microsoftsales.crm.dynamics.com)" -ForegroundColor Yellow
    Write-Host "    Connect GlobalProtect VPN before generating reports." -ForegroundColor Yellow
}

# ── Step 5: Azure login ──────────────────────────────────────
Write-Host ""
Write-Host "  [5/6] Checking Azure login..." -ForegroundColor Yellow
try {
    $azUser = az account show --query "user.name" -o tsv 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    Already logged in as: $azUser"
    } else { throw "not logged in" }
} catch {
    Write-Host "    Azure login required — opening browser..."
    az login --tenant 72f988bf-86f1-41af-91ab-2d7cd011db47
}

# ── Step 6: Interactive setup ─────────────────────────────────
Write-Host ""
Write-Host "  [6/6] Running interactive setup..." -ForegroundColor Yellow
Write-Host ""
Push-Location $repoPath
$env:PYTHONIOENCODING = "utf-8"
python run_governance.py --setup
Pop-Location

# ── Done ──────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ============================================================" -ForegroundColor Green
Write-Host "  Setup complete!" -ForegroundColor Green
Write-Host "  ============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Your working directory: $repoPath"
Write-Host "  Bootstrap log: $LogPath"
Write-Host ""

# Register a 'msxcp' command in the user's PowerShell profile.
try {
    $profilePath = $PROFILE.CurrentUserAllHosts
    $profileDir = Split-Path $profilePath -Parent
    if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
    $marker = "# >>> MSXCP launcher (added by bootstrap.ps1) >>>"
    $endMarker = "# <<< MSXCP launcher <<<"
    $existing = ""
    if (Test-Path $profilePath) { $existing = Get-Content $profilePath -Raw }
    if ($existing -match [regex]::Escape($marker)) {
        $pattern = [regex]::Escape($marker) + "[\s\S]*?" + [regex]::Escape($endMarker) + "\r?\n?"
        $existing = [regex]::Replace($existing, $pattern, "")
    }
    $block = @"
$marker
function msxcp { & '$repoPath\msxcp.ps1' @args }
$endMarker
"@
    Set-Content -Path $profilePath -Value ($existing.TrimEnd() + "`r`n" + $block) -Encoding UTF8
    Write-Host "  [OK] Registered 'msxcp' in $profilePath" -ForegroundColor Green
    Write-Host "       Open a new PowerShell window and just type: msxcp"
} catch {
    Write-Host "  [!] Could not auto-register 'msxcp' alias: $_" -ForegroundColor Yellow
    Write-Host "      Manual fallback: Set-Alias msxcp `"$repoPath\msxcp.ps1`""
}

Write-Host ""
Write-Host "  Next steps:"
Write-Host "    1) Open a new PowerShell window"
Write-Host "    2) Type:  msxcp"
Write-Host ""

try { Stop-Transcript } catch {}
