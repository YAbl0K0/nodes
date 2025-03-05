#!/bin/bash

# Файл зі списком гаманців (формат: адреса, приватний ключ)
WALLETS_FILE="wallets.csv"

# Контрактні адреси
CONTRACT_ADDRESS="0x2b790dea1f6c5d72d5c60af0f9cd6834374a964b"

# RPC вузол Arbitrum
RPC_URL="https://arb-mainnet.g.alchemy.com/v2/CZp2sOzdTa1SZukXkVGpP0kpsyhJL5nL"

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
            data: '0xce9650d8',
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
    const contractAddress = '$CONTRACT_ADDRESS';
    const contractABI = ['function withdraw(uint256 amount, uint256 duration) external'];
    const contract = new ethers.Contract(contractAddress, contractABI, wallet);
    const amount = ethers.parseUnits('1', 18); // Сума для виводу
    const duration = 604800; // 7 днів у секундах
    async function redeem() {
        try {
            const tx = await contract.withdraw(amount, duration);
            console.log('Redeem TX:', tx.hash);
        } catch (error) {
            console.error('Помилка у транзакції:', error);
        }
    }
redeem();"
    
    sleep 10  # Очікування перед наступним гаманцем
  
done < "$WALLETS_FILE"

echo "Готово!"
