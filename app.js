// AgentMint frontend — no build step, ethers v6 via CDN.
// Fill in CONTRACT_ADDRESS after the mainnet deployment; until then the
// page shows the contract as "not deployed yet" and minting stays disabled.
const CONFIG = {
  chainId: 56, // BNB Chain mainnet
  chainName: "BNB Chain",
  // Deployed 20 Nov 2026 (tx 0x51151adbc15f3f496f553a720e221517d5809d69c7697fd5baa5e439908f2a79).
  contractAddress: "0xf6593c8cb43b763f8dc731886467f80a134bebe9",
  // Official Agent ID registry (SPACE ID Agent ID, ERC-721) on BSC 56.
  registryAddress: "0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F",
  bscScan: "https://bscscan.com",
};

const AGENT_MINT_ABI = [
  "function mint()",
  "function isEligible(address account) view returns (bool)",
  "function holdsAgentID(address account) view returns (bool)",
  "function hasMinted(address account) view returns (bool)",
  "function totalSupply() view returns (uint256)",
  "function remaining() view returns (uint256)",
  "function MAX_SUPPLY() view returns (uint256)",
  "function name() view returns (string)",
  "function symbol() view returns (string)",
];

const REGISTRY_ABI = [
  "function balanceOf(address owner) view returns (uint256)",
  "function handleOf(address owner) view returns (string)",
];

const $ = (id) => document.getElementById(id);
let provider, signer, account, agentMint;

function setStatus(html) {
  $("status").innerHTML = html;
}

function short(addr) {
  return addr ? addr.slice(0, 6) + "…" + addr.slice(-4) : "—";
}

async function refresh() {
  if (!agentMint || !account) return;
  try {
    const [holds, minted, total, max, remaining] = await Promise.all([
      agentMint.holdsAgentID(account),
      agentMint.hasMinted(account),
      agentMint.totalSupply(),
      agentMint.MAX_SUPPLY(),
      agentMint.remaining(),
    ]);
    const registry = new ethers.Contract(CONFIG.registryAddress, REGISTRY_ABI, provider);
    let handle = "";
    try { handle = await registry.handleOf(account); } catch { handle = ""; }

    $("agentId").innerHTML = holds
      ? `<span class="ok">Yes${handle ? " — " + handle + ".ai" : ""}</span>`
      : `<span class="bad">No Agent ID found</span>`;
    $("minted").innerHTML = minted
      ? `<span class="muted">Yes — one per wallet</span>`
      : `<span class="ok">Not yet</span>`;
    $("supply").textContent = `${total} / ${max} (remaining ${remaining})`;

    const eligible = await agentMint.isEligible(account);
    const btn = $("mintBtn");
    btn.disabled = !eligible;
    btn.textContent = eligible
      ? "Mint my free AgentMint"
      : minted
        ? "Already minted — one per wallet"
        : holds ? "Minting closed (sold out)" : "You need an Agent ID to mint";
  } catch (e) {
    console.error(e);
    setStatus(`<span class="bad">Could not read contract state: ${e.message}</span>`);
  }
}

async function connect() {
  if (!window.ethereum) {
    setStatus(`<span class="bad">No wallet found. Install MetaMask or open this page in a wallet browser.</span>`);
    return;
  }
  try {
    provider = new ethers.BrowserProvider(window.ethereum);
    const network = await provider.getNetwork();
    if (Number(network.chainId) !== CONFIG.chainId) {
      try {
        await window.ethereum.request({
          method: "wallet_switchEthereumChain",
          params: [{ chainId: "0x38" }], // 56
        });
      } catch {
        setStatus(`<span class="bad">Please switch your wallet to BNB Chain (chain 56).</span>`);
        return;
      }
    }
    const accounts = await provider.send("eth_requestAccounts", []);
    account = accounts[0];
    signer = await provider.getSigner();
    $("network").textContent = CONFIG.chainName + " (56)";
    $("account").textContent = short(account);
    $("connectBtn").textContent = "Connected: " + short(account);
    $("connectBtn").disabled = true;
    await refresh();
  } catch (e) {
    console.error(e);
    setStatus(`<span class="bad">Connection failed: ${e.message}</span>`);
  }
}

async function mint() {
  if (!agentMint || !account) return;
  const btn = $("mintBtn");
  btn.disabled = true;
  btn.textContent = "Waiting for wallet…";
  try {
    setStatus("Please confirm the mint in your wallet. Mint is free — you only pay network gas (about 0.00001 BNB).");
    const tx = await agentMint.connect(signer).mint();
    setStatus(`Mint sent: <a href="${CONFIG.bscScan}/tx/${tx.hash}" target="_blank" rel="noopener">${tx.hash}</a><br>Waiting for confirmation…`);
    const receipt = await tx.wait();
    if (receipt.status === 1) {
      setStatus(`<span class="ok">Minted!</span> <a href="${CONFIG.bscScan}/tx/${tx.hash}" target="_blank" rel="noopener">View on BscScan</a>`);
    } else {
      setStatus(`<span class="bad">Transaction failed on-chain.</span>`);
    }
    await refresh();
  } catch (e) {
    console.error(e);
    const msg = (e && e.message) || "Mint failed.";
    setStatus(`<span class="bad">${msg.slice(0, 300)}</span>`);
    btn.disabled = false;
    btn.textContent = "Mint my free AgentMint";
  }
}

window.addEventListener("DOMContentLoaded", () => {
  if (!CONFIG.contractAddress) {
    $("contract").innerHTML = `<span class="muted">Not deployed yet — TBD</span>`;
    $("supply").textContent = "—";
    setStatus(`<span class="muted">The contract is built and tested but not deployed to mainnet yet. Deployment is pending the owner's decision; this page will activate once the contract address is set.</span>`);
    $("mintBtn").disabled = true;
    $("connectBtn").disabled = true;
    return;
  }
  agentMint = null; // created after connect, when a provider exists
  $("contract").innerHTML = `<a href="${CONFIG.bscScan}/address/${CONFIG.contractAddress}" target="_blank" rel="noopener">${short(CONFIG.contractAddress)}</a>`;
  $("connectBtn").addEventListener("click", async () => {
    await connect();
    if (provider) agentMint = new ethers.Contract(CONFIG.contractAddress, AGENT_MINT_ABI, provider);
    await refresh();
  });
  $("mintBtn").addEventListener("click", mint);
  if (window.ethereum) {
    window.ethereum.on("accountsChanged", () => window.location.reload());
    window.ethereum.on("chainChanged", () => window.location.reload());
  }
});
