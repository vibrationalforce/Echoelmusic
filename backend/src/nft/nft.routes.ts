// NFT Routes
import { Router } from 'express';
import nftController from './nft.controller';
import { authenticateToken } from '../middleware/auth.middleware';

const router = Router();

/**
 * @route   POST /api/nft/create
 * @desc    Create NFT (upload to IPFS, draft state)
 * @access  Private
 */
router.post('/create', authenticateToken, nftController.createNFT);

/**
 * @route   POST /api/nft/mint
 * @desc    Mint NFT to blockchain
 * @access  Private
 */
router.post('/mint', authenticateToken, nftController.mintNFT);

/**
 * @route   POST /api/nft/list
 * @desc    List NFT for sale
 * @access  Private
 */
router.post('/list', authenticateToken, nftController.listNFT);

/**
 * @route   GET /api/nft/my-nfts
 * @desc    Get user's NFTs
 * @access  Private
 */
router.get('/my-nfts', authenticateToken, nftController.getUserNFTs);

/**
 * @route   GET /api/nft/marketplace
 * @desc    Get marketplace NFTs (listed for sale)
 * @access  Public
 */
router.get('/marketplace', nftController.getMarketplace);

/**
 * @route   GET /api/nft/:id
 * @desc    Get NFT by ID
 * @access  Public
 */
router.get('/:id', nftController.getNFTById);

export default router;
