# MSXCP Installer

**Public installer + winget manifests for [MSXCP](https://github.com/jaimecartodb/emea-dn-governance-report)** — the AI-powered governance report engine for Microsoft EMEA Digital Natives.

> The MSXCP working repository is **private**. This repo is the public entry point for installing it.
> You must have been granted Read access to the working repo before installing.
> See [docs/REQUEST-ACCESS.md](docs/REQUEST-ACCESS.md).

---

## Install

### Recommended — one-liner (Windows 10 1809+ / Windows 11)

```powershell
irm https://raw.githubusercontent.com/jaimecartodb/msxcp-installer/main/bootstrap.ps1 | iex
```

What this does:
1. Installs prereqs via `winget`: Git, GitHub CLI, Node.js LTS, Python 3.11, Azure CLI.
2. Prompts you to sign in to GitHub (`gh auth login`) — *uses your GitHub identity to clone the private working repo*.
3. Verifies you have access to `jaimecartodb/emea-dn-governance-report`. If not, prints a friendly access-request link and exits.
4. Clones the working repo to `%USERPROFILE%\Coding\emea-dn-governance-report`.
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

| If you are…                                                | Use this path                                          |
| ---------------------------------------------------------- | ------------------------------------------------------ |
| EMEA DN team member with `msxcp-users` Read access         | **Bootstrap one-liner** (top of this README)           |
| Internal pilot wanting the winget UX today                 | `winget install --manifest …` against this repo        |
| Anyone, once winget-pkgs PR #364380 lands                  | `winget install jaimecartodb.MSXCP`                    |
| Don't have access yet                                      | Read [docs/REQUEST-ACCESS.md](docs/REQUEST-ACCESS.md)  |

---

## Troubleshooting

| Symptom                                                     | Cause                                              | Fix                                                                                                                |
| ----------------------------------------------------------- | -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `404 Not Found` on the `irm` one-liner                      | Network proxy or you're typing the URL wrong       | Confirm you can reach `raw.githubusercontent.com` and copy the URL exactly as shown above.                         |
| `Your GitHub account doesn't have access to …`              | You're not on the `msxcp-users` team yet           | See [docs/REQUEST-ACCESS.md](docs/REQUEST-ACCESS.md). After you're added, re-run the bootstrap.                    |
| `gh auth login` browser flow fails behind a corporate proxy | `HTTP_PROXY` not set                               | `setx HTTP_PROXY http://your.proxy:8080` and reopen PowerShell.                                                    |
| `winget install jaimecartodb.MSXCP` returns "No package"    | winget-pkgs PR #364380 hasn't merged               | Use the bootstrap one-liner instead, or `winget install --manifest …` against this repo's local manifests.         |
| MSI download URL 404                                        | Old manifest pointed at the private working repo   | Update to the v0.2.0+ manifest in this repo. `InstallerUrl` now points at this public repo's releases.             |

---

## What's in this repo

```
msxcp-installer/
├── bootstrap.ps1                  ← one-command first-time setup
├── msxcp.ps1                      ← branded launcher (mirrored from working repo)
├── winget/
│   ├── launcher/                  ← Go source for msxcp.exe (winget portable)
│   │   ├── go.mod
│   │   └── msxcp.go
│   └── manifests/
│       └── j/jaimecartodb/MSXCP/  ← winget-pkgs manifests (one folder per version)
├── .github/workflows/release.yml  ← builds msxcp.exe + zips on tag push
├── docs/
│   ├── INSTALL.md                 ← long-form install guide
│   └── REQUEST-ACCESS.md          ← how to get added to msxcp-users
├── LICENSE
└── README.md (this file)
```

**This repo contains no customer data, no CRM payloads, no MSX queries.** All of that lives in the private working repo (`emea-dn-governance-report`), which the bootstrap clones using your authenticated GitHub session.

---

## Releases

Tagging `vX.Y.Z` here triggers `.github/workflows/release.yml`, which:

1. Builds `winget/launcher/msxcp.go` → `msxcp.exe` (Windows amd64).
2. Packages it as `MSXCP-X.Y.Z.zip`.
3. Attaches the zip to the GitHub Release.
4. Computes the SHA256 and updates the corresponding winget manifest (or hands off to `vedantmgoyal9/winget-releaser` to open the upstream PR).

The winget `InstallerUrl` for every version points at this repo's releases — never the private working repo.

---

## License

MIT — see [LICENSE](LICENSE).

`msxcp.ps1` and the `winget/launcher` Go source are mirrored from the working repository under the same licence.
