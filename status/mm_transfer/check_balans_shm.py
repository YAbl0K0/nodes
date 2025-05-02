from web3 import Web3

# RPC нода Shardeum
rpc_url = "https://dapps.shardeum.org/"
web3 = Web3(Web3.HTTPProvider(rpc_url))

if not web3.isConnected():
    print("❌ Не удалось подключиться к RPC")
    exit()

# Загрузка адресов из файла
with open("shm_addresses.txt", "r") as f:
    addresses = [line.strip() for line in f if line.strip().startswith("0x")]

print(f"🔍 Проверка {len(addresses)} адресов...\n")

# Проверка баланса каждого адреса
for address in addresses:
    try:
        balance_wei = web3.eth.get_balance(address)
        balance_shm = web3.fromWei(balance_wei, 'ether')
        print(f"{address} → {balance_shm} SHM")
    except Exception as e:
        print(f"{address} → Ошибка: {e}")
