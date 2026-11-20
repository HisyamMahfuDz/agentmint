# AgentMint — Test report

Date: 20 Nov 2026 (~11:37–12:00 WIB). All tests run by Muse; no mainnet
funds spent, nothing submitted.

## 1. Registry verification (live BSC mainnet RPC, 20 Nov 2026)

Source: Sourcify v2 ABI for
`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`, cross-checked with live
`eth_call` reads via `https://bsc-dataseed.binance.org`.

| Check | Result |
| --- | --- |
| `name()` | `"SPACE ID Agent ID"` |
| `symbol()` | `"AI"` |
| `balanceOf(hisyam.ai 0x65f51…2eC)` | `1` — holder |
| `balanceOf(testnet wallet 0x689C…8324)` | `0` — non-holder |
| `balanceOf(0x000…000)` | reverts `ERC721InvalidOwner` (expected; `msg.sender` can never be zero) |
| `handleOf(hisyam.ai)` | `"hisyam"` |
| `handleOf(0x000…000)` | `""` (empty) |

**Gating check (verified, not guessed):** the registry is an ERC-721, so
"caller holds an Agent ID" is exactly `registry.balanceOf(caller) > 0`.
That is the check `AgentMint.mint()` uses. It matches how the existing
Agent ID-gated free mints gate on the same registry.

## 2. Fork tests — real registry, BSC mainnet fork (forge)

Command: `forge test --fork-url https://bsc-dataseed.binance.org -vv`
Toolchain: forge 1.10.0, solc 0.8.24, optimizer on / 200 runs,
OpenZeppelin 5.0.2, forge-std 1.17.0. The tests impersonate
hisyam.ai (a real holder, `balanceOf == 1`) via `vm.prank`; no real
transaction is sent.

| # | Test | Result | Gas |
| --- | --- | --- | --- |
| 1 | `testRegistryIsReal` (holder / non-holder / zero address) | PASS | 28,193 |
| 2 | `testHolderCanMint` (holder mints #1, `ownerOf(1)` = hisyam.ai) | PASS | 145,331 |
| 3 | `testHolderCannotMintTwice` (reverts `AlreadyMinted`) | PASS | 138,346 |
| 4 | `testNonHolderCannotMint` (reverts `NotAgentIDHolder`) | PASS | 39,793 |
| 5 | `testMintWithValueReverts` (low-level call with 0.01 ETH reverts; `mint()` is non-payable) | PASS | 36,571 |
| 6 | `testNonOwnerCannotSetBaseURI` (reverts `OwnableUnauthorizedAccount`) | PASS | 33,439 |
| 7 | `testOwnerCanSetBaseURI` (set → `tokenURI` uses it; clear → back to on-chain) | PASS | 395,165 |
| 8 | `testTokenURIOnChain` (`tokenURI(1)` starts with `data:application/json;base64,`) | PASS | 304,482 |
| 9 | `testTokenURINonexistentReverts` | PASS | 12,700 |
| 10 | `testIsEligible` (true → false after mint; false for non-holder) | PASS | 147,530 |
| 11 | `testSupplyCap` (cap-1 instance: 2nd mint reverts `SoldOut`) | PASS | 2,199,909 |

**11 passed, 0 failed, 0 skipped.**

## 3. Live end-to-end test — local anvil (chain 31337) with mock registry

Anvil (no fork) on `http://127.0.0.1:8545`. Deployed via
`script/DeployLocal.s.sol` (`--broadcast --unlocked`, deployer = anvil
account #0 `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`, granted one mock
Agent ID `"localtester"`). All transactions status `1`.

| Tx | Hash | Gas used |
| --- | --- | --- |
| Deploy `MockAgentIDRegistry` | `0x5dd5fed5ac79c31b9c6cdb97e16f681300eab23085d89b5490d9f2fef1690d78` | 310,457 |
| `grant(deployer, "localtester")` | `0x3a8c6ec6ad91a50360f78dc4b0ab6afca01d7c551475acb2db72c54084323a99` | 67,467 |
| Deploy `AgentMint` | `0xcee38eab792752b1acd8872588d963d5731fbe1ee763d50d18ed355bd6a017d7` | **2,027,286** |
| `mint()` (smoke mint, token #1) | `0x501483fee09b6aecebec4d7da592ae0152e12499d964ef4d1dab2dcb995929e7` | **102,694** |

Addresses (local anvil only, not mainnet):
- Mock registry: `0x5FbDB2315678afecb367f032d93F642f64180aa3`
- AgentMint: `0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0`

State verified live with `cast`:
- `ownerOf(1)` = `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` ✓
- `totalSupply()` = 1, `remaining()` = 9,999 ✓
- `holdsAgentID(deployer)` = true, `isEligible(deployer)` = false after mint ✓
- Non-holder (anvil account #1) `mint()` → reverts `NotAgentIDHolder` (`0x9ed3633c`) ✓
- Second mint by deployer → reverts `AlreadyMinted` (`0xddefae28`) ✓
- `tokenURI(1)` decoded: valid JSON (`name: "AgentMint #1"`,
  `description: "Free mint for Agent ID holders on BNB Chain. One per
  Agent ID holder, no fees, no payment. Minted by localtester.ai."`,
  attributes `Agent ID = localtester.ai`, `Mint = Free`) and a valid
  749-byte inline SVG containing `#1`, `localtester.ai`, `AGENTMINT` ✓

## 4. Deployment gas — mainnet estimate

Measured on the live local deploy (receipt): **deploy 2,027,286 gas**,
**mint 102,694 gas**. Fork simulation of the mainnet deploy script
reported 2,635,139 total gas (includes simulation overhead) — treat as an
upper bound. Fork-test mint gas 145,331 includes test-harness overhead;
use it as the conservative mint figure.

Live inputs (20 Nov 2026 ~11:53 WIB):
- BSC gas price (`cast gas-price`): **0.05 gwei**
- BNB price: **Rp10.368.161** (CoinGecko; Binance Vision $568.16/BNB)

| Action | Gas | @ 0.05 gwei (BNB / Rp) | @ 0.10 gwei (BNB / Rp) |
| --- | --- | --- | --- |
| Deploy AgentMint | 2,027,286 | 0.000101 / Rp1.051 | 0.000203 / Rp2.102 |
| Mint (1 NFT) | 145,331 (conservative) | 0.0000073 / Rp75 | 0.0000145 / Rp151 |
| Deploy + 1 mint | — | **≈0.000109 / Rp1.126** | **≈0.000217 / Rp2.253** |

## 5. Funding check (fresh, 20 Nov 2026 ~11:53 WIB)

| Wallet | BNB balance | ≈ Rp | Covers deploy + 1 mint? |
| --- | --- | --- | --- |
| hisyam.ai `0x65f51…2eC` | 0.000299419081205379 | Rp3.105 | **Yes** at 0.05 and 0.10 gwei; leaves ≈0.000190 BNB (≈Rp1.970) at 0.05 gwei, ≈0.000082 BNB (≈Rp850) at 0.10 gwei |
| meta1 `0x0CEd…cEDE` | 0.002320315800445661 | Rp24.055 | Yes, easily (not the designated deployer/prize wallet) |

**No funding gap for the deployment itself.** Margin on hisyam.ai is
thin: after deploying, only ~0.00008–0.00019 BNB remains — enough for
roughly 10–25 more simple transactions at current gas prices. A small
top-up before deploying is recommended (not strictly required). Note the
deploy must go through the Binance Agentic Wallet (`baw`) with user +
Binance App approval; baw's gas price has historically varied
0.055–0.105 gwei.

## 6. Blockers

1. **BSC testnet deploy — BLOCKED: testnet wallet holds 0 tBNB.**
   Checked with `cast balance` on `https://bsc-testnet.publicnode.com`
   and `https://bsc-testnet-dataseed.bnbchain.org` (both returned `0`);
   `data-seed-prebsc-1/2-s1.binance.org:8545` timed out (egress).
   No other wallet was used (per instructions). Remedy: claim tBNB from
   the BSC testnet faucet, then run `script/DeployLocal.s.sol` on chain 97.
2. **Anvil BSC-mainnet fork — blocked by egress timeouts.** `anvil
   --fork-url` failed twice at genesis (`failed to get account ... MPP
   HTTP request ... operation timed out`) on both `bsc-dataseed` and
   `bsc-dataseed1`. Forge's fork (used by the 11 passing tests) works
   fine — only anvil's heavier genesis fetch times out. Not a contract
   issue; the fork tests already prove the real-registry gating.
3. **Mainnet deploy + form submission — NOT done** (by design). Both need
   the user's explicit confirmation: deploy needs a per-transaction
   confirmation + Binance App approval; the submission form needs the
   deployed contract address, a live website URL, and confirmation of
   hisyam.ai as prize recipient.
4. **Frontend not hosted.** `frontend/` is ready but has no public URL
   yet; `CONFIG.contractAddress` is empty until mainnet deploy. Hosting
   (Vercel/Netlify/GitHub Pages) is a post-deploy step.

## 7. Toolchain record (for Sourcify/BscScan verification)

- solc **0.8.24**, optimizer **enabled, 200 runs**, EVM Cancun, no via-IR
- OpenZeppelin Contracts **v5.0.2**, forge-std **v1.17.0**, forge **1.10.0**
- Constructor args (mainnet): registry
  `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`, maxSupply `10000`,
  owner = deployer (hisyam.ai)
