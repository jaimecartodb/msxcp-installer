# Request Access to MSXCP

The MSXCP **working repository** (`jaimecartodb/emea-dn-governance-report`) is private. It contains
governance data, territory configurations, and CRM payload examples that aren't suitable for public
release.

To install MSXCP, your GitHub account must have **Read** access to that working repo, granted via the
`msxcp-users` team.

## How to request access

1. Make sure your GitHub account is the one you actually use day-to-day (corporate or personal — either
   works, but it has to be the one you'll authenticate with via `gh auth login`).
2. Open an issue on this installer repo:
   👉 [Open an access-request issue](https://github.com/jaimecartodb/msxcp-installer/issues/new?title=Access%20request%3A%20msxcp-users&body=GitHub%20username%3A%20%0AYour%20name%3A%20%0ATeam%2Fterritory%3A%20%0AReason%3A%20)
3. Or contact Jaime de Mora directly (Microsoft EMEA — Digital Natives team).

Include:
- Your GitHub username (`@yourhandle`).
- Your name and team / territory.
- A one-line reason ("EMEA DN seller for ES territory", "beta tester", etc.).

Once you've been added to the `msxcp-users` team, re-run the bootstrap one-liner:

```powershell
irm https://raw.githubusercontent.com/jaimecartodb/msxcp-installer/main/bootstrap.ps1 | iex
```

It will detect your access and proceed automatically.

## Why is the working repo private?

It contains:

- Real customer financials (per-account ACR / PBO / pipeline numbers).
- Live territory escalations and risk commentary.
- ATU codes and seller assignments.
- CRM query templates that reveal internal entity shapes.

None of that belongs in a public repo. The installer (this repo) deliberately contains **none** of it
— only bootstrap scripts, the launcher binary source, winget manifests, and install documentation.
