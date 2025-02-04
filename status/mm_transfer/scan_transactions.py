from web3 import Web3
from web3.middleware import geth_poa_middleware

# RPC-адреса для поддерживаемых сетей
RPC_URLS = {
    "mantle": "https://rpc.mantle.xyz",
    "arbitrum": "https://arb1.arbitrum.io/rpc",
    "optimism": "https://mainnet.optimism.io",
    "opbnb": "https://opbnb-mainnet-rpc.bnbchain.org"
}

def connect_to_network(network):
    """ Подключение к выбранной сети """
    if network not in RPC_URLS:
        print(f"❌ Ошибка: Сеть '{network}' не поддерживается!")
        return None

    w3 = Web3(Web3.HTTPProvider(RPC_URLS[network]))
    
    # Добавляем поддержку POA (Arbitrum, BNB Chain)
    w3.middleware_onion.inject(geth_poa_middleware, layer=0)

    if w3.is_connected():
        print(f"✅ Подключено к сети {network.capitalize()} (Block: {w3.eth.block_number})")
        return w3
    else:
        print(f"❌ Ошибка подключения к сети {network.capitalize()}!")
        return None

def get_transactions_by_address(w3, address, start_block=0, end_block="latest"):
    """ Поиск транзакций для указанного адреса """
    address = address.lower()
    end_block = w3.eth.block_number if end_block == "latest" else end_block
    transactions = []

    print(f"🔍 Поиск транзакций в сети {w3.provider.endpoint_uri} от блока {start_block} до {end_block}...")

    for block_number in range(start_block, end_block + 1):
        block = w3.eth.get_block(block_number, full_transactions=True)
        for tx in block.transactions:
            if tx["from"].lower() == address or (tx["to"] and tx["to"].lower() == address):
                transactions.append({
                    "hash": tx.hash.hex(),
                    "from": tx["from"],
                    "to": tx["to"],
                    "value": w3.from_wei(tx["value"], 'ether'),
                    "block": block_number
                })

    return transactions

def print_transactions(w3, address):
    """ Вывод транзакций в удобном формате """
    transactions = get_transactions_by_address(w3, address)

    if transactions:
        print(f"\n📌 Транзакции для адреса: {address}")
        print("TxHash; Отправитель; Получатель; Значение; Блок")
        for tx in transactions:
            print(f"{tx['hash']}; {tx['from']}; {tx['to']}; {tx['value']} ETH/MNT; {tx['block']}")
    else:
        print(f"❌ Транзакции не найдены для {address}")

if __name__ == "__main__":
    print("Выберите сеть: mantle, arbitrum, optimism, opbnb")
    network = input("Введите название сети: ").strip().lower()
    
    w3 = connect_to_network(network)
    
    if w3:
        address = input("Введите адрес для поиска транзакций: ").strip()
        print_transactions(w3, address)
