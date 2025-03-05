import json
import time
import schedule
from web3 import Web3

# Подключение к RPC сети Arbitrum One
RPC_URL = "https://arb1.arbitrum.io/rpc"  # Замени на свой надежный RPC
web3 = Web3(Web3.HTTPProvider(RPC_URL))

# Контракт multicall
MULTICALL_ADDRESS = "0x911F8bB66aD57b8c6C80D5D3FC7eB15a9c634"  # Уточни адрес

# Файл с аккаунтами
ACCOUNTS_FILE = "accounts.json"

# Функция клейма
CLAIM_FUNCTION_SIG = web3.keccak(text="claim()")[:4].hex()

# Функция вывода (замена redeem)
WITHDRAW_FUNCTION_SIG = web3.keccak(text="withdraw(uint256,uint256)")[:4].hex()

# Загружаем аккаунты
def load_accounts():
    with open(ACCOUNTS_FILE, "r") as file:
        return json.load(file)

# Получаем nonce с безопасным увеличением
def get_safe_nonce(address):
    return web3.eth.get_transaction_count(address, "pending")

# Функция отправки транзакции
def send_transaction(private_key, to, data, value=0):
    account = web3.eth.account.from_key(private_key)
    nonce = get_safe_nonce(account.address)

    tx = {
        "to": to,
        "value": value,
        "gas": 300000,  # Увеличенный gas limit
        "gasPrice": web3.to_wei("5", "gwei"),
        "nonce": nonce,
        "data": data,
        "chainId": web3.eth.chain_id
    }

    signed_tx = web3.eth.account.sign_transaction(tx, private_key)
    tx_hash = web3.eth.send_raw_transaction(signed_tx.rawTransaction)
    return web3.to_hex(tx_hash)

# Клейм токенов через multicall
def claim_tokens(private_key):
    print("⏳ Клейм токенов через multicall...")

    # Формируем данные для multicall
    claim_data = CLAIM_FUNCTION_SIG
    multicall_data = "0xac9650d8" + claim_data[2:].zfill(64)  # 0xac9650d8 — multicall()

    tx_hash = send_transaction(private_key, MULTICALL_ADDRESS, multicall_data)
    print(f"✅ Токены заклеймили! Tx: {tx_hash}")
    return tx_hash

# Функция получения баланса
def get_balance(wallet_address):
    token_contract = web3.eth.contract(address=MULTICALL_ADDRESS, abi=[{
        "constant": True,
        "inputs": [{"name": "_owner", "type": "address"}],
        "name": "balanceOf",
        "outputs": [{"name": "balance", "type": "uint256"}],
        "type": "function"
    }])

    return token_contract.functions.balanceOf(wallet_address).call()

# Вывод токенов (redeem -> withdraw)
def withdraw_tokens(private_key, wallet_address):
    print(f"⏳ Проверка баланса перед выводом для {wallet_address}...")
    balance = get_balance(wallet_address)

    if balance > 0:
        duration = 0  # Укажи корректное значение
        withdraw_data = WITHDRAW_FUNCTION_SIG + web3.to_hex(balance)[2:].zfill(64) + web3.to_hex(duration)[2:].zfill(64)
        
        tx_hash = send_transaction(private_key, MULTICALL_ADDRESS, withdraw_data)
        print(f"✅ Токены успешно выведены! Tx: {tx_hash}")
        return tx_hash
    else:
        print("❌ Баланс = 0, вывод невозможен.")
        return None

# Основной процесс
def process_accounts():
    accounts = load_accounts()
    for acc in accounts:
        private_key = acc["private_key"]
        wallet_address = acc["wallet_address"]

        # Проверяем баланс перед клеймом
        initial_balance = get_balance(wallet_address)
        print(f"💰 Баланс до клейма: {initial_balance}")

        # Клейм токенов
        claim_tx = claim_tokens(private_key)
        time.sleep(10)

        # Проверяем баланс после клейма
        new_balance = get_balance(wallet_address)
        print(f"💰 Баланс после клейма: {new_balance}")

        # Вывод токенов
        withdraw_tx = withdraw_tokens(private_key, wallet_address)

        # Логирование
        with open("transactions.log", "a") as log:
            log.write(f"{wallet_address} | Claim: {claim_tx} | Withdraw: {withdraw_tx}\n")

# Запуск скрипта каждый день в 09:00
schedule.every().day.at("09:00").do(process_accounts)

print("⏳ Скрипт запущен, ждет 09:00...")
while True:
    schedule.run_pending()
    time.sleep(30)
