#!/bin/bash

# Файл зі списком гаманців (формат: адреса, приватний ключ)
WALLETS_FILE="wallets.csv"

# Контрактні адреси
CONTRACT_ADDRESS="0xa91fF8b606BA57D8c6638Dd8CF3FC7eB15a9c634"

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
    node -e '
const ethers = require("ethers");
const provider = new ethers.JsonRpcProvider("'$RPC_URL'");
const wallet = new ethers.Wallet("'$PRIVATE_KEY'", provider);

const contractAddress = "'$CONTRACT_ADDRESS'";
const contractABI = [
    "function multicall(bytes[] calldata data) external",
    "function nodeClaim(address node, uint256 rewards) external",
    "function tokenRewards(address node) view returns (uint256)"
];

const contract = new ethers.Contract(contractAddress, contractABI, wallet);

async function simulateMulticall() {
    try {
        const nodeAddress = "'$ADDRESS'";
        const rewards = await contract.tokenRewards(nodeAddress);
        
        if (rewards === 0n) {
            console.log(`❌ Немає доступних нагород для ${nodeAddress}`);
            return;
        }

        const claimData = contract.interface.encodeFunctionData("nodeClaim", [nodeAddress, rewards]);

        // Симуляція multicall
        await contract.callStatic.multicall([claimData]);
        console.log("✅ Симуляція успішна, транзакція не буде відхилена");

    } catch (error) {
        console.error("❌ Симуляція показала, що транзакція буде відхилена:");
        if (error.data) {
            console.error("🛑 Raw Revert Data:", error.data);
        } else {
            console.error(error);
        }
    }
}

simulateMulticall();'


    sleep 10  # Очікування перед наступною транзакцією
    
    # Генерація та підпис транзакції для REDEEM
    node -e '
const ethers = require("ethers");
const provider = new ethers.JsonRpcProvider("'$RPC_URL'");
const wallet = new ethers.Wallet("'$PRIVATE_KEY'", provider);

const contractAddress = "0x2b790Dea1f6c5d72D5C60aF0F9CD6834374a964B";

const contractABI = [
    "function withdraw(uint256 amount, uint256 duration) external",
    "function balanceOf(address account) view returns (uint256)"
];

const contract = new ethers.Contract(contractAddress, contractABI, wallet);

async function simulateWithdraw() {
    try {
        const balance = await contract.balanceOf(wallet.address);
        console.log("Баланс перед withdraw:", ethers.formatUnits(balance, 18));

        if (balance === 0n) {
            console.log("❌ Баланс 0, немає що виводити");
            return;
        }

        const amount = ethers.parseUnits("1", 18); // Виводимо 1 veCARV
        const duration = 1296000; // 15 днів в секундах

        // Симуляція withdraw
        await contract.callStatic.withdraw(amount, duration);
        console.log("✅ Симуляція withdraw успішна");

    } catch (error) {
        console.error("❌ Помилка симуляції withdraw:");
        if (error.data) {
            console.error("🛑 Raw Revert Data:", error.data);
        } else {
            console.error(error);
        }
    }
}

simulateWithdraw();'

  
done < "$WALLETS_FILE"

echo "Готово!"
