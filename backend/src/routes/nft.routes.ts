/**
 * NFT routes - Biometric moment NFTs
 */

import { Router } from 'express';
const router = Router();

// TODO: Implement NFT routes
// POST /api/v1/nft/mint - Mint new NFT
// GET /api/v1/nft/:tokenId - Get NFT details
// GET /api/v1/nft/user/:userId - Get user's NFTs
// POST /api/v1/nft/:tokenId/transfer - Transfer NFT

router.post('/mint', (req, res) => {
  res.status(501).json({ message: 'NFT routes not implemented yet' });
});

export default router;
