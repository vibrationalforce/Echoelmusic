# Hardhat Development Environment

FROM node:18-alpine

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm install

# Copy contract files
COPY . .

# Compile contracts
RUN npx hardhat compile

EXPOSE 8545

CMD ["npx", "hardhat", "node"]
