# 🚀 ECHOELMUSIC DEPLOYMENT QUICKSTART

**Quick guide to get the Echoelmusic platform running locally**

---

## 📋 Prerequisites

Before you begin, ensure you have:

- ✅ **Docker** & **Docker Compose** installed
- ✅ **Node.js 18+** and **npm 9+** installed
- ✅ **Git** installed

**Check your versions:**
```bash
docker --version
docker-compose --version
node --version
npm --version
```

---

## ⚡ Quick Start (5 minutes)

### 1. Run the Setup Script

```bash
# Make the script executable (if not already)
chmod +x infrastructure/scripts/setup-dev.sh

# Run setup
./infrastructure/scripts/setup-dev.sh
```

This script will:
- ✅ Create `.env` file from template
- ✅ Install all dependencies (backend + contracts)
- ✅ Start Docker containers (PostgreSQL, Redis, IPFS, Hardhat)
- ✅ Set up development environment

### 2. Configure Environment Variables

```bash
# Edit the .env file with your API keys
nano .env  # or use your favorite editor
```

**For local development, you can skip most API keys.** The minimum required:
```env
NODE_ENV=development
JWT_SECRET=your_random_64_byte_hex_string
ENCRYPTION_KEY=your_random_32_byte_hex_string
```

**Generate secrets:**
```bash
# JWT Secret (64 bytes)
openssl rand -hex 64

# Encryption Key (32 bytes)
openssl rand -hex 32
```

### 3. Run Database Migrations

```bash
cd backend
npm run migrate
```

### 4. Deploy Smart Contracts (Local)

```bash
cd contracts
npm run deploy:localhost
```

**Copy the contract address** from the output and add it to `.env`:
```env
NFT_CONTRACT_ADDRESS=0x...  # Address from deployment
```

### 5. Start Backend Server

```bash
cd backend
npm run dev
```

### 6. Test the API

```bash
# Health check
curl http://localhost:3000/api/v1/health

# Expected response:
# {"status":"healthy","timestamp":"2025-11-16T...","uptime":1.234,"environment":"development"}
```

---

## 🎯 What's Running?

After setup, you'll have these services:

| Service | URL | Credentials |
|---------|-----|-------------|
| **Backend API** | http://localhost:3000 | N/A |
| **PostgreSQL** | localhost:5432 | `echoelmusic` / `echoelmusic_dev_password` |
| **Redis** | localhost:6379 | Password: `echoelmusic_redis_password` |
| **IPFS API** | http://localhost:5001 | N/A |
| **IPFS Gateway** | http://localhost:8080 | N/A |
| **Hardhat Node** | http://localhost:8545 | N/A (local blockchain) |
| **pgAdmin** | http://localhost:5050 | `admin@echoelmusic.com` / `admin` |

---

## 📁 Project Structure

```
Echoelmusic/
├── backend/              # Node.js/TypeScript API
│   ├── src/
│   │   ├── routes/      # API endpoints
│   │   ├── controllers/ # Business logic
│   │   ├── models/      # Database models
│   │   ├── services/    # External services
│   │   └── utils/       # Utilities
│   ├── package.json
│   └── Dockerfile
│
├── contracts/            # Solidity smart contracts
│   ├── EchoelmusicBiometricNFT.sol
│   ├── scripts/deploy.js
│   ├── package.json
│   └── hardhat.config.js
│
├── infrastructure/
│   ├── docker/
│   │   └── docker-compose.yml
│   └── scripts/
│       └── setup-dev.sh
│
├── .env.template         # Environment template
└── PRODUCTION_DEPLOYMENT_ROADMAP.md
```

---

## 🔧 Development Commands

### Backend

```bash
cd backend

# Development mode (hot reload)
npm run dev

# Build for production
npm run build

# Run tests
npm test

# Run linter
npm run lint

# Database migrations
npm run migrate          # Run migrations
npm run migrate:rollback # Rollback last migration
npm run migrate:make create_users_table  # Create new migration
```

### Smart Contracts

```bash
cd contracts

# Compile contracts
npm run compile

# Run tests
npm test

# Deploy to local Hardhat network
npm run deploy:localhost

# Deploy to Polygon Mumbai (testnet)
npm run deploy:mumbai

# Deploy to Polygon Mainnet (production)
npm run deploy:polygon

# Verify contract on Polygonscan
npm run verify:polygon <CONTRACT_ADDRESS>
```

### Docker

```bash
cd infrastructure/docker

# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# View logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f backend

# Restart a service
docker-compose restart backend

# Remove all containers and volumes
docker-compose down -v
```

---

## 🧪 Testing the NFT Minting Flow

### 1. Get Local Testnet Accounts

When you start Hardhat node, it gives you 20 accounts with 10,000 ETH each:

```bash
# In contracts directory
npx hardhat node
```

Copy one of the private keys and addresses for testing.

### 2. Deploy Contract

```bash
npm run deploy:localhost
```

### 3. Mint a Test NFT

Create a test script `contracts/scripts/mint-test.js`:

```javascript
const hre = require("hardhat");

async function main() {
  const contractAddress = "YOUR_DEPLOYED_CONTRACT_ADDRESS";
  const nft = await hre.ethers.getContractAt("EchoelmusicBiometricNFT", contractAddress);

  const tx = await nft.mintBiometricMoment(
    "test-session-123",
    "ipfs://QmTest...",
    72,   // heartRate
    8,    // hrvCoherence
    97    // emotionPeak
  );

  await tx.wait();
  console.log("NFT minted! Transaction:", tx.hash);
}

main();
```

---

## 🐛 Troubleshooting

### Docker containers won't start

```bash
# Check if ports are already in use
lsof -i :5432  # PostgreSQL
lsof -i :6379  # Redis
lsof -i :3000  # Backend

# Stop conflicting services or change ports in docker-compose.yml
```

### "Cannot connect to database"

```bash
# Check PostgreSQL is running
docker-compose ps postgres

# View PostgreSQL logs
docker-compose logs postgres

# Restart PostgreSQL
docker-compose restart postgres
```

### "Contract deployment failed"

```bash
# Make sure Hardhat node is running
docker-compose ps hardhat

# Check you have the right network in hardhat.config.js
# For local: localhost
# For testnet: mumbai
# For mainnet: polygon
```

### "npm install fails"

```bash
# Clear npm cache
npm cache clean --force

# Remove node_modules and reinstall
rm -rf node_modules package-lock.json
npm install
```

---

## 🔐 Security Checklist (Before Production)

- [ ] Change all default passwords in `.env`
- [ ] Generate strong JWT and encryption secrets
- [ ] Never commit `.env` to version control
- [ ] Use environment variables for all secrets
- [ ] Enable HTTPS/SSL for all endpoints
- [ ] Set up proper firewall rules
- [ ] Use AWS Secrets Manager or similar for production
- [ ] Enable 2FA for all admin accounts
- [ ] Set up monitoring and alerting
- [ ] Perform security audit before mainnet deployment

---

## 📚 Next Steps

1. **Read the full roadmap:** `PRODUCTION_DEPLOYMENT_ROADMAP.md`
2. **Implement authentication:** Start with `backend/src/routes/auth.routes.ts`
3. **Add database models:** Create user, session, and NFT models
4. **Integrate Stripe:** For payment processing
5. **Set up IPFS:** Upload NFT metadata
6. **Test thoroughly:** Write integration tests

---

## 🆘 Getting Help

- **Documentation:** Check all `.md` files in the project
- **Logs:** Always check Docker logs first: `docker-compose logs -f`
- **Issues:** Create detailed bug reports with logs and steps to reproduce

---

## 🎉 You're Ready!

You now have a fully functional development environment for Echoelmusic. Start building! 🚀

**Happy coding!** 🎵🧬
