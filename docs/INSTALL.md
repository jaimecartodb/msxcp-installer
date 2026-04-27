# MSXCP — Detailed install guide

For the quick install, see the [README](../README.md). This guide goes deeper.

## What gets installed

The bootstrap installs (via `winget`) any of these that aren't already on your machine:

| Tool          | winget package          | Why                                          |
| ------------- | ----------------------- | -------------------------------------------- |
| Git           | `Git.Git`               | Clone + version control                      |
| GitHub CLI    | `GitHub.cli`            | Authenticated clone of the MCAPS-internal repo |
| Node.js LTS   | `OpenJS.NodeJS.LTS`     | MSX-MCP CRM data fetcher                     |
| Python 3.11   | `Python.Python.3.11`    | Report generator + CLI                       |
| Azure CLI     | `Microsoft.AzureCLI`    | Auth for CRM + SharePoint                    |

You also need **GlobalProtect VPN** (for MSX CRM access). The bootstrap doesn't install it because it
comes from your IT portal — install it separately via your IT self-service portal.

## What the bootstrap touches

- Creates `%USERPROFILE%\Coding` if missing.
- Clones the working repo into `%USERPROFILE%\Coding\msxcp-engine`.
- Adds an `msxcp` function to `$PROFILE.CurrentUserAllHosts` so you can launch from any directory.
- Writes a transcript to `%USERPROFILE%\Coding\msxcp-bootstrap.log` for support.
- Runs `gh auth login -h github.com -w` (browser flow) and `gh auth refresh -s read:org`.

It does **not**:

- Modify any other PowerShell profile files.
- Install anything globally as Administrator (winget runs in user mode).
- Send telemetry anywhere.

## Re-running

The bootstrap is **idempotent**. If something fails partway, fix the underlying issue and re-run the
one-liner — it'll skip what's already done.

## Uninstall

```powershell
# Remove the working repo
Remove-Item -Recurse -Force "$env:USERPROFILE\Coding\msxcp-engine"

# Remove the msxcp function from your profile (manual edit)
notepad $PROFILE.CurrentUserAllHosts
# Delete the block between '# >>> MSXCP launcher' and '# <<< MSXCP launcher'

# Optionally uninstall the prereqs you don't need elsewhere
winget uninstall GitHub.cli      # only if you don't use gh outside MSXCP
# (Git/Node/Python/Azure CLI are usually wanted anyway — leave them.)

# Remove the bootstrap transcript
Remove-Item "$env:USERPROFILE\Coding\msxcp-bootstrap.log"
```

## Air-gapped / offline install

Not currently supported. The bootstrap needs network access to:
- `winget` package sources
- `github.com` (for clone + auth)
- `microsoftsales.crm.dynamics.com` (for CRM at runtime — VPN needed)
- Azure (for `az login`)

If you need an offline build, open an issue.

## Behind a corporate proxy

Set `HTTP_PROXY` / `HTTPS_PROXY` before running the one-liner:

```powershell
[Environment]::SetEnvironmentVariable("HTTPS_PROXY","http://your.proxy:8080","User")
[Environment]::SetEnvironmentVariable("HTTP_PROXY","http://your.proxy:8080","User")
# reopen PowerShell, then run the bootstrap one-liner
```
