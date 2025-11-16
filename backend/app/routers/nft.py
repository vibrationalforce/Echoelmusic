"""NFT minting for biometric peak moments"""

from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from web3 import Web3
from datetime import datetime
import json
import uuid

from ..database import get_db
from ..config import settings
from .. import models, schemas

router = APIRouter()

# Web3 setup
w3 = Web3(Web3.HTTPProvider(settings.WEB3_PROVIDER_URL))


@router.post("/mint", response_model=schemas.NFTMintResponse)
async def mint_nft(
    request: schemas.NFTMintRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db)
):
    """
    Mint NFT for biometric peak moment

    Only mints if emotion_peak >= 0.95 (95% threshold)
    Creates unique NFT with:
    - Biometric data at peak
    - Timestamp in session
    - Audio/video snapshot
    - Metadata on IPFS
    - Minted on Polygon (low gas fees)
    """

    # Validate emotion peak threshold
    if request.emotion_peak < 0.95:
        raise HTTPException(
            status_code=400,
            detail=f"Emotion peak {request.emotion_peak:.2%} is below 95% threshold for NFT minting"
        )

    # Get session
    stmt = select(models.Session).where(models.Session.session_id == request.session_id)
    result = await db.execute(stmt)
    session = result.scalar_one_or_none()

    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    # Get biometric data at timestamp
    biometric_data = session.biometric_data or {}

    # Create metadata
    metadata = {
        "name": f"Echoelmusic Peak #{request.session_id[:8]}",
        "description": f"Biometric peak moment captured at {request.emotion_peak:.2%} emotion intensity",
        "image": f"ipfs://Qm...{request.session_id}",  # TODO: Upload image to IPFS
        "animation_url": session.video_url,
        "attributes": [
            {"trait_type": "Emotion Peak", "value": f"{request.emotion_peak:.2%}"},
            {"trait_type": "Timestamp", "value": request.timestamp},
            {"trait_type": "Session ID", "value": request.session_id},
            {"trait_type": "Heart Rate", "value": biometric_data.get("heart_rate", 0)},
            {"trait_type": "HRV Coherence", "value": biometric_data.get("hrv_coherence", 0)},
        ],
        "properties": {
            "session_id": request.session_id,
            "timestamp": request.timestamp,
            "emotion_peak": request.emotion_peak,
            "biometrics": biometric_data
        }
    }

    # Upload metadata to IPFS
    ipfs_hash = await upload_to_ipfs(metadata)

    # Mint NFT on blockchain (simplified)
    token_id = await mint_on_blockchain(
        session_id=request.session_id,
        metadata_uri=f"ipfs://{ipfs_hash}",
        timestamp=int(request.timestamp),
        emotion_peak=int(request.emotion_peak * 100)
    )

    # Create NFT record
    nft = models.NFT(
        user_id=session.user_id,
        session_id=session.id,
        token_id=token_id,
        contract_address=settings.NFT_CONTRACT_ADDRESS,
        chain="polygon",
        name=metadata["name"],
        description=metadata["description"],
        metadata_uri=f"ipfs://{ipfs_hash}",
        timestamp=request.timestamp,
        emotion_peak=request.emotion_peak,
        heart_rate=biometric_data.get("heart_rate"),
        hrv_coherence=biometric_data.get("hrv_coherence"),
        tx_hash="0x...",  # TODO: Get real tx hash
        minted_at=datetime.utcnow(),
        opensea_url=f"https://opensea.io/assets/matic/{settings.NFT_CONTRACT_ADDRESS}/{token_id}"
    )

    db.add(nft)
    await db.commit()
    await db.refresh(nft)

    return schemas.NFTMintResponse(
        nft_id=nft.id,
        token_id=token_id,
        tx_hash=nft.tx_hash,
        ipfs_hash=ipfs_hash,
        opensea_url=nft.opensea_url,
        contract_address=settings.NFT_CONTRACT_ADDRESS,
        metadata=metadata
    )


async def upload_to_ipfs(metadata: dict) -> str:
    """Upload metadata to IPFS (simplified)"""
    # TODO: Implement actual IPFS upload
    # import ipfshttpclient
    # client = ipfshttpclient.connect()
    # result = client.add_json(metadata)
    # return result

    return f"Qm{uuid.uuid4().hex[:44]}"  # Placeholder


async def mint_on_blockchain(session_id: str, metadata_uri: str, timestamp: int, emotion_peak: int) -> int:
    """Mint NFT on Polygon blockchain (simplified)"""
    # TODO: Implement actual smart contract interaction
    # contract = w3.eth.contract(address=settings.NFT_CONTRACT_ADDRESS, abi=NFT_ABI)
    # tx = contract.functions.mintBiometricMoment(
    #     session_id,
    #     metadata_uri,
    #     timestamp,
    #     emotion_peak
    # ).transact()
    # receipt = w3.eth.wait_for_transaction_receipt(tx)
    # token_id = contract.functions.tokenOfOwnerByIndex(owner, 0).call()

    return int(datetime.utcnow().timestamp())  # Placeholder token ID


@router.get("/user/{user_id}", response_model=list[schemas.NFTResponse])
async def get_user_nfts(
    user_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Get all NFTs for a user"""
    stmt = select(models.NFT)\
        .where(models.NFT.user_id == user_id)\
        .order_by(models.NFT.created_at.desc())

    result = await db.execute(stmt)
    nfts = result.scalars().all()

    return nfts


@router.get("/session/{session_id}", response_model=list[schemas.NFTResponse])
async def get_session_nfts(
    session_id: str,
    db: AsyncSession = Depends(get_db)
):
    """Get all NFTs from a specific session"""
    stmt = select(models.Session).where(models.Session.session_id == session_id)
    result = await db.execute(stmt)
    session = result.scalar_one_or_none()

    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    stmt = select(models.NFT)\
        .where(models.NFT.session_id == session.id)\
        .order_by(models.NFT.created_at.desc())

    result = await db.execute(stmt)
    nfts = result.scalars().all()

    return nfts
