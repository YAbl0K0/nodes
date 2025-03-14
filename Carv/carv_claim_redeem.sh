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

    node -e '
    const ethers = require("ethers");
    const provider = new ethers.JsonRpcProvider("'$RPC_URL'");
    const wallet = new ethers.Wallet("'$PRIVATE_KEY'", provider);

    const contractAddress = "'$CONTRACT_ADDRESS'";
    const contractABI = [
        "function multicall(bytes[] calldata data) external",
        "function nodeClaim(address node, uint256 rewards) external"
    ];

    const contract = new ethers.Contract(contractAddress, contractABI, wallet);

    async function executeMulticall() {
        try {
            const nodeAddress = "'$ADDRESS'";
            const rewards = ethers.parseUnits("1", 18); // Мінімальна тестова сума

            // Кодування виклику nodeClaim
            const claimData = contract.interface.encodeFunctionData("nodeClaim", [nodeAddress, rewards]);

            // Виклик multicall з nodeClaim
            const tx = await contract.multicall([claimData], { gasLimit: 800000 });
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

done < "$WALLETS_FILE"

echo "Готово!"
