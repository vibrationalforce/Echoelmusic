// NFT Minting Service - Blockchain Integration
import { ethers } from 'ethers';
import { create as ipfsHttpClient } from 'ipfs-http-client';
import { PrismaClient } from '@prisma/client';
import { AppError } from '../middleware/error.middleware';

const prisma = new PrismaClient();

// IPFS Configuration
const ipfs = ipfsHttpClient({
  host: process.env.IPFS_HOST || 'ipfs.infura.io',
  port: 5001,
  protocol: 'https',
  headers: {
    authorization: `Basic ${Buffer.from(
      `${process.env.IPFS_PROJECT_ID}:${process.env.IPFS_PROJECT_SECRET}`
    ).toString('base64')}`
  }
});

// Blockchain Configuration
const NETWORKS = {
  POLYGON: {
    rpcUrl: process.env.POLYGON_RPC_URL || 'https://polygon-rpc.com',
    chainId: 137,
    name: 'Polygon',
    currency: 'MATIC',
    explorer: 'https://polygonscan.com'
  },
  ETHEREUM: {
    rpcUrl: process.env.ETHEREUM_RPC_URL || 'https://mainnet.infura.io/v3/' + process.env.INFURA_KEY,
    chainId: 1,
    name: 'Ethereum',
    currency: 'ETH',
    explorer: 'https://etherscan.io'
  }
};

// ERC-721 NFT Contract ABI (simplified)
const NFT_CONTRACT_ABI = [
  'function mintNFT(address to, string memory tokenURI) public returns (uint256)',
  'function tokenURI(uint256 tokenId) public view returns (string memory)',
  'function ownerOf(uint256 tokenId) public view returns (address)',
  'function transferFrom(address from, address to, uint256 tokenId) public'
];

export interface CreateNFTInput {
  title: string;
  description?: string;
  audioFile: Buffer;
  coverImage?: Buffer;
  price?: number;
  royaltyPercent?: number;
  blockchain?: 'POLYGON' | 'ETHEREUM';
  hrvSnapshot?: string;
  gestureData?: string;
}

export interface MintNFTInput {
  nftId: string;
  walletAddress: string;
}

export class NFTService {
  /**
   * Upload audio and metadata to IPFS
   */
  private async uploadToIPFS(
    audioFile: Buffer,
    coverImage: Buffer | undefined,
    metadata: any
  ): Promise<{ audioUrl: string; coverUrl?: string; metadataUrl: string }> {
    try {
      // Upload audio file
      const audioResult = await ipfs.add(audioFile);
      const audioUrl = `https://ipfs.io/ipfs/${audioResult.path}`;

      // Upload cover image (if provided)
      let coverUrl: string | undefined;
      if (coverImage) {
        const coverResult = await ipfs.add(coverImage);
        coverUrl = `https://ipfs.io/ipfs/${coverResult.path}`;
      }

      // Create NFT metadata (ERC-721 standard)
      const nftMetadata = {
        name: metadata.title,
        description: metadata.description || '',
        image: coverUrl || '',
        audio: audioUrl,
        attributes: [
          { trait_type: 'Platform', value: 'Echoelmusic' },
          { trait_type: 'Bio-Reactive', value: metadata.hrvSnapshot ? 'Yes' : 'No' },
          ...(metadata.tempo ? [{ trait_type: 'Tempo', value: metadata.tempo }] : []),
          ...(metadata.genre ? [{ trait_type: 'Genre', value: metadata.genre }] : [])
        ],
        properties: {
          audioUrl,
          coverUrl,
          creator: metadata.creator,
          createdAt: new Date().toISOString(),
          ...(metadata.hrvSnapshot && { hrvSnapshot: metadata.hrvSnapshot }),
          ...(metadata.gestureData && { gestureData: metadata.gestureData })
        }
      };

      // Upload metadata JSON
      const metadataResult = await ipfs.add(JSON.stringify(nftMetadata));
      const metadataUrl = `https://ipfs.io/ipfs/${metadataResult.path}`;

      return { audioUrl, coverUrl, metadataUrl };
    } catch (error) {
      console.error('IPFS Upload Error:', error);
      throw new AppError('Failed to upload to IPFS', 500);
    }
  }

  /**
   * Create NFT (draft state, not yet minted)
   */
  async createNFT(
    userId: string,
    input: CreateNFTInput
  ): Promise<any> {
    // Get user
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new AppError('User not found', 404);
    }

    // Upload to IPFS
    const { audioUrl, coverUrl, metadataUrl } = await this.uploadToIPFS(
      input.audioFile,
      input.coverImage,
      {
        title: input.title,
        description: input.description,
        creator: user.name || user.email,
        hrvSnapshot: input.hrvSnapshot,
        gestureData: input.gestureData
      }
    );

    // Create NFT record
    const nft = await prisma.nFT.create({
      data: {
        userId,
        title: input.title,
        description: input.description,
        audioUrl,
        coverImageUrl: coverUrl,
        metadata: metadataUrl,
        price: input.price,
        currency: input.blockchain === 'ETHEREUM' ? 'ETH' : 'MATIC',
        royaltyPercent: input.royaltyPercent || 10.0,
        blockchain: input.blockchain || 'POLYGON',
        status: 'DRAFT',
        hrvSnapshot: input.hrvSnapshot,
        gestureData: input.gestureData
      }
    });

    return nft;
  }

  /**
   * Mint NFT to blockchain
   */
  async mintNFT(input: MintNFTInput): Promise<any> {
    const { nftId, walletAddress } = input;

    // Get NFT
    const nft = await prisma.nFT.findUnique({ where: { id: nftId } });
    if (!nft) {
      throw new AppError('NFT not found', 404);
    }

    if (nft.status !== 'DRAFT') {
      throw new AppError('NFT already minted', 400);
    }

    // Update status to minting
    await prisma.nFT.update({
      where: { id: nftId },
      data: { status: 'MINTING' }
    });

    try {
      // Get network config
      const network = NETWORKS[nft.blockchain];
      if (!network) {
        throw new AppError('Invalid blockchain', 400);
      }

      // Connect to blockchain
      const provider = new ethers.JsonRpcProvider(network.rpcUrl);
      const wallet = new ethers.Wallet(process.env.MINTER_PRIVATE_KEY || '', provider);

      // Get NFT contract
      const contractAddress = process.env.NFT_CONTRACT_ADDRESS || '';
      const contract = new ethers.Contract(contractAddress, NFT_CONTRACT_ABI, wallet);

      // Mint NFT
      const tx = await contract.mintNFT(walletAddress, nft.metadata);
      const receipt = await tx.wait();

      // Get token ID from event logs
      const tokenId = receipt.logs[0].topics[3]; // Assuming standard ERC-721 event

      // Update NFT record
      const updatedNFT = await prisma.nFT.update({
        where: { id: nftId },
        data: {
          status: 'MINTED',
          tokenId: tokenId.toString(),
          contractAddress,
          mintedAt: new Date()
        }
      });

      return {
        ...updatedNFT,
        txHash: receipt.hash,
        explorerUrl: `${network.explorer}/tx/${receipt.hash}`
      };
    } catch (error) {
      // Revert status on error
      await prisma.nFT.update({
        where: { id: nftId },
        data: { status: 'DRAFT' }
      });

      console.error('Minting Error:', error);
      throw new AppError('Failed to mint NFT', 500);
    }
  }

  /**
   * List NFT for sale
   */
  async listNFT(nftId: string, price: number): Promise<any> {
    const nft = await prisma.nFT.findUnique({ where: { id: nftId } });
    if (!nft) {
      throw new AppError('NFT not found', 404);
    }

    if (nft.status !== 'MINTED') {
      throw new AppError('NFT must be minted first', 400);
    }

    return prisma.nFT.update({
      where: { id: nftId },
      data: {
        status: 'LISTED',
        price,
        listedAt: new Date()
      }
    });
  }

  /**
   * Get user's NFTs
   */
  async getUserNFTs(userId: string): Promise<any[]> {
    return prisma.nFT.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      include: {
        sales: true
      }
    });
  }

  /**
   * Get marketplace NFTs (listed for sale)
   */
  async getMarketplaceNFTs(
    page: number = 1,
    limit: number = 20,
    blockchain?: string
  ): Promise<{ nfts: any[]; total: number }> {
    const skip = (page - 1) * limit;

    const where: any = {
      status: 'LISTED'
    };

    if (blockchain) {
      where.blockchain = blockchain;
    }

    const [nfts, total] = await Promise.all([
      prisma.nFT.findMany({
        where,
        orderBy: { listedAt: 'desc' },
        skip,
        take: limit,
        include: {
          user: {
            select: {
              id: true,
              name: true,
              username: true,
              avatar: true
            }
          }
        }
      }),
      prisma.nFT.count({ where })
    ]);

    return { nfts, total };
  }

  /**
   * Get NFT by ID
   */
  async getNFTById(nftId: string): Promise<any> {
    const nft = await prisma.nFT.findUnique({
      where: { id: nftId },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            username: true,
            avatar: true,
            walletAddress: true
          }
        },
        sales: {
          orderBy: { createdAt: 'desc' }
        }
      }
    });

    if (!nft) {
      throw new AppError('NFT not found', 404);
    }

    return nft;
  }

  /**
   * Calculate biometric hash (unique signature)
   */
  private calculateBiometricHash(hrvSnapshot?: string, gestureData?: string): string {
    if (!hrvSnapshot && !gestureData) return '';

    const data = JSON.stringify({ hrvSnapshot, gestureData });
    return ethers.keccak256(ethers.toUtf8Bytes(data));
  }
}

export default new NFTService();
