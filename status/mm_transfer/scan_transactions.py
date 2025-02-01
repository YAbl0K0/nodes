from web3 import Web3

# Подключение к Mantle RPC
RPC_URL = "https://rpc.mantle.xyz"
w3 = Web3(Web3.HTTPProvider(RPC_URL))

assert w3.is_connected(), "Ошибка: Не удалось подключиться к сети Mantle!"

def get_transactions_by_address(address, start_block=0, end_block="latest"):
    """ Ищет все транзакции, связанные с указанным адресом """
    address = address.lower()  # Приводим к нижнему регистру для точного сравнения
    end_block = w3.eth.block_number if end_block == "latest" else end_block
    transactions = []

    print(f"🔍 Поиск транзакций от блока {start_block} до {end_block}...")

    for block_number in range(start_block, end_block + 1):
        block = w3.eth.get_block(block_number, full_transactions=True)

        for tx in block.transactions:
            if tx["from"].lower() == address or tx["to"] and tx["to"].lower() == address:
                transactions.append({
                    "hash": tx.hash.hex(),
                    "from": tx["from"],
                    "to": tx["to"],
                    "value": w3.from_wei(tx["value"], 'ether'),
                    "block": block_number
                })

    return transactions

def print_transactions(address):
    """ Выводит транзакции в удобном формате """
    transactions = get_transactions_by_address(address)

    if transactions:
        print(f"\n📌 Транзакции для адреса: {address}")
        print("TxHash; Отправитель; Получатель; Значение; Блок")
        for tx in transactions:
            print(f"{tx['hash']}; {tx['from']}; {tx['to']}; {tx['value']} MNT; {tx['block']}")
    else:
        print(f"❌ Транзакции не найдены для {address}")

if __name__ == "__main__":
    address = input("Введите адрес для поиска транзакций: ").strip()
    print_transactions(address)
