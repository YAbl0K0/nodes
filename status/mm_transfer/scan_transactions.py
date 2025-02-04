from web3 import Web3

# RPC URL
RPC_URL = "https://arb1.arbitrum.io/rpc"  # Замените на нужный RPC

def get_logs(address, from_block=0, to_block="latest"):
    """Получение логов для указанного адреса"""
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    if not w3.is_connected():
        print("❌ Ошибка подключения к RPC")
        return []

    print(f"✅ Подключено. Текущий блок: {w3.eth.block_number}")

    # Параметры запроса логов
    logs = w3.eth.get_logs({
        "fromBlock": from_block,
        "toBlock": to_block,
        "address": address
    })

    return logs

if __name__ == "__main__":
    address = input("Введите адрес: ").strip()
    logs = get_logs(address)
    print(f"Найдено логов: {len(logs)}")

    # Вывод логов
    for log in logs:
        print(f"TxHash: {log['transactionHash'].hex()}, Block: {log['blockNumber']}")
