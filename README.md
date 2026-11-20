# AgentMint — Free mint for Agent ID holders on BNB Chain

A free, open-source ERC-721 minter where every Binance Agent ID holder can
mint exactly one NFT. No payment, no fees, no allowlist, no withdraw — the
contract never holds funds. Built for the **Binance Agent ID Hackathon**
(Project Awards, 58,000 USDC).

## Live site

https://hisyammahfudz.github.io/agentmint/

Connect wallet → the page checks your Agent ID eligibility → free mint.

## Contract (BSC mainnet, chain 56)

- **AgentMint:** `0xf6593c8cb43b763f8dc731886467f80a134bebe9`
- **Deploy tx:** `0x51151adbc15f3f496f553a720e221517d5809d69c7697fd5baa5e439908f2a79`
  (block 134,641,401, 20 Nov 2026)
- **BscScan:** https://bscscan.com/address/0xf6593c8cb43b763f8dc731886467f80a134bebe9
- **Source verified on Sourcify:** exact match (creation + runtime),
  matchId 59571868.
- **First mint (smoke test):** token #1 to hisyam.ai, tx
  `0x09059337e31fb7ae1c334f07982516466b5ed4cdffbce61eb7e61c738ee947ee`.

## How it works

- The contract checks the official Agent ID registry (SPACE ID Agent ID,
  `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`): a caller holds an Agent ID
  iff `registry.balanceOf(caller) > 0`.
- `mint()` is non-payable, so sending BNB reverts. One mint per wallet,
  supply cap 10,000.
- Metadata is generated fully on-chain: `tokenURI` returns a data-URI JSON
  with an inline SVG badge showing the token number and the owner's Agent
  ID handle. No hosting dependency for the NFTs themselves.
- Owner powers are limited to `setBaseURI` (metadata only). No pause, no
  withdraw, no hidden transfers or approvals.

## Files in this repo

| Path | What it is |
| --- | --- |
| `index.html`, `app.js` | Static minter site (ethers v6 via CDN, no build step) |
| `AgentMint.sol` | The minter contract (ERC-721, OpenZeppelin 5.0.2) |
| `TEST-REPORT.md` | Full test evidence (11/11 fork tests, gas) |
| `SUBMISSION.md` | Hackathon submission brief |

## Build & test (from source)

Requires [Foundry](https://getfoundry.sh) (forge 1.10.0), solc 0.8.24,
optimizer enabled, 200 runs, EVM Cancun, OpenZeppelin Contracts v5.0.2.

```bash
forge build
forge test --fork-url https://bsc-dataseed.binance.org -vv
# → 11 passed, 0 failed
```

## License

MIT. Prize-recipient wallet: hisyam.ai
(`0x65f51A97152BAe3D3F17321992003521BAB562eC`).
