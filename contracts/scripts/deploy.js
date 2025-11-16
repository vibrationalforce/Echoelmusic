/**
 * Deployment script for Echoelmusic Biometric NFT contract
 *
 * Usage:
 * - Test: npx hardhat run scripts/deploy.js --network localhost
 * - Mumbai: npx hardhat run scripts/deploy.js --network mumbai
 * - Polygon: npx hardhat run scripts/deploy.js --network polygon
 */

const hre = require("hardhat");

async function main() {
  console.log("🚀 Starting Echoelmusic NFT deployment...\n");

  // Get deployer account
  const [deployer] = await hre.ethers.getSigners();
  console.log("📝 Deploying contracts with account:", deployer.address);

  // Check balance
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", hre.ethers.formatEther(balance), "MATIC\n");

  // Warn if balance is low
  if (balance < hre.ethers.parseEther("0.1")) {
    console.warn("⚠️  WARNING: Low balance! You may need more MATIC for deployment and testing.\n");
  }

  // Deploy contract
  console.log("📦 Deploying EchoelmusicBiometricNFT...");
  const EchoelmusicNFT = await hre.ethers.getContractFactory("EchoelmusicBiometricNFT");
  const nft = await EchoelmusicNFT.deploy();

  await nft.waitForDeployment();
  const nftAddress = await nft.getAddress();

  console.log("✅ EchoelmusicBiometricNFT deployed to:", nftAddress);
  console.log("\n📋 Contract Details:");
  console.log("   Name:", await nft.name());
  console.log("   Symbol:", await nft.symbol());
  console.log("   Mint Price:", hre.ethers.formatEther(await nft.mintPrice()), "MATIC");
  console.log("   Owner:", await nft.owner());

  // Save deployment info
  const deploymentInfo = {
    network: hre.network.name,
    contractAddress: nftAddress,
    deployer: deployer.address,
    deployedAt: new Date().toISOString(),
    blockNumber: await hre.ethers.provider.getBlockNumber(),
  };

  console.log("\n🎉 Deployment Complete!");
  console.log("\n📝 IMPORTANT: Save this information to your .env file:");
  console.log("───────────────────────────────────────────────────────");
  console.log(`NFT_CONTRACT_ADDRESS=${nftAddress}`);
  console.log(`CONTRACT_OWNER_ADDRESS=${deployer.address}`);
  console.log("───────────────────────────────────────────────────────\n");

  // Instructions for verification
  if (hre.network.name !== "localhost" && hre.network.name !== "hardhat") {
    console.log("🔍 To verify on Polygonscan, run:");
    console.log(`   npx hardhat verify --network ${hre.network.name} ${nftAddress}\n`);
  }

  // Save to file
  const fs = require("fs");
  const path = require("path");
  const deploymentPath = path.join(__dirname, "../deployments", `${hre.network.name}.json`);

  // Create deployments directory if it doesn't exist
  const deploymentsDir = path.join(__dirname, "../deployments");
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir);
  }

  fs.writeFileSync(deploymentPath, JSON.stringify(deploymentInfo, null, 2));
  console.log("💾 Deployment info saved to:", deploymentPath);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });
