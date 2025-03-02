from web3 import Web3

# Настройки
RPC_URL = "https://mainnet.infura.io/v3/YOUR_INFURA_PROJECT_ID"  # Замените на актуальный RPC
CONTRACT_ADDRESS = "0xb06C68C8f9DE60107eAbda0D7567743967113360"
ABI = '[{"constant":true,"inputs":[{"name":"owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"}]'

# Подключение к сети
web3 = Web3(Web3.HTTPProvider(RPC_URL))

# Подключение к контракту
contract = web3.eth.contract(address=Web3.to_checksum_address(CONTRACT_ADDRESS), abi=ABI)

# Читаем список адресов
with open("wallet.txt", "r") as file:
    addresses = [line.strip() for line in file if line.strip()]

# Проверка наличия NFT
for address in addresses:
    if web3.is_address(address):
        balance = contract.functions.balanceOf(Web3.to_checksum_address(address)).call()
        if balance > 0:
            print(f"{address} владеет {balance} NFT")
        else:
            print(f"{address} не имеет NFT")
    else:
        print(f"Неверный адрес: {address}")
