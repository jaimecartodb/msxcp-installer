# MSXCP Installer

**Public installer for [MSXCP](https://github.com/mcaps-microsoft/msxcp-engine)** — the AI-powered governance report engine for the EMEA Digital Natives team (MCAPS).

> ### 🛡️ Trust model — please read
>
> MSXCP is an **internal Microsoft tool** maintained by **Jaime de Mora** (CTO for Startups & Unicorns, MCAPS EMEA — `jaimedemora@microsoft.com`).
>
> The actual engine — including all customer financials, escalations, and territory data — lives at
> [`mcaps-microsoft/msxcp-engine`](https://github.com/mcaps-microsoft/msxcp-engine), **Internal visibility** in the
> Microsoft EMU enterprise. Only authenticated MCAPS employees can read it.
>
> This **installer repo** is hosted on a personal GitHub account (`jaimecartodb`) for one reason: the
> bootstrap one-liner uses anonymous `irm | iex`, which requires the script to live on a **public** repo —
> and the `mcaps-microsoft` GitHub org policy currently allows only Internal/Private visibility. This repo
> contains **zero customer data** — only the bootstrap script and onboarding docs.
>
> **Canonical entry point:** [`https://aka.ms/msxcp`](https://aka.ms/msxcp) — Microsoft-managed shortlink that redirects to the bootstrap script in this repo. The shortlink is owned in AAD and can be re-pointed any time, so the public-facing one-liner stays stable even if this installer ever moves to a `microsoft/` org.
>
> Audit it before you run it: [`bootstrap.ps1`](bootstrap.ps1) is the only thing the one-liner executes.

> The MSXCP working repository is **MCAPS-internal** (`mcaps-microsoft/msxcp-engine`, Internal visibility).
> Any Microsoft employee who is a member of the `mcaps-microsoft` GitHub org can install MSXCP — no per-user invitation required.
> If you're not yet a member of `mcaps-microsoft`, see [docs/REQUEST-ACCESS.md](docs/REQUEST-ACCESS.md).

---

## Install

### Recommended — one-liner (Windows 10 1809+ / Windows 11)

```powershell
irm https://aka.ms/msxcp | iex
```

What this does:
1. Installs prereqs via `winget`: Git, GitHub CLI, Node.js LTS, Python 3.11, Azure CLI.
2. Prompts you to sign in to GitHub with your **Microsoft EMU account** (looks like `<alias>_microsoft`) — `gh auth login` browser flow.
3. Verifies your account can read `mcaps-microsoft/msxcp-engine`. If not, prints a friendly link to StartRight (https://aka.ms/startright) and exits cleanly.
4. Clones the working repo to `%USERPROFILE%\Coding\msxcp-engine`.
5. Installs npm + pip dependencies.
6. Logs you into Azure (browser flow).
7. **Registers MSXCP with Copilot CLI**: runs `python -m msxcp install copilot-cli --force`, which (a) registers the MSXCP MCP server in `~/.copilot/mcp.json` so Copilot CLI routes natural-language prompts to MSXCP, and (b) seeds `~/.copilot/permissions-config.json` so day-to-day commands run without confirmation prompts — *only* inside `~\Coding\msxcp-engine`. Anywhere else on your machine, normal Copilot CLI prompting and MCP routing are unchanged. If the Python installer fails for any reason, falls back to a PowerShell shim that handles approvals only.
8. Runs the interactive territory-setup wizard.
9. Registers an `msxcp` command in your PowerShell profile.

A transcript of the run is written to `%USERPROFILE%\Coding\msxcp-bootstrap.log` for support.

### Check-only mode (don't install anything yet)

```powershell
$env:MSXCP_BOOTSTRAP_CHECK = "1"; irm https://aka.ms/msxcp | iex
```

Reports which prereqs are missing and whether your GitHub account has access — without changing your machine.

### Already installed? Stop the constant approval prompts (and/or wire up MCP)

If you installed MSXCP before the bootstrap registered MSXCP with Copilot CLI, every shell command (`python`, `git`, `gh`, `az`, …) inside the engine repo asks for confirmation, and natural-language prompts may not route to MSXCP. Run this once to fix both:

```powershell
irm https://raw.githubusercontent.com/jaimecartodb/msxcp-installer/main/trust-tools.ps1 | iex
```

What it does:
- **Preferred path:** invokes `python -m msxcp install copilot-cli --force` in your engine repo — registers the MSXCP MCP server in `~/.copilot/mcp.json` *and* seeds `~/.copilot/permissions-config.json`. Idempotent, backs up to `mcp.json.bak` and `permissions-config.json.bak`.
- **Fallback (engine missing or Python missing):** seeds approvals only via a bundled PowerShell shim (no MCP registration). Lets you stop the prompts even before the engine is cloned.

If your engine lives elsewhere: `$env:MSXCP_ENGINE_PATH = 'D:\work\msxcp-engine'` before the `irm` line.

---

## Audience matrix — which install path is for me?

| If you are…                                                  | Use this path                                          |
| ------------------------------------------------------------ | ------------------------------------------------------ |
| Microsoft employee, member of `mcaps-microsoft` GitHub org   | **Bootstrap one-liner** (top of this README)           |
| Microsoft employee, **not yet** a member of `mcaps-microsoft` | First [join the org via StartRight](docs/REQUEST-ACCESS.md), then run the bootstrap |

---

## Troubleshooting

| Symptom                                                       | Cause                                                                 | Fix                                                                                                                |
| ------------------------------------------------------------- | --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `404 Not Found` on the `irm` one-liner                        | Network proxy or you mistyped the URL                                 | Confirm you can reach `raw.githubusercontent.com` and copy the URL exactly as shown above.                         |
| `Your GitHub account ... can't see mcaps-microsoft/msxcp-engine` and you're a personal GH account | You're signed in with your personal account, not your Microsoft EMU one | `gh auth logout`, re-run the bootstrap, pick the Microsoft option in the browser. Use your `<alias>_microsoft` identity. |
| Same error but you *are* on your `_microsoft` EMU account     | You're not yet a member of the `mcaps-microsoft` GitHub org           | Join via [StartRight](https://aka.ms/startright) → "Join organization" → search `mcaps-microsoft`. Re-run after.   |
| `gh auth login` browser flow fails behind a corporate proxy   | `HTTP_PROXY` not set                                                  | `setx HTTP_PROXY http://your.proxy:8080` and reopen PowerShell.                                                    |
| MSI download URL 404                                          | Old manifest pointed at the old private working repo                  | Update to the v0.2.0+ manifest in this repo. `InstallerUrl` now points at this public repo's releases.             |

---

## What's in this repo

```
msxcp-installer/
├── bootstrap.ps1                  ← one-command first-time setup
├── trust-tools.ps1                ← one-shot repair: pre-seed Copilot CLI approvals
├── lib/
│   └── Set-MsxcpToolApprovals.ps1 ← reusable helper used by bootstrap + trust-tools
├── msxcp.ps1                      ← branded launcher (mirrored from working repo)
├── msxcp.cmd                      ← shim used by the winget-installed exe
├── winget/
│   ├── launcher/                  ← Go source for msxcp.exe (winget portable)
│   │   ├── go.mod
│   │   └── msxcp.go
│   └── manifests/
│       └── j/jaimecartodb/MSXCP/  ← winget-pkgs manifests (one folder per version)
├── .github/workflows/release.yml  ← builds msxcp.exe + zips on tag push
├── docs/
│   ├── INSTALL.md                 ← long-form install guide
│   └── REQUEST-ACCESS.md          ← how to join `mcaps-microsoft` via StartRight
├── LICENSE
└── README.md (this file)
```

**This repo contains no customer data, no CRM payloads, no MSX queries.** All of that lives in the MCAPS-internal working repo (`mcaps-microsoft/msxcp-engine`), which the bootstrap clones using your authenticated GitHub session.

This installer repo is **public** — it has to be, so the `irm | iex` one-liner works without authentication. Only the *engine* repo containing MCAPS data is Internal.

---

## Releases

Tagging `vX.Y.Z` here triggers `.github/workflows/release.yml`, which:

1. Builds `winget/launcher/msxcp.go` → `msxcp.exe` (Windows amd64).
2. Stages `msxcp.exe` + `msxcp.cmd` + `msxcp.ps1` + `bootstrap.ps1` + `LICENSE` + `README.md`.
3. Packages them as `MSXCP-X.Y.Z.zip`.
4. Attaches the zip to the GitHub Release.
5. Computes the SHA256 and updates the corresponding winget manifest (or hands off to `vedantmgoyal9/winget-releaser` to open the upstream PR).

The winget `InstallerUrl` for every version points at this repo's releases — never the working repo.

---

## License

MIT — see [LICENSE](LICENSE).

`msxcp.ps1` and the `winget/launcher` Go source are mirrored from the working repository under the same licence.
