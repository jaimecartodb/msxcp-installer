<#
.SYNOPSIS
    Pin the local msxcp-engine clone to a specific git ref + write engine.lock.

.DESCRIPTION
    Idempotent helper used by both bootstrap.ps1 (first-time install) and
    trust-tools.ps1 (repair). Ensures every MSXCP user runs *the same*
    engine code as their colleagues — the local-side counterpart to PR1–PR5
    in mcaps-microsoft/msxcp-engine, which made canonical reports run
    centrally in GHA at a pinned engine_ref.

    Behavior:
      1. Verify the repo's `origin` URL points at the expected upstream
         (mcaps-microsoft/msxcp-engine). Refuses to pin against a stranger.
      2. Hard-fail if the repo has any uncommitted changes (modified,
         staged, or untracked files). The whole point of pinning is that
         engine code is canonical — silent stash would defeat that.
      3. `git fetch --tags --quiet` so the requested ref is resolvable.
      4. `git rev-parse --verify "$Ref^{commit}"` to validate the ref is
         a real, unambiguous commit. Reject typos / unknown tags.
      5. `git checkout` the resolved SHA in detached-HEAD state. Detached
         HEAD is intentional: if a user does `git pull` by habit, the
         resulting error is a useful signal that they're bypassing the
         pinning model.
      6. Write `<repo>/.engine.lock` with the resolved identity. Read by
         msxcp.ps1 on every launch to detect drift.

    Returns the resolved SHA on success. Throws on failure (caller decides
    whether to exit or continue).

.PARAMETER RepoPath
    Path to the local msxcp-engine clone.

.PARAMETER Ref
    Git ref to pin to. May be a tag (preferred), branch, or full SHA.
    For reproducibility, prefer immutable tags over branch names.

.PARAMETER ExpectedOrigin
    Substring that must appear in `git remote get-url origin`. Defaults to
    'mcaps-microsoft/msxcp-engine'. Use only when forking/testing.

.PARAMETER InstallerVersion
    Version string of the installer producing the lock (for diagnostics).
#>

param(
    [Parameter(Mandatory=$true)][string]$RepoPath,
    [Parameter(Mandatory=$true)][string]$Ref,
    [string]$ExpectedOrigin = 'mcaps-microsoft/msxcp-engine',
    [string]$InstallerVersion = 'unknown'
)

$ErrorActionPreference = 'Stop'

function Invoke-Git {
    param([string[]]$GitArgs)
    $out = & git -C $RepoPath @GitArgs 2>&1
    $code = $LASTEXITCODE
    return [pscustomobject]@{ Output = $out; ExitCode = $code }
}

if (-not (Test-Path (Join-Path $RepoPath ".git"))) {
    throw "Not a git repository: $RepoPath"
}

# 1. Origin check — refuse to pin a clone that points at the wrong upstream.
$origin = (Invoke-Git @('remote', 'get-url', 'origin')).Output | Out-String
$origin = $origin.Trim()
if (-not ($origin -match [regex]::Escape($ExpectedOrigin))) {
    throw @"
Engine repo origin does not look right: $origin
Expected to contain: $ExpectedOrigin
Refusing to pin — re-run bootstrap.ps1 to reclone, or fix the remote.
"@
}

# 2. Cleanliness gate — modified or staged tracked files block. Untracked
#    files (generated reports, scratch data, gitignored experiments) are
#    common and legitimate, so we allow them. The integrity guarantee that
#    matters is "no one runs modified engine code"; new files in the working
#    tree don't change the engine code that gets executed.
$status = (Invoke-Git @('status', '--porcelain=v1', '--untracked-files=no')).Output
if ($status) {
    $statusText = ($status | Out-String).TrimEnd()
    throw @"
Engine repo at $RepoPath has uncommitted changes to TRACKED files:

$statusText

MSXCP requires every user to run identical engine code. Refusing to repin
silently. Either commit/discard your changes, or remove the repo and let
bootstrap.ps1 reclone it cleanly:

    Remove-Item -Recurse -Force '$RepoPath'
    irm https://aka.ms/msxcp | iex
"@
}

# 3. Fetch tags so the requested ref is resolvable.
$fetch = Invoke-Git @('fetch', '--tags', '--quiet', '--prune')
if ($fetch.ExitCode -ne 0) {
    throw "git fetch failed (exit $($fetch.ExitCode)): $($fetch.Output)"
}

# 4. Validate ref resolves to exactly one commit.
$revParse = Invoke-Git @('rev-parse', '--verify', "$Ref^{commit}")
if ($revParse.ExitCode -ne 0) {
    throw @"
Engine ref '$Ref' could not be resolved to a commit.

Available recent tags:
$((Invoke-Git @('tag', '--sort=-creatordate', '-l', 'v*')).Output | Select-Object -First 10 | Out-String)

Set MSXCP_ENGINE_REF to a valid tag and re-run.
"@
}
$resolvedSha = ($revParse.Output | Out-String).Trim()

# Determine ref type for the lockfile (tag/branch/sha) — best-effort.
$refType = 'unknown'
if ((Invoke-Git @('show-ref', '--verify', '--quiet', "refs/tags/$Ref")).ExitCode -eq 0) {
    $refType = 'tag'
} elseif ((Invoke-Git @('show-ref', '--verify', '--quiet', "refs/remotes/origin/$Ref")).ExitCode -eq 0) {
    $refType = 'branch'
} elseif ($Ref -match '^[0-9a-f]{7,40}$' -and $resolvedSha.StartsWith($Ref.ToLower())) {
    $refType = 'sha'
}

# 5. Detached-HEAD checkout to the resolved SHA.
$currentSha = ((Invoke-Git @('rev-parse', 'HEAD')).Output | Out-String).Trim()
if ($currentSha -ne $resolvedSha) {
    $checkout = Invoke-Git @('-c', 'advice.detachedHead=false', 'checkout', '--quiet', $resolvedSha)
    if ($checkout.ExitCode -ne 0) {
        throw "git checkout $resolvedSha failed: $($checkout.Output)"
    }
}

# 6. Write engine.lock.
$lock = [ordered]@{
    schema_version    = 1
    engine_ref        = $Ref
    engine_ref_type   = $refType
    engine_sha        = $resolvedSha
    origin            = $origin
    installed_at      = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    installer_version = $InstallerVersion
    pinned_by         = "Set-MsxcpEnginePin.ps1"
}
$lockPath = Join-Path $RepoPath ".engine.lock"
$lock | ConvertTo-Json -Depth 4 | Set-Content -Path $lockPath -Encoding UTF8 -NoNewline:$false

return $resolvedSha
