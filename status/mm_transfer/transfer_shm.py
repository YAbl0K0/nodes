import sys
import time
import random
from web3 import Web3
import concurrent.futures
from decimal import Decimal, getcontext

# Точность
getcontext().prec = 30

# RPC Shardeum
RPC_URL = "https://api.shardeum.org"
w3 = Web3(Web3.HTTPProvider(RPC_URL))

# Проверка соединения
if not w3.is_connected():
    print("❌ Не удалось подключиться к RPC Shardeum!")
    sys.exit()

CHAIN_ID = 8118  # mainnet Shardeum
GAS_LIMIT = 21000  # стандартный газ для перевода нативных токенов

def get_gas_price():
    try:
        return w3.eth.gas_price
    except Exception as e:
        print(f"❌ Ошибка получения цены газа: {e}")
        return w3.to_wei(1, 'gwei')  # fallback

def send_shm(private_key, sender, recipient):
    try:
        balance_wei = w3.eth.get_balance(sender)
        balance = w3.from_wei(balance_wei, 'ether')
        print(f"💰 Баланс {sender}: {balance} SHM")

        gas_price = get_gas_price()
        required_wei = gas_price * GAS_LIMIT

        if balance_wei <= required_wei:
            print(f"⚠️ Недостаточно SHM для оплаты газа, пропускаем {sender}")
            return

        send_amount_wei = balance_wei - required_wei
        send_amount = w3.from_wei(send_amount_wei, 'ether')
        print(f"📤 Отправляем {send_amount} SHM → {recipient}")

        nonce = w3.eth.get_transaction_count(sender, 'pending')
        tx = {
            'nonce': nonce,
            'to': recipient,
            'value': send_amount_wei,
            'gas': GAS_LIMIT,
            'gasPrice': gas_price,
            'chainId': CHAIN_ID
        }

        signed_tx = w3.eth.account.sign_transaction(tx, private_key)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
        tx_url = f"https://explorer.shardeum.org/transaction/{w3.to_hex(tx_hash)}"

        print(f"✅ TX отправлена: {tx_url}")

        with open("tx_hashes.log", "a") as f:
            f.write(f"{sender} → {recipient}: {send_amount} SHM | TX: {tx_url}\n")

        time.sleep(2)

    except Exception as e:
        print(f"❌ Ошибка у {sender}: {e}")
        with open("errors.log", "a") as f:
            f.write(f"{sender}: {e}\n")

def main():
    try:
        with open("addresses_shm.txt", "r") as f:
            lines = [line.strip() for line in f if line.strip()]

        def process(line):
            try:
                sender, private_key, recipient = line.split(";")
                sender = w3.to_checksum_address(sender)
                recipient = w3.to_checksum_address(recipient)
                send_shm(private_key, sender, recipient)
                time.sleep(random.uniform(2, 5))
            except Exception as e:
                print(f"⚠️ Ошибка строки '{line}': {e}")

        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            executor.map(process, lines)

    except FileNotFoundError:
        print("❌ Файл addresses.txt не найден!")

if __name__ == "__main__":
    main()
