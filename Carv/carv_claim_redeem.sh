#!/bin/bash

# Файл зі списком гаманців (формат: адреса, приватний ключ)
WALLETS_FILE="wallets.csv"

# Контрактні адреси
CONTRACT_ADDRESS="0x2b790dea1f6c5d72d5c60af0f9cd6834374a964b"
CLAIM_FUNCTION="0xce9650d8"  # multicall
REDEEM_FUNCTION="0x4413a3e70"  # withdraw

# RPC вузол Arbitrum
RPC_URL="https://arb1.arbitrum.io/rpc"

# Встановлення ethers.js, якщо не встановлено
if ! command -v node &> /dev/null || ! npm list -g ethers &> /dev/null; then
    echo "Установка Node.js та ethers.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt install -y nodejs
    npm install -g ethers
fi

# Цикл по всіх гаманцях у файлі
while IFS="," read -r ADDRESS PRIVATE_KEY
  do
    echo "Обробка гаманця: $ADDRESS"
    
    # Генерація та підпис транзакції для CLAIM
    node -e "const ethers = require('ethers');
    const provider = new ethers.JsonRpcProvider('$RPC_URL');
    const wallet = new ethers.Wallet('$PRIVATE_KEY', provider);
    async function claim() {
        const tx = await wallet.sendTransaction({
            to: '$CONTRACT_ADDRESS',
            data: '$CLAIM_FUNCTION',
            gasLimit: 1000000
        });
        console.log('Claim TX:', tx.hash);
    }
    claim();"
    
    sleep 10  # Очікування перед наступною транзакцією
    
    # Генерація та підпис транзакції для REDEEM
    node -e "const ethers = require('ethers');
    const provider = new ethers.JsonRpcProvider('$RPC_URL');
    const wallet = new ethers.Wallet('$PRIVATE_KEY', provider);
    async function redeem() {
        const tx = await wallet.sendTransaction({
            to: '$CONTRACT_ADDRESS',
            data: '$REDEEM_FUNCTION',
            gasLimit: 1000000
        });
        console.log('Redeem TX:', tx.hash);
    }
    redeem();"
    
    sleep 10  # Очікування перед наступним гаманцем
  
done < "$WALLETS_FILE"

echo "Готово!"
