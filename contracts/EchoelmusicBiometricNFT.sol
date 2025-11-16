// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title EchoelmusicBiometricNFT
 * @dev NFT contract for minting biometric peak moments from Echoelmusic sessions
 *
 * Features:
 * - Mint NFTs for high emotional peaks (>= 95%)
 * - Store biometric data on-chain
 * - 10% royalties to original creator
 * - Emergency pause functionality
 * - IPFS metadata storage
 */
contract EchoelmusicBiometricNFT is
    ERC721,
    ERC721URIStorage,
    ERC721Royalty,
    ReentrancyGuard,
    Ownable,
    Pausable
{
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // Minting price in MATIC (adjustable by owner)
    uint256 public mintPrice = 0.01 ether;

    // Royalty percentage (basis points, e.g., 1000 = 10%)
    uint96 public constant ROYALTY_BASIS_POINTS = 1000; // 10%

    // Minimum emotion peak required to mint (0-100 scale)
    uint256 public constant MIN_EMOTION_PEAK = 95;

    // Biometric moment data structure
    struct BiometricMoment {
        string sessionId;        // Unique session identifier
        uint256 timestamp;       // Block timestamp of mint
        uint256 heartRate;       // Heart rate at peak (BPM)
        uint256 hrvCoherence;    // HRV coherence score (0-10 scale)
        uint256 emotionPeak;     // Emotion peak intensity (0-100 scale)
        address creator;         // Original creator address
        uint256 royaltiesEarned; // Total royalties earned (in wei)
        string metadataURI;      // IPFS URI for metadata
    }

    // Mapping from token ID to biometric data
    mapping(uint256 => BiometricMoment) public moments;

    // Mapping from user address to their token IDs
    mapping(address => uint256[]) public userMoments;

    // Mapping from session ID to token ID (prevent duplicate mints)
    mapping(string => uint256) public sessionToToken;

    // Events
    event MomentMinted(
        uint256 indexed tokenId,
        address indexed creator,
        uint256 emotionPeak,
        string sessionId,
        string metadataURI
    );

    event MintPriceUpdated(uint256 oldPrice, uint256 newPrice);

    event RoyaltyPaid(
        uint256 indexed tokenId,
        address indexed creator,
        uint256 amount
    );

    constructor() ERC721("Echoelmusic Biometric Moments", "ECHO") {}

    /**
     * @dev Mint a new biometric moment NFT
     * @param sessionId Unique session identifier
     * @param tokenURI IPFS URI for token metadata
     * @param heartRate Heart rate at peak moment (BPM)
     * @param hrvCoherence HRV coherence score (0-10)
     * @param emotionPeak Emotion peak intensity (0-100)
     */
    function mintBiometricMoment(
        string memory sessionId,
        string memory tokenURI,
        uint256 heartRate,
        uint256 hrvCoherence,
        uint256 emotionPeak
    ) public payable nonReentrant whenNotPaused returns (uint256) {
        require(msg.value >= mintPrice, "Insufficient payment");
        require(emotionPeak >= MIN_EMOTION_PEAK, "Emotion peak below minimum threshold");
        require(emotionPeak <= 100, "Invalid emotion peak value");
        require(hrvCoherence <= 10, "Invalid HRV coherence value");
        require(bytes(sessionId).length > 0, "Session ID cannot be empty");
        require(sessionToToken[sessionId] == 0, "Moment already minted for this session");

        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        // Mint NFT to sender
        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);

        // Set royalty for this token (10% to creator)
        _setTokenRoyalty(newTokenId, msg.sender, ROYALTY_BASIS_POINTS);

        // Store biometric data
        moments[newTokenId] = BiometricMoment({
            sessionId: sessionId,
            timestamp: block.timestamp,
            heartRate: heartRate,
            hrvCoherence: hrvCoherence,
            emotionPeak: emotionPeak,
            creator: msg.sender,
            royaltiesEarned: 0,
            metadataURI: tokenURI
        });

        // Track user's moments
        userMoments[msg.sender].push(newTokenId);

        // Mark session as minted
        sessionToToken[sessionId] = newTokenId;

        emit MomentMinted(newTokenId, msg.sender, emotionPeak, sessionId, tokenURI);

        return newTokenId;
    }

    /**
     * @dev Get all token IDs owned by a user
     */
    function getUserMoments(address user) external view returns (uint256[] memory) {
        return userMoments[user];
    }

    /**
     * @dev Get biometric data for a token
     */
    function getMomentData(uint256 tokenId) external view returns (BiometricMoment memory) {
        require(_exists(tokenId), "Token does not exist");
        return moments[tokenId];
    }

    /**
     * @dev Get token ID for a session (returns 0 if not minted)
     */
    function getTokenBySession(string memory sessionId) external view returns (uint256) {
        return sessionToToken[sessionId];
    }

    /**
     * @dev Get total supply of NFTs
     */
    function totalSupply() external view returns (uint256) {
        return _tokenIds.current();
    }

    /**
     * @dev Update mint price (owner only)
     */
    function setMintPrice(uint256 newPrice) external onlyOwner {
        uint256 oldPrice = mintPrice;
        mintPrice = newPrice;
        emit MintPriceUpdated(oldPrice, newPrice);
    }

    /**
     * @dev Withdraw contract balance (owner only)
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(owner()).transfer(balance);
    }

    /**
     * @dev Pause contract (owner only)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause contract (owner only)
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // Required overrides for multiple inheritance

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage, ERC721Royalty) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage, ERC721Royalty)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
