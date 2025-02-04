from web3 import Web3
from concurrent.futures import ThreadPoolExecutor

RPC_URLS = {
    "mantle": "https://rpc.mantle.xyz",
    "arbitrum": "https://arb1.arbitrum.io/rpc",
    "optimism": "https://mainnet.optimism.io",
    "opbnb": "https://opbnb-mainnet-rpc.bnbchain.org",
}

def connect_to_network():
    print("\nВыберите сеть:")
    for i, network in enumerate(RPC_URLS.keys(), 1):
        print(f"{i}. {network.capitalize()}")

    choice = int(input("Введите номер сети: ").strip()) - 1
    network = list(RPC_URLS.keys())[choice]
    print(f"\nПодключаемся к сети {network.capitalize()}...")
    w3 = Web3(Web3.HTTPProvider(RPC_URLS[network]))

    if w3.is_connected():
        print(f"✅ Успешно подключено к сети {network.capitalize()} (Block: {w3.eth.block_number})")
        return w3
    else:
        print(f"❌ Ошибка подключения к сети {network.capitalize()}!")
        return None

def scan_block_range(w3, address, start_block, end_block):
    transactions = []
    for block_number in range(start_block, end_block + 1):
        try:
            block = w3.eth.get_block(block_number, full_transactions=True)
            for tx in block.transactions:
                if tx["from"].lower() == address.lower() or (tx["to"] and tx["to"].lower() == address.lower()):
                    transactions.append({
                        "hash": tx.hash.hex(),
                        "from": tx["from"],
                        "to": tx["to"],
                        "value": w3.from_wei(tx["value"], 'ether'),
                        "block": block_number,
                    })
        except Exception:
            continue
    return transactions

def get_transactions_parallel(w3, address, latest_block, workers=4):
    step = latest_block // workers
    ranges = [(i, min(i + step, latest_block)) for i in range(0, latest_block + 1, step)]
    transactions = []

    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = [executor.submit(scan_block_range, w3, address, start, end) for start, end in ranges]
        for future in futures:
            transactions.extend(future.result())

    return transactions

def print_transactions(transactions):
    if transactions:
        print("\n📌 Найденные транзакции:")
        print("TxHash; Отправитель; Получатель; Значение; Блок")
        for tx in transactions:
            print(f"{tx['hash']}; {tx['from']}; {tx['to']}; {tx['value']} ETH/MNT; {tx['block']}")
    else:
        print("❌ Транзакции не найдены")

if __name__ == "__main__":
    w3 = connect_to_network()
    if w3:
        address = input("\nВведите адрес для поиска транзакций: ").strip()
        latest_block = w3.eth.block_number

        print("🔍 Параллельное сканирование...")
        transactions = get_transactions_parallel(w3, address, latest_block, workers=4)
        print_transactions(transactions)
