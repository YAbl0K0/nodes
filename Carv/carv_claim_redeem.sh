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
node -e 'const ethers = require("ethers");
const provider = new ethers.JsonRpcProvider("'$RPC_URL'");
const wallet = new ethers.Wallet("'$PRIVATE_KEY'", provider);
const contractAddress = "0x40377e5ba6..."; // Той контракт, що був у попередніх викликах

const contractABI = [
    "function multicall(bytes[] calldata data) external",
    "function <РОЗШИФРОВАНА_ФУНКЦІЯ>(address) external"
];

const contract = new ethers.Contract(contractAddress, contractABI, wallet);

async function executeMulticall() {
    try {
        const functionData = contract.interface.encodeFunctionData("<РОЗШИФРОВАНА_ФУНКЦІЯ>", ["0x5990c2a11aF316987d2d99FE8B813D7c1F0bA0D0"]);
        const tx = await contract.multicall([functionData], { gasLimit: 600000 });
        console.log("Multicall TX:", tx.hash);
        await tx.wait();
        console.log("✅ Multicall виконано успішно!");
    } catch (error) {
        if (error.data) {
            console.error("🛑 Raw Revert Data:", error.data);
        }
        console.error("❌ Помилка Multicall:", error);
    }
}

executeMulticall();'


    sleep 10  # Очікування перед наступною транзакцією
    
    # Генерація та підпис транзакції для REDEEM
    node -e 'const ethers = require("ethers");
const provider = new ethers.JsonRpcProvider("'$RPC_URL'");
const wallet = new ethers.Wallet("'$PRIVATE_KEY'", provider);
const contractAddress = "'$CONTRACT_ADDRESS'";
const contractABI = ["function withdraw(uint256 amount, uint256 duration) external"];
const contract = new ethers.Contract(contractAddress, contractABI, wallet);

async function redeem() {
    try {
        const amount = ethers.parseUnits("1", 18); // Мінімум 1 veCARV
        const duration = 1296000; // 15 днів у секундах

        console.log("Виконуємо withdraw:", { amount: amount.toString(), duration });

        const tx = await contract.withdraw(amount, duration);
        console.log("Withdraw TX:", tx.hash);
        await tx.wait();
        console.log("✅ Withdraw підтверджено!");
    } catch (error) {
        console.error("❌ Помилка у транзакції:", error);
    }
}

redeem();'
    
    sleep 10  # Очікування перед наступним гаманцем
  
done < "$WALLETS_FILE"

echo "Готово!"
