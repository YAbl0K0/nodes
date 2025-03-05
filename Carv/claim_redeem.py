import json
import time
import schedule
from web3 import Web3

# Подключение к RPC сети Arbitrum One
RPC_URL = "https://worldchain-mainnet.g.alchemy.com/v2/uxH9ix8Ifu27RJO332Yii9nqVqGqUTRa"  # Замени на свой надежный RPC
web3 = Web3(Web3.HTTPProvider(RPC_URL))

# Данные контракта
MULTICALL_ADDRESS = "0xac9650d8"
CLAIM_FUNCTION_SIG = web3.keccak(text="claim()")[:4].hex()
REDEEM_FUNCTION_SIG = web3.keccak(text="redeem(address,uint256)")[:4].hex()

# Файл с аккаунтами
ACCOUNTS_FILE = "accounts.json"
REDEEM_TARGET = "0x2b790Dea1f6c5d72D5C60aF0F9CD6834374a964B"

# Загрузка аккаунтов
def load_accounts():
    with open(ACCOUNTS_FILE, "r") as file:
        return json.load(file)

# Отправка транзакции
def send_transaction(private_key, to, data, value=0):
    account = web3.eth.account.from_key(private_key)
    nonce = web3.eth.get_transaction_count(account.address)

    tx = {
        "to": to,
        "value": value,
        "gas": 250000,
        "gasPrice": web3.to_wei("5", "gwei"),
        "nonce": nonce,
        "data": data,
        "chainId": web3.eth.chain_id
    }

    signed_tx = web3.eth.account.sign_transaction(tx, private_key)
    tx_hash = web3.eth.send_raw_transaction(signed_tx.rawTransaction)
    return web3.to_hex(tx_hash)

# Клейм токенов
def claim_tokens(private_key):
    print("⏳ Клейм токенов...")
    tx_hash = send_transaction(private_key, MULTICALL_ADDRESS, CLAIM_FUNCTION_SIG)
    print(f"✅ Токены заклеймили! Tx: {tx_hash}")
    return tx_hash

# Редим токенов
def redeem_tokens(private_key, wallet_address):
    print(f"⏳ Проверка баланса перед редимом для {wallet_address}...")

    token_contract = web3.eth.contract(address=MULTICALL_ADDRESS, abi=[{
        "constant": True,
        "inputs": [{"name": "_owner", "type": "address"}],
        "name": "balanceOf",
        "outputs": [{"name": "balance", "type": "uint256"}],
        "type": "function"
    }])

    balance = token_contract.functions.balanceOf(wallet_address).call()
    if balance > 0:
        redeem_data = REDEEM_FUNCTION_SIG + web3.to_hex(REDEEM_TARGET)[2:].zfill(64) + web3.to_hex(balance)[2:].zfill(64)
        tx_hash = send_transaction(private_key, MULTICALL_ADDRESS, redeem_data)
        print(f"✅ Токены отправлены! Tx: {tx_hash}")
        return tx_hash
    else:
        print("❌ Баланс = 0, редим невозможен.")
        return None

# Основной процесс для всех аккаунтов
def process_accounts():
    accounts = load_accounts()
    for acc in accounts:
        private_key = acc["private_key"]
        wallet_address = acc["wallet_address"]

        # Клейм токенов
        claim_tx = claim_tokens(private_key)
        time.sleep(10)  # Даем время транзакции

        # Редим токенов
        redeem_tx = redeem_tokens(private_key, wallet_address)

        # Логируем
        with open("transactions.log", "a") as log:
            log.write(f"{wallet_address} | Claim: {claim_tx} | Redeem: {redeem_tx}\n")

# Запускаем процесс каждый день в 9:00
schedule.every().day.at("09:00").do(process_accounts)

print("⏳ Скрипт запущен, ждет 09:00...")
while True:
    schedule.run_pending()
    time.sleep(30)

