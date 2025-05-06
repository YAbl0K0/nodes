import sys
import time
import random
from web3 import Web3
import concurrent.futures
from decimal import Decimal, getcontext

getcontext().prec = 30

# Один фиксированный RPC
RPC_URL = "https://api.shardeum.org"
w3 = Web3(Web3.HTTPProvider(RPC_URL))

# Проверка подключения
if not w3.is_connected():
    print("❌ Не удалось подключиться к RPC Shardeum!")
    sys.exit()

CHAIN_ID = 8118
GAS_LIMIT = 22000
RETRY_LIMIT = 5  # кол-во попыток при ошибке 101

def get_gas_price():
    try:
        return w3.eth.gas_price
    except:
        return w3.to_wei(1, 'gwei')

def send_shm(private_key, sender, recipient):
    try:
        balance_wei = w3.eth.get_balance(sender)
        balance = w3.from_wei(balance_wei, 'ether')
        print(f"💰 Баланс {sender}: {balance} SHM")

        gas_price = get_gas_price()
        required_wei = gas_price * GAS_LIMIT

        if balance_wei <= required_wei:
            print(f"⚠️ Недостаточно SHM для газа, пропускаем {sender}")
            return True  # Считаем это "успешной" попыткой, т.к. отправлять не нужно

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

        for attempt in range(RETRY_LIMIT):
            try:
                tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
                tx_url = f"https://explorer.shardeum.org/transaction/{w3.to_hex(tx_hash)}"
                print(f"✅ TX отправлена: {tx_url}")

                with open("tx_hashes.log", "a") as f:
                    f.write(f"{sender} → {recipient}: {send_amount} SHM | TX: {tx_url}\n")
                return True
            except Exception as e:
                if "Maximum load exceeded" in str(e) and attempt < RETRY_LIMIT - 1:
                    wait_time = 5 + attempt * 2
                    print(f"⚠️ Перегрузка RPC, повтор {attempt + 1}/3 через {wait_time} сек...")
                    time.sleep(wait_time)
                else:
                    print(f"❌ Ошибка у {sender}: {e}")
                    with open("errors.log", "a") as f:
                        f.write(f"{sender}: {e}\n")
                    return False
    except Exception as e:
        print(f"❌ Общая ошибка у {sender}: {e}")
        with open("errors.log", "a") as f:
            f.write(f"{sender}: {e}\n")
        return False

def main():
    try:
        with open("addresses_shm.txt", "r") as f:
            lines = [line.strip() for line in f if line.strip()]

        def process(line):
            try:
                sender, private_key, recipient = line.split(";")
                sender = w3.to_checksum_address(sender)
                recipient = w3.to_checksum_address(recipient)

                max_global_retries = 10
                attempt = 0

                while attempt < max_global_retries:
                    success = send_shm(private_key, sender, recipient)
                    if success:
                        break
                    attempt += 1
                    print(f"🔁 Попытка {attempt}/{max_global_retries} для {sender}, через 10 сек...")
                    time.sleep(10)

                if attempt >= max_global_retries:
                    print(f"❌ Превышено количество попыток для {sender}, аварийное завершение.")
                    with open("errors.log", "a") as f:
                        f.write(f"{sender}: Превышено {max_global_retries} попыток\n")
                    sys.exit(1)

                time.sleep(random.uniform(5, 10))
            except Exception as e:
                print(f"⚠️ Ошибка строки '{line}': {e}")

        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
            executor.map(process, lines)

    except FileNotFoundError:
        print("❌ Файл addresses_shm.txt не найден!")

if __name__ == "__main__":
    main()
