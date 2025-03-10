import json
import time
import schedule
from web3 import Web3

# Подключение к RPC сети Arbitrum One
RPC_URL = "https://worldchain-mainnet.g.alchemy.com/v2/uxH9ix8Ifu27RJO332Yii9nqVqGqUTRa"
web3 = Web3(Web3.HTTPProvider(RPC_URL))

# Контракты
MULTICALL_ADDRESS = Web3.to_checksum_address("0x911F8bB66aD57b8c6C80D5D3FC7eB15a9c634")  # Контракт multicall для клейма
WITHDRAW_CONTRACT_ADDRESS = Web3.to_checksum_address("0x2b790Dea1f6c5d72D5C60aF0F9CD6834374a964B")  # Контракт для вывода

# Файл с аккаунтами
ACCOUNTS_FILE = "accounts.json"

# Функции контрактов
CLAIM_FUNCTION_SIG = web3.keccak(text="claim()")[:4].hex()
WITHDRAW_FUNCTION_SIG = web3.keccak(text="withdraw(uint256,uint256)")[:4].hex()

# Выбор режима вывода токенов
print("Выберите режим redeem:")
print("1 - Вывести все токены")
print("2 - Вывести только 10 токенов")
choice = input("Введите 1 или 2: ").strip()

if choice == "1":
    redeem_all = True
    print("✅ Будет выполнен вывод всех токенов.")
elif choice == "2":
    redeem_all = False
    print("✅ Будет выполнен вывод только 10 токенов.")
else:
    print("❌ Неверный выбор, выход из программы.")
    exit()

# Установим duration для `withdraw`
WITHDRAW_DURATION = 0  # Можно изменить, если нужно другое время разблокировки

# Загрузка аккаунтов
def load_accounts():
    with open(ACCOUNTS_FILE, "r") as file:
        return json.load(file)

# Получение nonce
def get_safe_nonce(address):
    return web3.eth.get_transaction_count(address, "pending")

# Функция отправки транзакции
def send_transaction(private_key, to, data, value=0):
    account = web3.eth.account.from_key(private_key)
    nonce = get_safe_nonce(account.address)

    tx = {
        "to": to,
        "value": value,
        "gas": 300000,
        "gasPrice": web3.to_wei("5", "gwei"),
        "nonce": nonce,
        "data": Web3.to_bytes(hexstr=data),
        "chainId": web3.eth.chain_id
    }

    signed_tx = web3.eth.account.sign_transaction(tx, private_key)
    tx_hash = web3.eth.send_raw_transaction(signed_tx.rawTransaction)

    print(f"⏳ Транзакция отправлена: {web3.to_hex(tx_hash)}")
    return web3.to_hex(tx_hash)

# Ожидание подтверждения транзакции
def wait_for_transaction(tx_hash, timeout=60):
    print(f"⏳ Ожидание подтверждения транзакции {tx_hash}...")
    start_time = time.time()

    while time.time() - start_time < timeout:
        receipt = web3.eth.get_transaction_receipt(tx_hash)
        if receipt and receipt.status == 1:
            print(f"✅ Транзакция {tx_hash} подтверждена!")
            return True
        time.sleep(5)

    print(f"⚠️ Транзакция {tx_hash} не подтвердилась за {timeout} секунд.")
    return False

# Получение баланса токенов
def get_balance(wallet_address, contract_address):
    token_contract = web3.eth.contract(address=contract_address, abi=[{
        "constant": True,
        "inputs": [{"name": "_owner", "type": "address"}],
        "name": "balanceOf",
        "outputs": [{"name": "balance", "type": "uint256"}],
        "type": "function"
    }])

    return token_contract.functions.balanceOf(wallet_address).call()

# Клейм токенов через multicall
def claim_tokens(private_key):
    print("⏳ Клейм токенов через multicall...")

    claim_data = CLAIM_FUNCTION_SIG
    multicall_data = "0xac9650d8" + claim_data[2:].zfill(64)

    tx_hash = send_transaction(private_key, MULTICALL_ADDRESS, multicall_data)
    return tx_hash

# Вывод токенов (redeem)
def withdraw_tokens(private_key, wallet_address):
    print(f"⏳ Проверка баланса перед выводом для {wallet_address}...")

    balance = get_balance(wallet_address, WITHDRAW_CONTRACT_ADDRESS)
    if balance > 0:
        if redeem_all:
            amount = balance  # Вывод всех токенов
        else:
            amount = min(10 * (10**18), balance)  # Вывод 10 токенов (с учетом 18 знаков)

        # Формируем правильные данные для `withdraw(uint256,uint256)`
        amount_hex = web3.to_hex(amount)[2:].zfill(64)
        duration_hex = web3.to_hex(WITHDRAW_DURATION)[2:].zfill(64)
        withdraw_data = WITHDRAW_FUNCTION_SIG + amount_hex + duration_hex

        tx_hash = send_transaction(private_key, WITHDRAW_CONTRACT_ADDRESS, withdraw_data)
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
        initial_balance = get_balance(wallet_address, WITHDRAW_CONTRACT_ADDRESS)
        print(f"💰 Баланс до клейма: {initial_balance}")

        # Выполняем клейм токенов
        claim_tx = claim_tokens(private_key)
        if not wait_for_transaction(claim_tx):
            print("❌ Клейм не подтвердился, пропускаем аккаунт.")
            continue

        # Ждем обновления баланса
        new_balance = get_balance(wallet_address, WITHDRAW_CONTRACT_ADDRESS)
        print(f"💰 Баланс после клейма: {new_balance}")

        # Вывод токенов (redeem)
        if new_balance > initial_balance:
            withdraw_tx = withdraw_tokens(private_key, wallet_address)
            wait_for_transaction(withdraw_tx)

        # Логирование
        with open("transactions.log", "a") as log:
            log.write(f"{wallet_address} | Claim: {claim_tx} | Withdraw: {withdraw_tx}\n")

# Запуск скрипта
process_accounts()
