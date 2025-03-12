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
const contractAddress = "'$CONTRACT_ADDRESS'";

// ABI контракту
const contractABI = [
    "function multicall(bytes[] calldata data) external",
    "function claimRewards() external",
    "function pendingRewards(address account) view returns (uint256)",
    "function owner() view returns (address)"
];

const contract = new ethers.Contract(contractAddress, contractABI, wallet);

async function claim() {
    try {
        // Перевірка власника (якщо є такі обмеження)
        const owner = await contract.owner();
        if (wallet.address.toLowerCase() !== owner.toLowerCase()) {
            console.log("⚠️ Цей гаманець не є власником контракту.");
            return;
        }

        // Перевірка наявності нагород
        const pending = await contract.pendingRewards(wallet.address);
        console.log("Pending Rewards:", pending.toString());
        if (pending.isZero()) {
            console.log("⚠️ Немає доступних нагород для CLAIM.");
            return;
        }

        // Симуляція транзакції
        await contract.callStatic.claimRewards();
        console.log("✅ Симуляція CLAIM успішна.");

        // Виконання multicall
        const claimData = contract.interface.encodeFunctionData("claimRewards", []);
        const tx = await contract.multicall([claimData], { gasLimit: 500000 });
        console.log("Claim TX:", tx.hash);
        await tx.wait();
        console.log("✅ Claim підтверджено!");

    } catch (error) {
        if (error.data) {
            console.error("🛑 Raw Revert Data:", error.data);
        }
        console.error("❌ Помилка Claim:", error);
    }
}

claim();'


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
