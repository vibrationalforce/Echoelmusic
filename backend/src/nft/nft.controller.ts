// NFT Controller
import { Response } from 'express';
import { asyncHandler } from '../middleware/error.middleware';
import { AuthRequest } from '../middleware/auth.middleware';
import nftService from './nft.service';
import multer from 'multer';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 100 * 1024 * 1024 } // 100MB
});

export class NFTController {
  /**
   * Create NFT (draft)
   */
  createNFT = [
    upload.fields([
      { name: 'audioFile', maxCount: 1 },
      { name: 'coverImage', maxCount: 1 }
    ]),
    asyncHandler(async (req: AuthRequest, res: Response) => {
      if (!req.userId) {
        return res.status(401).json({ error: 'Unauthorized' });
      }

      const files = req.files as { [fieldname: string]: Express.Multer.File[] };
      const { title, description, price, royaltyPercent, blockchain, hrvSnapshot, gestureData } =
        req.body;

      if (!files.audioFile || files.audioFile.length === 0) {
        return res.status(400).json({ error: 'Audio file is required' });
      }

      const nft = await nftService.createNFT(req.userId, {
        title,
        description,
        audioFile: files.audioFile[0].buffer,
        coverImage: files.coverImage?.[0]?.buffer,
        price: price ? parseFloat(price) : undefined,
        royaltyPercent: royaltyPercent ? parseFloat(royaltyPercent) : undefined,
        blockchain,
        hrvSnapshot,
        gestureData
      });

      res.status(201).json({
        success: true,
        message: 'NFT created successfully',
        data: nft
      });
    })
  ];

  /**
   * Mint NFT to blockchain
   */
  mintNFT = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { nftId, walletAddress } = req.body;

    if (!nftId || !walletAddress) {
      return res.status(400).json({ error: 'nftId and walletAddress are required' });
    }

    const result = await nftService.mintNFT({ nftId, walletAddress });

    res.json({
      success: true,
      message: 'NFT minted successfully',
      data: result
    });
  });

  /**
   * List NFT for sale
   */
  listNFT = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { nftId, price } = req.body;

    if (!nftId || !price) {
      return res.status(400).json({ error: 'nftId and price are required' });
    }

    const nft = await nftService.listNFT(nftId, parseFloat(price));

    res.json({
      success: true,
      message: 'NFT listed for sale',
      data: nft
    });
  });

  /**
   * Get user's NFTs
   */
  getUserNFTs = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const nfts = await nftService.getUserNFTs(req.userId);

    res.json({
      success: true,
      data: nfts
    });
  });

  /**
   * Get marketplace NFTs
   */
  getMarketplace = asyncHandler(async (req: AuthRequest, res: Response) => {
    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 20;
    const blockchain = req.query.blockchain as string;

    const result = await nftService.getMarketplaceNFTs(page, limit, blockchain);

    res.json({
      success: true,
      data: result.nfts,
      pagination: {
        page,
        limit,
        total: result.total,
        totalPages: Math.ceil(result.total / limit)
      }
    });
  });

  /**
   * Get NFT by ID
   */
  getNFTById = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { id } = req.params;

    const nft = await nftService.getNFTById(id);

    res.json({
      success: true,
      data: nft
    });
  });
}

export default new NFTController();
