# AgentMint — Binance Agent ID Hackathon submission brief

## Project name

**AgentMint**

## One-paragraph description

AgentMint is a free, open-source NFT minter for Agent ID holders on BNB
Chain. Anyone who holds a Binance Agent ID can mint exactly one AgentMint
NFT — no payment, no fees, no allowlist. The contract is a minimal ERC-721
whose only owner power is changing metadata; it never holds funds, has no
withdraw function, and generates all metadata fully on-chain (data-URI
JSON with an inline SVG badge showing the token number and the minter's
Agent ID handle), so the collection needs no hosting and no backend. It
shows what Agent ID is for: a wallet's on-chain identity gating something
useful, with the check done entirely on-chain in one call.

## How it uses Agent ID

The mint is gated on the official Agent ID registry (SPACE ID Agent ID,
`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` on BNB Chain). The contract
calls `registry.balanceOf(msg.sender) > 0` — the canonical ERC-721
ownership check — so only wallets that actually hold an Agent ID can mint.
The same registry also supplies the minter's handle (`handleOf`) for the
on-chain SVG badge, so every NFT is visibly tied to its owner's Agent ID.
No off-chain allowlist, no signatures, no oracle: eligibility is proven
on-chain, by the registry itself.

## Website

- **URL: TBD** — the static frontend is ready in `frontend/` (no build
  step, ethers v6 via CDN); the deployed contract address is already set
  in `frontend/app.js` (`CONFIG.contractAddress`). Hosting on
  Vercel/Netlify/GitHub Pages is still pending.
- The site: connect wallet → checks Agent ID eligibility via the registry
  → free mint button → tx status with BscScan link.

## Contract address

- **Mainnet (BSC 56): `0xf6593c8cb43b763f8dc731886467f80a134bebe9`** — DEPLOYED
  20 Nov 2026 ~12:47 WIB, block 134,641,401.
- Deploy tx: `0x51151adbc15f3f496f553a720e221517d5809d69c7697fd5baa5e439908f2a79`
  (status 1). From hisyam.ai via the Arachnid deterministic deployment
  proxy (CREATE2, salt 0) — baw cannot send a direct contract-creation tx,
  so the factory route was used; owner is hisyam.ai, gas used 2,031,068
  at 0.0715 gwei = 0.000145221362 BNB (≈Rp1.506).
- Verified on-chain: name "AgentMint", symbol "AGM", owner hisyam.ai,
  registry 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F, MAX_SUPPLY 10,000,
  totalSupply 0, holdsAgentID(hisyam.ai) = true. Runtime bytecode
  byte-identical to the compiled artifact except the two immutable slots
  (registry + 10,000).
- Source verified on Sourcify — exact match (creation + runtime),
  verifiedAt 2026-11-20T05:50:00Z, matchId 59571868.
  BscScan: https://bscscan.com/address/0xf6593c8cb43b763f8dc731886467f80a134bebe9
- Testnet/local verification is complete (see TEST-REPORT.md): 11/11 fork
  tests against the real registry, plus a live end-to-end deploy + mint on
  local anvil with a mock registry.

## Prize-recipient wallet

- **hisyam.ai — `0x65f51A97152BAe3D3F17321992003521BAB562eC`** (Binance
  Agentic Wallet). **Confirmed by the user 20 Nov 2026 ~13:06 WIB.**

## Submission form

- Form: https://app.binance.com/uni-qr/user-survey/fb26d2bd25e04329b1ba77c7b3811d23
  ("Agent ID Hackathon Project Submission Form", via the "Submit Project
  Now" button on the official Square post).
- Deadline: **9 Dec 2026 15:00 WIB**.
- Status: **NOT submitted.** Nothing has been submitted and nothing will
  be submitted without the user's explicit go-ahead, a deployed + verified
  mainnet contract, and a live website URL.

## Open source

- License: MIT. Contract `contracts/AgentMint.sol`, frontend
  `frontend/`, tests `test/AgentMint.t.sol` — all in the project workspace.
  (Public repo link to be added when the code is pushed to GitHub.)
