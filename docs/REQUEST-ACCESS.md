# Getting Access to MSXCP

MSXCP is a **MCAPS-internal tool**. The working repository (`mcaps-microsoft/msxcp-engine`) has **Internal visibility** inside the Microsoft GitHub EMU enterprise — meaning **any Microsoft employee who is a member of the `mcaps-microsoft` GitHub org** can read and clone it. There is no per-user invitation step, no `msxcp-users` team to join, and no manual approval.

If the bootstrap tells you it can't see `mcaps-microsoft/msxcp-engine`, one of two things is true.

## 1. You're signed in with a personal GitHub account

The bootstrap detects this and tells you. MSXCP requires your **Microsoft EMU GitHub account** — the one that looks like `<alias>_microsoft` (e.g., `jdoe_microsoft`). You almost certainly already have one if you've ever used GitHub at Microsoft.

**Fix:**

```powershell
gh auth logout              # clear the personal account
# re-run the install one-liner — when the browser opens, pick the
# "Microsoft" / Single Sign-On option, NOT a personal sign-in.
irm https://raw.githubusercontent.com/jaimecartodb/msxcp-installer/main/bootstrap.ps1 | iex
```

If you're not sure whether you have an EMU account, just run the bootstrap — it'll surface the right `gh auth login` flow, and signing in via Microsoft SSO will provision/sign you in to your EMU account automatically.

## 2. Your EMU account isn't a member of `mcaps-microsoft` yet

This is a one-time onboarding step (~5 min) via Microsoft's StartRight portal.

**Direct link (pre-filled for `mcaps-microsoft`):**
👉 https://web-ux.prod.startclean.microsoft.com/?join=mcaps-microsoft

**Or the canonical shortlink:**
👉 https://aka.ms/startright → **"Join organization"** → search **`mcaps-microsoft`** → submit.

Provisioning is usually quick (a few minutes), occasionally up to a few hours. Once it completes, **re-run the bootstrap one-liner** — your access will be detected automatically.

## Why this model?

- ✅ **No bottleneck on a single admin** — you don't need to wait for anyone to invite you.
- ✅ **Aligned with peer MCAPS tooling** — this is the same access model used by `mcaps-microsoft/msx-mcp`, `mcaps-microsoft/iq-core`, etc.
- ✅ **Governed by your Microsoft identity** — when you leave or change roles, EMU handles offboarding automatically.
- ✅ **No customer data leakage risk** — Internal visibility is enforced at the GitHub Enterprise boundary; non-Microsoft accounts cannot see the repo even if they know its URL.

## What's in the working repo (and why we keep it Internal, not Public)

- Real MCAPS customer financials (per-account ACR / PBO / pipeline numbers).
- Live territory escalations and risk commentary.
- ATU codes and seller assignments.
- CRM query templates that reveal internal entity shapes.

None of that belongs outside Microsoft. This installer repo (which is **public**) deliberately contains **none** of the above — only bootstrap scripts, the launcher binary source, winget manifests, and install documentation.

## Still stuck?

Open an issue on this installer repo:
👉 https://github.com/jaimecartodb/msxcp-installer/issues/new

Or contact **Jaime de Mora** (CTO Startups & Unicorns, Microsoft EMEA — Digital Natives team).
