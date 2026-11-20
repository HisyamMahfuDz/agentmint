// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @title AgentMint — free NFT mint for Agent ID holders on BNB Chain
/// @author AgentMint (Binance Agent ID Hackathon entry)
/// @notice A free, open-source ERC-721 where every Agent ID holder can mint
///         exactly one NFT. No payment, no allowlist, no fees, no withdraw:
///         the contract never holds funds. The only owner power is changing
///         the (optional) off-chain base URI for metadata; by default all
///         metadata is generated fully on-chain (data-URI JSON + inline SVG),
///         so the collection has no hosting dependency.
/// @dev Gating is verified against the official Agent ID registry
///      (SPACE ID Agent ID, ERC-721) at
///      0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F on BNB Chain (56).
///      A caller holds an Agent ID iff `registry.balanceOf(caller) > 0`.
///      Verified live 20 Nov 2026: name() = "SPACE ID Agent ID",
///      symbol() = "AI", balanceOf(0x65f51A97152BAe3D3F17321992003521BAB562eC)
///      (hisyam.ai) = 1, handleOf(hisyam.ai) = "hisyam".
interface IAgentIDRegistry {
    /// @notice Number of Agent ID tokens owned by `owner`.
    function balanceOf(address owner) external view returns (uint256);

    /// @notice The Agent ID handle (without the ".ai" suffix) of `owner`,
    ///         or an empty string if the address holds no Agent ID.
    function handleOf(address owner) external view returns (string memory);
}

/// @title AgentMint
/// @notice Free, one-per-wallet, Agent ID-gated ERC-721 mint on BNB Chain.
contract AgentMint is ERC721, Ownable {
    using Strings for uint256;

    /// @notice The Agent ID registry used for the eligibility check.
    IAgentIDRegistry public immutable agentIDRegistry;

    /// @notice Maximum number of AgentMint NFTs that can ever exist.
    uint256 public immutable MAX_SUPPLY;

    /// @notice Next token ID to mint. Token IDs start at 1.
    uint256 public nextTokenId = 1;

    /// @notice True once an address has minted its one free AgentMint.
    mapping(address => bool) public hasMinted;

    /// @notice Optional off-chain metadata base URI. Empty by default, which
    ///         means tokenURI is generated fully on-chain. The owner may set
    ///         it later (metadata only); it never affects minting, ownership
    ///         or funds, because the contract holds none.
    string public baseURI;

    /// @notice Emitted when an Agent ID holder mints.
    event Minted(address indexed minter, uint256 indexed tokenId);

    /// @notice Emitted when the owner changes the base URI.
    event BaseURIUpdated(string newBaseURI);

    /// @notice Caller does not hold an Agent ID.
    error NotAgentIDHolder();

    /// @notice Caller already minted its one free AgentMint.
    error AlreadyMinted();

    /// @notice The 10,000 supply cap has been reached.
    error SoldOut();

    /// @param agentIDRegistry_ Address of the Agent ID registry contract.
    ///        Mainnet (BSC 56): 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F.
    /// @param maxSupply_ Supply cap for this deployment (10,000 on mainnet).
    /// @param initialOwner_ Owner of the contract (metadata admin only).
    constructor(address agentIDRegistry_, uint256 maxSupply_, address initialOwner_)
        ERC721("AgentMint", "AGM")
        Ownable(initialOwner_)
    {
        require(agentIDRegistry_ != address(0), "AgentMint: zero registry");
        require(maxSupply_ > 0, "AgentMint: zero supply");
        agentIDRegistry = IAgentIDRegistry(agentIDRegistry_);
        MAX_SUPPLY = maxSupply_;
    }

    /// @notice Mint one free AgentMint. The caller must hold an Agent ID and
    ///         must not have minted before. Sending BNB reverts: the function
    ///         is non-payable, so any attached value is rejected by the EVM.
    /// @dev Emits {Minted} and the standard ERC-721 {Transfer} event.
    function mint() external {
        if (nextTokenId > MAX_SUPPLY) revert SoldOut();
        if (hasMinted[msg.sender]) revert AlreadyMinted();
        if (!_holdsAgentID(msg.sender)) revert NotAgentIDHolder();

        uint256 tokenId = nextTokenId;
        unchecked {
            ++nextTokenId;
        }
        hasMinted[msg.sender] = true;
        emit Minted(msg.sender, tokenId);
        _safeMint(msg.sender, tokenId);
    }

    /// @notice Change the off-chain metadata base URI. Metadata only: it does
    ///         not affect minting, ownership, or funds. Set to "" to go back
    ///         to fully on-chain metadata.
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    /// @notice Whether `account` holds at least one Agent ID token.
    function holdsAgentID(address account) external view returns (bool) {
        return _holdsAgentID(account);
    }

    /// @notice Whether `account` can mint right now: holds an Agent ID, has
    ///         not minted before, and supply is still available.
    function isEligible(address account) external view returns (bool) {
        if (nextTokenId > MAX_SUPPLY) return false;
        if (hasMinted[account]) return false;
        return _holdsAgentID(account);
    }

    /// @notice Number of AgentMint NFTs minted so far.
    function totalSupply() external view returns (uint256) {
        return nextTokenId - 1;
    }

    /// @notice Number of mints still available.
    function remaining() external view returns (uint256) {
        if (nextTokenId > MAX_SUPPLY) return 0;
        return MAX_SUPPLY - (nextTokenId - 1);
    }

    /// @notice Metadata for `tokenId`. By default a self-contained data URI:
    ///         JSON with an inline SVG badge showing the token number and the
    ///         owner's Agent ID handle. If the owner set a base URI, returns
    ///         baseURI + tokenId instead (metadata only).
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        address owner = _ownerOf(tokenId);
        require(owner != address(0), "AgentMint: nonexistent token");

        if (bytes(baseURI).length > 0) {
            return string.concat(baseURI, tokenId.toString());
        }

        string memory handle = agentIDRegistry.handleOf(owner);
        string memory displayHandle =
            bytes(handle).length > 0 ? string.concat(handle, ".ai") : "unknown";

        string memory svg = _buildSVG(tokenId, displayHandle);

        string memory json = string.concat(
            '{"name":"AgentMint #',
            tokenId.toString(),
            '","description":"Free mint for Agent ID holders on BNB Chain. One per Agent ID holder, no fees, no payment. Minted by ',
            displayHandle,
            '.","image":"data:image/svg+xml;base64,',
            Base64.encode(bytes(svg)),
            '","attributes":[{"trait_type":"Agent ID","value":"',
            displayHandle,
            '"},{"trait_type":"Mint","value":"Free"}]}'
        );

        return string.concat("data:application/json;base64,", Base64.encode(bytes(json)));
    }

    /// @dev Builds the inline SVG badge for a token.
    function _buildSVG(uint256 tokenId, string memory displayHandle) internal pure returns (string memory) {
        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="640" height="640" viewBox="0 0 640 640">',
            '<rect width="640" height="640" fill="#0B0E11"/>',
            '<rect x="24" y="24" width="592" height="592" rx="32" fill="none" stroke="#F0B90B" stroke-width="4"/>',
            '<text x="320" y="120" font-family="monospace" font-size="44" font-weight="bold" fill="#F0B90B" text-anchor="middle">AGENTMINT</text>',
            '<text x="320" y="300" font-family="monospace" font-size="96" font-weight="bold" fill="#FFFFFF" text-anchor="middle">#',
            tokenId.toString(),
            "</text>",
            '<text x="320" y="400" font-family="monospace" font-size="36" fill="#F0B90B" text-anchor="middle">',
            displayHandle,
            "</text>",
            '<text x="320" y="520" font-family="monospace" font-size="24" fill="#8A8F98" text-anchor="middle">Free mint for Agent ID holders</text>',
            "</svg>"
        );
    }

    /// @dev Canonical Agent ID check, verified against the live registry:
    ///      the registry is an ERC-721, so holding an Agent ID means a
    ///      nonzero balance. The zero address is never a holder (the
    ///      registry reverts on balanceOf(0), so guard it here).
    function _holdsAgentID(address account) internal view returns (bool) {
        if (account == address(0)) return false;
        return agentIDRegistry.balanceOf(account) > 0;
    }
}
