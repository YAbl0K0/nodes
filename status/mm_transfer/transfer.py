from web3 import Web3

# RPC-адреса для поддерживаемых сетей
RPC_URLS = {
    "mantle": "https://rpc.mantle.xyz",
    "arbitrum": "https://arb1.arbitrum.io/rpc",
    "optimism": "https://mainnet.optimism.io",
    "opbnb": "https://opbnb-mainnet-rpc.bnbchain.org",
}

def connect_to_network():
    """Меню выбора сети и подключение"""
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

def get_last_transactions(w3, address, count=1):
    """Получить последние транзакции (1 или 10)"""
    latest_block = w3.eth.block_number
    transactions = []

    print(f"🔍 Поиск последних {count} транзакций...")

    for block_number in range(latest_block, latest_block - 1000, -1):  # Сканируем последние 1000 блоков
        try:
            block = w3.eth.get_block(block_number, full_transactions=True)
        except Exception as e:
            print(f"⚠️ Ошибка при чтении блока {block_number}: {e}")
            continue

        for tx in block.transactions:
            if tx["from"].lower() == address.lower() or (tx["to"] and tx["to"].lower() == address.lower()):
                transactions.append({
                    "hash": tx.hash.hex(),
                    "from": tx["from"],
                    "to": tx["to"],
                    "value": w3.from_wei(tx["value"], 'ether'),
                    "block": block_number,
                })

            if len(transactions) >= count:
                return transactions

    return transactions

def print_transactions(transactions, count):
    """Вывод транзакций в удобном формате"""
    if transactions:
        print(f"\n📌 Последние {count} транзакций:")
        print("TxHash; Отправитель; Получатель; Значение; Блок")
        for tx in transactions:
            print(f"{tx['hash']}; {tx['from']}; {tx['to']}; {tx['value']} ETH/MNT; {tx['block']}")
    else:
        print("❌ Транзакции не найдены")

if __name__ == "__main__":
    w3 = connect_to_network()
    if w3:
        address = input("\nВведите адрес для поиска транзакций: ").strip()
        print("\nЧто вы хотите получить?")
        print("1. Последнюю транзакцию")
        print("2. Последние 10 транзакций")
        choice = int(input("Введите ваш выбор (1 или 2): ").strip())

        count = 1 if choice == 1 else 10
        transactions = get_last_transactions(w3, address, count)
        print_transactions(transactions, count)
