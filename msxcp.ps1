<#
.SYNOPSIS
    MSXCP — Branded launcher for the governance report engine.

.DESCRIPTION
    Optional convenience launcher that adds a branded banner and passes
    persona context (territory, role, alias) to the Copilot CLI seed prompt.

    You can also run `copilot` directly from the repo directory — both work.
    AGENTS.md will auto-detect your persona from config.json on first interaction.

    Quick access alias (optional):
        Set-Alias msxcp "C:\Users\$env:USERNAME\Coding\emea-dn-governance-report\msxcp.ps1"

.EXAMPLE
    .\msxcp.ps1              # Show banner + launch Copilot CLI
    .\msxcp.ps1 -NoCopilot   # Show banner only (for scripting/embedding)

.NOTES
    Preferred usage: cd to the repo directory and run `copilot` directly.
    The agent will call `get_profile` on first interaction to detect your persona.
#>

param(
    [Parameter(Position=0)]
    [string]$Command,
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$ExtraArgs,
    [switch]$NoCopilot,
    [switch]$Demo
)

$RepoRoot = $PSScriptRoot

# Sub-commands dispatch to python msxcp_cli.py and exit immediately.
# Keeps msxcp.ps1 thin — the Python side owns all real logic so the same
# behaviour works on macOS/Linux via the `msxcp` shell function.
$SubCommands = @('doctor','version','update','status','feedback','whats-new','smoke','help','crm')
if ($Command -and $SubCommands -contains $Command.ToLower()) {
    $env:PYTHONIOENCODING = 'utf-8'
    try {
        [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    } catch {}
    Set-Location $RepoRoot
    $cliArgs = @('-m', 'msxcp', $Command.ToLower())
    if ($ExtraArgs) { $cliArgs += $ExtraArgs }
    python @cliArgs
    exit $LASTEXITCODE
}

# Force UTF-8 so unicode box-drawing / emoji in python output render correctly.
# (PowerShell 5.1 defaults to cp1252 for child-process stdout, which produces mojibake.)
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    $OutputEncoding = [System.Text.UTF8Encoding]::new()
    $env:PYTHONIOENCODING = 'utf-8'
} catch {}

# --- First-run detection --------------------------------------------------
# If this install has no config.json, we were almost certainly just
# extracted by winget (or a user cloned the repo and hasn't run bootstrap).
# Offer to run the interactive setup. Skip in non-interactive sessions and
# when already inside bootstrap.
$configPath = Join-Path $RepoRoot "config.json"
$firstRunMarker = Join-Path $RepoRoot ".msxcp_first_run_done"
if (-not (Test-Path $configPath) -and
    -not (Test-Path $firstRunMarker) -and
    [Environment]::UserInteractive -and
    -not $env:MSXCP_SKIP_FIRST_RUN) {

    Write-Host ""
    Write-Host "  [*] MSXCP -- first run detected" -ForegroundColor Cyan
    Write-Host "  No config.json found. Would you like to run setup now?" -ForegroundColor Gray
    Write-Host "  This installs Python deps, npm deps, logs into Azure," -ForegroundColor Gray
    Write-Host "  and walks you through territory configuration." -ForegroundColor Gray
    Write-Host ""
    $answer = Read-Host "  Run setup? [Y/n]"
    if ($answer -eq '' -or $answer -match '^[Yy]') {
        & (Join-Path $RepoRoot "bootstrap.ps1")
        New-Item -ItemType File -Path $firstRunMarker -Force | Out-Null
        exit 0
    } else {
        Write-Host "  Skipping setup. Run 'msxcp' again any time to resume." -ForegroundColor Yellow
        New-Item -ItemType File -Path $firstRunMarker -Force | Out-Null
        exit 0
    }
}

# -- Count territories + read user profile from config.json --
$territories = 0
$userAlias   = ""
$userRole    = ""
$defaultTerritory = ""
if (Test-Path $configPath) {
    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        $territories = ($config.territories | Get-Member -MemberType NoteProperty).Count

        # Auto-detect user from Azure CLI login
        try {
            $azEmail = (az account show --query "user.name" -o tsv 2>$null)
            if ($azEmail -and $azEmail -match "^([^@]+)@") {
                $userAlias = $Matches[1].ToLower()
            }
        } catch { }

        # Fall back to default_user if az detection failed
        if (-not $userAlias -and $config.default_user) {
            $userAlias = $config.default_user
        }

        # Resolve persona from config
        if ($userAlias -and $config.users.$userAlias) {
            $userProfile = $config.users.$userAlias
            $userRole = $userProfile.role
            $defaultTerritory = $userProfile.default_territory
            if (-not $defaultTerritory -and $userProfile.territories.Count -eq 1) {
                $defaultTerritory = $userProfile.territories[0]
            }
        }
    } catch { }
}

# ── Probe prerequisites ─────────────────────────────────────
$probeIssues = @()
if (-not (Get-Command copilot -ErrorAction SilentlyContinue)) {
    $probeIssues += "[X] 'copilot' CLI not found on PATH - install from https://gh.io/copilot"
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    $probeIssues += "[X] 'node' not found - install Node.js 18+ from https://nodejs.org"
}
if (-not (Test-Path $configPath)) {
    $probeIssues += "[!] config.json missing - run 'python run_governance.py --setup' first"
}
$mcpVendored = Join-Path $RepoRoot "vendor\msx-copilot-mcp"
if (-not (Test-Path (Join-Path $mcpVendored "src\index.js"))) {
    $probeIssues += "[!] vendored msx-copilot-mcp missing at $mcpVendored - re-run bootstrap.ps1"
}
if ($probeIssues.Count -gt 0) {
    Write-Host ""
    foreach ($i in $probeIssues) { Write-Host "  $i" -ForegroundColor Yellow }
    Write-Host ""
    $hardFail = $probeIssues | Where-Object { $_ -like "[X]*" }
    if ($hardFail -and -not $NoCopilot) {
        Write-Host "  Cannot launch Copilot CLI. Fix the [X] issues above first." -ForegroundColor Red
        Write-Host ""
        exit 1
    }
}

# ── Brand mark ──────────────────────────────────────────────
Write-Host ""
Write-Host "  ◈ " -ForegroundColor Cyan -NoNewline
Write-Host "MSXCP" -ForegroundColor White
if ($territories -gt 0) {
    Write-Host "  governance report engine · $territories territories" -ForegroundColor DarkGray
} else {
    Write-Host "  governance report engine" -ForegroundColor DarkGray
}

# ── Engine pin / drift check ────────────────────────────────
# .engine.lock is written by the installer (Set-MsxcpEnginePin.ps1) so every
# user runs the same engine code as their colleagues. Mismatch = local
# modifications or `git pull` since pin = colleagues may see different
# behavior. Non-fatal — just a clear yellow warning.
$lockPath = Join-Path $RepoRoot ".engine.lock"
if (Test-Path $lockPath) {
    try {
        $lock = Get-Content $lockPath -Raw | ConvertFrom-Json
        $headSha = (git -C $RepoRoot rev-parse HEAD 2>$null)
        if ($LASTEXITCODE -eq 0 -and $headSha) {
            $shortPinned = $lock.engine_sha.Substring(0, [Math]::Min(7, $lock.engine_sha.Length))
            if ($headSha.Trim() -eq $lock.engine_sha) {
                Write-Host "  engine: $($lock.engine_ref) · $shortPinned" -ForegroundColor DarkGray
            } else {
                $shortHead = $headSha.Substring(0, 7)
                Write-Host "  engine: $($lock.engine_ref) · $shortPinned" -ForegroundColor DarkGray
                Write-Host "  [!] Engine has drifted from pinned $($lock.engine_ref) (now at $shortHead)" -ForegroundColor Yellow
                Write-Host "      Colleagues may see different behavior. Re-run bootstrap.ps1 to repin." -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Host "  [!] Could not read .engine.lock: $_" -ForegroundColor Yellow
    }
} elseif (Test-Path (Join-Path $RepoRoot ".git")) {
    Write-Host "  [!] Engine version not pinned. Re-run bootstrap.ps1 to pin to a known version." -ForegroundColor Yellow
}
Write-Host ""

# ── What's new — last 3 commits (best-effort, silently skipped on non-git) ──
try {
    $recent = git -C $RepoRoot log -3 --pretty=format:"%ad  %h  %s" --date=short 2>$null
    if ($LASTEXITCODE -eq 0 -and $recent) {
        Write-Host "  What's new" -ForegroundColor DarkGray
        foreach ($line in ($recent -split "`n")) {
            if ($line.Length -gt 76) { $line = $line.Substring(0, 73) + "..." }
            Write-Host "    $line" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
} catch {}

# ── Launch Copilot CLI with an MSXCP-branded greeting seed ──
# `copilot -i "<prompt>"` starts interactive mode and auto-executes the seed
# prompt on turn 1, so the user sees the ◈ welcome banner immediately instead
# of a blank prompt. The AGENTS.md "First-turn greeting" rule defines the
# exact response format.
if (-not $NoCopilot) {
    Set-Location $RepoRoot
    $today = (Get-Date).ToString("yyyy-MM-dd")
    $seed = "__MSXCP_GREET__ territories=$territories today=$today"
    if ($userRole) { $seed += " role=$userRole" }
    if ($defaultTerritory) { $seed += " default_territory=$defaultTerritory" }
    if ($userAlias) { $seed += " alias=$userAlias" }
    if ($Demo) {
        # Demo mode: skip every command-confirmation prompt so a live pitch
        # flows uninterrupted. Safe only for controlled demo runs — never for
        # day-to-day use. Triggered via `.\msxcp.ps1 -Demo`.
        Write-Host "[DEMO MODE] Tool confirmations disabled for this session." -ForegroundColor Yellow
        copilot --allow-all -i $seed
    } else {
        copilot -i $seed
    }
}
