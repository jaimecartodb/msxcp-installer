# MSXCP Installer

**Public installer + winget manifests for [MSXCP](https://github.com/mcaps-microsoft/msxcp-engine)** — the AI-powered governance report engine for the EMEA Digital Natives team (MCAPS).

> The MSXCP working repository is **MCAPS-internal** (`mcaps-microsoft/msxcp-engine`, Internal visibility).
> Any Microsoft employee who is a member of the `mcaps-microsoft` GitHub org can install MSXCP — no per-user invitation required.
> If you're not yet a member of `mcaps-microsoft`, see [docs/REQUEST-ACCESS.md](docs/REQUEST-ACCESS.md).

---

## Install

### Recommended — one-liner (Windows 10 1809+ / Windows 11)

```powershell
irm https://raw.githubusercontent.com/jaimecartodb/msxcp-installer/main/bootstrap.ps1 | iex
```

What this does:
1. Installs prereqs via `winget`: Git, GitHub CLI, Node.js LTS, Python 3.11, Azure CLI.
2. Prompts you to sign in to GitHub with your **Microsoft EMU account** (looks like `<alias>_microsoft`) — `gh auth login` browser flow.
3. Verifies your account can read `mcaps-microsoft/msxcp-engine`. If not, prints a friendly link to StartRight (https://aka.ms/startright) and exits cleanly.
4. Clones the working repo to `%USERPROFILE%\Coding\msxcp-engine`.
5. Installs npm + pip dependencies.
6. Logs you into Azure (browser flow).
7. Runs the interactive territory-setup wizard.
8. Registers an `msxcp` command in your PowerShell profile.

A transcript of the run is written to `%USERPROFILE%\Coding\msxcp-bootstrap.log` for support.

### Check-only mode (don't install anything yet)

```powershell
$env:MSXCP_BOOTSTRAP_CHECK = "1"; irm https://raw.githubusercontent.com/jaimecartodb/msxcp-installer/main/bootstrap.ps1 | iex
```

Reports which prereqs are missing and whether your GitHub account has access — without changing your machine.

### Alternative — winget (coming soon)

> ⚠️ **Not yet available** — the [winget-pkgs PR](https://github.com/microsoft/winget-pkgs/pull/364380) hasn't merged yet.
> Until it does, use the bootstrap one-liner above.

Once the PR lands, you'll be able to install with:

```powershell
winget install jaimecartodb.MSXCP
```

For internal pilots, you can install from the local manifests in this repo today:

```powershell
git clone https://github.com/jaimecartodb/msxcp-installer
winget install --manifest .\msxcp-installer\winget\manifests\j\jaimecartodb\MSXCP\0.2.0\
```

---

## Audience matrix — which install path is for me?

| If you are…                                                  | Use this path                                          |
| ------------------------------------------------------------ | ------------------------------------------------------ |
| Microsoft employee, member of `mcaps-microsoft` GitHub org   | **Bootstrap one-liner** (top of this README)           |
| Microsoft employee, **not yet** a member of `mcaps-microsoft` | First [join the org via StartRight](docs/REQUEST-ACCESS.md), then run the bootstrap |
| Internal pilot wanting the winget UX today                   | `winget install --manifest …` against this repo        |
| Anyone, once winget-pkgs PR #364380 lands                    | `winget install jaimecartodb.MSXCP`                    |

---

## Troubleshooting

| Symptom                                                       | Cause                                                                 | Fix                                                                                                                |
| ------------------------------------------------------------- | --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `404 Not Found` on the `irm` one-liner                        | Network proxy or you mistyped the URL                                 | Confirm you can reach `raw.githubusercontent.com` and copy the URL exactly as shown above.                         |
| `Your GitHub account ... can't see mcaps-microsoft/msxcp-engine` and you're a personal GH account | You're signed in with your personal account, not your Microsoft EMU one | `gh auth logout`, re-run the bootstrap, pick the Microsoft option in the browser. Use your `<alias>_microsoft` identity. |
| Same error but you *are* on your `_microsoft` EMU account     | You're not yet a member of the `mcaps-microsoft` GitHub org           | Join via [StartRight](https://aka.ms/startright) → "Join organization" → search `mcaps-microsoft`. Re-run after.   |
| `gh auth login` browser flow fails behind a corporate proxy   | `HTTP_PROXY` not set                                                  | `setx HTTP_PROXY http://your.proxy:8080` and reopen PowerShell.                                                    |
| `winget install jaimecartodb.MSXCP` returns "No package"      | winget-pkgs PR #364380 hasn't merged                                  | Use the bootstrap one-liner instead, or `winget install --manifest …` against this repo's local manifests.         |
| MSI download URL 404                                          | Old manifest pointed at the old private working repo                  | Update to the v0.2.0+ manifest in this repo. `InstallerUrl` now points at this public repo's releases.             |

---

## What's in this repo

```
msxcp-installer/
├── bootstrap.ps1                  ← one-command first-time setup
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
