import sys
import time
import random
from web3 import Web3
from decimal import Decimal, getcontext
import concurrent.futures

# Устанавливаем высокую точность
getcontext().prec = 30

# Подключение к Web3 (указываем RPC для сети DILL)
RPC_URL = "https://rpc-alps.dill.xyz"
w3 = Web3(Web3.HTTPProvider(RPC_URL))
assert w3.is_connected(), "Ошибка: Не удалось подключиться к сети DILL!"

# Настройки сети
CHAIN_ID = 102125
DEFAULT_GAS_LIMIT = 21000  # Базовый лимит газа для перевода нативных токенов

def get_gas_price():
    """Получает актуальную цену газа"""
    try:
        return w3.eth.gas_price
    except Exception as e:
        print(f"❌ Ошибка получения цены газа: {e}")
        return w3.to_wei(5, 'gwei')  # Дефолтное значение

def get_dill_balance(address):
    """Получает баланс нативного токена DILL"""
    try:
        return w3.from_wei(w3.eth.get_balance(address), 'ether')
    except Exception as e:
        print(f"❌ Ошибка получения баланса {address}: {e}")
        return 0.0

def send_dill(private_key, sender, recipient):
    """Отправляет весь доступный DILL (вычитая газ, не оставляя остаток)"""
    eth_balance_wei = w3.eth.get_balance(sender)

    print(f"💰 Баланс {sender}: {w3.from_wei(eth_balance_wei, 'ether')} DILL")

    if eth_balance_wei <= 0:
        print(f"⚠️ Пропускаем {sender}: баланс 0 DILL")
        return

    gas_price = get_gas_price()
    estimated_gas = DEFAULT_GAS_LIMIT
    required_eth_wei = estimated_gas * gas_price

    print(f"🛠 Требуется {w3.from_wei(required_eth_wei, 'ether')} DILL на газ | Баланс {w3.from_wei(eth_balance_wei, 'ether')} DILL")

    if eth_balance_wei <= required_eth_wei:
        print(f"❌ Недостаточно DILL для газа, пропускаем {sender}")
        return

    send_amount_wei = max(eth_balance_wei - required_eth_wei, 0)

    if send_amount_wei <= 0:
        print(f"⚠️ После учета газа нечего отправлять. Пропускаем {sender}")
        return

    send_amount = w3.from_wei(send_amount_wei, 'ether')
    print(f"📤 Отправляем {send_amount} DILL → {recipient}")

    nonce = w3.eth.get_transaction_count(sender, "pending")

    try:
        tx = {
            'to': recipient,
            'value': int(send_amount_wei),
            'gas': int(estimated_gas),
            'gasPrice': int(gas_price),
            'nonce': nonce,
            'chainId': CHAIN_ID
        }
        signed_tx = w3.eth.account.sign_transaction(tx, private_key)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
        tx_hash_hex = w3.to_hex(tx_hash)

        print(f"✅ Отправлено {send_amount} DILL: {tx_hash_hex}")

        with open("tx_hashes.log", "a") as log_file:
            log_file.write(f"{sender} -> {recipient}: {send_amount} DILL | TX: {tx_hash_hex}\n")

        time.sleep(5)
    except Exception as e:
        print(f"❌ Ошибка при отправке с {sender}: {str(e)}")
        with open("errors.log", "a") as error_file:
            error_file.write(f"Ошибка с {sender}: {str(e)}\n")

def main():
    """Главная функция с многопоточностью и рандомной задержкой"""
    try:
        with open("addresses.txt", "r") as file:
            lines = [line.strip() for line in file if line.strip()]
        
        def process_line(line):
            try:
                sender, private_key, recipient = line.split(";")
                sender = w3.to_checksum_address(sender)
                recipient = w3.to_checksum_address(recipient)

                send_dill(private_key, sender, recipient)

                delay = random.uniform(2, 7)
                print(f"⏳ Задержка {delay:.2f} сек перед следующим потоком")
                time.sleep(delay)

            except Exception as e:
                print(f"⚠️ Ошибка обработки строки '{line}': {e}")

        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            executor.map(process_line, lines)

    except FileNotFoundError:
        print("❌ Файл addresses.txt не найден! Создайте файл и добавьте адреса.")

if __name__ == "__main__":
    main()
